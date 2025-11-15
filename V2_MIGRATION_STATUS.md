# Clownfish v2 Architecture Update Progress

**Date:** October 20, 2025  
**Status:** Architecture migration in progress - v1 (5-stage) → v2 (14-stage OoO)

---

## ✅ Completed Updates

### 1. Configuration Files
- **clownfish_config.vh** - Fully updated to v2 specifications:
  - Extended ISA from RV32IMAF to RV32GCBV (added Double, Compressed, Bit-manip, Vector)
  - Updated pipeline configuration: 5 → 14 stages
  - Added out-of-order parameters:
    - 64-entry Reorder Buffer
    - 48-entry Reservation Stations (partitioned by type)
    - 96 physical integer registers (32 arch + 64 rename)
    - 96 physical FP registers
    - 64 physical vector registers
  - Tournament branch predictor configuration:
    - 2K BTB, 2K GShare, 2K Bimodal, 2K Selector
    - 32-entry RAS, 256-entry indirect predictor
  - Vector Extension (RVV 1.0):
    - VLEN = 128 bits
    - 32 vector registers (v0-v31)
    - 4 parallel vector lanes
  - Execution unit configuration:
    - 2× Simple ALU, 1× Complex ALU
    - 1× MUL/DIV, 1× FPU, 1× Vector Unit, 1× LSU
  - Updated latencies for all execution units

- **config.tcl** - Updated for 1.0 GHz target:
  - Clock period: 2.0ns → 1.0ns (500 MHz → 1.0 GHz)
  - Tighter clock tree synthesis constraints:
    - Target skew: 50ps → 30ps
    - Max wire length: 200 → 150
  - Added new execution unit files to VERILOG_FILES list

---

## 🔧 Execution Units Created

### Simple ALU (2 instances)
**File:** `rtl/execution/simple_alu.v`  
**Status:** ✅ Complete  
**Features:**
- Single-cycle latency
- Operations: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
- Fully pipelined with 1 cycle throughput
- ROB and physical register tracking
- Always ready (non-blocking)

### Complex ALU (1 instance)
**File:** `rtl/execution/complex_alu.v`  
**Status:** ✅ Complete  
**Features:**
- Single-cycle latency
- Handles all branch operations: BEQ, BNE, BLT, BGE, BLTU, BGEU
- Jump operations: JAL, JALR
- Upper immediate operations: LUI, AUIPC
- Branch target calculation
- Branch taken/not-taken output
- ROB and physical register tracking

### Multiply/Divide Unit (1 instance)
**File:** `rtl/execution/mul_div_unit.v`  
**Status:** ✅ Complete  
**Features:**
- Pipelined multiplier: 3 cycles latency, 1 cycle throughput
- Operations: MUL, MULH, MULHSU, MULHU
- Iterative divider: 18 cycles latency
- Operations: DIV, DIVU, REM, REMU
- Separate pipelines for MUL and DIV
- Ready signal indicates when unit can accept new operations

### Floating-Point Unit (1 instance)
**File:** `rtl/execution/fpu_unit.v`  
**Status:** ✅ Complete  
**Features:**
- IEEE 754 compliant FPU
- Single and double precision support (RV32F + RV32D)
- Operations: FADD, FSUB, FMUL, FDIV, FSQRT, FMADD, FSGNJ, FMIN/MAX, FCVT, FMV, FCMP, FCLASS
- Variable latency pipeline:
  - Sign injection/compare/move: 1 cycle
  - ADD/SUB: 3 cycles
  - MUL: 4 cycles
  - FMADD: 5 cycles
  - DIV: 10 cycles (SP), 17 cycles (DP)
  - SQRT: 10 cycles (SP), 17 cycles (DP)
- FP exception flags (NV, DZ, OF, UF, NX)
- Rounding mode support

### Vector Unit (1 instance)
**File:** `rtl/execution/vector_unit.v`  
**Status:** ✅ Complete  
**Features:**
- RVV 1.0 (RISC-V Vector Extension) implementation
- VLEN = 128 bits, 4 parallel lanes (32-bit each)
- 32 vector registers (v0-v31)
- Operations: VADD, VSUB, VMUL, VDIV, VAND, VOR, VXOR, VSLL, VSRL, VSRA
- Vector-vector and vector-scalar operations
- Vector load/store support
- VSETVL for dynamic vector configuration
- Latencies:
  - Simple ALU ops: 2 cycles
  - Vector multiply: 4 cycles (via pipeline)
  - Vector divide: 20 cycles (iterative)
  - Vector load/store: 3 cycles (L1 hit)
