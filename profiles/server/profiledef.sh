#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="caelaris-server"
iso_label="CAEL_SRV_$(date +%y%m)"
iso_publisher="Caelaris Linux Project <https://github.com/kurokai-kun/caelaris-linux>"
iso_application="Caelaris Linux Server & Headless Edition"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/g_wheel"]="0:0:440"
  ["/root"]="0:0:750"
  ["/usr/local/bin/caelaris-installer-cli"]="0:0:755"
  ["/usr/local/bin/caelaris-server-quickstart"]="0:0:755"
)
