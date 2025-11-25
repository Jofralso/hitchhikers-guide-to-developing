# Lab 3: U-Boot Bootloader for BeaglePlay

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about bootloaders:

*"A bootloader is the first piece of software that runs when your board powers on. It's like Arthur Dent's morning routine - essential, often confusing, and if it goes wrong, the entire day (or boot process) is ruined. The difference is that U-Boot is marginally more reliable than Arthur's grasp of temporal mechanics."*

## Learning Objectives

By the end of this lab, you will be able to:

- Understand the AM62x multi-stage boot architecture
- Build bootloader components for both 32-bit (R5) and 64-bit (A53) processors
- Compile U-Boot SPL for the R5 cortex processor
- Build ARM Trusted Firmware (TF-A) for secure boot
- Configure and compile U-Boot for the main A53 processors
- Create properly formatted SD card boot partitions
- Test and interact with U-Boot bootloader
- Configure U-Boot environment persistence
- Add custom commands to U-Boot

**Estimated Time:** 4-5 hours

**Prerequisites:**
- Completed Lab 1 (Custom Toolchain)
- Completed Lab 2 (Hardware Discovery)
- Basic understanding of boot sequences
- Familiarity with cross-compilation

## Introduction

### The BeaglePlay Boot Challenge

Unlike simple microcontrollers with a single processor, the TI AM62x SoC on BeaglePlay presents a complex boot architecture with **three different processor types**:

1. **Cortex-R5F** (32-bit, WKUP domain) - Boot orchestrator
2. **Cortex-M4F** (32-bit, MCU domain) - Security & power management  
3. **Cortex-A53** (64-bit, MAIN domain) - Linux application processors (4 cores)

This complexity means we can't just compile a single bootloader. We need to build multiple components that work together in a carefully choreographed boot sequence.

### Why This Matters

Understanding the boot process is critical because:

- **Debugging:** When boot fails, you need to know which stage is failing
- **Security:** Each boot stage can verify the next (secure boot chains)
- **Performance:** Boot time optimization requires understanding each stage
- **Customization:** Advanced features require bootloader modifications

Think of it like a relay race - each runner (boot stage) must successfully hand off the baton (control) to the next, or the whole race fails.

## Boot Sequence Overview

### TI AM62x Boot Flow

Here's the complete boot sequence we'll implement:

```
┌──────────────┐
│  Power-On    │
│  Reset       │
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│  ROM Code (R5 CPU)   │ ← Built into SoC, cannot modify
│  - Minimal init      │
│  - Read boot source  │
│  - Load tiboot3.bin  │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  tiboot3.bin         │ ← We build this (R5 SPL + TIFS)
│  - R5 U-Boot SPL     │
│  - TIFS firmware     │
│  - DDR init          │
│  - Start M4F & A53   │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  TF-A (BL31)         │ ← We build this (A53 secure world)
│  - ARM Trusted FW    │
│  - Secure services   │
│  - Switch to normal  │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  tispl.bin           │ ← We build this (A53 SPL)
│  - A53 U-Boot SPL    │
│  - Load full U-Boot  │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  u-boot.img          │ ← We build this (Full U-Boot)
│  - Full bootloader   │
│  - Shell/commands    │
│  - Load Linux kernel │
└──────────────────────┘
```

### What We're Building

| Component | Processor | Purpose | Output File |
|-----------|-----------|---------|-------------|
| **R5 SPL** | Cortex-R5F (32-bit) | Initialize DDR, start A53 | `tiboot3.bin` |
| **TIFS** | Cortex-M4F (32-bit) | Security & power mgmt | (embedded in tiboot3.bin) |
| **TF-A** | Cortex-A53 (64-bit) | Secure world services | `bl31.bin` → `tispl.bin` |
| **A53 SPL** | Cortex-A53 (64-bit) | Load full U-Boot | `tispl.bin` |
| **U-Boot** | Cortex-A53 (64-bit) | Interactive shell, boot Linux | `u-boot.img` |

Notice we need **two different cross-compilation toolchains**:
- 32-bit ARM toolchain for R5/M4F components
- 64-bit ARM64 toolchain for A53 components (built in Lab 1)

## Workspace Setup

Create a dedicated bootloader directory:

```bash
cd $HOME/embedded-labs
mkdir -p bootloader
cd bootloader
```

All work in this lab happens in this directory.

## Part 1: 32-bit ARM Toolchain for R5

### Why We Need This

The R5 processor is a 32-bit ARMv7-R CPU, different from the 64-bit ARMv8-A Cortex-A53. We need a matching toolchain.

**Option A:** Use Crosstool-NG to build a custom 32-bit toolchain (slow, ~2 hours)  
**Option B:** Download pre-built toolchain from ARM (fast, recommended)

### Installing Pre-built ARM Toolchain

