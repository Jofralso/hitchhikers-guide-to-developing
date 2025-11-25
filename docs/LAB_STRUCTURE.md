# Lab Structure and Learning Path

**Target Platform**: BeaglePlay (Texas Instruments AM62 - Cortex-A53)

This document outlines the adapted learning labs for embedded Linux development on BeaglePlay, inspired by professional training materials but created as original content.

## Overview

The learning journey is divided into three main tracks:

1. **Embedded Linux Fundamentals** - Core system development skills
2. **Yocto Project** - Industrial build system mastery
3. **Linux Debugging & Performance** - Advanced troubleshooting

---

## Track 1: Embedded Linux Fundamentals

### Lab 1: Cross-Compilation Toolchain
**Objective**: Build a custom toolchain for ARM64/AARCH64

**Topics**:
- Crosstool-NG configuration and usage
- Target architecture: ARM Cortex-A53 (BeaglePlay CPU)
- C library selection: musl vs glibc vs uclibc
- GCC configuration for embedded targets
- Toolchain testing with QEMU user-mode emulation

**Key Deliverables**:
- Working `aarch64-linux-gcc` toolchain
- Cross-compiled "Hello World" application
- Understanding of sysroot and library paths

---

### Lab 2: Hardware Discovery
**Objective**: Understand BeaglePlay hardware architecture

**Topics**:
- TI AM62 SoC architecture (Quad-core Cortex-A53)
- Memory layout (DDR4, on-chip SRAM)
- Peripheral interfaces (UART, I2C, SPI, GPIO, USB)
- BeaglePlay-specific features (WiFi, Bluetooth, SubGHz, mikroBUS)
- Device Tree basics for hardware description

**Key Deliverables**:
- Hardware connection diagram
- Serial console access via UART
- Device Tree exploration for BeaglePlay

---

### Lab 3: Bootloader - U-Boot
**Objective**: Configure and build U-Boot for BeaglePlay

**Topics**:
- U-Boot architecture and boot sequence
- BeaglePlay-specific U-Boot configuration
- Boot sources: SD card, eMMC
- U-Boot environment variables
- Network booting (TFTP, NFS)
- Loading kernel and device tree

**Key Deliverables**:
- Custom U-Boot binary for BeaglePlay
- Automated boot script
- Network boot configuration

---

### Lab 4: Linux Kernel
**Objective**: Configure, build, and boot a custom Linux kernel

**Topics**:
- Kernel version selection (LTS vs mainline)
- BeaglePlay-specific kernel configuration
- Device Tree compilation and customization
- Kernel modules and built-in drivers
- Kernel command line parameters
- Cross-compilation workflow

**Key Deliverables**:
- Bootable Linux kernel image
- Custom Device Tree blob (.dtb)
- Working serial console and basic peripherals

---

### Lab 5: Root Filesystem - Tiny System
**Objective**: Create a minimal root filesystem from scratch

**Topics**:
- Essential filesystem hierarchy (/bin, /lib, /etc, /dev)
- BusyBox configuration and compilation
- Static vs dynamic linking
- Init process and system startup
- Basic device nodes
- Manual library dependency resolution

**Key Deliverables**:
- Bootable minimal Linux system (<10 MB)
- Understanding of what makes Linux "Linux"
- Custom init scripts

---

### Lab 6: Block Filesystems
**Objective**: Implement proper filesystems for storage

**Topics**:
- ext4 for SD card/eMMC
- Filesystem mounting and fstab
- Read-only vs read-write filesystems
- Partition schemes (boot, rootfs, data)
- Filesystem tools (mkfs, fsck, resize2fs)

**Key Deliverables**:
- Multi-partition SD card setup
- Persistent data storage
- Filesystem optimization for embedded use

---

### Lab 7: Flash Filesystems
**Objective**: Work with flash-specific filesystems

**Topics**:
- UBIFS for raw NAND/NOR flash
- SquashFS for read-only compressed storage
- Overlay filesystems (OverlayFS)
- Flash wear leveling concepts
- MTD subsystem basics

**Key Deliverables**:
- Compressed read-only rootfs
- Writable overlay for configuration
- Understanding flash constraints

