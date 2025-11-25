# Lab 19: System Monitoring and Resource Analysis

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about debugging:

*"Debugging is the art of figuring out why your code doesn't work, as opposed to why you thought it would work. This is similar to the difference between what Deep Thought calculated (42) and what everyone expected (a useful answer). Both are technically correct, but only one is helpful."*

## Objectives

Master essential Linux system monitoring tools to analyze process behavior, memory usage, I/O performance, and network activity.

**What You'll Learn:**
- Monitor running processes with `ps` and `top`
- Analyze memory allocation using `/proc` filesystem and `pmap`
- Track I/O performance with `iostat` and `iotop`
- Monitor virtual memory with `vmstat`
- Analyze network activity with `netstat` and `ss`
- Understand system resource bottlenecks

**Time Required:** 2-3 hours (or approximately 42 minutes in improbable circumstances)

---

## Prerequisites

**Hardware:**
- BeaglePlay board (TI AM62x)
- Development workstation
- Network connection

**Software:**
- Working Linux system on BeaglePlay (from previous labs)
- SSH access
- Root privileges

---

## 1. Process Monitoring with ps

### 1.1 Understanding ps

**`ps`** displays snapshot of current processes.

**Basic usage:**
```bash
# All processes
ps aux

# Process tree
ps auxf

# Specific user
ps -u root

# Custom format
ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem
```

### 1.2 Analyze Running Processes

**On BeaglePlay:**
```bash
ssh root@192.168.0.100
ps aux
```

**Output columns:**
```
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.3   5324  3208 ?        Ss   10:00   0:01 /sbin/init
root       123  0.1  1.2  45632 12048 ?        Ssl  10:00   0:05 /usr/bin/systemd
```

**Key columns:**
- **PID**: Process ID
- **%CPU**: CPU usage percentage
- **%MEM**: Memory usage percentage
- **VSZ**: Virtual memory size (KB)
- **RSS**: Resident Set Size (physical RAM, KB)
- **STAT**: Process state (R=running, S=sleeping, Z=zombie)

### 1.3 Find Resource-Heavy Processes

```bash
# Top 10 CPU consumers
ps aux --sort=-%cpu | head -11

# Top 10 memory consumers
ps aux --sort=-%mem | head -11

# Processes using most threads
ps -eLf | awk '{print $4}' | sort | uniq -c | sort -nr | head -10
```

---

## 2. Real-Time Monitoring with top

### 2.1 Interactive top Usage

```bash
top
```

**Output:**
```
top - 10:30:15 up 2:15,  1 user,  load average: 0.08, 0.12, 0.10
Tasks:  95 total,   1 running,  94 sleeping,   0 stopped,   0 zombie
%Cpu(s):  2.1 us,  0.8 sy,  0.0 ni, 96.9 id,  0.2 wa,  0.0 hi,  0.0 si,  0.0 st
MiB Mem :   1987.2 total,   1234.5 free,    345.2 used,    407.5 buff/cache
MiB Swap:      0.0 total,      0.0 free,      0.0 used.   1567.8 avail Mem 

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
  456 root      20   0  123456  45678  12345 S   5.2   2.3   0:12.34 my-app
  123 root      20   0   98765  23456   8765 S   1.2   1.2   0:05.67 systemd
```

**Interactive commands:**
- `k`: Kill process
- `r`: Renice process
- `M`: Sort by memory
- `P`: Sort by CPU
- `1`: Show individual CPU cores
- `c`: Show full command
- `q`: Quit

### 2.2 top Command-Line Options

```bash
# Update every 2 seconds
top -d 2

# Show specific user
top -u nginx

# Batch mode (for logging)
top -b -n 1 > system-snapshot.txt

# Monitor specific processes
top -p 123,456,789
```

### 2.3 Understanding Load Average

**Load average:** `0.08, 0.12, 0.10`
- Last 1 minute: 0.08
- Last 5 minutes: 0.12
- Last 15 minutes: 0.10

