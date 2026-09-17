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

rm -rf "$BUILD_PROFILE" "$WORK_DIR"
mkdir -p "$BUILD_PROFILE"

# 1. Copy the official archiso releng profile as baseline (provides bootloaders, syslinux, efiboot)
if [ -d "/usr/share/archiso/configs/releng" ]; then
    echo "Copying archiso releng bootloader baseline..."
    cp -r /usr/share/archiso/configs/releng/. "$BUILD_PROFILE/"
fi

# 2. Overlay our edition-specific profile
cp -r "${PROFILE_SRC}/." "$BUILD_PROFILE/"

# 3. Append our shared packages, desktop packages, and baseline packages
if [ -f "/usr/share/archiso/configs/releng/packages.x86_64" ]; then
    cat "/usr/share/archiso/configs/releng/packages.x86_64" >> "${BUILD_PROFILE}/packages.x86_64"
fi
cat "${ROOT_DIR}/shared/packages.common" >> "${BUILD_PROFILE}/packages.x86_64"
cat "${PROFILE_SRC}/packages.x86_64" >> "${BUILD_PROFILE}/packages.x86_64"

# 4. Sort and deduplicate packages.x86_64
sort -u "${BUILD_PROFILE}/packages.x86_64" -o "${BUILD_PROFILE}/packages.x86_64"
# Remove empty lines and comments
sed -i '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "${BUILD_PROFILE}/packages.x86_64"

# 5. Overlay shared pacman.conf
cp "${ROOT_DIR}/shared/pacman.conf" "${BUILD_PROFILE}/pacman.conf"

# 6. Overlay shared airootfs files
if [ -d "${ROOT_DIR}/shared/airootfs" ]; then
    mkdir -p "${BUILD_PROFILE}/airootfs"
    cp -r "${ROOT_DIR}/shared/airootfs/." "${BUILD_PROFILE}/airootfs/"
fi

# 7. Inject custom os-release branding
mkdir -p "${BUILD_PROFILE}/airootfs/etc"
cp "${ROOT_DIR}/shared/branding/os-release" "${BUILD_PROFILE}/airootfs/etc/os-release"

# 8. Configure Graphical Boot & Display Manager
mkdir -p "${BUILD_PROFILE}/airootfs/etc/systemd/system/sysinit.target.wants"
ln -sf /usr/lib/systemd/system/graphical.target "${BUILD_PROFILE}/airootfs/etc/systemd/system/default.target"
ln -sf /etc/systemd/system/caelaris-live-setup.service "${BUILD_PROFILE}/airootfs/etc/systemd/system/sysinit.target.wants/caelaris-live-setup.service"

if [[ "$EDITION" == "kde" ]]; then
    mkdir -p "${BUILD_PROFILE}/airootfs/etc/systemd/system/graphical.target.wants"
    ln -sf /usr/lib/systemd/system/sddm.service "${BUILD_PROFILE}/airootfs/etc/systemd/system/display-manager.service"
    ln -sf /usr/lib/systemd/system/sddm.service "${BUILD_PROFILE}/airootfs/etc/systemd/system/graphical.target.wants/sddm.service"
fi

if [[ "$EDITION" == "gnome" ]]; then
    mkdir -p "${BUILD_PROFILE}/airootfs/etc/systemd/system/graphical.target.wants"
    ln -sf /usr/lib/systemd/system/gdm.service "${BUILD_PROFILE}/airootfs/etc/systemd/system/display-manager.service"
    ln -sf /usr/lib/systemd/system/gdm.service "${BUILD_PROFILE}/airootfs/etc/systemd/system/graphical.target.wants/gdm.service"
fi

# Remove releng console autologin on tty1 so SDDM/GDM takes the screen
rm -rf "${BUILD_PROFILE}/airootfs/etc/systemd/system/getty@tty1.service.d"

mkdir -p "$OUT_DIR"

echo "Running mkarchiso validation and build..."
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$BUILD_PROFILE"

echo "=========================================================="
echo " ISO Generated successfully in: ${OUT_DIR}                "
echo "=========================================================="
