#!/usr/bin/env bash
set -euo pipefail

EDITION="${1:-kde}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
WORK_DIR="/tmp/caelaris-arm64-pc-work"
OUT_DIR="${ROOT_DIR}/out-arm64-pc"
ROOTFS_DIR="${WORK_DIR}/rootfs"
BUILD_DATE=$(date +%Y.%m.%d)
IMAGE_NAME="caelaris-arm64-pc-${BUILD_DATE}"

echo "=========================================================="
echo " Building Caelaris Linux ARM64 Laptop & PC Edition        "
echo " Target: Apple Silicon, Snapdragon X Elite & ARM PCs      "
echo " Edition: ${EDITION} | Date: ${BUILD_DATE}               "
echo "=========================================================="

mkdir -p "$WORK_DIR" "$OUT_DIR" "$ROOTFS_DIR"

# 1. Download Arch Linux ARM generic 64-bit rootfs baseline
ARCH_ARM_TAR="ArchLinuxARM-aarch64-latest.tar.gz"
DOWNLOAD_URL="http://os.archlinuxarm.org/os/${ARCH_ARM_TAR}"

if [ ! -f "${WORK_DIR}/${ARCH_ARM_TAR}" ]; then
    echo "[1/5] Downloading Arch Linux ARM aarch64 generic baseline..."
    curl -fL -o "${WORK_DIR}/${ARCH_ARM_TAR}" "$DOWNLOAD_URL" || {
        echo "Primary mirror failed, trying fallback mirror..."
        curl -fL -o "${WORK_DIR}/${ARCH_ARM_TAR}" "http://de3.mirror.archlinuxarm.org/os/${ARCH_ARM_TAR}"
    }
else
    echo "[1/5] Using cached Arch Linux ARM rootfs..."
fi

# 2. Extract rootfs
echo "[2/5] Extracting ARM64 root filesystem..."
bsdtar -xpf "${WORK_DIR}/${ARCH_ARM_TAR}" -C "$ROOTFS_DIR"

# 2.5. Provision Live Desktop Preview & Graphical Installer Packages via QEMU
echo "[2.5/5] Provisioning Live Desktop (KDE Plasma Wayland) and Installer Packages via QEMU..."

QEMU_BIN=""
if [ -f /usr/bin/qemu-aarch64-static ]; then
    QEMU_BIN="/usr/bin/qemu-aarch64-static"
elif [ -f /usr/bin/qemu-arm64-static ]; then
    QEMU_BIN="/usr/bin/qemu-arm64-static"
fi

if [ -n "$QEMU_BIN" ]; then
    echo "Found QEMU emulator: $QEMU_BIN. Setting up chroot environment..."
    cp "$QEMU_BIN" "${ROOTFS_DIR}/usr/bin/"

    # Set up bind mounts for chroot execution
    mount --bind /dev "${ROOTFS_DIR}/dev" || true
    mount --bind /dev/pts "${ROOTFS_DIR}/dev/pts" || true
    mount -t proc proc "${ROOTFS_DIR}/proc" || true
    mount -t sysfs sysfs "${ROOTFS_DIR}/sys" || true

    cleanup_chroot() {
        umount -l "${ROOTFS_DIR}/dev/pts" 2>/dev/null || true
        umount -l "${ROOTFS_DIR}/dev" 2>/dev/null || true
        umount -l "${ROOTFS_DIR}/proc" 2>/dev/null || true
        umount -l "${ROOTFS_DIR}/sys" 2>/dev/null || true
        rm -f "${ROOTFS_DIR}/usr/bin/qemu-aarch64-static" "${ROOTFS_DIR}/usr/bin/qemu-arm64-static" 2>/dev/null || true
    }
    trap cleanup_chroot EXIT INT TERM

    # Ensure robust DNS inside chroot by replacing any dangling symlinks with authoritative public DNS
    rm -f "${ROOTFS_DIR}/etc/resolv.conf"
    cat << 'EOF' > "${ROOTFS_DIR}/etc/resolv.conf"
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 9.9.9.9
EOF

    # Configure multiple high-speed, reliable mirrors
    mkdir -p "${ROOTFS_DIR}/etc/pacman.d"
    cat << 'EOF' > "${ROOTFS_DIR}/etc/pacman.d/mirrorlist"
