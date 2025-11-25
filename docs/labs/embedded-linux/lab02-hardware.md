# Lab 2: BeaglePlay Hardware Discovery

**Platform**: BeaglePlay (TI AM62x Cortex-A53)  
**Prerequisites**: Lab 1 completed (cross-compilation toolchain ready)  
**Duration**: 2-3 hours (or approximately 42 minutes in improbable circumstances)  
**Difficulty**: ⭐⭐☆☆☆ (2/5)

---

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about hardware discovery:

*"Hardware discovery is the art of asking your embedded board what it is and what it can do, in the hope that it will answer in a language you understand. This is somewhat more successful than asking a Vogon for directions, though both may require substantial interpretation."*

## Objectives

By the end of this lab, you will be able to:

- [ ] Understand BeaglePlay and TI AM62x hardware architecture
- [ ] Set up serial console communication (UART)
- [ ] Access U-Boot bootloader console
- [ ] Identify BeaglePlay expansion interfaces and connectors
- [ ] Control GPIO pins and LEDs from Linux
- [ ] Understand basic Device Tree concepts

---

## Background

### BeaglePlay Hardware Overview

**Board**: BeaglePlay Rev A1  
**SoC**: Texas Instruments AM6254 (part of AM62x family)

**Key Specifications**:
- **Application Processor**: 4x ARM Cortex-A53 @ 1.4 GHz (64-bit)
- **Real-Time MCU**: 1x ARM Cortex-M4F @ 400 MHz
- **Memory**: 2 GB DDR4 RAM
- **Storage**: 16 GB eMMC + microSD slot
- **Wireless**: WiFi 5 (2.4/5 GHz), Bluetooth 5.2 LE, SubGHz (CC1352)
- **Networking**: Gigabit Ethernet (10/100/1000)
- **USB**: 1x Type-C (console + power), 1x Type-A host
- **Video**: HDMI (via mikroBUS or other expansion)

### TI AM62x SoC Architecture

```
┌───────────────────────────────────────────────────────┐
│                   TI AM62x SoC                        │
├───────────────────────────────────────────────────────┤
│                                                       │
│  ┌─────────────────┐      ┌──────────────────┐      │
│  │  Cortex-A53     │      │  Cortex-M4F      │      │
│  │  Quad-core      │◄────►│  Real-Time MCU   │      │
│  │  @ 1.4 GHz      │      │  @ 400 MHz       │      │
│  └─────────────────┘      └──────────────────┘      │
│         ▲                                            │
│         │                                            │
│  ┌──────┴──────────────────────────────────────┐    │
│  │        Memory Subsystem                     │    │
│  │  - DDR4 Controller (2 GB)                   │    │
│  │  - SRAM (256 KB)                            │    │
│  │  - L2 Cache                                 │    │
│  └─────────────────────────────────────────────┘    │
│                                                       │
│  ┌──────────────────────────────────────────────┐   │
│  │         Peripherals                          │   │
│  │  - UART (6x)       - I2C (4x)               │   │
│  │  - SPI (3x)        - GPIO (multiple banks)   │   │
│  │  - USB 2.0 (2x)    - MMC/SD (3x)            │   │
│  │  - Ethernet MAC    - PCIe                    │   │
│  │  - ADC             - PWM/Timer               │   │
│  └──────────────────────────────────────────────┘   │
│                                                       │
└───────────────────────────────────────────────────────┘
```

### Boot Sequence

BeaglePlay uses a multi-stage boot process:

1. **ROM Code** (on-chip): TI Secure Boot ROM
2. **R5 SPL** (tiboot3.bin): 32-bit, runs on Cortex-R5 (inside DM3 subsystem)
3. **TF-A** (bl31.bin): ARM Trusted Firmware-A (secure world)
4. **A53 SPL** (tispl.bin): 64-bit, runs on Cortex-A53
5. **U-Boot** (u-boot.img): Full bootloader on A53
6. **Linux Kernel**: Your custom kernel

---

## Prerequisites Check

```bash
# Verify Lab 1 completion
which aarch64-linux-gcc
# Should show: /home/user/x-tools/aarch64-beagleplay-linux-musl/bin/aarch64-linux-gcc

# Check workspace
ls ~/embedded-linux-labs/
# Should show: lab01-toolchain/
```

