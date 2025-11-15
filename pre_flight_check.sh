#!/bin/bash
# ============================================================================
# OpenLane Pre-Flight Check for Clownfish v2 with OpenRAM Macros
# ============================================================================
# Run this before starting OpenLane to verify all macro files are present
# and the configuration is correct.

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║          OpenLane Pre-Flight Check - Clownfish v2 + OpenRAM             ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

DESIGN_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DESIGN_DIR"

ERRORS=0
WARNINGS=0

# ============================================================================
# Check 1: OpenRAM Macro Files
# ============================================================================
echo "📦 Checking OpenRAM macro files..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

MACROS=(sram_l1_icache_way sram_l1_dcache_way sram_l2_cache_way sram_tlb)

for macro in "${MACROS[@]}"; do
    echo "Checking $macro..."
    
    # LEF
    if [ -f "macros/openram_output/${macro}.lef" ]; then
        SIZE=$(ls -lh "macros/openram_output/${macro}.lef" | awk '{print $5}')
        echo "  ✅ LEF:  ${SIZE}"
    else
        echo "  ❌ LEF:  MISSING"
        ((ERRORS++))
    fi
    
    # GDS
    if [ -f "macros/openram_output/${macro}.gds" ]; then
        SIZE=$(ls -lh "macros/openram_output/${macro}.gds" | awk '{print $5}')
        echo "  ✅ GDS:  ${SIZE}"
    else
        echo "  ❌ GDS:  MISSING"
        ((ERRORS++))
    fi
    
    # Liberty (TT corner)
    if ls macros/openram_output/${macro}_TT_5p0V_25C.lib >/dev/null 2>&1; then
        SIZE=$(ls -lh macros/openram_output/${macro}_TT_5p0V_25C.lib | awk '{print $5}')
        echo "  ✅ LIB:  ${SIZE} (TT corner)"
    else
        echo "  ❌ LIB:  MISSING (TT corner)"
        ((ERRORS++))
    fi
    
    # Verilog (blackbox)
    if [ -f "macros/openram_output/${macro}.v" ]; then
        SIZE=$(ls -lh "macros/openram_output/${macro}.v" | awk '{print $5}')
        echo "  ✅ RTL:  ${SIZE}"
    else
        echo "  ❌ RTL:  MISSING"
        ((ERRORS++))
    fi
    
    echo ""
done

# ============================================================================
# Check 2: Verilog Module Names Match LEF Macros
# ============================================================================
echo "🔍 Verifying module names match LEF macros..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for macro in "${MACROS[@]}"; do
    LEF_NAME=$(grep "^MACRO" macros/openram_output/${macro}.lef | awk '{print $2}')
    RTL_NAME=$(grep "^module" macros/openram_output/${macro}.v | sed 's/module \([a-z_0-9]*\).*/\1/')
    
    if [ "$LEF_NAME" = "$RTL_NAME" ]; then
        echo "  ✅ $macro: LEF='$LEF_NAME' RTL='$RTL_NAME' (match)"
    else
        echo "  ❌ $macro: LEF='$LEF_NAME' RTL='$RTL_NAME' (MISMATCH!)"
        ((ERRORS++))
    fi
done
echo ""

# ============================================================================
# Check 3: config.tcl Settings
# ============================================================================
echo "⚙️  Checking config.tcl settings..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if grep -q "VERILOG_FILES_BLACKBOX" config.tcl; then
    echo "  ✅ VERILOG_FILES_BLACKBOX is set"
else
    echo "  ❌ VERILOG_FILES_BLACKBOX is NOT set"
    ((ERRORS++))
fi

if grep -q "EXTRA_LEFS.*glob.*openram_output" config.tcl; then
    echo "  ✅ EXTRA_LEFS points to OpenRAM output"
else
    echo "  ⚠️  EXTRA_LEFS may not be configured correctly"
    ((WARNINGS++))
fi

if grep -q "EXTRA_GDS_FILES.*glob.*openram_output" config.tcl; then
    echo "  ✅ EXTRA_GDS_FILES points to OpenRAM output"
else
    echo "  ⚠️  EXTRA_GDS_FILES may not be configured correctly"
    ((WARNINGS++))
fi

if grep -q "EXTRA_LIBS.*TT_5p0V_25C" config.tcl; then
    echo "  ✅ EXTRA_LIBS points to TT corner libs"
else
    echo "  ⚠️  EXTRA_LIBS may not be configured correctly"
    ((WARNINGS++))
fi

echo ""

# ============================================================================
# Check 4: RTL Files Exist
# ============================================================================
echo "📁 Checking core RTL files..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

RTL_FILES=(
    "clownfish_soc_v2.v"
    "rtl/core/clownfish_core_v2.v"
    "rtl/memory/l1_icache.v"
    "rtl/memory/l1_dcache_new.v"
    "rtl/memory/l2_cache_new.v"
)

for rtl in "${RTL_FILES[@]}"; do
    if [ -f "$rtl" ]; then
        echo "  ✅ $rtl"
    else
        echo "  ❌ $rtl (MISSING)"
        ((ERRORS++))
    fi
done

echo ""

# ============================================================================
# Check 5: Yosys Parse Test
# ============================================================================
echo "🧪 Running Yosys syntax check..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v yosys &> /dev/null; then
    YOSYS_LOG=$(mktemp)
    yosys -p "read_verilog -I./include -sv clownfish_soc_v2.v rtl/core/*.v rtl/memory/*.v rtl/ooo/*.v rtl/execution/*.v rtl/predictor/*.v macros/openram_output/sram*.v" > "$YOSYS_LOG" 2>&1
    
    if grep -q "Successfully finished Verilog frontend" "$YOSYS_LOG"; then
        echo "  ✅ Yosys parse successful"
    else
        echo "  ❌ Yosys parse FAILED"
        echo ""
        echo "Last 20 lines of Yosys output:"
        tail -20 "$YOSYS_LOG"
        ((ERRORS++))
    fi
    rm -f "$YOSYS_LOG"
else
    echo "  ⚠️  Yosys not found, skipping parse check"
    ((WARNINGS++))
fi

echo ""

# ============================================================================
# Summary
# ============================================================================
echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║                           SUMMARY                                        ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ All checks passed! Ready for OpenLane synthesis."
    echo ""
    echo "Next steps:"
    echo "  1. Set OPENLANE_ROOT environment variable"
    echo "  2. Run: make mount"
    echo "  3. Run: ./flow.tcl -design /path/to/clownfish_microarchitecture -tag v2_with_srams"
    echo ""
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  $WARNINGS warning(s) found, but no critical errors."
    echo "    You can proceed with synthesis, but review the warnings above."
    echo ""
    exit 0
else
    echo "❌ $ERRORS error(s) and $WARNINGS warning(s) found."
    echo "    Fix the errors above before running OpenLane."
    echo ""
    exit 1
fi
