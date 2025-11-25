# Lab 23: Performance Profiling and System Tracing

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about performance profiling:

*"Performance profiling reveals where your program spends its time. Often, you'll discover it's spending most of its time in the last place you'd expect - rather like finding that Slartibartfast spent more time on Norway's fjords than on the award-winning coastline of Africa."*

## Objectives

Master system-wide performance profiling with `perf`, function tracing with `ftrace`, and advanced visualization tools to identify CPU hotspots and optimize performance.

**What You'll Learn:**
- Profile CPU usage with `perf`
- Generate flame graphs for visualization
- Use ftrace for function-level kernel tracing
- Trace with trace-cmd and visualize with KernelShark
- Profile userspace with uprobes
- Analyze lock contention and context switches

**Time Required:** 4-5 hours

---

## Prerequisites

**Hardware:**
- BeaglePlay board
- Development workstation
- Network connection

**Software:**
- Linux kernel with perf and ftrace support
- perf-tools package
- Python for flame graph generation

---

## 1. Introduction to perf

### 1.1 What is perf?

**`perf`** is Linux's performance profiling tool using hardware performance counters and software events.

**Capabilities:**
- CPU profiling (sampling)
- Hardware counter access (cache misses, branch mispredictions)
- Kernel and userspace profiling
- Flamegraph generation

### 1.2 Install perf

**On BeaglePlay:**
```bash
# Buildroot: Enable in kernel config
BR2_LINUX_KERNEL_TOOL_PERF=y

# Yocto: Add to image
IMAGE_INSTALL:append = " perf"

# Check installation
perf --version
```

### 1.3 Kernel Configuration

**Required kernel configs:**
```
CONFIG_PERF_EVENTS=y
CONFIG_DEBUG_KERNEL=y
CONFIG_KALLSYMS=y
CONFIG_KALLSYMS_ALL=y
CONFIG_DEBUG_INFO=y
```

**Verify:**
```bash
cat /boot/config-$(uname -r) | grep CONFIG_PERF_EVENTS
```

---

## 2. Basic perf Usage

### 2.1 Record Performance Data

**Profile entire system:**
```bash
perf record -a sleep 10
```

**Options:**
- `-a`: All CPUs
- `-g`: Capture call graphs
- `-F 999`: Sample at 999 Hz

**Profile specific command:**
```bash
perf record -g ./my-app
```

**Outputs `perf.data` file.**

### 2.2 Analyze Recorded Data

```bash
perf report
```

**Output:**
```
Samples: 45K of event 'cpu-clock:pppH', Event count (approx.): 11250000000
Overhead  Command    Shared Object       Symbol
  45.23%  my-app     my-app              [.] compute_heavy_function
  12.34%  my-app     libc-2.31.so        [.] memcpy
   8.45%  my-app     my-app              [.] process_data
   5.67%  my-app     [kernel.kallsyms]   [k] copy_user_enhanced_fast_string
```

**Columns:**
- **Overhead**: % of CPU time
- **Symbol**: Function name
- `[.]` = userspace, `[k]` = kernel

**Interactive navigation:**
- `Enter`: Drill into function
- `a`: Annotate (show assembly)
- `q`: Quit

### 2.3 Create Test Program

**Create `cpu_hog.c`:**
```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void inefficient_sort(int *arr, int n) {
    // O(n²) bubble sort
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n - 1; j++) {
            if (arr[j] > arr[j+1]) {
                int tmp = arr[j];
                arr[j] = arr[j+1];
                arr[j+1] = tmp;
            }
        }
    }
}

void fast_memset(char *buf, int size) {
    memset(buf, 0, size);
}

void slow_memset(char *buf, int size) {
    for (int i = 0; i < size; i++) {
        buf[i] = 0;
    }
}

int main() {
    printf("CPU profiling test\n");
    
    // Spend time in inefficient_sort
    int *arr = malloc(5000 * sizeof(int));
    for (int i = 0; i < 5000; i++) arr[i] = rand();
    inefficient_sort(arr, 5000);
    
    // Spend time in memset functions
    char *buf = malloc(100 * 1024 * 1024);
    for (int i = 0; i < 100; i++) {
        fast_memset(buf, 100 * 1024 * 1024);
    }
    for (int i = 0; i < 100; i++) {
        slow_memset(buf, 1024 * 1024);
    }
    
    free(arr);
    free(buf);
    return 0;
}
```

