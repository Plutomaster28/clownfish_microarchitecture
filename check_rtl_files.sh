#!/bin/bash
echo "Checking all RTL files..."
files=(
    "clownfish_soc_v2_no_l2_rtl.v"
    "rtl/core/clownfish_core_v2.v"
    "rtl/clusters/execution_cluster.v"
    "rtl/execution/simple_alu.v"
    "rtl/execution/complex_alu.v"
    "rtl/execution/mul_div_unit.v"
    "rtl/execution/fpu_unit.v"
    "rtl/execution/vector_unit.v"
    "rtl/execution/lsu.v"
    "rtl/predictor/gshare_predictor.v"
    "rtl/predictor/bimodal_predictor.v"
    "rtl/predictor/tournament_selector.v"
    "rtl/predictor/btb.v"
    "rtl/predictor/ras.v"
    "rtl/ooo/register_rename.v"
    "rtl/ooo/reservation_station.v"
    "rtl/ooo/reorder_buffer.v"
    "rtl/memory/l1_icache.v"
    "rtl/memory/l1_dcache_new.v"
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
    echo "✅ All RTL files present!"
else
    echo "❌ $missing files missing!"
fi
