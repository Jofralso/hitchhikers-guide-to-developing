# Lab 25: Kernel Debugging and OOPS Analysis

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about the Linux kernel:

*"The Linux kernel is the brain of your embedded system. Unlike certain galactic presidents, it's actually quite good at multitasking, managing hardware, and not generally causing chaos. Though both occasionally crash when faced with infinite improbability."*

## Objectives

Master kernel debugging techniques including KGDB for interactive debugging, analyzing kernel OOPS messages, using kernel debugging configs, and detecting kernel bugs with sanitizers.

**What You'll Learn:**
- Analyze kernel OOPS and panic messages
- Use KGDB for interactive kernel debugging
- Enable kernel debugging options (PROVE_LOCKING, DEBUG_ATOMIC_SLEEP)
- Detect memory leaks with kmemleak
- Debug deadlocks and race conditions
- Understand kernel stack traces

**Time Required:** 4-5 hours

---

## Prerequisites

**Hardware:**
- BeaglePlay board
- USB-to-Serial adapter (for KGDB)
- Development workstation

**Software:**
- Kernel compiled with debugging symbols
- GDB with ARM64 support
- Serial console access

---

## 1. Understanding Kernel OOPS

### 1.1 What is a Kernel OOPS?

**OOPS** = kernel detected internal error but can continue running.
**Panic** = fatal error, kernel halts.

**Common causes:**
- NULL pointer dereference
- Invalid memory access
- Stack corruption
- Division by zero in kernel code

### 1.2 Example OOPS Message

**Trigger OOPS with buggy module:**

**Create `oops_module.c`:**
```c
#include <linux/module.h>
#include <linux/kernel.h>

static int __init oops_init(void) {
    int *ptr = NULL;
    printk(KERN_INFO "About to OOPS...\n");
    *ptr = 42;  // NULL pointer dereference!
    return 0;
}

static void __exit oops_exit(void) {
    printk(KERN_INFO "Exiting (never reached)\n");
}

module_init(oops_init);
module_exit(oops_exit);
MODULE_LICENSE("GPL");
```

**Makefile:**
```makefile
obj-m += oops_module.o

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
```

**Build and load:**
```bash
make
sudo insmod oops_module.ko
```

**OOPS output:**
```
Unable to handle kernel NULL pointer dereference at virtual address 0000000000000000
Mem abort info:
  ESR = 0x96000045
  EC = 0x25: DABT (current EL), IL = 32 bits
  SET = 0, FnV = 0
  EA = 0, S1PTW = 0
Data abort info:
  ISV = 0, ISS = 0x00000045
  CM = 0, WnR = 1
user pgtable: 4k pages, 48-bit VAs, pgdp=000000008a123000
[0000000000000000] pgd=0000000000000000, p4d=0000000000000000
Internal error: Oops: 96000045 [#1] SMP
Modules linked in: oops_module(O+) [last unloaded: oops_module]
CPU: 0 PID: 567 Comm: insmod Tainted: G           O      5.10.0 #1
Hardware name: BeaglePlay (DT)
pstate: 60000005 (nZCv daif -PAN -UAO -TCO BTYPE=--)
pc : oops_init+0x14/0x1000 [oops_module]
lr : do_one_initcall+0x50/0x230
sp : ffff800012a3bd10
x29: ffff800012a3bd10 x28: 0000000000000000 
x27: ffff0000c1234000 x26: ffff800011234000
...
Call trace:
 oops_init+0x14/0x1000 [oops_module]
 do_one_initcall+0x50/0x230
 do_init_module+0x60/0x240
 load_module+0x1abc/0x1d00
 __do_sys_finit_module+0xac/0x100
 __arm64_sys_finit_module+0x20/0x30
 el0_svc_common.constprop.0+0x78/0x1c0
 do_el0_svc+0x24/0x90
 el0_svc+0x14/0x20
 el0_sync_handler+0xb0/0xc0
 el0_sync+0x180/0x1c0
Code: d2800000 d503201f 910003fd f9001fe0 (b9000000)
---[ end trace 123456789abcdef ]---
```

### 1.3 Decode OOPS

**Key information:**
1. **Fault address**: `0000000000000000` (NULL)
2. **PC** (Program Counter): `oops_init+0x14` (crash location)
3. **Call trace**: Shows function call chain
4. **Tainted**: `O` = out-of-tree module
5. **Code**: Bytes at crash site

**Decode with addr2line:**
```bash
addr2line -e oops_module.ko oops_init+0x14
# oops_module.c:7
```

