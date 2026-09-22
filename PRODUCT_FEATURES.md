# Caelaris Linux — Comprehensive Product Features Guide

**Document Version:** 1.0-Rolling  
**Document Type:** Product Features & Capabilities Specification  
**Target Platform:** x86_64 (UEFI & Legacy BIOS)  
**Base Distribution:** Arch Linux Rolling Baseline  
**Author:** Caelaris Core Architecture & Engineering Team  
**Last Updated:** September 2026  

---

## 1. Executive Product Overview

**Caelaris Linux** is a next-generation Arch-based operating system designed for gamers, software engineers, and power users who demand cutting-edge performance with zero configuration headaches. By combining Arch Linux's rolling package model with pre-configured dual desktop environments, automated hardware/virtualization drivers, a custom graphical installer, and pro-grade gaming enhancements, Caelaris Linux offers an uncompromising desktop experience straight from the ISO.

---

## 2. Core Feature Highlights

```
==================================================================================
                     CAELARIS LINUX FEATURE HIGHLIGHTS
==================================================================================
  [1] Dual Desktop Environments   -> KDE Plasma 6 (Default) + GNOME 4x on Wayland
  [2] Live Session Hot-Switcher   -> Switch between KDE & GNOME in 2 seconds
  [3] Native Graphical Installer  -> Python/PyQt6 wizard with guided Btrfs & Ext4
  [4] Silent Direct Bootloader    -> Clean single "Caelaris Linux" entry to SDDM
  [5] Single User Profile Purity  -> Zero leftover liveuser profiles after setup
  [6] Pro-Grade Gaming Stack      -> vm.max_map_count, GameMode, MangoHud, Steam
  [7] Universal Hypervisor Tools  -> VMware, VirtualBox, and QEMU/UTM auto-scaling
  [8] Full Software Access        -> Pacman, yay (Arch User Repository), Flathub
  [9] Caelaris Welcome Assistant  -> 1-click maintenance tool (shown only once)
 [10] PipeWire Pro Audio Graph    -> Low-latency audio with JACK/ALSA/Pulse bridges
==================================================================================
```

---

## 3. Desktop Environments & User Interface

### 3.1 KDE Plasma 6 (Default Environment)
- **Wayland Native:** Driven by KWin Wayland compositor, providing stutter-free fractional display scaling, touchpad gestures, and zero screen-tearing.
- **Caelaris Dark Breeze Styling:** Customized visual aesthetic with elegant translucency, dark panels, and bespoke Caelaris wallpapers and icons.
- **Application Suite:** Includes Dolphin file manager, Konsole terminal, Kate text editor, Spectacle screenshot tool, and System Settings.

### 3.2 GNOME 4x (Alternative Environment)
- **Fluid Gestures & Navigation:** Powered by Mutter Wayland compositor with full three-finger touchpad gesture navigation.
- **Modern Workflow:** Streamlined Activities Overview, dynamic workspaces, and integrated search.
- **Included Applications:** Nautilus file manager, GNOME Terminal, Loupe image viewer, and Text Editor.

### 3.3 Live Preview Desktop Switcher
- **Instant Hot-Switching:** Run `caelaris-switch-desktop` directly from the live preview desktop to toggle between KDE Plasma 6 and GNOME in under 2 seconds without restarting the virtual machine or PC.
- **Dual Session at Login:** Post-installation, users can freely toggle between Plasma (Wayland) and GNOME (Wayland) from the SDDM session menu at any time.

---

## 4. Installation & First-Boot Experience

### 4.1 Caelaris Native Graphical Installer (`caelaris-installer-gui`)
- **PyQt6 Interface:** Responsive, multithreaded graphical installer running seamlessly in live preview.
- **Guided Disk Partitioning:**
  - **Btrfs Mode (Recommended):** Automatically configures standard subvolumes (`@`, `@home`, `@cache`, `@snapshots`) with transparent Zstandard compression.
  - **Ext4 Mode:** Reliable, high-compatibility filesystem for traditional installations.
  - **EFI System Partition (ESP):** Formatted as FAT32 and mounted cleanly to `/boot/efi`.
- **Automated Kernel & Microcode Deployment:** Deploys `vmlinuz-linux` and detects CPU architecture to configure `intel-ucode` or `amd-ucode`.
- **Initramfs Generation:** Runs chrooted `mkinitcpio -P` inside the newly prepared root filesystem, creating reliable default and fallback recovery images.

