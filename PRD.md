# Caelaris Linux — Product Requirement Document (PRD)

**Document Version:** 1.0-Rolling  
**Status:** Approved for Release / Production  
**Target Architecture:** x86_64 (UEFI & Legacy BIOS)  
**Base Distribution:** Arch Linux Rolling Baseline  
**Author:** Caelaris Core Architecture & Engineering Team  
**Last Updated:** September 2026  

---

## 1. Executive Summary & Product Vision

### 1.1 Vision Statement
**Caelaris Linux** is engineered to eliminate the friction and compromise between bleeding-edge Linux software access and immediate, out-of-the-box desktop usability. Arch Linux provides an unmatched rolling package ecosystem, but its manual installation and unconfigured baseline create steep friction for developers, gamers, and testers. Conversely, existing turnkey distributions often introduce unwanted system bloat, unoptimized kernels, heavy background telemetry, or inflexible desktop lock-in.

Caelaris Linux delivers an ultra-responsive, modern, and gaming-optimized computing platform built upon Arch Linux. It features out-of-the-box dual graphical sessions (**KDE Plasma 6** as default and **GNOME 4x** as an alternative), instant session switching, an intuitive custom graphical installer, deep virtualization guest acceleration (VMware, VirtualBox, QEMU/SPICE), complete GPU driver stacks (AMD, Intel, NVIDIA with DRM modesetting), and pro-grade performance tuning without unnecessary bloat.

### 1.2 Core Value Proposition
- **Turnkey Live Preview & Installation:** Zero-setup live preview featuring instant 1080p display auto-resizing, pre-configured live user, and full sudo permissions.
- **Dual Desktop Flexibility:** Boot into KDE Plasma 6 or GNOME directly from the bootloader, switch seamlessly during live preview, and select your preferred desktop at every SDDM login post-installation.
- **Custom Native Graphical Installer:** A dedicated Python/PyQt6 installer (`caelaris-installer-gui`) supporting automated Btrfs subvolume partitioning, ext4, UEFI/BIOS GRUB deployment, hardware driver enablement, and pristine post-install system sanitization.
- **Pro-Grade Gaming Performance:** Pre-configured kernel sysctl tuning (`vm.max_map_count=2147483642`, `vm.swappiness=10`, Google BBR TCP congestion, CAKE packet scheduling), PipeWire low-latency audio, GameMode, MangoHud, Steam, and 32-bit Vulkan drivers.
- **Universal Hardware & Hypervisor Integration:** Automatic detection and service configuration for physical GPUs (AMD, Intel, NVIDIA proprietary) and hypervisors (`open-vm-tools`, `vboxservice`, `spice-vdagentd`, `qemu-guest-agent`).
- **Clean Boot & Single User Profile:** Silent, uncluttered bootloader entry labeled strictly **`Caelaris Linux`** booting directly to the graphical login screen with zero scrolling terminal clutter, guaranteeing that only the user-created account exists on the target disk.

---

## 2. Target Personas & Success Metrics

### 2.1 Target User Personas

| User Persona | Key Needs & Pain Points | How Caelaris Linux Solves It |
| :--- | :--- | :--- |
| **The Linux Gamer** | Demands maximum FPS, zero frame-time stutter, seamless Steam/Proton/Wine compatibility, and easy hardware telemetry. | Pre-configured high `max_map_count`, GameMode, MangoHud, Steam, 32-bit Vulkan drivers, and low-latency PipeWire audio stack. |
| **The Developer & Power User** | Requires bleeding-edge toolchains, rapid compilation, AUR access, and responsive terminal environments. | Bundled `yay` AUR helper, modern Zsh/Bash configurations with autosuggestions, Fastfetch, btop, Git, and complete build toolchains. |
| **The Virtualization & OS Tester** | Evaluates Linux inside VMware Workstation, VirtualBox, or UTM/QEMU, struggling with display resolution and clipboard failures. | Pre-activated `open-vm-tools`, `vboxservice`, `spice-vdagentd`, and dynamic userspace geometry auto-resizer (`caelaris-autoresize`). |
| **The Modern Desktop Enthusiast** | Wants a clean, aesthetic desktop without maintaining complex dotfiles or fighting broken desktop updates. | Pure KDE Plasma 6 (Wayland) with custom Caelaris branding, alongside GNOME 4x, switchable at will with zero profile pollution. |

### 2.2 Key Performance Indicators (KPIs) & Success Criteria

