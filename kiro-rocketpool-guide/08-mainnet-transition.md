# Phase 11: Mainnet Transition Checklist
⏱ Estimated time: 2 hours | 🎯 Difficulty: Medium

> *Why this matters: Your validator is about to go live on Ethereum mainnet. This is the point of no return — once active, going offline costs you attestation rewards. Run through this checklist completely before your validator reaches `staking` status.*

**Target timing:** Complete this checklist ~1 week before your estimated queue assignment date.

### Pre-Launch Checklist

**Infrastructure**
- [ ] Mainnet execution client fully synced (`rocketpool node sync` shows "fully synced")
- [ ] Mainnet consensus client fully synced
- [ ] All 5+ Docker containers running and healthy
- [ ] Disk usage on `/mnt/ssd` below 60% (Nethermind mainnet DB is ~1.2TB)
- [ ] UPS or stable power confirmed
- [ ] Internet connection stable — check uptime over the past 2 weeks

**Security**
- [ ] SSH key-only auth confirmed — from the Pi, run `ssh rp-node01 echo ok` and confirm it connects without a password prompt
- [ ] Password auth disabled on node — from the Pi, run `ssh -o PreferredAuthentications=password nodeop@rp-node01.local` and confirm it is rejected
- [ ] UFW firewall active with correct ports
- [ ] Fail2ban running
- [ ] Pi jump host hardened and watchdog cron running
- [ ] Grafana password changed from default
- [ ] Node wallet seed phrase stored offline and verified

**Rocket Pool Configuration**
- [ ] Withdrawal address set to cold wallet — verify it one more time
- [ ] Smoothing pool opt-in confirmed (`rocketpool node status`)
- [ ] MEV-Boost enabled with at least 2 relays connected
- [ ] Doppelganger protection enabled

**Monitoring**
- [ ] Grafana dashboard accessible and showing data
- [ ] At least one alert configured (email or webhook) for validator going offline
- [ ] You know how to check logs: `rocketpool service logs validator`

### Step 11.1: Final Pre-Launch Sync Verification

```bash
# Run this the day before your validator is expected to go active
rocketpool node sync && \
rocketpool megapool validators && \
echo "=== Final check complete ==="
```

### Step 11.2: Stop Testnet

Once your mainnet validator is active, stop the testnet instance to free resources:

```bash
export RP_PATH=~/.rocketpool-testnet
rocketpool --config-path $RP_PATH service stop
```

### Step 11.3: Confirm Validator Active

```bash
# Your validator status should show 'staking'
rocketpool megapool validators
```

**Expected output:**
```
Validator 1:
  Status:    staking
  Balance:   32.XXXXX ETH
  ...
```

Find your validator on `https://beaconcha.in` using your validator public key to see live attestation performance.

### ✅ Phase 11 Verification

```bash
# Final agent verification
echo -n "Validator active: " && \
rocketpool megapool validators 2>&1 | grep -q "staking" && echo "PASS" || echo "NOT YET ACTIVE" && \

echo -n "Smoothing pool: " && \
rocketpool node status 2>&1 | grep -qi "smoothing pool.*yes\|opted in" && echo "PASS" || echo "CHECK MANUALLY" && \

echo -n "MEV-Boost: " && \
docker ps | grep -q "mev-boost" && echo "PASS" || echo "FAIL — mev-boost container not running"
```
