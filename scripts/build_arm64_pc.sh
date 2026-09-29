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
        plasma-workspace
        plasma-desktop
        kwin
        plasma-x11-session
        plasma-nm
        plasma-pa
        powerdevil
        kscreen
        systemsettings
        polkit-kde-agent
        xdg-desktop-portal-kde
        layer-shell-qt
        qt6-declarative
        qt6-svg
        sddm
        sddm-kcm
        wayland
        qt6-wayland
        xorg-server
        xorg-xinit
        xorg-xwayland
        konsole
        dolphin
        breeze
        breeze-gtk
        breeze-icons
        gnome-shell
        gnome-session
        gnome-settings-daemon
        gnome-control-center
        mutter
        ptyxis
        nautilus
        xdg-desktop-portal-gnome
        accountsservice
        spice-vdagent
        mesa
        vulkan-freedreno
        vulkan-panfrost
        linux-firmware
        pipewire
        pipewire-alsa
        pipewire-pulse
        wireplumber
        networkmanager
        network-manager-applet
        python
        python-pyqt6
        python-psutil
        parted
        gptfdisk
        dosfstools
        e2fsprogs
        btrfs-progs
        arch-install-scripts
        archinstall
        rsync
        squashfs-tools
        grub
        efibootmgr
        sudo
        bash
        xorg-xhost
        kwrite
        hicolor-icon-theme
        adwaita-icon-theme
        hyprland
        xdg-desktop-portal-hyprland
        waybar
        rofi-wayland
        swaybg
    )

    echo "Installing live preview desktop & installer packages..."
    # Tier 1: Core System, Kernel, GUI Installer, and Bootloader essentials
    chroot "$ROOTFS_DIR" /bin/bash -c "pacman -S --needed --noconfirm --overwrite='*' linux-aarch64 mkinitcpio mkinitcpio-archiso python python-pyqt6 sudo bash networkmanager sddm mesa grub efibootmgr parted gptfdisk dosfstools e2fsprogs btrfs-progs rsync squashfs-tools noto-fonts xorg-xhost hicolor-icon-theme" || {
        echo "Retrying Tier 1 package installation..."
        sleep 3
        chroot "$ROOTFS_DIR" /bin/bash -c "pacman -S --needed --noconfirm --overwrite='*' linux-aarch64 mkinitcpio mkinitcpio-archiso python python-pyqt6 sudo bash networkmanager sddm mesa grub efibootmgr parted gptfdisk dosfstools e2fsprogs btrfs-progs rsync squashfs-tools noto-fonts xorg-xhost hicolor-icon-theme"
    }

    # Tier 2: Complete Desktop Preview Suite & Graphics
    chroot "$ROOTFS_DIR" /bin/bash -c "pacman -S --needed --noconfirm --overwrite='*' pipewire-jack qt6-multimedia-ffmpeg ${DESKTOP_PKGS[*]}" || {
        echo "Retrying Tier 2 individual package installation..."
        chroot "$ROOTFS_DIR" /bin/bash -c "for pkg in ${DESKTOP_PKGS[*]}; do pacman -S --needed --noconfirm --overwrite='*' \"\$pkg\" 2>/dev/null || true; done"
    }

    # Verify installation of core desktop and installer packages
    if [ ! -f "${ROOTFS_DIR}/usr/bin/python" ] || [ ! -f "${ROOTFS_DIR}/usr/bin/sddm" ]; then
        echo "CRITICAL ERROR: Desktop packages failed to install inside ARM64 rootfs."
        exit 1
    fi

    # Configure mkinitcpio for live ISO booting
    cat << 'EOF' > "${ROOTFS_DIR}/etc/mkinitcpio.conf"
