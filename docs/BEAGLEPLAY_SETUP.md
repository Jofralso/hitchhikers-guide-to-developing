# BeaglePlay Hardware Setup Guide

This guide covers the initial setup and configuration of the BeaglePlay development board.

## Hardware Overview

### BeaglePlay Specifications

- **SoC**: Texas Instruments AM6254
  - Quad-core ARM Cortex-A53 @ 1.4GHz (64-bit)
  - Arm Cortex-M4F MCU for real-time operations
- **Memory**: 2GB DDR4 RAM
- **Storage**: 
  - 16GB eMMC flash (on-board)
  - microSD card slot (up to 128GB)
- **Wireless**:
  - WiFi 5 (802.11ac) 2.4/5GHz
  - Bluetooth 5.2 LE
  - SubGHz radio (868/915 MHz CC1352)
- **Wired Networking**: Gigabit Ethernet (10/100/1000 Mbps)
- **USB**:
  - 1x USB Type-C (power, data, console)
  - 1x USB 2.0 Type-A host port
- **Expansion**:
  - mikroBUS connector
  - Grove connector
  - QWIIC/STEMMA QT connector (I2C)
  - 2x 46-pin headers (GPIOs, SPI, I2C, UART, PWM, etc.)
- **Debug**: 
  - UART console via USB-C
  - JTAG/SWD interface
- **Power**: USB Type-C (5V, minimum 3A recommended)
- **Dimensions**: 86.36mm x 54.61mm

### Comparison to Other Platforms

| Feature | BeaglePlay | Raspberry Pi 4B | Raspberry Pi 5 |
|---------|-----------|-----------------|----------------|
| CPU | ARM Cortex-A53 (4-core) | ARM Cortex-A72 (4-core) | ARM Cortex-A76 (4-core) |
| Clock | 1.4 GHz | 1.5 GHz | 2.4 GHz |
| RAM | 2 GB DDR4 | 1/2/4/8 GB | 4/8 GB |
| SubGHz | ✅ Yes (CC1352) | ❌ No | ❌ No |
| Real-time MCU | ✅ Yes (M4F) | ❌ No | ❌ No |
| mikroBUS | ✅ Yes | ❌ No | ❌ No |
| Price | ~$99 | ~$35-75 | ~$60-80 |

**Why BeaglePlay for Embedded Linux?**
- Industrial-focused design with expansion connectors
- Real-time MCU for deterministic tasks
- SubGHz radio for IoT/LPWAN applications
- Better documentation for low-level development
- Active community and professional support

---

## Initial Setup

### What You Need

1. **BeaglePlay board**
2. **USB Type-C cable** (data + power capable)
3. **microSD card** (32GB or larger, Class 10/UHS-I)
4. **Development PC** running Linux (Ubuntu 24.04 recommended)
5. **Ethernet cable** (optional, for network boot labs)
6. **5V/3A power supply** (USB-C, optional but recommended for peripherals)

### Power Options

BeaglePlay can be powered via:
1. **USB Type-C**: Easiest for development (also provides serial console)
2. **mikroBUS 5V pin**: For standalone deployments
3. **Barrel jack** (with optional adapter): Legacy power option

**Recommendation**: Use USB-C for all development work.

---

## First Boot

### Step 1: Download a Working Image

For initial testing, download the latest BeaglePlay Debian image:

```bash
cd ~/Downloads
wget https://debian.beagleboard.org/images/bone-debian-latest-console-armhf.img.xz
# Or download from: https://www.beagleboard.org/distros
```

**Note**: We'll build our own minimal images in the labs, but this confirms hardware works.

### Step 2: Flash to microSD Card

**Linux**:
```bash
# Find your SD card device (be careful!)
lsblk

# Assuming your SD card is /dev/sdX (replace X with actual letter)
# CAUTION: This will erase all data on the card!
xzcat bone-debian-latest-console-armhf.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
sync
```

**Etcher (cross-platform)**:
```bash
# Download from: https://www.balena.io/etcher/
# Use GUI to flash image
```

### Step 3: Insert SD Card and Connect

1. Power off BeaglePlay (if powered)
2. Insert microSD card into slot
3. Connect USB-C cable from BeaglePlay to your PC
4. BeaglePlay should boot automatically (LEDs will blink)

