# Lab 6: Hardware Device Access and Driver Development

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about hardware discovery:

*"Hardware discovery is the art of asking your embedded board what it is and what it can do, in the hope that it will answer in a language you understand. This is somewhat more successful than asking a Vogon for directions, though both may require substantial interpretation."*

## Objectives

Master hardware device access patterns on embedded Linux systems:

- Explore Linux device abstractions (`/dev`, `/sys`)
- Control GPIOs using the legacy sysfs interface
- Manage LEDs through the LED subsystem
- Enable and probe I2C buses
- Compile and install in-tree kernel modules
- Develop and deploy out-of-tree kernel modules
- Declare devices in the Device Tree
- Work with USB devices and the Linux device driver model

## Prerequisites

- Completed Lab 5 (Root Filesystem)
- Working NFS root filesystem
- Serial console access to BeaglePlay
- Basic understanding of Linux kernel modules

## Lab Duration

Approximately 4-5 hours

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      User Space                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ i2cdetect│  │  lsusb   │  │  lsmod   │  │ modprobe │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘  │
├───────┼─────────────┼─────────────┼─────────────┼──────────┤
│       │    Kernel Space            │             │          │
│  ┌────▼─────┐  ┌───▼──────┐  ┌───▼──────┐  ┌───▼──────┐ │
│  │  sysfs   │  │ USB Core │  │  Module  │  │ I2C Core │ │
│  │/sys/class│  │ /sys/bus │  │ Loader   │  │/dev/i2c-*│ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘ │
│  ┌────▼──────────────▼─────────────▼──────────────▼─────┐ │
│  │            Device Driver Subsystems                   │ │
│  │  GPIO │ LED │ I2C │ USB │ Sound │ Input │ MMC       │ │
│  └────┬──────┬──────┬─────┬───────┬────────┬────────┬──┘ │
├───────┼──────┼──────┼─────┼───────┼────────┼────────┼────┤
│  ┌────▼──────▼──────▼─────▼───────▼────────▼────────▼──┐ │
│  │           Hardware (BeaglePlay AM62x)                │ │
│  │  GPIOs │ LEDs │ I2C │ USB │ Pins │ MMC │ Audio      │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Environment Setup

### Working Directory

```bash
# Create dedicated hardware lab directory
cd $HOME/embedded-linux-beagleplay-labs
mkdir -p hardware/nunchuk-driver
cd hardware
```

### Verify NFS Root Filesystem

We'll continue using the NFS root filesystem from Lab 5:

```bash
# Verify NFS export
cat /etc/exports | grep tinysystem

# Expected output:
# /home/<user>/embedded-linux-beagleplay-labs/tinysystem/nfsroot *(rw,no_root_squash,no_subtree_check)

# Restart NFS server if needed
sudo systemctl restart nfs-kernel-server
```

### Boot the System

Power on your BeaglePlay and verify the NFS boot:

```bash
# On BeaglePlay serial console, verify the mount
mount | grep nfs

# Expected output showing NFS root:
# 192.168.0.1:/home/<user>/embedded-linux-beagleplay-labs/tinysystem/nfsroot on / type nfs ...
```

## Section 1: Exploring the Linux Device Model

### Understanding /dev

The `/dev` directory contains device files - special files that represent hardware devices.

**On the BeaglePlay:**

```bash
# List all device files
ls -l /dev/

# Terminal devices (text input/output)
ls -l /dev/tty*

# Console device (kernel command line console= parameter)
ls -l /dev/console

# Serial ports
ls -l /dev/ttyS*

# MMC devices and partitions
ls -l /dev/mmcblk*
```

**Device File Anatomy:**

```bash
# Example: character device
crw-rw---- 1 root tty 5, 1 Jan  1 00:00 /dev/console
# c = character device
# 5 = major number (device driver)
# 1 = minor number (specific device instance)

# Example: block device
brw-rw---- 1 root disk 179, 0 Jan  1 00:00 /dev/mmcblk0
# b = block device
# 179 = major number (MMC/SD driver)
# 0 = minor number (first MMC device)
```

**Challenge:** Find the device file for the serial console you're using.

<details>
<summary>Solution</summary>

```bash
# Check kernel boot messages for console device
dmesg | grep console

# Usually /dev/ttyS2 on BeaglePlay
ls -l /dev/ttyS2
```

</details>

### Exploring sysfs (/sys)

Sysfs provides a structured view of the kernel's device model.

**Device Classification:**

```bash
# Explore devices by class (subsystem)
ls /sys/class/

# Network devices
ls -l /sys/class/net/

# Examine network interface properties
cd /sys/class/net/eth0/  # or your network interface name

# Link speed (Mbps)
cat speed

# MAC address
cat address

# RX statistics
cat statistics/rx_bytes
cat statistics/rx_packets

# TX statistics
cat statistics/tx_bytes
cat statistics/tx_packets
```

**Bus Exploration:**

```bash
# All buses in the system
ls /sys/bus/

# MMC bus devices
ls /sys/bus/mmc/devices/

# Explore first MMC device
cd /sys/bus/mmc/devices/mmc0:0001/

# Device serial number
cat serial

# Product name
cat name

# Manufacturing date
cat date

# Preferred erase size (for partition alignment)
cat preferred_erase_size
```

**Platform Devices:**

```bash
# Platform bus (SoC-integrated devices)
ls /sys/bus/platform/devices/

# I2C controllers
ls /sys/bus/platform/devices/ | grep i2c
```

**Verification Checklist:**

