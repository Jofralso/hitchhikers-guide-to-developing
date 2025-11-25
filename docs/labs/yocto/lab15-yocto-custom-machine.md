# Lab 15: Custom Machine Configuration

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about debugging:

*"Debugging is the art of figuring out why your code doesn't work, as opposed to why you thought it would work. This is similar to the difference between what Deep Thought calculated (42) and what everyone expected (a useful answer). Both are technically correct, but only one is helpful."*

## Objectives

Create custom machine configurations to define hardware-specific settings, bootloader parameters, and kernel configurations for your target platform.

**What You'll Learn:**
- Machine configuration file structure
- SoC family includes
- Bootloader and kernel provider selection
- Device Tree specification
- Serial console configuration
- Multi-config for R5 bootloader

**Time Required:** 1-2 hours

---

## Prerequisites

**Completed Labs:**
- Lab 13: Custom Yocto Layer
- Lab 14: Recipe Extension

---

## 1. Understanding Machine Configurations

### 1.1 What is a Machine?

**Machine** = Hardware platform definition

**Includes:**
- CPU architecture
- Bootloader settings
- Kernel configuration
- Device Tree files
- Serial console parameters

**Example machines:**
- `beagleplay`: BeaglePlay board
- `qemux86-64`: QEMU x86_64
- `raspberrypi4`: Raspberry Pi 4

### 1.2 Machine File Location

**Standard path:**
```
meta-<layer>/conf/machine/<machine-name>.conf
```

**Example:**
```
meta-ti/conf/machine/beagleplay.conf
meta-beagleplay/conf/machine/beagleplay-custom.conf
```

---

## 2. Creating Custom Machine

### 2.1 Create Machine Config File

```bash
cd ~/yocto-labs/meta-beagleplay
mkdir -p conf/machine
nano conf/machine/beagleplay-custom.conf
```

### 2.2 Basic Machine Structure

```python
#@TYPE: Machine
#@NAME: BeaglePlay Custom
#@DESCRIPTION: Custom BeaglePlay machine configuration

# Include TI K3 SoC family settings
require conf/machine/include/k3.inc
require conf/machine/include/mc_k3r5.inc

# SoC family
SOC_FAMILY:append = ":am62xx"

# Serial console
SERIAL_CONSOLES = "115200;ttyS2"

# Kernel provider
PREFERRED_PROVIDER_virtual/kernel = "linux-ti-staging"
KERNEL_DEVICETREE = "ti/k3-am625-beagleplay.dtb"

# Bootloader provider
PREFERRED_PROVIDER_virtual/bootloader = "u-boot-ti-staging"
PREFERRED_PROVIDER_u-boot = "u-boot-ti-staging"

# U-Boot configuration
UBOOT_MACHINE = "am62x_beagleplay_a53_defconfig"

# TI-specific settings
TFA_BOARD = "lite"
TFA_K3_SYSTEM_SUSPEND = "1"
OPTEEMACHINE = "k3-am62x"

# Boot method (extlinux)
require conf/machine/include/extlinux-bb.inc
```

### 2.3 Understanding Each Section

**SoC Family:**
```python
require conf/machine/include/k3.inc
```
Inherits ARM64 TI K3 platform defaults.

**Serial Console:**
```python
SERIAL_CONSOLES = "115200;ttyS2"
```
Format: `"baudrate;device"`

**Kernel:**
```python
PREFERRED_PROVIDER_virtual/kernel = "linux-ti-staging"
KERNEL_DEVICETREE = "ti/k3-am625-beagleplay.dtb"
```
Selects TI kernel and Device Tree blob.

**Bootloader:**
```python
UBOOT_MACHINE = "am62x_beagleplay_a53_defconfig"
```
U-Boot defconfig for Cortex-A53.

---

## 3. R5 Multi-Config Support

### 3.1 Why R5 Configuration?

**BeaglePlay boot sequence:**
1. **ROM code** loads R5 SPL (tiboot3.bin)
2. **R5 SPL** loads TF-A + A53 SPL (tispl.bin)
3. **A53 SPL** loads U-Boot proper (u-boot.img)
4. **U-Boot** boots Linux kernel

**R5 is ARM Cortex-R5** (different architecture from A53) → needs separate machine config.

### 3.2 Create R5 Machine Config

```bash
nano conf/machine/beagleplay-custom-k3r5.conf
```

**Content:**
```python
#@TYPE: Machine
#@NAME: BeaglePlay Custom R5
#@DESCRIPTION: R5 bootloader configuration for BeaglePlay Custom

require conf/machine/include/k3r5.inc

# System firmware
SYSFW_SOC = "am62x"
SYSFW_CONFIG = "evm"
SYSFW_SUFFIX = "gp"  # General Purpose (not High Security)

# U-Boot R5 defconfig
UBOOT_MACHINE = "am62x_beagleplay_r5_defconfig"
```

**Naming convention:** `<machine>-k3r5.conf`

---

## 4. Using Custom Machine

### 4.1 Update Build Configuration

```bash
cd ~/yocto-labs/build
nano conf/local.conf
```

**Change MACHINE:**
```python
# Old:
# MACHINE = "beagleplay"

# New:
MACHINE = "beagleplay-custom"
```

### 4.2 Clean and Rebuild

```bash
bitbake -c cleanall core-image-minimal
bitbake core-image-minimal
```

**Full rebuild required** (different machine).

### 4.3 Verify Output

```bash
ls tmp/deploy/images/beagleplay-custom/
```

**Should contain:**
```
Image-beagleplay-custom.bin
k3-am625-beagleplay.dtb
tiboot3.bin
tispl.bin
u-boot.img
core-image-minimal-beagleplay-custom.rootfs.tar.xz
```

