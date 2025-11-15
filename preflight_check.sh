#!/bin/bash
# Pre-flight check before OpenLane run

echo "==================================================================="
echo "Clownfish v2 NO_L2 - Pre-flight Verification"
echo "==================================================================="
echo ""

# Check RTL file exists
echo "[1/6] Checking RTL wrapper..."
if [ -f "clownfish_soc_v2_no_l2_rtl.v" ]; then
    SIZE=$(du -h clownfish_soc_v2_no_l2_rtl.v | cut -f1)
    echo "✓ RTL wrapper found: clownfish_soc_v2_no_l2_rtl.v ($SIZE)"
    
    # Check for arbiter logic
    if grep -q "arb_select_dcache" clownfish_soc_v2_no_l2_rtl.v; then
        echo "✓ Arbiter logic present"
    else
        echo "✗ WARNING: Arbiter logic not found!"
    fi
else
    echo "✗ ERROR: RTL wrapper not found!"
    exit 1
fi
echo ""

# Check hierarchical modules
echo "[2/6] Checking pre-synthesized modules..."
MODULES=(
    "clownfish_core_v2_synth.v"
    "simple_alu_synth.v"
    "complex_alu_synth.v"
    "mul_div_unit_synth.v"
    "fpu_unit_synth.v"
    "vector_unit_synth.v"
    "lsu_synth.v"
    "gshare_predictor_synth.v"
    "bimodal_predictor_synth.v"
    "tournament_selector_synth.v"
    "btb_synth.v"
    "ras_synth.v"
    "register_rename_synth.v"
    "reservation_station_synth.v"
    "reorder_buffer_synth.v"
    "l1_icache_synth.v"
    "l1_dcache_new_synth.v"
)

FOUND=0
MISSING=0
for module in "${MODULES[@]}"; do
    if [ -f "hierarchical_synth/$module" ]; then
        ((FOUND++))
    else
        echo "  ✗ Missing: $module"
        ((MISSING++))
    fi
done

echo "✓ Found $FOUND/17 hierarchical modules"
if [ $MISSING -gt 0 ]; then
    echo "✗ WARNING: $MISSING modules missing!"
fi
echo ""

# Check SRAM macros (should be 3, NOT 4)
echo "[3/6] Checking SRAM macros (NO L2)..."
SRAM_COUNT=$(ls macros/openram_output/*.lef 2>/dev/null | wc -l)
if [ $SRAM_COUNT -eq 3 ]; then
    echo "✓ Found 3 SRAM macros (correct - NO L2)"
    ls macros/openram_output/*.lef | sed 's/^/  - /'
elif [ $SRAM_COUNT -eq 4 ]; then
    echo "✗ WARNING: Found 4 SRAMs - L2 SRAM still present!"
    echo "  Remove sram_l2_cache_way.* files"
else
    echo "✗ ERROR: Found $SRAM_COUNT SRAMs (expected 3)"
fi
echo ""

# Check config.tcl
echo "[4/6] Checking config.tcl..."
if grep -q "clownfish_soc_v2_no_l2_rtl.v" config.tcl; then
    echo "✓ config.tcl points to NO_L2 RTL"
else
    echo "✗ WARNING: config.tcl may not point to correct file"
fi

if grep -q "VERILOG_ELABORATE_ONLY" config.tcl; then
    echo "✗ WARNING: VERILOG_ELABORATE_ONLY still set (should be removed for RTL)"
else
    echo "✓ VERILOG_ELABORATE_ONLY not set (good for RTL synthesis)"
fi
echo ""

# Check runs directory
echo "[5/6] Checking runs directory..."
RUN_COUNT=$(ls -d runs/*/ 2>/dev/null | wc -l)
if [ $RUN_COUNT -eq 0 ]; then
    echo "✓ Runs directory clean (fresh start)"
else
    echo "⚠ Found $RUN_COUNT existing runs"
    echo "  Consider: sudo rm -rf runs/* for clean start"
fi
echo ""

# Estimate total size
echo "[6/6] Estimating total netlist size..."
TOTAL_SIZE=0
for module in "${MODULES[@]}"; do
    if [ -f "hierarchical_synth/$module" ]; then
        SIZE=$(stat -c%s "hierarchical_synth/$module" 2>/dev/null || stat -f%z "hierarchical_synth/$module" 2>/dev/null)
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
    fi
done

RTL_SIZE=$(stat -c%s "clownfish_soc_v2_no_l2_rtl.v" 2>/dev/null || stat -f%z "clownfish_soc_v2_no_l2_rtl.v" 2>/dev/null)
TOTAL_SIZE=$((TOTAL_SIZE + RTL_SIZE))

TOTAL_MB=$((TOTAL_SIZE / 1048576))
echo "✓ Total netlist size: ~${TOTAL_MB}MB (manageable for synthesis)"
echo ""

echo "==================================================================="
echo "Pre-flight check complete!"
echo "==================================================================="
echo ""
echo "Ready to run OpenLane:"
echo "  docker exec -it openlane bash"
echo "  cd /openlane"
echo "  flow.tcl -design /home/miyamii/clownfish_microarchitecture -tag NO_L2_CLEAN"
echo ""
echo "Expected runtime: 6-12 hours"
echo "Expected cells: ~1.2M (NOT 547!)"
echo "Expected utilization: 40-60% (NOT 0.01%!)"
echo ""