### Step 4: Access Serial Console

The USB-C connection provides a serial console at 115200 baud.

**Find the device**:
```bash
# Linux: usually /dev/ttyACM0 or /dev/ttyUSB0
ls -l /dev/ttyACM*
ls -l /dev/ttyUSB*

# Check kernel messages
dmesg | tail
```

**Connect with screen**:
```bash
sudo apt install screen
sudo screen /dev/ttyACM0 115200
```

**Or use minicom**:
```bash
sudo apt install minicom
sudo minicom -D /dev/ttyACM0 -b 115200
```

**Or use picocom** (recommended):
```bash
sudo apt install picocom
sudo picocom -b 115200 /dev/ttyACM0
# Exit: Ctrl-A, Ctrl-X
```

**Default Credentials** (for Debian image):
- Username: `debian`
- Password: `temppwd`

### Step 5: Network Configuration

**Via Ethernet** (easiest):
- Connect Ethernet cable
- DHCP should auto-configure network
- Find IP: `ip addr show eth0`

**Via WiFi**:
```bash
# On BeaglePlay (via serial console)
sudo nmcli device wifi list
sudo nmcli device wifi connect "YOUR_SSID" password "YOUR_PASSWORD"
```

**SSH Access**:
```bash
# From development PC
ssh debian@beagleplay.local
# Or use IP address: ssh debian@192.168.1.XXX
```

---

## GPIO and Expansion Headers

### Pin Headers

BeaglePlay has two 46-pin headers (P8 and P9) similar to other BeagleBone boards.

**Important**: 
- I/O voltage: 3.3V (NOT 5V tolerant!)
- Always check pinout before connecting devices

**Pinout Reference**: https://docs.beagleboard.org/latest/boards/beagleplay/

### mikroBUS Socket

BeaglePlay includes a mikroBUS connector for Click boards from MikroElektronika.

**Pinout**:
```
AN  - Analog Input
RST - Reset
CS  - SPI Chip Select
SCK - SPI Clock
MISO - SPI Master In
MOSI - SPI Master Out
PWM - PWM Output
INT - Interrupt
RX  - UART Receive
TX  - UART Transmit
SCL - I2C Clock
SDA - I2C Data
```

**Compatible Modules**: 1000+ Click boards available
**Example Use Cases**: Sensors, displays, motor controllers, communication modules

### Grove Connector

Single Grove connector supporting I2C devices.

**Use Case**: Quick prototyping with Seeed Studio Grove modules

### QWIIC/STEMMA QT

I2C connector compatible with SparkFun QWIIC and Adafruit STEMMA QT ecosystem.

**Voltage**: 3.3V
**Protocol**: I2C
**Use Case**: Chaining multiple I2C sensors without breadboards

---

## Boot Modes

### Boot Order

BeaglePlay boot sequence (default):
1. **microSD card** (if present and bootable)
2. **eMMC** (on-board flash)
3. **USB** (DFU mode)
4. **UART/Serial** boot (rarely used)

### Boot Button

**Location**: Small button labeled "BOOT" or "USR"

**Function**:
- Hold during power-up: Forces boot from eMMC (skips SD card)
- Quick press during boot: Can interrupt U-Boot for console

### eMMC vs SD Card

**For Development**:
- Use microSD card for easy reflashing
- Keep eMMC as recovery/fallback

**For Production**:
- Flash final image to eMMC
- Faster boot times
- More reliable than SD cards

**Flash to eMMC** (from booted system):
```bash
# Boot from SD card first
# Then flash eMMC with image from SD:
sudo /opt/scripts/tools/eMMC/beaglebone-black-make-microSD-flasher-from-eMMC.sh
# Or use custom flashing scripts (covered in labs)
```

---

## LED Indicators

BeaglePlay has multiple LEDs:

| LED | Color | Typical Meaning |
|-----|-------|-----------------|
| USR0 | Blue | Heartbeat (system alive) |
| USR1 | Blue | SD card activity |
| USR2 | Blue | CPU activity |
| USR3 | Blue | eMMC activity |
| Power | Red/Green | Power status |

**Controlling LEDs**:
```bash
# On running system
cd /sys/class/leds/

# Turn on USR LED 0
echo 1 > beagleplay::usr0/brightness

# Set trigger to heartbeat
echo heartbeat > beagleplay::usr0/trigger
```

