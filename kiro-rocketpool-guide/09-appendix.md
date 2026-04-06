# Appendix A: Troubleshooting

### Node won't sync

```bash
# Check execution client logs for errors
rocketpool service logs eth1 --tail 100

# Restart a specific container
rocketpool service restart eth1
```

### Validator missing attestations

```bash
# Check validator logs
rocketpool service logs validator --tail 50

# Verify consensus client is connected to execution client
rocketpool service logs eth2 --tail 50 | grep -i "execution\|jwt\|error"
```

### Disk space running low

```bash
# Check what's using space
du -sh /mnt/ssd/docker/*

# Nethermind pruning (reduces DB size — takes several hours, node stays online)
rocketpool service exec eth1 -- nethermind --Pruning.Mode=Full
```

### Container keeps restarting

```bash
# Check why a container is restarting
docker inspect rocketpool_eth1 | grep -A5 '"RestartCount"'
rocketpool service logs eth1 --tail 200
```

### Lost SSH access

If you lock yourself out, you need physical access to the machine:
1. Connect a monitor and keyboard to the Beelink
2. Log in locally as `nodeop`
3. Check `/etc/ssh/sshd_config` for errors: `sudo sshd -t`
4. Restore from backup: `sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config && sudo systemctl restart ssh`

---

## Appendix B: Routine Maintenance

### Weekly
```bash
# Health check
rocketpool node sync && rocketpool megapool validators && df -h /mnt/ssd
```

### Monthly
```bash
# Check for Smartnode updates
rocketpool service version

# Check for system updates (auto-updates handle security patches, but check for major upgrades)
sudo apt list --upgradable
```

### Updating Smartnode

```bash
# Download new version (replace X.X.X with latest from github.com/rocket-pool/smartnode/releases)
wget https://github.com/rocket-pool/smartnode/releases/download/vX.X.X/rocketpool-cli-linux-amd64 \
  -O ~/bin/rocketpool
chmod +x ~/bin/rocketpool

# Apply the update
rocketpool service install --update
rocketpool service start
```

---

## Appendix C: Emergency Procedures

### Preventing Slashing — The Most Important Rule

> 🔴 **Critical:** Slashing occurs when your validator signs two conflicting messages — most commonly when your keys run on two nodes simultaneously. This is the only realistic way to get slashed.

**Never:**
- Run your validator keys on two machines at the same time
- Start your node after a migration without confirming the old node is fully stopped
- Restore from backup while the original is still running

**If you need to migrate to new hardware:**
1. Stop the old node completely: `rocketpool service stop`
2. Wait for doppelganger protection to complete on the new node (it will pause for ~2 epochs on startup)
3. Only then confirm the new node is attesting

### Emergency Node Shutdown

```bash
# Graceful stop — use this for planned maintenance
rocketpool service stop

# The validator will go offline and start missing attestations
# This is recoverable — you earn back missed rewards after the same duration offline
```

### Key Backup Verification

```bash
# Verify your wallet mnemonic is correct without exposing it
# This shows your wallet address — confirm it matches what you registered
rocketpool wallet status
```

---

## Appendix D: RPL Staking (Optional)

> *RPL staking is optional under Saturn 1 — you can run a validator with just 4 ETH and no RPL. However, staking RPL boosts your ETH commission and earns you RPL issuance rewards. This appendix explains the mechanics.*

### How RPL Staking Works

- RPL is the Rocket Pool governance and reward token
- Staking RPL against your node earns you additional ETH commission on top of your base validator rewards
- You also earn RPL issuance rewards (paid every 28 days)
- RPL stake gives you voting power in the protocol DAO (proportional to square root of staked RPL)

### Commission Boost

| RPL staked (as % of borrowed ETH) | ETH rewards vs solo staking |
|---|---|
| 0% (no RPL) | ~30% more than solo |
| ≥10% of borrowed ETH | ~42% more than solo |
| Smoothing pool + ≥10% RPL | Maximum yield |

With 1 validator (28 ETH borrowed), 10% = 2.8 ETH worth of RPL to hit max commission.

### Staking RPL

```bash
# Check current RPL price and how much you need
rocketpool node status

# Stake RPL (you must hold RPL in your node wallet first)
rocketpool node stake-rpl
```

### Unstaking RPL

RPL can only be unstaked if:
- Your remaining staked RPL stays above 15% of your bonded ETH after withdrawal
- You haven't staked in the last 28 days

```bash
# Withdraw excess RPL
rocketpool node withdraw-rpl
```

> 📝 **Note:** RPL price volatility means your effective stake percentage changes over time. Monitor it periodically with `rocketpool node status`.

---

*Guide written collaboratively by a human operator and Kiro, April 2026.*
*Rocket Pool Saturn 1 | Ubuntu 24.04.4 LTS (kernel 6.17) | Smartnode v1.19.4*
