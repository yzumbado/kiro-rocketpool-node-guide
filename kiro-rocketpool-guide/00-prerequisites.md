# Before You Start

## What you need

| Item | Details |
|---|---|
| Hardware | Beelink GTI15 (Intel Core Ultra 9 285H, 64GB DDR5, 1TB OS NVMe, 4TB WD Black SN850X) |
| Raspberry Pi 2 | Jump host — security boundary between your Mac and the node (any revision) |
| MicroSD card | 16GB+ for the Pi |
| USB drive | One 16GB+ USB drive — used first for the BIOS flash, then reformatted for the Ubuntu installer |
| Network | Wired Ethernet to your router for both the Pi and the node — no Wi-Fi during setup |
| Testnet ETH | Hoodi testnet ETH for gas — faucet at `https://hoodi.ethpandaops.io/` |
| Mainnet ETH | 4 ETH bond + ~0.1 ETH for gas (Saturn 1 megapool deposit) |
| Cold wallet | A hardware wallet (Ledger/Trezor) for your withdrawal address — non-negotiable |
| Time | ~5–7 hours for full setup (includes Pi), then 2–3 days for chain sync |

> 💡 **Tip:** One USB drive is enough for the node setup. Use it for the BIOS flash first, then wipe and reuse it for the Ubuntu installer.

## Static IP Reservations

> 📝 **Note:** Static IP reservations require a router that supports DHCP reservations. If you don't have your final router yet, skip this section — the guide uses `.local` hostnames throughout which work without any router configuration. See [10-pending-improvements.md](./10-pending-improvements.md) for how to add static IPs later.

When you have your final router, set DHCP reservations so both devices always get the same IP:

| Device | Hostname | Suggested Reserved IP |
|---|---|---|
| Raspberry Pi 2 | `pi-jumphost` | `192.168.1.10` |
| Beelink GTI15 | `rp-node01` | `192.168.1.20` |

## Setup Order

1. **[00b-jump-host-setup.md](./00b-jump-host-setup.md)** — Set up the Pi first. It becomes your management machine for everything that follows.
2. **[01-hardware-prep.md](./01-hardware-prep.md)** — BIOS flash on the Beelink (done from Windows, not the Pi)
3. **[02-os-install.md](./02-os-install.md)** — Ubuntu install + SSH handoff to the Pi
4. **[HANDOFF.md](./HANDOFF.md)** — Hand off to Kiro for all remaining phases
