#!/bin/bash#!/bin/bash

# Simple hierarchical synthesis runner# =============================================================================

set -e# Standalone Hierarchical Synthesis for Clownfish RISC-V v2

# =============================================================================

cd /home/miyamii/clownfish_microarchitecture/hierarchical_synth# Run Yosys synthesis without OpenLane's forced flattening

# =============================================================================

echo "======================================================"

echo "  HIERARCHICAL SYNTHESIS - Clownfish RISC-V v2"set -e  # Exit on error

echo "======================================================"

echo "Started: $(date)"# Set environment variables

echo ""export DESIGN_DIR="/home/miyamii/clownfish_microarchitecture"

export PDK_ROOT="${PDK_ROOT:-/home/miyamii/.ciel}"

YOSYS="/usr/bin/yosys"

echo "=========================================="

# Stage 1: Small units (fast)echo "Clownfish v2 Hierarchical Synthesis"

echo "[1/17] Synthesizing simple_alu..."echo "=========================================="

$YOSYS -s synth_simple_alu.ys > simple_alu.log 2>&1 && echo "  ✓ Done"echo "Design Dir: $DESIGN_DIR"

echo "PDK Root:   $PDK_ROOT"

echo "[2/17] Synthesizing complex_alu..."echo ""

$YOSYS -s synth_complex_alu.ys > complex_alu.log 2>&1 && echo "  ✓ Done"

# Check if PDK exists

echo "[3/17] Synthesizing mul_div_unit..."if [ ! -d "$PDK_ROOT/sky130A" ]; then

$YOSYS -s synth_mul_div_unit.ys > mul_div.log 2>&1 && echo "  ✓ Done"    echo "ERROR: Sky130 PDK not found at $PDK_ROOT"

    echo "Set PDK_ROOT environment variable to your PDK location"

# Stage 2: Medium units (slower)    exit 1

echo "[4/17] Synthesizing FPU (30-60 min)..."fi

$YOSYS -s synth_fpu_unit.ys > fpu.log 2>&1 && echo "  ✓ Done"

# Check if Liberty file exists

echo "[5/17] Synthesizing vector unit (30-60 min)..."LIBERTY="$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

$YOSYS -s synth_vector_unit.ys > vector.log 2>&1 && echo "  ✓ Done"if [ ! -f "$LIBERTY" ]; then

    echo "ERROR: Liberty file not found at $LIBERTY"

echo "[6/17] Synthesizing LSU..."    exit 1

$YOSYS -s synth_lsu.ys > lsu.log 2>&1 && echo "  ✓ Done"fi



# Stage 3: Branch predictorecho "Found Sky130 PDK at $PDK_ROOT"

echo "[7/17] Synthesizing gshare_predictor..."echo "Using Liberty: $LIBERTY"

$YOSYS -s synth_gshare_predictor.ys > gshare.log 2>&1 && echo "  ✓ Done"echo ""



echo "[8/17] Synthesizing bimodal_predictor..."# Change to design directory

$YOSYS -s synth_bimodal_predictor.ys > bimodal.log 2>&1 && echo "  ✓ Done"cd "$DESIGN_DIR"



echo "[9/17] Synthesizing tournament_selector..."# Run Yosys synthesis

$YOSYS -s synth_tournament_selector.ys > tournament.log 2>&1 && echo "  ✓ Done"echo "Starting Yosys hierarchical synthesis..."

echo "This may take 10-30 minutes for a 2M gate design..."

echo "[10/17] Synthesizing BTB..."echo ""

$YOSYS -s synth_btb.ys > btb.log 2>&1 && echo "  ✓ Done"

yosys -c synth_hierarchical.tcl 2>&1 | tee yosys_synth.log

echo "[11/17] Synthesizing RAS..."

$YOSYS -s synth_ras.ys > ras.log 2>&1 && echo "  ✓ Done"# Check if synthesis succeeded

if [ -f "clownfish_synth.blif" ]; then

# Stage 4: OoO logic    echo ""

echo "[12/17] Synthesizing register_rename..."    echo "=========================================="

$YOSYS -s synth_register_rename.ys > register_rename.log 2>&1 && echo "  ✓ Done"    echo "✓ Synthesis completed successfully!"

    echo "=========================================="

echo "[13/17] Synthesizing reservation_station..."    echo "Output files:"

$YOSYS -s synth_reservation_station.ys > reservation_station.log 2>&1 && echo "  ✓ Done"    ls -lh clownfish_synth.* synth_stats.txt hierarchy_check.txt 2>/dev/null || true

    echo ""

echo "[14/17] Synthesizing reorder_buffer (30-45 min)..."    echo "Next steps:"

$YOSYS -s synth_reorder_buffer.ys > reorder_buffer.log 2>&1 && echo "  ✓ Done"    echo "1. Review synth_stats.txt for design size"

    echo "2. Review hierarchy_check.txt to confirm hierarchy preserved"

# Stage 5: Caches (THE LONG ONES)    echo "3. Use OpenLane (or manual OpenROAD) for floorplan/placement/routing"

echo "[15/17] Synthesizing L1 I-cache (30-45 min)..."    echo ""

$YOSYS -s synth_l1_icache.ys > l1_icache.log 2>&1 && echo "  ✓ Done"    echo "To continue with OpenLane using this netlist:"

    echo "  - Replace synthesis step with this pre-synthesized netlist"

echo "[16/17] Synthesizing L1 D-cache (30-45 min)..."    echo "  - Or use OpenROAD directly for P&R"

$YOSYS -s synth_l1_dcache_new.ys > l1_dcache.log 2>&1 && echo "  ✓ Done"else

    echo ""

echo "[17/17] Synthesizing L2 cache (60-120 MIN - BE PATIENT!)..."    echo "=========================================="

$YOSYS -s synth_l2_cache_new.ys > l2_cache.log 2>&1 && echo "  ✓ Done"    echo "✗ Synthesis failed - check yosys_synth.log"

    echo "=========================================="

echo ""    exit 1

echo "======================================================"fi

echo "  ALL MODULES SYNTHESIZED!"
echo "======================================================"
echo "Finished: $(date)"
echo ""
echo "Synthesized modules:"
ls -lh *_synth.v
echo ""
echo "Total size:"
du -sh .
echo ""
