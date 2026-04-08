---
inclusion: always
---

# Session State — Rocket Pool Node Setup

This file tracks the current state of the setup. Kiro reads it at the start of every session to know where we are. Update it as you progress — either manually or by asking Kiro to update it for you.

---

## Setup Values

These are the actual values configured during setup. Kiro uses these so you don't have to repeat yourself.

```yaml
# Jump Host (Raspberry Pi 2)
pi_hostname: ""           # e.g. pi-client
pi_user: ""               # e.g. piop
pi_host: ""               # e.g. pi-client.local or 192.168.1.10
pi_ssh_key: ""            # e.g. ~/.ssh/id_ed25519_pi-client

# Node (Beelink GTI15)
node_hostname: ""         # e.g. rp-node01
node_host: ""             # e.g. rp-node01.local or 192.168.1.20
node_user: nodeop

# Network
static_ips_configured: false
subnet: ""                # e.g. 192.168.1.0/24

# Rocket Pool
network: ""               # testnet or mainnet
smartnode_version: ""     # e.g. v1.19.4
wallet_address: ""        # node wallet address (not the seed phrase)
withdrawal_address: ""    # cold wallet address
validator_pubkey: ""      # mainnet validator public key
queue_position: ""        # at time of deposit
estimated_activation: ""  # estimated date

# Monitoring
grafana_url: ""           # e.g. http://rp-node01.local:3100
webhook_url: ""           # Discord/Telegram webhook for watchdog alerts
```

---

## Phase Progress

Update status as each phase completes. Kiro uses this to know where to continue.

| Phase | Description | Status | Date | Notes |
|---|---|---|---|---|
| 0b | Jump host — Pi flash + SSH setup | ○ | | |
| 0 | Hardware prep — BIOS flash | ○ | | |
| 1 | Ubuntu install | ○ | | |
| 2 | First boot + SSH handoff | ○ | | |
| 3 | Security hardening | ○ | | |
| 4 | Storage configuration | ○ | | |
| 5 | Docker install | ○ | | |
| 6 | Smartnode install | ○ | | |
| 7 | Testnet configuration | ○ | | |
| 7.5 | Testnet validator creation | ○ | | |
| 8 | Testnet validation + metrics | ○ | | |
| 9 | Mainnet queue deposit | ○ | | |
| 10 | Parallel testnet operation | ○ | | |
| 11 | Mainnet transition | ○ | | |

*Status: ○ not started · ↻ in progress · ✓ complete · ! blocked*

---

## Open Issues / Blockers

*Use this section to track anything that needs attention before moving forward.*

| Date | Phase | Issue | Status |
|---|---|---|---|
| Apr 2026 | 0b | `setup-mac-ssh.sh.template` still polls for `firstrun.log` which no longer exists (M3 from security audit). Needs: remove stale poll, add explicit human approval flow before running `harden-pi.sh` | ↻ in progress — see TASKS.md T1 |
| Apr 2026 | 0b | Project docs partially outdated — some files still reference old firstrun.sh approach | ↻ in progress — see TASKS.md T2 |

---

## Session Log

*Brief notes from each session — what was done, what was decided.*

| Date | Summary |
|---|---|
| Apr 2026 | Major architecture refactor: removed firstrun.sh from flash process. Flash now minimal (userconf.txt + ssh file only). All hardening moved to harden-pi.sh which runs over SSH after boot. Created security audit (SECURITY-AUDIT.md). Created kiro-dev.md steering file for maintainer sessions. Created TASKS.md for short-term task tracking. Fixed 12 backlog issues from code review. |
