# Research Sources & Prior Art

This guide was built from the following source material. These files informed the decisions, hardware notes, and configuration choices throughout the guide.

---

## Original Setup Guides (Included in this repo)

These are earlier iterations of node setup guides for the same hardware, written before this guide existed. They document the Debian 12 path that was ultimately replaced by Ubuntu 24.04.4.

| File | Description |
|---|---|
| `beelink_gti15_rocketpool_setup_guide.md` | Debian 12 setup guide for the Beelink GTI15 — the primary source this guide was derived from |
| `debian_beelink_setup_notes.md` | Hardware quirk notes for Debian on the GTI15 (kernel requirements, NVMe issues) |
| `debian_12_install_guide.md` | General Debian 12 installation reference |
| `ubuntu_24_04_rocketpool_setup_guide.md` | Earlier Ubuntu guide — the direct predecessor to this one |
| `Debian_install.txt` | Official Debian 12 installation manual (text format) |

---

## External Sources (Not included — referenced only)

| Source | URL | Usage |
|---|---|---|
| Rocket Pool Documentation | `https://docs.rocketpool.net` | Node operator responsibilities, hardware requirements, Smartnode setup, Saturn 1 megapool |
| Rocket Pool Saturn 1 | `https://saturn.rocketpool.net` | Saturn 1 feature details, 4 ETH bond, megapool mechanics |
| Checkpoint Sync Endpoints | `https://eth-clients.github.io/checkpoint-sync-endpoints/` | Hoodi testnet checkpoint sync URLs |
| Beelink Support | `https://www.bee-link.com/blogs/all` | GTI15 BIOS updates |
| Ubuntu Server Install Guide | `https://ubuntu.com/tutorials/install-ubuntu-server` | Installer walkthrough reference |
| Raspberry Pi Imager | `https://www.raspberrypi.com/software/` | Pi OS flash tool |
| Client Diversity | `https://clientdiversity.org/` | Nethermind/Nimbus selection rationale |

---

## How This Guide Was Made

This guide was written collaboratively between a human operator and **Kiro**, an AI assistant. The process involved:

1. Analyzing the existing source guides and identifying gaps
2. Live web research into current best practices (Saturn 1, Ubuntu 24.04.4, checkpoint sync URLs)
3. Iterative writing with the human shaping direction and Kiro providing research and execution
4. Real-world testing against actual hardware

The collaboration model itself is documented in the guide's intro section — this project is as much about demonstrating human+AI collaboration as it is about Rocket Pool node setup.
