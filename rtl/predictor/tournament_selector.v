// ============================================================================
// Tournament Selector - Clownfish RISC-V Processor
// ============================================================================
// Meta-predictor that chooses between GShare and Bimodal predictors
// Uses 2-bit counters to track which predictor is more accurate
// ============================================================================

`include "../../include/clownfish_config.vh"

module tournament_selector (
    input  wire         clk,
    input  wire         rst_n,
    
    // Prediction inputs from both predictors
    input  wire         predict_valid_i,
    input  wire [31:0]  predict_pc_i,
    input  wire         gshare_predict_i,
    input  wire [1:0]   gshare_confidence_i,
    input  wire         bimodal_predict_i,
    input  wire [1:0]   bimodal_confidence_i,
    
    // Selected prediction output
    output reg          predict_taken_o,
    output reg          select_gshare_o,     // Which predictor was selected
    
    // Update interface (from branch resolution)
    input  wire         update_valid_i,
    input  wire [31:0]  update_pc_i,
    input  wire         update_taken_i,
    input  wire         update_gshare_correct_i,
    input  wire         update_bimodal_correct_i
);

// Tournament parameters
localparam SELECTOR_SIZE = `SELECTOR_SIZE;  // 2048 entries
localparam SELECTOR_INDEX_BITS = 11;         // log2(2048)

// Selector table - 2-bit saturating counters
// 00, 01: prefer Bimodal
// 10, 11: prefer GShare
reg [1:0] selector [0:SELECTOR_SIZE-1];

// Generate index from PC
function [SELECTOR_INDEX_BITS-1:0] selector_index;
    input [31:0] pc;
    begin
        selector_index = pc[SELECTOR_INDEX_BITS+1:2];
    end
endfunction

wire [SELECTOR_INDEX_BITS-1:0] predict_idx_w = selector_index(predict_pc_i);
wire [SELECTOR_INDEX_BITS-1:0] update_idx_w  = selector_index(update_pc_i);

// Selection logic
always @(*) begin
    select_gshare_o = 1'b0;
    predict_taken_o = 1'b0;

    if (predict_valid_i) begin
        if (selector[predict_idx_w][1]) begin
            // Prefer GShare (counter >= 2)
            select_gshare_o = 1'b1;
            predict_taken_o = gshare_predict_i;
        end else begin
            // Prefer Bimodal (counter < 2)
            select_gshare_o = 1'b0;
            predict_taken_o = bimodal_predict_i;
        end
    end
end

// Update logic (train selector based on which predictor was correct)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Initialization in initial block
    end else begin
        if (update_valid_i) begin
            // Update selector based on which predictor was correct
            case ({update_gshare_correct_i, update_bimodal_correct_i})
                2'b10: begin
                    // Only GShare was correct - increment towards GShare
                    if (selector[update_idx_w] < 2'b11)
                        selector[update_idx_w] <= selector[update_idx_w] + 1;
                end
                
                2'b01: begin
                    // Only Bimodal was correct - decrement towards Bimodal
                    if (selector[update_idx_w] > 2'b00)
                        selector[update_idx_w] <= selector[update_idx_w] - 1;
                end
                
                2'b00, 2'b11: begin
                    // Both wrong or both correct - no update
                    // (no change in selector preference)
                end
            endcase
        end
    end
end

// Initialize selector to neutral (2'b01 - slightly prefer Bimodal)
integer i;
initial begin
    for (i = 0; i < SELECTOR_SIZE; i = i + 1) begin
        selector[i] = 2'b01;  // Slightly prefer Bimodal initially
    end
end

endmodule