- [ ] Successfully explored `/dev` and identified device types
- [ ] Found serial console device file
- [ ] Examined network interface properties in `/sys/class/net/`
- [ ] Explored MMC device information
- [ ] Located platform devices for I2C controllers

## Section 2: GPIO Control with Legacy Sysfs

### Enable GPIO Sysfs Interface

The legacy GPIO sysfs interface requires `CONFIG_GPIO_SYSFS`.

**Kernel Configuration:**

```bash
cd $HOME/embedded-linux-beagleplay-labs/kernel/linux

# Enable legacy GPIO interface
make ARCH=arm64 CROSS_COMPILE=aarch64-beagleplay-linux-musl- menuconfig

# Navigate to:
# General setup
#   --> Configure standard kernel features (expert users)
#       [*] Configure standard kernel features (expert users)  # Enable CONFIG_EXPERT

# Device Drivers
#   --> GPIO Support
#       [*] /sys/class/gpio/... (sysfs interface) (DEPRECATED)  # Enable CONFIG_GPIO_SYSFS

# Also enable Debugfs:
# Kernel hacking
#   --> Generic Kernel Debugging Instruments
#       [*] Debug Filesystem
#       [*] Debugfs default access (Access normal)

# Save and exit
```

**Compile and Install:**

```bash
# Build kernel image
make ARCH=arm64 CROSS_COMPILE=aarch64-beagleplay-linux-musl- Image.gz -j$(nproc)

# Copy to TFTP directory
cp arch/arm64/boot/Image.gz /srv/tftp/

# Reboot BeaglePlay and verify new kernel
```

### Mount Debugfs

```bash
# On BeaglePlay
mount -t debugfs debugfs /sys/kernel/debug

# View GPIO information
cat /sys/kernel/debug/gpio
```

**Expected Output:**

```
gpiochip0: GPIOs 0-87, parent: platform/600000.gpio, 600000.gpio:
 gpio-42  (                    |reset               ) out lo ACTIVE LOW
 gpio-50  (                    |cd                  ) in  hi ACTIVE LOW

gpiochip1: GPIOs 88-175, parent: platform/601000.gpio, 601000.gpio:

gpiochip2: GPIOs 512-639, parent: platform/4201000.gpio, 4201000.gpio:

gpiochip3: GPIOs 640-727, parent: platform/42110000.gpio, 42110000.gpio:
```

### BeaglePlay mikroBUS GPIO Selection

The BeaglePlay mikroBUS connector provides several GPIO pins.

**MikroBUS Pinout (Connector J5):**

```
     ┌─────────────┐
PWM  │ 1         2 │ AN
INT  │ 3         4 │ RST
CS   │ 5         6 │ SCK
MOSI │ 7         8 │ MISO
3.3V │ 9        10 │ GND
5V   │11        12 │ GND
SDA  │13        14 │ SCL
     └─────────────┘
```

**Pin Mapping to SoC:**

According to BeaglePlay schematics:
- **INT pin** → GPIO1_9 (SoC pin)
- **PWM pin** → GPIO0_36 (SoC pin)
- **AN pin** → GPIO0_35 (SoC pin)  
- **RST pin** → GPIO1_14 (SoC pin)

**Find INT Pin Linux GPIO Number:**

```bash
# Check debugfs GPIO listing
cat /sys/kernel/debug/gpio | grep MIKROBUS

# Look for GPIO1_9, also called gpio-640
# Output should show:
# gpio-640 (MIKROBUS_GPIO1_9  |                    ) in  hi
```

The INT pin is **GPIO 640** (gpio-640 in Linux).

### Control GPIO via Sysfs

**Test Setup - Hardware Wiring:**

Use a male-to-male jumper wire:
1. Connect one end to **INT** pin (pin 3) on mikroBUS connector
2. Connect other end to **GND** pin (pin 10) on mikroBUS connector

**Export GPIO:**

```bash
# Navigate to GPIO sysfs interface
cd /sys/class/gpio

# Export GPIO 640 (INT pin)
echo 640 > export

# Verify new GPIO directory created
ls -l gpio640/
```

**Configure as Input:**

```bash
# Set direction to input
echo in > gpio640/direction

# Read current value (should be 0, connected to GND)
cat gpio640/value
# Output: 0
```

**Test with 3.3V:**

```bash
# Disconnect the wire from GND
# Connect it to 3.3V pin (pin 9) instead

# Read value again (should be 1)
cat gpio640/value
# Output: 1
```

**Configure as Output:**

```bash
# Set direction to output
echo out > gpio640/direction

# Set high (3.3V)
echo 1 > gpio640/value

# You can measure 3.3V on the INT pin with a multimeter

# Set low (0V)
echo 0 > gpio640/value

# Disconnect wire from 3.3V before continuing
```

**Check GPIO Status:**

```bash
# View GPIO in debugfs (shows usage and direction)
cat /sys/kernel/debug/gpio | grep 640

# Expected output:
# gpio-640 (MIKROBUS_GPIO1_9  |sysfs              ) out lo
```

**Unexport GPIO:**

```bash
# Release the GPIO when done
cd /sys/class/gpio
echo 640 > unexport

# Verify directory removed
ls gpio640/
# Should show: No such file or directory
```

**Verification Checklist:**

- [ ] Kernel compiled with `CONFIG_GPIO_SYSFS` enabled
- [ ] Debugfs mounted and GPIO information visible
- [ ] GPIO 640 (INT pin) successfully exported
- [ ] Read LOW value (0) when connected to GND
- [ ] Read HIGH value (1) when connected to 3.3V
- [ ] Successfully configured GPIO as output
- [ ] Unexported GPIO after testing

