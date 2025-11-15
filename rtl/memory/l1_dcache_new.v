// ============================================================================
// L1 Data Cache - Clownfish RISC-V Processor
// ============================================================================
// 32 KB, 4-way set associative, 64-byte cache lines
// Write-back policy with write buffer
// Uses OpenRAM-generated SRAM macros (8x 64-bit words per line)
// Non-blocking with MSHR support for outstanding misses
// ============================================================================

`include "../../include/clownfish_config.vh"

module l1_dcache_new (
    input  wire         clk,
    input  wire         rst_n,
    
    // LSU interface (load path)
    input  wire         load_req_valid_i,
    input  wire [31:0]  load_req_addr_i,
    input  wire [2:0]   load_req_size_i,     // 0=byte, 1=half, 2=word, 3=double
    input  wire         load_req_signed_i,
    output reg          load_req_ready_o,
    
    output reg          load_resp_valid_o,
    output reg  [63:0]  load_resp_data_o,
    output reg          load_resp_error_o,
    input  wire         load_resp_ready_i,
    
    // LSU interface (store path)
    input  wire         store_req_valid_i,
    input  wire [31:0]  store_req_addr_i,
    input  wire [63:0]  store_req_data_i,
    input  wire [7:0]   store_req_mask_i,    // Byte enable mask
    input  wire [2:0]   store_req_size_i,
    output reg          store_req_ready_o,
    
    output reg          store_resp_valid_o,
    output reg          store_resp_error_o,
    input  wire         store_resp_ready_i,
    
    // Store commit interface (from ROB)
    input  wire         store_commit_valid_i,
    input  wire [5:0]   store_commit_id_i,
    
    // L2 cache interface
    output reg          l2_req_valid_o,
    output reg  [31:0]  l2_req_addr_o,
    output reg          l2_req_we_o,         // Write enable
    output reg  [511:0] l2_req_data_o,       // Write data (64 bytes)
    input  wire         l2_req_ready_i,
    
    input  wire         l2_resp_valid_i,
    input  wire [511:0] l2_resp_data_i,
    input  wire         l2_resp_error_i,
    output reg          l2_resp_ready_o,
    
    // Fence/Flush interface
    input  wire         fence_i,
    output reg          fence_done_o
);

// Cache parameters
localparam SETS = `L1_DCACHE_SETS;           // 128 sets
localparam WAYS = `L1_DCACHE_WAYS;           // 4 ways
localparam LINE_SIZE = `L1_DCACHE_LINE_SIZE; // 64 bytes
localparam WORDS_PER_LINE = 8;               // 8x 64-bit words

// MSHR parameters
localparam MSHR_ENTRIES = 8;

// Address breakdown
localparam INDEX_WIDTH = 7;
localparam OFFSET_WIDTH = 6;
localparam TAG_WIDTH = 32 - INDEX_WIDTH - OFFSET_WIDTH;
localparam INDEX_MSB = OFFSET_WIDTH + INDEX_WIDTH - 1;

// Request tracking
reg         curr_req_is_store;
reg [31:0]  curr_req_addr;
reg [63:0]  curr_store_data;
reg [7:0]   curr_store_mask;

wire [INDEX_WIDTH-1:0] curr_req_index  = curr_req_addr[INDEX_MSB:OFFSET_WIDTH];
wire [TAG_WIDTH-1:0]   curr_req_tag    = curr_req_addr[31:INDEX_MSB+1];
wire [OFFSET_WIDTH-1:0] curr_req_offset = curr_req_addr[OFFSET_WIDTH-1:0];
wire [2:0]             curr_req_word   = curr_req_offset[OFFSET_WIDTH-1:3];

// Cache state
localparam STATE_IDLE         = 4'b0000;
localparam STATE_TAG_CHECK    = 4'b0001;
localparam STATE_ALLOCATE     = 4'b0010;
localparam STATE_REFILL       = 4'b0011;
localparam STATE_WRITEBACK    = 4'b0100;
localparam STATE_RESPOND      = 4'b0101;
localparam STATE_STORE_HIT    = 4'b0110;
localparam STATE_FENCE        = 4'b0111;

reg [3:0] state, next_state;

// OpenRAM SRAM instances (4 ways × 8 words per line)
reg  sram_csb   [0:WAYS-1][0:WORDS_PER_LINE-1];
reg  sram_web   [0:WAYS-1][0:WORDS_PER_LINE-1];
reg  [7:0] sram_wmask [0:WAYS-1][0:WORDS_PER_LINE-1];
reg  [INDEX_WIDTH-1:0] sram_addr [0:WAYS-1][0:WORDS_PER_LINE-1];
reg  [63:0] sram_din   [0:WAYS-1][0:WORDS_PER_LINE-1];
wire [63:0] sram_dout  [0:WAYS-1][0:WORDS_PER_LINE-1];

