# OpenRAM Configuration Files for Clownfish RISC-V Processor

This directory contains OpenRAM configuration files for generating SRAM macros for the processor's memory hierarchy.

## Cache Specifications

- **L1 Instruction Cache**: 32KB, 4-way set associative, 64-byte lines
- **L1 Data Cache**: 32KB, 4-way set associative, 64-byte lines  
- **L2 Unified Cache**: 256-512KB, 8-16 way set associative, 64-byte lines
- **TLB**: 64 entries

## Configuration Files

### `l1_icache_config.py`
- Generates SRAM for ONE way of the L1 I-cache
- 512 bits × 128 words (64 bytes × 128 lines = 8KB per way)
- Instantiate 4 times in your design for 4-way associativity

### `l1_dcache_config.py`
- Generates SRAM for ONE way of the L1 D-cache
- 512 bits × 128 words (64 bytes × 128 lines = 8KB per way)
- Instantiate 4 times in your design for 4-way associativity

### `l2_cache_config.py`
- Generates SRAM for ONE way of the L2 cache
- 512 bits × 512 words (64 bytes × 512 lines = 32KB per way)
- For 256KB L2: Instantiate 8 times (8-way)
- For 512KB L2: Instantiate 16 times (16-way) or modify config

### `tlb_config.py`
- Generates SRAM for the TLB
- 64 bits × 64 entries
- Single instance for the entire TLB

## How to Generate SRAM Macros

### Prerequisites
```bash
# Install OpenRAM
git clone https://github.com/VLSIDA/OpenRAM.git
cd OpenRAM

# Set environment variables
export OPENRAM_HOME="$(pwd)/compiler"
export OPENRAM_TECH="$(pwd)/technology"
```

### Generate Each SRAM

```bash
# From the openram_configs directory
python3 $OPENRAM_HOME/openram.py l1_icache_config.py
python3 $OPENRAM_HOME/openram.py l1_dcache_config.py
python3 $OPENRAM_HOME/openram.py l2_cache_config.py
python3 $OPENRAM_HOME/openram.py tlb_config.py
```

### Generated Files

Each configuration will produce:
- `.v` - Verilog behavioral model
- `.lef` - Physical layout abstract (for OpenLane)
- `.lib` - Liberty timing file (for OpenLane)
- `.gds` - GDSII layout (for OpenLane)
- `.sp` - Spice netlist
- `.html` - Datasheet with specifications

## Usage in Verilog

### L1 Instruction Cache Example
```verilog
// Instantiate 4 ways for 4-way set associative
genvar i;
generate
    for (i = 0; i < 4; i = i + 1) begin : icache_ways
        sram_l1_icache_way way (
            .clk0(clk),
            .csb0(icache_csb[i]),
            .web0(icache_web[i]),
            .wmask0(icache_wmask[i]),
            .addr0(icache_addr[i]),
            .din0(icache_din[i]),
            .dout0(icache_dout[i])
        );
    end
endgenerate
```

## Technology Node

Default configuration uses **Sky130** (130nm). To change:

1. Edit the `technology_name` parameter in each config file
2. Available options:
   - `"sky130"` - SkyWater 130nm (open PDK)
   - `"scn4m_subm"` - Generic submicron (for testing)
   - `"freepdk45"` - FreePDK 45nm

## Memory Organization Summary

| Component | Total Size | Word Size | Num Words | Instances | Associativity |
|-----------|------------|-----------|-----------|-----------|---------------|
| L1 I-Cache | 32KB | 512 bits | 128 | 4 | 4-way |
| L1 D-Cache | 32KB | 512 bits | 128 | 4 | 4-way |
| L2 Cache | 256KB | 512 bits | 512 | 8 | 8-way |
| L2 Cache | 512KB | 512 bits | 512 | 16 | 16-way |
| TLB | 512 bytes | 64 bits | 64 | 1 | N/A |

## Notes

- Each cache line is 64 bytes (512 bits) as specified
- Write masks enable byte-level writes (8-bit granularity)
- TLB uses standard SRAM; CAM-like behavior must be implemented in RTL
- L2 can be scaled from 256KB to 512KB by adjusting number of ways
- All SRAMs use single-ported configuration (can be modified for dual-port)
