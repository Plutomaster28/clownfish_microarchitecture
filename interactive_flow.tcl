#!/usr/bin/env tclsh
# Custom OpenLane flow for Clownfish - skips detailed placement
# Works with OpenLane v1.0.1

package require openlane

# Prep the design
prep -design /home/miyamii/clownfish_microarchitecture -tag SKIP_DPL_INTERACTIVE -overwrite

# Run synthesis
puts "\[INFO\]: Running Synthesis..."
run_synthesis

# Run floorplan
puts "\[INFO\]: Running Floorplan..."
run_floorplan

# Run placement (will do GPL and try DPL, but we'll catch the error)
puts "\[INFO\]: Running Global Placement..."
if {[catch {run_placement} err]} {
    puts "\[WARNING\]: Placement step failed (expected DPL-0044), continuing anyway..."
    puts "\[WARNING\]: Error was: $err"
}

# At this point we should have GPL results even if DPL failed
# Check if we have a placed design
set run_dir "/home/miyamii/clownfish_microarchitecture/runs/SKIP_DPL_INTERACTIVE"
set gpl_odb "$run_dir/tmp/placement/10-global.odb"

if {![file exists $gpl_odb]} {
    # Try other locations
    set gpl_odb "$run_dir/tmp/placement/5-global.odb"
}

puts "\[INFO\]: Checking for GPL results at: $gpl_odb"

if {[file exists $gpl_odb]} {
    puts "\[INFO\]: Found GPL results at: $gpl_odb"
    puts "\[INFO\]: Skipping detailed placement and CTS (macro compatibility issues)"
    puts "\[INFO\]: Proceeding directly to routing with GPL placement..."
    
    # Try routing with GPL placement
    puts "\[INFO\]: Running Global Routing..."
    if {[catch {run_routing} err]} {
        puts "\[WARNING\]: Routing had issues (expected with macro congestion): $err"
        puts "\[INFO\]: Attempting to generate layout anyway..."
    }
    
    # Try to generate GDS anyway
    puts "\[INFO\]: Generating final layout with Magic..."
    if {[catch {run_magic} err]} {
        puts "\[WARNING\]: Magic step had issues: $err"
        puts "\[INFO\]: Checking if any GDS was generated..."
    }
    
    # Check for any output files
    set results_dir "$run_dir/results"
    if {[file exists "$results_dir/signoff"]} {
        puts "\[INFO\]: Layout generation attempted - check results/signoff/ directory"
    }
    if {[file exists "$results_dir/routing"]} {
        puts "\[INFO\]: Routing results available in results/routing/ directory"
    }
    if {[file exists "$run_dir/tmp"]} {
        puts "\[INFO\]: Intermediate files in tmp/ directory"
    }
    
    puts "\[INFO\]: Flow complete! Check runs/SKIP_DPL_INTERACTIVE/ for any generated files"
    puts "\[INFO\]: Note: Design may have DRC/LVS issues due to skipped legalization"
} else {
    puts "\[ERROR\]: Could not find GPL results, cannot continue"
    exit 1
}
