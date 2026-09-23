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

# 9. Brand and configure Dual-Desktop Bootloader Menus (KDE & GNOME Preview Options)
echo "Configuring bootloader entries for Caelaris Linux (KDE & GNOME)..."

# Brand global text
find "${BUILD_PROFILE}/efiboot" "${BUILD_PROFILE}/grub" "${BUILD_PROFILE}/syslinux" -type f \( -name "*.conf" -o -name "*.cfg" \) -exec sed -i \
    -e 's/Arch Linux/Caelaris Linux/g' \
    -e 's/archlinux/caelaris/g' {} + 2>/dev/null || true

# Strip any splash references
find "${BUILD_PROFILE}/efiboot" "${BUILD_PROFILE}/grub" "${BUILD_PROFILE}/syslinux" -type f \( -name "*.conf" -o -name "*.cfg" \) -exec sed -i \
    -e 's/splash//g' {} + 2>/dev/null || true

# A. UEFI systemd-boot configuration
if [ -d "${BUILD_PROFILE}/efiboot/loader" ]; then
    mkdir -p "${BUILD_PROFILE}/efiboot/loader/entries"
    rm -rf "${BUILD_PROFILE}/efiboot/loader/entries/"* 2>/dev/null || true

    cat > "${BUILD_PROFILE}/efiboot/loader/loader.conf" << 'EOF'
timeout 3
default 01-caelaris.conf
beep 0
EOF

    cat > "${BUILD_PROFILE}/efiboot/loader/entries/01-caelaris.conf" << 'EOF'
title   Caelaris Linux
linux   /%INSTALL_DIR%/boot/x86_64/vmlinuz-linux
initrd  /%INSTALL_DIR%/boot/intel-ucode.img
initrd  /%INSTALL_DIR%/boot/amd-ucode.img
initrd  /%INSTALL_DIR%/boot/x86_64/initramfs-linux.img
options archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% desktop=plasma video=1920x1080 quiet
EOF
fi

# B. BIOS Syslinux configuration
if [ -d "${BUILD_PROFILE}/syslinux" ]; then
    sed -i 's/TIMEOUT .*/TIMEOUT 30/' "${BUILD_PROFILE}/syslinux/archiso_head.cfg" 2>/dev/null || true
    sed -i 's/DEFAULT .*/DEFAULT caelaris/' "${BUILD_PROFILE}/syslinux/archiso.cfg" 2>/dev/null || true

    cat > "${BUILD_PROFILE}/syslinux/archiso_sys-linux.cfg" << 'EOF'
LABEL caelaris
TEXT HELP
Boot Caelaris Linux live preview with KDE Plasma 6.
ENDTEXT
MENU LABEL Caelaris Linux
LINUX /%INSTALL_DIR%/boot/x86_64/vmlinuz-linux
INITRD /%INSTALL_DIR%/boot/intel-ucode.img,/%INSTALL_DIR%/boot/amd-ucode.img,/%INSTALL_DIR%/boot/x86_64/initramfs-linux.img
APPEND archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% desktop=plasma video=1920x1080 quiet

LABEL boot_hdd
TEXT HELP
Boot installed operating system from the primary local hard drive.
ENDTEXT
MENU LABEL Boot Installed System (Hard Disk)
COM32 whichsys.c32
APPEND -iso- chain.c32 hd0
EOF
fi

# C. GRUB configuration
if [ -f "${BUILD_PROFILE}/grub/grub.cfg" ]; then
    cat > "${BUILD_PROFILE}/grub/grub.cfg" << 'EOF'
set timeout=3
set default="0"

menuentry "Caelaris Linux" --class caelaris --class kde --class gnu-linux --class gnu --class os {
    set gfxpayload=keep
    linux /%INSTALL_DIR%/boot/x86_64/vmlinuz-linux archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% desktop=plasma video=1920x1080 quiet
    initrd /%INSTALL_DIR%/boot/intel-ucode.img /%INSTALL_DIR%/boot/amd-ucode.img /%INSTALL_DIR%/boot/x86_64/initramfs-linux.img
}

menuentry "Boot Installed System (Hard Disk)" --class hd --class disk {
    set root=(hd0)
    chainloader +1
}
EOF
fi

# 10. Configure Graphical Boot & Display Manager
mkdir -p "${BUILD_PROFILE}/airootfs/etc/systemd/system/graphical.target.wants"
ln -sf /usr/lib/systemd/system/graphical.target "${BUILD_PROFILE}/airootfs/etc/systemd/system/default.target"
ln -sf /etc/systemd/system/caelaris-live-setup.service "${BUILD_PROFILE}/airootfs/etc/systemd/system/graphical.target.wants/caelaris-live-setup.service"
ln -sf /usr/lib/systemd/system/sddm.service "${BUILD_PROFILE}/airootfs/etc/systemd/system/display-manager.service"
ln -sf /usr/lib/systemd/system/sddm.service "${BUILD_PROFILE}/airootfs/etc/systemd/system/graphical.target.wants/sddm.service"

# Mask benign systemd-loop@ service on CD-ROM to silence loopback block device log
ln -sf /dev/null "${BUILD_PROFILE}/airootfs/etc/systemd/system/systemd-loop@.service" 2>/dev/null || true

# Enable VirtualBox, VMware & UTM / QEMU Guest Services for display scaling & acceleration
mkdir -p "${BUILD_PROFILE}/airootfs/etc/systemd/system/multi-user.target.wants"
ln -sf /usr/lib/systemd/system/vboxservice.service "${BUILD_PROFILE}/airootfs/etc/systemd/system/multi-user.target.wants/vboxservice.service" 2>/dev/null || true
ln -sf /usr/lib/systemd/system/vmtoolsd.service "${BUILD_PROFILE}/airootfs/etc/systemd/system/multi-user.target.wants/vmtoolsd.service" 2>/dev/null || true
ln -sf /usr/lib/systemd/system/vmware-vmblock-fuse.service "${BUILD_PROFILE}/airootfs/etc/systemd/system/multi-user.target.wants/vmware-vmblock-fuse.service" 2>/dev/null || true
ln -sf /usr/lib/systemd/system/spice-vdagentd.service "${BUILD_PROFILE}/airootfs/etc/systemd/system/multi-user.target.wants/spice-vdagentd.service" 2>/dev/null || true

# Generate PNG logo from SVG if rsvg-convert is available
if which rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w 256 -h 256 -o "${BUILD_PROFILE}/airootfs/usr/share/pixmaps/caelaris-logo.png" "${BUILD_PROFILE}/airootfs/usr/share/pixmaps/caelaris-logo.svg" 2>/dev/null || true
fi

# Ensure all scripts are executable
chmod +x "${BUILD_PROFILE}/airootfs/usr/bin/"* 2>/dev/null || true
chmod +x "${BUILD_PROFILE}/airootfs/etc/skel/Desktop/"*.desktop 2>/dev/null || true

# Remove console autologin on tty1 so graphical display manager takes the screen
rm -rf "${BUILD_PROFILE}/airootfs/etc/systemd/system/getty@tty1.service.d"

# Privacy & Security: Ensure clean machine-id and no SSH host keys in ISO airootfs
truncate -s 0 "${BUILD_PROFILE}/airootfs/etc/machine-id" 2>/dev/null || true
rm -f "${BUILD_PROFILE}/airootfs"/etc/ssh/ssh_host_* 2>/dev/null || true

mkdir -p "$OUT_DIR"

echo "Running mkarchiso validation and build..."
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$BUILD_PROFILE"

echo "=========================================================="
echo " ISO Generated successfully in: ${OUT_DIR}                "
echo "=========================================================="
