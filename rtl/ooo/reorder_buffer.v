// ============================================================================
// Reorder Buffer (ROB) - Clownfish RISC-V Processor
// ============================================================================
// 64-entry circular buffer for in-order commit of out-of-order execution
// Ensures precise exceptions and architectural state consistency
// ============================================================================

`include "../../include/clownfish_config.vh"

module reorder_buffer (
    input  wire         clk,
    input  wire         rst_n,
    
    // Allocation interface (from dispatch)
    input  wire         alloc_valid_i,
    input  wire [31:0]  alloc_pc_i,
    input  wire [4:0]   alloc_arch_dest_i,      // Architectural register
    input  wire [6:0]   alloc_phys_dest_i,      // Physical register
    input  wire [6:0]   alloc_phys_dest_old_i,  // Old physical register (for freeing)
    input  wire         alloc_is_store_i,
    input  wire         alloc_is_branch_i,
    input  wire         alloc_is_fp_i,
    input  wire         alloc_is_vec_i,
    output wire         alloc_ready_o,
    output wire [5:0]   alloc_rob_id_o,         // Assigned ROB ID
    
    // Completion interface (from execution units)
    input  wire         complete_valid_i,
    input  wire [5:0]   complete_rob_id_i,
    input  wire [31:0]  complete_result_i,
    input  wire         complete_exception_i,
    input  wire [3:0]   complete_exception_cause_i,
    input  wire [31:0]  complete_branch_target_i,
    input  wire         complete_branch_taken_i,
    input  wire         complete_branch_mispredict_i,
    
    // Commit interface
    output reg          commit_valid_o,
    output reg  [5:0]   commit_rob_id_o,
    output reg  [4:0]   commit_arch_dest_o,
    output reg  [6:0]   commit_phys_dest_o,
    output reg  [6:0]   commit_phys_dest_old_o, // For freeing
    output reg  [31:0]  commit_result_o,
    output reg          commit_is_store_o,
    output reg          commit_is_branch_o,
    output reg          commit_is_fp_o,
    output reg          commit_is_vec_o,
    
    // Exception/flush interface
    output reg          exception_o,
    output reg  [3:0]   exception_cause_o,
    output reg  [31:0]  exception_pc_o,
    output reg          flush_o,
    output reg  [31:0]  flush_target_o,
    
    // Store commit signal (to LSU)
    output reg          store_commit_valid_o,
    output reg  [5:0]   store_commit_rob_id_o,
    
    // Status signals
    output wire         full_o,
    output wire         empty_o,
    output wire [6:0]   count_o
);

// ROB parameters
localparam ROB_ENTRIES = `ROB_ENTRIES;  // 64 entries
localparam ROB_PTR_WIDTH = 6;           // log2(64)

// ROB entry structure
reg [31:0]  rob_pc          [0:ROB_ENTRIES-1];
reg [4:0]   rob_arch_dest   [0:ROB_ENTRIES-1];
reg [6:0]   rob_phys_dest   [0:ROB_ENTRIES-1];
reg [6:0]   rob_phys_old    [0:ROB_ENTRIES-1];
reg [31:0]  rob_result      [0:ROB_ENTRIES-1];
reg [3:0]   rob_exc_cause   [0:ROB_ENTRIES-1];
reg [31:0]  rob_branch_tgt  [0:ROB_ENTRIES-1];

// ROB entry flags
reg         rob_valid       [0:ROB_ENTRIES-1];
reg         rob_completed   [0:ROB_ENTRIES-1];
reg         rob_exception   [0:ROB_ENTRIES-1];
reg         rob_is_store    [0:ROB_ENTRIES-1];
reg         rob_is_branch   [0:ROB_ENTRIES-1];
reg         rob_is_fp       [0:ROB_ENTRIES-1];
reg         rob_is_vec      [0:ROB_ENTRIES-1];
reg         rob_branch_taken [0:ROB_ENTRIES-1];
reg         rob_branch_mispredict [0:ROB_ENTRIES-1];

// ROB pointers (circular buffer)
reg [ROB_PTR_WIDTH-1:0] head;  // Oldest entry (commit point)
reg [ROB_PTR_WIDTH-1:0] tail;  // Next free entry (allocation point)
reg [6:0] entry_count;         // Number of valid entries

