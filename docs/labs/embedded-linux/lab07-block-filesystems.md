# Lab 7: Block Filesystems and Persistent Storage

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about root filesystems:

*"A root filesystem is where all your files live. Think of it as the contents of your towel bag - essential utilities, helpful tools, and the occasional item whose purpose you've completely forgotten but you're certain you'll need eventually."*

## Objectives

Transition from network-based root filesystem to persistent block storage:

- Create and manage filesystem partitions on SD card
- Build ext4 filesystems for data storage
- Create read-only SquashFS root filesystem
- Use tmpfs for volatile temporary storage
- Configure persistent mounts with fstab
- Boot completely from SD card (kernel + DTB + rootfs)
- Implement proper separation: system vs. user data

## Prerequisites

- Completed Lab 6 (Hardware Devices)
- Working NFS root filesystem from Lab 5
- SD card (minimum 8GB) in BeaglePlay
- Understanding of filesystem concepts
- Familiarity with partition tables

## Lab Duration

Approximately 3-4 hours

## Storage Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        SD Card (mmcblk0)                        │
├────────────────┬──────────────┬────────────────┬────────────────┤
│ Partition 1    │ Partition 2  │ Partition 3    │ Partition 4    │
│ Boot (FAT32)   │ Env (ext4)   │ RootFS (squash)│ Data (ext4)    │
│ ~100MB         │ ~50MB        │ ~100MB         │ Rest of space  │
│                │              │                │                │
│ tiboot3.bin    │ uEnv.txt     │ BusyBox        │ /www/upload/   │
│ tispl.bin      │ Image.gz     │ Libraries      │ files/         │
│ u-boot.img     │ *.dtb        │ /bin, /sbin    │ User data      │
│                │              │ /etc (config)  │                │
└────────────────┴──────────────┴────────────────┴────────────────┘

System Boot Flow:
1. ROM → tiboot3.bin (partition 1, FAT32)
2. R5 SPL → tispl.bin (partition 1, FAT32)
3. A53 U-Boot → u-boot.img (partition 1, FAT32)
4. U-Boot loads: Image.gz + DTB (partition 2, ext4)
5. Linux mounts: root=squashfs (partition 3, read-only)
6. System mounts: /www/upload/files (partition 4, read-write)
7. tmpfs mounted at: /var/log, /tmp (volatile RAM)
```

## Environment Setup

### Working Directory

```bash
# Create block filesystem lab directory
cd $HOME/embedded-linux-beagleplay-labs
mkdir -p blockfs
cd blockfs
```

### Verify Current NFS Setup

```bash
# On BeaglePlay, verify current NFS mount
mount | grep nfs

# Expected:
# 192.168.0.1:/home/<user>/.../tinysystem/nfsroot on / type nfs ...

# Note current system size
du -sh /
```

## Section 1: Filesystem Support in Kernel

### Configure Kernel for Filesystem Types

We need support for ext4, SquashFS, and tmpfs.

```bash
cd $HOME/embedded-linux-beagleplay-labs/kernel/linux

make ARCH=arm64 CROSS_COMPILE=aarch64-beagleplay-linux-musl- menuconfig
```

**Enable the following:**

```
File systems --->
    <*> Second extended fs support            (CONFIG_EXT2_FS)
    <*> The Extended 4 (ext4) filesystem      (CONFIG_EXT4_FS)
        [*] Ext4 POSIX Access Control Lists
        [*] Ext4 Security Labels
    
    [*] Miscellaneous filesystems --->
        <*> SquashFS 4.0 - Squashed file system support  (CONFIG_SQUASHFS)
            [*] Squashfs XATTR support
            [*] Include support for ZLIB compressed file systems
            [*] Include support for LZ4 compressed file systems
            [*] Include support for LZO compressed file systems
            [*] Include support for XZ compressed file systems
            [*] Include support for ZSTD compressed file systems
    
    Pseudo filesystems --->
        [*] Tmpfs virtual memory file system support (CONFIG_TMPFS)
        [*] Tmpfs POSIX Access Control Lists
```

**Compile and Deploy:**

```bash
# Build kernel
make ARCH=arm64 CROSS_COMPILE=aarch64-beagleplay-linux-musl- Image.gz -j$(nproc)

# Copy to TFTP
cp arch/arm64/boot/Image.gz /srv/tftp/

