# Hierarchical Synthesis Plan for Clownfish v2

## Strategy: Divide & Conquer

Instead of synthesizing the entire 2.5M gate design at once, we'll:
1. Synthesize major blocks independently
2. Treat each as a hard macro (like the SRAMs)
3. Integrate at the top level

---

## Module Breakdown

### Block 1: Execution Units (`execution_cluster`)
**Files:**
- rtl/execution/simple_alu.v
- rtl/execution/complex_alu.v
- rtl/execution/mul_div_unit.v
- rtl/execution/fpu_unit.v
- rtl/execution/vector_unit.v
- rtl/execution/lsu.v

**Estimated size:** ~300K gates
**Synthesis time:** ~10-15 min

### Block 2: OoO Infrastructure (`ooo_cluster`)
**Files:**
- rtl/ooo/reorder_buffer.v
- rtl/ooo/reservation_station.v
- rtl/ooo/register_rename.v

**Estimated size:** ~400K gates
**Synthesis time:** ~15-20 min

### Block 3: Branch Predictor (`predictor_cluster`)
**Files:**
- rtl/predictor/gshare_predictor.v
- rtl/predictor/bimodal_predictor.v
- rtl/predictor/tournament_selector.v
- rtl/predictor/btb.v
- rtl/predictor/ras.v
- rtl/predictor/branch_predictor.v

**Estimated size:** ~150K gates
**Synthesis time:** ~5-10 min

### Block 4: Memory Hierarchy (`memory_cluster`)
**Files:**
- rtl/memory/l1_icache.v
- rtl/memory/l1_dcache_new.v
- rtl/memory/l2_cache_new.v
- macros/openram_output/sram_*.v (blackboxed)

**Estimated size:** ~200K gates + SRAM macros
**Synthesis time:** ~10-15 min

### Block 5: Core Pipeline (`core_cluster`)
**Files:**
- rtl/core/clownfish_core_v2.v (just the pipeline glue)

**Estimated size:** ~50K gates
**Synthesis time:** ~5 min

### Top Level: SoC Integration
**Files:**
- clownfish_soc_v2.v
- References all 5 clusters as blackboxes

**Estimated size:** ~5K gates (just wiring)
**Synthesis time:** ~2 min

---

## Total Time: ~1-2 hours vs 8+ hours!

---

## Implementation Steps

I'll create:
1. Wrapper modules for each cluster
2. Separate config.tcl for each block
3. Script to run all blocks in parallel
4. Final top-level integration config

Ready to proceed?
