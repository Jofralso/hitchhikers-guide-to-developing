# Lab 1: Cross-Compilation Toolchain Examples

## DON'T PANIC

This directory contains working examples for Lab 1 - Building a Cross-Compilation Toolchain.

**The Guide says**: *"Cross-compilation is the art of building software on one architecture to run on another. It's a bit like teaching a fish to climb a tree, except the fish is your code and the tree is a BeaglePlay."*

## What's Inside

- **`src/hello.c`** - Simple Hello World program demonstrating cross-compilation
- **`Makefile`** - Automated build system for native and cross compilation
- **`scripts/`** - Helper scripts (if needed)

## Prerequisites

```bash
# Install cross-compilation toolchain
sudo apt update
sudo apt install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu

# Optional: Install QEMU for testing ARM binaries on x86
sudo apt install -y qemu-user
```

## Quick Start

### 1. Check Your Toolchain

```bash
make check-toolchain
```

**Expected output**:
```
✓ aarch64-linux-gnu-gcc found
aarch64-linux-gnu-gcc (Ubuntu 13.2.0-23ubuntu4) 13.2.0
```

### 2. Build Everything

```bash
make all
```

This builds:
- `build/hello-x86_64` - Native binary (runs on your PC)
- `build/hello-arm64` - Cross-compiled binary (runs on BeaglePlay)

### 3. Test Native Binary

```bash
make test-native
```

### 4. Test ARM64 Binary with QEMU

```bash
make test-cross
```

**Expected output**:
```
╔════════════════════════════════════════════════╗
║                                                ║
║         DON'T PANIC                            ║
║                                                ║
║    The Hitchhiker's Guide to Embedded Linux   ║
║                                                ║
╚════════════════════════════════════════════════╝

Hello from BeaglePlay!

This program was cross-compiled for ARM64/AARCH64
and is running on embedded Linux.

=== System Information ===
System:    Linux
Machine:   aarch64
==========================

🎉 Success! Your cross-compilation toolchain works!
```

## Available Make Targets

```bash
make help           # Show all available targets
make all            # Build both native and cross binaries
make native         # Build for x86_64
make cross          # Build for ARM64
make cross-static   # Build static ARM64 binary (no dependencies)
make test           # Test both binaries
make clean          # Remove build artifacts
```

## Understanding the Build

### Native Compilation (x86_64)

```bash
gcc -Wall -Wextra -std=c11 -O2 src/hello.c -o build/hello-x86_64
```

- Compiles for **your PC** architecture
- Uses system's native GCC
- Binary runs directly on your machine

### Cross-Compilation (ARM64)

```bash
aarch64-linux-gnu-gcc -Wall -Wextra -std=c11 -O2 src/hello.c -o build/hello-arm64
```

- Compiles for **BeaglePlay** architecture (ARM64)
- Uses cross-compiler toolchain
- Binary only runs on ARM64 systems (or via QEMU)

### Verify Binary Architecture

```bash
file build/hello-x86_64
file build/hello-arm64
```

**Expected**:
```
build/hello-x86_64: ELF 64-bit LSB executable, x86-64, version 1 (SYSV)
build/hello-arm64:  ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV)
```

## Testing with QEMU

QEMU user-mode emulation allows you to run ARM64 binaries on your x86_64 PC:

```bash
# Dynamic linking (requires ARM libraries)
qemu-aarch64 -L /usr/aarch64-linux-gnu build/hello-arm64

# Static linking (standalone)
make cross-static
qemu-aarch64 build/hello-arm64-static
```

## Deploying to BeaglePlay

### Method 1: SCP (Secure Copy)

```bash
# Copy to BeaglePlay
scp build/hello-arm64 debian@beagleplay.local:~/

# SSH and run
ssh debian@beagleplay.local
./hello-arm64
```

### Method 2: HTTP Server

On your PC:
```bash
cd build
python3 -m http.server 8000
```

On BeaglePlay:
```bash
wget http://YOUR_PC_IP:8000/hello-arm64
chmod +x hello-arm64
./hello-arm64
```

### Method 3: microSD Card

```bash
# Copy to SD card
cp build/hello-arm64 /media/user/SD_CARD/

# Unmount, insert into BeaglePlay, and run
```

## Troubleshooting

### "aarch64-linux-gnu-gcc: command not found"

```bash
sudo apt install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
```

### "qemu-aarch64: Could not open..."

Dynamic binary needs ARM libraries:
```bash
# Option 1: Specify library path
qemu-aarch64 -L /usr/aarch64-linux-gnu build/hello-arm64

# Option 2: Build static binary
make cross-static
qemu-aarch64 build/hello-arm64-static
```

### "Permission denied" when running on BeaglePlay

```bash
chmod +x hello-arm64
```

## Key Concepts

1. **Cross-Compilation**: Building code on one architecture (x86_64) for another (ARM64)
2. **Toolchain**: Set of tools (compiler, linker, libraries) for target architecture
3. **ABI**: Application Binary Interface - defines how binaries interact with OS
4. **ELF**: Executable and Linkable Format - Linux binary format

## Success Criteria

✅ Cross-compiler installed and working  
✅ Native binary compiles and runs  
✅ ARM64 binary compiles successfully  
✅ ARM64 binary runs with QEMU  
✅ ARM64 binary runs on actual BeaglePlay  

## Next Steps

- **Lab 2**: Hardware Discovery - Explore BeaglePlay platform
- **Lab 3**: U-Boot Bootloader - Boot sequence customization
- **Lab 4**: Linux Kernel - Build custom kernel

## Additional Resources

- [GNU Toolchain Documentation](https://gcc.gnu.org/onlinedocs/)
- [QEMU User Guide](https://www.qemu.org/docs/master/user/main.html)
- [ARM64 ABI](https://github.com/ARM-software/abi-aa)

---

**Remember**: The answer to cross-compilation is always 42... characters in the target triple `aarch64-unknown-linux-gnu`.

*Part of [The Hitchhiker's Guide to Embedded Linux](../../docs/labs/embedded-linux/lab01-toolchain.md)*