Server = http://fl.us.mirror.archlinuxarm.org/$arch/$repo
Server = http://nj.us.mirror.archlinuxarm.org/$arch/$repo
Server = http://mirror.archlinuxarm.org/$arch/$repo
Server = http://de3.mirror.archlinuxarm.org/$arch/$repo
Server = http://dk.mirror.archlinuxarm.org/$arch/$repo
EOF

    # Optimize pacman config for speed and reliability during image build (disable CheckSpace & Landlock/seccomp sandbox under QEMU)
    sed -i 's/^#ParallelDownloads = .*/ParallelDownloads = 5/' "${ROOTFS_DIR}/etc/pacman.conf" 2>/dev/null || true
    sed -i 's/^SigLevel.*/SigLevel = Never/' "${ROOTFS_DIR}/etc/pacman.conf" 2>/dev/null || true
    sed -i 's/^CheckSpace/#CheckSpace/' "${ROOTFS_DIR}/etc/pacman.conf" 2>/dev/null || true
    sed -i '/\[options\]/a DisableSandboxFilesystem\nDisableSandboxSyscalls\nDownloadUser = root' "${ROOTFS_DIR}/etc/pacman.conf" 2>/dev/null || true

    # Initialize pacman keyring
    echo "Initializing Arch Linux ARM pacman keyring..."
    chroot "$ROOTFS_DIR" /bin/bash -c "pacman-key --init && pacman-key --populate archlinuxarm" || true

    # Verify DNS inside chroot
    echo "Testing DNS resolution inside ARM64 chroot..."
    chroot "$ROOTFS_DIR" /bin/bash -c "getent hosts mirror.archlinuxarm.org || true"

    # Sync package databases with retry
    echo "Updating package databases..."
    chroot "$ROOTFS_DIR" /bin/bash -c "pacman -Sy --noconfirm" || {
        echo "Retrying pacman database sync..."
        sleep 2
        chroot "$ROOTFS_DIR" /bin/bash -c "pacman -Sy --noconfirm"
    }

    # Desktop packages for live preview & installer
    # Unified Dual Desktop Suite: Pre-installs BOTH KDE Plasma 6 and GNOME Desktop
    DESKTOP_PKGS=(
        plasma-desktop
        kwin
        sddm
        wayland
        qt6-wayland
        xorg-xwayland
        konsole
        dolphin
        breeze
        breeze-gtk
        gnome-shell
        mutter
        ptyxis
        nautilus
        mesa
        vulkan-freedreno
        vulkan-panfrost
        linux-firmware
        pipewire
        wireplumber
        networkmanager
        network-manager-applet
        python
        python-pyqt6
        python-psutil
        parted
        dosfstools
        e2fsprogs
        btrfs-progs
        arch-install-scripts
        rsync
        squashfs-tools
        grub
        efibootmgr
        sudo
        bash
    )

    echo "Installing live preview desktop & installer packages..."
    # Tier 1: Core System, Kernel, GUI Installer, and Bootloader essentials
    chroot "$ROOTFS_DIR" /bin/bash -c "pacman -S --needed --noconfirm --overwrite='*' linux-aarch64 mkinitcpio mkinitcpio-archiso python python-pyqt6 sudo bash networkmanager sddm mesa grub efibootmgr parted dosfstools e2fsprogs btrfs-progs rsync squashfs-tools noto-fonts" || {
        echo "Retrying Tier 1 package installation..."
        sleep 3
        chroot "$ROOTFS_DIR" /bin/bash -c "pacman -S --needed --noconfirm --overwrite='*' linux-aarch64 mkinitcpio mkinitcpio-archiso python python-pyqt6 sudo bash networkmanager sddm mesa grub efibootmgr parted dosfstools e2fsprogs btrfs-progs rsync squashfs-tools noto-fonts"
    }

    # Tier 2: Complete Desktop Preview Suite & Graphics
    chroot "$ROOTFS_DIR" /bin/bash -c "pacman -S --needed --noconfirm --overwrite='*' pipewire-jack qt6-multimedia-ffmpeg ${DESKTOP_PKGS[*]}" || {
        echo "Retrying Tier 2 package installation..."
        sleep 3
        chroot "$ROOTFS_DIR" /bin/bash -c "pacman -S --needed --noconfirm --overwrite='*' pipewire-jack qt6-multimedia-ffmpeg ${DESKTOP_PKGS[*]}"
    }

    # Verify installation of core desktop and installer packages
    if [ ! -f "${ROOTFS_DIR}/usr/bin/python" ] || [ ! -f "${ROOTFS_DIR}/usr/bin/sddm" ]; then
        echo "CRITICAL ERROR: Desktop packages failed to install inside ARM64 rootfs."
        exit 1
    fi

    # Configure mkinitcpio for live ISO booting
    cat << 'EOF' > "${ROOTFS_DIR}/etc/mkinitcpio.conf"
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base udev archiso archiso_loop_mnt block filesystems keyboard)
COMPRESSION="zstd"
EOF
    echo "Generating bootable live initramfs..."
    chroot "$ROOTFS_DIR" /bin/bash -c "mkinitcpio -P" || true

    # Ensure liveuser exists inside rootfs
    chroot "$ROOTFS_DIR" /bin/bash -c "
        if ! id -u liveuser >/dev/null 2>&1; then
            useradd -m -c 'Caelaris Live' -g users -G wheel,video,audio,storage,input,power -s /bin/bash liveuser
        fi
        passwd -d liveuser
    " || true

    # Generate standalone BOOTAA64.EFI using ARM64 GRUB modules
    echo "Compiling standalone ARM64 EFI bootloader (BOOTAA64.EFI)..."
    chroot "$ROOTFS_DIR" /bin/bash -c "
        if which grub-mkstandalone >/dev/null 2>&1; then
            grub-mkstandalone \
                --format=arm64-efi \
                -O arm64-efi \
                --output=/boot/BOOTAA64.EFI \
                --locales='' \
                --fonts='' \
                'boot/grub/grub.cfg=/etc/hostname' 2>/dev/null || true
        fi
    " || true

    # Restore standard pacman options for target installation
    sed -i 's/^SigLevel = Never/SigLevel = Required DatabaseOptional/' "${ROOTFS_DIR}/etc/pacman.conf" 2>/dev/null || true
    sed -i 's/^#CheckSpace/CheckSpace/' "${ROOTFS_DIR}/etc/pacman.conf" 2>/dev/null || true
    sed -i '/^DisableSandbox/d' "${ROOTFS_DIR}/etc/pacman.conf" 2>/dev/null || true
    sed -i '/^DownloadUser/d' "${ROOTFS_DIR}/etc/pacman.conf" 2>/dev/null || true

    # Clean package cache
    chroot "$ROOTFS_DIR" /bin/bash -c "pacman -Scc --noconfirm" || true

    cleanup_chroot
    trap - EXIT INT TERM
