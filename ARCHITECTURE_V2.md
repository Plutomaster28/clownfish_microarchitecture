# Clownfish RISC-V Processor - Version 2 Architecture
## "Bleeding Edge 130nm" - Maximum Performance Design

---

## 🎯 Design Philosophy

**Goal**: Create the most powerful 32-bit RISC-V processor achievable on 130nm process technology, targeting performance comparable to or exceeding Intel Pentium 4 while maintaining lower power consumption.

**Target Market**: High-performance embedded systems, edge computing, specialized workloads requiring vector processing.

---

## 📊 Core Specifications

### ISA: RV32GCBV
- **RV32I** - Base integer instruction set
- **RV32M** - Integer multiply/divide
- **RV32A** - Atomic instructions
- **RV32F** - Single-precision floating-point
- **RV32D** - Double-precision floating-point
- **RV32C** - Compressed instructions (16-bit encoding)
- **Zicsr** - CSR instructions
- **Zifencei** - Instruction fence
- **Zba, Zbb, Zbc, Zbs** - Bit manipulation extensions
- **RVV 1.0** - Vector extension (VLEN=128)

### Pipeline Architecture
- **14-stage pipeline** (deep but manageable)
- **Out-of-order execution** (Tomasulo-style)
- **3-wide fetch/decode**
- **4-wide issue** (4 micro-ops per cycle)
- **Superscalar execution**

### Performance Targets
| Metric | Target | Notes |
|--------|--------|-------|
| **Clock Frequency** | 1.0 - 1.3 GHz | On 130nm process |
| **IPC (Integer)** | 1.8 - 2.5 | Out-of-order benefit |
| **IPC (FP/Vector)** | 2.0 - 3.0 | With vector unit |
| **Branch Misprediction** | < 5% | Tournament predictor |
| **Power** | 15 - 25 W | @ 1.2 GHz typical |
| **Die Area** | 35 - 45 mm² | 6mm × 7mm approx |

---

## 🔧 Microarchitecture Details

### 14-Stage Pipeline Breakdown

```
┌────────────────────────────────────────────────────────────────┐
│ Stage 1-4: Frontend (Fetch & Decode)                           │
├────────────────────────────────────────────────────────────────┤
│ F1: Fetch Address Generation                                   │
│     - PC calculation                                            │
│     - Branch prediction (BTB lookup)                           │
│     - I-TLB access                                             │
│                                                                 │
│ F2: I-Cache Access                                             │
│     - I-Cache tag check                                        │
│     - Instruction fetch (up to 3 instructions)                │
│     - Predecode (identify instruction boundaries)              │
│                                                                 │
│ F3: Instruction Queue & Alignment                              │
│     - Align fetched instructions                               │
│     - Handle 16-bit compressed instructions                    │
│     - Macro-op fusion detection                                │
│     - Fill instruction queue (16 entries)                      │
│                                                                 │
│ F4: Decode & Register Rename                                   │
│     - Decode up to 3 instructions                              │
│     - Register renaming (map to physical registers)           │
│     - Break into micro-ops if needed                          │
│     - Allocate ROB entries                                     │
├────────────────────────────────────────────────────────────────┤
│ Stage 5-6: Dispatch                                            │
├────────────────────────────────────────────────────────────────┤
│ D1: Issue Queue & Resource Check                               │
│     - Place in reservation stations (48 entries)              │
│     - Check execution unit availability                        │
│     - Check structural hazards                                 │
│                                                                 │
│ D2: Operand Fetch & Bypass                                     │
│     - Read physical register file                              │
│     - Bypass from execution units                              │
│     - Immediate value extraction                               │
│     - Issue ready micro-ops to execution units                │
├────────────────────────────────────────────────────────────────┤
│ Stage 7-11: Execute                                            │
├────────────────────────────────────────────────────────────────┤
│ EX1: Primary Execution                                         │
│     - ALU0: Simple integer (add, sub, logic)                  │
│     - ALU1: Simple integer (add, sub, logic)                  │
│     - AGU: Address generation for loads/stores                │
│     - Branch: Branch condition evaluation                      │
│                                                                 │
│ EX2: Secondary Execution                                       │
│     - Complex ALU: Shifts, rotates, bit manipulation          │
│     - Multiply Stage 1 (Booth encoding)                       │
│     - FPU Stage 1 (Unpack & align)                            │
│     - Vector Stage 1 (Element distribution)                   │
│                                                                 │
│ EX3: Extended Execution                                        │
│     - Multiply Stage 2 (Partial products)                     │
│     - FPU Stage 2 (Mantissa operation)                        │
│     - Vector Stage 2 (Parallel operations)                    │
│                                                                 │
│ EX4: Completion                                                │
│     - Multiply Stage 3 (Final accumulation)                   │
│     - FPU Stage 3 (Normalization)                             │
│     - Vector Stage 3 (Result collection)                      │
│                                                                 │
│ EX5: Final Stage                                               │
│     - Divide iteration (1 bit per cycle)                      │
│     - FPU Stage 4 (Rounding & pack)                           │
│     - Vector Stage 4 (Writeback prepare)                      │
├────────────────────────────────────────────────────────────────┤
│ Stage 12-13: Memory                                            │
├────────────────────────────────────────────────────────────────┤
│ M1: D-Cache Access                                             │
│     - D-TLB lookup                                             │
│     - D-Cache tag check & data read                           │
│     - Store buffer check                                       │
│     - Miss handling register allocation                        │
│                                                                 │
│ M2: Data Alignment & Exception                                 │
│     - Align loaded data                                        │
│     - Sign extension                                           │
│     - Exception detection                                      │
│     - Store buffer write                                       │
├────────────────────────────────────────────────────────────────┤
│ Stage 14: Writeback & Commit                                   │
├────────────────────────────────────────────────────────────────┤
│ WB: Register Writeback                                         │
│     - Write to physical register file                          │
│     - ROB entry completion                                     │
│     - In-order commit (up to 4 per cycle)                     │
│     - Free physical registers                                  │
│     - Update architectural state                               │
└────────────────────────────────────────────────────────────────┘
```

