# Lab 4: Linux Kernel for BeaglePlay

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about the Linux kernel:

*"The Linux kernel is the brain of your embedded system. Unlike certain galactic presidents, it's actually quite good at multitasking, managing hardware, and not generally causing chaos. Though both occasionally crash when faced with infinite improbability."*

## Learning Objectives

By the end of this lab, you will be able to:

- Clone and navigate the Linux kernel source tree
- Configure the kernel for ARM64 and BeaglePlay hardware
- Cross-compile the Linux kernel and Device Tree Blobs
- Load kernel and DTB via TFTP network boot
- Set up U-Boot to boot Linux
- Understand kernel boot arguments and console configuration
- Troubleshoot kernel boot issues

**Estimated Time:** 3-4 hours

**Prerequisites:**
- Completed Lab 1 (Custom Toolchain)
- Completed Lab 2 (Hardware Discovery)
- Completed Lab 3 (U-Boot Bootloader)
- Familiarity with git
- Basic understanding of kernel configuration

## Introduction

### Why Build Your Own Kernel?

The Linux kernel is the heart of your embedded system. While many projects use pre-built kernels, building your own gives you:

**Control**
- Enable/disable drivers for your specific hardware
- Optimize for size, performance, or power consumption
- Add custom patches or out-of-tree drivers

**Learning**
- Understand what's actually running on your hardware
- Debug kernel issues with symbols and source access
- Experiment with new kernel features

**Customization**
- Remove unnecessary features to reduce boot time
- Add security features (SELinux, AppArmor, etc.)
- Tune for real-time performance (PREEMPT_RT)

For BeaglePlay, we need a kernel that supports:
- TI AM62x SoC (K3 multicore architecture)
- ARM Cortex-A53 processors (ARMv8-A, 64-bit)
- BeaglePlay peripherals (Ethernet, mikroBUS, GPIO, etc.)
- Device Tree for hardware description

### What We'll Build

```
┌────────────────────────┐
│  Linux Kernel Sources  │ ← Clone from kernel.org
└───────────┬────────────┘
            │
            ▼
┌────────────────────────┐
│  Configuration         │ ← defconfig + menuconfig
│  (arm64 + K3 SoC)      │
└───────────┬────────────┘
            │
            ▼
┌────────────────────────┐
│  Cross-Compilation     │ ← aarch64-beagleplay-linux-musl-gcc
└───────────┬────────────┘
            │
            ▼
┌─────────────────────────────────────────┐
│  Output Files:                          │
│  - Image.gz (compressed kernel)         │
│  - k3-am625-beagleplay.dtb (Device Tree)│
└───────────┬─────────────────────────────┘
            │
            ▼
┌────────────────────────┐
│  U-Boot TFTP Boot      │ ← Network loading
│  - tftp Image.gz       │
│  - tftp DTB            │
│  - booti command       │
└────────────────────────┘
```

## Workspace Setup

Create kernel lab directory:

```bash
cd $HOME/embedded-labs
mkdir -p kernel
cd kernel
```

All kernel work happens here.

## Part 1: Getting the Kernel Sources

### Understanding Kernel Versions

The Linux kernel has two main development branches:

**Mainline (Linus Tree)**
- Latest development code
- Managed by Linus Torvalds
- New features, potentially less stable
- Repository: `https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux`

**Stable Releases**
- Long-term support versions
- Bug fixes and security patches
- More stable for production
- Repository: `https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux`

For this lab, we'll use **Linux 6.6.x** (LTS - Long Term Support).

### Clone the Kernel

**⚠️  WARNING (in large, friendly letters):** The kernel repository is **huge** (~3GB). This will take 15-30 minutes on a typical connection.

Clone Linus's mainline tree:

```bash
cd $HOME/embedded-labs/kernel
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux
cd linux
```

While it downloads, understand what you're getting:
- **50,000+** files
- **30+ million** lines of code
- **80,000+** git commits
- Drivers for thousands of devices

Check the current version:

```bash
make kernelversion
```

You'll see something like `6.12.0-rc5` (a release candidate from mainline).

### Add Stable Releases

The stable tree contains tested LTS versions. Add it as a remote:

