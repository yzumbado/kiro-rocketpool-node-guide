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
PI_HOSTNAME="${INPUT_HOSTNAME:-$DEFAULT_HOSTNAME}"
echo "  → $PI_HOSTNAME"

# --- Username ---
DEFAULT_USERNAME="piop"
ask "Pi username [default: ${DEFAULT_USERNAME}]:"
read -r INPUT_USERNAME
PI_USER="${INPUT_USERNAME:-$DEFAULT_USERNAME}"
echo "  → $PI_USER"

# --- Password ---
ask "Pi password (used only until SSH keys are set up):"
read -rs PI_PASSWORD
echo ""
if [ -z "$PI_PASSWORD" ]; then
    error "Password cannot be empty."
fi
ask "Confirm password:"
read -rs PI_PASSWORD_CONFIRM
echo ""
if [ "$PI_PASSWORD" != "$PI_PASSWORD_CONFIRM" ]; then
    error "Passwords do not match. Run the script again."
fi
echo "  → [password set]"

# --- Timezone ---
DEFAULT_TZ="UTC"
ask "Timezone [default: ${DEFAULT_TZ}]:"
read -r INPUT_TZ
TIMEZONE="${INPUT_TZ:-$DEFAULT_TZ}"
echo "  → $TIMEZONE"

# --- Pi static IP (optional — skip if no final router yet) ---
echo ""
info "Static IPs are optional. Press Enter to skip and use .local hostnames instead."
ask "Pi static IP for DHCP reservation (or press Enter to skip):"
read -r INPUT_PI_IP
PI_IP="${INPUT_PI_IP:-}"
echo "  → ${PI_IP:-[not set — using ${PI_HOSTNAME}.local]}"

# --- Node hostname ---
DEFAULT_NODE_HOSTNAME="rp-node01"
ask "Node (Beelink) hostname [default: ${DEFAULT_NODE_HOSTNAME}]:"
read -r INPUT_NODE_HOSTNAME
NODE_HOSTNAME="${INPUT_NODE_HOSTNAME:-$DEFAULT_NODE_HOSTNAME}"
echo "  → $NODE_HOSTNAME"

ask "Node (Beelink) static IP for DHCP reservation (or press Enter to skip):"
read -r INPUT_NODE_IP
NODE_IP="${INPUT_NODE_IP:-}"
echo "  → ${NODE_IP:-[not set — using ${NODE_HOSTNAME}.local]}"

# Determine hostnames to use in SSH config
PI_HOST="${PI_IP:-${PI_HOSTNAME}.local}"
NODE_HOST="${NODE_IP:-${NODE_HOSTNAME}.local}"

# --- Discord webhook (optional) ---
ask "Discord webhook URL for watchdog alerts (press Enter to skip):"
read -r WEBHOOK_URL
echo "  → ${WEBHOOK_URL:-[not set]}"

# =============================================================================
# STEP 3: SSH key — generate if needed
# =============================================================================
echo ""
info "Checking SSH keys..."

JUMPHOST_KEY="$HOME/.ssh/id_ed25519_${PI_HOSTNAME}"
JUMPHOST_PUB="${JUMPHOST_KEY}.pub"

if [ ! -f "$JUMPHOST_PUB" ]; then
    info "Generating new Ed25519 key pair for Mac → Pi access..."
    ssh-keygen -t ed25519 -C "mac-to-${PI_HOSTNAME}" -f "$JUMPHOST_KEY" -N ""
    success "Key generated: ${JUMPHOST_PUB}"
else
    success "Found existing key: ${JUMPHOST_PUB}"
fi

MAC_PUBKEY=$(cat "$JUMPHOST_PUB")
if [ -z "$MAC_PUBKEY" ]; then
    error "SSH public key is empty — cannot continue. Check $JUMPHOST_PUB"
fi

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
# Use grep -c for robustness against diskutil output format changes
if diskutil info "$SD_DEVICE" | grep -c "Media Read-Only:.*Yes" | grep -q "^[1-9]"; then
    error "The SD card at ${SD_DEVICE} is write-protected (Media Read-Only: Yes).
    This can happen if:
    - The card's physical lock switch is engaged (check the SD adapter)
    - A previous failed write corrupted the card's controller
    - The card is damaged or low quality
    Try a different card. Recommended: Samsung PRO Endurance or SanDisk Endurance."
fi

SD_SIZE=$(diskutil info "$SD_DEVICE" | grep "Disk Size" | awk '{print $3, $4}')
SD_NAME=$(diskutil info "$SD_DEVICE" | grep "Media Name" | cut -d: -f2 | xargs)

