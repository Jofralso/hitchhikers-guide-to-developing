# Embedded Linux Labs - Index

**Target Platform**: BeaglePlay (TI AM62x Cortex-A53)  
**Total Labs**: 9  
**Estimated Time**: 35-45 hours  
**Difficulty**: Beginner to Intermediate

---

## Lab Overview

This series of labs provides hands-on experience with embedded Linux development, from building a custom toolchain to creating complete embedded systems. All labs are adapted for the BeaglePlay platform using original examples and content.

---

## Prerequisites

Before starting these labs, ensure you have:

- **Hardware**: BeaglePlay board, USB-C cable, microSD card (32GB+)
- **Software**: Ubuntu 24.04 LTS (or similar Linux distribution)
- **Skills**: Linux command line, basic C programming, Git basics
- **Time**: Allocate 3-5 hours per lab for learning and experimentation

See [Quick Start Guide](../../QUICK_START.md) for initial setup.

---

## Lab Progression

### [Lab 1: Cross-Compilation Toolchain](lab01-toolchain.md)
**Duration**: 2-3 hours | **Status**: ✅ Complete

Build a custom ARM64 toolchain using Crosstool-NG for the BeaglePlay's Cortex-A53 processor.

**What you'll learn**:
- Cross-compilation fundamentals
- Toolchain components (GCC, binutils, C library)
- Crosstool-NG configuration
- musl vs glibc vs uclibc
- QEMU user-mode testing

**Deliverables**:
- Working `aarch64-linux-gcc` toolchain
- Cross-compiled test programs
- Understanding of sysroot and linking

---

### Lab 2: BeaglePlay Hardware Discovery
**Duration**: 2-3 hours | **Status**: 🔄 In Development

Explore BeaglePlay hardware architecture and establish serial communication.

**What you'll learn**:
- TI AM62x SoC architecture
- Serial console (UART) configuration
- GPIO basics and LED control
- Device Tree introduction
- Expansion connectors (mikroBUS, Grove, QWIIC)

**Deliverables**:
- Working serial console connection
- GPIO LED blink program
- Hardware documentation

---

### Lab 3: U-Boot Bootloader
**Duration**: 3-4 hours | **Status**: 📋 Planned

Build and configure U-Boot bootloader for BeaglePlay.

**What you'll learn**:
- Boot sequence and boot ROM
- U-Boot compilation and configuration
- Boot sources (SD card, eMMC)
- U-Boot environment variables
- Network boot (TFTP/NFS)

**Deliverables**:
- Custom U-Boot binary
- Automated boot scripts
- Network boot configuration

---

### Lab 4: Linux Kernel
**Duration**: 4-5 hours | **Status**: 📋 Planned

Configure, compile, and boot a custom Linux kernel.

**What you'll learn**:
- Kernel source organization
- Kernel configuration (menuconfig)
- Device Tree compilation
- Cross-compiling the kernel
- Kernel modules vs built-in drivers

**Deliverables**:
- Bootable Linux kernel
- Custom Device Tree
- Working peripherals (UART, GPIO)

---

### Lab 5: Tiny Root Filesystem (BusyBox)
**Duration**: 3-4 hours | **Status**: 📋 Planned

Create a minimal root filesystem from scratch.

**What you'll learn**:
- Essential filesystem hierarchy
- BusyBox configuration and compilation
- Static vs dynamic linking
- Init system basics
- Device nodes creation

**Deliverables**:
- Bootable minimal system (<10 MB)
- Custom init scripts
- Understanding of "what makes Linux work"

---

### Lab 6: Block Filesystems
**Duration**: 2-3 hours | **Status**: 📋 Planned

Implement persistent storage with ext4 filesystems.

**What you'll learn**:
- ext4 filesystem basics
- Partition schemes (GPT, MBR)
- fstab configuration
- Mounting filesystems
- Read-only vs read-write rootfs

**Deliverables**:
- Multi-partition SD card
- Proper filesystem mounting
- Persistent data storage

---

### Lab 7: Flash Filesystems
**Duration**: 2-3 hours | **Status**: 📋 Planned

Work with flash-optimized filesystems.

**What you'll learn**:
- SquashFS (compressed read-only)
- OverlayFS (writable overlay)
- MTD subsystem basics
- Flash wear leveling
- Update strategies

**Deliverables**:
- Compressed read-only rootfs
- Writable overlay for config
- Understanding flash constraints

---

### Lab 8: Buildroot
**Duration**: 4-5 hours | **Status**: 📋 Planned

Automate complete system builds with Buildroot.

**What you'll learn**:
- Buildroot architecture
- Package selection and configuration
- Custom board support (defconfig)
- External trees
- SDK generation

**Deliverables**:
- Automated complete system build
- Custom Buildroot configuration
- Application SDK

---

### Lab 9: Application Development
**Duration**: 3-4 hours | **Status**: 📋 Planned

Develop and debug applications on BeaglePlay.

**What you'll learn**:
- Application cross-compilation
- Remote debugging (gdbserver)
- Hardware interfacing (I2C, GPIO)
- Library dependencies (pkg-config)
- Example: Nunchuk I2C driver

**Deliverables**:
- Custom application for BeaglePlay
- Remote debugging session
- Hardware interaction demo

---

## Learning Path Recommendations

