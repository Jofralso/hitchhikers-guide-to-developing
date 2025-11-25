# Lab 20: Application Debugging with GDB

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about GDB:

*"GDB is a debugger that allows you to peek inside your program while it's running, much like looking inside a Somebody Else's Problem field. Unlike SEP fields, however, GDB actually shows you what's there rather than making you ignore it."*

## Objectives

Master the GNU Debugger (GDB) for diagnosing crashes, analyzing coredumps, remote debugging, and automating debug tasks with Python scripting.

**What You'll Learn:**
- Compile with debug symbols (`-g`)
- Use GDB interactively to debug applications
- Analyze coredumps from crashed programs
- Remote debugging from workstation to BeaglePlay
- Automate debugging with GDB Python API
- Use Compiler Explorer for assembly analysis

**Time Required:** 3-4 hours

---

## Prerequisites

**Hardware:**
- BeaglePlay board with working Linux
- Development workstation
- Network connection

**Software:**
- Cross-compilation toolchain (from Lab 1)
- GDB and gdbserver
- Root access on BeaglePlay

---

## 1. Compiling with Debug Symbols

### 1.1 Debug vs Release Builds

**Without debug symbols (-O2 optimized):**
```bash
aarch64-linux-gnu-gcc -O2 -o app app.c
file app
# app: ELF 64-bit LSB executable, stripped
```

**With debug symbols (-g):**
```bash
aarch64-linux-gnu-gcc -g -O0 -o app app.c
file app
# app: ELF 64-bit LSB executable, not stripped
```

**Options:**
- **-g**: Include debug info
- **-O0**: No optimization (easier debugging)
- **-ggdb**: GDB-specific debug info

### 1.2 Check Debug Info

```bash
# Verify debug symbols present
readelf -S app | grep debug

# Should see sections like:
# .debug_info
# .debug_line
# .debug_str
```

### 1.3 Create Test Program

**Create `buggy.c`:**
```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int divide(int a, int b) {
    return a / b;  // Bug: no check for b == 0
}

void leak_memory() {
    char *ptr = malloc(1024);
    strcpy(ptr, "This memory will leak");
    // Bug: forgot to free(ptr)
}

void buffer_overflow() {
    char buffer[10];
    strcpy(buffer, "This string is way too long!");  // Bug: overflow
}

int main(int argc, char *argv[]) {
    printf("Starting buggy program...\n");
    
    if (argc > 1 && strcmp(argv[1], "crash") == 0) {
        printf("Triggering divide by zero...\n");
        int result = divide(10, 0);
        printf("Result: %d\n", result);
    }
    
    if (argc > 1 && strcmp(argv[1], "overflow") == 0) {
        printf("Triggering buffer overflow...\n");
        buffer_overflow();
    }
    
    if (argc > 1 && strcmp(argv[1], "leak") == 0) {
        printf("Leaking memory...\n");
        leak_memory();
    }
    
    printf("Program finished\n");
    return 0;
}
```

**Compile:**
```bash
aarch64-linux-gnu-gcc -g -O0 -o buggy buggy.c
scp buggy root@192.168.0.100:/tmp/
```

---

## 2. Interactive GDB Debugging

### 2.1 Starting GDB

**On BeaglePlay:**
```bash
ssh root@192.168.0.100
cd /tmp
gdb ./buggy
```

**GDB prompt:**
```
(gdb) 
```

### 2.2 Basic GDB Commands

**Set breakpoint:**
```gdb
(gdb) break main
Breakpoint 1 at 0xaaaaaaaa0750: file buggy.c, line 20.

(gdb) break divide
Breakpoint 2 at 0xaaaaaaaa0680: file buggy.c, line 5.

(gdb) break buggy.c:25
Breakpoint 3 at 0xaaaaaaaa0780: file buggy.c, line 25.
```

**Run program:**
```gdb
(gdb) run crash
Starting program: /tmp/buggy crash

Breakpoint 1, main (argc=2, argv=0xfffffffff8) at buggy.c:20
20	    printf("Starting buggy program...\n");
```