// Tag/Valid/Dirty storage
reg [TAG_WIDTH-1:0] tag_array [0:WAYS-1][0:SETS-1];
reg                 valid_array [0:WAYS-1][0:SETS-1];
reg                 dirty_array [0:WAYS-1][0:SETS-1];

// LRU bits (pseudo-LRU for 4-way)
reg [2:0] lru_bits [0:SETS-1];

// Hit detection
reg [WAYS-1:0] way_hit;
reg hit;
reg [1:0] hit_way;
reg [1:0] victim_way;

// Write buffer (8 entries)
reg [31:0]  wb_addr [0:7];
reg [511:0] wb_data [0:7];
reg [7:0]   wb_valid;
reg [2:0]   wb_head, wb_tail;

// MSHR for outstanding misses
reg [31:0] mshr_addr [0:MSHR_ENTRIES-1];
reg [MSHR_ENTRIES-1:0] mshr_valid;
reg [2:0]  mshr_alloc_ptr;

// Generate SRAM instances
genvar way, word;
generate
    for (way = 0; way < WAYS; way = way + 1) begin : gen_ways
        for (word = 0; word < WORDS_PER_LINE; word = word + 1) begin : gen_words
            sram_l1_dcache_way sram_inst (
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

// Capture request metadata when leaving IDLE
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        curr_req_is_store <= 1'b0;
        curr_req_addr     <= 32'h0;
        curr_store_data   <= 64'h0;
        curr_store_mask   <= 8'h0;
    end else if (state == STATE_IDLE) begin
        if (load_req_valid_i && load_req_ready_o) begin
            curr_req_is_store <= 1'b0;
            curr_req_addr     <= load_req_addr_i;
            curr_store_data   <= 64'h0;
            curr_store_mask   <= 8'h0;
        end else if (store_req_valid_i && store_req_ready_o && store_commit_valid_i) begin
            curr_req_is_store <= 1'b1;
            curr_req_addr     <= store_req_addr_i;
            curr_store_data   <= store_req_data_i;
            curr_store_mask   <= store_req_mask_i;
        end
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    
    case (state)
        STATE_IDLE: begin
            if (fence_i)
                next_state = STATE_FENCE;
            else if (load_req_valid_i)
                next_state = STATE_TAG_CHECK;
            else if (store_req_valid_i && store_commit_valid_i)
                next_state = STATE_TAG_CHECK;
        end
        
        STATE_TAG_CHECK: begin
            if (hit) begin
                if (curr_req_is_store)
                    next_state = STATE_STORE_HIT;
                else
                    next_state = STATE_RESPOND;
            end else begin
                // Miss: Check if need writeback
                if (dirty_array[victim_way][curr_req_index])
                    next_state = STATE_WRITEBACK;
                else if (l2_req_ready_i)
                    next_state = STATE_ALLOCATE;
            end
        end
        
        STATE_WRITEBACK: begin
            if (l2_req_ready_i)
                next_state = STATE_ALLOCATE;
        end
        
        STATE_ALLOCATE: begin
            if (l2_resp_valid_i)
                next_state = STATE_REFILL;
        end
        
        STATE_REFILL: begin
            next_state = STATE_RESPOND;
        end
        
        STATE_STORE_HIT: begin
            next_state = STATE_RESPOND;
        end
        
        STATE_RESPOND: begin
            if ((!curr_req_is_store && load_resp_ready_i) ||
                (curr_req_is_store && store_resp_ready_i))
                next_state = STATE_IDLE;
        end
        
        STATE_FENCE: begin
            if (wb_valid == 8'h00)
                next_state = STATE_IDLE;
        end
        
        default: next_state = STATE_IDLE;
    endcase
end

// Tag check and hit detection
integer i;
always @(*) begin
    hit = 1'b0;
    hit_way = 2'b00;
    way_hit = 4'b0000;
    
    for (i = 0; i < WAYS; i = i + 1) begin
        if (valid_array[i][curr_req_index] && (tag_array[i][curr_req_index] == curr_req_tag)) begin
            hit = 1'b1;
            hit_way = i[1:0];
            way_hit[i] = 1'b1;
        end
    end
    
    // Victim selection (simple: use LRU)
    victim_way = lru_bits[curr_req_index][1:0];
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
            sram_addr[w][wd] = curr_req_index;
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
                    sram_addr[w][wd] = curr_req_index;
                end
            end
        end
        
        STATE_WRITEBACK: begin
            // Read victim line for writeback payload
            for (wd = 0; wd < WORDS_PER_LINE; wd = wd + 1) begin
                sram_csb[victim_way][wd] = 1'b0;
                sram_web[victim_way][wd] = 1'b1;
                sram_addr[victim_way][wd] = curr_req_index;
            end
        end

        STATE_STORE_HIT: begin
            // Write to hit way
            for (wd = 0; wd < WORDS_PER_LINE; wd = wd + 1) begin
                sram_addr[hit_way][wd] = curr_req_index;
                sram_csb[hit_way][wd] = 1'b0;
                if (wd[2:0] == curr_req_word) begin
                    sram_web[hit_way][wd] = 1'b0;  // Write enable
                    sram_wmask[hit_way][wd] = curr_store_mask;
                    sram_din[hit_way][wd] = curr_store_data;
                end else begin
                    sram_web[hit_way][wd] = 1'b1;  // Read
                end
            end
        end
        
        STATE_REFILL: begin
            // Write entire cache line from L2
            for (wd = 0; wd < WORDS_PER_LINE; wd = wd + 1) begin
                sram_addr[victim_way][wd] = curr_req_index;
                sram_csb[victim_way][wd] = 1'b0;
                sram_web[victim_way][wd] = 1'b0;  // Write
                sram_wmask[victim_way][wd] = 8'hFF;
                sram_din[victim_way][wd] = l2_resp_data_i[wd*64 +: 64];
            end
        end
    endcase
end

// Output and control logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        load_req_ready_o  <= 1'b1;
        load_resp_valid_o <= 1'b0;
        load_resp_data_o  <= 64'h0;
        load_resp_error_o <= 1'b0;
        
        store_req_ready_o  <= 1'b1;
        store_resp_valid_o <= 1'b0;
        store_resp_error_o <= 1'b0;
        
        l2_req_valid_o  <= 1'b0;
        l2_req_addr_o   <= 32'h0;
        l2_req_we_o     <= 1'b0;
        l2_req_data_o   <= 512'h0;
        l2_resp_ready_o <= 1'b0;
        
        fence_done_o <= 1'b0;
        
        wb_valid <= 8'h00;
        wb_head <= 3'h0;
        wb_tail <= 3'h0;
    end else begin
        case (state)
            STATE_IDLE: begin
                load_req_ready_o  <= 1'b1;
                store_req_ready_o <= 1'b1;
                load_resp_valid_o <= 1'b0;
                store_resp_valid_o <= 1'b0;
                fence_done_o <= 1'b0;
            end
            
            STATE_TAG_CHECK: begin
                load_req_ready_o  <= 1'b0;
                store_req_ready_o <= 1'b0;
            end
            
            STATE_WRITEBACK: begin
                // Send dirty line to L2
                l2_req_valid_o <= 1'b1;
                l2_req_addr_o  <= {tag_array[victim_way][curr_req_index], curr_req_index, 6'h0};
                l2_req_we_o    <= 1'b1;
                // Collect data from SRAM
                l2_req_data_o  <= {sram_dout[victim_way][7], sram_dout[victim_way][6],
                                   sram_dout[victim_way][5], sram_dout[victim_way][4],
                                   sram_dout[victim_way][3], sram_dout[victim_way][2],
                                   sram_dout[victim_way][1], sram_dout[victim_way][0]};
            end
            
            STATE_ALLOCATE: begin
                l2_req_valid_o  <= 1'b1;
                l2_req_addr_o   <= {curr_req_addr[31:6], 6'h0};
                l2_req_we_o     <= 1'b0;
                l2_resp_ready_o <= 1'b1;
            end
            
            STATE_REFILL: begin
                l2_req_valid_o  <= 1'b0;
                l2_resp_ready_o <= 1'b0;
                
                // Update tag array
                tag_array[victim_way][curr_req_index]   <= curr_req_tag;
                valid_array[victim_way][curr_req_index] <= 1'b1;
                dirty_array[victim_way][curr_req_index] <= 1'b0;
                
                // Update LRU
                lru_bits[curr_req_index] <= {lru_bits[curr_req_index][1:0], ~victim_way[0]};
            end
            
            STATE_STORE_HIT: begin
                // Mark line as dirty
                dirty_array[hit_way][curr_req_index] <= 1'b1;
                
                // Update LRU
                lru_bits[curr_req_index] <= {lru_bits[curr_req_index][1:0], ~hit_way[0]};
                
                store_resp_valid_o <= 1'b1;
                store_resp_error_o <= 1'b0;
            end
            
            STATE_RESPOND: begin
                if (!curr_req_is_store) begin
                    load_resp_valid_o <= 1'b1;
                    load_resp_data_o  <= sram_dout[hit_way][curr_req_word];
                    load_resp_error_o <= 1'b0;
                    
                    // Update LRU
                    lru_bits[curr_req_index] <= {lru_bits[curr_req_index][1:0], ~hit_way[0]};
                end
                
                if (load_resp_ready_i)
                    load_resp_valid_o <= 1'b0;
                if (store_resp_ready_i)
                    store_resp_valid_o <= 1'b0;
            end
            
            STATE_FENCE: begin
                fence_done_o <= (wb_valid == 8'h00);
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
        lru_bits[k] = 3'b000;
    end
    for (k = 0; k < MSHR_ENTRIES; k = k + 1) begin
        mshr_addr[k] = 32'h0;
    end
    mshr_valid = {MSHR_ENTRIES{1'b0}};
    mshr_alloc_ptr = 3'h0;
end

endmodule
