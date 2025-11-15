// ============================================================================
// Clownfish RISC-V Processor - Configuration Header
// ============================================================================
// Project: Clownfish v2 - High-Performance 32-bit RISC-V Processor
// ISA: RV32GCBV (I=base, M=mul/div, A=atomic, F=float, D=double, C=compressed, B=bit-manip, V=vector)
// Architecture: 14-stage out-of-order superscalar pipeline
// Target: 1.0-1.3 GHz on 130nm process
// ============================================================================

`ifndef CLOWNFISH_CONFIG_VH
`define CLOWNFISH_CONFIG_VH

// ============================================================================
// ISA Configuration
// ============================================================================
`define XLEN 32                     // Register width
`define ILEN 32                     // Instruction width (max, can be 16 with C extension)
`define RV32I                       // Base integer ISA
`define RV32M                       // Multiply/Divide extension
`define RV32A                       // Atomic extension
`define RV32F                       // Single-precision float extension
`define RV32D                       // Double-precision float extension
`define RV32C                       // Compressed instruction extension
`define RV32B                       // Bit manipulation extension
`define RV32V                       // Vector extension (RVV 1.0)

// ============================================================================
// Privilege Levels
// ============================================================================
`define PRIV_USER       2'b00
`define PRIV_SUPERVISOR 2'b01
`define PRIV_MACHINE    2'b11

// ============================================================================
// Memory Configuration
// ============================================================================
`define ADDR_WIDTH 32               // Virtual address width
`define PHYS_ADDR_WIDTH 36          // Physical address width (PAE - 64GB addressable)
`define PAE_ENABLED                 // Physical Address Extension enabled

// L1 Instruction Cache
`define L1_ICACHE_SIZE      32768   // 32 KB
`define L1_ICACHE_WAYS      4       // 4-way set associative
`define L1_ICACHE_LINE_SIZE 64      // 64 bytes per line
`define L1_ICACHE_SETS      128     // 32KB / (4 ways * 64 bytes)

// L1 Data Cache
`define L1_DCACHE_SIZE      32768   // 32 KB
`define L1_DCACHE_WAYS      4       // 4-way set associative
`define L1_DCACHE_LINE_SIZE 64      // 64 bytes per line
`define L1_DCACHE_SETS      128     // 32KB / (4 ways * 64 bytes)

// L2 Unified Cache
`define L2_CACHE_SIZE       262144  // 256 KB (can be 512 KB)
`define L2_CACHE_WAYS       8       // 8-way set associative
`define L2_CACHE_LINE_SIZE  64      // 64 bytes per line
`define L2_CACHE_SETS       512     // 256KB / (8 ways * 64 bytes)

// TLB
`define TLB_ENTRIES         64      // 64 TLB entries
`define PAGE_SIZE           4096    // 4 KB pages (Sv32)

// ============================================================================
// Pipeline Configuration - 14-Stage Out-of-Order Superscalar
// ============================================================================
`define PIPELINE_STAGES     14      // F1-F4, D1-D2, EX1-EX5, M1-M2, WB

// Frontend (Fetch)
`define FETCH_WIDTH         3       // Fetch up to 3 instructions per cycle
`define FETCH_QUEUE_DEPTH   16      // Instruction queue depth

// Decode/Dispatch
`define DECODE_WIDTH        3       // Decode up to 3 instructions per cycle
`define ISSUE_WIDTH         4       // Issue up to 4 uops per cycle
`define ENABLE_MACRO_FUSION         // Enable macro-op fusion

// Out-of-Order Execution
`define ROB_ENTRIES         64      // Reorder Buffer entries
`define RS_ENTRIES          48      // Reservation Station entries (total)
`define RS_ALU_ENTRIES      16      // RS entries for simple ALU ops
`define RS_COMPLEX_ENTRIES  8       // RS entries for complex ops
`define RS_MEM_ENTRIES      16      // RS entries for memory ops
`define RS_FP_ENTRIES       8       // RS entries for FP ops

