# OpenRAM Cache Generation Status

## Setup Complete ✓

The OpenRAM environment has been properly configured and all necessary dependencies have been installed.

### Environment Setup
- **OpenRAM Location**: `~/OpenRAM`
- **Technology**: `scn4m_subm` (with sky130 also available)
- **Python Environment**: Conda environment with all dependencies installed
- **Missing Import Fixed**: Added `lef_rom_interconnect` to scn4m_subm technology

### Configuration Files Updated

All configuration files have been optimized for better OpenRAM compatibility:

####  1. **L1 Instruction Cache** (`l1_icache_config.py`)
   - **Word Size**: 64 bits (8 bytes) - reduced from 512 bits
   - **Number of Words**: 128
   - **Configuration**: 1 RW port, 1 bank
   - **Note**: Need 8 instances per way for full 64-byte cache line
   - **Total Instances Needed**: 4 ways × 8 = **32 SRAM macros**

#### 2. **L1 Data Cache** (`l1_dcache_config.py`)
   - **Word Size**: 64 bits (8 bytes)
   - **Number of Words**: 128
   - **Configuration**: 1 RW port, 1 bank
   - **Note**: Need 8 instances per way for full 64-byte cache line
   - **Total Instances Needed**: 4 ways × 8 = **32 SRAM macros**

#### 3. **L2 Unified Cache** (`l2_cache_config.py`)
   - **Word Size**: 64 bits (8 bytes)
   - **Number of Words**: 512
   - **Configuration**: 1 RW port, 1 bank
   - **Note**: Need 8 instances per way for full 64-byte cache line
   - **For 256KB**: 8 ways × 8 = **64 SRAM macros**
   - **For 512KB**: 16 ways × 8 = **128 SRAM macros**

#### 4. **TLB** (`tlb_config.py`)
   - **Word Size**: 64 bits
   - **Number of Words**: 64 entries
   - **Configuration**: 1 RW port, 1 R port, 1 bank
   - **Total Instances Needed**: **1 SRAM macro**

## Generation Script

The `generate_all.sh` script has been updated with the correct OpenRAM paths and environment setup:

```bash
#!/bin/bash
# Set up OpenRAM environment
cd ~/OpenRAM
source setpaths.sh
source ~/OpenRAM/miniconda/bin/activate
cd - > /dev/null

# Then runs generation for all configs
```

## How to Run Generation

### Generate All Cache Modules
```bash
cd ~/clownfish_microarchitecture/openram_configs
bash generate_all.sh
```

### Generate Individual Modules
```bash
cd ~/clownfish_microarchitecture/openram_configs
source ~/OpenRAM/setpaths.sh
source ~/OpenRAM/miniconda/bin/activate
python3 ~/OpenRAM/sram_compiler.py <config_file>.py
```

## Important Notes

### Generation Time
- **Each SRAM takes 5-30 minutes** to generate depending on size
- L1 caches: ~5-10 minutes each
- L2 cache: ~15-30 minutes  
- TLB: ~3-5 minutes
- **Total time estimate**: 30-60 minutes for all configs

### Why 64-bit Words?
OpenRAM has performance and stability issues with very wide word sizes (512+ bits). The original configs used 512-bit words which caused the compiler to hang. By using 64-bit words:
- Generation is much faster
- More stable compilation
- Better area/timing results
- More flexible memory organization

### Hardware Implementation
When instantiating in your RTL:
- For L1 I-cache: Instantiate 32 SRAMs (4 ways × 8 slices)
- For L1 D-cache: Instantiate 32 SRAMs (4 ways × 8 slices)
- For L2 cache: Instantiate 64 or 128 SRAMs depending on size
- For TLB: Instantiate 1 SRAM

Each 64-byte cache line is split across 8 SRAM instances (8 bytes each).

## Output Files

Generated files will be in: `../macros/openram_output/`

For each SRAM, you'll get:
- `.v` - Verilog netlist
- `.sp` - SPICE netlist
- `.lib` - Liberty timing file
- `.lef` - LEF physical layout
- `.gds` - GDSII layout
- `.html` - Datasheet with specs
- `.log` - Generation log

## Troubleshooting

If generation fails:
1. Check that OPENRAM_HOME and OPENRAM_TECH are set
2. Verify conda environment is activated
3. Check log files in `../macros/openram_output/`
4. Try generating one config at a time

## Next Steps

After successful generation:
1. Review the `.html` datasheets for timing/area info
2. Integrate `.v` files into your processor RTL
3. Use `.lib` files for synthesis
4. Use `.lef` and `.gds` for place & route
5. Create wrapper modules to instantiate multiple SRAMs per cache way
