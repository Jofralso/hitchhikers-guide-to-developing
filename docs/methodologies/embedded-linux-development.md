# Embedded Linux Development Methodology

## DON'T PANIC

The Guide has this to say about embedded Linux development:

*"Embedded Linux development is the art of taking a perfectly good Linux distribution and cramming it into a device that has less computing power than a 1990s calculator. It's remarkably similar to fitting a whale into a phone booth - technically possible with the right tools, but requires careful planning and a willingness to make compromises."*

---

## Overview

This methodology defines the structured approach to embedded Linux development, from hardware bring-up to application deployment. Based on the BeaglePlay training curriculum and industry best practices.

## Development Workflow

### Phase 1: Environment Setup

**Objective**: Establish development infrastructure

**Steps**:
1. **Host System Preparation**
   - Ubuntu 24.04 LTS recommended
   - Install essential build tools
   - Configure cross-compilation toolchain
   - Set up serial console access

2. **Target Hardware Setup**
   - BeaglePlay board configuration
   - Serial console connectivity
   - Network configuration (optional)
   - Storage preparation (microSD)

**Success Criteria**:
- ✅ Cross-compiler installed and verified
- ✅ Serial console access working
- ✅ Hello World compiles for target architecture
- ✅ QEMU user-mode emulation functional

**Estimated Time**: 1-2 hours

---

### Phase 2: Toolchain Mastery

**Objective**: Build and customize cross-compilation toolchain

**Approaches**:

#### A. Pre-built Toolchain (Quick Start)
```bash
sudo apt install gcc-aarch64-linux-gnu
```
**Pros**: Fast, maintained, well-tested  
**Cons**: Less control, may not match target exactly

#### B. Crosstool-NG (Recommended)
```bash
git clone https://github.com/crosstool-ng/crosstool-ng
cd crosstool-ng
./bootstrap && ./configure --enable-local
make
./ct-ng list-samples
./ct-ng aarch64-unknown-linux-gnu
./ct-ng menuconfig
./ct-ng build
```
**Pros**: Full control, customizable, reproducible  
**Cons**: Longer build time, more complex

#### C. Buildroot/Yocto (Advanced)
Generates toolchain as part of full system build.

**Best Practice**: Start with pre-built, graduate to Crosstool-NG for production.

---

### Phase 3: Bootloader Development

**Objective**: Customize U-Boot for target platform

**Key Concepts**:
- **SPL (Secondary Program Loader)**: First-stage bootloader
- **U-Boot Proper**: Second-stage bootloader
- **Device Tree**: Hardware description
- **Environment**: Boot configuration

**Workflow**:
```bash
# 1. Clone U-Boot
git clone https://source.denx.de/u-boot/u-boot.git
cd u-boot

# 2. Configure for BeaglePlay
make CROSS_COMPILE=aarch64-linux-gnu- am62x_evm_a53_defconfig

# 3. Customize (optional)
make CROSS_COMPILE=aarch64-linux-gnu- menuconfig

# 4. Build
make CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)

# 5. Deploy to SD card
# See lab03-bootloader for details
```

**Testing Strategy**:
1. Verify boot via serial console
2. Check environment variables
3. Test network boot (TFTP)
4. Validate device tree loading

---

### Phase 4: Kernel Development

**Objective**: Build custom Linux kernel for target

**Configuration Philosophy**:
- **Minimal**: Only essential drivers (faster boot, smaller size)
- **Modular**: Drivers as modules (flexible, larger size)
- **Balanced**: Common built-in, others modular (recommended)

**Workflow**:
```bash
# 1. Get kernel source
git clone https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
cd linux

# 2. Start with defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig

# 3. Customize for BeaglePlay
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- menuconfig
# Enable: TI AM62x support, device drivers, filesystems

# 4. Build
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image modules dtbs -j$(nproc)

# 5. Install modules (to rootfs staging area)
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
     INSTALL_MOD_PATH=/path/to/rootfs modules_install
```

**Device Tree Modifications**:
```dts
// Custom DTS overlay for application-specific hardware
/dts-v1/;
/plugin/;

/ {
    compatible = "ti,am625-sk";
    
    fragment@0 {
        target = <&main_i2c0>;
        __overlay__ {
            custom_sensor@48 {
                compatible = "vendor,sensor";
                reg = <0x48>;
            };
        };
    };
};
```

