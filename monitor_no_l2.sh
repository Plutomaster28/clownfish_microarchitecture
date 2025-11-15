#!/bin/bash
while true; do
    echo "=== $(date +'%H:%M:%S') ==="
    docker stats --no-stream --format "CPU: {{.CPUPerc}} | MEM: {{.MemUsage}}" $(docker ps -q --filter "ancestor=efabless/openlane:v0.21") 2>/dev/null || { echo "Docker finished!"; break; }
    tail -3 openlane_no_l2.log | head -2
    echo ""
    sleep 300
done
