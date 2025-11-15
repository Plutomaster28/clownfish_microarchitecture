# ============================================================================
# Synopsys Design Constraints (SDC) for Clownfish RISC-V Processor
# ============================================================================
# Target: 500 MHz (2.0 ns period) on 130nm process
# ============================================================================

# ============================================================================
# Clock Definition
# ============================================================================
create_clock -name clk -period 2.0 [get_ports clk]

# Clock uncertainty (jitter + skew budget)
set_clock_uncertainty 0.1 [get_clocks clk]

# Clock transition (rise/fall time)
set_clock_transition 0.05 [get_clocks clk]

# Clock latency (estimated)
set_clock_latency -source 0.2 [get_clocks clk]
set_clock_latency 0.1 [get_clocks clk]

# ============================================================================
# Input/Output Delays
# ============================================================================

# External memory interface delays (assuming external DRAM)
set input_delay_mem 0.5
set output_delay_mem 0.5

set_input_delay -clock clk -max $input_delay_mem [get_ports mem_rdata*]
set_input_delay -clock clk -max $input_delay_mem [get_ports mem_ready]
set_output_delay -clock clk -max $output_delay_mem [get_ports mem_addr*]
set_output_delay -clock clk -max $output_delay_mem [get_ports mem_wdata*]
set_output_delay -clock clk -max $output_delay_mem [get_ports mem_we]
set_output_delay -clock clk -max $output_delay_mem [get_ports mem_be*]
set_output_delay -clock clk -max $output_delay_mem [get_ports mem_valid]

# UART interface (slow, relaxed timing)
set input_delay_uart 1.0
set output_delay_uart 1.0

set_input_delay -clock clk -max $input_delay_uart [get_ports uart_rx]
set_output_delay -clock clk -max $output_delay_uart [get_ports uart_tx]

# GPIO (relaxed timing)
set input_delay_gpio 1.0
set output_delay_gpio 1.0

set_input_delay -clock clk -max $input_delay_gpio [get_ports gpio_in*]
set_output_delay -clock clk -max $output_delay_gpio [get_ports gpio_out*]
set_output_delay -clock clk -max $output_delay_gpio [get_ports gpio_oe*]

# External interrupts (relaxed)
set_input_delay -clock clk -max 1.0 [get_ports external_irq*]

# JTAG (asynchronous, but constrain anyway)
set_input_delay -clock clk -max 1.5 [get_ports jtag_tck]
set_input_delay -clock clk -max 1.5 [get_ports jtag_tms]
set_input_delay -clock clk -max 1.5 [get_ports jtag_tdi]
set_output_delay -clock clk -max 1.5 [get_ports jtag_tdo]

# ============================================================================
# Reset
# ============================================================================
set_input_delay -clock clk 0.0 [get_ports rst_n]
set_false_path -from [get_ports rst_n]

# ============================================================================
# Drive Strengths
# ============================================================================
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin Y [all_inputs]
set_driving_cell -lib_cell sky130_fd_sc_hd__clkbuf_8 -pin X [get_ports clk]

# ============================================================================
# Load Capacitances
# ============================================================================
set_load 0.05 [all_outputs]

# ============================================================================
# Multi-Cycle Paths
# ============================================================================

# Multiply operation (3 cycles)
set_multicycle_path -setup 3 -from [get_pins -hierarchical *multiplier*/mul_*] \
                              -to [get_pins -hierarchical *id_ex_*]

# Divide operation (34 cycles)
set_multicycle_path -setup 34 -from [get_pins -hierarchical *divider*/div_*] \
                               -to [get_pins -hierarchical *id_ex_*]

# FPU operations
set_multicycle_path -setup 4 -from [get_pins -hierarchical *fpu*/fadd_*] \
                             -to [get_pins -hierarchical *ex_mem_*]

set_multicycle_path -setup 5 -from [get_pins -hierarchical *fpu*/fmul_*] \
                             -to [get_pins -hierarchical *ex_mem_*]

