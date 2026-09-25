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

# 4. Filter unwanted packages (beeps, accessibility speech clutter, memtest, edk2-shell) and deduplicate
sed -i -E '/^(livecd-sounds|espeakup|brltty|memtest86\+|memtest86\+-efi|edk2-shell|virtualbox-guest-utils-nox)$/d' "${BUILD_PROFILE}/packages.x86_64"
sort -u "${BUILD_PROFILE}/packages.x86_64" -o "${BUILD_PROFILE}/packages.x86_64"
sed -i '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "${BUILD_PROFILE}/packages.x86_64"

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

# 9. Configure Silent, Clutter-Free Bootloader Menus (UEFI & BIOS)
echo "Configuring bootloader entries for Caelaris Linux..."

# Strip any residual splash, play, or audible beep directives across all bootloader configs
find "${BUILD_PROFILE}" -type f \( -name "*.conf" -o -name "*.cfg" \) -exec sed -i \
    -e 's/Arch Linux/Caelaris Linux/g' \
    -e 's/archlinux/caelaris/g' \
    -e 's/splash//g' \
    -e '/^[[:space:]]*play /d' \
    -e 's/beep on/beep 0/g' \
    -e 's/beep no/beep 0/g' \
    -e 's/beep 1/beep 0/g' {} + 2>/dev/null || true

# A. UEFI systemd-boot configuration (handles both modern loader/ and legacy efiboot/loader/)
for loader_dir in "${BUILD_PROFILE}/loader" "${BUILD_PROFILE}/efiboot/loader"; do
    if [ -d "$loader_dir" ]; then
        mkdir -p "${loader_dir}/entries"
        # Purge upstream archiso clutter (speech, memtest, uefi-shell, copy-to-ram)
        rm -rf "${loader_dir}/entries/"* 2>/dev/null || true

        cat > "${loader_dir}/loader.conf" << 'EOF'
timeout 2
default 01-caelaris.conf
beep 0
console-mode max
EOF

        cat > "${loader_dir}/entries/01-caelaris.conf" << 'EOF'
title   Caelaris Linux
linux   /%INSTALL_DIR%/boot/x86_64/vmlinuz-linux
initrd  /%INSTALL_DIR%/boot/intel-ucode.img
initrd  /%INSTALL_DIR%/boot/amd-ucode.img
initrd  /%INSTALL_DIR%/boot/x86_64/initramfs-linux.img
options archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% systemd.unit=graphical.target desktop=plasma video=1920x1080 quiet loglevel=3 rd.udev.log_level=3 plymouth.enable=0 modprobe.blacklist=pcspkr,snd_pcsp
EOF

        cat > "${loader_dir}/entries/02-caelaris-safe.conf" << 'EOF'
title   Caelaris Linux (Safe Graphics / Fallback)
linux   /%INSTALL_DIR%/boot/x86_64/vmlinuz-linux
initrd  /%INSTALL_DIR%/boot/intel-ucode.img
initrd  /%INSTALL_DIR%/boot/amd-ucode.img
initrd  /%INSTALL_DIR%/boot/x86_64/initramfs-linux.img
options archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% systemd.unit=graphical.target desktop=plasma nomodeset quiet plymouth.enable=0 modprobe.blacklist=pcspkr,snd_pcsp
EOF
    fi
done

