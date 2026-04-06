# Pending Setup Improvements

This file tracks known improvements that are deferred — either because they require hardware not yet available, or because they're optimizations rather than blockers. Work through these after your node is running and validated.

---

## 1. Static IP Reservations
**Priority:** High — do this as soon as you have your final router
**Effort:** 10 min

### Why it matters
The guide currently uses `.local` mDNS hostnames (`pi-jumphost.local`, `rp-node01.local`). These work reliably on most home networks but can fail if:
- Your router doesn't support mDNS forwarding
- Two devices share the same hostname
- You're connecting from a different subnet

Static IPs via DHCP reservation eliminate all of these edge cases.

### How to do it

**Step 1: Find the MAC addresses of both devices**

On the Pi:
```bash
ip link show eth0 | grep "link/ether" | awk '{print $2}'
```

On the node:
```bash
ip link show | grep -A1 "10000" | grep "link/ether" | awk '{print $2}'
```

Or find them in your router's connected devices list.

**Step 2: Set DHCP reservations in your router**

Log into your router admin panel (usually `192.168.1.1` or `192.168.0.1`). Find "DHCP Reservations", "Static Leases", or "Address Reservation" and add:

| Device | MAC Address | Reserved IP |
|---|---|---|
| Raspberry Pi 2 (`pi-jumphost`) | *(from step 1)* | `192.168.1.10` |
| Beelink GTI15 (`rp-node01`) | *(from step 1)* | `192.168.1.20` |

> 💡 **Tip:** Choose IPs outside your router's normal DHCP range. If your router assigns `192.168.1.100–200`, use `192.168.1.10` and `192.168.1.20`.

**Step 3: Update SSH configs to use IPs**

On your Mac (`~/.ssh/config`):
```bash
# Replace .local hostnames with IPs
sed -i '' 's/pi-jumphost.local/192.168.1.10/' ~/.ssh/config
sed -i '' 's/rp-node01.local/192.168.1.20/' ~/.ssh/config
```

On the Pi (`~/.ssh/config`):
```bash
sed -i 's/rp-node01.local/192.168.1.20/' ~/.ssh/config
```

**Step 4: Tighten UFW on the Pi to subnet-only**

Once you know your subnet, restrict SSH to local network only:
```bash
# On the Pi — replace 192.168.1.0/24 with your actual subnet
sudo ufw delete allow 22/tcp
sudo ufw allow from 192.168.1.0/24 to any port 22 comment 'SSH local only'
sudo ufw reload
```

**Step 5: Update the watchdog script**

```bash
# On the Pi — update NODE_HOST in the watchdog
sed -i 's/NODE_HOST="rp-node01"/NODE_HOST="192.168.1.20"/' ~/scripts/node-watchdog.sh
```

**Step 6: Update the steering file**

Update `.kiro/steering/rocketpool-guide.md` to reflect the new IPs so future sessions use them.

---

## 2. Restrict UFW on the Node to Pi-Only SSH
**Priority:** Medium
**Effort:** 5 min

Currently the node allows SSH from any IP on port 22. Once you have static IPs, you can restrict SSH to only accept connections from the Pi's IP:

```bash
# On the node — run after static IPs are set
sudo ufw delete allow 22/tcp
sudo ufw allow from 192.168.1.10 to any port 22 comment 'SSH from Pi jump host only'
sudo ufw reload
```

This means even if someone gets onto your local network, they can't SSH directly to the node — they'd need to compromise the Pi first.

---

## 3. SSH Key Passphrase on the Pi's Node Key
**Priority:** Medium
**Effort:** 5 min

The `rp_node_key` on the Pi currently has a passphrase set interactively. For the watchdog script to run unattended, you need `ssh-agent` running on the Pi so the key is unlocked without prompting.

```bash
# On the Pi — add to ~/.bashrc
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/rp_node_key
```

Or use a systemd user service for a more robust solution:
```bash
# Create ssh-agent service
mkdir -p ~/.config/systemd/user
tee ~/.config/systemd/user/ssh-agent.service > /dev/null <<EOF
[Unit]
Description=SSH key agent

[Service]
Type=simple
Environment=SSH_AUTH_SOCK=%t/ssh-agent.socket
ExecStart=/usr/bin/ssh-agent -D -a $SSH_AUTH_SOCK

[Install]
WantedBy=default.target
EOF

systemctl --user enable ssh-agent
systemctl --user start ssh-agent
```

---

## 4. Grafana External Access (Optional)
**Priority:** Low
**Effort:** 15 min

Currently Grafana is only accessible on your local network at `http://rp-node01.local:3100`. If you want to check your node from outside your home network without a VPN, you can set up a secure tunnel.

Options (in order of security):
1. **Tailscale** — zero-config VPN, free tier covers this use case perfectly. Install on both your Mac and the node, access Grafana via the Tailscale IP.
2. **Cloudflare Tunnel** — expose Grafana via a Cloudflare-managed HTTPS URL with access controls.
3. **WireGuard** — self-hosted VPN, more setup but full control.

> ⚠️ **Warning:** Never expose Grafana directly to the internet without authentication. The default `admin/rocketpool` credentials are well-known.

---

## 5. UPS (Uninterruptible Power Supply)
**Priority:** High for mainnet
**Effort:** Hardware purchase + 30 min config

A power outage while your validator is active causes missed attestations. A UPS gives you:
- Clean shutdown time when power fails
- Protection against power surges

**Recommended approach:**
- Any UPS with USB monitoring support (APC, CyberPower)
- Install `apcupsd` on the node to monitor battery status and trigger graceful shutdown