---

## 💪 Execution Units

### 1. Integer ALU0 (Simple)
- **Operations**: ADD, SUB, AND, OR, XOR, compare
- **Latency**: 1 cycle
- **Throughput**: 1 op/cycle
- **Width**: 32-bit

### 2. Integer ALU1 (Simple)
- **Operations**: ADD, SUB, AND, OR, XOR, compare
- **Latency**: 1 cycle
- **Throughput**: 1 op/cycle
- **Width**: 32-bit

### 3. Complex Integer Unit
- **Operations**: SLL, SRL, SRA, ROL, ROR, bit manipulation (Zb*)
- **Latency**: 2 cycles
- **Throughput**: 1 op/2 cycles
- **Width**: 32-bit
- **Features**: Barrel shifter, population count, leading zero detection

### 4. Integer Multiply/Divide Unit
- **Multiply**:
  - Latency: 3 cycles (pipelined)
  - Throughput: 1 op/cycle
  - Algorithm: Radix-4 Booth encoding
  - Supports: MUL, MULH, MULHSU, MULHU
  
- **Divide**:
  - Latency: 34 cycles (iterative)
  - Throughput: 1 op/34 cycles
  - Algorithm: SRT division
  - Supports: DIV, DIVU, REM, REMU

### 5. Floating-Point Unit (Unified SP/DP)
- **Operations**: FADD, FSUB, FMUL, FDIV, FSQRT, FMADD, FCVT
- **Latency**:
  - FADD/FSUB: 4 cycles
  - FMUL: 5 cycles
  - FMADD: 6 cycles
  - FDIV: 16 cycles (SP), 24 cycles (DP)
  - FSQRT: 16 cycles (SP), 28 cycles (DP)
- **Throughput**: 1 op/cycle (for independent ops)
- **Supports**: IEEE-754 single & double precision
- **Features**: Denormal handling, all rounding modes

### 6. Vector Unit (RVV 1.0)
- **VLEN**: 128 bits
- **ELEN**: 64 bits (max element width)
- **Registers**: 32 vector registers (v0-v31)
- **Element Types**: 8, 16, 32, 64-bit integers and floats
- **Operations**:
  - Vector arithmetic (add, sub, mul, div)
  - Vector FMA (fused multiply-add)
  - Vector load/store (unit stride, strided, indexed)
  - Vector permute/shuffle
  - Vector reductions
