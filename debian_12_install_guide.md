# Debian GNU/Linux 12 (Bookworm) Installation Guide
*Optimized for Node Operators (64-bit PC / amd64)*

This guide provides a comprehensive walkthrough of installing Debian 12. It is based on the official Debian 12 Installation Guide.

---

## 1. System Requirements & Hardware
### Supported Architectures
- **AMD64 & Intel 64 (amd64):** Fully supported.
- **CPU:** Both AMD and Intel 64-bit processors.
- **Multi-core/SMP:** Supported out of the box.

### Memory and Disk Space
| Install Type | RAM (Minimum) | RAM (Recommended) | Hard Drive |
| :--- | :--- | :--- | :--- |
| **Headless (No Desktop)** | 256 MB | 512 MB | 4 GB |
| **With Desktop (GNOME/KDE)** | 1 GB | 2 GB | 10 GB |
*Note: For a Rocket Pool node, 16GB+ RAM and 2TB+ NVMe SSD are recommended for chain syncing.*

### Firmware Requirements
Modern hardware (WiFi, GPUs, some NICs) often requires **non-free firmware**. 
- Starting with Debian 12, official images include a `non-free-firmware` section.
- The installer automatically detects and installs required firmware.

---

## 2. Before You Install
### Key Information Needed
- **Network Settings:** Hostname, Domain, IP (if static), Gateway, and DNS. (DHCP is usually automatic).
- **Hardware IDs:** For troubleshooting, use `lspci -nn` or `lsusb` in a live system to find Vendor:Product IDs.
- **BIOS/UEFI Settings:**
    - Invoke via **F2, F12, or Del**.
    - Set Boot Mode to **UEFI** (preferred over CSM/Legacy).
    - Disable **Secure Boot** if you encounter driver issues (though Debian supports it via "shim").
    - Disable Windows **Fast Startup** in dual-boot scenarios to avoid filesystem corruption.

---

## 3. Obtaining & Preparing Installation Media
### Official Images
- **Netinst CD:** Small image, downloads packages during install. Recommended for fast internet.
- **Full DVD:** Contains more packages; useful for offline installs.

### Creating a Bootable USB (Linux/macOS)
1. Identify device: `lsblk`
2. Write image: `sudo cp debian.iso /dev/sdX && sync`
*Note: Write to the whole device (/dev/sdb), not a partition (/dev/sdb1).*

---

## 4. Using the Debian Installer
### Initial Steps
1. **Language/Locale:** Choose your language and country.
2. **Keyboard:** Select your layout (default is usually fine).
3. **Network:** Usually handled via DHCP. Set your **Hostname** (e.g., `rocketpool-node`).

### Partitioning (Critical Step)
- **Guided - Use Entire Disk:** Recommended for beginners.
- **Guided - LVM:** Allows for easier resizing of partitions later.
- **Guided - Encrypted LVM:** Best for security (requires passphrase at boot).
- **Manual:** For custom setups (e.g., separate `/var` for chain data).

**Required Partitions:**
1. **EFI System Partition (ESP):** ~512MB (FAT32) for UEFI booting.
2. **Root (/):** Where the OS lives.
3. **Swap:** Virtual memory (size depends on physical RAM).

### Software Selection (Tasksel)
For a **Headless Node**, select only:
- [x] SSH Server
- [x] Standard system utilities
- [ ] (Uncheck all Desktop Environments like GNOME, KDE, etc.)

---

## 5. Completing the Installation
### GRUB Bootloader
- Install GRUB to the primary drive (UEFI partition).
- If dual-booting, it should detect other OSes automatically.

### First Boot
- Remove the USB stick and reboot.
- **Root Login:** If you set a root password, use it. If not, the first user created has `sudo` privileges.

---

## 6. Post-Installation & Maintenance
### Package Management (APT)
- **Update:** `sudo apt update`
- **Upgrade:** `sudo apt upgrade`
- **Install Software:** `sudo apt install <package-name>`

### Documentation
- Manuals: `man <command>`
- Package docs: `/usr/share/doc/<package-name>/`

### Troubleshooting the Boot
- If the screen is black, try adding `nomodeset` to the kernel boot parameters in GRUB.
- Access rescue mode from the installer media if the system won't boot.

---

## Appendix: Partitioning for Node Operators
When setting up a Rocket Pool node, consider these directories:
- `/var/lib/docker`: Where Docker images and volumes live (if using Docker mode).
- `/home`: Often where the Smartnode is installed.
- **Separate Data Drive:** It is common to mount a large NVMe SSD to a specific path like `/mnt/ssd` for the Ethereum chain data.
