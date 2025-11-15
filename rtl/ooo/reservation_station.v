// ============================================================================
// Reservation Station - Clownfish RISC-V Processor
// ============================================================================
// Unified reservation station for all execution units (48 entries total)
// Handles instruction scheduling, operand capture, and wakeup logic
// ============================================================================

`include "../../include/clownfish_config.vh"

module reservation_station (
    input  wire         clk,
    input  wire         rst_n,
    
    // Dispatch interface (from decode/rename)
    input  wire         dispatch_valid_i,
    input  wire [5:0]   dispatch_rob_id_i,
    input  wire [6:0]   dispatch_phys_dest_i,
    input  wire [6:0]   dispatch_phys_src1_i,
    input  wire [6:0]   dispatch_phys_src2_i,
    input  wire [31:0]  dispatch_imm_i,
    input  wire [31:0]  dispatch_pc_i,
    input  wire [5:0]   dispatch_opcode_i,
    input  wire [3:0]   dispatch_unit_type_i,    // Target execution unit
    input  wire         dispatch_src1_ready_i,
    input  wire         dispatch_src2_ready_i,
    input  wire [31:0]  dispatch_src1_value_i,
    input  wire [31:0]  dispatch_src2_value_i,
    output wire         dispatch_ready_o,
    
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
    
    // Issue interface (to execution units)
    // Simple ALU 0
    output reg          issue_alu0_valid_o,
    output reg  [5:0]   issue_alu0_rob_id_o,
    output reg  [6:0]   issue_alu0_phys_dest_o,
    output reg  [31:0]  issue_alu0_src1_o,
    output reg  [31:0]  issue_alu0_src2_o,
    output reg  [5:0]   issue_alu0_opcode_o,
    input  wire         issue_alu0_ready_i,
    
    // Simple ALU 1
    output reg          issue_alu1_valid_o,
    output reg  [5:0]   issue_alu1_rob_id_o,
    output reg  [6:0]   issue_alu1_phys_dest_o,
    output reg  [31:0]  issue_alu1_src1_o,
    output reg  [31:0]  issue_alu1_src2_o,
    output reg  [5:0]   issue_alu1_opcode_o,
    input  wire         issue_alu1_ready_i,
    
    // Complex ALU
    output reg          issue_complex_valid_o,
    output reg  [5:0]   issue_complex_rob_id_o,
    output reg  [6:0]   issue_complex_phys_dest_o,
    output reg  [31:0]  issue_complex_src1_o,
    output reg  [31:0]  issue_complex_src2_o,
    output reg  [31:0]  issue_complex_pc_o,
    output reg  [31:0]  issue_complex_imm_o,
    output reg  [5:0]   issue_complex_opcode_o,
    input  wire         issue_complex_ready_i,

    // Mul/Div Unit
    output reg          issue_muldiv_valid_o,
    output reg  [5:0]   issue_muldiv_rob_id_o,
    output reg  [6:0]   issue_muldiv_phys_dest_o,
    output reg  [31:0]  issue_muldiv_src1_o,
    output reg  [31:0]  issue_muldiv_src2_o,
    output reg  [5:0]   issue_muldiv_opcode_o,
    input  wire         issue_muldiv_ready_i,
    
    // FPU
    output reg          issue_fpu_valid_o,
    output reg  [5:0]   issue_fpu_rob_id_o,
    output reg  [6:0]   issue_fpu_phys_dest_o,
    output reg  [63:0]  issue_fpu_src1_o,
    output reg  [63:0]  issue_fpu_src2_o,
    output reg  [5:0]   issue_fpu_opcode_o,
    input  wire         issue_fpu_ready_i,
    
    // LSU
    output reg          issue_lsu_valid_o,
    output reg  [5:0]   issue_lsu_rob_id_o,
    output reg  [6:0]   issue_lsu_phys_dest_o,
    output reg  [31:0]  issue_lsu_addr_o,
    output reg  [31:0]  issue_lsu_data_o,
    output reg  [5:0]   issue_lsu_opcode_o,
    input  wire         issue_lsu_ready_i,
    
    // Vector Unit
    output reg          issue_vec_valid_o,
    output reg  [5:0]   issue_vec_rob_id_o,
    output reg  [6:0]   issue_vec_phys_dest_o,
    output reg  [4:0]   issue_vec_vs1_o,
    output reg  [4:0]   issue_vec_vs2_o,
    output reg  [31:0]  issue_vec_scalar_o,
    output reg  [5:0]   issue_vec_opcode_o,
    input  wire         issue_vec_ready_i,
    
    // Flush interface
    input  wire         flush_i,
    
    // Status
    output wire [5:0]   count_o,
    output wire         full_o
);

// RS parameters
localparam RS_ENTRIES = `RS_ENTRIES;  // 48 entries
localparam RS_PTR_WIDTH = 6;          // log2(64) to be safe

