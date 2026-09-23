#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
WORK_DIR="/tmp/caelaris-work-cloud"
OUT_DIR="${ROOT_DIR}/out-cloud"
BUILD_PROFILE="/tmp/caelaris-profile-cloud"
PROFILE_SRC="${ROOT_DIR}/profiles/cloud"
BUILD_DATE=$(date +%Y.%m.%d)

if [[ $EUID -ne 0 ]]; then
    echo "Error: Building the cloud ISO requires root privileges. Please run with sudo."
    exit 1
fi

echo "=========================================================="
echo " Building Caelaris Linux Cloud & Cloud-Init Edition       "
echo " Date: ${BUILD_DATE} | Target: Cloud / OpenStack / Proxmox"
echo "=========================================================="

rm -rf "$BUILD_PROFILE" "$WORK_DIR"
mkdir -p "$BUILD_PROFILE" "$OUT_DIR"

# 1. Base archiso profile copy
if [ -d "/usr/share/archiso/configs/releng" ]; then
    echo "Copying baseline archiso releng profile..."
    cp -r /usr/share/archiso/configs/releng/. "$BUILD_PROFILE/"
fi

# 2. Overlay cloud profile definition & packages
cp -r "${PROFILE_SRC}/." "$BUILD_PROFILE/"

# 3. Consolidate packages
if [ -f "/usr/share/archiso/configs/releng/packages.x86_64" ]; then
    cat "/usr/share/archiso/configs/releng/packages.x86_64" >> "${BUILD_PROFILE}/packages.x86_64"
fi
cat "${PROFILE_SRC}/packages.x86_64" >> "${BUILD_PROFILE}/packages.x86_64"
sort -u "${BUILD_PROFILE}/packages.x86_64" -o "${BUILD_PROFILE}/packages.x86_64"
sed -i '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "${BUILD_PROFILE}/packages.x86_64"

# 4. Copy shared pacman.conf
cp "${ROOT_DIR}/shared/pacman.conf" "${BUILD_PROFILE}/pacman.conf" 2>/dev/null || true

# 5. Overlay shared airootfs and cloud specific airootfs
if [ -d "${ROOT_DIR}/shared/airootfs" ]; then
    mkdir -p "${BUILD_PROFILE}/airootfs"
    cp -r "${ROOT_DIR}/shared/airootfs/." "${BUILD_PROFILE}/airootfs/"
fi
if [ -d "${PROFILE_SRC}/airootfs" ]; then
    mkdir -p "${BUILD_PROFILE}/airootfs"
    cp -r "${PROFILE_SRC}/airootfs/." "${BUILD_PROFILE}/airootfs/"
fi

# Ensure all files defined in file_permissions exist in airootfs
mkdir -p "${BUILD_PROFILE}/airootfs/etc/sudoers.d"
if [ ! -f "${BUILD_PROFILE}/airootfs/etc/sudoers.d/g_wheel" ]; then
    echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > "${BUILD_PROFILE}/airootfs/etc/sudoers.d/g_wheel"
fi
mkdir -p "${BUILD_PROFILE}/airootfs/root"
[ -f "${BUILD_PROFILE}/airootfs/etc/shadow" ] || touch "${BUILD_PROFILE}/airootfs/etc/shadow"
[ -f "${BUILD_PROFILE}/airootfs/etc/gshadow" ] || touch "${BUILD_PROFILE}/airootfs/etc/gshadow"
chmod +x "${BUILD_PROFILE}/airootfs/usr/local/bin/caelaris-cloud-setup" 2>/dev/null || true

# Privacy & Security: Ensure clean machine-id and no SSH keys in build profile
mkdir -p "${BUILD_PROFILE}/airootfs/etc"
truncate -s 0 "${BUILD_PROFILE}/airootfs/etc/machine-id" 2>/dev/null || true
rm -f "${BUILD_PROFILE}/airootfs"/etc/ssh/ssh_host_* 2>/dev/null || true

# 6. Build the Cloud ISO using mkarchiso
echo "Running mkarchiso to build Caelaris Cloud Edition..."
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$BUILD_PROFILE"

# Normalize output filename
find "$OUT_DIR" -name "*.iso" -exec mv {} "${OUT_DIR}/caelaris-cloud-x86_64.iso" \;

# Generate SHA256 checksum
cd "$OUT_DIR"
sha256sum "caelaris-cloud-x86_64.iso" > "caelaris-cloud-x86_64.iso.sha256"
sha256sum "caelaris-cloud-x86_64.iso" > "SHA256SUMS.txt"
cd "$ROOT_DIR"

echo "=========================================================="
echo " Cloud ISO Built Successfully:                            "
echo " ${OUT_DIR}/caelaris-cloud-x86_64.iso                     "
echo "=========================================================="