set_multicycle_path -setup 16 -from [get_pins -hierarchical *fpu*/fdiv_*] \
                               -to [get_pins -hierarchical *ex_mem_*]

# ============================================================================
# False Paths
# ============================================================================

# Asynchronous reset
set_false_path -from [get_ports rst_n] -to [all_registers]

# JTAG clock domain (if separate)
# set_false_path -from [get_clocks jtag_tck] -to [get_clocks clk]
# set_false_path -from [get_clocks clk] -to [get_clocks jtag_tck]

# Debug halt signal (quasi-static)
set_false_path -from [get_ports debug_halt_req]
set_false_path -from [get_ports debug_resume_req]

# ============================================================================
# Case Analysis (if needed for scan/test modes)
# ============================================================================
# set_case_analysis 0 [get_ports test_mode]

# ============================================================================
# Max Fanout
# ============================================================================
set_max_fanout 16 [current_design]

# ============================================================================
# Max Transition
# ============================================================================
set_max_transition 0.2 [current_design]

# ============================================================================
# Max Capacitance
# ============================================================================
set_max_capacitance 0.1 [current_design]

# ============================================================================
# Area Constraint (optional)
# ============================================================================
# set_max_area 25000000  ;# 25 mm² in µm²

# ============================================================================
# Operating Conditions
# ============================================================================
# Worst-case timing corner
set_operating_conditions -max ss_1p60v_100C

# Best-case timing corner (for hold checks)
set_operating_conditions -min ff_1p95v_n40C

# ============================================================================
# Special Constraints for Cache SRAMs
# ============================================================================

# OpenRAM SRAMs have their own timing models in .lib files
# These are automatically loaded via EXTRA_LIBS in config.tcl

# Tag array access (critical path)
set_max_delay 0.8 -from [get_pins -hierarchical *cache*/addr*] \
                  -to [get_pins -hierarchical *cache*/hit]

# Data array access
set_max_delay 0.9 -from [get_pins -hierarchical *cache*/addr*] \
                  -to [get_pins -hierarchical *cache*/rdata*]

# ============================================================================
# Pipeline Stage Constraints
# ============================================================================

# IF stage (I-Cache access)
set_max_delay 0.9 -from [get_pins -hierarchical */pc*] \
                  -to [get_pins -hierarchical */if_id_inst*]

# ID stage (decode + register read)
set_max_delay 0.7 -from [get_pins -hierarchical */if_id_inst*] \
                  -to [get_pins -hierarchical */id_ex_*]

# EX stage (ALU + branch)
set_max_delay 0.8 -from [get_pins -hierarchical */id_ex_*] \
                  -to [get_pins -hierarchical */ex_mem_*]

# MEM stage (D-Cache access)
set_max_delay 0.9 -from [get_pins -hierarchical */ex_mem_*] \
                  -to [get_pins -hierarchical */mem_wb_*]

# WB stage (write-back)
set_max_delay 0.5 -from [get_pins -hierarchical */mem_wb_*] \
                  -to [get_pins -hierarchical */int_regfile*]

# ============================================================================
# Clock Gating (if enabled)
# ============================================================================
# set_clock_gating_check -setup 0.1 [all_registers]
# set_clock_gating_check -hold 0.05 [all_registers]

# ============================================================================
# DFT Constraints (if scan chains are added)
# ============================================================================
# set_scan_configuration -style multiplexed_flip_flop
# set_dft_signal -view existing_dft -type ScanEnable -port scan_en
# set_dft_signal -view existing_dft -type Reset -port rst_n

# ============================================================================
# Notes
# ============================================================================
# 1. These constraints target 500 MHz on 130nm process
# 2. May need relaxation initially, then tighten iteratively
# 3. Multi-cycle paths for long-latency operations (mul/div/FPU)
# 4. Pipeline stage timing budgets may need adjustment
# 5. SRAM timing comes from OpenRAM-generated .lib files
# 6. Add more specific constraints as design matures
# ============================================================================
