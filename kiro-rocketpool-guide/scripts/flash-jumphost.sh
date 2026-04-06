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

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
ask()     { echo -e "${YELLOW}[INPUT]${NC} $1"; }

echo ""
echo "=============================================="
echo "  Rocket Pool Jump Host — SD Card Flash Tool"
echo "  Raspberry Pi 2 · Raspberry Pi OS Lite 32-bit"
echo "=============================================="
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

JUMPHOST_KEY="$HOME/.ssh/id_ed25519_jumphost"
JUMPHOST_PUB="${JUMPHOST_KEY}.pub"

if [ ! -f "$JUMPHOST_PUB" ]; then
    warn "No jumphost SSH key found at ${JUMPHOST_PUB}"
    info "Generating new Ed25519 key pair for Mac → Pi access..."
    ssh-keygen -t ed25519 -C "mac-to-jumphost" -f "$JUMPHOST_KEY" -N ""
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

set -e
LOG="/var/log/firstrun.log"
exec > >(tee -a \$LOG) 2>&1
echo "=== First-run hardening started: \$(date) ==="

# Update system
apt-get update -y
apt-get upgrade -y
apt-get install -y ufw fail2ban curl wget

# Set timezone
timedatectl set-timezone ${TIMEZONE}

# Install SSH public key for Mac → Pi access
mkdir -p /home/${PI_USER}/.ssh
chmod 700 /home/${PI_USER}/.ssh
echo "${MAC_PUBKEY}" >> /home/${PI_USER}/.ssh/authorized_keys
chmod 600 /home/${PI_USER}/.ssh/authorized_keys
chown -R ${PI_USER}:${PI_USER} /home/${PI_USER}/.ssh

# Harden SSH daemon
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config
grep -q "^AllowUsers" /etc/ssh/sshd_config || echo "AllowUsers ${PI_USER}" >> /etc/ssh/sshd_config

# Configure UFW — allow SSH on local network
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH local network only'
ufw --force enable

# Configure fail2ban
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
systemctl enable fail2ban
systemctl start fail2ban

# Create scripts directory and watchdog
mkdir -p /home/${PI_USER}/scripts

cat > /home/${PI_USER}/scripts/node-watchdog.sh << 'WATCHDOG'
#!/bin/bash
NODE_HOST="${NODE_HOSTNAME}"
WEBHOOK_URL="${WEBHOOK_URL}"
ALERT_COOLDOWN=3600
ALERT_FILE="/tmp/watchdog_last_alert"
ISSUES=()

if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "\$NODE_HOST" exit 2>/dev/null; then
    ISSUES+=("🔴 Node SSH unreachable")
fi