**BeaglePlay has 4 CPU cores:**
- Load < 4.0: System handling load well
- Load > 4.0: Processes waiting for CPU

---

## 3. Memory Analysis with /proc

### 3.1 System-Wide Memory Info

```bash
cat /proc/meminfo
```

**Output:**
```
MemTotal:        2035456 kB
MemFree:         1264128 kB
MemAvailable:    1605632 kB
Buffers:          56832 kB
Cached:          352256 kB
SwapCached:           0 kB
Active:          425984 kB
Inactive:        201728 kB
```

**Key metrics:**
- **MemTotal**: Total physical RAM
- **MemFree**: Unused RAM
- **MemAvailable**: RAM available for applications (includes reclaimable cache)
- **Cached**: Page cache (file data)
- **Buffers**: Block device buffers

### 3.2 Per-Process Memory

```bash
# Memory usage of PID 456
cat /proc/456/status | grep -E "VmSize|VmRSS|VmData"
```

**Output:**
```
VmSize:    123456 kB  # Virtual memory
VmRSS:      45678 kB  # Physical RAM
VmData:     34567 kB  # Private data
```

### 3.3 Memory Maps with pmap

```bash
# Show memory map of process
pmap -x 456
```

**Output:**
```
Address           Kbytes     RSS   Dirty Mode  Mapping
0000aaaab0000000    1024    1024       0 r-x-- my-app
0000aaaab0100000      64      64      64 rw--- my-app
0000ffff80000000   1856     128       0 r-x-- libc-2.31.so
0000ffff801d0000      64      64      64 rw--- libc-2.31.so
```

**Columns:**
- **RSS**: Resident memory (in RAM)
- **Dirty**: Modified pages
- **Mode**: Permissions (r=read, w=write, x=execute)

---

## 4. I/O Performance with iostat

### 4.1 Install sysstat Package

```bash
# If not already installed
opkg install sysstat
# or in Yocto, add to IMAGE_INSTALL
```

### 4.2 Monitor Disk I/O

```bash
iostat -x 2 5
```

**Output:**
```
Device            r/s     w/s     rkB/s     wkB/s   %util
mmcblk0          12.5     8.3    256.7     134.2    5.2
mmcblk0p1         1.2     0.5     15.3       8.1    0.3
mmcblk0p2        11.3     7.8    241.4     126.1    4.9
```

**Metrics:**
- **r/s, w/s**: Reads/writes per second
- **rkB/s, wkB/s**: KB read/written per second
- **%util**: Device utilization (>80% = bottleneck)

### 4.3 CPU Statistics

```bash
iostat -c 2 5
```

**Shows CPU usage breakdown:**
```
%user   %nice %system %iowait  %steal   %idle
  2.3     0.0     0.8     0.2     0.0    96.7
```

**High %iowait** indicates processes waiting for I/O.

---

## 5. Virtual Memory with vmstat

### 5.1 Monitor System Activity

```bash
vmstat 2 10
```

**Output:**
```
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 1  0      0 1264128  56832 352256    0    0    12     8  142  234  2  1 97  0  0
 0  0      0 1263456  56832 352512    0    0     0    16  156  245  2  1 97  0  0
```

**Key columns:**
- **r**: Processes running/waiting for CPU
- **b**: Processes blocked on I/O
- **swpd**: Swap used (should be 0 on BeaglePlay)
- **free**: Free RAM
- **bi/bo**: Blocks in/out (I/O)
- **us/sy/id/wa**: CPU usage (user/system/idle/wait)

### 5.2 Memory Statistics

```bash
vmstat -s
```

**Detailed memory breakdown.**

### 5.3 Disk Statistics

```bash
vmstat -d
```

**Per-disk statistics.**

---

## 6. Network Monitoring

### 6.1 Active Connections with netstat

```bash
netstat -tunapl
```

**Output:**
```
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      234/sshd
tcp        0      0 192.168.0.100:22        192.168.0.1:54321       ESTABLISHED 456/sshd
```