Download the official ARM GNU toolchain for bare-metal 32-bit ARM:

```bash
cd $HOME/embedded-labs/bootloader
wget https://developer.arm.com/-/media/Files/downloads/gnu/12.2.rel1/binrel/arm-gnu-toolchain-12.2.rel1-x86_64-arm-none-eabi.tar.xz
```

Extract to the same location as our 64-bit toolchain:

```bash
tar xf arm-gnu-toolchain-12.2.rel1-x86_64-arm-none-eabi.tar.xz -C $HOME/x-tools/
```

Add to your PATH (add this to `~/.bashrc` for persistence):

```bash
export PATH=$HOME/x-tools/arm-gnu-toolchain-12.2.rel1-x86_64-arm-none-eabi/bin:$PATH
```

Reload your shell or source the updated `.bashrc`:

```bash
source ~/.bashrc
```

Verify the installation:

```bash
arm-none-eabi-gcc --version
```

You should see:

```
arm-none-eabi-gcc (Arm GNU Toolchain 12.2.Rel1 (Build arm-12.24)) 12.2.1 20221205
```

**Understanding the toolchain tuple:** `arm-none-eabi`
- **arm** - Target architecture (32-bit ARM)
- **none** - No operating system (bare metal)
- **eabi** - Embedded Application Binary Interface

## Part 2: Building R5 U-Boot SPL

### Get U-Boot Sources

BeaglePlay support is not yet in mainline U-Boot, so we use BeagleBoard's fork:

```bash
cd $HOME/embedded-labs/bootloader
git clone https://git.beagleboard.org/beagleplay/u-boot.git
cd u-boot/
git checkout f036fb
```

The `f036fb` commit is tested and known to work with BeaglePlay.

### Understand U-Boot Build System

Take a moment to read the README:

```bash
less README
```

Key sections:
- **Building the Software** - Configuration and compilation process
- **Configuration** - How defconfig files work
- **Building** - Cross-compilation variables

U-Boot uses Kconfig (same as Linux kernel) for configuration.

### Configure U-Boot for R5

We'll use **out-of-tree builds** to keep source clean and build artifacts separate. This allows building multiple U-Boot configurations from the same source.

Create R5 build directory:

```bash
mkdir -p $HOME/embedded-labs/bootloader/build_uboot/r5
```

Set the cross-compiler:

```bash
export CROSS_COMPILE=arm-none-eabi-
```

**Important (like knowing where your towel is):** The trailing dash is required!

Find the R5 configuration:

```bash
ls configs/ | grep am62x
```

You'll see several configs. We want `am62x_evm_r5_defconfig` for R5 SPL.

Load the configuration:

```bash
make am62x_evm_r5_defconfig O=$HOME/embedded-labs/bootloader/build_uboot/r5/
```

The `O=` parameter tells make to place all build output in that directory.

### Install Build Dependencies

U-Boot needs several development packages:

```bash
sudo apt install libssl-dev device-tree-compiler swig python3-dev python3-setuptools
```

What these provide:
- **libssl-dev** - Cryptographic signing of boot images
- **device-tree-compiler** - Compile Device Tree Blobs (DTBs)
- **swig** - Python bindings for U-Boot tools
- **python3-dev** - mkimage and other build tools

### Compile R5 U-Boot SPL

Now build it:

```bash
make -j$(nproc) O=$HOME/embedded-labs/bootloader/build_uboot/r5/
```

The `-j$(nproc)` uses all CPU cores for parallel compilation.

Build time: ~2-5 minutes on a modern system.

### Verify R5 Build Output

Check what was built:

```bash
ls -lh $HOME/embedded-labs/bootloader/build_uboot/r5/spl/
```

Key files:
- **u-boot-spl.bin** - The R5 SPL binary (this is what we need!)
- **u-boot-spl.map** - Memory map for debugging
- **u-boot-spl** - ELF file with debug symbols

The `u-boot-spl.bin` is ~220KB. Check its size:

```bash
ls -lh $HOME/embedded-labs/bootloader/build_uboot/r5/spl/u-boot-spl.bin
```

**What does R5 SPL do?**
- Initializes DDR memory (critical - without RAM, nothing else works)
- Loads TIFS firmware to the M4F processor
- Wakes up the first Cortex-A53 CPU
- Hands control to TF-A on the A53

## Part 3: TI Firmware (TIFS)

### Get TI Firmware Package

TI provides pre-built firmware for security and device management:

```bash
cd $HOME/embedded-labs/bootloader
git clone https://git.ti.com/git/processor-firmware/ti-linux-firmware.git
cd ti-linux-firmware
git checkout 09.01.00.008
```

This package contains:
- **TIFS** - TI Foundational Security firmware (runs on M4F)
- **DM** - Device Management firmware (power/clock control)

Explore the firmware files:

