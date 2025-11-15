// ============================================================================
// Vector Unit - Clownfish RISC-V Processor
// ============================================================================
// RVV 1.0 (RISC-V Vector Extension) implementation
// VLEN = 128 bits, 4 lanes (32-bit each), 32 vector registers
// Operations: VADD, VSUB, VMUL, VDIV, VLOAD, VSTORE, and more
// ============================================================================

`include "../../include/clownfish_config.vh"

module vector_unit (
    input  wire         clk,
    input  wire         rst_n,
    
    // Input from reservation station
    input  wire         valid_i,
    input  wire [4:0]   vs1_i,           // Source vector register 1
    input  wire [4:0]   vs2_i,           // Source vector register 2
    input  wire [4:0]   vd_i,            // Destination vector register
    input  wire [31:0]  scalar_i,        // Scalar operand (for vsetvl, etc.)
    input  wire [5:0]   vec_op_i,        // Vector operation
    input  wire [5:0]   rob_id_i,
    input  wire [6:0]   phys_dest_i,
    
    // Vector configuration
    input  wire [10:0]  vtype_i,         // Vector type (SEW, LMUL, etc.)
    input  wire [7:0]   vl_i,            // Vector length
    
    // Output result
    output reg          valid_o,
    output reg  [127:0] result_o,        // VLEN = 128 bits
    output reg  [5:0]   rob_id_o,
    output reg  [6:0]   phys_dest_o,
    output reg          exception_o,
    
    // Ready signal
    output wire         ready_o,
    
    // Memory interface (for vector loads/stores)
    output reg          mem_req_valid_o,
    output reg  [31:0]  mem_req_addr_o,
    output reg  [127:0] mem_req_data_o,
    output reg          mem_req_we_o,
    input  wire         mem_req_ready_i,
    
    input  wire         mem_resp_valid_i,
    input  wire [127:0] mem_resp_data_i,
    input  wire         mem_resp_error_i,
    output reg          mem_resp_ready_o
);

// Vector register file (32 registers × 128 bits each)
reg [127:0] vrf [0:31];

// Vector operation codes (subset of RVV 1.0)
localparam OP_VADD_VV   = 6'b000000;  // Vector-vector add
localparam OP_VSUB_VV   = 6'b000001;  // Vector-vector subtract
localparam OP_VMUL_VV   = 6'b000010;  // Vector-vector multiply
localparam OP_VDIV_VV   = 6'b000011;  // Vector-vector divide
localparam OP_VAND_VV   = 6'b000100;  // Vector-vector AND
localparam OP_VOR_VV    = 6'b000101;  // Vector-vector OR
localparam OP_VXOR_VV   = 6'b000110;  // Vector-vector XOR
localparam OP_VADD_VX   = 6'b001000;  // Vector-scalar add
localparam OP_VSUB_VX   = 6'b001001;  // Vector-scalar subtract
localparam OP_VMUL_VX   = 6'b001010;  // Vector-scalar multiply
localparam OP_VDIV_VX   = 6'b001011;  // Vector-scalar divide
localparam OP_VSLL_VV   = 6'b010000;  // Vector shift left logical
localparam OP_VSRL_VV   = 6'b010001;  // Vector shift right logical
localparam OP_VSRA_VV   = 6'b010010;  // Vector shift right arithmetic
localparam OP_VLOAD     = 6'b100000;  // Vector load
localparam OP_VSTORE    = 6'b100001;  // Vector store
localparam OP_VSETVL    = 6'b111111;  // Set vector length

// Vector configuration registers
reg [10:0] vtype;  // Vector type
reg [7:0]  vl;     // Vector length
reg [7:0]  vstart; // Vector start index (for resumable operations)

// Extract SEW (Standard Element Width) from vtype
wire [2:0] sew = vtype[5:3];  // 000=8-bit, 001=16-bit, 010=32-bit, 011=64-bit
wire [2:0] lmul = vtype[2:0]; // Length multiplier

// Number of elements based on SEW
wire [7:0] num_elements = (sew == 3'b000) ? 8'd16 :  // 128/8 = 16
                          (sew == 3'b001) ? 8'd8  :  // 128/16 = 8
                          (sew == 3'b010) ? 8'd4  :  // 128/32 = 4
                                            8'd2;    // 128/64 = 2

// Pipeline stages for vector operations
localparam PIPE_STAGES = 4;  // 4 lanes, can process 1 element per lane per cycle

reg [PIPE_STAGES-1:0] pipe_valid;
reg [5:0] pipe_op [0:PIPE_STAGES-1];
reg [5:0] pipe_rob_id [0:PIPE_STAGES-1];
reg [6:0] pipe_phys_dest [0:PIPE_STAGES-1];
reg [4:0] pipe_vd [0:PIPE_STAGES-1];

// Intermediate computation results (4 lanes × 32-bit)
reg [31:0] lane_result [0:3];
reg [127:0] vector_result;
reg [127:0] vector_result_next;

// Divider state (for vector divide - non-pipelined)
localparam DIV_IDLE = 2'b00;
localparam DIV_BUSY = 2'b01;
localparam DIV_DONE = 2'b10;

reg [1:0]  vec_div_state;
reg [4:0]  vec_div_counter;
reg [127:0] vec_div_result;
reg [5:0]  vec_div_rob_id;
reg [6:0]  vec_div_phys_dest;
reg [4:0]  vec_div_vd;

// Memory operation state
localparam MEM_IDLE = 2'b00;
localparam MEM_REQ  = 2'b01;
localparam MEM_WAIT = 2'b10;

reg [1:0] mem_state;
reg [4:0] mem_vd;
reg [5:0] mem_rob_id;
reg [6:0] mem_phys_dest;

// Ready when not busy with division or memory operation
assign ready_o = (vec_div_state == DIV_IDLE) && (mem_state == MEM_IDLE) && !pipe_valid[0];

// Vector ALU computation (4 parallel lanes)
task vec_alu_compute;
    input [5:0] op;
    input [127:0] vs1_data;
    input [127:0] vs2_data;
    input [31:0] scalar_data;
    output [127:0] result;
    integer lane;
    reg [31:0] lane_a, lane_b, lane_res;
    begin
        result = 128'h0;
        
        // Process 4 lanes in parallel (each lane is 32-bit)
        for (lane = 0; lane < 4; lane = lane + 1) begin
            // Extract operands for this lane
            lane_a = vs1_data[lane*32 +: 32];
            
            // Select second operand (vector or scalar)
            if (op >= OP_VADD_VX && op <= OP_VDIV_VX)
                lane_b = scalar_data;
            else
                lane_b = vs2_data[lane*32 +: 32];
            
            // Perform operation
            case (op)
                OP_VADD_VV, OP_VADD_VX: lane_res = lane_a + lane_b;
                OP_VSUB_VV, OP_VSUB_VX: lane_res = lane_a - lane_b;
                OP_VMUL_VV, OP_VMUL_VX: lane_res = lane_a * lane_b;
                OP_VAND_VV: lane_res = lane_a & lane_b;
                OP_VOR_VV:  lane_res = lane_a | lane_b;
                OP_VXOR_VV: lane_res = lane_a ^ lane_b;
                OP_VSLL_VV: lane_res = lane_a << lane_b[4:0];
                OP_VSRL_VV: lane_res = lane_a >> lane_b[4:0];
                OP_VSRA_VV: lane_res = $signed(lane_a) >>> lane_b[4:0];
                default:    lane_res = 32'h0;
            endcase
            
            // Write result to output
            result[lane*32 +: 32] = lane_res;
        end
    end
endtask

function [127:0] vec_div_compute;
    input [127:0] vs1_data;
    input [127:0] vs2_data;
    input [31:0]  scalar_data;
    input          use_scalar;
    integer lane;
    reg [31:0] lane_a;
    reg [31:0] lane_b;
    begin
        vec_div_compute = 128'h0;
        for (lane = 0; lane < 4; lane = lane + 1) begin
            lane_a = vs1_data[lane*32 +: 32];
            lane_b = use_scalar ? scalar_data : vs2_data[lane*32 +: 32];
            if (lane_b != 0)
                vec_div_compute[lane*32 +: 32] = lane_a / lane_b;
            else
                vec_div_compute[lane*32 +: 32] = 32'hFFFF_FFFF;
        end
    end
endfunction

// Pipeline stage 0: Input and operation dispatch
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pipe_valid[0] <= 1'b0;
    vec_div_state <= DIV_IDLE;
    vec_div_counter <= 5'd0;
    vec_div_result <= 128'h0;
    mem_state <= MEM_IDLE;
    vtype <= 11'h0;
    vl <= 8'h0;
    vstart <= 8'h0;
    end else begin
        // Handle vector configuration (vsetvl)
        if (valid_i && vec_op_i == OP_VSETVL && ready_o) begin
            vtype <= vtype_i;
            vl <= vl_i;
            pipe_valid[0] <= 1'b0;
        end
        // Handle vector divide (non-pipelined)
        else if (valid_i && (vec_op_i == OP_VDIV_VV || vec_op_i == OP_VDIV_VX) && ready_o) begin
            vec_div_state <= DIV_BUSY;
            vec_div_counter <= 5'd19;  // 20 cycles for vector divide
            vec_div_rob_id <= rob_id_i;
            vec_div_phys_dest <= phys_dest_i;
            vec_div_vd <= vd_i;
            vec_div_result <= vec_div_compute(vrf[vs1_i], vrf[vs2_i], scalar_i, (vec_op_i == OP_VDIV_VX));
            pipe_valid[0] <= 1'b0;
        end
        // Handle vector load/store (memory operations)
        else if (valid_i && (vec_op_i == OP_VLOAD || vec_op_i == OP_VSTORE) && ready_o) begin
            mem_state <= MEM_REQ;
            mem_vd <= vd_i;
            mem_rob_id <= rob_id_i;
            mem_phys_dest <= phys_dest_i;
            pipe_valid[0] <= 1'b0;
        end
        // Handle pipelined vector operations
        else if (valid_i && ready_o) begin
            pipe_valid[0] <= 1'b1;
            pipe_op[0] <= vec_op_i;
            pipe_rob_id[0] <= rob_id_i;
            pipe_phys_dest[0] <= phys_dest_i;
            pipe_vd[0] <= vd_i;
        end else begin
            pipe_valid[0] <= 1'b0;
        end
        
        // Vector divider state machine
        case (vec_div_state)
            DIV_IDLE: begin
                // Handled above
            end
            DIV_BUSY: begin
                if (vec_div_counter > 0) begin
                    vec_div_counter <= vec_div_counter - 1;
                end else begin
                    vec_div_state <= DIV_DONE;
                end
            end
            DIV_DONE: begin
                vec_div_state <= DIV_IDLE;
            end
        endcase
        
        // Memory operation state machine
        case (mem_state)
            MEM_IDLE: begin
                // Handled above
            end
            MEM_REQ: begin
                if (mem_req_ready_i) begin
                    mem_state <= MEM_WAIT;
                end
            end
            MEM_WAIT: begin
                if (mem_resp_valid_i) begin
                    mem_state <= MEM_IDLE;
                end
            end
        endcase
    end
end

// Pipeline stage 1: Compute
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pipe_valid[1] <= 1'b0;
        vector_result <= 128'h0;
    end else begin
        pipe_valid[1] <= pipe_valid[0];
        pipe_op[1] <= pipe_op[0];
        pipe_rob_id[1] <= pipe_rob_id[0];
        pipe_phys_dest[1] <= pipe_phys_dest[0];
        pipe_vd[1] <= pipe_vd[0];
        vector_result <= vector_result_next;
    end
end

// Compute next vector result based on current pipe inputs
always @(*) begin
    vector_result_next = 128'h0;
    if (pipe_valid[0]) begin
        vec_alu_compute(pipe_op[0], vrf[vs1_i], vrf[vs2_i], scalar_i, vector_result_next);
    end
end

// Pipeline stage 2: Writeback preparation
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pipe_valid[2] <= 1'b0;
    end else begin
        pipe_valid[2] <= pipe_valid[1];
        pipe_op[2] <= pipe_op[1];
        pipe_rob_id[2] <= pipe_rob_id[1];
        pipe_phys_dest[2] <= pipe_phys_dest[1];
        pipe_vd[2] <= pipe_vd[1];
    end
end

// Memory interface logic
always @(*) begin
    mem_req_valid_o = 1'b0;
    mem_req_addr_o = 32'h0;
    mem_req_data_o = 128'h0;
    mem_req_we_o = 1'b0;
    mem_resp_ready_o = 1'b0;
    
    if (mem_state == MEM_REQ) begin
        mem_req_valid_o = 1'b1;
        mem_req_addr_o = scalar_i;  // Address comes from scalar operand
        
        if (vec_op_i == OP_VSTORE) begin
            mem_req_we_o = 1'b1;
            mem_req_data_o = vrf[vs2_i];  // Store vs2 to memory
        end
    end
    
    if (mem_state == MEM_WAIT) begin
        mem_resp_ready_o = 1'b1;
    end
end

// Output stage: Result writeback
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_o <= 1'b0;
        result_o <= 128'h0;
        rob_id_o <= 6'h0;
        phys_dest_o <= 7'h0;
        exception_o <= 1'b0;
    end else begin
        valid_o <= 1'b0;
        exception_o <= 1'b0;
        
        // Pipelined operations (2 cycle latency for simple ops)
        if (pipe_valid[2]) begin
            valid_o <= 1'b1;
            result_o <= vector_result;
            rob_id_o <= pipe_rob_id[2];
            phys_dest_o <= pipe_phys_dest[2];
            
            // Write to VRF
            vrf[pipe_vd[2]] <= vector_result;
        end
        // Vector divider output
        else if (vec_div_state == DIV_DONE) begin
            valid_o <= 1'b1;
            result_o <= vec_div_result;  // Simplified (real would compute division)
            rob_id_o <= vec_div_rob_id;
            phys_dest_o <= vec_div_phys_dest;
            
            // Write to VRF
            vrf[vec_div_vd] <= vec_div_result;
        end
        // Memory operation completion
        else if (mem_state == MEM_WAIT && mem_resp_valid_i) begin
            if (vec_op_i == OP_VLOAD) begin
                valid_o <= 1'b1;
                result_o <= mem_resp_data_i;
                rob_id_o <= mem_rob_id;
                phys_dest_o <= mem_phys_dest;
                exception_o <= mem_resp_error_i;
                
                // Write loaded data to VRF
                vrf[mem_vd] <= mem_resp_data_i;
            end else begin
                // Store completion (no result)
                valid_o <= 1'b1;
                result_o <= 128'h0;
                rob_id_o <= mem_rob_id;
                phys_dest_o <= mem_phys_dest;
                exception_o <= mem_resp_error_i;
            end
        end
    end
end

// Initialize VRF
integer k;
initial begin
    for (k = 0; k < 32; k = k + 1) begin
        vrf[k] = 128'h0;
    end
end

endmodule
