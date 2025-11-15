// Execution Units Cluster Wrapper
// Bundles all 6 execution units into a single synthesizable block

module execution_cluster (
    input wire clk,
    input wire rst_n,
    
    // Simple ALU 0 interface
    input wire alu0_valid_i,
    input wire [31:0] alu0_a_i,
    input wire [31:0] alu0_b_i,
    input wire [3:0] alu0_op_i,
    input wire [5:0] alu0_rob_id_i,
    input wire [6:0] alu0_phys_dest_i,
    output wire alu0_valid_o,
    output wire [31:0] alu0_result_o,
    output wire [5:0] alu0_rob_id_o,
    output wire [6:0] alu0_phys_dest_o,
    output wire alu0_exception_o,
    output wire alu0_ready_o,
    
    // Simple ALU 1 interface
    input wire alu1_valid_i,
    input wire [31:0] alu1_a_i,
    input wire [31:0] alu1_b_i,
    input wire [3:0] alu1_op_i,
    input wire [5:0] alu1_rob_id_i,
    input wire [6:0] alu1_phys_dest_i,
    output wire alu1_valid_o,
    output wire [31:0] alu1_result_o,
    output wire [5:0] alu1_rob_id_o,
    output wire [6:0] alu1_phys_dest_o,
    output wire alu1_exception_o,
    output wire alu1_ready_o,
    
    // Complex ALU interface
    input wire complex_valid_i,
    input wire [31:0] complex_a_i,
    input wire [31:0] complex_b_i,
    input wire [31:0] complex_imm_i,
    input wire [31:0] complex_pc_i,
    input wire [3:0] complex_op_i,
    input wire [5:0] complex_rob_id_i,
    input wire [6:0] complex_phys_dest_i,
    output wire complex_valid_o,
    output wire [31:0] complex_result_o,
    output wire [5:0] complex_rob_id_o,
    output wire [6:0] complex_phys_dest_o,
    output wire complex_exception_o,
    output wire complex_br_taken_o,
    output wire [31:0] complex_br_target_o,
    output wire complex_ready_o,
    
    // MulDiv interface
    input wire muldiv_valid_i,
    input wire [31:0] muldiv_a_i,
    input wire [31:0] muldiv_b_i,
    input wire [3:0] muldiv_op_i,
    input wire [5:0] muldiv_rob_id_i,
    input wire [6:0] muldiv_phys_dest_i,
    output wire muldiv_valid_o,
    output wire [31:0] muldiv_result_o,
    output wire [5:0] muldiv_rob_id_o,
    output wire [6:0] muldiv_phys_dest_o,
    output wire muldiv_exception_o,
    output wire muldiv_ready_o,
    
    // FPU interface
    input wire fpu_valid_i,
    input wire [63:0] fpu_a_i,
    input wire [63:0] fpu_b_i,
    input wire [63:0] fpu_c_i,
    input wire [4:0] fpu_op_i,
    input wire fpu_is_double_i,
    input wire [2:0] fpu_rm_i,
    input wire [5:0] fpu_rob_id_i,
    input wire [6:0] fpu_phys_dest_i,
    output wire fpu_valid_o,
    output wire [63:0] fpu_result_o,
    output wire [5:0] fpu_rob_id_o,
    output wire [6:0] fpu_phys_dest_o,
    output wire fpu_exception_o,
    output wire [4:0] fpu_fflags_o,
    output wire fpu_ready_o,
    
    // Vector Unit interface
    input wire vec_valid_i,
    input wire [4:0] vec_vs1_i,
    input wire [4:0] vec_vs2_i,
    input wire [4:0] vec_vd_i,
    input wire [31:0] vec_scalar_i,
    input wire [5:0] vec_op_i,
    input wire [5:0] vec_rob_id_i,
    input wire [6:0] vec_phys_dest_i,
    input wire [10:0] vec_vtype_i,
    input wire [7:0] vec_vl_i,
    output wire vec_valid_o,
    output wire [127:0] vec_result_o,
    output wire [5:0] vec_rob_id_o,
    output wire [6:0] vec_phys_dest_o,
    output wire vec_exception_o,
    output wire vec_ready_o,
    
    // LSU interface
    input wire lsu_valid_i,
    input wire [31:0] lsu_addr_i,
    input wire [31:0] lsu_data_i,
    input wire [3:0] lsu_op_i,
    input wire [5:0] lsu_rob_id_i,
    input wire [6:0] lsu_phys_dest_i,
    input wire lsu_is_store_i,
    input wire lsu_store_commit_i,
    input wire [5:0] lsu_store_commit_rob_id_i,
    input wire lsu_flush_i,
    output wire lsu_valid_o,
    output wire [31:0] lsu_result_o,
    output wire [5:0] lsu_rob_id_o,
    output wire [6:0] lsu_phys_dest_o,
    output wire lsu_exception_o,
    output wire [3:0] lsu_exception_cause_o,
    output wire lsu_ready_o,
    
    // LSU D-cache interface
    output wire lsu_dcache_req_valid_o,
    output wire [31:0] lsu_dcache_req_addr_o,
    output wire [31:0] lsu_dcache_req_data_o,
    output wire lsu_dcache_req_we_o,
    output wire [3:0] lsu_dcache_req_be_o,
    input wire lsu_dcache_req_ready_i,
    input wire lsu_dcache_resp_valid_i,
    input wire [31:0] lsu_dcache_resp_data_i,
    input wire lsu_dcache_resp_error_i,
    output wire lsu_dcache_resp_ready_o
);

