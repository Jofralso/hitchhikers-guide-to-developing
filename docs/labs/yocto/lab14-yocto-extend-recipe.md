# Lab 14: Extend Recipes with bbappend

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about debugging:

*"Debugging is the art of figuring out why your code doesn't work, as opposed to why you thought it would work. This is similar to the difference between what Deep Thought calculated (42) and what everyone expected (a useful answer). Both are technically correct, but only one is helpful."*

## Objectives

Master the art of extending existing recipes without modifying the original files, using BitBake append (`.bbappend`) files for customization.

**What You'll Learn:**
- Create `.bbappend` files
- Apply patches to existing recipes
- Add custom configuration files
- Extend kernel configuration
- Add Nunchuk joystick support to Linux kernel
- Best practices for recipe extension

**Time Required:** 2-3 hours (or approximately 42 minutes in improbable circumstances)

---

## Prerequisites

**Completed Labs:**
- Lab 13: Create Custom Yocto Layer

**Hardware:**
- Wii Nunchuk controller
- mikroBUS connector on BeaglePlay

---

## 1. Understanding bbappend Files

### 1.1 Why bbappend?

**Problem:** You need to modify an existing recipe from another layer.

**Bad solution:** Edit the original recipe
- Breaks on layer updates
- Merge conflicts
- Not maintainable

**Good solution:** Create `.bbappend` file
- ✅ Original recipe untouched
- ✅ Changes in your layer
- ✅ Survives upstream updates
- ✅ Clear separation of concerns

### 1.2 bbappend Mechanics

**Recipe location:**
```
meta-ti/recipes-kernel/linux/linux-ti-staging_6.6.bb
```

**Your bbappend:**
```
meta-beagleplay/recipes-kernel/linux/linux-ti-staging_6.6.bbappend
```

**Naming rules:**
- Must match recipe base name
- Can use `%` wildcard for version: `linux-ti-staging_%.bbappend`

---

## 2. Creating Your First bbappend

### 2.1 Extend Kernel Recipe

**Create directory structure:**
```bash
cd ~/yocto-labs/meta-beagleplay
mkdir -p recipes-kernel/linux
```

**Create bbappend file:**
```bash
nano recipes-kernel/linux/linux-ti-staging_%.bbappend
```

**Minimal bbappend:**
```python
# Extend kernel recipe for BeaglePlay customizations
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
```

**What this does:**
- `FILESEXTRAPATHS`: Adds directory to file search path
- `:prepend :=`: Immediate prepend (evaluated once)
- `${THISDIR}/files:`: Points to `files/` subdirectory

### 2.2 Verify bbappend is Recognized

```bash
cd ~/yocto-labs/build
bitbake-layers show-appends
```

**Expected output:**
```
linux-ti-staging_6.6.bb:
  /home/user/yocto-labs/meta-beagleplay/recipes-kernel/linux/linux-ti-staging_%.bbappend
```

✅ bbappend matched!

---

## 3. Adding Kernel Patches

### 3.1 Nunchuk Driver Background

We'll add a custom kernel driver for Wii Nunchuk joystick support.

**What it does:**
- Communicates with Nunchuk via I2C
- Exposes joystick input device (`/dev/input/js0`)
- Handles button and accelerometer data

### 3.2 Obtain Patch Files

**Create files directory:**
```bash
cd ~/yocto-labs/meta-beagleplay/recipes-kernel/linux
mkdir files
```

**Download/create patches** (example content):

**File 1: `files/0001-add-nunchuk-driver.patch`**
```bash
nano files/0001-add-nunchuk-driver.patch
```