**Step through code:**
```gdb
(gdb) next          # Execute one line (step over)
(gdb) step          # Execute one line (step into functions)
(gdb) continue      # Continue to next breakpoint
(gdb) finish        # Execute until current function returns
```

### 2.3 Inspecting Variables

```gdb
(gdb) print argc
$1 = 2

(gdb) print argv[1]
$2 = 0xffffffffef "crash"

(gdb) print result
$3 = 0  # Uninitialized before assignment

(gdb) display result  # Auto-display on every step
(gdb) info locals     # Show all local variables
(gdb) info args       # Show function arguments
```

### 2.4 Examining Memory

```gdb
(gdb) x/s argv[1]     # Examine as string
0xffffffffef:	"crash"

(gdb) x/10x buffer    # Examine 10 hex words
0xfffffffff0:	0x00000000	0x00000000	...

(gdb) x/10i main      # Disassemble 10 instructions
0xaaaaaaaa0750 <main>:	stp	x29, x30, [sp, #-32]!
0xaaaaaaaa0754 <main+4>:	mov	x29, sp
```

### 2.5 Backtrace (Call Stack)

```gdb
(gdb) backtrace
#0  divide (a=10, b=0) at buggy.c:5
#1  0xaaaaaaaa0790 in main (argc=2, argv=0xfffffffff8) at buggy.c:25
```

---

## 3. Coredump Analysis

### 3.1 Enable Coredumps

**On BeaglePlay:**
```bash
# Check current limit
ulimit -c
# 0 means coredumps disabled

# Enable unlimited coredumps
ulimit -c unlimited

# Verify
ulimit -c
# unlimited
```

### 3.2 Trigger Crash and Generate Coredump

```bash
./buggy crash
```

**Output:**
```
Starting buggy program...
Triggering divide by zero...
Floating point exception (core dumped)
```

**Coredump created:**
```bash
ls -lh core
# -rw------- 1 root root 128K Jan 15 10:30 core
```

### 3.3 Analyze Coredump

```bash
gdb ./buggy core
```

**GDB output:**
```
Core was generated by `./buggy crash'.
Program terminated with signal SIGFPE, Arithmetic exception.
#0  divide (a=10, b=0) at buggy.c:5
5	    return a / b;
```

**Inspect state at crash:**
```gdb
(gdb) backtrace
#0  divide (a=10, b=0) at buggy.c:5
#1  0xaaaaaaaa0790 in main (argc=2, argv=0xfffffffff8) at buggy.c:25

(gdb) frame 0
#0  divide (a=10, b=0) at buggy.c:5
5	    return a / b;

(gdb) print a
$1 = 10

(gdb) print b
$2 = 0  # There's the bug!
```

### 3.4 Coredump Location Configuration

**Configure systemd coredump handler:**
```bash
cat /etc/systemd/coredump.conf
```

**Or use kernel core pattern:**
```bash
echo "/tmp/core.%e.%p" > /proc/sys/kernel/core_pattern
# %e = executable name
# %p = PID
```

---

## 4. Remote Debugging

### 4.1 Setup gdbserver on BeaglePlay

**On BeaglePlay:**
```bash
gdbserver :2345 ./buggy crash
```

**Output:**
```
Process ./buggy created; pid = 567
Listening on port 2345
```

### 4.2 Connect from Workstation

**On workstation:**
```bash
cd ~/beagleplay-labs/toolchain
gdb-multiarch ./buggy
```

**In GDB:**
```gdb
(gdb) target remote 192.168.0.100:2345
Remote debugging using 192.168.0.100:2345
Reading symbols from /lib/ld-linux-aarch64.so.1...

(gdb) break divide
Breakpoint 1 at 0xaaaaaaaa0680: file buggy.c, line 5.