```bash
git remote add stable https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux
git fetch stable
```

This fetches stable branches (another ~2GB download, but incremental).

List available stable branches:

```bash
git branch -r | grep stable
```

You'll see many branches:

```
stable/linux-4.19.y
stable/linux-5.4.y
stable/linux-5.10.y
stable/linux-5.15.y
stable/linux-6.1.y
stable/linux-6.6.y   ← We'll use this one
stable/linux-6.12.y
```

The `.y` suffix means "all patch releases" (e.g., 6.6.1, 6.6.2, 6.6.3...).

### Checkout Stable Version

Switch to Linux 6.6.x:

```bash
git checkout stable/linux-6.6.y
```

Verify the version:

```bash
make kernelversion
```

Should show something like `6.6.60` (exact patch version depends on when you ran this).

**Why 6.6?**
- LTS version (supported until December 2026)
- Excellent TI AM62x support
- Tested with BeaglePlay
- Good balance of features vs stability

## Part 2: Kernel Configuration

### Understanding Kernel Configuration

The kernel has **10,000+** configuration options! Examples:
- Which filesystems to support (ext4, FAT, NFS)
- Which drivers to include (Ethernet, USB, GPIO)
- Processor-specific optimizations
- Debug features

Configuration is managed by **Kconfig**, similar to U-Boot's system.

Three build options for each feature:
- **`y`** - Built into kernel image (always loaded)
- **`m`** - Built as loadable module (can be loaded at runtime)
- **`n`** - Not built (disabled)

### Set Cross-Compilation Environment

Tell the kernel build system we're cross-compiling:

```bash
export ARCH=arm64
export CROSS_COMPILE=aarch64-beagleplay-linux-musl-
```

**Important (like knowing where your towel is):** We use **arm64** (not aarch64) for the kernel!
- Kernel calls 64-bit ARM "arm64"
- Toolchains call it "aarch64"
- Both mean the same thing

Add to `~/.bashrc` for persistence:

```bash
echo 'export ARCH=arm64' >> ~/.bashrc
echo 'export CROSS_COMPILE=aarch64-beagleplay-linux-musl-' >> ~/.bashrc
```

Verify toolchain is in PATH:

```bash
${CROSS_COMPILE}gcc --version
```

Should show:

```
aarch64-beagleplay-linux-musl-gcc (GCC) 13.2.0
```

### Find Default Configuration

List available default configurations for arm64:

```bash
make help | grep defconfig
```

Or see all arm64 defconfigs:

```bash
ls -1 arch/arm64/configs/
```

Output:

```
defconfig  ← This is the one we want!
```

Unlike some architectures, ARM64 has a single unified `defconfig` that supports many boards through Device Tree.

### Load Base Configuration

Load the ARM64 default configuration:

```bash
make defconfig
```

This creates `.config` in the kernel source directory with ~8,000 configuration options.

Inspect the config file (optional):

```bash
head -50 .config
```

You'll see lines like:

```
CONFIG_ARM64=y
CONFIG_64BIT=y
CONFIG_ARCH_K3=y
...
```

### Customize Configuration

Now fine-tune the config with menuconfig:

```bash
make menuconfig
```