// Instantiate all 6 execution units
simple_alu #(.UNIT_ID(0)) alu0_inst (
    .clk(clk), .rst_n(rst_n),
    .valid_i(alu0_valid_i), .operand_a_i(alu0_a_i), .operand_b_i(alu0_b_i),
    .alu_op_i(alu0_op_i), .rob_id_i(alu0_rob_id_i), .phys_dest_i(alu0_phys_dest_i),
    .valid_o(alu0_valid_o), .result_o(alu0_result_o), .rob_id_o(alu0_rob_id_o),
    .phys_dest_o(alu0_phys_dest_o), .exception_o(alu0_exception_o), .ready_o(alu0_ready_o)
);

simple_alu #(.UNIT_ID(1)) alu1_inst (
    .clk(clk), .rst_n(rst_n),
    .valid_i(alu1_valid_i), .operand_a_i(alu1_a_i), .operand_b_i(alu1_b_i),
    .alu_op_i(alu1_op_i), .rob_id_i(alu1_rob_id_i), .phys_dest_i(alu1_phys_dest_i),
    .valid_o(alu1_valid_o), .result_o(alu1_result_o), .rob_id_o(alu1_rob_id_o),
    .phys_dest_o(alu1_phys_dest_o), .exception_o(alu1_exception_o), .ready_o(alu1_ready_o)
);

complex_alu complex_inst (
    .clk(clk), .rst_n(rst_n),
    .valid_i(complex_valid_i), .operand_a_i(complex_a_i), .operand_b_i(complex_b_i),
    .imm_i(complex_imm_i), .pc_i(complex_pc_i), .op_i(complex_op_i),
    .rob_id_i(complex_rob_id_i), .phys_dest_i(complex_phys_dest_i),
    .valid_o(complex_valid_o), .result_o(complex_result_o), .rob_id_o(complex_rob_id_o),
    .phys_dest_o(complex_phys_dest_o), .exception_o(complex_exception_o),
    .branch_taken_o(complex_br_taken_o), .branch_target_o(complex_br_target_o),
    .ready_o(complex_ready_o)
);

mul_div_unit muldiv_inst (
    .clk(clk), .rst_n(rst_n),
    .valid_i(muldiv_valid_i), .operand_a_i(muldiv_a_i), .operand_b_i(muldiv_b_i),
    .op_i(muldiv_op_i), .rob_id_i(muldiv_rob_id_i), .phys_dest_i(muldiv_phys_dest_i),
    .valid_o(muldiv_valid_o), .result_o(muldiv_result_o), .rob_id_o(muldiv_rob_id_o),
    .phys_dest_o(muldiv_phys_dest_o), .exception_o(muldiv_exception_o), .ready_o(muldiv_ready_o)
);

fpu_unit fpu_inst (
    .clk(clk), .rst_n(rst_n),
    .valid_i(fpu_valid_i), .operand_a_i(fpu_a_i), .operand_b_i(fpu_b_i), .operand_c_i(fpu_c_i),
    .fpu_op_i(fpu_op_i), .is_double_i(fpu_is_double_i), .rm_i(fpu_rm_i),
    .rob_id_i(fpu_rob_id_i), .phys_dest_i(fpu_phys_dest_i),
    .valid_o(fpu_valid_o), .result_o(fpu_result_o), .rob_id_o(fpu_rob_id_o),
    .phys_dest_o(fpu_phys_dest_o), .exception_o(fpu_exception_o),
    .fflags_o(fpu_fflags_o), .ready_o(fpu_ready_o)
);

vector_unit vec_inst (
    .clk(clk), .rst_n(rst_n),
    .valid_i(vec_valid_i), .vs1_i(vec_vs1_i), .vs2_i(vec_vs2_i), .vd_i(vec_vd_i),
    .scalar_i(vec_scalar_i), .vec_op_i(vec_op_i), .rob_id_i(vec_rob_id_i),
    .phys_dest_i(vec_phys_dest_i), .vtype_i(vec_vtype_i), .vl_i(vec_vl_i),
    .valid_o(vec_valid_o), .result_o(vec_result_o), .rob_id_o(vec_rob_id_o),
    .phys_dest_o(vec_phys_dest_o), .exception_o(vec_exception_o), .ready_o(vec_ready_o)
);

lsu lsu_inst (
    .clk(clk), .rst_n(rst_n),
    .valid_i(lsu_valid_i), .addr_i(lsu_addr_i), .store_data_i(lsu_data_i),
    .mem_op_i(lsu_op_i), .rob_id_i(lsu_rob_id_i), .phys_dest_i(lsu_phys_dest_i),
    .is_store_i(lsu_is_store_i),
    .valid_o(lsu_valid_o), .result_o(lsu_result_o), .rob_id_o(lsu_rob_id_o),
    .phys_dest_o(lsu_phys_dest_o), .exception_o(lsu_exception_o),
    .exception_cause_o(lsu_exception_cause_o), .ready_o(lsu_ready_o),
    .dcache_req_valid_o(lsu_dcache_req_valid_o), .dcache_req_addr_o(lsu_dcache_req_addr_o),
    .dcache_req_data_o(lsu_dcache_req_data_o), .dcache_req_we_o(lsu_dcache_req_we_o),
    .dcache_req_be_o(lsu_dcache_req_be_o), .dcache_req_ready_i(lsu_dcache_req_ready_i),
    .dcache_resp_valid_i(lsu_dcache_resp_valid_i), .dcache_resp_data_i(lsu_dcache_resp_data_i),
    .dcache_resp_error_i(lsu_dcache_resp_error_i), .dcache_resp_ready_o(lsu_dcache_resp_ready_o),
    .mmu_vaddr_o(), .mmu_paddr_i(32'h0), .mmu_valid_i(1'b1), .mmu_page_fault_i(1'b0),
    .store_commit_i(lsu_store_commit_i), .store_commit_rob_id_i(lsu_store_commit_rob_id_i),
    .fence_i(1'b0), .flush_i(lsu_flush_i)
);

endmodule
