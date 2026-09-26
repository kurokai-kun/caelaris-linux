#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "=========================================================="
echo " Caelaris Linux ARM64 ISO Merger (Linux / macOS Terminal) "
echo "=========================================================="
echo ""

if [ ! -f "caelaris-arm64-pc.iso.part-00" ] || [ ! -f "caelaris-arm64-pc.iso.part-01" ]; then
    echo "[-] Error: Missing part files in $DIR"
    echo "    Please ensure caelaris-arm64-pc.iso.part-00 and part-01 are in the same folder."
    exit 1
fi

echo "[*] Merging ISO parts into caelaris-arm64-pc.iso..."
cat caelaris-arm64-pc.iso.part-00 caelaris-arm64-pc.iso.part-01 > caelaris-arm64-pc.iso

if [ -f "caelaris-arm64-pc.iso" ]; then
    SIZE=$(ls -lh caelaris-arm64-pc.iso | awk '{print $5}')
    echo "[+] SUCCESS! Assembled caelaris-arm64-pc.iso ($SIZE)"
    echo ""
    echo "[*] Verifying checksum..."
    CHECK_CMD=""
    if command -v shasum >/dev/null 2>&1; then
        CHECK_CMD="shasum -a 256 -c"
    elif command -v sha256sum >/dev/null 2>&1; then
        CHECK_CMD="sha256sum -c"
    fi

    if [ -n "$CHECK_CMD" ]; then
        if [ -f "caelaris-arm64-pc.iso.sha256" ]; then
            $CHECK_CMD caelaris-arm64-pc.iso.sha256 || {
                echo ""
                echo "[-] Notice: Checksum failed. If you downloaded part files at different times,"
                echo "    please re-download part-00 and part-01 together to ensure they match."
            }
        elif [ -f "SHA256SUMS.txt" ]; then
            $CHECK_CMD SHA256SUMS.txt || true
        fi
    fi
else
    echo "[-] Assembly failed."
    exit 1
fi