else
    echo "Notice: QEMU aarch64 emulator not found on host. Continuing with baseline rootfs."
fi

# 3. Apply Complete Caelaris Flagship Customizations (Matching x86_64)
echo "[3/5] Applying full Caelaris desktop customizations and configurations..."

# Hostname & branding
echo "caelaris-arm64" > "${ROOTFS_DIR}/etc/hostname"

cat << 'EOF' > "${ROOTFS_DIR}/etc/os-release"
NAME="Caelaris Linux ARM64"
PRETTY_NAME="Caelaris Linux ARM64 (Laptop & PC Edition)"
ID=caelaris
ID_LIKE=archarm
BUILD_ID=rolling
ANSI_COLOR="38;2;168;85;247"
HOME_URL="https://github.com/kurokai-kun/caelaris-linux"
DOCUMENTATION_URL="https://github.com/kurokai-kun/caelaris-linux"
SUPPORT_URL="https://github.com/kurokai-kun/caelaris-linux/issues"
LOGO=caelaris
EOF

# Copy shared airootfs configurations
if [ -d "${ROOT_DIR}/shared/airootfs" ]; then
    echo "Copying shared Caelaris system configurations..."
    cp -a "${ROOT_DIR}/shared/airootfs/." "${ROOTFS_DIR}/" 2>/dev/null || true
