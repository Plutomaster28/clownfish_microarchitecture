# Custom OpenLane synthesis script for MASSIVE designs (2M+ gates)
# This COMPLETELY bypasses ABC optimization
# Place in: scripts/yosys/synth_no_abc.tcl

yosys -import

set buffering 0
set sizing 0
set vtop $::env(DESIGN_NAME)
set sclib $::env(LIB_SYNTH)
set dfflib $sclib

# Read defines
if { [info exists ::env(SYNTH_DEFINES) ] } {
    foreach define $::env(SYNTH_DEFINES) {
        verilog_defines -D$define
    }
}

# Include directories
set vIdirsArgs ""
if {[info exist ::env(VERILOG_INCLUDE_DIRS)]} {
    foreach dir $::env(VERILOG_INCLUDE_DIRS) {
        lappend vIdirsArgs "-I$dir"
    }
    set vIdirsArgs [join $vIdirsArgs]
}

# Read libraries
if { $::env(SYNTH_READ_BLACKBOX_LIB) } {
    foreach lib $::env(LIB_SYNTH_COMPLETE_NO_PG) {
        read_liberty -lib -ignore_miss_dir -setattr blackbox $lib
    }
}

if { [info exists ::env(EXTRA_LIBS) ] } {
    foreach lib $::env(EXTRA_LIBS) {
        read_liberty -lib -ignore_miss_dir -setattr blackbox $lib
    }
}

# Read blackbox Verilog (SRAMs)
if { [info exists ::env(VERILOG_FILES_BLACKBOX)] } {
    foreach verilog_file $::env(VERILOG_FILES_BLACKBOX) {
        read_verilog -sv -lib {*}$vIdirsArgs $verilog_file
    }
}

# Read design files
foreach verilog_file $::env(VERILOG_FILES) {
    read_verilog -sv {*}$vIdirsArgs $verilog_file
}

# Set hierarchy
hierarchy -check -top $vtop

# Basic RTL optimization
procs; opt
fsm; opt  
memory -nomap; opt

# Simple techmap - NO ABC!
techmap; opt

# Map flip-flops
dfflibmap -liberty $sclib; opt

# Clean up
opt_clean -purge
autoname

# Write checkpoint before "ABC" (but we're skipping it!)
tee -o "$::env(synth_report_prefix)_chk.rpt" check
tee -o "$::env(synth_report_prefix)_stat.rpt" stat -liberty $sclib

# Write netlist WITHOUT ABC optimization
write_verilog -noattr -noexpr "$::env(synthesis_results)/$vtop.v"

puts "\n===== SYNTHESIS COMPLETE (NO ABC) ====="
puts "WARNING: Design was NOT optimized by ABC"
puts "OpenROAD Resizer will handle optimization during placement"
puts "========================================\n"