# Reboot BeaglePlay
```

### Verify Filesystem Support

```bash
# On BeaglePlay (after reboot)
cat /proc/filesystems

# Expected output (partial):
# nodev   sysfs
# nodev   tmpfs
# nodev   devtmpfs
#         ext4
#         squashfs
# nodev   nfs
```

**Verification Checklist:**

- [ ] ext4 filesystem support enabled
- [ ] SquashFS support with compression enabled
- [ ] tmpfs support enabled
- [ ] Kernel compiled and deployed
- [ ] Filesystem types visible in `/proc/filesystems`

## Section 2: SD Card Partitioning

### Identify SD Card Device

```bash
# On BeaglePlay
cat /proc/partitions

# Expected output:
# major minor  #blocks  name
#  179        0    7634944 mmcblk0
#  179        1     131072 mmcblk0p1    # Boot partition (existing)
#  179        2      32768 mmcblk0p2    # Env partition (existing)
```

**Important (like knowing where your towel is):** 
- `mmcblk0` is the SD card device
- Existing partitions 1 and 2 contain bootloader and environment
- **DO NOT DELETE OR MODIFY PARTITIONS 1 AND 2!**

### Backup Important Data

Before repartitioning, backup the web upload files (if any):

```bash
# On workstation (from NFS root)
cd $HOME/embedded-linux-beagleplay-labs/tinysystem/nfsroot
tar czf /tmp/www-backup.tar.gz www/upload/files/
```

### Create New Partitions

We'll add two new partitions:
- Partition 3: 100MB for SquashFS root filesystem
- Partition 4: Remaining space for data (ext4)

**On BeaglePlay:**

```bash
# CAUTION: This modifies the partition table!
fdisk /dev/mmcblk0
```

**fdisk interactive commands:**

```
Command (m for help): p    # Print current partition table

# You should see partitions 1 and 2
# Note the end sector of partition 2

Command (m for help): n    # New partition
Partition type: p          # Primary
Partition number: 3        # Partition 3
First sector: <press Enter to accept default>
Last sector: +100M         # 100 megabytes for root filesystem

Command (m for help): n    # New partition for data
Partition type: p          # Primary
Partition number: 4        # Partition 4  
First sector: <press Enter>
Last sector: <press Enter> # Use remaining space

Command (m for help): p    # Print to verify

# You should now see 4 partitions:
# mmcblk0p1 (boot, FAT32)
# mmcblk0p2 (env, ext4)
# mmcblk0p3 (rootfs, will be SquashFS)
# mmcblk0p4 (data, will be ext4)

Command (m for help): w    # Write changes and exit
```

### Verify New Partitions

```bash
# Re-read partition table
partprobe /dev/mmcblk0

# Or reboot if partprobe not available
reboot

# After reboot, verify
cat /proc/partitions

# Expected:
#  179        0    7634944 mmcblk0
#  179        1     131072 mmcblk0p1
#  179        2      32768 mmcblk0p2
#  179        3     102400 mmcblk0p3    # New: ~100MB
#  179        4    7398400 mmcblk0p4    # New: rest of card
```

**Verification Checklist:**

- [ ] Partition table backed up (optional but recommended)
- [ ] New partition 3 created (100MB)
- [ ] New partition 4 created (remaining space)
- [ ] Partition table written successfully
- [ ] New partitions visible in `/proc/partitions`

## Section 3: Data Partition (ext4)

### Create ext4 Filesystem

```bash
# On BeaglePlay
# Create ext4 filesystem on partition 4
mkfs.ext4 -L data /dev/mmcblk0p4

# Flags explanation:
# -L data: Set volume label to "data"
# -E nodiscard: Skip bad block discarding (faster, optional)

# Expected output:
# Creating filesystem with ... 4k blocks and ... inodes
# ...
# Writing superblocks and filesystem accounting information: done
```

### Mount and Test Data Partition

```bash
# Create mount point
mkdir -p /mnt/data

# Mount partition
mount /dev/mmcblk0p4 /mnt/data

# Verify mount
mount | grep mmcblk0p4
# /dev/mmcblk0p4 on /mnt/data type ext4 (rw,relatime)

# Test write
echo "Test file on data partition" > /mnt/data/test.txt
cat /mnt/data/test.txt