fi

# Ensure gaming sysctl parameters
mkdir -p "${ROOTFS_DIR}/etc/sysctl.d"
cat << 'EOF' > "${ROOTFS_DIR}/etc/sysctl.d/99-caelaris-gaming.conf"
# Caelaris Linux - High Performance Low Latency Sysctl
vm.max_map_count = 2147483642
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
net.core.default_qdisc = cake
net.ipv4.tcp_congestion_control = bbr
EOF

# Ensure ZRAM configuration
mkdir -p "${ROOTFS_DIR}/etc/systemd"
cat << 'EOF' > "${ROOTFS_DIR}/etc/systemd/zram-generator.conf"
[zram0]
zram-size = min(ram, 8192)
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF

# Configure SDDM display manager with autologin to live user
mkdir -p "${ROOTFS_DIR}/etc/sddm.conf.d"
SESSION_NAME="plasma"
if [ "$EDITION" = "gnome" ]; then
    SESSION_NAME="gnome"
fi

cat << EOF > "${ROOTFS_DIR}/etc/sddm.conf.d/autologin.conf"
[Autologin]
User=liveuser
Session=${SESSION_NAME}.desktop
Relogin=false
EOF

# Configure liveuser with wheel privileges
mkdir -p "${ROOTFS_DIR}/etc/sudoers.d"
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > "${ROOTFS_DIR}/etc/sudoers.d/wheel"
chmod 440 "${ROOTFS_DIR}/etc/sudoers.d/wheel"

# Configure dynamic session selection service based on bootloader session= cmdline parameter
mkdir -p "${ROOTFS_DIR}/usr/lib/systemd/system"
cat << 'EOF' > "${ROOTFS_DIR}/usr/lib/systemd/system/caelaris-session-select.service"
[Unit]
Description=Select Caelaris Live Desktop Session from Boot Argument
Before=sddm.service display-manager.service
ConditionPathExists=/etc/sddm.conf.d/autologin.conf

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'if grep -qw "session=gnome" /proc/cmdline; then sed -i "s/Session=.*/Session=gnome.desktop/" /etc/sddm.conf.d/autologin.conf; else sed -i "s/Session=.*/Session=plasma.desktop/" /etc/sddm.conf.d/autologin.conf; fi'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable system services
mkdir -p "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants"
mkdir -p "${ROOTFS_DIR}/etc/systemd/system/display-manager.service.wants"
ln -sf /usr/lib/systemd/system/systemd-resolved.service "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/" || true
ln -sf /usr/lib/systemd/system/NetworkManager.service "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/" || true
ln -sf /usr/lib/systemd/system/sddm.service "${ROOTFS_DIR}/etc/systemd/system/display-manager.service" || true
ln -sf /usr/lib/systemd/system/caelaris-session-select.service "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/" || true

