<p align="center">
  <img src="https://raw.githubusercontent.com/kurokai-kun/caelaris-linux/main/assets/logo.png?v=2" alt="Caelaris Linux Logo" width="140">
</p>

# Caelaris Linux ARM64 Laptop & PC Edition (Apple Silicon & Snapdragon)

Official 64-bit ARM (`aarch64`) operating system engineered for modern ARM laptops, Apple Silicon Macs, and ARM workstations.

---

### 📥 How to Download & Assemble Your ISO
Because GitHub limits individual asset uploads to under 2.0 GB, this ISO (~2.58 GB) is distributed in multi-part chunks:

1. **Download the files into the SAME folder (e.g. ~/Downloads)**:
   - `caelaris-arm64-pc.iso.part-00`
   - `caelaris-arm64-pc.iso.part-01`
   - Download the helper script for your operating system:
     - **macOS (Apple Silicon)**: [`combine.command`](https://github.com/kurokai-kun/caelaris-linux/releases/download/arm64-pc-release/combine.command)
     - **Windows**: [`combine.bat`](https://github.com/kurokai-kun/caelaris-linux/releases/download/arm64-pc-release/combine.bat)
     - **Linux**: [`combine.sh`](https://github.com/kurokai-kun/caelaris-linux/releases/download/arm64-pc-release/combine.sh)

2. **Assemble the single ISO file**:
   * **On macOS (Mac with Apple Silicon M1/M2/M3/M4)**:
     * **Option A (One-Click)**: Simply double-click **`combine.command`** directly in macOS Finder!
     * **Option B (Terminal)**: Open Terminal and run:
       ```bash
       cd ~/Downloads && cat caelaris-arm64-pc.iso.part-00 caelaris-arm64-pc.iso.part-01 > caelaris-arm64-pc.iso
       ```
   * **On Windows**:
     * Double-click **`combine.bat`**
   * **On Linux**:
     * Open terminal in your download folder and run: `bash combine.sh`

---

### 🖥️ Running on Apple Silicon Mac (VMware Fusion & UTM)

#### ⚡ VMware Fusion on macOS:
If VMware Fusion shows **`EFI VMware Virtual SATA CDROM Drive... No Media`**, it means the virtual CD/DVD drive is disconnected or pointing to an unmerged/empty file. To fix this:
1. First, make sure you ran the merge step above so **`caelaris-arm64-pc.iso`** is fully assembled (~2.58 GB).
2. In VMware Fusion, go to the top menu: **Virtual Machine** -> **Settings...**
3. Click on **CD/DVD (SATA)**:
   - ⚠️ **Check the box: "Connect CD/DVD Drive"** (this is unchecked by default in Fusion if no disc is inserted!).
   - In the dropdown, choose **"Choose a disc or disc image..."** and select your merged **`caelaris-arm64-pc.iso`**.
4. Go to **Processors & Memory**: Allocate **4 to 8 GB RAM** and **4+ CPU cores**.
5. Power on the VM — it will immediately boot into Caelaris Linux!

#### ⚡ UTM on macOS:
1. Open UTM -> Click **Create a New Virtual Machine** -> **Virtualize** -> **Linux**.
2. Browse and select your assembled **`caelaris-arm64-pc.iso`**.
3. Allocate **4 to 8 GB RAM** and **4+ CPU cores**.
4. In Display settings, enable **VirtIO-GPU Metal acceleration**.
5. Start the VM to enjoy native Apple Silicon execution speed and smooth Wayland graphics!

---

### 📦 Available Release Assets:
1. **`caelaris-arm64-pc.iso.part-00`** & **`caelaris-arm64-pc.iso.part-01`**: Multi-part ISO chunks (~2.58 GB combined).
2. **`combine.command`**: macOS Finder double-click helper to automatically assemble the ISO.
3. **`combine.bat`**: Windows helper to assemble the ISO.
4. **`combine.sh`**: Linux/macOS Terminal helper script.
5. **`caelaris-arm64-pc.iso.sha256`**: SHA256 integrity checksum.
6. **`QUICKSTART_ARM64_PC.txt`**: Setup guide for UTM, VMware Fusion, and Snapdragon Copilot+ laptops.
