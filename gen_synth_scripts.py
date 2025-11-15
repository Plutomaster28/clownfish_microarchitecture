#!/usr/bin/env python3
"""Generate hierarchical synthesis scripts for Clownfish v2"""

import os

PDK_LIB = "/home/miyamii/.ciel/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
DESIGN_DIR = "/home/miyamii/clownfish_microarchitecture"
SRAM_DIR = f"{DESIGN_DIR}/macros/openram_output"

def gen_simple_module(name, verilog_path, top_module):
    """Generate synthesis script for a simple module"""
    return f"""read_liberty -lib {PDK_LIB}
read_verilog -sv {verilog_path}
hierarchy -check -top {top_module}
proc
opt
fsm
opt
memory
opt
techmap
opt
dfflibmap -liberty {PDK_LIB}
opt_clean -purge
stat -liberty {PDK_LIB}
write_verilog -noattr {name}_synth.v
"""

def gen_sram_module(name, verilog_path, top_module, sram_files):
    """Generate synthesis script for module with SRAM dependencies"""
    sram_reads = "\n".join([f"read_verilog -lib {SRAM_DIR}/{f}" for f in sram_files])
    return f"""read_liberty -lib {PDK_LIB}
{sram_reads}
read_verilog -sv {verilog_path}
hierarchy -check -top {top_module}
proc
opt
fsm
opt
memory
opt
techmap
opt
dfflibmap -liberty {PDK_LIB}
opt_clean -purge
stat -liberty {PDK_LIB}
write_verilog -noattr {name}_synth.v
"""

# Module definitions
modules = [
    ("simple_alu", f"{DESIGN_DIR}/rtl/execution/simple_alu.v", "simple_alu", []),
    ("complex_alu", f"{DESIGN_DIR}/rtl/execution/complex_alu.v", "complex_alu", []),
    ("mul_div_unit", f"{DESIGN_DIR}/rtl/execution/mul_div_unit.v", "mul_div_unit", []),
    ("fpu_unit", f"{DESIGN_DIR}/rtl/execution/fpu_unit.v", "fpu_unit", []),
    ("vector_unit", f"{DESIGN_DIR}/rtl/execution/vector_unit.v", "vector_unit", []),
    ("lsu", f"{DESIGN_DIR}/rtl/execution/lsu.v", "lsu", []),
    ("gshare_predictor", f"{DESIGN_DIR}/rtl/predictor/gshare_predictor.v", "gshare_predictor", []),
    ("bimodal_predictor", f"{DESIGN_DIR}/rtl/predictor/bimodal_predictor.v", "bimodal_predictor", []),
    ("tournament_selector", f"{DESIGN_DIR}/rtl/predictor/tournament_selector.v", "tournament_selector", []),
    ("btb", f"{DESIGN_DIR}/rtl/predictor/btb.v", "btb", []),
    ("ras", f"{DESIGN_DIR}/rtl/predictor/ras.v", "ras", []),
    ("register_rename", f"{DESIGN_DIR}/rtl/ooo/register_rename.v", "register_rename", []),
    ("reservation_station", f"{DESIGN_DIR}/rtl/ooo/reservation_station.v", "reservation_station", []),
    ("reorder_buffer", f"{DESIGN_DIR}/rtl/ooo/reorder_buffer.v", "reorder_buffer", []),
    ("l1_icache", f"{DESIGN_DIR}/rtl/memory/l1_icache.v", "l1_icache", ["sram_l1_icache_way.v"]),
    ("l1_dcache_new", f"{DESIGN_DIR}/rtl/memory/l1_dcache_new.v", "l1_dcache_new", ["sram_l1_dcache_way.v"]),
    ("l2_cache_new", f"{DESIGN_DIR}/rtl/memory/l2_cache_new.v", "l2_cache_new", ["sram_l2_cache_way.v", "sram_tlb.v"]),
]

os.makedirs("hierarchical_synth", exist_ok=True)
os.chdir("hierarchical_synth")

for name, vpath, top, srams in modules:
    if srams:
        script = gen_sram_module(name, vpath, top, srams)
    else:
        script = gen_simple_module(name, vpath, top)
    
    with open(f"synth_{name}.ys", "w") as f:
        f.write(script)
    
    print(f"Generated synth_{name}.ys")

print("\nAll synthesis scripts generated in hierarchical_synth/")
