# Lab 24: eBPF and BCC Tracing

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about debugging:

*"Debugging is the art of figuring out why your code doesn't work, as opposed to why you thought it would work. This is similar to the difference between what Deep Thought calculated (42) and what everyone expected (a useful answer). Both are technically correct, but only one is helpful."*

## Objectives

Master eBPF (extended Berkeley Packet Filter) and BCC (BPF Compiler Collection) for creating custom, low-overhead tracing tools that run safely in the kernel.

**What You'll Learn:**
- Understand eBPF architecture and capabilities
- Use BCC tools for system analysis
- Write custom BCC tracing scripts in Python
- Port BCC tools to embedded systems with libbpf
- Trace network packets, disk I/O, and system calls
- Create production-ready eBPF programs

**Time Required:** 4-5 hours

---

## Prerequisites

**Hardware:**
- BeaglePlay board
- Development workstation
- 2GB+ RAM

**Software:**
- Linux kernel 4.9+ with eBPF support
- BCC tools installed
- Python 3.x
- LLVM/Clang compiler

---

## 1. Introduction to eBPF

### 1.1 What is eBPF?

**eBPF** enables running sandboxed programs in the kernel without changing kernel source code or loading kernel modules.

**Use cases:**
- Performance monitoring and profiling
- Network packet filtering and manipulation
- Security policy enforcement
- System call filtering (seccomp-bpf)

**Advantages:**
- **Safe**: Verified by kernel to prevent crashes
- **Fast**: JIT-compiled to native code
- **No kernel recompilation**: Dynamic loading
- **Low overhead**: Minimal performance impact

### 1.2 eBPF Architecture

```
User Space:
  ┌─────────────┐
  │ BCC/libbpf  │ ← Python/C program
  └──────┬──────┘
         │ syscall(bpf)
Kernel Space:
  ┌──────▼──────┐
  │ BPF Verifier│ ← Ensures program safety
  └──────┬──────┘
  ┌──────▼──────┐
  │  JIT Compiler│ ← Compile to ARM64 code
  └──────┬──────┘
  ┌──────▼──────┐
  │ BPF Program │ ← Runs on events (kprobes, tracepoints, etc.)
  └──────┬──────┘
  ┌──────▼──────┐
  │  BPF Maps   │ ← Shared data structures
  └─────────────┘
```

### 1.3 Kernel Configuration

**Required configs:**
```
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_HAVE_EBPF_JIT=y
CONFIG_BPF_EVENTS=y
CONFIG_KPROBES=y
CONFIG_UPROBES=y
CONFIG_TRACEPOINTS=y
```

**Verify:**
```bash
cat /boot/config-$(uname -r) | grep CONFIG_BPF
```

---

## 2. Install BCC

### 2.1 BCC on Workstation

**Ubuntu/Debian:**
```bash
sudo apt-get install bpfcc-tools python3-bpfcc libbpfcc-dev linux-headers-$(uname -r)
```

**Verify:**
```bash
ls /usr/share/bcc/tools/
```

### 2.2 BCC on BeaglePlay (Cross-Compile)

**Yocto setup:**
```bash
# In local.conf
IMAGE_INSTALL:append = " bcc python3-bcc kernel-dev"

# May need to build BCC from source for ARM64
```

**Buildroot:**
```bash
make menuconfig
# Target packages → Debugging → bcc
```

**The Guide notes:** BCC has heavy dependencies (LLVM, Python). For embedded, consider libbpf (Lab 24.7).

---

## 3. Pre-Built BCC Tools

### 3.1 Explore Available Tools

**List tools:**
```bash
ls /usr/share/bcc/tools/
```

**Categories:**
- **File I/O**: `opensnoop`, `statsnoop`, `filetop`
- **Disk I/O**: `biotop`, `biolatency`, `biosnoop`
- **Network**: `tcpconnect`, `tcpaccept`, `tcptop`
- **Process**: `execsnoop`, `exitsnoop`, `pidstat`
- **Performance**: `profile`, `offcputime`, `funccount`

### 3.2 execsnoop - Trace Process Execution

**Monitor all new processes:**
```bash
sudo /usr/share/bcc/tools/execsnoop
```

**Output:**
```
PCOMM            PID    PPID   RET ARGS
bash             567    456      0 /usr/bin/ls -la
grep             568    567      0 /usr/bin/grep hello
```

**Shows:**
- Parent process (PPID)
- Return code (RET)
- Full command arguments

**Use case:** Detect unwanted process spawning.