# Check filesystem info
df -h /mnt/data
# Should show available space
```

### Migrate Upload Directory to Data Partition

Currently, web uploads are stored in `/www/upload/files` in the NFS root. Let's move this to persistent storage.

```bash
# Create directory structure on data partition
mkdir -p /mnt/data/www/upload/files

# Restore backup if you created one earlier
# (or manually copy any existing files from NFS)

# Unmount for now (we'll set up automatic mounting later)
umount /mnt/data
```

**Verification Checklist:**

- [ ] ext4 filesystem created on `/dev/mmcblk0p4`
- [ ] Filesystem labeled as "data"
- [ ] Successfully mounted and tested write access
- [ ] Directory structure created for web uploads

## Section 4: Root Filesystem (SquashFS)

### Prepare Root Filesystem Directory

We'll use the NFS root from Lab 5 as the base.

```bash
# On workstation
cd $HOME/embedded-linux-beagleplay-labs/blockfs

# Copy NFS root to blockfs directory
cp -a ../tinysystem/nfsroot ./rootfs

# Important: Create init symlink
# SquashFS kernel boot requires /init
cd rootfs
ln -s sbin/init init

# Verify
ls -l init
# lrwxrwxrwx 1 user user 9 ... init -> sbin/init
```

### Modify Startup Scripts for Block Storage

The startup script needs to mount the data partition automatically.

```bash
# Edit rcS
cd $HOME/embedded-linux-beagleplay-labs/blockfs/rootfs/etc/init.d
vi rcS
```

**Modify rcS to add data partition mount:**

```bash
#!/bin/sh

# Mount essential filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys

# Mount data partition for web uploads
mkdir -p /www/upload/files
mount -t ext4 /dev/mmcblk0p4 /www/upload/files

# Mount tmpfs for temporary files
mount -t tmpfs tmpfs /tmp
mount -t tmpfs tmpfs /var

# Create necessary directories in tmpfs
mkdir -p /var/log
mkdir -p /var/run

# Load kernel modules
modprobe snd-usb-audio
modprobe nunchuk

# Network configuration
ip addr add 192.168.0.100/24 dev eth0
ip link set eth0 up

# Start web server
/usr/sbin/httpd -h /www/

echo "Starting system..."
```

### Update Upload Script Configuration

The upload script needs to log to tmpfs, not the data partition.

```bash
cd $HOME/embedded-linux-beagleplay-labs/blockfs/rootfs/www/cgi-bin
vi upload.cfg
```

**Update log file path:**

```bash
#!/bin/sh

# Upload configuration
UPLOAD_DIR=/www/upload/files
LOG_FILE=/var/log/upload.log    # Changed from /www/upload/files/upload.log
MAX_SIZE=10485760  # 10MB
```

### Install SquashFS Tools (Workstation)

```bash
# On workstation
sudo apt update
sudo apt install squashfs-tools
```

### Create SquashFS Image

```bash
cd $HOME/embedded-linux-beagleplay-labs/blockfs

# Create compressed SquashFS image
mksquashfs rootfs rootfs.sqfs -comp xz -Xbcj arm

# Flags explanation:
# -comp xz: Use XZ compression (best compression ratio)
# -Xbcj arm: ARM-specific binary optimization filter

# Expected output:
# Creating 4.0 filesystem on rootfs.sqfs, block size 131072.
# ...
# Exportable Squashfs 4.0 filesystem, xz compressed, data block size 131072
```

**Check Image Size:**

```bash
ls -lh rootfs.sqfs

# Should be significantly smaller than original rootfs directory
du -sh rootfs
du -sh rootfs.sqfs

# Example:
# 50M   rootfs/
# 12M   rootfs.sqfs
```

### Write SquashFS to SD Card

We'll use `dd` to write the image directly to partition 3.

**Important (like knowing where your towel is):** This operation must be done from the workstation or from BeaglePlay before mounting partition 3.

#### Option A: From Workstation (SD Card Reader)

```bash
# Remove SD card from BeaglePlay and insert into workstation SD reader
# Identify device (e.g., /dev/sdb)
lsblk

# Write SquashFS image to partition 3
sudo dd if=rootfs.sqfs of=/dev/sdb3 bs=1M status=progress

# Sync to ensure all data is written
sync
```

#### Option B: From BeaglePlay (via NFS)

```bash
# On workstation: copy image to NFS root
cp rootfs.sqfs $HOME/embedded-linux-beagleplay-labs/tinysystem/nfsroot/tmp/