// Register Renaming
`define NUM_PHYS_INT_REGS   96      // Physical integer registers (32 arch + 64 rename)
`define NUM_PHYS_FP_REGS    96      // Physical FP registers (32 arch + 64 rename)
`define NUM_PHYS_VEC_REGS   64      // Physical vector registers (32 arch + 32 rename)

// Branch Prediction (Tournament Predictor)
`define BTB_ENTRIES         2048    // Branch Target Buffer entries
`define GSHARE_SIZE         2048    // GShare predictor entries
`define BIMODAL_SIZE        2048    // Bimodal predictor entries
`define SELECTOR_SIZE       2048    // Tournament selector entries
`define RAS_DEPTH           32      // Return Address Stack depth
`define INDIRECT_PRED_ENTRIES 256   // Indirect branch predictor

// Store Buffer
`define STORE_BUFFER_DEPTH  8       // Number of store buffer entries
`define LOAD_QUEUE_DEPTH    16      // Load queue depth
`define MSHR_ENTRIES        4       // Miss Status Holding Registers

// ============================================================================
// Register File
// ============================================================================
`define NUM_INT_REGS        32      // 32 integer registers (x0-x31)
`define NUM_FP_REGS         32      // 32 floating-point registers (f0-f31)
`define NUM_VEC_REGS        32      // 32 vector registers (v0-v31)

// Vector Extension Configuration (RVV 1.0)
`define VLEN                128     // Vector register length in bits
`define ELEN                64      // Maximum element width
`define SLEN                128     // Striping distance (same as VLEN for simplicity)
`define VLEN_BYTES          16      // VLEN in bytes (128/8)
`define MAX_LMUL            8       // Maximum LMUL value
`define VEC_ALU_LANES       4       // Number of parallel vector lanes (32-bit)

// ============================================================================
// Execution Unit Configuration
// ============================================================================
`define NUM_SIMPLE_ALU      2       // 2 simple ALU units (add, logic, shift)
`define NUM_COMPLEX_ALU     1       // 1 complex ALU (branches, misc)
`define NUM_MUL_DIV         1       // 1 multiply/divide unit
`define NUM_FPU             1       // 1 floating-point unit
`define NUM_VECTOR_UNIT     1       // 1 vector unit
`define NUM_LSU             1       // 1 load-store unit

// ============================================================================
// Execution Unit Latencies
// ============================================================================
// Simple ALU (2 units)
`define SIMPLE_ALU_LATENCY  1       // 1 cycle (add, sub, logic, shift)

// Complex ALU (1 unit)
`define COMPLEX_ALU_LATENCY 1       // 1 cycle (branches, misc)

// Multiply/Divide Unit (1 unit, pipelined)
`define MUL_LATENCY         3       // 3 cycles (pipelined, 1 cycle throughput)
`define DIV_LATENCY         18      // 18 cycles (iterative)

// Floating-Point Unit (1 unit, pipelined)
`define FPU_ADD_LATENCY     3       // 3 cycles
`define FPU_MUL_LATENCY     4       // 4 cycles
`define FPU_FMADD_LATENCY   5       // 5 cycles (fused multiply-add)
`define FPU_DIV_SP_LATENCY  10      // 10 cycles (single-precision)
`define FPU_DIV_DP_LATENCY  17      // 17 cycles (double-precision)
`define FPU_SQRT_SP_LATENCY 10      // 10 cycles
`define FPU_SQRT_DP_LATENCY 17      // 17 cycles
`define FPU_CVT_LATENCY     2       // 2 cycles (conversion)

// Vector Unit (1 unit, 4 lanes)
`define VEC_ALU_LATENCY     2       // 2 cycles (add, logic)
`define VEC_MUL_LATENCY     4       // 4 cycles
`define VEC_DIV_LATENCY     20      // 20 cycles
`define VEC_LOAD_LATENCY    3       // 3 cycles (L1 hit)
`define VEC_STORE_LATENCY   1       // 1 cycle (to store buffer)

// Load-Store Unit (1 unit)
`define LSU_LOAD_LATENCY    3       // 3 cycles (L1 hit)
`define LSU_STORE_LATENCY   1       // 1 cycle (to store buffer)

