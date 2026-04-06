# Rocket Pool Node Setup Guide: Ubuntu Server 24.04 LTS Edition
**Hardware:** Beelink GTI15 | Intel Core Ultra 9 285H | 64GB DDR5 | 1TB OS NVMe | 4TB WD Black SN850X
**Network:** Hoodi Testnet -> Ethereum Mainnet
**Clients:** Nethermind (Execution) + Nimbus (Consensus)

---

## [ ] Phase 1: Hardware Preparation (Windows 11)
*Before installing Linux, you must resolve known hardware quirks using the pre-installed Windows OS.*

- [ ] **Update WD SN850X Firmware:** Boot into Windows 11, download the WD Dashboard, and apply the latest firmware to your 4TB NVMe drive.
- [ ] **Download BIOS Update:** Download the T205 BIOS from Beelink's official site to fix known Linux freezing issues tied to the ME firmware.
- [ ] **Format BIOS USB:** Format a 16GB+ USB drive to `FAT32` and label the volume exactly `WINPE`.
- [ ] **Extract BIOS:** Extract ALL files from the BIOS zip directly to the root of the USB drive.
- [ ] **Flash BIOS:** 
  - Restart, press `F7` at the boot logo, select `EFI USB Device`.
  - Press any key except ESC, type your USB volume (e.g., `fs3:`), type `Flash.nsh`, and press Enter. 
  - *WARNING: Do not power off during this process.* Wait for "Update EC Rom successfully!".
- [ ] **Configure BIOS Settings:** Reboot and press `Del` to enter BIOS setup. Change the following:
  - `Storage Operation Mode`: Set strictly to **AHCI/NVME** (Prevents extreme WD SSD overheating under Linux).
  - `Secure Boot`: **Disabled**.
  - `State After G3`: **S0** (Ensures auto-boot after power outages).
  - `Boot Order`: **USB first**.

---

## [ ] Phase 2: Ubuntu Server 24.04 LTS Installation
*Ubuntu Server 24.04 LTS is chosen because its modern kernel natively supports the Arrow Lake CPU and 10Gbps Intel network cards, bypassing the need for offline driver hunting.*

- [ ] **Prepare OS USB:** Flash the Ubuntu Server 24.04 LTS ISO to a USB drive and boot the Beelink from it.
- [ ] **Network:** The installer should immediately recognize your Intel 10Gbps Ethernet ports. Connect a cable and let it acquire an IP via DHCP.
- [ ] **Partitioning (OS Drive):** 
  - Select the **1TB built-in NVMe** for the OS. 
  - Choose `Use entire disk`. Uncheck the option to set up an LVM to keep the filesystem simple. 
  - *Leave the 4TB drive completely untouched for now.*
- [ ] **User Creation:** Create a standard user account (e.g., `nodeop`) with a strong password. This user will automatically receive `sudo` privileges.
- [ ] **Software Selection:** Choose **Ubuntu Server (minimized)** or standard. **Do NOT install a graphical desktop** to save RAM and reduce the attack surface. Select `OpenSSH server` so you can manage it remotely.
- [ ] **Reboot & Update:** Remove the USB, reboot, log in, and ensure the system is up to date:
  `sudo apt update && sudo apt upgrade -y`
- [ ] **Set Timezone:** Standardize your logs to universal time:
  `sudo timedatectl set-timezone UTC`

---

## [ ] Phase 3: Security Hardening
*Your node protects real assets. Secure it before installing any node software.*

- [ ] **Generate SSH Key:** On your *personal computer*, generate an Ed25519 key: 
  `ssh-keygen -t ed25519 -C "rocketpool-node"`
- [ ] **Transfer SSH Key:** Copy the public key to the node: 
  `ssh-copy-id nodeop@<node-ip>`
- [ ] **Disable Passwords & Root Login:** SSH into the node and edit the config:
  `sudo nano /etc/ssh/sshd_config`
  - Set `PasswordAuthentication no`
  - Set `PermitRootLogin no`
  - Add `AllowUsers nodeop`
- [ ] **Test & Apply SSH:** Test for typos with `sudo sshd -t`. If clear, restart the service with `sudo systemctl restart ssh`.
- [ ] **Configure UFW Firewall:** Run the following commands in order:
  - `sudo ufw default deny incoming`
  - `sudo ufw default allow outgoing`
  - `sudo ufw allow 22/tcp` (SSH)
  - `sudo ufw allow 30303` (Execution P2P)
  - `sudo ufw allow 9000` (Consensus P2P)
  - `sudo ufw enable`
- [ ] **Install Fail2ban:** Protect against brute-force attacks:
  - `sudo apt install fail2ban`
  - `sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local`
  - Edit `jail.local` to add `enabled = true` under the `[sshd]` section.
  - `sudo systemctl enable fail2ban && sudo systemctl start fail2ban`
- [ ] **Configure Auto-Updates:** Install `unattended-upgrades` to automatically apply security patches in the background. Ensure `Automatic-Reboot "false"` is set so the node doesn't randomly reboot during block proposals.
- [ ] **Harden Shared Memory:** Prevent code execution in RAM:
  - `sudo nano /etc/fstab`
  - Append: `tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0`
- [ ] **Network Kernel Hardening:** Ignore malicious network packets:
  - `sudo nano /etc/sysctl.conf`
  - Add `net.ipv4.icmp_echo_ignore_broadcasts = 1`, `net.ipv4.conf.all.accept_source_route = 0`, and `net.ipv4.tcp_syncookies = 1`. 
  - Apply with `sudo sysctl -p`.

---

## [ ] Phase 4: Docker & Smartnode Installation
*Rocket Pool runs your clients inside isolated Docker containers.*

- [ ] **Install Official Docker:** Do not use default packages. Download Docker's GPG keys and install from their official repository:
  - `sudo install -m 0755 -d /etc/apt/keyrings`
  - `sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc`
  - Add the repo to `/etc/apt/sources.list.d/docker.list`, update, and `sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`.
- [ ] **Docker Permissions:** Allow your user to run Docker:
  - `sudo usermod -aG docker nodeop`
  - `newgrp docker`
- [ ] **Download Rocket Pool CLI:** 
  - `mkdir -p ~/bin`
  - `wget https://github.com/rocket-pool/smartnode/releases/latest/download/rocketpool-cli-linux-amd64 -O ~/bin/rocketpool`
  - `chmod +x ~/bin/rocketpool`
- [ ] **Initialize Smartnode:** Run `rocketpool service install` and confirm.

---

## [ ] Phase 5: Rocket Pool Wizard Configuration
*Configure the clients and network via the Terminal UI.*

- [ ] **Launch Wizard:** Run `rocketpool service config`.
- [ ] **Network:** Select **Hoodi Testnet** to practice safely with fake ETH.
- [ ] **Mode:** Select **Locally Managed** (Docker mode).
- [ ] **Execution Client:** Select **Nethermind**. It is incredibly fast and safely keeps you out of the dangerous Geth supermajority.
- [ ] **Consensus Client:** Select **Nimbus**. It uses the lowest amount of RAM/CPU and has <1% market share, vastly improving network diversity.
- [ ] **Checkpoint Sync:** Enter the trusted Holesky/Hoodi sync URL (`https://checkpoint-sync.holesky.ethpandaops.io/`) to sync the Beacon chain in minutes instead of days.
- [ ] **Doppelganger Protection:** Select **Yes**. This forces a short wait on restart to ensure your keys aren't double-voting elsewhere, preventing severe slashings.
- [ ] **Start the Node:** Save the configuration and follow the CLI prompts to initialize your node!