### **Sequential Path** (Recommended for Beginners)
Follow labs 1-9 in order. Each lab builds on previous knowledge.

```
Lab 1 → Lab 2 → Lab 3 → Lab 4 → Lab 5 → Lab 6 → Lab 7 → Lab 8 → Lab 9
```

### **Fast Track** (For Experienced Developers)
If you're comfortable with Linux and cross-compilation:

```
Lab 1 (skim) → Lab 4 → Lab 8 → Lab 9
```

### **Hardware Focus** (For Hardware Engineers)
Emphasis on hardware interfacing:

```
Lab 1 → Lab 2 → Lab 4 → Lab 9
```

### **Build Systems Focus** (For System Integrators)
Focus on automated builds:

```
Lab 1 → Lab 5 → Lab 8
```

---

## Lab Format

Each lab follows a consistent structure:

1. **Objectives**: What you'll achieve
2. **Background**: Theory and concepts
3. **Prerequisites**: What you need before starting
4. **Setup**: Workspace preparation
5. **Step-by-Step Instructions**: Detailed hands-on tasks
6. **Verification**: How to test your work
7. **Troubleshooting**: Common issues and solutions
8. **Going Further**: Optional advanced challenges
9. **Key Takeaways**: Summary of learning
10. **References**: Additional resources

---

## Hardware Requirements

### Essential
- **BeaglePlay board** (~$99)
- **USB-C cable** (data + power)
- **microSD card** (32GB+, Class 10/UHS-I)
- **Development PC** (Ubuntu 24.04, 16GB RAM, 100GB storage)

### Recommended
- **Ethernet cable** (for network boot)
- **USB hub** (for multiple devices)
- **mikroBUS Click boards** (for hardware experiments)

### Optional
- **JTAG debugger** (for kernel debugging)
- **Logic analyzer** (for protocol debugging)
- **Oscilloscope** (for hardware signals)

---

## Software Requirements

### Development Tools
```bash
# Essential packages (installed in Lab 1)
sudo apt install build-essential git
sudo apt install gcc-aarch64-linux-gnu
sudo apt install qemu-user

# Additional tools (as needed per lab)
sudo apt install device-tree-compiler
sudo apt install u-boot-tools
sudo apt install nfs-kernel-server
```

### Recommended Tools
- **Text Editor**: VS Code, Vim, or Emacs
- **Terminal Multiplexer**: tmux or screen
- **Serial Console**: picocom or minicom
- **Version Control**: Git (for tracking progress)

---

## Lab Data and Resources

### Downloaded Materials
Each lab provides:
- Sample source code (all original, not copied)
- Configuration files
- Helper scripts
- Test data

### External Resources
- Kernel sources: kernel.org
- U-Boot sources: denx.de
- Buildroot: buildroot.org
- TI AM62x documentation

---

## Progress Tracking

Track your progress through the labs:

```bash
# Create progress tracker
cat > ~/embedded-linux-progress.md << 'EOF'
# Embedded Linux Labs Progress

- [ ] Lab 1: Toolchain (0%)
- [ ] Lab 2: Hardware (0%)
- [ ] Lab 3: U-Boot (0%)
- [ ] Lab 4: Kernel (0%)
- [ ] Lab 5: Tiny System (0%)
- [ ] Lab 6: Block FS (0%)
- [ ] Lab 7: Flash FS (0%)
- [ ] Lab 8: Buildroot (0%)
- [ ] Lab 9: App Dev (0%)

## Notes
EOF
```

---

## Getting Help

### Before Asking
1. **Read error messages** carefully (first error is usually the root cause)
2. **Search online** for specific error messages
3. **Check documentation** for the tool/command you're using
4. **Review lab instructions** to ensure you didn't miss a step

### Resources
- **BeagleBoard Forums**: https://forum.beagleboard.org/
- **Stack Overflow**: Tag your questions with `beagleplay`, `embedded-linux`
- **GitHub Issues**: Report documentation errors or unclear instructions
- **IRC**: #beagle on irc.libera.chat

### Contributing
Found an error? Have an improvement? Submit a pull request!
See [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines.

---

## Tips for Success

1. **Don't rush**: Each lab takes time to understand - it's learning, not a race
2. **Take notes**: Document issues you encounter and how you solved them
3. **Experiment**: Try variations and optional challenges
4. **Ask questions**: Don't stay stuck - seek help after 10-15 minutes
5. **Have fun**: Embedded Linux is fascinating - enjoy the journey!

---

## Advanced Topics (Future Labs)

After completing these 9 labs, consider:

- **Yocto Project** (Labs 10-14): Industrial build system
- **Linux Debugging** (Labs 15-21): Profiling, tracing, performance analysis
- **Real-Time Linux**: PREEMPT-RT, Xenomai
- **Device Drivers**: Writing custom kernel drivers
- **Security**: Secure boot, encryption, hardening

---

## License and Attribution

All lab content is original work created for this learning repository.

**Inspiration**: Lab structure inspired by professional embedded Linux training, adapted with original examples and explanations.

**License**: CC BY-SA 4.0 (same as parent repository)

**Hardware**: BeaglePlay specifications and documentation © BeagleBoard.org Foundation

---

**Ready to start?** → [Lab 1: Cross-Compilation Toolchain](lab01-toolchain.md)

---

*Last updated: November 25, 2025*  
*Total labs documented: 1/9*  
*Status: Active development*
