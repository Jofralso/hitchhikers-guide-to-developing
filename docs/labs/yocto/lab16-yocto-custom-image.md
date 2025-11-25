# Lab 16: Create Custom Image

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about debugging:

*"Debugging is the art of figuring out why your code doesn't work, as opposed to why you thought it would work. This is similar to the difference between what Deep Thought calculated (42) and what everyone expected (a useful answer). Both are technically correct, but only one is helpful."*

## Objectives

Design custom image recipes that define exact package selections, image features, and build requirements for production and development variants.

**What You'll Learn:**
- Write custom image recipes
- Control package selection
- Differentiate production vs. debug images
- Manage image features
- Control rootfs size
- Create custom package groups

**Time Required:** 1-2 hours

---

## Prerequisites

**Completed Labs:**
- Lab 13-15: Custom layers, machine configs

---

## 1. Understanding Image Recipes

### 1.1 Image Recipe Purpose

**Image recipe defines:**
- Packages to install
- Image features (debug, dev tools)
- Rootfs size limits
- License compliance
- Post-processing tasks

**Common images:**
- `core-image-minimal`: Bare minimum
- `core-image-base`: + networking
- `core-image-full-cmdline`: All CLI tools

---

## 2. Creating Custom Image

### 2.1 Basic Image Recipe

```bash
cd ~/yocto-labs/meta-beagleplay
mkdir -p recipes-images
nano recipes-images/beagleplay-image-minimal.bb
```

**Content:**
```python
SUMMARY = "Minimal BeaglePlay image"
DESCRIPTION = "Production-ready minimal image for BeaglePlay"
LICENSE = "MIT"

# Inherit core image class
inherit core-image

# Core packages
IMAGE_INSTALL = " \
    packagegroup-core-boot \
    packagegroup-core-ssh-dropbear \
    ${CORE_IMAGE_EXTRA_INSTALL} \
"

# Add custom packages
IMAGE_INSTALL += " \
    packagegroup-beagleplay-games \
    i2c-tools \
    can-utils \
"

# Image features
IMAGE_FEATURES += " \
    ssh-server-dropbear \
    package-management \
"

# Rootfs size limit (MB)
IMAGE_ROOTFS_SIZE ?= "512000"
IMAGE_ROOTFS_EXTRA_SPACE = "10000"
```

### 2.2 Build Custom Image

```bash
cd ~/yocto-labs/build
bitbake beagleplay-image-minimal
```

---

## 3. Production vs. Debug Images

### 3.1 Create Debug Image

```bash
nano ~/yocto-labs/meta-beagleplay/recipes-images/beagleplay-image-debug.bb
```

**Content:**
```python
SUMMARY = "Debug BeaglePlay image"
DESCRIPTION = "Development image with debugging tools"
LICENSE = "MIT"

# Inherit production image
require beagleplay-image-minimal.bb

# Override description
DESCRIPTION = "Development image with debugging tools for BeaglePlay"

# Add debug features
IMAGE_FEATURES += " \
    tools-debug \
    tools-sdk \
    dbg-pkgs \
    dev-pkgs \
"

# Extra debug packages
IMAGE_INSTALL += " \
    gdb \
    gdbserver \
    strace \
    ltrace \
    perf \
    htop \
    vim \
"

# Allow larger rootfs for debug
IMAGE_ROOTFS_SIZE = "1024000"
```

**Benefits:**
- Code reuse via `require`
- Clear differentiation
- Same base, different tools

---

## 4. Custom Package Groups

### 4.1 Create Development Tools Group

```bash
nano ~/yocto-labs/meta-beagleplay/recipes-core/packagegroups/packagegroup-beagleplay-dev.bb
```

**Content:**
```python
SUMMARY = "BeaglePlay development tools"
DESCRIPTION = "Development and debugging utilities"
LICENSE = "MIT"

inherit packagegroup

RDEPENDS:${PN} = " \
    gdbserver \
    strace \
    ltrace \
    i2c-tools \
    can-utils \
    mtd-utils \
    evtest \
    lsof \
    tree \
    nano \
"
```

### 4.2 Use in Debug Image

```python
IMAGE_INSTALL += " packagegroup-beagleplay-dev"
```

---

## 5. Image Features

### 5.1 Common Features

