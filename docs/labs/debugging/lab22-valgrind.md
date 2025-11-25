# Lab 22: Memory Debugging with Valgrind

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about debugging:

*"Debugging is the art of figuring out why your code doesn't work, as opposed to why you thought it would work. This is similar to the difference between what Deep Thought calculated (42) and what everyone expected (a useful answer). Both are technically correct, but only one is helpful."*

## Objectives

Master Valgrind for detecting memory leaks, buffer overflows, use-after-free bugs, and other memory errors that cause crashes and security vulnerabilities.

**What You'll Learn:**
- Detect memory leaks with Memcheck
- Find buffer overflows and underruns
- Identify use-after-free errors
- Debug with vgdb (Valgrind + GDB)
- Profile heap usage with Massif
- Optimize cache performance with Cachegrind

**Time Required:** 3-4 hours

---

## Prerequisites

**Hardware:**
- BeaglePlay board
- Development workstation
- 2GB+ RAM recommended

**Software:**
- Valgrind installed
- Programs compiled with `-g` debug symbols

---

## 1. Introduction to Valgrind

### 1.1 What is Valgrind?

**Valgrind** is a dynamic analysis framework with multiple tools:
- **Memcheck**: Memory error detector (default)
- **Massif**: Heap profiler
- **Cachegrind**: Cache profiler
- **Helgrind**: Thread error detector
- **Callgrind**: Call-graph profiler

### 1.2 Install Valgrind

**On BeaglePlay:**
```bash
# Buildroot
opkg install valgrind

# Debian/Ubuntu
apt-get install valgrind

# Yocto: Add to image
IMAGE_INSTALL:append = " valgrind"
```

**Verify:**
```bash
valgrind --version
# valgrind-3.21.0
```

---

## 2. Memory Leak Detection

### 2.1 Simple Memory Leak

**Create `leak_simple.c`:**
```c
#include <stdlib.h>

int main() {
    int *array = malloc(100 * sizeof(int));
    array[0] = 42;
    // Forgot to free(array)!
    return 0;
}
```

**Compile:**
```bash
aarch64-linux-gnu-gcc -g -o leak_simple leak_simple.c
```

**Run with Valgrind:**
```bash
valgrind --leak-check=full ./leak_simple
```

**Output:**
```
==567== Memcheck, a memory error detector
==567== Command: ./leak_simple
==567== 
==567== HEAP SUMMARY:
==567==     in use at exit: 400 bytes in 1 blocks
==567==   total heap usage: 1 allocs, 0 frees, 400 bytes allocated
==567== 
==567== 400 bytes in 1 blocks are definitely lost in loss record 1 of 1
==567==    at 0x4839D8C: malloc (vg_replace_malloc.c:381)
==567==    by 0x1086B7: main (leak_simple.c:4)
==567== 
==567== LEAK SUMMARY:
==567==    definitely lost: 400 bytes in 1 blocks
==567==    indirectly lost: 0 bytes in 0 blocks
==567==      possibly lost: 0 bytes in 0 blocks
==567==    still reachable: 0 bytes in 0 blocks
==567== 
==567== ERROR SUMMARY: 1 errors from 1 contexts
```

**Analysis:**
- **400 bytes lost** at line 4 (`malloc`)
- **0 frees** vs **1 allocs**

**Fix:**
```c
free(array);
```

### 2.2 Leak Types

**Definitely lost:**
```c
int *p = malloc(100);
p = NULL;  // Lost reference!
```

**Indirectly lost:**
```c
struct node {
    int data;
    struct node *next;
};

struct node *head = malloc(sizeof(struct node));
head->next = malloc(sizeof(struct node));
free(head);  // Lost head->next!
```

**Still reachable:**
```c
int *p = malloc(100);
// Program exits, pointer still valid
// Not a "leak" but not freed
```

**Possibly lost:**
```c
int *p = malloc(100);
p++;  // Interior pointer
// Valgrind unsure if this is intentional
```

### 2.3 Complex Leak Example

**Create `leak_complex.c`:**
```c
#include <stdlib.h>
#include <string.h>

typedef struct {
    char *name;
    int *data;
} Record;

Record* create_record(const char *n) {
    Record *r = malloc(sizeof(Record));
    r->name = strdup(n);  // Allocates memory
    r->data = malloc(100 * sizeof(int));
    return r;
}

void free_record_buggy(Record *r) {
    free(r->name);
    // Forgot to free r->data!
    free(r);
}

int main() {
    Record *rec = create_record("test");
    free_record_buggy(rec);
    return 0;
}
```

**Run Valgrind:**
```bash
valgrind --leak-check=full ./leak_complex
```

**Output:**
```
==567== 400 bytes in 1 blocks are definitely lost in loss record 1 of 1
==567==    at 0x4839D8C: malloc (vg_replace_malloc.c:381)
==567==    by 0x108723: create_record (leak_complex.c:11)
==567==    by 0x108789: main (leak_complex.c:20)
```