MODULES=(loop squashfs isofs overlay xz)
BINARIES=()
FILES=()
HOOKS=(base udev archiso archiso_loop_mnt block filesystems keyboard)
COMPRESSION="xz"
EOF
    echo "Generating bootable live initramfs..."
    chroot "$ROOTFS_DIR" /bin/bash -c "mkinitcpio -P" || true

    # Completely purge alarm user and ensure single liveuser exists with UID 1000
    chroot "$ROOTFS_DIR" /bin/bash -c "
        userdel -r -f alarm 2>/dev/null || true
        rm -rf /home/alarm /var/lib/AccountsService/users/alarm 2>/dev/null || true
        if ! id -u liveuser >/dev/null 2>&1; then
            useradd -u 1000 -m -c 'Caelaris Live' -g users -G wheel,video,audio,optical,storage,input,power -s /bin/bash liveuser
        fi
        passwd -d liveuser 2>/dev/null || true
        passwd -d root 2>/dev/null || true
    " || true
    rm -rf "${ROOTFS_DIR}/home/alarm"
    rm -f "${ROOTFS_DIR}/var/lib/AccountsService/users/alarm"

    # Generate standalone BOOTAA64.EFI using ARM64 GRUB modules
    echo "Compiling standalone ARM64 EFI bootloader (BOOTAA64.EFI)..."
    cat << 'GRUB_EARLY' > "${ROOTFS_DIR}/tmp/early_grub.cfg"
insmod part_gpt
insmod part_msdos
insmod iso9660
insmod fat
insmod ext2
insmod btrfs
insmod search
insmod search_fs_file
insmod search_label
insmod test
insmod echo
insmod normal

if [ -n "$cmdpath" ]; then
    set prefix=$cmdpath
    if [ -f $prefix/grub.cfg ]; then
        configfile $prefix/grub.cfg
    fi
fi

search --no-floppy --set=root --label CAELARIS_ARM64_PC
if [ -z "$root" ]; then
    search --no-floppy --set=root --file /EFI/BOOT/grub.cfg
fi
if [ -z "$root" ]; then
    search --no-floppy --set=root --file /live/vmlinuz
fi
if [ -z "$root" ]; then
    search --no-floppy --set=root --file /boot/grub/grub.cfg
fi

if [ -f ($root)/EFI/BOOT/grub.cfg ]; then
    set prefix=($root)/EFI/BOOT
    configfile $prefix/grub.cfg
elif [ -f ($root)/boot/grub/grub.cfg ]; then
    set prefix=($root)/boot/grub
    configfile $prefix/grub.cfg
fi
GRUB_EARLY

    chroot "$ROOTFS_DIR" /bin/bash -c "
        if which grub-mkstandalone >/dev/null 2>&1; then
            grub-mkstandalone \
                --format=arm64-efi \
                -O arm64-efi \
                --output=/boot/BOOTAA64.EFI \
                --locales='' \
                --fonts='' \
                --modules='part_gpt part_msdos iso9660 fat ext2 btrfs search search_fs_file search_fs_uuid search_label test echo normal linux all_video gfxterm font loadenv configfile' \
                'boot/grub/grub.cfg=/tmp/early_grub.cfg' 2>/dev/null || {
                grub-mkstandalone \
                    --format=arm64-efi \
                    -O arm64-efi \
                    --output=/boot/BOOTAA64.EFI \
                    --locales='' \
                    --fonts='' \
                    'boot/grub/grub.cfg=/tmp/early_grub.cfg' 2>/dev/null || true
            }
        fi
    " || true
    rm -f "${ROOTFS_DIR}/tmp/early_grub.cfg"

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