- **Latency**: 2-6 cycles depending on operation
- **Throughput**: Up to 4 elements per cycle (for 32-bit ops)

### 7. Load/Store Unit
- **Load Queue**: 16 entries
- **Store Buffer**: 8 entries
- **Features**:
  - Non-blocking loads (4 outstanding misses)
  - Store-to-load forwarding
  - Write coalescing in store buffer
  - Unaligned access support
  - Atomic operations (AMO*, LR/SC)
- **Bandwidth**: 32-bit or 64-bit per cycle

---

## 🧠 Out-of-Order Infrastructure

### Reorder Buffer (ROB)
- **Size**: 64 entries
- **Function**: Track in-flight instructions, ensure in-order commit
- **Commit Width**: Up to 4 instructions per cycle
- **Features**: Exception handling, precise interrupts

### Reservation Stations
- **Total**: 48 entries
- **Distribution**:
  - Integer RS: 16 entries (for ALU0, ALU1, Complex)
  - FP/Vector RS: 12 entries (for FPU, Vector Unit)
  - Load/Store RS: 20 entries (for LSU)
- **Wake-up**: Broadcast-based, single-cycle wake-up

### Register Renaming
- **Architectural Registers**:
  - 32 integer registers (x0-x31)
  - 32 FP registers (f0-f31)
  - 32 vector registers (v0-v31)
- **Physical Registers**:
  - 96 integer physical registers
  - 96 FP physical registers
  - 48 vector physical registers
- **Algorithm**: R10K-style register renaming
- **Free List**: Track available physical registers

### Bypass Network
- **Full bypass**: All execution units can forward to all units
- **Latency**: Single cycle bypass
- **Complexity**: 7 → 7 bypass paths (49 muxes)

---

## 🎯 Branch Prediction

### Tournament Predictor (Hybrid)
- **Structure**: Combination of GShare + Bimodal
- **Meta-predictor**: Chooses between GShare and Bimodal
- **History Length**: 12 bits global history
- **GShare Table**: 4K entries (4096 × 2-bit saturating counters)
- **Bimodal Table**: 2K entries (2048 × 2-bit saturating counters)
- **Meta Table**: 2K entries (choose which predictor)

### Branch Target Buffer (BTB)
- **Size**: 2K entries (2048 entries)
- **Associativity**: 4-way set associative
- **Entry**: {Tag, Target Address, Type (branch/jump/call/return)}
- **Prediction**: 2-cycle BTB lookup

### Return Address Stack (RAS)
- **Size**: 32 entries
- **Function**: Predict return addresses for function calls
- **Push**: On JAL/JALR with rd=x1/x5
- **Pop**: On JALR with rs1=x1/x5 and rd=x0

### Indirect Branch Predictor
- **Size**: 64 entries
- **Hash**: PC XOR history
- **Target**: For indirect jumps (JALR)

### Performance Expectations
- **Branch Prediction Accuracy**: 95-97%
- **Misprediction Penalty**: 14 cycles (full pipeline flush)
- **Effective Misprediction Cost**: ~0.5-0.7 cycles per branch on average

---

## 💾 Memory Subsystem

### L1 Instruction Cache
- **Size**: 32 KB
- **Associativity**: 4-way set associative
- **Line Size**: 64 bytes
- **Sets**: 128 sets
- **Latency**: 2 cycles (hit)
- **Indexing**: Virtually Indexed, Physically Tagged (VIPT)
- **Features**:
  - Predecode bits stored with cache line
  - 16-byte fetch per cycle (up to 8 compressed or 4 normal instructions)
  - Stream buffer for sequential prefetch

### L1 Data Cache
- **Size**: 32 KB
- **Associativity**: 4-way set associative
- **Line Size**: 64 bytes
- **Sets**: 128 sets
- **Latency**: 2 cycles (hit)
- **Write Policy**: Write-back, write-allocate
- **Features**:
  - Non-blocking (4 MSHRs for outstanding misses)
  - 8-entry store buffer with write coalescing
  - Store-to-load forwarding
  - Support for atomic operations

