# Lab 26: Crash Dump Analysis with kdump and kexec

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about debugging:

*"Debugging is the art of figuring out why your code doesn't work, as opposed to why you thought it would work. This is similar to the difference between what Deep Thought calculated (42) and what everyone expected (a useful answer). Both are technically correct, but only one is helpful."*

## Objectives

Master crash dump collection with kdump/kexec for post-mortem analysis of kernel panics and system crashes, enabling root cause analysis even when systems are unresponsive.

**What You'll Learn:**
- Configure kexec for fast kernel reboots
- Set up kdump for crash dump collection
- Analyze crash dumps with the crash utility
- Extract useful information from vmcore files
- Automate crash dump collection
- Debug production system failures

**Time Required:** 3-4 hours

---

## Prerequisites

**Hardware:**
- BeaglePlay board
- 2GB+ RAM (kdump reserves memory)
- Development workstation
- Network/USB storage for dumps

**Software:**
- Kernel with kdump/kexec support
- crash utility
- kexec-tools package

---

## 1. Understanding kdump and kexec

### 1.1 What is kexec?

**kexec** allows booting a new kernel from currently running kernel without BIOS/bootloader.

**Use cases:**
- Fast reboots (skip firmware)
- Crash dump collection
- System recovery

**How it works:**
1. Load new kernel into memory
2. When triggered, jump to new kernel
3. New kernel boots (no firmware reset)

### 1.2 What is kdump?

**kdump** uses kexec to boot a crash kernel when primary kernel panics.

**Workflow:**
```
┌─────────────────┐
│ Production      │
│ Kernel Running  │
│ (Reserve memory │
│  for crash)     │
└────────┬────────┘
         │
         │ PANIC!
         ▼
┌─────────────────┐
│ kexec Triggered │
│ Boot Crash      │
│ Kernel          │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Crash Kernel    │
│ - Minimal env   │
│ - Save vmcore   │
│ - Reboot        │
└─────────────────┘
```

### 1.3 Memory Reservation

**BeaglePlay has 2GB RAM:**
- Production kernel: 1.75GB
- Crash kernel: 256MB (reserved at boot)

**Reserved region cannot be used by production kernel.**

---

## 2. Kernel Configuration

### 2.1 Required Configs

**For kexec:**
```
CONFIG_KEXEC=y
CONFIG_KEXEC_FILE=y
```

**For kdump:**
```
CONFIG_CRASH_DUMP=y
CONFIG_PROC_VMCORE=y
CONFIG_SYSFS=y
CONFIG_DEBUG_INFO=y
```

**Additional useful:**
```
CONFIG_RELOCATABLE=y      # Kernel can run at different addresses
CONFIG_RANDOMIZE_BASE=n   # Disable KASLR for easier debugging
```

### 2.2 Enable in Yocto

**In `local.conf`:**
```
KERNEL_FEATURES:append = " features/kexec/kexec-enable.scc"

# Or manually
KERNEL_CONFIG_FRAGMENTS:append = " ${THISDIR}/files/kdump.cfg"
```

**Create `kdump.cfg`:**
```
CONFIG_KEXEC=y
CONFIG_KEXEC_FILE=y
CONFIG_CRASH_DUMP=y
CONFIG_PROC_VMCORE=y
```

### 2.3 Verify Configuration

```bash
cat /boot/config-$(uname -r) | grep -E "KEXEC|CRASH|VMCORE"
```

**Should show:**
```
CONFIG_KEXEC=y
CONFIG_KEXEC_FILE=y
CONFIG_CRASH_DUMP=y
CONFIG_PROC_VMCORE=y
```

---

## 3. Install kdump Tools

### 3.1 Install kexec-tools

**On BeaglePlay:**
```bash
# Buildroot
make menuconfig
# Target packages → System tools → kexec

# Yocto
IMAGE_INSTALL:append = " kexec-tools"

# Debian/Ubuntu
apt-get install kexec-tools makedumpfile crash
```

**Verify:**
```bash
kexec --version
# kexec-tools 2.0.23
```

### 3.2 Install crash Utility

**On workstation (for analysis):**
```bash
sudo apt-get install crash linux-image-$(uname -r)-dbgsym
```

---

## 4. Configure Crash Kernel

### 4.1 Reserve Memory

**Boot parameter method:**

**In U-Boot, edit bootargs:**
```
setenv bootargs "console=ttyS0,115200 root=/dev/mmcblk0p2 crashkernel=256M"
saveenv
```