# Configure SDDM display manager with modern theme and autologin to live user
mkdir -p "${ROOTFS_DIR}/etc/sddm.conf.d"
cat << 'EOF' > "${ROOTFS_DIR}/etc/sddm.conf.d/10-caelaris.conf"
[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot

[Theme]
Current=breeze
CursorTheme=breeze_cursors
EOF

SESSION_NAME="plasma"
if [ "$EDITION" = "gnome" ]; then
    SESSION_NAME="gnome"
fi

cat << EOF > "${ROOTFS_DIR}/etc/sddm.conf.d/autologin.conf"
[Autologin]
User=liveuser
Session=${SESSION_NAME}
Relogin=false
EOF

# Configure PAM to ensure passwordless autologin and permit liveuser
mkdir -p "${ROOTFS_DIR}/etc/pam.d"
cat << 'EOF' > "${ROOTFS_DIR}/etc/pam.d/sddm-autologin"
#%PAM-1.0
auth        sufficient  pam_permit.so
auth        required    pam_env.so
account     include     system-login
password    include     system-login
session     include     system-login
EOF

cat << 'EOF' > "${ROOTFS_DIR}/etc/pam.d/sddm"
#%PAM-1.0
auth        sufficient  pam_permit.so
auth        include     system-login
account     include     system-login
password    include     system-login
session     include     system-login
EOF

# Configure AccountsService
mkdir -p "${ROOTFS_DIR}/var/lib/AccountsService/users"
cat << EOF > "${ROOTFS_DIR}/var/lib/AccountsService/users/liveuser"
[User]
Language=en_US.UTF-8
Session=${SESSION_NAME}
XSession=${SESSION_NAME}
SystemAccount=false
RealName=Caelaris Live
Icon=/usr/share/pixmaps/caelaris-logo.png
EOF
chmod 0644 "${ROOTFS_DIR}/var/lib/AccountsService/users/liveuser"
rm -f "${ROOTFS_DIR}/var/lib/AccountsService/users/alarm" 2>/dev/null || true

# Configure liveuser with wheel privileges and GUI environment preservation
mkdir -p "${ROOTFS_DIR}/etc/sudoers.d"
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > "${ROOTFS_DIR}/etc/sudoers.d/wheel"
echo "liveuser ALL=(ALL:ALL) NOPASSWD: ALL" > "${ROOTFS_DIR}/etc/sudoers.d/liveuser"
cat << 'EOF' > "${ROOTFS_DIR}/etc/sudoers.d/99-caelaris-env"
Defaults env_keep += "DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR XAUTHORITY PULSE_SERVER"
EOF
chmod 440 "${ROOTFS_DIR}/etc/sudoers.d/wheel" "${ROOTFS_DIR}/etc/sudoers.d/liveuser" "${ROOTFS_DIR}/etc/sudoers.d/99-caelaris-env"

# Configure dynamic session selection service based on bootloader session= cmdline parameter
mkdir -p "${ROOTFS_DIR}/usr/lib/systemd/system"
cat << 'EOF' > "${ROOTFS_DIR}/usr/lib/systemd/system/caelaris-session-select.service"
[Unit]
Description=Select Caelaris Live Desktop Session from Boot Argument
Before=sddm.service display-manager.service
ConditionPathExists=/etc/sddm.conf.d/autologin.conf

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'if grep -qE "session=caelestia|desktop=caelestia|session=hyprland|desktop=hyprland" /proc/cmdline; then sed -i "s/Session=.*/Session=hyprland/" /etc/sddm.conf.d/autologin.conf; elif grep -qw "session=gnome" /proc/cmdline; then sed -i "s/Session=.*/Session=gnome/" /etc/sddm.conf.d/autologin.conf; else sed -i "s/Session=.*/Session=plasma/" /etc/sddm.conf.d/autologin.conf; fi'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable system services and configure default graphical target
mkdir -p "${ROOTFS_DIR}/etc/systemd/system/graphical.target.wants"
mkdir -p "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants"

ln -sf /usr/lib/systemd/system/graphical.target "${ROOTFS_DIR}/etc/systemd/system/default.target"

# Enable live setup service before SDDM
ln -sf /etc/systemd/system/caelaris-live-setup.service "${ROOTFS_DIR}/etc/systemd/system/graphical.target.wants/caelaris-live-setup.service"
ln -sf /etc/systemd/system/caelaris-live-setup.service "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/caelaris-live-setup.service"

# Enable SDDM display manager
ln -sf /usr/lib/systemd/system/sddm.service "${ROOTFS_DIR}/etc/systemd/system/display-manager.service"
ln -sf /usr/lib/systemd/system/sddm.service "${ROOTFS_DIR}/etc/systemd/system/graphical.target.wants/sddm.service"
ln -sf /usr/lib/systemd/system/sddm.service "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/sddm.service"

# Enable essential background services
ln -sf /usr/lib/systemd/system/systemd-resolved.service "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/" || true
ln -sf /usr/lib/systemd/system/NetworkManager.service "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/" || true
ln -sf /usr/lib/systemd/system/spice-vdagentd.service "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/" || true
ln -sf /usr/lib/systemd/system/caelaris-session-select.service "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/" || true

# Prevent getty@tty1 from seizing console and causing display blinking
ln -sf /dev/null "${ROOTFS_DIR}/etc/systemd/system/getty@tty1.service" 2>/dev/null || true
rm -rf "${ROOTFS_DIR}/etc/systemd/system/getty@tty1.service.d" 2>/dev/null || true

# Mask plymouth services so systemd never hangs waiting on non-existent splash daemon
for unit in plymouth-start.service plymouth-quit.service plymouth-quit-wait.service plymouth-reboot.service plymouth-poweroff.service plymouth-halt.service plymouth-kexec.service plymouth-switch-root.service; do
    ln -sf /dev/null "${ROOTFS_DIR}/etc/systemd/system/${unit}" 2>/dev/null || true
done

# Place and make executable "Install Caelaris Linux" desktop launcher for liveuser
mkdir -p "${ROOTFS_DIR}/home/liveuser/Desktop"
if [ -f "${ROOTFS_DIR}/etc/skel/Desktop/install-caelaris.desktop" ]; then
    cp -f "${ROOTFS_DIR}/etc/skel/Desktop/install-caelaris.desktop" "${ROOTFS_DIR}/home/liveuser/Desktop/"
fi
chmod +x "${ROOTFS_DIR}/home/liveuser/Desktop/"*.desktop 2>/dev/null || true
chmod +x "${ROOTFS_DIR}/usr/bin/caelaris-"* 2>/dev/null || true
chown -R 1000:100 "${ROOTFS_DIR}/home/liveuser" 2>/dev/null || true

# Update Hyprland wayland session entry to Caelestia Shell (Hyprland) and clean up duplicates
if [ -f "${ROOTFS_DIR}/usr/share/wayland-sessions/hyprland.desktop" ]; then
    sed -i 's/^Name=.*/Name=Caelestia Shell (Hyprland)/' "${ROOTFS_DIR}/usr/share/wayland-sessions/hyprland.desktop"
    sed -i 's|^Exec=.*|Exec=/usr/bin/caelestia-session|' "${ROOTFS_DIR}/usr/share/wayland-sessions/hyprland.desktop"
    sed -i 's|^TryExec=.*|TryExec=/usr/bin/caelestia-session|' "${ROOTFS_DIR}/usr/share/wayland-sessions/hyprland.desktop"
fi
rm -f "${ROOTFS_DIR}/usr/share/wayland-sessions/caelestia.desktop" 2>/dev/null || true

# Isolate KDE and GNOME application menus to avoid clutter in both environments
for kapp in org.kde.dolphin dolphin org.kde.konsole konsole org.kde.kate kate \
             org.kde.kwrite kwrite org.kde.ark ark org.kde.spectacle spectacle \
             org.kde.gwenview gwenview org.kde.kcalc kcalc \
             org.kde.plasma-systemmonitor plasma-systemmonitor \
             systemsettings kinfocenter org.kde.discover org.kde.drkonqi \
             org.kde.plasma.vault org.kde.kfind org.kde.plasma.emojier; do
    for dir in "${ROOTFS_DIR}/usr/share/applications" "${ROOTFS_DIR}/usr/local/share/applications"; do
        df="${dir}/${kapp}.desktop"
        if [ -f "$df" ]; then
            sed -i '/^NotShowIn=/d; /^OnlyShowIn=/d' "$df" 2>/dev/null || true
            echo "NotShowIn=GNOME;" >> "$df"
        fi
    done
done

for gapp in org.gnome.Nautilus nautilus org.gnome.Ptyxis ptyxis \
             org.gnome.TextEditor gnome-text-editor org.gnome.Calculator gnome-calculator \
             org.gnome.SystemMonitor gnome-system-monitor org.gnome.DiskUtility gnome-disk-utility \
             gnome-control-center org.gnome.Settings org.gnome.Characters org.gnome.font-viewer \
             org.gnome.Logs org.gnome.Software org.gnome.Tour org.gnome.Console org.gnome.Terminal; do
    for dir in "${ROOTFS_DIR}/usr/share/applications" "${ROOTFS_DIR}/usr/local/share/applications"; do
        df="${dir}/${gapp}.desktop"
        if [ -f "$df" ]; then
            sed -i '/^NotShowIn=/d; /^OnlyShowIn=/d' "$df" 2>/dev/null || true
            echo "NotShowIn=KDE;" >> "$df"
        fi
    done
done

# Deploy Caelaris branding and high-resolution icons across all theme directories
if [ -f "${ROOT_DIR}/assets/logo.png" ]; then
    echo "Deploying Caelaris logo across all icon directories..."
    mkdir -p "${ROOTFS_DIR}/usr/share/pixmaps"
    cp -f "${ROOT_DIR}/assets/logo.png" "${ROOTFS_DIR}/usr/share/pixmaps/caelaris-logo.png"
    cp -f "${ROOT_DIR}/assets/logo.png" "${ROOTFS_DIR}/usr/share/pixmaps/distributor-logo.png"
    cp -f "${ROOT_DIR}/assets/logo.png" "${ROOTFS_DIR}/usr/share/pixmaps/system-software-install.png"

    for sz in 16 22 24 32 48 64 128 256; do
        mkdir -p "${ROOTFS_DIR}/usr/share/icons/hicolor/${sz}x${sz}/apps"
        cp -f "${ROOT_DIR}/assets/logo.png" "${ROOTFS_DIR}/usr/share/icons/hicolor/${sz}x${sz}/apps/caelaris-logo.png"
        cp -f "${ROOT_DIR}/assets/logo.png" "${ROOTFS_DIR}/usr/share/icons/hicolor/${sz}x${sz}/apps/distributor-logo.png"
        cp -f "${ROOT_DIR}/assets/logo.png" "${ROOTFS_DIR}/usr/share/icons/hicolor/${sz}x${sz}/apps/system-software-install.png"
        cp -f "${ROOT_DIR}/assets/logo.png" "${ROOTFS_DIR}/usr/share/icons/hicolor/${sz}x${sz}/apps/start-here-kde.png"
        cp -f "${ROOT_DIR}/assets/logo.png" "${ROOTFS_DIR}/usr/share/icons/hicolor/${sz}x${sz}/apps/start-here.png"
    done
fi

# Hide terminal text editors (vim, nvim, vi, nano) and utility clutter from GUI application launcher
for util in vim nvim vi nano avahi-discover bssh bvnc qv4l2 qvidcap lstopo cmake-gui \
            electron electron31 electron32 electron33; do
    for dir in "${ROOTFS_DIR}/usr/share/applications" "${ROOTFS_DIR}/usr/local/share/applications"; do
        df="${dir}/${util}.desktop"
        if [ -f "$df" ]; then
            sed -i '/^NoDisplay=/d' "$df" 2>/dev/null || true
            echo "NoDisplay=true" >> "$df"
        fi
    done
done
rm -f "${ROOTFS_DIR}/usr/share/applications/vim.desktop" "${ROOTFS_DIR}/usr/share/applications/nvim.desktop" 2>/dev/null || true

# Rebuild icon cache and desktop database in chroot
if which qemu-aarch64-static >/dev/null 2>&1; then
    chroot "$ROOTFS_DIR" /bin/bash -c "
        gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
        update-desktop-database /usr/share/applications 2>/dev/null || true
        kbuildsycoca6 --noincremental 2>/dev/null || true
    " 2>/dev/null || true
fi

# 4. Generate Uncompromised Full Desktop Hybrid ARM64 ISO
echo "[4/5] Generating Full ARM64 UEFI Desktop ISO..."
ISO_STAGING="${WORK_DIR}/iso-staging"
rm -rf "$ISO_STAGING"
mkdir -p "${ISO_STAGING}/live" "${ISO_STAGING}/EFI/BOOT"

# Privacy & Security: Ensure unique machine ID and fresh SSH host keys on first boot
truncate -s 0 "${ROOTFS_DIR}/etc/machine-id" 2>/dev/null || true
rm -f "${ROOTFS_DIR}"/etc/ssh/ssh_host_* 2>/dev/null || true

echo "Creating SquashFS filesystem for ISO (xz compression, 1M block size)..."
mksquashfs "$ROOTFS_DIR" "${ISO_STAGING}/live/airootfs.sfs" -comp xz -b 1M

# Archiso hook expects airootfs.sfs inside archisobasedir (e.g. /live/airootfs.sfs or /live/aarch64/airootfs.sfs)
mkdir -p "${ISO_STAGING}/live/aarch64" "${ISO_STAGING}/live/arm64"
ln -f "${ISO_STAGING}/live/airootfs.sfs" "${ISO_STAGING}/live/aarch64/airootfs.sfs"
ln -f "${ISO_STAGING}/live/airootfs.sfs" "${ISO_STAGING}/live/arm64/airootfs.sfs"
ln -f "${ISO_STAGING}/live/airootfs.sfs" "${ISO_STAGING}/live/filesystem.squashfs"

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
mkdir -p "${ISO_STAGING}/EFI/BOOT"
mkdir -p "${ISO_STAGING}/boot/grub/arm64-efi"

cat << 'EOF' > "${ISO_STAGING}/EFI/BOOT/grub.cfg"
set default="0"
set timeout=12

set color_normal=light-gray/black
set color_highlight=white/magenta

# Search and switch root to partition containing live kernel
search --no-floppy --set=root --file /live/vmlinuz
if [ -z "$root" ]; then
    search --no-floppy --set=root --label CAELARIS_ARM64_PC
fi

menuentry "Caelaris Linux" --class caelaris --class kde --class gnu-linux --class gnu --class os {
    search --no-floppy --set=root --file /live/vmlinuz
    linux /live/vmlinuz archisobasedir=live archisolabel=CAELARIS_ARM64_PC boot=live quiet loglevel=3 rd.udev.log_level=3 systemd.show_status=0 session=plasma plymouth.enable=0 modprobe.blacklist=pcspkr,snd_pcsp
    initrd /live/initrd.img
}

menuentry "Caelaris Linux (Safe Graphics / Fallback)" --class caelaris --class gnu-linux {
    search --no-floppy --set=root --file /live/vmlinuz
    linux /live/vmlinuz archisobasedir=live archisolabel=CAELARIS_ARM64_PC boot=live nomodeset quiet plymouth.enable=0 modprobe.blacklist=pcspkr,snd_pcsp
    initrd /live/initrd.img
}
EOF

# Ensure grub.cfg is available at standard search locations
cp -f "${ISO_STAGING}/EFI/BOOT/grub.cfg" "${ISO_STAGING}/boot/grub/grub.cfg"
cp -f "${ISO_STAGING}/EFI/BOOT/grub.cfg" "${ISO_STAGING}/boot/grub/arm64-efi/grub.cfg"

# Ensure BOOTAA64.EFI exists in ISO_STAGING
if [ -f "${ROOTFS_DIR}/boot/BOOTAA64.EFI" ]; then
    cp "${ROOTFS_DIR}/boot/BOOTAA64.EFI" "${ISO_STAGING}/EFI/BOOT/BOOTAA64.EFI"
fi

if [ ! -f "${ISO_STAGING}/EFI/BOOT/BOOTAA64.EFI" ] && which grub-mkstandalone >/dev/null 2>&1; then
    echo "Generating BOOTAA64.EFI via host grub-mkstandalone..."
    cat << 'GRUB_EARLY' > "${WORK_DIR}/host_early_grub.cfg"
insmod part_gpt
insmod part_msdos
insmod iso9660
insmod fat
insmod ext2
insmod btrfs
insmod search
insmod search_fs_file
insmod search_label
insmod test
insmod echo
insmod normal

if [ -n "$cmdpath" ]; then
    set prefix=$cmdpath
    if [ -f $prefix/grub.cfg ]; then
        configfile $prefix/grub.cfg
    fi
fi

search --no-floppy --set=root --label CAELARIS_ARM64_PC
if [ -z "$root" ]; then
    search --no-floppy --set=root --file /EFI/BOOT/grub.cfg
fi
if [ -z "$root" ]; then
    search --no-floppy --set=root --file /live/vmlinuz
fi
if [ -z "$root" ]; then
    search --no-floppy --set=root --file /boot/grub/grub.cfg
fi

if [ -f ($root)/EFI/BOOT/grub.cfg ]; then
    set prefix=($root)/EFI/BOOT
    configfile $prefix/grub.cfg
elif [ -f ($root)/boot/grub/grub.cfg ]; then
    set prefix=($root)/boot/grub
    configfile $prefix/grub.cfg
fi
GRUB_EARLY
    grub-mkstandalone \
        --format=arm64-efi \
        -O arm64-efi \
        --output="${ISO_STAGING}/EFI/BOOT/BOOTAA64.EFI" \
        --locales="" \
        --fonts="" \
        --modules="part_gpt part_msdos iso9660 fat ext2 btrfs search search_fs_file search_fs_uuid search_label test echo normal linux all_video gfxterm font loadenv configfile" \
        "boot/grub/grub.cfg=${WORK_DIR}/host_early_grub.cfg" 2>/dev/null || {
        grub-mkstandalone \
            --format=arm64-efi \
            -O arm64-efi \
            --output="${ISO_STAGING}/EFI/BOOT/BOOTAA64.EFI" \
            --locales="" \
            --fonts="" \
            "boot/grub/grub.cfg=${WORK_DIR}/host_early_grub.cfg" 2>/dev/null || true
    }
    rm -f "${WORK_DIR}/host_early_grub.cfg"
fi

# Create FAT32 EFI boot partition image (with BOOTAA64.EFI, grub.cfg, and live kernel/initrd fallback)
truncate -s 256M "${ISO_STAGING}/efi.img"
mkfs.vfat -F 32 -n "EFI" "${ISO_STAGING}/efi.img"
mmd -i "${ISO_STAGING}/efi.img" ::EFI ::EFI/BOOT ::boot ::boot/grub ::live || true
if [ -f "${ISO_STAGING}/EFI/BOOT/BOOTAA64.EFI" ]; then
    mcopy -i "${ISO_STAGING}/efi.img" "${ISO_STAGING}/EFI/BOOT/BOOTAA64.EFI" ::EFI/BOOT/ || true
fi
mcopy -i "${ISO_STAGING}/efi.img" "${ISO_STAGING}/EFI/BOOT/grub.cfg" ::EFI/BOOT/ || true
mcopy -i "${ISO_STAGING}/efi.img" "${ISO_STAGING}/EFI/BOOT/grub.cfg" ::boot/grub/ || true
if [ -f "${ISO_STAGING}/live/vmlinuz" ]; then
    mcopy -i "${ISO_STAGING}/efi.img" "${ISO_STAGING}/live/vmlinuz" ::live/vmlinuz || true
fi
if [ -f "${ISO_STAGING}/live/initrd.img" ]; then
    mcopy -i "${ISO_STAGING}/efi.img" "${ISO_STAGING}/live/initrd.img" ::live/initrd.img || true
fi

# Generate Hybrid GPT/UEFI ISO with El Torito for virtual CD-ROM (VMware Fusion, UTM, QEMU) and GPT for USB flash drives
echo "Building final hybrid UEFI ISO via xorriso..."
xorriso -as mkisofs \
    -r -V "CAELARIS_ARM64_PC" \
    -J -joliet-long \
    -e "efi.img" \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -append_partition 2 0xef "${ISO_STAGING}/efi.img" \
    -appended_part_as_gpt \
    -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
    -o "${OUT_DIR}/${IMAGE_NAME}.iso" \
    "$ISO_STAGING" || {
        xorriso -as mkisofs \
            -r -V "CAELARIS_ARM64_PC" \
            -e "efi.img" \
            -no-emul-boot \
            -o "${OUT_DIR}/${IMAGE_NAME}.iso" \
            "$ISO_STAGING"
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
