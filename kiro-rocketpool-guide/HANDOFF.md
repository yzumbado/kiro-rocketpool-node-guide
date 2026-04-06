# 🤝 Handoff Point — Agent Entry

**SSH is working. This is where Kiro takes over.**

---

## For the Human

To hand off execution to Kiro, open a new chat and say:

> *"I've completed the human section of the Kiro Rocket Pool Node Guide. My node hostname is `rp-node01.local`, username is `nodeop`. Access is via the Pi jump host at `pi-jumphost.local`. Please continue from Phase 3 — start with the bootstrap check in HANDOFF.md."*

---

## For the Agent

> 🤖 **Agent note:** On receiving the handoff, run the bootstrap check below first. Confirm Ubuntu 24.04.4, kernel 6.17+, and available disk space on `/` before proceeding. All subsequent phases are executable over SSH.

### Bootstrap Check

```bash
# Run this first — confirm the environment before touching anything
echo "=== Node Bootstrap Check ===" && \
lsb_release -d && \
uname -r && \
hostname -I && \
df -h / && \
df -h /dev/nvme* 2>/dev/null || true && \
echo "=== BOOTSTRAP COMPLETE ==="
```

**Expected output:**
```
=== Node Bootstrap Check ===
Description: Ubuntu 24.04.4 LTS
6.17.x-xx-generic
192.168.x.x
/dev/nvme0n1p2   xxx   xxx   xxx  xx% /
=== BOOTSTRAP COMPLETE ===
```

If the output shows a different Ubuntu version or kernel below 6.17, stop and report to the user before proceeding.

### Execution Order

Once bootstrap passes, execute the agent section files in this order:

1. [03-security-hardening.md](./03-security-hardening.md)
2. [04-storage-docker.md](./04-storage-docker.md)
3. [05-smartnode-install.md](./05-smartnode-install.md)
4. [06-testnet-setup.md](./06-testnet-setup.md)
5. [07-mainnet-queue.md](./07-mainnet-queue.md) ← requires human approval for ETH transactions
6. [08-mainnet-transition.md](./08-mainnet-transition.md)

**Stop and request human input at any step marked** 🔴