**Compile:**
```bash
aarch64-linux-gnu-gcc -g -O2 -o cpu_hog cpu_hog.c
```

**Profile:**
```bash
perf record -g ./cpu_hog
perf report
```

---

## 3. Advanced perf Features

### 3.1 Call Graph Profiling

```bash
perf record -g --call-graph dwarf ./cpu_hog
```

**View call graph in report:**
```
- 45.23% inefficient_sort
   - main
      - __libc_start_main
         - _start
```

**Shows complete call chain.**

### 3.2 Hardware Performance Counters

**List available events:**
```bash
perf list
```

**Output:**
```
Hardware event:
  cycles                     [Hardware event]
  instructions               [Hardware event]
  cache-references           [Hardware event]
  cache-misses               [Hardware event]
  branch-instructions        [Hardware event]
  branch-misses              [Hardware event]
```

**Profile cache misses:**
```bash
perf stat -e cache-references,cache-misses ./cpu_hog
```

**Output:**
```
 Performance counter stats for './cpu_hog':

        45,678,901      cache-references
         5,678,012      cache-misses      #   12.43% of all cache refs

       2.345678901 seconds time elapsed
```

**12% cache miss rate** indicates poor cache locality.

### 3.3 Top-like Monitoring

```bash
perf top
```

**Real-time CPU hotspot display:**
```
Samples: 12K of event 'cpu-clock:pppH', 4000 Hz, Event count (approx.): 3056250000
Overhead  Shared Object       Symbol
  45.23%  cpu_hog             [.] inefficient_sort
  12.34%  libc-2.31.so        [.] memset
   5.67%  [kernel]            [k] finish_task_switch
```

**Updated live as program runs.**

---

## 4. Flame Graphs

### 4.1 Install FlameGraph Tools

**On workstation:**
```bash
git clone https://github.com/brendangregg/FlameGraph
cd FlameGraph
```

### 4.2 Generate Flame Graph

**Capture perf data:**
```bash
perf record -F 99 -a -g -- sleep 30
```

**Convert to flame graph:**
```bash
perf script | ./FlameGraph/stackcollapse-perf.pl | ./FlameGraph/flamegraph.pl > flame.svg
```

**View in browser:**
```bash
firefox flame.svg
```

**Flame graph visualization:**
- X-axis: Alphabetical order (not time!)
- Y-axis: Stack depth
- Width: Time spent in function
- Color: Random (for differentiation)

**Click to zoom** into specific call stacks.

### 4.3 Interpret Flame Graph

**Wide plateaus** = CPU hotspots (optimization targets)

**Example:**
```
|----------------------- main() -----------------------|
|         |------ inefficient_sort() ------|
|         |   |---- many recursive calls ---|
```

**`inefficient_sort()` occupies large width** = high CPU usage.

---

## 5. Introduction to ftrace

### 5.1 What is ftrace?

**ftrace** is the kernel's built-in function tracer.

**Features:**
- Trace kernel functions
- Measure function latency
- Create custom trace events
- Zero overhead when disabled

### 5.2 Enable ftrace

**Check if available:**
```bash
mount | grep tracefs
# tracefs on /sys/kernel/tracing type tracefs (rw,relatime)
```

**Or mount manually:**
```bash
mount -t tracefs nodev /sys/kernel/tracing
cd /sys/kernel/tracing
```

### 5.3 Basic ftrace Usage

**List available tracers:**
```bash
cat /sys/kernel/tracing/available_tracers
```

**Output:**
```
function_graph function nop
```

**Enable function tracer:**
```bash
echo function > /sys/kernel/tracing/current_tracer
echo 1 > /sys/kernel/tracing/tracing_on
```

**View trace:**
```bash
cat /sys/kernel/tracing/trace | head -20
```

**Output:**
```
# tracer: function
#
# entries-in-buffer/entries-written: 45678/2345678   #P:4
#
#           TASK-PID   CPU#  TIMESTAMP  FUNCTION
#              | |       |      |         |
          <idle>-0     [000] 123.456789: rcu_idle_exit <-cpu_startup_entry
          <idle>-0     [000] 123.456790: arch_cpu_idle_exit <-cpu_startup_entry
          <idle>-0     [000] 123.456791: tick_nohz_idle_exit <-cpu_startup_entry
```