| Metric | Target SLA | Implementation Strategy |
| :--- | :--- | :--- |
| **Live Cold Boot Time** | < 5.0 seconds (NVMe SSD) | Asynchronous systemd services, removal of locking graphical splash daemons, native systemd-sysusers. |
| **Display Auto-Resize Latency** | < 1.0 second on window resize | Background daemon (`caelaris-autoresize`) monitoring DRM modes via `kscreen-doctor` and `xrandr`. |
| **Installer Success Rate** | > 99.5% completion | Python/PyQt6 automated partitioning, reliable unsquashfs/rsync extraction, chroot key generation, and bulletproof GRUB fallback. |
| **Post-Install Profile Purity** | 100% single user profile | Complete purge of temporary `liveuser`, sysusers definitions, and AccountsService artifacts during Step 6 of installation. |
| **Bootloader Cleanliness** | 1 clean entry: `Caelaris Linux` | Post-processing `grub.cfg` to strip redundant distro version tags and applying quiet kernel parameters (`quiet loglevel=3 rd.udev.log_level=3 systemd.show_status=0 vt.global_cursor_default=0`). |
| **Welcome Assistant Frequency** | Exactly 1 time per user | Local configuration flag (`~/.config/caelaris-welcome-shown`) verified before launching the GTK3 assistant. |

---

## 3. Product Architecture & File System Structure

### 3.1 Repository & Component Layout
```
caelaris-linux/
├── .github/workflows/
│   └── build.yml               # GitHub Actions CI/CD matrix & release chunking
├── shared/
│   ├── packages.common         # Unified base, gaming, media & hardware stack
│   ├── pacman.conf             # Multi-mirror package repos + Multilib enabled
│   ├── branding/               # Distro identity, os-release, logos
│   └── airootfs/               # Overlay root filesystem
│       ├── etc/default/grub    # Silent boot parameters & GRUB styling
│       ├── etc/sysctl.d/       # Pro-grade low-latency gaming & network sysctl
│       ├── etc/sysusers.d/     # Live preview systemd-sysusers provisioning
│       ├── etc/sddm.conf.d/    # Display manager autologin & theme configs
│       └── usr/bin/
│           ├── caelaris-installer-gui   # PyQt6 Graphical Installer
│           ├── caelaris-welcome         # GTK3 Welcome & Setup Assistant
│           ├── caelaris-switch-desktop  # Instant live session switcher
│           └── caelaris-autoresize      # VM display geometry listener
├── profiles/
│   └── kde/                    # Primary ISO profile (KDE Plasma 6 + GNOME)
│       ├── packages.x86_64     # Desktop environment package definitions
│       └── profiledef.sh       # Zstandard level 19 compression & file modes
└── scripts/
    ├── build.sh                # Local & container build orchestrator
    └── setup_build_env.sh      # Build host dependency bootstrapper
```

---

## 4. Detailed Functional Requirements

### 4.1 Dual Desktop Environments & Session Switcher (FR-1)
- **Default Session:** KDE Plasma 6 running on Wayland composited by KWin.
- **Alternative Session:** GNOME 4x running on Wayland composited by Mutter.
- **Session Selection:** Available on the installed system via the SDDM session selection dropdown at every login.
- **Live Preview Hot-Switching:** Users can switch between KDE and GNOME in the live environment using `caelaris-switch-desktop` without rebooting, taking less than 2 seconds.

### 4.2 Caelaris Graphical Installer (FR-2)
- **Technology:** Custom Python 3 and PyQt6 application (`caelaris-installer-gui`) running with root privileges.
- **Storage & Partitioning:**
  - Automated Btrfs setup with standard subvolume layout (`@` for root, `@home` for home directories, `@cache`, and `@snapshots`).
  - Automated Ext4 setup as an alternative for legacy or simple storage environments.
  - Dedicated EFI System Partition (ESP) formatted as FAT32, mounted at `/boot/efi`.
- **System Extraction:** Direct extraction of compressed `airootfs.sfs` via `unsquashfs -f -d /mnt` with fallback to `rsync -aAXv`.
- **Kernel & Microcode Deployment:** Automatic copying and validation of `vmlinuz-linux` and CPU microcode packages (`intel-ucode.img`, `amd-ucode.img`) to the target `/boot`.
- **Hardware & Driver Provisioning:**
  - Automatic hardware detection via `lspci`.
  - Automatic configuration of NVIDIA DRM modesetting (`options nvidia-drm modeset=1` in `/etc/modprobe.d/nvidia.conf`) when NVIDIA hardware is present.
  - Automatic enablement of guest integration daemons (`vmtoolsd`, `vmware-vmblock-fuse`, `vboxservice`, `spice-vdagentd`, `qemu-guest-agent`).
- **Profile Sanitization:**
  - User creation with designated password, real name, and full sudo permissions.
  - Complete deletion of `liveuser` (`userdel -r -f liveuser`).
  - Purging of `/etc/sysusers.d/caelaris-liveuser.conf`, `/var/lib/AccountsService/users/liveuser`, `/home/liveuser`, and live sudoers rules.
  - Automatic removal of `install-caelaris.desktop` from the installed user's Desktop and `/etc/skel/Desktop`.