**Or in device tree:**
```dts
/ {
    reserved-memory {
        crash_dump@80000000 {
            compatible = "shared-dma-pool";
            reg = <0x0 0x80000000 0x0 0x10000000>; // 256MB at 2GB
            no-map;
        };
    };
};
```

### 4.2 Verify Reservation

```bash
dmesg | grep crashkernel
```

**Output:**
```
[    0.000000] Reserving 256MB of memory at 2048MB for crashkernel (System RAM: 2048MB)
```

**Check reserved memory:**
```bash
cat /proc/iomem | grep Crash
```

**Output:**
```
80000000-8fffffff : Crash kernel
```

---

## 5. Load Crash Kernel

### 5.1 Load Kernel and Initrd

**Prepare crash kernel:**
```bash
kexec -p /boot/vmlinuz-$(uname -r) \
      --initrd=/boot/initrd.img-$(uname -r) \
      --append="root=/dev/mmcblk0p2 console=ttyS0,115200 irqpoll maxcpus=1 reset_devices"
```

**Options:**
- `-p`: Load panic kernel
- `--append`: Kernel command line for crash kernel
- `irqpoll`: Poll for interrupts (useful after crash)
- `maxcpus=1`: Use single CPU
- `reset_devices`: Reset devices before crash kernel boots

**Verify loaded:**
```bash
cat /sys/kernel/kexec_crash_loaded
# 1 (loaded), 0 (not loaded)
```

### 5.2 Automatic Loading

**Create systemd service `/etc/systemd/system/kdump.service`:**
```ini
[Unit]
Description=Crash recovery kernel loader
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/kexec -p /boot/vmlinuz-$(uname -r) \
          --initrd=/boot/initrd.img-$(uname -r) \
          --append="root=/dev/mmcblk0p2 console=ttyS0,115200 irqpoll maxcpus=1 reset_devices"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

**Enable:**
```bash
systemctl enable kdump
systemctl start kdump
```

---

## 6. Trigger Test Crash

### 6.1 Trigger Kernel Panic

**Method 1: SysRq trigger**
```bash
echo 1 > /proc/sys/kernel/sysrq
echo c > /proc/sysrq-trigger
```

**Method 2: Kernel module**
```c
#include <linux/module.h>
#include <linux/kernel.h>

static int __init panic_init(void) {
    panic("Test panic for kdump!");
    return 0;
}

module_init(panic_init);
MODULE_LICENSE("GPL");
```

**Load:**
```bash
insmod panic_module.ko
```

### 6.2 Observe Crash Kernel Boot

**Serial console output:**
```
Kernel panic - not syncing: Test panic for kdump!
CPU: 0 PID: 567 Comm: insmod Not tainted 5.10.0 #1
Hardware name: BeaglePlay (DT)
Call trace:
 dump_backtrace+0x0/0x1a0
 show_stack+0x18/0x70
 dump_stack+0xb0/0xfc
 panic+0x140/0x320
 panic_init+0x14/0x1000 [panic_module]
...
---[ end Kernel panic - not syncing: Test panic for kdump! ]---
```

**Then:**
```
kexec: Starting new kernel
Linux version 5.10.0 (crash kernel)
...
```

**Crash kernel boots and saves dump.**

---

## 7. Save Crash Dump

### 7.1 Configure Dump Location

**In crash kernel's initramfs, create script:**

**`/etc/kdump.conf` or init script:**
```bash
#!/bin/sh
# Save vmcore to USB drive

mount /dev/sda1 /mnt
makedumpfile -c -d 31 /proc/vmcore /mnt/vmcore-$(date +%Y%m%d-%H%M%S)
umount /mnt
reboot -f
```

**makedumpfile options:**
- `-c`: Compress dump
- `-d 31`: Filter pages (exclude free pages, cache, etc.)
- Reduces dump size significantly (e.g., 2GB → 200MB)

### 7.2 Dump Filtering

**Filter levels (`-d` flag):**
- `1`: Exclude zero pages
- `2`: Exclude cache pages
- `4`: Exclude user pages
- `8`: Exclude free pages
- `31`: Exclude all above (minimal dump)

**Full dump (no filtering):**
```bash
cp /proc/vmcore /mnt/vmcore
```

---

## 8. Analyze Crash Dump

### 8.1 Transfer Dump to Workstation

```bash
scp beagleplay:/mnt/vmcore-20250115-123456 .
```

### 8.2 Launch crash Utility

```bash
crash vmlinux vmcore-20250115-123456
```

**Output:**
```
crash 7.3.0
Copyright (C) 2002-2021  Red Hat, Inc.

      KERNEL: vmlinux
    DUMPFILE: vmcore-20250115-123456
        CPUS: 4
        DATE: Wed Jan 15 12:34:56 2025
      UPTIME: 00:12:34