if [ \${#ISSUES[@]} -eq 0 ]; then
    CONTAINER_COUNT=\$(ssh "\$NODE_HOST" "docker ps | grep -c rocketpool" 2>/dev/null)
    if [ "\${CONTAINER_COUNT:-0}" -lt 5 ]; then
        ISSUES+=("⚠️ Only \$CONTAINER_COUNT/5+ Rocket Pool containers running")
    fi
fi

if [ \${#ISSUES[@]} -eq 0 ]; then
    DISK_USED=\$(ssh "\$NODE_HOST" "df /mnt/ssd | awk 'NR==2{print \\\$5}' | tr -d '%'" 2>/dev/null)
    if [ "\${DISK_USED:-0}" -gt 85 ]; then
        ISSUES+=("⚠️ Node disk at \${DISK_USED}% — action needed")
    fi
fi

if [ \${#ISSUES[@]} -gt 0 ] && [ -n "\$WEBHOOK_URL" ]; then
    LAST_ALERT=\$(cat "\$ALERT_FILE" 2>/dev/null || echo 0)
    NOW=\$(date +%s)
    if [ \$((NOW - LAST_ALERT)) -gt \$ALERT_COOLDOWN ]; then
        MESSAGE="**rp-node01 Alert** \$(date)\n\$(printf '%s\n' "\${ISSUES[@]}")"
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

# Configure SSH client for node access
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

echo "=== First-run hardening complete: \$(date) ==="
echo "NOTE: Generate the node SSH key manually after first login:"
echo "  ssh-keygen -t ed25519 -C 'rp-node01-access' -f ~/.ssh/rp_node_key"

# Self-destruct
rm -f "\$0"
FIRSTRUN

chmod +x "$FIRSTRUN_SCRIPT"

# =============================================================================
# STEP 6: Confirmation summary
# =============================================================================
echo ""
echo "=============================================="
echo "  CONFIGURATION SUMMARY — Review before flash"
echo "=============================================="
echo ""
echo "  Pi hostname:      $HOSTNAME"
echo "  Pi username:      $PI_USER"
echo "  Pi password:      [set]"
echo "  Timezone:         $TIMEZONE"
echo "  Pi static IP:     ${PI_IP:-[not set — using ${HOSTNAME}.local]}"
echo "  Node host:        ${NODE_IP:-[not set — using ${NODE_HOSTNAME}.local]}"
echo "  SSH key (Mac→Pi): $JUMPHOST_PUB"
echo "  Watchdog webhook: ${WEBHOOK_URL:-[not set]}"
echo ""
echo "  Target device:    $SD_DEVICE"
echo "  Device name:      $SD_NAME"
echo "  Device size:      $SD_SIZE"
echo ""
echo "  First-run script will:"
echo "    ✓ Update all packages"
echo "    ✓ Install ufw, fail2ban, curl, wget"
echo "    ✓ Inject your SSH public key"
echo "    ✓ Disable password SSH auth"
echo "    ✓ Configure UFW (SSH local subnet only)"
echo "    ✓ Configure fail2ban (3 retries, 24h ban)"
echo "    ✓ Install watchdog cron (every 15 min)"
echo "    ✓ Pre-configure SSH client for rp-node01"
echo ""
echo "=============================================="
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
info "Flashing $RAW_DEVICE using dd — this takes 3–8 minutes..."
echo ""

# Decompress image if needed
OS_IMG="${OS_IMAGE%.xz}"
if [ ! -f "$OS_IMG" ]; then
    info "Decompressing image..."
    xz -dk "$OS_IMAGE"
    success "Decompressed to $OS_IMG"
fi

# Write image with dd (bypasses macOS app sandbox restrictions)
sudo dd if="$OS_IMG" of="$RAW_DEVICE" bs=4m status=progress
sync
success "Image written"

# Re-mount to inject first-run script
info "Mounting boot partition to inject first-run script..."
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
    warn "First-run script was NOT injected automatically."
    warn "The Pi will boot but without the hardening configuration."
    warn "You can manually copy the first-run script:"
    warn "  sudo cp $FIRSTRUN_SCRIPT /Volumes/bootfs/firstrun.sh"
    warn "  sudo chmod +x /Volumes/bootfs/firstrun.sh"
else
    info "Injecting first-run script into $BOOT_MOUNT_PATH..."
    sudo cp "$FIRSTRUN_SCRIPT" "$BOOT_MOUNT_PATH/firstrun.sh"
    sudo chmod +x "$BOOT_MOUNT_PATH/firstrun.sh"
    success "First-run script injected"
fi

# =============================================================================
# STEP 9: Done
# =============================================================================
rm -f "$FIRSTRUN_SCRIPT"

echo ""
echo "=============================================="
success "Flash complete!"
echo "=============================================="
echo ""
echo "Next steps:"
echo ""
echo "  1. Set DHCP reservation in your router:"
echo "       Pi MAC → $PI_HOST"
echo ""
echo "  2. Insert SD card into Pi 2, connect Ethernet, power on"
echo "     Wait ~3 minutes for first boot + hardening to complete"
echo ""
echo "  3. Test SSH from your Mac:"
echo "       ssh -i $JUMPHOST_KEY ${PI_USER}@${PI_HOST}"
echo ""
echo "  4. Once logged in, generate the node SSH key:"
echo "       ssh-keygen -t ed25519 -C '${NODE_HOSTNAME}-access' -f ~/.ssh/rp_node_key"
echo ""
echo "  5. Add Mac SSH config entry:"
cat << SSHCONFIG
       # Add to ~/.ssh/config on your Mac:
       Host jumphost
           HostName $PI_HOST
           User $PI_USER
           IdentityFile $JUMPHOST_KEY
           ServerAliveInterval 60

       Host $NODE_HOSTNAME
           HostName $NODE_HOST
           User nodeop
           ProxyJump jumphost
           IdentityFile /dev/null
SSHCONFIG
echo ""
echo "  Then continue with 01-hardware-prep.md"
echo ""
