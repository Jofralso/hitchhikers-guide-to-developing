# Lab 1: Building a Cross-Compilation Toolchain

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about cross-compilation toolchains:

*"A cross-compilation toolchain is a bit like a babel fish for computer architectures. It translates your perfectly reasonable x86_64 instructions into ARM64 gibberish that only a BeaglePlay can understand. The main difference is that the babel fish was designed by a benevolent creator who wanted universal communication, whereas the toolchain was designed by compiler engineers who, while generally quite pleasant at parties, seem to have been educated by Vogons."*

This is, of course, unfair to compiler engineers. Most of them are very nice people once you get to know them. They just happen to work in a field where a missing semicolon can cause your computer to develop what can only be described as electronic depression.

**Platform**: BeaglePlay (ARM Cortex-A53, 64-bit) - *Also known as "the computer that speaks a different language"*  
**Prerequisites**: Linux command line basics, C programming, your towel  
**Duration**: 2-3 hours (or approximately 42 minutes in improbable circumstances) (or 42 minutes if you're a time traveler)  
**Difficulty**: ⭐⭐⭐☆☆ (3/5 on the Vogon poetry scale)

---

## Objectives

By the end of this lab, you will be able to:

- [ ] Understand the components of a cross-compilation toolchain (without your brain leaking out your ears)
- [ ] Configure Crosstool-NG for ARM64 architecture (mostly harmless)
- [ ] Build a custom toolchain targeting the BeaglePlay's Cortex-A53 processor
- [ ] Test the toolchain with QEMU user-mode emulation
- [ ] Understand the difference between C libraries (musl, glibc, uclibc) and why this matters more than you'd think

---

## Background

### What is a Cross-Compilation Toolchain?

The Guide's definition of **cross-compilation toolchain**:

*Cross-compilation toolchain (n): A set of development tools that allows you to compile code on one platform (your development PC with its fancy x86_64 processor) to run on a completely different platform (the BeaglePlay with its ARM64/AARCH64 processor, which speaks an entirely different dialect of machine code). This is roughly equivalent to writing a letter in English while sitting in London, having it automatically translated to Betelgeusean, and then mailing it to someone in the Betelgeuse system who has never heard of Earth. The remarkable thing is that it actually works.*

**Components** (All essential, like knowing where your towel is):
- **Compiler**: `gcc` or `clang` - translates C/C++ to machine code (thinks it knows everything)
- **Binutils**: Tools like `ld` (linker), `as` (assembler), `objdump`, `ar` (the supporting cast)
- **C Library**: Provides standard functions (printf, malloc, etc.) - the babel fish of function calls
- **Kernel Headers**: Interface to Linux system calls (Vogon poetry for the kernel)
- **GDB**: GNU Debugger for debugging cross-compiled programs (Marvin's favorite tool)

### Why Build Your Own Toolchain?

You might reasonably ask, "Why build a toolchain when pre-built ones exist?" This is an excellent question, showing you have the survival instincts Arthur Dent lacked when faced with planetary demolition.

While pre-built toolchains exist (like `gcc-aarch64-linux-gnu`), building your own offers:

1. **Full Control**: Choose specific GCC version, C library, optimizations (be your own Slartibartfast)
2. **Compatibility**: Match exact kernel version and system requirements (avoid Vogon-level compatibility issues)
3. **Size Optimization**: Exclude unnecessary features for embedded systems (pack light, like for hitchhiking)
4. **Learning**: Understanding what's inside the "black box" (because curiosity didn't kill Ford Prefect)

*Ford Prefect's note: "Always know how your toolchain works. You never know when you'll need to rebuild it at short notice, possibly while hanging onto the side of a hyperspace freighter."*

### C Library Choices

The Guide's take on C libraries: "Choosing a C library is like choosing which Pan Galactic Gargle Blaster to drink. They all do roughly the same thing, but with vastly different levels of consequences."

| Library | Size | Features | Best For | Guide Rating |
|---------|------|----------|----------|--------------|
| **glibc** | Large (~2MB) | Full POSIX, best compatibility | Desktop, servers | "Mostly Harmless" |
| **musl** | Small (~600KB) | Clean, standards-compliant | Modern embedded | "Froody" |
| **uclibc-ng** | Tiny (~400KB) | Configurable features | Memory-constrained systems | "Hoopy" |

**For this lab**: We'll use **musl** - it's lightweight yet fully functional.

---

## Prerequisites Check

Before starting, ensure you have:

```bash
# Check available disk space (need ~10 GB)
df -h ~

# Check RAM (need at least 4 GB)
free -h

# Verify Ubuntu version
lsb_release -a
# Recommended: Ubuntu 24.04 LTS
```

---

## Setup

### Workspace Preparation

```bash
# Create lab directory
mkdir -p ~/embedded-linux-labs/lab01-toolchain
cd ~/embedded-linux-labs/lab01-toolchain

# Set environment variable for convenience
export LAB_DIR=$PWD
echo "Lab directory: $LAB_DIR"
```

### Required Packages

```bash
# Update package database
sudo apt update

# Install build dependencies
sudo apt install -y \
    build-essential \
    git \
    autoconf \
    bison \
    flex \
    texinfo \
    help2man \
    gawk \
    libtool-bin \
    libncurses5-dev \
    unzip \
    gettext \
    python3 \
    qemu-user

# Verify installations
gcc --version
git --version
python3 --version
```

**Expected**: GCC 11.4 or newer, Git 2.34 or newer, Python 3.10 or newer

---

## Part 1: Getting Crosstool-NG

### Step 1.1: Clone Crosstool-NG Repository

**Goal**: Download the Crosstool-NG source code

```bash
# Clone from GitHub
git clone https://github.com/crosstool-ng/crosstool-ng.git
cd crosstool-ng

# Checkout tested version
git checkout crosstool-ng-1.26.0

# Verify checkout
git describe --tags
```

**Expected Output**:
```
crosstool-ng-1.26.0
```

**What is Crosstool-NG?**  
A flexible framework for building cross-compilation toolchains. It automates downloading, configuring, and building all toolchain components.

### Step 1.2: Bootstrap Crosstool-NG

**Goal**: Generate configuration scripts

```bash
# Run bootstrap to create configure script
./bootstrap

# Check for generated files
ls -l configure
```

**Expected**: You should see a `configure` script created

**Troubleshooting**:
- **Error**: "autoconf: command not found"
  - **Solution**: `sudo apt install autoconf automake`

### Step 1.3: Build Crosstool-NG

**Goal**: Compile Crosstool-NG for local use

```bash
# Configure for local installation (no system-wide install)
./configure --enable-local

# Build (takes ~2 minutes)
make -j$(nproc)

# Verify build
./ct-ng version
```

**Expected Output**:
```
This is crosstool-NG version crosstool-ng-1.26.0
```

**What is `--enable-local`?**  
Keeps ct-ng in the current directory instead of installing to `/usr/local/bin`. Useful for testing without root privileges.

---

## Part 2: Configuring the Toolchain

### Step 2.1: List Available Samples

**Goal**: Explore pre-configured toolchain templates

```bash
# List all sample configurations
./ct-ng list-samples

# Filter for ARM64 samples
./ct-ng list-samples | grep aarch64
```

**Expected Output** (partial):
```
aarch64-unknown-linux-gnu
aarch64-unknown-linux-musl
aarch64-rpi3-linux-gnu
```

**What are samples?**  
Pre-made configurations for common architectures. We'll use one as a starting point and customize it.

### Step 2.2: Load Base Configuration

**Goal**: Start with ARM64/musl sample

```bash
# Load the aarch64-unknown-linux-musl sample
./ct-ng aarch64-unknown-linux-musl

# Verify configuration loaded
ls -l .config
```

**Expected**: `.config` file created with default settings

### Step 2.3: Customize Configuration

**Goal**: Optimize for BeaglePlay's Cortex-A53 processor

```bash
# Launch menuconfig interface
./ct-ng menuconfig
```

**Navigation**: Use arrow keys, Enter to select, Space to toggle, `/` to search, `?` for help

#### Configuration Changes:

**1. Path and misc options**:
- Navigate to: `Paths and misc options`
- Enable: `☑ Try features marked as EXPERIMENTAL`
- **Why**: Allows newer GCC versions and features

**2. Target options**:
- Navigate to: `Target options`
- Set `Emit assembly for CPU (ARCH_CPU)`: `cortex-a53`
  - **Why**: BeaglePlay uses TI AM62 with Cortex-A53 cores
- Verify `Endianness`: `Little endian` (default)
  - **Why**: ARM Cortex-A53 uses little-endian mode

**3. Toolchain options**:
- Navigate to: `Toolchain options`
- Set `Tuple's vendor string`: `beagleplay`
  - **Result**: Toolchain will be named `aarch64-beagleplay-linux-musl`
- Set `Tuple's alias`: `aarch64-linux`
  - **Why**: Allows using shorter command `aarch64-linux-gcc`

**4. Operating System**:
- Navigate to: `Operating System → Version of linux`
- Select: `6.6.x` (or closest available LTS version)
  - **Why**: Match kernel version you'll use on BeaglePlay
  - **Important**: Toolchain kernel headers should NOT be newer than target kernel

**5. C-library**:
- Navigate to: `C-library`
- Verify: `C library` = `musl` (LIBC_MUSL)
- Keep default musl version (latest stable)
  - **Why**: Lightweight, modern, clean codebase

**6. C compiler**:
- Navigate to: `C compiler`
- Set `Version of gcc`: `13.3.0` or latest stable
- Verify: `☑ C++` is enabled
  - **Why**: Many embedded projects use C++

**7. Debug facilities**:
- Navigate to: `Debug facilities`
- **Disable all debug tools** (gdb, strace, ltrace)
  - **Why**: We'll build these separately later with better control
  - Saves compilation time and disk space

**Save and Exit**: Press `S` to save, then `Q` to quit

### Step 2.4: Review Configuration

```bash
# Display current configuration
./ct-ng show-config

# Check tuple (toolchain naming)
./ct-ng show-tuple
```

**Expected**:
```
aarch64-beagleplay-linux-musl
```

---

## Part 3: Building the Toolchain

*The Guide notes: "Building a toolchain from scratch is like waiting for a Vogon to finish reading poetry - it takes an improbably long time, but the end result is (hopefully) less painful."*

### Step 3.1: Start the Build

**Goal**: Compile the complete toolchain

```bash
# Start build (this takes 30-60 minutes)
./ct-ng build

# Monitor progress in another terminal (optional)
# tail -f ~/crosstool-ng/.build/build.log
```

**What happens during build**:
1. Download source tarballs (Linux headers, GCC, binutils, musl)
2. Extract archives
3. Configure each component
4. Build binutils
5. Build initial GCC (stage 1)
6. Build musl C library
7. Build full GCC (stage 2)
8. Create sysroot with headers and libraries
9. Install to `~/x-tools/`

**Build time**: 30-60 minutes depending on CPU  
**Disk space used**: ~9 GB during build, ~2 GB final

**Progress indicators**:
```
[INFO ]  Installing cross-gdb
[EXTRA]    Configuring cross-gdb
[INFO ]  Building cross-gdb
[INFO ]  Installing cross-gdb
```

**Troubleshooting**:
- **Error**: "No space left on device"
  - **Solution**: Free up disk space, need ~10 GB free
  
- **Error**: Build fails with compilation errors
  - **Solution**: Check build.log: `tail -100 ~/.build/build.log`
  
- **Build takes too long** (>2 hours)
  - **Check**: CPU usage with `htop`, build should use all cores
  - **Note**: First build is slow, subsequent builds are faster

### Step 3.2: Verify Installation

```bash
# Check toolchain installation
ls -lh ~/x-tools/

# List toolchain directory
ls ~/x-tools/aarch64-beagleplay-linux-musl/

# Check bin directory
ls ~/x-tools/aarch64-beagleplay-linux-musl/bin/
```

**Expected files in bin/**:
```
aarch64-beagleplay-linux-musl-gcc
aarch64-beagleplay-linux-musl-g++
aarch64-beagleplay-linux-musl-ld
aarch64-beagleplay-linux-musl-as
aarch64-beagleplay-linux-musl-objdump
aarch64-linux-gcc (alias)
aarch64-linux-g++ (alias)
```

---

## Part 4: Testing the Toolchain

### Step 4.1: Add Toolchain to PATH

```bash
# Add toolchain to current session
export PATH=$HOME/x-tools/aarch64-beagleplay-linux-musl/bin:$PATH

# Verify
which aarch64-linux-gcc

# Make permanent (optional)
echo 'export PATH=$HOME/x-tools/aarch64-beagleplay-linux-musl/bin:$PATH' >> ~/.bashrc
```

### Step 4.2: Create Test Program

```bash
# Create test directory
cd ~/embedded-linux-labs/lab01-toolchain
mkdir test
cd test

# Create hello.c
cat > hello.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    printf("╔══════════════════════════════════════════╗\n");
    printf("║   Hello from BeaglePlay!                ║\n");
    printf("╚══════════════════════════════════════════╝\n");
    printf("\n");
    printf("System Information:\n");
    printf("  Architecture: ARM64/AARCH64\n");
    printf("  Processor:    Cortex-A53 (64-bit)\n");
    printf("  Platform:     TI AM62x (BeaglePlay)\n");
    printf("  C Library:    musl libc\n");
    printf("\n");
    printf("Compiled with:\n");
    printf("  GCC version:  %s\n", __VERSION__);
    printf("  Compilation:  %s %s\n", __DATE__, __TIME__);
    printf("\n");
    
    if (argc > 1) {
        printf("Arguments passed: %d\n", argc - 1);
        for (int i = 1; i < argc; i++) {
            printf("  arg[%d]: %s\n", i, argv[i]);
        }
    }
    
    return EXIT_SUCCESS;
}
EOF
```

### Step 4.3: Compile with Cross-Compiler

```bash
# Cross-compile for ARM64
aarch64-linux-gcc -o hello-arm64 hello.c

# Check binary type
file hello-arm64
```

**Expected Output**:
```
hello-arm64: ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV),
dynamically linked, interpreter /lib/ld-musl-aarch64.so.1, not stripped
```

**Key observations**:
- `ARM aarch64`: Compiled for 64-bit ARM
- `dynamically linked`: Uses shared libraries
- `ld-musl-aarch64.so.1`: musl C library dynamic linker

### Step 4.4: Compare with Native Compilation

```bash
# Compile for x86_64 (your PC)
gcc -o hello-x86 hello.c

# Compare file sizes
ls -lh hello-*

# Compare binary types
file hello-x86
file hello-arm64
```

**Expected**: Different ELF types for x86_64 vs ARM64

### Step 4.5: Inspect Binary

```bash
# View binary header
readelf -h hello-arm64

# List shared library dependencies
aarch64-linux-readelf -d hello-arm64 | grep NEEDED

# Or use ldd-equivalent
aarch64-linux-ldd hello-arm64
```

**Expected dependencies**:
```
libc.so
```

---

## Part 5: QEMU User-Mode Testing

### Step 5.1: Install QEMU User

```bash
# Install QEMU user-mode emulator
sudo apt install qemu-user

# Verify installation
qemu-aarch64 --version
```

### Step 5.2: First Run Attempt

```bash
# Try to run ARM64 binary on x86_64 host
qemu-aarch64 hello-arm64
```

**Expected Error**:
```
qemu-aarch64: Could not open '/lib/ld-musl-aarch64.so.1': No such file or directory
```

**Why it fails**: QEMU can emulate ARM64 CPU, but the binary needs ARM64 shared libraries (dynamic linker).

### Step 5.3: Find Library Path

```bash
# Find musl dynamic linker in toolchain
find ~/x-tools -name "ld-musl-aarch64.so.1"
```

**Expected**:
```
/home/youruser/x-tools/aarch64-beagleplay-linux-musl/aarch64-beagleplay-linux-musl/sysroot/lib/ld-musl-aarch64.so.1
```

**What is sysroot?**  
The "root filesystem" for cross-compilation containing ARM64 headers and libraries.

### Step 5.4: Run with Library Path

```bash
# Set SYSROOT variable for convenience
export SYSROOT=~/x-tools/aarch64-beagleplay-linux-musl/aarch64-beagleplay-linux-musl/sysroot

# Run with -L flag to specify library path
qemu-aarch64 -L $SYSROOT hello-arm64
```

**Expected Output**:
```
╔══════════════════════════════════════════╗
║   Hello from BeaglePlay!                ║
╚══════════════════════════════════════════╝

System Information:
  Architecture: ARM64/AARCH64
  Processor:    Cortex-A53 (64-bit)
  Platform:     TI AM62x (BeaglePlay)
  C Library:    musl libc

Compiled with:
  GCC version:  13.3.0
  Compilation:  Nov 25 2025 14:30:00
```

🎉 **Success!** You're running ARM64 code on an x86_64 PC using QEMU!

### Step 5.5: Test with Arguments

```bash
# Run with command-line arguments
qemu-aarch64 -L $SYSROOT hello-arm64 arg1 arg2 "test argument"
```

**Expected**:
```
Arguments passed: 3
  arg[1]: arg1
  arg[2]: arg2
  arg[3]: test argument
```

---

## Part 6: Static vs Dynamic Linking

### Step 6.1: Create Static Binary

```bash
# Compile with static linking
aarch64-linux-gcc -static -o hello-arm64-static hello.c

# Compare sizes
ls -lh hello-arm64*
```

**Expected**:
- `hello-arm64`: ~16 KB (dynamic)
- `hello-arm64-static`: ~800 KB (static)

**Why the difference?**  
Static binary includes entire C library, dynamic binary only references it.

### Step 6.2: Test Static Binary

```bash
# Run without -L flag (no external libraries needed)
qemu-aarch64 hello-arm64-static
```

**Expected**: Works without SYSROOT because all code is embedded.

**Trade-offs**:

| Linking | Size | Advantages | Disadvantages |
|---------|------|------------|---------------|
| **Dynamic** | Small | Shared libs, updates easy | Needs libraries at runtime |
| **Static** | Large | Self-contained | Large, no shared updates |

**When to use each**:
- **Dynamic**: Normal applications, space-constrained systems
- **Static**: Initial bootup programs, rescue systems, containers

---

## Part 7: Toolchain Exploration

### Step 7.1: Explore Compiler Options

```bash
# View compiler version and configuration
aarch64-linux-gcc -v

# List supported CPU types
aarch64-linux-gcc --target-help | grep march

# Check optimization levels
aarch64-linux-gcc --help=optimizers
```

### Step 7.2: Compile with Optimizations

```bash
# No optimization
aarch64-linux-gcc -O0 -o hello-O0 hello.c

# Optimize for size
aarch64-linux-gcc -Os -o hello-Os hello.c

# Optimize for speed
aarch64-linux-gcc -O3 -o hello-O3 hello.c

# Compare sizes
ls -lh hello-O*
```

**Expected**: Os (size) < O0 (none) < O3 (speed)

### Step 7.3: Inspect Generated Assembly

```bash
# Generate assembly output
aarch64-linux-gcc -S -O2 hello.c -o hello.s

# View assembly
head -50 hello.s
```

**Learning**: See how C code translates to ARM64 instructions.

### Step 7.4: Examine Object Files

```bash
# Compile to object file (not linked)
aarch64-linux-gcc -c hello.c -o hello.o

# Display symbols
aarch64-linux-nm hello.o

# Disassemble
aarch64-linux-objdump -d hello.o | head -50
```

---

## Verification

### Test Your Work

```bash
# Verification script
cat > verify-toolchain.sh << 'EOF'
#!/bin/bash
set -e

echo "=== Toolchain Verification ==="
echo ""

# Check toolchain exists
if [ -d ~/x-tools/aarch64-beagleplay-linux-musl ]; then
    echo "✓ Toolchain installed"
else
    echo "✗ Toolchain not found"
    exit 1
fi

# Check compiler
if command -v aarch64-linux-gcc &> /dev/null; then
    echo "✓ Compiler in PATH"
    echo "  Version: $(aarch64-linux-gcc --version | head -1)"
else
    echo "✗ Compiler not in PATH"
    exit 1
fi

# Test compilation
cd /tmp
echo 'int main() { return 0; }' > test.c
if aarch64-linux-gcc -o test test.c 2>/dev/null; then
    echo "✓ Can compile test program"
    rm -f test test.c
else
    echo "✗ Compilation failed"
    exit 1
fi

# Check QEMU
if command -v qemu-aarch64 &> /dev/null; then
    echo "✓ QEMU installed"
else
    echo "✗ QEMU not found"
    exit 1
fi

echo ""
echo "=== All checks passed! ==="
EOF

chmod +x verify-toolchain.sh
./verify-toolchain.sh
```

### Checklist

- [ ] Crosstool-NG built successfully
- [ ] Toolchain configured for Cortex-A53
- [ ] Toolchain build completed without errors
- [ ] `aarch64-linux-gcc` accessible in PATH
- [ ] Test program compiles for ARM64
- [ ] `file` command shows correct architecture
- [ ] QEMU can run the cross-compiled binary
- [ ] Both dynamic and static linking work

---

## Cleanup (Optional)

```bash
# Remove build artifacts to save space (~9 GB)
cd ~/embedded-linux-labs/lab01-toolchain/crosstool-ng
./ct-ng clean

# This removes:
# - Downloaded source tarballs
# - Temporary build files
# - Keeps: Final toolchain in ~/x-tools/
```

**Warning**: Only clean if build was successful. If you need to rebuild, you'll download everything again.

---

## Going Further (Optional Challenges)

### Challenge 1: Multi-Library Comparison

Build three toolchains with different C libraries:
1. musl (lightweight)
2. glibc (full-featured)
3. uclibc-ng (minimal)

Compare:
- Build time
- Final size
- Binary size
- Feature differences

### Challenge 2: Cortex-A72 Toolchain

Build a second toolchain optimized for Raspberry Pi 4 (Cortex-A72):
- Change `ARCH_CPU` to `cortex-a72`
- Compare performance of binaries on same hardware

### Challenge 3: Custom GCC Patches

Research and apply GCC patches:
- Download GCC sources
- Apply optimization patches
- Build and benchmark

### Challenge 4: Toolchain Wrapper Script

Create a wrapper script that:
- Automatically sets SYSROOT
- Adds default compiler flags
- Logs compilation commands
- Simplifies cross-compilation workflow

---

## Common Issues

### Issue 1: Build Fails with "No space left on device"

**Symptoms**:
- Build stops mid-way
- Error message about disk space

**Solution**:
```bash
# Check available space
df -h ~

# Clean up if needed
sudo apt clean
rm -rf ~/.cache/*

# Need minimum 10 GB free
```

### Issue 2: "configure: error: C compiler cannot create executables"

**Symptoms**:
- Build fails early during binutils configuration

**Causes**:
- Missing build-essential package
- Corrupted GCC installation

**Solutions**:
```bash
# Reinstall build tools
sudo apt install --reinstall build-essential

# Verify native compiler works
gcc --version
echo 'int main() { return 0; }' | gcc -x c - -o /tmp/test
```

### Issue 3: QEMU "Illegal instruction" Error

**Symptoms**:
- Binary crashes when run with QEMU

**Causes**:
- Binary built for wrong architecture
- QEMU version too old

**Solutions**:
```bash
# Verify binary architecture
file hello-arm64
# Should show: ARM aarch64

# Update QEMU
sudo apt install --upgrade qemu-user

# Check QEMU version
qemu-aarch64 --version
```

### Issue 4: Toolchain Build Takes Hours

**Symptoms**:
- Build running for >2 hours

**Causes**:
- Low-end CPU
- Single-core building
- Slow disk I/O

**Solutions**:
```bash
# Check if using multiple cores
htop
# Should see high CPU usage across all cores

# Force parallel build
./ct-ng build CT_JOBS=$(nproc)

# Use tmpfs for faster builds (if enough RAM)
./ct-ng build CT_PREFIX=/tmp/toolchain
```

---

## Key Takeaways

1. **Cross-compilation is essential** for embedded development - target hardware is too slow/limited for compilation
2. **Toolchain components** work together: compiler, linker, libraries, headers
3. **C library choice matters**: musl (small), glibc (compatible), uclibc (minimal)
4. **CPU optimization** improves performance: `-mcpu=cortex-a53` uses specific instructions
5. **QEMU user-mode** allows testing ARM binaries without hardware
6. **Sysroot** is the cross-compilation "root filesystem" with ARM libraries
7. **Static linking** creates larger but self-contained binaries
8. **Toolchain naming** follows pattern: `arch-vendor-os-abi` (e.g., `aarch64-beagleplay-linux-musl`)

---

## References

- **Crosstool-NG Documentation**: https://crosstool-ng.github.io/docs/
- **GCC Cross-Compilation**: https://gcc.gnu.org/onlinedocs/gcc/Cross-Compilation.html
- **musl libc**: https://musl.libc.org/
- **ARM Cortex-A53 TRM**: https://developer.arm.com/documentation/ddi0500/latest/
- **QEMU User Mode**: https://qemu.readthedocs.io/en/latest/user/index.html

---

## Next Steps

✅ **Completed**: Lab 1 - Cross-Compilation Toolchain  
⏭️ **Up Next**: Lab 2 - BeaglePlay Hardware Discovery

**What you'll learn next**:
- BeaglePlay hardware architecture
- Serial console communication
- Device Tree basics
- GPIO and peripheral access

**Recommended preparation**:
- Read BeaglePlay Technical Reference Manual
- Review Device Tree specification
- Set up serial console connection

---

*Lab created: November 25, 2025*  
*Last updated: November 25, 2025*  
*Tested on: Ubuntu 24.04 LTS, Crosstool-NG 1.26.0*  
*Target: BeaglePlay (TI AM62x Cortex-A53)*
