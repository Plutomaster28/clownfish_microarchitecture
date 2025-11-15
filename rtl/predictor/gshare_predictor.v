// ============================================================================
// GShare Branch Predictor - Clownfish RISC-V Processor
// ============================================================================
// 2K-entry GShare predictor with global history
// Uses XOR of PC and global history to index into pattern history table
// ============================================================================

`include "../../include/clownfish_config.vh"

module gshare_predictor (
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
    input  wire         update_taken_i,
    input  wire [10:0]  update_history_i,       // Global history at prediction time
    
    // Global history register (shared, read-only for prediction)
    input  wire [10:0]  global_history_i
);

// GShare parameters
localparam GSHARE_SIZE = `GSHARE_SIZE;  // 2048 entries
localparam GSHARE_INDEX_BITS = 11;      // log2(2048)

// Pattern History Table (PHT) - 2-bit saturating counters
reg [1:0] pht [0:GSHARE_SIZE-1];

// Generate index by XORing PC with global history
function [GSHARE_INDEX_BITS-1:0] gshare_index;
    input [31:0] pc;
    input [GSHARE_INDEX_BITS-1:0] history;
    begin
        // XOR lower PC bits with history
        gshare_index = pc[GSHARE_INDEX_BITS+1:2] ^ history;
    end
endfunction

wire [GSHARE_INDEX_BITS-1:0] predict_idx_w = gshare_index(predict_pc_i, global_history_i);
wire [GSHARE_INDEX_BITS-1:0] update_idx_w  = gshare_index(update_pc_i, update_history_i);

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
    for (i = 0; i < GSHARE_SIZE; i = i + 1) begin
        pht[i] = 2'b01;  // Weakly not-taken
    end
end

endmodule
