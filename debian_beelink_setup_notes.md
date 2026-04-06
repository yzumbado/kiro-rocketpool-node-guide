## 4. Debian Linux Considerations & Known Hardware Quirks

This node operates on a headless Debian environment. Because the Beelink GTI15 utilizes cutting-edge Intel hardware (Arrow Lake CPU, BE200 WiFi), specific Debian configurations are required to ensure system stability and component recognition.

### 1. The Kernel Version Requirement (Crucial)
* **The Issue:** The default stable release of Debian 12 ("Bookworm") ships with Linux Kernel 6.1 LTS. This kernel is too old to recognize the Intel Core Ultra 9 285H CPU architecture efficiently, and it completely lacks the drivers for the Intel BE200 WiFi 7 card.
* **The Solution:** You have two paths. 
    1. **Debian 12 with Backports (Recommended):** Install standard Debian 12 via a hardwired Ethernet connection. Once installed, immediately add the `bookworm-backports` repository and upgrade the kernel: `sudo apt install -t bookworm-backports linux-image-amd64` and `sudo apt install -t bookworm-backports firmware-iwlwifi`.
    2. **Debian 13 ("Trixie"):** Install the testing/newer branch of Debian which includes a modern kernel (6.11+) out of the box. 

### 2. BIOS Storage Settings: High NVMe Temperatures on Debian
* **The Issue:** By default, some modern Mini PC BIOS settings have the storage controller set to "RAID On" or "Intel RST". While Debian can boot with this, users report it causes NVMe drives (specifically WD and Kioxia) to run exceptionally hot (63ºC+ while idle) because Debian cannot properly manage the drive's power states through the RAID controller.
* **The Solution:** Before installing Debian, enter the Beelink BIOS and ensure the storage operation mode is set strictly to **AHCI/NVME**. This allows Debian's native `nvme-core` drivers to manage the WD_BLACK SN850X temperatures correctly.

### 3. WD_BLACK SN850X Active State Power Management (ASPM)
* **The Issue:** Even in AHCI mode, Western Digital drives can occasionally drop offline or throw PCIe bus errors in Debian kernel logs (`dmesg`) when the OS attempts to put the drive into its deepest sleep state (PS4). 
* **The Solution:** If the node experiences random storage disconnects, edit the GRUB bootloader (`sudo nano /etc/default/grub`), find the `GRUB_CMDLINE_LINUX_DEFAULT` line, and append `nvme_core.default_ps_max_latency_us=5500`. Then run `sudo update-grub`. This limits the sleep states and keeps the drive highly responsive for chain syncing.

### 4. The Headless Installation Target
* **The Issue:** To maximize the 64GB of RAM for the execution client, we do not want a Desktop Environment (GUI) consuming resources.
* **The Solution:** During the Debian installation wizard, at the "Software Selection" step, **uncheck** "Debian desktop environment" and "GNOME". Only check **"SSH server"** and **"standard system utilities"**.
