# Lab 10: First Yocto Project Build

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about Yocto:

*"The Yocto Project is a build system of such staggering complexity that it makes the Infinite Improbability Drive look straightforward. However, once you understand it (which will take approximately 42 tries), it's actually quite brilliant."*

## Objectives

Master the fundamentals of the Yocto Project build system by setting up a complete OpenEmbedded environment and building your first custom Linux distribution for the BeaglePlay.

**What You'll Learn:**
- Set up the Yocto Project/OpenEmbedded build environment
- Understand BitBake and layer architecture
- Configure machine-specific builds for TI AM62x (BeaglePlay)
- Build a minimal root filesystem image
- Deploy and boot a Yocto-generated image

**Time Required:** 3-4 hours

---

## Prerequisites

**Hardware:**
- BeaglePlay board (TI AM62x Cortex-A53)
- microSD card (16GB+ recommended)
- USB-C cable for power
- USB-to-Serial adapter (3.3V UART)
- Serial terminal software (picocom, minicom)

**Software:**
- Ubuntu 22.04+ or compatible Linux distribution
- At least 50GB free disk space (recommend 100GB+)
- Internet connection for downloading layers

**Knowledge:**
- Completed embedded Linux track (Labs 1-9)
- Understanding of cross-compilation
- Familiarity with Git and Python

---

## 1. Understanding Yocto Project

### 1.1 What is Yocto?

The **Yocto Project** is an open-source collaboration project providing templates, tools, and methods for creating custom Linux-based systems regardless of the hardware architecture.

**Key Components:**
- **Poky**: Reference distribution and build system
- **OpenEmbedded-Core**: Core metadata and recipes
- **BitBake**: Task execution engine (Python-based)
- **Layers**: Modular metadata organization

### 1.2 Why Use Yocto?

**Advantages over manual approaches:**
- **Reproducibility**: Builds are deterministic and traceable
- **Scalability**: Manage hundreds of packages efficiently
- **Customization**: Full control over every component
- **Community**: Thousands of ready-to-use recipes
- **Maintenance**: Upstream tracking and security updates

**Comparison with Buildroot:**
- More complex but more flexible
- Recipe-based vs. makefile-based
- Better for complex products with long lifecycles

### 1.3 Yocto Architecture

```
┌─────────────────────────────────────────────────┐
│                 BitBake Engine                  │
│         (Task Scheduler & Executor)             │
└─────────────────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
┌───────▼──────┐ ┌──────▼─────┐ ┌──────▼─────┐
│  meta        │ │ meta-oe    │ │ meta-ti    │
│  (Poky core) │ │ (packages) │ │ (BSP)      │
└──────────────┘ └────────────┘ └────────────┘
        │               │               │
        └───────────────┼───────────────┘
                        │
        ┌───────────────▼───────────────┐
        │     Build Directory           │
        │  - conf/                      │
        │  - tmp/                       │
        │  - downloads/                 │
        │  - sstate-cache/              │
        └───────────────────────────────┘
```

**Layer Structure:**
- **meta**: Core OpenEmbedded recipes
- **meta-poky**: Poky-specific configurations
- **meta-yocto-bsp**: Reference BSP for QEMU and generic boards
- **meta-ti**: Texas Instruments BSP (AM62x support)
- **meta-openembedded**: Community packages (python, networking, etc.)
- **meta-arm**: ARM-specific toolchains and recipes

---

## 2. System Setup

### 2.1 Prerequisites Check

**Verify disk space:**
```bash
df -h $HOME
# Need at least 50GB free, 100GB+ recommended
```

**Check Ubuntu version:**
```bash
lsb_release -a
# Should be Ubuntu 22.04 or 24.04
```

**Verify no eCryptFS encryption:**
```bash
mount | grep ecryptfs
# Should return nothing - eCryptFS breaks long filenames
```

If your home directory uses eCryptFS, create the Yocto workspace on an unencrypted partition.

