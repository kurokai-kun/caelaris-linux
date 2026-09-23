## 🖥️ Caelaris Linux Server & Headless Edition

Official high-performance, minimal server release of Caelaris Linux engineered exclusively for bare-metal servers, homelabs, Proxmox VE, KVM hypervisors, and cloud microservices.

---

### ⚡ Key Architectural Advantages:
- **Sub-150 MB Idle RAM**: Completely stripped of graphical display servers (no X11/Wayland background daemons). 100% of memory and CPU cycles are dedicated to compute, databases, and container pods.
- **Cockpit Web Management Console**: Instant web-based management dashboard accessible at `https://<server-ip>:9090` for inspecting CPU metrics, RAID pools, systemd services, firewall rules, and container logs.
- **Native Docker & Rootless Podman**: Pre-installed and configured with native Btrfs snapshotting storage driver for zero-copy layer staging and rapid CI/CD builds.
- **Automated Btrfs RAID & Snapshots**: Automated subvolumes (`@server`, `@var_lib_docker`, `@var_log`) formatted with transparent zstd compression for 0.05-second atomic rollbacks.
- **BBR & CAKE Network Stacks**: Pre-tuned TCP BBR congestion control and CAKE packet scheduling for maximum server throughput and zero bufferbloat during heavy ingress/egress load.
- **Hardened OpenSSH & Zero Telemetry**: Pre-configured OpenSSH using Ed25519 elliptic curve keys, fail2ban compatibility, and 100% offline-first privacy.

---

### 📦 Available Release Assets:
1. **`caelaris-server-x86_64.iso`**: Standalone, bootable hybrid UEFI/BIOS server ISO (~1.1 GB). Single-file 1-click download.
2. **`caelaris-server-x86_64.iso.sha256`**: Cryptographic SHA256 integrity checksum.
3. **`SHA256SUMS.txt`**: Consolidated verification file.
4. **`QUICKSTART_SERVER.txt`**: Complete setup guide for physical servers, remote headless SSH, and Proxmox VE.

---

### 🛠️ Quick Installation:
```bash
# Automated TUI Installation
sudo caelaris-installer-cli --disk /dev/nvme0n1

# Headless Unattended Remote Installation (via SSH)
ssh root@caelaris-live.local
caelaris-installer-cli --headless --disk /dev/sda
```
