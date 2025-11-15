// ============================================================================
// Return Address Stack (RAS) - Clownfish RISC-V Processor
// ============================================================================
// 32-entry circular stack for return address prediction
// Handles function call/return prediction
// ============================================================================

`include "../../include/clownfish_config.vh"

module ras (
    input  wire         clk,
    input  wire         rst_n,
    
    // Push interface (on function call)
    input  wire         push_valid_i,
    input  wire [31:0]  push_addr_i,     // Return address (PC+4)
    
    // Pop interface (on return)
    input  wire         pop_valid_i,
    output reg  [31:0]  pop_addr_o,
    output reg          pop_valid_o,     // Stack not empty
    
    // Speculative recovery (on misprediction)
    input  wire         recover_valid_i,
    input  wire [4:0]   recover_tos_i,   // Restore TOS pointer

    // Observable top-of-stack pointer (for recovery snapshot)
    output wire [RAS_PTR_BITS-1:0] tos_o
);

// RAS parameters
localparam RAS_DEPTH = `RAS_DEPTH;       // 32 entries
localparam RAS_PTR_BITS = 5;             // log2(32)

// RAS storage
reg [31:0] ras_stack [0:RAS_DEPTH-1];
reg [RAS_PTR_BITS-1:0] tos;              // Top-of-stack pointer
reg [RAS_PTR_BITS:0] count;              // Number of valid entries (0-32)

assign tos_o = tos;

// Push operation (on function call)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tos   <= {RAS_PTR_BITS{1'b0}};
        count <= {(RAS_PTR_BITS+1){1'b0}};
    end else if (recover_valid_i) begin
        // Restore TOS pointer on misprediction
        tos <= recover_tos_i;
        // Note: Count not precisely tracked during speculation
        // Conservative: assume stack might be full
        count <= RAS_DEPTH;
    end else if (push_valid_i && !pop_valid_i) begin
        // Push only
        ras_stack[tos] <= push_addr_i;
        tos <= tos + 1'b1;  // Wrap around automatically
        if (count < RAS_DEPTH)
            count <= count + 1'b1;
    end else if (!push_valid_i && pop_valid_i) begin
        // Pop only
        if (count > 0) begin
            tos <= tos - 1'b1;  // Wrap around automatically
            count <= count - 1'b1;
        end
    end else if (push_valid_i && pop_valid_i) begin
        // Push and pop simultaneously
        // Push to current TOS, then leave pointer unchanged
        ras_stack[tos - 1'b1] <= push_addr_i;
        // TOS and count unchanged
    end
end

// Pop operation (combinational read)
always @(*) begin
    if (count > 0) begin
        pop_addr_o  = ras_stack[tos - 1'b1];  // Read from TOS-1
        pop_valid_o = 1'b1;
    end else begin
        pop_addr_o  = 32'h0;
        pop_valid_o = 1'b0;
    end
end

// Initialize stack
integer i;
initial begin
    for (i = 0; i < RAS_DEPTH; i = i + 1) begin
        ras_stack[i] = 32'h0;
    end
end

endmodule
