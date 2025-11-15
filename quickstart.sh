#!/bin/bash
# ============================================================================
# Clownfish RISC-V Processor - Quick Start Script
# ============================================================================

set -e  # Exit on error

echo "=============================================="
echo "  Clownfish RISC-V Processor - Quick Start"
echo "=============================================="
echo ""

# Check if we're in the right directory
if [ ! -f "config.tcl" ]; then
    echo "Error: config.tcl not found. Please run this script from the project root."
    exit 1
fi

# Display project status
echo "📋 Project Status:"
echo "  ✓ Project structure created"
echo "  ✓ Top-level SoC (clownfish_soc.v)"
echo "  ✓ CPU core skeleton (rtl/core/clownfish_core.v)"
echo "  ✓ OpenLane configuration (config.tcl)"
echo "  ✓ Timing constraints (constraints/clownfish.sdc)"
echo "  ✓ OpenRAM SRAMs generated (129 instances)"
echo ""

# Display memory macro status
echo "💾 Memory Macros:"
SRAM_COUNT=$(ls macros/openram_output/*.v 2>/dev/null | wc -l)
echo "  Found $SRAM_COUNT SRAM Verilog files in macros/openram_output/"
if [ $SRAM_COUNT -gt 0 ]; then
    echo "  ✓ L1 I-Cache SRAM"
    echo "  ✓ L1 D-Cache SRAM"
    echo "  ✓ L2 Cache SRAM"
    echo "  ✓ TLB SRAM"
fi
echo ""

# Check RTL file count
echo "🔧 RTL Status:"
RTL_COUNT=$(find rtl -name "*.v" 2>/dev/null | wc -l)
echo "  RTL files: $RTL_COUNT"
echo "  Core modules: $(find rtl/core -name "*.v" 2>/dev/null | wc -l)"
echo "  Memory modules: $(find rtl/memory -name "*.v" 2>/dev/null | wc -l)"
echo "  Peripheral modules: $(find rtl/peripherals -name "*.v" 2>/dev/null | wc -l)"
echo ""

# Display next steps
echo "🚀 Next Steps:"
echo ""
echo "1. Implementation Priority:"
echo "   □ Complete instruction decoder (RV32IMAF)"
echo "   □ Add hazard detection & forwarding"
echo "   □ Implement execution units (MUL/DIV/FPU)"
echo "   □ Create cache controllers"
echo "   □ Implement MMU and TLB"
echo "   □ Add CSR unit and system components"
echo ""

echo "2. For Development:"
echo "   - Edit RTL files in rtl/core/, rtl/memory/, rtl/peripherals/"
echo "   - Use include/clownfish_config.vh for global config"
echo "   - Use include/riscv_opcodes.vh for instruction encoding"
echo ""

echo "3. To Run Synthesis (when RTL is complete):"
echo "   cd $(pwd)"
echo "   # Make sure OpenLane is installed"
echo "   make mount  # Enter OpenLane container"
echo "   ./flow.tcl -design . -tag run1"
echo ""

echo "4. To Regenerate SRAMs (if needed):"
echo "   cd openram_configs"
echo "   bash generate_all.sh"
echo ""

echo "5. For Testing:"
echo "   - Create testbenches in testbench/"
echo "   - Use Verilator or Icarus Verilog"
echo "   - Run RISC-V compliance tests"
echo ""

# Check for optional tools
echo "🔍 Tool Check:"
which verilator > /dev/null 2>&1 && echo "  ✓ Verilator found" || echo "  ✗ Verilator not found (optional)"
which iverilog > /dev/null 2>&1 && echo "  ✓ Icarus Verilog found" || echo "  ✗ Icarus Verilog not found (optional)"
[ -d ~/OpenRAM ] && echo "  ✓ OpenRAM found at ~/OpenRAM" || echo "  ✗ OpenRAM not found"
echo ""

# Display documentation
echo "📚 Documentation:"
echo "  - README.md - Main project documentation"
echo "  - IMPLEMENTATION_SUMMARY.md - Detailed implementation guide"
echo "  - openram_configs/GENERATION_STATUS.md - SRAM generation guide"
echo ""

# Display quick reference
echo "📖 Quick Reference:"
echo "  Target Clock: 500 MHz (2.0 ns period)"
echo "  Process: 130nm (scn4m_subm / sky130)"
echo "  Die Size: 5mm × 5mm (~25 mm²)"
echo "  SRAM Instances: 129 total"
echo "    - L1 I-Cache: 32 instances"
echo "    - L1 D-Cache: 32 instances"
echo "    - L2 Cache: 64 instances"
echo "    - TLB: 1 instance"
echo ""

echo "=============================================="
echo "  Ready to build Clownfish! 🐠"
echo "=============================================="
echo ""
echo "For detailed information, see:"
echo "  cat README.md"
echo "  cat IMPLEMENTATION_SUMMARY.md"
echo ""
