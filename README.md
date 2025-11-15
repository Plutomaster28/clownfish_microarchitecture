# Clownfish RISC-V Processor

A high-performance, 32-bit RISC-V processor targeting 130nm process technology through the OpenLane flow.

## 🎯 Specifications

### ISA
- **RV32IMAF** - Base Integer + Multiply/Divide + Atomic + Single-Precision Float
- **Privilege Levels**: Machine, Supervisor, User
- **Virtual Memory**: Sv32 MMU with 4KB pages
- **Endianness**: Little-endian

### Microarchitecture
- **Pipeline**: 5-stage in-order (IF → ID → EX → MEM → WB)
- **Issue Width**: Single-issue scalar
- **Target Clock**: 500 MHz on 130nm process
- **Branch Prediction**: 2-bit saturating counter + 512-entry BTB

### Memory Hierarchy
| Component | Size | Associativity | Line Size | Notes |
|-----------|------|---------------|-----------|-------|
| L1 I-Cache | 32 KB | 4-way | 64 B | Virtually indexed, physically tagged |
| L1 D-Cache | 32 KB | 4-way | 64 B | Write-back, write-allocate |
| L2 Cache | 256-512 KB | 8-way | 64 B | Unified, on-die |
| TLB | 64 entries | — | — | Sv32 page tables |

### Execution Units
- 1× ALU (integer logic, shift, compare)
- 1× Multiplier/Divider (pipelined mul, iterative div)
- 1× FPU (single-precision, IEEE-754)
- 1× Load/Store Unit (with store buffer)

### Peripherals
- UART (console/boot)
- CLINT (Core-Local Interrupt Controller / Timer)
- PLIC (Platform-Level Interrupt Controller)
- GPIO
- JTAG Debug Module (RISC-V Debug Spec 0.13)

## 📁 Project Structure

```
clownfish_microarchitecture/
├── config.tcl                      # OpenLane configuration (ROOT)
├── clownfish_soc.v                 # Top-level SoC module (ROOT)
│
├── rtl/                            # RTL source files
│   ├── core/                       # CPU core
│   │   ├── clownfish_core.v       # 5-stage pipeline (✓ Created)
│   │   ├── hazard_unit.v          # Hazard detection & forwarding
│   │   ├── alu.v                  # Arithmetic Logic Unit
│   │   ├── multiplier.v           # Multiply/Divide unit
│   │   ├── fpu.v                  # Floating-Point Unit
│   │   └── branch_predictor.v     # 2-bit predictor + BTB
│   │
│   ├── memory/                    # Memory subsystem
│   │   ├── l1_icache.v           # L1 Instruction Cache
│   │   ├── l1_dcache_new.v       # L1 Data Cache (OoO)
│   │   ├── l2_cache_new.v        # L2 Unified Cache (OoO)
│   │   ├── cache_controller.v    # Cache state machine
│   │   ├── mmu.v                 # Memory Management Unit
│   │   ├── tlb.v                 # Translation Lookaside Buffer
│   │   └── memory_controller.v   # External memory interface
│   │
│   └── peripherals/               # Peripherals
│       ├── csr_unit.v            # Control/Status Registers
│       ├── plic.v                # Platform-Level Interrupt Controller
│       ├── clint.v               # Core-Local Interrupt Controller
│       ├── uart.v                # UART controller
│       ├── gpio.v                # GPIO controller
│       └── debug_module.v        # RISC-V Debug Module
│
├── include/                       # Header files
│   ├── clownfish_config.vh       # Global configuration (✓ Created)
│   └── riscv_opcodes.vh          # RISC-V instruction encoding (✓ Created)
│
├── macros/                        # Generated SRAM macros
│   └── openram_output/           # OpenRAM generated files
│       ├── sram_l1_icache_way.*  # L1 I-Cache SRAM (✓ Generated)
│       ├── sram_l1_dcache_way.*  # L1 D-Cache SRAM (✓ Generated)
│       ├── sram_l2_cache_way.*   # L2 Cache SRAM (✓ Generated)
│       └── sram_tlb.*            # TLB SRAM (✓ Generated)
│
├── openram_configs/               # OpenRAM configurations
│   ├── l1_icache_config.py       # L1 I-Cache config (✓ Done)
│   ├── l1_dcache_config.py       # L1 D-Cache config (✓ Done)
│   ├── l2_cache_config.py        # L2 Cache config (✓ Done)
│   ├── tlb_config.py             # TLB config (✓ Done)
│   ├── generate_all.sh           # Generation script (✓ Done)
│   └── GENERATION_STATUS.md      # Status documentation
│
├── constraints/                   # Timing constraints
│   └── clownfish.sdc             # Synopsys Design Constraints
│
├── testbench/                     # Verification
│   ├── tb_core.v                 # Core testbench
│   ├── tb_soc.v                  # SoC testbench
│   └── test_programs/            # RISC-V test programs
│
└── docs/                          # Documentation
    ├── architecture.md            # Architecture document
    ├── memory_map.md              # Memory map
    └── integration.md             # Integration guide
```

