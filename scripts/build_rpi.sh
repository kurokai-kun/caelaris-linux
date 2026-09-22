#!/usr/bin/env bash
set -euo pipefail

EDITION="${1:-kde}"
FORMAT="${2:-both}" # both, iso, img
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
WORK_DIR="/tmp/caelaris-rpi-work"
OUT_DIR="${ROOT_DIR}/out-rpi"
ROOTFS_DIR="${WORK_DIR}/rootfs"
BUILD_DATE=$(date +%Y.%m.%d)
IMAGE_NAME="caelaris-rpi-arm64-${BUILD_DATE}"

echo "=========================================================="
echo " Building Caelaris Linux ARM64 (Raspberry Pi Edition)     "
echo " Target: Raspberry Pi 5, 4 & 3B+ | Format: ${FORMAT}      "
echo "=========================================================="

mkdir -p "$WORK_DIR" "$OUT_DIR" "$ROOTFS_DIR"

# 1. Download Arch Linux ARM Raspberry Pi 64-bit rootfs baseline
ARCH_ARM_TAR="ArchLinuxARM-rpi-aarch64-latest.tar.gz"
DOWNLOAD_URL="http://os.archlinuxarm.org/os/${ARCH_ARM_TAR}"

if [ ! -f "${WORK_DIR}/${ARCH_ARM_TAR}" ]; then
    echo "[1/6] Downloading Arch Linux ARM aarch64 baseline..."
    curl -fL -o "${WORK_DIR}/${ARCH_ARM_TAR}" "$DOWNLOAD_URL" || {
        echo "Primary mirror failed, trying fallback mirror..."
        curl -fL -o "${WORK_DIR}/${ARCH_ARM_TAR}" "http://de3.mirror.archlinuxarm.org/os/${ARCH_ARM_TAR}"
    }
else
    echo "[1/6] Using cached Arch Linux ARM rootfs..."
fi

# 2. Extract rootfs
echo "[2/6] Extracting ARM64 root filesystem..."
bsdtar -xpf "${WORK_DIR}/${ARCH_ARM_TAR}" -C "$ROOTFS_DIR"

# 3. Apply Caelaris Linux Customizations
echo "[3/6] Applying Caelaris Linux tuning and configurations..."

# Hostname & branding
echo "caelaris-rpi" > "${ROOTFS_DIR}/etc/hostname"

cat << 'EOF' > "${ROOTFS_DIR}/etc/os-release"
NAME="Caelaris Linux ARM64"
PRETTY_NAME="Caelaris Linux ARM64 (Raspberry Pi Edition)"
ID=caelaris
ID_LIKE=archarm
BUILD_ID=rolling
ANSI_COLOR="38;2;56;189;248"
HOME_URL="https://github.com/kurokai-kun/caelaris-linux"
DOCUMENTATION_URL="https://github.com/kurokai-kun/caelaris-linux"
SUPPORT_URL="https://github.com/kurokai-kun/caelaris-linux/issues"
LOGO=caelaris
EOF

# Overlay gaming and low-latency sysctl
if [ -f "${ROOT_DIR}/shared/airootfs/etc/sysctl.d/99-caelaris-gaming.conf" ]; then
    mkdir -p "${ROOTFS_DIR}/etc/sysctl.d"
    cp "${ROOT_DIR}/shared/airootfs/etc/sysctl.d/99-caelaris-gaming.conf" "${ROOTFS_DIR}/etc/sysctl.d/"
fi

# Overlay ZRAM compression config
if [ -f "${ROOT_DIR}/shared/airootfs/etc/systemd/zram-generator.conf" ]; then
    mkdir -p "${ROOTFS_DIR}/etc/systemd"
    cp "${ROOT_DIR}/shared/airootfs/etc/systemd/zram-generator.conf" "${ROOTFS_DIR}/etc/systemd/"
fi

