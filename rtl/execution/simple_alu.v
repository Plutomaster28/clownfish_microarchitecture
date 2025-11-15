// ============================================================================
// Simple ALU - Clownfish RISC-V Processor
// ============================================================================
// Single-cycle integer ALU for basic operations
// Operations: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
// Latency: 1 cycle
// Throughput: 1 operation per cycle
// ============================================================================

`include "../../include/clownfish_config.vh"

module simple_alu #(
    parameter UNIT_ID = 0  // 0 or 1 for dual ALU setup
)(
    input  wire         clk,
    input  wire         rst_n,
    
    // Input operands
    input  wire         valid_i,
    input  wire [31:0]  operand_a_i,
    input  wire [31:0]  operand_b_i,
    input  wire [3:0]   alu_op_i,      // ALU operation
    input  wire [5:0]   rob_id_i,      // ROB entry ID
    input  wire [6:0]   phys_dest_i,   // Physical destination register
    
    // Output result
    output reg          valid_o,
    output reg  [31:0]  result_o,
    output reg  [5:0]   rob_id_o,
    output reg  [6:0]   phys_dest_o,
    output reg          exception_o,
    
    // Ready signal
    output wire         ready_o
);

// ALU operation codes
localparam ALU_ADD  = 4'b0000;
localparam ALU_SUB  = 4'b0001;
localparam ALU_AND  = 4'b0010;
localparam ALU_OR   = 4'b0011;
localparam ALU_XOR  = 4'b0100;
localparam ALU_SLL  = 4'b0101;  // Shift left logical
localparam ALU_SRL  = 4'b0110;  // Shift right logical
localparam ALU_SRA  = 4'b0111;  // Shift right arithmetic
localparam ALU_SLT  = 4'b1000;  // Set less than (signed)
localparam ALU_SLTU = 4'b1001;  // Set less than (unsigned)

// Simple ALU is always ready (single cycle, non-pipelined)
assign ready_o = 1'b1;

// Intermediate result
reg [31:0] alu_result;

// Combinational ALU logic
always @(*) begin
    alu_result = 32'h0;
    
    case (alu_op_i)
        ALU_ADD:  alu_result = operand_a_i + operand_b_i;
        ALU_SUB:  alu_result = operand_a_i - operand_b_i;
        ALU_AND:  alu_result = operand_a_i & operand_b_i;
        ALU_OR:   alu_result = operand_a_i | operand_b_i;
        ALU_XOR:  alu_result = operand_a_i ^ operand_b_i;
        ALU_SLL:  alu_result = operand_a_i << operand_b_i[4:0];
        ALU_SRL:  alu_result = operand_a_i >> operand_b_i[4:0];
        ALU_SRA:  alu_result = $signed(operand_a_i) >>> operand_b_i[4:0];
        ALU_SLT:  alu_result = ($signed(operand_a_i) < $signed(operand_b_i)) ? 32'd1 : 32'd0;
        ALU_SLTU: alu_result = (operand_a_i < operand_b_i) ? 32'd1 : 32'd0;
        default:  alu_result = 32'h0;
    endcase
end

// Register output (1 cycle latency)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_o     <= 1'b0;
        result_o    <= 32'h0;
        rob_id_o    <= 6'h0;
        phys_dest_o <= 7'h0;
        exception_o <= 1'b0;
    end else begin
        valid_o     <= valid_i;
        result_o    <= alu_result;
        rob_id_o    <= rob_id_i;
        phys_dest_o <= phys_dest_i;
        exception_o <= 1'b0;  // Simple ALU never generates exceptions
    end
end

endmodule