```python
IMAGE_FEATURES += " \
    ssh-server-dropbear \  # SSH server
    package-management \   # opkg on target
    debug-tweaks \         # Root login, no password
    tools-debug \          # gdb, strace
    tools-sdk \            # Compiler on target
    dbg-pkgs \             # Debug symbols
    dev-pkgs \             # Headers
    read-only-rootfs \     # Immutable rootfs
"
```

### 5.2 Security vs. Development

**Production:**
```python
# NO debug-tweaks (requires password)
# NO tools-sdk (no compiler)
# read-only-rootfs
IMAGE_FEATURES = "ssh-server-dropbear"
```

**Development:**
```python
# debug-tweaks (easy login)
# tools-sdk (on-target compilation)
IMAGE_FEATURES = "debug-tweaks tools-sdk"
```

---

## 6. Rootfs Size Management

### 6.1 Size Configuration

```python
# Base size (KB)
IMAGE_ROOTFS_SIZE = "512000"  # 500MB

# Extra space (KB)
IMAGE_ROOTFS_EXTRA_SPACE = "10000"  # 10MB

# Overhead factor
IMAGE_OVERHEAD_FACTOR = "1.3"  # 30% overhead
```

### 6.2 Handle Size Errors

**Error:**
```
ERROR: Function do_rootfs failed: Image size exceeds IMAGE_ROOTFS_SIZE
```

**Solutions:**
```python
# Increase size
IMAGE_ROOTFS_SIZE = "1024000"

# Or remove limit
IMAGE_ROOTFS_SIZE = ""
```

---

## 7. License Manifest

### 7.1 Enable License Tracking

```python
# In image recipe
COPY_LIC_MANIFEST = "1"
COPY_LIC_DIRS = "1"
LICENSE_CREATE_PACKAGE = "1"
```

### 7.2 View Licenses

**After build:**
```bash
ls tmp/deploy/licenses/beagleplay-image-minimal*/
```

**Contains license files for all packages.**

---

## 8. Post-Install Customization

### 8.1 Add Custom Files

```python
do_rootfs:append() {
    # Create custom motd
    echo "Welcome to BeaglePlay!" > ${IMAGE_ROOTFS}/etc/motd
    
    # Add startup script
    install -d ${IMAGE_ROOTFS}/etc/init.d
    install -m 0755 ${THISDIR}/files/custom-init.sh \
        ${IMAGE_ROOTFS}/etc/init.d/
}
```

### 8.2 Set Root Password

```python
# Inherit extrausers class
inherit extrausers

# Set root password (hashed)
EXTRA_USERS_PARAMS = "usermod -P 'mypassword' root;"
```

---

## 9. Building and Testing

### 9.1 Build Both Images

```bash
bitbake beagleplay-image-minimal
bitbake beagleplay-image-debug
```

### 9.2 Compare Sizes

```bash
cd tmp/deploy/images/beagleplay-custom
ls -lh *-image-*.rootfs.tar.xz

# Minimal: ~50MB
# Debug: ~200MB
```

### 9.3 Deploy and Test

**Minimal:**
```bash
xz -dc beagleplay-image-minimal-*.wic.xz | \
    sudo dd of=/dev/sdb bs=4M
```

**Debug:**
```bash
xz -dc beagleplay-image-debug-*.wic.xz | \
    sudo dd of=/dev/sdb bs=4M
```

---

## 10. Key Takeaways

**Accomplished:**
1. ✅ Created custom production image
2. ✅ Created debug image variant
3. ✅ Managed package groups
4. ✅ Controlled image features
5. ✅ Configured rootfs size

**Skills Gained:**
- Image recipe structure
- Production vs. debug differentiation
- Package group organization
- License compliance

---

## 11. Verification Checklist

- [ ] `beagleplay-image-minimal.bb` builds successfully
- [ ] `beagleplay-image-debug.bb` builds successfully
- [ ] Debug image includes gdb, strace
- [ ] Production image excludes debug tools
- [ ] Both images boot on BeaglePlay
- [ ] License manifest generated

---

**End of Lab 16**

*The Guide rates this lab: **Mostly Harmless** ⭐⭐⭐⭐*

You can now create purpose-built images tailored to specific use cases, balancing functionality, security, and size requirements.
