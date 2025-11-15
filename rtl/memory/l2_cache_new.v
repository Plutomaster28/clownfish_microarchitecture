// ============================================================================
// L2 Unified Cache - Clownfish RISC-V Processor
// ============================================================================
// 512 KB, 8-way set associative, 64-byte cache lines
// Write-back policy, inclusive with L1
// Services both L1 I-Cache and L1 D-Cache
// Uses OpenRAM-generated SRAM macros (8x 64-bit words per line)
// ============================================================================

`include "../../include/clownfish_config.vh"

module l2_cache_new (
    input  wire         clk,
    input  wire         rst_n,
    
    // L1 I-Cache interface
    input  wire         l1i_req_valid_i,
    input  wire [31:0]  l1i_req_addr_i,
    output reg          l1i_req_ready_o,
    
    output reg          l1i_resp_valid_o,
    output reg  [511:0] l1i_resp_data_o,
    output reg          l1i_resp_error_o,
    input  wire         l1i_resp_ready_i,
    
    // L1 D-Cache interface
    input  wire         l1d_req_valid_i,
    input  wire [31:0]  l1d_req_addr_i,
    input  wire         l1d_req_we_i,
    input  wire [511:0] l1d_req_data_i,
    output reg          l1d_req_ready_o,
    
    output reg          l1d_resp_valid_o,
    output reg  [511:0] l1d_resp_data_o,
    output reg          l1d_resp_error_o,
    input  wire         l1d_resp_ready_i,
    
    // Memory interface (to external DRAM controller)
    output reg          mem_req_valid_o,
    output reg  [31:0]  mem_req_addr_o,
    output reg          mem_req_we_o,
    output reg  [511:0] mem_req_data_o,
    input  wire         mem_req_ready_i,
    
    input  wire         mem_resp_valid_i,
    input  wire [511:0] mem_resp_data_i,
    input  wire         mem_resp_error_i,
    output reg          mem_resp_ready_o
);

// L2 Cache parameters
localparam SETS = `L2_CACHE_SETS;            // 1024 sets
localparam WAYS = `L2_CACHE_WAYS;            // 8 ways
localparam LINE_SIZE = `L2_CACHE_LINE_SIZE;  // 64 bytes
localparam WORDS_PER_LINE = 8;               // 8x 64-bit words

// Address breakdown
// [31:16] Tag (16 bits)
// [15:6]  Index (10 bits for 1024 sets)
// [5:0]   Offset (6 bits for 64 bytes)
localparam TAG_WIDTH = 16;
localparam INDEX_WIDTH = 10;
localparam OFFSET_WIDTH = 6;

// Request arbitration (L1I has priority for instruction fetches)
wire req_valid = l1i_req_valid_i | l1d_req_valid_i;
wire req_is_l1i = l1i_req_valid_i;
wire [31:0] req_addr = l1i_req_valid_i ? l1i_req_addr_i : l1d_req_addr_i;
wire req_we = l1d_req_valid_i & l1d_req_we_i;
wire [511:0] req_wdata = l1d_req_data_i;

wire [TAG_WIDTH-1:0]   req_tag    = req_addr[31:16];
wire [INDEX_WIDTH-1:0] req_index  = req_addr[15:6];
wire [OFFSET_WIDTH-1:0] req_offset = req_addr[5:0];

// Cache state machine
localparam STATE_IDLE       = 4'b0000;
localparam STATE_TAG_CHECK  = 4'b0001;
localparam STATE_WRITE_HIT  = 4'b0010;
localparam STATE_WRITEBACK  = 4'b0011;
localparam STATE_ALLOCATE   = 4'b0100;
localparam STATE_REFILL     = 4'b0101;
localparam STATE_RESPOND    = 4'b0110;

reg [3:0] state, next_state;
reg req_was_l1i;  // Track which L1 made the request

// OpenRAM SRAM instances (8 ways × 8 words per line)
reg  sram_csb   [0:WAYS-1][0:WORDS_PER_LINE-1];
reg  sram_web   [0:WAYS-1][0:WORDS_PER_LINE-1];
reg  [7:0] sram_wmask [0:WAYS-1][0:WORDS_PER_LINE-1];
reg  [8:0] sram_addr  [0:WAYS-1][0:WORDS_PER_LINE-1];
reg  [63:0] sram_din  [0:WAYS-1][0:WORDS_PER_LINE-1];
wire [63:0] sram_dout [0:WAYS-1][0:WORDS_PER_LINE-1];

// Tag/Valid/Dirty storage
reg [TAG_WIDTH-1:0] tag_array [0:WAYS-1][0:SETS-1];
reg                 valid_array [0:WAYS-1][0:SETS-1];
reg                 dirty_array [0:WAYS-1][0:SETS-1];

// Pseudo-LRU for 8-way (7 bits per set)
reg [6:0] lru_bits [0:SETS-1];

// Hit detection
reg [WAYS-1:0] way_hit;
reg hit;
reg [2:0] hit_way;
reg [2:0] victim_way;

// Cache line buffer
reg [511:0] line_buffer;

