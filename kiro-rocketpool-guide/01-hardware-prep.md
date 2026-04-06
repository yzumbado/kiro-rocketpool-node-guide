# Phase 0: Hardware Preparation
⏱ Estimated time: 45 min | 🎯 Difficulty: Medium

> *Why this matters: The Beelink GTI15 ships with a known BIOS bug that causes random Linux freezes tied to the Intel ME firmware. Fix this before installing anything, or you'll be debugging mysterious crashes at 2am.*

### Step 0.1: Update WD SN850X Firmware
🧑 **Human required**

Boot into the pre-installed Windows 11. Download **WD Dashboard** from Western Digital's official site and apply the latest firmware to the 4TB NVMe drive. This prevents known data integrity issues under Linux.

### Step 0.2: Download the BIOS Update
🧑 **Human required**

Go to Beelink's official support site (`https://www.bee-link.com/`) and navigate to the GTI15 product page. Download the latest available BIOS for your unit. As of April 2026, the current version is **T205** — the zip file will be named something like `GTI15_BIOS_T205.zip`. If a newer version is listed, use that instead.

> 📝 **Note:** Beelink publishes BIOS updates on their blog at `https://www.bee-link.com/blogs/all`. Check there for any GTI15 updates newer than T205 before downloading.

### Step 0.3: Prepare the BIOS Flash USB
🧑 **Human required**

> 💡 **Tip:** This is the same USB drive you'll use for Ubuntu later. After the BIOS flash is complete and verified, you'll wipe it and flash Ubuntu onto it.

> ⚠️ **Warning:** The volume label must be exactly `WINPE` — uppercase, no spaces. The BIOS flash script looks for this label. Get it wrong and the flash won't start.

1. Format the USB drive to `FAT32`
2. Set the volume label to exactly `WINPE`
3. Extract **all files** from the BIOS zip directly to the root of the USB (not into a subfolder)

### Step 0.4: Flash the BIOS
🧑 **Human required**

> 🔴 **Critical:** Do not power off the machine during this process. A failed flash can brick the device. Plug into a UPS or ensure stable power before starting.

1. Restart the Beelink and press `F7` at the boot logo
2. Select `EFI USB Device`
3. Press any key except `ESC`
4. Type your USB volume identifier (e.g. `fs3:`) and press `Enter`
5. Type `Flash.nsh` and press `Enter`
6. Wait for: `Update EC Rom successfully!`
7. The machine will reboot automatically

### Step 0.5: Configure BIOS Settings
🧑 **Human required**

Reboot and press `Del` to enter BIOS setup. Apply these settings:

| Setting | Value | Reason |
|---|---|---|
| Secure Boot | **Disabled** | Required for Ubuntu to boot without kernel signing issues |
| State After G3 | **S0** | Auto-boots after power outages — critical for an always-on validator |
| Boot Order | **USB first** | Needed for OS installation |

Save and exit.

> 📝 **Note:** The AHCI/NVME storage mode setting documented in some community guides for similar Beelink hardware has not been confirmed as accessible in the GTI15 BIOS. Ubuntu 24.04.4 with kernel 6.17 handles NVMe power management natively without requiring this change.

### ✅ Phase 0 Verification
🧑 **Human required**

- [ ] BIOS version shows T205 (or newer) on the main BIOS screen
- [ ] Machine boots normally after BIOS flash
