// ============================================================================
// Load-Store Unit - Clownfish RISC-V Processor
// ============================================================================
// Handles all memory operations: loads, stores, atomic operations
// Features: 16-entry load queue, 8-entry store buffer
// Supports: RV32I memory ops, RV32A atomic ops
// ============================================================================

`include "../../include/clownfish_config.vh"

module lsu (
    input  wire         clk,
    input  wire         rst_n,
    
    // Input from reservation station
    input  wire         valid_i,
    input  wire [31:0]  addr_i,          // Virtual address
    input  wire [31:0]  store_data_i,    // Data to store
    input  wire [3:0]   mem_op_i,        // Memory operation
    input  wire [5:0]   rob_id_i,
    input  wire [6:0]   phys_dest_i,
    input  wire         is_store_i,      // 1=store, 0=load
    
    // Output result
    output reg          valid_o,
    output reg  [31:0]  result_o,
    output reg  [5:0]   rob_id_o,
    output reg  [6:0]   phys_dest_o,
    output reg          exception_o,
    output reg  [3:0]   exception_cause_o,
    
    // Ready signal
    output wire         ready_o,
    
    // L1 D-Cache interface
    output reg          dcache_req_valid_o,
    output reg  [31:0]  dcache_req_addr_o,
    output reg  [31:0]  dcache_req_data_o,
    output reg          dcache_req_we_o,    // Write enable
    output reg  [3:0]   dcache_req_be_o,    // Byte enable
    input  wire         dcache_req_ready_i,
    
    input  wire         dcache_resp_valid_i,
    input  wire [31:0]  dcache_resp_data_i,
    input  wire         dcache_resp_error_i,
    output reg          dcache_resp_ready_o,
    
    // MMU interface for address translation
    output reg  [31:0]  mmu_vaddr_o,
    input  wire [31:0]  mmu_paddr_i,
    input  wire         mmu_valid_i,
    input  wire         mmu_page_fault_i,
    
    // Store commit signal from ROB
    input  wire         store_commit_i,
    input  wire [5:0]   store_commit_rob_id_i,
    
    // Fence/flush interface
    input  wire         fence_i,
    input  wire         flush_i
);

// Memory operation codes
localparam OP_LB   = 4'b0000;  // Load byte (signed)
localparam OP_LH   = 4'b0001;  // Load halfword (signed)
localparam OP_LW   = 4'b0010;  // Load word
localparam OP_LBU  = 4'b0100;  // Load byte (unsigned)
localparam OP_LHU  = 4'b0101;  // Load halfword (unsigned)
localparam OP_SB   = 4'b1000;  // Store byte
localparam OP_SH   = 4'b1001;  // Store halfword
localparam OP_SW   = 4'b1010;  // Store word
localparam OP_AMO  = 4'b1100;  // Atomic memory operation

// Load queue (16 entries)
localparam LQ_DEPTH = `LOAD_QUEUE_DEPTH;
reg [LQ_DEPTH-1:0] lq_valid;
reg [31:0] lq_addr [0:LQ_DEPTH-1];
reg [3:0]  lq_op [0:LQ_DEPTH-1];
reg [5:0]  lq_rob_id [0:LQ_DEPTH-1];
reg [6:0]  lq_phys_dest [0:LQ_DEPTH-1];
reg [LQ_DEPTH-1:0] lq_addr_valid;  // Address computed
reg [LQ_DEPTH-1:0] lq_issued;      // Issued to cache

