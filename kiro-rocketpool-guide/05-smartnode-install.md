# Phase 6: Rocket Pool Smartnode Installation
⏱ Estimated time: 15 min | 🎯 Difficulty: Easy

> 📝 **Note:** Check for the latest Smartnode release before running: `https://github.com/rocket-pool/smartnode/releases`. This guide uses **v1.19.4**. If a newer stable version is available, replace the version number in the download URL.

### Step 6.1: Download the Rocket Pool CLI

```bash
# Create a local bin directory
mkdir -p ~/bin

# Download the Smartnode CLI v1.19.4
wget https://github.com/rocket-pool/smartnode/releases/download/v1.19.4/rocketpool-cli-linux-amd64 \
  -O ~/bin/rocketpool

# Make it executable
chmod +x ~/bin/rocketpool

# Add ~/bin to PATH if not already there
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

```bash
# Verify the download
rocketpool --version
```

**Expected output:**
```
rocketpool version 1.19.4
```

### Step 6.2: Install the Smartnode Stack

```bash
# Install Rocket Pool services
rocketpool service install
```

When prompted, type `y` to confirm. This installs the Docker compose files and service configuration.

```bash
# Log out and back in to apply group changes
exit
```

Reconnect via SSH from the Pi:
```bash
# Run on the Pi jump host
ssh rp-node01
```

### ✅ Phase 6 Verification

```bash
# Agent verification: Smartnode is installed
rocketpool --version && echo "PASS: CLI installed" || echo "FAIL: CLI not found"
ls ~/.rocketpool/docker-compose.yml > /dev/null 2>&1 \
  && echo "PASS: Service files present" || echo "FAIL: Service files missing"
```