---

## Setup

### Workspace Preparation

```bash
# Create lab directory
mkdir -p ~/embedded-linux-labs/lab02-hardware
cd ~/embedded-linux-labs/lab02-hardware

# Set environment
export LAB_DIR=$PWD
export PATH=$HOME/x-tools/aarch64-beagleplay-linux-musl/bin:$PATH
```

### Required Packages

```bash
# Install serial communication tools
sudo apt install -y \
    picocom \
    minicom \
    screen \
    cu

# Install USB tools (to identify serial devices)
sudo apt install -y \
    usbutils \
    lsusb

# Add user to dialout group for serial access
sudo usermod -a -G dialout $USER

# Log out and back in for group change to take effect
```

---

## Part 1: Serial Console Setup

### Step 1.1: Connect BeaglePlay

**Hardware Connection**:

1. **DO NOT power on** BeaglePlay yet
2. Connect **USB-C cable** from BeaglePlay to your PC
   - Use the main USB-C port (not the one labeled "Debug")
   - This provides both power and serial console
3. BeaglePlay will **auto-power on** when USB-C is connected

**LED Indicators**:
- Power LED (red/green): Should light up
- User LEDs (blue): May blink during boot

### Step 1.2: Identify Serial Device

```bash
# Check kernel messages for new USB device
sudo dmesg | tail -30

# Look for lines like:
# [12345.678] usb 1-2: new high-speed USB device
# [12345.890] cdc_acm 1-2:1.0: ttyACM0: USB ACM device
```

**Common device names**:
- `/dev/ttyACM0` - Most common for BeaglePlay USB-C console
- `/dev/ttyUSB0` - If using separate USB-to-UART adapter
- `/dev/ttyS0` - Built-in serial port (rare on modern PCs)

**Verify device**:
```bash
# List ACM devices
ls -l /dev/ttyACM*

# Check device info
udevadm info /dev/ttyACM0 | grep ID_MODEL
# Should show something related to BeaglePlay or CP2105
```

### Step 1.3: Serial Console Parameters

BeaglePlay serial console settings:
- **Baud rate**: 115200
- **Data bits**: 8
- **Parity**: None  
- **Stop bits**: 1
- **Flow control**: None

**Shorthand**: `115200 8N1`

### Step 1.4: Connect with picocom

```bash
# Connect to serial console
picocom -b 115200 /dev/ttyACM0

# Expected output:
# picocom v3.1
# port is        : /dev/ttyACM0
# baudrate is    : 115200
# ...
# Terminal ready
```

**picocom Controls**:
- **Ctrl+A, Ctrl+X**: Exit picocom
- **Ctrl+A, Ctrl+H**: Show help
- **Ctrl+A, Ctrl+P**: Toggle local echo

**Troubleshooting**:
```bash
# Permission denied?
sudo chmod 666 /dev/ttyACM0
# Or better: add user to dialout group (already done above, requires re-login)

# Device busy?
sudo lsof | grep ttyACM0
# Kill other process using the device

# No such device?
# Check different device: /dev/ttyUSB0, /dev/ttyACM1, etc.
```

### Step 1.5: First Boot Messages

With picocom connected, you should see boot messages:

```
U-Boot SPL 2024.01 (Nov 25 2025)
SYSFW ABI: 3.1 (firmware rev 0x0009)
Trying to boot from MMC1

...

U-Boot 2024.01 (Nov 25 2025)
SoC:   AM62X SR1.0
Model: BeagleBoard.org BeaglePlay
DRAM:  2 GiB
Core:  61 devices, 28 uclasses

...

Hit any key to stop autoboot:  3
=>
```

**If you don't see anything**:
1. Power cycle BeaglePlay (unplug/replug USB-C)
2. Try different baud rates: 9600, 38400, 57600
3. Check cable (must support data, not just charging)

---

## Part 2: U-Boot Exploration

### Step 2.1: Interrupt Boot Sequence

When you see "Hit any key to stop autoboot", press **Spacebar** quickly.

You'll get U-Boot prompt:
```
=>
```

### Step 2.2: Basic U-Boot Commands