---

### Phase 5: Root Filesystem Construction

**Objective**: Create minimal yet functional root filesystem

**Approaches**:

#### A. BusyBox (Minimal - Recommended for Learning)
```bash
# 1. Build BusyBox
git clone https://git.busybox.net/busybox
cd busybox
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- menuconfig
# Enable: Static binary
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- install

# 2. Create rootfs structure
mkdir -p rootfs/{bin,sbin,etc,proc,sys,dev,lib,usr,tmp,home,root}

# 3. Copy BusyBox
cp -a _install/* rootfs/

# 4. Add essential files
cat > rootfs/etc/inittab << 'EOF'
::sysinit:/etc/init.d/rcS
::respawn:/sbin/getty -L console 0 vt100
::shutdown:/bin/umount -a -r
EOF

# 5. Create init script
cat > rootfs/etc/init.d/rcS << 'EOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
EOF
chmod +x rootfs/etc/init.d/rcS
```

#### B. Buildroot (Automated)
```bash
make beagleplay_defconfig
make menuconfig  # Customize packages
make -j$(nproc)
# Output: output/images/rootfs.tar
```

#### C. Yocto/OpenEmbedded (Production)
Full-featured distribution with package management.

**Directory Structure**:
```
rootfs/
├── bin/           # Essential binaries
├── sbin/          # System binaries
├── lib/           # Shared libraries
├── usr/
│   ├── bin/       # User binaries
│   ├── sbin/      # Non-essential system binaries
│   └── lib/       # User libraries
├── etc/           # Configuration files
├── dev/           # Device files
├── proc/          # Process information (mount point)
├── sys/           # Sysfs (mount point)
├── tmp/           # Temporary files
├── home/          # User home directories
└── root/          # Root user home
```

---

### Phase 6: Application Development

**Objective**: Develop and debug applications for target

**Cross-Development Workflow**:

1. **Write Code** (on host)
```c
// example.c
#include <stdio.h>
int main(void) {
    printf("Running on BeaglePlay!\n");
    return 0;
}
```

2. **Cross-Compile** (on host)
```bash
aarch64-linux-gnu-gcc -o example example.c
```

3. **Deploy** (to target)
```bash
scp example debian@beagleplay.local:~/
```

4. **Debug** (on target or remote)
```bash
# On target
gdb ./example

# Remote debugging
gdbserver :2345 ./example  # On target
aarch64-linux-gnu-gdb      # On host
(gdb) target remote beagleplay.local:2345
```

**Debugging Tools**:
- **gdb**: Interactive debugging
- **gdbserver**: Remote debugging
- **strace**: System call tracing
- **ltrace**: Library call tracing
- **valgrind**: Memory debugging
- **perf**: Performance profiling

---

## Build System Integration

### Buildroot Integration

**Philosophy**: Automated, reproducible builds

**Workflow**:
```bash
# 1. Configure
make menuconfig
  # Target options → aarch64
  # Toolchain → External toolchain
  # System → Custom scripts
  # Filesystem images → tar

# 2. Add custom packages
mkdir -p package/myapp
cat > package/myapp/Config.in
cat > package/myapp/myapp.mk

# 3. Build
make -j$(nproc)

# 4. Output
ls output/images/
```

### Yocto Integration

**Philosophy**: Layer-based, scalable, industry-standard

**Workflow**:
```bash
# 1. Setup
git clone git://git.yoctoproject.org/poky
cd poky
source oe-init-build-env

# 2. Configure (conf/local.conf)
MACHINE = "beagleplay"

# 3. Add custom layer
bitbake-layers create-layer meta-custom
bitbake-layers add-layer meta-custom

# 4. Create recipe
# meta-custom/recipes-apps/myapp/myapp_1.0.bb

# 5. Build
bitbake core-image-minimal
```

---

## Testing Methodology

### Unit Testing

**On Host** (with QEMU):
```bash
# Compile for ARM64
aarch64-linux-gnu-gcc -o test_suite tests/*.c

# Run with QEMU
qemu-aarch64 -L /usr/aarch64-linux-gnu ./test_suite
```

### Integration Testing

