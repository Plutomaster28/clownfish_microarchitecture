# Load technology
tech load /home/miyamii/.ciel/volare/sky130/versions/bdc9412b3e468c102d01b7cf6337be06ec6e9c9a/sky130A/libs.tech/magic/sky130A.tech

# Read LEF files
lef read /home/miyamii/.ciel/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
lef read /home/miyamii/clownfish_microarchitecture/macros/openram_output/sram_l1_icache_way.lef
lef read /home/miyamii/clownfish_microarchitecture/macros/openram_output/sram_l1_dcache_way.lef
lef read /home/miyamii/clownfish_microarchitecture/macros/openram_output/sram_tlb.lef

# Load DEF
def read /home/miyamii/clownfish_microarchitecture/runs/SKIP_DPL_INTERACTIVE/tmp/placement/10-global.def

# Write GDS
gds write /home/miyamii/clownfish_microarchitecture/runs/SKIP_DPL_INTERACTIVE/clownfish_soc_v2_placed.gds

puts "GDS written successfully"
quit -noprompt