### 4.2 Single User Profile Guarantee
- **Complete Live Artifact Purge:** Deletes the temporary `liveuser` account (`userdel -r -f liveuser`), removing `/home/liveuser` and live sudoers permissions.
- **Sysusers Cleanup:** Deletes `/etc/sysusers.d/caelaris-liveuser.conf` to prevent systemd from recreating the live account on future boots.
- **AccountsService Registration:** Configures the newly created user as the sole system profile in `/var/lib/AccountsService/users/`.
- **Clean Desktop:** Automatically strips installer desktop shortcuts from `/home/{user}/Desktop/` and `/etc/skel/Desktop/`.

### 4.3 Silent Direct Bootloader
- **Clean Menu Title:** Configures GRUB with a single entry titled **`Caelaris Linux`** (and `Caelaris Linux (Recovery Mode)`).
- **Console Clutter Suppression:** Silent kernel parameters (`quiet loglevel=3 rd.udev.log_level=3 systemd.show_status=0 vt.global_cursor_default=0`) eliminate console text and service start lines, booting directly into the graphical SDDM login screen.
- **Universal Removable Fallback:** Installs both NVRAM and fallback `EFI/BOOT/BOOTX64.EFI` bootloaders, eliminating boot loops on hypervisors.

---

## 5. Gaming & Extreme Performance Stack

### 5.1 Pro-Grade Kernel & Sysctl Optimizations
- **High Memory Map Limit:** `vm.max_map_count = 2147483642` eliminates crashes and shader stalls in modern memory-intensive titles (e.g. Star Citizen, Hogwarts Legacy, complex Wine/Proton games).
- **Reduced Swappiness:** `vm.swappiness = 10` forces the kernel to preserve gaming textures and processes in physical RAM.
- **CAKE Network Queue Management:** `net.core.default_qdisc = cake` actively prevents bufferbloat during online multiplayer matches.
- **Google BBR Congestion Control:** `net.ipv4.tcp_congestion_control = bbr` optimizes network packet delivery and lowers ping under high connection loads.

### 5.2 Out-of-the-Box Gaming Software
- **Steam Client:** Pre-installed and configured for Steam Play (Proton).
- **MangoHud:** In-game performance telemetry overlay (FPS, frame times, CPU/GPU temperatures, RAM usage) supporting both 64-bit and 32-bit Vulkan/OpenGL titles.
- **Feral GameMode:** Automatic CPU governor prioritization, GPU clock locking, and I/O niceness tuning during active gameplay.
- **VKD3D & DXVK Ready:** Complete Vulkan translation layers for DirectX 9, 10, 11, and 12.
- **32-Bit Multilib Drivers:** Full 32-bit graphics libraries enabled by default for legacy Windows games running via Proton.

---

## 6. Universal Virtualization & Hardware Drivers

### 6.1 Hypervisor Guest Integration
| Hypervisor | Integrated Services | Supported Capabilities |
| :--- | :--- | :--- |
| **VMware Workstation / Fusion** | `open-vm-tools`, `vmtoolsd`, `vmware-vmblock-fuse`, `xf86-video-vmware` | Dynamic window resizing, host shared folders, two-way clipboard. |
| **Oracle VirtualBox** | `virtualbox-guest-utils`, `vboxservice`, `vboxsf` | Shared clipboard, seamless mouse integration, auto-resolution scaling. |
| **QEMU / KVM / UTM (macOS)** | `spice-vdagent`, `spice-vdagentd`, `qemu-guest-agent` | SPICE dynamic display resizing, clipboard synchronization, guest management. |

### 6.2 Dynamic Display Resizing (`caelaris-autoresize`)
- Background daemon actively listens to hypervisor window geometry updates.
- Instantly syncs guest resolution to match host window resizing in under 1 second without manual display configuration.

### 6.3 Physical GPU Drivers
- **AMD Radeon:** In-kernel `amdgpu` driver paired with Mesa `vulkan-radeon` (RADV) and hardware VA-API video decoding.
- **Intel Arc & Iris Xe:** `i915` / `xe` driver paired with Mesa `vulkan-intel` (ANV) and `intel-media-driver`.
- **NVIDIA GeForce:** Automatic DRM modesetting (`options nvidia-drm modeset=1`) configured on systems detected with NVIDIA GPUs.

---

## 7. Package Management & Software Repositories

- **Official Arch Linux Repositories:** Access to Core, Extra, and Multilib repos with rapid rolling updates.
- **Arch User Repository (AUR):** Bundled `yay` helper for seamless installation and compilation of community software.
- **Flatpak & Flathub Sandbox:** Native Flatpak backend ready for sandboxed application distribution.
- **Pacman Keyring Auto-Initialization:** Automatically initializes pacman keys during installation for error-free software installation on first boot.

---

## 8. First-Run Caelaris Welcome Assistant