// Execution unit types
localparam UNIT_ALU_SIMPLE  = 4'b0000;
localparam UNIT_ALU_COMPLEX = 4'b0001;
localparam UNIT_MUL_DIV     = 4'b0010;
localparam UNIT_FPU         = 4'b0011;
localparam UNIT_LSU         = 4'b0100;
localparam UNIT_VECTOR      = 4'b0101;

// RS entry structure
reg         rs_valid        [0:RS_ENTRIES-1];
reg         rs_ready        [0:RS_ENTRIES-1];  // Both operands ready
reg [5:0]   rs_rob_id       [0:RS_ENTRIES-1];
reg [6:0]   rs_phys_dest    [0:RS_ENTRIES-1];
reg [6:0]   rs_phys_src1    [0:RS_ENTRIES-1];
reg [6:0]   rs_phys_src2    [0:RS_ENTRIES-1];
reg [31:0]  rs_src1_value   [0:RS_ENTRIES-1];
reg [31:0]  rs_src2_value   [0:RS_ENTRIES-1];
reg         rs_src1_ready   [0:RS_ENTRIES-1];
reg         rs_src2_ready   [0:RS_ENTRIES-1];
reg [31:0]  rs_imm          [0:RS_ENTRIES-1];
reg [31:0]  rs_pc           [0:RS_ENTRIES-1];
reg [5:0]   rs_opcode       [0:RS_ENTRIES-1];
reg [3:0]   rs_unit_type    [0:RS_ENTRIES-1];

// Entry count
reg [5:0] entry_count;
assign count_o = entry_count;
assign full_o = (entry_count == RS_ENTRIES);
assign dispatch_ready_o = !full_o;

