#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="caelaris-kde"
iso_label="CAELARIS_KDE_$(date +%Y%m)"
iso_publisher="Caelaris Project <https://github.com/kurokai-kun/caelaris-linux>"
iso_application="Caelaris Linux Live/Rescue & Installer (KDE Edition)"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/g_wheel"]="0:0:440"
  ["/root"]="0:0:750"
)
