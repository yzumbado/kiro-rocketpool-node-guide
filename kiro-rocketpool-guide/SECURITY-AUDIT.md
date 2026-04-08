# Security Audit Report
## Kiro Rocket Pool Jump Host — Automation Scripts

**Audit date:** April 2026
**Scope:** `flash-jumphost.sh`, `setup-mac-ssh.sh.template`, `harden-pi.sh.template`
**Auditor role:** Security auditor + Unix scripting expert

---

## 1. Architecture Overview

The automation consists of three scripts with distinct execution contexts and trust boundaries.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        TRUST BOUNDARY MAP                           │
│                                                                     │
│  [Mac — Operator's machine]          [Pi — Jump Host]              │
│  ┌─────────────────────┐             ┌──────────────────────┐      │
│  │ flash-jumphost.sh   │             │ harden-pi.sh         │      │
│  │ (runs as user+sudo) │             │ (runs as root/sudo)  │      │
│  │                     │             │                      │      │
│  │ setup-mac-ssh.sh    │──SSH──────▶ │ Pi OS (Bookworm)     │      │
│  │ (runs as user)      │             │                      │      │
│  └─────────────────────┘             └──────────────────────┘      │
│                                                                     │
│  Sensitive data on Mac:              Sensitive data on Pi:         │
│  - PI_PASSWORD (in memory only)      - authorized_keys             │
│  - MAC_PUBKEY (from ~/.ssh/)         - sshd_config                 │
│  - WEBHOOK_URL (in generated script) - /etc/ufw/                   │
│  - HASHED_PASSWORD (in userconf.txt) - crontab                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Complete Workflow Diagram

```
HUMAN                    MAC SCRIPTS              PI HARDWARE           PI OS
  │                          │                        │                   │
  │  git pull                │                        │                   │
  │─────────────────────────▶│                        │                   │
  │                          │                        │                   │
  │  ./flash-jumphost.sh     │                        │                   │
  │─────────────────────────▶│                        │                   │
  │                          │                        │                   │
  │  [interactive inputs]    │                        │                   │
  │◀────────────────────────▶│                        │                   │
  │  hostname, user,         │                        │                   │
  │  password (x2),          │                        │                   │
  │  timezone, IPs,          │                        │                   │
  │  webhook                 │                        │                   │
  │                          │                        │                   │
  │                          │ generate SSH key       │                   │
  │                          │ (~/.ssh/id_ed25519_*)  │                   │
  │                          │                        │                   │
  │  identify SD card        │                        │                   │
  │─────────────────────────▶│                        │                   │
  │                          │                        │                   │
  │  confirm YES             │                        │                   │
  │─────────────────────────▶│                        │                   │
  │                          │                        │                   │
  │                          │ download + verify      │                   │
  │                          │ Pi OS image (SHA256)   │                   │
  │                          │                        │                   │
  │                          │ disable macOS          │                   │
  │                          │ auto-mount             │                   │
  │                          │                        │                   │
  │                          │ dd flash to SD card    │                   │
  │                          │──────────────────────▶ │                   │
  │                          │                        │                   │
  │                          │ re-enable auto-mount   │                   │
  │                          │                        │                   │
  │                          │ mount boot partition   │                   │
  │                          │ write userconf.txt     │                   │
  │                          │ write ssh (empty file) │                   │
  │                          │                        │                   │
  │                          │ generate:              │                   │
  │                          │ - setup-mac-ssh.sh     │                   │
  │                          │ - harden-pi.sh         │                   │
  │                          │                        │                   │
  │                          │ eject SD card          │                   │
  │                          │──────────────────────▶ │                   │
  │                          │                        │                   │
  │  [physical steps]        │                        │                   │
  │  insert SD, connect      │                        │                   │
  │  ethernet, power on      │                        │                   │
  │─────────────────────────────────────────────────▶ │                   │
  │                          │                        │ boot              │
  │                          │                        │──────────────────▶│
  │                          │                        │                   │
  │                          │                        │ read userconf.txt │
  │                          │                        │◀──────────────────│
  │                          │                        │ create user piop  │
  │                          │                        │                   │
  │                          │                        │ read ssh file     │
  │                          │                        │◀──────────────────│
  │                          │                        │ enable sshd       │
  │                          │                        │                   │
  │  ./setup-mac-ssh.sh      │                        │                   │
  │─────────────────────────▶│                        │                   │
  │                          │ write ~/.ssh/config    │                   │
  │                          │ ping loop (30 attempts)│                   │
  │                          │──────────────────────▶ │                   │
  │                          │◀──────────────────────  │                   │
  │                          │ test SSH connection    │                   │
  │                          │──────────────SSH──────▶ │                   │
  │                          │◀──────────────────────  │                   │
  │                          │                        │                   │
  │  [KIRO AGENT TAKES OVER] │                        │                   │
  │                          │                        │                   │
  │                          │ copy harden-pi.sh      │                   │
  │                          │──────────────SSH──────▶ │                   │
  │                          │                        │                   │
  │                          │ sudo bash harden-pi.sh │                   │
  │                          │──────────────SSH──────▶ │                   │
  │                          │                        │ apt update/upgrade│
  │                          │                        │ install packages  │
  │                          │                        │ set timezone      │
  │                          │                        │ inject SSH key    │
  │                          │                        │ harden sshd       │
  │                          │                        │ configure UFW     │
  │                          │                        │ configure fail2ban│
  │                          │                        │ install watchdog  │
  │                          │                        │ configure SSH     │
  │                          │                        │ client for node   │
  │                          │◀──────────────────────  │                   │
  │                          │                        │                   │
  │  Pi is hardened          │                        │                   │
  │  Continue with           │                        │                   │
  │  01-hardware-prep.md     │                        │                   │
```

---

## 3. Security Findings

### 3.1 CRITICAL

**C1 — Password transmitted in plaintext to `userconf.txt`**
- **Location:** `flash-jumphost.sh` STEP 8, boot partition injection
- **Issue:** `PI_PASSWORD` is collected interactively and used to generate a SHA-512 hash via `openssl passwd -6` or Python's `crypt` module. The hash is written to `userconf.txt` on the SD card boot partition. The plaintext password exists in memory during the script execution and is never written to disk — this is acceptable. However, the password is also stored in `PI_PASSWORD` shell variable for the duration of the script, which could be exposed via `/proc/$$/environ` on Linux (not applicable on macOS).
- **Risk:** Low on macOS. The password is temporary — `harden-pi.sh` disables password auth entirely.
- **Recommendation:** Explicitly unset `PI_PASSWORD` and `PI_PASSWORD_CONFIRM` immediately after `HASHED_PASSWORD` is generated.

**C2 — SSH private key generated without passphrase**
- **Location:** `flash-jumphost.sh` STEP 3
- **Issue:** `ssh-keygen ... -N ""` generates the key with an empty passphrase. If the Mac is compromised, the key provides immediate access to the Pi with no additional factor.
- **Risk:** Medium. The Pi is on a local network only, but the key is the sole authentication mechanism after hardening.
- **Recommendation:** Prompt for a key passphrase, or document the tradeoff explicitly. For a home lab jump host this is acceptable but should be a conscious decision.

**C3 — `harden-pi.sh` contains the SSH public key as a literal string**
- **Location:** `flash-jumphost.sh` STEP 9, `harden-pi.sh` generation
- **Issue:** `MAC_PUBKEY` is substituted into `harden-pi.sh` via `sed`. The generated script contains the full public key as a literal string. Public keys are not secret, but the generated script also contains `WEBHOOK_URL` which may be a sensitive Discord/Telegram webhook URL.
- **Risk:** Low for the public key. Medium for the webhook URL — anyone with the generated `harden-pi.sh` can post to your webhook channel.
- **Recommendation:** `harden-pi.sh` is already in `.gitignore`. Add a warning in the script header that it contains sensitive values and should not be shared.

### 3.2 MEDIUM

**M1 — `setup-mac-ssh.sh` uses `StrictHostKeyChecking=accept-new`**
- **Location:** `setup-mac-ssh.sh.template` STEP 3
- **Issue:** `StrictHostKeyChecking=accept-new` automatically accepts new host keys without verification. This is vulnerable to a MITM attack on first connection — an attacker on the local network could present a fake Pi.
- **Risk:** Low in a home network context. Higher if the network is shared or untrusted.
- **Recommendation:** After first connection, verify the host key fingerprint manually: `ssh-keygen -l -f ~/.ssh/known_hosts`. Document this step in the guide.

**M2 — `harden-pi.sh` restarts SSH daemon mid-session**
- **Location:** `harden-pi.sh.template` STEP 4
- **Issue:** `systemctl restart ssh` is called while the script is running over SSH. If the restart takes longer than the `ServerAliveInterval`, the connection drops and the script is killed mid-execution, leaving SSH in a partially hardened state.
- **Risk:** Medium. SSH hardening may be incomplete — `PasswordAuthentication no` may be set but the service not restarted, leaving the old config active.
- **Recommendation:** Use `systemctl reload ssh` instead of `restart` where possible, or run the SSH hardening as the last step before a deliberate reconnect.

**M3 — `setup-mac-ssh.sh` polls for `firstrun.log` that no longer exists**
- **Location:** `setup-mac-ssh.sh.template` STEP 4
- **Issue:** The template still polls for `grep -q 'First-run hardening complete' /var/log/firstrun.log` — but with the new minimal flash approach, `firstrun.sh` no longer runs and this file will never exist. The poll will always timeout.
- **Risk:** Low — the poll times out gracefully. But it's misleading and wastes 2 minutes.
- **Recommendation:** Remove STEP 4 from `setup-mac-ssh.sh.template` entirely, or replace it with a check that `harden-pi.sh` has been run.

**M4 — Webhook URL stored in generated script without encryption**
- **Location:** `harden-pi.sh` (generated)
- **Issue:** The Discord/Telegram webhook URL is embedded as plaintext in `harden-pi.sh` and also in the watchdog script on the Pi at `/home/piop/scripts/node-watchdog.sh`.
- **Risk:** Anyone with read access to the Pi or the generated script can post to your webhook channel.
- **Recommendation:** Store the webhook URL in a separate config file with restricted permissions (`chmod 600`), not embedded in the script.

### 3.3 LOW / INFORMATIONAL

**L1 — `sudo defaults write` modifies system-wide macOS settings**
- The script disables `AutomountDisksWithoutUserApproval` system-wide during flash. If the script crashes before re-enabling it, all removable volumes will stop auto-mounting until manually restored.
- **Recommendation:** Add a `trap` to re-enable auto-mount on script exit/error.

**L2 — `dd` flash has no integrity verification**
- After writing the image, there is no read-back verification that the written data matches the source. A failing SD card could silently write corrupted data.
- **Recommendation:** Add `dd if="$RAW_DEVICE" bs=4m count=$((IMAGE_SIZE / 4194304)) | sha256sum` after flash and compare against the known image hash.

**L3 — `userconf.txt` left on boot partition after first boot**
- Raspberry Pi OS deletes `userconf.txt` after processing it on first boot. However, if the Pi is powered off before this happens, the hashed password remains readable on the boot partition.
- **Risk:** The hash is SHA-512 crypt — computationally expensive to crack. Low risk.
- **Recommendation:** Document that the password is temporary and will be disabled by `harden-pi.sh`.

**L4 — No SSH key rotation mechanism**
- The generated SSH key (`id_ed25519_<hostname>`) has no expiry and no rotation procedure.
- **Recommendation:** Add a key rotation step to `10-pending-improvements.md`.

**L5 — `harden-pi.sh` uses `set -euo pipefail` but SSH restart can cause exit**
- If `systemctl restart ssh` causes the SSH session to drop, `set -e` will catch the non-zero exit and terminate the script, potentially leaving hardening incomplete.
- **Recommendation:** Wrap the SSH restart in `|| true` and verify the service is running in a subsequent step.

---

## 4. Recommendations Summary

| Priority | Finding | Recommendation |
|---|---|---|
| Critical | C1 — Password in memory | Unset `PI_PASSWORD` after hash generation |
| Critical | C2 — Key without passphrase | Prompt for passphrase or document tradeoff |
| Critical | C3 — Webhook in generated script | Add sensitive data warning to script header |
| Medium | M1 — MITM on first SSH | Document host key verification step |
| Medium | M2 — SSH restart mid-session | Use `reload` or restructure hardening order |
| Medium | M3 — Stale firstrun.log poll | Remove or replace STEP 4 in setup-mac-ssh.sh |
| Medium | M4 — Webhook URL plaintext | Store in separate `chmod 600` config file |
| Low | L1 — auto-mount not restored on crash | Add `trap` to re-enable on exit |
| Low | L2 — No post-flash verification | Add read-back SHA256 check |
| Low | L3 — userconf.txt on boot partition | Document temporary password lifecycle |
| Low | L4 — No key rotation | Add to pending improvements |
| Low | L5 — set -e + SSH restart | Wrap restart in `|| true` |

---

## 5. Positive Security Observations

These are things the scripts do well:

- **SHA256 verification** of the OS image before flashing — prevents corrupted or tampered images
- **Password confirmation** — prevents typos setting an unknown password
- **Ed25519 keys** — modern, secure key type preferred over RSA
- **Minimal flash approach** — no code execution at boot time reduces attack surface dramatically
- **`set -euo pipefail`** — fails fast on errors, prevents silent failures
- **Write-protect detection** — prevents writing to a locked card
- **Minimum SD size check** — prevents mid-write failures
- **`harden-pi.sh` runs in a proper environment** — network up, systemd running, user exists — eliminates the entire class of boot-time script failures
- **Generated scripts are gitignored** — sensitive values don't end up in version control
- **UFW default deny** — correct default posture
- **fail2ban with 24h ban** — aggressive but appropriate for a security boundary device

---

## 6. Architecture Assessment

The current three-script architecture is well-structured:

```
flash-jumphost.sh     → Minimal: flash + enable SSH only
setup-mac-ssh.sh      → Connectivity: configure Mac SSH + verify Pi reachable  
harden-pi.sh          → Hardening: all security config over SSH in proper env
```

This separation of concerns is the right pattern. The previous approach (firstrun.sh at boot) conflated flashing with hardening and ran in an environment that couldn't support it reliably. The current approach is more robust, more debuggable, and easier to reason about.

The main architectural gap is that `setup-mac-ssh.sh` still has a stale reference to `firstrun.log` (M3) and doesn't yet trigger `harden-pi.sh` automatically. The full automation loop — flash → boot → SSH confirmed → harden — is not yet closed end-to-end.

**Recommended next step:** Update `setup-mac-ssh.sh.template` to automatically run `harden-pi.sh` over SSH after confirming connectivity, completing the automation loop.