# On BeaglePlay:
dd if=/tmp/rootfs.sqfs of=/dev/mmcblk0p3 bs=1M

# Sync
sync
```

**Verification Checklist:**

- [ ] NFS root copied to blockfs/rootfs directory
- [ ] `/init` symlink created pointing to `/sbin/init`
- [ ] Startup script modified to mount data partition
- [ ] Upload script configured to log to `/var/log`
- [ ] SquashFS image created successfully
- [ ] Image written to `/dev/mmcblk0p3`

## Section 5: Tmpfs for Volatile Storage

### Why Tmpfs?

Tmpfs is a temporary filesystem stored in RAM:

- **Fast:** No disk I/O, operates at RAM speed
- **Volatile:** Data lost on reboot (ideal for logs, temporary files)
- **Automatically sized:** Grows/shrinks based on usage
- **Read-only root friendly:** Allows writes even with SquashFS root

### Tmpfs Mount Points

Our startup script already mounts tmpfs at:

```bash
mount -t tmpfs tmpfs /tmp      # Temporary files
mount -t tmpfs tmpfs /var      # Variable data (logs, run files)
```

### Verify Tmpfs in Startup Script

The `rcS` script we modified earlier should have:

```bash
# Mount tmpfs for temporary files
mount -t tmpfs tmpfs /tmp
mount -t tmpfs tmpfs /var

# Create necessary directories in tmpfs
mkdir -p /var/log
mkdir -p /var/run
```

This ensures:
- `/var/log/upload.log` is stored in RAM (volatile)
- System run files go to `/var/run` (volatile)
- Temporary files go to `/tmp` (volatile)

## Section 6: Boot from SD Card Root Filesystem

### Configure U-Boot Bootcmd

Now we'll configure U-Boot to boot the kernel and DTB from SD card partition 2 (ext4), and mount root from partition 3 (SquashFS).

**Copy Kernel and DTB to SD Card (Workstation):**

```bash
# Remove SD card from BeaglePlay, insert into workstation
# Assume partition 2 is mounted at /media/<user>/env

# Copy kernel
cp $HOME/embedded-linux-beagleplay-labs/kernel/linux/arch/arm64/boot/Image.gz \
   /media/<user>/env/

# Copy Device Tree
cp $HOME/embedded-linux-beagleplay-labs/kernel/linux/arch/arm64/boot/dts/ti/k3-am625-beagleplay-custom.dtb \
   /media/<user>/env/

# Sync and unmount
sync
sudo umount /media/<user>/env
```

**Insert SD card back into BeaglePlay and boot.**

### Update U-Boot Environment

**On BeaglePlay U-Boot console (interrupt boot with any key):**

```bash
# Save current TFTP boot command (for easy switching back)
=> setenv bootcmdtftp "${bootcmd}"

# Define SD card boot command
=> setenv bootcmdsd 'load mmc 1:2 0x80000000 Image.gz; load mmc 1:2 0x82000000 k3-am625-beagleplay-custom.dtb; booti 0x80000000 - 0x82000000'

# Set kernel command line for SD card root
=> setenv bootargs 'console=ttyS2,115200 root=/dev/mmcblk0p3 rootwait ro'

# Explanation:
# - console=ttyS2,115200: Serial console
# - root=/dev/mmcblk0p3: Root filesystem on partition 3
# - rootwait: Wait for SD card initialization before mounting root
# - ro: Mount root filesystem as read-only (SquashFS requirement)

# Set bootcmd to SD card boot
=> setenv bootcmd 'run bootcmdsd'

# Save environment
=> saveenv

# Boot
=> boot
```

### Expected Boot Sequence

Watch the boot messages:

```
U-Boot SPL 2024.01 (...)
...
Loading kernel from MMC...
Loading Device Tree from MMC...
Starting kernel ...

[    0.000000] Booting Linux on physical CPU 0x0000000000 [0x410fd034]
...
[    2.543210] VFS: Mounted root (squashfs filesystem) readonly on device 179:3.
[    2.678543] devtmpfs: mounted
...
[    3.123456] mount: mounting /dev/mmcblk0p4 on /www/upload/files succeeded
...
Starting system...

Welcome to BeaglePlay!
beagleplay login:
```

**Key indicators:**
- `Mounted root (squashfs filesystem) readonly on device 179:3` ← SquashFS root
- `mounting /dev/mmcblk0p4 on /www/upload/files succeeded` ← Data partition

### Verify Mounts

```bash
# Login as root (no password)