// Status signals
assign full_o  = (entry_count == ROB_ENTRIES);
assign empty_o = (entry_count == 0);
assign count_o = entry_count;
assign alloc_ready_o = !full_o;
assign alloc_rob_id_o = tail;

// Loop variable and local regs for synthesis
integer idx;
reg flush_event;
reg [ROB_PTR_WIDTH-1:0] head_next;
reg [ROB_PTR_WIDTH-1:0] tail_next;
integer entry_count_next;

// Combined allocation, completion, and commit logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (idx = 0; idx < ROB_ENTRIES; idx = idx + 1) begin
            rob_valid[idx]            <= 1'b0;
            rob_completed[idx]        <= 1'b0;
            rob_exception[idx]        <= 1'b0;
            rob_is_store[idx]         <= 1'b0;
            rob_is_branch[idx]        <= 1'b0;
            rob_is_fp[idx]            <= 1'b0;
            rob_is_vec[idx]           <= 1'b0;
            rob_branch_taken[idx]     <= 1'b0;
            rob_branch_mispredict[idx]<= 1'b0;
            rob_pc[idx]               <= 32'h0;
            rob_arch_dest[idx]        <= 5'h0;
            rob_phys_dest[idx]        <= 7'h0;
            rob_phys_old[idx]         <= 7'h0;
            rob_result[idx]           <= 32'h0;
            rob_exc_cause[idx]        <= 4'h0;
            rob_branch_tgt[idx]       <= 32'h0;
        end
        head                 <= 6'h0;
        tail                 <= 6'h0;
        entry_count          <= 7'h0;
        commit_valid_o       <= 1'b0;
        commit_rob_id_o      <= 6'h0;
        commit_arch_dest_o   <= 5'h0;
        commit_phys_dest_o   <= 7'h0;
        commit_phys_dest_old_o <= 7'h0;
        commit_result_o      <= 32'h0;
        commit_is_store_o    <= 1'b0;
        commit_is_branch_o   <= 1'b0;
        commit_is_fp_o       <= 1'b0;
        commit_is_vec_o      <= 1'b0;
        exception_o          <= 1'b0;
        exception_cause_o    <= 4'h0;
        exception_pc_o       <= 32'h0;
        flush_o              <= 1'b0;
        flush_target_o       <= 32'h0;
        store_commit_valid_o <= 1'b0;
        store_commit_rob_id_o<= 6'h0;
    end else begin
        commit_valid_o       <= 1'b0;
        exception_o          <= 1'b0;
        flush_o              <= 1'b0;
        store_commit_valid_o <= 1'b0;

        flush_event      = 1'b0;
        head_next        = head;
        tail_next        = tail;
        entry_count_next = entry_count;

        if (complete_valid_i && !flush_o) begin
            if (rob_valid[complete_rob_id_i]) begin
                rob_completed[complete_rob_id_i]        <= 1'b1;
                rob_result[complete_rob_id_i]           <= complete_result_i;
                rob_exception[complete_rob_id_i]        <= complete_exception_i;
                rob_exc_cause[complete_rob_id_i]        <= complete_exception_cause_i;
                rob_branch_tgt[complete_rob_id_i]       <= complete_branch_target_i;
                rob_branch_taken[complete_rob_id_i]     <= complete_branch_taken_i;
                rob_branch_mispredict[complete_rob_id_i]<= complete_branch_mispredict_i;
            end
        end

        if (rob_valid[head] && rob_completed[head]) begin
            if (rob_exception[head]) begin
                exception_o       <= 1'b1;
                exception_cause_o <= rob_exc_cause[head];
                exception_pc_o    <= rob_pc[head];
                flush_o           <= 1'b1;
                flush_target_o    <= rob_pc[head];
                flush_event       = 1'b1;
            end else if (rob_is_branch[head] && rob_branch_mispredict[head]) begin
                flush_o        <= 1'b1;
                flush_target_o <= rob_branch_taken[head] ? rob_branch_tgt[head] : (rob_pc[head] + 32'd4);
                flush_event    = 1'b1;

                commit_valid_o       <= 1'b1;
                commit_rob_id_o      <= head;
                commit_arch_dest_o   <= rob_arch_dest[head];
                commit_phys_dest_o   <= rob_phys_dest[head];
                commit_phys_dest_old_o <= rob_phys_old[head];
                commit_result_o      <= rob_result[head];
                commit_is_store_o    <= rob_is_store[head];
                commit_is_branch_o   <= rob_is_branch[head];
                commit_is_fp_o       <= rob_is_fp[head];
                commit_is_vec_o      <= rob_is_vec[head];
            end else begin
                commit_valid_o       <= 1'b1;
                commit_rob_id_o      <= head;
                commit_arch_dest_o   <= rob_arch_dest[head];
                commit_phys_dest_o   <= rob_phys_dest[head];
                commit_phys_dest_old_o <= rob_phys_old[head];
                commit_result_o      <= rob_result[head];
                commit_is_store_o    <= rob_is_store[head];
                commit_is_branch_o   <= rob_is_branch[head];
                commit_is_fp_o       <= rob_is_fp[head];
                commit_is_vec_o      <= rob_is_vec[head];

                if (rob_is_store[head]) begin
                    store_commit_valid_o  <= 1'b1;
                    store_commit_rob_id_o <= head;
                end
            end

            rob_valid[head]            <= 1'b0;
            rob_completed[head]        <= 1'b0;
            rob_exception[head]        <= 1'b0;
            rob_branch_mispredict[head]<= 1'b0;
            rob_branch_taken[head]     <= 1'b0;

            if (entry_count_next > 0)
                entry_count_next = entry_count_next - 1;

            head_next = head + 1;
        end

        if (alloc_valid_i && alloc_ready_o) begin
            rob_valid[tail]            <= 1'b1;
            rob_completed[tail]        <= 1'b0;
            rob_exception[tail]        <= 1'b0;
            rob_pc[tail]               <= alloc_pc_i;
            rob_arch_dest[tail]        <= alloc_arch_dest_i;
            rob_phys_dest[tail]        <= alloc_phys_dest_i;
            rob_phys_old[tail]         <= alloc_phys_dest_old_i;
            rob_result[tail]           <= 32'h0;
            rob_exc_cause[tail]        <= 4'h0;
            rob_branch_tgt[tail]       <= 32'h0;
            rob_branch_taken[tail]     <= 1'b0;
            rob_branch_mispredict[tail]<= 1'b0;
            rob_is_store[tail]         <= alloc_is_store_i;
            rob_is_branch[tail]        <= alloc_is_branch_i;
            rob_is_fp[tail]            <= alloc_is_fp_i;
            rob_is_vec[tail]           <= alloc_is_vec_i;

            tail_next = tail + 1;
            if (entry_count_next < ROB_ENTRIES)
                entry_count_next = entry_count_next + 1;
        end

        if (flush_event) begin
            tail_next        = head_next;
            entry_count_next = 0;
            for (idx = 0; idx < ROB_ENTRIES; idx = idx + 1) begin
                rob_valid[idx]            <= 1'b0;
                rob_completed[idx]        <= 1'b0;
                rob_exception[idx]        <= 1'b0;
                rob_branch_mispredict[idx]<= 1'b0;
                rob_branch_taken[idx]     <= 1'b0;
            end
        end

        head <= head_next;
        tail <= tail_next;
        entry_count <= entry_count_next[6:0];
    end
end

// Initialize ROB entries
integer j;
initial begin
    for (j = 0; j < ROB_ENTRIES; j = j + 1) begin
        rob_valid[j]       = 1'b0;
        rob_completed[j]   = 1'b0;
        rob_exception[j]   = 1'b0;
        rob_is_store[j]    = 1'b0;
        rob_is_branch[j]   = 1'b0;
        rob_is_fp[j]       = 1'b0;
        rob_is_vec[j]      = 1'b0;
        rob_branch_taken[j] = 1'b0;
        rob_branch_mispredict[j] = 1'b0;
    end
    head = 6'h0;
    tail = 6'h0;
    entry_count = 7'h0;
end

endmodule
