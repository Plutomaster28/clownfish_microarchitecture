# Post-GPL Hook: Mark all SRAM macros as FIXED before detailed placement
# This prevents DPL-0044 errors when macros are passed to detailed placement

puts "\[INFO\]: Running post-GPL hook to fix SRAM macros..."

# Get the design
set design_name [ord::get_db_block]

# Get all instances in the design
set all_insts [$design_name getInsts]

set fixed_count 0

# Iterate through all instances and mark SRAM macros as FIXED
foreach inst $all_insts {
    set inst_name [$inst getName]
    set master [$inst getMaster]
    set master_name [$master getName]
    
    # Check if this is an SRAM macro (by master name)
    if {[string match "*sram_l1_*" $master_name] || [string match "*sram_tlb*" $master_name]} {
        # Mark as FIXED so detailed placement skips it
        $inst setPlacementStatus "FIRM"
        incr fixed_count
        puts "\[INFO\]:   Fixed macro instance: $inst_name (master: $master_name)"
    }
}

puts "\[INFO\]: Post-GPL hook complete. Fixed $fixed_count SRAM macro instances."