**Options:**
- `-t`: TCP
- `-u`: UDP
- `-n`: Numeric (no DNS)
- `-a`: All sockets
- `-p`: Show PID/program
- `-l`: Listening sockets

### 6.2 Modern Alternative: ss

```bash
# Faster than netstat
ss -tunapl
```

### 6.3 Network Statistics

```bash
netstat -i
```

**Output:**
```
Iface      MTU    RX-OK RX-ERR RX-DRP TX-OK TX-ERR TX-DRP Flg
eth0      1500   123456      0      0  98765      0      0 BMRU
lo       65536    45678      0      0  45678      0      0 LRU
```

**Watch for RX-ERR and TX-ERR** (packet errors).

---

## 7. Practical Exercises

### 7.1 Find Memory Leak

**Scenario:** Application slowly consuming memory.

**Steps:**
```bash
# Monitor process memory over time
watch -n 5 'ps aux | grep my-app'

# Detailed memory map
pmap -x $(pidof my-app)

# Check /proc for growth
watch -n 2 'cat /proc/$(pidof my-app)/status | grep VmRSS'
```

### 7.2 Identify I/O Bottleneck

```bash
# Real-time I/O monitoring
iotop -o
```

**Shows processes doing I/O.**

**Alternative:**
```bash
# Per-process I/O
pidstat -d 2 5
```

### 7.3 Diagnose High CPU Usage

```bash
# Find CPU hog
top -b -n 1 | head -20

# Check if single-threaded or multi-threaded
ps -eLf | grep my-app

# CPU affinity (which cores process uses)
taskset -cp $(pidof my-app)
```

---

## 8. Advanced Monitoring

### 8.1 htop (Enhanced top)

```bash
htop
```

**Features:**
- Color-coded display
- Mouse support
- Vertical/horizontal scrolling
- Tree view
- Easy process management

### 8.2 glances (All-in-One)

```bash
glances
```

**Shows CPU, memory, disk, network in single view.**

### 8.3 System Load Graphing

```bash
# Log metrics for graphing
sar -u 2 1800 > cpu-load.txt
sar -r 2 1800 > memory-usage.txt
```

---

## 9. Troubleshooting Scenarios

### 9.1 System Running Slow

**Check:**
```bash
# Load average
uptime

# CPU usage
top

# Memory pressure
free -h

# I/O wait
iostat -x 2 5

# Swap activity (should be none)
vmstat 2 5
```

### 9.2 Out of Memory

**Investigate:**
```bash
# System memory
cat /proc/meminfo

# Largest consumers
ps aux --sort=-%mem | head -20

# OOM killer logs
dmesg | grep -i "out of memory"
```

### 9.3 Network Issues

**Debug:**
```bash
# Active connections
ss -tunapl

# Interface statistics
netstat -i

# Connection tracking
cat /proc/net/nf_conntrack
```

---

## 10. Key Takeaways

**Accomplished:**
1. ✅ Mastered process monitoring with ps and top
2. ✅ Analyzed memory with /proc and pmap
3. ✅ Monitored I/O with iostat
4. ✅ Tracked system resources with vmstat
5. ✅ Debugged network with netstat/ss

**Essential Commands:**
- `top`: Real-time process viewer
- `ps aux`: Process snapshot
- `free -h`: Memory overview
- `iostat -x`: I/O performance
- `vmstat`: System statistics

**Next Steps:**
- **Lab 20**: Application debugging with GDB
- **Lab 21**: System call tracing

---

## 11. Verification Checklist

- [ ] Can identify top CPU consumers
- [ ] Can find memory leaks with pmap
- [ ] Understand load average interpretation
- [ ] Can diagnose I/O bottlenecks
- [ ] Know when system is memory-constrained
- [ ] Can monitor network connections

---

**End of Lab 19**

*The Guide rates this lab: **Mostly Harmless** ⭐⭐⭐⭐*

System monitoring is the foundation of performance analysis and debugging. These tools provide the visibility needed to identify bottlenecks and resource constraints before they become critical issues.