# Place and make executable "Install Caelaris Linux" desktop launcher for liveuser
mkdir -p "${ROOTFS_DIR}/home/liveuser/Desktop"
if [ -f "${ROOTFS_DIR}/etc/skel/Desktop/install-caelaris.desktop" ]; then
    cp -f "${ROOTFS_DIR}/etc/skel/Desktop/install-caelaris.desktop" "${ROOTFS_DIR}/home/liveuser/Desktop/"
fi
chmod +x "${ROOTFS_DIR}/home/liveuser/Desktop/"*.desktop 2>/dev/null || true
chmod +x "${ROOTFS_DIR}/usr/bin/caelaris-"* 2>/dev/null || true
chown -R 1000:100 "${ROOTFS_DIR}/home/liveuser" 2>/dev/null || true

# 4. Generate Uncompromised Full Desktop Hybrid ARM64 ISO
echo "[4/5] Generating Full ARM64 UEFI Desktop ISO..."
ISO_STAGING="${WORK_DIR}/iso-staging"
rm -rf "$ISO_STAGING"
mkdir -p "${ISO_STAGING}/live" "${ISO_STAGING}/EFI/BOOT"

# Privacy & Security: Ensure unique machine ID and fresh SSH host keys on first boot
truncate -s 0 "${ROOTFS_DIR}/etc/machine-id" 2>/dev/null || true
rm -f "${ROOTFS_DIR}"/etc/ssh/ssh_host_* 2>/dev/null || true

echo "Creating SquashFS filesystem for ISO (zstd level 15)..."
mksquashfs "$ROOTFS_DIR" "${ISO_STAGING}/live/filesystem.squashfs" -comp zstd -Xcompression-level 15 -b 1M

# Locate or copy ARM64 kernel and initramfs
if [ -f "${ROOTFS_DIR}/boot/Image" ]; then
    cp "${ROOTFS_DIR}/boot/Image" "${ISO_STAGING}/live/vmlinuz"
elif [ -f "${ROOTFS_DIR}/boot/vmlinuz-linux" ]; then
    cp "${ROOTFS_DIR}/boot/vmlinuz-linux" "${ISO_STAGING}/live/vmlinuz"
elif [ -f "${ROOTFS_DIR}/boot/vmlinuz-linux-aarch64" ]; then
    cp "${ROOTFS_DIR}/boot/vmlinuz-linux-aarch64" "${ISO_STAGING}/live/vmlinuz"
fi

if [ -f "${ROOTFS_DIR}/boot/initramfs-linux.img" ]; then
    cp "${ROOTFS_DIR}/boot/initramfs-linux.img" "${ISO_STAGING}/live/initrd.img"
elif [ -f "${ROOTFS_DIR}/boot/initramfs-linux-fallback.img" ]; then
    cp "${ROOTFS_DIR}/boot/initramfs-linux-fallback.img" "${ISO_STAGING}/live/initrd.img"
fi

# Ensure kernel and initramfs are non-empty
if [ ! -s "${ISO_STAGING}/live/vmlinuz" ]; then
    echo "CRITICAL ERROR: ARM64 kernel image (/boot/Image) missing or 0 bytes!"
    exit 1
fi
if [ ! -s "${ISO_STAGING}/live/initrd.img" ]; then
    echo "CRITICAL ERROR: ARM64 initramfs image (/boot/initramfs-linux.img) missing or 0 bytes!"
    exit 1
fi

# Create GRUB EFI configuration for ARM64 PCs & Apple Silicon
cat << 'EOF' > "${ISO_STAGING}/EFI/BOOT/grub.cfg"
set default="0"
set timeout=3

set color_normal=light-gray/black
set color_highlight=white/magenta

menuentry "Caelaris Linux ARM64 (KDE Plasma 6 - Default)" --class caelaris --class gnu-linux {
    linux /live/vmlinuz archisobasedir=live archisolabel=CAELARIS_ARM64_PC boot=live quiet loglevel=3 rd.udev.log_level=3 systemd.show_status=0 splash session=plasma
    initrd /live/initrd.img
}

