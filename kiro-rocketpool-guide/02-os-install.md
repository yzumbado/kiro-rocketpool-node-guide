# Phase 1: Ubuntu Server 24.04 LTS Installation
⏱ Estimated time: 30 min | 🎯 Difficulty: Easy

> *Why this matters: Ubuntu 24.04.4 LTS ships with kernel 6.17, which has improved support for the Intel Core Ultra 9 285H (Arrow Lake) and better NVMe power management than earlier point releases. This eliminates the backports kernel dance required on Debian 12 — you get working hardware out of the box.*

### Step 1.1: Prepare the Ubuntu USB
🧑 **Human required**

Download **Ubuntu Server 24.04.4 LTS** from `https://ubuntu.com/download/server`. Flash it to a USB drive using Balena Etcher or `dd`.

> 📝 **Note:** Use the Server ISO, not the Desktop ISO. The desktop environment consumes RAM your Ethereum clients need and increases your attack surface.

### Step 1.2: Boot and Install
🧑 **Human required**

Boot the Beelink from the USB. The installer uses a text menu — navigate with arrow keys, `Tab`, and `Enter`.

---

**Step 1.2.1 — Language**

Select `English` (or your preferred language).

---

**Step 1.2.2 — Keyboard Layout**

Select your keyboard layout. If unsure, leave the default — you can change it after install.

---

**Step 1.2.3 — Installation Type**

Select **Install Ubuntu Server** (the first option). The other two options are for MAAS cloud deployments — not relevant here.

---

**Step 1.2.4 — Network**

The Intel 10Gbps ports should be detected immediately. Connect a cable and let DHCP assign an IP. The installer will show the assigned address — note it down.

> 📝 **Note:** If no network is detected, the install can still proceed. You'll configure networking after reboot.

---

**Step 1.2.5 — Storage**

- Select **Use entire disk**
- Select the **1TB built-in NVMe** as the target disk
- **Uncheck** "Set up this disk as an LVM group" — keep the filesystem simple
- Leave the 4TB WD Black completely untouched

> ⚠️ **Warning:** The installer lists drives by device ID and size. Confirm you are selecting the 1TB drive, not the 4TB. When the partition summary appears, verify the device name and size before selecting Done.

On the confirmation screen ("Confirm destructive action"), select **Continue**. There is no undo from this point.

---

**Step 1.2.6 — Third-Party Drivers**

When prompted to search for third-party drivers:
- ✅ **Check this option**

Ubuntu will detect and install Intel firmware packages (microcode, NIC firmware) that can't be shipped by default due to licensing. On Arrow Lake hardware this is a free win — zero risk, potential stability improvement.

---

**Step 1.2.7 — Profile Setup**

This is where you create the system user. Use these values:

| Field | Value | Notes |
|---|---|---|
| Your name | `Node Operator 01` | Display name — cosmetic only |
| Your server's name | `rp-node01` | Hostname — used in logs and SSH prompt |
| Pick a username | `nodeop` | This guide uses `nodeop` throughout |
| Choose a password | *(strong passphrase)* | Use a password manager — this is your sudo password |
| Confirm your password | *(repeat)* | |

> 💡 **Tip:** The hostname `rp-node01` will appear in your terminal prompt (`nodeop@rp-node01`) and in Grafana dashboards. If you plan to run multiple nodes, use a consistent naming scheme (e.g. `rp-node01`, `rp-node02`).

---

**Step 1.2.8 — SSH Key Import (Optional)**

The installer offers to import SSH public keys from GitHub, Launchpad, or Ubuntu One by username. Skip this — we set up SSH keys manually in Phase 2, which gives you more control.

---

**Step 1.2.9 — OpenSSH Server**

When asked about additional software:
- ✅ **Select OpenSSH server** — required for remote management
- ✅ **Allow password authentication over SSH** — the installer forces this on if you want OpenSSH. You cannot uncheck it here.
- Leave all other snaps and packages unchecked

> 📝 **Note:** Password authentication over SSH is a temporary necessity during setup. It will be explicitly disabled in Phase 3 (Step 3.1) once you have key-based login confirmed and working. Do not skip that step.

---

**Step 1.2.10 — Featured Server Snaps**

A list of popular snaps will be offered (Docker, Nextcloud, microk8s, etc.).

- ❌ **Leave everything unchecked**

