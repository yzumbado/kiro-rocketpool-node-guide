---
inclusion: always
---

# Rocket Pool Node Guide — Project Steering File

This file gives Kiro full context on this project so every session starts informed, not cold. Read this before making any changes to the guide.

---

## What This Project Is

A collaborative technical guide to set up a Rocket Pool Ethereum staking node on a Beelink GTI15 mini PC running Ubuntu 24.04.4 LTS, configured for Saturn 1 (megapool, 4 ETH bond). The guide is written and maintained together by the human operator and Kiro.

The guide has a second purpose beyond staking: it is a demonstration of how to use AI as a real partner in solving a complex technical problem — researching, planning, writing, and executing together.

---

## Guide Location and File Structure

All guide files live in `kiro-rocketpool-guide/`:

```
README.md                  Master index + TOC + About This Guide
00-prerequisites.md        Hardware checklist + setup order
00b-jump-host-setup.md     Raspberry Pi 2 jump host — security boundary between Mac and node
01-hardware-prep.md        Phase 0: BIOS flash, WD firmware
02-os-install.md           Phase 1–2: Ubuntu install + SSH handoff
HANDOFF.md                 Agent entry point — bootstrap check + execution order
03-security-hardening.md   Phase 3: SSH hardening, UFW, fail2ban, sysctl
04-storage-docker.md       Phase 4–5: 4TB NVMe mount + Docker install
05-smartnode-install.md    Phase 6: Rocket Pool CLI v1.19.4
06-testnet-setup.md        Phase 7–8: Testnet config, validator creation, metrics
07-mainnet-queue.md        Phase 9–10: Mainnet deposit + parallel testnet operation
08-mainnet-transition.md   Phase 11: Go-live checklist
09-appendix.md             Troubleshooting, maintenance, emergency, RPL staking
10-pending-improvements.md Deferred improvements: static IPs, UPS, backups, external access
scripts/flash-jumphost.sh              Automated SD card flash script for the Pi (run on Mac)
scripts/setup-mac-ssh.sh.template      Source-of-truth template for post-boot Mac SSH setup
scripts/setup-mac-ssh.sh               Generated at runtime by flash-jumphost.sh (gitignored)
yoel-notes.md              Operator installation tracker — personal notes, fill in during setup
```

---

## Hardware Context

| Component | Spec |
|---|---|
| Machine | Beelink GTI15 |
| CPU | Intel Core Ultra 9 285H (Arrow Lake) |
| RAM | 64GB DDR5 |
| OS drive | 1TB built-in NVMe |
| Chain data drive | 4TB WD Black SN850X (mounted at `/mnt/ssd`) |
| Network | Dual Intel 10Gbps Ethernet |
| OS | Ubuntu 24.04.4 LTS (kernel 6.17 via HWE stack) |

**Jump host:** Raspberry Pi 2 (ARMv7, 1GB RAM) running Raspberry Pi OS Lite 32-bit. Hostname `pi-jumphost.local`. Acts as SSH security boundary and node watchdog. The node's SSH key lives only on the Pi, never on the operator's Mac. SD card flashed using `scripts/flash-jumphost.sh` which automates OS flash + first-boot hardening.

**Node hostname:** `rp-node01.local`

> 📝 **Note:** The guide currently uses `.local` mDNS hostnames throughout. Static IPs (`192.168.1.10` for Pi, `192.168.1.20` for node) are a pending improvement tracked in `10-pending-improvements.md` — deferred until the operator has their final router.

**Username on node:** `nodeop`
**Username on Pi:** `piop`
**Node hostname:** `rp-node01` (mDNS: `rp-node01.local`)
**Pi hostname:** `pi-jumphost` (mDNS: `pi-jumphost.local`)

---

## Key Technical Decisions and Rationale

**Ubuntu 24.04.4 over Debian 12**
Ubuntu 24.04.4 ships with kernel 6.17 (HWE) which natively supports Arrow Lake CPU and Intel 10Gbps NICs. Debian 12 requires manual backports kernel installation for the same hardware support.

