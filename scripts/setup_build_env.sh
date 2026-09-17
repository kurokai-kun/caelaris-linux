#!/usr/bin/env bash
set -euo pipefail

echo "=========================================================="
echo " Setting up NovaOS Build Environment (Arch Linux / WSL)   "
echo "=========================================================="

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (or with sudo)." 
   exit 1
fi

echo "[1/4] Updating pacman databases..."
pacman -Syu --noconfirm

echo "[2/4] Installing archiso build dependencies..."
pacman -S --needed --noconfirm archiso arch-install-scripts git base-devel dosfstools squashfs-tools

echo "[3/4] Installing QEMU and virtualization tools for testing..."
pacman -S --needed --noconfirm qemu-desktop edk2-ovmf

echo "[4/4] Verifying loop devices and filesystem support..."
modprobe loop || true

echo "=========================================================="
echo " Build environment is ready! You can now run build.sh.    "
echo "=========================================================="