### 2.2 Install Build Dependencies

```bash
sudo apt update
sudo apt install -y \
    gawk wget git diffstat unzip texinfo gcc build-essential \
    chrpath socat cpio python3 python3-pip python3-pexpect \
    xz-utils debianutils iputils-ping python3-git python3-jinja2 \
    python3-subunit zstd liblz4-tool file locales libacl1 \
    libssl-dev libgmp-dev libmpc-dev lz4 zlib1g-dev
```

**What these packages do:**
- **gawk, diffstat, texinfo**: Build system utilities
- **python3-***: BitBake dependencies
- **chrpath, patchelf**: Binary manipulation
- **socat**: Networking tools for BitBake
- **zstd, lz4**: Compression for package caching

### 2.3 Configure Git

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

Yocto tracks all changes via Git - proper configuration is essential.

### 2.4 Ubuntu 24.04 AppArmor Workaround

Ubuntu 24.04 restricts unprivileged user namespaces via AppArmor, which breaks BitBake's network isolation.

**Temporary fix (reboot required):**
```bash
echo 0 | sudo tee /proc/sys/kernel/apparmor_restrict_unprivileged_userns
```

**Persistent fix:**
```bash
echo 'kernel.apparmor_restrict_unprivileged_userns = 0' | \
    sudo tee /etc/sysctl.d/99-bitbake.conf
sudo sysctl --system
```

**Verify:**
```bash
cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns
# Should output: 0
```

---

## 3. Setting Up the Yocto Environment

### 3.1 Create Workspace

```bash
mkdir -p ~/yocto-labs
cd ~/yocto-labs
```

### 3.2 Download Poky

**Clone the Scarthgap LTS release (Yocto 5.0):**
```bash
git clone https://git.yoctoproject.org/git/poky
cd poky
git checkout -b scarthgap-5.0.4 scarthgap-5.0.4
cd ..
```

**Why Scarthgap?**
- LTS release (supported until April 2026)
- TI AM62x well-supported
- Stable BSP layer ecosystem

### 3.3 Download Required Layers

**meta-openembedded (community packages):**
```bash
git clone -b scarthgap \
    https://git.openembedded.org/meta-openembedded
```

**meta-arm (ARM toolchains):**
```bash
git clone https://git.yoctoproject.org/git/meta-arm
cd meta-arm
git checkout -b yocto-5.0.1 yocto-5.0.1
cd ..
```

**meta-ti (BeaglePlay BSP):**
```bash
git clone https://git.yoctoproject.org/git/meta-ti
cd meta-ti
git checkout -b scarthgap-10.01.03 10.01.03
cd ..
```

**Verify layer versions:**
```bash
cd ~/yocto-labs
for layer in poky meta-openembedded meta-arm meta-ti; do
    echo "=== $layer ==="
    cd $layer
    git describe --tags
    cd ..
done
```

### 3.4 Understand Layer Structure

**Explore Poky:**
```bash
cd ~/yocto-labs/poky
ls -l
```

**Output:**
```
meta/           # Core OpenEmbedded recipes
meta-poky/      # Poky distribution policy
meta-yocto-bsp/ # Reference BSPs (QEMU)
bitbake/        # BitBake build engine
scripts/        # Utility scripts
oe-init-build-env  # Environment setup script
```

**Explore meta-ti:**
```bash
cd ~/yocto-labs/meta-ti
ls -l
```

**Output:**
```
meta-ti-bsp/    # Board support (BeaglePlay)
meta-ti-extras/ # Additional TI packages
recipes-*/      # Recipe directories
conf/           # Layer and machine configurations
```

**Check BeaglePlay machine config:**
```bash
cat meta-ti-bsp/conf/machine/beagleplay.conf | head -30
```

You'll see AM62x-specific settings: SoC family, kernel provider, bootloader configurations.

---

## 4. Initializing the Build Environment

### 4.1 Source the Environment Script

