## 🛠️ Phase 1: Pre-Installation Preparation

**1. 🍎 Prepare the Linux Bootable USB (On your MacBook)**
*   📥 Download the standard x86_64 Debian 12 (Bookworm) `amd64` netinstall ISO from [debian.org/download].
*   💾 Flash the ISO to your USB key using a tool like Balena Etcher. 
*   ⚠️ **Mac Terminal Warning:** If you choose to use the Mac command line (`dd` command) instead of Balena Etcher, make sure to write the ISO to the *whole device* (e.g., `/dev/diskX`) and not a specific partition (e.g., `/dev/diskX1`) [1].
*   *(Optional)* 💽 If you wish to practice on your MacBook first, download the UTM virtual machine app from [mac.getutm.app] [2].

**2. ⚙️ Configure the Beelink BIOS (On the GTI15)**
*   🔌 Plug in the USB key, turn on the Beelink, and press `Del` repeatedly to enter the BIOS [3].
*   🖥️ **Boot Mode:** Ensure the Boot Mode is explicitly set to **UEFI** (and disable CSM/Legacy mode if available) [4]. Debian's bootloader requires the EFI System Partition (ESP) to function correctly.
*   💽 **Storage Configuration:** Change the storage operation mode strictly to **AHCI/NVME** [5]. This allows Debian's native `nvme-core` drivers to properly manage the WD Black SN850X power states and prevents it from running exceptionally hot [5].
*   🔓 **Secure Boot:** Set to **Disabled** to avoid kernel signing issues [3].
*   ⚡ **State After G3:** Set to **S0** (auto-power-on) so the machine automatically reboots if power is lost and restored [3].
*   🥇 **Boot Order:** Set to boot from the USB drive first [3]. Save and exit.

---

## 🐧 Phase 2: Linux OS Installation

**1. 💿 Boot and Partition**
*   ⌨️ Select the text-based **Install** option from the GRUB menu [6]. 
*   🌑 *Troubleshooting Tip:* If the screen is completely black upon first boot, restart and add `nomodeset` to the kernel boot parameters in the GRUB menu to force basic software rendering [7].
*   🗣️ Follow the prompts for Language (English), Country, and Keyboard Layout [8-10].
*   🏷️ Set a descriptive hostname like `rp-node01` and leave the domain name blank [11, 12].
*   🚫🔑 **Crucial Step:** Leave the **Root Password blank** [12]. This locks the root account and automatically grants your standard user `sudo` privileges, which is standard security practice for a validator node [13].
*   👤 Create your non-root user account (e.g., `nodeop`) and assign a strong passphrase [14, 15].
*   🗄️ **Disk Setup:** Select **Guided - use entire disk** and choose the built-in 1TB SSD [16, 17]. Select **All files in one partition** [18]. *(The 4TB WD Black drive will be mounted separately in the next phase).*

**2. 📦 Software Selection & Bootloader**
*   🚫🖼️ When prompted for software selection, explicitly **uncheck** "Debian desktop environment" and "GNOME" [19]. A GUI consumes RAM and increases the attack surface [19].
*   ✅ Leave **"SSH server"** and **"standard system utilities"** checked and proceed [19].
*   ⚙️ **GRUB Confirmation:** When asked, select **Yes** to install the GRUB bootloader to your primary drive (UEFI partition) [20].

---

## 🔧 Phase 3: Hardware Tweaks & Storage Configuration

Once the installation is complete, reboot, remove the USB, and log in locally to the Beelink as your user (`nodeop`) [21].

**1. 🧠 Apply the Modern Kernel (Debian 12 Backports)**
*   🕰️ Debian 12 ships with Kernel 6.1, which is too old for the Intel Core Ultra 9 285H CPU and BE200 Wi-Fi 7 [22]. Plug in a hardwired Ethernet connection.
*   🌐 Run: `sudo apt update` then `sudo apt install -t bookworm-backports linux-image-amd64` and `sudo apt install -t bookworm-backports firmware-iwlwifi` [22].

