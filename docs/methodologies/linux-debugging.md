# Linux Debugging Methodology

## DON'T PANIC

The Guide has this to say about debugging:

*"Debugging is the art of determining why your code doesn't do what you thought you told it to do. It's a bit like being a detective, except the crime scene is a memory dump, the suspects are all pointers, and the smoking gun is usually a missing semicolon three files away from where the actual problem manifests."*

---

## Overview

This methodology provides a systematic approach to debugging Linux systems and applications, from user-space programs to kernel-level issues.

## The Debugging Mindset

### Core Principles

1. **Reproduce First**: If you can't reproduce it, you can't fix it
2. **Isolate the Problem**: Binary search through complexity
3. **Understand Before Changing**: Random changes rarely fix issues
4. **One Change at a Time**: Multiple changes obscure causation
5. **Document Everything**: Future you will thank present you

### The Guide's Debugging Hierarchy

```
Level 1: Print Debugging    ← "Is it plugged in?"
Level 2: Interactive GDB    ← "Let's talk to the code"
Level 3: System Tracing     ← "What is the system actually doing?"
Level 4: Performance Tools  ← "Why is it slow?"
Level 5: Kernel Debugging   ← "The Matrix has you..."
```

---

## User-Space Debugging

### Level 1: Printf Debugging

**When to use**: Initial investigation, quick checks

**Technique**:
```c
printf("DEBUG: Entering function foo(), value=%d\n", value);
printf("DEBUG: After malloc, ptr=%p\n", ptr);
printf("DEBUG: Before critical section\n");
```

**Best Practices**:
- Prefix with `DEBUG:` for easy filtering
- Include variable values
- Add timestamps for timing issues
- Use conditional compilation for production

```c
#ifdef DEBUG
#define DBG_PRINT(fmt, ...) \
    printf("[DEBUG %s:%d] " fmt "\n", __FILE__, __LINE__, ##__VA_ARGS__)
#else
#define DBG_PRINT(fmt, ...)
#endif
```

---

### Level 2: GDB (GNU Debugger)

**When to use**: Crashes, segfaults, logic errors

#### Basic Workflow

```bash
# Compile with debug symbols
gcc -g -o myapp myapp.c

# Run in GDB
gdb ./myapp

# GDB commands
(gdb) run                    # Start program
(gdb) break main             # Set breakpoint
(gdb) break myfile.c:42      # Break at line
(gdb) continue               # Continue execution
(gdb) next                   # Step over
(gdb) step                   # Step into
(gdb) print variable         # Show value
(gdb) backtrace             # Call stack
(gdb) info locals           # Local variables
```

#### Advanced Techniques

**Conditional Breakpoints**:
```gdb
break myfunction if count > 100
```

**Watchpoints** (break when variable changes):
```gdb
watch my_variable
```

**Catchpoints** (break on events):
```gdb
catch throw              # C++ exception
catch syscall open       # System call
```

#### Remote Debugging (Cross-Development)

On target (BeaglePlay):
```bash
gdbserver :2345 ./myapp
```

On host:
```bash
aarch64-linux-gnu-gdb ./myapp
(gdb) target remote beagleplay.local:2345
(gdb) continue
```

---

### Level 3: Core Dumps

**Enable core dumps**:
```bash
ulimit -c unlimited
```

**Analyze crash**:
```bash
gdb ./myapp core
(gdb) backtrace
(gdb) info registers
(gdb) disassemble
```

**Automated core dump analysis**:
```bash
# Set core pattern
echo "/var/crash/core.%e.%p" | sudo tee /proc/sys/kernel/core_pattern

# Analyze automatically
gdb -batch -ex "thread apply all bt" ./myapp /var/crash/core.myapp.1234
```

---

### Level 4: System Call Tracing

#### strace (System Call Tracer)

**Basic usage**:
```bash
# Trace all system calls
strace ./myapp

# Follow forks
strace -f ./myapp

# Time each call
strace -T ./myapp

# Count calls
strace -c ./myapp

# Filter specific calls
strace -e open,read,write ./myapp

# Attach to running process
strace -p PID
```

**Common patterns**:
```bash
# Find missing files
strace -e openat ./myapp 2>&1 | grep ENOENT

# Network debugging
strace -e socket,connect,send,recv ./myapp

# Performance issues
strace -T -e trace=file ./myapp 2>&1 | grep -v "< 0.00"
```

#### ltrace (Library Call Tracer)

```bash
# Trace library calls
ltrace ./myapp

# Specific libraries
ltrace -l libmylib.so ./myapp
```

---

### Level 5: Memory Debugging

#### Valgrind

**Memory leak detection**:
```bash
valgrind --leak-check=full --show-leak-kinds=all ./myapp
```

**Use-after-free detection**:
```bash
valgrind --track-origins=yes ./myapp
```

**Cache profiling**:
```bash
valgrind --tool=cachegrind ./myapp
kcachegrind cachegrind.out.PID
```

