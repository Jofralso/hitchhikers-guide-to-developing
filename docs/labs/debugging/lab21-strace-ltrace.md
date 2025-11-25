# Lab 21: System Call and Library Tracing

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about debugging:

*"Debugging is the art of figuring out why your code doesn't work, as opposed to why you thought it would work. This is similar to the difference between what Deep Thought calculated (42) and what everyone expected (a useful answer). Both are technically correct, but only one is helpful."*

## Objectives

Master `strace` and `ltrace` to understand how programs interact with the kernel and libraries, essential for diagnosing system-level issues and performance problems.

**What You'll Learn:**
- Trace system calls with `strace`
- Analyze library function calls with `ltrace`
- Filter and format trace output
- Identify performance bottlenecks
- Debug file access and permission issues
- Understand process behavior

**Time Required:** 2-3 hours (or approximately 42 minutes in improbable circumstances)

---

## Prerequisites

**Hardware:**
- BeaglePlay board
- Development workstation
- Network connection

**Software:**
- strace and ltrace installed
- Sample applications to trace

---

## 1. Introduction to strace

### 1.1 What is strace?

**`strace`** intercepts and records system calls made by a process.

**System calls** are the interface between user programs and the kernel:
- `open()`, `read()`, `write()`, `close()` - File I/O
- `fork()`, `execve()`, `wait()` - Process management
- `socket()`, `connect()`, `send()` - Networking
- `mmap()`, `brk()` - Memory management

### 1.2 Basic Usage

**Trace simple command:**
```bash
strace ls /tmp
```

**Output:**
```
execve("/usr/bin/ls", ["ls", "/tmp"], 0xfffffffff8 /* 12 vars */) = 0
brk(NULL)                               = 0xaaaaaaaa8000
mmap(NULL, 4096, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0xfffff7ff0000
openat(AT_FDCWD, "/tmp", O_RDONLY|O_NONBLOCK|O_CLOEXEC|O_DIRECTORY) = 3
getdents64(3, /* 5 entries */, 32768)   = 160
write(1, "file1\nfile2\nfile3\n", 18)   = 18
close(3)                                = 0
exit_group(0)                           = ?
```

**Format:** `syscall(args) = return_value`

### 1.3 Install strace

**On BeaglePlay:**
```bash
# Using opkg (Buildroot)
opkg install strace

# Using apt (Debian-based)
apt-get install strace

# Using Yocto, add to image:
IMAGE_INSTALL:append = " strace"
```

---

## 2. strace Command Options

### 2.1 Filter Specific System Calls

**Trace only file operations:**
```bash
strace -e trace=open,openat,read,write,close cat /etc/hostname
```

**Output:**
```
openat(AT_FDCWD, "/etc/hostname", O_RDONLY) = 3
read(3, "beagleplay\n", 131072)         = 11
write(1, "beagleplay\n", 11)            = 11
close(3)                                = 0
```

**Trace only network calls:**
```bash
strace -e trace=network nc -l 8080
```

**Categories:**
- `file`: File operations
- `process`: fork, exec, wait
- `network`: socket, connect, send, recv
- `signal`: kill, sigaction
- `memory`: mmap, brk, mprotect

### 2.2 Output Formatting

**Show timestamps:**
```bash
strace -t ls
# -t: Time of day
# -tt: Time with microseconds
# -ttt: Unix timestamp
```

**Show time spent in each syscall:**
```bash
strace -T ls
```

**Output:**
```
openat(AT_FDCWD, "/tmp", O_RDONLY) = 3 <0.000045>
# <0.000045> = 45 microseconds
```

**Count syscall statistics:**
```bash
strace -c ls /tmp
```

**Output:**
```
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
 45.23    0.000543          54        10           mmap
 21.34    0.000256          64         4           openat
 12.45    0.000149          37         4           read
 ...
```

### 2.3 Attach to Running Process

**Find PID:**
```bash
ps aux | grep my-app
# root  567  0.5  1.2  ...  my-app
```

**Attach strace:**
```bash
strace -p 567
```

**Detach:** Press `Ctrl+C`

### 2.4 Follow Child Processes

```bash
strace -f -e trace=process ./parent-app
```

**`-f`**: Follow forks and child processes

---

## 3. Practical strace Examples

### 3.1 Debug File Not Found

**Program fails to open file:**
```bash
strace -e trace=open,openat,stat ./my-app
```