**Shows line 7:** `*ptr = 42;`

---

## 2. Kernel Debugging Configuration

### 2.1 Essential Debug Configs

**In kernel `.config`:**
```
# Basic debugging
CONFIG_DEBUG_KERNEL=y
CONFIG_DEBUG_INFO=y
CONFIG_DEBUG_INFO_DWARF4=y

# Stack traces
CONFIG_STACKTRACE=y
CONFIG_FRAME_POINTER=y

# Memory debugging
CONFIG_SLUB_DEBUG=y
CONFIG_DEBUG_KMEMLEAK=y

# Lock debugging
CONFIG_PROVE_LOCKING=y
CONFIG_DEBUG_ATOMIC_SLEEP=y
CONFIG_DEBUG_MUTEXES=y
CONFIG_DEBUG_SPINLOCK=y

# Additional checks
CONFIG_DEBUG_LIST=y
CONFIG_DEBUG_OBJECTS=y
CONFIG_DEBUG_VM=y
```

### 2.2 Enable in Yocto

**In `local.conf` or machine config:**
```
KERNEL_DEBUG_ENABLE = "1"
KERNEL_FEATURES:append = " features/debug/printk.scc features/debug/debug-kernel.scc"
```

**Or manually:**
```bash
bitbake -c menuconfig virtual/kernel
# Kernel hacking → [*] Kernel debugging
```

### 2.3 Enable in Buildroot

```bash
make linux-menuconfig
# Kernel hacking → [*] Kernel debugging
```

---

## 3. Lock Debugging

### 3.1 PROVE_LOCKING (Lockdep)

**Detects:**
- Lock inversion (AB-BA deadlock)
- Lock held too long
- Incorrect lock usage

**Example deadlock:**
```c
// Thread 1:
mutex_lock(&lock_a);
mutex_lock(&lock_b);  // AB order
mutex_unlock(&lock_b);
mutex_unlock(&lock_a);

// Thread 2:
mutex_lock(&lock_b);
mutex_lock(&lock_a);  // BA order - DEADLOCK!
mutex_unlock(&lock_a);
mutex_unlock(&lock_b);
```

**Lockdep output:**
```
======================================================
WARNING: possible circular locking dependency detected
======================================================
task_a/567 is trying to acquire lock:
ffff0000c1234000 (lock_b){+.+.}, at: thread_func+0x34/0x100

but task is already holding lock:
ffff0000c5678000 (lock_a){+.+.}, at: thread_func+0x24/0x100

which lock already depends on the new lock:

the existing dependency chain (in reverse order) is:
-> #1 (lock_a){+.+.}:
       lock_acquire+0xd0/0x200
       _mutex_lock+0x80/0x100
       thread_func+0x24/0x100
       
-> #0 (lock_b){+.+.}:
       lock_acquire+0xd0/0x200
       _mutex_lock+0x80/0x100
       thread_func+0x34/0x100
```

**Fix:** Always acquire locks in same order.

### 3.2 DEBUG_ATOMIC_SLEEP

**Detects sleeping in atomic context:**
```c
spinlock_lock(&my_lock);  // Atomic context
msleep(100);              // BUG: Sleep in atomic!
spinlock_unlock(&my_lock);
```

**Error message:**
```
BUG: sleeping function called from invalid context at kernel/time/timer.c:1234
in_atomic(): 1, irqs_disabled(): 0, pid: 567, name: my_task
```

---

## 4. Memory Leak Detection with kmemleak

### 4.1 Enable kmemleak

**Kernel config:**
```
CONFIG_DEBUG_KMEMLEAK=y
```

**Boot parameter:**
```
# In bootargs
kmemleak=on
```

### 4.2 Trigger Scan

**Create leaky module:**
```c
#include <linux/module.h>
#include <linux/slab.h>

static int __init leak_init(void) {
    void *ptr = kmalloc(1024, GFP_KERNEL);
    printk("Allocated but not freed: %p\n", ptr);
    // Missing kfree(ptr)!
    return 0;
}

module_init(leak_init);
MODULE_LICENSE("GPL");
```

**Load module:**
```bash
insmod leak_module.ko
```

**Scan for leaks:**
```bash
echo scan > /sys/kernel/debug/kmemleak
cat /sys/kernel/debug/kmemleak
```

**Output:**
```
unreferenced object 0xffff0000c1234000 (size 1024):
  comm "insmod", pid 567, jiffies 4294937296 (age 123.456s)
  hex dump (first 32 bytes):
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
  backtrace:
    [<ffff800010123456>] kmalloc_trace+0x80/0x100
    [<ffff800011234567>] leak_init+0x20/0x1000 [leak_module]
    [<ffff800010345678>] do_one_initcall+0x50/0x230
```