(gdb) continue
```

**Advantages:**
- Debug from comfortable workstation
- Access full source code locally
- Use graphical GDB frontends

### 4.3 Attach to Running Process

**Find PID on BeaglePlay:**
```bash
ps aux | grep my-app
# root  789  0.5  1.2  ...  my-app
```

**Start gdbserver attached:**
```bash
gdbserver :2345 --attach 789
```

**Connect from workstation:**
```gdb
(gdb) target remote 192.168.0.100:2345
(gdb) continue
```

---

## 5. GDB Python Scripting

### 5.1 Check Python Support

```gdb
(gdb) python print("GDB Python is working!")
GDB Python is working!
```

### 5.2 Simple Python Commands

**Print all local variables:**
```gdb
(gdb) python
>frame = gdb.selected_frame()
>block = frame.block()
>for symbol in block:
>    if symbol.is_argument or symbol.is_variable:
>        print(f"{symbol.name} = {symbol.value(frame)}")
>end
argc = 2
argv = 0xfffffffff8
result = <optimized out>
```

### 5.3 Custom GDB Command in Python

**Create `debug_helpers.py`:**
```python
import gdb

class PrintStructCommand(gdb.Command):
    """Print all fields of a struct"""
    
    def __init__(self):
        super(PrintStructCommand, self).__init__(
            "print-struct", gdb.COMMAND_DATA
        )
    
    def invoke(self, arg, from_tty):
        try:
            val = gdb.parse_and_eval(arg)
            struct_type = val.type
            
            if struct_type.code != gdb.TYPE_CODE_STRUCT:
                print("Error: Not a struct")
                return
            
            print(f"Struct {struct_type.tag}:")
            for field in struct_type.fields():
                field_val = val[field.name]
                print(f"  {field.name} = {field_val}")
        except gdb.error as e:
            print(f"Error: {e}")

PrintStructCommand()
```

**Load in GDB:**
```gdb
(gdb) source debug_helpers.py
(gdb) print-struct my_struct_var
```

### 5.4 Automated Debugging Script

**Create `auto_debug.py`:**
```python
import gdb

# Set breakpoints
gdb.execute("break main")
gdb.execute("break divide")

# Run program
gdb.execute("run crash")

# Collect stack traces at each breakpoint
traces = []

class BreakpointHandler(gdb.Breakpoint):
    def stop(self):
        frame = gdb.selected_frame()
        bt = gdb.execute("backtrace", to_string=True)
        traces.append({
            'location': frame.name(),
            'backtrace': bt
        })
        return False  # Continue execution

# Set up handlers
for bp in gdb.breakpoints():
    bp.__class__ = BreakpointHandler

print("Automated debugging complete")
print(f"Collected {len(traces)} stack traces")
```

**Run script:**
```bash
gdb -batch -x auto_debug.py ./buggy
```

---

## 6. Advanced GDB Features

### 6.1 Conditional Breakpoints

```gdb
(gdb) break divide if b == 0
Breakpoint 1 at 0xaaaaaaaa0680: file buggy.c, line 5.

# Break only when condition is true
(gdb) run crash
Breakpoint 1, divide (a=10, b=0) at buggy.c:5
```

### 6.2 Watchpoints (Break on Variable Change)

```gdb
(gdb) watch result
Hardware watchpoint 2: result

(gdb) continue
Hardware watchpoint 2: result
Old value = 0
New value = -1234567
```

### 6.3 Reverse Debugging

**Record execution:**
```gdb
(gdb) record
(gdb) continue
# Program crashes

(gdb) reverse-step
# Step backwards!

(gdb) reverse-continue
# Run backwards to previous breakpoint
```

---

## 7. Compiler Explorer Integration

### 7.1 Understanding Assembly

**Use Compiler Explorer (https://godbolt.org) to see assembly:**

**C code:**
```c
int divide(int a, int b) {
    return a / b;
}
```

**ARM64 assembly output:**
```asm
divide:
    sdiv    w0, w0, w1    ; Signed divide
    ret
```

**Compare with optimized version:**
```bash
# -O2 optimization
aarch64-linux-gnu-gcc -O2 -S divide.c -o divide.s
cat divide.s
```

### 7.2 Debug Assembly in GDB

```gdb
(gdb) disassemble divide
Dump of assembler code for function divide:
   0x0000aaaaaaaa0680 <+0>:     sdiv    w0, w0, w1
   0x0000aaaaaaaa0684 <+4>:     ret

(gdb) break *0x0000aaaaaaaa0680
(gdb) stepi  # Step one instruction
```

---

## 8. Practical Debugging Scenarios

### 8.1 Null Pointer Dereference

**Create `nullptr.c`:**
```c
#include <stdio.h>