---

### Lab 8: Buildroot
**Objective**: Automate system building with Buildroot

**Topics**:
- Buildroot architecture and menuconfig
- BeaglePlay board support (custom defconfig)
- Package selection and configuration
- External tree for customizations
- Rebuilding and incremental builds
- Generating SDK for application development

**Key Deliverables**:
- Automated complete system build
- Custom Buildroot configuration
- Reproducible builds

---

### Lab 9: Application Development
**Objective**: Develop and debug applications on target

**Topics**:
- Cross-compilation of applications
- Library dependencies and pkg-config
- Remote debugging with gdbserver
- Application frameworks (Qt, GTK+ if applicable)
- Hardware interfacing (GPIO, I2C, SPI via sysfs/libgpiod)
- Example: Nunchuk controller driver (I2C device)

**Key Deliverables**:
- Custom application for BeaglePlay
- Remote debugging session
- Hardware interaction demo

---

## Track 2: Yocto Project Development

### Lab 10: Yocto Introduction
**Objective**: Build first image with Yocto for BeaglePlay

**Topics**:
- Yocto Project architecture (Poky, BitBake, OpenEmbedded)
- Setting up build environment
- Understanding layers and recipes
- BeaglePlay BSP layer
- Image types (core-image-minimal, core-image-full-cmdline)

**Key Deliverables**:
- Working Yocto build environment
- Basic image running on BeaglePlay
- Understanding of BitBake workflow

---

### Lab 11: Custom Recipes
**Objective**: Create and modify recipes

**Topics**:
- Recipe syntax and structure (.bb files)
- Fetching sources (git, tarballs)
- do_compile, do_install tasks
- Recipe dependencies (DEPENDS, RDEPENDS)
- Package splitting and FILES variables
- Adding custom applications to image

**Key Deliverables**:
- Custom application recipe
- Modified existing recipe
- Package deployed to target

---

### Lab 12: Custom Layers
**Objective**: Organize customizations in layers

**Topics**:
- Layer structure and layer.conf
- Creating meta-beagleplay-custom layer
- Layer priorities and bbappend files
- Machine configuration files
- Distribution policies

**Key Deliverables**:
- Custom layer for project-specific code
- BeaglePlay machine configuration
- Organized build structure

---

### Lab 13: BSP and Kernel
**Objective**: Customize kernel in Yocto

**Topics**:
- Kernel recipe (linux-yocto, linux-ti)
- Device Tree modifications via Yocto
- Kernel configuration fragments
- Out-of-tree kernel modules as recipes
- Kernel version management

**Key Deliverables**:
- Custom kernel with modifications
- Device Tree overlays
- Kernel module integration

---

### Lab 14: SDK and devtool
**Objective**: Use Yocto SDK for development

**Topics**:
- Generating and installing SDK
- SDK sysroot and toolchain
- devtool workflow (add, modify, upgrade)
- eSDK (extensible SDK)
- Application development workflow

**Key Deliverables**:
- Installed SDK for BeaglePlay
- Application developed with SDK
- devtool recipe management

---

## Track 3: Linux Debugging and Performance

### Lab 15: System Profiling
**Objective**: Understand system load and resource usage

**Topics**:
- top, htop, vmstat, iostat
- CPU usage analysis
- Memory usage patterns
- Process states and scheduling
- System resource monitoring

**Key Deliverables**:
- System performance baseline
- Identified bottlenecks
- Monitoring dashboard

---

### Lab 16: Application Debugging - GDB
**Objective**: Master gdb for debugging applications

**Topics**:
- Local and remote debugging
- Breakpoints, watchpoints, catchpoints
- Stepping and execution control
- Core dump analysis
- GDB scripting basics
- ELF binary inspection (readelf, objdump, nm)

**Key Deliverables**:
- Debug session recordings
- Post-mortem crash analysis
- Understanding of ELF format

---

### Lab 17: Tracing - strace and ltrace
**Objective**: Trace system calls and library calls

**Topics**:
- strace for system call tracing
- ltrace for library call tracing
- Filtering and focusing traces
- Performance impact of tracing
- Identifying issues from traces

