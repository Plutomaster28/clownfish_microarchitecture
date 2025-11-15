#!/bin/bash
# ============================================================================
# Clownfish v2 - OpenLane Synthesis Preparation
# ============================================================================

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║            🚀 CLOWNFISH v2 - OPENLANE SYNTHESIS PREP 🚀                  ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if OpenLane is installed
if [ ! -d "$OPENLANE_ROOT" ] && [ ! -d "/openlane" ]; then
    echo "⚠️  WARNING: OpenLane not found!"
    echo "   Set OPENLANE_ROOT or install OpenLane first"
    echo "   https://github.com/The-OpenROAD-Project/OpenLane"
    echo ""
fi

# Design info
echo "📊 DESIGN INFORMATION:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Design Name:        clownfish_soc_v2"
echo "Top Module:         clownfish_soc_v2.v"
echo "Architecture:       14-stage Out-of-Order Superscalar"
echo "Clock Target:       1.0 GHz (1.0 ns period)"
echo "Process:            130nm (sky130)"
echo ""

# Count RTL files
echo "📁 RTL FILES:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RTL_COUNT=$(find rtl -name "*.v" -type f | wc -l)
RTL_LINES=$(find rtl -name "*.v" -type f -exec wc -l {} + | tail -1 | awk '{print $1}')
echo "Total RTL files:    $RTL_COUNT files"
echo "Total RTL lines:    $RTL_LINES lines"
echo ""

# List main components
echo "✅ COMPONENTS:"
echo "   • clownfish_soc_v2.v          (SOC wrapper)"
echo "   • clownfish_core_v2.v         (14-stage OoO core)"
echo "   • Execution Units (6)         (ALU×2, Complex, MUL/DIV, FPU, Vector, LSU)"
echo "   • OoO Infrastructure (3)      (ROB, RS, Register Rename)"
echo "   • Branch Predictor (6)        (GShare, Bimodal, Selector, BTB, RAS, Top)"
echo "   • Memory Hierarchy (3)        (L1I, L1D, L2)"
echo ""

# Check for syntax issues
echo "🔍 QUICK SYNTAX CHECK:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if command -v iverilog &> /dev/null; then
    echo "Running iverilog syntax check..."
    iverilog -t null -I include -g2009 clownfish_soc_v2.v 2>&1 | head -20
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo "✅ No critical syntax errors detected"
    else
        echo "⚠️  Some syntax issues found (Yosys might still handle them)"
    fi
else
    echo "⚠️  iverilog not found - skipping syntax check"
    echo "   (Yosys will handle this during synthesis)"
fi
echo ""

# Synthesis recommendations
echo "🚀 READY FOR OPENLANE SYNTHESIS!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 NEXT STEPS:"
echo "   1. Start OpenLane interactive mode:"
echo "      make mount"
echo ""
echo "   2. Run synthesis:"
echo "      ./flow.tcl -design clownfish_microarchitecture -tag v2_test"
echo ""
echo "   3. Or just synthesis step:"
echo "      ./flow.tcl -design clownfish_microarchitecture -tag v2_test -synth_only"
echo ""
echo "⚙️  SYNTHESIS PARAMETERS (from config.tcl):"
echo "   • Clock Period:     1.0 ns (1.0 GHz target - AGGRESSIVE!)"
echo "   • Strategy:         DELAY 1 (timing optimized)"
echo "   • Core Utilization: 50% (room for routing)"
echo "   • Max Fanout:       6 (conservative)"
echo ""
echo "⚠️  IMPORTANT NOTES:"
echo "   • First run will likely have timing violations (1.0 GHz is tough!)"
echo "   • Start with synthesis only to check resource usage"
echo "   • Expect ~1.5M-2.5M gates (large design!)"
echo "   • May need to reduce clock to 500-800 MHz for timing closure"
echo "   • Pipeline stages might need retiming"
echo ""
echo "🎯 REALISTIC EXPECTATIONS:"
echo "   • 500-700 MHz:  Very achievable"
echo "   • 800-900 MHz:  Possible with optimization"
echo "   • 1.0 GHz:      Stretch goal, needs careful tuning"
echo "   • 1.3 GHz:      Extremely difficult on 130nm"
echo ""
echo "Good luck! You're about to synthesize a Pentium 4 competitor! 🔥"
echo ""
