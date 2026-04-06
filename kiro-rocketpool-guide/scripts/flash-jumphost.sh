#!/bin/bash
# =============================================================================
# flash-jumphost.sh
# Raspberry Pi 2 Jump Host — Automated SD Card Flash
#
# Run this script on your Mac. It will:
#   1. Collect required configuration from you
#   2. Auto-detect what it can from your system
#   3. Show a confirmation summary before touching anything
#   4. Flash Raspberry Pi OS Lite (32-bit) to your SD card
#   5. Inject a first-run script that hardens the Pi on first boot
#
# Requirements:
#   - rpi-imager installed: brew install rpi-imager
#   - SD card inserted in your Mac
#   - Your SSH public key at ~/.ssh/id_ed25519_jumphost.pub
#     (if it doesn't exist, this script will generate it)
#
# Usage:
#   chmod +x flash-jumphost.sh
#   ./flash-jumphost.sh
# =============================================================================

set -euo pipefail

# Clean up any leftover temp files from previous runs
rm -f /tmp/pi-firstrun-*.sh 2>/dev/null || true

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "  ${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "  ${GREEN}✅ $1${NC}"; }
warn()    { echo -e "  ${YELLOW}⚠️  $1${NC}"; }
error()   { echo -e "  ${RED}❌ $1${NC}"; exit 1; }
ask()     { echo -e "  ${YELLOW}❓ $1${NC}"; }

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  🚀 Rocket Pool Jump Host Flash Tool             ║"
echo "║  Raspberry Pi 2 · Raspberry Pi OS Lite 32-bit   ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# STEP 1: Check dependencies
# =============================================================================
info "Checking dependencies..."

if ! command -v rpi-imager &>/dev/null; then
    # Check if installed as macOS app but not in PATH
    RPI_IMAGER_BIN="/Applications/Raspberry Pi Imager.app/Contents/MacOS/rpi-imager"
    if [ -f "$RPI_IMAGER_BIN" ]; then
        success "rpi-imager found at app bundle path"
        # Create a local alias for the rest of the script
        alias rpi-imager="\"$RPI_IMAGER_BIN\""
        RPI_IMAGER_CMD="$RPI_IMAGER_BIN"
    else
        error "rpi-imager not found. Install it with: brew install --cask raspberry-pi-imager"
    fi
else
    RPI_IMAGER_CMD="rpi-imager"
fi
success "rpi-imager ready"

if ! command -v diskutil &>/dev/null; then
    error "diskutil not found — this script requires macOS."
fi

# pv is required for progress display — auto-install if missing
if ! command -v pv &>/dev/null; then
    info "Installing pv (required for flash progress bar)..."
    if command -v brew &>/dev/null; then
        brew install pv
    else
        error "pv is not installed and Homebrew is not available. Install pv manually: brew install pv"
    fi
fi
success "pv ready"

# =============================================================================
# STEP 2: Collect configuration
# =============================================================================
echo ""
info "Collecting configuration..."
echo ""

# --- Hostname ---
DEFAULT_HOSTNAME="pi-jumphost"
ask "Pi hostname [default: ${DEFAULT_HOSTNAME}]:"
read -r INPUT_HOSTNAME
HOSTNAME="${INPUT_HOSTNAME:-$DEFAULT_HOSTNAME}"

# --- Username ---
DEFAULT_USERNAME="piop"
ask "Pi username [default: ${DEFAULT_USERNAME}]:"
read -r INPUT_USERNAME
PI_USER="${INPUT_USERNAME:-$DEFAULT_USERNAME}"

# --- Password ---
ask "Pi password (used only until SSH keys are set up):"
read -rs PI_PASSWORD
echo ""
if [ -z "$PI_PASSWORD" ]; then
    error "Password cannot be empty."
fi

# --- Timezone ---
DEFAULT_TZ="UTC"
ask "Timezone [default: ${DEFAULT_TZ}]:"
read -r INPUT_TZ
TIMEZONE="${INPUT_TZ:-$DEFAULT_TZ}"

# --- Pi static IP (optional — skip if no final router yet) ---
echo ""
info "Static IPs are optional. Press Enter to skip and use .local hostnames instead."
ask "Pi static IP for DHCP reservation (or press Enter to skip):"
read -r INPUT_PI_IP
PI_IP="${INPUT_PI_IP:-}"

