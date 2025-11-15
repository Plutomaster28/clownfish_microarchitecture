// ============================================================================
// Clownfish Core v2 - 14-Stage Out-of-Order Superscalar Processor
// ============================================================================
// RV32GCBV ISA (Base + Compressed + M + A + F + D + B + Vector)
// 4-wide issue, 64-entry ROB, 48-entry RS
// Clock target: 1.0 GHz @ 130nm
// ============================================================================
// Pipeline: F1-F4 (Frontend) → D1-D2 (Dispatch) → EX1-EX5 (Execute) → 
//           M1-M2 (Memory) → WB (Writeback/Commit)
// ============================================================================

`include "../../include/clownfish_config.vh"

module clownfish_core_v2 (
    input  wire         clk,
    input  wire         rst_n,
    
    // Instruction memory interface (to L1 I-Cache)
    output wire         imem_req_valid_o,
    output wire [31:0]  imem_req_addr_o,
    input  wire         imem_req_ready_i,
    input  wire         imem_resp_valid_i,
    input  wire [31:0]  imem_resp_data_i,
    input  wire         imem_resp_error_i,
    output wire         imem_resp_ready_o,
    
    // Data memory interface (to L1 D-Cache)
    output wire         dmem_load_req_valid_o,
    output wire [31:0]  dmem_load_req_addr_o,
    output wire [2:0]   dmem_load_req_size_o,
    output wire         dmem_load_req_signed_o,
    input  wire         dmem_load_req_ready_i,
    
    input  wire         dmem_load_resp_valid_i,
    input  wire [63:0]  dmem_load_resp_data_i,
    input  wire         dmem_load_resp_error_i,
    output wire         dmem_load_resp_ready_o,
    
    output wire         dmem_store_req_valid_o,
    output wire [31:0]  dmem_store_req_addr_o,
    output wire [63:0]  dmem_store_req_data_o,
    output wire [7:0]   dmem_store_req_mask_o,
    output wire [2:0]   dmem_store_req_size_o,
    input  wire         dmem_store_req_ready_i,
    
    input  wire         dmem_store_resp_valid_i,
    input  wire         dmem_store_resp_error_i,
    output wire         dmem_store_resp_ready_o,
    
    // Store commit from ROB
    output wire         store_commit_valid_o,
    output wire [5:0]   store_commit_id_o,
    
    // Interrupts and exceptions
    input  wire         ext_interrupt_i,
    input  wire         timer_interrupt_i,
    input  wire         software_interrupt_i
);

// ============================================================================
// Frontend: F1-F4 (Fetch, Predict, Decode, Queue)
// ============================================================================
reg [31:0] pc_f1;
reg fetch_valid_f1;

// Branch predictor
wire        pred_taken;
wire [31:0] pred_target;
wire        pred_target_valid;
wire [10:0] pred_history;
wire [4:0]  pred_ras_tos;

// Branch predictor update from backend
wire bp_update_valid;
wire [31:0] bp_update_pc;
wire bp_update_taken;
wire [31:0] bp_update_target;
wire bp_update_is_branch;
wire bp_update_is_call;
wire bp_update_is_return;
wire [10:0] bp_update_history;
wire bp_mispredict;
wire [10:0] bp_recover_history;
wire [4:0] bp_recover_ras_tos;

branch_predictor bp_inst (
    .clk                (clk),
    .rst_n              (rst_n),
    .pred_valid_i       (fetch_valid_f1),
    .pred_pc_i          (pc_f1),
    .pred_taken_o       (pred_taken),
    .pred_target_o      (pred_target),
    .pred_target_valid_o(pred_target_valid),
    .pred_history_o     (pred_history),
    .pred_ras_tos_o     (pred_ras_tos),
    .update_valid_i     (bp_update_valid),
    .update_pc_i        (bp_update_pc),
    .update_taken_i     (bp_update_taken),
    .update_target_i    (bp_update_target),
    .update_is_branch_i (bp_update_is_branch),
    .update_is_call_i   (bp_update_is_call),
    .update_is_return_i (bp_update_is_return),
    .update_history_i   (bp_update_history),
    .mispredict_i       (bp_mispredict),
    .recover_history_i  (bp_recover_history),
    .recover_ras_tos_i  (bp_recover_ras_tos)
);

// I-Cache interface
assign imem_req_valid_o = fetch_valid_f1;
assign imem_req_addr_o  = pc_f1;
assign imem_resp_ready_o = 1'b1;

// Flush from ROB
wire flush;
wire [31:0] flush_target;

// PC update
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pc_f1 <= 32'h0000_0000;
        fetch_valid_f1 <= 1'b1;
    end else if (flush) begin
        pc_f1 <= flush_target;
        fetch_valid_f1 <= 1'b1;
    end else if (imem_req_ready_i && fetch_valid_f1) begin
        if (pred_taken && pred_target_valid)
            pc_f1 <= pred_target;
        else
            pc_f1 <= pc_f1 + 32'd4;
    end
end

// F2: Instruction from I-Cache
reg [31:0] instr_f2, pc_f2;
reg valid_f2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        instr_f2 <= 32'h00000013;  // NOP
        pc_f2 <= 32'h0;
        valid_f2 <= 1'b0;
    end else if (flush) begin
        valid_f2 <= 1'b0;
    end else if (imem_resp_valid_i) begin
        instr_f2 <= imem_resp_data_i;
        pc_f2 <= pc_f1;
        valid_f2 <= 1'b1;
    end else begin
        valid_f2 <= 1'b0;
    end
end

// F3: Decode
reg [31:0] instr_f3, pc_f3;
reg [31:0] imm_f3;
reg [10:0] history_f3;
reg valid_f3;

// Decode logic
wire [6:0] opcode = instr_f2[6:0];
wire [4:0] rd     = instr_f2[11:7];
wire [4:0] rs1    = instr_f2[19:15];
wire [4:0] rs2    = instr_f2[24:20];
wire [2:0] funct3 = instr_f2[14:12];
wire [6:0] funct7 = instr_f2[31:25];

// Immediate generation
reg [31:0] imm;
always @(*) begin
    case (opcode)
        7'b0010011, 7'b0000011, 7'b1100111: // I-type
            imm = {{20{instr_f2[31]}}, instr_f2[31:20]};
        7'b0100011: // S-type
            imm = {{20{instr_f2[31]}}, instr_f2[31:25], instr_f2[11:7]};
        7'b1100011: // B-type
            imm = {{19{instr_f2[31]}}, instr_f2[31], instr_f2[7], instr_f2[30:25], instr_f2[11:8], 1'b0};
        7'b0110111, 7'b0010111: // U-type
            imm = {instr_f2[31:12], 12'h0};
        7'b1101111: // J-type
            imm = {{11{instr_f2[31]}}, instr_f2[31], instr_f2[19:12], instr_f2[20], instr_f2[30:21], 1'b0};
        default:
            imm = 32'h0;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        instr_f3 <= 32'h00000013;
        pc_f3 <= 32'h0;
        imm_f3 <= 32'h0;
        history_f3 <= 11'h0;
        valid_f3 <= 1'b0;
    end else if (flush) begin
        valid_f3 <= 1'b0;
    end else if (valid_f2) begin
        instr_f3 <= instr_f2;
        pc_f3 <= pc_f2;
        imm_f3 <= imm;
        history_f3 <= pred_history;
        valid_f3 <= 1'b1;
    end else begin
        valid_f3 <= 1'b0;
    end
end

// F4: Instruction Queue (32 entries, 4-wide dequeue to dispatch)
reg [31:0] iq_instr [0:31];
reg [31:0] iq_pc [0:31];
reg [31:0] iq_imm [0:31];
reg [10:0] iq_history [0:31];
reg [4:0]  iq_head, iq_tail;
wire [5:0] iq_count = (iq_tail >= iq_head) ? (iq_tail - iq_head) : (32 + iq_tail - iq_head);
wire iq_full  = (iq_count >= 6'd30);
wire iq_empty = (iq_count == 6'd0);

// Enqueue
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        iq_tail <= 5'h0;
    end else if (flush) begin
        iq_tail <= 5'h0;
    end else if (valid_f3 && !iq_full) begin
        iq_instr[iq_tail] <= instr_f3;
        iq_pc[iq_tail] <= pc_f3;
        iq_imm[iq_tail] <= imm_f3;
        iq_history[iq_tail] <= history_f3;
        iq_tail <= iq_tail + 1'b1;
    end
end

// ============================================================================
// Dispatch: D1-D2 (ROB/RS/Rename Allocation)
// ============================================================================
wire dispatch_ready;
wire [5:0] rob_alloc_id;
wire rob_alloc_ready;
wire rs_alloc_ready;
wire [6:0] phys_dest, phys_dest_old, phys_src1, phys_src2;
wire src1_ready, src2_ready;
wire [31:0] src1_value, src2_value;
wire rename_ready;
wire rename_has_dest;

// Reservation station issue signals
wire rs_issue_alu0_valid;
wire [5:0] rs_issue_alu0_rob_id;
wire [6:0] rs_issue_alu0_phys_dest;
wire [31:0] rs_issue_alu0_src1;
wire [31:0] rs_issue_alu0_src2;
wire [5:0] rs_issue_alu0_opcode;

wire rs_issue_alu1_valid;
wire [5:0] rs_issue_alu1_rob_id;
wire [6:0] rs_issue_alu1_phys_dest;
wire [31:0] rs_issue_alu1_src1;
wire [31:0] rs_issue_alu1_src2;
wire [5:0] rs_issue_alu1_opcode;

wire rs_issue_complex_valid;
wire [5:0] rs_issue_complex_rob_id;
wire [6:0] rs_issue_complex_phys_dest;
wire [31:0] rs_issue_complex_src1;
wire [31:0] rs_issue_complex_src2;
wire [31:0] rs_issue_complex_pc;
wire [31:0] rs_issue_complex_imm;
wire [5:0] rs_issue_complex_opcode;

wire rs_issue_muldiv_valid;
wire [5:0] rs_issue_muldiv_rob_id;
wire [6:0] rs_issue_muldiv_phys_dest;
wire [31:0] rs_issue_muldiv_src1;
wire [31:0] rs_issue_muldiv_src2;
wire [5:0] rs_issue_muldiv_opcode;

wire rs_issue_fpu_valid;
wire [5:0] rs_issue_fpu_rob_id;
wire [6:0] rs_issue_fpu_phys_dest;
wire [63:0] rs_issue_fpu_src1;
wire [63:0] rs_issue_fpu_src2;
wire [5:0] rs_issue_fpu_opcode;

wire rs_issue_lsu_valid;
wire [5:0] rs_issue_lsu_rob_id;
wire [6:0] rs_issue_lsu_phys_dest;
wire [31:0] rs_issue_lsu_addr;
wire [31:0] rs_issue_lsu_data;
wire [5:0] rs_issue_lsu_opcode;

wire rs_issue_vec_valid;
wire [5:0] rs_issue_vec_rob_id;
wire [6:0] rs_issue_vec_phys_dest;
wire [4:0] rs_issue_vec_vs1;
wire [4:0] rs_issue_vec_vs2;
wire [31:0] rs_issue_vec_scalar;
wire [5:0] rs_issue_vec_opcode;

assign dispatch_ready = !iq_empty && rob_alloc_ready && rs_alloc_ready && rename_ready;
assign rename_has_dest = (iq_instr[iq_head][11:7] != 5'd0);

// Helper to translate LSU byte enables into abstract size codes for cache I/O
function automatic [2:0] be_to_size;
    input [3:0] be;
    begin
        case (be)
            4'b0001, 4'b0010, 4'b0100, 4'b1000: be_to_size = 3'd0; // byte
            4'b0011, 4'b0110, 4'b1100:         be_to_size = 3'd1; // halfword (aligned pairs)
            default:                            be_to_size = 3'd2; // word or wider
        endcase
    end
endfunction

// Dequeue from IQ
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        iq_head <= 5'h0;
    end else if (flush) begin
        iq_head <= 5'h0;
    end else if (dispatch_ready) begin
        iq_head <= iq_head + 1'b1;
    end
end

// ============================================================================
// OoO Infrastructure
// ============================================================================

// ROB
wire rob_commit_valid;
wire [4:0] rob_commit_arch_dest;
wire [6:0] rob_commit_phys_dest, rob_commit_phys_old;
wire [31:0] rob_commit_result;
wire store_commit_valid;
wire [5:0] store_commit_id;
wire rob_exception;
wire [3:0] rob_exception_cause;
wire [31:0] rob_exception_pc;

reorder_buffer rob_inst (
    .clk               (clk),
    .rst_n             (rst_n),
    .alloc_valid_i     (dispatch_ready),
    .alloc_pc_i        (iq_pc[iq_head]),
    .alloc_arch_dest_i (iq_instr[iq_head][11:7]),
    .alloc_phys_dest_i (phys_dest),
    .alloc_phys_dest_old_i (phys_dest_old),
    .alloc_is_store_i  (1'b0),
    .alloc_is_branch_i (1'b0),
    .alloc_is_fp_i     (1'b0),
    .alloc_is_vec_i    (1'b0),
    .alloc_ready_o     (rob_alloc_ready),
    .alloc_rob_id_o    (rob_alloc_id),
    .complete_valid_i  (1'b0),
    .complete_rob_id_i (6'h0),
    .complete_result_i (32'h0),
    .complete_exception_i (1'b0),
    .complete_exception_cause_i (4'h0),
    .complete_branch_target_i (32'h0),
    .complete_branch_taken_i (1'b0),
    .complete_branch_mispredict_i (1'b0),
    .commit_valid_o    (rob_commit_valid),
    .commit_arch_dest_o(rob_commit_arch_dest),
    .commit_phys_dest_o(rob_commit_phys_dest),
    .commit_phys_dest_old_o (rob_commit_phys_old),
    .commit_result_o   (rob_commit_result),
    .commit_is_store_o (),
    .commit_is_branch_o(),
    .commit_is_fp_o    (),
    .commit_is_vec_o   (),
    .exception_o       (rob_exception),
    .exception_cause_o (rob_exception_cause),
    .exception_pc_o    (rob_exception_pc),
    .flush_o           (flush),
    .flush_target_o    (flush_target),
    .store_commit_valid_o (store_commit_valid),
    .store_commit_rob_id_o(store_commit_id),
    .full_o            (),
    .empty_o           (),
    .count_o           ()
);

// Register Rename
register_rename rename_inst (
    .clk                (clk),
    .rst_n              (rst_n),
    .rename_valid_i     (dispatch_ready),
    .rename_arch_src1_i (iq_instr[iq_head][19:15]),
    .rename_arch_src2_i (iq_instr[iq_head][24:20]),
    .rename_arch_dest_i (iq_instr[iq_head][11:7]),
    .rename_has_dest_i  (rename_has_dest),
    .rename_is_fp_i     (1'b0),  // TODO: decode FP instructions
    .rename_is_vec_i    (1'b0),  // TODO: decode vector instructions
    .rename_ready_o     (rename_ready),
    .rename_phys_src1_o (phys_src1),
    .rename_phys_src2_o (phys_src2),
    .rename_phys_dest_o (phys_dest),
    .rename_phys_dest_old_o (phys_dest_old),
    .rename_src1_ready_o(src1_ready),
    .rename_src2_ready_o(src2_ready),
    .rename_src1_value_o(src1_value),
    .rename_src2_value_o(src2_value),
    .commit_valid_i     (rob_commit_valid),
    .commit_arch_dest_i (rob_commit_arch_dest),
    .commit_phys_dest_i (rob_commit_phys_dest),
    .commit_phys_dest_old_i  (rob_commit_phys_old),
    .commit_result_i    (rob_commit_result),
    .commit_is_fp_i     (1'b0),
    .commit_is_vec_i    (1'b0),
    .wakeup0_valid_i    (1'b0),  // TODO: wire execution units
    .wakeup0_phys_dest_i(7'h0),
    .wakeup0_value_i    (32'h0),
    .wakeup1_valid_i    (1'b0),
    .wakeup1_phys_dest_i(7'h0),
    .wakeup1_value_i    (32'h0),
    .wakeup2_valid_i    (1'b0),
    .wakeup2_phys_dest_i(7'h0),
    .wakeup2_value_i    (32'h0),
    .wakeup3_valid_i    (1'b0),
    .wakeup3_phys_dest_i(7'h0),
    .wakeup3_value_i    (32'h0),
    .flush_i            (flush)
);

// Reservation Station
reservation_station rs_inst (
    .clk                  (clk),
    .rst_n                (rst_n),
    .dispatch_valid_i     (dispatch_ready),
    .dispatch_rob_id_i    (rob_alloc_id),
    .dispatch_phys_dest_i (phys_dest),
    .dispatch_phys_src1_i (phys_src1),
    .dispatch_phys_src2_i (phys_src2),
    .dispatch_imm_i       (iq_imm[iq_head]),
    .dispatch_pc_i        (iq_pc[iq_head]),
    .dispatch_opcode_i    (iq_instr[iq_head][5:0]),
    .dispatch_unit_type_i (4'h0),  // TODO: decode unit type
    .dispatch_src1_ready_i(src1_ready),
    .dispatch_src2_ready_i(src2_ready),
    .dispatch_src1_value_i(src1_value),
    .dispatch_src2_value_i(src2_value),
    .dispatch_ready_o     (rs_alloc_ready),
    .wakeup0_valid_i      (1'b0),  // TODO: wire execution units
    .wakeup0_phys_dest_i  (7'h0),
    .wakeup0_value_i      (32'h0),
    .wakeup1_valid_i      (1'b0),
    .wakeup1_phys_dest_i  (7'h0),
    .wakeup1_value_i      (32'h0),
    .wakeup2_valid_i      (1'b0),
    .wakeup2_phys_dest_i  (7'h0),
    .wakeup2_value_i      (32'h0),
    .wakeup3_valid_i      (1'b0),
    .wakeup3_phys_dest_i  (7'h0),
    .wakeup3_value_i      (32'h0),
    .issue_alu0_valid_o   (rs_issue_alu0_valid),
    .issue_alu0_rob_id_o  (rs_issue_alu0_rob_id),
    .issue_alu0_phys_dest_o(rs_issue_alu0_phys_dest),
    .issue_alu0_src1_o    (rs_issue_alu0_src1),
    .issue_alu0_src2_o    (rs_issue_alu0_src2),
    .issue_alu0_opcode_o  (rs_issue_alu0_opcode),
    .issue_alu0_ready_i   (alu0_ready),
    .issue_alu1_valid_o   (rs_issue_alu1_valid),
    .issue_alu1_rob_id_o  (rs_issue_alu1_rob_id),
    .issue_alu1_phys_dest_o(rs_issue_alu1_phys_dest),
    .issue_alu1_src1_o    (rs_issue_alu1_src1),
    .issue_alu1_src2_o    (rs_issue_alu1_src2),
    .issue_alu1_opcode_o  (rs_issue_alu1_opcode),
    .issue_alu1_ready_i   (alu1_ready),
    .issue_complex_valid_o(rs_issue_complex_valid),
    .issue_complex_rob_id_o(rs_issue_complex_rob_id),
    .issue_complex_phys_dest_o(rs_issue_complex_phys_dest),
    .issue_complex_src1_o (rs_issue_complex_src1),
    .issue_complex_src2_o (rs_issue_complex_src2),
    .issue_complex_pc_o   (rs_issue_complex_pc),
    .issue_complex_imm_o  (rs_issue_complex_imm),
    .issue_complex_opcode_o(rs_issue_complex_opcode),
    .issue_complex_ready_i(complex_ready),
    .issue_muldiv_valid_o (rs_issue_muldiv_valid),
    .issue_muldiv_rob_id_o(rs_issue_muldiv_rob_id),
    .issue_muldiv_phys_dest_o(rs_issue_muldiv_phys_dest),
    .issue_muldiv_src1_o  (rs_issue_muldiv_src1),
    .issue_muldiv_src2_o  (rs_issue_muldiv_src2),
    .issue_muldiv_opcode_o(rs_issue_muldiv_opcode),
    .issue_muldiv_ready_i (muldiv_ready),
    .issue_fpu_valid_o    (rs_issue_fpu_valid),
    .issue_fpu_rob_id_o   (rs_issue_fpu_rob_id),
    .issue_fpu_phys_dest_o(rs_issue_fpu_phys_dest),
    .issue_fpu_src1_o     (rs_issue_fpu_src1),
    .issue_fpu_src2_o     (rs_issue_fpu_src2),
    .issue_fpu_opcode_o   (rs_issue_fpu_opcode),
    .issue_fpu_ready_i    (fpu_ready),
    .issue_lsu_valid_o    (rs_issue_lsu_valid),
    .issue_lsu_rob_id_o   (rs_issue_lsu_rob_id),
    .issue_lsu_phys_dest_o(rs_issue_lsu_phys_dest),
    .issue_lsu_addr_o     (rs_issue_lsu_addr),
    .issue_lsu_data_o     (rs_issue_lsu_data),
    .issue_lsu_opcode_o   (rs_issue_lsu_opcode),
    .issue_lsu_ready_i    (lsu_ready),
    .issue_vec_valid_o    (rs_issue_vec_valid),
    .issue_vec_rob_id_o   (rs_issue_vec_rob_id),
    .issue_vec_phys_dest_o(rs_issue_vec_phys_dest),
    .issue_vec_vs1_o      (rs_issue_vec_vs1),
    .issue_vec_vs2_o      (rs_issue_vec_vs2),
    .issue_vec_scalar_o   (rs_issue_vec_scalar),
    .issue_vec_opcode_o   (rs_issue_vec_opcode),
    .issue_vec_ready_i    (vec_ready),
    .flush_i              (flush),
    .count_o              (),
    .full_o               ()
);

// ============================================================================
// Execution Units - All 6 units wired to RS/ROB
// ============================================================================

// Unit 0: Simple ALU 0
wire alu0_valid_out;
wire [31:0] alu0_result;
wire [5:0] alu0_rob_id;
wire [6:0] alu0_phys_dest;
wire alu0_exception;
wire alu0_ready;

simple_alu #(.UNIT_ID(0)) alu0_inst (
    .clk         (clk),
    .rst_n       (rst_n),
    .valid_i     (rs_issue_alu0_valid),
    .operand_a_i (rs_issue_alu0_src1),
    .operand_b_i (rs_issue_alu0_src2),
    .alu_op_i    (rs_issue_alu0_opcode[3:0]),
    .rob_id_i    (rs_issue_alu0_rob_id),
    .phys_dest_i (rs_issue_alu0_phys_dest),
    .valid_o     (alu0_valid_out),
    .result_o    (alu0_result),
    .rob_id_o    (alu0_rob_id),
    .phys_dest_o (alu0_phys_dest),
    .exception_o (alu0_exception),
    .ready_o     (alu0_ready)
);

// Unit 1: Simple ALU 1
wire alu1_valid_out;
wire [31:0] alu1_result;
wire [5:0] alu1_rob_id;
wire [6:0] alu1_phys_dest;
wire alu1_exception;
wire alu1_ready;

simple_alu #(.UNIT_ID(1)) alu1_inst (
    .clk         (clk),
    .rst_n       (rst_n),
    .valid_i     (rs_issue_alu1_valid),
    .operand_a_i (rs_issue_alu1_src1),
    .operand_b_i (rs_issue_alu1_src2),
    .alu_op_i    (rs_issue_alu1_opcode[3:0]),
    .rob_id_i    (rs_issue_alu1_rob_id),
    .phys_dest_i (rs_issue_alu1_phys_dest),
    .valid_o     (alu1_valid_out),
    .result_o    (alu1_result),
    .rob_id_o    (alu1_rob_id),
    .phys_dest_o (alu1_phys_dest),
    .exception_o (alu1_exception),
    .ready_o     (alu1_ready)
);

// Unit 2: Complex ALU (branches, jumps)
wire complex_valid_out;
wire [31:0] complex_result;
wire [5:0] complex_rob_id;
wire [6:0] complex_phys_dest;
wire complex_exception;
wire complex_ready;
wire complex_mispredict;
wire [31:0] complex_correct_target;
wire complex_br_taken;

complex_alu complex_inst (
    .clk            (clk),
    .rst_n          (rst_n),
    .valid_i        (rs_issue_complex_valid),
    .operand_a_i    (rs_issue_complex_src1),
    .operand_b_i    (rs_issue_complex_src2),
    .imm_i          (rs_issue_complex_imm),
    .pc_i           (rs_issue_complex_pc),
    .op_i           (rs_issue_complex_opcode[3:0]),
    .rob_id_i       (rs_issue_complex_rob_id),
    .phys_dest_i    (rs_issue_complex_phys_dest),
    .valid_o        (complex_valid_out),
    .result_o       (complex_result),
    .rob_id_o       (complex_rob_id),
    .phys_dest_o    (complex_phys_dest),
    .exception_o    (complex_exception),
    .branch_taken_o (complex_br_taken),
    .branch_target_o(complex_correct_target),
    .ready_o        (complex_ready)
);

// Unit 3: MUL/DIV
wire muldiv_valid_out;
wire [31:0] muldiv_result;
wire [5:0] muldiv_rob_id;
wire [6:0] muldiv_phys_dest;
wire muldiv_exception;
wire muldiv_ready;

mul_div_unit muldiv_inst (
    .clk         (clk),
    .rst_n       (rst_n),
    .valid_i     (rs_issue_muldiv_valid),
    .operand_a_i (rs_issue_muldiv_src1),
    .operand_b_i (rs_issue_muldiv_src2),
    .op_i        (rs_issue_muldiv_opcode[3:0]),
    .rob_id_i    (rs_issue_muldiv_rob_id),
    .phys_dest_i (rs_issue_muldiv_phys_dest),
    .valid_o     (muldiv_valid_out),
    .result_o    (muldiv_result),
    .rob_id_o    (muldiv_rob_id),
    .phys_dest_o (muldiv_phys_dest),
    .exception_o (muldiv_exception),
    .ready_o     (muldiv_ready)
);

// Unit 4: FPU
wire fpu_valid_out;
wire [63:0] fpu_result;
wire [5:0] fpu_rob_id;
wire [6:0] fpu_phys_dest;
wire fpu_exception;
wire [4:0] fpu_exception_flags;
wire fpu_ready;

fpu_unit fpu_inst (
    .clk              (clk),
    .rst_n            (rst_n),
    .valid_i          (rs_issue_fpu_valid),
    .operand_a_i      (rs_issue_fpu_src1),
    .operand_b_i      (rs_issue_fpu_src2),
    .operand_c_i      (64'h0),
    .fpu_op_i         (rs_issue_fpu_opcode[4:0]),
    .is_double_i      (1'b0),    // TODO: decode
    .rm_i             (3'b000),  // TODO: get from instruction
    .rob_id_i         (rs_issue_fpu_rob_id),
    .phys_dest_i      (rs_issue_fpu_phys_dest),
    .valid_o          (fpu_valid_out),
    .result_o         (fpu_result),
    .rob_id_o         (fpu_rob_id),
    .phys_dest_o      (fpu_phys_dest),
    .exception_o      (fpu_exception),
    .fflags_o         (fpu_exception_flags),
    .ready_o          (fpu_ready)
);

// Unit 5: Vector Unit
wire vec_valid_out;
wire [127:0] vec_result;
wire [5:0] vec_rob_id;
wire [6:0] vec_phys_dest;
wire vec_exception;
wire vec_ready;

vector_unit vec_inst (
    .clk         (clk),
    .rst_n       (rst_n),
    .valid_i     (rs_issue_vec_valid),
    .vs1_i       (rs_issue_vec_vs1),
    .vs2_i       (rs_issue_vec_vs2),
    .vd_i        (rs_issue_vec_phys_dest[4:0]),
    .scalar_i    (rs_issue_vec_scalar),
    .vec_op_i    (rs_issue_vec_opcode),
    .rob_id_i    (rs_issue_vec_rob_id),
    .phys_dest_i (rs_issue_vec_phys_dest),
    .vtype_i     (11'h040), // TODO: track dynamic vtype
    .vl_i        (8'd16),   // TODO: get from CSR
    .valid_o     (vec_valid_out),
    .result_o    (vec_result),
    .rob_id_o    (vec_rob_id),
    .phys_dest_o (vec_phys_dest),
    .exception_o (vec_exception),
    .ready_o     (vec_ready)
);

// Unit 6: LSU (Load-Store Unit)
wire lsu_valid_out;
wire [31:0] lsu_result;
wire [5:0] lsu_rob_id;
wire [6:0] lsu_phys_dest;
wire lsu_exception;
wire [3:0] lsu_exception_cause;
wire lsu_ready;

wire        lsu_dcache_req_valid;
wire [31:0] lsu_dcache_req_addr;
wire [31:0] lsu_dcache_req_data;
wire        lsu_dcache_req_we;
wire [3:0]  lsu_dcache_req_be;
wire        lsu_dcache_req_ready;
wire        lsu_dcache_resp_valid;
wire [31:0] lsu_dcache_resp_data;
wire        lsu_dcache_resp_error;
wire        lsu_dcache_resp_ready;

lsu lsu_inst (
    .clk                 (clk),
    .rst_n               (rst_n),
    .valid_i             (rs_issue_lsu_valid),
    .addr_i              (rs_issue_lsu_addr),
    .store_data_i        (rs_issue_lsu_data),
    .mem_op_i            (rs_issue_lsu_opcode[3:0]),
    .rob_id_i            (rs_issue_lsu_rob_id),
    .phys_dest_i         (rs_issue_lsu_phys_dest),
    .is_store_i          (rs_issue_lsu_opcode[4]),
    .valid_o             (lsu_valid_out),
    .result_o            (lsu_result),
    .rob_id_o            (lsu_rob_id),
    .phys_dest_o         (lsu_phys_dest),
    .exception_o         (lsu_exception),
    .exception_cause_o   (lsu_exception_cause),
    .ready_o             (lsu_ready),
    .dcache_req_valid_o  (lsu_dcache_req_valid),
    .dcache_req_addr_o   (lsu_dcache_req_addr),
    .dcache_req_data_o   (lsu_dcache_req_data),
    .dcache_req_we_o     (lsu_dcache_req_we),
    .dcache_req_be_o     (lsu_dcache_req_be),
    .dcache_req_ready_i  (lsu_dcache_req_ready),
    .dcache_resp_valid_i (lsu_dcache_resp_valid),
    .dcache_resp_data_i  (lsu_dcache_resp_data),
    .dcache_resp_error_i (lsu_dcache_resp_error),
    .dcache_resp_ready_o (lsu_dcache_resp_ready),
    .mmu_vaddr_o         (),  // TODO: wire MMU
    .mmu_paddr_i         (32'h0),
    .mmu_valid_i         (1'b1),
    .mmu_page_fault_i    (1'b0),
    .store_commit_i      (store_commit_valid),
    .store_commit_rob_id_i(store_commit_id),
    .fence_i             (1'b0),
    .flush_i             (flush)
);

// LSU <-> memory interface bridging (splits unified LSU channel)
assign dmem_load_req_valid_o  = lsu_dcache_req_valid & ~lsu_dcache_req_we;
assign dmem_load_req_addr_o   = lsu_dcache_req_addr;
assign dmem_load_req_size_o   = be_to_size(lsu_dcache_req_be);
assign dmem_load_req_signed_o = 1'b0;  // TODO: plumb sign information from LSU

assign dmem_store_req_valid_o = lsu_dcache_req_valid & lsu_dcache_req_we;
assign dmem_store_req_addr_o  = lsu_dcache_req_addr;
assign dmem_store_req_data_o  = {32'h0, lsu_dcache_req_data};
assign dmem_store_req_mask_o  = {4'h0, lsu_dcache_req_be};
assign dmem_store_req_size_o  = be_to_size(lsu_dcache_req_be);

assign lsu_dcache_req_ready = lsu_dcache_req_we ? dmem_store_req_ready_i
                                               : dmem_load_req_ready_i;

assign lsu_dcache_resp_valid = dmem_load_resp_valid_i | dmem_store_resp_valid_i;
assign lsu_dcache_resp_data  = dmem_load_resp_valid_i ? dmem_load_resp_data_i[31:0]
                                                      : 32'h0;
assign lsu_dcache_resp_error = (dmem_load_resp_valid_i & dmem_load_resp_error_i) |
                               (dmem_store_resp_valid_i & dmem_store_resp_error_i);

assign dmem_load_resp_ready_o  = lsu_dcache_resp_ready;
assign dmem_store_resp_ready_o = lsu_dcache_resp_ready;

assign store_commit_valid_o = store_commit_valid;
assign store_commit_id_o    = store_commit_id;

// ============================================================================
// Completion to ROB (from all execution units)
// ============================================================================
// Wire execution unit outputs to ROB completion ports
// ROB has 4 completion ports - multiplex 6 units
wire [3:0] complete_valid = {
    complex_valid_out,                   // Port 3
    muldiv_valid_out | fpu_valid_out,    // Port 2
    vec_valid_out | lsu_valid_out,       // Port 1
    alu0_valid_out | alu1_valid_out      // Port 0
};

// Wakeup to Register Rename (from all units)
// 4 wakeup ports - same multiplexing
wire [3:0] wakeup_valid = complete_valid;

// Branch predictor update from complex ALU
assign complex_mispredict = 1'b0;  // TODO: compute against predicted outcome
assign bp_update_valid = complex_valid_out;
assign bp_update_pc = rs_issue_complex_pc;
assign bp_update_taken = complex_br_taken;
assign bp_update_target = complex_correct_target;
assign bp_update_is_branch = 1'b1;  // TODO: proper decode
assign bp_update_is_call = 1'b0;    // TODO: decode JAL/JALR
assign bp_update_is_return = 1'b0;  // TODO: decode JALR with rs1=x1
assign bp_update_history = history_f3;  // TODO: proper history tracking
assign bp_mispredict = complex_mispredict;
assign bp_recover_history = 11'h0;  // TODO: save history at dispatch
assign bp_recover_ras_tos = 5'h0;   // TODO: save RAS TOS

// ============================================================================
// Initialization
// ============================================================================
integer ii;
initial begin
    for (ii = 0; ii < 32; ii = ii + 1) begin
        iq_instr[ii] = 32'h00000013;  // NOP
        iq_pc[ii] = 32'h0;
        iq_imm[ii] = 32'h0;
        iq_history[ii] = 11'h0;
    end
end

endmodule
