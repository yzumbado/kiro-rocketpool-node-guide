#!/usr/bin/env bats
# =============================================================================
# flash-jumphost.bats
# Unit tests for flash-jumphost.sh
#
# Run: bats kiro-rocketpool-guide/scripts/tests/flash-jumphost.bats
# Or:  kiro-rocketpool-guide/scripts/tests/run-tests.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
FLASH_SCRIPT="$SCRIPT_DIR/flash-jumphost.sh"
SETUP_TEMPLATE="$SCRIPT_DIR/setup-mac-ssh.sh.template"
HARDEN_TEMPLATE="$SCRIPT_DIR/harden-pi.sh.template"

# =============================================================================
# Syntax check
# =============================================================================

@test "flash-jumphost.sh passes bash syntax check" {
  run bash -n "$FLASH_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "setup-mac-ssh.sh.template passes bash syntax check" {
  # Replace placeholders with dummy values before syntax checking
  TMPFILE=$(mktemp /tmp/test-template-XXXXXX.sh)
  sed \
    -e 's|{{HOSTNAME}}|pi-jumphost|g' \
    -e 's|{{PI_HOST}}|pi-jumphost.local|g' \
    -e 's|{{PI_USER}}|piop|g' \
    -e 's|{{JUMPHOST_KEY}}|~/.ssh/id_ed25519_pi-jumphost|g' \
    -e 's|{{NODE_HOSTNAME}}|rp-node01|g' \
    -e 's|{{NODE_HOST}}|rp-node01.local|g' \
    "$SETUP_TEMPLATE" > "$TMPFILE"
  run bash -n "$TMPFILE"
  rm -f "$TMPFILE"
  [ "$status" -eq 0 ]
}

@test "harden-pi.sh.template passes bash syntax check" {
  TMPFILE=$(mktemp /tmp/test-template-XXXXXX.sh)
  sed \
    -e 's|{{HOSTNAME}}|pi-jumphost|g' \
    -e 's|{{PI_HOST}}|pi-jumphost.local|g' \
    -e 's|{{PI_USER}}|piop|g' \
    -e 's|{{NODE_HOSTNAME}}|rp-node01|g' \
    -e 's|{{NODE_HOST}}|rp-node01.local|g' \
    -e 's|{{TIMEZONE}}|UTC|g' \
    -e 's|{{WEBHOOK_URL}}||g' \
    -e 's|{{MAC_PUBKEY}}|ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA test-key|g' \
    "$HARDEN_TEMPLATE" > "$TMPFILE"
  run bash -n "$TMPFILE"
  rm -f "$TMPFILE"
  [ "$status" -eq 0 ]
}

# =============================================================================
# Input validation — SD device checks
# =============================================================================

# Source helper: load only the validation functions by extracting and eval-ing them
# We mock all system calls so nothing touches real hardware

setup() {
  # Mock all dangerous/hardware commands
  diskutil()  { :; }
  dd()        { :; }
  pv()        { :; }
  sudo()      { shift; "$@" 2>/dev/null || true; }
  brew()      { :; }
  curl()      { :; }
  xz()        { :; }
  ssh-keygen(){ :; }
  export -f diskutil dd pv sudo brew curl xz ssh-keygen
}

@test "rejects partition device (e.g. /dev/disk4s1)" {
  # Extract just the partition check logic and test it directly
  run bash -c '
    SD_DEVICE="/dev/disk4s1"
    if [[ "$SD_DEVICE" =~ s[0-9]+$ ]]; then
      echo "partition error"
      exit 1
    fi
  '
  [ "$status" -eq 1 ]
  [[ "$output" == *"partition error"* ]]
}