---

## 5. Advanced Machine Configuration

### 5.1 Add Machine Features

**Edit machine config:**
```python
# Machine features
MACHINE_FEATURES = " \
    ext2 \
    usbhost \
    usbgadget \
    ethernet \
    wifi \
    bluetooth \
    alsa \
"
```

**Features control:**
- Package selection
- Kernel modules
- Image capabilities

### 5.2 Storage Configuration

**SD card / eMMC:**
```python
# WIC image settings
WKS_FILE = "beagleplay-custom.wks"
IMAGE_FSTYPES = "tar.xz wic.xz"
IMAGE_BOOT_FILES = " \
    Image \
    k3-am625-beagleplay.dtb \
    tiboot3.bin \
    tispl.bin \
    u-boot.img \
"
```

### 5.3 Kernel Configuration

**Default kernel config:**
```python
KERNEL_DEFCONFIG = "defconfig"
KERNEL_CONFIG_FRAGMENTS = "beagleplay-custom.cfg"
```

**Extra kernel modules:**
```python
KERNEL_MODULE_AUTOLOAD += "nunchuk"
```

---

## 6. Creating WKS Partition Layout

### 6.1 Custom Partition Table

**Create WKS file:**
```bash
mkdir -p ~/yocto-labs/meta-beagleplay/wic
nano ~/yocto-labs/meta-beagleplay/wic/beagleplay-custom.wks
```

**Content:**
```
# BeaglePlay Custom partition layout

part /boot --source bootimg-partition --ondisk mmcblk0 --fstype=vfat --label boot --active --align 4096 --size 128M
part / --source rootfs --ondisk mmcblk0 --fstype=ext4 --label rootfs --align 4096 --size 2G
```

**Explanation:**
- `part /boot`: FAT32 boot partition (128MB)
- `part /`: ext4 root filesystem (2GB)
- `--ondisk mmcblk0`: SD card device
- `--align 4096`: 4KB alignment

### 6.2 Reference in Machine Config

```python
WKS_FILE = "beagleplay-custom.wks"
WKS_FILE_DEPENDS = "virtual/kernel u-boot-ti-staging"
```

---

## 7. Machine-Specific Overrides

### 7.1 Conditional Variables

**Syntax:**
```python
VARIABLE:<machine> = "value"
VARIABLE:append:<machine> = " extra"
```

**Example:**
```python
# Different kernel for custom machine
PREFERRED_VERSION_linux-ti-staging:beagleplay-custom = "6.6.%"

# Extra packages for custom machine
IMAGE_INSTALL:append:beagleplay-custom = " custom-app"
```

### 7.2 Multi-Machine Recipes

**Recipe can check machine:**
```python
do_install() {
    if [ "${MACHINE}" = "beagleplay-custom" ]; then
        install -m 0644 custom-config ${D}/etc/
    fi
}
```

---

## 8. Testing Custom Machine

### 8.1 Build Verification

```bash
bitbake core-image-minimal
```

**Check variables:**
```bash
bitbake -e core-image-minimal | grep "^MACHINE="
# Output: MACHINE="beagleplay-custom"

bitbake -e core-image-minimal | grep "^SERIAL_CONSOLES="
# Output: SERIAL_CONSOLES="115200;ttyS2"
```

### 8.2 Flash and Boot

```bash
cd tmp/deploy/images/beagleplay-custom
xz -dc core-image-minimal-beagleplay-custom.rootfs.wic.xz | \
    sudo dd of=/dev/sdb bs=4M status=progress conv=fdatasync
```

**Boot BeaglePlay from SD card.**

**Verify in boot logs:**
```
U-Boot 2023.04 (Nov 20 2024)
Model: BeagleBoard.org BeaglePlay
```

---

## 9. Going Further

### 9.1 Machine Include Files

**Create reusable includes:**
```bash
nano conf/machine/include/beagleplay-common.inc
```

**Content:**
```python
# Common settings for all BeaglePlay variants

SOC_FAMILY:append = ":am62xx"
SERIAL_CONSOLES = "115200;ttyS2"
PREFERRED_PROVIDER_virtual/kernel = "linux-ti-staging"
```

**Use in machine configs:**
```python
require conf/machine/include/beagleplay-common.inc
```

### 9.2 Multiple Machine Variants

**Create family of machines:**
```
conf/machine/
├── beagleplay-minimal.conf    # Minimal features
├── beagleplay-dev.conf        # Development tools
├── beagleplay-production.conf # Production config
```

---

## 10. Key Takeaways

**Accomplished:**
1. ✅ Created custom machine configuration
2. ✅ Configured R5 multi-config support
3. ✅ Defined custom partition layout
4. ✅ Built and tested custom machine

**Skills Gained:**
- Machine configuration structure
- SoC family includes
- Multi-architecture support
- WKS partition definitions

**Next Steps:**
- **Lab 16**: Create custom distribution images
- **Lab 17**: SDK development workflow

---

## 11. Verification Checklist

- [ ] `beagleplay-custom.conf` created
- [ ] R5 config `beagleplay-custom-k3r5.conf` created
- [ ] Build succeeds with MACHINE="beagleplay-custom"
- [ ] Images appear in `tmp/deploy/images/beagleplay-custom/`
- [ ] SD card boots successfully
- [ ] Serial console works on ttyS2

---

**End of Lab 15**

*The Guide rates this lab: **Mostly Harmless** ⭐⭐⭐⭐*

Custom machine configurations enable you to define precise hardware-specific settings, manage multiple board variants, and maintain clean separation between different product configurations.