# Configure Raspberry Pi config.txt with VideoCore hardware acceleration
cat << 'EOF' >> "${ROOTFS_DIR}/boot/config.txt"
# Caelaris Linux - Universal Raspberry Pi Hardware Acceleration

# --- Universal Settings ---
[all]
arm_64bit=1
disable_overscan=1
hdmi_force_hotplug=1
dtparam=audio=on

# --- Raspberry Pi 3 / 3B+ (1GB RAM Optimization) ---
[pi3]
dtoverlay=vc4-kms-v3d,cma-128
gpu_mem=64
arm_freq=1400

# --- Raspberry Pi 4 / 400 ---
[pi4]
dtoverlay=vc4-kms-v3d
gpu_mem=128

# --- Raspberry Pi 5 ---
[pi5]
dtoverlay=vc4-kms-v3d
dtoverlay=rp1
gpu_mem=256
EOF

# Configure default user 'caelaris' in sysusers and sudoers
mkdir -p "${ROOTFS_DIR}/etc/sudoers.d"
echo "%wheel ALL=(ALL:ALL) ALL" > "${ROOTFS_DIR}/etc/sudoers.d/wheel"
chmod 440 "${ROOTFS_DIR}/etc/sudoers.d/wheel"

# Enable essential systemd services
mkdir -p "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants"
ln -sf /usr/lib/systemd/system/systemd-resolved.service "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/" || true

# 4. Generate Flashable Disk Image (.img.xz)
if [[ "$FORMAT" == "both" || "$FORMAT" == "img" ]]; then
    echo "[4/6] Creating 5GB raw Raspberry Pi disk image..."
    RAW_IMG="${WORK_DIR}/${IMAGE_NAME}.img"
    truncate -s 5G "$RAW_IMG"

    parted --script "$RAW_IMG" \
        mklabel msdos \
        mkpart primary fat32 1MiB 512MiB \
        set 1 boot on \
        mkpart primary ext4 512MiB 100%

    LOOP_DEV=$(losetup --find --show --partscan "$RAW_IMG")
    
    mkfs.vfat -F 32 -n "BOOT" "${LOOP_DEV}p1"
    mkfs.ext4 -F -L "ROOT" "${LOOP_DEV}p2"

    MOUNT_DIR="/tmp/caelaris-rpi-mount"
    mkdir -p "$MOUNT_DIR"
    mount "${LOOP_DEV}p2" "$MOUNT_DIR"
    mkdir -p "${MOUNT_DIR}/boot"
    mount "${LOOP_DEV}p1" "${MOUNT_DIR}/boot"

    echo "Copying files to disk image..."
    cp -a "${ROOTFS_DIR}/." "$MOUNT_DIR/"

    # Setup fstab with PARTUUID
    ROOT_PARTUUID=$(blkid -s PARTUUID -o value "${LOOP_DEV}p2" || echo "")
    BOOT_PARTUUID=$(blkid -s PARTUUID -o value "${LOOP_DEV}p1" || echo "")
    
    cat << EOF > "${MOUNT_DIR}/etc/fstab"
PARTUUID=${BOOT_PARTUUID}  /boot  vfat  defaults  0  2
PARTUUID=${ROOT_PARTUUID}  /      ext4  defaults,noatime  0  1
EOF

    # Configure cmdline.txt
    echo "console=serial0,115200 console=tty1 root=PARTUUID=${ROOT_PARTUUID} rootfstype=ext4 fsck.repair=yes rootwait quiet loglevel=3" > "${MOUNT_DIR}/boot/cmdline.txt"

    umount "${MOUNT_DIR}/boot"
    umount "$MOUNT_DIR"
    losetup -d "$LOOP_DEV"

    echo "Compressing raw disk image with XZ..."
    xz -T0 -9 -c "$RAW_IMG" > "${OUT_DIR}/${IMAGE_NAME}.img.xz"
    rm -f "$RAW_IMG"
    echo "Created: ${OUT_DIR}/${IMAGE_NAME}.img.xz"