**Shows allocation backtrace** to find leak source.

---

## 5. Interactive Kernel Debugging with KGDB

### 5.1 Configure KGDB

**Kernel config:**
```
CONFIG_KGDB=y
CONFIG_KGDB_SERIAL_CONSOLE=y
CONFIG_MAGIC_SYSRQ=y
```

**Boot parameters:**
```
kgdboc=ttyS0,115200 kgdbwait
```

**Options:**
- `kgdboc`: KGDB over console (serial port)
- `kgdbwait`: Wait for debugger at boot

### 5.2 Connect GDB

**On BeaglePlay (boots and waits):**
```
KGDB: Waiting for connection from remote gdb...
```

**On workstation:**
```bash
gdb vmlinux
```

**In GDB:**
```gdb
(gdb) target remote /dev/ttyUSB0
Remote debugging using /dev/ttyUSB0
0xffff800010123456 in default_idle ()

(gdb) bt
#0  0xffff800010123456 in default_idle ()
#1  0xffff800010234567 in arch_cpu_idle ()
#2  0xffff800010345678 in do_idle ()
```

### 5.3 Set Breakpoints

```gdb
(gdb) break sys_read
Breakpoint 1 at 0xffff800010456789: file fs/read.c, line 123.

(gdb) continue
```

**On BeaglePlay, trigger syscall:**
```bash
cat /etc/hostname
```

**GDB hits breakpoint:**
```gdb
Breakpoint 1, sys_read (fd=3, buf=0xfffffffff8, count=1024) at fs/read.c:123
123	    if (fd < 0) return -EBADF;
```

### 5.4 Examine Kernel State

```gdb
(gdb) print current->comm
$1 = "cat"

(gdb) print current->pid
$2 = 567

(gdb) x/20i $pc
# Disassemble current location
```

---

## 6. Magic SysRq for Debugging

### 6.1 Enable Magic SysRq

**Boot parameter:**
```
sysrq_always_enabled=1
```

**Or at runtime:**
```bash
echo 1 > /proc/sys/kernel/sysrq
```

### 6.2 Useful SysRq Commands

**Via serial console:**
```
Alt+SysRq+<key>
```

**Or via /proc:**
```bash
echo <key> > /proc/sysrq-trigger
```

**Common keys:**
- **t**: Dump task states (all processes)
- **m**: Dump memory info
- **w**: Dump blocked (waiting) tasks
- **l**: Dump all CPUs' backtraces
- **p**: Dump registers
- **s**: Sync filesystems
- **u**: Remount read-only
- **b**: Reboot immediately

**Example - show all tasks:**
```bash
echo t > /proc/sysrq-trigger
dmesg | tail -100
```

**Output:**
```
bash            S 567     1  0x00000000
Call trace:
 __switch_to+0x80/0x100
 schedule+0x50/0x100
 schedule_timeout+0x80/0x150
 wait_for_completion+0x90/0x120
```

---

## 7. Crash Dump Analysis

### 7.1 Decode Code Bytes

**From OOPS:**
```
Code: d2800000 d503201f 910003fd f9001fe0 (b9000000)
```

**Disassemble:**
```bash
echo "d2800000 d503201f 910003fd f9001fe0 b9000000" | \
  xxd -r -p | \
  aarch64-linux-gnu-objdump -D -b binary -m aarch64 -
```

**Output:**
```
   0:	d2800000 	mov	x0, #0x0
   4:	d503201f 	nop
   8:	910003fd 	mov	x29, sp
   c:	f9001fe0 	str	x0, [sp, #56]
  10:	b9000000 	str	w0, [x0]  ← Crash here (store to x0=NULL)
```

### 7.2 Analyze with crash Utility

**Install crash:**
```bash
sudo apt-get install crash
```

**Analyze vmcore:**
```bash
crash vmlinux vmcore
```

**Commands:**
```
crash> bt       # Backtrace
crash> ps       # Process list
crash> log      # Kernel log
crash> files    # Open files
crash> vm       # Virtual memory
```

---

## 8. Debugging Kernel Modules

### 8.1 Load Module with Debug Symbols

**Build module with debug:**
```makefile
EXTRA_CFLAGS := -g -O0
```

**Load module:**
```bash
insmod my_module.ko
```

**Find module load address:**
```bash
cat /sys/module/my_module/sections/.text
# 0xffff800012340000
```