**Kernel 6.8 vs 6.17**
The Ubuntu 24.04.4 installer boots with kernel 6.8 (GA). Kernel 6.17 (HWE) must be explicitly installed: `sudo apt install -y linux-generic-hwe-24.04`. This is done in Phase 2 Step 2.1.

**Nethermind + Nimbus (fixed, not random)**
Both are genuine minority clients (~5% EL, ~1% CL). On 64GB RAM hardware, Nimbus is the only CL that won't stress the RAM budget alongside Nethermind and Docker overhead. Random selection could land on Teku (RAM-heavy) or Geth (58% supermajority). Fixed minority pair is the right call for this hardware.

**Saturn 1 megapool**
4 ETH bond per validator. Single megapool contract manages multiple validators. Standard queue ~2 months. Express tickets limited under RPIP-75. Strategy: deposit on mainnet to enter queue, run testnet in parallel, switch before assignment.

**Smoothing pool**
Enabled. Post-Saturn operators get ~42% more than solo staking with smoothing pool vs ~15% without.

**MEV-Boost relays**
Flashbots (`boost-relay.flashbots.net`), bloXroute max profit, Ultrasound (`relay.ultrasound.money`). Minimum 2 relays.

**Checkpoint sync URL for Hoodi testnet**
`https://checkpoint-sync.hoodi.ethpandaops.io` — NOT the Holesky URL. The old guides used the wrong URL.

**Docker installed from official repo**
Not from Ubuntu's `docker.io` snap or apt package. Official repo gives current version with full `daemon.json` support needed for `data-root` redirect to 4TB drive.

**Docker data root**
`/mnt/ssd/docker` — all chain data on the 4TB NVMe, not the 1TB OS drive.

**Smartnode version**
v1.19.4 as of April 2026. Check `https://github.com/rocket-pool/smartnode/releases` for newer stable versions before installing.

**Raspberry Pi OS Lite 32-bit**
Pi 2 has ARMv7 CPU — cannot run 64-bit OS. Ubuntu Server for Pi drops 32-bit support. Raspberry Pi OS Lite 32-bit is the only actively maintained minimal option.

**Static IPs via router DHCP reservation**
Deferred — not yet configured. The guide uses `.local` mDNS hostnames throughout (`pi-jumphost.local`, `rp-node01.local`). When the operator has their final router, static IPs will be added via DHCP reservation. Full instructions in `10-pending-improvements.md` item 1. When static IPs are set, SSH configs on both Mac and Pi need updating, and UFW on the Pi should be tightened to subnet-only (pending improvement 2).

---

## Collaboration Model

The guide is split into two sections with a clear handoff point:

**Human section (Phases 0–2 + jump host setup):** Physical setup requiring hands on hardware. Marked `🧑 Human required`. Kiro guides but cannot execute.

**Agent section (Phases 3–11):** Executed over SSH. Kiro can run these directly. Steps involving real funds or seed phrases are marked `🔴` and require human approval.

**Handoff:** When the human completes Phase 2 and SSH is working, they open a new chat and say: *"I've completed the human section. My node IP is `192.168.1.20`, username is `nodeop`. Please continue from Phase 3."* Kiro reads `HANDOFF.md` first, runs the bootstrap check, then proceeds.

---

## Style Guide

**Voice:** Second person ("you"), present tense, imperative commands. Professional structure like AWS guides but with personality — dry humor on dangerous steps, acknowledgment of long waits, no filler.

**Phase header template:**
```
## Phase N: Title
⏱ Estimated time: X min | 🎯 Difficulty: Easy / Medium / Hard
```

**"Why this matters" boxes:** Only when the reason is non-obvious or stakes are high. Not on every step.

**Callout types:**
- `> 📝 **Note:**` — extra context
- `> ⚠️ **Warning:**` — you could break something
- `> 🔴 **Critical:**` — you could lose funds or lock yourself out
- `> 💡 **Tip:**` — optional improvement
- `> 🤖 **Agent note:**` — machine-readable hints for automated execution