# --- Node hostname ---
DEFAULT_NODE_HOSTNAME="rp-node01"
ask "Node (Beelink) hostname [default: ${DEFAULT_NODE_HOSTNAME}]:"
read -r INPUT_NODE_HOSTNAME
NODE_HOSTNAME="${INPUT_NODE_HOSTNAME:-$DEFAULT_NODE_HOSTNAME}"

ask "Node (Beelink) static IP for DHCP reservation (or press Enter to skip):"
read -r INPUT_NODE_IP
NODE_IP="${INPUT_NODE_IP:-}"

# Determine hostnames to use in SSH config
PI_HOST="${PI_IP:-${HOSTNAME}.local}"
NODE_HOST="${NODE_IP:-${NODE_HOSTNAME}.local}"

# --- Discord webhook (optional) ---
ask "Discord webhook URL for watchdog alerts (press Enter to skip):"
read -r WEBHOOK_URL

# =============================================================================
# STEP 3: SSH key — generate if needed
# =============================================================================
echo ""
info "Checking SSH keys..."

JUMPHOST_KEY="$HOME/.ssh/id_ed25519_${HOSTNAME}"
JUMPHOST_PUB="${JUMPHOST_KEY}.pub"

if [ ! -f "$JUMPHOST_PUB" ]; then
    info "Generating new Ed25519 key pair for Mac → Pi access..."
    ssh-keygen -t ed25519 -C "mac-to-${HOSTNAME}" -f "$JUMPHOST_KEY" -N ""
    success "Key generated: ${JUMPHOST_PUB}"
else
    success "Found existing key: ${JUMPHOST_PUB}"
fi

MAC_PUBKEY=$(cat "$JUMPHOST_PUB")

# =============================================================================
# STEP 4: Detect SD card
# =============================================================================
echo ""
info "Detecting SD card..."
echo ""
echo "Current disks on your system:"
echo "-------------------------------"
diskutil list | grep -E "^/dev/disk|external|SD|SDXC|SDHC|FAT|DOS" || diskutil list
echo "-------------------------------"
echo ""

ask "Enter the SD card device (e.g. /dev/disk4 — NOT a partition like /dev/disk4s1):"
read -r SD_DEVICE

if [ -z "$SD_DEVICE" ]; then
    error "No device specified."
fi

if [[ "$SD_DEVICE" =~ s[0-9]+$ ]]; then
    error "You specified a partition (${SD_DEVICE}). Use the whole disk (e.g. /dev/disk4)."
fi

if ! diskutil info "$SD_DEVICE" &>/dev/null; then
    error "Device ${SD_DEVICE} not found."
fi

# Verify card is not write-protected before proceeding
WRITE_PROTECTED=$(diskutil info "$SD_DEVICE" | grep "Media Read-Only" | awk '{print $NF}')
if [ "$WRITE_PROTECTED" = "Yes" ]; then
    error "The SD card at ${SD_DEVICE} is write-protected (Media Read-Only: Yes).
    This can happen if:
    - The card's physical lock switch is engaged (check the SD adapter)
    - A previous failed write corrupted the card's controller
    - The card is damaged or low quality
    Try a different card. Recommended: Samsung PRO Endurance or SanDisk Endurance."
fi

SD_SIZE=$(diskutil info "$SD_DEVICE" | grep "Disk Size" | awk '{print $3, $4}')
SD_NAME=$(diskutil info "$SD_DEVICE" | grep "Media Name" | cut -d: -f2 | xargs)

# =============================================================================
# STEP 5: Build the first-run hardening script
# =============================================================================
FIRSTRUN_SCRIPT=$(mktemp /tmp/pi-firstrun-XXXXXX.sh)

cat > "$FIRSTRUN_SCRIPT" << FIRSTRUN
#!/bin/bash
# First-run hardening script — injected by flash-jumphost.sh
# Runs once on first boot as root, then deletes itself
# Logs to /var/log/firstrun.log AND /boot/firmware/firstrun-debug.log (readable from Mac)

# Enable verbose logging for debugging — do NOT use set -e (causes silent exits)
set -x

# Dual logging — both to system log and to boot partition (readable from Mac without booting)
SYSLOG="/var/log/firstrun.log"
BOOTLOG="/boot/firmware/firstrun-debug.log"
STATUSFILE="/boot/firmware/firstrun-status.txt"