# Minimum size check — image decompresses to ~1.9GB, need at least 4GB
SD_SIZE_BYTES=$(diskutil info "$SD_DEVICE" | grep "Disk Size" | grep -oE '[0-9]+ Bytes' | awk '{print $1}')
MIN_SIZE_BYTES=4000000000
if [ -n "$SD_SIZE_BYTES" ] && [ "$SD_SIZE_BYTES" -lt "$MIN_SIZE_BYTES" ]; then
    error "SD card is too small (${SD_SIZE}). Minimum 4GB required."
fi

# =============================================================================
# STEP 5: No first-run script needed
# All hardening is done by the agent over SSH after the Pi boots.
# The flash only needs to get SSH working.
# =============================================================================
# (nothing to do here — boot partition injection handles SSH enablement)

# =============================================================================
# STEP 6: Confirmation summary
# =============================================================================
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║           CONFIGURATION SUMMARY                 ║"
echo "╠══════════════════════════════════════════════════╣"
printf "║  🖥️  %-12s  %-30s║\n" "Pi hostname"  "$PI_HOSTNAME"
printf "║  👤 %-12s  %-30s║\n" "Pi username"  "$PI_USER"
printf "║  🌍 %-12s  %-30s║\n" "Timezone"     "$TIMEZONE"
printf "║  🌐 %-12s  %-30s║\n" "Pi address"   "${PI_IP:-${PI_HOSTNAME}.local}"
printf "║  🌐 %-12s  %-30s║\n" "Node address" "${NODE_IP:-${NODE_HOSTNAME}.local}"
printf "║  🔑 %-12s  %-30s║\n" "SSH key"      "$HOME/.ssh/id_ed25519_${PI_HOSTNAME}"
printf "║  🔔 %-12s  %-30s║\n" "Webhook"      "${WEBHOOK_URL:-[not set]}"
echo "╠══════════════════════════════════════════════════╣"
printf "║  💾 %-12s  %-30s║\n" "Target"       "$SD_DEVICE"
printf "║  📦 %-12s  %-30s║\n" "Device"       "$SD_NAME"
printf "║  📏 %-12s  %-30s║\n" "Size"         "$SD_SIZE"
echo "╠══════════════════════════════════════════════════╣"
echo "║  Boot configuration will:                       ║"
echo "║    ✓ Create user ${PI_USER} (bypasses wizard)         ║"
echo "║    ✓ Enable SSH on first boot                   ║"
echo "║                                                 ║"
echo "║  After boot, the agent will handle:             ║"
echo "║    → System update + package install            ║"
echo "║    → SSH key injection + hardening              ║"
echo "║    → UFW + fail2ban                             ║"
echo "║    → Watchdog cron + SSH client config          ║"
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
    pv -s "$IMAGE_SIZE" -N "  🚀 Flashing SD card" "$OS_IMG" | sudo dd of="$RAW_DEVICE" bs=4m \
        || error "Flash failed — dd reported an error. Check device permissions and card health."
else
    info "Progress updates every 5 seconds..."
    sudo dd if="$OS_IMG" of="$RAW_DEVICE" bs=4m status=progress \
        || error "Flash failed — dd reported an error. Check device permissions and card health."
fi
sync
success "Image written"

# Re-enable macOS auto-mount
info "Re-enabling macOS auto-mount..."
sudo defaults delete /Library/Preferences/SystemConfiguration/autodiskmount \
    AutomountDisksWithoutUserApproval 2>/dev/null || true

# Re-mount to inject first-run script
info "Mounting boot partition to inject configuration files..."
diskutil mountDisk "$SD_DEVICE" || true

# Poll for mount point instead of fixed sleep
BOOT_MOUNT_PATH=""
for _i in $(seq 1 15); do
    for path in "/Volumes/bootfs" "/Volumes/boot" "/Volumes/BOOT"; do
        if [ -d "$path" ]; then
            BOOT_MOUNT_PATH="$path"
            break 2
        fi
    done
    # Also try via diskutil
    BOOT_MOUNT=$(diskutil list "$SD_DEVICE" 2>/dev/null | grep -i "boot\|fat" | awk '{print $NF}' | head -1)
    if [ -n "$BOOT_MOUNT" ]; then
        MP=$(diskutil info "$BOOT_MOUNT" 2>/dev/null | grep "Mount Point" | awk '{print $3}')
        if [ -n "$MP" ] && [ -d "$MP" ]; then
            BOOT_MOUNT_PATH="$MP"
            break
        fi
    fi
    sleep 1