**Heap profiling**:
```bash
valgrind --tool=massif ./myapp
ms_print massif.out.PID
```

#### AddressSanitizer (ASan)

**Compile with ASan**:
```bash
gcc -fsanitize=address -g -o myapp myapp.c
./myapp
```

**Detects**:
- Use-after-free
- Heap buffer overflow
- Stack buffer overflow
- Global buffer overflow
- Use-after-return
- Memory leaks

---

## Kernel-Space Debugging

### Level 1: Kernel Logs (dmesg)

```bash
# View all messages
dmesg

# Follow new messages
dmesg -w

# Filter by level
dmesg -l err,warn

# Clear buffer
dmesg -C

# Show timestamps
dmesg -T
```

**Add custom kernel messages**:
```c
printk(KERN_INFO "Module loaded\n");
printk(KERN_DEBUG "Debug info: value=%d\n", value);
pr_info("Simpler syntax\n");
```

### Level 2: Dynamic Debug

**Enable dynamic debug**:
```bash
# At boot
echo "module mymodule +p" > /sys/kernel/debug/dynamic_debug/control

# Runtime
echo "file myfile.c +p" > /sys/kernel/debug/dynamic_debug/control
echo "func myfunction +p" > /sys/kernel/debug/dynamic_debug/control
```

---

### Level 3: ftrace (Function Tracer)

**Basic function tracing**:
```bash
cd /sys/kernel/debug/tracing

# Set tracer
echo function > current_tracer

# Enable tracing
echo 1 > tracing_on

# View trace
cat trace

# Disable
echo 0 > tracing_on
```

**Function graph**:
```bash
echo function_graph > current_tracer
echo 1 > tracing_on
cat trace
```

**Event tracing**:
```bash
# List available events
cat available_events

# Enable specific event
echo 1 > events/syscalls/sys_enter_open/enable

# Filter
echo 'filename == "/etc/passwd"' > events/syscalls/sys_enter_open/filter
```

---

### Level 4: perf (Performance Analysis)

**Record system-wide events**:
```bash
# Record for 10 seconds
perf record -a sleep 10

# Analyze
perf report

# Call graph
perf record -g -a sleep 10
perf report -g
```

**CPU sampling**:
```bash
# Sample on-CPU functions
perf record -F 99 -a -g -- sleep 30
perf report
```

**Hardware events**:
```bash
# Cache misses
perf stat -e cache-misses,cache-references ./myapp

# Branch mispredictions
perf stat -e branches,branch-misses ./myapp
```

**Flame graphs**:
```bash
perf record -F 99 -a -g -- sleep 30
perf script | stackcollapse-perf.pl | flamegraph.pl > flame.svg
```

---

### Level 5: KGDB (Kernel GDB)

**Setup**:

1. Kernel config:
```
CONFIG_KGDB=y
CONFIG_KGDB_SERIAL_CONSOLE=y
```

2. Boot with:
```
kgdbwait kgdboc=ttyS0,115200
```

3. Connect from host:
```bash
aarch64-linux-gnu-gdb vmlinux
(gdb) target remote /dev/ttyUSB0
(gdb) continue
```

**Debug kernel panic**:
```bash
# Trigger KGDB on panic
echo 1 > /proc/sys/kernel/panic_on_oops

# Manually enter KGDB
echo g > /proc/sysrq-trigger
```

---

### Level 6: Crash Analysis (kdump/kexec)

**Setup kdump**:
```bash
# Reserve memory
# Add to kernel cmdline: crashkernel=256M

# Install tools
sudo apt install kdump-tools

# Configure
sudo vi /etc/default/kdump-tools
# USE_KDUMP=1

# Test
echo c > /proc/sysrq-trigger
```

**Analyze crash dump**:
```bash
crash /usr/lib/debug/boot/vmlinux-$(uname -r) /var/crash/dump
crash> bt                  # Backtrace
crash> ps                  # Process list
crash> log                # Kernel log
crash> dis                # Disassemble
```

---

## Performance Debugging

### CPU Profiling

**Find CPU hogs**:
```bash
top                        # Interactive
htop                       # Better interactive
pidstat -p PID 1          # Per-process stats
```

**Profile application**:
```bash
perf record ./myapp
perf report
```

### I/O Profiling

**Block I/O**:
```bash
iostat -x 1               # I/O statistics
iotop                     # I/O per process
blktrace /dev/sda         # Block layer tracing
```

**File I/O**:
```bash
strace -T -e open,read,write,close ./myapp
```

### Network Profiling

**Connections**:
```bash
ss -tunapl                # All connections
netstat -tulpn            # Listening ports
```

**Traffic**:
```bash
tcpdump -i eth0           # Packet capture
iftop                     # Bandwidth per connection
nethogs                   # Per-process bandwidth
```

---

## Debugging Strategies

### The Binary Search Approach

1. **Identify working version**: `git bisect start`
2. **Mark bad commit**: `git bisect bad`
3. **Mark good commit**: `git bisect good v1.0`
4. **Test each**: Build and test
5. **Repeat**: `git bisect good/bad`
6. **Find culprit**: Git identifies exact commit