**Output:**
```
openat(AT_FDCWD, "/etc/config.conf", O_RDONLY) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/usr/local/etc/config.conf", O_RDONLY) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/home/root/.config.conf", O_RDONLY) = 3
```

**Shows search path** until file found.

### 3.2 Diagnose Permission Issues

```bash
strace -e trace=open,access ./my-app 2>&1 | grep EACCES
```

**Output:**
```
openat(AT_FDCWD, "/dev/i2c-1", O_RDWR) = -1 EACCES (Permission denied)
```

**Solution:** Add user to `i2c` group or run as root.

### 3.3 Identify Slow Operations

**Trace with timing:**
```bash
strace -T -e trace=read,write ./slow-app
```

**Output:**
```
read(3, "...", 4096) = 4096 <0.000023>
read(3, "...", 4096) = 4096 <2.345678>  # Slow read!
```

**2.3 seconds** = likely waiting for network/disk.

### 3.4 Trace Network Activity

**Create test client:**
```bash
strace -e trace=network curl http://192.168.0.1
```

**Output:**
```
socket(AF_INET, SOCK_STREAM, IPPROTO_TCP) = 3
connect(3, {sa_family=AF_INET, sin_port=htons(80), sin_addr=inet_addr("192.168.0.1")}, 16) = 0
sendto(3, "GET / HTTP/1.1\r\nHost: 192.168.0.1\r\n...", 78, MSG_NOSIGNAL, NULL, 0) = 78
recvfrom(3, "HTTP/1.1 200 OK\r\n...", 16384, 0, NULL, NULL) = 512
```

---

## 4. Introduction to ltrace

### 4.1 What is ltrace?

**`ltrace`** intercepts library function calls (libc, etc.).

**Difference from strace:**
- **strace**: System calls (kernel interface)
- **ltrace**: Library calls (user-space functions)

### 4.2 Basic Usage

```bash
ltrace ls /tmp
```

**Output:**
```
__libc_start_main(0xaaaaaaaa1234, 2, 0xfffffffff8, ...
strcmp("ls", "ls")                      = 0
malloc(1024)                            = 0xaaaaaaaa8000
opendir("/tmp")                         = 0xaaaaaaaa8100
readdir(0xaaaaaaaa8100)                 = { d_name = "file1" }
printf("%s\n", "file1")                 = 6
free(0xaaaaaaaa8000)                    = <void>
```

### 4.3 Filter Library Calls

**Trace only malloc/free:**
```bash
ltrace -e malloc,free ./my-app
```

**Trace only string functions:**
```bash
ltrace -e 'strcmp*' ./my-app
# Matches strcmp, strcpy, strlen, etc.
```

---

## 5. Practical ltrace Examples

### 5.1 Find Memory Leaks

**Create `leak.c`:**
```c
#include <stdlib.h>
#include <string.h>

int main() {
    for (int i = 0; i < 100; i++) {
        char *ptr = malloc(1024);
        strcpy(ptr, "Leaked memory");
        // Missing free(ptr)!
    }
    return 0;
}
```

**Compile and trace:**
```bash
aarch64-linux-gnu-gcc -o leak leak.c
ltrace -e malloc,free ./leak
```

**Output:**
```
malloc(1024) = 0xaaaaaaaa8000
malloc(1024) = 0xaaaaaaaa8400
malloc(1024) = 0xaaaaaaaa8800
...
# 100 malloc() calls, 0 free() calls!
```

### 5.2 Trace String Operations

```bash
ltrace -e 'str*' ./my-app
```

**Output:**
```
strlen("Hello World") = 11
strcmp("user", "root") = 1
strcpy(0xfffffffff0, "config.txt") = 0xfffffffff0
```

### 5.3 Debug Library Loading

```bash
ltrace -e 'dlopen*' ./my-app
```

**Shows dynamic library loading.**

---

## 6. Combining strace and ltrace

### 6.1 Trace Both System and Library Calls

**Terminal 1 - strace:**
```bash
strace -o strace.log -tt ./my-app
```

**Terminal 2 - ltrace:**
```bash
ltrace -o ltrace.log -tt ./my-app
```

**Analyze together:**
```bash
# System calls
grep "open\|read\|write" strace.log

# Library calls
grep "malloc\|free\|strcmp" ltrace.log
```

### 6.2 Correlate by Timestamp

**Both logs have timestamps (`-tt`)**, can merge chronologically.

---

## 7. Advanced Usage

### 7.1 Save Trace to File

```bash
strace -o trace.log -ff -tt ./my-app
```

