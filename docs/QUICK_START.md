# Quick Start: Your First Lab

**Goal**: Get from zero to running your first embedded Linux lab in 30 minutes.

---

## What You'll Do

1. Set up BeaglePlay hardware
2. Verify serial console access
3. Set up development environment
4. Run a simple cross-compiled "Hello World"

---

## Prerequisites

- [ ] BeaglePlay board
- [ ] USB-C cable (data capable)
- [ ] Ubuntu 24.04 Linux PC (or similar)
- [ ] Internet connection
- [ ] ~30 minutes

---

## Step 1: Hardware Check (5 minutes)

### Connect BeaglePlay

1. **Power off** your BeaglePlay (if powered)
2. **Connect** USB-C cable from BeaglePlay to your PC
3. BeaglePlay should **power on** automatically (LEDs blink)

### Verify Serial Console

```bash
# Check if USB serial device appears
ls -l /dev/ttyACM0

# If not found, check for USB devices
dmesg | grep tty
# Look for /dev/ttyUSB0 or similar
```

**Add yourself to dialout group** (first time only):
```bash
sudo usermod -a -G dialout $USER
# Log out and back in for this to take effect
```

### Connect to Console

```bash
# Install picocom if needed
sudo apt install picocom

# Connect (Ctrl+A, Ctrl+X to exit)
picocom -b 115200 /dev/ttyACM0
```

**Expected**: You should see boot messages or a login prompt.

**Troubleshooting**: See [BeaglePlay Setup Guide](BEAGLEPLAY_SETUP.md#troubleshooting)

---

## Step 2: Development Environment (10 minutes)

### Install Essential Packages

```bash
# Update package database
sudo apt update

# Install build essentials and cross-compilation tools
sudo apt install -y \
    build-essential \
    git \
    wget \
    bc \
    bison \
    flex \
    libssl-dev \
    libncurses5-dev \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    qemu-user
```

**What these do**:
- `build-essential`: GCC, make, and basic build tools
- `gcc-aarch64-linux-gnu`: Cross-compiler for ARM64 (BeaglePlay's architecture)
- `qemu-user`: Run ARM binaries on your x86 PC (for testing)

### Create Workspace

```bash
# Create directory for all labs
mkdir -p ~/embedded-linux-labs
cd ~/embedded-linux-labs

# Create first lab directory
mkdir -p lab1-hello-world
cd lab1-hello-world
```

---

## Step 3: First Cross-Compilation (10 minutes)

### Write Hello World

```bash
# Create hello.c
cat > hello.c << 'EOF'
#include <stdio.h>

int main(void) {
    printf("Hello from BeaglePlay!\n");
    printf("Architecture: ARM64/AARCH64\n");
    printf("System: Embedded Linux\n");
    return 0;
}
EOF
```

### Compile for x86 (your PC)

```bash
# Native compilation
gcc -o hello-x86 hello.c

# Run it
./hello-x86
```

**Expected output**:
```
Hello from BeaglePlay!
Architecture: ARM64/AARCH64
System: Embedded Linux
```

### Cross-Compile for ARM64 (BeaglePlay)

```bash
# Cross-compilation for ARM64
aarch64-linux-gnu-gcc -o hello-arm64 hello.c

# Check the binary
file hello-arm64
```

**Expected output**:
```
hello-arm64: ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV), 
dynamically linked, interpreter /lib/ld-linux-aarch64.so.1, ...
```

**Important**: Notice it says "ARM aarch64" - this is for BeaglePlay!

### Test with QEMU

```bash
# Run ARM64 binary on your x86 PC using QEMU
qemu-aarch64 -L /usr/aarch64-linux-gnu hello-arm64
```

**Expected output**:
```
Hello from BeaglePlay!
Architecture: ARM64/AARCH64
System: Embedded Linux
```

**🎉 Success!** You've just cross-compiled your first embedded Linux program!

---

## Step 4: Run on Real Hardware (5 minutes)

### Transfer to BeaglePlay

**Option A: Via Serial Console** (if you have working system on BeaglePlay):

1. Connect to BeaglePlay serial console
2. Log in (default: `debian` / `temppwd`)
3. On your PC, start a simple web server:
   ```bash
   python3 -m http.server 8000
   ```
4. On BeaglePlay:
   ```bash
   wget http://YOUR_PC_IP:8000/hello-arm64
   chmod +x hello-arm64
   ./hello-arm64
   ```

**Option B: Via SSH** (if network is configured):
```bash
# From your PC
scp hello-arm64 debian@beagleplay.local:~/
ssh debian@beagleplay.local
./hello-arm64
```

**Option C: Via microSD Card** (manual method):
1. Copy `hello-arm64` to SD card
2. Insert SD card into BeaglePlay
3. Boot and mount SD card
4. Run the binary

---

## What You've Learned

✅ **Hardware**: BeaglePlay serial console access  
✅ **Cross-Compilation**: Building code for different architecture  
✅ **Toolchain**: Using `aarch64-linux-gnu-gcc`  
✅ **Testing**: QEMU user-mode emulation  
✅ **Deployment**: Transferring binaries to target  

---

## Common Issues

### "Permission denied" for /dev/ttyACM0

```bash
# Add yourself to dialout group
sudo usermod -a -G dialout $USER
# Then log out and log back in
```

### "qemu-aarch64: Could not open..."

You're using dynamically linked binary. Either:

**Option 1**: Static linking:
```bash
aarch64-linux-gnu-gcc -static -o hello-arm64 hello.c
qemu-aarch64 hello-arm64
```

**Option 2**: Specify library path:
```bash
qemu-aarch64 -L /usr/aarch64-linux-gnu hello-arm64
```

### Cross-compiler not found

```bash
# Install the cross-compilation toolchain
sudo apt install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
```

---

## Next Steps

You're ready for the full labs! Choose your path:

1. **Lab 1**: [Build Custom Toolchain](LAB_STRUCTURE.md#lab-1-cross-compilation-toolchain)
   - Learn Crosstool-NG
   - Customize toolchain
   - Professional workflow

2. **Lab 2**: [Hardware Discovery](LAB_STRUCTURE.md#lab-2-hardware-discovery)
   - BeaglePlay architecture
   - Device Tree basics
   - Peripheral interfaces

3. **Continue Reading**:
   - [Full Lab Structure](LAB_STRUCTURE.md) - All 21 labs
   - [BeaglePlay Setup](BEAGLEPLAY_SETUP.md) - Detailed hardware guide
   - [Training Analysis](TRAINING_ANALYSIS.md) - How labs were created

---

## Congratulations! 🎉

You've successfully:
- Set up BeaglePlay
- Installed cross-compilation tools
- Built and tested your first embedded program
- Deployed to real hardware

**Remember**: Don't Panic. Embedded Linux is a journey, not a destination.

---

**Time invested**: ~30 minutes  
**Skills gained**: Foundation for embedded development  
**Next milestone**: Complete Lab 1 (custom toolchain)

---

*Last updated: 2025-01-24*  
*Tested on: Ubuntu 24.04, BeaglePlay Rev A1*