### L2 Unified Cache
- **Size**: 512 KB
- **Associativity**: 8-way set associative
- **Line Size**: 64 bytes
- **Sets**: 1024 sets
- **Latency**: 8-10 cycles (hit)
- **Write Policy**: Write-back, inclusive of L1
- **Features**:
  - Shared between instruction and data
  - Pseudo-LRU replacement
  - ECC protection (SECDED)

### Translation Lookaside Buffers (TLB)
- **I-TLB**: 64 entries, 4-way, fully associative
- **D-TLB**: 64 entries, 4-way, fully associative
- **Page Sizes**: 4 KB (Sv32)
- **Miss Penalty**: Hardware page table walker
- **Page Table Walk Latency**: ~40-60 cycles (on L2 hit)

### Miss Status Holding Registers (MSHR)
- **D-Cache MSHRs**: 4 entries
- **L2 MSHRs**: 8 entries
- **Function**: Track outstanding cache misses, allow hit-under-miss

### Memory Controller
- **Interface**: 64-bit wide to external DRAM
- **Protocol**: Simple request/response (can upgrade to AXI)
- **Bandwidth**: ~8 GB/s @ 1 GHz
- **Latency**: ~50-100 ns to DRAM (typical)

---

## 🔌 RVV Vector Extension Details

### Vector Registers (128-bit VLEN)
```
v0-v31: 32 × 128-bit vector registers

Configurable Element Widths:
- SEW=8:  16 elements × 8-bit  (16 bytes)
- SEW=16:  8 elements × 16-bit (16 bytes)
- SEW=32:  4 elements × 32-bit (16 bytes)
- SEW=64:  2 elements × 64-bit (16 bytes)
```

### Vector Operations
1. **Vector Arithmetic**
   - vadd.vv, vsub.vv, vmul.vv, vdiv.vv
   - vadd.vx (vector-scalar)
   - Latency: 3-5 cycles

2. **Vector FMA (Fused Multiply-Add)**
   - vfmadd.vv, vfnmadd.vv, vfmsub.vv
   - Latency: 6 cycles
   - Throughput: 1 op/cycle

3. **Vector Load/Store**
   - vle.v (unit stride load)
   - vse.v (unit stride store)
   - vlse.v (strided load)
   - vlxei.v (indexed load)
   - Bandwidth: 16 bytes/cycle

4. **Vector Permute**
   - vrgather.vv, vslideup, vslidedown
   - Latency: 4 cycles

5. **Vector Reductions**
   - vredsum, vredmax, vredmin
   - Latency: log2(elements) cycles

### SSE2 Comparison
```
Feature                 SSE2              RVV (VLEN=128)
────────────────────────────────────────────────────────
Register Count         16 (xmm0-xmm15)   32 (v0-v31)
Register Width         128-bit           128-bit
Integer Support        ✓                 ✓
FP Support             Single, Double    Single, Double
Element Widths         8,16,32,64-bit    8,16,32,64-bit
Packed Operations      ✓                 ✓
Scalar Operations      ✓                 ✓ (via vx forms)
Predication            Limited           ✓ (mask registers)
Variable Length        ✗                 ✓ (via vl register)
Gather/Scatter         Limited           ✓ (indexed ops)
────────────────────────────────────────────────────────
Instruction Count      144 (SSE2)        ~200+ (RVV)
```

**RVV Advantages**:
- More flexible (variable length)
- Better predication support
- Native gather/scatter
- Cleaner instruction encoding
- Open standard (no licensing)

---

## ⚡ Clock & Power Optimization

### Target Clock: 1.0 - 1.3 GHz on 130nm

### Techniques for High Frequency

1. **Critical Path Optimization**
   - **Pipeline Balancing**: Each stage ~0.77-1.0 ns
   - **Logic Depth Reduction**: Max 10-12 gate delays per stage
   - **Custom Cells**: Hand-optimized critical paths
   - **Path Splitting**: Break long combinational paths

2. **Aggressive Clock Gating**
   - **Fine-Grained**: Gate at register level
   - **Coarse-Grained**: Gate entire functional units when idle
   - **Expected Savings**: 30-40% dynamic power
   - **Implementation**: Integrated clock gating cells

