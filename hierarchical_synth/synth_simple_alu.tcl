yosys -import
read_liberty -lib $::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog -sv $::env(DESIGN_DIR)/rtl/execution/simple_alu.v
hierarchy -check -top simple_alu
proc; opt; fsm; opt; memory; opt
techmap; opt
dfflibmap -liberty $::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
opt_clean -purge
stat -liberty $::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
write_verilog -noattr simple_alu_synth.v
