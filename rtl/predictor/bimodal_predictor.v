// ============================================================================
// Bimodal Branch Predictor - Clownfish RISC-V Processor
// ============================================================================
// 2K-entry bimodal predictor (local history)
// Simple PC-indexed pattern history table with 2-bit saturating counters
// ============================================================================

`include "../../include/clownfish_config.vh"

module bimodal_predictor (
    input  wire         clk,
    input  wire         rst_n,
    
    // Prediction request
    input  wire         predict_valid_i,
    input  wire [31:0]  predict_pc_i,
    output reg          predict_taken_o,
    output reg  [1:0]   predict_confidence_o,  // 2-bit saturating counter
    
    // Update interface (from branch resolution)
    input  wire         update_valid_i,
    input  wire [31:0]  update_pc_i,
    input  wire         update_taken_i
);

// Bimodal parameters
localparam BIMODAL_SIZE = `BIMODAL_SIZE;  // 2048 entries
localparam BIMODAL_INDEX_BITS = 11;        // log2(2048)

// Pattern History Table (PHT) - 2-bit saturating counters
reg [1:0] pht [0:BIMODAL_SIZE-1];

// Generate index from PC
function [BIMODAL_INDEX_BITS-1:0] bimodal_index;
    input [31:0] pc;
    begin
        // Use lower PC bits (skip 2 LSBs for alignment)
        bimodal_index = pc[BIMODAL_INDEX_BITS+1:2];
    end
endfunction

wire [BIMODAL_INDEX_BITS-1:0] predict_idx_w = bimodal_index(predict_pc_i);
wire [BIMODAL_INDEX_BITS-1:0] update_idx_w  = bimodal_index(update_pc_i);

// Prediction logic
always @(*) begin
    predict_taken_o = 1'b0;
    predict_confidence_o = 2'b00;

    if (predict_valid_i) begin
        predict_confidence_o = pht[predict_idx_w];
        predict_taken_o = pht[predict_idx_w][1];  // Taken if counter >= 2 (MSB = 1)
    end
end

// Update logic (train predictor)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Initialization in initial block
    end else begin
        if (update_valid_i) begin
            // Update 2-bit saturating counter
            if (update_taken_i) begin
                // Branch was taken - increment counter (saturate at 3)
                if (pht[update_idx_w] < 2'b11)
                    pht[update_idx_w] <= pht[update_idx_w] + 1;
            end else begin
                // Branch was not taken - decrement counter (saturate at 0)
                if (pht[update_idx_w] > 2'b00)
                    pht[update_idx_w] <= pht[update_idx_w] - 1;
            end
        end
    end
end

// Initialize PHT to weakly not-taken (2'b01)
integer i;
initial begin
    for (i = 0; i < BIMODAL_SIZE; i = i + 1) begin
        pht[i] = 2'b01;  // Weakly not-taken
    end
end

endmodule