LOAD AVERAGE: 0.15, 0.08, 0.03
       TASKS: 95
    NODENAME: beagleplay
     RELEASE: 5.10.0
     VERSION: #1 SMP PREEMPT Wed Jan 15 10:00:00 UTC 2025
     MACHINE: aarch64  (2000 Mhz)
      MEMORY: 2 GB
       PANIC: "Test panic for kdump!"

crash>
```

### 8.3 Examine Crash State

**Show panic message:**
```
crash> log | tail -50
```

**Backtrace of crashing task:**
```
crash> bt
PID: 567    TASK: ffff0000c1234000  CPU: 0   COMMAND: "insmod"
 #0 [ffff800012a3bd00] crash_kexec at ffff800010123456
 #1 [ffff800012a3bd20] __crash_kexec at ffff800010234567
 #2 [ffff800012a3bd40] panic at ffff800010345678
 #3 [ffff800012a3bd80] panic_init at ffff800011456789 [panic_module]
 #4 [ffff800012a3bda0] do_one_initcall at ffff800010567890
 #5 [ffff800012a3bdc0] do_init_module at ffff800010678901
```

**Show process list:**
```
crash> ps
   PID    PPID  CPU       TASK        ST  %MEM     VSZ    RSS  COMM
>    0      0   0  ffff800012345000  RU   0.0       0      0  [swapper/0]
     1      0   1  ffff0000c0001000  IN   0.1    5324   3208  systemd
   567      1   0  ffff0000c1234000  PA   0.2   45632  12048  insmod
```

**`>` marks crashing task.**

### 8.4 Examine Variables

**Show global variables:**
```
crash> p jiffies
jiffies = $1 = 750000
```

**Show struct members:**
```
crash> struct task_struct.comm ffff0000c1234000
  comm = "insmod"
