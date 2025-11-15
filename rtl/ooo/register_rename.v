// ============================================================================
// Register Rename Unit - Clownfish RISC-V Processor
// ============================================================================
// Implements register renaming for out-of-order execution
// Includes Register Alias Table (RAT) and Free List management
// ============================================================================

`include "../../include/clownfish_config.vh"

module register_rename (
    input  wire         clk,
    input  wire         rst_n,
    
    // Rename interface (from decode)
    input  wire         rename_valid_i,
    input  wire [4:0]   rename_arch_src1_i,
    input  wire [4:0]   rename_arch_src2_i,
    input  wire [4:0]   rename_arch_dest_i,
    input  wire         rename_has_dest_i,      // Instruction writes to dest
    input  wire         rename_is_fp_i,
    input  wire         rename_is_vec_i,
    output reg          rename_ready_o,
    
    // Renamed outputs
    output reg  [6:0]   rename_phys_src1_o,
    output reg  [6:0]   rename_phys_src2_o,
    output reg  [6:0]   rename_phys_dest_o,
    output reg  [6:0]   rename_phys_dest_old_o, // Previous mapping (for freeing)
    output reg          rename_src1_ready_o,
    output reg          rename_src2_ready_o,
    output reg  [31:0]  rename_src1_value_o,
    output reg  [31:0]  rename_src2_value_o,
    
    // Commit interface (from ROB)
    input  wire         commit_valid_i,
    input  wire [4:0]   commit_arch_dest_i,
    input  wire [6:0]   commit_phys_dest_i,
    input  wire [6:0]   commit_phys_dest_old_i,
    input  wire [31:0]  commit_result_i,
    input  wire         commit_is_fp_i,
    input  wire         commit_is_vec_i,
    
    // Wakeup interface (from execution units)
    input  wire         wakeup0_valid_i,
    input  wire [6:0]   wakeup0_phys_dest_i,
    input  wire [31:0]  wakeup0_value_i,
    
    input  wire         wakeup1_valid_i,
    input  wire [6:0]   wakeup1_phys_dest_i,
    input  wire [31:0]  wakeup1_value_i,
    
    input  wire         wakeup2_valid_i,
    input  wire [6:0]   wakeup2_phys_dest_i,
    input  wire [31:0]  wakeup2_value_i,
    
    input  wire         wakeup3_valid_i,
    input  wire [6:0]   wakeup3_phys_dest_i,
    input  wire [31:0]  wakeup3_value_i,
    
    // Flush interface
    input  wire         flush_i
);

// Register file sizes
localparam NUM_ARCH_INT_REGS  = 32;
localparam NUM_ARCH_FP_REGS   = 32;
localparam NUM_ARCH_VEC_REGS  = 32;
localparam NUM_PHYS_INT_REGS  = `NUM_PHYS_INT_REGS;  // 96
localparam NUM_PHYS_FP_REGS   = `NUM_PHYS_FP_REGS;   // 96
localparam NUM_PHYS_VEC_REGS  = `NUM_PHYS_VEC_REGS;  // 64

// Register Alias Tables (RAT)
// Maps architectural registers to physical registers
reg [6:0]  rat_int  [0:NUM_ARCH_INT_REGS-1];   // Integer RAT
reg [6:0]  rat_fp   [0:NUM_ARCH_FP_REGS-1];    // FP RAT
reg [6:0]  rat_vec  [0:NUM_ARCH_VEC_REGS-1];   // Vector RAT

// Committed RAT (for recovery on flush)
reg [6:0]  rat_committed_int [0:NUM_ARCH_INT_REGS-1];
reg [6:0]  rat_committed_fp  [0:NUM_ARCH_FP_REGS-1];
reg [6:0]  rat_committed_vec [0:NUM_ARCH_VEC_REGS-1];

// Physical register file (stores values)
reg [31:0] prf_int  [0:NUM_PHYS_INT_REGS-1];
reg [63:0] prf_fp   [0:NUM_PHYS_FP_REGS-1];
reg [127:0] prf_vec [0:NUM_PHYS_VEC_REGS-1];

// Physical register ready bits
reg        prf_int_ready  [0:NUM_PHYS_INT_REGS-1];
reg        prf_fp_ready   [0:NUM_PHYS_FP_REGS-1];
reg        prf_vec_ready  [0:NUM_PHYS_VEC_REGS-1];