## Section 3: LED Control via Sysfs

### Kernel Configuration

```bash
cd $HOME/embedded-linux-beagleplay-labs/kernel/linux

make ARCH=arm64 CROSS_COMPILE=aarch64-beagleplay-linux-musl- menuconfig

# Enable:
# Device Drivers
#   --> LED Support
#       <*> LED Class Support                      # CONFIG_LEDS_CLASS
#       <*> LED Support for GPIO connected LEDs    # CONFIG_LEDS_GPIO
#       <*> LED Trigger support
#           <*> LED Timer Trigger                  # CONFIG_LEDS_TRIGGER_TIMER
#           <*> LED Heartbeat Trigger              # CONFIG_LEDS_TRIGGER_HEARTBEAT

# Save and rebuild kernel
make ARCH=arm64 CROSS_COMPILE=aarch64-beagleplay-linux-musl- Image.gz -j$(nproc)
cp arch/arm64/boot/Image.gz /srv/tftp/
```

Reboot the BeaglePlay with the updated kernel.

### Explore LED Devices

```bash
# On BeaglePlay
cd /sys/class/leds
ls -l

# You should see several LEDs, including:
# beagleplay:green:usr0
# beagleplay:green:usr1
# beagleplay:green:usr2
# beagleplay:green:usr3
# beagleplay:green:usr4
```

### Control LED Manually

```bash
# Enter LED directory (choose any user LED)
cd /sys/class/leds/beagleplay:green:usr0

# Check current trigger
cat trigger
# Output shows available triggers and current (in brackets):
# none usb-gadget usb-host rc-feedback kbd-scrolllock ...
# [heartbeat] timer ... default-on

# Disable all triggers
echo none > trigger

# Manual control - turn ON
echo 1 > brightness

# Wait a moment, then turn OFF
echo 0 > brightness
```

### Use Timer Trigger

```bash
# Enable timer trigger
echo timer > trigger

# Set ON time (milliseconds)
echo 100 > delay_on

# Set OFF time (milliseconds)
echo 900 > delay_off

# LED should now blink: 100ms ON, 900ms OFF
```

**Experiment with Different Patterns:**

```bash
# Fast blink
echo 50 > delay_on
echo 50 > delay_off

# Slow pulse
echo 500 > delay_on
echo 1500 > delay_off

# Short flash
echo 20 > delay_on
echo 2000 > delay_off
```

### Restore Heartbeat

```bash
# Return to heartbeat trigger
echo heartbeat > trigger

# LED will pulse with a heartbeat pattern
```

**Verification Checklist:**

- [ ] LED class and GPIO LED support compiled into kernel
- [ ] LEDs visible in `/sys/class/leds/`
- [ ] Successfully controlled LED brightness manually
- [ ] Timer trigger functional with custom delays
- [ ] Heartbeat trigger operational

## Section 4: I2C Bus Management

### List I2C Buses

```bash
# On BeaglePlay
i2cdetect -l

# Expected output:
# i2c-0   i2c       OMAP I2C adapter              I2C adapter
# i2c-1   i2c       OMAP I2C adapter              I2C adapter
# i2c-2   i2c       OMAP I2C adapter              I2C adapter
# i2c-3   i2c       OMAP I2C adapter              I2C adapter
# i2c-5   i2c       OMAP I2C adapter              I2C adapter
```

### Map I2C Linux Numbers to Hardware

```bash
# Check I2C controller base addresses
ls -l /sys/bus/i2c/devices/i2c-*

# Output:
# ... -> .../20000000.i2c/i2c-0    # I2C0 controller
# ... -> .../20010000.i2c/i2c-1    # I2C1 controller
# ... -> .../20020000.i2c/i2c-2    # I2C2 controller
# ... -> .../20030000.i2c/i2c-3    # I2C3 controller
# ... -> .../4900000.i2c/i2c-5     # MCU_I2C0 controller
```

**AM62x I2C Controller Addresses (from TRM):**

| Linux Name | Hardware Name | Base Address | BeaglePlay Connector |
|------------|---------------|--------------|---------------------|
| i2c-0      | I2C0          | 0x2000_0000  | Internal only       |
| i2c-1      | I2C1          | 0x2001_0000  | Grove connector     |
| i2c-2      | I2C2          | 0x2002_0000  | Qwiic connector     |
| i2c-3      | I2C3          | 0x2003_0000  | mikroBUS connector  |
| i2c-5      | MCU_I2C0      | 0x0490_0000  | Internal only       |

We'll use **i2c-3** (mikroBUS connector) for the Nunchuk.

### Probe I2C Buses

```bash
# Probe internal I2C bus (i2c-0)
i2cdetect -r 0

# WARNING will appear - this is normal
# Output shows detected devices:
#      0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
# 00:          -- -- -- -- -- -- -- -- -- -- -- -- --
# 10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
# 20: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
# 30: UU -- -- -- -- -- -- -- -- -- -- -- -- -- -- --    # 0x30: kernel driver active
# 40: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
# 50: 50 -- -- -- -- -- -- -- -- -- -- -- -- -- -- --    # 0x50: EEPROM
# 60: -- -- -- -- -- -- -- -- 68 -- -- -- -- -- -- --    # 0x68: RTC or sensor
# 70: -- -- -- -- -- -- -- --

# Probe mikroBUS I2C bus (i2c-3) - should be empty
i2cdetect -r 3
# All -- (no devices detected yet)
```