**Code blocks:** Every command in its own fenced bash block with a comment explaining what it does. Never inline for commands to run.

**Expected output:** Show truncated expected output after key commands.

**Verification blocks:** End of every phase. Machine-checkable `PASS/FAIL` pattern:
```bash
command && echo "PASS" || echo "FAIL"
```

**Decision tables:** When choosing between options (OS, clients, tools), use a table with verdict and reason columns.

**Agent-executable additions:**
- Every verification has an unambiguous exit condition
- Destructive commands have pre-condition checks
- Steps requiring human judgment marked `🧑 Human required`
- Phase dependencies stated explicitly at the top

**Emojis:** Purposeful, not decorative. ⚠️ on genuinely dangerous steps. ✅ on verification checkpoints. Not one per bullet point.

**Version pinning:** Specific versions for this release. Add a note pointing to the release page for checking newer versions.

**What NOT to do:**
- No wall-of-text paragraphs
- No repeating the same warning multiple times
- No "Congratulations!" filler
- No assuming "it should work" is sufficient

---

## Audience

Terminal-comfortable but not necessarily a Linux expert. The guide should also be executable by an agent (Kiro) over SSH for the agent section. Assumes basic terminal comfort, not Linux mastery.

---

## Current State and Known Issues

- Guide is complete through all 11 phases + appendices + jump host setup + pending improvements
- All content validated against: Ubuntu 24.04.4 installer behavior (kernel 6.8 on first boot, 6.17 after HWE install), Hoodi testnet checkpoint sync URLs, Smartnode v1.19.4 release notes, Saturn 1 launch (Feb 18 2026)
- `.local` mDNS hostnames used throughout — static IPs deferred to `10-pending-improvements.md`
- Pi flash script (`scripts/flash-jumphost.sh`) automates SD card flash + first-boot hardening + post-boot SSH setup. Install rpi-imager with `brew install --cask raspberry-pi-imager` and pv with `brew install pv`. The script generates `setup-mac-ssh.sh` at runtime from `setup-mac-ssh.sh.template`.
- `setup-mac-ssh.sh.template` is the source of truth for post-boot Mac SSH setup. The generated `setup-mac-ssh.sh` is gitignored (contains user-specific values).
- Post-flash flow: auto-eject → physical instructions → animated ping loop → SSH config write → connection test → hardening completion poll → ready confirmation.
- `yoel-notes.md` is the operator's personal installation tracker — fill in during setup
- UFW on the Pi currently allows SSH on port 22 broadly. Tightening to subnet-only is pending improvement #2 (requires static IPs first)

---

## Things to Keep in Mind

- Always check `https://github.com/rocket-pool/smartnode/releases` before referencing a Smartnode version
- Always check `https://eth-clients.github.io/checkpoint-sync-endpoints/` before referencing checkpoint sync URLs
- The AHCI/NVME BIOS setting was removed — could not be confirmed as accessible in the GTI15 BIOS
- The T205 BIOS is current as of April 2026 for the GTI15 — check `https://www.bee-link.com/blogs/all` for newer versions
- When the operator mentions running commands, they are connecting via the Pi jump host (`pi-jumphost.local`), not directly from their Mac
- All hostnames use `.local` mDNS — do not substitute IPs unless the operator confirms static IPs have been configured
- `brew install rpi-imager` does NOT work — correct command is `brew install --cask raspberry-pi-imager`
- Static IPs and subnet-restricted UFW are tracked in `10-pending-improvements.md` — do not treat them as current config

## Steering Files in This Project

| File | Purpose | Inclusion |
|---|---|---|
| `rocketpool-guide.md` | Full project context — hardware, decisions, file structure, technical rationale | Always |
| `session-state.md` | Current phase progress, setup values, blockers, session log | Always |
| `onboarding.md` | How to open every session — greeting templates based on state | Always |
| `persona.md` | How Kiro presents itself — tone, behavior, what to proactively surface | Always |
