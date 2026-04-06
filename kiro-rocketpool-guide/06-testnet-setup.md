# Phase 7: Testnet Configuration (Hoodi)
⏱ Estimated time: 20 min | 🎯 Difficulty: Easy

> *Why this matters: You are about to configure software that will eventually hold real ETH and sign blocks on Ethereum mainnet. Running on Hoodi testnet first lets you validate every part of the stack — sync, attestations, MEV, Grafana — with fake ETH. Mistakes here cost nothing. Mistakes on mainnet can cost everything.*

### Step 7.1: Client Selection — Nethermind + Nimbus

Before launching the config wizard, understand what you're choosing and why.

**Execution client: Nethermind**

| | Nethermind | Geth (default) |
|---|---|---|
| Network share | ~5% | ~58% |
| Sync speed | Fast (snap sync) | Fast |
| RAM usage | Moderate | Moderate |
| Risk if bug hits | You're in the minority — protected | 58% of the network goes down together |

**Consensus client: Nimbus**

| | Nimbus | Lighthouse / Prysm |
|---|---|---|
| Network share | ~1% | ~35% / ~30% |
| RAM usage | Lowest of all CL clients | Higher |
| CPU usage | Lowest of all CL clients | Higher |
| Risk if bug hits | You're in the minority — protected | Majority outage possible |

**Why not random client selection?**

The Rocket Pool docs suggest random selection to improve network diversity. That's philosophically correct — but on this specific hardware (64GB RAM, always-on home node), Nethermind + Nimbus is the better fixed choice because:

- Nimbus is the only CL client that won't stress the RAM budget when running alongside Nethermind and Docker overhead
- Both are genuine minority clients — you're contributing to diversity, not hiding from it
- Random selection could land you on Teku (RAM-heavy) or Geth (supermajority) — neither is ideal here

> 📝 **Note:** If you ever migrate to higher-spec hardware, reconsider random selection. On a 128GB+ machine, all client combinations are viable.

### Step 7.2: Launch the Configuration Wizard

```bash
rocketpool service config
```

Work through the wizard with these selections:

| Setting | Value | Reason |
|---|---|---|
| Network | **Hoodi Testnet** | Safe practice environment with fake ETH |
| Client Mode | **Locally Managed** | Docker mode — Rocket Pool manages the containers |
| Execution Client | **Nethermind** | Minority client, fast sync, good RAM profile |
| Consensus Client | **Nimbus** | Lowest resource usage, <1% network share |
| Checkpoint Sync URL | `https://checkpoint-sync.hoodi.ethpandaops.io` | Syncs beacon chain in minutes instead of days |
| Doppelganger Protection | **Yes** | Waits on restart to confirm your keys aren't running elsewhere — prevents slashing |
| MEV-Boost | **Enabled** | See Step 7.3 |
| Smoothing Pool | **Enabled** | See Step 7.3 |

> ⚠️ **Warning:** The checkpoint sync URL in earlier guides (`checkpoint-sync.holesky.ethpandaops.io`) is for Holesky, not Hoodi. Using the wrong URL will cause sync to fail silently. Use the Hoodi URL above.

### Step 7.3: MEV-Boost and Smoothing Pool

> *Why this matters: MEV-Boost connects your validator to a marketplace of block builders who compete to give you the most profitable block. The smoothing pool averages out the luck factor — instead of waiting months for a random block proposal, you share in every proposal across all pool participants. For post-Saturn operators, the Rocket Pool docs show the smoothing pool delivers ~42% more than solo staking vs ~15% without it.*

In the wizard, under **MEV-Boost**:
- Enable MEV-Boost: **Yes**
- Select relays: choose at least 2-3 reputable relays. Recommended starting set:
  - `https://boost-relay.flashbots.net` (Flashbots — largest, most reliable)
  - `https://bloxroute.max-profit.blxrbdn.com` (bloXroute max profit)
  - `https://relay.ultrasound.money` (Ultrasound — non-filtering)

> 📝 **Note:** On testnet, MEV-Boost relays may have limited activity. This is expected — the configuration is what matters. On mainnet, you'll see real MEV rewards.

Under **Smoothing Pool**:
- Opt in: **Yes**

### Step 7.4: Start the Node

```bash
# Save config and start all containers
rocketpool service start
```

**Expected output:**
```
Starting rocketpool_eth1 ... done
Starting rocketpool_eth2 ... done
Starting rocketpool_node ... done
Starting rocketpool_watchtower ... done
Starting rocketpool_validator ... done
Starting rocketpool_mev-boost ... done
```

### ✅ Phase 7 Verification

```bash
# Check all containers are running
docker ps --format "table {{.Names}}\t{{.Status}}" | grep rocketpool
```

