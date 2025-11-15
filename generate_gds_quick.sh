#!/bin/bash
# Wrapper to run generate_gds_only.tcl in OpenLane container

echo "[INFO]: Generating GDS from GPL placement (no routing)"
echo "[INFO]: Using existing SKIP_DPL_INTERACTIVE run..."

# Detect the container name
CONTAINER_NAME=$(docker ps --format '{{.Names}}' | grep -E 'openlane|pensive' | head -n 1)

if [ -z "$CONTAINER_NAME" ]; then
    echo "[ERROR]: No OpenLane container found running"
    echo "[INFO]: Starting OpenLane container..."
    cd /home/miyamii/clownfish_microarchitecture
    docker run -it -v $(pwd):/home/miyamii/clownfish_microarchitecture -v /home/miyamii/.ciel:/home/miyamii/.ciel ghcr.io/the-openroad-project/openlane:latest bash
    exit 1
fi

echo "[INFO]: Using container: $CONTAINER_NAME"

# Run the TCL script in the container
docker exec -i $CONTAINER_NAME bash -c "cd /openlane && tclsh /home/miyamii/clownfish_microarchitecture/generate_gds_only.tcl"

echo "[INFO]: Done! Check runs/SKIP_DPL_INTERACTIVE/results/ for GDS files"
