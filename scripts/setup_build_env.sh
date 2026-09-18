#!/usr/bin/env bash
set -euo pipefail

echo "=========================================================="
echo " Setting up Caelaris Build Environment (Arch Linux / CI)  "
echo "=========================================================="

echo "[1/3] Refreshing pacman keyring & mirrors..."
pacman -Sy --noconfirm archlinux-keyring
pacman-key --init
pacman-key --populate archlinux
pacman -Syu --noconfirm

echo "[2/3] Installing archiso build dependencies..."
pacman -S --needed --noconfirm archiso arch-install-scripts git base-devel dosfstools squashfs-tools syslinux edk2-shell memtest86+ librsvg

echo "[3/3] Build environment setup complete!"
echo "=========================================================="
