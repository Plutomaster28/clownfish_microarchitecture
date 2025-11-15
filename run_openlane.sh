#!/bin/bash
# Quick-start script for OpenLane run
# This is what you run INSIDE the OpenLane Docker container

echo "==================================================================="
echo "  Clownfish v2 - NO L2 Cache - OpenLane Run"
echo "==================================================================="
echo ""
echo "Design: clownfish_soc_v2 (NO L2 cache)"
echo "Gate count: ~1.2M gates"
echo "Die size: 4mm × 4mm"
echo "Target: Sky130 130nm PDK"
echo ""
echo "Expected runtime: 6-12 hours"
echo ""
echo "==================================================================="
echo ""

# Check if we're in Docker
if [ ! -f "/openlane/flow.tcl" ]; then
    echo "ERROR: This script must be run INSIDE the OpenLane Docker container!"
    echo ""
    echo "Start Docker first:"
    echo "  docker exec -it openlane bash"
    echo ""
    echo "Then run this script again."
    exit 1
fi

# Change to openlane directory
cd /openlane

# Run the flow
echo "Starting OpenLane flow..."
echo "Tag: NO_L2_CLEAN"
echo ""
echo "Monitor progress with:"
echo "  tail -f /home/miyamii/clownfish_microarchitecture/runs/NO_L2_CLEAN/openlane.log"
echo ""
echo "==================================================================="
echo ""

# Run flow with tag
./flow.tcl -design /home/miyamii/clownfish_microarchitecture -tag NO_L2_CLEAN

echo ""
echo "==================================================================="
echo "OpenLane run completed!"
echo "==================================================================="
echo ""
echo "Check results at:"
echo "  /home/miyamii/clownfish_microarchitecture/runs/NO_L2_CLEAN/"
echo ""