// Free lists (available physical registers)
reg [NUM_PHYS_INT_REGS-1:0]  free_list_int;
reg [NUM_PHYS_FP_REGS-1:0]   free_list_fp;
reg [NUM_PHYS_VEC_REGS-1:0]  free_list_vec;

// Free list counters
reg [6:0] free_count_int;
reg [6:0] free_count_fp;
reg [6:0] free_count_vec;

// Find first free physical register
function [6:0] find_free_phys_reg;
    input [95:0] free_list;  // Max size
    integer i;
    begin
        find_free_phys_reg = 7'h7F;  // Invalid
        for (i = 0; i < 96; i = i + 1) begin
            if (free_list[i] && find_free_phys_reg == 7'h7F) begin
                find_free_phys_reg = i[6:0];
            end
        end
    end
endfunction

localparam integer MAX_PHYS_REGS = 96;
localparam integer INT_PAD = (MAX_PHYS_REGS > NUM_PHYS_INT_REGS) ? (MAX_PHYS_REGS - NUM_PHYS_INT_REGS) : 0;
localparam integer FP_PAD  = (MAX_PHYS_REGS > NUM_PHYS_FP_REGS)  ? (MAX_PHYS_REGS - NUM_PHYS_FP_REGS)  : 0;
localparam integer VEC_PAD = (MAX_PHYS_REGS > NUM_PHYS_VEC_REGS) ? (MAX_PHYS_REGS - NUM_PHYS_VEC_REGS) : 0;

wire [MAX_PHYS_REGS-1:0] free_list_int_ext = { {INT_PAD{1'b0}}, free_list_int };
wire [MAX_PHYS_REGS-1:0] free_list_fp_ext  = { {FP_PAD{1'b0}}, free_list_fp };
wire [MAX_PHYS_REGS-1:0] free_list_vec_ext = { {VEC_PAD{1'b0}}, free_list_vec };

wire [6:0] next_free_int = find_free_phys_reg(free_list_int_ext);
wire [6:0] next_free_fp  = find_free_phys_reg(free_list_fp_ext);
wire [6:0] next_free_vec = find_free_phys_reg(free_list_vec_ext);

// Check if we can allocate registers
wire can_allocate_int = (free_count_int > 0);
wire can_allocate_fp  = (free_count_fp > 0);
wire can_allocate_vec = (free_count_vec > 0);

always @(*) begin
    if (!rename_is_fp_i && !rename_is_vec_i) begin
        rename_ready_o = can_allocate_int;
    end else if (rename_is_fp_i) begin
        rename_ready_o = can_allocate_fp;
    end else begin
        rename_ready_o = can_allocate_vec;
    end
end

// Rename logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Initialization handled in initial block
    end else begin
        if (flush_i) begin
            integer i;
            // Restore RAT to committed state
            for (i = 0; i < NUM_ARCH_INT_REGS; i = i + 1) begin
                rat_int[i] <= rat_committed_int[i];
            end
            for (i = 0; i < NUM_ARCH_FP_REGS; i = i + 1) begin
                rat_fp[i] <= rat_committed_fp[i];
            end
            for (i = 0; i < NUM_ARCH_VEC_REGS; i = i + 1) begin
                rat_vec[i] <= rat_committed_vec[i];
            end
            
            // Rebuild free lists (all non-committed phys regs are free)
            // Simplified: would need more complex logic
        end else if (rename_valid_i && rename_ready_o && rename_has_dest_i) begin
            // Allocate new physical register
            if (!rename_is_fp_i && !rename_is_vec_i) begin
                // Integer register
                if (next_free_int != 7'h7F) begin
                    rename_phys_dest_o     <= next_free_int;
                    rename_phys_dest_old_o <= rat_int[rename_arch_dest_i];
                    
                    // Update RAT
                    rat_int[rename_arch_dest_i] <= next_free_int;
                    
                    // Mark new register as not ready
                    prf_int_ready[next_free_int] <= 1'b0;
                    
                    // Remove from free list
                    free_list_int[next_free_int] <= 1'b0;
                    free_count_int <= free_count_int - 1;
                end
            end else if (rename_is_fp_i) begin
                // FP register
                if (next_free_fp != 7'h7F) begin
                    rename_phys_dest_o     <= next_free_fp;
                    rename_phys_dest_old_o <= rat_fp[rename_arch_dest_i];
                    
                    rat_fp[rename_arch_dest_i]  <= next_free_fp;
                    prf_fp_ready[next_free_fp]  <= 1'b0;
                    free_list_fp[next_free_fp]  <= 1'b0;
                    free_count_fp <= free_count_fp - 1;
                end
            end else begin
                // Vector register
                if (next_free_vec != 7'h7F) begin
                    rename_phys_dest_o     <= next_free_vec;
                    rename_phys_dest_old_o <= rat_vec[rename_arch_dest_i];
                    
                    rat_vec[rename_arch_dest_i] <= next_free_vec;
                    prf_vec_ready[next_free_vec] <= 1'b0;
                    free_list_vec[next_free_vec] <= 1'b0;
                    free_count_vec <= free_count_vec - 1;
                end
            end
        end
        
        // Commit interface: update committed RAT and free old physical registers
        if (commit_valid_i) begin
            if (!commit_is_fp_i && !commit_is_vec_i) begin
                // Integer commit
                rat_committed_int[commit_arch_dest_i] <= commit_phys_dest_i;
                prf_int[commit_phys_dest_i] <= commit_result_i;
                prf_int_ready[commit_phys_dest_i] <= 1'b1;
                
                // Free old physical register
                if (commit_phys_dest_old_i != commit_phys_dest_i) begin
                    free_list_int[commit_phys_dest_old_i] <= 1'b1;
                    free_count_int <= free_count_int + 1;
                end
            end else if (commit_is_fp_i) begin
                // FP commit
                rat_committed_fp[commit_arch_dest_i] <= commit_phys_dest_i;
                prf_fp[commit_phys_dest_i] <= {32'h0, commit_result_i};
                prf_fp_ready[commit_phys_dest_i] <= 1'b1;
                
                if (commit_phys_dest_old_i != commit_phys_dest_i) begin
                    free_list_fp[commit_phys_dest_old_i] <= 1'b1;
                    free_count_fp <= free_count_fp + 1;
                end
            end else begin
                // Vector commit
                rat_committed_vec[commit_arch_dest_i] <= commit_phys_dest_i;
                prf_vec_ready[commit_phys_dest_i] <= 1'b1;
                
                if (commit_phys_dest_old_i != commit_phys_dest_i) begin
                    free_list_vec[commit_phys_dest_old_i] <= 1'b1;
                    free_count_vec <= free_count_vec + 1;
                end
            end
        end

        // Wakeup logic: mark integer physical registers ready and update values
        if (wakeup0_valid_i && wakeup0_phys_dest_i < NUM_PHYS_INT_REGS) begin
            prf_int_ready[wakeup0_phys_dest_i] <= 1'b1;
            prf_int[wakeup0_phys_dest_i] <= wakeup0_value_i;
        end

        if (wakeup1_valid_i && wakeup1_phys_dest_i < NUM_PHYS_INT_REGS) begin
            prf_int_ready[wakeup1_phys_dest_i] <= 1'b1;
            prf_int[wakeup1_phys_dest_i] <= wakeup1_value_i;
        end

        if (wakeup2_valid_i && wakeup2_phys_dest_i < NUM_PHYS_INT_REGS) begin
            prf_int_ready[wakeup2_phys_dest_i] <= 1'b1;
            prf_int[wakeup2_phys_dest_i] <= wakeup2_value_i;
        end

        if (wakeup3_valid_i && wakeup3_phys_dest_i < NUM_PHYS_INT_REGS) begin
            prf_int_ready[wakeup3_phys_dest_i] <= 1'b1;
            prf_int[wakeup3_phys_dest_i] <= wakeup3_value_i;
        end
    end
end

// Combinational read of source operands
always @(*) begin
    if (!rename_is_fp_i && !rename_is_vec_i) begin
        // Integer sources
        rename_phys_src1_o  = rat_int[rename_arch_src1_i];
        rename_phys_src2_o  = rat_int[rename_arch_src2_i];
        rename_src1_ready_o = prf_int_ready[rat_int[rename_arch_src1_i]];
        rename_src2_ready_o = prf_int_ready[rat_int[rename_arch_src2_i]];
        rename_src1_value_o = prf_int[rat_int[rename_arch_src1_i]];
        rename_src2_value_o = prf_int[rat_int[rename_arch_src2_i]];
    end else if (rename_is_fp_i) begin
        // FP sources
        rename_phys_src1_o  = rat_fp[rename_arch_src1_i];
        rename_phys_src2_o  = rat_fp[rename_arch_src2_i];
        rename_src1_ready_o = prf_fp_ready[rat_fp[rename_arch_src1_i]];
        rename_src2_ready_o = prf_fp_ready[rat_fp[rename_arch_src2_i]];
        rename_src1_value_o = prf_fp[rat_fp[rename_arch_src1_i]][31:0];
        rename_src2_value_o = prf_fp[rat_fp[rename_arch_src2_i]][31:0];
    end else begin
        // Vector sources
        rename_phys_src1_o  = rat_vec[rename_arch_src1_i];
        rename_phys_src2_o  = rat_vec[rename_arch_src2_i];
        rename_src1_ready_o = prf_vec_ready[rat_vec[rename_arch_src1_i]];
        rename_src2_ready_o = prf_vec_ready[rat_vec[rename_arch_src2_i]];
        rename_src1_value_o = 32'h0;  // Vector values not passed through rename
        rename_src2_value_o = 32'h0;
    end
    
    // x0 is always 0 and ready
    if (rename_arch_src1_i == 5'h0) begin
        rename_src1_ready_o = 1'b1;
        rename_src1_value_o = 32'h0;
    end
    if (rename_arch_src2_i == 5'h0) begin
        rename_src2_ready_o = 1'b1;
        rename_src2_value_o = 32'h0;
    end
end

// Initialize
integer i;
initial begin
    // Initialize RATs (arch reg N maps to phys reg N initially)
    for (i = 0; i < NUM_ARCH_INT_REGS; i = i + 1) begin
        rat_int[i] = i[6:0];
        rat_committed_int[i] = i[6:0];
    end
    for (i = 0; i < NUM_ARCH_FP_REGS; i = i + 1) begin
        rat_fp[i] = i[6:0];
        rat_committed_fp[i] = i[6:0];
    end
    for (i = 0; i < NUM_ARCH_VEC_REGS; i = i + 1) begin
        rat_vec[i] = i[6:0];
        rat_committed_vec[i] = i[6:0];
    end
    
    // Initialize physical register files
    for (i = 0; i < NUM_PHYS_INT_REGS; i = i + 1) begin
        prf_int[i] = 32'h0;
        prf_int_ready[i] = (i < NUM_ARCH_INT_REGS) ? 1'b1 : 1'b0;
    end
    for (i = 0; i < NUM_PHYS_FP_REGS; i = i + 1) begin
        prf_fp[i] = 64'h0;
        prf_fp_ready[i] = (i < NUM_ARCH_FP_REGS) ? 1'b1 : 1'b0;
    end
    for (i = 0; i < NUM_PHYS_VEC_REGS; i = i + 1) begin
        prf_vec[i] = 128'h0;
        prf_vec_ready[i] = (i < NUM_ARCH_VEC_REGS) ? 1'b1 : 1'b0;
    end
    
    // Initialize free lists (first N are mapped to arch regs, rest are free)
    free_list_int = {NUM_PHYS_INT_REGS{1'b0}};
    free_list_fp  = {NUM_PHYS_FP_REGS{1'b0}};
    free_list_vec = {NUM_PHYS_VEC_REGS{1'b0}};
    
    for (i = NUM_ARCH_INT_REGS; i < NUM_PHYS_INT_REGS; i = i + 1) begin
        free_list_int[i] = 1'b1;
    end
    for (i = NUM_ARCH_FP_REGS; i < NUM_PHYS_FP_REGS; i = i + 1) begin
        free_list_fp[i] = 1'b1;
    end
    for (i = NUM_ARCH_VEC_REGS; i < NUM_PHYS_VEC_REGS; i = i + 1) begin
        free_list_vec[i] = 1'b1;
    end
    
    free_count_int = NUM_PHYS_INT_REGS - NUM_ARCH_INT_REGS;
    free_count_fp  = NUM_PHYS_FP_REGS - NUM_ARCH_FP_REGS;
    free_count_vec = NUM_PHYS_VEC_REGS - NUM_ARCH_VEC_REGS;
end

endmodule
