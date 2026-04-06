# Phase 4: Storage Configuration
⏱ Estimated time: 15 min | 🎯 Difficulty: Easy

> *Why this matters: The 4TB WD Black SN850X is where your Ethereum chain data lives. Nethermind's database alone is ~1.2TB and grows over time. Mounting it correctly — and pointing Docker at it — keeps your OS drive clean and gives your clients room to breathe.*

### Step 4.1: Identify the 4TB Drive

```bash
# List all block devices with sizes
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
```

**Expected output (example):**
```
NAME        SIZE TYPE MOUNTPOINT
nvme0n1   931.5G disk
└─nvme0n1p1 931.5G part /
nvme1n1     3.6T disk
```

The 4TB drive will appear as `nvme1n1` (or similar) with no mountpoint. Note the exact device name.

> ⚠️ **Warning:** Confirm the device name before the next step. Formatting the wrong drive destroys your OS. The 4TB drive has no partitions and no mountpoint.

### Step 4.2: Format the 4TB Drive

```bash
# Format as ext4 — replace nvme1n1 with your actual device name
sudo mkfs.ext4 /dev/nvme1n1
```

**Expected output:**
```
Creating filesystem with 976773168 4k blocks and 244203520 inodes
...
Writing superblocks and filesystem accounting information: done
```

### Step 4.3: Create Mount Point and Get UUID

```bash
# Create the mount point
sudo mkdir -p /mnt/ssd

# Get the UUID of the new filesystem
sudo blkid /dev/nvme1n1
```

**Expected output (example):**
```
/dev/nvme1n1: UUID="a1b2c3d4-e5f6-..." TYPE="ext4"
```

Copy the UUID value.

### Step 4.4: Mount Permanently via fstab

```bash
# Add to fstab for automatic mounting on boot
# Replace <UUID> with the value from Step 4.3
echo "UUID=<UUID> /mnt/ssd ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab
```

> 📝 **Note:** `noatime` prevents the filesystem from writing an access timestamp every time a file is read — important for a database-heavy workload like chain sync.

```bash
# Mount now without rebooting
sudo mount -a
```

### Step 4.5: Create Docker Data Directory

```bash
# Docker will store all chain data here
sudo mkdir -p /mnt/ssd/docker
```

### ✅ Phase 4 Verification

```bash
# Agent verification: 4TB drive is mounted and accessible
echo "--- Mount check ---"
mountpoint -q /mnt/ssd && echo "PASS: /mnt/ssd is mounted" || echo "FAIL: /mnt/ssd not mounted"

echo "--- Available space ---"
df -h /mnt/ssd

echo "--- Docker data dir ---"
test -d /mnt/ssd/docker && echo "PASS: Docker dir exists" || echo "FAIL: Docker dir missing"
```

**Expected:** /mnt/ssd mounted with ~3.6TB available.

---

# Phase 5: Docker Installation
⏱ Estimated time: 10 min | 🎯 Difficulty: Easy

> *Why this matters: Rocket Pool runs Nethermind and Nimbus inside Docker containers. Ubuntu's default `docker.io` package is often outdated. We install from Docker's official repository to get the current stable version with full compose support.*

### Step 5.1: Install Docker from Official Repository

```bash
# Install prerequisites
sudo apt install -y ca-certificates curl

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
```

### Step 5.2: Point Docker at the 4TB Drive

```bash
# Configure Docker to store all data on the 4TB NVMe
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "data-root": "/mnt/ssd/docker"
}
EOF

# Restart Docker to apply
sudo systemctl restart docker
```

### Step 5.3: Add User to Docker Group

```bash
# Allow nodeop to run Docker without sudo
sudo usermod -aG docker nodeop

# Apply group change to current session
newgrp docker
```

### ✅ Phase 5 Verification

```bash
# Agent verification: Docker is running and using the correct data root
echo "--- Docker service ---"
sudo systemctl is-active docker && echo "PASS" || echo "FAIL"

echo "--- Docker data root ---"
docker info 2>/dev/null | grep "Docker Root Dir" | grep -q "/mnt/ssd/docker" \
  && echo "PASS: Using 4TB drive" || echo "FAIL: Wrong data root"

echo "--- Docker permissions ---"
docker ps > /dev/null 2>&1 && echo "PASS: nodeop can run Docker" || echo "FAIL: Permission denied"
```