```bash
sudo apt install apcupsd -y
```

Configure `/etc/apcupsd/apcupsd.conf` with your UPS model and set `BATTERYLEVEL 20` to trigger shutdown at 20% battery.

---

## 6. Automated Node Updates
**Priority:** Medium
**Effort:** 30 min

Currently Smartnode updates are manual. You can automate checking for new versions and alerting via the Pi watchdog:

Add to `~/scripts/node-watchdog.sh` on the Pi:
```bash
# Check for Smartnode updates
CURRENT=$(ssh rp-node01 "rocketpool --version 2>/dev/null | awk '{print \$3}'")
LATEST=$(curl -s https://api.github.com/repos/rocket-pool/smartnode/releases/latest \
  | grep '"tag_name"' | cut -d'"' -f4 | tr -d 'v')
if [ "$CURRENT" != "$LATEST" ]; then
    ISSUES+=("📦 Smartnode update available: v$CURRENT → v$LATEST")
fi
```

---

## 7. Backup Strategy
**Priority:** High for mainnet
**Effort:** 1 hour

Critical items to back up:
- Node wallet mnemonic (already done — paper backup)
- Validator keystore files: `~/.rocketpool/data/validators/`
- Rocket Pool config: `~/.rocketpool/`

Simple backup to an encrypted USB drive:
```bash
# On the node — run monthly
tar -czf /tmp/rp-backup-$(date +%Y%m%d).tar.gz \
  ~/.rocketpool/data/validators/ \
  ~/.rocketpool/*.yml \
  ~/.rocketpool/*.json

# Encrypt with GPG
gpg --symmetric /tmp/rp-backup-$(date +%Y%m%d).tar.gz
```

> 🔴 **Critical:** Never back up validator keystores to cloud storage unencrypted. If your keystore is stolen and used on another machine simultaneously, you will be slashed.

---

## Completion Tracker

| Improvement | Status | Date |
|---|---|---|
| 1. Static IP reservations | ⬜ | |
| 2. Restrict node SSH to Pi-only | ⬜ | |
| 3. SSH agent on Pi | ⬜ | |
| 4. Grafana external access | ⬜ | |
| 5. UPS setup | ⬜ | |
| 6. Automated update alerts | ⬜ | |
| 7. Backup strategy | ⬜ | |

*Status: ⬜ not started · 🔄 in progress · ✅ complete*

---

## 8. flash-jumphost.sh — Known Issues Backlog
**Priority:** Medium — fix before next major release
**Effort:** 1–2 hours total

Issues identified during deep code review. Listed in priority order.

### C1 — Empty MAC_PUBKEY not validated
If `~/.ssh/id_ed25519_<hostname>.pub` is empty or unreadable, the SSH key injection silently writes a blank line to `authorized_keys`. SSH key login will fail with no clear error.
**Fix:** Add before the heredoc: `[ -z "$MAC_PUBKEY" ] && error "SSH public key is empty — cannot continue"`

### C3 — HOSTNAME variable collision
`HOSTNAME` is a reserved bash environment variable. Setting it to the Pi hostname can cause unexpected behavior on some systems.
**Fix:** Rename to `PI_HOSTNAME` throughout the Mac-side script.

### C4 — /boot vs /boot/firmware path assumption
`cmdline.txt` gets `systemd.run=/boot/firmware/firstrun.sh` but on Pi 2 with older firmware the boot path may be `/boot` not `/boot/firmware`.
**Fix:** Add `/boot/firstrun.sh` as a fallback path in cmdline.txt, or detect the correct path from the mounted partition.

### M2 — dd exit code not checked
`pv ... | sudo dd of="$RAW_DEVICE"` — if dd fails, the error is swallowed by the pipe.
**Fix:** Add `|| error "Flash failed — check device and permissions"` after the pipe.

### M3 — sleep 2 fragile mount wait
Fixed `sleep 2` after `diskutil mountDisk` may not be enough on slow systems.
**Fix:** Poll for mount point: `for i in $(seq 1 10); do [ -d "/Volumes/bootfs" ] && break; sleep 1; done`

### M4 — Dead variable
`ORIGINAL_CMDLINE=$(cat "$CMDLINE")` is assigned but never used.
**Fix:** Remove the line.

### M5 — apt-get upgrade can hang
No `DEBIAN_FRONTEND=noninteractive` set — interactive package prompts can stall the script indefinitely.
**Fix:** Add `export DEBIAN_FRONTEND=noninteractive` before all apt calls in firstrun.sh.

### M6 — SSH config appended on re-run
`cat >> ~/.ssh/config` appends on every run. If firstrun.sh runs twice, duplicate entries appear.
**Fix:** Check `grep -q "Host ${NODE_HOSTNAME}" ~/.ssh/config 2>/dev/null` before appending.

### m1 — Duplicate STEP 9 comment
Two `# STEP 9` headers in flash-jumphost.sh. Cosmetic.

### m2 — rpi-imager dependency check is now unused
The script uses `dd` directly. The rpi-imager check is dead code.
**Fix:** Remove the rpi-imager dependency check, or repurpose it.

### m3 — Write-protect check fragile
`diskutil info` output format could change. `awk '{print $NF}'` may return wrong value.
**Fix:** Use `grep -c "Media Read-Only:.*Yes"` instead.

### m4 — No minimum SD card size check
Image is ~1.9GB decompressed. A 1GB card fails mid-write with a cryptic error.
**Fix:** Check `SD_SIZE_BYTES` against minimum before flashing.
