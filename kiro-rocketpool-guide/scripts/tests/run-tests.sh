#!/bin/bash
# =============================================================================
# run-tests.sh
# Run all script tests: shellcheck static analysis + bats unit tests
#
# Usage:
#   bash kiro-rocketpool-guide/scripts/tests/run-tests.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$SCRIPT_DIR/tests"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warn()    { echo -e "${YELLOW}⚠️  $1${NC}"; }
error()   { echo -e "${RED}❌ $1${NC}"; }

PASS=0
FAIL=0

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  🧪 Script Test Suite                            ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# 1. shellcheck — static analysis
# =============================================================================
info "Running shellcheck..."
echo ""

SCRIPTS=(
  "$SCRIPT_DIR/flash-jumphost.sh"
  "$SCRIPT_DIR/setup-mac-ssh.sh.template"
  "$SCRIPT_DIR/harden-pi.sh.template"
)

for script in "${SCRIPTS[@]}"; do
  name=$(basename "$script")
  if shellcheck --shell=bash --severity=warning "$script" 2>&1; then
    success "shellcheck: $name"
    PASS=$((PASS + 1))
  else
    error "shellcheck: $name"
    FAIL=$((FAIL + 1))
  fi
done

echo ""

# =============================================================================
# 2. bats — unit tests
# =============================================================================
info "Running bats unit tests..."
echo ""

if ! command -v bats &>/dev/null; then
  warn "bats not found — install with: brew install bats-core"
  FAIL=$((FAIL + 1))
else
  if bats "$TEST_DIR/flash-jumphost.bats"; then
    PASS=$((PASS + 1))
    # bats prints its own pass/fail summary
  else
    FAIL=$((FAIL + 1))
  fi
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "╔══════════════════════════════════════════════════╗"
TOTAL=$((PASS + FAIL))
if [ "$FAIL" -eq 0 ]; then
  printf "║  ✅ All checks passed (%d/%d)%s║\n" "$PASS" "$TOTAL" "                        " | head -c 52
  echo "║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""
  exit 0
else
  printf "║  ❌ %d check(s) failed (%d/%d passed)%s║\n" "$FAIL" "$PASS" "$TOTAL" "                  " | head -c 52
  echo "║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""
  exit 1
fi
