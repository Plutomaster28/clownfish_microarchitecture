#!/bin/bash
while true; do
  clear
  echo "=== OpenLane Progress Monitor ==="
  echo "Time: $(date)"
  echo ""
  tail -20 /home/miyamii/clownfish_microarchitecture/openlane_presyn.log
  sleep 10
done