done

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
    info "Injecting minimal boot configuration into $BOOT_MOUNT_PATH..."

    # 1. userconf.txt — creates user and bypasses interactive first-boot wizard
    # Try Homebrew openssl first (macOS LibreSSL doesn't support -6)
    if /opt/homebrew/opt/openssl/bin/openssl passwd -6 "test" &>/dev/null 2>&1; then
        HASHED_PASSWORD=$(/opt/homebrew/opt/openssl/bin/openssl passwd -6 "$PI_PASSWORD")
    elif openssl passwd -6 "test" &>/dev/null 2>&1; then
        HASHED_PASSWORD=$(openssl passwd -6 "$PI_PASSWORD")
    else
        error "Could not generate SHA-512 password hash. Install openssl: brew install openssl"
    fi
    echo "${PI_USER}:${HASHED_PASSWORD}" | sudo tee "$BOOT_MOUNT_PATH/userconf.txt" > /dev/null
    success "userconf.txt written — user ${PI_USER} will be created on first boot"

    # 2. ssh — empty file that enables SSH on first boot
    sudo touch "$BOOT_MOUNT_PATH/ssh"
    success "ssh file created — SSH will be enabled on first boot"

    # That's it. No firstrun.sh, no cmdline.txt modification.
    # All hardening is done by the agent over SSH after the Pi boots.
    success "Boot configuration complete — Pi will boot with SSH enabled"
fi

# =============================================================================
# STEP 9: Generate setup-mac-ssh.sh and harden-pi.sh, then run post-flash flow
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Generate setup-mac-ssh.sh from template
TEMPLATE="$SCRIPT_DIR/setup-mac-ssh.sh.template"
SETUP_SCRIPT="$SCRIPT_DIR/setup-mac-ssh.sh"

if [ -f "$TEMPLATE" ]; then
    info "Generating setup-mac-ssh.sh from template..."
    sed \
        -e "s|{{HOSTNAME}}|${PI_HOSTNAME}|g" \
        -e "s|{{PI_HOST}}|${PI_HOST}|g" \
        -e "s|{{PI_USER}}|${PI_USER}|g" \
        -e "s|{{JUMPHOST_KEY}}|${JUMPHOST_KEY}|g" \
        -e "s|{{NODE_HOSTNAME}}|${NODE_HOSTNAME}|g" \
        -e "s|{{NODE_HOST}}|${NODE_HOST}|g" \
        "$TEMPLATE" > "$SETUP_SCRIPT"
    chmod +x "$SETUP_SCRIPT"
    success "Generated: $SETUP_SCRIPT"
else
    warn "setup-mac-ssh.sh.template not found — skipping"
fi

# Generate harden-pi.sh from template
HARDEN_TEMPLATE="$SCRIPT_DIR/harden-pi.sh.template"
HARDEN_SCRIPT="$SCRIPT_DIR/harden-pi.sh"

if [ -f "$HARDEN_TEMPLATE" ]; then
    info "Generating harden-pi.sh from template..."
    # MAC_PUBKEY may contain special chars — write to temp file and use @file substitution
    PUBKEY_ESCAPED=$(echo "$MAC_PUBKEY" | sed 's|[&/\]|\\&|g')
    sed \
        -e "s|{{HOSTNAME}}|${PI_HOSTNAME}|g" \
        -e "s|{{PI_HOST}}|${PI_HOST}|g" \
        -e "s|{{PI_USER}}|${PI_USER}|g" \
        -e "s|{{NODE_HOSTNAME}}|${NODE_HOSTNAME}|g" \
        -e "s|{{NODE_HOST}}|${NODE_HOST}|g" \
        -e "s|{{TIMEZONE}}|${TIMEZONE}|g" \
        -e "s|{{WEBHOOK_URL}}|${WEBHOOK_URL}|g" \
        -e "s|{{MAC_PUBKEY}}|${PUBKEY_ESCAPED}|g" \
        "$HARDEN_TEMPLATE" > "$HARDEN_SCRIPT"
    chmod +x "$HARDEN_SCRIPT"
    success "Generated: $HARDEN_SCRIPT"
else
    warn "harden-pi.sh.template not found — skipping"
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
echo "  The Pi will boot with SSH enabled — no first-run script."
echo "  Boot time is ~60-90 seconds."
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  🔍 How to validate the Pi is working            ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  Option A — Check the LEDs:"
echo "    Red LED solid    = powered on"
echo "    Green LED blinks = SD card being read (booting)"
echo "    Green LED off    = not reading SD card (boot failure)"
echo ""
echo "  Option B — Ping the Pi:"
echo "    ping -c 3 ${PI_HOST}"
echo ""
echo "  Option C — SSH in (password login, key not yet set up):"
echo "    ssh ${PI_USER}@${PI_HOST}"
echo ""
echo "  Once the Pi responds, run setup-mac-ssh.sh to configure SSH,"
echo "  then the agent will run harden-pi.sh to complete hardening."
echo ""
echo "  Once the Pi is confirmed working, run:"
echo "    bash ${SETUP_SCRIPT:-kiro-rocketpool-guide/scripts/setup-mac-ssh.sh}"
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  ✅ Flash complete! SD card is ready.            ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
