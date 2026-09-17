#!/usr/bin/env bash
set -euo pipefail

EDITION="${1:-kde}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
WORK_DIR="/tmp/caelaris-work-${EDITION}"
OUT_DIR="${ROOT_DIR}/out"

if [[ "$EDITION" != "kde" && "$EDITION" != "gnome" ]]; then
    echo "Usage: sudo ./build.sh [kde|gnome]"
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo "Error: mkarchiso requires root privileges. Please run with sudo."
    exit 1
fi

echo "=========================================================="
echo " Building Caelaris Linux - Edition: ${EDITION^^}          "
echo "=========================================================="

PROFILE_SRC="${ROOT_DIR}/profiles/${EDITION}"
BUILD_PROFILE="/tmp/caelaris-profile-${EDITION}"

rm -rf "$BUILD_PROFILE"
mkdir -p "$BUILD_PROFILE"

# Copy base profile
cp -r "${PROFILE_SRC}/." "$BUILD_PROFILE/"

# Merge shared packages
cat "${ROOT_DIR}/shared/packages.common" >> "${BUILD_PROFILE}/packages.x86_64"

# Merge shared pacman.conf
cp "${ROOT_DIR}/shared/pacman.conf" "${BUILD_PROFILE}/pacman.conf"

# Merge shared airootfs overlays
if [ -d "${ROOT_DIR}/shared/airootfs" ]; then
    mkdir -p "${BUILD_PROFILE}/airootfs"
    cp -r "${ROOT_DIR}/shared/airootfs/." "${BUILD_PROFILE}/airootfs/"
fi

# Inject custom os-release branding
mkdir -p "${BUILD_PROFILE}/airootfs/etc"
cp "${ROOT_DIR}/shared/branding/os-release" "${BUILD_PROFILE}/airootfs/etc/os-release"

mkdir -p "$OUT_DIR"

echo "Running mkarchiso..."
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$BUILD_PROFILE"

echo "=========================================================="
echo " ISO Generated successfully in: ${OUT_DIR}                "
echo "=========================================================="