```bash
cd ~/yocto-labs
source poky/oe-init-build-env
```

**What this does:**
- Creates `build/` directory
- Generates `conf/local.conf` and `conf/bblayers.conf`
- Sets up BitBake environment variables
- Changes directory to `build/`

**You're now in:** `~/yocto-labs/build/`

### 4.2 Verify Environment

```bash
echo $BUILDDIR
# Output: /home/user/yocto-labs/build

which bitbake
# Output: /home/user/yocto-labs/poky/bitbake/bin/bitbake
```

**Important (like knowing where your towel is):** You must source `oe-init-build-env` in every new shell session.

### 4.3 Understand Build Directory Structure

```bash
ls -l ~/yocto-labs/build/
```

**Output:**
```
conf/           # Configuration files
tmp/            # Build artifacts (created during build)
downloads/      # Downloaded source tarballs
sstate-cache/   # Shared state cache (build acceleration)
```

---

## 5. Configuring the Build

### 5.1 Configure Target Machine

**Edit local.conf:**
```bash
nano conf/local.conf
```

**Find the MACHINE variable (around line 33):**
```
#MACHINE ??= "qemux86-64"
```

**Change to BeaglePlay:**
```
MACHINE ??= "beagleplay"
```

**Add disk space optimization (optional but recommended):**
```
# Remove work directories after build to save space
INHERIT += "rm_work"

# Keep sources for debugging
RM_WORK_EXCLUDE += "linux-ti-staging u-boot-ti-staging"
```

**Add parallel build settings:**
```
# Use all CPU cores (adjust based on your system)
BB_NUMBER_THREADS ?= "${@oe.utils.cpu_count()}"
PARALLEL_MAKE ?= "-j ${@oe.utils.cpu_count()}"
```

**Save and exit** (Ctrl+O, Enter, Ctrl+X).

### 5.2 Configure Layers

**Edit bblayers.conf:**
```bash
nano conf/bblayers.conf
```

**You'll see:**
```
BBLAYERS ?= " \
  /home/user/yocto-labs/poky/meta \
  /home/user/yocto-labs/poky/meta-poky \
  /home/user/yocto-labs/poky/meta-yocto-bsp \
  "
```

**Add required layers:**
```
BBLAYERS ?= " \
  /home/user/yocto-labs/poky/meta \
  /home/user/yocto-labs/poky/meta-poky \
  /home/user/yocto-labs/poky/meta-yocto-bsp \
  /home/user/yocto-labs/meta-openembedded/meta-oe \
  /home/user/yocto-labs/meta-openembedded/meta-python \
  /home/user/yocto-labs/meta-openembedded/meta-networking \
  /home/user/yocto-labs/meta-arm/meta-arm \
  /home/user/yocto-labs/meta-arm/meta-arm-toolchain \
  /home/user/yocto-labs/meta-ti/meta-ti-bsp \
  /home/user/yocto-labs/meta-ti/meta-ti-extras \
  "
```

**Important (like knowing where your towel is):** Use absolute paths. Replace `/home/user/` with your actual home directory path.

**Quick way to get absolute paths:**
```bash
# Generate layer paths automatically
cd ~/yocto-labs
for layer in \
    meta-openembedded/meta-oe \
    meta-openembedded/meta-python \
    meta-openembedded/meta-networking \
    meta-arm/meta-arm \
    meta-arm/meta-arm-toolchain \
    meta-ti/meta-ti-bsp \
    meta-ti/meta-ti-extras; do
    realpath $layer
done
```

Copy the output and paste into `BBLAYERS`.

### 5.3 Verify Configuration

**Check layer dependencies:**
```bash
bitbake-layers show-layers
```