### 4.3 Silent & Clean Bootloader (FR-3)
- **GRUB Bootloader Configuration:**
  - Single primary boot option labeled strictly **`Caelaris Linux`**.
  - Secondary fallback entry labeled **`Caelaris Linux (Recovery Mode)`**.
  - UEFI NVRAM installation with universal `--removable` fallback (`EFI/BOOT/BOOTX64.EFI`) ensuring instant boot on VMware, VirtualBox, and UEFI PCs.
  - Silent boot flags: `quiet loglevel=3 rd.udev.log_level=3 systemd.show_status=0 vt.global_cursor_default=0 video=1920x1080`.

### 4.4 Pro-Grade Performance & Gaming Stack (FR-4)
- **Sysctl Kernel Parameterization (`/etc/sysctl.d/99-caelaris-gaming.conf`):**
  - `vm.max_map_count = 2147483642` (ensures smooth operation for Star Citizen, Hogwarts Legacy, Proton games).
  - `vm.swappiness = 10` (keeps game assets in RAM, minimizing disk I/O latency).
  - `net.core.default_qdisc = cake` (eliminates bufferbloat and latency spikes).
  - `net.ipv4.tcp_congestion_control = bbr` (Google BBR for low-latency network streaming).
- **Gaming Software Ecosystem:** Bundled Steam client, GameMode (`gamemoded`), MangoHud overlay (64-bit and 32-bit), VKD3D DirectX 12 translation layer, and complete 32-bit multilib graphics drivers.

### 4.5 Universal Virtualization Support (FR-5)
- **VMware Workstation / Fusion:** Pre-configured `open-vm-tools`, `xf86-video-vmware`, and `vmware-vmblock-fuse`.
- **VirtualBox:** Pre-configured `virtualbox-guest-utils` (`vboxservice`).
- **UTM / QEMU / KVM:** Bundled `spice-vdagentd` and `qemu-guest-agent`.
- **Dynamic Display Geometry:** `caelaris-autoresize` daemon monitors window size adjustments and matches host resolutions in under 1 second.

### 4.6 First-Run Caelaris Welcome Assistant (FR-6)
- **Technology:** GTK3 application (`caelaris-welcome`) providing 1-click system configuration shortcuts.
- **Session Detection:**
  - Live Preview mode: Prompts user to test hardware or launch the Graphical Installer.
  - Installed mode: Displays welcome message, system update tools, gaming launcher, and driver utilities.
- **One-Time Policy:** Writes `~/.config/caelaris-welcome-shown` on initial display, automatically closing on future boots in both KDE and GNOME.

---

## 5. Non-Functional Requirements & Security

### 5.1 Reliability & System Resilience
- **Fail-Safe Bootloader Generation:** If standard `grub-mkconfig` fails to detect the installed kernel, `caelaris-installer-gui` automatically injects a verified, UUID-mapped fallback boot block into `/mnt/boot/grub/grub.cfg`.
- **Initramfs Integrity:** Clean generation of `/etc/mkinitcpio.conf` without live-media dependencies, building both default and fallback rescue images during installation.

### 5.2 Security & Permissions
- **Separation of Privileges:** Live environment provides non-interactive sudo (`NOPASSWD`) for testing convenience, whereas the installed system strictly enforces password-protected wheel group authorization (`%wheel ALL=(ALL:ALL) ALL`).
- **Desktop Security Validation:** Desktop shortcuts explicitly tagged with trusted execution flags (`metadata::trusted true`) to avoid security confirmation dialogs.

---

## 6. Release Engineering & Continuous Integration

### 6.1 GitHub Actions Automation
- **Continuous Integration:** Workflow triggered on push to `main` branch.
- **Build Container:** Clean Arch Linux container (`archlinux:latest`) equipped with `archiso`, `squashfs-tools`, and required packaging tools.
- **Compression Profile:** SquashFS compressed using Zstandard level 19 (`-Xcompression-level 19`).

### 6.2 Asset Distribution & 2GB Limit Bypass
- **File Splitting:** Because GitHub Releases enforces a hard 2,147,483,648 byte limit per asset, the ISO file is automatically divided into parts under 1900 MB:
  - `caelaris-kde-*.iso.part-00`
  - `caelaris-kde-*.iso.part-01`
  - `caelaris-kde-*.iso.part-02`
- **1-Click Windows Reassembly:** Distributed alongside `combine.bat`, allowing users to double-click to concatenate parts via `copy /b` and verify SHA256 integrity automatically.
- **Direct Cloud Mirror:** Automated upload to Pixeldrain API providing a direct single-click 4.2GB ISO download link.

---

## 7. Product Roadmap

```
[Phase 1: Foundations]        -> Archiso base, KDE Plasma 6 profile, pacman mirrors (COMPLETED)
[Phase 2: Dual DE & Tools]    -> GNOME 4x integration, live session switcher (COMPLETED)
[Phase 3: Native Installer]   -> PyQt6 GUI installer, silent boot, single profile (COMPLETED)
[Phase 4: Release Pipeline]   -> GitHub Actions CI, chunked releases, combine.bat (COMPLETED)
[Phase 5: Kernel & Theme]     -> Custom Caelaris Zen-BORE kernel & bespoke theme (ROADMAP)
```