### 3.3 opensnoop - Trace File Opens

**Monitor file opens:**
```bash
sudo /usr/share/bcc/tools/opensnoop
```

**Output:**
```
PID    COMM               FD ERR PATH
567    cat                 3   0 /etc/hostname
568    vim                 3   0 /home/root/.vimrc
569    systemd             4   2 /var/log/messages
```

**ERR column:** 0 = success, non-zero = error code.

**Use case:** Debug "file not found" errors.

### 3.4 biotop - Top-Like Disk I/O

**Monitor disk I/O by process:**
```bash
sudo /usr/share/bcc/tools/biotop
```

**Output:**
```
PID    COMM             D MAJ MIN  DISK       I/O  Kbytes     AVGms
567    tar              R 179   0  mmcblk0   1234  123456     12.34
568    dd               W 179   0  mmcblk0    567   56789     23.45
```

**Columns:**
- **D**: Direction (R=read, W=write)
- **I/O**: Number of I/O operations
- **AVGms**: Average latency

### 3.5 tcpconnect - Trace TCP Connections

**Monitor outbound TCP connections:**
```bash
sudo /usr/share/bcc/tools/tcpconnect
```

**Output:**
```
PID    COMM         IP SADDR            DADDR            DPORT
567    curl         4  192.168.0.100    93.184.216.34    80
568    ssh          4  192.168.0.100    192.168.0.1      22
```

**Use case:** Detect unexpected network connections.

---

## 4. Write Custom BCC Scripts

### 4.1 Hello World BCC Program

**Create `hello_bcc.py`:**
```python
#!/usr/bin/env python3
from bcc import BPF

# BPF program (C code)
prog = """
int hello(void *ctx) {
    bpf_trace_printk("Hello, eBPF!\\n");
    return 0;
}
"""

# Load BPF program
b = BPF(text=prog)

# Attach to system call (execve)
b.attach_kprobe(event="__arm64_sys_execve", fn_name="hello")

# Print trace messages
print("Tracing execve... Hit Ctrl-C to stop.")
try:
    b.trace_print()
except KeyboardInterrupt:
    pass
```

**Run:**
```bash
sudo python3 hello_bcc.py
```

**In another terminal, run commands:**
```bash
ls
echo test
```

**Output:**
```
Tracing execve... Hit Ctrl-C to stop.
            bash-567   [000] d... 123.456789: hello: Hello, eBPF!
            bash-568   [001] d... 123.567890: hello: Hello, eBPF!
```

### 4.2 Count System Calls

**Create `syscall_count.py`:**
```python
#!/usr/bin/env python3
from bcc import BPF
from time import sleep

prog = """
#include <uapi/linux/ptrace.h>

BPF_HASH(syscall_count, u64);

int count_syscalls(struct pt_regs *ctx) {
    u64 syscall_nr = ctx->regs[8];  // ARM64: x8 register holds syscall number
    u64 *count = syscall_count.lookup(&syscall_nr);
    if (count) {
        (*count)++;
    } else {
        u64 initial = 1;
        syscall_count.update(&syscall_nr, &initial);
    }
    return 0;
}
"""

b = BPF(text=prog)
b.attach_kprobe(event="__arm64_sys_call", fn_name="count_syscalls")

print("Counting syscalls for 10 seconds...")
sleep(10)

# Print syscall counts
print("\nTop 10 syscalls:")
counts = b["syscall_count"]
for k, v in sorted(counts.items(), key=lambda x: x[1].value, reverse=True)[:10]:
    print(f"Syscall {k.value:3d}: {v.value:6d} calls")
```

**Output:**
```
Top 10 syscalls:
Syscall  63:  12345 calls  # read()
Syscall  64:   9876 calls  # write()
Syscall  57:   5432 calls  # close()
```

### 4.3 Trace Function Arguments

**Create `trace_open.py`:**
```python
#!/usr/bin/env python3
from bcc import BPF

prog = """
#include <uapi/linux/ptrace.h>

int trace_open(struct pt_regs *ctx, const char *filename) {
    char fn[256];
    bpf_probe_read_user(&fn, sizeof(fn), (void *)filename);
    bpf_trace_printk("open(%s)\\n", fn);
    return 0;
}
"""

b = BPF(text=prog)
b.attach_kprobe(event="do_sys_open", fn_name="trace_open")

print("Tracing open() syscalls... Ctrl-C to stop.")
try:
    b.trace_print()
except KeyboardInterrupt:
    pass
```