# B. BIOS Syslinux configuration
if [ -d "${BUILD_PROFILE}/syslinux" ]; then
    # Purge upstream archiso clutter (memtest, HDT, speech, PXE)
    rm -f "${BUILD_PROFILE}/syslinux"/*speech* "${BUILD_PROFILE}/syslinux"/*memtest* "${BUILD_PROFILE}/syslinux"/*hdt* "${BUILD_PROFILE}/syslinux"/archiso_pxe* 2>/dev/null || true

    cat > "${BUILD_PROFILE}/syslinux/syslinux.cfg" << 'EOF'
DEFAULT loadconfig

LABEL loadconfig
  CONFIG archiso_sys.cfg
EOF

    cat > "${BUILD_PROFILE}/syslinux/archiso_head.cfg" << 'EOF'
DEFAULT caelaris
PROMPT 0
TIMEOUT 20
MENU TITLE Caelaris Linux
EOF

    cat > "${BUILD_PROFILE}/syslinux/archiso_sys.cfg" << 'EOF'
INCLUDE archiso_head.cfg
INCLUDE archiso_sys-linux.cfg
INCLUDE archiso_tail.cfg
EOF

    cat > "${BUILD_PROFILE}/syslinux/archiso_tail.cfg" << 'EOF'
LABEL reboot
MENU LABEL Reboot
COM32 reboot.c32

LABEL poweroff
MENU LABEL Power Off
COM32 poweroff.c32
EOF

    # Strip audible ASCII bell characters (\x07) and prompt beeps from all syslinux configs
    find "${BUILD_PROFILE}/syslinux" -type f -exec sed -i 's/\x07//g' {} + 2>/dev/null || true

    cat > "${BUILD_PROFILE}/syslinux/archiso_sys-linux.cfg" << 'EOF'
LABEL caelaris
TEXT HELP
Boot Caelaris Linux live desktop.
ENDTEXT
MENU LABEL Caelaris Linux
LINUX /%INSTALL_DIR%/boot/x86_64/vmlinuz-linux
INITRD /%INSTALL_DIR%/boot/intel-ucode.img,/%INSTALL_DIR%/boot/amd-ucode.img,/%INSTALL_DIR%/boot/x86_64/initramfs-linux.img
APPEND archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% systemd.unit=graphical.target desktop=plasma video=1920x1080 quiet loglevel=3 rd.udev.log_level=3 plymouth.enable=0 modprobe.blacklist=pcspkr,snd_pcsp

LABEL caelaris_safe
TEXT HELP
Boot Caelaris Linux with basic safe graphics mode.
ENDTEXT
MENU LABEL Caelaris Linux (Safe Graphics)
LINUX /%INSTALL_DIR%/boot/x86_64/vmlinuz-linux
INITRD /%INSTALL_DIR%/boot/intel-ucode.img,/%INSTALL_DIR%/boot/amd-ucode.img,/%INSTALL_DIR%/boot/x86_64/initramfs-linux.img
APPEND archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% systemd.unit=graphical.target desktop=plasma nomodeset quiet plymouth.enable=0 modprobe.blacklist=pcspkr,snd_pcsp

LABEL boot_hdd
TEXT HELP
Boot installed operating system from the primary local hard drive.
ENDTEXT
MENU LABEL Boot Installed System (Hard Disk)
COM32 whichsys.c32
APPEND -iso- chain.c32 hd0
EOF
fi

# C. GRUB configuration (UEFI & BIOS)
find "${BUILD_PROFILE}" -type f -name "grub.cfg" -exec sh -c '
    cat > "$1" << "EOF"
set default="0"
set timeout=2

menuentry "Caelaris Linux" --class caelaris --class kde --class gnu-linux --class gnu --class os {
    set gfxpayload=keep
    linux /%INSTALL_DIR%/boot/x86_64/vmlinuz-linux archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% systemd.unit=graphical.target desktop=plasma video=1920x1080 quiet loglevel=3 rd.udev.log_level=3 plymouth.enable=0 modprobe.blacklist=pcspkr,snd_pcsp
    initrd /%INSTALL_DIR%/boot/intel-ucode.img /%INSTALL_DIR%/boot/amd-ucode.img /%INSTALL_DIR%/boot/x86_64/initramfs-linux.img
}

menuentry "Caelaris Linux (Safe Graphics / Fallback)" --class caelaris --class gnu-linux {
    set gfxpayload=keep
    linux /%INSTALL_DIR%/boot/x86_64/vmlinuz-linux archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% systemd.unit=graphical.target desktop=plasma nomodeset quiet plymouth.enable=0 modprobe.blacklist=pcspkr,snd_pcsp
    initrd /%INSTALL_DIR%/boot/intel-ucode.img /%INSTALL_DIR%/boot/amd-ucode.img /%INSTALL_DIR%/boot/x86_64/initramfs-linux.img
}

menuentry "Boot Installed System (Hard Disk)" --class hd --class disk {
    set root=(hd0)
    chainloader +1
}
EOF
' _ {} \;

# 10. Configure Graphical Boot & Display Manager
mkdir -p "${BUILD_PROFILE}/airootfs/etc/systemd/system/graphical.target.wants"
mkdir -p "${BUILD_PROFILE}/airootfs/etc/systemd/system/multi-user.target.wants"
ln -sf /usr/lib/systemd/system/graphical.target "${BUILD_PROFILE}/airootfs/etc/systemd/system/default.target"
ln -sf /etc/systemd/system/caelaris-live-setup.service "${BUILD_PROFILE}/airootfs/etc/systemd/system/graphical.target.wants/caelaris-live-setup.service"
ln -sf /etc/systemd/system/caelaris-live-setup.service "${BUILD_PROFILE}/airootfs/etc/systemd/system/multi-user.target.wants/caelaris-live-setup.service"
ln -sf /usr/lib/systemd/system/sddm.service "${BUILD_PROFILE}/airootfs/etc/systemd/system/display-manager.service"
ln -sf /usr/lib/systemd/system/sddm.service "${BUILD_PROFILE}/airootfs/etc/systemd/system/graphical.target.wants/sddm.service"
ln -sf /usr/lib/systemd/system/sddm.service "${BUILD_PROFILE}/airootfs/etc/systemd/system/multi-user.target.wants/sddm.service"

# Configure SDDM with stable display server and pre-configured autologin
mkdir -p "${BUILD_PROFILE}/airootfs/etc/sddm.conf.d"
cat > "${BUILD_PROFILE}/airootfs/etc/sddm.conf.d/autologin.conf" << 'EOF'
[Autologin]
User=liveuser
Session=plasma
Relogin=false
EOF

cat > "${BUILD_PROFILE}/airootfs/etc/sddm.conf.d/10-general.conf" << 'EOF'
[General]
DisplayServer=x11
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot

[Theme]
Current=breeze
CursorTheme=breeze_cursors
EOF
rm -f "${BUILD_PROFILE}/airootfs/etc/sddm.conf.d/10-wayland.conf" 2>/dev/null || true

# Mask plymouth services completely so systemd never hangs waiting on splash daemon
for unit in plymouth-start.service plymouth-quit.service plymouth-quit-wait.service plymouth-reboot.service plymouth-poweroff.service plymouth-halt.service plymouth-kexec.service plymouth-switch-root.service; do
    ln -sf /dev/null "${BUILD_PROFILE}/airootfs/etc/systemd/system/${unit}" 2>/dev/null || true
done

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
