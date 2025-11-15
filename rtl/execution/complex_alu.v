// ============================================================================
// Complex ALU - Clownfish RISC-V Processor
// ============================================================================
// Handles branches, comparisons, and miscellaneous operations
// Operations: Branch conditions, LUI, AUIPC, misc integer ops
// Latency: 1 cycle
// Throughput: 1 operation per cycle
// ============================================================================

`include "../../include/clownfish_config.vh"

module complex_alu (
    input  wire         clk,
    input  wire         rst_n,
    
    // Input operands
    input  wire         valid_i,
    input  wire [31:0]  operand_a_i,
    input  wire [31:0]  operand_b_i,
    input  wire [31:0]  pc_i,           // PC for branch/jump calculations
    input  wire [31:0]  imm_i,          // Immediate value
    input  wire [3:0]   op_i,           // Operation code
    input  wire [5:0]   rob_id_i,
    input  wire [6:0]   phys_dest_i,
    
    // Output result
    output reg          valid_o,
    output reg  [31:0]  result_o,
    output reg  [31:0]  branch_target_o,
    output reg          branch_taken_o,
    output reg  [5:0]   rob_id_o,
    output reg  [6:0]   phys_dest_o,
    output reg          exception_o,
    
    // Ready signal
    output wire         ready_o
);

// Complex ALU operation codes
localparam OP_BEQ    = 4'b0000;  // Branch if equal
localparam OP_BNE    = 4'b0001;  // Branch if not equal
localparam OP_BLT    = 4'b0010;  // Branch if less than (signed)
localparam OP_BGE    = 4'b0011;  // Branch if greater or equal (signed)
localparam OP_BLTU   = 4'b0100;  // Branch if less than (unsigned)
localparam OP_BGEU   = 4'b0101;  // Branch if greater or equal (unsigned)
localparam OP_JAL    = 4'b0110;  // Jump and link
localparam OP_JALR   = 4'b0111;  // Jump and link register
localparam OP_LUI    = 4'b1000;  // Load upper immediate
localparam OP_AUIPC  = 4'b1001;  // Add upper immediate to PC

// Always ready (single cycle)
assign ready_o = 1'b1;

// Intermediate signals
reg [31:0] calc_result;
reg [31:0] calc_target;
reg        calc_taken;

// Combinational logic
always @(*) begin
    calc_result = 32'h0;
    calc_target = 32'h0;
    calc_taken  = 1'b0;
    
    case (op_i)
        OP_BEQ: begin
            calc_taken  = (operand_a_i == operand_b_i);
            calc_target = pc_i + imm_i;
            calc_result = {31'h0, calc_taken};
        end
        
        OP_BNE: begin
            calc_taken  = (operand_a_i != operand_b_i);
            calc_target = pc_i + imm_i;
            calc_result = {31'h0, calc_taken};
        end
        
        OP_BLT: begin
            calc_taken  = ($signed(operand_a_i) < $signed(operand_b_i));
            calc_target = pc_i + imm_i;
            calc_result = {31'h0, calc_taken};
        end
        
        OP_BGE: begin
            calc_taken  = ($signed(operand_a_i) >= $signed(operand_b_i));
            calc_target = pc_i + imm_i;
            calc_result = {31'h0, calc_taken};
        end
        
        OP_BLTU: begin
            calc_taken  = (operand_a_i < operand_b_i);
            calc_target = pc_i + imm_i;
            calc_result = {31'h0, calc_taken};
        end
        
        OP_BGEU: begin
            calc_taken  = (operand_a_i >= operand_b_i);
            calc_target = pc_i + imm_i;
            calc_result = {31'h0, calc_taken};
        end
        
        OP_JAL: begin
            calc_taken  = 1'b1;
            calc_target = pc_i + imm_i;
            calc_result = pc_i + 32'd4;  // Return address
        end
        
        OP_JALR: begin
            calc_taken  = 1'b1;
            calc_target = (operand_a_i + imm_i) & ~32'h1;  // Clear LSB
            calc_result = pc_i + 32'd4;  // Return address
        end
        
        OP_LUI: begin
            calc_taken  = 1'b0;
            calc_target = 32'h0;
            calc_result = imm_i;  // Upper 20 bits already in place
        end
        
        OP_AUIPC: begin
            calc_taken  = 1'b0;
            calc_target = 32'h0;
            calc_result = pc_i + imm_i;
        end
        
        default: begin
            calc_taken  = 1'b0;
            calc_target = 32'h0;
            calc_result = 32'h0;
        end
    endcase
end

// Register output (1 cycle latency)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_o         <= 1'b0;
        result_o        <= 32'h0;
        branch_target_o <= 32'h0;
        branch_taken_o  <= 1'b0;
        rob_id_o        <= 6'h0;
        phys_dest_o     <= 7'h0;
        exception_o     <= 1'b0;
    end else begin
        valid_o         <= valid_i;
        result_o        <= calc_result;
        branch_target_o <= calc_target;
        branch_taken_o  <= calc_taken;
        rob_id_o        <= rob_id_i;
        phys_dest_o     <= phys_dest_i;
        exception_o     <= 1'b0;  // Complex ALU handles misalignment elsewhere
    end
end

endmodule
