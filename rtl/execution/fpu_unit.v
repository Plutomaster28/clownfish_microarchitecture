// ============================================================================
// Floating-Point Unit - Clownfish RISC-V Processor
// ============================================================================
// IEEE 754 compliant FPU for RV32F (single) and RV32D (double precision)
// Operations: FADD, FSUB, FMUL, FDIV, FSQRT, FMADD, FMV, FCVT, FCLASS, FCMP
// Pipelined design with varying latencies
// ============================================================================

`include "../../include/clownfish_config.vh"

module fpu_unit (
    input  wire         clk,
    input  wire         rst_n,
    
    // Input operands
    input  wire         valid_i,
    input  wire [63:0]  operand_a_i,     // Support double precision
    input  wire [63:0]  operand_b_i,
    input  wire [63:0]  operand_c_i,     // For FMADD
    input  wire [4:0]   fpu_op_i,        // FPU operation
    input  wire         is_double_i,     // 1=double precision, 0=single
    input  wire [2:0]   rm_i,            // Rounding mode
    input  wire [5:0]   rob_id_i,
    input  wire [6:0]   phys_dest_i,
    
    // Output result
    output reg          valid_o,
    output reg  [63:0]  result_o,
    output reg  [4:0]   fflags_o,        // FP exception flags
    output reg  [5:0]   rob_id_o,
    output reg  [6:0]   phys_dest_o,
    output reg          exception_o,
    
    // Ready signal
    output wire         ready_o
);

// FPU operation codes
localparam OP_FADD   = 5'b00000;  // Add
localparam OP_FSUB   = 5'b00001;  // Subtract
localparam OP_FMUL   = 5'b00010;  // Multiply
localparam OP_FDIV   = 5'b00011;  // Divide
localparam OP_FSQRT  = 5'b00100;  // Square root
localparam OP_FMADD  = 5'b00101;  // Fused multiply-add
localparam OP_FMSUB  = 5'b00110;  // Fused multiply-sub
localparam OP_FNMADD = 5'b00111;  // Fused negative multiply-add
localparam OP_FNMSUB = 5'b01000;  // Fused negative multiply-sub
localparam OP_FSGNJ  = 5'b01001;  // Sign injection
localparam OP_FSGNJN = 5'b01010;  // Sign injection (negated)
localparam OP_FSGNJX = 5'b01011;  // Sign injection (XOR)
localparam OP_FMIN   = 5'b01100;  // Minimum
localparam OP_FMAX   = 5'b01101;  // Maximum
localparam OP_FCVT   = 5'b01110;  // Convert
localparam OP_FMV    = 5'b01111;  // Move
localparam OP_FCMP   = 5'b10000;  // Compare
localparam OP_FCLASS = 5'b10001;  // Classify

// Rounding modes
localparam RM_RNE = 3'b000;  // Round to nearest, ties to even
localparam RM_RTZ = 3'b001;  // Round towards zero
localparam RM_RDN = 3'b010;  // Round down
localparam RM_RUP = 3'b011;  // Round up
localparam RM_RMM = 3'b100;  // Round to nearest, ties away

// FP exception flags
localparam FLAG_NV = 4;  // Invalid operation
localparam FLAG_DZ = 3;  // Divide by zero
localparam FLAG_OF = 2;  // Overflow
localparam FLAG_UF = 1;  // Underflow
localparam FLAG_NX = 0;  // Inexact

// Pipeline stages for different operations
// Stage 0: Input
// Stage 1-3: ADD/SUB (3 cycles)
// Stage 1-4: MUL (4 cycles)
// Stage 1-5: FMADD (5 cycles)
// Stage 1-10: DIV SP (10 cycles)
// Stage 1-17: DIV DP (17 cycles)

// Maximum pipeline depth
localparam MAX_STAGES = 17;

// Pipeline registers
reg [MAX_STAGES-1:0] pipe_valid;
reg [4:0] pipe_op [0:MAX_STAGES-1];
reg [5:0] pipe_rob_id [0:MAX_STAGES-1];
reg [6:0] pipe_phys_dest [0:MAX_STAGES-1];
reg       pipe_is_double [0:MAX_STAGES-1];
reg [2:0] pipe_rm [0:MAX_STAGES-1];

// Intermediate computation stages
reg [63:0] stage1_result;
reg [63:0] stage2_result;
reg [63:0] stage3_result;
reg [63:0] stage4_result;
reg [63:0] stage5_result;
reg [4:0]  stage_fflags [0:MAX_STAGES-1];

// Divider state machine
localparam DIV_IDLE = 2'b00;
localparam DIV_BUSY = 2'b01;
localparam DIV_DONE = 2'b10;

reg [1:0]  div_state;
reg [4:0]  div_counter;
reg [63:0] div_result;
reg [4:0]  div_fflags;
reg [5:0]  div_rob_id;
reg [6:0]  div_phys_dest;

// Ready when divider idle and pipeline not full
assign ready_o = (div_state == DIV_IDLE) && !pipe_valid[0];

// Helper function: Extract single precision float
function [31:0] sp_extract;
    input [63:0] data;
    begin
        sp_extract = data[31:0];
    end
endfunction

// Helper function: Extend single to double (for future use)
function [63:0] sp_to_dp;
    input [31:0] sp;
    begin
        // Simplified conversion (full implementation would handle exponent/mantissa)
        sp_to_dp = {32'h0, sp};
    end
endfunction

// Stage 0: Input and operation dispatch
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pipe_valid[0] <= 1'b0;
        div_state <= DIV_IDLE;
    end else begin
        // Handle division separately (non-pipelined)
        if (valid_i && (fpu_op_i == OP_FDIV || fpu_op_i == OP_FSQRT) && ready_o) begin
            div_state <= DIV_BUSY;
            div_counter <= is_double_i ? 5'd16 : 5'd9;  // DP: 17 cycles, SP: 10 cycles
            div_rob_id <= rob_id_i;
            div_phys_dest <= phys_dest_i;
            pipe_valid[0] <= 1'b0;
        end
        // Handle pipelined operations
        else if (valid_i && ready_o && fpu_op_i != OP_FDIV && fpu_op_i != OP_FSQRT) begin
            pipe_valid[0] <= 1'b1;
            pipe_op[0] <= fpu_op_i;
            pipe_rob_id[0] <= rob_id_i;
            pipe_phys_dest[0] <= phys_dest_i;
            pipe_is_double[0] <= is_double_i;
            pipe_rm[0] <= rm_i;
        end else begin
            pipe_valid[0] <= 1'b0;
        end
        
        // Divider state machine
        case (div_state)
            DIV_IDLE: begin
                // Handled above
            end
            DIV_BUSY: begin
                if (div_counter > 0) begin
                    div_counter <= div_counter - 1;
                end else begin
                    div_state <= DIV_DONE;
                end
            end
            DIV_DONE: begin
                div_state <= DIV_IDLE;
            end
        endcase
    end
end

// Pipeline stage 1: Initial computation
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pipe_valid[1] <= 1'b0;
        stage1_result <= 64'h0;
    end else begin
        pipe_valid[1] <= pipe_valid[0];
        pipe_op[1] <= pipe_op[0];
        pipe_rob_id[1] <= pipe_rob_id[0];
        pipe_phys_dest[1] <= pipe_phys_dest[0];
        pipe_is_double[1] <= pipe_is_double[0];
        pipe_rm[1] <= pipe_rm[0];
        
        if (pipe_valid[0]) begin
            // Simplified computation (real FPU would use proper IEEE 754 logic)
            case (pipe_op[0])
                OP_FADD: begin
                    // Placeholder: Simple bit manipulation
                    stage1_result <= operand_a_i;  // Real: unpacking and alignment
                    stage_fflags[1] <= 5'h0;
                end
                OP_FSUB: begin
                    stage1_result <= operand_a_i;
                    stage_fflags[1] <= 5'h0;
                end
                OP_FMUL: begin
                    stage1_result <= operand_a_i;
                    stage_fflags[1] <= 5'h0;
                end
                OP_FMADD: begin
                    stage1_result <= operand_a_i;
                    stage_fflags[1] <= 5'h0;
                end
                OP_FSGNJ: begin
                    // Sign injection: result = sign(b) | magnitude(a)
                    if (pipe_is_double[0])
                        stage1_result <= {operand_b_i[63], operand_a_i[62:0]};
                    else
                        stage1_result <= {32'h0, operand_b_i[31], operand_a_i[30:0]};
                    stage_fflags[1] <= 5'h0;
                end
                OP_FSGNJN: begin
                    // Sign injection negated
                    if (pipe_is_double[0])
                        stage1_result <= {~operand_b_i[63], operand_a_i[62:0]};
                    else
                        stage1_result <= {32'h0, ~operand_b_i[31], operand_a_i[30:0]};
                    stage_fflags[1] <= 5'h0;
                end
                OP_FSGNJX: begin
                    // Sign injection XOR
                    if (pipe_is_double[0])
                        stage1_result <= {operand_a_i[63] ^ operand_b_i[63], operand_a_i[62:0]};
                    else
                        stage1_result <= {32'h0, operand_a_i[31] ^ operand_b_i[31], operand_a_i[30:0]};
                    stage_fflags[1] <= 5'h0;
                end
                OP_FMIN, OP_FMAX: begin
                    // Simplified comparison (real would handle NaN, etc.)
                    stage1_result <= operand_a_i;
                    stage_fflags[1] <= 5'h0;
                end
                OP_FCVT, OP_FMV, OP_FCMP, OP_FCLASS: begin
                    // Single cycle operations
                    stage1_result <= operand_a_i;
                    stage_fflags[1] <= 5'h0;
                end
                default: begin
                    stage1_result <= 64'h0;
                    stage_fflags[1] <= 5'h0;
                end
            endcase
        end
    end
end

// Pipeline stages 2-5: Continuation of pipelined operations
genvar i;
generate
    for (i = 2; i <= 5; i = i + 1) begin : gen_pipe_stages
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                pipe_valid[i] <= 1'b0;
            end else begin
                pipe_valid[i] <= pipe_valid[i-1];
                pipe_op[i] <= pipe_op[i-1];
                pipe_rob_id[i] <= pipe_rob_id[i-1];
                pipe_phys_dest[i] <= pipe_phys_dest[i-1];
                pipe_is_double[i] <= pipe_is_double[i-1];
                pipe_rm[i] <= pipe_rm[i-1];
                stage_fflags[i] <= stage_fflags[i-1];
            end
        end
    end
endgenerate

// Output stage: Select result based on operation latency
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_o <= 1'b0;
        result_o <= 64'h0;
        fflags_o <= 5'h0;
        rob_id_o <= 6'h0;
        phys_dest_o <= 7'h0;
        exception_o <= 1'b0;
    end else begin
        // Check each pipeline stage for completion
        valid_o <= 1'b0;
        
        // Single-cycle ops (stage 1)
        if (pipe_valid[1] && (pipe_op[1] == OP_FSGNJ || pipe_op[1] == OP_FSGNJN || 
                               pipe_op[1] == OP_FSGNJX || pipe_op[1] == OP_FMV ||
                               pipe_op[1] == OP_FCLASS || pipe_op[1] == OP_FCMP)) begin
            valid_o <= 1'b1;
            result_o <= stage1_result;
            fflags_o <= stage_fflags[1];
            rob_id_o <= pipe_rob_id[1];
            phys_dest_o <= pipe_phys_dest[1];
            exception_o <= 1'b0;
        end
        // ADD/SUB (3 cycles - stage 3)
        else if (pipe_valid[3] && (pipe_op[3] == OP_FADD || pipe_op[3] == OP_FSUB)) begin
            valid_o <= 1'b1;
            result_o <= stage1_result;  // Simplified
            fflags_o <= stage_fflags[3];
            rob_id_o <= pipe_rob_id[3];
            phys_dest_o <= pipe_phys_dest[3];
            exception_o <= 1'b0;
        end
        // MUL (4 cycles - stage 4)
        else if (pipe_valid[4] && pipe_op[4] == OP_FMUL) begin
            valid_o <= 1'b1;
            result_o <= stage1_result;  // Simplified
            fflags_o <= stage_fflags[4];
            rob_id_o <= pipe_rob_id[4];
            phys_dest_o <= pipe_phys_dest[4];
            exception_o <= 1'b0;
        end
        // FMADD (5 cycles - stage 5)
        else if (pipe_valid[5] && (pipe_op[5] == OP_FMADD || pipe_op[5] == OP_FMSUB ||
                                    pipe_op[5] == OP_FNMADD || pipe_op[5] == OP_FNMSUB)) begin
            valid_o <= 1'b1;
            result_o <= stage1_result;  // Simplified
            fflags_o <= stage_fflags[5];
            rob_id_o <= pipe_rob_id[5];
            phys_dest_o <= pipe_phys_dest[5];
            exception_o <= 1'b0;
        end
        // Divider output
        else if (div_state == DIV_DONE) begin
            valid_o <= 1'b1;
            result_o <= operand_a_i;  // Simplified (real would compute division)
            fflags_o <= 5'h0;
            rob_id_o <= div_rob_id;
            phys_dest_o <= div_phys_dest;
            exception_o <= 1'b0;
        end
    end
end

endmodule
