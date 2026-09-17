#!/usr/bin/env bash
set -euo pipefail

echo "=========================================================="
echo " Setting up Caelaris Build Environment (Arch Linux / CI)  "
echo "=========================================================="

echo "[1/4] Refreshing pacman keyring & mirrors..."
pacman -Sy --noconfirm archlinux-keyring
pacman-key --init
pacman-key --populate archlinux

echo "[2/4] Setting up Chaotic-AUR repository for Calamares..."
pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com || pacman-key --recv-key 3056513887B78AEB --keyserver hkps://keyserver.ubuntu.com || true
pacman-key --lsign-key 3056513887B78AEB || true
pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' || true
pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' || true

pacman -Syu --noconfirm

echo "[3/4] Installing archiso build dependencies..."
pacman -S --needed --noconfirm archiso arch-install-scripts git base-devel dosfstools squashfs-tools syslinux edk2-shell memtest86+

echo "[4/4] Build environment setup complete!"
echo "=========================================================="