```bash
# Display U-Boot version and build info
=> version

# List all available commands
=> help

# Get help on specific command
=> help printenv

# Display all environment variables
=> printenv

# Show board information
=> bdinfo

# List memory regions
=> md 0x80000000 10
```

### Step 2.3: Storage Device Information

```bash
# List MMC (SD/eMMC) devices
=> mmc list
# Output:
# mmc@fa10000: 0 (eMMC)
# mmc@fa00000: 1 (SD)
# mmc@fa20000: 2

# Select SD card
=> mmc dev 1

# Show SD card info
=> mmc info
# Shows: Device, Type, Capacity, etc.

# List partitions on SD card
=> mmc part

# Read filesystem (if FAT)
=> fatls mmc 1:1
```

### Step 2.4: Network Information

```bash
# Show network configuration
=> printenv ipaddr
=> printenv serverip
=> printenv ethaddr

# Note: Network may not be configured yet (will configure in later lab)
```

---

## Part 3: Hardware Interfaces

### Step 3.1: Expansion Connectors

BeaglePlay provides multiple expansion options:

#### **mikroBUS Socket**

16-pin socket for [MikroElektronika Click boards](https://www.mikroe.com/click):

| Pin | Function | Pin | Function |
|-----|----------|-----|----------|
| 1   | AN (Analog) | 9  | TX (UART) |
| 2   | RST (Reset) | 10 | RX (UART) |
| 3   | CS (SPI)    | 11 | SCL (I2C) |
| 4   | SCK (SPI)   | 12 | SDA (I2C) |
| 5   | MISO (SPI)  | 13 | +5V |
| 6   | MOSI (SPI)  | 14 | GND |
| 7   | +3.3V       | 15 | GND |
| 8   | GND         | 16 | INT (Interrupt) |

**Compatible modules**: 1000+ Click boards (sensors, displays, wireless, etc.)

#### **Grove Connector**

4-pin connector for [Seeed Studio Grove modules](https://www.seeedstudio.com/category/Grove-c-1003.html):

| Pin | Function |
|-----|----------|
| 1   | SCL (I2C) |
| 2   | SDA (I2C) |
| 3   | VCC (5V or 3.3V) |
| 4   | GND |

**Use case**: Quick prototyping with I2C sensors

#### **QWIIC/STEMMA QT Connector**

4-pin JST SH connector compatible with:
- SparkFun [Qwiic ecosystem](https://www.sparkfun.com/qwiic)
- Adafruit [STEMMA QT ecosystem](https://www.adafruit.com/category/620)

Pinout: VCC (3.3V), GND, SDA, SCL (I2C)

**Advantage**: Daisy-chaining multiple I2C devices without soldering

#### **46-Pin Headers (P8 & P9)**

Similar to other BeagleBone boards, providing:
- GPIO (3.3V logic level - **NOT 5V tolerant!**)
- PWM outputs
- Analog inputs (ADC)
- SPI, I2C, UART interfaces
- Power pins (3.3V, 5V, GND)

**Pinout**: See [official documentation](https://docs.beagleboard.org/latest/boards/beagleplay/ch02.html)

### Step 3.2: On-Board Components

**LEDs**:
- **USR0-USR3**: User-controllable LEDs (blue)
- **Power**: Power indicator (red/green)
- **WiFi/BT**: Wireless activity indicators

**Buttons**:
- **BOOT**: Hold during power-up to force eMMC boot
- **RESET**: Hard reset button

**Wireless**:
- **WiFi**: 2.4/5 GHz (WL1807MOD module)
- **Bluetooth**: 5.2 LE
- **SubGHz**: CC1352P7 (868/915 MHz for LoRa, Thread, etc.)

---

## Part 4: GPIO and LED Control

### Step 4.1: Understanding GPIO

**GPIO** (General Purpose Input/Output) pins can be:
- **Output**: Drive HIGH (3.3V) or LOW (0V)
- **Input**: Read HIGH or LOW state
- **Interrupt**: Trigger on state change

**BeaglePlay USR LEDs**:
- Connected to specific GPIO pins
- Controlled via Linux `sysfs` interface
- Can be triggered by events (heartbeat, mmc activity, etc.)

### Step 4.2: LED Control from U-Boot

U-Boot may not have full GPIO support configured by default, so we'll control LEDs from Linux (next labs). For now, just understand the concept.

**GPIO Calculation**:
- AM62x GPIO is organized in banks
- Each bank has 32 GPIOs (GPIO0-GPIO31)
- Formula: `GPIO number = (bank × 32) + pin`

Example:
- GPIO1_25 = (1 × 32) + 25 = GPIO 57

---

## Part 5: Boot Sources

### Step 5.1: Understanding Boot Order

BeaglePlay boot sequence (ROM code):

1. **Check USR button**:
   - Pressed: Skip to step 3 (eMMC only)
   - Not pressed: Continue

2. **Try microSD card** (mmc1):
   - Look for bootable FAT partition
   - Load `tiboot3.bin`
   - If found: Boot from SD
   - If not found: Continue

3. **Try eMMC** (mmc0):
   - Look for bootable partition
   - Load `tiboot3.bin`
   - If found: Boot from eMMC
   - If not found: Try USB/UART

4. **USB Boot** (DFU mode):
   - Wait for USB connection
   - Allow flashing via USB

### Step 5.2: Forcing Boot Source

**Boot from SD Card** (default if SD inserted):
- Just insert SD card and power on

**Boot from eMMC** (even if SD is inserted):
1. Hold **USR button**
2. Power on or press RESET
3. Release USR button after 2 seconds

**Boot to USB DFU Mode** (for recovery):
- Remove SD card
- Erase eMMC boot partition
- Power on → will enter DFU mode

---

## Part 6: Device Tree Introduction

### Step 6.1: What is Device Tree?

**Device Tree** is a data structure that describes hardware to the kernel:
- **NOT** executable code
- **IS** a hardware description
- Tells kernel: "What devices exist and where are they?"

**Why needed?**
- ARM SoCs have diverse hardware configurations
- Kernel can't auto-detect everything (unlike x86 PCI)
- One kernel binary + different Device Trees = support multiple boards

### Step 6.2: Device Tree Files

**Source**: `.dts` files (human-readable)
```dts
/ {
    model = "BeagleBoard.org BeaglePlay";
    compatible = "beagle,am625-beagleplay", "ti,am625";
    
    leds {
        compatible = "gpio-leds";
        led-0 {
            label = "beagleplay:green:usr0";
            gpios = <&main_gpio0 3 GPIO_ACTIVE_HIGH>;
            linux,default-trigger = "heartbeat";
        };
    };
};
```

**Compiled**: `.dtb` files (binary blob)
- Compiled with `dtc` (Device Tree Compiler)
- Loaded by bootloader alongside kernel
- Format: Flattened Device Tree (FDT)

### Step 6.3: BeaglePlay Device Tree

**Main DTS**: `k3-am625-beagleplay.dts`

Describes:
- AM62x SoC peripherals
- BeaglePlay-specific hardware
- GPIO assignments
- I2C/SPI devices
- WiFi/Bluetooth modules
- Ethernet PHY
- mikroBUS resources

**Location in kernel source**:
```
arch/arm64/boot/dts/ti/k3-am625-beagleplay.dts
```

---

## Verification

### Test Your Work

```bash
# Create verification log
cat > verify-hardware.txt << 'EOF'
BeaglePlay Hardware Discovery - Verification Log
=================================================

1. Serial Console
   [PASS/FAIL] Device found: /dev/ttyACM0
   [PASS/FAIL] picocom connects successfully
   [PASS/FAIL] Boot messages visible

2. U-Boot Access
   [PASS/FAIL] Can interrupt boot sequence
   [PASS/FAIL] U-Boot prompt (=>) appears
   [PASS/FAIL] Commands execute (help, version)

3. Storage Devices
   [PASS/FAIL] eMMC detected (mmc list)
   [PASS/FAIL] SD card detected (if inserted)

4. Hardware Understanding
   [PASS/FAIL] Understand mikroBUS pinout
   [PASS/FAIL] Understand boot sequence
   [PASS/FAIL] Understand Device Tree concept

Notes:
EOF

# Fill in PASS/FAIL and notes
nano verify-hardware.txt
```

### Checklist

- [ ] Serial console configured and working
- [ ] Can access U-Boot prompt
- [ ] Understand BeaglePlay hardware architecture
- [ ] Know the expansion connector options
- [ ] Understand boot source priority
- [ ] Basic Device Tree knowledge acquired

---

## Going Further (Optional)

### Challenge 1: U-Boot Scripting

Create a U-Boot script that:
1. Prints custom boot message
2. Tests SD card presence
3. Sets up network variables
4. Saves configuration

### Challenge 2: Serial Console Alternatives

Try other serial terminal programs:
- `minicom`: More features, more complex
- `screen`: Ubiquitous, multi-window support
- `cu`: Simple, minimal

Compare pros/cons of each.

### Challenge 3: USB Console Deep Dive

Research:
- How USB CDC ACM class works
- BeaglePlay USB console chip (CP2105)
- Writing Linux kernel driver for USB serial

---

## Common Issues

### Issue 1: No Serial Device Appears

**Symptoms**:
- No /dev/ttyACM0 or /dev/ttyUSB0
- `ls /dev/tty*` doesn't show new devices

**Solutions**:
```bash
# Check USB connection
lsusb
# Look for BeaglePlay or CP210x device

# Check dmesg for errors
dmesg | grep -i usb
dmesg | grep -i cdc

# Load driver manually (if needed)
sudo modprobe cdc_acm

# Try different USB port (avoid USB 3.0 hubs sometimes)
```

### Issue 2: Permission Denied on /dev/ttyACM0

**Symptoms**:
- `picocom: Permission denied`

**Solutions**:
```bash
# Temporary fix (until reboot)
sudo chmod 666 /dev/ttyACM0

# Permanent fix (requires logout/login)
sudo usermod -a -G dialout $USER
# Then logout and back in

# Verify group membership
groups | grep dialout
```

### Issue 3: Garbled Characters on Console

**Symptoms**:
- Random characters instead of readable text
- Symbols and garbage

**Causes**:
- Wrong baud rate
- Flow control enabled

**Solutions**:
```bash
# Try different baud rates
picocom -b 9600 /dev/ttyACM0
picocom -b 38400 /dev/ttyACM0
picocom -b 57600 /dev/ttyACM0
picocom -b 115200 /dev/ttyACM0  # Correct for BeaglePlay

# Disable flow control explicitly
picocom -b 115200 -f n /dev/ttyACM0
```

---

## Key Takeaways

1. **Serial console** is essential for embedded development - first interface to the board
2. **USB-C provides both power and console** - convenient for BeaglePlay
3. **U-Boot** is the bootloader - provides early hardware initialization and kernel loading
4. **Boot sequence** is multi-stage: ROM → R5 SPL → TF-A → A53 SPL → U-Boot → Kernel
5. **Device Tree** describes hardware to kernel - separation of code and hardware description
6. **Expansion connectors** (mikroBUS, Grove, Qwiic) make prototyping easier
7. **GPIO** provides basic digital I/O - foundation for hardware interaction

---

## References

- **BeaglePlay Documentation**: https://docs.beagleboard.org/latest/boards/beagleplay/
- **TI AM62x TRM**: https://www.ti.com/lit/pdf/spruiv7
- **Device Tree Specification**: https://devicetree-specification.readthedocs.io/
- **U-Boot Documentation**: https://docs.u-boot.org/
- **mikroBUS Standard**: https://www.mikroe.com/mikrobus

---

## Next Steps

✅ **Completed**: Lab 2 - BeaglePlay Hardware Discovery  
⏭️ **Up Next**: Lab 3 - U-Boot Bootloader

**What you'll learn next**:
- Compile U-Boot from source
- Configure bootloader for network boot
- Set up TFTP server
- Load kernel over network
- Automate boot process

**Recommended preparation**:
- Review U-Boot commands learned here
- Set up Ethernet connection to BeaglePlay
- Read about TFTP protocol

---

*Lab created: November 25, 2025*  
*Last updated: November 25, 2025*  
*Tested on: Ubuntu 24.04 LTS, BeaglePlay Rev A1*  
*Hardware: BeaglePlay (TI AM62x Cortex-A53)*
