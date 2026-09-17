#!/usr/bin/env bash
set -euo pipefail

ISO_PATH="${1:-}"

if [[ -z "$ISO_PATH" ]]; then
    ISO_PATH=$(find ../out/ -name "*.iso" 2>/dev/null | head -n 1 || true)
fi

if [[ -z "$ISO_PATH" || ! -f "$ISO_PATH" ]]; then
    echo "Error: No ISO file found in ../out/. Please specify the ISO path:"
    echo "Usage: ./test_qemu.sh <path_to_iso>"
    exit 1
fi

echo "Launching $ISO_PATH in QEMU (UEFI, 4GB RAM, VirtIO)..."

qemu-system-x86_64 \
    -enable-kvm \
    -m 4G \
    -smp 4 \
    -cpu host \
    -vga virtio \
    -display default,show-cursor=on \
    -usb \
    -device usb-tablet \
    -cdrom "$ISO_PATH" \
    -boot d