menuentry "Caelaris Linux ARM64 (GNOME Desktop)" --class caelaris --class gnu-linux {
    linux /live/vmlinuz archisobasedir=live archisolabel=CAELARIS_ARM64_PC boot=live quiet loglevel=3 rd.udev.log_level=3 systemd.show_status=0 splash session=gnome
    initrd /live/initrd.img
}

menuentry "Caelaris Linux ARM64 (Safe Graphics / Fallback)" --class caelaris --class gnu-linux {
    linux /live/vmlinuz archisobasedir=live archisolabel=CAELARIS_ARM64_PC boot=live nomodeset
    initrd /live/initrd.img
}
EOF

# Ensure BOOTAA64.EFI exists in ISO_STAGING
if [ -f "${ROOTFS_DIR}/boot/BOOTAA64.EFI" ]; then
    cp "${ROOTFS_DIR}/boot/BOOTAA64.EFI" "${ISO_STAGING}/EFI/BOOT/BOOTAA64.EFI"
fi

if [ ! -f "${ISO_STAGING}/EFI/BOOT/BOOTAA64.EFI" ] && which grub-mkstandalone >/dev/null 2>&1; then
    echo "Generating BOOTAA64.EFI via host grub-mkstandalone..."
    grub-mkstandalone \
        --format=arm64-efi \
        -O arm64-efi \
        --output="${ISO_STAGING}/EFI/BOOT/BOOTAA64.EFI" \
        --locales="" \
        --fonts="" \
        "boot/grub/grub.cfg=${ISO_STAGING}/EFI/BOOT/grub.cfg" 2>/dev/null || true
fi

# Create FAT32 EFI boot partition image (with BOOTAA64.EFI and grub.cfg)
truncate -s 64M "${ISO_STAGING}/efi.img"
mkfs.vfat -F 32 -n "EFI" "${ISO_STAGING}/efi.img"
mmd -i "${ISO_STAGING}/efi.img" ::EFI ::EFI/BOOT || true
if [ -f "${ISO_STAGING}/EFI/BOOT/BOOTAA64.EFI" ]; then
    mcopy -i "${ISO_STAGING}/efi.img" "${ISO_STAGING}/EFI/BOOT/BOOTAA64.EFI" ::EFI/BOOT/ || true
fi
mcopy -i "${ISO_STAGING}/efi.img" "${ISO_STAGING}/EFI/BOOT/grub.cfg" ::EFI/BOOT/ || true

# Generate Hybrid GPT/UEFI ISO
echo "Building final hybrid UEFI ISO via xorriso..."
xorriso -as mkisofs \
    -r -V "CAELARIS_ARM64_PC" \
    -J -joliet-long \
    -append_partition 2 0xef "${ISO_STAGING}/efi.img" \
    -appended_part_as_gpt \
    -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
    -o "${OUT_DIR}/${IMAGE_NAME}.iso" \
    "$ISO_STAGING" || {
        xorriso -as mkisofs -r -V "CAELARIS_ARM64_PC" -o "${OUT_DIR}/${IMAGE_NAME}.iso" "$ISO_STAGING"
    }

cp "${OUT_DIR}/${IMAGE_NAME}.iso" "${OUT_DIR}/caelaris-arm64-pc.iso"
rm -rf "$ISO_STAGING"

# 5. Generate Checksums
echo "[5/5] Generating SHA256 cryptographic checksums..."
cd "$OUT_DIR"
sha256sum "${IMAGE_NAME}.iso" > "${IMAGE_NAME}.iso.sha256"
sha256sum "caelaris-arm64-pc.iso" > "caelaris-arm64-pc.iso.sha256"

echo "=========================================================="
echo " Caelaris Linux ARM64 PC ISO build completed!             "
echo " Image: ${OUT_DIR}/${IMAGE_NAME}.iso                      "
ls -lh "${OUT_DIR}"
echo "=========================================================="