**Disable tracing:**
```bash
echo 0 > /sys/kernel/tracing/tracing_on
```

---

## 6. Function Graph Tracer

### 6.1 Trace Function Calls

```bash
echo function_graph > /sys/kernel/tracing/current_tracer
echo 1 > /sys/kernel/tracing/tracing_on
sleep 1
echo 0 > /sys/kernel/tracing/tracing_on
cat /sys/kernel/tracing/trace | head -50
```

**Output:**
```
 0)               |  sys_read() {
 0)               |    vfs_read() {
 0)               |      rw_verify_area() {
 0)   0.234 us    |        security_file_permission();
 0)   1.234 us    |      }
 0)               |      __vfs_read() {
 0)  12.345 us    |        ext4_file_read_iter();
 0)  13.567 us    |      }
 0)  16.789 us    |    }
 0)  18.012 us    |  }
```

**Shows call hierarchy and duration.**

### 6.2 Filter Specific Functions

**Trace only a specific function:**
```bash
echo schedule > /sys/kernel/tracing/set_ftrace_filter
echo function > /sys/kernel/tracing/current_tracer
echo 1 > /sys/kernel/tracing/tracing_on
```

**Clear filter:**
```bash
echo > /sys/kernel/tracing/set_ftrace_filter
```

---

## 7. trace-cmd (ftrace Frontend)

### 7.1 Install trace-cmd

```bash
# Yocto
IMAGE_INSTALL:append = " trace-cmd kernelshark"

# Buildroot
make menuconfig
# Target packages -> Debugging -> trace-cmd

# Verify
trace-cmd --version
```

### 7.2 Record Trace

**System-wide trace:**
```bash
trace-cmd record -e sched -e syscalls -a sleep 5
```

**Options:**
- `-e sched`: Scheduler events
- `-e syscalls`: System calls
- `-a`: All CPUs

**Creates `trace.dat` file.**

### 7.3 Report Trace

```bash
trace-cmd report trace.dat | head -50
```

**Output:**
```
cpus=4
     sleep-567   [000] 123.456789: sys_nanosleep: 
     sleep-567   [000] 123.456790: sched_switch: prev_comm=sleep prev_pid=567 ==> next_comm=swapper/0
     <idle>-0     [000] 128.456789: sched_switch: prev_comm=swapper/0 ==> next_comm=sleep next_pid=567
     sleep-567   [000] 128.456790: sys_exit: ret=0
```

---

## 8. KernelShark Visualization

### 8.1 Install KernelShark

**On workstation:**
```bash
sudo apt-get install kernelshark
```

### 8.2 View Trace

**Transfer trace.dat from BeaglePlay:**
```bash
scp root@192.168.0.100:/root/trace.dat .
```

**Open in KernelShark:**
```bash
kernelshark trace.dat
```

**GUI shows:**
- Timeline view of events
- CPU utilization graphs
- Task scheduling visualization
- Filterable by event type

**Interactive features:**
- Zoom in/out
- Search events
- Filter by task/CPU
- Measure time intervals

---

## 9. Userspace Probing (uprobes)

### 9.1 Trace Userspace Functions

**Add uprobe for function in binary:**
```bash
# Find function address
nm cpu_hog | grep inefficient_sort
# 0000000000001234 T inefficient_sort

# Add uprobe
echo 'p:my_probe /tmp/cpu_hog:0x1234' > /sys/kernel/tracing/uprobe_events

# Enable
echo 1 > /sys/kernel/tracing/events/uprobes/my_probe/enable

# Run program
./cpu_hog

# View trace
cat /sys/kernel/tracing/trace
```

**Output:**
```
cpu_hog-567   [001] 123.456789: my_probe: (0x1234)
```

### 9.2 Trace with Arguments

```bash
echo 'p:my_probe /tmp/cpu_hog:0x1234 arg1=%di arg2=%si' > /sys/kernel/tracing/uprobe_events
```

**Captures function arguments** (x86_64 calling convention: rdi, rsi, etc.).

---

## 10. Performance Analysis Workflow

### 10.1 Identify Bottleneck