# Check all mounts
mount

# Expected output:
# /dev/mmcblk0p3 on / type squashfs (ro,relatime)
# devtmpfs on /dev type devtmpfs (rw,relatime,...)
# proc on /proc type proc (rw,relatime)
# sysfs on /sys type sysfs (rw,relatime)
# /dev/mmcblk0p4 on /www/upload/files type ext4 (rw,relatime)
# tmpfs on /tmp type tmpfs (rw,relatime)
# tmpfs on /var type tmpfs (rw,relatime)

# Check filesystem usage
df -h

# /dev/mmcblk0p3 on / should show squashfs, read-only
# /dev/mmcblk0p4 on /www/upload/files should show ext4, read-write
# tmpfs on /var and /tmp should show RAM usage
```

### Test Read-Only Root

```bash
# Try to create a file in root (should fail)
touch /test.txt
# touch: /test.txt: Read-only file system

# Verify root is read-only
mount | grep "on / "
# /dev/mmcblk0p3 on / type squashfs (ro,relatime)
```

### Test Write to Data Partition

```bash
# Create test file
echo "Persistent data test" > /www/upload/files/test.txt

# Read it back
cat /www/upload/files/test.txt

# Reboot
reboot

# After reboot, verify file persists
cat /www/upload/files/test.txt
# Persistent data test    <-- File survived reboot!
```

### Test Tmpfs Volatility

```bash
# Create file in tmpfs
echo "Volatile log entry" > /var/log/test.log
cat /var/log/test.log

# Reboot
reboot

# After reboot, check if file exists
cat /var/log/test.log
# cat: can't open '/var/log/test.log': No such file or directory  <-- Gone!
```

**Verification Checklist:**

- [ ] Kernel and DTB copied to SD card partition 2
- [ ] U-Boot configured to load from SD card
- [ ] Kernel command line set with `root=/dev/mmcblk0p3 rootwait ro`
- [ ] System boots successfully from SquashFS root
- [ ] Root filesystem mounted read-only
- [ ] Data partition mounted at `/www/upload/files` (read-write)
- [ ] Tmpfs mounted at `/tmp` and `/var`
- [ ] Persistent data survives reboot
- [ ] Tmpfs data is volatile (lost on reboot)

## Section 7: Testing Web Interface

### Verify HTTP Server

```bash
# On BeaglePlay, check httpd is running
ps | grep httpd

# Expected:
#  1234 root     /usr/sbin/httpd -h /www/
```

### Test Upload Functionality

**From your workstation browser:**

1. Navigate to `http://192.168.0.100/index.html`

2. Upload a test image using the web interface

3. Verify image appears in listing

**On BeaglePlay:**

```bash
# Check uploaded file
ls -l /www/upload/files/

# Should show your uploaded image
# -rw-r--r-- 1 root root 123456 Jan  1 00:12 test-image.jpg
```

### Check Upload Log

```bash
# View upload log (tmpfs - volatile)
cat /var/log/upload.log

# Should show upload activity
# Jan  1 00:12:34 File uploaded: test-image.jpg (123456 bytes)
```

### Verify Log Volatility

```bash
# Note log contents
cat /var/log/upload.log

# Reboot
reboot

# After reboot, check log
cat /var/log/upload.log
# Should be empty or non-existent

# But uploaded files persist!
ls /www/upload/files/
# Files still there!
```

**Verification Checklist:**

- [ ] Web server running and accessible
- [ ] File upload functionality works
- [ ] Uploaded files stored on ext4 data partition
- [ ] Upload log written to tmpfs `/var/log`
- [ ] Uploaded files persist across reboot
- [ ] Upload log is volatile (lost on reboot)

## Section 8: Switching Boot Modes

### Switch Back to TFTP Boot (for Development)

During development, NFS/TFTP boot is faster for iteration. Let's keep the ability to switch modes.

**On U-Boot console:**

```bash
# Boot from TFTP/NFS
=> setenv bootcmd 'run bootcmdtftp'
=> saveenv
=> boot

# Or without saving (one-time):
=> run bootcmdtftp
```

### Switch Back to SD Card Boot

```bash
# Boot from SD card
=> setenv bootcmd 'run bootcmdsd'
=> saveenv
=> boot
```

