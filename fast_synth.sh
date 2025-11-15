#!/bin/bash
# Ultra-fast synthesis with NO optimization - just parse to gates

DESIGN_DIR="/home/miyamii/clownfish_microarchitecture"
PDK_ROOT="/home/miyamii/.ciel"

echo "Starting FAST synthesis (no optimization)..."
echo "This should complete in under 5 minutes"

/usr/bin/yosys -p "
# Read stdlib
read_liberty -lib $PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# Read SRAMs as blackboxes
read_verilog -lib $DESIGN_DIR/macros/openram_output/sram_l1_icache_way.v
read_verilog -lib $DESIGN_DIR/macros/openram_output/sram_l1_dcache_way.v  
read_verilog -lib $DESIGN_DIR/macros/openram_output/sram_l2_cache_way.v
read_verilog -lib $DESIGN_DIR/macros/openram_output/sram_tlb.v

# Read design (use -sv for SystemVerilog support)
read_verilog -sv $DESIGN_DIR/clownfish_soc_v2.v
read_verilog -sv $DESIGN_DIR/rtl/core/clownfish_core_v2.v
read_verilog -sv $DESIGN_DIR/rtl/execution/simple_alu.v
read_verilog -sv $DESIGN_DIR/rtl/execution/complex_alu.v
read_verilog -sv $DESIGN_DIR/rtl/execution/mul_div_unit.v
read_verilog -sv $DESIGN_DIR/rtl/execution/fpu_unit.v
read_verilog -sv $DESIGN_DIR/rtl/execution/vector_unit.v
read_verilog -sv $DESIGN_DIR/rtl/execution/lsu.v
read_verilog -sv $DESIGN_DIR/rtl/ooo/reorder_buffer.v
read_verilog -sv $DESIGN_DIR/rtl/ooo/reservation_station.v
read_verilog -sv $DESIGN_DIR/rtl/ooo/register_rename.v
read_verilog -sv $DESIGN_DIR/rtl/predictor/gshare_predictor.v
read_verilog -sv $DESIGN_DIR/rtl/predictor/bimodal_predictor.v
read_verilog -sv $DESIGN_DIR/rtl/predictor/tournament_selector.v
read_verilog -sv $DESIGN_DIR/rtl/predictor/btb.v
read_verilog -sv $DESIGN_DIR/rtl/predictor/ras.v
read_verilog -sv $DESIGN_DIR/rtl/predictor/branch_predictor.v
read_verilog -sv $DESIGN_DIR/rtl/memory/l1_icache.v
read_verilog -sv $DESIGN_DIR/rtl/memory/l1_dcache_new.v
read_verilog -sv $DESIGN_DIR/rtl/memory/l2_cache_new.v

# Hierarchy check
hierarchy -check -top clownfish_soc_v2

# Process to netlist
proc; opt

# Simple logic optimization
opt_clean

# Map flip-flops ONLY (no combinatorial optimization!)
dfflibmap -liberty $PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# Write MINIMAL netlist
write_verilog -noattr clownfish_fast.v

# Stats
stat

" 2>&1 | tee fast_synth.log

echo ""
echo "===================================="
if [ -f clownfish_fast.v ]; then
    echo "SUCCESS! Netlist: clownfish_fast.v"
    ls -lh clownfish_fast.v
else
    echo "FAILED - check fast_synth.log"
fi
echo "===================================="
