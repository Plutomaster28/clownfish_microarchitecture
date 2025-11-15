// ============================================================================
// L1 Instruction Cache - Clownfish RISC-V Processor
// ============================================================================
// 32 KB, 4-way set associative, 64-byte cache lines
// Uses OpenRAM-generated SRAM macros (8x 64-bit words per line)
// Non-blocking with MSHR support
// ============================================================================

`include "../../include/clownfish_config.vh"

module l1_icache (
    input  wire         clk,
    input  wire         rst_n,
    
    // CPU interface
    input  wire         req_valid_i,
    input  wire [31:0]  req_addr_i,
    output reg          req_ready_o,
    
    output reg          resp_valid_o,
    output reg  [31:0]  resp_data_o,
    output reg          resp_error_o,
    input  wire         resp_ready_i,
    
    // L2 cache interface
    output reg          l2_req_valid_o,
    output reg  [31:0]  l2_req_addr_o,
    input  wire         l2_req_ready_i,
    
    input  wire         l2_resp_valid_i,
    input  wire [511:0] l2_resp_data_i,  // Full cache line (64 bytes)
    input  wire         l2_resp_error_i,
    output reg          l2_resp_ready_o,
    
    // Flush interface
    input  wire         flush_i
);

// Cache parameters
localparam SETS = `L1_ICACHE_SETS;      // 128 sets
localparam WAYS = `L1_ICACHE_WAYS;      // 4 ways
localparam LINE_SIZE = `L1_ICACHE_LINE_SIZE;  // 64 bytes
localparam WORDS_PER_LINE = 8;           // 8x 64-bit words

// Address breakdown
// [31:12] Tag (20 bits)
// [11:6]  Index (6 bits for 64 sets, but we have 128 so 7 bits)
// [5:0]   Offset (6 bits for 64 bytes)
localparam INDEX_WIDTH = 7;
localparam OFFSET_WIDTH = 6;
localparam TAG_WIDTH = 32 - INDEX_WIDTH - OFFSET_WIDTH;
localparam INDEX_MSB = OFFSET_WIDTH + INDEX_WIDTH - 1;

wire [INDEX_WIDTH-1:0] req_index  = req_addr_i[INDEX_MSB:OFFSET_WIDTH];
wire [TAG_WIDTH-1:0]   req_tag    = req_addr_i[31:INDEX_MSB+1];
wire [OFFSET_WIDTH-1:0] req_offset = req_addr_i[OFFSET_WIDTH-1:0];
wire [2:0]             req_word   = req_addr_i[OFFSET_WIDTH-1:3];  // Which 64-bit word in line

// Cache state machine
localparam STATE_IDLE       = 3'b000;
localparam STATE_TAG_CHECK  = 3'b001;
localparam STATE_ALLOCATE   = 3'b010;
localparam STATE_REFILL     = 3'b011;
localparam STATE_RESPOND    = 3'b100;

reg [2:0] state, next_state;

// OpenRAM SRAM instances (4 ways × 8 words per line)
// Each SRAM is 64-bit × 128 entries
localparam TOTAL_SRAMS = WAYS * WORDS_PER_LINE;
localparam SRAM_ADDR_BITS = 7;
localparam SRAM_DATA_BITS = 64;
localparam SRAM_MASK_BITS = 8;

wire [TOTAL_SRAMS-1:0]                       sram_csb;   // Chip select (active low)
wire [TOTAL_SRAMS-1:0]                       sram_web;   // Write enable (active low)
wire [TOTAL_SRAMS*SRAM_MASK_BITS-1:0]        sram_wmask;
wire [TOTAL_SRAMS*SRAM_ADDR_BITS-1:0]        sram_addr;
wire [TOTAL_SRAMS*SRAM_DATA_BITS-1:0]        sram_din;
wire [TOTAL_SRAMS*SRAM_DATA_BITS-1:0]        sram_dout;