3. **Voltage Islands**
   - **Core Logic**: 1.8V (high performance)
   - **Caches**: 1.5V (lower power)
   - **Peripherals**: 1.2V (low power)
   - **Level Shifters**: Required between islands
   - **Power Savings**: ~25% total power

4. **Pipeline Optimizations**
   - **Latch-Based Design**: For critical paths (faster than flip-flops)
   - **Domino Logic**: Limited use in ALU critical paths
   - **Wave Pipelining**: In multiply/FPU units

5. **Physical Design**
   - **Floorplanning**: Minimize wire lengths on critical paths
   - **Metal Stack**: Use upper metals (M3, M4) for long routes
   - **Custom Routing**: For critical nets
   - **Buffer Insertion**: Aggressive buffering on long paths

### Power Budget (@ 1.2 GHz typical)
```
Component          Power (W)    Percentage
─────────────────────────────────────────
Integer Core       5-8 W        30%
FP/Vector Unit     3-5 W        20%
L1 Caches          2-3 W        15%
L2 Cache           3-4 W        20%
Memory Interface   1-2 W        8%
Peripherals        0.5-1 W      3%
Clock Network      1-2 W        8%
─────────────────────────────────────────
Total              15-25 W      100%
```

### Thermal Design
- **TDP**: 25W @ 1.3 GHz
- **Process**: 130nm (expect higher leakage than modern nodes)
- **Cooling**: Passive heatsink sufficient for most applications
- **Die Temp**: Target < 85°C junction temperature

---

## 📐 Physical Design Estimates

### Die Area Breakdown
```
Component              Area (mm²)   Percentage
──────────────────────────────────────────────
Integer Core Logic     8-10         22%
FP Unit                2-3          6%
Vector Unit            3-4          8%
ROB + RS               4-5          11%
Register Files         5-6          14%
Branch Predictors      1-2          3%
L1 I-Cache (32KB)      4-5          11%
L1 D-Cache (32KB)      4-5          11%
L2 Cache (512KB)       12-15        33%
MMU/TLB                1-2          3%
──────────────────────────────────────────────
Total (estimated)      35-45 mm²    100%
```

### Floorplan Concept
```
┌─────────────────────────────────────────┐
│  L2 Cache (512 KB)                      │
│  ┌───────────────────────────────────┐  │
│  │  [8-way set associative]          │  │
│  │  [1024 sets × 64B lines]          │  │
│  └───────────────────────────────────┘  │
├──────────────┬──────────────────────────┤
│ L1 I-Cache   │  Core Logic              │
│  (32KB)      │  ┌────────────────────┐  │
│  ┌────────┐  │  │ Fetch/Decode       │  │
│  │ 4-way  │  │  │ (Frontend)         │  │
│  │ 128set │  │  ├────────────────────┤  │
│  └────────┘  │  │ ROB + RS           │  │
│              │  │ (OoO Engine)       │  │
├──────────────┤  ├────────────────────┤  │
│ L1 D-Cache   │  │ ALU0 | ALU1        │  │
│  (32KB)      │  │ Complex ALU        │  │
│  ┌────────┐  │  ├────────────────────┤  │
│  │ 4-way  │  │  │ MUL/DIV Unit       │  │
│  │ 128set │  │  ├────────────────────┤  │
│  └────────┘  │  │ FP Unit            │  │
│              │  ├────────────────────┤  │
├──────────────┤  │ Vector Unit        │  │
│ MMU/TLB      │  │ (RVV)              │  │
│ Branch Pred  │  └────────────────────┘  │
└──────────────┴──────────────────────────┘
```

---

## 🎯 Performance Estimates

### Integer Performance (CoreMark)
- **Estimated**: 3.5 - 4.5 CoreMark/MHz
- **@ 1.2 GHz**: ~4200-5400 CoreMarks
- **Comparison**: Pentium 4 ~2.0-2.5 CM/MHz

### Floating-Point Performance (SPEC FP)
- **Estimated**: 1.8 - 2.5 GFLOPS (scalar)
- **With Vector**: 4 - 6 GFLOPS (vectorized)
- **@ 1.2 GHz, 32-bit FP**: ~4.8 GFLOPS theoretical peak