**Expected output:**
```
layer                 path                                      priority
==========================================================================
meta                  /home/user/yocto-labs/poky/meta           5
meta-poky             /home/user/yocto-labs/poky/meta-poky      5
meta-yocto-bsp        /home/user/yocto-labs/poky/meta-yocto-bsp 5
meta-oe               /home/user/yocto-labs/meta-openembedded/meta-oe  6
meta-python           /home/user/yocto-labs/meta-openembedded/meta-python  7
meta-networking       /home/user/yocto-labs/meta-openembedded/meta-networking  5
meta-arm              /home/user/yocto-labs/meta-arm/meta-arm   5
meta-arm-toolchain    /home/user/yocto-labs/meta-arm/meta-arm-toolchain  5
meta-ti-bsp           /home/user/yocto-labs/meta-ti/meta-ti-bsp  6
meta-ti-extras        /home/user/yocto-labs/meta-ti/meta-ti-extras  7
```

**Check for dependency issues:**
```bash
bitbake-layers check-layers
```

Should return no errors.

---

## 6. Building Your First Image

### 6.1 Understand BitBake Images

**Common image targets:**
- **core-image-minimal**: Bare minimum (console only, ~10MB rootfs)
- **core-image-base**: Basic with networking
- **core-image-full-cmdline**: All console tools
- **core-image-sato**: Graphical desktop (large)

We'll build **core-image-minimal** for this first build.

### 6.2 Start the Build

```bash
cd ~/yocto-labs/build
bitbake core-image-minimal
```

**Expected output:**
```
Loading cache: 100% |##################################| Time: 0:00:05
Loaded 4321 entries from dependency cache.
Parsing recipes: 100% |################################| Time: 0:00:38
Parsing of 2456 .bb files complete (2450 cached, 6 parsed). 4328 targets, 412 skipped, 0 masked, 0 errors.
NOTE: Resolving any missing task queue dependencies
...
NOTE: Tasks Summary: Attempted 3284 tasks of which 0 didn't need to be rerun and all succeeded.
```

**First build will take 1-3 hours** depending on:
- CPU cores (more is better)
- Internet speed (downloads ~5GB)
- Disk speed (SSD recommended)

**What's happening:**
1. BitBake parses all recipes and dependencies
2. Downloads source tarballs to `downloads/`
3. Unpacks, patches, configures, compiles packages
4. Generates rootfs and bootable image
5. Caches intermediate results in `sstate-cache/`

### 6.3 Monitor Build Progress

**Open another terminal and monitor:**
```bash
# Watch disk usage
watch -n 5 'df -h ~/yocto-labs/build/tmp'

# Monitor currently running tasks
tail -f ~/yocto-labs/build/tmp/log/cooker/beagleplay/console-latest.log
```

**Common tasks you'll see:**
- `do_fetch`: Download sources
- `do_unpack`: Extract archives
- `do_patch`: Apply patches
- `do_configure`: Run ./configure or cmake
- `do_compile`: Build the package
- `do_install`: Install to staging area
- `do_package`: Create binary packages
- `do_rootfs`: Assemble root filesystem

### 6.4 Handle Build Errors

**If build fails:**
```bash
# Check error log
cat tmp/log/cooker/beagleplay/console-latest.log | grep ERROR

# Clean specific package and retry
bitbake -c cleansstate <package-name>
bitbake <package-name>

# Full clean (last resort)
bitbake -c cleanall <package-name>
```

**Common issues:**
- **Network timeouts**: Retry the build
- **Disk full**: Free up space, adjust `tmp/` location
- **Missing dependencies**: Update host packages

---

## 7. Analyzing Build Results

### 7.1 Locate Build Artifacts

```bash
cd ~/yocto-labs/build/tmp/deploy/images/beagleplay
ls -lh
```

**Key files:**
```
core-image-minimal-beagleplay.rootfs.tar.xz   # Root filesystem archive
core-image-minimal-beagleplay.rootfs.wic.xz   # Complete SD card image
Image-beagleplay.bin                          # Kernel binary
tiboot3.bin                                   # R5 SPL bootloader
tispl.bin                                     # ARM Trusted Firmware + U-Boot SPL
u-boot.img                                    # U-Boot proper
```

