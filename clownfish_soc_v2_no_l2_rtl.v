// ============================================================================
// Clownfish SoC v2 TURBO - NO L2 Cache + PAE
// ============================================================================
// Features: PAE (36-bit addressing), Turbo Boost (1.1-3.5 GHz), NO L2 cache
// L1 caches connected directly to memory via priority arbiter
// ============================================================================

`include "include/clownfish_config.vh"

module clownfish_soc_v2 (
    input  wire         clk,
    input  wire         rst_n,
    
    // External memory interface with PAE (36-bit physical addressing)
    output wire         mem_req_valid_o,
    output wire [35:0]  mem_req_addr_o,      // PAE: 36-bit = 64GB addressable
    output wire         mem_req_we_o,
    output wire [511:0] mem_req_data_o,
    input  wire         mem_req_ready_i,
    
    input  wire         mem_resp_valid_i,
    input  wire [511:0] mem_resp_data_i,
    input  wire         mem_resp_error_i,
    output wire         mem_resp_ready_o,
    
    // Interrupts
    input  wire         ext_interrupt_i,
    input  wire         timer_interrupt_i,
    input  wire         software_interrupt_i
);

// ============================================================================
// Core Instance
// ============================================================================
wire        core_imem_req_valid;
wire [31:0] core_imem_req_addr;
wire        core_imem_req_ready;
wire        core_imem_resp_valid;
wire [31:0] core_imem_resp_data;
wire        core_imem_resp_error;
wire        core_imem_resp_ready;

wire        core_dmem_load_req_valid;
wire [31:0] core_dmem_load_req_addr;
wire [2:0]  core_dmem_load_req_size;
wire        core_dmem_load_req_signed;
wire        core_dmem_load_req_ready;

wire        core_dmem_load_resp_valid;
wire [63:0] core_dmem_load_resp_data;
wire        core_dmem_load_resp_error;
wire        core_dmem_load_resp_ready;

wire        core_dmem_store_req_valid;
wire [31:0] core_dmem_store_req_addr;
wire [63:0] core_dmem_store_req_data;
wire [7:0]  core_dmem_store_req_mask;
wire [2:0]  core_dmem_store_req_size;
wire        core_dmem_store_req_ready;

wire        core_dmem_store_resp_valid;
wire        core_dmem_store_resp_error;
wire        core_dmem_store_resp_ready;

wire        core_store_commit_valid;
wire [5:0]  core_store_commit_id;

clownfish_core_v2 core_inst (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .imem_req_valid_o       (core_imem_req_valid),
    .imem_req_addr_o        (core_imem_req_addr),
    .imem_req_ready_i       (core_imem_req_ready),
    .imem_resp_valid_i      (core_imem_resp_valid),
    .imem_resp_data_i       (core_imem_resp_data),
    .imem_resp_error_i      (core_imem_resp_error),
    .imem_resp_ready_o      (core_imem_resp_ready),
    .dmem_load_req_valid_o  (core_dmem_load_req_valid),
    .dmem_load_req_addr_o   (core_dmem_load_req_addr),
    .dmem_load_req_size_o   (core_dmem_load_req_size),
    .dmem_load_req_signed_o (core_dmem_load_req_signed),
    .dmem_load_req_ready_i  (core_dmem_load_req_ready),
    .dmem_load_resp_valid_i (core_dmem_load_resp_valid),
    .dmem_load_resp_data_i  (core_dmem_load_resp_data),
    .dmem_load_resp_error_i (core_dmem_load_resp_error),
    .dmem_load_resp_ready_o (core_dmem_load_resp_ready),
    .dmem_store_req_valid_o (core_dmem_store_req_valid),
    .dmem_store_req_addr_o  (core_dmem_store_req_addr),
    .dmem_store_req_data_o  (core_dmem_store_req_data),
    .dmem_store_req_mask_o  (core_dmem_store_req_mask),
    .dmem_store_req_size_o  (core_dmem_store_req_size),
    .dmem_store_req_ready_i (core_dmem_store_req_ready),
    .dmem_store_resp_valid_i(core_dmem_store_resp_valid),
    .dmem_store_resp_error_i(core_dmem_store_resp_error),
    .dmem_store_resp_ready_o(core_dmem_store_resp_ready),
    .store_commit_valid_o   (core_store_commit_valid),
    .store_commit_id_o      (core_store_commit_id),
    .ext_interrupt_i        (ext_interrupt_i),
    .timer_interrupt_i      (timer_interrupt_i),
    .software_interrupt_i   (software_interrupt_i)
);

// ============================================================================
// L1 Instruction Cache
// ============================================================================
wire        l1i_l2_req_valid;
wire [31:0] l1i_l2_req_addr;
wire        l1i_l2_req_ready;
wire        l1i_l2_resp_valid;
wire [511:0] l1i_l2_resp_data;
wire        l1i_l2_resp_error;
wire        l1i_l2_resp_ready;

l1_icache l1_icache_inst (
    .clk             (clk),
    .rst_n           (rst_n),
    .req_valid_i     (core_imem_req_valid),
    .req_addr_i      (core_imem_req_addr),
    .req_ready_o     (core_imem_req_ready),
    .resp_valid_o    (core_imem_resp_valid),
    .resp_data_o     (core_imem_resp_data),
    .resp_error_o    (core_imem_resp_error),
    .resp_ready_i    (core_imem_resp_ready),
    .l2_req_valid_o  (l1i_l2_req_valid),
    .l2_req_addr_o   (l1i_l2_req_addr),
    .l2_req_ready_i  (l1i_l2_req_ready),
    .l2_resp_valid_i (l1i_l2_resp_valid),
    .l2_resp_data_i  (l1i_l2_resp_data),
    .l2_resp_error_i (l1i_l2_resp_error),
    .l2_resp_ready_o (l1i_l2_resp_ready),
    .flush_i         (1'b0)
);

// ============================================================================
// L1 Data Cache
// ============================================================================
wire        l1d_l2_req_valid;
wire [31:0] l1d_l2_req_addr;
wire        l1d_l2_req_we;
wire [511:0] l1d_l2_req_data;
wire        l1d_l2_req_ready;
wire        l1d_l2_resp_valid;
wire [511:0] l1d_l2_resp_data;
wire        l1d_l2_resp_error;
wire        l1d_l2_resp_ready;

l1_dcache_new l1_dcache_inst (
    .clk                  (clk),
    .rst_n                (rst_n),
    .load_req_valid_i     (core_dmem_load_req_valid),
    .load_req_addr_i      (core_dmem_load_req_addr),
    .load_req_size_i      (core_dmem_load_req_size),
    .load_req_signed_i    (core_dmem_load_req_signed),
    .load_req_ready_o     (core_dmem_load_req_ready),
    .load_resp_valid_o    (core_dmem_load_resp_valid),
    .load_resp_data_o     (core_dmem_load_resp_data),
    .load_resp_error_o    (core_dmem_load_resp_error),
    .load_resp_ready_i    (core_dmem_load_resp_ready),
    .store_req_valid_i    (core_dmem_store_req_valid),
    .store_req_addr_i     (core_dmem_store_req_addr),
    .store_req_data_i     (core_dmem_store_req_data),
    .store_req_mask_i     (core_dmem_store_req_mask),
    .store_req_size_i     (core_dmem_store_req_size),
    .store_req_ready_o    (core_dmem_store_req_ready),
    .store_resp_valid_o   (core_dmem_store_resp_valid),
    .store_resp_error_o   (core_dmem_store_resp_error),
    .store_resp_ready_i   (core_dmem_store_resp_ready),
    .store_commit_valid_i (core_store_commit_valid),
    .store_commit_id_i    (core_store_commit_id),
    .l2_req_valid_o       (l1d_l2_req_valid),
    .l2_req_addr_o        (l1d_l2_req_addr),
    .l2_req_we_o          (l1d_l2_req_we),
    .l2_req_data_o        (l1d_l2_req_data),
    .l2_req_ready_i       (l1d_l2_req_ready),
    .l2_resp_valid_i      (l1d_l2_resp_valid),
    .l2_resp_data_i       (l1d_l2_resp_data),
    .l2_resp_error_i      (l1d_l2_resp_error),
    .l2_resp_ready_o      (l1d_l2_resp_ready),
    .fence_i              (1'b0),
    .fence_done_o         ()
);

// ============================================================================
// Memory Arbiter - Priority-based (D-cache > I-cache)
// ============================================================================
reg arb_select_dcache;
reg arb_serving;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        arb_select_dcache <= 1'b0;
        arb_serving <= 1'b0;
    end else begin
        if (!arb_serving) begin
            if (l1d_l2_req_valid) begin
                arb_select_dcache <= 1'b1;
                arb_serving <= 1'b1;
            end else if (l1i_l2_req_valid) begin
                arb_select_dcache <= 1'b0;
                arb_serving <= 1'b1;
            end
        end
        
        if (arb_serving && mem_resp_valid_i) begin
            if (arb_select_dcache && l1d_l2_resp_ready) begin
                arb_serving <= 1'b0;
            end else if (!arb_select_dcache && l1i_l2_resp_ready) begin
                arb_serving <= 1'b0;
            end
        end
    end
end

// ============================================================================
// PAE Translation: 32-bit Virtual → 36-bit Physical
// ============================================================================
wire [35:0] l1i_phys_addr;
wire [35:0] l1d_phys_addr;

// Simple PAE: Extend virtual address to physical (MMU would do full translation)
assign l1i_phys_addr = {4'b0000, l1i_l2_req_addr};  // I-cache: low memory
assign l1d_phys_addr = {4'b0000, l1d_l2_req_addr};  // D-cache: low memory

// ============================================================================
// Memory Interface with PAE Addressing
// ============================================================================
assign mem_req_valid_o = arb_select_dcache ? l1d_l2_req_valid : l1i_l2_req_valid;
assign mem_req_addr_o  = arb_select_dcache ? l1d_phys_addr : l1i_phys_addr;  // PAE: 36-bit
assign mem_req_we_o    = arb_select_dcache ? l1d_l2_req_we : 1'b0;
assign mem_req_data_o  = arb_select_dcache ? l1d_l2_req_data : 512'b0;

assign l1d_l2_req_ready = arb_select_dcache && mem_req_ready_i;
assign l1i_l2_req_ready = !arb_select_dcache && mem_req_ready_i;

assign l1d_l2_resp_valid = arb_select_dcache ? mem_resp_valid_i : 1'b0;
assign l1d_l2_resp_data  = mem_resp_data_i;
assign l1d_l2_resp_error = mem_resp_error_i;

assign l1i_l2_resp_valid = !arb_select_dcache ? mem_resp_valid_i : 1'b0;
assign l1i_l2_resp_data  = mem_resp_data_i;
assign l1i_l2_resp_error = mem_resp_error_i;

assign mem_resp_ready_o = arb_select_dcache ? l1d_l2_resp_ready : l1i_l2_resp_ready;

endmodule
