#!/bin/bash
# Direct DEF to GDS conversion using Magic

echo "[INFO]: Converting placed DEF to GDS using Magic..."

RUN_DIR="/home/miyamii/clownfish_microarchitecture/runs/SKIP_DPL_INTERACTIVE"
DEF_FILE="$RUN_DIR/tmp/placement/10-global.def"
GDS_OUTPUT="$RUN_DIR/clownfish_soc_v2_placed.gds"

if [ ! -f "$DEF_FILE" ]; then
    echo "[ERROR]: DEF file not found at $DEF_FILE"
    exit 1
fi

echo "[INFO]: Input DEF: $DEF_FILE"
echo "[INFO]: Output GDS: $GDS_OUTPUT"

# Detect the container name
CONTAINER_NAME=$(docker ps --format '{{.Names}}' | grep -E 'openlane|pensive' | head -n 1)

if [ -z "$CONTAINER_NAME" ]; then
    echo "[ERROR]: No OpenLane container found running"
    exit 1
fi

echo "[INFO]: Using container: $CONTAINER_NAME"

# Create Magic script
cat > /tmp/magic_def2gds.tcl << 'EOF'
# Load technology
tech load /home/miyamii/.ciel/sky130A/libs.tech/magic/sky130A.tech

# Read LEF files
lef read /home/miyamii/.ciel/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
lef read /home/miyamii/.ciel/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd__nom.lef
lef read /home/miyamii/clownfish_microarchitecture/macros/openram_output/sram_l1_icache_way.lef
lef read /home/miyamii/clownfish_microarchitecture/macros/openram_output/sram_l1_dcache_way.lef
lef read /home/miyamii/clownfish_microarchitecture/macros/openram_output/sram_tlb.lef

# Load DEF
def read /home/miyamii/clownfish_microarchitecture/runs/SKIP_DPL_INTERACTIVE/tmp/placement/10-global.def

# Write GDS
gds write /home/miyamii/clownfish_microarchitecture/runs/SKIP_DPL_INTERACTIVE/clownfish_soc_v2_placed.gds

puts "GDS written successfully"
quit -noprompt
EOF

# Copy script to container
docker cp /tmp/magic_def2gds.tcl $CONTAINER_NAME:/tmp/magic_def2gds.tcl

# Run Magic
echo "[INFO]: Running Magic to generate GDS..."
docker exec -i $CONTAINER_NAME magic -dnull -noconsole -rcfile /home/miyamii/.ciel/sky130A/libs.tech/magic/sky130A.magicrc /tmp/magic_def2gds.tcl

# Check if GDS was created
if [ -f "$GDS_OUTPUT" ]; then
    SIZE=$(du -h "$GDS_OUTPUT" | cut -f1)
    echo "[SUCCESS]: GDS generated at $GDS_OUTPUT (Size: $SIZE)"
    echo "[INFO]: This is a placed-only layout (no routing) suitable for visualization"
else
    echo "[ERROR]: GDS file was not generated"
    exit 1
fi

echo "[INFO]: You can view the GDS with: klayout $GDS_OUTPUT"