**Expected output:** All rocketpool containers showing `Up X minutes`.

```bash
# Agent verification
docker ps | grep -c "rocketpool" | xargs -I{} sh -c \
  '[ {} -ge 5 ] && echo "PASS: {} containers running" || echo "FAIL: Expected 5+ containers"'
```

---

## Phase 7.5: Create a Testnet Validator

> *Why this matters: You cannot measure attestation performance without a running validator. These steps create a testnet wallet and validator on Hoodi — giving you real metrics to validate against before touching mainnet.*

### Step 7.5.1: Initialize the Testnet Wallet

```bash
# Create a node wallet for testnet
rocketpool wallet init
```

> 📝 **Note:** This is a testnet wallet. The mnemonic still needs to be stored safely — but this wallet holds no real value. You will create a separate mainnet wallet in Phase 9.

```bash
# Show your testnet wallet address
rocketpool node status
```

### Step 7.5.2: Get Hoodi Testnet ETH

Fund your testnet wallet with Hoodi ETH from the faucet:
- Faucet: `https://hoodi.ethpandaops.io/`
- Amount needed: ~0.1 ETH for gas + 4 ETH for the validator bond

🧑 **Human required:** Copy your wallet address from the previous step and paste it into the faucet.

### Step 7.5.3: Register the Testnet Node

```bash
# Register with Rocket Pool on Hoodi testnet
rocketpool node register
```

### Step 7.5.4: Create a Testnet Megapool Validator

```bash
# Make a testnet megapool deposit (4 ETH bond)
rocketpool megapool deposit
```

Select 1 validator, confirm the 4 ETH bond, and submit.

```bash
# Monitor your testnet validator status
rocketpool megapool validators
```

**Expected progression:** `initialized` → `prelaunch` → `staking`

> 📝 **Note:** On testnet, the queue is much shorter than mainnet. Your validator should reach `staking` status within hours to a day.

### ✅ Phase 7.5 Verification

```bash
echo -n "Testnet wallet: " && \
rocketpool node status 2>&1 | grep -q "registered" && echo "PASS" || echo "FAIL" && \

echo -n "Testnet validator: " && \
rocketpool megapool validators 2>&1 | grep -q "initialized\|prelaunch\|staking" && echo "PASS" || echo "FAIL"
```

---

## Phase 8: Testnet Validation & Metrics
⏱ Estimated time: 2–3 days (sync) + 30 min (setup) | 🎯 Difficulty: Medium

> *Why this matters: Syncing is not the same as working. This phase teaches you what "healthy" looks like on your node — so when something goes wrong on mainnet at 3am, you know exactly what to check and what the numbers mean.*

### Step 8.1: Monitor Initial Sync

```bash
# Check sync status for both clients
rocketpool node sync
```

**Expected output (while syncing):**
```
Your Smartnode is currently using the Hoodi Test Network.

=== Execution Client ===
Your execution client is still syncing.
Sync progress: 14.23%
...

=== Consensus Client ===
Your consensus client is still syncing (synced to epoch 12345 of 98765).
```

**Expected output (fully synced):**
```
=== Execution Client ===
Your execution client is fully synced.

=== Consensus Client ===
Your consensus client is fully synced.
```

> 📝 **Note:** Checkpoint sync gets the consensus client to head in minutes. The execution client (Nethermind) takes longer — typically 4–12 hours on fast NVMe with a good connection. Do not proceed to Phase 9 until both show fully synced.

```bash
# Agent verification: both clients synced
rocketpool node sync 2>&1 | grep -q "fully synced" && echo "PASS" || echo "STILL SYNCING — wait and retry"
```

### Step 8.2: Enable Grafana Monitoring

Rocket Pool ships with a pre-built Grafana dashboard. This is not optional — it's how you monitor your node health.

```bash
# Enable the metrics stack
rocketpool service config
```

Navigate to **Monitoring / Alerting** and enable:
- Grafana: **Yes**
- Prometheus: **Yes**
- Node Exporter: **Yes**

```bash
# Open Grafana port in the firewall
sudo ufw allow 3100/tcp comment 'Grafana dashboard'
```

Access Grafana at `http://<node-ip>:3100` from your personal computer.
Default credentials: `admin` / `rocketpool`

> ⚠️ **Warning:** Change the Grafana password immediately after first login. It's accessible on your local network.

### Step 8.3: Key Metrics — What They Mean and What to Watch

Once your node has been running for 24–48 hours with an active validator, these are the metrics that tell you if everything is healthy.

**Sync Status**

| Metric | Healthy value | What it means if wrong |
|---|---|---|
| Execution client sync | 100% / "Synced" | If stuck, Nethermind may need a restart or has a peering issue |
| Consensus client sync | 100% / "Synced" | If stuck, check checkpoint sync URL or Nimbus logs |