// Find free entry for allocation
function [5:0] find_free_entry;
    integer i;
    begin
        find_free_entry = 6'h3F;  // Invalid
        for (i = 0; i < RS_ENTRIES; i = i + 1) begin
            if (!rs_valid[i] && find_free_entry == 6'h3F) begin
                find_free_entry = i[5:0];
            end
        end
    end
endfunction

// Find oldest ready entry for a specific unit type
function [5:0] find_ready_entry;
    input [3:0] unit_type;
    integer i;
    begin
        find_ready_entry = 6'h3F;  // Invalid
        for (i = 0; i < RS_ENTRIES; i = i + 1) begin
            if (rs_valid[i] && rs_ready[i] && rs_unit_type[i] == unit_type) begin
                find_ready_entry = i[5:0];
                i = RS_ENTRIES;  // Break (select oldest = lowest index)
            end
        end
    end
endfunction

wire [5:0] free_entry = find_free_entry();
wire [5:0] ready_alu0    = find_ready_entry(UNIT_ALU_SIMPLE);
wire [5:0] ready_alu1    = find_ready_entry(UNIT_ALU_SIMPLE);
wire [5:0] ready_complex = find_ready_entry(UNIT_ALU_COMPLEX);
wire [5:0] ready_muldiv  = find_ready_entry(UNIT_MUL_DIV);
wire [5:0] ready_fpu     = find_ready_entry(UNIT_FPU);
wire [5:0] ready_lsu     = find_ready_entry(UNIT_LSU);
wire [5:0] ready_vec     = find_ready_entry(UNIT_VECTOR);

wire issue_alu0_fire    = (ready_alu0    != 6'h3F) && issue_alu0_ready_i;
wire issue_complex_fire = (ready_complex != 6'h3F) && issue_complex_ready_i;
wire issue_muldiv_fire  = (ready_muldiv  != 6'h3F) && issue_muldiv_ready_i;
wire issue_fpu_fire     = (ready_fpu     != 6'h3F) && issue_fpu_ready_i;
wire issue_lsu_fire     = (ready_lsu     != 6'h3F) && issue_lsu_ready_i;
wire issue_vec_fire     = (ready_vec     != 6'h3F) && issue_vec_ready_i;

wire dispatch_fire = dispatch_valid_i && dispatch_ready_o && (free_entry != 6'h3F);

genvar rs_idx;
generate
    for (rs_idx = 0; rs_idx < RS_ENTRIES; rs_idx = rs_idx + 1) begin : rs_entry
        localparam [5:0] ENTRY_ID = rs_idx;

        wire entry_issue_fire =
            (issue_alu0_fire    && ready_alu0    == ENTRY_ID) ||
            (issue_complex_fire && ready_complex == ENTRY_ID) ||
            (issue_muldiv_fire  && ready_muldiv  == ENTRY_ID) ||
            (issue_fpu_fire     && ready_fpu     == ENTRY_ID) ||
            (issue_lsu_fire     && ready_lsu     == ENTRY_ID) ||
            (issue_vec_fire     && ready_vec     == ENTRY_ID);

        wire entry_dispatch_fire = dispatch_fire && (free_entry == ENTRY_ID);

        wire src1_hit_w0 = wakeup0_valid_i && (rs_phys_src1[rs_idx] == wakeup0_phys_dest_i);
        wire src1_hit_w1 = wakeup1_valid_i && (rs_phys_src1[rs_idx] == wakeup1_phys_dest_i);
        wire src1_hit_w2 = wakeup2_valid_i && (rs_phys_src1[rs_idx] == wakeup2_phys_dest_i);
        wire src1_hit_w3 = wakeup3_valid_i && (rs_phys_src1[rs_idx] == wakeup3_phys_dest_i);
        wire src1_hit_any = src1_hit_w0 || src1_hit_w1 || src1_hit_w2 || src1_hit_w3;
        wire [31:0] src1_wake_value = src1_hit_w3 ? wakeup3_value_i :
                                      src1_hit_w2 ? wakeup2_value_i :
                                      src1_hit_w1 ? wakeup1_value_i :
                                      src1_hit_w0 ? wakeup0_value_i :
                                      rs_src1_value[rs_idx];

        wire src2_hit_w0 = wakeup0_valid_i && (rs_phys_src2[rs_idx] == wakeup0_phys_dest_i);
        wire src2_hit_w1 = wakeup1_valid_i && (rs_phys_src2[rs_idx] == wakeup1_phys_dest_i);
        wire src2_hit_w2 = wakeup2_valid_i && (rs_phys_src2[rs_idx] == wakeup2_phys_dest_i);
        wire src2_hit_w3 = wakeup3_valid_i && (rs_phys_src2[rs_idx] == wakeup3_phys_dest_i);
        wire src2_hit_any = src2_hit_w0 || src2_hit_w1 || src2_hit_w2 || src2_hit_w3;
        wire [31:0] src2_wake_value = src2_hit_w3 ? wakeup3_value_i :
                                      src2_hit_w2 ? wakeup2_value_i :
                                      src2_hit_w1 ? wakeup1_value_i :
                                      src2_hit_w0 ? wakeup0_value_i :
                                      rs_src2_value[rs_idx];

        wire src1_ready_post = rs_src1_ready[rs_idx] || (rs_valid[rs_idx] && src1_hit_any);
        wire src2_ready_post = rs_src2_ready[rs_idx] || (rs_valid[rs_idx] && src2_hit_any);

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                rs_valid[rs_idx]      <= 1'b0;
                rs_ready[rs_idx]      <= 1'b0;
                rs_src1_ready[rs_idx] <= 1'b0;
                rs_src2_ready[rs_idx] <= 1'b0;
                rs_rob_id[rs_idx]     <= 6'h0;
                rs_phys_dest[rs_idx]  <= 7'h0;
                rs_phys_src1[rs_idx]  <= 7'h0;
                rs_phys_src2[rs_idx]  <= 7'h0;
                rs_src1_value[rs_idx] <= 32'h0;
                rs_src2_value[rs_idx] <= 32'h0;
                rs_imm[rs_idx]        <= 32'h0;
                rs_pc[rs_idx]         <= 32'h0;
                rs_opcode[rs_idx]     <= 6'h0;
                rs_unit_type[rs_idx]  <= 4'h0;
            end else if (flush_i) begin
                rs_valid[rs_idx]      <= 1'b0;
                rs_ready[rs_idx]      <= 1'b0;
                rs_src1_ready[rs_idx] <= 1'b0;
                rs_src2_ready[rs_idx] <= 1'b0;
                rs_rob_id[rs_idx]     <= 6'h0;
                rs_phys_dest[rs_idx]  <= 7'h0;
                rs_phys_src1[rs_idx]  <= 7'h0;
                rs_phys_src2[rs_idx]  <= 7'h0;
                rs_src1_value[rs_idx] <= 32'h0;
                rs_src2_value[rs_idx] <= 32'h0;
                rs_imm[rs_idx]        <= 32'h0;
                rs_pc[rs_idx]         <= 32'h0;
                rs_opcode[rs_idx]     <= 6'h0;
                rs_unit_type[rs_idx]  <= 4'h0;
            end else begin
                if (entry_dispatch_fire) begin
                    rs_valid[rs_idx]      <= 1'b1;
                    rs_ready[rs_idx]      <= dispatch_src1_ready_i && dispatch_src2_ready_i;
                    rs_src1_ready[rs_idx] <= dispatch_src1_ready_i;
                    rs_src2_ready[rs_idx] <= dispatch_src2_ready_i;
                    rs_rob_id[rs_idx]     <= dispatch_rob_id_i;
                    rs_phys_dest[rs_idx]  <= dispatch_phys_dest_i;
                    rs_phys_src1[rs_idx]  <= dispatch_phys_src1_i;
                    rs_phys_src2[rs_idx]  <= dispatch_phys_src2_i;
                    rs_src1_value[rs_idx] <= dispatch_src1_value_i;
                    rs_src2_value[rs_idx] <= dispatch_src2_value_i;
                    rs_imm[rs_idx]        <= dispatch_imm_i;
                    rs_pc[rs_idx]         <= dispatch_pc_i;
                    rs_opcode[rs_idx]     <= dispatch_opcode_i;
                    rs_unit_type[rs_idx]  <= dispatch_unit_type_i;
                end else begin
                    if (entry_issue_fire) begin
                        rs_valid[rs_idx]      <= 1'b0;
                        rs_ready[rs_idx]      <= 1'b0;
                        rs_src1_ready[rs_idx] <= 1'b0;
                        rs_src2_ready[rs_idx] <= 1'b0;
                        rs_rob_id[rs_idx]     <= 6'h0;
                        rs_phys_dest[rs_idx]  <= 7'h0;
                        rs_phys_src1[rs_idx]  <= 7'h0;
                        rs_phys_src2[rs_idx]  <= 7'h0;
                        rs_src1_value[rs_idx] <= 32'h0;
                        rs_src2_value[rs_idx] <= 32'h0;
                        rs_imm[rs_idx]        <= 32'h0;
                        rs_pc[rs_idx]         <= 32'h0;
                        rs_opcode[rs_idx]     <= 6'h0;
                        rs_unit_type[rs_idx]  <= 4'h0;
                    end else if (rs_valid[rs_idx]) begin
                        if (!rs_src1_ready[rs_idx] && src1_hit_any) begin
                            rs_src1_ready[rs_idx] <= 1'b1;
                            rs_src1_value[rs_idx] <= src1_wake_value;
                        end
                        if (!rs_src2_ready[rs_idx] && src2_hit_any) begin
                            rs_src2_ready[rs_idx] <= 1'b1;
                            rs_src2_value[rs_idx] <= src2_wake_value;
                        end
                        if (!rs_ready[rs_idx] && (src1_ready_post && src2_ready_post)) begin
                            rs_ready[rs_idx] <= 1'b1;
                        end
                    end
                end
            end
        end
    end
endgenerate

always @(posedge clk or negedge rst_n) begin
    integer delta;
    integer next_count;
    if (!rst_n) begin
        entry_count <= 6'd0;
    end else if (flush_i) begin
        entry_count <= 6'd0;
    end else begin
        delta = 0;
        if (dispatch_fire)
            delta = delta + 1;
        if (issue_alu0_fire)
            delta = delta - 1;
        if (issue_complex_fire)
            delta = delta - 1;
        if (issue_muldiv_fire)
            delta = delta - 1;
        if (issue_fpu_fire)
            delta = delta - 1;
        if (issue_lsu_fire)
            delta = delta - 1;
        if (issue_vec_fire)
            delta = delta - 1;

        next_count = entry_count + delta;
        if (next_count < 0)
            next_count = 0;
        else if (next_count > RS_ENTRIES)
            next_count = RS_ENTRIES;

        entry_count <= next_count[5:0];
    end
end

// Issue logic (select and issue ready entries to execution units)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        issue_alu0_valid_o     <= 1'b0;
        issue_alu0_rob_id_o    <= 6'h0;
        issue_alu0_phys_dest_o <= 7'h0;
        issue_alu0_src1_o      <= 32'h0;
        issue_alu0_src2_o      <= 32'h0;
        issue_alu0_opcode_o    <= 6'h0;

        issue_alu1_valid_o     <= 1'b0;
        issue_alu1_rob_id_o    <= 6'h0;
        issue_alu1_phys_dest_o <= 7'h0;
        issue_alu1_src1_o      <= 32'h0;
        issue_alu1_src2_o      <= 32'h0;
        issue_alu1_opcode_o    <= 6'h0;

        issue_complex_valid_o     <= 1'b0;
        issue_complex_rob_id_o    <= 6'h0;
        issue_complex_phys_dest_o <= 7'h0;
        issue_complex_src1_o      <= 32'h0;
        issue_complex_src2_o      <= 32'h0;
        issue_complex_pc_o        <= 32'h0;
        issue_complex_imm_o       <= 32'h0;
        issue_complex_opcode_o    <= 6'h0;

        issue_muldiv_valid_o     <= 1'b0;
        issue_muldiv_rob_id_o    <= 6'h0;
        issue_muldiv_phys_dest_o <= 7'h0;
        issue_muldiv_src1_o      <= 32'h0;
        issue_muldiv_src2_o      <= 32'h0;
        issue_muldiv_opcode_o    <= 6'h0;

        issue_fpu_valid_o     <= 1'b0;
        issue_fpu_rob_id_o    <= 6'h0;
        issue_fpu_phys_dest_o <= 7'h0;
        issue_fpu_src1_o      <= 64'h0;
        issue_fpu_src2_o      <= 64'h0;
        issue_fpu_opcode_o    <= 6'h0;

        issue_lsu_valid_o     <= 1'b0;
        issue_lsu_rob_id_o    <= 6'h0;
        issue_lsu_phys_dest_o <= 7'h0;
        issue_lsu_addr_o      <= 32'h0;
        issue_lsu_data_o      <= 32'h0;
        issue_lsu_opcode_o    <= 6'h0;

        issue_vec_valid_o     <= 1'b0;
        issue_vec_rob_id_o    <= 6'h0;
        issue_vec_phys_dest_o <= 7'h0;
        issue_vec_vs1_o       <= 5'h0;
        issue_vec_vs2_o       <= 5'h0;
        issue_vec_scalar_o    <= 32'h0;
        issue_vec_opcode_o    <= 6'h0;
    end else begin
        issue_alu0_valid_o    <= 1'b0;
        issue_alu1_valid_o    <= 1'b0;
        issue_complex_valid_o <= 1'b0;
        issue_muldiv_valid_o  <= 1'b0;
        issue_fpu_valid_o     <= 1'b0;
        issue_lsu_valid_o     <= 1'b0;
        issue_vec_valid_o     <= 1'b0;

        if (issue_alu0_fire) begin
            issue_alu0_valid_o     <= 1'b1;
            issue_alu0_rob_id_o    <= rs_rob_id[ready_alu0];
            issue_alu0_phys_dest_o <= rs_phys_dest[ready_alu0];
            issue_alu0_src1_o      <= rs_src1_value[ready_alu0];
            issue_alu0_src2_o      <= rs_src2_value[ready_alu0];
            issue_alu0_opcode_o    <= rs_opcode[ready_alu0];
        end

        // Simple ALU 1 currently unused (placeholder)
        issue_alu1_valid_o <= 1'b0;

        if (issue_complex_fire) begin
            issue_complex_valid_o     <= 1'b1;
            issue_complex_rob_id_o    <= rs_rob_id[ready_complex];
            issue_complex_phys_dest_o <= rs_phys_dest[ready_complex];
            issue_complex_src1_o      <= rs_src1_value[ready_complex];
            issue_complex_src2_o      <= rs_src2_value[ready_complex];
            issue_complex_pc_o        <= rs_pc[ready_complex];
            issue_complex_imm_o       <= rs_imm[ready_complex];
            issue_complex_opcode_o    <= rs_opcode[ready_complex];
        end

        if (issue_muldiv_fire) begin
            issue_muldiv_valid_o     <= 1'b1;
            issue_muldiv_rob_id_o    <= rs_rob_id[ready_muldiv];
            issue_muldiv_phys_dest_o <= rs_phys_dest[ready_muldiv];
            issue_muldiv_src1_o      <= rs_src1_value[ready_muldiv];
            issue_muldiv_src2_o      <= rs_src2_value[ready_muldiv];
            issue_muldiv_opcode_o    <= rs_opcode[ready_muldiv];
        end

        if (issue_fpu_fire) begin
            issue_fpu_valid_o     <= 1'b1;
            issue_fpu_rob_id_o    <= rs_rob_id[ready_fpu];
            issue_fpu_phys_dest_o <= rs_phys_dest[ready_fpu];
            issue_fpu_src1_o      <= {32'h0, rs_src1_value[ready_fpu]};
            issue_fpu_src2_o      <= {32'h0, rs_src2_value[ready_fpu]};
            issue_fpu_opcode_o    <= rs_opcode[ready_fpu];
        end

        if (issue_lsu_fire) begin
            issue_lsu_valid_o     <= 1'b1;
            issue_lsu_rob_id_o    <= rs_rob_id[ready_lsu];
            issue_lsu_phys_dest_o <= rs_phys_dest[ready_lsu];
            issue_lsu_addr_o      <= rs_src1_value[ready_lsu] + rs_imm[ready_lsu];
            issue_lsu_data_o      <= rs_src2_value[ready_lsu];
            issue_lsu_opcode_o    <= rs_opcode[ready_lsu];
        end

        if (issue_vec_fire) begin
            issue_vec_valid_o     <= 1'b1;
            issue_vec_rob_id_o    <= rs_rob_id[ready_vec];
            issue_vec_phys_dest_o <= rs_phys_dest[ready_vec];
            issue_vec_vs1_o       <= rs_phys_src1[ready_vec][4:0];
            issue_vec_vs2_o       <= rs_phys_src2[ready_vec][4:0];
            issue_vec_scalar_o    <= rs_src1_value[ready_vec];
            issue_vec_opcode_o    <= rs_opcode[ready_vec];
        end
    end
end

// Initialize RS entries
integer j;
initial begin
    for (j = 0; j < RS_ENTRIES; j = j + 1) begin
        rs_valid[j]      = 1'b0;
        rs_ready[j]      = 1'b0;
        rs_src1_ready[j] = 1'b0;
        rs_src2_ready[j] = 1'b0;
    end
    entry_count = 6'h0;
end

endmodule