log_step() {
    echo "[\$(date '+%H:%M:%S')] STEP: \$1" | tee -a "\$SYSLOG" "\$BOOTLOG"
    echo "STEP: \$1 [\$(date)]" > "\$STATUSFILE"
}

exec > >(tee -a "\$SYSLOG" "\$BOOTLOG") 2>&1
echo "STARTED [\$(date)]" > "\$STATUSFILE"
echo "=== First-run hardening started: \$(date) ===" | tee "\$BOOTLOG"

# FIX 2: Ensure user exists before any user-dependent operations
# userconf.txt creates the user during the Pi OS wizard which may not have run yet
log_step "ensure user exists"
id -u ${PI_USER} &>/dev/null || useradd -m -s /bin/bash ${PI_USER}

# FIX 1: Wait for network before any apt calls
# systemd.run= fires before networking is fully up on Pi 2
log_step "wait for network"
for i in \$(seq 1 30); do
    ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 && break
    echo "Waiting for network... attempt \$i/30"
    sleep 5
done
ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 || {
    echo "FAILED: no network after 150s" > "\$STATUSFILE"
    echo "ERROR: Network not available — apt installs will fail. Rebooting to retry."
    /sbin/reboot -f
}

log_step "apt-get update"
apt-get update -y

log_step "apt-get upgrade"
apt-get upgrade -y

log_step "install packages"
apt-get install -y ufw fail2ban curl wget

# FIX 4: Verify packages installed — abort clearly if not
for pkg in ufw fail2ban curl wget; do
    dpkg -l "\$pkg" 2>/dev/null | grep -q "^ii" || {
        echo "FAILED: package \$pkg did not install" > "\$STATUSFILE"
        echo "ERROR: \$pkg failed to install — check network and retry"
        /sbin/reboot -f
    }
done

# FIX 3: Set timezone without systemd (timedatectl requires D-Bus which isn't up yet)
log_step "set timezone"
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
echo "${TIMEZONE}" > /etc/timezone

# Install SSH public key for Mac → Pi access
log_step "install SSH public key"
mkdir -p /home/${PI_USER}/.ssh
chmod 700 /home/${PI_USER}/.ssh
echo "${MAC_PUBKEY}" >> /home/${PI_USER}/.ssh/authorized_keys
chmod 600 /home/${PI_USER}/.ssh/authorized_keys
chown -R ${PI_USER}:${PI_USER} /home/${PI_USER}/.ssh

# Harden SSH daemon
log_step "harden SSH daemon"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config
grep -q "^AllowUsers" /etc/ssh/sshd_config || echo "AllowUsers ${PI_USER}" >> /etc/ssh/sshd_config

# Configure UFW — allow SSH on local network
log_step "configure UFW"
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH local network only'
ufw --force enable