```bash
ls -lh ti-sysfw/
ls -lh ti-dm/am62xx/
```

Key files:
- `ti-sysfw/ti-fs-firmware-am62x-gp.bin` - TIFS for GP (General Purpose) devices
- `ti-dm/am62xx/ipc_echo_testb_mcu1_0_release_strip.xer5f` - DM firmware

**GP vs HS:** BeaglePlay uses GP (general purpose) silicon. HS (High Security) devices have secure boot enabled and require signed images.

### Create Combined tiboot3.bin Image

The ROM code expects a single `tiboot3.bin` file containing:
1. R5 U-Boot SPL
2. TIFS firmware
3. X.509 certificate wrapper (for authentication)

TI provides the `k3-image-gen` tool to create this combined image:

```bash
cd $HOME/embedded-labs/bootloader
git clone https://git.ti.com/cgit/k3-image-gen/k3-image-gen
cd k3-image-gen/
git checkout 09.00.00.001
```

Build the combined image:

```bash
make SOC=am62x \
     SBL=$HOME/embedded-labs/bootloader/build_uboot/r5/spl/u-boot-spl.bin \
     SYSFW_PATH=$HOME/embedded-labs/bootloader/ti-linux-firmware/ti-sysfw/ti-fs-firmware-am62x-gp.bin
```

Parameters explained:
- **SOC=am62x** - Target SoC (determines certificate format)
- **SBL=...** - Secondary Boot Loader (our R5 SPL)
- **SYSFW_PATH=...** - System firmware (TIFS)

Output:

```bash
ls -lh tiboot3-am62x-gp-evm.bin
```

The tool creates a ~280KB file and a symlink `tiboot3.bin` → `tiboot3-am62x-gp-evm.bin`.

**What's inside tiboot3.bin?**

```
┌─────────────────────────┐
│  X.509 Certificate      │  ← Authentication header
├─────────────────────────┤
│  TIFS Firmware          │  ← M4F security firmware
├─────────────────────────┤
│  R5 U-Boot SPL          │  ← DDR init, boot orchestration
└─────────────────────────┘
```

Use this command to inspect it (optional):

```bash
file tiboot3.bin
hexdump -C tiboot3.bin | head -50
```

## Part 4: ARM Trusted Firmware (TF-A)

### What is TF-A?

ARM Trusted Firmware provides:
- **Secure Monitor** - Mediates access to secure resources
- **Power Management** - CPU hotplug, suspend/resume
- **Secure Boot** - Chain of trust verification

It runs in ARM's "Secure World" (EL3 exception level) and provides services to the "Normal World" (where Linux runs).

### Get TF-A Sources

Clone the official ARM repository:

```bash
cd $HOME/embedded-labs/bootloader
git clone https://github.com/ARM-software/arm-trusted-firmware.git
cd arm-trusted-firmware/
git checkout v2.9
```

Version 2.9 is tested with BeaglePlay.

### Configure TF-A for AM62x

TF-A uses simple Makefile-based configuration. Set up for 64-bit:

```bash
export CROSS_COMPILE=aarch64-beagleplay-linux-musl-
```

This uses our custom toolchain from Lab 1!

Build TF-A with these parameters:

```bash
make ARCH=aarch64 PLAT=k3 TARGET_BOARD=lite -j$(nproc)
```

Parameters explained:
- **ARCH=aarch64** - 64-bit ARM architecture
- **PLAT=k3** - TI K3 SoC family (AM62x, AM64x, AM65x all use this)
- **TARGET_BOARD=lite** - BeaglePlay variant (fewer features than full EVM)

Build time: ~1 minute

### Verify TF-A Build

Check the output:

```bash
ls -lh build/k3/lite/release/
```

Key file:
- **bl31.bin** - BL31 (Boot Loader stage 3.1) for A53

```bash
ls -lh build/k3/lite/release/bl31.bin
```

Size: ~50-60KB