- Configurable SEW (Standard Element Width) and LMUL

### Load-Store Unit (1 instance)
**File:** `rtl/execution/lsu.v`  
**Status:** ✅ Complete  
**Features:**
- 16-entry load queue for speculative loads
- 8-entry store buffer for committed stores
- Operations: LB, LH, LW, LBU, LHU, SB, SH, SW, AMO (atomic)
- Memory disambiguation and ordering
- Address translation via MMU interface
- Misalignment detection and exception handling
- Store commit logic (waits for ROB commit signal)
- Fence/flush support
- Exception handling:
  - Load/store misaligned
  - Load/store access fault
  - Load/store page fault

---

## 📦 Memory Subsystem Updates

### L1 Instruction Cache
**File:** `rtl/memory/l1_icache.v`  
**Status:** ✅ Updated with OpenRAM integration  
**Features:**
- Instantiates 4 ways × 8 words of OpenRAM SRAM (`sram_l1_icache_way`)
- 128 sets, 4-way set-associative
- Tag comparison and hit detection
- State machine: IDLE → TAG_CHECK → ALLOCATE → REFILL → RESPOND
- L2 miss handling
- Pseudo-LRU replacement policy
- Tag and valid bit storage

### L1 Data Cache
**File:** `rtl/memory/l1_dcache_new.v`  
**Status:** � In progress (OpenRAM-backed controller under development)  
**Next:** Complete store handling, MMU integration, and verification

### L2 Unified Cache
**File:** `rtl/memory/l2_cache_new.v`  
**Status:** 🔄 To be updated (skeleton in place)  
**Next:** 8-way set-associative controller with OpenRAM integration

---



---

## 🎯 Out-of-Order Infrastructure (Not Yet Started)

### Required Modules:
1. **reorder_buffer.v** - 64-entry ROB for in-order commit
2. **reservation_station.v** - 48-entry RS for instruction scheduling
3. **register_rename.v** - RAT and free list management
4. **issue_queue.v** - 4-wide superscalar issue logic

### Required Predictor Modules:
1. **gshare_predictor.v** - 2K-entry GShare with global history
2. **bimodal_predictor.v** - 2K-entry bimodal predictor
3. **tournament_selector.v** - Meta-predictor for hybrid selection
4. **btb.v** - 2K-entry Branch Target Buffer
5. **ras.v** - 32-entry Return Address Stack

---

## 📊 Current Architecture Summary

| Component | v1 (Old) | v2 (New) | Status |
|-----------|----------|----------|--------|
| **ISA** | RV32IMAF | RV32GCBV | ✅ Config updated |
| **Pipeline** | 5 stages | 14 stages | ⏳ Core redesign needed |
| **Clock** | 500 MHz | 1.0 GHz | ✅ Config updated |
| **Execution** | In-order | Out-of-order | ⏳ Infrastructure needed |
| **Issue Width** | 1-wide | 4-wide | ⏳ Core redesign needed |
| **Branch Pred** | 512 BTB | 2K Tournament | ⏳ Predictor modules needed |
| **Simple ALU** | 1 unit | 2 units | ✅ Created |
| **Complex ALU** | In core | 1 unit | ✅ Created |
| **MUL/DIV** | Basic | 1 pipelined | ✅ Created |
| **FPU** | Stub | 1 pipelined | ✅ Created |
| **Vector** | None | 1 unit (RVV) | ✅ Created |
| **LSU** | Basic | 1 unit w/ queues | ✅ Created |
| **L1 I-Cache** | Stub | 32KB, 4-way | ✅ OpenRAM integrated |
| **L1 D-Cache** | Stub | 32KB, 4-way | 🚧 Controller under development |
| **L2 Cache** | Stub | 512KB, 8-way | ⏳ OpenRAM integration needed |

---

## 🗂️ File Organization

```
clownfish_microarchitecture/
├── include/
│   └── clownfish_config.vh          ✅ Updated to v2
├── rtl/
│   ├── core/
│   │   └── clownfish_core.v         ⏳ Needs v2 redesign (14-stage OoO)
│   ├── execution/                   📁 NEW DIRECTORY
│   │   ├── simple_alu.v             ✅ Created
│   │   ├── complex_alu.v            ✅ Created
│   │   ├── mul_div_unit.v           ✅ Created
│   │   ├── fpu_unit.v               ✅ Created
│   │   ├── vector_unit.v            ✅ Created
│   │   └── lsu.v                    ✅ Created
│   ├── memory/
│   │   ├── l1_icache.v              ✅ Updated with OpenRAM
│   │   ├── l1_dcache_new.v          🚧 OpenRAM-backed controller
│   │   ├── l2_cache_new.v           ⏳ Needs OpenRAM integration
│   │   └── ...
│   └── peripherals/                 (No changes yet)
├── config.tcl                       ✅ Updated to 1.0 GHz
├── clownfish_soc.v                  ⏳ Needs update for new modules
└── ARCHITECTURE_V2.md               ✅ Complete specification
```