# Configure fail2ban
log_step "configure fail2ban"
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
cat > /etc/fail2ban/jail.d/sshd.local << 'EOF'
[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
maxretry = 3
bantime = 24h
EOF
# FIX 3: Guard systemctl calls — D-Bus may not be available at this stage
systemctl enable fail2ban 2>/dev/null || update-rc.d fail2ban defaults 2>/dev/null || true
systemctl start fail2ban 2>/dev/null || true

# Create scripts directory and watchdog
log_step "create watchdog script"
mkdir -p /home/${PI_USER}/scripts

cat > /home/${PI_USER}/scripts/node-watchdog.sh << WATCHDOG
#!/bin/bash
NODE_HOST="${NODE_HOSTNAME}"
WEBHOOK_URL="${WEBHOOK_URL}"
ALERT_COOLDOWN=3600
ALERT_FILE="/tmp/watchdog_last_alert"
ISSUES=()

if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "\$NODE_HOST" exit 2>/dev/null; then
    ISSUES+=("Node SSH unreachable")
fi

if [ \${#ISSUES[@]} -eq 0 ]; then
    CONTAINER_COUNT=\$(ssh "\$NODE_HOST" "docker ps | grep -c rocketpool" 2>/dev/null)
    if [ "\${CONTAINER_COUNT:-0}" -lt 5 ]; then
        ISSUES+=("Only \$CONTAINER_COUNT/5+ Rocket Pool containers running")
    fi
fi

if [ \${#ISSUES[@]} -eq 0 ]; then
    DISK_USED=\$(ssh "\$NODE_HOST" "df /mnt/ssd | awk 'NR==2{print \\\$5}' | tr -d '%'" 2>/dev/null)
    if [ "\${DISK_USED:-0}" -gt 85 ]; then
        ISSUES+=("Node disk at \${DISK_USED}% — action needed")
    fi
fi

if [ \${#ISSUES[@]} -gt 0 ] && [ -n "\$WEBHOOK_URL" ]; then
    LAST_ALERT=\$(cat "\$ALERT_FILE" 2>/dev/null || echo 0)
    NOW=\$(date +%s)
    if [ \$((NOW - LAST_ALERT)) -gt \$ALERT_COOLDOWN ]; then
        MESSAGE="rp-node01 Alert \$(date): \$(printf '%s ' "\${ISSUES[@]}")"
        curl -s -X POST "\$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"content\": \"\$MESSAGE\"}" > /dev/null
        echo "\$NOW" > "\$ALERT_FILE"
    fi
fi
WATCHDOG

chmod +x /home/${PI_USER}/scripts/node-watchdog.sh
chown -R ${PI_USER}:${PI_USER} /home/${PI_USER}/scripts

# Schedule watchdog cron
(crontab -u ${PI_USER} -l 2>/dev/null; \
  echo "*/15 * * * * /home/${PI_USER}/scripts/node-watchdog.sh >> /home/${PI_USER}/scripts/watchdog.log 2>&1") \
  | crontab -u ${PI_USER} -

log_step "configure SSH client"
mkdir -p /home/${PI_USER}/.ssh
cat >> /home/${PI_USER}/.ssh/config << EOF
Host ${NODE_HOSTNAME}
    HostName ${NODE_HOST}
    User nodeop
    IdentityFile /home/${PI_USER}/.ssh/rp_node_key
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
chmod 600 /home/${PI_USER}/.ssh/config
chown ${PI_USER}:${PI_USER} /home/${PI_USER}/.ssh/config

log_step "complete"
echo "=== First-run hardening complete: \$(date) ===" | tee -a "\$BOOTLOG"
echo "COMPLETE [\$(date)]" > "\$STATUSFILE"
echo "NOTE: Generate the node SSH key manually after first login:"
echo "  ssh-keygen -t ed25519 -C 'rp-node01-access' -f ~/.ssh/rp_node_key"

# FIX 5: Use direct kernel reboot — systemd bus not available at this stage
rm -f "\$0"
/sbin/reboot -f
FIRSTRUN

chmod +x "$FIRSTRUN_SCRIPT"

# =============================================================================
# STEP 6: Confirmation summary
# =============================================================================
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║           CONFIGURATION SUMMARY                 ║"
echo "╠══════════════════════════════════════════════════╣"
printf "║  🖥️  %-12s  %-30s║\n" "Pi hostname"  "$HOSTNAME"
printf "║  👤 %-12s  %-30s║\n" "Pi username"  "$PI_USER"
printf "║  🌍 %-12s  %-30s║\n" "Timezone"     "$TIMEZONE"
printf "║  🌐 %-12s  %-30s║\n" "Pi address"   "${PI_IP:-${HOSTNAME}.local}"
printf "║  🌐 %-12s  %-30s║\n" "Node address" "${NODE_IP:-${NODE_HOSTNAME}.local}"
printf "║  🔑 %-12s  %-30s║\n" "SSH key"      "~/.ssh/id_ed25519_${HOSTNAME}"
printf "║  🔔 %-12s  %-30s║\n" "Webhook"      "${WEBHOOK_URL:-[not set]}"
echo "╠══════════════════════════════════════════════════╣"
printf "║  💾 %-12s  %-30s║\n" "Target"       "$SD_DEVICE"
printf "║  📦 %-12s  %-30s║\n" "Device"       "$SD_NAME"
printf "║  📏 %-12s  %-30s║\n" "Size"         "$SD_SIZE"
echo "╠══════════════════════════════════════════════════╣"
echo "║  First-run script will:                         ║"
echo "║    ✓ Update all packages                        ║"
echo "║    ✓ Install ufw, fail2ban, curl, wget          ║"
echo "║    ✓ Inject your SSH public key                 ║"
echo "║    ✓ Disable password SSH auth                  ║"
echo "║    ✓ Configure UFW + fail2ban                   ║"
echo "║    ✓ Install watchdog cron (every 15 min)       ║"
echo "║    ✓ Pre-configure SSH client for node          ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
warn "THIS WILL ERASE ALL DATA ON $SD_DEVICE ($SD_NAME)"
echo ""
ask "Type YES to confirm and flash, anything else to cancel:"
read -r CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    info "Cancelled. No changes made."
    rm -f "$FIRSTRUN_SCRIPT"
    exit 0
fi

# =============================================================================
# STEP 7: Download OS image
# =============================================================================
echo ""
info "Checking Raspberry Pi OS Lite (32-bit) image..."

OS_URL="https://downloads.raspberrypi.com/raspios_lite_armhf/images/raspios_lite_armhf-2025-05-13/2025-05-13-raspios-bookworm-armhf-lite.img.xz"
# SHA256 from official Raspberry Pi downloads page
OS_SHA256="a73d68b618c3ca40190c1aa04005a4dafcf32bc861c36c0d1fc6ddc48a370b6e"

# Persistent cache — survives reboots unlike /tmp
CACHE_DIR="$HOME/.cache/kiro-rocketpool"
OS_IMAGE="$CACHE_DIR/raspios-lite-armhf.img.xz"
mkdir -p "$CACHE_DIR"

download_image() {
    info "Downloading Raspberry Pi OS Lite (32-bit) — ~500MB..."
    curl -L --progress-bar "$OS_URL" -o "$OS_IMAGE"
    success "Download complete — cached at $OS_IMAGE"
}

verify_image() {
    info "Verifying SHA256 checksum..."
    ACTUAL_SHA=$(shasum -a 256 "$OS_IMAGE" | awk '{print $1}')
    if [ "$ACTUAL_SHA" = "$OS_SHA256" ]; then
        success "SHA256 verified"
        return 0
    else
        warn "SHA256 mismatch — image may be corrupt or outdated"
        warn "Expected: $OS_SHA256"
        warn "Got:      $ACTUAL_SHA"
        return 1
    fi
}

if [ -f "$OS_IMAGE" ]; then
    info "Found cached image: $OS_IMAGE ($(du -sh "$OS_IMAGE" | cut -f1))"
    if ! verify_image; then
        warn "Cached image failed verification — re-downloading..."
        rm -f "$OS_IMAGE"
        download_image
        verify_image || error "Downloaded image failed SHA256 verification. Check your internet connection or update the OS_SHA256 in the script."
    fi
else
    download_image
    verify_image || error "Downloaded image failed SHA256 verification. Check your internet connection or update the OS_SHA256 in the script."
fi

# =============================================================================
# STEP 8: Flash
# =============================================================================
echo ""
info "Unmounting $SD_DEVICE before flash..."
diskutil unmountDisk "$SD_DEVICE" || true

RAW_DEVICE="${SD_DEVICE/disk/rdisk}"

# Disable macOS auto-mount to prevent it ejecting the card mid-write
# A mid-write eject at 37% was the root cause of the previous card failure
info "Disabling macOS auto-mount during flash (will re-enable after)..."
sudo defaults write /Library/Preferences/SystemConfiguration/autodiskmount \
    AutomountDisksWithoutUserApproval -bool false

# Ensure card is still unmounted
diskutil unmountDisk "$SD_DEVICE" 2>/dev/null || true

info "Flashing $RAW_DEVICE using dd — this takes 3–8 minutes..."
echo ""

# Decompress image if needed
OS_IMG="${OS_IMAGE%.xz}"
if [ ! -f "$OS_IMG" ]; then
    info "Decompressing image..."
    xz -dk "$OS_IMAGE"
    success "Decompressed to $OS_IMG"
fi

# Write image with dd — use pv for progress bar if available
IMAGE_SIZE=$(stat -f%z "$OS_IMG")
IMAGE_SIZE_MB=$((IMAGE_SIZE / 1024 / 1024))
info "Image size: ${IMAGE_SIZE_MB}MB"

if command -v pv &>/dev/null; then
    pv -s "$IMAGE_SIZE" -N "  🚀 Flashing SD card" "$OS_IMG" | sudo dd of="$RAW_DEVICE" bs=4m
else
    info "Progress updates every 5 seconds..."
    sudo dd if="$OS_IMG" of="$RAW_DEVICE" bs=4m status=progress
fi
sync
success "Image written"

# Re-enable macOS auto-mount
info "Re-enabling macOS auto-mount..."
sudo defaults delete /Library/Preferences/SystemConfiguration/autodiskmount \
    AutomountDisksWithoutUserApproval 2>/dev/null || true

# Re-mount to inject first-run script
info "Mounting boot partition to inject configuration files..."
sleep 2
diskutil mountDisk "$SD_DEVICE" || true
sleep 2

# Find the boot partition (FAT32, named 'bootfs' or 'boot')
BOOT_MOUNT=$(diskutil list "$SD_DEVICE" | grep -i "boot\|fat" | awk '{print $NF}' | head -1)
BOOT_MOUNT_PATH=""

if [ -n "$BOOT_MOUNT" ]; then
    BOOT_MOUNT_PATH=$(diskutil info "$BOOT_MOUNT" 2>/dev/null | grep "Mount Point" | awk '{print $3}')
fi

# Fallback: check common mount paths
if [ -z "$BOOT_MOUNT_PATH" ] || [ ! -d "$BOOT_MOUNT_PATH" ]; then
    for path in "/Volumes/bootfs" "/Volumes/boot" "/Volumes/BOOT"; do
        if [ -d "$path" ]; then
            BOOT_MOUNT_PATH="$path"
            break
        fi
    done
fi

if [ -z "$BOOT_MOUNT_PATH" ] || [ ! -d "$BOOT_MOUNT_PATH" ]; then
    warn "Could not find boot partition mount point."
    warn "Configuration files were NOT injected automatically."
    warn "Manual steps required before booting the Pi:"
    warn "  1. Mount the SD card boot partition"
    warn "  2. Create userconf.txt with: echo '${PI_USER}:\$(openssl passwd -6 ${PI_PASSWORD})' > /Volumes/bootfs/userconf.txt"
    warn "  3. Create empty ssh file: touch /Volumes/bootfs/ssh"
    warn "  4. Copy firstrun.sh: cp $FIRSTRUN_SCRIPT /Volumes/bootfs/firstrun.sh"
    warn "  5. Add to cmdline.txt: append 'systemd.run=/boot/firmware/firstrun.sh' to the end of the single line"
else
    info "Injecting configuration into $BOOT_MOUNT_PATH..."

    # 1. userconf.txt — bypasses the interactive first-boot wizard
    # openssl passwd -6 requires OpenSSL (not LibreSSL which ships with macOS)
    # Try openssl first, fall back to Python if needed
    if openssl passwd -6 "test" &>/dev/null 2>&1; then
        HASHED_PASSWORD=$(openssl passwd -6 "$PI_PASSWORD")
    else
        HASHED_PASSWORD=$(python3 -c "import crypt; print(crypt.crypt('$PI_PASSWORD', crypt.mksalt(crypt.METHOD_SHA512)))" 2>/dev/null)
    fi
    if [ -z "$HASHED_PASSWORD" ]; then
        error "Could not generate password hash. Install openssl: brew install openssl"
    fi
    echo "${PI_USER}:${HASHED_PASSWORD}" | sudo tee "$BOOT_MOUNT_PATH/userconf.txt" > /dev/null
    success "userconf.txt written (bypasses setup wizard)"

    # 2. ssh — empty file that enables SSH on first boot
    sudo touch "$BOOT_MOUNT_PATH/ssh"
    success "ssh file created (enables SSH)"

    # 3. firstrun.sh — our hardening script
    sudo cp "$FIRSTRUN_SCRIPT" "$BOOT_MOUNT_PATH/firstrun.sh"
    sudo chmod +x "$BOOT_MOUNT_PATH/firstrun.sh"
    success "firstrun.sh injected"

    # 4. cmdline.txt — add systemd.run to execute firstrun.sh on boot
    CMDLINE="$BOOT_MOUNT_PATH/cmdline.txt"
    if [ -f "$CMDLINE" ]; then
        # Back up original cmdline.txt
        sudo cp "$CMDLINE" "$CMDLINE.bak"
        ORIGINAL_CMDLINE=$(cat "$CMDLINE")

        if ! grep -q "firstrun.sh" "$CMDLINE"; then
            # Read current content, append systemd.run parameter
            # Use a safe approach: append to end of line rather than inserting before rootwait
            CURRENT=$(cat "$CMDLINE" | tr -d '\n')
            NEW_CMDLINE="${CURRENT} systemd.run=/boot/firmware/firstrun.sh"
            echo "$NEW_CMDLINE" | sudo tee "$CMDLINE" > /dev/null

            # Validate — confirm the file still has rootwait and our addition
            if grep -q "rootwait" "$CMDLINE" && grep -q "firstrun.sh" "$CMDLINE"; then
                success "cmdline.txt updated and validated"
            else
                warn "cmdline.txt validation failed — restoring backup"
                sudo cp "$CMDLINE.bak" "$CMDLINE"
                warn "firstrun.sh will NOT run automatically on first boot"
                warn "Pi will still boot correctly — hardening must be done manually"
            fi
        else
            info "cmdline.txt already references firstrun.sh — skipping"
        fi
    else
        warn "cmdline.txt not found — firstrun.sh may not execute automatically"
    fi

    success "All boot configuration files injected"
fi

# =============================================================================
# STEP 9: Done
# =============================================================================
# =============================================================================
# STEP 9: Generate setup-mac-ssh.sh and run post-flash flow
# =============================================================================
rm -f "$FIRSTRUN_SCRIPT"

# Generate setup-mac-ssh.sh from template
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/setup-mac-ssh.sh.template"
SETUP_SCRIPT="$SCRIPT_DIR/setup-mac-ssh.sh"

if [ -f "$TEMPLATE" ]; then
    info "Generating setup-mac-ssh.sh from template..."
    sed \
        -e "s|{{HOSTNAME}}|${HOSTNAME}|g" \
        -e "s|{{PI_HOST}}|${PI_HOST}|g" \
        -e "s|{{PI_USER}}|${PI_USER}|g" \
        -e "s|{{JUMPHOST_KEY}}|${JUMPHOST_KEY}|g" \
        -e "s|{{NODE_HOSTNAME}}|${NODE_HOSTNAME}|g" \
        -e "s|{{NODE_HOST}}|${NODE_HOST}|g" \
        "$TEMPLATE" > "$SETUP_SCRIPT"
    chmod +x "$SETUP_SCRIPT"
    success "Generated: $SETUP_SCRIPT"
else
    warn "Template not found — skipping setup-mac-ssh.sh generation"
fi

# Eject SD card
echo ""
info "Ejecting SD card..."
diskutil eject "$SD_DEVICE" 2>/dev/null && success "SD card ejected safely" || \
    warn "Could not auto-eject — please eject manually from Finder"

# Physical instructions
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  📋 Physical Setup Instructions                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  1️⃣  Remove the SD card from your Mac"
echo "  2️⃣  Insert it into the Raspberry Pi 2 (underside slot)"
echo "  3️⃣  Connect an Ethernet cable from the Pi to your router"
echo "  4️⃣  Connect the Pi to power (Micro USB)"
echo ""
echo "  The Pi will boot and run the hardening script automatically."
echo "  This takes ~3 minutes on first boot."
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  🔍 How to validate the Pi is working            ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  Option A — Check the LEDs:"
echo "    Red LED solid   = powered on"
echo "    Green LED blinks = SD card being read (booting)"
echo "    Green LED off    = not reading SD card (boot failure)"
echo ""
echo "  Option B — Check boot partition files from your Mac:"
echo "    After ~3 min, re-insert the SD card and check:"
echo "    cat /Volumes/bootfs/firstrun-status.txt"
echo "    cat /Volumes/bootfs/firstrun-debug.log"
echo "    These files show exactly what ran and where it stopped."
echo ""
echo "  Option C — Ping the Pi:"
echo "    ping -c 3 ${PI_HOST}"
echo "    (Only works after firstrun.sh completes and Pi reboots)"
echo ""
echo "  Option D — SSH in:"
echo "    ssh -i ${JUMPHOST_KEY} ${PI_USER}@${PI_HOST}"
echo ""
echo "  Once the Pi is confirmed working, run:"
echo "    bash ${SETUP_SCRIPT:-kiro-rocketpool-guide/scripts/setup-mac-ssh.sh}"
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  ✅ Flash complete! SD card is ready.            ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
