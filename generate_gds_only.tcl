#!/usr/bin/env tclsh
# Generate GDS from GPL placement only - no routing
# For visualization/proof of manufacturability

package require openlane

# Use existing run with GPL results
set run_dir "/home/miyamii/clownfish_microarchitecture/runs/SKIP_DPL_INTERACTIVE"
set gpl_odb "$run_dir/tmp/placement/10-global.odb"

puts "\[INFO\]: Generating GDS from placed design (no routing)..."
puts "\[INFO\]: Using GPL results from: $gpl_odb"

# Check if GPL results exist
if {![file exists $gpl_odb]} {
    puts "\[ERROR\]: GPL results not found at $gpl_odb"
    exit 1
}

# Load the design context
prep -design /home/miyamii/clownfish_microarchitecture -tag SKIP_DPL_INTERACTIVE

# Set the current database to the GPL result
set ::env(CURRENT_ODB) $gpl_odb
set ::env(CURRENT_DEF) "$run_dir/tmp/placement/10-global.def"

puts "\[INFO\]: Loaded placed design from GPL"
puts "\[INFO\]: Generating GDS with Magic..."

# Run Magic to generate GDS from the placed design
# This will show placed cells and macros, no routing
if {[catch {
    # Use run_magic_spice_export which is more tolerant of incomplete designs
    run_magic_spice_export
    
    # Then try to generate GDS
    exec magic -dnull -noconsole -rcfile /home/miyamii/.ciel/sky130A/libs.tech/magic/sky130A.magicrc << EOF
load $run_dir/tmp/magic/10-magic.def
gds write $run_dir/results/signoff/clownfish_soc_v2_placed_only.gds
quit
EOF
    
} err]} {
    puts "\[WARNING\]: Magic had issues: $err"
}

# Alternative: Use OpenROAD to write GDS directly
puts "\[INFO\]: Attempting direct GDS write with OpenROAD..."
if {[catch {
    exec openroad -exit << EOF
read_lef /home/miyamii/.ciel/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
read_lef /home/miyamii/clownfish_microarchitecture/macros/openram_output/sram_l1_icache_way.lef
read_lef /home/miyamii/clownfish_microarchitecture/macros/openram_output/sram_l1_dcache_way.lef
read_lef /home/miyamii/clownfish_microarchitecture/macros/openram_output/sram_tlb.lef
read_def $run_dir/tmp/placement/10-global.def
write_gds $run_dir/results/signoff/clownfish_soc_v2_gpl_only.gds
exit
EOF
} err]} {
    puts "\[WARNING\]: OpenROAD GDS write had issues: $err"
}

puts "\[INFO\]: Checking for generated GDS files..."
set gds_files [glob -nocomplain "$run_dir/results/signoff/*.gds" "$run_dir/results/magic/*.gds"]
if {[llength $gds_files] > 0} {
    puts "\[SUCCESS\]: Generated GDS files:"
    foreach gds $gds_files {
        puts "  - $gds"
        puts "    Size: [expr [file size $gds] / 1024 / 1024] MB"
    }
} else {
    puts "\[WARNING\]: No GDS files found in expected locations"
    puts "\[INFO\]: Checking all run directories..."
    exec find $run_dir -name "*.gds" -type f
}

puts "\[INFO\]: Done!"
