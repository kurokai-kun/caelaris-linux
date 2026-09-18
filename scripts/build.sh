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

# 1. Copy official archiso releng profile as baseline
if [ -d "/usr/share/archiso/configs/releng" ]; then
    echo "Copying archiso releng bootloader baseline..."
    cp -r /usr/share/archiso/configs/releng/. "$BUILD_PROFILE/"
fi

# 2. Overlay our edition-specific profile
cp -r "${PROFILE_SRC}/." "$BUILD_PROFILE/"

# 3. Append baseline, shared, and edition packages
if [ -f "/usr/share/archiso/configs/releng/packages.x86_64" ]; then
    cat "/usr/share/archiso/configs/releng/packages.x86_64" >> "${BUILD_PROFILE}/packages.x86_64"
fi
cat "${ROOT_DIR}/shared/packages.common" >> "${BUILD_PROFILE}/packages.x86_64"
cat "${PROFILE_SRC}/packages.x86_64" >> "${BUILD_PROFILE}/packages.x86_64"

# 4. Sort and deduplicate packages
sort -u "${BUILD_PROFILE}/packages.x86_64" -o "${BUILD_PROFILE}/packages.x86_64"
sed -i '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "${BUILD_PROFILE}/packages.x86_64"
sed -i '/virtualbox-guest-utils-nox/d' "${BUILD_PROFILE}/packages.x86_64"
sed -i '/xf86-video-vmware/d' "${BUILD_PROFILE}/packages.x86_64"

# 5. Overlay shared pacman.conf
cp "${ROOT_DIR}/shared/pacman.conf" "${BUILD_PROFILE}/pacman.conf"

# 6. Overlay shared airootfs files
if [ -d "${ROOT_DIR}/shared/airootfs" ]; then
    mkdir -p "${BUILD_PROFILE}/airootfs"
    cp -r "${ROOT_DIR}/shared/airootfs/." "${BUILD_PROFILE}/airootfs/"
fi

# 7. Copy Calamares configuration to /etc/calamares
mkdir -p "${BUILD_PROFILE}/airootfs/etc/calamares"
cp -r "${ROOT_DIR}/installer/calamares/." "${BUILD_PROFILE}/airootfs/etc/calamares/"

# 8. Inject custom os-release branding
mkdir -p "${BUILD_PROFILE}/airootfs/etc"
cp "${ROOT_DIR}/shared/branding/os-release" "${BUILD_PROFILE}/airootfs/etc/os-release"

# 9. Brand and configure Dual-Desktop Bootloader Menus
echo "Configuring bootloader entries for Caelaris Linux (KDE & GNOME)..."

# Brand existing entries
find "${BUILD_PROFILE}/efiboot" "${BUILD_PROFILE}/grub" "${BUILD_PROFILE}/syslinux" -type f \( -name "*.conf" -o -name "*.cfg" \) -exec sed -i \
    -e 's/Arch Linux install medium/Caelaris Linux (KDE Plasma)/g' \
    -e 's/Arch Linux/Caelaris Linux/g' \
    -e 's/archlinux/caelaris/g' {} + 2>/dev/null || true

# Add GNOME bootloader entry in UEFI systemd-boot if template exists
if [ -d "${BUILD_PROFILE}/efiboot/loader/entries" ]; then
    BASE_ENTRY=$(find "${BUILD_PROFILE}/efiboot/loader/entries" -name "*x86_64*.conf" | head -n 1 || true)
    if [ -n "$BASE_ENTRY" ] && [ -f "$BASE_ENTRY" ]; then
        GNOME_ENTRY="${BUILD_PROFILE}/efiboot/loader/entries/02-caelaris-gnome.conf"
        cp "$BASE_ENTRY" "$GNOME_ENTRY"
        sed -i 's/title.*/title   Caelaris Linux (GNOME Desktop)/' "$GNOME_ENTRY"
        sed -i 's/options.*/& desktop=gnome/' "$GNOME_ENTRY"
    fi
fi

# 10. Configure Graphical Boot & Display Manager
mkdir -p "${BUILD_PROFILE}/airootfs/etc/systemd/system/sysinit.target.wants"
ln -sf /usr/lib/systemd/system/graphical.target "${BUILD_PROFILE}/airootfs/etc/systemd/system/default.target"
ln -sf /etc/systemd/system/caelaris-live-setup.service "${BUILD_PROFILE}/airootfs/etc/systemd/system/sysinit.target.wants/caelaris-live-setup.service"

mkdir -p "${BUILD_PROFILE}/airootfs/etc/systemd/system/graphical.target.wants"
ln -sf /usr/lib/systemd/system/sddm.service "${BUILD_PROFILE}/airootfs/etc/systemd/system/display-manager.service"
ln -sf /usr/lib/systemd/system/sddm.service "${BUILD_PROFILE}/airootfs/etc/systemd/system/graphical.target.wants/sddm.service"

# Enable VirtualBox Guest Service for seamless display scaling & acceleration
mkdir -p "${BUILD_PROFILE}/airootfs/etc/systemd/system/multi-user.target.wants"
ln -sf /usr/lib/systemd/system/vboxservice.service "${BUILD_PROFILE}/airootfs/etc/systemd/system/multi-user.target.wants/vboxservice.service" 2>/dev/null || true

# Generate PNG logo from SVG if rsvg-convert is available
if which rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w 256 -h 256 -o "${BUILD_PROFILE}/airootfs/usr/share/pixmaps/caelaris-logo.png" "${BUILD_PROFILE}/airootfs/usr/share/pixmaps/caelaris-logo.svg" 2>/dev/null || true
fi

# Ensure all scripts are executable
chmod +x "${BUILD_PROFILE}/airootfs/usr/bin/"* 2>/dev/null || true
chmod +x "${BUILD_PROFILE}/airootfs/etc/skel/Desktop/"*.desktop 2>/dev/null || true

# Remove console autologin on tty1 so graphical display manager takes the screen
rm -rf "${BUILD_PROFILE}/airootfs/etc/systemd/system/getty@tty1.service.d"

mkdir -p "$OUT_DIR"

echo "Running mkarchiso validation and build..."
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$BUILD_PROFILE"

echo "=========================================================="
echo " ISO Generated successfully in: ${OUT_DIR}                "
echo "=========================================================="
