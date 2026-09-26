#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "=========================================================="
echo " Caelaris Linux ARM64 ISO Merger (macOS / Apple Silicon)  "
echo "=========================================================="
echo ""

if [ ! -f "caelaris-arm64-pc.iso.part-00" ] || [ ! -f "caelaris-arm64-pc.iso.part-01" ]; then
    echo "[-] Error: Missing part files in $DIR"
    echo "    Please ensure caelaris-arm64-pc.iso.part-00 and part-01 are in the same folder as this script."
    echo ""
    read -p "Press Enter to close..."
    exit 1
fi

echo "[*] Merging ISO parts into caelaris-arm64-pc.iso..."
cat caelaris-arm64-pc.iso.part-00 caelaris-arm64-pc.iso.part-01 > caelaris-arm64-pc.iso

if [ -f "caelaris-arm64-pc.iso" ]; then
    SIZE=$(ls -lh caelaris-arm64-pc.iso | awk '{print $5}')
    echo "[+] SUCCESS! Assembled caelaris-arm64-pc.iso ($SIZE)"
    echo ""
    echo "In VMware Fusion or UTM on Mac:"
    echo "  1. Select 'caelaris-arm64-pc.iso'"
    echo "  2. In VMware Fusion -> Settings -> CD/DVD: ensure 'Connect CD/DVD Drive' is CHECKED!"
else
    echo "[-] Assembly failed."
fi

echo ""
read -p "Press Enter to exit..."
