# Lab 5: Root Filesystem with BusyBox and NFS

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about root filesystems:

*"A root filesystem is where all your files live. Think of it as the contents of your towel bag - essential utilities, helpful tools, and the occasional item whose purpose you've completely forgotten but you're certain you'll need eventually."*

## Learning Objectives

By the end of this lab, you will be able to:

- Understand Linux root filesystem structure and requirements
- Build BusyBox to provide essential Unix utilities
- Create a minimal root filesystem from scratch
- Set up NFS server for network-based root filesystem
- Configure kernel for NFS root boot
- Create init scripts and system startup configuration
- Mount virtual filesystems (proc, sysfs, devtmpfs)
- Switch between static and dynamic linking
- Set up a simple web server on the embedded system

**Estimated Time:** 3-4 hours

**Prerequisites:**
- Completed Lab 1 (Custom Toolchain)
- Completed Lab 2 (Hardware Discovery)
- Completed Lab 3 (U-Boot Bootloader)
- Completed Lab 4 (Linux Kernel)
- Understanding of filesystem hierarchy
- Basic shell scripting knowledge

## Introduction

### What is a Root Filesystem?

In Lab 4, our kernel successfully booted but panicked with:

```
Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)
```

This happened because the kernel needs a **root filesystem** - a directory tree containing:
- **`/sbin/init`** - The first userspace program (PID 1)
- **Essential commands** - ls, cp, cat, mount, etc.
- **Libraries** - Shared libraries for dynamically linked programs
- **Configuration files** - System startup scripts, network config, etc.
- **Device files** - In `/dev` (or created dynamically)

Without a root filesystem, the kernel has no userspace to run!

### Why BusyBox?

BusyBox is the "Swiss Army Knife of Embedded Linux":

**Single Binary, Multiple Tools**
- One executable provides 300+ Unix utilities
- `busybox ls`, `busybox cp`, `busybox mount`, etc.
- Symbolic links allow `ls` → `busybox`

**Tiny Size**
- Full-featured: ~900KB static binary
- Minimal config: ~400KB
- Compare to GNU coreutils: ~14MB!

**Perfect for Embedded**
- Low memory footprint
- No dependencies when built static
- Configurable features (like kernel menuconfig)

### Why NFS Root?

During development, NFS (Network File System) root is invaluable:

**Instant Updates**
- Edit files on PC, changes immediately visible on target
- No reflashing, no SD card swapping
- Edit-test cycle in seconds, not minutes

**Easy Debugging**
- Access target filesystem from PC
- Copy files in/out effortlessly
- Inspect logs, add debugging tools

**Flexibility**
- Try different configurations quickly
- Revert changes instantly
- Share root filesystem between multiple boards

**Production Note:** NFS root is for development only. Production systems use local storage (eMMC, SD, flash).

### What We'll Build

```
Development PC                    BeaglePlay
┌─────────────────┐              ┌──────────────┐
│                 │              │              │
│ /home/you/      │              │ Kernel boots │
│  nfsroot/       │              │              │
│   bin/          │  NFS mount   │ Mounts NFS   │
│   sbin/     ◄───┼──────────────┼─ as /       │
│   etc/          │  Ethernet    │              │
│   lib/          │              │ Runs init    │
│   ...           │              │              │
│                 │              │ Shell prompt!│
└─────────────────┘              └──────────────┘
```

The BeaglePlay will mount your PC's directory as its root filesystem over the network!

## Workspace Setup

Create root filesystem lab directory:

```bash
cd $HOME/embedded-labs
mkdir -p tinysystem
cd tinysystem
```

All root filesystem work happens here.

## Part 1: Understanding NFS Root Requirements

### Kernel Configuration Check

First, verify our kernel has NFS client support.

Check if NFS is enabled:

```bash
cd $HOME/embedded-labs/kernel/linux
grep -E "CONFIG_NFS_FS|CONFIG_ROOT_NFS|CONFIG_IP_PNP" .config
```

Should show:

```
CONFIG_NFS_FS=y
CONFIG_ROOT_NFS=y
CONFIG_IP_PNP=y
CONFIG_IP_PNP_DHCP=y
```

If any are missing or set to `=m` (module), enable them:

```bash
make menuconfig
```

Navigate to:

```
File systems →
  Network File Systems →
    [*] NFS client support
    [*] NFS client support for NFS version 3
    [*] Root file system on NFS
```

And:

```
Networking support →
  Networking options →
    [*] IP: kernel level autoconfiguration
```