```

**Examine memory:**
```
crash> rd 0xffff800012a3bd00 20
ffff800012a3bd00:  ffff800010123456 ffff800012a3bd20   V.......  ......
ffff800012a3bd10:  0000000000000000 ffff0000c1234000   ........@.#.....
```

### 8.5 Disassemble Code

**At crash location:**
```
crash> dis panic_init
0xffff800011456789 <panic_init>:        stp     x29, x30, [sp,#-16]!
0xffff80001145678d <panic_init+4>:      mov     x29, sp
0xffff800011456791 <panic_init+8>:      adrp    x0, 0xffff800011457000
0xffff800011456795 <panic_init+12>:     add     x0, x0, #0x123
0xffff800011456799 <panic_init+16>:     bl      0xffff800010345678 <panic>
```

---

## 9. Advanced crash Commands

### 9.1 Analyze Locks

**Show held locks:**
```
crash> lock_stat
```

**Blocked tasks:**
```
crash> ps -m
# Shows tasks in uninterruptible sleep (blocked on locks/I/O)
```

### 9.2 Network State

**Show network connections:**
```
crash> net
```

**Socket buffers:**
```
crash> net -s
```

### 9.3 File System State

**Open files:**
```
crash> files 567
```

**Mounted filesystems:**
```
crash> mount
```

---

## 10. Automate Crash Analysis

### 10.1 crash Script

**Create `analyze.crash`:**
```
log | tail -100
bt
ps
files
sys
quit
```

**Run:**
```bash
crash -i analyze.crash vmlinux vmcore > crash-report.txt
```

### 10.2 Python Script for Multiple Dumps

**Create `batch_analyze.sh`:**
```bash
#!/bin/bash

for vmcore in vmcore-*; do
    echo "=== Analyzing $vmcore ===" >> analysis.log
    crash -i analyze.crash vmlinux "$vmcore" >> analysis.log 2>&1
done
```

---

## 11. Production Deployment

### 11.1 Automated Dump Collection

**Create `/etc/init.d/kdump-save` (initramfs):**
```bash
#!/bin/sh

DUMP_PATH="/var/crash"
DUMP_FILE="vmcore-$(cat /proc/sys/kernel/hostname)-$(date +%Y%m%d-%H%M%S)"

# Mount persistent storage
mount /dev/sda1 /mnt || {
    echo "Failed to mount dump storage"
    exit 1
}

# Save dump
makedumpfile -c -d 31 /proc/vmcore "/mnt/$DUMP_FILE" || {
    echo "makedumpfile failed"
    umount /mnt
    exit 1
}

# Save kernel log
dmesg > "/mnt/$DUMP_FILE.log"

umount /mnt
reboot -f
```

### 11.2 Remote Dump Upload

**Upload to server:**
```bash
# In crash kernel
nc dump-server.local 9999 < /proc/vmcore

# On server
nc -l 9999 > vmcore-$(date +%Y%m%d-%H%M%S)
```

---

## 12. Troubleshooting

### 12.1 Crash Kernel Fails to Load

**Error:** "Cannot allocate memory"

**Solution:**
- Increase `crashkernel=` reservation
- Check physical memory availability

**Error:** "Invalid argument"

**Solution:**
- Verify kernel has `CONFIG_KEXEC=y`
- Check kernel/initrd paths

### 12.2 No vmcore Generated

**Check:**
1. `/proc/vmcore` exists in crash kernel?
2. Crash kernel has write access to dump location?
3. Sufficient disk space?

**Debug crash kernel:**
- Add `debug` to crash kernel command line
- View serial console output

---

## 13. Performance Considerations

### 13.1 Memory Overhead

**BeaglePlay with 2GB RAM:**
- `crashkernel=256M`: 12.5% overhead
- Consider smaller dump (128M) if memory-constrained
- Use `makedumpfile -d 31` to minimize required space

### 13.2 Dump Time

**Factors:**
- Dump size (compressed: faster)
- Storage speed (USB 2.0 vs SD card)
- Filter level (higher = faster)

**Typical times:**
- Full 2GB dump: 5-10 minutes
- Filtered to 200MB: 1-2 minutes

---

## 14. Key Takeaways

**Accomplished:**
1. ✅ Configured kdump and kexec
2. ✅ Reserved memory for crash kernel
3. ✅ Triggered test crashes
4. ✅ Collected and analyzed crash dumps
5. ✅ Used crash utility for post-mortem analysis
6. ✅ Automated dump collection

**Essential Commands:**
- `kexec -p vmlinuz`: Load crash kernel
- `echo c > /proc/sysrq-trigger`: Trigger test crash
- `makedumpfile -c -d 31`: Create compressed dump
- `crash vmlinux vmcore`: Analyze dump

**Workflow:**
1. Configure and load crash kernel at boot
2. When panic occurs, kexec boots crash kernel
3. Crash kernel saves vmcore and reboots
4. Analyze vmcore with crash utility

---

## 15. Verification Checklist

- [ ] Can reserve memory for crash kernel
- [ ] Can load crash kernel with kexec
- [ ] Can trigger test panic
- [ ] Crash kernel boots and saves dump
- [ ] Can analyze dump with crash utility
- [ ] Understand crash commands (bt, ps, log)

---

**End of Lab 26**

*The Guide rates this lab: **Mostly Harmless** ⭐⭐⭐⭐*

kdump and kexec provide the ultimate safety net for production systems. Even when a kernel panic makes the system unresponsive, kdump ensures you can collect a complete crash dump for root cause analysis, turning mysterious failures into debuggable problems.

---

## 🎉 Congratulations! 🎉

**You have completed the entire Linux Debugging track!**

**26 Labs Completed:**
- **Labs 1-9**: Embedded Linux Fundamentals
- **Labs 10-18**: Yocto Project Development
- **Labs 19-26**: Advanced Debugging and Performance Analysis

**Skills Acquired:**
- ✅ System monitoring and resource analysis
- ✅ Application debugging with GDB
- ✅ System call and library tracing
- ✅ Memory debugging with Valgrind
- ✅ Performance profiling (perf, ftrace, flame graphs)
- ✅ eBPF and BCC for custom tracing
- ✅ Kernel debugging (KGDB, OOPS analysis, lockdep)
- ✅ Crash dump analysis (kdump, crash utility)

**You are now equipped to:**
- Debug the most challenging embedded Linux issues
- Optimize system and application performance
- Analyze production crashes and kernel panics
- Build robust, high-performance embedded systems

**Thank you for completing this comprehensive training!** 🚀