**2. 🧊 Apply the NVMe ASPM Fix**
*   💤 To prevent the WD Black SN850X drive from dropping offline during deep sleep states, edit the bootloader [23].
*   📝 Run `sudo nano /etc/default/grub` [23].
*   🔍 Find the line starting with `GRUB_CMDLINE_LINUX_DEFAULT` and append `nvme_core.default_ps_max_latency_us=5500` [23].
*   💾 Save the file and run `sudo update-grub` [23].

**3. ⏰ Set Timezone and Update System**
*   🌍 Set the system to Universal Time: `sudo timedatectl set-timezone UTC` [24].
*   🔄 Apply OS updates: `sudo apt update && sudo apt upgrade -y` [25].

**4. 📁 Format and Mount the 4TB Chain Data NVMe**
*   🔎 Identify your 4TB drive (usually `/dev/nvme1n1`) by running `lsblk` [1].
*   🧹 Format the drive to ext4: `sudo mkfs.ext4 /dev/nvme1n1` *(ensure you have the correct drive identifier before running this!)*.
*   📂 Create a mount point: `sudo mkdir -p /mnt/ssd` [26].
*   🆔 Find the drive's UUID: `sudo blkid`.
*   🔗 Mount it permanently: `sudo nano /etc/fstab` and append `UUID=<your-drive-uuid> /mnt/ssd ext4 defaults 0 2`.
*   🚀 Mount the drive now without rebooting: `sudo mount -a`.
*   📡 Find your IP address by running `hostname -I` [27]. You can now switch to your MacBook.

---

## 🛡️ Phase 4: Security Hardening (On the MacBook via SSH)

**1. 🗝️ Generate and Install SSH Keys**
*   💻 On your Mac terminal, generate an Ed25519 key pair: `ssh-keygen -t ed25519 -C "rocketpool-node"` [28].
*   📤 Copy the key to your node: `ssh-copy-id nodeop@<your-node-ip>` [29].
*   🖥️ SSH into the node: `ssh nodeop@<your-node-ip>` [30]. *(For production, YubiKey FIDO2 hardware keys are mandated [31])*

**2. 🚪 Secure the SSH Daemon**
*   📝 Run `sudo nano /etc/ssh/sshd_config` [32].
*   🚫🔐 Set `PasswordAuthentication no` [33].
*   🚫👑 Set `PermitRootLogin prohibit-password` [33].
*   🚫⌨️ Set `KbdInteractiveAuthentication no` [34].
*   ✅👤 Add `AllowUsers nodeop` at the bottom of the file [34].
*   ✅ Validate the config with `sudo sshd -t`, then apply with `sudo systemctl restart ssh` [35, 36].

**3. 🧱 Configure the UFW Firewall**
*   🚦 Run the following commands to secure network ports [37]:
    `sudo apt install ufw`
    `sudo ufw default deny incoming`
    `sudo ufw default allow outgoing`
    `sudo ufw allow 22/tcp`
    `sudo ufw allow 30303` *(Nethermind P2P)*
    `sudo ufw allow 9000` *(Nimbus P2P)*
    `sudo ufw enable`

**4. 👮 Install Fail2ban & Unattended Upgrades**
*   📥 Install: `sudo apt install fail2ban unattended-upgrades` [38, 39].
*   🤖 Enable automatic security updates: `sudo dpkg-reconfigure -plow unattended-upgrades` and select "Yes" [40]. Set `Automatic-Reboot "false"` in `/etc/apt/apt.conf.d/50unattended-upgrades` [41, 42].
*   👀 Configure Fail2ban to monitor SSH by copying `/etc/fail2ban/jail.conf` to `/etc/fail2ban/jail.local` and setting `enabled = true` under `[sshd]` [43, 44]. Enable it: `sudo systemctl enable fail2ban --now` [45].

**5. 🔒 System-Level Hardening**
*   🛑 Secure Shared Memory: `sudo nano /etc/fstab` and append `tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0` [46].
*   🚧 Sysctl Hardening: `sudo nano /etc/sysctl.conf` and add parameters to disable ICMP broadcasts, source routing, and enable SYN cookies [47]. Apply with `sudo sysctl -p` [48].

---

## 🐳 Phase 5: Docker Installation & Custom Data Directory

