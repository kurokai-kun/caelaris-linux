# Caelaris Linux (Arch-Based Distribution)

Caelaris is a modern, modular Arch Linux-based distribution featuring dedicated editions for both **KDE Plasma** and **GNOME**, integrated with the **Calamares** graphical system installer.

---

## ?? Project Architecture

```
custom-arch-distro/
+-- shared/
¦   +-- packages.common         # Core packages (kernel, pipewire, networkmanager, drivers)
¦   +-- pacman.conf             # Repository mirrors & package caching settings
¦   +-- airootfs/               # Shared filesystem overlays (sudoers, systemd presets)
¦   +-- branding/               # Distro identity (os-release, logos, banners)
+-- profiles/
¦   +-- kde/                    # KDE Plasma 6 + SDDM Live edition
¦   ¦   +-- packages.x86_64
¦   ¦   +-- profiledef.sh
¦   ¦   +-- airootfs/
¦   +-- gnome/                  # GNOME 4x + GDM Live edition
¦       +-- packages.x86_64
¦       +-- profiledef.sh
¦       +-- airootfs/
+-- installer/
¦   +-- calamares/              # Calamares graphical installer configurations
¦       +-- settings.conf       # Module execution sequence
¦       +-- branding/           # Caelaris installer branding and slideshow
¦       +-- modules/            # Partition, user creation, bootloader, desktop selector
+-- scripts/
    +-- setup_build_env.sh      # Prepares Arch/WSL build host with dependencies
    +-- build.sh                # Main automated ISO build orchestrator
    +-- test_qemu.sh            # Tests generated ISO in QEMU on Linux/WSL
    +-- test_qemu.bat           # Tests generated ISO in QEMU on Windows
```

---

## ??? Build Environment Setup (Windows)

Because `mkarchiso` relies on Linux kernel primitives (loopback mounts, ext4/squashfs permissions, `chroot`), the build script must run inside an Arch Linux environment.

### Option 1: ArchWSL (Fastest & Easiest on Windows)
1. Install WSL from an Administrator PowerShell prompt:
   ```powershell
   wsl --install
   ```
2. Download and install **ArchWSL** from [ArchWSL GitHub](https://github.com/yuk7/ArchWSL/releases) (or via winget if available).
3. Open ArchWSL and navigate to your Windows project directory:
   ```bash
   cd /mnt/d/"Linux Project"
   ```
4. Run the setup script:
   ```bash
   sudo chmod +x scripts/*.sh
   sudo ./scripts/setup_build_env.sh
   ```

### Option 2: Arch Linux Virtual Machine (VirtualBox / VMware)
1. Boot a minimal Arch Linux VM.
2. Share or clone this folder into the VM.
3. Run `sudo ./scripts/setup_build_env.sh`.

---

## ?? Building Your Distro ISOs

To build the **KDE Plasma Edition**:
```bash
sudo ./scripts/build.sh kde
```

To build the **GNOME Edition**:
```bash
sudo ./scripts/build.sh gnome
```

The output `.iso` files will be placed in the `./out/` directory (e.g. `out/Caelaris-kde-2026.09-x86_64.iso`).

---

## ?? Testing Your ISO

### In QEMU (Instant test)
```bash
./scripts/test_qemu.sh
```
Or on Windows:
```cmd
.\scripts\test_qemu.bat
```

### In VirtualBox
1. Create a new VM: Type `Linux`, Version `Arch Linux (64-bit)`.
2. Allocate 4 GB RAM, 2-4 vCPUs.
3. Enable **EFI** in VM Settings -> System -> Motherboard -> `Enable EFI`.
4. Attach the generated ISO to the optical drive and start the VM.

---

## ?? Customizing Caelaris

* **Change Distro Name / Metadata:** Edit `shared/branding/os-release` and `installer/calamares/branding/default/branding.desc`.
* **Add Default Packages:** Add package names to `shared/packages.common` (for all editions) or `profiles/kde/packages.x86_64` / `profiles/gnome/packages.x86_64`.
* **Custom Wallpapers & Themes:** Place wallpapers in `shared/airootfs/usr/share/backgrounds/` and theme files in `shared/airootfs/usr/share/themes/`.
