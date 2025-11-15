# =============================================================================
# Hierarchical Yosys Synthesis Script for Clownfish RISC-V v2
# =============================================================================
# This script performs hierarchical synthesis WITHOUT flattening
# Designed for 2M+ gate designs with large cache modules
# =============================================================================

yosys -import

# Read Sky130 standard cell library
read_liberty -lib $::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# Read design files
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

# CRITICAL: Use proc command to convert processes to netlists
proc

# Optimize (but DON'T flatten)
opt

# FSM extraction and optimization
fsm
opt

# Memory mapping
memory -nomap
opt

# Technology mapping - hierarchical, no flattening
techmap
opt

# ABC synthesis - use AREA script (lightest)
# Synthesize each module separately to avoid OOM
puts "Starting ABC synthesis on individual modules..."

# Use abc with minimal script for large modules
abc -g AND -liberty $::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# Final cleanup
opt_clean -purge

# Rename internal signals for readability
autoname

# Generate statistics
tee -o synth_stats.txt stat -liberty $::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# Check hierarchy is preserved
tee -o hierarchy_check.txt hierarchy -check

# Write synthesized netlist (BLIF format for OpenROAD)
write_blif -gates clownfish_synth.blif

# Also write Verilog for inspection
write_verilog -noattr -noexpr -nohex -nodec clownfish_synth.v

# Print summary
puts "========================================="
puts "Hierarchical synthesis complete!"
puts "Output files:"
puts "  - clownfish_synth.blif (for OpenROAD)"
puts "  - clownfish_synth.v (Verilog netlist)"
puts "  - synth_stats.txt (statistics)"
puts "  - hierarchy_check.txt (hierarchy info)"
puts "========================================="