// Generate SRAM instances
genvar way, word;
generate
    for (way = 0; way < WAYS; way = way + 1) begin : gen_ways
        for (word = 0; word < WORDS_PER_LINE; word = word + 1) begin : gen_words
            sram_l2_cache_way sram_inst (
                .clk0   (clk),
                .csb0   (sram_csb[way][word]),
                .web0   (sram_web[way][word]),
                .wmask0 (sram_wmask[way][word]),
                .addr0  (sram_addr[way][word]),
                .din0   (sram_din[way][word]),
                .dout0  (sram_dout[way][word])
            );
        end
    end
endgenerate

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= STATE_IDLE;
    else
        state <= next_state;
end

// Next state logic
always @(*) begin
    next_state = state;
    
    case (state)
        STATE_IDLE: begin
            if (req_valid)
                next_state = STATE_TAG_CHECK;
        end
        
        STATE_TAG_CHECK: begin
            if (hit) begin
                if (req_we)
                    next_state = STATE_WRITE_HIT;
                else
                    next_state = STATE_RESPOND;
            end else begin
                // Miss: check if victim is dirty
                if (valid_array[victim_way][req_index] && 
                    dirty_array[victim_way][req_index])
                    next_state = STATE_WRITEBACK;
                else if (mem_req_ready_i)
                    next_state = STATE_ALLOCATE;
            end
        end
        
        STATE_WRITE_HIT: begin
            next_state = STATE_RESPOND;
        end
        
        STATE_WRITEBACK: begin
            if (mem_req_ready_i)
                next_state = STATE_ALLOCATE;
        end
        
        STATE_ALLOCATE: begin
            if (mem_resp_valid_i)
                next_state = STATE_REFILL;
        end
        
        STATE_REFILL: begin
            next_state = STATE_RESPOND;
        end
        
        STATE_RESPOND: begin
            if ((req_was_l1i && l1i_resp_ready_i) || 
                (!req_was_l1i && l1d_resp_ready_i))
                next_state = STATE_IDLE;
        end
        
        default: next_state = STATE_IDLE;
    endcase
end

// Tag check and hit detection
integer i;
always @(*) begin
    hit = 1'b0;
    hit_way = 3'b000;
    way_hit = 8'h00;
    
    for (i = 0; i < WAYS; i = i + 1) begin
        if (valid_array[i][req_index] && (tag_array[i][req_index] == req_tag)) begin
            hit = 1'b1;
            hit_way = i[2:0];
            way_hit[i] = 1'b1;
        end
    end
    
    // Victim selection using pseudo-LRU
    // Simplified: use lower bits of LRU
    victim_way = lru_bits[req_index][2:0];
end

// SRAM control logic
integer w, wd;
always @(*) begin
    // Default: All SRAMs disabled
    for (w = 0; w < WAYS; w = w + 1) begin
        for (wd = 0; wd < WORDS_PER_LINE; wd = wd + 1) begin
            sram_csb[w][wd] = 1'b1;   // Disabled
            sram_web[w][wd] = 1'b1;   // Read
            sram_wmask[w][wd] = 8'hFF;
            sram_addr[w][wd] = req_index[8:0];
            sram_din[w][wd] = 64'h0;
        end
    end
    
    case (state)
        STATE_TAG_CHECK, STATE_RESPOND: begin
            // Read from all ways for tag check
            for (w = 0; w < WAYS; w = w + 1) begin
                for (wd = 0; wd < WORDS_PER_LINE; wd = wd + 1) begin
                    sram_csb[w][wd] = 1'b0;   // Enable
                    sram_web[w][wd] = 1'b1;   // Read
                    sram_addr[w][wd] = req_index[8:0];
                end
            end
        end
        
        STATE_WRITE_HIT: begin
            // Write to hit way
            for (wd = 0; wd < WORDS_PER_LINE; wd = wd + 1) begin
                sram_csb[hit_way][wd] = 1'b0;
                sram_web[hit_way][wd] = 1'b0;  // Write
                sram_addr[hit_way][wd] = req_index[8:0];
                sram_din[hit_way][wd] = req_wdata[wd*64 +: 64];
            end
        end
        
        STATE_WRITEBACK: begin
            // Read victim line for writeback
            for (wd = 0; wd < WORDS_PER_LINE; wd = wd + 1) begin
                sram_csb[victim_way][wd] = 1'b0;
                sram_web[victim_way][wd] = 1'b1;  // Read
                sram_addr[victim_way][wd] = req_index[8:0];
            end
        end
        
        STATE_REFILL: begin
            // Write entire cache line from memory
            for (wd = 0; wd < WORDS_PER_LINE; wd = wd + 1) begin
                sram_csb[victim_way][wd] = 1'b0;
                sram_web[victim_way][wd] = 1'b0;  // Write
                sram_addr[victim_way][wd] = req_index[8:0];
                sram_wmask[victim_way][wd] = 8'hFF;
                sram_din[victim_way][wd] = mem_resp_data_i[wd*64 +: 64];
            end
        end
    endcase
end

