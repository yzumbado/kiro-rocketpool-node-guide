# 🚀 Kiro's Guide to Running a Rocket Pool Node
### Ubuntu 24.04 LTS + Beelink GTI15 + Saturn 1 Edition

> **Last validated:** April 2026 | **Smartnode version:** v1.19.4 | **Ubuntu:** 24.04.4 LTS (kernel 6.17)

---

## About This Guide

This is a collaborative guide — written and executed together by a human and **Kiro**, an AI assistant built into the IDE.

The goal is to take a Beelink GTI15 mini PC from bare metal to a fully operational Rocket Pool Saturn 1 Ethereum staking node. But there's a second goal running in parallel: to demonstrate what it looks like to use AI as a real partner in solving a complex technical problem — not just answering questions, but researching, planning, writing, and executing alongside you.

**How the collaboration works:**

The guide is split into two sections with a clear handoff point:

- **Human section (Phases 0–2):** Physical setup — BIOS, OS install, and getting SSH working. These steps require hands on the hardware. Kiro can guide you, but can't click buttons for you. Yet.
- **Agent section (Phases 3–11):** Once SSH is live, Kiro can connect to your node and execute every remaining phase directly. You stay in the loop, approve decisions, and handle anything that involves real money or seed phrases.

**Why this matters beyond staking:**

Every phase of this guide was researched, cross-referenced, and written by Kiro based on a conversation — not a pre-written template. The source material was a set of earlier Debian and Ubuntu guides, official Rocket Pool docs, and live web research into current best practices. Kiro identified the gaps, proposed the structure, and wrote the content. You shaped the direction.

That's the model: you bring the goal and the judgment, Kiro brings the research and the execution. Neither of you could do this as well alone.

> 📝 **Note:** This guide is specific to the Beelink GTI15 hardware. The Rocket Pool and security sections apply broadly to any Ubuntu 24.04 server, but the BIOS and hardware steps are hardware-specific.

---

## Table of Contents

### 🧑 Human Section — Physical Setup
| File | Contents | Est. Time |
|---|---|---|
| [00-prerequisites.md](./00-prerequisites.md) | What you need before starting | 5 min read |
| [00b-jump-host-setup.md](./00b-jump-host-setup.md) | Jump host: Raspberry Pi 2 setup + hardening | 45 min |
| [scripts/flash-jumphost.sh](./scripts/flash-jumphost.sh) | Automated SD card flash script (run on Mac) | 10 min |
| [01-hardware-prep.md](./01-hardware-prep.md) | Phase 0: BIOS flash, WD firmware | 45 min |
| [02-os-install.md](./02-os-install.md) | Phase 1–2: Ubuntu install + SSH handoff | 45 min |

### 🤝 Handoff
| File | Contents |
|---|---|
| [HANDOFF.md](./HANDOFF.md) | Agent entry point — start here if taking over from SSH |

### 🤖 Agent Section — Remote Execution
| File | Contents | Est. Time |
|---|---|---|
| [03-security-hardening.md](./03-security-hardening.md) | Phase 3: SSH, UFW, fail2ban, kernel hardening | 30 min |
| [04-storage-docker.md](./04-storage-docker.md) | Phase 4–5: 4TB mount + Docker install | 25 min |
| [05-smartnode-install.md](./05-smartnode-install.md) | Phase 6: Rocket Pool CLI | 15 min |
| [06-testnet-setup.md](./06-testnet-setup.md) | Phase 7–8: Testnet config, validator, metrics | 2–3 days |
| [07-mainnet-queue.md](./07-mainnet-queue.md) | Phase 9–10: Mainnet deposit + parallel testnet | ~2 months |
| [08-mainnet-transition.md](./08-mainnet-transition.md) | Phase 11: Go-live checklist | 2 hours |

### 📚 Reference
| File | Contents |
|---|---|
| [09-appendix.md](./09-appendix.md) | Troubleshooting, maintenance, emergency procedures, RPL staking |
| [10-pending-improvements.md](./10-pending-improvements.md) | Deferred improvements: static IPs, UPS, backups, external access |

---

## How to Use This Guide

**If you're a human starting from scratch:** Begin with [00-prerequisites.md](./00-prerequisites.md), then set up your jump host with [00b-jump-host-setup.md](./00b-jump-host-setup.md) before touching the node hardware. Work through the files in order from there.

**If you're handing off to Kiro:** Complete the human section through [02-os-install.md](./02-os-install.md), then open [HANDOFF.md](./HANDOFF.md) and follow the instructions there. Kiro connects via the jump host.

**If you're an agent receiving a handoff:** Read [HANDOFF.md](./HANDOFF.md) first. It contains your bootstrap check and starting instructions.

**If you need to look something up:** Use the Table of Contents above to jump directly to the relevant file.
