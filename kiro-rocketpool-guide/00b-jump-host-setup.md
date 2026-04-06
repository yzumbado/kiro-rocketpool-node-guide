# Jump Host Setup: Raspberry Pi 2
⏱ Estimated time: 60 min | 🎯 Difficulty: Easy

> *Why this matters: Your personal Mac is a general-purpose computer — browser, email, apps, all running simultaneously. Putting your node's SSH private key on it means a compromised Mac is a path to a compromised node. A dedicated jump host solves this: the SSH key to your node lives only on the Pi, and your Mac only ever connects to the Pi. Two separate authentication boundaries instead of one. If your Mac is ever compromised, your node is still safe.*

**The architecture:**

```
Your Mac ──SSH──▶ Raspberry Pi 2 [pi-jumphost] ──SSH──▶ Beelink GTI15 [rp-node01]
         (key)    holds node SSH key + watchdog          Nethermind + Nimbus + RP
```

Your Mac never holds the node's private key. The Pi is the only machine that can reach the node directly. The Pi also runs a lightweight watchdog that alerts you if the node goes unhealthy.

---

## What You Need

| Item | Details |
|---|---|
| Raspberry Pi 2 | Any revision (B, B+) |
| MicroSD card | 16GB+ recommended |
| MicroSD card reader | For flashing from your Mac |
| Ethernet cable | Wired to your router — same network as the node |
| Power supply | Micro USB, 2A+ |
| Raspberry Pi Imager | Free — `https://www.raspberrypi.com/software/` |

> 📝 **Note:** The Pi 2 has no built-in Wi-Fi. Wired Ethernet is required — which is better for a security-focused always-on device anyway. No Wi-Fi means one less attack surface.

---

## OS Choice: Why Raspberry Pi OS Lite (32-bit)

> *Why this matters: The Pi 2 has a 32-bit ARMv7 CPU. It cannot run 64-bit operating systems. This narrows the choice significantly — and that's fine for our use case.*

| Option | Verdict | Reason |
|---|---|---|
| Raspberry Pi OS Lite (32-bit) | ✅ **Use this** | Official, actively maintained, minimal footprint, perfect Pi 2 support |
| Raspberry Pi OS Desktop (32-bit) | ❌ Skip | Desktop wastes RAM on a headless device |
| Ubuntu Server for Pi | ❌ Skip | Drops 32-bit ARM support — won't run on Pi 2 |
| Raspberry Pi OS (64-bit) | ❌ Skip | Pi 2's ARMv7 CPU cannot run 64-bit code |
| Debian Lite | ⚠️ Works | Valid alternative but Raspberry Pi OS has better hardware support out of the box |

Raspberry Pi OS Lite gives us a minimal Debian-based headless server with full Pi 2 hardware support, active security updates, and a tiny RAM footprint — leaving most of the 1GB free for our watchdog scripts.

---

## Static IP: Why Both the Pi and Node Benefit From One

> *This step is optional until you have your final router. The guide uses `.local` hostnames throughout which work without any IP configuration. See [10-pending-improvements.md](./10-pending-improvements.md) for how to add static IPs later when your router is ready.*

If you do have a router that supports DHCP reservations, setting fixed IPs now means your SSH configs and firewall rules never break after a router reboot. See `10-pending-improvements.md` for the full instructions.

---

## Phase 0b.1: Flash Raspberry Pi OS Lite

> *Why this matters: The traditional approach — open Imager GUI, click through options, flash — works fine but requires manual steps you'll repeat if you ever need to rebuild the Pi. The automated path uses `rpi-imager --cli` with a first-run script that hardens the Pi on first boot. You answer a few questions once, and the Pi comes up fully configured.*

### Option A: Automated Flash (Recommended)
🧑 **Human required — run on your Mac**

This is the primary path. A script collects your configuration, confirms it with you, then flashes and injects a hardening script in one shot.

**Install rpi-imager if you don't have it:**
```bash
# Install as a macOS app (it's a cask, not a formula)
brew install --cask raspberry-pi-imager
```