**Key Deliverables**:
- Traced application behavior
- Identified system call patterns
- Library usage analysis

---

### Lab 18: Performance Analysis - perf
**Objective**: Profile CPU usage with perf

**Topics**:
- perf record and perf report
- CPU profiling (sampling)
- Hotspot identification
- Flame graphs
- Hardware counter events
- Kernel and userspace profiling

**Key Deliverables**:
- Performance profile of application
- Flame graph visualization
- Optimization opportunities identified

---

### Lab 19: Memory Debugging - Valgrind
**Objective**: Detect memory issues

**Topics**:
- Memcheck tool for leak detection
- Use-after-free and buffer overflows
- Massif for heap profiling
- Cachegrind for cache simulation
- Performance vs debugging builds

**Key Deliverables**:
- Memory-clean application
- Heap usage visualization
- Fixed memory bugs

---

### Lab 20: Advanced Tracing - ftrace and eBPF
**Objective**: Kernel-level tracing and profiling

**Topics**:
- ftrace: function tracer, trace events
- trace-cmd and KernelShark
- eBPF programs and bpftrace
- kprobes and uprobes
- BCC tools for system analysis
- libbpf programming

**Key Deliverables**:
- Kernel function traces
- Custom eBPF tracing programs
- System-wide performance analysis

---

### Lab 21: Kernel Debugging
**Objective**: Debug kernel crashes and issues

**Topics**:
- KGDB (Kernel GDB) setup
- Kernel panic analysis
- Oops messages interpretation
- ftrace for kernel debugging
- Kmemleak for kernel memory leaks
- Lockdep for locking issues

**Key Deliverables**:
- KGDB debugging session
- Analyzed kernel crash
- Fixed kernel-level issue

---

## Hardware Requirements

### Primary Platform: BeaglePlay
- **SoC**: Texas Instruments AM6254 (Quad-core Cortex-A53 @ 1.4GHz)
- **RAM**: 2GB DDR4
- **Storage**: 16GB eMMC + microSD slot
- **Connectivity**: WiFi 5, Bluetooth 5.2, Gigabit Ethernet, SubGHz (868/915 MHz)
- **Expansion**: mikroBUS, Grove, QWIIC/STEMMA QT connectors
- **Debug**: UART via USB-C, JTAG

### Development Host Requirements
- **OS**: Ubuntu 24.04 LTS (or similar Linux distribution)
- **RAM**: Minimum 8GB (16GB recommended for Yocto)
- **Storage**: 100GB free space (Yocto builds are large)
- **CPU**: Modern multi-core processor

### Accessories
- USB-C cable (power + serial console)
- microSD card (32GB+, Class 10 or better)
- Ethernet cable (for network boot labs)
- Optional: mikroBUS peripherals (sensors, displays)

---

## Time Estimates

| Track | Labs | Estimated Time |
|-------|------|----------------|
| Embedded Linux Fundamentals | Labs 1-9 | 25-35 hours |
| Yocto Project | Labs 10-14 | 20-25 hours |
| Debugging & Performance | Labs 15-21 | 25-30 hours |
| **Total** | **21 labs** | **70-90 hours** |

---

## Prerequisites

- **Linux Command Line**: Comfortable with shell, file operations, text editing
- **C Programming**: Basic to intermediate level
- **Git**: Version control fundamentals
- **Hardware**: Understanding of basic electronics (optional but helpful)

---

## Learning Resources

- Linux kernel documentation
- U-Boot documentation
- Yocto Project Mega-Manual
- BeaglePlay technical reference manual
- TI AM62x documentation
- Device Tree specification

---

## Notes

1. **Original Content**: All labs are adapted concepts - you must create your own implementations
2. **BeaglePlay Focus**: Labs specifically target BeaglePlay hardware, not generic boards
3. **Progression**: Each lab builds on previous knowledge - follow the order
4. **Customization**: Feel free to extend labs with your own experiments
5. **Documentation**: Document your journey - this is a learning repository

---

*Last Updated: 2025-01-24*
*Target Platform: BeaglePlay*
*Based on: Professional embedded Linux training concepts, adapted for self-learning*