**On Target**:
```bash
# Automated test script
#!/bin/sh
echo "Running integration tests..."
./test_hardware
./test_peripherals
./test_network
echo "All tests passed!"
```

### Performance Testing

```bash
# Boot time
systemd-analyze

# Application performance
perf stat ./application

# Memory usage
valgrind --tool=massif ./application
```

---

## Deployment Strategies

### Development Deployment

**NFS Root**:
- Fast iteration
- No reflashing needed
- Easy debugging

```bash
# On host (NFS server)
sudo exportfs -o rw,no_root_squash beagleplay:/srv/nfs/rootfs

# U-Boot bootargs
setenv bootargs root=/dev/nfs nfsroot=192.168.1.100:/srv/nfs/rootfs ip=dhcp
```

**TFTP + NFS**:
- Network boot kernel
- NFS root filesystem
- Ideal for development

### Production Deployment

**SD Card**:
```bash
# Partition
sudo fdisk /dev/sdX
# p1: boot (FAT32, 128MB)
# p2: rootfs (ext4, remaining)

# Format
sudo mkfs.vfat -F 32 -n boot /dev/sdX1
sudo mkfs.ext4 -L rootfs /dev/sdX2

# Install
sudo cp -a boot/* /media/boot/
sudo cp -a rootfs/* /media/rootfs/
```

**eMMC Flash**:
- Faster than SD
- More reliable
- Requires flashing utility

---

## Best Practices

### Code Organization

```
project/
├── src/              # Application source
├── include/          # Headers
├── scripts/          # Build/deploy scripts
├── configs/          # Kernel/buildroot configs
├── patches/          # Custom patches
└── docs/             # Project documentation
```

### Version Control

```bash
# Track configurations
git add configs/kernel.config
git add configs/buildroot.config
git commit -m "feat: Add custom kernel configuration"

# Tag releases
git tag -a v1.0.0 -m "Release 1.0.0"
```

### Documentation

**Maintain**:
- Build instructions
- Hardware setup guide
- Troubleshooting notes
- Known issues
- Changelog

---

## Common Pitfalls

### 1. Endianness Mismatch
**Problem**: Code works on x86 but fails on ARM  
**Solution**: Use endian-safe code, test on target

### 2. Library Path Issues
**Problem**: Application can't find libraries  
**Solution**: Check `LD_LIBRARY_PATH`, use `ldd` to verify

### 3. Device Tree Errors
**Problem**: Peripherals not detected  
**Solution**: Verify device tree, check kernel logs (`dmesg`)

### 4. Cross-Compilation Flags
**Problem**: Binary won't run on target  
**Solution**: Verify `CROSS_COMPILE` and `ARCH` are set correctly

### 5. Kernel Module Dependencies
**Problem**: Module won't load  
**Solution**: Check `modprobe`, verify kernel version match

---

## Performance Optimization

### Boot Time

1. **Kernel**: Disable unused drivers
2. **Init**: Minimize services
3. **Filesystem**: Use compressed filesystem
4. **Async**: Parallelize initialization

### Runtime Performance

1. **Compiler Flags**: `-O2`, `-march=native`
2. **Profiling**: Use `perf` to identify hotspots
3. **Caching**: Leverage CPU cache effectively
4. **Algorithms**: Choose appropriate data structures

---

## Security Considerations

### Minimal Attack Surface

- Remove unnecessary services
- Disable unused ports
- Minimal package installation

### Updates

- Secure boot (optional)
- Signed images
- OTA update mechanism

### Hardening

- SELinux/AppArmor
- Firewall rules
- User permissions

---

## References

- [Bootlin Embedded Linux Training](https://bootlin.com/training/embedded-linux/)
- [Yocto Project Documentation](https://docs.yoctoproject.org/)
- [Buildroot Manual](https://buildroot.org/downloads/manual/manual.html)
- [U-Boot Documentation](https://u-boot.readthedocs.io/)
- [Linux Kernel Documentation](https://www.kernel.org/doc/)

---

**Remember**: The answer to "How long does a kernel build take?" is 42 minutes... or longer if you forgot to enable ccache.

*Part of the [Hitchhiker's Guide to Developing](https://github.com/Jofralso/hitchhikers-guide-to-developing)*