**Symlinks point to timestamped versions:**
```bash
ls -l Image-beagleplay.bin
# Output: Image-beagleplay.bin -> Image--5.10.168+git0+<hash>-r8a-beagleplay-<timestamp>.bin
```

### 7.2 Examine Image Contents

**Extract rootfs to inspect:**
```bash
cd ~/yocto-labs/build/tmp/deploy/images/beagleplay
mkdir -p /tmp/rootfs-inspect
tar -xf core-image-minimal-beagleplay.rootfs.tar.xz -C /tmp/rootfs-inspect
```

**Explore:**
```bash
ls -l /tmp/rootfs-inspect/
# Output: bin/ boot/ dev/ etc/ home/ lib/ media/ mnt/ proc/ run/ sbin/ sys/ tmp/ usr/ var/

du -sh /tmp/rootfs-inspect/
# Output: ~12M (very minimal!)
```

**Check installed packages:**
```bash
cat /tmp/rootfs-inspect/usr/lib/opkg/status | grep "^Package:"
```

### 7.3 Understand WIC Image Format

**WIC (Wic Image Creator)** is Yocto's partition image tool.

**Inspect partition layout:**
```bash
xz -dc core-image-minimal-beagleplay.rootfs.wic.xz > /tmp/image.wic
fdisk -l /tmp/image.wic
```

**Expected output:**
```
Device                                      Boot  Start     End Sectors  Size Id Type
/tmp/image.wic1                             *      8192  139263  131072   64M  c W95 FAT32 (LBA)
/tmp/image.wic2                                  147456 1196031 1048576  512M 83 Linux
```

**Partition structure:**
- **Partition 1 (boot)**: FAT32, contains kernel + Device Tree + bootloader
- **Partition 2 (rootfs)**: ext4, root filesystem

### 7.4 Check Build Statistics

```bash
bitbake -g core-image-minimal
cat pn-buildlist | wc -l
# Output: ~400 packages built
```

**View dependency graph:**
```bash
bitbake -g core-image-minimal -u depexp
# Opens graphical dependency explorer (requires X11)
```

**Build time report:**
```bash
cat tmp/log/cooker/beagleplay/console-latest.log | grep "Build Configuration"
cat tmp/log/cooker/beagleplay/console-latest.log | grep "Tasks Summary"
```

---

## 8. Preparing the SD Card

### 8.1 Identify SD Card Device

**Insert SD card and check device name:**
```bash
lsblk
```

**Output:**
```
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda           8:0    0 465.8G  0 disk 
└─sda1        8:1    0 465.8G  0 part /
sdb           8:16   1  14.9G  0 disk        <-- SD card
└─sdb1        8:17   1  14.9G  0 part /media/user/SDCARD
```

**Your SD card is `/dev/sdb`** (may be different on your system).

**WARNING:** Double-check! Writing to wrong device destroys data.

### 8.2 Unmount Existing Partitions

```bash
sudo umount /dev/sdb*
# Ignore errors if not mounted
```

### 8.3 Flash the Image

**Write WIC image to SD card:**
```bash
cd ~/yocto-labs/build/tmp/deploy/images/beagleplay

xz -dc core-image-minimal-beagleplay.rootfs.wic.xz | \
    sudo dd of=/dev/sdb conv=fdatasync bs=4M status=progress
```

**Explanation:**
- `xz -dc`: Decompress XZ archive to stdout
- `dd`: Write raw data to block device
- `conv=fdatasync`: Flush write cache (ensure data integrity)
- `bs=4M`: Write in 4MB blocks (faster)
- `status=progress`: Show transfer progress

**Wait for completion** (takes 1-2 minutes).

**Sync filesystems:**
```bash
sudo sync
```

**Safely remove SD card:**
```bash
sudo eject /dev/sdb
```

---

## 9. Serial Console Setup