**In GDB:**
```gdb
(gdb) add-symbol-file my_module.ko 0xffff800012340000
(gdb) break my_module_function
```

### 8.2 printk Debugging

**Traditional but effective:**
```c
printk(KERN_DEBUG "my_func: value=%d\n", value);
```

**View output:**
```bash
dmesg | grep my_func
```

**Dynamic debug (preferred):**
```c
pr_debug("my_func: value=%d\n", value);
```

**Enable at runtime:**
```bash
echo 'module my_module +p' > /sys/kernel/debug/dynamic_debug/control
```

---

## 9. Real-World Debugging Example

### 9.1 Scenario: System Hangs

**Symptoms:** System becomes unresponsive.

**Step 1: Check if kernel is alive**
```bash
# Via SysRq
echo l > /proc/sysrq-trigger
# If this works, kernel is running
```

**Step 2: Dump all tasks**
```bash
echo t > /proc/sysrq-trigger
dmesg > /tmp/tasks.log
```

**Step 3: Find blocked tasks**
```bash
echo w > /proc/sysrq-trigger
```

**Output:**
```
task                PC      stack   pid father
my_daemon       D    0   567    1 0x00000000
Call trace:
 __switch_to+0x80/0x100
 schedule+0x50/0x100
 mutex_lock+0x40/0x80        ← Waiting for mutex
 my_driver_ioctl+0x30/0x100
 ksys_ioctl+0x80/0x120
```

**Analysis:** `my_daemon` stuck waiting for mutex in driver.

**Step 4: Check lock holder**
```bash
# If PROVE_LOCKING enabled
cat /proc/lockdep
```

### 9.2 Fix and Verify

**Add debug output to driver:**
```c
pr_debug("Acquiring lock...\n");
mutex_lock(&driver_lock);
pr_debug("Lock acquired\n");
```

**Enable dynamic debug and reproduce.**

---

## 10. Kernel Sanitizers

### 10.1 KASAN (Kernel Address Sanitizer)

**Detects:**
- Use-after-free
- Out-of-bounds access
- Double-free

**Enable:**
```
CONFIG_KASAN=y
```

**Example detection:**
```
BUG: KASAN: use-after-free in my_func+0x80/0x100
Write of size 4 at addr ffff0000c1234000 by task my_task/567

Allocated by task 567:
 kasan_save_stack+0x20/0x40
 __kasan_kmalloc+0x80/0xa0
 my_func+0x20/0x100

Freed by task 567:
 kasan_save_stack+0x20/0x40
 kasan_set_free_info+0x20/0x30
 __kasan_slab_free+0x100/0x130
 kfree+0x80/0x200
 my_func+0x60/0x100
```

### 10.2 UBSAN (Undefined Behavior Sanitizer)

**Detects:**
- Integer overflow
- Null pointer arithmetic
- Out-of-bounds array access

**Enable:**
```
CONFIG_UBSAN=y
```

---

## 11. Troubleshooting Tips

### 11.1 System Won't Boot

**Serial console shows panic:**
1. Note panic message and call trace
2. Check if related to recent kernel/driver change
3. Revert change or add debug output
4. Use `initcall_debug` boot param to see init sequence

### 11.2 Intermittent Crashes

**Hard to reproduce:**
1. Enable all debug options
2. Add extensive logging
3. Use stress testing tools
4. Consider race condition (add locking debug)

---

## 12. Key Takeaways

**Accomplished:**
1. ✅ Decoded kernel OOPS messages
2. ✅ Enabled kernel debug configs
3. ✅ Used KGDB for interactive debugging
4. ✅ Detected memory leaks with kmemleak
5. ✅ Debugged deadlocks with lockdep
6. ✅ Analyzed crashes with Magic SysRq

**Essential Skills:**
- Read and understand kernel stack traces
- Use addr2line to find crash source
- Enable appropriate debug configs
- Use Magic SysRq for hung systems

**Next Steps:**
- **Lab 26**: kdump and kexec for crash dumps

---

## 13. Verification Checklist

- [ ] Can decode kernel OOPS messages
- [ ] Understand kernel debug configs
- [ ] Can use KGDB for debugging
- [ ] Can detect memory leaks
- [ ] Can debug deadlocks
- [ ] Can use Magic SysRq commands

---

**End of Lab 25**

*The Guide rates this lab: **Mostly Harmless** ⭐⭐⭐⭐*

Kernel debugging is essential for developing robust drivers and system software. Understanding OOPS messages, using debug configs, and leveraging KGDB enables you to diagnose even the most challenging kernel issues.
