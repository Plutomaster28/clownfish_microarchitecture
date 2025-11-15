// ============================================================================
// Branch Target Buffer (BTB) - Clownfish RISC-V Processor
// ============================================================================
// 2K-entry BTB for storing branch target addresses
// Direct-mapped cache indexed by PC
// ============================================================================

`include "../../include/clownfish_config.vh"

module btb (
    input  wire         clk,
    input  wire         rst_n,
    
    // Lookup interface
    input  wire         lookup_valid_i,
    input  wire [31:0]  lookup_pc_i,
    output reg          lookup_hit_o,
    output reg  [31:0]  lookup_target_o,
    output reg          lookup_is_call_o,    // For RAS management
    output reg          lookup_is_return_o,  // For RAS management
    
    // Update interface (from branch resolution)
    input  wire         update_valid_i,
    input  wire [31:0]  update_pc_i,
    input  wire [31:0]  update_target_i,
    input  wire         update_is_branch_i,
    input  wire         update_is_call_i,
    input  wire         update_is_return_i
);

// BTB parameters
localparam BTB_ENTRIES = `BTB_ENTRIES;  // 2048 entries
localparam BTB_INDEX_BITS = 11;          // log2(2048)
localparam BTB_TAG_BITS = 19;            // 32 - 11 - 2 (alignment)

// BTB entry structure
reg                      btb_valid    [0:BTB_ENTRIES-1];
reg [BTB_TAG_BITS-1:0]   btb_tag      [0:BTB_ENTRIES-1];
reg [31:0]               btb_target   [0:BTB_ENTRIES-1];
reg                      btb_is_call  [0:BTB_ENTRIES-1];
reg                      btb_is_return[0:BTB_ENTRIES-1];

// Generate index and tag from PC
function [BTB_INDEX_BITS-1:0] btb_index;
    input [31:0] pc;
    begin
        btb_index = pc[BTB_INDEX_BITS+1:2];
    end
endfunction

function [BTB_TAG_BITS-1:0] btb_tag_extract;
    input [31:0] pc;
    begin
        btb_tag_extract = pc[31:BTB_INDEX_BITS+2];
    end
endfunction

wire [BTB_INDEX_BITS-1:0] lookup_idx_w = btb_index(lookup_pc_i);
wire [BTB_TAG_BITS-1:0]   lookup_tag_w = btb_tag_extract(lookup_pc_i);
wire [BTB_INDEX_BITS-1:0] update_idx_w = btb_index(update_pc_i);
wire [BTB_TAG_BITS-1:0]   update_tag_w = btb_tag_extract(update_pc_i);

// Lookup logic (combinational)
always @(*) begin
    lookup_hit_o       = 1'b0;
    lookup_target_o    = 32'h0;
    lookup_is_call_o   = 1'b0;
    lookup_is_return_o = 1'b0;

    if (lookup_valid_i) begin
        // Check for hit (valid + tag match)
        if (btb_valid[lookup_idx_w] && btb_tag[lookup_idx_w] == lookup_tag_w) begin
            lookup_hit_o      = 1'b1;
            lookup_target_o   = btb_target[lookup_idx_w];
            lookup_is_call_o  = btb_is_call[lookup_idx_w];
            lookup_is_return_o = btb_is_return[lookup_idx_w];
        end
    end
end

// Update logic (allocate/update BTB entry)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Initialization in initial block
    end else begin
        if (update_valid_i && update_is_branch_i) begin
            // Update/allocate BTB entry
            btb_valid[update_idx_w]     <= 1'b1;
            btb_tag[update_idx_w]       <= update_tag_w;
            btb_target[update_idx_w]    <= update_target_i;
            btb_is_call[update_idx_w]   <= update_is_call_i;
            btb_is_return[update_idx_w] <= update_is_return_i;
        end
    end
end

// Initialize BTB to invalid
integer i;
initial begin
    for (i = 0; i < BTB_ENTRIES; i = i + 1) begin
        btb_valid[i]     = 1'b0;
        btb_tag[i]       = {BTB_TAG_BITS{1'b0}};
        btb_target[i]    = 32'h0;
        btb_is_call[i]   = 1'b0;
        btb_is_return[i] = 1'b0;
    end
end

endmodule