### 9.1 Connect Serial Adapter

**BeaglePlay UART pins** (3-pin header next to USB-C):
```
Pin 1 (closest to USB-C): TX (Board transmit)
Pin 2 (middle):           RX (Board receive)
Pin 3 (far from USB-C):   GND (Ground)
```

**USB-to-Serial adapter connection:**
- Adapter **RX** → BeaglePlay **TX** (Pin 1)
- Adapter **TX** → BeaglePlay **RX** (Pin 2)
- Adapter **GND** → BeaglePlay **GND** (Pin 3)

**Rule:** TX connects to RX, RX connects to TX.

### 9.2 Configure Serial Permissions

```bash
# Add user to dialout group
sudo usermod -a -G dialout $USER

# Apply group change (logout/login or use newgrp)
newgrp dialout
```

**Verify:**
```bash
groups | grep dialout
```

### 9.3 Install and Use picocom

```bash
sudo apt install picocom
```

**Connect to serial console:**
```bash
picocom -b 115200 /dev/ttyUSB0
```

**Exit picocom:** Press `Ctrl+A` then `Ctrl+X`

**If `/dev/ttyUSB0` doesn't exist:**
```bash
dmesg | grep tty
# Look for: usb 1-2: FTDI USB Serial Device converter now attached to ttyUSB0
```

---

## 10. Booting the Image

### 10.1 Power On Sequence

1. **Insert SD card** into BeaglePlay
2. **Press and hold USR button** (near LEDs)
3. **Connect USB-C power cable** while holding button
4. **Release USR button after 2 seconds**

This forces boot from SD card instead of eMMC.

### 10.2 Observe Boot Logs

**You should see in picocom:**

**Stage 1: R5 SPL (tiboot3.bin):**
```
U-Boot SPL 2023.04 (Nov 20 2024)
SYSFW ABI: 3.1 (firmware rev 0x0009 '9.1.8--v09.01.08')
Trying to boot from MMC1
```

**Stage 2: TF-A + A53 SPL (tispl.bin):**
```
NOTICE:  BL31: v2.9(release):v2.9.0
NOTICE:  BL31: Built : 10:23:45, Nov 20 2024
```

**Stage 3: U-Boot (u-boot.img):**
```
U-Boot 2023.04 (Nov 20 2024)
SoC:   AM62X SR1.0 HS-FS
Model: BeagleBoard.org BeaglePlay
Hit any key to stop autoboot:  0
```

**Stage 4: Linux Kernel:**
```
[    0.000000] Booting Linux on physical CPU 0x0000000000 [0x410fd034]
[    0.000000] Linux version 5.10.168-ti-g12345678 (oe-user@oe-host) (aarch64-oe-linux-gcc ...)
...
[    5.234567] Run /sbin/init as init process
```

**Stage 5: Login Prompt:**
```
Poky (Yocto Project Reference Distro) 5.0.4 beagleplay /dev/ttyS2

beagleplay login:
```

### 10.3 Login

**Username:** `root` (no password by default)

```
beagleplay login: root
root@beagleplay:~#
```

**Congratulations!** You've successfully built and booted a Yocto-based Linux system.

---

## 11. Exploring the System

### 11.1 Basic System Information

```bash
# Kernel version
uname -a
# Output: Linux beagleplay 5.10.168-ti-g12345678 #1 SMP PREEMPT Wed Nov 20 10:23:45 UTC 2024 aarch64 GNU/Linux

# CPU info
cat /proc/cpuinfo | grep "model name"

# Memory
free -h

# Disk usage
df -h

# Running processes
ps aux
```

### 11.2 Test Network (if available)

```bash
# Show network interfaces
ip link show

# Bring up Ethernet (if cable connected)
ip link set dev eth0 up
udhcpc -i eth0

# Test connectivity
ping -c 3 8.8.8.8
```

### 11.3 Explore Installed Packages