**Content (example structure):**
```patch
From abc123def456... Mon Sep 17 00:00:00 2001
From: Your Name <your.email@example.com>
Date: Mon, 20 Nov 2024 10:00:00 +0000
Subject: [PATCH 1/2] Add Wii Nunchuk I2C joystick driver

Add kernel driver for Nintendo Wii Nunchuk controller
connected via I2C bus.

Signed-off-by: Your Name <your.email@example.com>
---
 drivers/input/joystick/Kconfig     |  10 ++
 drivers/input/joystick/Makefile    |   1 +
 drivers/input/joystick/nunchuk.c   | 250 +++++++++++++++++++++++++++++
 3 files changed, 261 insertions(+)
 create mode 100644 drivers/input/joystick/nunchuk.c

diff --git a/drivers/input/joystick/Kconfig b/drivers/input/joystick/Kconfig
index 123456..789abc 100644
--- a/drivers/input/joystick/Kconfig
+++ b/drivers/input/joystick/Kconfig
@@ -300,4 +300,14 @@ config JOYSTICK_XPAD_LEDS
 	  This option enables support for the LED which surrounds the Big X on
 	  XBox 360 controller.
 
+config JOYSTICK_NUNCHUK
+	tristate "Nintendo Wii Nunchuk"
+	depends on I2C
+	help
+	  Say Y here if you want to use a Nintendo Wii Nunchuk controller
+	  connected via I2C.
+
+	  To compile this driver as a module, choose M here: the
+	  module will be called nunchuk.
+
 endif
diff --git a/drivers/input/joystick/Makefile b/drivers/input/joystick/Makefile
index 654321..fedcba 100644
--- a/drivers/input/joystick/Makefile
+++ b/drivers/input/joystick/Makefile
@@ -30,3 +30,4 @@ obj-$(CONFIG_JOYSTICK_WARRIOR)		+= warrior.o
 obj-$(CONFIG_JOYSTICK_XPAD)		+= xpad.o
 obj-$(CONFIG_JOYSTICK_ZHENHUA)		+= zhenhua.o
 obj-$(CONFIG_JOYSTICK_WALKERA0701)	+= walkera0701.o
+obj-$(CONFIG_JOYSTICK_NUNCHUK)		+= nunchuk.o
diff --git a/drivers/input/joystick/nunchuk.c b/drivers/input/joystick/nunchuk.c
new file mode 100644
index 000000..123456
--- /dev/null
+++ b/drivers/input/joystick/nunchuk.c
@@ -0,0 +1,250 @@
+// SPDX-License-Identifier: GPL-2.0
+/*
+ * Nintendo Wii Nunchuk I2C joystick driver
+ */
+
+#include <linux/module.h>
+#include <linux/i2c.h>
+#include <linux/input.h>
+#include <linux/delay.h>
+
+// (Driver implementation code here)
+// ...
+
+MODULE_LICENSE("GPL");
+MODULE_AUTHOR("Your Name");
+MODULE_DESCRIPTION("Nintendo Wii Nunchuk driver");
--
2.40.1
```

**File 2: `files/0002-enable-nunchuk-device-tree.patch`**
```bash
nano files/0002-enable-nunchuk-device-tree.patch
```

**Content:**
```patch
From def456abc789... Mon Sep 17 00:00:00 2001
From: Your Name <your.email@example.com>
Date: Mon, 20 Nov 2024 10:05:00 +0000
Subject: [PATCH 2/2] ARM64: dts: beagleplay: Add Nunchuk to I2C3

Enable Nunchuk controller on I2C3 bus (mikroBUS connector).

Signed-off-by: Your Name <your.email@example.com>
---
 arch/arm64/boot/dts/ti/k3-am625-beagleplay.dts | 8 ++++++++
 1 file changed, 8 insertions(+)

diff --git a/arch/arm64/boot/dts/ti/k3-am625-beagleplay.dts b/arch/arm64/boot/dts/ti/k3-am625-beagleplay.dts
index 123456..789abc 100644
--- a/arch/arm64/boot/dts/ti/k3-am625-beagleplay.dts
+++ b/arch/arm64/boot/dts/ti/k3-am625-beagleplay.dts
@@ -400,6 +400,14 @@
 	status = "okay";
 	pinctrl-names = "default";
 	pinctrl-0 = <&mikrobus_i2c_pins_default>;
+
+	nunchuk: joystick@52 {
+		compatible = "nintendo,nunchuk";
+		reg = <0x52>;
+		interrupt-parent = <&main_gpio0>;
+		interrupts = <12 IRQ_TYPE_EDGE_FALLING>;
+		status = "okay";
+	};
 };
 
 &main_i2c1 {
--
2.40.1
```

### 3.3 Add Patches to bbappend

**Edit bbappend:**
```bash
nano recipes-kernel/linux/linux-ti-staging_%.bbappend
```

**Add patches:**
```python
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " \
    file://0001-add-nunchuk-driver.patch \
    file://0002-enable-nunchuk-device-tree.patch \
"
```