This opens a text-based UI. Navigate with:
- **Arrow keys** - Move around
- **Enter** - Select submenu
- **Space** - Toggle option (y/m/n)
- **/** - Search for config option
- **?** - Help on current option
- **Save** - Write .config
- **Exit** - Go back or quit

**Recommended Changes:**

**1. Disable GCC Plugins (avoid build dependencies)**

Navigate to:
```
Kernel hacking →
  Compile-time checks and compiler options →
    [ ] GCC plugins
```

Press Space to disable (no asterisk).

**2. Optimize for BeaglePlay (reduce kernel size)**

Navigate to:
```
Platform selection →
```

You'll see options for:
- `[ ]` Actions Semi Platforms
- `[ ]` NVIDIA Tegra SoC Family  
- `[*]` Texas Instruments Inc. K3 multicore SoC architecture ← Keep ONLY this!
- `[ ]` ARMv8 software model (Versatile Express)
- Many more...

**Disable everything except "Texas Instruments Inc. K3"** - this removes support for hundreds of boards we don't need.

**3. Disable Display Drivers (not needed for initial testing)**

Navigate to:
```
Device Drivers →
  Graphics support →
    [ ] Direct Rendering Manager (XFree86 4.1.0 and higher DRI support)
```

Disable this whole section - saves ~50MB in kernel size!

**4. Enable Networking Features (for TFTP and NFS)**

Navigate to:
```
Device Drivers →
  Network device support →
    Ethernet driver support →
      [*] Texas Instruments (TI) devices
        <*> TI K3 AM65 CPSW Ethernet driver
```

Make sure this is enabled (built-in, not module) - we need it for network boot!

**Optional Configuration Changes:**

Search (`/`) for these and verify they're enabled:
- `CONFIG_NFS_FS` - NFS client (for root filesystem over network later)
- `CONFIG_IP_PNP` - IP autoconfiguration (simplifies network boot)
- `CONFIG_ROOT_NFS` - Root filesystem over NFS
- `CONFIG_DEVTMPFS_MOUNT` - Auto-mount /dev (needed for init)

Save configuration and exit menuconfig.

### Verify Configuration

Check that key options are set:

```bash
grep -E "CONFIG_ARCH_K3|CONFIG_NFS_FS|CONFIG_DEVTMPFS_MOUNT" .config
```

Should show:

```
CONFIG_ARCH_K3=y
CONFIG_NFS_FS=y
CONFIG_DEVTMPFS_MOUNT=y
```

## Part 3: Cross-Compiling the Kernel

### Install Build Dependencies

The kernel build needs several development packages:

```bash
sudo apt install build-essential libssl-dev libelf-dev flex bison
```

What these provide:
- **build-essential** - GCC, make, etc. (for host tools)
- **libssl-dev** - Cryptographic signing of kernel modules
- **libelf-dev** - ELF binary parsing (for objtool)
- **flex** - Lexical analyzer (for config parsers)
- **bison** - Parser generator (for config parsers)

### Compile the Kernel

Now build it!

```bash
make -j$(nproc)
```

**What happens during the build:**

1. **Host tools compilation** (~30 seconds)
   - Builds scripts and utilities needed for kernel build
   
2. **Kernel compilation** (~10-20 minutes on 4-core machine)
   - Compiles ~8,000 .c files
   - Links into vmlinux (uncompressed kernel)
   
3. **Image creation** (~30 seconds)
   - Compresses vmlinux → Image.gz
   
4. **Device Tree compilation** (~10 seconds)
   - Compiles .dts files → .dtb blobs
   
5. **Module compilation** (if any modules enabled)

Total time: **10-25 minutes** depending on CPU.

**Progress output** looks like:

```
  CC      init/main.o
  CC      init/version.o
  CC      init/do_mounts.o
  ...
  LD      vmlinux
  OBJCOPY arch/arm64/boot/Image
  GZIP    arch/arm64/boot/Image.gz
  DTC     arch/arm64/boot/dts/ti/k3-am625-beagleplay.dtb
```

### Verify Build Output

Check what was produced:

```bash
ls -lh arch/arm64/boot/
```

You should see:

```
-rw-r--r-- 1 you you  22M Image          ← Uncompressed kernel
-rw-r--r-- 1 you you 9.8M Image.gz       ← Compressed kernel (use this!)
drwxr-xr-x 8 you you 4.0K dts            ← Device Tree sources
```

The **Image.gz** is our bootable kernel - compressed from 22MB to 9.8MB!

### Find the Device Tree Blob

Device Trees are in subdirectories by vendor:

```bash
ls arch/arm64/boot/dts/ti/*.dtb | grep beagleplay
```

Output:

```
arch/arm64/boot/dts/ti/k3-am625-beagleplay.dtb
```

This is our **Device Tree Blob (DTB)** for BeaglePlay!

Inspect its size:

```bash
ls -lh arch/arm64/boot/dts/ti/k3-am625-beagleplay.dtb
```

Should be around **200-250KB**.

### Understanding Build Artifacts

| File | Purpose | Size | Use |
|------|---------|------|-----|
| **vmlinux** | Uncompressed kernel ELF | ~150MB | Debugging with symbols |
| **Image** | Raw uncompressed kernel binary | ~22MB | Direct boot (no compression) |
| **Image.gz** | Gzip compressed kernel | ~10MB | **← Use this for boot!** |
| **k3-am625-beagleplay.dtb** | Device Tree Blob | ~250KB | Hardware description |

We'll use **Image.gz** and **k3-am625-beagleplay.dtb** for booting.

## Part 4: Network Boot Setup

Before we can boot the kernel, we need to set up TFTP for network loading.

### Configure U-Boot Networking

Power on BeaglePlay, hold USR button, stop at U-Boot prompt.

Set IP addresses in U-Boot:

```
=> setenv ipaddr 192.168.1.100
=> setenv serverip 192.168.1.1
=> saveenv
```

**Adjust these IPs for your network!** The board (ipaddr) and your PC (serverip) must be on the same subnet.

Verify the settings:

```
=> printenv ipaddr serverip
```

### Configure PC Network Interface

Find your Ethernet interface connected to BeaglePlay:

```bash
ip a
```

Look for the interface that appears when you plug in the Ethernet cable. It might be named:
- `enp0s31f6` (PCIe Ethernet)
- `enx...` (USB Ethernet adapter)
- `eth0` (older naming)

**Method 1: Using NetworkManager CLI (recommended)**

```bash
sudo nmcli con add type ethernet ifname YOUR_INTERFACE ip4 192.168.1.1/24
```

Replace `YOUR_INTERFACE` with your actual interface name.

**Method 2: Manual configuration (if NetworkManager not available)**

```bash
sudo ip addr add 192.168.1.1/24 dev YOUR_INTERFACE
sudo ip link set YOUR_INTERFACE up
```

Verify the configuration:

```bash
ip addr show YOUR_INTERFACE
```

Should show:

```
inet 192.168.1.1/24 scope global YOUR_INTERFACE
```

### Install TFTP Server

Install `tftpd-hpa`:

```bash
sudo apt install tftpd-hpa
```

Check the TFTP server configuration:

```bash
cat /etc/default/tftpd-hpa
```

Should show:

```
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/srv/tftp"
TFTP_ADDRESS=":69"
TFTP_OPTIONS="--secure"
```

The default TFTP directory is `/srv/tftp`.

### Prepare TFTP Directory

Create and set permissions:

```bash
sudo mkdir -p /srv/tftp
sudo chown -R $USER:$USER /srv/tftp
```

Restart TFTP server:

```bash
sudo systemctl restart tftpd-hpa
sudo systemctl status tftpd-hpa
```

Should show "active (running)".

### Test TFTP Connection

Create a test file:

```bash
echo "TFTP test from BeaglePlay" > /srv/tftp/test.txt
```

From U-Boot on BeaglePlay:

```
=> tftp 0x82000000 test.txt
```

Expected output:

```
Using ethernet@8000000 port@1 device
TFTP from server 192.168.1.1; our IP address is 192.168.1.100
Filename 'test.txt'.
Load address: 0x82000000
Loading: #
         5.9 KiB/s
done
Bytes transferred = 28 (1c hex)
```

Success! TFTP is working.

Verify the data was downloaded:

```
=> md 0x82000000
```

Should show the test file content.

### Troubleshooting TFTP

**Problem:** `TFTP error: 'Access violation'`

**Cause:** File permissions or wrong directory

**Solution:**

```bash
sudo chmod -R 755 /srv/tftp
sudo chown -R tftp:tftp /srv/tftp
```

**Problem:** `TFTP timeout`

**Cause:** Firewall blocking TFTP port 69

**Solution:**

```bash
sudo ufw allow from 192.168.1.100 to any port 69 proto udp
```

Or temporarily disable firewall:

```bash
sudo ufw disable
```

**Problem:** `T T T T` (continuous timeouts)

**Cause:** Network cable not connected or wrong interface configured

**Solution:**
- Check Ethernet cable is firmly connected
- Verify PC interface has correct IP: `ip addr`
- Try different network cable

## Part 5: Booting the Kernel

### Copy Kernel Files to TFTP

```bash
cp $HOME/embedded-labs/kernel/linux/arch/arm64/boot/Image.gz /srv/tftp/
cp $HOME/embedded-labs/kernel/linux/arch/arm64/boot/dts/ti/k3-am625-beagleplay.dtb /srv/tftp/
```

Verify files are present:

```bash
ls -lh /srv/tftp/
```

Should show:

```
-rw-r--r-- 1 you you  28 test.txt
-rw-r--r-- 1 you you 9.8M Image.gz
-rw-r--r-- 1 you you 236K k3-am625-beagleplay.dtb
```

### Configure Kernel Boot Arguments

From U-Boot, set the kernel command line:

```
=> setenv bootargs console=ttyS2,115200n8
=> saveenv
```

**Bootargs explanation:**
- **console=ttyS2** - Use serial port 2 for console output
- **115200n8** - Baud rate 115200, no parity, 8 data bits

This tells the kernel where to send console messages.

### Load Kernel via TFTP

Load the compressed kernel image:

```
=> tftp 0x82000000 Image.gz
```

Expected output:

```
Using ethernet@8000000 port@1 device
TFTP from server 192.168.1.1; our IP address is 192.168.1.100
Filename 'Image.gz'.
Load address: 0x82000000
Loading: ########################### ... ###
         9.1 MiB/s
done
Bytes transferred = 10281472 (9ce300 hex)
```

Note the hex size - we'll need this in the next step.

### Load Device Tree via TFTP

```
=> tftp 0x88000000 k3-am625-beagleplay.dtb
```

Different address (0x88000000) to avoid overwriting the kernel!

Expected output:

```
Bytes transferred = 241664 (3b000 hex)
```

### Understanding Decompression Requirements

Try to boot:

```
=> booti 0x82000000 - 0x88000000
```

You'll get an error:

```
kernel_comp_addr_r or kernel_comp_size is not provided!
```

**What's happening:**
- `Image.gz` is compressed (9.8MB)
- Before booting, U-Boot must decompress it
- Decompressed size is ~22MB
- U-Boot needs to know where to put the decompressed image and its maximum size

Set decompression parameters:

```
=> setenv kernel_comp_addr_r 0x90000000
=> setenv kernel_comp_size 0x2000000
```

Parameters explained:
- **kernel_comp_addr_r** - RAM address for decompressed kernel (1.5GB offset)
- **kernel_comp_size** - Max decompressed size (32MB = 0x2000000)

Why 32MB? Our uncompressed Image is 22MB, so 32MB gives a safe margin.

Save these settings:

```
=> saveenv
```

### Boot the Kernel

Now try again:

```
=> booti 0x82000000 - 0x88000000
```

**Success!** You should see:

```
## Flattened Device Tree blob at 88000000
   Booting using the fdt blob at 0x88000000
Working FDT set to 88000000
   Uncompressing Kernel Image to 90000000
   Loading Device Tree to 000000009f7f5000, end 000000009f7ff3bf ... OK
Working FDT set to 9f7f5000

Starting kernel ...

[    0.000000] Booting Linux on physical CPU 0x0000000000 [0x410fd034]
[    0.000000] Linux version 6.6.60 (you@hostname) (aarch64-beagleplay-linux-musl-gcc (GCC) 13.2.0, GNU ld (GNU Binutils) 2.41) #1 SMP PREEMPT Wed Jan 15 16:45:12 UTC 2025
[    0.000000] Machine model: BeagleBoard.org BeaglePlay
[    0.000000] efi: UEFI not found.
[    0.000000] Reserved memory: created DMA memory pool at 0x000000009c800000, size 3 MiB
[    0.000000] OF: reserved mem: initialized node r5f-dma-memory@9c800000, compatible id shared-dma-pool
...
[    0.847623] ti-sci 44043000.system-controller: ABI: 3.1 (firmware rev 0x0009 '9.1.8--v09.01.08 (Kool Koala)')
...
[    2.156842] am65-cpsw-nuss 8000000.ethernet: initialized cpsw ale version 1.5
[    2.163789] am65-cpsw-nuss 8000000.ethernet: ALE Table size 512
...
```

The kernel will boot and eventually panic:

```
[    5.234567] Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)
```

**This is expected!** We haven't provided a root filesystem yet. The kernel successfully booted - it just has nowhere to find `/sbin/init`.

### Analyzing the Boot Messages

Let's understand what happened:

**Initial Boot:**
```
[    0.000000] Booting Linux on physical CPU 0x0000000000 [0x410fd034]
```
- CPU ID 0x410fd034 = ARM Cortex-A53
- Physical CPU 0 (first of four A53 cores)

**Kernel Version:**
```
[    0.000000] Linux version 6.6.60 (you@hostname) (aarch64-beagleplay-linux-musl-gcc...)
```
- Confirms we're running our custom-built kernel
- Built with our Musl toolchain!

**Hardware Detection:**
```
[    0.000000] Machine model: BeagleBoard.org BeaglePlay
```
- Device Tree correctly identified the board

**TI System Firmware:**
```
[    0.847623] ti-sci 44043000.system-controller: ABI: 3.1 (firmware rev 0x0009 '9.1.8--v09.01.08 (Kool Koala)')
```
- Communication with TIFS firmware working
- Same "Kool Koala" version we saw in U-Boot

**Ethernet:**
```
[    2.156842] am65-cpsw-nuss 8000000.ethernet: initialized cpsw ale version 1.5
```
- Ethernet controller initialized (we'll use this for NFS root later)

**Expected Panic:**
```
[    5.234567] Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)
```
- Normal - we haven't configured a root filesystem yet
- Lab 5 will build a root filesystem

## Part 6: Streamlining the Boot Process

Manually typing TFTP commands every boot is tedious. Let's automate it!

### Create Boot Script

In U-Boot, set environment variables for automatic boot:

```
=> setenv load_kernel 'tftp ${kernel_addr_r} Image.gz'
=> setenv load_dtb 'tftp ${fdt_addr_r} k3-am625-beagleplay.dtb'
=> setenv netboot 'run load_kernel; run load_dtb; booti ${kernel_addr_r} - ${fdt_addr_r}'
```

Variables explained:
- **load_kernel** - Command to load kernel
- **load_dtb** - Command to load Device Tree
- **netboot** - Run both loads and boot

The `${kernel_addr_r}` and `${fdt_addr_r}` are predefined U-Boot variables for safe load addresses.

Check their values:

```
=> printenv kernel_addr_r fdt_addr_r
```

Output:

```
kernel_addr_r=0x82000000
fdt_addr_r=0x88000000
```

Perfect - these are the addresses we used earlier!

### Test the Boot Script

Now you can boot with a single command:

```
=> run netboot
```

Should load both files and boot the kernel.

### Make It Automatic (Optional)

To boot automatically after a delay:

```
=> setenv bootcmd 'run netboot'
=> setenv bootdelay 3
=> saveenv
```

Now on every boot, U-Boot will:
1. Wait 3 seconds (press SPACE to interrupt)
2. Automatically run `netboot`
3. Load kernel and DTB via TFTP
4. Boot Linux

**Caution:** Make sure TFTP server is always running! Otherwise, boot will fail.

To disable auto-boot:

```
=> setenv bootcmd
=> saveenv
```

(Empty bootcmd disables auto-boot)

## Part 7: Kernel Configuration Deep Dive

### Inspecting Configuration Options

Find out what a specific config does:

```bash
cd $HOME/embedded-labs/kernel/linux
make menuconfig
```

Press `/` (search) and type `NFS_FS`. You'll see:

```
Symbol: NFS_FS [=y]
Type  : tristate
Defined at fs/nfs/Kconfig:1
Prompt: NFS client support
Depends on: NETWORK_FILESYSTEMS [=y] && INET [=y]
Location:
  -> File systems
    -> Network File Systems
```

This shows:
- **Symbol name:** CONFIG_NFS_FS
- **Current value:** y (built-in)
- **Dependencies:** Requires networking enabled
- **Location:** Where to find it in menuconfig

### Comparing Configurations

Save your current config:

```bash
cp .config my_beagleplay_config
```

Try changing something in menuconfig, then compare:

```bash
make menuconfig
# Change some options
scripts/diffconfig my_beagleplay_config .config
```

This shows only the differences!

### Viewing All Enabled Options

See every CONFIG_* set to `y` or `m`:

```bash
grep -E "^CONFIG_" .config | grep -v "# CONFIG" | wc -l
```

Typical ARM64 defconfig: **~2,500** options enabled!

See the largest categories:

```bash
grep -E "^CONFIG_" .config | cut -d_ -f1-2 | sort | uniq -c | sort -rn | head -20
```

## Troubleshooting

*Marvin's note: "I've calculated your chances of success. You won't like them. But here's how to improve the odds anyway."*


### Kernel Panics on Boot

**Symptom:** Kernel panics before mounting root

**Possible Causes:**
1. Wrong Device Tree (DTB)
2. Missing critical drivers
3. Incorrect bootargs

**Solution:**
- Verify DTB filename: `k3-am625-beagleplay.dtb`
- Check bootargs: `console=ttyS2,115200n8`
- Enable debug output: `setenv bootargs '${bootargs} debug'`

### TFTP Download Fails

**Symptom:** `T T T T` timeout errors

**Check List:**
- [ ] Ethernet cable connected
- [ ] PC IP configured: `ip addr show`
- [ ] TFTP server running: `systemctl status tftpd-hpa`
- [ ] Files in `/srv/tftp/`: `ls /srv/tftp/`
- [ ] Firewall allows TFTP: `sudo ufw status`
- [ ] U-Boot IP correct: `printenv ipaddr serverip`

### Kernel Decompression Error

**Symptom:** `kernel_comp_addr_r or kernel_comp_size is not provided!`

**Solution:**

```
setenv kernel_comp_addr_r 0x90000000
setenv kernel_comp_size 0x2000000
saveenv
```

### Wrong Console Output

**Symptom:** No kernel messages on serial console

**Cause:** Wrong console device in bootargs

**Solution:**

Check Device Tree for correct serial port:

```bash
grep -A5 "chosen" arch/arm64/boot/dts/ti/k3-am625-beagleplay.dts
```

Should show:

```
chosen {
    stdout-path = "serial2:115200n8";
};
```

This means `console=ttyS2` (serial2 = ttyS2).

### Build Errors

**Error:** `No rule to make target 'debian/canonical-certs.pem'`

**Cause:** Ubuntu-specific certificate config

**Solution:**

```bash
scripts/config --disable SYSTEM_TRUSTED_KEYS
scripts/config --disable SYSTEM_REVOCATION_KEYS
make olddefconfig
```

**Error:** `ld: cannot find -lelf`

**Cause:** Missing libelf-dev

**Solution:**

```bash
sudo apt install libelf-dev
```

**Error:** `flex: not found`

**Cause:** Missing flex/bison

**Solution:**

```bash
sudo apt install flex bison
```

### Network Interface Not Found

**Symptom:** Ethernet not working in kernel

**Solution:**

Enable TI K3 Ethernet driver:

```bash
make menuconfig
# Navigate to:
# Device Drivers → Network device support → Ethernet driver support →
# [*] Texas Instruments (TI) devices
#   <*> TI K3 AM65 CPSW Ethernet driver
```

Rebuild:

```bash
make -j$(nproc)
```

## Verification Checklist

*Ford Prefect says: "Always verify your work. It's the difference between a working system and a very expensive paperweight."*


Before moving to the next lab, ensure:

- [ ] Linux kernel source cloned and stable/linux-6.6.y checked out
- [ ] Kernel configured with ARM64 defconfig and customized for BeaglePlay
- [ ] Kernel compilation successful
- [ ] Image.gz and k3-am625-beagleplay.dtb files generated
- [ ] TFTP server installed and running on development PC
- [ ] Network configured (PC and BeaglePlay on same subnet)
- [ ] TFTP download test successful from U-Boot
- [ ] Kernel boots via TFTP and displays boot messages
- [ ] Kernel panics with "Unable to mount root fs" (expected!)
- [ ] U-Boot boot script created for streamlined booting

## Going Further (Optional Challenges)

### Challenge 1: Kernel Size Optimization

**Goal:** Reduce kernel size by disabling unnecessary features

**Tasks:**
1. Current Image.gz size: ~10MB
2. Target: Get it under 5MB
3. Disable unused drivers (sound, graphics, USB gadgets)
4. Compare boot time before/after

**Hints:**
- Use `make localmodconfig` to only enable currently loaded modules (won't help much on first build)
- Disable entire subsystems: sound, media, staging drivers
- Check size: `ls -lh arch/arm64/boot/Image.gz`

### Challenge 2: Custom Kernel Command Line

**Goal:** Pass custom parameters to the kernel

**Tasks:**
1. Add `initcall_debug` to bootargs (shows function call timings)
2. Add `quiet` to reduce boot messages
3. Compare boot times with different log levels

**Hints:**

```
setenv bootargs 'console=ttyS2,115200n8 initcall_debug'
```

Research kernel parameters: `Documentation/admin-guide/kernel-parameters.txt`

### Challenge 3: Device Tree Exploration

**Goal:** Understand how Device Tree describes hardware

**Tasks:**
1. Read the Device Tree source: `arch/arm64/boot/dts/ti/k3-am625-beagleplay.dts`
2. Find the serial console node
3. Find the Ethernet controller node
4. Identify mikroBUS connector pinout

**Hints:**

```bash
less arch/arm64/boot/dts/ti/k3-am625-beagleplay.dts
# Search for: /serial@, /ethernet@, /chosen
```

### Challenge 4: Enable Kernel Debugging

**Goal:** Build kernel with debug symbols for GDB debugging

**Tasks:**
1. Enable CONFIG_DEBUG_INFO
2. Enable CONFIG_GDB_SCRIPTS
3. Build and compare vmlinux size
4. Explore debug symbols with GDB (later lab)

**Hints:**

```bash
make menuconfig
# Kernel hacking → Compile-time checks and compiler options →
#   [*] Compile the kernel with debug info
```

Note: This makes the kernel MUCH larger (~500MB vmlinux)!

### Challenge 5: Build a Module

**Goal:** Compile a kernel driver as a loadable module

**Tasks:**
1. Choose a simple driver (e.g., dummy network driver)
2. Configure it as `<M>` (module) instead of `<*>` (built-in)
3. Build just that module: `make M=drivers/net`
4. Find the .ko file

**Hints:**

```bash
make menuconfig
# Find a driver, set to <M>
make modules
find . -name "*.ko"
```

We'll learn to load modules in Lab 5!

## Summary

In this lab, you:

✅ Cloned the Linux kernel source tree (mainline + stable)  
✅ Checked out a stable LTS version (6.6.x)  
✅ Configured the kernel for ARM64 and BeaglePlay hardware  
✅ Cross-compiled the kernel and Device Tree Blobs  
✅ Set up TFTP server for network-based kernel loading  
✅ Configured U-Boot networking and boot arguments  
✅ Successfully booted a custom Linux kernel via TFTP  
✅ Created U-Boot boot scripts to streamline the process  
✅ Learned to troubleshoot kernel boot issues  

### Key Takeaways

1. **Kernel is highly configurable** - Thousands of options affect functionality and size
2. **Device Tree is critical** - Modern ARM systems require correct DTB for hardware detection
3. **Network boot is powerful** - TFTP allows rapid testing without SD card writes
4. **Compression saves space** - Image.gz is ~50% smaller than uncompressed Image
5. **Boot arguments matter** - Console configuration must match hardware

### What's Next?

In **Lab 5**, we'll:
- Build a minimal root filesystem with BusyBox
- Create init scripts and startup configuration
- Mount the root filesystem over NFS
- Get a working shell prompt
- Build statically and dynamically linked programs

The kernel is booting - now we need a userspace!

---

**Estimated completion time:** 3-4 hours  
**Difficulty:** ⭐⭐⭐ (Intermediate)

**Questions?** Refer to:
- [Kernel Documentation](https://www.kernel.org/doc/html/latest/)
- [Device Tree Specification](https://www.devicetree.org/)
- [Linux ARM64 Boot](https://www.kernel.org/doc/Documentation/arm64/booting.txt)