### Vector Performance
- **Peak Throughput**: 4 × 32-bit ops/cycle = 4.8 GOPS @ 1.2 GHz
- **Sustained (typical)**: 60-70% of peak = ~3.0 GOPS
- **Memory Bound**: 16 bytes/cycle = 19.2 GB/s @ 1.2 GHz (L1 bandwidth)

### Power Efficiency
- **Performance/Watt**: ~250 CoreMarks/Watt
- **Comparison**: Pentium 4 ~42 CM/W (significantly worse)
- **Energy per Instruction**: ~10-15 nJ/instruction

---

## 🏆 Competitive Analysis

### vs. Intel Pentium 4 (Prescott, 90nm)
```
Metric               Pentium 4      Clownfish v2    Winner
────────────────────────────────────────────────────────────
Process             90nm            130nm           P4
Clock Speed         3.8 GHz         1.2 GHz         P4
Pipeline Depth      31 stages       14 stages       Clownfish
IPC (Integer)       0.5-0.9         1.8-2.5         Clownfish
Power               100W            20W             Clownfish
Die Area            ~112 mm²        ~40 mm²         Clownfish
Performance/Watt    ~42 CM/W        ~250 CM/W       Clownfish
Branch Predict      ~90%            ~95%            Clownfish
L1 D-Cache          16KB, 8-way     32KB, 4-way     Clownfish
L2 Cache            1-2MB           512KB           P4
ISA                 x86             RISC-V          Subjective
────────────────────────────────────────────────────────────
Overall                             Clownfish wins on efficiency,
                                    competitive on raw performance
```

### vs. ARM Cortex-A8 (65nm)
```
Metric               Cortex-A8       Clownfish v2    Winner
────────────────────────────────────────────────────────────
Process             65nm            130nm           A8
Clock Speed         1.0 GHz         1.2 GHz         Clownfish
Pipeline Depth      13 stages       14 stages       Tie
Issue Width         2-wide          4-wide          Clownfish
IPC                 1.0-2.0         1.8-2.5         Clownfish
Power               ~2W             ~20W            A8
SIMD                NEON (128b)     RVV (128b)      Tie
L2 Cache            128-512KB       512KB           Clownfish
────────────────────────────────────────────────────────────
Overall                             Clownfish higher performance,
                                    A8 better power efficiency
```

---

## 🚀 Implementation Roadmap

### Phase 1: Core Pipeline (Months 1-3)
- [ ] Design 14-stage pipeline structure
- [ ] Implement fetch and decode stages
- [ ] Basic ALU and execution units
- [ ] Simple in-order execution (OoO comes later)

### Phase 2: Out-of-Order Infrastructure (Months 4-6)
- [ ] Reorder Buffer (ROB) implementation
- [ ] Reservation Stations
- [ ] Register renaming logic
- [ ] Bypass network

### Phase 3: Advanced Features (Months 7-9)
- [ ] Tournament branch predictor
- [ ] Vector unit (RVV) implementation
- [ ] FPU with full IEEE-754 support
- [ ] Non-blocking caches with MSHRs

### Phase 4: Integration & Optimization (Months 10-12)
- [ ] Integrate OpenRAM SRAMs
- [ ] Clock gating implementation
- [ ] Critical path optimization
- [ ] Power analysis and reduction

### Phase 5: Verification & Tape-out Prep (Months 13-18)
- [ ] RISC-V compliance tests
- [ ] Performance benchmarking
- [ ] Physical design (OpenLane flow)
- [ ] Timing closure @ 1.2-1.3 GHz
- [ ] DRC/LVS clean
- [ ] Tape-out

---

## 📚 References

1. **RISC-V ISA Manual** - https://riscv.org/specifications/
2. **RISC-V Vector Extension Spec** - https://github.com/riscv/riscv-v-spec
3. **Hennessy & Patterson** - "Computer Architecture: A Quantitative Approach"
4. **Intel P6 Microarchitecture** - Out-of-order design reference
5. **ARM Cortex-A Series** - Modern processor architecture
6. **Berkeley Out-of-Order Machine (BOOM)** - Open-source RISC-V OoO core

---

**Status**: Architecture specification complete. Ready for implementation!

**Last Updated**: October 20, 2025
