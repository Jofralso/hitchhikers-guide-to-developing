# Lab 11: Advanced Yocto Configuration

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about Yocto:

*"The Yocto Project is a build system of such staggering complexity that it makes the Infinite Improbability Drive look straightforward. However, once you understand it (which will take approximately 42 tries), it's actually quite brilliant."*

## Objectives

Master advanced BitBake configuration techniques, package management, and network-based development workflows to accelerate iteration cycles.

**What You'll Learn:**
- Customize package selection with `IMAGE_INSTALL`
- Configure preferred package providers
- Set up NFS root filesystem for rapid testing
- Use TFTP for kernel/bootloader development
- Optimize BitBake build performance
- Understand BitBake task execution model

**Time Required:** 2-3 hours (or approximately 42 minutes in improbable circumstances)

---

## Prerequisites

**Completed Labs:**
- Lab 10: First Yocto Project Build

**Hardware:**
- BeaglePlay with SD card (from Lab 10)
- Ethernet cable
- Development workstation with Ethernet port (or USB-Ethernet adapter)

**Software:**
- Working Yocto build environment
- `core-image-minimal` successfully built

---

## 1. Understanding Yocto Configuration

### 1.1 Configuration Hierarchy

Yocto's configuration comes from multiple sources with defined precedence:

```
┌─────────────────────────────────────┐
│  BitBake Variables (Highest)        │
│  1. Environment (BB_ENV_PASSTHROUGH) │
│  2. local.conf                       │
│  3. auto.conf                        │
│  4. Machine config (.conf)           │
│  5. Distribution config (poky.conf)  │
│  6. Layer config (layer.conf)        │
│  7. Recipe (.bb) files               │
│  8. Default values (Lowest)          │
└─────────────────────────────────────┘
```

**Assignment operators:**
- `=`: Simple assignment (evaluated when accessed)
- `:=`: Immediate expansion
- `+=`: Append with space
- `=+`: Prepend with space
- `.=`: Append without space
- `=.`: Prepend without space
- `??=`: Weak default (only if not set)
- `?=`: Default (overridable)

### 1.2 Key Configuration Files

**`conf/local.conf`:**
```
# Build-specific settings
MACHINE = "beagleplay"
DL_DIR = "${TOPDIR}/downloads"
SSTATE_DIR = "${TOPDIR}/sstate-cache"
DISTRO = "poky"
PACKAGE_CLASSES = "package_ipk"
IMAGE_INSTALL:append = " dropbear strace"
```

**`conf/bblayers.conf`:**
```
# Layer inclusion
BBLAYERS ?= " \
  ${TOPDIR}/../poky/meta \
  ${TOPDIR}/../meta-ti/meta-ti-bsp \
  ...
"
```

**Why two files?**
- `bblayers.conf`: What layers to use (rarely changes)
- `local.conf`: Build customization (frequently modified)

### 1.3 Variable Exploration

**View all variables for a recipe:**
```bash
bitbake -e core-image-minimal | less
```

**Search for specific variable:**
```bash
bitbake -e core-image-minimal | grep "^IMAGE_INSTALL="
```

**Show where variable is set:**
```bash
bitbake -e core-image-minimal | grep -A 5 "^# IMAGE_INSTALL"
```

---

## 2. Customizing Package Selection

### 2.1 Understanding IMAGE_INSTALL

**`IMAGE_INSTALL`** controls which packages go into the final rootfs.

**View default packages:**
```bash
cd ~/yocto-labs/build
bitbake -e core-image-minimal | grep "^IMAGE_INSTALL="
```

**Output (example):**
```
IMAGE_INSTALL="packagegroup-core-boot packagegroup-base-extended dropbear"
```

**Package groups are meta-packages** that pull in multiple related packages.

### 2.2 Add Packages to Image

**Edit local.conf:**
```bash
nano conf/local.conf
```

**Add Dropbear SSH server:**
```
# Append to IMAGE_INSTALL (note the space before dropbear)
IMAGE_INSTALL:append = " dropbear"
```