## 🚀 Getting Started

### Prerequisites
- OpenLane (for ASIC flow)
- OpenRAM (for SRAM generation) - Already set up at `~/OpenRAM`
- Verilator or Icarus Verilog (for simulation)
- RISC-V GNU Toolchain (for compiling test programs)

### Building with OpenLane

1. **Navigate to project root**:
   ```bash
   cd ~/clownfish_microarchitecture
   ```

2. **Run OpenLane flow**:
   ```bash
   make mount  # Enter OpenLane Docker container
   ./flow.tcl -design . -tag run1
   ```

3. **Check results**:
   ```bash
   cd runs/run1/reports/
   ```

### Memory Macros

The SRAM macros have been generated using OpenRAM:
- **Status**: ✅ All macros generated successfully
- **Location**: `macros/openram_output/`
- **Files per macro**: `.v`, `.lib`, `.lef`, `.gds`, `.html` (datasheet)

**Important**: Each cache uses 64-bit word SRAMs:
- L1 I-Cache: 32 instances (4 ways × 8 slices)
- L1 D-Cache: 32 instances (4 ways × 8 slices)
- L2 Cache: 64 instances (8 ways × 8 slices) for 256KB
- TLB: 1 instance

## 📊 Design Status

### ✅ Completed
- [x] Project structure and build system
- [x] Configuration headers (ISA, memory map, opcodes)
- [x] Top-level SoC integration
- [x] OpenLane configuration
- [x] OpenRAM SRAM generation (all 4 configs)
- [x] 5-stage pipeline skeleton (basic RV32I)

### 🚧 In Progress
- [ ] Complete CPU core implementation
  - [ ] Full RV32IMAF instruction decode
  - [ ] Hazard detection and forwarding unit
  - [ ] Multiplier/Divider unit
  - [ ] Floating-Point Unit
  - [ ] Branch predictor
- [ ] Memory subsystem
  - [ ] L1 I-Cache controller
  - [ ] L1 D-Cache controller
  - [ ] L2 Cache controller
  - [ ] MMU and TLB implementation
- [ ] Peripherals
  - [ ] CSR unit
  - [ ] PLIC
  - [ ] CLINT
  - [ ] UART
  - [ ] GPIO
  - [ ] Debug module

### 📝 To Do
- [ ] Comprehensive testbench
- [ ] RISC-V compliance tests
- [ ] Timing closure iterations
- [ ] Power analysis
- [ ] Documentation

## 🎯 Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Process | 130nm | scn4m_subm or sky130 |
| Clock | 500 MHz | 2.0 ns period |
| IPC | ~0.9 | On integer workloads |
| Area | ~25 mm² | 5mm × 5mm die |
| L1 Latency | 1-2 cycles | Hit latency |
| L2 Latency | 8-12 cycles | Hit latency |

## 🔧 Key Design Decisions

### Cache Organization
- **64-bit SRAM words** instead of 512-bit for OpenRAM compatibility
- **Multiple instances per way** (8 instances = 1 cache line)
- **Separate tag and data arrays** for better area efficiency

### Pipeline
- **In-order execution** for v1 (out-of-order in v2)
- **Simple branch prediction** (2-bit saturating counters)
- **Data forwarding** to reduce stalls

### Memory Interface
- **Write-back caches** for better performance
- **Simple bus protocol** (AMBA-Lite style)
- **Store buffer** to hide write latency

## 📚 References

- [RISC-V ISA Specification](https://riscv.org/technical/specifications/)
- [RISC-V Privileged Spec](https://riscv.org/technical/specifications/)
- [OpenRAM Documentation](https://openram.org/)
- [OpenLane Documentation](https://openlane.readthedocs.io/)

## 📄 License

[Add your license here]

## 👥 Contributors

[Add contributors]

---

**Note**: This is an active development project. The core has been scaffolded but many modules need implementation. See the Design Status section for current progress.