**Explanation:**
- `SRC_URI:append`: Adds files to source list
- BitBake automatically applies `.patch` files
- Patches applied in `do_patch` task
- Order matters - patches applied sequentially

---

## 4. Adding Kernel Configuration

### 4.1 Create defconfig Fragment

**Enable Nunchuk driver:**
```bash
nano files/nunchuk.cfg
```

**Content:**
```
CONFIG_JOYSTICK_NUNCHUK=y
CONFIG_INPUT_JOYSTICK=y
CONFIG_INPUT_EVDEV=y
```

### 4.2 Add defconfig to bbappend

**Update bbappend:**
```python
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " \
    file://0001-add-nunchuk-driver.patch \
    file://0002-enable-nunchuk-device-tree.patch \
    file://nunchuk.cfg \
"
```

**Kernel recipe automatically merges `.cfg` files** via `kernel-yocto` class.

---

## 5. Building Modified Kernel

### 5.1 Clean and Rebuild

```bash
cd ~/yocto-labs/build
bitbake -c cleanall virtual/kernel
bitbake virtual/kernel
```

**Build takes ~20-30 minutes** (full kernel rebuild).

### 5.2 Verify Patches Applied

**Check kernel work directory:**
```bash
cd ~/yocto-labs/build/tmp/work/beagleplay-poky-linux/linux-ti-staging/*/git
git log --oneline | head -5
```

**Should show:**
```
abc123d (HEAD) enable-nunchuk-device-tree
def456e add-nunchuk-driver
...
```

**Check driver exists:**
```bash
ls drivers/input/joystick/nunchuk.c
# Should exist
```

### 5.3 Verify Configuration

**Check kernel config:**
```bash
cd ~/yocto-labs/build/tmp/work/beagleplay-poky-linux/linux-ti-staging/*/
cat .config | grep NUNCHUK
```

**Output:**
```
CONFIG_JOYSTICK_NUNCHUK=y
```

---

## 6. Deploy and Test

### 6.1 Rebuild Image

```bash
bitbake core-image-minimal
```

### 6.2 Deploy to NFS

```bash
cd ~/yocto-labs/build/tmp/deploy/images/beagleplay
sudo rm -rf /nfs/beagleplay/*
sudo tar -xf core-image-minimal-beagleplay.rootfs.tar.xz -C /nfs/beagleplay
sudo chown -R root:root /nfs/beagleplay

# Copy new kernel to SD card boot partition (or TFTP)
sudo mount /dev/sdb1 /mnt
sudo cp Image /mnt/
sudo cp k3-am625-beagleplay.dtb /mnt/
sudo umount /mnt
```

### 6.3 Connect Nunchuk Hardware

**mikroBUS I2C3 pins on BeaglePlay:**
- Pin 11: SDA (I2C3 data)
- Pin 12: SCL (I2C3 clock)
- Pin 7: 3.3V (power)
- Pin 10: GND (ground)

**Nunchuk pinout (UEXT connector):**
```
   1  2  3  4  5  6  7  8  9 10
  ┌──┬──┬──┬──┬──┬──┬──┬──┬──┬──┐
  │3V│  │  │  │  │  │GN│SC│SD│  │
  │3V│  │  │  │  │  │D │L │A │  │
  └──┴──┴──┴──┴──┴──┴──┴──┴──┴──┘
```

**Connections:**
- Nunchuk 3V3 → mikroBUS Pin 7
- Nunchuk GND → mikroBUS Pin 10
- Nunchuk SCL → mikroBUS Pin 12
- Nunchuk SDA → mikroBUS Pin 11

### 6.4 Boot and Verify

**Boot BeaglePlay, check kernel log:**
```bash
dmesg | grep -i nunchuk
```

**Expected:**
```
[    2.345678] nunchuk 3-0052: Nintendo Wii Nunchuk detected
[    2.456789] input: Nintendo Wii Nunchuk as /devices/platform/.../input/input0
```

**Check device node:**
```bash
ls -l /dev/input/js0
# Output: crw-rw---- 1 root input 13, 0 Nov 20 10:00 /dev/input/js0
```

**Test input events:**
```bash
cat /dev/input/js0
# Move joystick, press buttons - should see binary data
```

**Use evtest (if installed):**
```bash
evtest /dev/input/js0
```

---

## 7. Advanced bbappend Techniques