### The Rubber Duck Method

Explain your code line-by-line to a rubber duck (or colleague). Often reveals the issue through verbalization.

### The Divide and Conquer

1. **Reproduce reliably**
2. **Minimize test case**: Remove unrelated code
3. **Binary search**: Comment out half, test, repeat
4. **Isolate**: Find minimal reproducer

### The Scientific Method

1. **Observe**: Gather data
2. **Hypothesize**: Form theory
3. **Predict**: What should happen if theory is correct?
4. **Test**: Does prediction match reality?
5. **Repeat**: Refine hypothesis

---

## Common Issues & Solutions

### Segmentation Fault

**Diagnosis**:
```bash
gdb ./myapp
(gdb) run
# Crash occurs
(gdb) backtrace
(gdb) print ptr        # Check pointer values
```

**Common causes**:
- Null pointer dereference
- Use-after-free
- Buffer overflow
- Stack overflow

### Memory Leak

**Detection**:
```bash
valgrind --leak-check=full ./myapp
```

**Fix patterns**:
```c
// Always pair malloc/free
ptr = malloc(size);
// ... use ptr ...
free(ptr);
ptr = NULL;

// RAII in C++
std::unique_ptr<T> ptr(new T);
// Automatic cleanup
```

### Race Condition

**Detection**:
```bash
# Thread sanitizer
gcc -fsanitize=thread -g -o myapp myapp.c
./myapp

# Helgrind (Valgrind)
valgrind --tool=helgrind ./myapp
```

**Prevention**:
- Use mutexes for shared data
- Minimize shared state
- Lock ordering discipline
- Consider lock-free algorithms

### Deadlock

**Detection**:
```bash
# GDB: Attach and check threads
gdb -p PID
(gdb) info threads
(gdb) thread apply all bt
```

**Prevention**:
- Always acquire locks in same order
- Use lock hierarchies
- Timeout on lock acquisition
- Lock-free data structures

---

## Debugging Checklist

### Before You Start

- [ ] Can you reproduce the issue?
- [ ] Do you have debug symbols? (`-g`)
- [ ] Do you have a minimal test case?
- [ ] Have you checked recent changes?
- [ ] Have you read the error message carefully?

### During Debugging

- [ ] One change at a time
- [ ] Document what you try
- [ ] Test after each change
- [ ] Use version control
- [ ] Take breaks (fresh perspective)

### After Fixing

- [ ] Understand root cause
- [ ] Add test to prevent regression
- [ ] Document in comments/commit message
- [ ] Consider if similar issues exist elsewhere
- [ ] Share knowledge with team

---

## Tools Reference

### Essential Tools

| Tool | Purpose | Platforms |
|------|---------|-----------|
| `gdb` | Interactive debugger | User/Kernel |
| `strace` | System call trace | User |
| `ltrace` | Library call trace | User |
| `valgrind` | Memory debugging | User |
| `perf` | Performance analysis | User/Kernel |
| `ftrace` | Function tracing | Kernel |
| `dmesg` | Kernel messages | Kernel |
| `crash` | Crash dump analysis | Kernel |

### Compiler Flags

```bash
-g              # Debug symbols
-g3             # Extra debug info
-ggdb           # GDB-specific debug info
-O0             # No optimization (easier debugging)
-Wall           # All warnings
-Wextra         # Extra warnings
-Werror         # Warnings as errors
-fsanitize=address     # Address sanitizer
-fsanitize=thread      # Thread sanitizer
-fsanitize=undefined   # Undefined behavior sanitizer
```

---

## Advanced Topics

### eBPF Debugging

```bash
# Install bcc-tools
sudo apt install bpfcc-tools

# Trace syscalls
sudo trace-bpfcc 'p:syscalls:sys_enter_open'

# Profile stack traces
sudo profile-bpfcc -F 99 -f 5
```

### Kernel Oops Analysis

```
# Example oops
Unable to handle kernel NULL pointer dereference at virtual address 00000000
PC is at my_function+0x20/0x60
LR is at calling_function+0x40/0x80
```

**Analysis**:
1. Note the function (`my_function`)
2. Check offset (`+0x20`)
3. Disassemble: `objdump -d module.ko`
4. Find instruction at offset
5. Check source code

---

## Resources

- [GDB Manual](https://sourceware.org/gdb/documentation/)
- [Valgrind Documentation](https://valgrind.org/docs/)
- [perf Wiki](https://perf.wiki.kernel.org/)
- [ftrace Documentation](https://www.kernel.org/doc/Documentation/trace/ftrace.txt)
- [Brendan Gregg's Blog](http://www.brendangregg.com/)

---

**Remember**: The answer to "How long will debugging take?" is 42 minutes... plus however long it actually takes after that estimate.

*Part of the [Hitchhiker's Guide to Developing](https://github.com/Jofralso/hitchhikers-guide-to-developing)*
