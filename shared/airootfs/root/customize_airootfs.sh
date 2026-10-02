#!/bin/bash
set +e

echo "=== Running Caelaris customize_airootfs.sh ==="

# 1. Completely remove plymouth and any plymouth themes/units
pacman -Rdd --noconfirm plymouth breeze-plymouth 2>/dev/null || true
rm -rf /usr/lib/systemd/system/plymouth* /etc/systemd/system/plymouth* /usr/bin/plymouth* /usr/bin/plymouthd 2>/dev/null || true

for u in plymouth-start.service plymouth-quit.service plymouth-quit-wait.service plymouth-reboot.service plymouth-poweroff.service plymouth-halt.service plymouth-kexec.service plymouth-switch-root.service; do
    systemctl mask "$u" 2>/dev/null || true
    ln -sf /dev/null "/etc/systemd/system/${u}" 2>/dev/null || true
done

# 2. Mask benign loop service on ISO
ln -sf /dev/null /etc/systemd/system/systemd-loop@.service 2>/dev/null || true

# 3. Create liveuser if not already created
if ! id -u liveuser >/dev/null 2>&1; then
    useradd -m -c "Caelaris Linux" -g users -G wheel,video,audio,optical,storage,input,power -s /bin/bash liveuser
fi
passwd -d liveuser 2>/dev/null || true
echo "liveuser ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/liveuser
chmod 0440 /etc/sudoers.d/liveuser
chfn -f "Caelaris Linux" liveuser 2>/dev/null || true

# 4. Set graphical target and enable display manager
systemctl set-default graphical.target
systemctl enable sddm.service
systemctl enable caelaris-live-setup.service
systemctl enable NetworkManager.service

# 5. Enable Virtualization Guest drivers for VMware, VirtualBox, and QEMU/KVM
systemctl enable vboxservice.service vmtoolsd.service vmware-vmblock-fuse.service spice-vdagentd.service qemu-guest-agent.service 2>/dev/null || true

# 6. Silence motherboard beeps permanently inside rootfs
mkdir -p /etc/modprobe.d
cat > /etc/modprobe.d/nobeep.conf << 'EOF'
blacklist pcspkr
blacklist snd_pcsp
EOF

# 7. Configure SDDM sessions: Strictly Plasma, GNOME, and Caelestia (No duplicate Plasma, No X11)
rm -rf /usr/share/xsessions/* 2>/dev/null || true
rm -f /usr/share/wayland-sessions/caelestia.desktop 2>/dev/null || true

if [ -f /usr/share/wayland-sessions/plasma.desktop ]; then
    sed -i 's/^Name=.*/Name=Plasma/' /usr/share/wayland-sessions/plasma.desktop
fi
if [ -f /usr/share/wayland-sessions/gnome.desktop ]; then
    sed -i 's/^Name=.*/Name=GNOME/' /usr/share/wayland-sessions/gnome.desktop
fi
if [ -f /usr/share/wayland-sessions/hyprland.desktop ]; then
    sed -i 's/^Name=.*/Name=Caelestia/' /usr/share/wayland-sessions/hyprland.desktop
    sed -i 's|^Exec=.*|Exec=/usr/bin/caelestia-session|' /usr/share/wayland-sessions/hyprland.desktop
    sed -i 's|^TryExec=.*|TryExec=/usr/bin/caelestia-session|' /usr/share/wayland-sessions/hyprland.desktop
fi

# Instruct SDDM to only look for Wayland sessions and ignore X11 sessions
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-wayland-only.conf << 'EOF'
[General]
DisplayServer=wayland

[Wayland]
SessionDir=/usr/share/wayland-sessions

[X11]
SessionDir=/dev/null
EOF

# 8. Pre-generate system-wide fontconfig cache to prevent glycin-svg sandbox seccomp crashes
echo "Generating fontconfig cache..."
fc-cache -r >/dev/null 2>&1 || true

# 9. Enforce complete application menu separation and clutter removal across all environments
if [ -x /usr/bin/caelaris-sanitize-apps ]; then
    /usr/bin/caelaris-sanitize-apps
fi

# 10. Enable Caelaris Defender Real-Time Security Guard
systemctl enable caelaris-defender.service 2>/dev/null || true

# 11. Enable Valve Device Memory Cgroups (dmemcg) & Dynamic VRAM Booster (Natalie Vock)
systemctl enable dmemcg-booster.service 2>/dev/null || true
systemctl enable caelaris-vram-booster.service 2>/dev/null || true

# 12. Pre-initialize pacman keyring and prevent reflector/getty boot failures
echo "Pre-initializing pacman keyring in rootfs..."
pacman-key --init 2>/dev/null || true
pacman-key --populate archlinux 2>/dev/null || true
systemctl disable reflector.service 2>/dev/null || true
systemctl mask reflector.service 2>/dev/null || true
ln -sf /dev/null /etc/systemd/system/reflector.service 2>/dev/null || true
ln -sf /dev/null /etc/systemd/system/getty@tty1.service 2>/dev/null || true

echo "=== customize_airootfs.sh completed successfully ==="