### 7.1 Conditional Append

**Machine-specific patches:**
```python
SRC_URI:append:beagleplay = " file://beagleplay-only.patch"
SRC_URI:append:qemux86-64 = " file://qemu-only.patch"
```

### 7.2 Override Variables

**Change kernel version:**
```python
PV = "6.6.32"
SRCREV = "abc123def456..."
```

**Add extra compiler flags:**
```python
EXTRA_OEMAKE:append = " CONFIG_DEBUG_INFO=y"
```

### 7.3 Extend Tasks

**Add post-install steps:**
```python
do_install:append() {
    install -m 0644 ${S}/extra-file ${D}/boot/
}
```

### 7.4 Remove Files from SRC_URI

**Remove unwanted patches:**
```python
SRC_URI:remove = "file://unwanted-patch.patch"
```

---

## 8. Best Practices

### 8.1 Patch Naming

**Convention:**
```
0001-short-description.patch
0002-another-change.patch
```

**Numbering ensures order.**

### 8.2 Patch Creation

**Generate from Git:**
```bash
cd linux-source/
git format-patch -1 HEAD
# Outputs: 0001-commit-message.patch
```

### 8.3 Config Fragment Organization

**Separate by feature:**
```
files/
├── nunchuk.cfg       # Nunchuk driver config
├── debug.cfg         # Debug options
├── usb.cfg           # USB gadget features
```

**Combine in bbappend:**
```python
SRC_URI:append = " \
    file://nunchuk.cfg \
    file://debug.cfg \
    file://usb.cfg \
"
```

---

## 9. Troubleshooting

**Problem:** Patch fails to apply

**Solution:**
```bash
# Check patch context
cat files/0001-patch.patch

# Manually apply to check
cd tmp/work/.../linux-ti-staging/.../git
patch -p1 < /path/to/patch

# If fails, regenerate patch against current kernel version
```

---

**Problem:** Configuration not taking effect

**Solution:**
```bash
# Check merged config
bitbake -c configure virtual/kernel
cat tmp/work/.../linux-ti-staging/.../.config | grep NUNCHUK

# Force reconfigure
bitbake -c cleanall virtual/kernel
bitbake virtual/kernel
```

---

**Problem:** bbappend not matched

**Solution:**
```bash
# Check exact recipe name
bitbake-layers show-recipes linux-ti-staging

# Use wildcard version
mv linux-ti-staging_6.6.bbappend linux-ti-staging_%.bbappend
```

---

## 10. Going Further

### 10.1 Patch ninvaders for Joystick

**Add joystick support to ninvaders:**
```python
# In meta-beagleplay/recipes-games/ninvaders/ninvaders_%.bbappend
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " file://0001-add-joystick-support.patch"

DEPENDS:append = " linux-input"
```

### 10.2 Multiple bbappend Files

**You can have multiple appends for same recipe:**
```
meta-layer1/recipes-kernel/linux/linux-ti-staging_%.bbappend
meta-layer2/recipes-kernel/linux/linux-ti-staging_%.bbappend
```

Both applied, layer priority determines order.

---

## 11. Key Takeaways

**Accomplished:**
1. ✅ Created bbappend files
2. ✅ Applied kernel patches
3. ✅ Added kernel configuration fragments
4. ✅ Extended Device Tree
5. ✅ Added Nunchuk driver support
6. ✅ Tested on hardware

**Skills Gained:**
- Non-invasive recipe modification
- Patch management
- Kernel customization workflow
- Hardware driver integration

**Next Steps:**
- **Lab 15**: Custom machine configurations
- **Lab 16**: Create custom distribution images
- **Lab 17**: SDK development workflow

---

## 12. Verification Checklist

- [ ] bbappend file created and recognized
- [ ] Patches apply successfully
- [ ] Kernel config includes Nunchuk driver
- [ ] Kernel rebuilds without errors
- [ ] Nunchuk device appears in `/dev/input/`
- [ ] evtest shows joystick events
- [ ] No merge conflicts on kernel updates

**Success criteria:** Functional Nunchuk joystick on BeaglePlay

---

**End of Lab 14**

*The Guide rates this lab: **Mostly Harmless** ⭐⭐⭐⭐*

You now master recipe extension through bbappend files, enabling clean customization of upstream packages without breaking maintainability. This is the foundation of professional Yocto development.