**Step 1: System-wide profiling**
```bash
perf top
```

**Identify hot functions.**

**Step 2: Detailed profiling**
```bash
perf record -g ./my-app
perf report
```

**Find call chains leading to hotspot.**

**Step 3: Annotate assembly**
```gdb
(gdb) disassemble inefficient_sort
```

**Or in perf report, press `a` on function.**

### 10.2 Fix and Verify

**Optimize code, then re-profile:**
```bash
perf stat -e cycles,instructions ./my-app-optimized
```

**Compare:**
- Cycles reduced?
- Instructions per cycle (IPC) improved?
- Cache misses decreased?

---

## 11. Advanced perf Recipes

### 11.1 Off-CPU Analysis

**Find where tasks are blocked:**
```bash
perf record -e sched:sched_switch -a -g -- sleep 10
perf script | ./FlameGraph/stackcollapse-perf.pl | ./FlameGraph/flamegraph.pl --color=io --title="Off-CPU Time" > offcpu.svg
```

**Shows time waiting for I/O, locks, etc.**

### 11.2 Lock Contention

```bash
perf lock record -a -- sleep 10
perf lock report
```

**Output:**
```
Name                   acquired  contended avg wait (ns)   total wait (ns)
&mm->mmap_sem              1234         45        123456          5555520
&sb->s_type->i_mutex       5678        123         98765         12160095
```

**High contention** = lock optimization needed.

### 11.3 Context Switch Analysis

```bash
perf record -e context-switches -a -g -- sleep 10
perf report
```

**High context switch rate** = scheduler thrashing.

---

## 12. Kernel Configuration for Tracing

### 12.1 Required Kernel Configs

```
CONFIG_FTRACE=y
CONFIG_FUNCTION_TRACER=y
CONFIG_FUNCTION_GRAPH_TRACER=y
CONFIG_DYNAMIC_FTRACE=y
CONFIG_KPROBES=y
CONFIG_UPROBES=y
CONFIG_TRACING=y
```

### 12.2 Enable in Yocto

**In `local.conf` or machine config:**
```
KERNEL_FEATURES:append = " cfg/ftrace.cfg"
```

---

## 13. Real-World Example: Optimize HTTP Server

**Scenario:** HTTP server using too much CPU.

**Step 1: Identify hotspot**
```bash
perf top
# Shows 60% in parse_http_request()
```

**Step 2: Profile in detail**
```bash
perf record -g -p $(pidof http-server)
# Let run for 60 seconds
perf report
```

**Step 3: Flame graph**
```bash
perf script | stackcollapse-perf.pl | flamegraph.pl > http.svg
```

**Analysis:** Wide plateau in `strcmp()` calls.

**Step 4: Optimize**
- Replace repeated `strcmp()` with hash table
- Use `memcmp()` for fixed-length fields

**Step 5: Verify**
```bash
perf stat -p $(pidof http-server) sleep 60
```

**Result:** 40% CPU reduction.

---

## 14. Key Takeaways

**Accomplished:**
1. ✅ Profiled CPU usage with perf
2. ✅ Generated and analyzed flame graphs
3. ✅ Traced kernel functions with ftrace
4. ✅ Visualized traces with KernelShark
5. ✅ Used uprobes for userspace tracing
6. ✅ Analyzed lock contention and context switches

**Essential Commands:**
- `perf record -g ./app`: Profile with call graphs
- `perf top`: Real-time CPU monitoring
- `trace-cmd record -e sched`: Trace scheduler
- `perf script | flamegraph.pl`: Generate flame graph

**Next Steps:**
- **Lab 24**: eBPF and BCC tracing
- **Lab 25**: Kernel debugging

---

## 15. Verification Checklist

- [ ] Can profile applications with perf
- [ ] Can generate flame graphs
- [ ] Understand ftrace function tracing
- [ ] Can use trace-cmd and KernelShark
- [ ] Can trace userspace with uprobes
- [ ] Can identify performance bottlenecks

---

**End of Lab 23**

*The Guide rates this lab: **Mostly Harmless** ⭐⭐⭐⭐*

Performance profiling is essential for building efficient systems. The combination of perf, ftrace, and visualization tools provides complete visibility into system behavior, from userspace applications to kernel internals.