**Options:**
- `-o file`: Output to file
- `-ff`: Separate file per process (trace.log.PID)
- `-tt`: Microsecond timestamps

### 7.2 Trace Specific File Operations

**Track all accesses to specific file:**
```bash
strace -e trace=file -e open --trace=/etc/passwd ./my-app
```

**Only shows operations on `/etc/passwd`.**

### 7.3 Decode Socket Addresses

```bash
strace -yy -e trace=network ./network-app
```

**`-yy`**: Show file descriptor paths and IP addresses

**Output:**
```
socket(AF_INET, SOCK_STREAM, IPPROTO_TCP) = 3<TCP:[192.168.0.100:54321->192.168.0.1:80]>
```

---

## 8. Performance Profiling with strace

### 8.1 Identify Slow System Calls

```bash
strace -c -S time ./my-app
```

**Output:**
```
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
 85.23    2.345678      234567        10           read
  8.45    0.232145       11607        20           write
  3.12    0.085632        4281        20           mmap
```

**85% of time** spent in `read()` syscalls.

### 8.2 Find Excessive Syscalls

```bash
strace -c ./my-app
```

**Look for:**
- **High call count**: Inefficient loops
- **High error count**: Repeated failures

---

## 9. Real-World Debugging Scenarios

### 9.1 Application Hangs

**Symptoms:** Program stops responding.

**Debug:**
```bash
# Find PID
ps aux | grep my-app

# Attach strace
strace -p 567
```

**Possible outputs:**
```
# Stuck in read() - waiting for input
read(3, 

# Stuck in futex - deadlock
futex(0xaaaaaaaa8000, FUTEX_WAIT_PRIVATE, 0, NULL

# Stuck in nanosleep - sleeping
nanosleep({tv_sec=1000000, tv_nsec=0},
```

### 9.2 High CPU Usage

```bash
strace -c -p 567
```

**Check for:**
- Tight loops with millions of syscalls
- Repeated failed syscalls (e.g., `ENOENT`)

### 9.3 File Access Patterns

**Find all files accessed:**
```bash
strace -e trace=open,openat ./my-app 2>&1 | grep -o '"/[^"]*"' | sort -u
```

**Output:**
```
"/dev/null"
"/etc/ld.so.cache"
"/etc/passwd"
"/lib/libc.so.6"
"/tmp/config.conf"
```

---

## 10. Troubleshooting Tips

### 10.1 Permission Denied

**strace needs permissions:**
```bash
# Run as root
sudo strace -p 567

# Or allow ptrace for your user
echo 0 > /proc/sys/kernel/yama/ptrace_scope
```

### 10.2 Too Much Output

**Limit output:**
```bash
# Only first 1000 lines
strace ./my-app 2>&1 | head -1000

# Only errors
strace -e trace=open ./my-app 2>&1 | grep -v "= 3"
```

### 10.3 Decode Binary Data

```bash
# Show hex and ASCII for read/write
strace -s 1024 -x ./my-app
```

---

## 11. Example: Debug Failed Service Start

**Scenario:** Service fails to start, no error logs.

```bash
strace -f -e trace=file,process systemctl start my-service
```

**Output reveals:**
```
openat(AT_FDCWD, "/etc/my-service/config", O_RDONLY) = -1 ENOENT (No such file or directory)
```

**Solution:** Create missing config file.

---

## 12. Key Takeaways

**Accomplished:**
1. ✅ Traced system calls with strace
2. ✅ Traced library calls with ltrace
3. ✅ Filtered and analyzed trace output
4. ✅ Identified performance bottlenecks
5. ✅ Debugged file access and permission issues

**Essential Commands:**
- `strace -e trace=file ./app`: File operations
- `strace -c ./app`: Call statistics
- `strace -p PID`: Attach to process
- `ltrace -e malloc,free ./app`: Memory allocation

**Next Steps:**
- **Lab 22**: Memory debugging with valgrind
- **Lab 23**: Performance profiling

---

## 13. Verification Checklist

- [ ] Can trace system calls of a program
- [ ] Can filter specific syscall categories
- [ ] Can attach to running processes
- [ ] Can identify slow syscalls with timing
- [ ] Understand difference between strace and ltrace
- [ ] Can debug file access issues

---

**End of Lab 21**

*The Guide rates this lab: **Mostly Harmless** ⭐⭐⭐⭐*

`strace` and `ltrace` are invaluable for understanding program behavior at the system level. They reveal exactly how applications interact with the kernel and libraries, making seemingly mysterious bugs transparent.