---

## UART/Serial Console Details

### Hardware Setup

**USB-C Connection**:
- Automatically creates `/dev/ttyACM0` (Linux)
- No FTDI cable needed
- Integrated UART-to-USB bridge

**Parameters**:
- Baud rate: 115200
- Data bits: 8
- Parity: None
- Stop bits: 1
- Flow control: None

### Accessing U-Boot Console

1. Connect serial terminal before powering on
2. Power on BeaglePlay
3. Quickly press any key when you see:
   ```
   Hit any key to stop autoboot:  2
   ```
4. You'll get U-Boot prompt: `=>`

**U-Boot Commands**:
```bash
=> help                 # List all commands
=> printenv            # Show environment variables
=> version             # U-Boot version
=> bdinfo              # Board info
=> mmc list            # List MMC devices
```

---

## Development Workflow

### Recommended Setup

```
┌─────────────────┐         USB-C          ┌──────────────┐
│  Development PC │◄──────────────────────►│  BeaglePlay  │
│  (Ubuntu 24.04) │    (Console + Power)   │              │
│                 │                        │   microSD    │
│  - Build tools  │      Ethernet          │   card       │
│  - Cross-comp   │◄──────────────────────►│              │
│  - Text editor  │     (Optional)         └──────────────┘
│  - Git          │                               │
└─────────────────┘                               │
                                            Peripherals
                                            (sensors, etc.)
```

### Workflow Steps (Preview)

1. **Write code** on development PC
2. **Cross-compile** for ARM64 (on PC)
3. **Transfer** binary to BeaglePlay (via network, SD card, or serial)
4. **Execute** on BeaglePlay
5. **Debug** via serial console or SSH
6. **Iterate**

(Detailed workflows covered in individual labs)

---

## Troubleshooting

### BeaglePlay Won't Boot

**Check**:
1. Proper USB-C cable (some cables are power-only)
2. SD card is properly formatted and imaged
3. Power supply provides enough current (3A recommended)
4. LEDs show activity

**Try**:
- Re-flash SD card
- Try booting from eMMC (remove SD card)
- Check serial console for error messages

### No Serial Console

**Linux**:
```bash
# Check if device appears
dmesg | grep tty

# Check permissions
ls -l /dev/ttyACM0

# Add user to dialout group (logout/login required)
sudo usermod -a -G dialout $USER
```

**Common Issues**:
- Driver not loaded: `sudo modprobe cdc_acm`
- Permission denied: User not in `dialout` group
- Wrong device: Try `/dev/ttyUSB0` or `/dev/ttyACM1`

### Network Not Working

**Ethernet**:
```bash
# Check link status
ip link show eth0

# Try manual DHCP
sudo dhclient eth0
```

**WiFi**:
```bash
# Check WiFi device
nmcli device status

# Scan for networks
sudo nmcli device wifi rescan
sudo nmcli device wifi list
```

### Can't SSH to BeaglePlay

**Check**:
1. Network connectivity: `ping beagleplay.local` or `ping <IP>`
2. SSH service running: `sudo systemctl status ssh` (on BeaglePlay)
3. Firewall not blocking (unlikely on default Debian image)

**Enable SSH** (if disabled):
```bash
# On BeaglePlay via serial console
sudo systemctl enable ssh
sudo systemctl start ssh
```

---

## Next Steps

Once your BeaglePlay is working:

1. ✅ Verify serial console access
2. ✅ Confirm network connectivity
3. ✅ Test SSH access
4. ✅ Explore GPIO (blink LED)
5. 📚 **Proceed to Lab 1: Cross-Compilation Toolchain**

---

## Additional Resources

- **Official Documentation**: https://docs.beagleboard.org/latest/boards/beagleplay/
- **BeagleBoard Forums**: https://forum.beagleboard.org/
- **TI AM62x TRM**: https://www.ti.com/product/AM625
- **Schematics**: https://git.beagleboard.org/beagleplay/beagleplay
- **Community Projects**: https://beagleboard.org/project

---

*Last Updated: 2025-01-24*
*Hardware: BeaglePlay Rev A1*
*Compatible with: Debian 11/12, Custom Buildroot/Yocto images*