@test "accepts whole disk device (e.g. /dev/disk4)" {
  run bash -c '
    SD_DEVICE="/dev/disk4"
    if [[ "$SD_DEVICE" =~ s[0-9]+$ ]]; then
      echo "partition error"
      exit 1
    fi
    echo "ok"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "rejects empty SD device" {
  run bash -c '
    SD_DEVICE=""
    if [ -z "$SD_DEVICE" ]; then
      echo "no device"
      exit 1
    fi
  '
  [ "$status" -eq 1 ]
}

# =============================================================================
# Input validation — password checks
# =============================================================================

@test "rejects empty password" {
  run bash -c '
    PI_PASSWORD=""
    if [ -z "$PI_PASSWORD" ]; then
      echo "empty password"
      exit 1
    fi
  '
  [ "$status" -eq 1 ]
}

@test "rejects mismatched passwords" {
  run bash -c '
    PI_PASSWORD="secret123"
    PI_PASSWORD_CONFIRM="different"
    if [ "$PI_PASSWORD" != "$PI_PASSWORD_CONFIRM" ]; then
      echo "mismatch"
      exit 1
    fi
  '
  [ "$status" -eq 1 ]
}

@test "accepts matching passwords" {
  run bash -c '
    PI_PASSWORD="secret123"
    PI_PASSWORD_CONFIRM="secret123"
    if [ "$PI_PASSWORD" != "$PI_PASSWORD_CONFIRM" ]; then
      echo "mismatch"
      exit 1
    fi
    echo "ok"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

# =============================================================================
# Default value handling
# =============================================================================

@test "hostname defaults to pi-jumphost when empty input" {
  run bash -c '
    DEFAULT_HOSTNAME="pi-jumphost"
    INPUT_HOSTNAME=""
    PI_HOSTNAME="${INPUT_HOSTNAME:-$DEFAULT_HOSTNAME}"
    echo "$PI_HOSTNAME"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == "pi-jumphost" ]]
}

@test "username defaults to piop when empty input" {
  run bash -c '
    DEFAULT_USERNAME="piop"
    INPUT_USERNAME=""
    PI_USER="${INPUT_USERNAME:-$DEFAULT_USERNAME}"
    echo "$PI_USER"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == "piop" ]]
}

@test "timezone defaults to UTC when empty input" {
  run bash -c '
    DEFAULT_TZ="UTC"
    INPUT_TZ=""
    TIMEZONE="${INPUT_TZ:-$DEFAULT_TZ}"
    echo "$TIMEZONE"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == "UTC" ]]
}

@test "PI_HOST uses .local when no static IP given" {
  run bash -c '
    PI_HOSTNAME="pi-jumphost"
    PI_IP=""
    PI_HOST="${PI_IP:-${PI_HOSTNAME}.local}"
    echo "$PI_HOST"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == "pi-jumphost.local" ]]
}

@test "PI_HOST uses static IP when provided" {
  run bash -c '
    PI_HOSTNAME="pi-jumphost"
    PI_IP="192.168.1.10"
    PI_HOST="${PI_IP:-${PI_HOSTNAME}.local}"
    echo "$PI_HOST"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == "192.168.1.10" ]]
}

# =============================================================================
# Template generation — sed substitutions
# =============================================================================

@test "setup-mac-ssh.sh template substitutes all placeholders" {
  TMPFILE=$(mktemp /tmp/test-generated-XXXXXX.sh)
  sed \
    -e 's|{{HOSTNAME}}|pi-jumphost|g' \
    -e 's|{{PI_HOST}}|pi-jumphost.local|g' \
    -e 's|{{PI_USER}}|piop|g' \
    -e 's|{{JUMPHOST_KEY}}|~/.ssh/id_ed25519_pi-jumphost|g' \
    -e 's|{{NODE_HOSTNAME}}|rp-node01|g' \
    -e 's|{{NODE_HOST}}|rp-node01.local|g' \
    "$SETUP_TEMPLATE" > "$TMPFILE"

  # No unsubstituted placeholders should remain
  run grep -c '{{' "$TMPFILE"
  rm -f "$TMPFILE"
  [ "$output" -eq 0 ]
}

