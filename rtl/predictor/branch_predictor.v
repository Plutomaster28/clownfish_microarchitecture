// ============================================================================
// Branch Predictor Top - Clownfish RISC-V Processor
// ============================================================================
// Integrates tournament predictor (GShare + Bimodal + Selector), BTB, and RAS
// Manages global history register for speculative prediction
// Provides unified prediction interface to frontend
// ============================================================================

`include "../../include/clownfish_config.vh"

module branch_predictor (
    input  wire         clk,
    input  wire         rst_n,
    
    // Prediction interface (from fetch stage)
    input  wire         pred_valid_i,
    input  wire [31:0]  pred_pc_i,
    output wire         pred_taken_o,        // Direction prediction
    output wire [31:0]  pred_target_o,       // Target address (if taken)
    output wire         pred_target_valid_o, // BTB hit or RAS valid
    output wire [10:0]  pred_history_o,      // Global history snapshot
    output wire [4:0]   pred_ras_tos_o,      // RAS TOS snapshot (for recovery)
    
    // Update interface (from branch resolution in execute stage)
    input  wire         update_valid_i,
    input  wire [31:0]  update_pc_i,
    input  wire         update_taken_i,      // Actual direction
    input  wire [31:0]  update_target_i,     // Actual target
    input  wire         update_is_branch_i,  // Is branch instruction
    input  wire         update_is_call_i,    // Is function call (JAL/JALR with rd=x1/x5)
    input  wire         update_is_return_i,  // Is function return (JALR with rs1=x1/x5)
    input  wire [10:0]  update_history_i,    // History at prediction time
    
    // Misprediction recovery
    input  wire         mispredict_i,
    input  wire [10:0]  recover_history_i,   // Correct history to restore
    input  wire [4:0]   recover_ras_tos_i    // Correct RAS TOS to restore
);

// ============================================================================
// Global History Register (11 bits)
// ============================================================================
reg [10:0] global_history;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        global_history <= 11'h0;
    end else if (mispredict_i) begin
        // Restore correct history on misprediction
        global_history <= recover_history_i;
    end else if (update_valid_i && update_is_branch_i) begin
        // Update history with resolved branch
        global_history <= {global_history[9:0], update_taken_i};
    end
end

// ============================================================================
// Tournament Predictor (GShare + Bimodal + Selector)
// ============================================================================
wire        gshare_pred;
wire [1:0]  gshare_conf;
wire        bimodal_pred;
wire [1:0]  bimodal_conf;
wire        tournament_pred;
wire        selector_prefers_gshare;

gshare_predictor gshare_inst (
    .clk            (clk),
    .rst_n          (rst_n),
    .predict_valid_i   (pred_valid_i),
    .predict_pc_i      (pred_pc_i),
    .global_history_i  (global_history),
    .predict_taken_o   (gshare_pred),
    .predict_confidence_o(gshare_conf),
    .update_valid_i (update_valid_i && update_is_branch_i),
    .update_pc_i    (update_pc_i),
    .update_history_i(update_history_i),
    .update_taken_i (update_taken_i)
);

bimodal_predictor bimodal_inst (
    .clk            (clk),
    .rst_n          (rst_n),
    .predict_valid_i   (pred_valid_i),
    .predict_pc_i      (pred_pc_i),
    .predict_taken_o   (bimodal_pred),
    .predict_confidence_o(bimodal_conf),
    .update_valid_i (update_valid_i && update_is_branch_i),
    .update_pc_i    (update_pc_i),
    .update_taken_i (update_taken_i)
);

tournament_selector selector_inst (
    .clk              (clk),
    .rst_n            (rst_n),
    .predict_valid_i       (pred_valid_i),
    .predict_pc_i          (pred_pc_i),
    .gshare_predict_i      (gshare_pred),
    .gshare_confidence_i   (gshare_conf),
    .bimodal_predict_i     (bimodal_pred),
    .bimodal_confidence_i  (bimodal_conf),
    .predict_taken_o       (tournament_pred),
    .select_gshare_o       (selector_prefers_gshare),
    .update_valid_i   (update_valid_i && update_is_branch_i),
    .update_pc_i      (update_pc_i),
    .update_taken_i   (update_taken_i),
    .update_gshare_correct_i (gshare_pred == update_taken_i),
    .update_bimodal_correct_i(bimodal_pred == update_taken_i)
);

// ============================================================================
// Branch Target Buffer (BTB)
// ============================================================================
wire        btb_hit;
wire [31:0] btb_target;
wire        btb_is_call;
wire        btb_is_return;

btb btb_inst (
    .clk               (clk),
    .rst_n             (rst_n),
    .lookup_valid_i    (pred_valid_i),
    .lookup_pc_i       (pred_pc_i),
    .lookup_hit_o      (btb_hit),
    .lookup_target_o   (btb_target),
    .lookup_is_call_o  (btb_is_call),
    .lookup_is_return_o(btb_is_return),
    .update_valid_i    (update_valid_i),
    .update_pc_i       (update_pc_i),
    .update_target_i   (update_target_i),
    .update_is_branch_i(update_is_branch_i),
    .update_is_call_i  (update_is_call_i),
    .update_is_return_i(update_is_return_i)
);

// ============================================================================
// Return Address Stack (RAS)
// ============================================================================
wire [31:0] ras_target;
wire        ras_valid;
wire [4:0]  ras_tos;
reg  [4:0]  ras_tos_snapshot;  // Snapshot of TOS for recovery

// Capture RAS TOS for snapshot (before any push/pop)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ras_tos_snapshot <= 5'h0;
    end else if (pred_valid_i) begin
        // Capture current TOS before speculation
    ras_tos_snapshot <= ras_tos;
    end
end

ras ras_inst (
    .clk              (clk),
    .rst_n            (rst_n),
    .push_valid_i     (pred_valid_i && btb_is_call),      // Push on predicted call
    .push_addr_i      (pred_pc_i + 32'd4),                // Return address
    .pop_valid_i      (pred_valid_i && btb_is_return),    // Pop on predicted return
    .pop_addr_o       (ras_target),
    .pop_valid_o      (ras_valid),
    .recover_valid_i  (mispredict_i),
    .recover_tos_i    (recover_ras_tos_i),
    .tos_o            (ras_tos)
);

// ============================================================================
// Prediction Output Logic
// ============================================================================
// Direction: Use tournament predictor
assign pred_taken_o = tournament_pred;

// Target: Use RAS if return, else BTB
assign pred_target_o = btb_is_return ? ras_target : btb_target;

// Target valid: BTB hit or RAS valid (for returns)
assign pred_target_valid_o = btb_hit && (btb_is_return ? ras_valid : 1'b1);

// Provide global history snapshot for recovery
assign pred_history_o = global_history;

// Provide RAS TOS snapshot for recovery
assign pred_ras_tos_o = ras_tos_snapshot;

endmodule