### U-Boot Environment Summary

After this lab, your U-Boot environment should have:

```bash
bootcmdtftp=<TFTP boot commands>   # Development mode
bootcmdsd=run bootcmdsd            # Production mode
bootcmd=run bootcmdsd              # Default: SD card boot
```

## Troubleshooting Guide

### Problem: Kernel panic - not syncing: VFS: Unable to mount root fs

**Symptoms:**

```
[    2.123456] VFS: Cannot open root device "mmcblk0p3" or unknown-block(179,3)
[    2.123456] Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(179,3)
```

**Possible causes:**

1. **SquashFS support not compiled in kernel:**

```bash
# Verify CONFIG_SQUASHFS=y
cd $HOME/embedded-linux-beagleplay-labs/kernel/linux
grep CONFIG_SQUASHFS .config

# Should show:
# CONFIG_SQUASHFS=y

# If not, reconfigure and recompile
make ARCH=arm64 menuconfig
# Enable SquashFS
make ARCH=arm64 CROSS_COMPILE=aarch64-beagleplay-linux-musl- Image.gz -j$(nproc)
```

2. **Partition 3 is empty or corrupted:**

```bash
# Boot from NFS first, then check partition 3
dd if=/dev/mmcblk0p3 bs=512 count=1 | hexdump -C

# SquashFS magic: 0x73717368 (hsqs in little-endian)
# Should see "hsqs" in first few bytes

# If not, re-write SquashFS image:
dd if=/tmp/rootfs.sqfs of=/dev/mmcblk0p3 bs=1M
sync
```

3. **Wrong partition number in bootargs:**

```bash
# Verify bootargs
# In U-Boot:
=> printenv bootargs
# Should show: root=/dev/mmcblk0p3

# If wrong, correct it:
=> setenv bootargs 'console=ttyS2,115200 root=/dev/mmcblk0p3 rootwait ro'
=> saveenv
```

### Problem: /www/upload/files mount fails

**Symptoms:**

```
mount: mounting /dev/mmcblk0p4 on /www/upload/files failed: No such device
```

**Solutions:**

1. **Ext4 support missing:**

```bash
# Verify ext4 is enabled in kernel
cat /proc/filesystems | grep ext4

# If not listed, recompile kernel with CONFIG_EXT4_FS=y
```

2. **Partition 4 not formatted:**

```bash
# Check if partition exists
cat /proc/partitions | grep mmcblk0p4

# Format if needed
mkfs.ext4 /dev/mmcblk0p4
```

3. **Mount point doesn't exist:**

```bash
# rcS should create mount point:
mkdir -p /www/upload/files
```

### Problem: Tmpfs mount fails

**Error:**

```
mount: mounting tmpfs on /tmp failed: Invalid argument
```

**Solution:**

```bash
# Verify tmpfs support
cat /proc/filesystems | grep tmpfs

# Should show:
# nodev tmpfs

# If missing, enable CONFIG_TMPFS in kernel
```

### Problem: System is read-only, can't write anywhere

**Symptoms:**

```bash
# Even data partition is read-only
touch /www/upload/files/test.txt
# touch: /www/upload/files/test.txt: Read-only file system
```

**Cause:** Data partition mounted read-only.

**Solution:**

```bash
# Remount data partition as read-write
mount -o remount,rw /dev/mmcblk0p4 /www/upload/files

# Verify
mount | grep mmcblk0p4
# Should show (rw,...)

# Fix rcS to mount as rw explicitly:
mount -t ext4 -o rw /dev/mmcblk0p4 /www/upload/files
```

### Problem: Cannot update system (SquashFS is read-only)

This is intentional! SquashFS root is immutable.

**To update the system:**

1. **Modify rootfs on workstation:**

```bash
cd $HOME/embedded-linux-beagleplay-labs/blockfs/rootfs
# Make changes to files/scripts
```

2. **Rebuild SquashFS image:**

```bash
cd $HOME/embedded-linux-beagleplay-labs/blockfs
mksquashfs rootfs rootfs.sqfs -comp xz -Xbcj arm
```

3. **Write new image to partition 3:**

```bash
# From workstation (SD card reader):
sudo dd if=rootfs.sqfs of=/dev/sdb3 bs=1M status=progress
sync

# Or from BeaglePlay (boot from NFS first):
dd if=/tmp/rootfs.sqfs of=/dev/mmcblk0p3 bs=1M
sync
```