Also verify `devtmpfs` is configured to auto-mount:

```bash
grep CONFIG_DEVTMPFS .config
```

Should show:

```
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
```

If you made changes, rebuild the kernel:

```bash
make -j$(nproc)
cp arch/arm64/boot/Image.gz /srv/tftp/
```

### NFS Root Boot Flow

Here's what happens when booting with NFS root:

```
1. U-Boot loads kernel via TFTP
2. Kernel boots, initializes network
3. Kernel contacts NFS server (IP from bootargs)
4. Kernel mounts NFS export as root filesystem
5. Kernel executes /sbin/init from NFS
6. System boots normally!
```

The kernel needs these boot arguments:

```
root=/dev/nfs                    ← Use NFS for root
nfsroot=192.168.1.1:/path,opts   ← NFS server and path
ip=192.168.1.100::::eth0         ← Board IP config
```

## Part 2: Building BusyBox

### Get BusyBox Sources

Clone the stable BusyBox repository:

```bash
cd $HOME/embedded-labs/tinysystem
git clone https://git.busybox.net/busybox
cd busybox/
git checkout 1_37_stable
```

Version 1.37 is the latest stable branch.

Check the version:

```bash
head -5 Makefile | grep VERSION
```

Should show:

```
VERSION = 1
PATCHLEVEL = 37
SUBLEVEL = 0
```

### Explore BusyBox

BusyBox uses Kconfig like the kernel. Check available commands:

```bash
ls -1 */Config.in | head -20
```

You'll see configuration files for:
- `archival/Config.in` - tar, gzip, unzip
- `console-tools/Config.in` - loadfont, setconsole
- `coreutils/Config.in` - ls, cp, mv, cat, etc.
- `editors/Config.in` - vi, sed, awk
- `networking/Config.in` - wget, ifconfig, ping

### Load Base Configuration

Start with a default config optimized for embedded systems:

```bash
make defconfig
```

This creates `.config` with reasonable defaults.

### Configure BusyBox

Customize the configuration:

```bash
make menuconfig
```

**Critical Changes:**

**1. Enable Static Linking (for now)**

Navigate to:

```
Settings →
  [*] Build static binary (no shared libs)
```

Press Space to enable (asterisk should appear).

**Why static?** Initially we have no C library in our root filesystem. Static linking embeds everything into the BusyBox binary. Later we'll switch to dynamic linking.

**2. Set Installation Prefix**

Navigate to:

```
Settings →
  Installation Options ("make install" behavior) →
    Destination path for 'make install'
```

Set this to:

```
/home/YOUR_USERNAME/embedded-labs/tinysystem/nfsroot
```

**Replace YOUR_USERNAME!** This is where BusyBox will be installed.

**3. Enable Useful Commands (optional but recommended)**

Navigate and enable these if not already enabled:

```
Archival Utilities →
  [*] tar
  [*] gunzip
  [*] gzip

Editors →
  [*] vi

Networking Utilities →
  [*] ping
  [*] wget
  [*] httpd (we'll use this later!)
```

Save and exit menuconfig.

### Cross-Compile BusyBox

Set up cross-compilation environment:

```bash
export ARCH=arm64
export CROSS_COMPILE=aarch64-beagleplay-linux-musl-
```

Build BusyBox:

```bash
make -j$(nproc)
```

Build time: ~1-2 minutes.

Check the binary size:

```bash
ls -lh busybox
```

Should be around **900KB-1.2MB** for a static build with most features enabled.

Verify it's statically linked:

```bash
file busybox
```

Output:

```
busybox: ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV), statically linked, not stripped
```

"statically linked" confirms it has no library dependencies.

### Install BusyBox

Install to our NFS root directory:

```bash
make install
```

This creates the directory structure:

```bash
ls -la $HOME/embedded-labs/tinysystem/nfsroot/
```

You should see:

```
total 12
drwxr-xr-x  4 you you 4096 bin
drwxr-xr-x  2 you you 4096 sbin
lrwxrwxrwx  1 you you   11 linuxrc -> bin/busybox
```

Check what's in `bin/`:

```bash
ls $HOME/embedded-labs/tinysystem/nfsroot/bin/ | head -20
```

You'll see hundreds of symlinks:

```
ls -> busybox
cp -> busybox
mv -> busybox
cat -> busybox
...
```

Check the actual BusyBox binary:

```bash
ls -lh $HOME/embedded-labs/tinysystem/nfsroot/bin/busybox
```

