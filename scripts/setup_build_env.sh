#!/usr/bin/env bash
set -euo pipefail

echo "=========================================================="
echo " Setting up Caelaris Build Environment (Arch Linux / CI)  "
echo "=========================================================="

echo "[1/4] Refreshing pacman keyring & mirrors..."
pacman -Sy --noconfirm archlinux-keyring
pacman -Syu --noconfirm

echo "[2/4] Installing archiso build dependencies..."
pacman -S --needed --noconfirm archiso arch-install-scripts git base-devel dosfstools squashfs-tools syslinux edk2-shell memtest86+

echo "[3/4] Preparing archiso profile baseline..."
mkdir -p /tmp

echo "=========================================================="
echo " Build environment is ready!                              "
echo "=========================================================="
