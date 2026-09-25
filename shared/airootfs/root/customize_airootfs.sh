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

echo "=== customize_airootfs.sh completed successfully ==="