fi

# 5. Generate Hybrid ARM64 ISO
if [[ "$FORMAT" == "both" || "$FORMAT" == "iso" ]]; then
    echo "[5/6] Generating ARM64 UEFI Hybrid ISO..."
    ISO_STAGING="/tmp/caelaris-arm64-iso"
    rm -rf "$ISO_STAGING"
    mkdir -p "${ISO_STAGING}/live" "${ISO_STAGING}/EFI/BOOT"

    echo "Creating SquashFS filesystem for ISO..."
    mksquashfs "$ROOTFS_DIR" "${ISO_STAGING}/live/filesystem.squashfs" -comp zstd -Xcompression-level 15 -b 1M

    # Copy ARM64 kernel and initramfs to ISO boot dir
    if [ -f "${ROOTFS_DIR}/boot/Image" ]; then
        cp "${ROOTFS_DIR}/boot/Image" "${ISO_STAGING}/live/vmlinuz"
    elif [ -f "${ROOTFS_DIR}/boot/vmlinuz-linux-rpi" ]; then
        cp "${ROOTFS_DIR}/boot/vmlinuz-linux-rpi" "${ISO_STAGING}/live/vmlinuz"
    fi

    if [ -f "${ROOTFS_DIR}/boot/initramfs-linux.img" ]; then
        cp "${ROOTFS_DIR}/boot/initramfs-linux.img" "${ISO_STAGING}/live/initrd.img"
    elif [ -f "${ROOTFS_DIR}/boot/initramfs-linux-rpi.img" ]; then
        cp "${ROOTFS_DIR}/boot/initramfs-linux-rpi.img" "${ISO_STAGING}/live/initrd.img"
    fi

    # Create GRUB EFI configuration
    cat << 'EOF' > "${ISO_STAGING}/EFI/BOOT/grub.cfg"
set default="0"
set timeout=5

menuentry "Caelaris Linux ARM64 (Live Session)" {
    linux /live/vmlinuz boot=live quiet splash
    initrd /live/initrd.img
}

menuentry "Caelaris Linux ARM64 (Safe Graphics)" {
    linux /live/vmlinuz boot=live nomodeset
    initrd /live/initrd.img
}
EOF

    # Create FAT32 EFI boot partition image
    truncate -s 64M "${ISO_STAGING}/efi.img"
    mkfs.vfat -F 32 -n "EFI" "${ISO_STAGING}/efi.img"
    mmd -i "${ISO_STAGING}/efi.img" ::EFI ::EFI/BOOT || true
    mcopy -i "${ISO_STAGING}/efi.img" "${ISO_STAGING}/EFI/BOOT/grub.cfg" ::EFI/BOOT/ || true

    xorriso -as mkisofs \
        -r -V "CAELARIS_ARM64" \
        -J -joliet-long \
        -append_partition 2 0xef "${ISO_STAGING}/efi.img" \
        -appended_part_as_gpt \
        -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
        -o "${OUT_DIR}/${IMAGE_NAME}.iso" \
        "$ISO_STAGING" || {
            xorriso -as mkisofs -r -V "CAELARIS_ARM64" -o "${OUT_DIR}/${IMAGE_NAME}.iso" "$ISO_STAGING"
        }

    rm -rf "$ISO_STAGING"
    echo "Created: ${OUT_DIR}/${IMAGE_NAME}.iso"
fi

# 6. Generate Checksums
echo "[6/6] Generating SHA256 checksums..."
cd "$OUT_DIR"
for f in ${IMAGE_NAME}*; do
    if [ -f "$f" ]; then
        sha256sum "$f" > "${f}.sha256"
    fi
done

echo "=========================================================="
echo " Caelaris Linux ARM64 build completed successfully!       "
ls -lh "${OUT_DIR}"
echo "=========================================================="