Docker is installed manually in Phase 5 from the official Docker repository. The snap version is older and doesn't support the custom data-root configuration we need to point chain data at the 4TB drive. Everything else on this list is irrelevant for a Rocket Pool node.

---

**Step 1.2.11 — Installation Progress**

The installer will now copy files and configure the system. This takes 5–10 minutes. No input needed.

When complete, you'll see **"Installation complete!"** — select **Reboot Now** and remove the USB drive when prompted.

### Step 1.3: First Boot
🧑 **Human required**

Remove the USB, reboot, and log in locally as `nodeop`.

### ✅ Phase 1 Verification
🧑 **Human required**

```bash
# Confirm Ubuntu version
lsb_release -a
```

**Expected output:**
```
Description: Ubuntu 24.04.4 LTS
```

```bash
# Confirm kernel version — will show 6.8 on first boot, 6.17 after Step 2.1
uname -r
```

**Expected output after Step 2.1 reboot:**
```
6.17.x-xx-generic
```

> 📝 **Note:** If you run this before completing Step 2.1, you'll see `6.8.0-xxx-generic` — that's normal. Complete Step 2.1 and reboot first.

---

# Phase 2: First Boot Configuration & SSH Handoff
⏱ Estimated time: 15 min | 🎯 Difficulty: Easy

This phase gets the node to the point where Kiro can take over. The goal is simple: working SSH with key-based auth.

### Step 2.1: Set Timezone and Update System

```bash
# Set timezone to UTC — keeps logs consistent with the network
sudo timedatectl set-timezone UTC

# Apply all pending updates
sudo apt update && sudo apt upgrade -y
```

```bash
# Explicitly install the HWE kernel (kernel 6.17) — the installer boots with 6.8 by default
sudo apt install -y linux-generic-hwe-24.04
```

```bash
# Reboot to load the new kernel
sudo reboot
```

After reboot, log back in and verify:

```bash
uname -r
```

**Expected output:**
```
6.17.x-xx-generic
```

> 📝 **Note:** The Ubuntu 24.04.4 installer boots with kernel 6.8 (GA kernel) by default. The HWE kernel 6.17 ships with the point release but must be explicitly installed. On Arrow Lake hardware, 6.17 provides better CPU and NVMe support — this step is not optional.

### Step 2.2: Install Essential Utilities

```bash
# Tools used throughout this guide
sudo apt install -y curl wget git htop iotop net-tools ufw
```

### Step 2.3: Find Your Node's IP Address

```bash
# Note this IP — you'll need it for SSH and to hand off to Kiro
hostname -I
```

Write down the local IP (e.g. `192.168.1.x`).

### Step 2.4: Generate SSH Keys
🧑 **Human required — run this on your PERSONAL COMPUTER, not the node**

```bash
# Generate an Ed25519 key pair — more secure than RSA
ssh-keygen -t ed25519 -C "rocketpool-node"
```

Save to the default location (`~/.ssh/id_ed25519`) and set a strong passphrase.

### Step 2.5: Copy the Public Key to the Node
🧑 **Human required — run this on your PERSONAL COMPUTER**

```bash
# Replace <node-ip> with the IP from Step 2.3
ssh-copy-id nodeop@<node-ip>
```

### Step 2.6: Test SSH Login
🧑 **Human required — run this on your PERSONAL COMPUTER**

```bash
# This should log you in without prompting for a password
ssh nodeop@<node-ip>
```

> 🔴 **Critical:** Confirm this works before proceeding. If SSH login fails, do not continue. Troubleshoot the key copy step before moving on.

### ✅ Phase 2 Verification

```bash
# Run on the node — confirms the baseline state before handoff
echo "=== Node Bootstrap Check ===" && \
lsb_release -d && \
uname -r && \
hostname -I && \
df -h / && \
echo "=== BOOTSTRAP: PASS ==="
```

**Expected output:**
```
=== Node Bootstrap Check ===
Description: Ubuntu 24.04.4 LTS
6.17.x-xx-generic
192.168.1.x
/dev/nvme0n1p2   xxx   xxx   xxx  xx% /
=== BOOTSTRAP: PASS ===
```

> 📝 **Note:** If `uname -r` shows `6.8.x`, the HWE kernel install in Step 2.1 did not complete. Run `sudo apt install -y linux-generic-hwe-24.04 && sudo reboot` and try again.

---

Once SSH is confirmed working, proceed to [HANDOFF.md](./HANDOFF.md).
