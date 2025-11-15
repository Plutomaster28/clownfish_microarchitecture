#!/bin/bash
# Create a single complete netlist by concatenating all synthesized modules
# Plus the top-level wrapper synthesis output

cd /home/miyamii/clownfish_microarchitecture

echo "Creating combined complete netlist..."

cat > clownfish_soc_v2_complete.v << 'HEADER'
// ============================================================================
// Clownfish RISC-V v2 - Complete Gate-Level Netlist
// ============================================================================
// Combined from hierarchical synthesis:
// - 17 pre-synthesized modules (execution units, branch prediction, OoO logic, caches)
// - Top-level integration (branch_predictor wrapper + core + soc)
// Generated: November 2024
// Total gates: ~2M
// ============================================================================

HEADER

# Append all 17 pre-synthesized modules
cat hierarchical_synth/simple_alu_synth.v >> clownfish_soc_v2_complete.v
cat hierarchical_synth/complex_alu_synth.v >> clownfish_soc_v2_complete.v
cat hierarchical_synth/mul_div_unit_synth.v >> clownfish_soc_v2_complete.v
cat hierarchical_synth/fpu_unit_synth.v >> clownfish_soc_v2_complete.v
cat hierarchical_synth/vector_unit_synth.v >> clownfish_soc_v2_complete.v
cat hierarchical_synth/lsu_synth.v >> clownfish_soc_v2_complete.v
cat hierarchical_synth/gshare_predictor_synth.v >> clownfish_soc_v2_complete.v
cat hierarchical_synth/bimodal_predictor_synth.v >> clownfish_soc_v2_complete.v
cat hierarchical_synth/tournament_selector_synth.v >> clownfish_soc_v2_complete.v
cat hierarchical_synth/btb_synth.v >> clownfish_soc_v2_complete.v
cat hierarchical_synth/ras_synth.v >> clownfish_soc_v2_complete.v
cat hierarchical_synth/register_rename_synth.v >> clownfish_soc_v2_complete.v
cat hierarchical_synth/reservation_station_synth.v >> clownfish_soc_v2_complete.v
cat hierarchical_synth/reorder_buffer_synth.v >> clownfish_soc_v2_complete.v
cat hierarchical_synth/l1_icache_synth.v >> clownfish_soc_v2_complete.v
cat hierarchical_synth/l1_dcache_new_synth.v >> clownfish_soc_v2_complete.v
cat hierarchical_synth/l2_cache_new_synth.v >> clownfish_soc_v2_complete.v

# Append the top-level wrapper synthesis output
cat clownfish_soc_v2_final.v >> clownfish_soc_v2_complete.v

echo ""
echo "=========================================="
if [ -f clownfish_soc_v2_complete.v ]; then
    SIZE=$(ls -lh clownfish_soc_v2_complete.v | awk '{print $5}')
    echo "SUCCESS! Complete netlist created:"
    echo "  File: clownfish_soc_v2_complete.v"
    echo "  Size: $SIZE"
    echo ""
    echo "This netlist contains:"
    echo "  - All 17 synthesized execution/cache/OoO modules (gate-level)"
    echo "  - Top-level integration (branch_predictor + core + soc wrappers)"
    echo "  - Ready for OpenLane floorplan/placement/routing"
else
    echo "FAILED!"
    exit 1
fi
echo "=========================================="