// ============================================================================
// Bus Configuration
// ============================================================================
`define BUS_DATA_WIDTH      32      // 32-bit data bus
`define BUS_ADDR_WIDTH      32      // 32-bit address bus

// ============================================================================
// Memory Map
// ============================================================================
`define MEM_ROM_BASE        32'h0000_0000  // Boot ROM (16 KB)
`define MEM_ROM_SIZE        32'h0000_4000
`define MEM_RAM_BASE        32'h8000_0000  // Main DRAM (128 MB)
`define MEM_RAM_SIZE        32'h0800_0000
`define MEM_PERIPH_BASE     32'hC000_0000  // Peripherals
`define MEM_DEBUG_BASE      32'hF000_0000  // Debug module

// Peripheral addresses
`define UART_BASE           32'hC000_1000
`define TIMER_BASE          32'hC000_2000  // CLINT
`define PLIC_BASE           32'hC000_C000
`define GPIO_BASE           32'hC000_3000

// ============================================================================
// Interrupt Configuration
// ============================================================================
`define NUM_INTERRUPTS      32      // 32 external interrupts
`define TIMER_IRQ           7       // Timer interrupt
`define EXTERNAL_IRQ        11      // External interrupt

// ============================================================================
// CSR Addresses (RISC-V Standard)
// ============================================================================
// Machine-level CSRs
`define CSR_MSTATUS         12'h300
`define CSR_MISA            12'h301
`define CSR_MIE             12'h304
`define CSR_MTVEC           12'h305
`define CSR_MSCRATCH        12'h340
`define CSR_MEPC            12'h341
`define CSR_MCAUSE          12'h342
`define CSR_MTVAL           12'h343
`define CSR_MIP             12'h344

// Supervisor-level CSRs
`define CSR_SSTATUS         12'h100
`define CSR_SIE             12'h104
`define CSR_STVEC           12'h105
`define CSR_SSCRATCH        12'h140
`define CSR_SEPC            12'h141
`define CSR_SCAUSE          12'h142
`define CSR_STVAL           12'h143
`define CSR_SIP             12'h144
`define CSR_SATP            12'h180  // Supervisor address translation

// User-level CSRs
`define CSR_CYCLE           12'hC00
`define CSR_TIME            12'hC01
`define CSR_INSTRET         12'hC02

// ============================================================================
// Exception Codes
// ============================================================================
`define EXC_INST_MISALIGNED     4'd0
`define EXC_INST_ACCESS_FAULT   4'd1
`define EXC_ILLEGAL_INST        4'd2
`define EXC_BREAKPOINT          4'd3
`define EXC_LOAD_MISALIGNED     4'd4
`define EXC_LOAD_ACCESS_FAULT   4'd5
`define EXC_STORE_MISALIGNED    4'd6
`define EXC_STORE_ACCESS_FAULT  4'd7
`define EXC_ECALL_U             4'd8
`define EXC_ECALL_S             4'd9
`define EXC_ECALL_M             4'd11
`define EXC_INST_PAGE_FAULT     4'd12
`define EXC_LOAD_PAGE_FAULT     4'd13
`define EXC_STORE_PAGE_FAULT    4'd15

// ============================================================================
// Clock Configuration
// ============================================================================
`define BASE_CLOCK_FREQ     1100    // Base frequency: 1.1 GHz (1100 MHz)
`define TURBO_CLOCK_FREQ    3500    // Turbo boost frequency: 3.5 GHz (3500 MHz)
`define TURBO_BOOST_ENABLE          // Enable dynamic turbo boost
`define CLOCK_GATING_ENABLE         // Enable clock gating for power saving

// ============================================================================
// Debug Configuration
// ============================================================================
`define DEBUG_ENABLE                // Enable debug module
`define JTAG_TAP_ENABLE            // Enable JTAG TAP

// ============================================================================
// Synthesis Directives
// ============================================================================
`ifdef SYNTHESIS
  `define NO_ASSERT                 // Disable assertions in synthesis
`endif

`endif // CLOWNFISH_CONFIG_VH