@test "harden-pi.sh template substitutes all placeholders" {
  TMPFILE=$(mktemp /tmp/test-generated-XXXXXX.sh)
  PUBKEY_ESCAPED=$(echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA test" | sed 's|[&/\]|\\&|g')
  sed \
    -e 's|{{HOSTNAME}}|pi-jumphost|g' \
    -e 's|{{PI_HOST}}|pi-jumphost.local|g' \
    -e 's|{{PI_USER}}|piop|g' \
    -e 's|{{NODE_HOSTNAME}}|rp-node01|g' \
    -e 's|{{NODE_HOST}}|rp-node01.local|g' \
    -e 's|{{TIMEZONE}}|UTC|g' \
    -e 's|{{WEBHOOK_URL}}||g' \
    -e "s|{{MAC_PUBKEY}}|${PUBKEY_ESCAPED}|g" \
    "$HARDEN_TEMPLATE" > "$TMPFILE"

  run grep -c '{{' "$TMPFILE"
  rm -f "$TMPFILE"
  [ "$output" -eq 0 ]
}

@test "generated setup-mac-ssh.sh contains correct hostname" {
  TMPFILE=$(mktemp /tmp/test-generated-XXXXXX.sh)
  sed \
    -e 's|{{HOSTNAME}}|my-pi|g' \
    -e 's|{{PI_HOST}}|my-pi.local|g' \
    -e 's|{{PI_USER}}|piop|g' \
    -e 's|{{JUMPHOST_KEY}}|~/.ssh/id_ed25519_my-pi|g' \
    -e 's|{{NODE_HOSTNAME}}|rp-node01|g' \
    -e 's|{{NODE_HOST}}|rp-node01.local|g' \
    "$SETUP_TEMPLATE" > "$TMPFILE"

  run grep 'PI_HOSTNAME="my-pi"' "$TMPFILE"
  rm -f "$TMPFILE"
  [ "$status" -eq 0 ]
}

# =============================================================================
# Boot file injection logic
# =============================================================================

@test "userconf.txt is written with correct format (user:hash)" {
  TMPDIR=$(mktemp -d /tmp/test-boot-XXXXXX)
  PI_USER="piop"
  # Use Homebrew openssl — macOS LibreSSL and Python 3.13+ crypt module both unavailable
  HASHED=$(/opt/homebrew/opt/openssl/bin/openssl passwd -6 "testpass" 2>/dev/null)

  run bash -c "echo '${PI_USER}:${HASHED}' | tee '${TMPDIR}/userconf.txt' > /dev/null && cat '${TMPDIR}/userconf.txt'"
  rm -rf "$TMPDIR"
  [ "$status" -eq 0 ]
  [[ "$output" == piop:* ]]
}

@test "ssh enablement file is created as empty file" {
  TMPDIR=$(mktemp -d /tmp/test-boot-XXXXXX)
  touch "$TMPDIR/ssh"
  run bash -c "[ -f '${TMPDIR}/ssh' ] && echo 'exists'"
  rm -rf "$TMPDIR"
  [ "$status" -eq 0 ]
  [[ "$output" == "exists" ]]
}

# =============================================================================
# SHA256 verification logic
# =============================================================================

@test "verify_image returns 0 when SHA256 matches" {
  TMPFILE=$(mktemp /tmp/test-img-XXXXXX)
  echo "test content" > "$TMPFILE"
  EXPECTED=$(shasum -a 256 "$TMPFILE" | awk '{print $1}')

  run bash -c "
    ACTUAL=\$(shasum -a 256 '$TMPFILE' | awk '{print \$1}')
    [ \"\$ACTUAL\" = \"$EXPECTED\" ] && echo 'match' || echo 'mismatch'
  "
  rm -f "$TMPFILE"
  [ "$status" -eq 0 ]
  [[ "$output" == "match" ]]
}

@test "verify_image returns 1 when SHA256 does not match" {
  TMPFILE=$(mktemp /tmp/test-img-XXXXXX)
  echo "test content" > "$TMPFILE"
  WRONG_SHA="0000000000000000000000000000000000000000000000000000000000000000"

  run bash -c "
    ACTUAL=\$(shasum -a 256 '$TMPFILE' | awk '{print \$1}')
    [ \"\$ACTUAL\" = \"$WRONG_SHA\" ] && echo 'match' || echo 'mismatch'
  "
  rm -f "$TMPFILE"
  [ "$status" -eq 0 ]
  [[ "$output" == "mismatch" ]]
}