**Shows `r->data` allocation never freed.**

---

## 3. Invalid Memory Access

### 3.1 Buffer Overflow

**Create `overflow.c`:**
```c
#include <string.h>

int main() {
    char buffer[10];
    strcpy(buffer, "This string is way too long!");  // Overflow!
    return 0;
}
```

**Run Valgrind:**
```bash
valgrind ./overflow
```

**Output:**
```
==567== Invalid write of size 1
==567==    at 0x483970C: strcpy (vg_replace_strmem.c:523)
==567==    by 0x1086C7: main (overflow.c:5)
==567==  Address 0x4a3f04a is 0 bytes after a block of size 10 alloc'd
==567==    at 0x483977F: malloc (vg_replace_malloc.c:381)
==567==    by 0x1086B3: main (overflow.c:4)
```

**Detected write beyond allocated buffer.**

### 3.2 Use-After-Free

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

**Run Valgrind:**
```bash
valgrind ./use_after_free
```

**Output:**
```
==567== Invalid read of size 4
==567==    at 0x1086D7: main (use_after_free.c:8)
==567==  Address 0x4a3f040 is 0 bytes inside a block of size 4 free'd
==567==    at 0x48399AB: free (vg_replace_malloc.c:755)
==567==    by 0x1086C3: main (use_after_free.c:7)
```

**Detected read from freed memory.**

### 3.3 Uninitialized Memory

**Create `uninit.c`:**
```c
#include <stdio.h>
#include <stdlib.h>

int main() {
    int *ptr = malloc(sizeof(int));
    if (*ptr == 42) {  // Reading uninitialized!
        printf("Magic number!\n");
    }
    free(ptr);
    return 0;
}
```

**Run Valgrind:**
```bash
valgrind ./uninit
```

**Output:**
```
==567== Conditional jump or move depends on uninitialised value(s)
==567==    at 0x1086C7: main (uninit.c:6)
```

---

## 4. Debugging with vgdb

### 4.1 Combine Valgrind and GDB

**Start program under Valgrind:**
```bash
valgrind --vgdb=yes --vgdb-error=0 ./my-app
```

**Output:**
```
==567== TO CONTROL THIS PROCESS USING vgdb:
==567==   target remote | /usr/lib/valgrind/vgdb --pid=567
```

**In another terminal, start GDB:**
```bash
gdb ./my-app
```

**In GDB, connect to vgdb:**
```gdb
(gdb) target remote | vgdb --pid=567
```

**Now GDB controls program running under Valgrind!**

### 4.2 Debug Memory Error with vgdb

**When Valgrind detects error, it pauses:**

```gdb
(gdb) continue
# Valgrind detects invalid write

(gdb) backtrace
#0  strcpy () at vg_replace_strmem.c:523
#1  0x1086c7 in main () at overflow.c:5

(gdb) print buffer
$1 = "This strin"  # Truncated due to overflow

(gdb) x/20c buffer
# Examine memory to see corruption
```

### 4.3 Monitor Specific Allocation

```gdb
(gdb) monitor leak_check full reachable any
# Request leak check via vgdb
```

---

## 5. Heap Profiling with Massif

### 5.1 Profile Heap Usage

**Create `heap_growth.c`:**
```c
#include <stdlib.h>
#include <unistd.h>

int main() {
    for (int i = 0; i < 100; i++) {
        malloc(1024 * 1024);  // 1MB allocations
        sleep(1);
    }
    return 0;
}
```

**Run Massif:**
```bash
valgrind --tool=massif ./heap_growth
```

**Massif creates `massif.out.<pid>` file.**

### 5.2 Visualize Heap Profile

```bash
ms_print massif.out.567
```

**Output:**
```
    MB
100.0^                                               #
     |                                             :#:
     |                                           ::#::
     |                                         :::#:::
 50.0+                                       ::::#::::
     |                                     :::::#:::::
     |                                   ::::::#::::::
     |                                 :::::::#:::::::
     |                               ::::::::#::::::::
  0.0+@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#@@@@@@@@@
    +------------------------------------------------------
       0                  Time                         100s

Number of snapshots: 50
 Detailed snapshots: [5, 10, 15, 20, 25, 30, 35, 40, 45, 50]
```

**ASCII graph shows heap growth over time.**

### 5.3 Identify Allocation Hotspots

**At peak (snapshot 50):**
```
Snapshot 50
================================================================================
  n        time(i)         total(B)   useful-heap(B) extra-heap(B)    stacks(B)
--------------------------------------------------------------------------------
 50     50,000,000      100,000,000      100,000,000             0            0

99.8% (100,000,000B) (heap allocation functions) malloc/new/new[], --alloc-fns, etc.
->99.8% (100,000,000B) 0x1086C7: main (heap_growth.c:5)
```

