#!/bin/bash
# Force use of Efabless OpenLane v2 image (the one that worked before)
export OPENLANE_IMAGE_NAME="efabless/openlane:latest"
export OPENLANE_TAG="latest"

cd /home/miyamii/OpenLane
echo "Using Docker image: $OPENLANE_IMAGE_NAME"
docker images | grep efabless/openlane

make mount