// Output control logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        l1i_req_ready_o  <= 1'b1;
        l1i_resp_valid_o <= 1'b0;
        l1i_resp_data_o  <= 512'h0;
        l1i_resp_error_o <= 1'b0;
        
        l1d_req_ready_o  <= 1'b1;
        l1d_resp_valid_o <= 1'b0;
        l1d_resp_data_o  <= 512'h0;
        l1d_resp_error_o <= 1'b0;
        
        mem_req_valid_o  <= 1'b0;
        mem_req_addr_o   <= 32'h0;
        mem_req_we_o     <= 1'b0;
        mem_req_data_o   <= 512'h0;
        mem_resp_ready_o <= 1'b0;
        
        req_was_l1i <= 1'b0;
        line_buffer <= 512'h0;
    end else begin
        case (state)
            STATE_IDLE: begin
                l1i_req_ready_o  <= 1'b1;
                l1d_req_ready_o  <= 1'b1;
                l1i_resp_valid_o <= 1'b0;
                l1d_resp_valid_o <= 1'b0;
            end
            
            STATE_TAG_CHECK: begin
                l1i_req_ready_o <= 1'b0;
                l1d_req_ready_o <= 1'b0;
                req_was_l1i <= req_is_l1i;
            end
            
            STATE_WRITE_HIT: begin
                // Mark line as dirty
                dirty_array[hit_way][req_index] <= 1'b1;
                
                // Update LRU
                lru_bits[req_index] <= {lru_bits[req_index][5:0], ~hit_way[0]};
            end
            
            STATE_WRITEBACK: begin
                // Send dirty line to memory
                mem_req_valid_o <= 1'b1;
                mem_req_addr_o  <= {tag_array[victim_way][req_index], req_index, 6'h0};
                mem_req_we_o    <= 1'b1;
                mem_req_data_o  <= {sram_dout[victim_way][7], sram_dout[victim_way][6],
                                    sram_dout[victim_way][5], sram_dout[victim_way][4],
                                    sram_dout[victim_way][3], sram_dout[victim_way][2],
                                    sram_dout[victim_way][1], sram_dout[victim_way][0]};
            end
            
            STATE_ALLOCATE: begin
                mem_req_valid_o  <= 1'b1;
                mem_req_addr_o   <= {req_addr[31:6], 6'h0};
                mem_req_we_o     <= 1'b0;
                mem_resp_ready_o <= 1'b1;
            end
            
            STATE_REFILL: begin
                mem_req_valid_o  <= 1'b0;
                mem_resp_ready_o <= 1'b0;
                
                // Update tag array
                tag_array[victim_way][req_index]   <= req_tag;
                valid_array[victim_way][req_index] <= 1'b1;
                dirty_array[victim_way][req_index] <= 1'b0;
                
                // Update LRU
                lru_bits[req_index] <= {lru_bits[req_index][5:0], ~victim_way[0]};
                
                // Buffer the line
                line_buffer <= mem_resp_data_i;
            end
            
            STATE_RESPOND: begin
                if (req_was_l1i) begin
                    l1i_resp_valid_o <= 1'b1;
                    if (hit)
                        l1i_resp_data_o <= {sram_dout[hit_way][7], sram_dout[hit_way][6],
                                           sram_dout[hit_way][5], sram_dout[hit_way][4],
                                           sram_dout[hit_way][3], sram_dout[hit_way][2],
                                           sram_dout[hit_way][1], sram_dout[hit_way][0]};
                    else
                        l1i_resp_data_o <= line_buffer;
                    l1i_resp_error_o <= mem_resp_error_i;
                    
                    // Update LRU on hit
                    if (hit)
                        lru_bits[req_index] <= {lru_bits[req_index][5:0], ~hit_way[0]};
                end else begin
                    l1d_resp_valid_o <= 1'b1;
                    if (hit)
                        l1d_resp_data_o <= {sram_dout[hit_way][7], sram_dout[hit_way][6],
                                           sram_dout[hit_way][5], sram_dout[hit_way][4],
                                           sram_dout[hit_way][3], sram_dout[hit_way][2],
                                           sram_dout[hit_way][1], sram_dout[hit_way][0]};
                    else
                        l1d_resp_data_o <= line_buffer;
                    l1d_resp_error_o <= mem_resp_error_i;
                    
                    // Update LRU on hit
                    if (hit)
                        lru_bits[req_index] <= {lru_bits[req_index][5:0], ~hit_way[0]};
                end
                
                if (l1i_resp_ready_i)
                    l1i_resp_valid_o <= 1'b0;
                if (l1d_resp_ready_i)
                    l1d_resp_valid_o <= 1'b0;
            end
        endcase
    end
end

// Initialize arrays
integer j, k;
initial begin
    for (j = 0; j < WAYS; j = j + 1) begin
        for (k = 0; k < SETS; k = k + 1) begin
            tag_array[j][k] = {TAG_WIDTH{1'b0}};
            valid_array[j][k] = 1'b0;
            dirty_array[j][k] = 1'b0;
        end
    end
    for (k = 0; k < SETS; k = k + 1) begin
        lru_bits[k] = 7'h00;
    end
end

endmodule
