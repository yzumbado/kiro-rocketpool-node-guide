# Phase 9: Mainnet Queue Strategy
⏱ Estimated time: 30 min | 🎯 Difficulty: Medium

> *Why this matters: The Rocket Pool validator queue is currently ~2 months long. That's not a bug — it's a feature of the protocol's design. The smart move is to get in queue now, keep running testnet in parallel, and be fully validated and ready to switch before your slot arrives. This phase sets that up.*

**The strategy in one sentence:** Register on mainnet, make your megapool deposit to enter the queue, then keep running Hoodi testnet until ~1 week before your estimated assignment date.

> 🔴 **Critical:** Everything from this phase onward involves real ETH. Double-check every address. There are no refunds on the blockchain.

### Step 9.1: Check Current Queue Wait Time

Before depositing, check the current queue so you can plan your testnet runway.

```bash
# Check current queue position estimate (once your node is registered)
rocketpool queue status
```

You can also check the live queue at `https://rocketpool.net/` or `https://rocketscan.io/`.

> 📝 **Note:** As of April 2026, the standard queue wait is approximately 2 months. Express tickets can reduce this, but new operators receive limited express tickets under RPIP-75.

### Step 9.2: Switch to Mainnet Configuration

> ⚠️ **Warning:** This step changes your node's network. Your testnet data will be preserved but inactive. You will run mainnet and testnet in parallel by keeping the testnet containers available but stopped.

```bash
# Stop testnet services first
rocketpool service stop

# Open config wizard
rocketpool service config
```

Change **Network** from `Hoodi Testnet` to `Ethereum Mainnet`.

Keep all other settings identical — same clients, same MEV relays, same smoothing pool opt-in.

```bash
# Start mainnet services
rocketpool service start
```

Wait for both clients to fully sync on mainnet before proceeding. This will take longer than testnet — Nethermind mainnet sync is typically 12–24 hours.

```bash
# Poll sync status every 30 seconds (Ctrl+C to stop, or run once to check)
rocketpool node sync

# Agent-friendly: loop until synced (exits automatically when complete)
until rocketpool node sync 2>&1 | grep -q "fully synced"; do
  echo "$(date): Still syncing — checking again in 60s"
  sleep 60
done
echo "SYNC COMPLETE"
```

### Step 9.3: Create and Fund the Node Wallet

🔴 **Human required for seed phrase backup**

```bash
# Initialize the node wallet
rocketpool wallet init
```

> 🔴 **Critical:** Write down the 24-word mnemonic on paper. Store it offline, in a safe place, separate from your hardware. This is the only recovery mechanism for your node wallet. Anyone with this phrase controls your funds.

```bash
# Show your node wallet address
rocketpool node status
```

Fund this address with:
- **~0.1 ETH** for gas costs (transactions, deposits, claims)
- You do **not** need to send your 4 ETH bond here yet — that happens at deposit time

### Step 9.4: Register the Node

```bash
# Register your node with the Rocket Pool protocol
rocketpool node register
```

Select your timezone when prompted — this maps your node on the global network display.

### Step 9.5: Set Your Withdrawal Address
🔴 **Human required**

> *Why this matters: Your withdrawal address is where your staked ETH and rewards go when you exit. If your node is ever compromised, an attacker cannot redirect funds if the withdrawal address is a cold wallet they don't control. This is the single most important security decision you make.*

```bash
# Set withdrawal address to your cold wallet
rocketpool node set-primary-withdrawal-address <your-cold-wallet-address>
```

> 🔴 **Critical:** Use an address from a hardware wallet (Ledger/Trezor) that you control independently of this node. Never use an exchange address. Confirm the address character by character before submitting.

### Step 9.6: Make the Megapool Deposit (Enter the Queue)

> *Why this matters: Saturn 1 uses megapools — a single smart contract that manages multiple validators. Your 4 ETH bond goes into this contract, and you enter the standard queue. The protocol matches your 4 ETH with 28 ETH from liquid stakers to create a 32 ETH validator.*

```bash
# Create your megapool and make the initial deposit
rocketpool megapool deposit
```

When prompted:
- Number of validators: **1** (start with one, add more later)
- Bond amount: **4 ETH** (Saturn 1 standard)
- Confirm the gas estimate and submit

```bash
# Check your position in the queue
rocketpool megapool validators
```

**Expected output:**
```
Validator 1:
  Status:         initialized → prelaunch (waiting for 28 ETH from pool)
  Queue position: ~XXX
  Estimated wait: ~XX days
```

> 📝 **Note:** Your validator moves from `initialized` → `prelaunch` → `staking` as the protocol matches ETH from the liquid staking pool. The queue position updates as other validators ahead of you are assigned.

### ✅ Phase 9 Verification

```bash
# Agent verification: node is registered and deposit is made
echo -n "Node registered: " && \
rocketpool node status 2>&1 | grep -q "registered" && echo "PASS" || echo "FAIL" && \

echo -n "Withdrawal address set: " && \
rocketpool node status 2>&1 | grep -q "Primary withdrawal address" && echo "PASS" || echo "FAIL" && \

echo -n "Megapool deposit made: " && \
rocketpool megapool validators 2>&1 | grep -q "initialized\|prelaunch\|staking" && echo "PASS" || echo "FAIL"
```

---

## Phase 10: Parallel Testnet Operation
⏱ Estimated time: ~2 months (queue wait) | 🎯 Difficulty: Easy

> *Why this matters: You're in the mainnet queue. Your validator isn't active yet. This is your window to keep validating on testnet, stay sharp on operations, and be fully confident before real ETH is at stake.*

### Step 10.1: Run Testnet in Parallel

While mainnet is synced and your deposit is in queue, you can run a separate testnet instance to keep practicing.

```bash
# The Rocket Pool data directory for testnet is separate
# You can run testnet by pointing to a different config directory
export RP_PATH=~/.rocketpool-testnet
rocketpool --config-path $RP_PATH service config
```

Select **Hoodi Testnet** and configure identically to Phase 7. This runs independently of your mainnet instance.

> 📝 **Note:** Both instances share the same machine. The testnet instance must use different P2P ports to avoid conflicts with mainnet. When configuring the testnet instance, set:
> - Execution P2P port: `30304` (instead of default `30303`)
> - Consensus P2P port: `9001` (instead of default `9000`)

```bash
# Open testnet P2P ports in the firewall
sudo ufw allow 30304/tcp comment 'Nethermind Testnet P2P TCP'
sudo ufw allow 30304/udp comment 'Nethermind Testnet P2P UDP'
sudo ufw allow 9001/tcp comment 'Nimbus Testnet P2P TCP'
sudo ufw allow 9001/udp comment 'Nimbus Testnet P2P UDP'
```

### Step 10.2: Weekly Mainnet Health Checks

While waiting in queue, run this weekly to confirm your mainnet node stays healthy:

```bash
# Weekly mainnet health check
echo "=== Weekly Mainnet Check ===" && \
echo "Date: $(date)" && \
rocketpool node sync && \
rocketpool megapool validators && \
df -h /mnt/ssd && \
docker ps --format "table {{.Names}}\t{{.Status}}" | grep rocketpool
```

### Step 10.3: Monitor Queue Progress

```bash
# Check estimated time until your validator is assigned
rocketpool megapool validators
```

When your validator status changes from `prelaunch` to `staking`, your validator is active on the Beacon Chain. You'll receive an email notification if you set up alerting in Grafana.
