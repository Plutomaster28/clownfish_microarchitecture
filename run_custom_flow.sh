#!/bin/bash
# Custom OpenLane flow that skips detailed placement
# This is a workaround for DPL-0044 errors with SRAM macros

set -e

echo "[INFO]: Starting custom OpenLane flow (skipping detailed placement)"

# Get the actual OpenLane container name
CONTAINER_NAME=$(docker ps | grep openlane | awk '{print $NF}')

if [ -z "$CONTAINER_NAME" ]; then
    echo "[ERROR]: OpenLane container not found. Is it running?"
    exit 1
fi

echo "[INFO]: Using OpenLane container: $CONTAINER_NAME"

# Run OpenLane in interactive mode
docker exec -i $CONTAINER_NAME bash -c "cd /openlane && tclsh << 'EOF'
package require openlane 0.9

# Load the design configuration
prep -design /home/miyamii/clownfish_microarchitecture -tag SKIP_DPL_CUSTOM_FLOW -overwrite

# Run synthesis
run_synthesis

# Run floorplan
run_floorplan

# Run placement up to global placement only
puts \"[INFO]: Running global placement only (skipping detailed placement)\"
global_placement_or

# At this point, macros should be placed by GPL
# Standard cells are also placed but not legalized

# Skip detailed_placement_or - go straight to CTS
puts \"[INFO]: Skipping detailed placement due to DPL-0044 with macros\"

# Run CTS
puts \"[INFO]: Running Clock Tree Synthesis\"
run_cts

# Run routing
puts \"[INFO]: Running Global Routing\"
run_routing

# Run finishing steps
puts \"[INFO]: Running finishing steps\"
run_magic
run_magic_spice_export
run_magic_drc
run_lvs
run_antenna_check

# Generate final outputs
puts \"[INFO]: Generating final outputs\"
run_lef_cvc

puts \"[INFO]: Custom flow complete! Check results in runs/SKIP_DPL_CUSTOM_FLOW/\"
EOF
"

echo "[INFO]: Custom flow finished"