**Output:**
```
cat-567   [000] d... 123.456789: trace_open: open(/etc/hostname)
vim-568   [001] d... 123.567890: trace_open: open(/home/root/.vimrc)
```

---

## 5. BPF Maps for Data Collection

### 5.1 BPF Map Types

**Common map types:**
- **BPF_HASH**: Hash table
- **BPF_ARRAY**: Fixed-size array
- **BPF_PERF_ARRAY**: Performance event array
- **BPF_RINGBUF**: Ring buffer (kernel 5.8+)

### 5.2 Use Hash Map for Aggregation

**Create `io_latency.py`:**
```python
#!/usr/bin/env python3
from bcc import BPF
from time import sleep

prog = """
#include <uapi/linux/ptrace.h>
#include <linux/blkdev.h>

BPF_HASH(start, struct request *);
BPF_HISTOGRAM(latency_us);

int trace_req_start(struct pt_regs *ctx, struct request *req) {
    u64 ts = bpf_ktime_get_ns();
    start.update(&req, &ts);
    return 0;
}

int trace_req_done(struct pt_regs *ctx, struct request *req) {
    u64 *tsp = start.lookup(&req);
    if (tsp) {
        u64 delta = bpf_ktime_get_ns() - *tsp;
        latency_us.increment(bpf_log2l(delta / 1000));
        start.delete(&req);
    }
    return 0;
}
"""

b = BPF(text=prog)
b.attach_kprobe(event="blk_account_io_start", fn_name="trace_req_start")
b.attach_kprobe(event="blk_account_io_done", fn_name="trace_req_done")

print("Tracing block I/O latency... Hit Ctrl-C to stop.")
try:
    sleep(30)
except KeyboardInterrupt:
    pass

print("\nI/O Latency Distribution (microseconds):")
b["latency_us"].print_log2_hist("latency (us)")
```

**Output:**
```
I/O Latency Distribution (microseconds):
     latency (us)    : count     distribution
         0 -> 1      : 0        |                                        |
         2 -> 3      : 5        |*                                       |
         4 -> 7      : 123      |***********                             |
         8 -> 15     : 456      |******************************************|
        16 -> 31     : 234      |*********************                   |
        32 -> 63     : 89       |********                                |
```

---

## 6. Network Packet Tracing

### 6.1 Trace TCP Packets

**Create `tcp_trace.py`:**
```python
#!/usr/bin/env python3
from bcc import BPF

prog = """
#include <uapi/linux/ptrace.h>
#include <net/sock.h>
#include <bcc/proto.h>

int trace_tcp_sendmsg(struct pt_regs *ctx, struct sock *sk) {
    u32 saddr = sk->__sk_common.skc_rcv_saddr;
    u32 daddr = sk->__sk_common.skc_daddr;
    u16 sport = sk->__sk_common.skc_num;
    u16 dport = sk->__sk_common.skc_dport;
    
    bpf_trace_printk("TCP %pI4:%d -> %pI4:%d\\n", &saddr, sport, &daddr, ntohs(dport));
    return 0;
}
"""

b = BPF(text=prog)
b.attach_kprobe(event="tcp_sendmsg", fn_name="trace_tcp_sendmsg")

print("Tracing TCP sends... Ctrl-C to stop.")
try:
    b.trace_print()
except KeyboardInterrupt:
    pass
```

**Output:**
```
curl-567   [000] d... 123.456789: trace_tcp_sendmsg: TCP 192.168.0.100:54321 -> 93.184.216.34:80
```

---

## 7. Porting to libbpf (Embedded)

### 7.1 Why libbpf?

**BCC challenges on embedded:**
- Large dependencies (Python, LLVM)
- Compiles BPF at runtime (slow, high memory)

**libbpf advantages:**
- Minimal dependencies (single C library)
- Pre-compiled BPF bytecode
- CO-RE (Compile Once, Run Everywhere)

### 7.2 Write libbpf Program

**Create `hello_libbpf.bpf.c`:**
```c
#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>

SEC("kprobe/__arm64_sys_execve")
int hello_bpf(void *ctx) {
    char msg[] = "Hello from libbpf!\n";
    bpf_trace_printk(msg, sizeof(msg));
    return 0;
}

char LICENSE[] SEC("license") = "GPL";
```

**Compile to BPF bytecode:**
```bash
clang -O2 -target bpf -c hello_libbpf.bpf.c -o hello_libbpf.bpf.o
```