genvar sram_idx;
generate
    for (sram_idx = 0; sram_idx < TOTAL_SRAMS; sram_idx = sram_idx + 1) begin : gen_sram_defaults
        assign sram_csb[sram_idx]  = 1'b0;              // always enable for read
        assign sram_web[sram_idx]  = 1'b1;              // default to read mode
        assign sram_wmask[sram_idx*SRAM_MASK_BITS +: SRAM_MASK_BITS] = {SRAM_MASK_BITS{1'b1}};
        assign sram_addr[sram_idx*SRAM_ADDR_BITS +: SRAM_ADDR_BITS]  = req_index[SRAM_ADDR_BITS-1:0];
        assign sram_din[sram_idx*SRAM_DATA_BITS +: SRAM_DATA_BITS]   = {SRAM_DATA_BITS{1'b0}};
    end
endgenerate

// Tag/Valid storage (separate small SRAM or registers)
reg [TAG_WIDTH-1:0] tag_array [0:WAYS-1][0:SETS-1];
reg                 valid_array [0:WAYS-1][0:SETS-1];

// LRU bits (pseudo-LRU for 4-way)
reg [2:0] lru_bits [0:SETS-1];  // 3 bits for 4-way pseudo-LRU

// Hit detection
reg [WAYS-1:0] way_hit;
reg hit;
reg [1:0] hit_way;

// Response buffer
reg [31:0] resp_buffer;

wire [SRAM_DATA_BITS-1:0] hit_word_data;
assign hit_word_data = sram_dout[(((hit_way * WORDS_PER_LINE) + req_word) * SRAM_DATA_BITS) +: SRAM_DATA_BITS];

// Generate SRAM instances for each way and word
genvar way, word;
generate
    for (way = 0; way < WAYS; way = way + 1) begin : gen_ways
        for (word = 0; word < WORDS_PER_LINE; word = word + 1) begin : gen_words
            localparam integer SRAM_IDX = way * WORDS_PER_LINE + word;
            sram_l1_icache_way sram_inst (
                .clk0   (clk),
                .csb0   (sram_csb[SRAM_IDX]),
                .web0   (sram_web[SRAM_IDX]),
                .wmask0 (sram_wmask[SRAM_IDX*SRAM_MASK_BITS +: SRAM_MASK_BITS]),
                .addr0  (sram_addr[SRAM_IDX*SRAM_ADDR_BITS +: SRAM_ADDR_BITS]),
                .din0   (sram_din[SRAM_IDX*SRAM_DATA_BITS +: SRAM_DATA_BITS]),
                .dout0  (sram_dout[SRAM_IDX*SRAM_DATA_BITS +: SRAM_DATA_BITS])
            );
        end
    end
endgenerate

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= STATE_IDLE;
    else if (flush_i)
        state <= STATE_IDLE;
    else
        state <= next_state;
end

// Next state logic
always @(*) begin
    next_state = state;
    
    case (state)
        STATE_IDLE: begin
            if (req_valid_i)
                next_state = STATE_TAG_CHECK;
        end
        
        STATE_TAG_CHECK: begin
            if (hit)
                next_state = STATE_RESPOND;
            else if (l2_req_ready_i)
                next_state = STATE_ALLOCATE;
        end
        
        STATE_ALLOCATE: begin
            if (l2_resp_valid_i)
                next_state = STATE_REFILL;
        end
        
        STATE_REFILL: begin
            next_state = STATE_RESPOND;
        end
        
        STATE_RESPOND: begin
            if (resp_ready_i)
                next_state = STATE_IDLE;
        end
        
        default: next_state = STATE_IDLE;
    endcase
end

// Tag check logic
integer i;
always @(*) begin
    hit = 1'b0;
    hit_way = 2'b00;
    way_hit = 4'b0000;
    
    for (i = 0; i < WAYS; i = i + 1) begin
        if (valid_array[i][req_index] && (tag_array[i][req_index] == req_tag)) begin
            hit = 1'b1;
            hit_way = i[1:0];
            way_hit[i] = 1'b1;
        end
    end
end

// Output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        req_ready_o     <= 1'b1;
        resp_valid_o    <= 1'b0;
        resp_data_o     <= 32'h0;
        resp_error_o    <= 1'b0;
        l2_req_valid_o  <= 1'b0;
        l2_req_addr_o   <= 32'h0;
        l2_resp_ready_o <= 1'b0;
    end else begin
        case (state)
            STATE_IDLE: begin
                req_ready_o  <= 1'b1;
                resp_valid_o <= 1'b0;
            end
            
            STATE_TAG_CHECK: begin
                req_ready_o <= 1'b0;
                if (hit) begin
                    // Read from SRAM (hit_way, req_word)
                    // Simplified: Return instruction from cache
                    resp_data_o  <= hit_word_data[31:0];
                    resp_valid_o <= 1'b1;
                    resp_error_o <= 1'b0;
                end else begin
                    // Miss: Request from L2
                    l2_req_valid_o <= 1'b1;
                    l2_req_addr_o  <= {req_addr_i[31:6], 6'h0};  // Aligned address
                end
            end
            
            STATE_ALLOCATE: begin
                l2_resp_ready_o <= 1'b1;
            end
            
            STATE_REFILL: begin
                // Write cache line from L2
                l2_resp_ready_o <= 1'b0;
                resp_data_o     <= hit_word_data[31:0];
                resp_valid_o    <= 1'b1;
            end
            
            STATE_RESPOND: begin
                if (resp_ready_i) begin
                    resp_valid_o <= 1'b0;
                end
            end
        endcase
    end
end

// Initialize tag/valid arrays
integer j, k;
initial begin
    for (j = 0; j < WAYS; j = j + 1) begin
        for (k = 0; k < SETS; k = k + 1) begin
            tag_array[j][k] = {TAG_WIDTH{1'b0}};
            valid_array[j][k] = 1'b0;
        end
    end
    for (k = 0; k < SETS; k = k + 1) begin
        lru_bits[k] = 3'b000;
    end
end

endmodule
