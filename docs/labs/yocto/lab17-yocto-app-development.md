# Lab 17: Application Development with SDK

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about debugging:

*"Debugging is the art of figuring out why your code doesn't work, as opposed to why you thought it would work. This is similar to the difference between what Deep Thought calculated (42) and what everyone expected (a useful answer). Both are technically correct, but only one is helpful."*

## Objectives

Generate and use the Yocto SDK for efficient cross-compilation and application development without full Yocto builds.

**What You'll Learn:**
- Build Yocto SDK
- Install and configure SDK
- Cross-compile applications
- Use SDK sysroot
- Debug with SDK toolchain
- Integrate applications back into Yocto

**Time Required:** 1-2 hours

---

## Prerequisites

**Completed Labs:**
- Lab 16: Custom Image Creation

---

## 1. Understanding the SDK

### 1.1 What is the SDK?

**SDK (Software Development Kit)** provides:
- Cross-compiler toolchain
- Libraries and headers (sysroot)
- Development tools (gdb, qemu)
- Environment setup script

**Two SDK types:**
1. **Standard SDK**: Toolchain only
2. **Extended SDK**: + BitBake and devtool

We'll use the extended SDK.

---

## 2. Building the SDK

### 2.1 Generate SDK

```bash
cd ~/yocto-labs/build
bitbake beagleplay-image-minimal -c populate_sdk
```

**Build time:** ~20-30 minutes

### 2.2 Locate SDK Installer

```bash
ls tmp/deploy/sdk/
```

**Output:**
```
poky-glibc-x86_64-beagleplay-image-minimal-cortexa53-beagleplay-custom-toolchain-5.0.4.sh
```

---

## 3. Installing the SDK

### 3.1 Run Installer

```bash
cd ~/yocto-labs/build/tmp/deploy/sdk
./poky-glibc-x86_64-beagleplay-image-minimal-cortexa53-beagleplay-custom-toolchain-5.0.4.sh
```

**Prompts:**
```
Enter target directory for SDK (default: /opt/poky/5.0.4):
/home/user/yocto-sdk

Extracting SDK...
Setting it up...
SDK has been successfully set up and is ready to be used.
```

### 3.2 SDK Structure

```bash
ls ~/yocto-sdk/
```

**Output:**
```
environment-setup-cortexa53-poky-linux   # Setup script
sysroots/                                 # Target and host sysroots
site-config-cortexa53-poky-linux
version-cortexa53-poky-linux
```

---

## 4. Using the SDK

### 4.1 Source Environment

**Open new terminal (clean environment):**
```bash
source ~/yocto-sdk/environment-setup-cortexa53-poky-linux
```

**Verify:**
```bash
echo $CC
# Output: aarch64-poky-linux-gcc ...

echo $SDKTARGETSYSROOT
# Output: /home/user/yocto-sdk/sysroots/cortexa53-poky-linux
```

### 4.2 Cross-Compile Test Program

```bash
cat > hello.c << 'EOF'
#include <stdio.h>
int main() {
    printf("Hello from BeaglePlay SDK!\n");
    return 0;
}
EOF

$CC hello.c -o hello
```

**Verify architecture:**
```bash
file hello
# Output: hello: ELF 64-bit LSB executable, ARM aarch64, ...
```

### 4.3 Transfer to Target

```bash
scp hello root@192.168.0.100:/tmp/
ssh root@192.168.0.100 /tmp/hello
```

**Output:**
```
Hello from BeaglePlay SDK!
```

---

## 5. Compiling Real Applications

### 5.1 Download Ctris Game

```bash
wget https://download.mobatek.net/sources/ctris-0.42-1-src.tar.bz2
tar -xf ctris-0.42-1-src.tar.bz2
tar -xf ctris-0.42.tar.bz2
cd ctris-0.42
```

### 5.2 Fix Makefile

**Edit Makefile:**
```bash
nano Makefile
```

**Delete lines that override CC:**
```makefile
# Remove or comment these:
# CC = gcc
# CXX = g++
```

**Add compatibility flags:**
```makefile
CFLAGS += -Wno-error=format-security -fcommon
```

### 5.3 Cross-Compile

```bash
make
```

**Verify:**
```bash
file ctris
# ELF 64-bit ARM aarch64
```

### 5.4 Deploy and Test

```bash
scp ctris root@192.168.0.100:/usr/bin/
ssh root@192.168.0.100
ctris
# Play Tetris!
```

---

## 6. Debugging with SDK

### 6.1 Compile with Debug Symbols

```bash
$CC -g hello.c -o hello-dbg
```

### 6.2 Remote Debugging

**On BeaglePlay:**
```bash
gdbserver :2345 /tmp/hello-dbg
```

**On host:**
```bash
$GDB hello-dbg
(gdb) target remote 192.168.0.100:2345
(gdb) break main
(gdb) continue
```

---

## 7. Key Takeaways

**Accomplished:**
1. ✅ Built and installed Yocto SDK
2. ✅ Cross-compiled applications
3. ✅ Debugged with gdbserver
4. ✅ Deployed to target

**Skills Gained:**
- SDK generation and installation
- Cross-compilation workflow
- Remote debugging techniques

---

**End of Lab 17**

*The Guide rates this lab: **Mostly Harmless** ⭐⭐⭐⭐*

The SDK enables rapid application development without rebuilding entire Yocto images, dramatically improving iteration speed.