**Loader program `hello_libbpf.c`:**
```c
#include <stdio.h>
#include <bpf/libbpf.h>
#include <bpf/bpf.h>

int main() {
    struct bpf_object *obj;
    struct bpf_program *prog;
    struct bpf_link *link;
    
    // Load BPF object
    obj = bpf_object__open_file("hello_libbpf.bpf.o", NULL);
    if (!obj) return 1;
    
    bpf_object__load(obj);
    
    // Attach to kprobe
    prog = bpf_object__find_program_by_name(obj, "hello_bpf");
    link = bpf_program__attach(prog);
    
    printf("Attached. Check /sys/kernel/debug/tracing/trace_pipe\n");
    getchar();  // Wait for Ctrl-C
    
    bpf_link__destroy(link);
    bpf_object__close(obj);
    return 0;
}
```

**Compile loader:**
```bash
gcc -o hello_libbpf hello_libbpf.c -lbpf
```

**Run:**
```bash
sudo ./hello_libbpf &
sudo cat /sys/kernel/debug/tracing/trace_pipe
```

---

## 8. Real-World Use Cases

### 8.1 Detect Unauthorized File Access

**Monitor sensitive files:**
```python
from bcc import BPF

prog = """
int trace_open(struct pt_regs *ctx, const char *filename) {
    char fn[256];
    bpf_probe_read_user(&fn, sizeof(fn), (void *)filename);
    
    // Check for /etc/shadow access
    char target[] = "/etc/shadow";
    for (int i = 0; i < sizeof(target); i++) {
        if (fn[i] != target[i]) return 0;
    }
    
    bpf_trace_printk("ALERT: /etc/shadow accessed!\\n");
    return 0;
}
"""

b = BPF(text=prog)
b.attach_kprobe(event="do_sys_open", fn_name="trace_open")
b.trace_print()
```

### 8.2 Network Monitoring

**Track bandwidth per process:**
```python
# Use tcptop BCC tool
sudo /usr/share/bcc/tools/tcptop
```

**Output:**
```
PID    COMM         LADDR                 RADDR                  RX_KB  TX_KB
567    curl         192.168.0.100:54321   93.184.216.34:80         128     12
568    sshd         192.168.0.100:22      192.168.0.1:12345        456    234
```

---

## 9. Performance Considerations

### 9.1 Overhead Measurement

**eBPF has minimal overhead (~1-5%):**

```bash
# Baseline
time ./benchmark

# With eBPF tracing
sudo python3 trace_open.py &
time ./benchmark
```

**Compare execution times.**

### 9.2 Optimization Tips

- Use **maps** instead of `bpf_trace_printk()` for production
- **Filter in kernel** to reduce data transfer
- Use **tail calls** for complex logic
- Minimize **map lookups**

---

## 10. Troubleshooting

### 10.1 BPF Verifier Errors

**Error:** "back-edge in program"
- **Cause**: Loop detected
- **Fix**: Unroll loops or use bounded iteration

**Error:** "invalid access to map value"
- **Cause**: Unvalidated pointer
- **Fix**: Check pointer before dereferencing

### 10.2 Missing Kernel Symbols

**Error:** "could not open kprobe event"
```bash
# Check available kprobes
cat /sys/kernel/debug/tracing/available_filter_functions | grep do_sys_open
```

---

## 11. Key Takeaways

**Accomplished:**
1. ✅ Understood eBPF architecture
2. ✅ Used pre-built BCC tools
3. ✅ Wrote custom BCC Python scripts
4. ✅ Used BPF maps for data collection
5. ✅ Ported to libbpf for embedded
6. ✅ Traced network and file I/O

**Essential Tools:**
- `execsnoop`: Monitor process execution
- `opensnoop`: Trace file opens
- `tcpconnect`: Track TCP connections
- `biotop`: Disk I/O monitoring

**Next Steps:**
- **Lab 25**: Kernel debugging (KGDB, OOPS)
- **Lab 26**: Crash dump analysis

---

## 12. Verification Checklist

- [ ] Can run BCC pre-built tools
- [ ] Can write custom BCC scripts
- [ ] Understand BPF maps
- [ ] Can trace kernel and userspace events
- [ ] Know when to use BCC vs libbpf
- [ ] Can debug BPF verifier errors

---

**End of Lab 24**

*The Guide rates this lab: **Mostly Harmless** ⭐⭐⭐⭐*

eBPF is revolutionizing Linux observability and security. It enables powerful, production-safe tracing without kernel modifications, making it ideal for debugging complex systems and enforcing security policies.
