# Kiro Rocket Pool Node Guide

A collaborative guide to set up a Rocket Pool Saturn 1 Ethereum staking node — written together with Kiro AI.

---

## Why This Exists

This project started from two goals that ended up being the same thing.

**Goal 1: Set up a Rocket Pool staking node.**
I wanted to run my own Ethereum validator using Rocket Pool's Saturn 1 protocol — a 4 ETH bond, a Beelink GTI15 mini PC, and a proper home staking setup. The existing guides were either outdated, Debian-focused, or missing the security and operational depth I wanted.

**Goal 2: Learn to work with AI tools in a real, meaningful way.**
I've found that the best way to learn something new is to use it on something you actually care about. Not a tutorial. Not a toy project. Something real, with real stakes, where the tool either helps you or it doesn't.

So I used Kiro — an AI assistant built into my IDE — as a genuine collaborator. Not to generate boilerplate. Not to answer one-off questions. But to research, plan, write, debug, and iterate alongside me on a complex technical problem.

The result is this guide.

---

## What This Guide Does

Takes a Beelink GTI15 mini PC from bare metal to a fully operational Rocket Pool Saturn 1 Ethereum staking node, with:

- A Raspberry Pi 2 as a dedicated security jump host — your SSH key to the node never touches your daily Mac
- Ubuntu 24.04.4 LTS with kernel 6.17 (HWE) for native Arrow Lake hardware support
- Nethermind + Nimbus as minority clients — contributing to Ethereum client diversity
- Saturn 1 megapool configuration (4 ETH bond, standard queue)
- Hoodi testnet validation before any real ETH is at stake
- A mainnet queue strategy — deposit to get in line, validate on testnet in parallel, switch before assignment
- Security hardening throughout — SSH key-only auth, UFW, fail2ban, kernel hardening

---

## What This Project Is Really About

Every phase of this guide was researched, cross-referenced, and written by Kiro based on a conversation. The source material was a set of earlier Debian and Ubuntu guides, official Rocket Pool docs, and live web research. Kiro identified the gaps, proposed the structure, and wrote the content. I shaped the direction, made the decisions, and tested the result.

That's the model: **you bring the goal and the judgment, Kiro brings the research and the execution.**

Some things I learned along the way:

- AI is most useful when you give it a real problem, not a fake one
- The quality of the output is directly proportional to the quality of your direction
- Complex, repetitive, security-sensitive work — exactly the kind that's easy to get wrong — is where AI collaboration pays off most
- Writing things down properly (specs, steering files, structured guides) makes the AI dramatically more useful across sessions

This repo is the artifact of that learning process. The commit history reflects the real journey — every correction, every gap found during testing, every decision revisited.

---

## Repository Structure

```
README.md                          ← You are here
SOURCES.md                         ← Research sources and prior art
kiro-rocketpool-guide/             ← The complete guide
  README.md                        ← Guide index and table of contents
  00-prerequisites.md              ← What you need before starting
  00b-jump-host-setup.md           ← Raspberry Pi 2 jump host setup
  01-hardware-prep.md              ← BIOS flash, WD firmware
  02-os-install.md                 ← Ubuntu install + SSH handoff
  HANDOFF.md                       ← Agent entry point
  03-security-hardening.md         ← SSH, UFW, fail2ban, kernel hardening
  04-storage-docker.md             ← 4TB NVMe + Docker
  05-smartnode-install.md          ← Rocket Pool CLI
  06-testnet-setup.md              ← Testnet config + validator + metrics
  07-mainnet-queue.md              ← Mainnet deposit + parallel testnet
  08-mainnet-transition.md         ← Go-live checklist
  09-appendix.md                   ← Troubleshooting, maintenance, RPL staking
  10-pending-improvements.md       ← Deferred improvements tracker
  scripts/flash-jumphost.sh        ← Automated Pi SD card flash script
```

The original source guides that informed this work are also included at the root — see `SOURCES.md` for context.

---

## Hardware

| Component | Spec |
|---|---|
| Node | Beelink GTI15 (Intel Core Ultra 9 285H, 64GB DDR5) |
| OS drive | 1TB built-in NVMe |
| Chain data | 4TB WD Black SN850X |
| Network | Dual Intel 10Gbps Ethernet |
| OS | Ubuntu 24.04.4 LTS (kernel 6.17 HWE) |
| Jump host | Raspberry Pi 2 (Raspberry Pi OS Lite 32-bit) |

---

## Status

🟡 **Alpha v1.0** — Guide is complete and under active testing. Expect corrections and improvements as the hardware setup is validated in real conditions. Follow the commit history to see what changed and why.

---

## Contributing

Found an error? Something unclear? Open an issue or a PR. Every correction makes the guide better for the next person.

If you're using this guide and hit something unexpected, the most useful thing you can do is describe exactly what you saw vs what the guide said — that's the feedback that improves it.

---

*Written collaboratively by Yoel Zumbado and [Kiro](https://kiro.dev), April 2026.*
