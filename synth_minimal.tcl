# =============================================================================
# MINIMAL Hierarchical Yosys Synthesis - NO ABC OPTIMIZATION
# =============================================================================
# This skips ABC entirely to avoid OOM
# Will produce larger netlist but completes synthesis
# =============================================================================

yosys -import

# Read Sky130 standard cell library
read_liberty -lib $::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# Read ALL design files
read_verilog $::env(DESIGN_DIR)/clownfish_soc_v2.v
read_verilog $::env(DESIGN_DIR)/rtl/core/clownfish_core_v2.v
read_verilog $::env(DESIGN_DIR)/rtl/execution/simple_alu.v
read_verilog $::env(DESIGN_DIR)/rtl/execution/complex_alu.v
read_verilog $::env(DESIGN_DIR)/rtl/execution/mul_div_unit.v
read_verilog $::env(DESIGN_DIR)/rtl/execution/fpu_unit.v
read_verilog $::env(DESIGN_DIR)/rtl/execution/vector_unit.v
read_verilog $::env(DESIGN_DIR)/rtl/execution/lsu.v
read_verilog $::env(DESIGN_DIR)/rtl/ooo/reorder_buffer.v
read_verilog $::env(DESIGN_DIR)/rtl/ooo/reservation_station.v
read_verilog $::env(DESIGN_DIR)/rtl/ooo/register_rename.v
read_verilog $::env(DESIGN_DIR)/rtl/predictor/gshare_predictor.v
read_verilog $::env(DESIGN_DIR)/rtl/predictor/bimodal_predictor.v
read_verilog $::env(DESIGN_DIR)/rtl/predictor/tournament_selector.v
read_verilog $::env(DESIGN_DIR)/rtl/predictor/btb.v
read_verilog $::env(DESIGN_DIR)/rtl/predictor/ras.v
read_verilog $::env(DESIGN_DIR)/rtl/predictor/branch_predictor.v
read_verilog $::env(DESIGN_DIR)/rtl/memory/l1_icache.v
read_verilog $::env(DESIGN_DIR)/rtl/memory/l1_dcache_new.v
read_verilog $::env(DESIGN_DIR)/rtl/memory/l2_cache_new.v

# Read SRAM blackbox models
read_verilog -lib $::env(DESIGN_DIR)/macros/openram_output/sram_l1_icache_way.v
read_verilog -lib $::env(DESIGN_DIR)/macros/openram_output/sram_l1_dcache_way.v
read_verilog -lib $::env(DESIGN_DIR)/macros/openram_output/sram_l2_cache_way.v
read_verilog -lib $::env(DESIGN_DIR)/macros/openram_output/sram_tlb.v

# Set top module
hierarchy -check -top clownfish_soc_v2

# Convert processes to netlists
proc; opt

# FSM extraction
fsm; opt

# Memory mapping
memory -nomap; opt

# Simple techmap - NO ABC!
techmap; opt

# Map remaining logic to standard cells using dfflibmap
dfflibmap -liberty $::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
opt

# Clean up
opt_clean -purge
autoname

# Statistics
tee -o synth_stats.txt stat -liberty $::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# Write outputs
write_verilog -noattr -noexpr -nohex -nodec clownfish_synth.v

puts "========================================="
puts "Minimal synthesis complete (NO ABC)!"
puts "Netlist: clownfish_synth.v"
puts "Note: Unoptimized - OpenROAD will handle optimization"
puts "========================================="