**TF-A Boot Stages:**
- **BL1** - Not used on AM62x (ROM code replaces this)
- **BL2** - Not used on AM62x (R5 SPL replaces this)
- **BL31** - Secure Monitor (this is what we built)
- **BL32** - Optional Secure OS (we're not using OP-TEE)
- **BL33** - Normal World bootloader (U-Boot)

## Part 5: Building A53 U-Boot

Now we build the full U-Boot for the 64-bit Cortex-A53 processors.

### Create A53 Build Directory

```bash
cd $HOME/embedded-labs/bootloader
mkdir -p build_uboot/a53
cd u-boot/
```

### Configure for A53

Switch to 64-bit toolchain:

```bash
export CROSS_COMPILE=aarch64-beagleplay-linux-musl-
```

Load A53 defconfig:

```bash
make am62x_evm_a53_defconfig O=$HOME/embedded-labs/bootloader/build_uboot/a53/
```

### Customize U-Boot Environment Storage

By default, U-Boot stores its environment in various places. We'll configure it to use an ext4 filesystem on the SD card for persistence.

Enter menuconfig:

```bash
make menuconfig O=$HOME/embedded-labs/bootloader/build_uboot/a53/
```

Navigate using arrow keys, Enter to select, Space to toggle, '/' to search.

Configuration changes:

1. Navigate to: `Environment` →
2. Enable: `Environment is in a EXT4 filesystem`
3. Disable all other environment storage options:
   - `[ ]` Environment is in MMC
   - `[ ]` Environment is in SPI flash
   - `[ ]` Environment is in UBI
4. Configure EXT4 environment:
   - `Name of the block device for the environment` → `mmc`
   - `Device and partition for where to store the environment` → `1:2`
   - `Name of the EXT4 file to use for the environment` → `/uboot.env`
5. Disable: `SPL Environment is in a EXT4 filesystem` (SPL doesn't need to save env)

Save and exit menuconfig.

**Why ext4 for environment?**
- Can edit `uboot.env` from Linux if needed
- Better for frequent writes than FAT32
- Easier to back up

### Build A53 U-Boot

This build needs to embed TF-A and Device Management firmware:

```bash
make -j$(nproc) \
     ATF=$HOME/embedded-labs/bootloader/arm-trusted-firmware/build/k3/lite/release/bl31.bin \
     DM=$HOME/embedded-labs/bootloader/ti-linux-firmware/ti-dm/am62xx/ipc_echo_testb_mcu1_0_release_strip.xer5f \
     O=$HOME/embedded-labs/bootloader/build_uboot/a53/
```

Parameters explained:
- **ATF=...** - Path to TF-A BL31 (will be embedded in tispl.bin)
- **DM=...** - Device Management firmware for M4F
- **O=...** - Output directory

Build time: ~3-5 minutes

### Verify A53 Build Output

Check what was produced:

```bash
ls -lh $HOME/embedded-labs/bootloader/build_uboot/a53/
```

Critical files:
- **tispl.bin** - TI SPL image (contains A53 SPL + TF-A + DM firmware)
- **u-boot.img** - Full U-Boot bootloader
- **u-boot** - ELF file with debug symbols

Size check:

```bash
ls -lh $HOME/embedded-labs/bootloader/build_uboot/a53/{tispl.bin,u-boot.img}
```

Expected sizes:
- `tispl.bin` - ~1.5MB (large because it contains TF-A and DM firmware)
- `u-boot.img` - ~900KB

**What's in tispl.bin?**

```
┌─────────────────────────┐
│  A53 U-Boot SPL         │  ← Loads full U-Boot
├─────────────────────────┤
│  TF-A BL31              │  ← Secure monitor
├─────────────────────────┤
│  DM Firmware            │  ← Device management
├─────────────────────────┤
│  Device Tree Blobs      │  ← Hardware descriptions
└─────────────────────────┘
```

## Part 6: SD Card Preparation

### Boot Requirements

The TI ROM code expects:
1. **FAT32 boot partition** with specific type code
2. **Bootable flag** set on the partition
3. Bootloader files in a specific order

We'll also create a second partition for U-Boot environment storage.

### Identify Your SD Card

Insert your SD card. Check which device it becomes:

```bash
sudo dmesg | tail -20
```

Look for messages like:

```
[12345.678] mmc0: new high speed SDHC card at address 0007
[12345.680] mmcblk0: mmc0:0007 SD16G 14.9 GiB
```

**Device naming:**
- `/dev/mmcblk0` - SD card on internal reader
- `/dev/sdb` - SD card on USB adapter

**⚠️ WARNING:** Double-check the device name! Using the wrong device will destroy your data!

Verify with:

```bash
lsblk
```

For this lab, we'll assume `/dev/mmcblk0`. **Adjust if your device is different!**

### Unmount Existing Partitions

If the SD card is auto-mounted:

```bash
sudo umount /dev/mmcblk0p*
```

### Erase Partition Table

Zero out the first 16MB to remove any existing partitions:

```bash
sudo dd if=/dev/zero of=/dev/mmcblk0 bs=1M count=16 status=progress
```

**What this does:**
- Removes old partition table
- Removes old bootloader remnants
- Ensures clean slate

### Create Partition Table

We'll use `cfdisk` for a visual interface:

```bash
sudo apt install fdisk
sudo cfdisk /dev/mmcblk0
```

If asked to "Select a label type", choose **dos** (MBR partition table). We don't need GPT for SD cards under 2TB.

### Create Partitions

In the cfdisk interface:

**Partition 1: Boot (FAT32)**

1. Select `[ New ]`
2. Partition size: `128M`
3. Select `[ primary ]`
4. Select `[ Type ]` → Choose `c` (W95 FAT32 LBA)
5. Select `[ Bootable ]` (asterisk `*` should appear in Boot column)

**Partition 2: U-Boot Environment (ext4)**

1. Move down to free space
2. Select `[ New ]`
3. Partition size: `300M`
4. Select `[ primary ]`
5. Type is already `83` (Linux) - no change needed

**Write Changes:**

1. Select `[ Write ]`
2. Type `yes` to confirm
3. Select `[ Quit ]`

Your partition table should look like:

```
Device        Boot   Start      End  Sectors  Size Id Type
/dev/mmcblk0p1 *       2048   264191   262144  128M  c W95 FAT32 (LBA)
/dev/mmcblk0p2       264192   878591   614400  300M 83 Linux
```

### Reload Partition Table

Remove and re-insert the SD card, or run:

```bash
sudo partprobe /dev/mmcblk0
```

### Create Filesystems

**Format boot partition as FAT32:**

```bash
sudo mkfs.vfat -F 32 -n boot /dev/mmcblk0p1
```

Parameters:
- `-F 32` - FAT32 filesystem
- `-n boot` - Volume label "boot"

**Format environment partition as ext4:**

```bash
sudo mkfs.ext4 -L env -O ^metadata_csum /dev/mmcblk0p2
```

Parameters:
- `-L env` - Volume label "env"
- `-O ^metadata_csum` - Disable metadata checksums (U-Boot doesn't support them yet)

**Why disable metadata_csum?**  
Current U-Boot (2021.01) doesn't support ext4 metadata checksums. Without this flag, U-Boot can't read/write the partition.

### Mount Boot Partition

Remove and re-insert the SD card. It should auto-mount to `/media/$USER/boot`.

Verify:

```bash
mount | grep mmcblk0p1
```

You should see:

```
/dev/mmcblk0p1 on /media/your-username/boot type vfat (...)
```

## Part 7: Install Bootloader to SD Card

Now we copy all our built bootloader components to the SD card.

### Copy Bootloader Files

```bash
# Copy R5 bootloader (tiboot3.bin)
cp $HOME/embedded-labs/bootloader/k3-image-gen/tiboot3.bin /media/$USER/boot/

# Copy A53 SPL (tispl.bin)
cp $HOME/embedded-labs/bootloader/build_uboot/a53/tispl.bin /media/$USER/boot/

# Copy full U-Boot (u-boot.img)
cp $HOME/embedded-labs/bootloader/build_uboot/a53/u-boot.img /media/$USER/boot/
```

Verify all files are present:

```bash
ls -lh /media/$USER/boot/
```

You should see:

```
-rwxr-xr-x 1 you you 279K tiboot3.bin
-rwxr-xr-x 1 you you 1.5M tispl.bin
-rwxr-xr-x 1 you you 900K u-boot.img
```

Safely eject:

```bash
sync
sudo umount /media/$USER/boot
```

## Part 8: Testing U-Boot

### Boot from SD Card

1. **Insert SD card** into BeaglePlay
2. **Hold USR button** (next to SD card slot)
3. **Power on** or **reset** the board (keep holding USR)
4. **Release USR** after 2 seconds

The USR button tells ROM code to boot from SD card instead of eMMC.

### Expected Boot Output

On your serial console (picocom), you should see:

```
U-Boot SPL 2021.01-gf036fbdc25 (Jan 15 2025 - 14:33:12 +0100)
SYSFW ABI: 3.1 (firmware rev 0x0009 '9.1.8--v09.01.08 (Kool Koala)')
SPL initial stack usage: 13384 bytes
Trying to boot from MMC2
spl_load_fit_image: Skip load 'tee': image size is 0!
Loading Environment from MMC... *** Warning - No MMC card found, using default environment

Starting ATF on ARM64 core...

NOTICE:  BL31: v2.9(release):v2.9.0
NOTICE:  BL31: Built : 14:28:19, Jan 15 2025


U-Boot SPL 2021.01-gf036fbdc25 (Jan 15 2025 - 15:45:30 +0100)
SYSFW ABI: 3.1 (firmware rev 0x0009 '9.1.8--v09.01.08 (Kool Koala)')
Trying to boot from MMC2


U-Boot 2021.01-gf036fbdc25 (Jan 15 2025 - 15:45:30 +0100)

SoC:   AM62X SR1.0 GP
Model: BeagleBoard.org BeaglePlay
Board: BEAGLEPLAY-A0- rev 02
DRAM:  2 GiB
MMC:   mmc@fa10000: 0, mmc@fa00000: 1, mmc@fa20000: 2
Loading Environment from EXT4... ** File not found /uboot.env **
** Unable to read "/uboot.env" from mmc1:2 **
In:    serial@2800000
Out:   serial@2800000
Err:   serial@2800000
Net:   
Error: ethernet@8000000port@1 address not set.

Press SPACE to abort autoboot in 2 seconds
=>
```

**Press SPACE** to stop autoboot and get to the U-Boot prompt: `=>`

### Analyzing Boot Messages

Let's understand what happened:

**Stage 1: R5 U-Boot SPL**
```
U-Boot SPL 2021.01-gf036fbdc25 (Jan 15 2025 - 14:33:12 +0100)
SYSFW ABI: 3.1 (firmware rev 0x0009 '9.1.8--v09.01.08 (Kool Koala)')
```
- Our R5 SPL started
- TIFS firmware loaded (Kool Koala = version 9.1.8)

**Stage 2: TF-A**
```
NOTICE:  BL31: v2.9(release):v2.9.0
NOTICE:  BL31: Built : 14:28:19, Jan 15 2025
```
- Our TF-A started in secure world
- Version 2.9 as expected

**Stage 3: A53 U-Boot SPL**
```
U-Boot SPL 2021.01-gf036fbdc25 (Jan 15 2025 - 15:45:30 +0100)
```
- A53 SPL loaded full U-Boot

**Stage 4: Full U-Boot**
```
U-Boot 2021.01-gf036fbdc25 (Jan 15 2025 - 15:45:30 +0100)
SoC:   AM62X SR1.0 GP
Model: BeagleBoard.org BeaglePlay
DRAM:  2 GiB
```
- Full U-Boot running!
- 2GB RAM detected

**Environment Warning (Expected):**
```
** File not found /uboot.env **
```
This is normal on first boot - we'll create the environment file later.

### Verify Build Dates

**⚠️ Important Check:** Make sure the dates in the boot messages match when you compiled!

If you see old dates (e.g., from March 2024), you're booting from eMMC instead of SD card. Power off, and make sure you're **holding the USR button** during power-on.

## Part 9: Exploring U-Boot Commands

Now that U-Boot is running, let's explore its features.

### Basic Commands

At the `=>` prompt, try:

```
=> help
```

You'll see available commands. Key ones:

- **printenv** - Show environment variables
- **setenv** - Set environment variable
- **saveenv** - Save environment to storage
- **mmc** - MMC/SD card operations
- **fatls** - List FAT filesystem
- **ext4ls** - List ext4 filesystem
- **bdinfo** - Board information
- **reset** - Reboot the board
- **boot** - Boot operating system

Get help on a specific command:

```
=> help mmc
```

### Display Board Information

```
=> bdinfo
```

Output shows:
- Boot parameters address
- RAM start/size
- Stack pointer location
- Relocation addresses

```
=> version
```

Shows U-Boot version and build configuration.

### Explore MMC/SD Card

List MMC devices:

```
=> mmc list
```

Output:

```
mmc@fa10000: 0 (eMMC)
mmc@fa00000: 1
mmc@fa20000: 2 (SD)
```

Switch to SD card:

```
=> mmc dev 2
```

List files on boot partition:

```
=> fatls mmc 2:1
```

You should see:

```
   279552   tiboot3.bin
  1572864   tispl.bin
   921600   u-boot.img

3 file(s), 0 dir(s)
```

These are the files we copied earlier!

### Memory Operations

Display memory (example - this won't show meaningful data yet):

```
=> md 0x82000000 0x10
```

This displays 16 (0x10) words starting at address 0x82000000 in RAM.

## Part 10: U-Boot Environment Persistence

### Understanding U-Boot Environment

The environment stores:
- Boot commands
- Network configuration
- Custom variables
- Boot arguments for Linux

By default, it's stored in RAM (lost on reboot). We configured it to persist in ext4.

### View Current Environment

```
=> printenv
```

You'll see many variables like:

```
bootcmd=run findfdt; run envboot; run init_${boot_fit}; run get_kern_...
bootdelay=2
baudrate=115200
arch=arm
cpu=armv8
board=am62x
soc=am62
...
```

Key variables:
- **bootcmd** - Command executed after bootdelay
- **bootdelay** - Seconds to wait before auto-boot
- **bootargs** - Arguments passed to Linux kernel

### Create Custom Variable

```
=> setenv labtest "BeaglePlay bootloader working!"
=> printenv labtest
```

Should show:

```
labtest=BeaglePlay bootloader working!
```

Now reboot:

```
=> reset
```

After reboot, press SPACE to stop autoboot, then:

```
=> printenv labtest
```

Output:

```
## Error: "labtest" not defined
```

The variable is gone because we didn't save it!

### Save Environment

Set the variable again:

```
=> setenv labtest "BeaglePlay persistent test"
=> saveenv
```

You should see:

```
Saving Environment to EXT4... File System is consistent
update journal finished
1153 bytes written in 15 ms (74.2 KiB/s)
```

This created `/uboot.env` on partition 2!

Now reboot and verify:

```
=> reset
```

(Press SPACE to stop autoboot)

```
=> printenv labtest
```

Output:

```
labtest=BeaglePlay persistent test
```

Success! The environment persists across reboots.

### Inspect Environment File

Boot to Linux later (Lab 4), and you can inspect the environment:

```bash
# From Linux on BeaglePlay
ls -lh /boot/uboot.env
hexdump -C /boot/uboot.env | head
```

You'll see it's a binary file with CRC checksums.

### Reset to Default Environment

If you need to reset everything:

```
=> env default -a
=> saveenv
```

This restores factory defaults.

## Part 11: Adding Custom Commands to U-Boot

Let's enable the `config` command to dump U-Boot's build configuration.

### Check Current Commands

```
=> help | grep config
```

If you don't see `config`, it's not enabled.

### Enable Config Command

Back on your development PC, reconfigure U-Boot:

```bash
cd $HOME/embedded-labs/bootloader/u-boot
make menuconfig O=$HOME/embedded-labs/bootloader/build_uboot/a53/
```

Navigate to:

```
Command line interface →
  Info commands →
    [*] config
```

Press Space to enable (asterisk should appear).

Save and exit menuconfig.

### Rebuild U-Boot

```bash
make -j$(nproc) \
     ATF=$HOME/embedded-labs/bootloader/arm-trusted-firmware/build/k3/lite/release/bl31.bin \
     DM=$HOME/embedded-labs/bootloader/ti-linux-firmware/ti-dm/am62xx/ipc_echo_testb_mcu1_0_release_strip.xer5f \
     O=$HOME/embedded-labs/bootloader/build_uboot/a53/
```

### Update SD Card

```bash
# Re-mount if needed
# Copy only the changed file (u-boot.img)
cp $HOME/embedded-labs/bootloader/build_uboot/a53/u-boot.img /media/$USER/boot/
sync
```

Note: We don't need to update tispl.bin or tiboot3.bin - only u-boot.img changed.

### Test New Command

Reboot BeaglePlay (hold USR button!), stop at U-Boot prompt:

```
=> config
```

You should see lots of output:

```
CONFIG_ARM=y
CONFIG_ARCH_K3=y
CONFIG_SYS_MALLOC_F_LEN=0x8000
CONFIG_SPL_LIBCOMMON_SUPPORT=y
...
```

This shows every CONFIG option U-Boot was built with - very useful for debugging!

### Challenge: Add More Commands

Try enabling these commands in menuconfig:

1. `base` - Print numbers in different bases (hex, dec, oct)
2. `blob` - Manipulate Blob objects
3. `crc32` - Calculate CRC32 checksum

Each time:
1. Enable in menuconfig
2. Rebuild
3. Copy u-boot.img to SD card
4. Test on hardware

## Troubleshooting

*Marvin's note: "I've calculated your chances of success. You won't like them. But here's how to improve the odds anyway."*


### Board Won't Boot from SD Card

**Symptom:** Old boot messages, or no output

**Causes:**
1. Not holding USR button during power-on
2. SD card not fully inserted
3. Bootloader files missing or corrupted

**Solution:**
- Power off completely (unplug USB-C)
- Verify SD card has tiboot3.bin, tispl.bin, u-boot.img
- Insert SD card firmly
- Hold USR button, plug in power, wait 3 seconds, release

### "No MMC card found" Error

**Symptom:** Environment save fails

**Cause:** Partition 2 not formatted correctly

**Solution:**

```bash
sudo mkfs.ext4 -L env -O ^metadata_csum /dev/mmcblk0p2
```

Make sure you used `-O ^metadata_csum` (disables metadata checksums).

### Environment Save Shows "File System Inconsistent"

**Cause:** ext4 partition has errors

**Solution:**

```bash
sudo fsck.ext4 -f /dev/mmcblk0p2
```

### Build Error: "arm-none-eabi-gcc: command not found"

**Cause:** 32-bit toolchain not in PATH

**Solution:**

```bash
export PATH=$HOME/x-tools/arm-gnu-toolchain-12.2.rel1-x86_64-arm-none-eabi/bin:$PATH
```

Add to `~/.bashrc` for persistence.

### Build Error: "bl31.bin: No such file"

**Cause:** TF-A not built or wrong path

**Solution:**

```bash
# Check if TF-A was built
ls -lh $HOME/embedded-labs/bootloader/arm-trusted-firmware/build/k3/lite/release/bl31.bin

# If missing, rebuild TF-A
cd $HOME/embedded-labs/bootloader/arm-trusted-firmware/
make ARCH=aarch64 PLAT=k3 TARGET_BOARD=lite -j$(nproc)
```

### Wrong Dates in Boot Messages

**Symptom:** Boot messages show dates from months ago

**Cause:** Booting from eMMC instead of SD card

**Solution:**
- Completely power off
- Make absolutely sure you're holding USR button during power-on
- Check that tiboot3.bin on SD card has recent timestamp

### Serial Console Shows Garbage

**Cause:** Wrong baud rate

**Solution:**

```bash
# Exit picocom: Ctrl+A, Ctrl+X
# Restart with correct settings
picocom -b 115200 /dev/ttyUSB0
```

## Verification Checklist

*Ford Prefect says: "Always verify your work. It's the difference between a working system and a very expensive paperweight."*


Before moving to the next lab, ensure:

- [ ] 32-bit ARM toolchain (`arm-none-eabi-gcc`) installed and working
- [ ] 64-bit ARM64 toolchain from Lab 1 still working
- [ ] R5 U-Boot SPL built successfully
- [ ] TF-A v2.9 built successfully
- [ ] A53 U-Boot built successfully
- [ ] SD card partitioned correctly (FAT32 boot + ext4 env)
- [ ] All three bootloader files copied to SD card
- [ ] Board boots from SD card (verify dates in boot messages)
- [ ] U-Boot prompt accessible by pressing SPACE
- [ ] Environment variables can be saved and persist across reboots
- [ ] Custom U-Boot command (config) successfully added and tested

## Going Further (Optional Challenges)

### Challenge 1: Boot Time Optimization

**Goal:** Measure and reduce boot time to U-Boot prompt

**Tasks:**
1. Add timing to boot messages (search for CONFIG_BOOTSTAGE)
2. Measure total time from power-on to U-Boot prompt
3. Reduce bootdelay from 2 seconds to 0
4. Investigate SPL size reduction options

**Hints:**
- Use a stopwatch or video recording to time boot
- Check `CONFIG_BOOTDELAY` in menuconfig
- Look for unnecessary drivers in SPL defconfig

### Challenge 2: Secure Boot Exploration

**Goal:** Understand the X.509 certificate in tiboot3.bin

**Tasks:**
1. Extract the certificate from tiboot3.bin
2. Examine it with openssl
3. Research how HS (High Security) devices verify signatures

**Hints:**

```bash
# The certificate is at the beginning of tiboot3.bin
dd if=tiboot3.bin of=cert.der bs=1 count=2048
openssl x509 -inform DER -in cert.der -text -noout
```

### Challenge 3: Multi-Boot Configuration

**Goal:** Create boot menu to choose between SD card and eMMC

**Tasks:**
1. Research U-Boot boot scripts (boot.scr)
2. Create a menu using `bootmenu` command
3. Allow selecting boot device at startup

**Hints:**
- Look for CONFIG_CMD_BOOTMENU
- Check U-Boot documentation: doc/README.bootmenu
- Use `setenv bootmenu_*` variables

### Challenge 4: Network Boot Preparation

**Goal:** Configure U-Boot for TFTP network booting (needed in Lab 4)

**Tasks:**
1. Set up static IP address in U-Boot environment
2. Configure TFTP server IP
3. Test network connectivity with `ping`

**Hints:**

```
setenv ipaddr 192.168.1.100
setenv serverip 192.168.1.1
ping ${serverip}
```

(Won't work yet - we need to configure Ethernet in Lab 4)

## Summary

In this lab, you:

✅ Understood the complex AM62x multi-stage boot architecture  
✅ Built bootloader components for two different CPU architectures (32-bit R5, 64-bit A53)  
✅ Compiled R5 U-Boot SPL with 32-bit ARM toolchain  
✅ Built ARM Trusted Firmware for secure boot services  
✅ Configured and compiled full U-Boot for A53  
✅ Created properly formatted SD card with boot and environment partitions  
✅ Successfully booted BeaglePlay from custom bootloader  
✅ Learned U-Boot commands and environment management  
✅ Added custom commands by reconfiguring U-Boot  

### Key Takeaways

1. **Multi-stage boot is complex** - BeaglePlay requires 5+ components working together
2. **Architecture matters** - Different CPUs need different toolchains
3. **Boot order is critical** - Each stage must correctly hand off to the next
4. **Environment persistence** - Proper filesystem configuration enables saving settings
5. **U-Boot is customizable** - Can add/remove features via menuconfig

### What's Next?

In **Lab 4**, we'll:
- Compile the Linux kernel for BeaglePlay
- Configure kernel for AM62x hardware
- Learn about Device Trees
- Boot kernel over network (TFTP)
- Configure U-Boot for kernel loading

The bootloader is ready - now we need an operating system!

---

**Estimated completion time:** 4-5 hours  
**Difficulty:** ⭐⭐⭐⭐ (Advanced)

**Questions?** Refer to:
- [U-Boot Documentation](https://u-boot.readthedocs.io/)
- [TI AM62x Technical Reference](https://www.ti.com/product/AM625)
- [ARM Trusted Firmware Docs](https://trustedfirmware-a.readthedocs.io/)