> 📝 **Note:** This installs `Raspberry Pi Imager.app` to your Applications folder. The CLI binary lives inside the app bundle at `/Applications/Raspberry\ Pi\ Imager.app/Contents/MacOS/rpi-imager` — the flash script handles this path automatically.

**Run the flash script:**
```bash
# From the kiro-rocketpool-guide/scripts/ directory
chmod +x flash-jumphost.sh
./flash-jumphost.sh
```

The script will:
1. Ask for hostname, username, password, timezone, IPs, and optional webhook URL
2. Auto-detect or generate your Mac → Pi SSH key
3. List your disks and ask you to identify the SD card
4. Show a full confirmation summary before touching anything
5. Flash Raspberry Pi OS Lite (32-bit) with all settings pre-configured
6. Inject a first-run script that runs on first boot and:
   - Updates all packages
   - Installs ufw, fail2ban, curl, wget
   - Injects your SSH public key
   - Disables password SSH auth
   - Configures UFW (SSH restricted to local subnet)
   - Configures fail2ban (3 retries, 24h ban)
   - Installs the watchdog cron
   - Pre-configures SSH client for `rp-node01`

> ⚠️ **Warning:** When the script asks for the SD card device, use the whole disk (e.g. `/dev/disk4`) not a partition (e.g. `/dev/disk4s1`). The script validates this but double-check — wrong device erases the wrong disk.

> 🤖 **Agent note:** This script is designed to be run interactively with the human present. The agent can guide the human through each prompt but should not attempt to run it autonomously — it requires physical SD card identification and a destructive confirmation.

After the script completes, skip to Phase 0b.2. Phases 0b.4 through 0b.7 are handled automatically by the first-run script on first boot — you only need to verify they completed.

---

### Option B: Manual Flash (Fallback)
🧑 **Human required**

Use this if the automated script fails or if you prefer the GUI.

Download and install **Raspberry Pi Imager** on your Mac from `https://www.raspberrypi.com/software/`.

Open Imager and configure:

1. **Device:** Raspberry Pi 2
2. **OS:** Raspberry Pi OS (other) → **Raspberry Pi OS Lite (32-bit)**
3. **Storage:** Your MicroSD card

Before writing, click the **gear icon (⚙️)** to open advanced options and pre-configure:

| Setting | Value | Reason |
|---|---|---|
| Hostname | `pi-jumphost` | Identifies the Pi on your network |
| Enable SSH | ✅ Password authentication | Needed for first login — disabled later |
| Username | `piop` | Dedicated operator user — not the default `pi` |
| Password | *(strong passphrase)* | Temporary — key-only auth replaces this in Phase 0b.7 |
| Locale / timezone | UTC | Consistent with the node |
| Wi-Fi | ❌ Leave blank | Wired only |

Click **Write** and wait for the flash to complete (~3 min).

If using Option B, you must complete Phases 0b.4 through 0b.7 manually after first boot.

---

## Phase 0b.2: First Boot and Verification
🧑 **Human required**

1. Insert the MicroSD into the Pi 2
2. Connect Ethernet to your router
3. Power on

**If you used Option A (automated script):** Wait ~3 minutes for first boot, then an additional ~5 minutes for the first-run hardening script to complete. The Pi will be fully configured when it's done.

**If you used Option B (manual):** Wait ~90 seconds for first boot only. You'll complete hardening manually in Phase 0b.7.

Verify the Pi is reachable using its hostname:

```bash
# Run on your Mac
ping -c 3 pi-jumphost.local
```

**Expected output:**
```
PING pi-jumphost.local: 56 data bytes
64 bytes from pi-jumphost.local: icmp_seq=0 ttl=64
```

> 📝 **Note:** If using Option A, wait the full ~8 minutes before trying to SSH in. The first-run script disables password auth — if you connect too early (before the script finishes), you may get locked out temporarily. If that happens, wait and retry.

---

## Phase 0b.3: Initial SSH Login
🧑 **Human required — run on your Mac**