**1. 📦 Install Docker Engine**
*   🔄 Update packages and install dependencies: `sudo apt update` and `sudo apt install ca-certificates curl` [49].
*   🔑 Add Docker's official GPG key [50]: 
    `sudo install -m 0755 -d /etc/apt/keyrings`
    `sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc`
    `sudo chmod a+r /etc/apt/keyrings/docker.asc`.
*   📥 Add the repository and install Docker [51, 52]:
    `sudo apt update`
    `sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`
*   👥 Add your user to the docker group: `sudo usermod -aG docker nodeop` [53].
*   ⚡ Apply the group change immediately: `newgrp docker` [54].

**2. 📂 Point Docker to the 4TB NVMe Drive**
*   📝 Create a Docker configuration file: `sudo nano /etc/docker/daemon.json` [55].
*   🎯 Add the following JSON to point Docker's data root to your mounted 4TB drive [55]:
    `{ "data-root": "/mnt/ssd/docker" }`
*   💾 Save the file, create the directory (`sudo mkdir -p /mnt/ssd/docker`), and restart the Docker daemon: `sudo systemctl restart docker` [55].

---

## ☄️ Phase 6: Rocket Pool Smartnode Setup

**1. 📥 Install the CLI**
*   📁 Create a binary directory: `mkdir -p ~/bin` [56].
*   ⬇️ Download the x86_64 Rocket Pool CLI: `wget https://github.com/rocket-pool/smartnode/releases/latest/download/rocketpool-cli-linux-amd64 -O ~/bin/rocketpool` [56].
*   🏃‍♂️ Make it executable: `chmod +x ~/bin/rocketpool`. Check the version with `rocketpool --version` [56].

**2. ⚙️ Install and Configure the Smartnode Services**
*   🏗️ Install the stack: `rocketpool service install`. Type `y` to confirm [57, 58].
*   🔄 Once completed, log out of SSH and log back in [58].
*   🧙‍♂️ Start the configuration wizard: `rocketpool service config` [59].
*   🕸️ **Network:** Select **Hoodi Testnet** [60].
*   🐳 **Client Mode:** Select **Locally Managed** (Docker Mode) [61, 62].
*   🧠 **Execution Client:** Select **Nethermind** [63, 64].
*   🤝 **Consensus Client:** Select **Nimbus** [65, 66].
*   ⏱️ **Checkpoint Sync:** Provide a valid Checkpoint Sync URL for the Hoodi testnet [67].
*   👯 **Doppelganger Protection:** Select **Yes** [68, 69].
*   💾 Save and exit the wizard [70].

**3. 🟢 Start the Node**
*   🚀 Run `rocketpool service start` to launch the containers [71].
*   ⏳ Verify everything is running and Checkpoint Sync was successful: `rocketpool node sync` [72]. Wait for both clients to fully sync before proceeding [73, 74].

---

## 💰 Phase 7: Node Wallet & Validator Setup

**1. 👛 Create the Node Wallet**
*   🔑 Run `rocketpool wallet init` [75]. Securely store the 24-word mnemonic [76].
*   🚰 Fund the new wallet with Hoodi Testnet ETH to cover gas costs [77].

**2. 📝 Register the Node**
*   🌍 Run `rocketpool node register` [78].
*   🗺️ Choose your timezone to map your node globally [79].

**3. 🏦 Set a Secure Primary Withdrawal Address**
*   🥶 **Crucial Step:** Run `rocketpool node set-primary-withdrawal-address` [80, 81].
*   🔐 Enter an address controlled by a cold wallet (like a Ledger or Trezor) to protect your funds if the node is ever compromised [82, 83].

**4. 🥩 Create a Megapool Validator**
*   💸 Run `rocketpool megapool deposit` [84].
*   1️⃣ Select to create 1 validator. The required bond on the testnet will be 4 ETH [85].
*   ⛽ Confirm the gas price, submit the transaction, and wait for confirmation [86]. 
*   🔍 Check its status with `rocketpool megapool validators` [86]. Your validator will progress from `initialized` to `prelaunch` (waiting in the Rocket Pool queue for 28 ETH), and eventually to `active_ongoing` once staking on the Beacon Chain [87-89]. 🎉
