#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="caelaris-kde"
iso_label="CAEL_KDE_$(date +%y%m)"
iso_publisher="Caelaris Project <https://github.com/kurokai-kun/caelaris-linux>"
iso_application="Caelaris Linux Live/Rescue & Installer (KDE Edition)"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/g_wheel"]="0:0:440"
  ["/root"]="0:0:750"
  ["/usr/bin/caelaris-live-setup"]="0:0:755"
  ["/usr/bin/caelaris-welcome"]="0:0:755"
  ["/usr/bin/caelaris-installer"]="0:0:755"
  ["/usr/bin/caelaris-installer-gui"]="0:0:755"
  ["/usr/bin/caelaris-autoresize"]="0:0:755"
  ["/usr/bin/caelaris-session-selector"]="0:0:755"
)