Should show the same ~900KB size.

**How it works:**
- All commands are symlinks to `busybox`
- BusyBox checks `argv[0]` (program name)
- Executes appropriate functionality

Test locally (won't fully work on x86, but demonstrates the concept):

```bash
$HOME/embedded-labs/tinysystem/nfsroot/bin/busybox echo "Hello from BusyBox"
```

## Part 3: Creating Root Filesystem Structure

BusyBox installed `bin/` and `sbin/`, but we need more directories.

### Create Essential Directories

```bash
cd $HOME/embedded-labs/tinysystem/nfsroot
mkdir -p dev etc lib proc sys tmp usr/lib usr/bin
```

Explanation of each directory:

| Directory | Purpose |
|-----------|---------|
| **/dev** | Device files (will be auto-populated by devtmpfs) |
| **/etc** | Configuration files (init scripts, network config) |
| **/lib** | Shared libraries (for dynamic linking later) |
| **/proc** | Virtual filesystem for process information |
| **/sys** | Virtual filesystem for kernel/device information |
| **/tmp** | Temporary files |
| **/usr/lib** | Additional libraries |
| **/usr/bin** | User commands |

Set proper permissions:

```bash
chmod 1777 tmp
```

The `1777` sets:
- `1` - Sticky bit (only owner can delete files)
- `777` - Read/write/execute for everyone

Verify the structure:

```bash
tree -L 1 .
```

Should show:

```
.
├── bin -> usr/bin
├── dev
├── etc
├── lib -> usr/lib
├── linuxrc -> bin/busybox
├── proc
├── sbin -> usr/sbin
├── sys
├── tmp
└── usr
```

## Part 4: NFS Server Setup

Now we'll export this directory via NFS so BeaglePlay can mount it.

### Install NFS Server

```bash
sudo apt install nfs-kernel-server
```

Verify it's running:

```bash
sudo systemctl status nfs-kernel-server
```

Should show "active (running)".

### Configure NFS Export

Edit the NFS exports file:

```bash
sudo nano /etc/exports
```

Add this line (all on ONE line):

```
/home/YOUR_USERNAME/embedded-labs/tinysystem/nfsroot 192.168.1.100(rw,no_root_squash,no_subtree_check,sync)
```

**Replace YOUR_USERNAME** with your actual username!

Parameters explained:
- **192.168.1.100** - Only allow this IP (our BeaglePlay)
- **rw** - Read-write access
- **no_root_squash** - Don't map root to anonymous user (allows root to create files)
- **no_subtree_check** - Faster, less secure (OK for development)
- **sync** - Write changes immediately (safer but slower)

**Important (like knowing where your towel is):** Make sure there's **NO SPACE** between the IP and the opening parenthesis! Otherwise default (read-only) options will be used.

### Apply NFS Configuration

Reload the NFS server configuration:

```bash
sudo exportfs -ra
```

The `-ra` means "re-export all directories".

Verify the export:

```bash
sudo exportfs -v
```

Should show:

```
/home/you/embedded-labs/tinysystem/nfsroot
        192.168.1.100(rw,wdelay,no_root_squash,no_subtree_check,sec=sys,...)
```

### Test NFS Locally (Optional)

Before testing on BeaglePlay, verify NFS works locally:

```bash
sudo mkdir -p /mnt/test
sudo mount -t nfs localhost:/home/$USER/embedded-labs/tinysystem/nfsroot /mnt/test
ls /mnt/test
```

Should show `bin`, `sbin`, `etc`, etc.

Unmount:

```bash
sudo umount /mnt/test
```

Success! NFS server is ready.

## Part 5: Booting with NFS Root

### Configure U-Boot for NFS Root

Power on BeaglePlay, hold USR button, stop at U-Boot prompt.

Set kernel boot arguments for NFS root:

```
=> setenv bootargs console=ttyS2,115200n8 root=/dev/nfs ip=192.168.1.100::::eth0 nfsroot=192.168.1.1:/home/YOUR_USERNAME/embedded-labs/tinysystem/nfsroot,nfsvers=3,tcp rw
=> saveenv
```

**Adjust these values:**
- **YOUR_USERNAME** - Your actual username
- **192.168.1.100** - BeaglePlay IP
- **192.168.1.1** - Your PC IP

Bootargs breakdown:

| Parameter | Meaning |
|-----------|---------|
| `console=ttyS2,115200n8` | Serial console configuration |
| `root=/dev/nfs` | Use NFS for root filesystem |
| `ip=192.168.1.100::::eth0` | Static IP for eth0 (format: ip:server:gateway:netmask:hostname:device) |
| `nfsroot=192.168.1.1:/path,nfsvers=3,tcp` | NFS server, path, version 3, TCP protocol |
| `rw` | Mount read-write |

### Boot the System

Load kernel and DTB:

```
=> run netboot
```

(Or manually: `tftp 0x82000000 Image.gz; tftp 0x88000000 k3-am625-beagleplay.dtb; booti 0x82000000 - 0x88000000`)

Watch the boot messages closely. You should see:

```
[    0.000000] Kernel command line: console=ttyS2,115200n8 root=/dev/nfs ip=192.168.1.100::::eth0 nfsroot=192.168.1.1:/home/you/embedded-labs/tinysystem/nfsroot,nfsvers=3,tcp rw
...
[    2.456789] am65-cpsw-nuss 8000000.ethernet eth0: Link is Up - 1Gbps/Full - flow control off
...
[    3.123456] IP-Config: Complete:
[    3.123500]      device=eth0, hwaddr=xx:xx:xx:xx:xx:xx, ipaddr=192.168.1.100, mask=255.255.255.0, gw=255.255.255.255
...
[    4.567890] VFS: Mounted root (nfs filesystem) on device 0:18.
...
[    5.234567] devtmpfs: mounted
[    5.678901] Freeing unused kernel image (initmem) memory: 6464K
[    5.678950] Run /sbin/init as init process
```

**Expected failure:**

```
[    6.123456] Kernel panic - not syncing: No working init found.  Try passing init= option to kernel. See Linux Documentation/admin-guide/init.rst for guidance.
```

**This is progress!** The kernel:
✅ Configured networking  
✅ Mounted NFS root  
✅ Tried to run `/sbin/init`  
❌ But `/sbin/init` doesn't exist yet!

### Create /dev Directory

The panic might also mention:

```
[    5.123456] devtmpfs: error mounting -2
```

This is because `/dev` doesn't exist. Create it:

```bash
cd $HOME/embedded-labs/tinysystem/nfsroot
mkdir -p dev
```

Reboot BeaglePlay. The devtmpfs error should be gone, but init panic remains.

## Part 6: Init System Configuration

Linux needs `/sbin/init` - the first userspace program. BusyBox provides a simple init system.

### Create Init Symlink

BusyBox init is just the busybox binary called as `init`:

```bash
cd $HOME/embedded-labs/tinysystem/nfsroot
ln -s ../bin/busybox sbin/init
```

Verify:

```bash
ls -l sbin/init
```

Should show:

```
lrwxrwxrwx 1 you you 14 sbin/init -> ../bin/busybox
```

### Create inittab Configuration

BusyBox init reads `/etc/inittab` for configuration.

Create it:

```bash
cat > etc/inittab << 'EOF'
# /etc/inittab for BusyBox init

# Mount proc and sysfs at boot
::sysinit:/etc/init.d/rcS

# Start a shell on console
::askfirst:/bin/sh

# Reboot on Ctrl-Alt-Del
::ctrlaltdel:/sbin/reboot

# Shutdown cleanly
::shutdown:/bin/umount -a -r
EOF
```

**Inittab format:** `<id>:<runlevels>:<action>:<process>`

- **::sysinit:** - Run `/etc/init.d/rcS` at system initialization
- **::askfirst:** - Start `/bin/sh`, ask for Enter first (prevents boot spam from covering prompt)
- **::ctrlaltdel:** - Handle Ctrl-Alt-Del
- **::shutdown:** - Unmount filesystems cleanly on shutdown

### Create Startup Script

Create the `rcS` startup script referenced in inittab:

```bash
mkdir -p etc/init.d
cat > etc/init.d/rcS << 'EOF'
#!/bin/sh

# BeaglePlay system startup script

echo "Starting BeaglePlay system..."

# Mount proc filesystem (process information)
mount -t proc proc /proc

# Mount sysfs filesystem (kernel/device information)
mount -t sysfs sysfs /sys

# Mount devtmpfs if not already mounted by kernel
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true

# Set hostname
hostname beagleplay

echo "System initialization complete."
EOF
```

Make it executable:

```bash
chmod +x etc/init.d/rcS
```

**What this script does:**
1. Mounts `/proc` - Virtual FS for process info (`ps` needs this)
2. Mounts `/sys` - Virtual FS for device info
3. Mounts `/dev` - Device files (may already be mounted by kernel)
4. Sets hostname

## Part 7: First Successful Boot!

Reboot BeaglePlay. You should now see:

```
[    5.678901] Run /sbin/init as init process
Starting BeaglePlay system...
System initialization complete.

Please press Enter to activate this console.
```

**Press Enter** and you'll get a shell prompt:

```
/ #
```

**Success!** You now have a working embedded Linux system!

### Test Your System

Try some commands:

```bash
ls /
pwd
cat /proc/cpuinfo
cat /proc/meminfo
free
ps
uname -a
```

Each command is actually BusyBox:

```bash
ls -l /bin/ls
```

Shows it's a symlink to busybox.

Check mounted filesystems:

```bash
mount
```

Should show:

```
192.168.1.1:/home/you/.../nfsroot on / type nfs (rw,...)
proc on /proc type proc (rw,...)
sysfs on /sys type sysfs (rw,...)
devtmpfs on /dev type devtmpfs (rw,...)
```

Your root filesystem is mounted via NFS!

### Test NFS Live Updates

On your PC, create a test file:

```bash
echo "Hello from NFS!" > $HOME/embedded-labs/tinysystem/nfsroot/tmp/test.txt
```

On BeaglePlay:

```bash
cat /tmp/test.txt
```

You immediately see the file! No reboot, no copying. This is the power of NFS root for development.

Edit on PC, see changes instantly on target. Try it:

```bash
# On PC
echo "Updated content" > $HOME/embedded-labs/tinysystem/nfsroot/tmp/test.txt

# On BeaglePlay
cat /tmp/test.txt
```

## Part 8: Virtual Filesystems Deep Dive

Let's understand what we mounted in `rcS`.

### /proc - Process Information

Explore `/proc`:

```bash
ls /proc
```

You'll see numbered directories (PIDs) and special files.

See all processes:

```bash
cat /proc/1/cmdline && echo
```

Shows PID 1's command line (`/sbin/init`).

CPU information:

```bash
cat /proc/cpuinfo
```

Shows all 4 Cortex-A53 cores.

Memory info:

```bash
cat /proc/meminfo
```

Shows total, free, cached memory.

Current kernel command line:

```bash
cat /proc/cmdline
```

Shows the bootargs we set in U-Boot!

### /sys - Kernel and Device Information

Explore `/sys`:

```bash
ls /sys
```

Check network interface info:

```bash
cat /sys/class/net/eth0/address
cat /sys/class/net/eth0/speed
cat /sys/class/net/eth0/statistics/rx_bytes
```

Shows MAC address, link speed (1000 Mbps), received bytes.

See all I2C buses:

```bash
ls /sys/bus/i2c/devices/
```

Check MMC devices:

```bash
ls /sys/class/mmc_host/
```

### /dev - Device Files

List device files:

```bash
ls -l /dev/ | head -20
```

Key devices:
- **console** - System console
- **ttyS0, ttyS1, ttyS2** - Serial ports (we're using ttyS2)
- **null** - Null device (discards all writes)
- **zero** - Provides infinite zeros
- **random, urandom** - Random number generators
- **mmcblk0, mmcblk0p1, etc.** - MMC/SD card and partitions

These are created by `devtmpfs` - the kernel automatically populates `/dev`.

## Part 9: Switching to Shared Libraries

Currently BusyBox is statically linked (~900KB). Let's rebuild with shared libraries to reduce size.

### Create a Test Program

First, let's see how dynamic linking works.

On your PC, create a test program:

```bash
cd $HOME/embedded-labs/tinysystem
cat > hello.c << 'EOF'
#include <stdio.h>

int main(void) {
    printf("Hello from BeaglePlay with dynamic linking!\n");
    return 0;
}
EOF
```

Compile it dynamically:

```bash
aarch64-beagleplay-linux-musl-gcc hello.c -o hello
```

Check what it needs:

```bash
file hello
```

Output:

```
hello: ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /lib/ld-musl-aarch64.so.1, not stripped
```

It needs `/lib/ld-musl-aarch64.so.1` - the dynamic linker!

Copy to target:

```bash
cp hello nfsroot/usr/bin/
```

On BeaglePlay, try to run it:

```bash
/usr/bin/hello
```

Error:

```
/usr/bin/hello: No such file or directory
```

**Misleading error!** It's not the program that's missing - it's the dynamic linker!

### Install Dynamic Linker

The dynamic linker is part of our toolchain. Find it:

```bash
find $HOME/x-tools/aarch64-beagleplay-linux-musl -name "ld-musl-aarch64.so.1"
```

Output:

```
/home/you/x-tools/aarch64-beagleplay-linux-musl/aarch64-beagleplay-linux-musl/lib/ld-musl-aarch64.so.1
```

Copy it to the target:

```bash
cp $HOME/x-tools/aarch64-beagleplay-linux-musl/aarch64-beagleplay-linux-musl/lib/ld-musl-aarch64.so.1 \
   nfsroot/lib/
```

**With Musl**, the dynamic linker contains the entire C library! So this one file is all we need.

### Test Dynamic Program

On BeaglePlay, try again:

```bash
/usr/bin/hello
```

Output:

```
Hello from BeaglePlay with dynamic linking!
```

Success! Dynamic linking works.

If you get an error, wait 30-60 seconds (NFS cache delay) and try again.

### Rebuild BusyBox Dynamically

Measure current BusyBox size:

```bash
ls -lh $HOME/embedded-labs/tinysystem/nfsroot/bin/busybox
```

Note the size (~900KB static).

Reconfigure BusyBox:

```bash
cd $HOME/embedded-labs/tinysystem/busybox
make menuconfig
```

Navigate to:

```
Settings →
  [ ] Build static binary (no shared libs)
```

Press Space to **disable** static linking (no asterisk).

Save and exit.

Rebuild and reinstall:

```bash
make -j$(nproc)
make install
```

Check new size:

```bash
ls -lh $HOME/embedded-labs/tinysystem/nfsroot/bin/busybox
```

Should be **~600KB** - about 30% smaller!

Verify it's dynamic:

```bash
file $HOME/embedded-labs/tinysystem/nfsroot/bin/busybox
```

Should show "dynamically linked".

### Test Dynamic BusyBox

Reboot BeaglePlay. Everything should still work:

```bash
ls /
ps
cat /proc/cpuinfo
```

Now check what libraries are needed:

```bash
ldd /bin/busybox
```

BusyBox will show:

```
ldd: /bin/busybox: Not a valid dynamic program (error 1)
```

This error is because BusyBox's `ldd` implementation is basic. But the program works, so dynamic linking is functioning!

## Part 10: Simple Web Server

BusyBox includes a simple HTTP server. Let's set it up!

### Create Web Content

Create web directory and a simple page:

```bash
cd $HOME/embedded-labs/tinysystem/nfsroot
mkdir -p www
cat > www/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>BeaglePlay Web Server</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background: #f5f5f5;
        }
        h1 {
            color: #333;
            border-bottom: 2px solid #0066cc;
            padding-bottom: 10px;
        }
        .info {
            background: white;
            padding: 15px;
            border-radius: 5px;
            margin: 10px 0;
        }
    </style>
</head>
<body>
    <h1>Welcome to BeaglePlay!</h1>
    <div class="info">
        <h2>System Information</h2>
        <p><strong>Board:</strong> BeagleBoard.org BeaglePlay</p>
        <p><strong>SoC:</strong> TI AM625 (ARM Cortex-A53)</p>
        <p><strong>Root FS:</strong> NFS from development PC</p>
        <p><strong>Web Server:</strong> BusyBox httpd</p>
    </div>
    <div class="info">
        <h2>Lab Progress</h2>
        <p>✅ Custom toolchain built</p>
        <p>✅ U-Boot compiled and installed</p>
        <p>✅ Linux kernel cross-compiled</p>
        <p>✅ Root filesystem created</p>
        <p>✅ BusyBox configured and built</p>
        <p>✅ NFS root working</p>
        <p>✅ Web server running!</p>
    </div>
</body>
</html>
EOF
```

### Start Web Server

On BeaglePlay, start the HTTP server:

```bash
/usr/sbin/httpd -h /www -p 8080
```

Parameters:
- **-h /www** - Document root
- **-p 8080** - Port 8080

The server automatically backgrounds itself.

Verify it's running:

```bash
ps | grep httpd
```

Should show the httpd process.

### Test Web Server

From your development PC, open a browser and navigate to:

```
http://192.168.1.100:8080/
```

You should see your webpage!

If you're using a proxy, make sure to bypass it for `192.168.1.100`:
- Firefox: Preferences → Network Settings → No proxy for: `192.168.1.100`
- Chrome: Use system proxy settings and configure in system network settings

### Add to Startup Script

Make the web server start automatically:

```bash
cat >> $HOME/embedded-labs/tinysystem/nfsroot/etc/init.d/rcS << 'EOF'

# Start web server
/usr/sbin/httpd -h /www -p 8080
echo "Web server started on port 8080"
EOF
```

Reboot and verify the web server starts automatically.

### Create a CGI Script (Optional)

BusyBox httpd supports CGI scripts. Create a dynamic page:

```bash
mkdir -p nfsroot/www/cgi-bin
cat > nfsroot/www/cgi-bin/info.sh << 'EOF'
#!/bin/sh

echo "Content-type: text/html"
echo ""
echo "<html><head><title>System Info</title></head><body>"
echo "<h1>BeaglePlay System Information</h1>"
echo "<pre>"
echo "<b>Hostname:</b> $(hostname)"
echo "<b>Uptime:</b> $(uptime)"
echo "<b>Memory:</b>"
free
echo ""
echo "<b>Processes:</b>"
ps
echo "</pre></body></html>"
EOF

chmod +x nfsroot/www/cgi-bin/info.sh
```

Browse to: `http://192.168.1.100:8080/cgi-bin/info.sh`

You'll see live system information!

## Troubleshooting

*Marvin's note: "I've calculated your chances of success. You won't like them. But here's how to improve the odds anyway."*


### NFS Mount Fails

**Symptom:** Kernel panics with "VFS: Unable to mount root (nfs)"

**Causes:**
1. NFS server not running
2. Wrong IP addresses in bootargs
3. Export path incorrect
4. Firewall blocking NFS

**Solutions:**

Check NFS server status:

```bash
sudo systemctl status nfs-kernel-server
```

Verify export:

```bash
sudo exportfs -v
```

Check firewall (Ubuntu):

```bash
sudo ufw allow from 192.168.1.100
```

Test NFS mount locally:

```bash
sudo mount -t nfs localhost:/home/$USER/embedded-labs/tinysystem/nfsroot /mnt
ls /mnt
sudo umount /mnt
```

### Init Not Found

**Symptom:** "No working init found"

**Cause:** `/sbin/init` doesn't exist or isn't executable

**Solution:**

```bash
cd $HOME/embedded-labs/tinysystem/nfsroot
ls -l sbin/init
# Should be a symlink to ../bin/busybox

# If missing:
ln -s ../bin/busybox sbin/init
```

### Shell Prompt Shows "can't access tty; job control turned off"

**Cause:** Wrong console device in inittab

**Solution:**

Edit `etc/inittab`, change:

```
::askfirst:/bin/sh
```

To:

```
ttyS2::askfirst:/bin/sh
```

This specifies the exact console device.

### Commands Not Working

**Symptom:** "sh: command not found" for basic commands

**Cause:** BusyBox not installed or PATH wrong

**Solution:**

Check BusyBox installation:

```bash
ls $HOME/embedded-labs/tinysystem/nfsroot/bin/busybox
```

On target, check PATH:

```bash
echo $PATH
```

Should include `/bin` and `/sbin`.

### Web Server Won't Start

**Symptom:** httpd exits immediately

**Cause:** Port already in use or wrong path

**Solution:**

Check if port 8080 is available:

```bash
netstat -tuln | grep 8080
```

Try a different port:

```bash
/usr/sbin/httpd -h /www -p 8000
```

Verify /www exists:

```bash
ls -ld /www
```

### NFS Writes Fail

**Symptom:** "Read-only file system" when creating files

**Cause:** `no_root_squash` not set in exports

**Solution:**

Edit `/etc/exports`, ensure:

```
/path/to/nfsroot 192.168.1.100(rw,no_root_squash,no_subtree_check)
```

No space between IP and `(` !

Reload exports:

```bash
sudo exportfs -ra
```

## Verification Checklist

*Ford Prefect says: "Always verify your work. It's the difference between a working system and a very expensive paperweight."*


Before moving to the next lab, ensure:

- [ ] BusyBox compiled and installed with all essential commands
- [ ] Root filesystem directory structure created
- [ ] NFS server configured and exporting nfsroot directory
- [ ] Kernel configured with NFS client and root support
- [ ] BeaglePlay boots with NFS root successfully
- [ ] Shell prompt accessible on serial console
- [ ] /proc, /sys, and /dev mounted correctly
- [ ] `ps`, `free`, `ls` commands working
- [ ] Files created on PC instantly visible on target (NFS live update)
- [ ] Dynamic linking working with shared libraries
- [ ] BusyBox rebuilt dynamically and system still boots
- [ ] Web server running and accessible from PC browser
- [ ] System startup script (rcS) executes on boot

## Going Further (Optional Challenges)

### Challenge 1: Initramfs Boot

**Goal:** Boot from initramfs instead of NFS

**Tasks:**
1. Configure kernel with `CONFIG_INITRAMFS_SOURCE` pointing to nfsroot
2. Create `/init` symlink to `/sbin/init`
3. Rebuild kernel - initramfs will be embedded
4. Boot without NFS (bootargs without nfsroot)

**Hints:**

```bash
cd $HOME/embedded-labs/tinysystem/nfsroot
ln -s sbin/init init

cd $HOME/embedded-labs/kernel/linux
make menuconfig
# General setup → Initramfs source file(s)
# Enter: /home/you/embedded-labs/tinysystem/nfsroot
```

**The Guide notes:** Switch back to NFS root after testing - it's more convenient for development!

### Challenge 2: Custom Init System

**Goal:** Write your own init replacement

**Tasks:**
1. Create a C program that mounts filesystems
2. Spawns a shell
3. Handles reaping zombie processes (wait())
4. Use it instead of BusyBox init

**Hints:**

```c
#include <stdio.h>
#include <sys/mount.h>
#include <unistd.h>

int main(void) {
    mount("proc", "/proc", "proc", 0, NULL);
    mount("sysfs", "/sys", "sysfs", 0, NULL);
    // ... spawn shell with fork()/execve()
    // ... wait() in loop for child processes
}
```

### Challenge 3: Network Configuration Script

**Goal:** Set up networking from init script

**Tasks:**
1. Create `/etc/network/interfaces` config
2. Write script to parse it and configure interfaces
3. Add to rcS
4. Support static IP and DHCP

**Hints:**

BusyBox includes `ifconfig`, `route`, and `udhcpc` (DHCP client).

### Challenge 4: Persistent Storage

**Goal:** Mount SD card partition for persistent storage

**Tasks:**
1. Create mount point `/mnt/data`
2. Add to rcS: `mount /dev/mmcblk0p3 /mnt/data`
3. Create files that survive reboot
4. Handle mount failure gracefully

**Hints:**

Check available partitions: `cat /proc/partitions`

### Challenge 5: System Logging

**Goal:** Implement syslog for system logging

**Tasks:**
1. Enable `CONFIG_SYSLOGD` in BusyBox
2. Configure syslogd in rcS
3. Make kernel log to /var/log/messages
4. Add log rotation

**Hints:**

```bash
mkdir -p /var/log
syslogd -O /var/log/messages
```

## Summary

In this lab, you:

✅ Built BusyBox to provide essential Unix utilities  
✅ Created a minimal root filesystem from scratch  
✅ Set up NFS server for network-based development  
✅ Configured kernel to boot with NFS root  
✅ Created init system with startup scripts  
✅ Mounted virtual filesystems (proc, sysfs, devtmpfs)  
✅ Understood the difference between static and dynamic linking  
✅ Switched BusyBox from static to dynamic to reduce size  
✅ Set up a simple web server on the embedded system  
✅ Experienced the power of NFS root for rapid development  

### Key Takeaways

1. **Root filesystem is essential** - Kernel is useless without userspace
2. **BusyBox is incredibly powerful** - 300+ utilities in one small binary
3. **NFS root accelerates development** - Edit on PC, test instantly on target
4. **Init system can be simple** - Just mount filesystems and spawn shell
5. **Virtual filesystems provide kernel info** - /proc and /sys are invaluable
6. **Dynamic linking saves space** - But requires runtime libraries

### What's Next?

In **Lab 6**, we'll:
- Explore hardware devices in `/dev` and `/sys`
- Control GPIOs and LEDs from userspace
- Use I2C to communicate with sensors
- Add a Nunchuk joystick as an input device
- Compile and load kernel modules
- Modify Device Tree to enable hardware

The system is running - now let's make it interact with hardware!

---

**Estimated completion time:** 3-4 hours  
**Difficulty:** ⭐⭐⭐ (Intermediate)

**Questions?** Refer to:
- [BusyBox Documentation](https://busybox.net/docs/)
- [NFS Documentation](https://linux-nfs.org/wiki/)
- [Linux Filesystem Hierarchy](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html)
