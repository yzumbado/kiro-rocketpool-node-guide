# Phase 3: Security Hardening
⏱ Estimated time: 30 min | 🎯 Difficulty: Medium

> *Why this matters: Your node will hold a wallet with real ETH and validator keys. Once it's on the internet, it will be scanned and probed within minutes. This phase locks the door before Rocket Pool opens the window.*

### Step 3.1: Harden the SSH Daemon

> *Why this matters: During the Ubuntu installer you were forced to enable password authentication over SSH — there was no way around it. This step disables it now that you have key-based login working. Until this step is complete, your node accepts password logins over SSH, which is a brute-force risk.*

> 🔴 **Critical:** Key-based SSH login (Phase 2, Step 2.6) must be confirmed working before running this step. If you disable password auth without a working key, you will lock yourself out. Recovery requires physical access to the machine.

```bash
# Back up the original config before touching it
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Apply hardened settings
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config

# Add AllowUsers if not already present
grep -q "^AllowUsers" /etc/ssh/sshd_config || echo "AllowUsers nodeop" | sudo tee -a /etc/ssh/sshd_config
```

```bash
# Validate config for typos before applying
sudo sshd -t && echo "PASS: SSH config valid" || echo "FAIL: Fix errors before restarting SSH"
```

```bash
# Apply only if validation passed
sudo systemctl restart ssh
```

> 🤖 **Agent note:** After restarting SSH, verify the current session is still active. Open a second SSH connection to confirm login still works before proceeding.

### Step 3.2: Configure UFW Firewall

```bash
# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH first — always
sudo ufw allow 22/tcp comment 'SSH'

# Execution client P2P (Nethermind)
sudo ufw allow 30303/tcp comment 'Nethermind P2P TCP'
sudo ufw allow 30303/udp comment 'Nethermind P2P UDP'

# Consensus client P2P (Nimbus)
sudo ufw allow 9000/tcp comment 'Nimbus P2P TCP'
sudo ufw allow 9000/udp comment 'Nimbus P2P UDP'

# Enable firewall
sudo ufw --force enable
```

```bash
# Verify
sudo ufw status verbose
```

**Expected output:**
```
Status: active
22/tcp                     ALLOW IN    Anywhere
30303/tcp                  ALLOW IN    Anywhere
30303/udp                  ALLOW IN    Anywhere
9000/tcp                   ALLOW IN    Anywhere
9000/udp                   ALLOW IN    Anywhere
```

### Step 3.3: Install and Configure Fail2ban

```bash
sudo apt install fail2ban -y
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Configure SSH jail
sudo tee /etc/fail2ban/jail.d/sshd.local > /dev/null <<EOF
[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
maxretry = 5
bantime = 1h
EOF

sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

```bash
# Verify
sudo fail2ban-client status sshd
```

**Expected output:**
```
Status for the jail: sshd
|- Filter
|  |- Currently failed: 0
`- Actions
   `- Currently banned: 0
```

### Step 3.4: Configure Automatic Security Updates

```bash
sudo apt install unattended-upgrades -y

# Enable automatic security updates
sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Disable automatic reboots — a random reboot during a block proposal costs rewards
sudo sed -i 's|//Unattended-Upgrade::Automatic-Reboot "false";|Unattended-Upgrade::Automatic-Reboot "false";|' \
  /etc/apt/apt.conf.d/50unattended-upgrades
sudo sed -i 's|//Unattended-Upgrade::Automatic-Reboot-WithUsers "true";|Unattended-Upgrade::Automatic-Reboot-WithUsers "false";|' \
  /etc/apt/apt.conf.d/50unattended-upgrades
```

### Step 3.5: Harden Shared Memory and Kernel Network Stack

```bash
# Prevent code execution in shared RAM
echo 'tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0' | sudo tee -a /etc/fstab

# Kernel network hardening
sudo tee -a /etc/sysctl.conf > /dev/null <<EOF

# Rocket Pool node hardening
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.log_martians = 1
EOF

# Apply immediately
sudo sysctl -p
```

### ✅ Phase 3 Verification

```bash
# Agent verification: all security services active
echo "--- SSH config ---"
sudo sshd -t && echo "PASS" || echo "FAIL"

echo "--- Firewall ---"
sudo ufw status | grep -q "Status: active" && echo "PASS" || echo "FAIL"

echo "--- Fail2ban ---"
sudo systemctl is-active fail2ban && echo "PASS" || echo "FAIL"

echo "--- Auto-updates ---"
systemctl is-active unattended-upgrades && echo "PASS" || echo "FAIL"
```

**All four must return PASS before proceeding.**