**UU vs Address:**
- `UU`: Device detected AND bound to a kernel driver
- `50`, `68`: Device detected but no driver bound

**Verification Checklist:**

- [ ] All I2C buses listed with `i2cdetect -l`
- [ ] Mapped Linux I2C numbers to hardware controllers
- [ ] Successfully probed i2c-0 and observed internal devices
- [ ] Probed i2c-3 (mikroBUS) and confirmed no devices yet

## Section 5: USB Device Detection

### Check USB Subsystem

```bash
# On BeaglePlay (before plugging USB audio)
lsusb

# Expected output (USB host controller only):
# Bus 001 Device 001: ID 1d6b:0002

# View USB devices in sysfs
ls -l /sys/bus/usb/devices/
```

### Plug USB Audio Headset

Connect the USB audio headset to BeaglePlay's USB host port.

**Monitor Kernel Messages:**

```bash
# Watch kernel log in real-time
dmesg -w

# You should see messages like:
# usb 1-1: new full-speed USB device number 2 using xhci-hcd
# usb 1-1: New USB device found, idVendor=1b3f, idProduct=2008
# usb 1-1: Product: USB Audio Device
# usb 1-1: Manufacturer: GeneralPlus
```

### Explore USB Device in Sysfs

```bash
# List USB devices again
lsusb
# Bus 001 Device 001: ID 1d6b:0002
# Bus 001 Device 002: ID 1b3f:2008    # <-- New device!

# Navigate to device sysfs directory
# Device topology: Bus 1, Port 1
cd /sys/bus/usb/devices/1-1

# Examine device properties
cat idVendor
# 1b3f

cat idProduct
# 2008

cat manufacturer
# GeneralPlus

cat product
# USB Audio Device

cat speed
# 12 (Mbps - full speed USB)
```

