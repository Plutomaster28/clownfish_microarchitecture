#!/bin/bash
echo "Checking all VERILOG_FILES..."
files=(
    "clownfish_soc_v2_no_l2_rtl.v"
    "rtl/core/clownfish_core_v2.v"
    "rtl/clusters/execution_cluster.v"
    "hierarchical_synth/simple_alu_synth.v"
    "hierarchical_synth/complex_alu_synth.v"
    "hierarchical_synth/mul_div_unit_synth.v"
    "hierarchical_synth/fpu_unit_synth.v"
    "hierarchical_synth/vector_unit_synth.v"
    "hierarchical_synth/lsu_synth.v"
    "hierarchical_synth/gshare_predictor_synth.v"
    "hierarchical_synth/bimodal_predictor_synth.v"
    "hierarchical_synth/tournament_selector_synth.v"
    "hierarchical_synth/btb_synth.v"
    "hierarchical_synth/ras_synth.v"
    "hierarchical_synth/register_rename_synth.v"
    "hierarchical_synth/reservation_station_synth.v"
    "hierarchical_synth/reorder_buffer_synth.v"
    "hierarchical_synth/l1_icache_synth.v"
    "hierarchical_synth/l1_dcache_new_synth.v"
)

missing=0
for f in "${files[@]}"; do
    if [ -f "$f" ]; then
        echo "✓ $f"
    else
        echo "✗ MISSING: $f"
        ((missing++))
    fi
done

echo ""
if [ $missing -eq 0 ]; then
    echo "✅ All files present!"
else
    echo "❌ $missing files missing!"
fi