```bash
# List installed packages
opkg list-installed

# Count packages
opkg list-installed | wc -l
# Output: ~50 packages in minimal image
```

### 11.4 Check Storage

```bash
# Partition layout
cat /proc/partitions

# Mount points
mount

# Root filesystem type
mount | grep "on / "
# Output: /dev/mmcblk0p2 on / type ext4 (rw,relatime)
```

---

## 12. Troubleshooting

### 12.1 Build Issues

**Problem:** `ERROR: Nothing PROVIDES <package>`

**Solution:** Missing layer dependency. Add the layer containing the package to `bblayers.conf`.

---

**Problem:** `ERROR: Fetcher failure for URL: 'https://...'`

**Solution:** Network issue or upstream server down. Check internet connection, retry build. If persistent, check recipe's `SRC_URI`.

---

**Problem:** `ERROR: Task do_compile failed`

**Solution:** Compilation error. Check:
```bash
cat tmp/work/<architecture>/<package>/<version>/temp/log.do_compile
```
May need to patch the recipe or update the package version.

---

**Problem:** Disk space full

**Solution:**
```bash
# Clean all build artifacts
bitbake -c cleanall core-image-minimal

# Remove old downloads
rm -rf downloads/*

# Clear sstate cache
rm -rf sstate-cache/*
```

### 12.2 Boot Issues

**Problem:** "Waiting for root device /dev/mmcblk0p2..."

**Solution:** U-Boot can't find rootfs partition. Check:
- SD card properly flashed
- Boot partition contains correct files
- U-Boot environment variables (printenv in U-Boot)

---

**Problem:** Kernel panic or immediate reboot

**Solution:**
- Kernel/Device Tree mismatch
- Corrupted image - reflash SD card
- Check Device Tree blob loaded: `cat /proc/device-tree/model`

---

**Problem:** No serial output

**Solution:**
- Verify TX/RX crossed correctly
- Check baud rate (should be 115200)
- Try different USB port
- Test serial adapter with loopback (connect TX to RX)

### 12.3 Yocto-Specific Issues

**Problem:** Changes to `local.conf` not taking effect

**Solution:** BitBake caches configuration. Force re-parse:
```bash
bitbake -c cleanall <package>
# Or delete tmp/cache/
```

---

**Problem:** Layer version mismatch errors

**Solution:** Ensure all layers use same Yocto release:
```bash
cd ~/yocto-labs
for d in poky meta-*; do
    cd $d
    echo "=== $d ==="
    git branch -v
    cd ..
done
```

All should show `scarthgap` or `yocto-5.0.*`.

---

**Problem:** Python errors during parsing

**Solution:** Virtual environment conflict. Start fresh shell:
```bash
# Exit any Python venv
deactivate

# Source Yocto environment cleanly
cd ~/yocto-labs
source poky/oe-init-build-env
```

---

## 13. Going Further

### 13.1 Rebuild After Changes

**After modifying local.conf:**
```bash
bitbake core-image-minimal
```

BitBake is smart - only rebuilds changed components.

### 13.2 Build Different Images

**Larger image with networking tools:**
```bash
bitbake core-image-base
```

**Full command-line tools:**
```bash
bitbake core-image-full-cmdline
```