---

## 🎯 Next Steps (Priority Order)

1. **Complete Execution Units** ✅ DONE (100%)
   - ✅ Simple ALU (2 units)
   - ✅ Complex ALU (1 unit)
   - ✅ MUL/DIV Unit (1 unit)
   - ✅ FPU Unit (1 unit)
   - ✅ Vector Unit (1 unit)
   - ✅ Load-Store Unit (1 unit)

2. **Complete Cache Integration** (In Progress - 33%)
   - ✅ L1 I-Cache with OpenRAM
   - ❌ L1 D-Cache with OpenRAM - **NEXT PRIORITY**
   - ❌ L2 Cache with OpenRAM

3. **Create OoO Infrastructure** (Not Started)
   - ❌ Reorder Buffer (ROB)
   - ❌ Reservation Stations (RS)
   - ❌ Register Rename (RAT)
   - ❌ Issue Queue

4. **Implement Branch Predictor** (Not Started)
   - ❌ GShare Predictor
   - ❌ Bimodal Predictor
   - ❌ Tournament Selector
   - ❌ BTB and RAS

5. **Redesign Core Pipeline** (Not Started)
   - ❌ 14-stage pipeline structure
   - ❌ Superscalar frontend (3-wide fetch/decode)
   - ❌ 4-wide issue logic
   - ❌ Integration with execution units

6. **Update Top-Level Integration** (Not Started)
   - ❌ Update clownfish_soc.v
   - ❌ Wire new execution units
   - ❌ Update bus interfaces

---

## 📈 Completion Metrics

- **Configuration:** 100% ✅
- **Execution Units:** 100% ✅ (6/6)
- **Memory Subsystem:** 33% (1/3) 🔄
- **OoO Infrastructure:** 0% ⏳
- **Branch Prediction:** 0% ⏳
- **Core Pipeline:** 0% ⏳
- **Top-Level Integration:** 0% ⏳

**Overall Progress:** ~40% complete (up from 25%)

---

## 🔧 Build Status

### Files Modified:
- `include/clownfish_config.vh` ✅
- `config.tcl` ✅
- `rtl/execution/simple_alu.v` ✅ (NEW)
- `rtl/execution/complex_alu.v` ✅ (NEW)
- `rtl/execution/mul_div_unit.v` ✅ (NEW)
- `rtl/execution/fpu_unit.v` ✅ (NEW)
- `rtl/execution/vector_unit.v` ✅ (NEW)
- `rtl/execution/lsu.v` ✅ (NEW)
- `rtl/memory/l1_icache.v` ✅

### Files to Update:
- `rtl/memory/l1_dcache_new.v`
- `rtl/memory/l2_cache_new.v`
- `rtl/core/clownfish_core.v`
- `clownfish_soc.v`

### Files to Create:
- `rtl/ooo/reorder_buffer.v`
- `rtl/ooo/reservation_station.v`
- `rtl/ooo/register_rename.v`
- `rtl/ooo/issue_queue.v`
- `rtl/predictor/gshare_predictor.v`
- `rtl/predictor/bimodal_predictor.v`
- `rtl/predictor/tournament_selector.v`
- `rtl/predictor/btb.v`
- `rtl/predictor/ras.v`

---

## 🚀 Performance Targets

- **Clock Frequency:** 1.0 GHz (target), 1.3 GHz (stretch)
- **IPC Target:** 1.8 - 2.5 (out-of-order)
- **Power Budget:** 15-25W @ 1.0 GHz
- **Die Area:** 35-45 mm² (130nm)

---

## 📝 Notes

- All execution units follow consistent interface:
  - ROB ID tracking for out-of-order commit
  - Physical register IDs for register renaming
  - Ready signals for reservation station scheduling
  - Exception signaling

- OpenRAM SRAM integration pattern established with L1 I-cache:
  - Generate 4 ways × 8 words (64-bit each)
  - Instantiate `sram_l1_*cache_way` modules
  - Separate tag/valid storage in registers or small SRAM
  - State machine for cache operations

- All modules use `clownfish_config.vh` for parameterization
- Clock period updated to 1.0ns (1 GHz) throughout design