**Shows 99.8% allocated at line 5 (`malloc`).**

---

## 6. Cache Profiling with Cachegrind

### 6.1 Profile Cache Misses

```bash
valgrind --tool=cachegrind ./my-app
```

**Creates `cachegrind.out.<pid>`.**

### 6.2 Analyze Cache Performance

```bash
cg_annotate cachegrind.out.567
```

**Output:**
```
I1 cache:         16384 B, 64 B, 4-way associative
D1 cache:         16384 B, 64 B, 4-way associative
LL cache:       2097152 B, 64 B, 16-way associative

Ir           I1mr  ILmr          Dr        D1mr  DLmr          Dw        D1mw  DLmw 
================================================================================
1,245,678      123    45     456,789      1,234    567     234,567         89    34  PROGRAM TOTALS

Ir           I1mr  ILmr          Dr        D1mr  DLmr          Dw        D1mw  DLmw  file:function
--------------------------------------------------------------------------------
  456,789       45    12     123,456        567    234      98,765         34    12  heap_growth.c:main
```

**Metrics:**
- **Ir**: Instruction reads
- **Dr/Dw**: Data reads/writes
- **I1mr/D1mr**: L1 cache misses
- **ILmr/DLmr**: Last-level cache misses

---

## 7. Suppression Files

### 7.1 Ignore Known Issues

**Create `valgrind.supp`:**
```
{
   known_libc_leak
   Memcheck:Leak
   fun:malloc
   fun:*libc*
}
```

**Use suppression:**
```bash
valgrind --suppressions=valgrind.supp ./my-app
```

### 7.2 Generate Suppressions

```bash
valgrind --gen-suppressions=all ./my-app
```

**Prints suppression entries for each error.**

---

## 8. Performance Considerations

### 8.1 Valgrind Slowdown

**Valgrind makes programs ~10-30x slower.**

**Techniques:**
- Test with smaller datasets
- Profile specific parts
- Use on development builds only

### 8.2 Optimize Valgrind Usage

**Reduce overhead:**
```bash
# Basic leak check (faster)
valgrind --leak-check=summary ./my-app

# No leak check (even faster, just memory errors)
valgrind --leak-check=no ./my-app
```

---

## 9. Real-World Examples

### 9.1 Find Leak in Long-Running Daemon

```bash
# Start daemon under Valgrind
valgrind --leak-check=full --log-file=valgrind.log ./my-daemon &

# Let run for hours/days
# ...

# Request leak check
killall -USR1 my-daemon
# Valgrind outputs leak report
```

### 9.2 Debug Embedded Memory Constraints

**BeaglePlay has limited RAM:**

```bash
# Monitor heap usage
valgrind --tool=massif --massif-out-file=massif.out ./embedded-app

# Analyze
ms_print massif.out
# Find peak memory usage and allocation sites
```

---

## 10. Advanced Valgrind Options

### 10.1 Track File Descriptors

```bash
valgrind --track-fds=yes ./my-app
```

**Reports unclosed file descriptors at exit.**

### 10.2 Detailed Leak Info

```bash
valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes ./my-app
```

**Options:**
- `--show-leak-kinds=all`: Show all leak types
- `--track-origins=yes`: Track origin of uninitialized values (slower)

---

## 11. Troubleshooting

### 11.1 Valgrind Errors

**"Cannot execute binary file":**
- Cross-compiled binary needs Valgrind on target

**"vgpreload libraries not found":**
```bash
export LD_LIBRARY_PATH=/usr/lib/valgrind
```

### 11.2 False Positives

**System libraries may show "leaks":**
- Use suppression files
- Focus on your code's allocations

---

## 12. Key Takeaways

**Accomplished:**
1. ✅ Detected memory leaks with Memcheck
2. ✅ Found buffer overflows and use-after-free
3. ✅ Used vgdb for interactive debugging
4. ✅ Profiled heap with Massif
5. ✅ Analyzed cache performance with Cachegrind

**Essential Commands:**
- `valgrind --leak-check=full ./app`: Full leak check
- `valgrind --tool=massif ./app`: Heap profiling
- `valgrind --vgdb=yes ./app`: GDB integration
- `ms_print massif.out.PID`: View heap profile

**Next Steps:**
- **Lab 23**: System-wide profiling with perf and ftrace
- **Lab 24**: eBPF tracing

---

## 13. Verification Checklist

- [ ] Can detect memory leaks
- [ ] Can identify buffer overflows
- [ ] Can debug with vgdb
- [ ] Understand heap profiling
- [ ] Can suppress known false positives
- [ ] Know when to use each Valgrind tool

---

**End of Lab 22**

*The Guide rates this lab: **Mostly Harmless** ⭐⭐⭐⭐*

Valgrind is essential for producing robust, memory-safe software. The time invested in fixing memory errors pays dividends in stability, security, and easier maintenance.
