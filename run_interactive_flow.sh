#!/bin/bash
# Run the interactive TCL flow inside the OpenLane container

set -e

echo "[INFO]: Starting interactive OpenLane flow (with error handling)"

# Get container name
CONTAINER_NAME=$(docker ps | grep openlane | awk '{print $NF}')

if [ -z "$CONTAINER_NAME" ]; then
    echo "[ERROR]: OpenLane container not running"
    exit 1
fi

echo "[INFO]: Using container: $CONTAINER_NAME"

# Copy the TCL script into the container and run it
docker exec -i $CONTAINER_NAME bash << 'EOF'
cd /openlane
tclsh /home/miyamii/clownfish_microarchitecture/interactive_flow.tcl
EOF

echo "[INFO]: Flow finished! Check runs/SKIP_DPL_INTERACTIVE/ for results"