**Custom image (we'll create this in Lab 16):**
```bash
bitbake my-custom-image
```

### 13.3 Explore BitBake Commands

```bash
# Show all available images
bitbake-layers show-recipes "*-image-*"

# Show recipe dependencies
bitbake -g core-image-minimal
dot -Tpng task-depends.dot -o task-depends.png

# Show recipe details
bitbake-layers show-recipes busybox
bitbake -e busybox | grep "^SRC_URI="
```

### 13.4 Speed Up Subsequent Builds

**Use shared downloads and sstate cache:**
```bash
# Edit conf/local.conf
DL_DIR = "/opt/yocto-shared/downloads"
SSTATE_DIR = "/opt/yocto-shared/sstate-cache"

# Create shared directories
sudo mkdir -p /opt/yocto-shared/{downloads,sstate-cache}
sudo chown -R $USER:$USER /opt/yocto-shared
```

This allows multiple build directories to share cached data.

---

## 14. Cleaning Up

### 14.1 Preserve Build Environment

**DO NOT delete these:**
- `build/conf/` - Your configuration
- `build/downloads/` - Source tarballs (reused)
- `build/sstate-cache/` - Build cache (huge time saver)

**Safe to delete:**
- `build/tmp/` - Regenerated on next build
- `build/cache/` - Regenerated on parsing

### 14.2 Clean Specific Packages

```bash
# Remove task outputs but keep downloads
bitbake -c clean <package>

# Remove shared state cache for package
bitbake -c cleansstate <package>

# Complete clean (removes downloads too)
bitbake -c cleanall <package>
```

### 14.3 Disk Space Management

**Check space usage:**
```bash
du -sh ~/yocto-labs/build/{tmp,downloads,sstate-cache}
```

**Typical sizes after first build:**
- `tmp/`: 20-40GB
- `downloads/`: 5-10GB
- `sstate-cache/`: 10-20GB

---

## 15. Key Takeaways

**What You Accomplished:**
1. ✅ Set up complete Yocto/OpenEmbedded environment
2. ✅ Configured build for BeaglePlay (TI AM62x)
3. ✅ Built minimal Linux distribution from source
4. ✅ Generated bootable SD card image
5. ✅ Successfully booted custom Linux on hardware

**Yocto Fundamentals Learned:**
- **Layers**: Modular metadata organization
- **BitBake**: Recipe-based build system
- **Machine configuration**: Hardware-specific settings
- **WIC images**: Partition layout and bootable media
- **Shared state caching**: Build acceleration

**Next Steps:**
- **Lab 11**: Advanced Yocto configuration and customization
- **Lab 12**: Add custom applications to images
- **Lab 13**: Create your own meta-layer
- **Lab 14**: Extend existing recipes with bbappend
- **Lab 15**: Define custom machine configurations

---

## 16. Verification Checklist

**Before proceeding to Lab 11, verify:**

- [ ] Yocto environment sources without errors
- [ ] `bitbake-layers show-layers` shows all 10 layers
- [ ] `bitbake core-image-minimal` completes successfully
- [ ] SD card image generated (~200MB compressed)
- [ ] BeaglePlay boots to login prompt from SD card
- [ ] Serial console accessible via `/dev/ttyUSB0`
- [ ] Root login works (no password)
- [ ] Basic commands work (ls, ps, mount)
- [ ] Kernel version shows Yocto build
- [ ] Build directory preserved for next lab

**Build time:** ~2 hours first build, ~10 minutes incremental  
**Disk usage:** ~60GB total  
**Success criteria:** Booting to shell on BeaglePlay hardware

---

## 17. Additional Resources

**Official Documentation:**
- Yocto Project Quick Build: https://docs.yoctoproject.org/brief-yoctoprojectqs/
- BitBake User Manual: https://docs.yoctoproject.org/bitbake/
- Yocto Dev Manual: https://docs.yoctoproject.org/dev-manual/

**TI-Specific:**
- meta-ti Layer: https://git.yoctoproject.org/meta-ti/
- AM62x Technical Reference: https://www.ti.com/product/AM625
- BeaglePlay Documentation: https://docs.beagleboard.org/latest/boards/beagleplay/

**Community:**
- Yocto Mailing Lists: https://lists.yoctoproject.org/
- #yocto IRC on Libera.Chat
- BeagleBoard Forums: https://forum.beagleboard.org/

---

**End of Lab 10**

*The Guide rates this lab: **Mostly Harmless** ⭐⭐⭐⭐*

You now have a functional Yocto build environment and understand the fundamentals of embedded Linux distribution creation. The next labs will teach you how to customize and extend this foundation to create production-ready systems.