4. **Reboot and test**

This workflow ensures system integrity - accidental changes can't corrupt the root filesystem.

## Advanced Challenges

### Challenge 1: Implement Overlay Filesystem

Combine read-only SquashFS root with read-write tmpfs overlay, allowing temporary system modifications without modifying the base SquashFS.

**Hint:** Use `overlayfs`

```bash
# In rcS:
mount -t overlay overlay -o lowerdir=/,upperdir=/tmp/upper,workdir=/tmp/work /mnt/overlay
```

### Challenge 2: Add Swap Partition

Create a swap partition on the SD card for emergency memory relief.

**Steps:**
1. Create partition 5 with fdisk (512MB)
2. Format as swap: `mkswap /dev/mmcblk0p5`
3. Enable in rcS: `swapon /dev/mmcblk0p5`

### Challenge 3: Implement /etc Overlay

Make `/etc` writable while keeping `/` read-only, allowing runtime configuration changes.

**Approach:**
- Copy `/etc` to `/www/upload/files/etc` (persistent)
- Use bind mount or overlay to make `/etc` writable

### Challenge 4: Partition Alignment Optimization

Optimize partition boundaries for SD card erase block size.

```bash
# Find preferred erase size
cat /sys/bus/mmc/devices/mmc0:0001/preferred_erase_size

# Align partitions to multiples of this size
# Use fdisk with sector calculations
```

### Challenge 5: Read-Only Root with Persistent Logs

Implement persistent logging despite read-only root:

**Approach:**
- Store logs on data partition: `/www/upload/files/logs/`
- Bind mount or symlink `/var/log` to persistent location
- Rotate logs to prevent partition filling

## What You've Learned

By completing this lab, you've mastered:

✅ **Filesystem Kernel Support:**
- Configured ext4 filesystem support
- Enabled SquashFS with multiple compression algorithms
- Enabled tmpfs for volatile RAM storage

✅ **Partition Management:**
- Used fdisk to create new partitions
- Preserved bootloader partitions
- Aligned partitions properly on SD card

✅ **ext4 Filesystem:**
- Created ext4 filesystems with labels
- Mounted and tested read-write access
- Used ext4 for persistent user data

✅ **SquashFS:**
- Created compressed SquashFS images
- Understood compression options (xz, lzo, lz4)
- Wrote SquashFS directly to partition
- Booted from read-only SquashFS root

✅ **Tmpfs:**
- Mounted tmpfs for volatile storage
- Used tmpfs for `/tmp` and `/var`
- Understood tmpfs lifecycle (RAM-based, lost on reboot)

✅ **System Integration:**
- Migrated from NFS to block storage boot
- Modified startup scripts for automatic mounting
- Configured U-Boot for SD card boot
- Implemented proper separation: system vs. user data

✅ **Boot Configuration:**
- Stored kernel and DTB on ext4 partition
- Configured kernel command line (`root=`, `rootwait`, `ro`)
- Managed multiple boot modes (TFTP vs. SD card)

✅ **Storage Architecture Best Practices:**
- Read-only root filesystem (SquashFS) for system integrity
- Read-write data partition (ext4) for user files
- Volatile storage (tmpfs) for temporary data and logs
- Clear separation of concerns

## Going Further

### Recommended Reading

**Kernel Documentation:**
- `Documentation/filesystems/ext4.txt` - ext4 filesystem
- `Documentation/filesystems/squashfs.txt` - SquashFS details
- `Documentation/filesystems/tmpfs.txt` - Tmpfs usage

**Storage:**
- `Documentation/mmc/` - MMC/SD card subsystem

**Articles:**
- "SquashFS vs ext4: When to use which" - Embedded Linux design patterns
- "Optimizing SD card usage in embedded Linux" - Partition alignment, wear leveling

### Next Steps

In **Lab 8: Buildroot**, you'll:
- Automate the entire build process with Buildroot
- Generate root filesystem images automatically
- Build external kernel modules with Buildroot
- Configure and customize package selection
- Create reproducible embedded Linux systems

---

**Estimated Completion Time:** 3-4 hours

**Difficulty:** ⭐⭐⭐☆☆ (Intermediate)

**Prerequisites Met:** ✅ Lab 6 (Hardware Devices)

**Leads to:** Lab 8 (Buildroot System Integration)