int main() {
    char *ptr = NULL;
    printf("%s\n", ptr);  // Crash!
    return 0;
}
```

**Debug:**
```bash
aarch64-linux-gnu-gcc -g -o nullptr nullptr.c
gdb ./nullptr
```

```gdb
(gdb) run
Program received signal SIGSEGV, Segmentation fault.
0x0000fffff7e12345 in strlen () from /lib/aarch64-linux-gnu/libc.so.6

(gdb) backtrace
#0  0x0000fffff7e12345 in strlen () from /lib/libc.so.6
#1  0x0000aaaaaaaa0750 in main () at nullptr.c:5

(gdb) frame 1
#1  0x0000aaaaaaaa0750 in main () at nullptr.c:5
5	    printf("%s\n", ptr);

(gdb) print ptr
$1 = 0x0 <-- NULL pointer
```

### 8.2 Use-After-Free

**Create `use_after_free.c`:**
```c
#include <stdlib.h>
#include <stdio.h>

int main() {
    int *ptr = malloc(sizeof(int));
    *ptr = 42;
    free(ptr);
    printf("%d\n", *ptr);  // Use after free!
    return 0;
}
```

**Debug with watchpoint:**
```gdb
(gdb) watch *ptr
(gdb) run
# Watchpoint triggers when ptr is freed and accessed
```

---

## 9. GDB Frontends

### 9.1 TUI Mode (Text UI)

```bash
gdb -tui ./buggy
```

**Or enable in session:**
```gdb
(gdb) tui enable
```

**Shows source code and assembly in split view.**

### 9.2 GDB Dashboard

**Install:**
```bash
wget -P ~ https://git.io/.gdbinit
```

**Enhanced GDB interface with:**
- Source code
- Assembly
- Registers
- Stack
- Threads

### 9.3 IDE Integration

**VS Code with GDB:**
- Install "C/C++" extension
- Configure `.vscode/launch.json`:

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Remote Debug",
            "type": "cppdbg",
            "request": "launch",
            "program": "${workspaceFolder}/buggy",
            "miDebuggerServerAddress": "192.168.0.100:2345",
            "miDebuggerPath": "/usr/bin/gdb-multiarch"
        }
    ]
}
```

---

## 10. Troubleshooting GDB Issues

### 10.1 Missing Debug Symbols

**Error:**
```
Reading symbols from ./app...(no debugging symbols found)
```

**Solution:**
```bash
# Recompile with -g
aarch64-linux-gnu-gcc -g -O0 -o app app.c
```

### 10.2 Optimized Code Debugging

**Variables show as `<optimized out>`:**

**Solution:** Compile with `-O0` or use `-Og` (optimize for debugging).

### 10.3 Source Path Issues

**GDB can't find source files:**

```gdb
(gdb) directory /path/to/source
(gdb) set substitute-path /old/path /new/path
```

---

## 11. Key Takeaways

**Accomplished:**
1. ✅ Compiled with debug symbols
2. ✅ Used GDB interactively
3. ✅ Analyzed coredumps
4. ✅ Remote debugging with gdbserver
5. ✅ Automated debugging with Python
6. ✅ Understood assembly with Compiler Explorer

**Essential GDB Commands:**
- `break`: Set breakpoint
- `run`: Start program
- `next/step`: Execute code
- `print`: Inspect variables
- `backtrace`: Show call stack
- `continue`: Resume execution

**Next Steps:**
- **Lab 21**: System call tracing with strace/ltrace
- **Lab 22**: Memory debugging with valgrind

---

## 12. Verification Checklist

- [ ] Can compile with debug symbols
- [ ] Can set breakpoints and step through code
- [ ] Can analyze coredumps to find crash cause
- [ ] Can debug remotely with gdbserver
- [ ] Understand basic GDB Python scripting
- [ ] Can read assembly output

---

**End of Lab 20**

*The Guide rates this lab: **Mostly Harmless** ⭐⭐⭐⭐*

GDB is the cornerstone of low-level debugging on Linux. Mastering it enables you to diagnose the most challenging bugs, from crashes to subtle memory corruption issues.