**Attestation Performance** — the most important validator metric

| Metric | Healthy value | What it means if wrong |
|---|---|---|
| Attestation rate | >95% | Your validator is voting correctly on most slots |
| Attestation rate | <90% | Something is wrong — check client logs immediately |
| Missed attestations | Occasional (1-2%) | Normal — network jitter, slot timing |
| Missed attestations | >5% consistently | Client issue, connectivity problem, or misconfiguration |

> *Why attestations matter: Every missed attestation is a small penalty. More importantly, a consistently low attestation rate on mainnet means you're not earning what you should — and it signals to the network that your node is unreliable.*

**Peer Count**

| Metric | Healthy value | What it means if wrong |
|---|---|---|
| Execution peers | >20 | If <5, your P2P ports may be blocked — check UFW rules |
| Consensus peers | >50 | If <10, check Nimbus logs for peering errors |

**System Resources**

| Metric | Healthy value | What it means if wrong |
|---|---|---|
| RAM usage | <48GB total | If >55GB, Nethermind cache may need tuning |
| Disk usage on /mnt/ssd | <70% | Nethermind DB grows ~50GB/month — plan ahead |
| Disk I/O | No sustained 100% | If maxed, your NVMe may be throttling |
| CPU usage | <40% average | Spikes during sync are normal; sustained high CPU is not |

**MEV-Boost**

| Metric | Healthy value | What it means if wrong |
|---|---|---|
| MEV-Boost connected | Yes | If no, check the mev-boost container logs |
| Relay connections | ≥1 relay connected | If 0, your relay URLs may be wrong or relays are down |

### Step 8.4: Check Node Logs

When something looks wrong in Grafana, these are the commands to dig deeper:

```bash
# Nethermind (execution client) logs
rocketpool service logs eth1

# Nimbus (consensus client) logs
rocketpool service logs eth2

# Validator logs
rocketpool service logs validator

# MEV-Boost logs
rocketpool service logs mev-boost

# All logs together (Ctrl+C to exit)
rocketpool service logs
```

**What to look for in logs:**

- `ERROR` or `CRIT` lines — always investigate these
- `Peer count: 0` — P2P connectivity issue
- `Database corruption` — rare but serious, may require resync
- `JWT authentication failed` — execution/consensus client communication broken

### Step 8.4.1: Configure a Basic Alert

Grafana can send alerts when your validator goes offline. Set up at least one notification channel.

1. In Grafana, go to **Alerting → Contact Points**
2. Click **Add contact point**
3. Choose your preferred method:
   - **Email:** requires SMTP config in Grafana settings
   - **Webhook:** works with Discord, Slack, PagerDuty — easiest to set up
4. For a Discord webhook:
   - Create a webhook in your Discord server settings
   - Paste the URL as the webhook endpoint
   - Test the connection
5. Go to **Alerting → Alert Rules** and enable the pre-built "Validator offline" rule

> 📝 **Note:** The Rocket Pool Grafana dashboard includes pre-built alert rules. You just need to attach a notification channel to them.

### Step 8.5: Testnet Pass/Fail Criteria

Before moving to Phase 9 (mainnet queue), your node must pass all of these:

```bash
# Run this full health check — all lines should return PASS
echo "=== Node Health Check ===" && \

echo -n "Sync status: " && \
rocketpool node sync 2>&1 | grep -q "fully synced" && echo "PASS" || echo "FAIL — not synced" && \

echo -n "Containers running: " && \
[ $(docker ps | grep -c rocketpool) -ge 5 ] && echo "PASS" || echo "FAIL — containers missing" && \

echo -n "Execution peers: " && \
PEERS=$(rocketpool service logs eth1 2>&1 | grep -oP 'peers=\K[0-9]+' | tail -1) && \
[ "${PEERS:-0}" -gt 10 ] && echo "PASS ($PEERS peers)" || echo "FAIL — low peers ($PEERS)" && \

echo -n "Disk space: " && \
USED=$(df /mnt/ssd | awk 'NR==2{print $5}' | tr -d '%') && \
[ "$USED" -lt 80 ] && echo "PASS (${USED}% used)" || echo "WARN — disk at ${USED}%" && \

echo "=== End Health Check ==="
```

**Manual checks (require 24–48 hours of runtime):**
- [ ] Attestation rate >95% in Grafana
- [ ] No ERROR/CRIT lines in validator logs
- [ ] MEV-Boost showing at least 1 connected relay
- [ ] RAM usage stable (not growing unboundedly)

**Only proceed to Phase 9 when all automated checks pass and manual checks are confirmed.**