**If you used Option A (automated script):**
```bash
# Key-based login — no password needed, key was injected during flash
ssh -i ~/.ssh/id_ed25519_jumphost piop@pi-jumphost.local
```

**If you used Option B (manual):**
```bash
# Password login for first access
ssh piop@pi-jumphost.local
```

Accept the host key fingerprint when prompted. You're now on the Pi.

**If using Option A, verify the first-run script completed successfully:**
```bash
# Check the first-run log
cat /var/log/firstrun.log | tail -5
```

**Expected last line:**
```
=== First-run hardening complete: [timestamp] ===
```

If you see this, Phases 0b.4 through 0b.7 are already done. Skip directly to Phase 0b.5 to generate the node SSH key.

---

## Phase 0b.4: Update the System
🧑 **Human required — run on the Pi**

> 📝 **Note:** The Pi 2 is slow. `apt upgrade` may take 5–10 minutes. This is normal.

```bash
# Update all packages
sudo apt update && sudo apt upgrade -y

# Install tools used throughout this guide
sudo apt install -y ufw fail2ban curl wget
```

```bash
# Reboot to apply any kernel updates
sudo reboot
```

Reconnect after reboot:
```bash
ssh piop@pi-jumphost.local
```

### ✅ Phase 0b.4 Verification

```bash
# Confirm OS and connectivity
lsb_release -d && echo "PASS: OS confirmed" || echo "FAIL"
ping -c 1 8.8.8.8 > /dev/null && echo "PASS: Internet reachable" || echo "FAIL: No internet"
```

---

## Phase 0b.5: Generate the Node SSH Key
🧑 **Human required — run on the Pi**

> *Why this matters: This key authenticates the Pi to your node. Generating it on the Pi means it never exists on your Mac. The passphrase protects it if the Pi's SD card is ever physically removed.*

```bash
# Generate Ed25519 key pair — stored only on the Pi
ssh-keygen -t ed25519 -C "rp-node01-access" -f ~/.ssh/rp_node_key
```

Set a strong passphrase when prompted.

```bash
# Display the public key — copy this for use in the main guide Step 2.5
cat ~/.ssh/rp_node_key.pub
```

> 📝 **Note:** When the main guide (Step 2.5) says to run `ssh-copy-id` from your "personal computer", run it from the Pi instead, using this key:
> ```bash
> ssh-copy-id -i ~/.ssh/rp_node_key.pub nodeop@rp-node01.local
> ```

---

## Phase 0b.6: Configure SSH Client on the Pi
🧑 **Human required — run on the Pi**

```bash
# Create SSH client config for clean one-command node access
tee ~/.ssh/config > /dev/null <<EOF
Host rp-node01
    HostName rp-node01.local
    User nodeop
    IdentityFile ~/.ssh/rp_node_key
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF

chmod 600 ~/.ssh/config
```

Test the connection (only after completing Phase 2 of the main guide):
```bash
ssh rp-node01
```

---

## Phase 0b.7: Harden the Pi
> *Why this matters: The Pi is your security perimeter. A poorly secured jump host is worse than no jump host — it becomes a pivot point. We apply the same hardening model as the node, with stricter settings where appropriate.*

### Step 0b.7.1: Generate Mac → Pi SSH Key
🧑 **Human required — run on your Mac**

```bash
# Separate key for Mac → Pi access only
ssh-keygen -t ed25519 -C "mac-to-jumphost" -f ~/.ssh/id_ed25519_jumphost
```

```bash
# Copy to the Pi
ssh-copy-id -i ~/.ssh/id_ed25519_jumphost.pub piop@pi-jumphost.local
```

```bash
# Verify key-based login works before proceeding
ssh -i ~/.ssh/id_ed25519_jumphost piop@pi-jumphost.local echo "PASS: key login works"
```

> 🔴 **Critical:** Confirm this returns "PASS" before continuing. The next step disables password auth. If key login isn't working, you will lock yourself out.

### Step 0b.7.2: Disable Password Authentication
🧑 **Human required — run on the Pi**

