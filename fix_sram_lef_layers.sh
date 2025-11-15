#!/bin/bash
# Fix SRAM LEF files: rename "metalN" to "metN" for Sky130 compatibility

SRAM_DIR="/home/miyamii/clownfish_microarchitecture/macros/openram_output"

echo "Fixing SRAM LEF layer names for Sky130 compatibility..."
echo "Converting: metal1 -> met1, metal2 -> met2, metal3 -> met3, metal4 -> met4, metal5 -> met5"
echo ""

# Backup original files
echo "Creating backups..."
for lef in "$SRAM_DIR"/*.lef; do
    if [ -f "$lef" ]; then
        cp "$lef" "$lef.backup"
        echo "  Backed up: $(basename $lef)"
    fi
done

echo ""
echo "Applying fixes..."

# Fix all LEF files
for lef in "$SRAM_DIR"/*.lef; do
    if [ -f "$lef" ] && [[ ! "$lef" == *.backup ]]; then
        echo "  Processing: $(basename $lef)"
        
        # Replace metal layer names with Sky130 convention
        sed -i 's/\bmetal1\b/met1/g' "$lef"
        sed -i 's/\bmetal2\b/met2/g' "$lef"
        sed -i 's/\bmetal3\b/met3/g' "$lef"
        sed -i 's/\bmetal4\b/met4/g' "$lef"
        sed -i 's/\bmetal5\b/met5/g' "$lef"
        
        # Count changes
        changes=$(grep -c "met[1-5]" "$lef" 2>/dev/null || echo "0")
        echo "    Found $changes layer references"
    fi
done

echo ""
echo "Done! Original files backed up with .backup extension"
echo ""
echo "Verifying changes..."
grep -h "LAYER met" "$SRAM_DIR"/*.lef 2>/dev/null | sort -u | head -10