**The Guide notes:** The USB device is detected, but no audio driver is loaded yet (we'll fix this in the next section).

**Verification Checklist:**

- [ ] USB host controller visible with `lsusb` before plugging device
- [ ] USB audio device detected after plugging
- [ ] Kernel messages show device enumeration
- [ ] Device properties readable in `/sys/bus/usb/devices/1-1/`

## Section 6: In-Tree Kernel Modules

### Configure USB Audio as Module

```bash
cd $HOME/embedded-linux-beagleplay-labs/kernel/linux

make ARCH=arm64 CROSS_COMPILE=aarch64-beagleplay-linux-musl- menuconfig

# Navigate to:
# Device Drivers
#   --> Sound card support
#       <*> Advanced Linux Sound Architecture (ALSA)
#           <M> USB sound devices   # <-- Change from <*> to <M>
#               <M> USB Audio/MIDI driver    # CONFIG_SND_USB_AUDIO

# Save and exit
```

### Compile Kernel and Modules

```bash
# Build kernel image (version will change to "dirty")
make ARCH=arm64 CROSS_COMPILE=aarch64-beagleplay-linux-musl- Image.gz -j$(nproc)

# Build all modules
make ARCH=arm64 CROSS_COMPILE=aarch64-beagleplay-linux-musl- modules -j$(nproc)
```

### Install Modules to NFS Root

```bash
# Install modules
make ARCH=arm64 CROSS_COMPILE=aarch64-beagleplay-linux-musl- \
    INSTALL_MOD_PATH=$HOME/embedded-linux-beagleplay-labs/tinysystem/nfsroot \
    modules_install

# Verify installation
ls -l $HOME/embedded-linux-beagleplay-labs/tinysystem/nfsroot/lib/modules/

# You should see a directory like: 6.6.x-dirty/
```

### Update Kernel and Reboot

```bash
# Copy new kernel to TFTP directory
cp arch/arm64/boot/Image.gz /srv/tftp/

# Reboot BeaglePlay
# The kernel version now matches the module directory: 6.6.x-dirty
```

### Load USB Audio Module

```bash
# On BeaglePlay, with USB audio headset plugged in

# Load the module
modprobe snd-usb-audio

# Check loaded modules
lsmod | grep snd

# Expected output showing dependencies:
# snd_usb_audio         245760  0
# snd_usbmidi_lib        36864  1 snd_usb_audio
# snd_rawmidi            36864  1 snd_usbmidi_lib
# snd_seq_device         16384  1 snd_rawmidi
# snd_hwdep              16384  1 snd_usb_audio
# snd_pcm               114688  1 snd_usb_audio
# snd_timer              32768  1 snd_pcm
# snd                    73728  7 snd_usb_audio,snd_hwdep,snd_timer,...
```

### Verify Audio Subsystem

```bash
# Check ALSA sound cards
cat /proc/asound/cards
# 0 [Device         ]: USB-Audio - USB Audio Device
#                      GeneralPlus USB Audio Device at usb-xhci-hcd...

# Check audio device files
ls -l /dev/snd/
# Should show: controlC0  pcmC0D0c  pcmC0D0p  timer
```

### Check USB Driver Binding

```bash
# List USB audio driver
ls -l /sys/bus/usb/drivers/snd-usb-audio/

# Should show symbolic link to device 1-1
```

### Auto-Load Module at Boot

Add module loading to startup scripts:

```bash
# On your workstation
cd $HOME/embedded-linux-beagleplay-labs/tinysystem/nfsroot/etc/init.d

# Edit rcS
vi rcS

# Add before the "Starting system..." message:
# Load kernel modules
modprobe snd-usb-audio
```

Reboot BeaglePlay and verify the module loads automatically:

```bash
# After reboot
lsmod | grep snd

# Should show snd_usb_audio and dependencies loaded
```

**Verification Checklist:**

- [ ] USB audio driver configured as module (`CONFIG_SND_USB_AUDIO=m`)
- [ ] Kernel and modules compiled successfully
- [ ] Modules installed to NFS root filesystem
- [ ] Module loads successfully with `modprobe snd-usb-audio`
- [ ] ALSA sound card detected in `/proc/asound/cards`
- [ ] Device files created in `/dev/snd/`
- [ ] USB driver binding visible in sysfs
- [ ] Module auto-loads at boot from startup script

## Section 7: Out-of-Tree Kernel Module - Nunchuk Driver

### Hardware Setup - Nunchuk Wiring

The Nintendo Wii Nunchuk uses I2C communication.

**Nunchuk Pinout:**

```
┌─────────────────┐
│   (UEXT front)  │
│                 │
│  ① ② ③ ④ ⑤ ⑥  │
└─────────────────┘

Pin 1: +3.3V (PWR)
Pin 2: GND
Pin 3: SCL (I2C clock)
Pin 4: SDA (I2C data)
Pin 5: Not connected
Pin 6: Not connected
```

**Connect to BeaglePlay mikroBUS:**

Using male-to-female jumper wires:

| Nunchuk Pin | BeaglePlay mikroBUS Pin |
|-------------|------------------------|
| Pin 1 (PWR) | Pin 9 (3.3V)          |
| Pin 2 (GND) | Pin 10 (GND)          |
| Pin 3 (SCL) | Pin 14 (SCL)          |
| Pin 4 (SDA) | Pin 13 (SDA)          |

### Detect Nunchuk on I2C Bus

```bash
# On BeaglePlay, probe I2C3 bus
i2cdetect -r 3

# Expected output:
#      0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
# 00:          -- -- -- -- -- -- -- -- -- -- -- -- --
# 10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
# 20: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
# 30: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
# 40: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
# 50: -- -- 52 -- -- -- -- -- -- -- -- -- -- -- -- --    # <-- Nunchuk at 0x52!
# 60: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
# 70: -- -- -- -- -- -- -- --
```

The Nunchuk is detected at I2C address **0x52**.

### Obtain Nunchuk Driver Source

```bash
# On your workstation
cd $HOME/embedded-linux-beagleplay-labs/hardware

# Download or create nunchuk.c driver
# For this lab, we'll create a simplified version
```

**Create nunchuk.c:**

```c
// nunchuk.c - I2C driver for Nintendo Wii Nunchuk
#include <linux/module.h>
#include <linux/i2c.h>
#include <linux/input.h>
#include <linux/input-polldev.h>
#include <linux/delay.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Your Name");
MODULE_DESCRIPTION("Nintendo Wii Nunchuk I2C driver");

struct nunchuk_dev {
    struct i2c_client *client;
    struct input_polled_dev *polled_input;
};

static void nunchuk_poll(struct input_polled_dev *polled_input)
{
    struct nunchuk_dev *nunchuk = polled_input->private;
    struct i2c_client *client = nunchuk->client;
    u8 data[6];
    int ret;
    int z, c;

    // Request data from Nunchuk
    ret = i2c_master_send(client, (u8[]){0x00}, 1);
    if (ret < 0) {
        dev_err(&client->dev, "Failed to request data\n");
        return;
    }

    msleep(10);

    // Read 6 bytes of data
    ret = i2c_master_recv(client, data, 6);
    if (ret != 6) {
        dev_err(&client->dev, "Failed to read data\n");
        return;
    }

    // Parse button states (inverted logic)
    z = !(data[5] & BIT(0));
    c = !(data[5] & BIT(1));

    // Report button events
    input_report_key(polled_input->input, BTN_Z, z);
    input_report_key(polled_input->input, BTN_C, c);

    // Report joystick position
    input_report_abs(polled_input->input, ABS_X, data[0]);
    input_report_abs(polled_input->input, ABS_Y, data[1]);

    input_sync(polled_input->input);
}

static int nunchuk_probe(struct i2c_client *client,
                         const struct i2c_device_id *id)
{
    struct nunchuk_dev *nunchuk;
    struct input_polled_dev *polled_input;
    struct input_dev *input;
    int ret;

    dev_info(&client->dev, "Nunchuk probe started\n");

    // Initialize Nunchuk
    ret = i2c_master_send(client, (u8[]){0xf0, 0x55}, 2);
    if (ret < 0) {
        dev_err(&client->dev, "Failed to send init cmd 1\n");
        return ret;
    }

    udelay(1000);

    ret = i2c_master_send(client, (u8[]){0xfb, 0x00}, 2);
    if (ret < 0) {
        dev_err(&client->dev, "Failed to send init cmd 2\n");
        return ret;
    }

    // Allocate device structure
    nunchuk = devm_kzalloc(&client->dev, sizeof(*nunchuk), GFP_KERNEL);
    if (!nunchuk)
        return -ENOMEM;

    nunchuk->client = client;

    // Allocate polled input device
    polled_input = input_allocate_polled_device();
    if (!polled_input) {
        dev_err(&client->dev, "Failed to allocate polled input\n");
        return -ENOMEM;
    }

    nunchuk->polled_input = polled_input;
    polled_input->private = nunchuk;
    polled_input->poll = nunchuk_poll;
    polled_input->poll_interval = 50; // 50ms polling

    input = polled_input->input;
    input->name = "Wii Nunchuk";
    input->id.bustype = BUS_I2C;

    // Setup input capabilities
    set_bit(EV_KEY, input->evbit);
    set_bit(BTN_Z, input->keybit);
    set_bit(BTN_C, input->keybit);

    set_bit(EV_ABS, input->evbit);
    set_bit(ABS_X, input->absbit);
    set_bit(ABS_Y, input->absbit);

    input_set_abs_params(input, ABS_X, 30, 220, 4, 8);
    input_set_abs_params(input, ABS_Y, 40, 200, 4, 8);

    // Register input device
    ret = input_register_polled_device(polled_input);
    if (ret) {
        dev_err(&client->dev, "Failed to register input device\n");
        input_free_polled_device(polled_input);
        return ret;
    }

    i2c_set_clientdata(client, nunchuk);

    dev_info(&client->dev, "Nunchuk device probed successfully\n");
    return 0;
}

static int nunchuk_remove(struct i2c_client *client)
{
    struct nunchuk_dev *nunchuk = i2c_get_clientdata(client);

    input_unregister_polled_device(nunchuk->polled_input);
    input_free_polled_device(nunchuk->polled_input);

    dev_info(&client->dev, "Nunchuk device removed\n");
    return 0;
}

static const struct i2c_device_id nunchuk_id[] = {
    { "nunchuk", 0 },
    { }
};
MODULE_DEVICE_TABLE(i2c, nunchuk_id);

static const struct of_device_id nunchuk_dt_ids[] = {
    { .compatible = "nintendo,nunchuk" },
    { }
};
MODULE_DEVICE_TABLE(of, nunchuk_dt_ids);

static struct i2c_driver nunchuk_driver = {
    .driver = {
        .name = "nunchuk",
        .of_match_table = nunchuk_dt_ids,
    },
    .probe = nunchuk_probe,
    .remove = nunchuk_remove,
    .id_table = nunchuk_id,
};
module_i2c_driver(nunchuk_driver);
```

**Create Makefile:**

```makefile
obj-m := nunchuk.o

all:
	make -C $(KERNEL_DIR) M=$(PWD) modules

clean:
	make -C $(KERNEL_DIR) M=$(PWD) clean

install:
	make -C $(KERNEL_DIR) M=$(PWD) INSTALL_MOD_PATH=$(INSTALL_MOD_PATH) modules_install
```

### Compile Out-of-Tree Module

```bash
# Set environment variables
export KERNEL_DIR=$HOME/embedded-linux-beagleplay-labs/kernel/linux
export ARCH=arm64
export CROSS_COMPILE=aarch64-beagleplay-linux-musl-

# Compile module
cd $HOME/embedded-linux-beagleplay-labs/hardware
make

# Verify nunchuk.ko was created
ls -l nunchuk.ko
```

### Install Module to NFS Root

```bash
# Install to NFS root filesystem
make install INSTALL_MOD_PATH=$HOME/embedded-linux-beagleplay-labs/tinysystem/nfsroot

# Verify installation
ls -l $HOME/embedded-linux-beagleplay-labs/tinysystem/nfsroot/lib/modules/6.6.*/updates/

# Should show nunchuk.ko
```

### Load Module on Target

```bash
# On BeaglePlay
modprobe nunchuk

# Check kernel messages
dmesg | tail -20

# Expected output:
# nunchuk: loading out-of-tree module taints kernel.
# Nunchuk probe started
```

**But wait!** The driver loaded, but the device wasn't probed. Check I2C bus:

```bash
i2cdetect -r 3
# Device at 0x52 still shown as "52", not "UU"
# This means no driver is bound to it!

# Check I2C drivers
ls /sys/bus/i2c/drivers/
# You'll see "nunchuk" directory

# But no devices inside:
ls /sys/bus/i2c/drivers/nunchuk/
# Empty!
```

**Why?** The kernel doesn't know about the Nunchuk device yet. We need to declare it in the Device Tree!

## Section 8: Device Tree Declaration

### Create Custom Device Tree

```bash
cd $HOME/embedded-linux-beagleplay-labs/kernel/linux/arch/arm64/boot/dts/ti

# Create custom DTS
vi k3-am625-beagleplay-custom.dts
```

**k3-am625-beagleplay-custom.dts:**

```dts
// SPDX-License-Identifier: GPL-2.0
/*
 * Custom BeaglePlay Device Tree
 * Based on k3-am625-beagleplay.dts
 */

/dts-v1/;

#include "k3-am625-beagleplay.dts"

/ {
    model = "BeaglePlay Custom Hardware Lab";
};

/* I2C3 - mikroBUS connector */
&main_i2c3 {
    status = "okay";
    clock-frequency = <100000>; /* 100 kHz for Nunchuk */

    nunchuk: joystick@52 {
        compatible = "nintendo,nunchuk";
        reg = <0x52>;
    };
};
```

**Key Elements:**

- `#include "k3-am625-beagleplay.dts"`: Inherit standard BeaglePlay DT
- `&main_i2c3`: Override I2C3 node
- `clock-frequency = <100000>`: Set bus to 100 kHz (Nunchuk requirement)
- `nunchuk: joystick@52`: Declare device at address 0x52
- `compatible = "nintendo,nunchuk"`: Match driver's `of_device_id`

### Compile Custom Device Tree

```bash
# Add to Makefile
cd $HOME/embedded-linux-beagleplay-labs/kernel/linux/arch/arm64/boot/dts/ti

vi Makefile

# Add line:
# dtb-$(CONFIG_ARCH_K3) += k3-am625-beagleplay-custom.dtb

# Compile
cd $HOME/embedded-linux-beagleplay-labs/kernel/linux
make ARCH=arm64 CROSS_COMPILE=aarch64-beagleplay-linux-musl- dtbs

# Copy to TFTP directory
cp arch/arm64/boot/dts/ti/k3-am625-beagleplay-custom.dtb /srv/tftp/
```

### Update U-Boot to Use Custom DTB

**On BeaglePlay U-Boot console:**

```
# Load custom DTB
=> setenv dtb_file k3-am625-beagleplay-custom.dtb

# Save environment
=> saveenv

# Boot
=> boot
```

### Verify Nunchuk Driver Binding

```bash
# On BeaglePlay, reload module
modprobe -r nunchuk
modprobe nunchuk

# Check kernel messages
dmesg | tail -10

# Expected output:
# nunchuk: loading out-of-tree module taints kernel.
# Nunchuk probe started
# Nunchuk device probed successfully
# input: Wii Nunchuk as /devices/platform/bus@f0000/20030000.i2c/i2c-3/3-0052/input/input2

# Check I2C driver binding
ls -l /sys/bus/i2c/drivers/nunchuk/
# Should show: 3-0052 -> ../../../../devices/platform/.../i2c-3/3-0052

# Probe I2C bus
i2cdetect -r 3
# Device at 0x52 now shows "UU" (driver bound!)
```

### Test Input Events

```bash
# Find input device number
ls /dev/input/event*

# Based on kernel message (input2 → event2), test events
cat /dev/input/event2 | od -x

# Press buttons and move joystick on Nunchuk
# You should see hexadecimal output changing

# Stop with Ctrl+C
```

**Verification Checklist:**

- [ ] Nunchuk wired correctly to mikroBUS I2C3
- [ ] Device detected at address 0x52 with `i2cdetect`
- [ ] Out-of-tree module compiled successfully
- [ ] Module installed to NFS root filesystem
- [ ] Custom Device Tree created with Nunchuk node
- [ ] Custom DTB compiled and copied to TFTP directory
- [ ] U-Boot configured to load custom DTB
- [ ] Driver probe successful (kernel message visible)
- [ ] Driver bound to device (visible in sysfs)
- [ ] Input events generated when Nunchuk is used

## Section 9: Persistent Module Loading

### Auto-Load Nunchuk Module

```bash
# On workstation
cd $HOME/embedded-linux-beagleplay-labs/tinysystem/nfsroot/etc/init.d

# Edit rcS
vi rcS

# Add after snd-usb-audio modprobe line:
modprobe nunchuk

# Save and exit
```

### Reboot and Verify

```bash
# On BeaglePlay
reboot

# After boot, check loaded modules
lsmod | grep nunchuk

# Check driver binding
ls -l /sys/bus/i2c/drivers/nunchuk/

# Verify input device
ls /dev/input/event*
```

## Troubleshooting Guide

### Problem: GPIO export fails with "Device or resource busy"

**Cause:** GPIO already claimed by another driver or device.

**Solution:**

```bash
# Check GPIO usage
cat /sys/kernel/debug/gpio | grep <gpio-number>

# If in use by device tree, modify DT to disable that node
```

### Problem: i2cdetect shows empty bus but device is connected

**Symptoms:**

```bash
i2cdetect -r 3
# All -- (no devices)
```

**Checklist:**

1. **Verify wiring:**
   - Check PWR → 3.3V
   - Check GND → GND
   - Check SCL → SCL pin
   - Check SDA → SDA pin

2. **Check pull-up resistors:** Nunchuk has internal pull-ups, but verify voltage on SDA/SCL is ~3.3V with multimeter

3. **Test with different Nunchuk** (if available)

4. **Verify I2C bus is enabled in Device Tree:**

```bash
# Check if I2C3 controller is enabled
ls /sys/bus/platform/devices/ | grep 20030000.i2c
```

### Problem: Module loads but device not probed

**Symptoms:**

```bash
modprobe nunchuk
# No error, but no "probed successfully" message
```

**Cause:** Device not declared in Device Tree.

**Solution:**

1. Verify custom DTB is loaded:

```bash
# Check device tree model
cat /sys/firmware/devicetree/base/model
# Should show: BeaglePlay Custom Hardware Lab
```

2. Check I2C3 node in DT:

```bash
ls /sys/firmware/devicetree/base/bus@f0000/i2c@20030000/
# Should show "joystick@52" directory
```

3. Recompile and reload custom DTB if missing

### Problem: "version magic" mismatch when loading module

**Error:**

```
insmod: ERROR: could not insert module nunchuk.ko: Invalid module format
dmesg: version magic '6.6.52 SMP mod_unload aarch64' should be '6.6.52-dirty SMP mod_unload aarch64'
```

**Cause:** Module compiled against different kernel version than running kernel.

**Solution:**

```bash
# Check running kernel version
uname -r
# 6.6.52-dirty

# Check module build version
modinfo nunchuk.ko | grep vermagic
# vermagic: 6.6.52 SMP mod_unload aarch64

# Rebuild kernel and modules together:
cd $HOME/embedded-linux-beagleplay-labs/kernel/linux
make ARCH=arm64 CROSS_COMPILE=aarch64-beagleplay-linux-musl- Image.gz modules -j$(nproc)
make ARCH=arm64 CROSS_COMPILE=aarch64-beagleplay-linux-musl- \
    INSTALL_MOD_PATH=$HOME/embedded-linux-beagleplay-labs/tinysystem/nfsroot \
    modules_install

# Rebuild out-of-tree module
cd $HOME/embedded-linux-beagleplay-labs/hardware
make clean
make
make install INSTALL_MOD_PATH=$HOME/embedded-linux-beagleplay-labs/tinysystem/nfsroot

# Update kernel on TFTP
cp $HOME/embedded-linux-beagleplay-labs/kernel/linux/arch/arm64/boot/Image.gz /srv/tftp/

# Reboot target
```

### Problem: Input events not generated

**Symptoms:**

```bash
cat /dev/input/event2 | od -x
# No output when Nunchuk buttons pressed
```

**Debug steps:**

1. Verify driver probed:

```bash
dmesg | grep -i nunchuk
# Should show "Nunchuk device probed successfully"
```

2. Check input device registered:

```bash
cat /proc/bus/input/devices | grep -A 5 Nunchuk
```

3. Enable I2C debugging in driver (requires driver modification)

4. Test I2C communication manually:

```bash
# Read from Nunchuk
i2cget -y 3 0x52 0x00
```

## Advanced Challenges

### Challenge 1: LED Heartbeat on GPIO

Create a custom LED trigger that blinks an external LED connected to GPIO 640.

**Requirements:**
- Add LED definition in Device Tree
- Use timer trigger
- Configure 1 second ON, 1 second OFF

<details>
<summary>Hint</summary>

Add to Device Tree:

```dts
/ {
    leds {
        compatible = "gpio-leds";
        
        custom_led {
            label = "mikrobus:green:custom";
            gpios = <&main_gpio0 36 GPIO_ACTIVE_HIGH>;
            linux,default-trigger = "timer";
        };
    };
};
```

</details>

### Challenge 2: Explore More I2C Devices

Scan all I2C buses and identify all devices. Research their addresses and likely function.

**Tools:**

```bash
# Scan all buses
for i in 0 1 2 3 5; do
    echo "=== Bus i2c-$i ==="
    i2cdetect -r $i
done

# Decode device addresses using I2C device list:
# https://i2c.wiki.kernel.org/index.php/Device_Addresses
```

### Challenge 3: Nunchuk Accelerometer Data

Modify the Nunchuk driver to also report accelerometer data (bytes 2-4 in the Nunchuk data packet).

**Requirements:**
- Add `ABS_RX`, `ABS_RY`, `ABS_RZ` axes
- Parse accelerometer bytes
- Report values using `input_report_abs()`

### Challenge 4: Create systemd Service for Module Loading

Instead of loading modules from `rcS`, create a proper systemd service.

**Hint:** Create `/etc/systemd/system/hardware-init.service`

## What You've Learned

By completing this lab, you've gained hands-on experience with:

✅ **Linux Device Model:**
- Explored `/dev` device files and their major/minor numbers
- Navigated sysfs (`/sys/class`, `/sys/bus`, `/sys/devices`)
- Understood device classification by subsystem

✅ **GPIO Management:**
- Enabled legacy GPIO sysfs interface
- Exported and controlled GPIOs from userspace
- Configured GPIOs as inputs and outputs
- Read digital values and set output states

✅ **LED Subsystem:**
- Controlled LEDs through sysfs
- Used LED triggers (heartbeat, timer, manual)
- Configured LED timing parameters

✅ **I2C Bus Management:**
- Listed and identified I2C controllers
- Mapped Linux I2C numbers to hardware addresses
- Probed I2C buses for devices
- Interpreted `i2cdetect` output

✅ **USB Device Model:**
- Detected USB devices with `lsusb`
- Explored USB device properties in sysfs
- Understood USB device enumeration

✅ **Kernel Module Development:**
- Configured kernel features as loadable modules
- Compiled in-tree modules
- Installed modules to target filesystem
- Loaded modules with `modprobe`
- Inspected module dependencies with `lsmod`
- Created out-of-tree kernel modules
- Wrote Makefile for external module compilation

✅ **Device Tree:**
- Created custom Device Tree overlays
- Declared I2C devices in DT
- Matched devices to drivers via `compatible` strings
- Compiled and deployed custom DTBs
- Verified DT contents via sysfs

✅ **Driver Development:**
- Wrote I2C device driver (Nunchuk)
- Implemented probe and remove functions
- Registered input devices
- Reported events to input subsystem
- Debugged driver-device binding issues

✅ **System Integration:**
- Automated module loading at boot
- Modified startup scripts
- Persistent hardware configuration

## Going Further

### Recommended Reading

**Kernel Documentation:**
- `Documentation/driver-api/gpio/` - GPIO subsystem
- `Documentation/leds/` - LED class documentation  
- `Documentation/i2c/` - I2C subsystem
- `Documentation/input/` - Input device drivers
- `Documentation/devicetree/` - Device Tree bindings

**Books:**
- *Linux Device Drivers* (3rd Edition) - Chapters 9-11
- *Essential Linux Device Drivers* - Chapters 3-8

### Next Steps

In **Lab 7: Block Filesystems**, you'll:
- Create ext4 filesystems on SD card
- Implement SquashFS for read-only root
- Use tmpfs for volatile storage
- Boot entirely from SD card (no NFS)

---

**Estimated Completion Time:** 4-5 hours

**Difficulty:** ⭐⭐⭐☆☆ (Intermediate)

**Prerequisites Met:** ✅ Lab 5 (Root Filesystem)

**Leads to:** Lab 7 (Block Filesystems)