```bash
# Back up original config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Disable password auth — key-only from here
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config
grep -q "^AllowUsers" /etc/ssh/sshd_config || echo "AllowUsers piop" | sudo tee -a /etc/ssh/sshd_config
```

```bash
# Validate before applying
sudo sshd -t && echo "PASS: config valid" || echo "FAIL: fix errors first"
```

```bash
sudo systemctl restart ssh
```

### Step 0b.7.3: Configure UFW Firewall
🧑 **Human required — run on the Pi**

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH from local network — mDNS works on the local subnet
sudo ufw allow 22/tcp comment 'SSH local network only'

sudo ufw --force enable
```

### Step 0b.7.4: Configure Fail2ban
🧑 **Human required — run on the Pi**

```bash
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

sudo tee /etc/fail2ban/jail.d/sshd.local > /dev/null <<EOF
[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
maxretry = 3
bantime = 24h
EOF

sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

> 📝 **Note:** `bantime = 24h` is stricter than the node's `1h`. The Pi is the front door — we're more aggressive here.

### ✅ Phase 0b.7 Verification

```bash
# Run on the Pi
echo "--- SSH config ---" && sudo sshd -t && echo "PASS" || echo "FAIL"
echo "--- Firewall ---" && sudo ufw status | grep -q "Status: active" && echo "PASS" || echo "FAIL"
echo "--- Fail2ban ---" && sudo systemctl is-active fail2ban && echo "PASS" || echo "FAIL"
```

```bash
# Run on your Mac — confirm key-only login still works
ssh -i ~/.ssh/id_ed25519_jumphost piop@pi-jumphost.local echo "PASS: Mac to Pi works"
```

---

## Phase 0b.8: Mac SSH Config
🧑 **Human required — run on your Mac**

```bash
tee -a ~/.ssh/config > /dev/null <<EOF

# Jump host
Host jumphost
    HostName pi-jumphost.local
    User piop
    IdentityFile ~/.ssh/id_ed25519_jumphost
    ServerAliveInterval 60

# Node via jump host — one command, two hops
Host rp-node01
    HostName rp-node01.local
    User nodeop
    ProxyJump jumphost
    IdentityFile /dev/null
EOF
```

From your Mac you now have:
- `ssh jumphost` — connects to the Pi
- `ssh rp-node01` — connects to the node through the Pi in one command

---

## Phase 0b.9: Node Watchdog
🧑 **Human required — run on the Pi**

> *Why this matters: The Pi is always on and has SSH access to the node. That makes it the natural place to run health checks. A simple cron script that runs every 15 minutes and alerts you via webhook costs almost nothing on the Pi 2 and means you find out about problems before your attestation rate drops.*

### Step 0b.9.1: Create the Watchdog Script

```bash
mkdir -p ~/scripts

tee ~/scripts/node-watchdog.sh > /dev/null <<'EOF'
#!/bin/bash

# Node watchdog — runs on Pi, checks node health, alerts via webhook
# Configure these:
NODE_HOST="rp-node01"
WEBHOOK_URL="https://discord.com/api/webhooks/YOUR_WEBHOOK_URL"
ALERT_COOLDOWN=3600  # seconds between repeat alerts for same issue

ALERT_FILE="/tmp/watchdog_last_alert"
ISSUES=()

# Check 1: SSH reachable
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$NODE_HOST" exit 2>/dev/null; then
    ISSUES+=("🔴 Node SSH unreachable")
fi

# Check 2: Docker containers running (only if SSH works)
if [ ${#ISSUES[@]} -eq 0 ]; then
    CONTAINER_COUNT=$(ssh "$NODE_HOST" "docker ps | grep -c rocketpool" 2>/dev/null)
    if [ "${CONTAINER_COUNT:-0}" -lt 5 ]; then
        ISSUES+=("⚠️ Only $CONTAINER_COUNT/5+ Rocket Pool containers running")
    fi
fi

# Check 3: Disk space on node
if [ ${#ISSUES[@]} -eq 0 ]; then
    DISK_USED=$(ssh "$NODE_HOST" "df /mnt/ssd | awk 'NR==2{print \$5}' | tr -d '%'" 2>/dev/null)
    if [ "${DISK_USED:-0}" -gt 85 ]; then
        ISSUES+=("⚠️ Node disk at ${DISK_USED}% — action needed soon")
    fi
fi

# Send alert if issues found
if [ ${#ISSUES[@]} -gt 0 ]; then
    # Check cooldown to avoid alert spam
    LAST_ALERT=$(cat "$ALERT_FILE" 2>/dev/null || echo 0)
    NOW=$(date +%s)
    if [ $((NOW - LAST_ALERT)) -gt $ALERT_COOLDOWN ]; then
        MESSAGE="**rp-node01 Alert** $(date)\n$(printf '%s\n' "${ISSUES[@]}")"
        curl -s -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"content\": \"$MESSAGE\"}" > /dev/null
        echo "$NOW" > "$ALERT_FILE"
    fi
fi
EOF

chmod +x ~/scripts/node-watchdog.sh
```

### Step 0b.9.2: Configure Your Webhook

Edit the script and replace `YOUR_WEBHOOK_URL` with your actual webhook:

```bash
nano ~/scripts/node-watchdog.sh
```

**To get a Discord webhook:**
1. Open Discord → Server Settings → Integrations → Webhooks
2. Create a new webhook, copy the URL
3. Paste it as `WEBHOOK_URL` in the script

**To use a different service:** Replace the `curl` command with any webhook-compatible service (Telegram, Slack, PagerDuty all work the same way).

### Step 0b.9.3: Test the Watchdog

```bash
# Run manually first to confirm it works
~/scripts/node-watchdog.sh
echo "Exit code: $?"
```

If the node is healthy, no alert is sent and the script exits silently. To test alerting, temporarily set `CONTAINER_COUNT` threshold to 99 in the script.

### Step 0b.9.4: Schedule with Cron

```bash
# Run watchdog every 15 minutes
(crontab -l 2>/dev/null; echo "*/15 * * * * /home/piop/scripts/node-watchdog.sh >> /home/piop/scripts/watchdog.log 2>&1") | crontab -
```

```bash
# Verify cron entry
crontab -l
```

**Expected output:**
```
*/15 * * * * /home/piop/scripts/node-watchdog.sh >> /home/piop/scripts/watchdog.log 2>&1
```

---

## ✅ Final Phase 0b Verification

```bash
# Run on the Pi — full jump host health check
echo "=== Jump Host Health Check ===" && \
echo -n "SSH config: " && sudo sshd -t && echo "PASS" || echo "FAIL" && \
echo -n "Firewall: " && sudo ufw status | grep -q "Status: active" && echo "PASS" || echo "FAIL" && \
echo -n "Fail2ban: " && sudo systemctl is-active fail2ban && echo "PASS" || echo "FAIL" && \
echo -n "Node key: " && test -f ~/.ssh/rp_node_key && echo "PASS" || echo "FAIL" && \
echo -n "Watchdog cron: " && crontab -l | grep -q "node-watchdog" && echo "PASS" || echo "FAIL" && \
echo "=== END ==="
```

```bash
# Run on your Mac — test both SSH hops
ssh jumphost echo "PASS: Mac → Pi" && \
ssh rp-node01 echo "PASS: Mac → Node via Pi"
```

**All checks must pass before proceeding to Phase 1 of the main guide.**

---

## Final Architecture

```
Your Mac
  │
  │  ssh jumphost  (~/.ssh/id_ed25519_jumphost)
  ▼
Raspberry Pi 2  [pi-jumphost.local]
  ├── Holds rp_node_key (never on Mac)
  ├── Watchdog cron every 15min → Discord/webhook alerts
  │
  │  ssh rp-node01  (~/.ssh/rp_node_key)
  ▼
Beelink GTI15  [rp-node01.local]
  └── Nethermind + Nimbus + Rocket Pool
```