- **Intuitive GTK3 Interface:** Designed to introduce new users to their Caelaris Linux installation.
- **One-Click Maintenance Actions:**
  - Update system repositories (`sudo pacman -Syu`).
  - Install popular software and development tools.
  - Launch gaming tools and graphics configuration utilities.
- **One-Time Execution Policy:** Records state in `~/.config/caelaris-welcome-shown`, automatically remaining hidden on future logins in both KDE and GNOME.

---

## 9. Audio & Multimedia Architecture

- **PipeWire Audio Graph:** Unified pro-audio server delivering ultra-low audio latency.
- **WirePlumber Session Manager:** Modular, policy-driven audio device switching.
- **Full Compatibility Bridges:** `pipewire-pulse`, `pipewire-alsa`, and `pipewire-jack` ensure complete compatibility across games, creative DAWs, and web browsers.
- **Comprehensive Codec Support:** Pre-installed support for H.264, H.265/HEVC, VP9, AV1, and AAC.

---

## 10. Feature Comparison Matrix

| Feature / Capability | Caelaris Linux | Vanilla Arch | Manjaro | Pop!_OS | Fedora Workstation |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Dual Desktop (KDE + GNOME)** | Yes (Unified ISO) | Manual | Separate ISOs | Separate Spins | Separate Spins |
| **Live Session Hot-Switcher** | Yes (< 2s) | No | No | No | No |
| **Custom Graphical Installer** | Yes (PyQt6) | No (CLI) | Calamares | Custom | Anaconda |
| **Tuned Low-Latency Gaming Sysctl** | Yes | Manual | No | Partial | Partial |
| **VMware & VBox Auto-Resize** | Yes (Built-in) | Manual | Partial | Partial | Partial |
| **Silent Direct Bootloader** | Yes | Manual | Partial | Partial | Yes (Plymouth) |
| **Purged Single User Profile** | Yes | N/A | Yes | Yes | Yes |
| **Bundled yay AUR Helper** | Yes | Manual | Pamac | Paru/Yay | No (COPR) |
| **PipeWire Low-Latency Audio** | Yes | Manual | Yes | Yes | Yes |

---

## 11. Platform Architecture & Raspberry Pi / ARM64 Roadmap

### 11.1 Tier 1: x86_64 PCs, Laptops & Virtual Machines (Production)
- **Target Processors:** Intel Core / Xeon & AMD Ryzen / EPYC (64-bit x86_64).
- **Boot Subsystem:** UEFI NVRAM with universal removable fallback (`EFI/BOOT/BOOTX64.EFI`) and Legacy BIOS via GRUB.
- **Distribution Format:** Bootable live hybrid ISO with multithreaded PyQt6 graphical installer (`caelaris-installer-gui`) and automated Btrfs subvolume layout.
- **Graphics & Hypervisors:** Native Mesa Gallium drivers (AMD RADV, Intel ANV), proprietary NVIDIA DRM modesetting, and full guest suite (`open-vm-tools`, `virtualbox-guest-utils`, `spice-vdagent`).

### 11.2 Tier 2: ARM64 & Raspberry Pi Edition (Active Build & Release Pipeline)
- **Target Hardware:**
  - **Raspberry Pi 5 (4GB / 8GB RAM):** Primary recommended SBC target offering desktop-class performance for dual KDE Plasma 6 & GNOME Wayland sessions.
  - **Raspberry Pi 4 Model B (4GB / 8GB RAM):** Fully supported with tuned lightweight compositor profiles.
  - **Raspberry Pi 3 Model B+ (1GB RAM):** Fully supported with VideoCore IV KMS drivers and active zstd ZRAM memory compression.
- **Base OS Foundation:** Arch Linux ARM (`aarch64` ALARM baseline) retaining rolling release packaging and `yay` AUR support.
- **Kernel & GPU Stack:** Vendor-optimized `linux-rpi` kernel with native Broadcom VideoCore VII (Pi 5), VI (Pi 4), and IV (Pi 3B+) hardware graphics acceleration under Wayland.
- **Distribution Formats:**
  - **Hybrid UEFI ARM64 ISO (`caelaris-rpi-arm64.iso`):** Universal bootable ISO for UEFI Pi firmware, ARM64 VMs (QEMU/UTM), and cloud ARM instances.
  - **Compressed Raw Image (`caelaris-rpi-arm64.img.xz`):** Ready for 1-click writing via **Raspberry Pi Imager** or **BalenaEtcher** to MicroSD cards, USB SSDs, or NVMe HATs.
- **Gaming & Emulation Stack:** Integrated `Box64` and `FEX-Emu` dynamic binary translation engines, enabling x86 game binaries, Steam ARM experimentation, and RetroArch emulation directly on the Raspberry Pi.
