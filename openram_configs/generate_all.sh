#!/bin/bash
# Script to generate all OpenRAM macros for Clownfish RISC-V processor

# Set up OpenRAM environment
cd ~/OpenRAM
source setpaths.sh
source ~/OpenRAM/miniconda/bin/activate
cd - > /dev/null

# Create output directory
mkdir -p ../macros/openram_output

echo "========================================="
echo "Generating OpenRAM macros for Clownfish"
echo "========================================="
echo ""
echo "Note: Each SRAM may take several minutes to generate."
echo ""

# Generate L1 Instruction Cache
echo "Generating L1 Instruction Cache SRAM..."
python3 ~/OpenRAM/sram_compiler.py l1_icache_config.py
if [ $? -ne 0 ]; then
    echo "Error generating L1 I-cache"
    exit 1
fi
echo "✓ L1 I-cache generated"
echo ""

# Generate L1 Data Cache
echo "Generating L1 Data Cache SRAM..."
python3 ~/OpenRAM/sram_compiler.py l1_dcache_config.py
if [ $? -ne 0 ]; then
    echo "Error generating L1 D-cache"
    exit 1
fi
echo "✓ L1 D-cache generated"
echo ""

# Generate L2 Cache
echo "Generating L2 Unified Cache SRAM..."
python3 ~/OpenRAM/sram_compiler.py l2_cache_config.py
if [ $? -ne 0 ]; then
    echo "Error generating L2 cache"
    exit 1
fi
echo "✓ L2 cache generated"
echo ""

# Generate TLB
echo "Generating TLB SRAM..."
python3 ~/OpenRAM/sram_compiler.py tlb_config.py
if [ $? -ne 0 ]; then
    echo "Error generating TLB"
    exit 1
fi
echo "✓ TLB generated"
echo ""

echo "========================================="
echo "All SRAM macros generated successfully!"
echo "========================================="
echo ""
echo "Generated files are in: ../macros/openram_output/"
echo ""
echo "Next steps:"
echo "1. Review the generated .html datasheets"
echo "2. Copy the required files (.v, .lef, .lib, .gds) to your OpenLane project"
echo "3. Update your OpenLane config.json with the macro paths"