// Store buffer (8 entries)
localparam SB_DEPTH = `STORE_BUFFER_DEPTH;
reg [SB_DEPTH-1:0] sb_valid;
reg [31:0] sb_addr [0:SB_DEPTH-1];
reg [31:0] sb_data [0:SB_DEPTH-1];
reg [3:0]  sb_op [0:SB_DEPTH-1];
reg [5:0]  sb_rob_id [0:SB_DEPTH-1];
reg [SB_DEPTH-1:0] sb_committed;   // Committed by ROB
reg [SB_DEPTH-1:0] sb_issued;      // Issued to cache

// Free entry pointers
reg [3:0] lq_head;  // Oldest entry
reg [3:0] lq_tail;  // Next free entry
reg [2:0] sb_head;  // Oldest entry
reg [2:0] sb_tail;  // Next free entry

// Ready when queues not full
wire lq_full = (lq_tail + 1) == lq_head;
wire sb_full = (sb_tail + 1) == sb_head;
assign ready_o = is_store_i ? !sb_full : !lq_full;

// State machine for memory disambiguation
localparam ST_IDLE       = 2'b00;
localparam ST_ADDR_TRANS = 2'b01;
localparam ST_CACHE_REQ  = 2'b10;
localparam ST_WAIT_RESP  = 2'b11;

reg [1:0] state;
reg [3:0] current_lq_idx;
reg [2:0] current_sb_idx;

// Exception causes
localparam EXC_LOAD_MISALIGNED  = 4'd4;
localparam EXC_LOAD_ACCESS      = 4'd5;
localparam EXC_STORE_MISALIGNED = 4'd6;
localparam EXC_STORE_ACCESS     = 4'd7;
localparam EXC_LOAD_PAGE_FAULT  = 4'd13;
localparam EXC_STORE_PAGE_FAULT = 4'd15;

// Misalignment check
function is_misaligned;
    input [31:0] addr;
    input [3:0]  op;
    begin
        case (op)
            OP_LH, OP_LHU, OP_SH: is_misaligned = addr[0];
            OP_LW, OP_SW:         is_misaligned = |addr[1:0];
            default:              is_misaligned = 1'b0;
        endcase
    end
endfunction

// Generate byte enable from operation
function [3:0] gen_byte_enable;
    input [31:0] addr;
    input [3:0]  op;
    begin
        case (op)
            OP_SB:  gen_byte_enable = 4'b0001 << addr[1:0];
            OP_SH:  gen_byte_enable = 4'b0011 << {addr[1], 1'b0};
            OP_SW:  gen_byte_enable = 4'b1111;
            default: gen_byte_enable = 4'b1111;
        endcase
    end
endfunction

// Loop variable for synthesis
integer idx;

// Combined queue management and completion logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        lq_valid       <= {LQ_DEPTH{1'b0}};
        lq_addr_valid  <= {LQ_DEPTH{1'b0}};
        lq_issued      <= {LQ_DEPTH{1'b0}};
        sb_valid       <= {SB_DEPTH{1'b0}};
        sb_committed   <= {SB_DEPTH{1'b0}};
        sb_issued      <= {SB_DEPTH{1'b0}};
        lq_head        <= 4'h0;
        lq_tail        <= 4'h0;
        sb_head        <= 3'h0;
        sb_tail        <= 3'h0;
        state          <= ST_IDLE;
        current_lq_idx <= 4'h0;
        current_sb_idx <= 3'h0;
        mmu_vaddr_o    <= 32'h0;
        valid_o        <= 1'b0;
        result_o       <= 32'h0;
        rob_id_o       <= 6'h0;
        phys_dest_o    <= 7'h0;
        exception_o    <= 1'b0;
        exception_cause_o <= 4'h0;
        for (idx = 0; idx < LQ_DEPTH; idx = idx + 1) begin
            lq_addr[idx]      <= 32'h0;
            lq_op[idx]        <= 4'h0;
            lq_rob_id[idx]    <= 6'h0;
            lq_phys_dest[idx] <= 7'h0;
        end
        for (idx = 0; idx < SB_DEPTH; idx = idx + 1) begin
            sb_addr[idx]   <= 32'h0;
            sb_data[idx]   <= 32'h0;
            sb_op[idx]     <= 4'h0;
            sb_rob_id[idx] <= 6'h0;
        end
    end else begin
        valid_o        <= 1'b0;
        exception_o    <= 1'b0;
        exception_cause_o <= 4'h0;

        if (flush_i) begin
            lq_valid      <= {LQ_DEPTH{1'b0}};
            lq_addr_valid <= {LQ_DEPTH{1'b0}};
            lq_issued     <= {LQ_DEPTH{1'b0}};
            sb_valid      <= {SB_DEPTH{1'b0}};
            sb_committed  <= {SB_DEPTH{1'b0}};
            sb_issued     <= {SB_DEPTH{1'b0}};
            lq_tail       <= lq_head;
            sb_tail       <= sb_head;
            state         <= ST_IDLE;
        end else begin
            if (store_commit_i) begin
                for (idx = 0; idx < SB_DEPTH; idx = idx + 1) begin
                    if (sb_valid[idx] && sb_rob_id[idx] == store_commit_rob_id_i) begin
                        sb_committed[idx] <= 1'b1;
                    end
                end
            end

            if (valid_i && ready_o) begin
                if (is_misaligned(addr_i, mem_op_i)) begin
                    valid_o        <= 1'b1;
                    exception_o    <= 1'b1;
                    exception_cause_o <= is_store_i ? EXC_STORE_MISALIGNED : EXC_LOAD_MISALIGNED;
                    rob_id_o       <= rob_id_i;
                    phys_dest_o    <= phys_dest_i;
                    result_o       <= 32'h0;
                end else if (!is_store_i) begin
                    lq_valid[lq_tail]      <= 1'b1;
                    lq_addr[lq_tail]       <= addr_i;
                    lq_op[lq_tail]         <= mem_op_i;
                    lq_rob_id[lq_tail]     <= rob_id_i;
                    lq_phys_dest[lq_tail]  <= phys_dest_i;
                    lq_addr_valid[lq_tail] <= 1'b1;
                    lq_issued[lq_tail]     <= 1'b0;
                    lq_tail                <= lq_tail + 1;
                end else begin
                    sb_valid[sb_tail]     <= 1'b1;
                    sb_addr[sb_tail]      <= addr_i;
                    sb_data[sb_tail]      <= store_data_i;
                    sb_op[sb_tail]        <= mem_op_i;
                    sb_rob_id[sb_tail]    <= rob_id_i;
                    sb_committed[sb_tail] <= 1'b0;
                    sb_issued[sb_tail]    <= 1'b0;
                    sb_tail               <= sb_tail + 1;
                end
            end

            case (state)
                ST_IDLE: begin
                    if (lq_valid[lq_head] && lq_addr_valid[lq_head] && !lq_issued[lq_head]) begin
                        current_lq_idx <= lq_head;
                        mmu_vaddr_o    <= lq_addr[lq_head];
                        state          <= ST_ADDR_TRANS;
                    end else if (sb_valid[sb_head] && sb_committed[sb_head] && !sb_issued[sb_head]) begin
                        current_sb_idx <= sb_head;
                        mmu_vaddr_o    <= sb_addr[sb_head];
                        state          <= ST_ADDR_TRANS;
                    end
                end

                ST_ADDR_TRANS: begin
                    if (mmu_valid_i) begin
                        if (mmu_page_fault_i) begin
                            state <= ST_IDLE;
                            if (lq_valid[current_lq_idx] && !lq_issued[current_lq_idx]) begin
                                valid_o        <= 1'b1;
                                exception_o    <= 1'b1;
                                exception_cause_o <= EXC_LOAD_PAGE_FAULT;
                                rob_id_o       <= lq_rob_id[current_lq_idx];
                                phys_dest_o    <= lq_phys_dest[current_lq_idx];
                                result_o       <= 32'h0;

                                lq_valid[current_lq_idx]      <= 1'b0;
                                lq_addr_valid[current_lq_idx] <= 1'b0;
                                lq_issued[current_lq_idx]     <= 1'b0;
                                if (current_lq_idx == lq_head)
                                    lq_head <= lq_head + 1;
                            end else if (sb_valid[current_sb_idx] && !sb_issued[current_sb_idx]) begin
                                valid_o        <= 1'b1;
                                exception_o    <= 1'b1;
                                exception_cause_o <= EXC_STORE_PAGE_FAULT;
                                rob_id_o       <= sb_rob_id[current_sb_idx];

                                sb_valid[current_sb_idx]     <= 1'b0;
                                sb_committed[current_sb_idx] <= 1'b0;
                                sb_issued[current_sb_idx]    <= 1'b0;
                                if (current_sb_idx == sb_head)
                                    sb_head <= sb_head + 1;
                            end
                        end else begin
                            state <= ST_CACHE_REQ;
                        end
                    end
                end

                ST_CACHE_REQ: begin
                    if (dcache_req_ready_i) begin
                        state <= ST_WAIT_RESP;
                        if (lq_valid[current_lq_idx] && !lq_issued[current_lq_idx])
                            lq_issued[current_lq_idx] <= 1'b1;
                        else if (sb_valid[current_sb_idx] && !sb_issued[current_sb_idx])
                            sb_issued[current_sb_idx] <= 1'b1;
                    end
                end

                ST_WAIT_RESP: begin
                    if (dcache_resp_valid_i) begin
                        state <= ST_IDLE;
                        if (lq_valid[current_lq_idx]) begin
                            valid_o     <= 1'b1;
                            rob_id_o    <= lq_rob_id[current_lq_idx];
                            phys_dest_o <= lq_phys_dest[current_lq_idx];

                            if (dcache_resp_error_i) begin
                                exception_o    <= 1'b1;
                                exception_cause_o <= EXC_LOAD_ACCESS;
                                result_o       <= 32'h0;
                            end else begin
                                case (lq_op[current_lq_idx])
                                    OP_LB:  result_o <= {{24{dcache_resp_data_i[7]}},  dcache_resp_data_i[7:0]};
                                    OP_LH:  result_o <= {{16{dcache_resp_data_i[15]}}, dcache_resp_data_i[15:0]};
                                    OP_LW:  result_o <= dcache_resp_data_i;
                                    OP_LBU: result_o <= {24'h0, dcache_resp_data_i[7:0]};
                                    OP_LHU: result_o <= {16'h0, dcache_resp_data_i[15:0]};
                                    default: result_o <= dcache_resp_data_i;
                                endcase
                            end

                            lq_valid[current_lq_idx]      <= 1'b0;
                            lq_addr_valid[current_lq_idx] <= 1'b0;
                            lq_issued[current_lq_idx]     <= 1'b0;
                            if (current_lq_idx == lq_head)
                                lq_head <= lq_head + 1;
                        end else if (sb_valid[current_sb_idx]) begin
                            if (dcache_resp_error_i) begin
                                valid_o        <= 1'b1;
                                exception_o    <= 1'b1;
                                exception_cause_o <= EXC_STORE_ACCESS;
                                rob_id_o       <= sb_rob_id[current_sb_idx];
                            end

                            sb_valid[current_sb_idx]     <= 1'b0;
                            sb_committed[current_sb_idx] <= 1'b0;
                            sb_issued[current_sb_idx]    <= 1'b0;
                            if (current_sb_idx == sb_head)
                                sb_head <= sb_head + 1;
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
end

// D-cache interface logic
always @(*) begin
    dcache_req_valid_o = 1'b0;
    dcache_req_addr_o = 32'h0;
    dcache_req_data_o = 32'h0;
    dcache_req_we_o = 1'b0;
    dcache_req_be_o = 4'h0;
    dcache_resp_ready_o = 1'b0;
    
    if (state == ST_CACHE_REQ) begin
        dcache_req_valid_o = 1'b1;
        
        // Check if load or store
        if (lq_valid[current_lq_idx] && !lq_issued[current_lq_idx]) begin
            // Load
            dcache_req_addr_o = mmu_paddr_i;
            dcache_req_we_o = 1'b0;
            dcache_req_be_o = 4'hF;
        end else if (sb_valid[current_sb_idx] && !sb_issued[current_sb_idx]) begin
            // Store
            dcache_req_addr_o = mmu_paddr_i;
            dcache_req_data_o = sb_data[current_sb_idx];
            dcache_req_we_o = 1'b1;
            dcache_req_be_o = gen_byte_enable(sb_addr[current_sb_idx], sb_op[current_sb_idx]);
        end
    end
    
    if (state == ST_WAIT_RESP) begin
        dcache_resp_ready_o = 1'b1;
    end
end

endmodule