**Why `:append` instead of `+=`?**
- `:append` is applied after all parsing (can't be overridden)
- `+=` can be overridden by recipes
- Leading space in `:append` is critical (avoids "packagedropbear")

**Add multiple packages:**
```
IMAGE_INSTALL:append = " \
    dropbear \
    strace \
    htop \
    nano \
    mtd-utils \
    i2c-tools \
    can-utils \
"
```

### 2.3 Rebuild with New Packages

```bash
bitbake core-image-minimal
```

**BitBake is intelligent:**
- Only rebuilds rootfs assembly
- Reuses previously built packages
- Downloads new package sources as needed

**Build takes ~5-10 minutes** (not full rebuild).

### 2.4 Verify Package Inclusion

**After build completes:**
```bash
cd ~/yocto-labs/build/tmp/deploy/images/beagleplay
tar -tf core-image-minimal-beagleplay.rootfs.tar.xz | grep -E "(dropbear|strace|htop)"
```

**Expected output:**
```
./usr/sbin/dropbear
./usr/bin/strace
./usr/bin/htop
...
```

### 2.5 Remove Packages

**Use `IMAGE_INSTALL:remove`:**
```
IMAGE_INSTALL:remove = "packagegroup-core-boot-dev"
```

**Or override completely:**
```
IMAGE_INSTALL = "packagegroup-core-boot dropbear"
```

**⚠️  WARNING (in large, friendly letters):** Complete override breaks things - use `:append`/`:remove` instead.

---

## 3. Setting Up Network Boot (NFS Root)

### 3.1 Why NFS Root?

**Benefits:**
- **No reflashing**: Changes visible immediately
- **Fast iteration**: Edit → sync → reboot (seconds)
- **Easy debugging**: Full access to rootfs from host
- **Unlimited space**: No SD card size constraints

**When to use:**
- Active development
- Kernel/driver debugging
- Application testing

**When NOT to use:**
- Production deployment
- Performance benchmarking (network overhead)
- Testing storage-specific features

### 3.2 Install NFS Server

**On development workstation:**
```bash
sudo apt install nfs-kernel-server
```

**Create NFS export directory:**
```bash
sudo mkdir -p /nfs/beagleplay
sudo chown -R $USER:$USER /nfs/beagleplay
chmod 755 /nfs/beagleplay
```

### 3.3 Configure NFS Exports

**Edit `/etc/exports`:**
```bash
sudo nano /etc/exports
```

**Add export entry:**
```
/nfs/beagleplay *(rw,sync,no_root_squash,no_subtree_check)
```

**Explanation:**
- `*`: Allow any client (use `192.168.0.0/24` for security)
- `rw`: Read-write access
- `sync`: Synchronous writes (safer but slower)
- `no_root_squash`: Don't map root UID to nobody
- `no_subtree_check`: Faster, less safe (OK for development)

**Apply changes:**
```bash
sudo exportfs -ra
```

**Verify export:**
```bash
sudo exportfs -v
# Output: /nfs/beagleplay <world>(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,no_root_squash,no_all_squash)
```

### 3.4 Extract Rootfs to NFS

**Clean NFS directory:**
```bash
sudo rm -rf /nfs/beagleplay/*
```

**Extract latest build:**
```bash
cd ~/yocto-labs/build/tmp/deploy/images/beagleplay
sudo tar -xf core-image-minimal-beagleplay.rootfs.tar.xz -C /nfs/beagleplay
```

**Verify extraction:**
```bash
ls -l /nfs/beagleplay/
# Output: bin boot dev etc home lib media mnt proc run sbin sys tmp usr var
```

**Fix permissions:**
```bash
sudo chown -R root:root /nfs/beagleplay
```

### 3.5 Configure Network Interface

**Find your Ethernet interface:**
```bash
ip link show
```

**Output (example):**
```
1: lo: <LOOPBACK,UP,LOWER_UP> ...
2: wlp2s0: <BROADCAST,MULTICAST,UP,LOWER_UP> ...  # WiFi
3: enp0s25: <BROADCAST,MULTICAST> ...              # Wired Ethernet (DOWN)
4: enx00e04c534458: <NO-CARRIER,BROADCAST,MULTICAST,UP> ... # USB Ethernet
```

**Your wired interface is likely `enp0s25` or `enx...`**

**Configure static IP using NetworkManager CLI:**
```bash
nmcli con add type ethernet \
    ifname enp0s25 \
    con-name beagleplay-eth \
    ip4 192.168.0.1/24
```

**Activate connection:**
```bash
nmcli con up beagleplay-eth
```

**Verify IP:**
```bash
ip addr show enp0s25
# Should show: inet 192.168.0.1/24 ...
```

**Alternative: Manual configuration (if nmcli fails):**
```bash
sudo ip addr add 192.168.0.1/24 dev enp0s25
sudo ip link set enp0s25 up
```

---

## 4. Configuring BeaglePlay for NFS Boot

### 4.1 Update SD Card Boot Configuration

**Mount SD card boot partition:**
```bash
# Insert SD card, check device name
lsblk
# Assuming /dev/sdb1 is boot partition
sudo mount /dev/sdb1 /mnt
```

**Edit extlinux.conf:**
```bash
sudo nano /mnt/extlinux/extlinux.conf
```

**Original:**
```
LABEL Linux
  KERNEL /Image
  FDT /k3-am625-beagleplay.dtb
  APPEND root=/dev/mmcblk0p2 rootwait rw console=ttyS2,115200n8
```

**Modified for NFS:**
```
LABEL Linux
  KERNEL /Image
  FDT /k3-am625-beagleplay.dtb
  APPEND root=/dev/nfs rw console=ttyS2,115200n8 nfsroot=192.168.0.1:/nfs/beagleplay,nfsvers=3,tcp ip=192.168.0.100:::::eth0
```

**Kernel command line breakdown:**
- `root=/dev/nfs`: Use NFS instead of local partition
- `nfsroot=192.168.0.1:/nfs/beagleplay,nfsvers=3,tcp`: NFS server and options
- `ip=192.168.0.100:::::eth0`: Static IP (format: `client-ip:server-ip:gw-ip:netmask:hostname:device:autoconf`)
- `console=ttyS2,115200n8`: Serial console

**Save and unmount:**
```bash
sudo sync
sudo umount /mnt
```

### 4.2 Connect Hardware

**Physical setup:**
1. Connect Ethernet cable: BeaglePlay ↔ Workstation (or switch)
2. Insert SD card into BeaglePlay
3. Connect serial console
4. Power on BeaglePlay

### 4.3 Verify NFS Boot

**Open serial console:**
```bash
picocom -b 115200 /dev/ttyUSB0
```

**You should see during boot:**
```
[    2.456789] IP-Config: Complete:
[    2.456790]      device=eth0, hwaddr=xx:xx:xx:xx:xx:xx, ipaddr=192.168.0.100
[    2.789012] VFS: Mounted root (nfs filesystem) on device 0:18.
```

**Verify NFS mount:**
```bash
# At BeaglePlay shell
mount | grep nfs
# Output: 192.168.0.1:/nfs/beagleplay on / type nfs (rw,relatime,vers=3,...)
```

**Test read-write access:**
```bash
touch /home/test-nfs-write
ls -l /home/
```

**On workstation, verify file appeared:**
```bash
ls -l /nfs/beagleplay/home/
# Should show test-nfs-write
```

---

## 5. Rapid Development Workflow

### 5.1 Modify Rootfs Without Rebuild

**Example: Add a test script**

On workstation:
```bash
cat > /nfs/beagleplay/usr/bin/hello-beagleplay << 'EOF'
#!/bin/sh
echo "Hello from BeaglePlay!"
echo "IP: $(ip addr show eth0 | grep inet | awk '{print $2}')"
echo "Uptime: $(uptime)"
EOF

chmod +x /nfs/beagleplay/usr/bin/hello-beagleplay
```

On BeaglePlay (reboot or just sync):
```bash
hello-beagleplay
```

**Output:**
```
Hello from BeaglePlay!
IP: 192.168.0.100/24
Uptime: 14:32:45 up 3 min, load average: 0.12, 0.08, 0.03
```

**No rebuild, no reflash - instant!**

### 5.2 Test Package Changes

**After rebuilding with new packages:**
```bash
cd ~/yocto-labs/build/tmp/deploy/images/beagleplay
sudo rm -rf /nfs/beagleplay/*
sudo tar -xf core-image-minimal-beagleplay.rootfs.tar.xz -C /nfs/beagleplay
sudo chown -R root:root /nfs/beagleplay
```

**Reboot BeaglePlay:**
```bash
# On BeaglePlay console
reboot
```

New packages available in ~30 seconds.

### 5.3 Debugging with NFS Root

**Install gdbserver in image:**
```bash
# Edit local.conf
IMAGE_INSTALL:append = " gdbserver"
bitbake core-image-minimal
```

**Extract to NFS, reboot BeaglePlay**

**Cross-compile test program on host:**
```bash
source ~/yocto-labs/poky/oe-init-build-env
bitbake core-image-minimal -c populate_sdk
```

Wait for SDK build, then install:
```bash
cd ~/yocto-labs/build/tmp/deploy/sdk
./poky-glibc-x86_64-core-image-minimal-cortexa53-beagleplay-toolchain-5.0.4.sh
# Install to: /opt/poky/5.0.4
```

**Write test program:**
```bash
cat > /tmp/test.c << 'EOF'
#include <stdio.h>
int main() {
    for (int i = 0; i < 10; i++) {
        printf("Count: %d\n", i);
    }
    return 0;
}
EOF
```

**Cross-compile:**
```bash
source /opt/poky/5.0.4/environment-setup-cortexa53-poky-linux
$CC -g /tmp/test.c -o /nfs/beagleplay/tmp/test
```

**Run on BeaglePlay with gdbserver:**
```bash
gdbserver :2345 /tmp/test
```

**Debug from host:**
```bash
$GDB /nfs/beagleplay/tmp/test
(gdb) target remote 192.168.0.100:2345
(gdb) break main
(gdb) continue
```

---

## 6. Preferred Package Providers

### 6.1 Understanding Virtual Packages

**Virtual packages** represent functionality, not specific implementations.

**Examples:**
- `virtual/kernel`: Provided by `linux-ti-staging`, `linux-yocto`, `linux-mainline`, etc.
- `virtual/bootloader`: Provided by `u-boot`, `barebox`, etc.
- `virtual/libc`: Provided by `glibc`, `musl`, `uclibc-ng`

**Check current provider:**
```bash
bitbake -vn virtual/kernel
```

**Output:**
```
NOTE: selecting linux-ti-staging to satisfy virtual/kernel due to PREFERRED_PROVIDERS
```

### 6.2 Change Preferred Provider

**Switch kernel provider in local.conf:**
```bash
nano conf/local.conf
```

**Add:**
```
PREFERRED_PROVIDER_virtual/kernel = "linux-yocto"
```

**Verify change:**
```bash
bitbake -vn virtual/kernel
# Output: NOTE: selecting linux-yocto to satisfy virtual/kernel due to PREFERRED_PROVIDERS
```

**For BeaglePlay, stick with `linux-ti-staging`** (TI-optimized kernel).

### 6.3 Version Preferences

**Pin specific version:**
```
PREFERRED_VERSION_linux-ti-staging = "6.1%"
```

**Check available versions:**
```bash
bitbake-layers show-recipes linux-ti-staging
```

**Output:**
```
linux-ti-staging:
  meta-ti-bsp        6.1.83+gitAUTOINC+abcdef1234
  meta-ti-bsp        6.6.32+gitAUTOINC+987654fedc
```

---

## 7. BitBake Deep Dive

### 7.1 Task Execution Model

**Every recipe has tasks:**
```
do_fetch       → Download sources
do_unpack      → Extract archives
do_patch       → Apply patches
do_configure   → Run ./configure or cmake
do_compile     → Build the software
do_install     → Install to staging area
do_package     → Create binary packages (RPM/DEB/IPK)
do_package_write_* → Write package files
do_populate_sysroot → Install to sysroot for other recipes
```

**List all tasks for a recipe:**
```bash
bitbake -c listtasks virtual/kernel
```

**Output:**
```
do_build
do_fetch
do_unpack
do_patch
do_configure
do_menuconfig  # Special: interactive kernel config
do_compile
do_install
...
```

### 7.2 Execute Specific Tasks

**Configure kernel interactively:**
```bash
bitbake -c menuconfig virtual/kernel
```

**Opens kernel menuconfig in terminal.**

**Save config, then rebuild:**
```bash
bitbake -c compile -f virtual/kernel  # Force recompile
bitbake core-image-minimal            # Rebuild image with new kernel
```

**Other useful task commands:**
```bash
# Clean package (remove outputs but keep downloads)
bitbake -c clean <package>

# Clean shared state
bitbake -c cleansstate <package>

# Clean everything including downloads
bitbake -c cleanall <package>

# Fetch all sources without building
bitbake --runall=fetch core-image-minimal
```

### 7.3 Dependency Graphing

**Generate task dependency graph:**
```bash
bitbake -g core-image-minimal
```

**Creates files:**
- `pn-buildlist`: List of recipes to build
- `task-depends.dot`: Task-level dependencies (massive)
- `pn-depends.dot`: Recipe-level dependencies

**View recipe dependencies visually:**
```bash
sudo apt install graphviz
dot -Tpng pn-depends.dot -o pn-depends.png
xdg-open pn-depends.png
```

**Filter to specific package:**
```bash
bitbake -g dropbear
dot -Tpng pn-depends.dot -o dropbear-deps.png
```

### 7.4 Dry Run Analysis

**Show what would be built without building:**
```bash
bitbake -vn core-image-minimal
```

**Useful for:**
- Verifying `PREFERRED_PROVIDER` changes
- Checking if changes trigger rebuilds
- Debugging recipe selection issues

---

## 8. Performance Optimization

### 8.1 Parallel Build Tuning

**Edit local.conf:**
```bash
nano conf/local.conf
```

**Add (adjust based on your CPU):**
```
# Number of BitBake tasks to run in parallel
BB_NUMBER_THREADS = "8"

# Number of make jobs per package (-j flag)
PARALLEL_MAKE = "-j 8"

# Limit parallel tasks for specific packages (memory-intensive builds)
PARALLEL_MAKE:pn-gcc = "-j 4"
PARALLEL_MAKE:pn-llvm = "-j 4"
```

**Guidelines:**
- `BB_NUMBER_THREADS`: Number of CPU cores
- `PARALLEL_MAKE`: 1.5× to 2× CPU cores (if enough RAM)
- Monitor with `htop` - adjust if thrashing

### 8.2 Shared State Cache

**Shared state (sstate-cache)** stores intermediate build results.

**Benefits:**
- Rebuild from cache instead of source
- Share between build directories
- Dramatically speeds up CI/CD

**Configure shared cache:**
```
# In local.conf
SSTATE_DIR = "/opt/yocto-shared/sstate-cache"
```

**Create directory:**
```bash
sudo mkdir -p /opt/yocto-shared/sstate-cache
sudo chown -R $USER:$USER /opt/yocto-shared
```

### 8.3 Download Directory

**Share downloads between projects:**
```
# In local.conf
DL_DIR = "/opt/yocto-shared/downloads"
```

**Create directory:**
```bash
sudo mkdir -p /opt/yocto-shared/downloads
sudo chown -R $USER:$USER /opt/yocto-shared
```

**Saves bandwidth and time - sources downloaded once, reused forever.**

### 8.4 Remove Work Directories

**Clean intermediate files to save disk:**
```
# In local.conf
INHERIT += "rm_work"

# Exclude packages you might debug
RM_WORK_EXCLUDE += "linux-ti-staging u-boot-ti-staging"
```

**Saves 30-50GB** but slows rebuilds (can't resume from intermediate steps).

### 8.5 Use Buildhistory

**Track what changed between builds:**
```
# In local.conf
INHERIT += "buildhistory"
BUILDHISTORY_COMMIT = "1"
```

**Creates Git repository tracking:**
- Package versions
- Installed files
- Image sizes
- Dependency changes

**View history:**
```bash
cd ~/yocto-labs/build/buildhistory
git log --oneline
git diff HEAD~1 HEAD
```

---

## 9. Network Boot with TFTP

### 9.1 Install TFTP Server

```bash
sudo apt install tftpd-hpa
```

**Configure:**
```bash
sudo nano /etc/default/tftpd-hpa
```

**Content:**
```
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/srv/tftp"
TFTP_ADDRESS=":69"
TFTP_OPTIONS="--secure"
```

**Create directory:**
```bash
sudo mkdir -p /srv/tftp
sudo chown -R tftp:tftp /srv/tftp
sudo chmod 755 /srv/tftp
```

**Restart service:**
```bash
sudo systemctl restart tftpd-hpa
sudo systemctl status tftpd-hpa
```

### 9.2 Copy Kernel and Device Tree

```bash
cd ~/yocto-labs/build/tmp/deploy/images/beagleplay

# Copy kernel
sudo cp Image /srv/tftp/

# Copy Device Tree
sudo cp k3-am625-beagleplay.dtb /srv/tftp/

# Set permissions
sudo chmod 644 /srv/tftp/*
```

### 9.3 Configure U-Boot for TFTP

**Boot BeaglePlay, stop at U-Boot prompt (press space during countdown).**

**Set network parameters:**
```
setenv ipaddr 192.168.0.100
setenv serverip 192.168.0.1
setenv gatewayip 192.168.0.1
```

**Set boot command:**
```
setenv bootcmd 'tftp ${loadaddr} Image; tftp ${fdtaddr} k3-am625-beagleplay.dtb; booti ${loadaddr} - ${fdtaddr}'
```

**Set kernel arguments:**
```
setenv bootargs 'root=/dev/nfs rw console=ttyS2,115200n8 nfsroot=192.168.0.1:/nfs/beagleplay,nfsvers=3,tcp ip=192.168.0.100:::::eth0'
```

**Save and boot:**
```
saveenv
boot
```

**Now BeaglePlay boots:**
1. Bootloader from SD card
2. Kernel via TFTP
3. Rootfs via NFS

**Ultimate development setup:**
- Kernel changes: Copy to `/srv/tftp/`, reboot
- Rootfs changes: Edit in `/nfs/beagleplay/`, reboot or sync
- No SD card reflashing ever

---

## 10. Package Management

### 10.1 Image Package Formats

**Yocto supports three package formats:**
- **RPM**: Red Hat Package Manager (default for Fedora-based)
- **DEB**: Debian packages (default for Debian/Ubuntu-based)
- **IPK**: Itsy Package Management (default for embedded, used by opkg)

**Set package format:**
```
# In local.conf
PACKAGE_CLASSES = "package_ipk"
```

**For BeaglePlay, IPK is recommended** (lightweight).

### 10.2 Runtime Package Management

**Enable package management on target:**
```
# In local.conf
EXTRA_IMAGE_FEATURES += "package-management"
```

**This adds `opkg` to the image.**

**Rebuild:**
```bash
bitbake core-image-minimal
```

**On BeaglePlay:**
```bash
opkg update
opkg list
opkg install htop
```

**Host package feed:**
```bash
cd ~/yocto-labs/build/tmp/deploy/ipk/
python3 -m http.server 8000
```

**Configure opkg on target:**
```bash
# On BeaglePlay
cat > /etc/opkg/base-feeds.conf << EOF
src/gz all http://192.168.0.1:8000/all
src/gz cortexa53 http://192.168.0.1:8000/cortexa53
src/gz beagleplay http://192.168.0.1:8000/beagleplay
EOF

opkg update
opkg install strace
```

### 10.3 Package Inspection

**List package contents:**
```bash
opkg files busybox
```

**Show package info:**
```bash
opkg info dropbear
```

**Search for files:**
```bash
opkg search /usr/bin/ssh
```

---

## 11. Troubleshooting

### 11.1 NFS Boot Issues

**Problem:** `VFS: Unable to mount root fs via NFS`

**Solutions:**
```bash
# On workstation: verify NFS export
sudo exportfs -v

# Verify network connectivity (ping from U-Boot)
ping 192.168.0.1

# Check kernel NFS support
zcat /proc/config.gz | grep NFS
# Should show: CONFIG_NFS_FS=y, CONFIG_ROOT_NFS=y
```

---

**Problem:** NFS mount succeeds but rootfs is empty

**Solution:**
```bash
# Check extraction
ls -la /nfs/beagleplay/
# Should contain bin/, etc/, usr/, not just empty directories

# Re-extract
sudo rm -rf /nfs/beagleplay/*
sudo tar -xpf ~/yocto-labs/build/tmp/deploy/images/beagleplay/core-image-minimal-beagleplay.rootfs.tar.xz -C /nfs/beagleplay
```

---

**Problem:** Permission denied errors on NFS

**Solution:**
```bash
# Fix ownership
sudo chown -R root:root /nfs/beagleplay

# Check exports has no_root_squash
sudo cat /etc/exports
# Should have: /nfs/beagleplay *(rw,sync,no_root_squash,no_subtree_check)
```

### 11.2 TFTP Boot Issues

**Problem:** `TFTP error: file not found`

**Solutions:**
```bash
# Verify TFTP server running
sudo systemctl status tftpd-hpa

# Check file permissions
ls -l /srv/tftp/Image
# Should be readable by all (644)

# Test from command line
tftp 192.168.0.1
tftp> get Image
tftp> quit
```

---

**Problem:** TFTP timeout

**Solutions:**
```bash
# Check firewall
sudo ufw status
sudo ufw allow 69/udp

# Verify server IP
ip addr show

# Test with tcpdump
sudo tcpdump -i enp0s25 port 69
# Boot BeaglePlay and watch for TFTP requests
```

### 11.3 BitBake Issues

**Problem:** `ERROR: Nothing PROVIDES 'package-name'`

**Solution:**
```bash
# Search for package
bitbake-layers show-recipes | grep package-name

# If not found, add layer containing it
bitbake-layers show-layers
# Check which layers have the package on layers.openembedded.org
```

---

**Problem:** Build fails with "No space left on device"

**Solution:**
```bash
# Check disk space
df -h ~/yocto-labs/build/tmp

# Clean up
bitbake -c cleansstate core-image-minimal
rm -rf ~/yocto-labs/build/tmp/work/*

# Or enable rm_work in local.conf
```

---

**Problem:** `ERROR: Multiple .bb files are due to be built which each provide <package>`

**Solution:**
```bash
# Multiple recipes provide same package
# Use PREFERRED_PROVIDER
nano conf/local.conf

# Add:
PREFERRED_PROVIDER_<package> = "recipe-name"
```

---

## 12. Going Further

### 12.1 Advanced IMAGE_INSTALL Techniques

**Conditional package inclusion:**
```
IMAGE_INSTALL:append:beagleplay = " ti-utils"
IMAGE_INSTALL:append:qemux86-64 = " qemu-guest-agent"
```

**Feature-based inclusion:**
```
EXTRA_IMAGE_FEATURES += "debug-tweaks ssh-server-dropbear"
```

**Package groups:**
```
IMAGE_INSTALL:append = " \
    packagegroup-core-full-cmdline \
    packagegroup-core-buildessential \
"
```

### 12.2 Create Custom Package Group

**Create recipe `recipes-core/packagegroups/packagegroup-beagleplay-dev.bb`:**
```
DESCRIPTION = "Development tools for BeaglePlay"
LICENSE = "MIT"

inherit packagegroup

RDEPENDS:${PN} = " \
    htop \
    strace \
    gdbserver \
    i2c-tools \
    can-utils \
    mtd-utils \
"
```

**Use in image:**
```
IMAGE_INSTALL:append = " packagegroup-beagleplay-dev"
```

### 12.3 License Compliance

**Generate license manifest:**
```
# In local.conf
INHERIT += "archiver"
COPYLEFT_LICENSE_INCLUDE = "*"
ARCHIVER_MODE[src] = "original"
```

**Rebuild:**
```bash
bitbake core-image-minimal
```

**License files in:**
```
tmp/deploy/licenses/core-image-minimal-beagleplay-*/
```

---

## 13. Key Takeaways

**What You Accomplished:**
1. ✅ Mastered BitBake configuration hierarchy
2. ✅ Customized image with `IMAGE_INSTALL`
3. ✅ Set up NFS root filesystem for rapid development
4. ✅ Configured TFTP boot for kernel iteration
5. ✅ Understood BitBake task execution model
6. ✅ Optimized build performance

**Advanced Skills Gained:**
- Package provider selection
- Network boot workflows
- BitBake command-line tools
- Performance tuning
- Package management on target

**Development Workflow Established:**
```
Edit code → Build → Extract to NFS → Reboot (30 seconds)
```

**Next Steps:**
- **Lab 12**: Add custom applications with recipes
- **Lab 13**: Create custom Yocto layers
- **Lab 14**: Extend recipes with bbappend
- **Lab 15**: Define custom machine configurations

---

## 14. Verification Checklist

**Before proceeding to Lab 12, verify:**

- [ ] `IMAGE_INSTALL` customization works (packages added)
- [ ] NFS server running and exporting `/nfs/beagleplay`
- [ ] BeaglePlay boots with NFS root successfully
- [ ] Network configured (192.168.0.1 host, 192.168.0.100 target)
- [ ] TFTP server operational (optional but recommended)
- [ ] Can modify rootfs and see changes on target without rebuild
- [ ] `bitbake -c menuconfig virtual/kernel` works
- [ ] Shared state cache configured for faster rebuilds
- [ ] Build completes in <15 minutes for incremental changes

**Build time:** ~10 minutes incremental, ~2 hours full rebuild  
**Development cycle:** <1 minute (edit → sync → reboot)  
**Success criteria:** Working NFS boot with custom packages

---

## 15. Additional Resources

**BitBake Documentation:**
- User Manual: https://docs.yoctoproject.org/bitbake/
- Variable Glossary: https://docs.yoctoproject.org/ref-manual/variables.html
- Task Manual: https://docs.yoctoproject.org/overview-manual/concepts.html#tasks

**Yocto Configuration:**
- Dev Manual - Customizing Images: https://docs.yoctoproject.org/dev-manual/customizing-images.html
- Mega Manual (searchable): https://docs.yoctoproject.org/singleindex.html

**Network Boot:**
- Linux NFS Root: https://www.kernel.org/doc/Documentation/filesystems/nfs/nfsroot.txt
- U-Boot TFTP: https://docs.u-boot.org/en/latest/usage/cmd/tftp.html

---

**End of Lab 11**

*The Guide rates this lab: **Mostly Harmless** ⭐⭐⭐⭐*

You now have an optimized Yocto development environment with network boot capabilities, enabling rapid iteration and efficient debugging. The next labs will teach you how to add your own applications and create reusable layers.
