# Lab 12: Add Custom Application

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about debugging:

*"Debugging is the art of figuring out why your code doesn't work, as opposed to why you thought it would work. This is similar to the difference between what Deep Thought calculated (42) and what everyone expected (a useful answer). Both are technically correct, but only one is helpful."*

## Objectives

Learn how to write Yocto recipes for custom applications, integrate third-party software, and handle build dependencies.

**What You'll Learn:**
- Write BitBake recipes from scratch
- Handle source downloads and checksums
- Manage build dependencies
- Cross-compile applications with Makefiles
- Integrate applications into rootfs images
- Debug recipe build failures

**Time Required:** 2-3 hours (or approximately 42 minutes in improbable circumstances)

---

## Prerequisites

**Completed Labs:**
- Lab 10: First Yocto Project Build
- Lab 11: Advanced Yocto Configuration

**Skills:**
- Understanding of Makefiles
- Basic C programming knowledge
- Familiarity with BitBake syntax

---

## 1. Understanding Yocto Recipes

### 1.1 What is a Recipe?

A **recipe** (`.bb` file) tells BitBake how to:
1. Fetch source code
2. Apply patches
3. Configure the build
4. Compile the software
5. Install binaries
6. Package results

**Recipe naming convention:**
```
<package-name>_<version>.bb
```

**Examples:**
- `busybox_1.36.1.bb`
- `dropbear_2022.83.bb`
- `ninvaders_0.1.1.bb`

### 1.2 Recipe Anatomy

**Minimal recipe structure:**
```python
# Metadata
SUMMARY = "Brief description"
DESCRIPTION = "Longer description"
HOMEPAGE = "https://project.org"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://LICENSE;md5=..."

# Source location
SRC_URI = "https://example.com/app-${PV}.tar.gz"
SRC_URI[sha256sum] = "..."

# Dependencies
DEPENDS = "ncurses"

# Build tasks (usually inherited or default)
inherit autotools  # or cmake, meson, etc.

# Custom tasks if needed
do_install:append() {
    install -d ${D}${bindir}
    install -m 0755 myapp ${D}${bindir}/
}
```

### 1.3 Common Recipe Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `PN` | Package name | `ninvaders` |
| `PV` | Package version | `0.1.1` |
| `S` | Source directory | `${WORKDIR}/ninvaders-${PV}` |
| `D` | Destination (install root) | `/path/to/image/` |
| `WORKDIR` | Recipe work directory | `tmp/work/.../ninvaders/0.1.1/` |
| `B` | Build directory | Usually same as `${S}` |
| `bindir` | Binary install path | `/usr/bin` |
| `libdir` | Library install path | `/usr/lib` |

**Variable expansion:**
- `${VAR}`: Reference variable
- `${@python_code}`: Inline Python

---

## 2. Project Selection: nInvaders

### 2.1 About nInvaders

**nInvaders** is a terminal-based Space Invaders clone using ncurses.

**Project details:**
- **Homepage:** https://ninvaders.sourceforge.net/
- **License:** GPL-2.0
- **Language:** C
- **Build system:** Make
- **Dependencies:** ncurses library

**Why this project?**
- Simple enough to understand
- Real-world build challenges (cross-compilation)
- Demonstrates dependency handling
- Fun to test!

### 2.2 Investigate Upstream Source

**Download and inspect:**
```bash
cd /tmp
wget http://downloads.sourceforge.net/ninvaders/ninvaders-0.1.1.tar.gz
tar -xzf ninvaders-0.1.1.tar.gz
cd ninvaders-0.1.1
```

**Check files:**
```bash
ls -l
# Output: COPYING  Makefile  README  aliens.c  aliens.h  globals.h  nInvaders.c  nInvaders.h  ufo.c  view.c
```

**Review license:**
```bash
head -20 COPYING
# GPL-2.0
```

**Examine Makefile:**
```bash
cat Makefile
```

**Key observations:**
```makefile
CC = gcc
CFLAGS = -O2
LIBS = -lncurses

all: nInvaders

nInvaders: $(OBJS)
	$(CC) $(CFLAGS) -o nInvaders $(OBJS) $(LIBS)

install: nInvaders
	cp nInvaders /usr/bin
```

**Issues for cross-compilation:**
- Hardcoded `gcc` (should use `${CC}` from environment)
- Install path not configurable (`/usr/bin` hardcoded)
- No `DESTDIR` support

We'll fix these in the recipe.

---

## 3. Creating the Recipe Structure

### 3.1 Recipe Location

**Recipes belong in layers.** For now, we'll add to `meta-poky` (not recommended for production, but simple for learning).

**Create recipe directory:**
```bash
cd ~/yocto-labs/poky
mkdir -p meta-poky/recipes-extended/ninvaders
```

**Why `recipes-extended`?**
- Yocto convention for non-core packages
- Other common directories: `recipes-core`, `recipes-kernel`, `recipes-graphics`, `recipes-connectivity`

### 3.2 Create Recipe File

```bash
cd ~/yocto-labs/poky/meta-poky/recipes-extended/ninvaders
nano ninvaders_0.1.1.bb
```

**Start with minimal metadata:**
```python
SUMMARY = "nInvaders - ncurses-based Space Invaders clone"
DESCRIPTION = "A terminal-based Space Invaders game using the ncurses library. \
Control your ship and defend against descending aliens!"
HOMEPAGE = "https://ninvaders.sourceforge.net/"
LICENSE = "GPL-2.0-only"

SRC_URI = "http://downloads.sourceforge.net/ninvaders/ninvaders-${PV}.tar.gz"
```

**Save and try to build:**
```bash
cd ~/yocto-labs/build
bitbake ninvaders
```

**Expected error:**
```
ERROR: ninvaders-0.1.1-r0 do_fetch: Fetcher failure: Unable to get checksum for ninvaders SRC_URI entry ninvaders-0.1.1.tar.gz: file could not be found
```

BitBake won't download without checksum verification (security feature).

---

## 4. Adding Checksums

### 4.1 Generate SHA256 Checksum

**On your workstation:**
```bash
wget http://downloads.sourceforge.net/ninvaders/ninvaders-0.1.1.tar.gz
sha256sum ninvaders-0.1.1.tar.gz
```

**Output (example):**
```
0e20b62aa8fe4a8e8ec977a5b3834f0648dd606c20c0aae903d9a96fc2aba16c  ninvaders-0.1.1.tar.gz
```

### 4.2 Update Recipe with Checksum

**Edit `ninvaders_0.1.1.bb`:**
```python
SUMMARY = "nInvaders - ncurses-based Space Invaders clone"
DESCRIPTION = "A terminal-based Space Invaders game using the ncurses library. \
Control your ship and defend against descending aliens!"
HOMEPAGE = "https://ninvaders.sourceforge.net/"
LICENSE = "GPL-2.0-only"

SRC_URI = "http://downloads.sourceforge.net/ninvaders/ninvaders-${PV}.tar.gz"
SRC_URI[sha256sum] = "0e20b62aa8fe4a8e8ec977a5b3834f0648dd606c20c0aae903d9a96fc2aba16c"
```

**Try building again:**
```bash
bitbake ninvaders
```

**New error:**
```
ERROR: ninvaders-0.1.1-r0 do_populate_lic: QA Issue: ninvaders: LIC_FILES_CHKSUM not specified for /path/to/sources
```

### 4.3 Add License Checksum

**License files must also be checksummed** to detect license changes.

**Check license file in extracted source:**
```bash
cd ~/yocto-labs/build/tmp/work/cortexa53-poky-linux/ninvaders/0.1.1-r0/ninvaders-0.1.1
cat COPYING | head -5
```

**Generate checksum:**
```bash
md5sum COPYING
# Output: 8ca43cbc842c2336e835926c2166c28b  COPYING
```

**Update recipe:**
```python
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=8ca43cbc842c2336e835926c2166c28b"
```

---

## 5. Handling Dependencies

### 5.1 Identify Runtime Dependencies

nInvaders uses **ncurses** for terminal graphics.

**Two types of dependencies:**
- **DEPENDS**: Build-time (headers, libraries needed during compilation)
- **RDEPENDS**: Runtime (binaries/libraries needed on target)

**For ncurses:**
```python
DEPENDS = "ncurses"
```

BitBake will build ncurses before ninvaders.

### 5.2 Full Recipe So Far

```python
SUMMARY = "nInvaders - ncurses-based Space Invaders clone"
DESCRIPTION = "A terminal-based Space Invaders game using the ncurses library. \
Control your ship and defend against descending aliens!"
HOMEPAGE = "https://ninvaders.sourceforge.net/"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=8ca43cbc842c2336e835926c2166c28b"

DEPENDS = "ncurses"

SRC_URI = "http://downloads.sourceforge.net/ninvaders/ninvaders-${PV}.tar.gz"
SRC_URI[sha256sum] = "0e20b62aa8fe4a8e8ec977a5b3834f0648dd606c20c0aae903d9a96fc2aba16c"
```

**Try building:**
```bash
bitbake -c cleanall ninvaders
bitbake ninvaders
```

**New error:**
```
ERROR: ninvaders-0.1.1-r0 do_compile: oe_runmake failed
...
multiple definition of `skill_level'
aliens.o:(.bss+0x674): first defined here
```

---

## 6. Fixing Compilation Issues

### 6.1 Understanding the Error

**GCC 10+ enforces stricter rules:**
- Multiple definitions of global variables across compilation units now error (previously just warnings)
- nInvaders code has this issue (old codebase)

**Solution:** Use `-fcommon` flag to revert to old behavior.

### 6.2 Add CFLAGS Override

**Update recipe:**
```python
SUMMARY = "nInvaders - ncurses-based Space Invaders clone"
DESCRIPTION = "A terminal-based Space Invaders game using the ncurses library. \
Control your ship and defend against descending aliens!"
HOMEPAGE = "https://ninvaders.sourceforge.net/"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=8ca43cbc842c2336e835926c2166c28b"

DEPENDS = "ncurses"

SRC_URI = "http://downloads.sourceforge.net/ninvaders/ninvaders-${PV}.tar.gz"
SRC_URI[sha256sum] = "0e20b62aa8fe4a8e8ec977a5b3834f0648dd606c20c0aae903d9a96fc2aba16c"

# Fix for GCC 10+ multiple definition errors
CFLAGS:append = " -fcommon"
```

**Try again:**
```bash
bitbake -c cleanall ninvaders
bitbake ninvaders
```

**New error:**
```
ERROR: ninvaders-0.1.1-r0 do_install: Function failed: do_install
...
make: *** No rule to make target 'install'.  Stop.
```

BitBake expects an `install` target, but nInvaders Makefile only has manual install.

---

## 7. Custom Install Task

### 7.1 Override do_install

**The `do_install` task** copies built files to staging area (`${D}`).

**Add to recipe:**
```python
do_install() {
    # Create binary directory
    install -d ${D}${bindir}
    
    # Install the nInvaders binary
    install -m 0755 ${B}/nInvaders ${D}${bindir}/ninvaders
}
```

**Explanation:**
- `install -d`: Create directory
- `${D}`: Destination root (rootfs staging area)
- `${bindir}`: `/usr/bin` (standard binary path)
- `install -m 0755`: Copy with executable permissions
- `${B}/nInvaders`: Source (built binary in build directory)
- Rename `nInvaders` → `ninvaders` (lowercase, Linux convention)

### 7.2 Full Working Recipe

```python
SUMMARY = "nInvaders - ncurses-based Space Invaders clone"
DESCRIPTION = "A terminal-based Space Invaders game using the ncurses library. \
Control your ship and defend against descending aliens!"
HOMEPAGE = "https://ninvaders.sourceforge.net/"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=8ca43cbc842c2336e835926c2166c28b"

DEPENDS = "ncurses"

SRC_URI = "http://downloads.sourceforge.net/ninvaders/ninvaders-${PV}.tar.gz"
SRC_URI[sha256sum] = "0e20b62aa8fe4a8e8ec977a5b3834f0648dd606c20c0aae903d9a96fc2aba16c"

# Fix for GCC 10+ multiple definition errors
CFLAGS:append = " -fcommon"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${B}/nInvaders ${D}${bindir}/ninvaders
}
```

**Build:**
```bash
bitbake -c cleanall ninvaders
bitbake ninvaders
```

**Should succeed!**

---

## 8. Integrating into Image

### 8.1 Add to IMAGE_INSTALL

**Edit `conf/local.conf`:**
```bash
nano conf/local.conf
```

**Add ninvaders:**
```
IMAGE_INSTALL:append = " ninvaders"
```

### 8.2 Rebuild Root Filesystem

```bash
bitbake core-image-minimal
```

**Only rebuilds rootfs assembly** - fast (1-2 minutes).

### 8.3 Deploy to NFS

```bash
cd ~/yocto-labs/build/tmp/deploy/images/beagleplay
sudo rm -rf /nfs/beagleplay/*
sudo tar -xf core-image-minimal-beagleplay.rootfs.tar.xz -C /nfs/beagleplay
sudo chown -R root:root /nfs/beagleplay
```

**Verify binary is included:**
```bash
find /nfs/beagleplay -name ninvaders
# Output: /nfs/beagleplay/usr/bin/ninvaders
```

---

## 9. Testing on Target

### 9.1 Boot BeaglePlay with NFS Root

**Boot sequence:**
1. Power on BeaglePlay
2. Wait for login prompt
3. Login as `root`

**Verify ninvaders is installed:**
```bash
which ninvaders
# Output: /usr/bin/ninvaders

ninvaders --version
# May not have --version, just run it
```

### 9.2 Run nInvaders

```bash
ninvaders
```

**You should see:**
```
  _   _   ___                     _               
 | \ | | |_ _|  _ __  __   ____ _| |   ___   _ _ 
 |  \| |  | |  | '_ \ \ \ / / _` | |  / _ \ | '_|
 | |\  |  | |  | | | | \ V / (_| | | |  __/ |
 |_| \_| |___| |_| |_|  \_/ \__,_|_|  \___| |_|

Press SPACE to start, Q to quit
```

**Controls:**
- Arrow keys: Move ship
- Space: Fire
- Q: Quit

**Play the game!** 🎮

---

## 10. Recipe Debugging

### 10.1 Explore Work Directory

**Recipe work directory:**
```bash
cd ~/yocto-labs/build/tmp/work/cortexa53-poky-linux/ninvaders/0.1.1-r0
ls -l
```

**Structure:**
```
ninvaders-0.1.1/    # Extracted sources (S variable)
temp/               # Build logs and scripts
image/              # Installed files (D variable)
package/            # Packaged files
deploy-debs/        # Binary packages (if using DEB)
```

### 10.2 Check Build Logs

**Compilation log:**
```bash
cat temp/log.do_compile
```

**Shows full compiler output** - useful for debugging build failures.

**Install log:**
```bash
cat temp/log.do_install
```

**All task logs:**
```bash
ls temp/log.do_*
# Output: log.do_compile  log.do_configure  log.do_fetch  log.do_install  log.do_package  ...
```

### 10.3 Examine Task Scripts

**BitBake generates shell scripts for each task:**
```bash
cat temp/run.do_compile
```

**Shows exactly what commands BitBake runs** - great for debugging.

### 10.4 Manual Build Testing

**Enter devshell (interactive build environment):**
```bash
bitbake -c devshell ninvaders
```

**Opens new terminal in build directory** with all environment variables set.

**Manually test commands:**
```bash
# In devshell
make clean
make
ls -l nInvaders
```

**Exit when done:**
```bash
exit
```

---

## 11. Advanced Recipe Techniques

### 11.1 Add Build Optimizations

**Customize Makefile variables:**
```python
EXTRA_OEMAKE = "'CC=${CC}' 'CFLAGS=${CFLAGS}' 'LDFLAGS=${LDFLAGS}'"
```

**This ensures cross-compilation toolchain is used.**

### 11.2 Apply Patches

**If you need to patch source code:**

**Create patch file:**
```bash
cd ~/yocto-labs/poky/meta-poky/recipes-extended/ninvaders
mkdir files
nano files/0001-fix-install-path.patch
```

**Add patch to SRC_URI:**
```python
SRC_URI = " \
    http://downloads.sourceforge.net/ninvaders/ninvaders-${PV}.tar.gz \
    file://0001-fix-install-path.patch \
"
```

BitBake automatically applies patches in `do_patch` task.

### 11.3 Add Configuration Options

**Use autotools classes for configure-based projects:**
```python
inherit autotools
```

**For CMake projects:**
```python
inherit cmake
```

**For Meson projects:**
```python
inherit meson
```

**nInvaders uses plain Makefile - no inheritance needed.**

### 11.4 Package Multiple Binaries

**If application has multiple binaries:**
```python
do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${B}/ninvaders ${D}${bindir}/
    install -m 0755 ${B}/ninvaders-server ${D}${bindir}/
}
```

### 11.5 Install Additional Files

**Install documentation:**
```python
do_install:append() {
    install -d ${D}${docdir}/${PN}
    install -m 0644 ${S}/README ${D}${docdir}/${PN}/
}
```

**Install configuration files:**
```python
do_install:append() {
    install -d ${D}${sysconfdir}
    install -m 0644 ${S}/config.conf ${D}${sysconfdir}/ninvaders.conf
}
```

---

## 12. Recipe Best Practices

### 12.1 Mandatory Variables

**Always define:**
- `SUMMARY`: Short description
- `HOMEPAGE`: Project URL
- `LICENSE`: SPDX identifier
- `LIC_FILES_CHKSUM`: License file checksum

**Recommended:**
- `DESCRIPTION`: Detailed description
- `SECTION`: Package category (games, utils, libs)
- `AUTHOR`: Package maintainer

### 12.2 Naming Conventions

**Recipe files:**
- `package-name_version.bb`
- Use lowercase
- Separate words with hyphens

**Version examples:**
- `ninvaders_0.1.1.bb` (specific version)
- `ninvaders_git.bb` (tracking Git HEAD)
- `ninvaders_1.0+gitAUTOINC.bb` (Git with auto-version)

### 12.3 License Identifiers

**Use SPDX standard:**
- `GPL-2.0-only` (not `GPLv2`)
- `MIT`
- `Apache-2.0`
- `BSD-3-Clause`

**Multiple licenses:**
```python
LICENSE = "GPL-2.0-only & MIT"
LIC_FILES_CHKSUM = " \
    file://COPYING.GPL;md5=... \
    file://LICENSE.MIT;md5=... \
"
```

### 12.4 Source URI Best Practices

**Prefer HTTPS over HTTP:**
```python
SRC_URI = "https://example.com/package-${PV}.tar.gz"
```

**Use mirrors for reliability:**
```python
SRC_URI = " \
    https://example.com/package-${PV}.tar.gz \
    https://mirror.example.org/package-${PV}.tar.gz \
"
```

**Git repositories:**
```python
SRC_URI = "git://github.com/user/project.git;protocol=https;branch=main"
SRCREV = "abc123def456..."  # Specific commit
```

---

## 13. Troubleshooting

### 13.1 Build Failures

**Problem:** `ERROR: <package> do_compile failed`

**Solutions:**
```bash
# Check compilation log
cat tmp/work/.../temp/log.do_compile

# Enter devshell to test manually
bitbake -c devshell <package>

# Clean and rebuild
bitbake -c cleanall <package>
bitbake <package>
```

---

**Problem:** Cross-compilation uses host compiler

**Solution:**
```python
# Ensure Makefile uses BitBake's CC
EXTRA_OEMAKE = "'CC=${CC}'"

# Or fix Makefile with patch
```

---

**Problem:** Library not found during linking

**Solution:**
```python
# Add library to DEPENDS
DEPENDS = "ncurses openssl zlib"

# Manually specify linker flags if needed
LDFLAGS:append = " -lmylib"
```

---

### 13.2 Checksum Mismatches

**Problem:** `Checksum mismatch for <file>`

**Solutions:**
```bash
# Upstream changed tarball - recalculate
wget <url>
sha256sum <file>

# Update SRC_URI[sha256sum]
```

---

**Problem:** License checksum mismatch

**Solution:**
```bash
# License file changed - update
cd tmp/work/.../package-version/package-version/
md5sum LICENSE

# Update LIC_FILES_CHKSUM
```

---

### 13.3 Installation Issues

**Problem:** `ERROR: <package> do_install failed`

**Solutions:**
```bash
# Check if Makefile has install target
grep -n install Makefile

# If not, implement custom do_install
do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${B}/binary ${D}${bindir}/
}
```

---

**Problem:** Installed files missing from package

**Solution:**
```bash
# Check what was installed
ls tmp/work/.../image/

# Check package contents
bitbake -e <package> | grep "^FILES:"
```

---

## 14. Going Further

### 14.1 Create Recipe for Another Application

**Try packaging a different application:**

**Example: htop (system monitor)**
- Homepage: https://htop.dev/
- Build system: Autotools
- Dependencies: ncurses

**Hints:**
```python
inherit autotools pkgconfig
DEPENDS = "ncurses"
```

### 14.2 Package from Git

**Recipe for Git repository:**
```python
SRC_URI = "git://github.com/user/project.git;protocol=https;branch=main"
SRCREV = "${AUTOREV}"  # Always use latest (not recommended for production)
PV = "1.0+git${SRCPV}"
```

**Pin to specific commit (recommended):**
```python
SRCREV = "abc123def456789..."
```

### 14.3 Multi-Package Recipes

**Split binary and libraries:**
```python
PACKAGES =+ "${PN}-libs"

FILES:${PN}-libs = "${libdir}/lib*.so.*"
FILES:${PN} = "${bindir}/*"
```

### 14.4 Runtime Package Recommendations

**Suggest optional packages:**
```python
RRECOMMENDS:${PN} = "package-data package-docs"
```

Installed if available, but not required.

---

## 15. Key Takeaways

**What You Accomplished:**
1. ✅ Wrote a complete BitBake recipe from scratch
2. ✅ Handled source downloads with checksums
3. ✅ Managed build dependencies
4. ✅ Fixed cross-compilation issues
5. ✅ Implemented custom install task
6. ✅ Integrated application into rootfs image
7. ✅ Tested on hardware

**Recipe Development Skills:**
- Checksum generation (SHA256, MD5)
- License compliance
- Dependency declaration
- Build customization (CFLAGS, LDFLAGS)
- Installation scripting
- Debugging techniques

**Next Steps:**
- **Lab 13**: Organize recipes into custom layers
- **Lab 14**: Extend existing recipes with bbappend
- **Lab 15**: Create custom machine configurations

---

## 16. Verification Checklist

**Before proceeding to Lab 13, verify:**

- [ ] `ninvaders_0.1.1.bb` recipe builds without errors
- [ ] `bitbake ninvaders` completes successfully
- [ ] Binary installed in rootfs at `/usr/bin/ninvaders`
- [ ] nInvaders runs on BeaglePlay hardware
- [ ] Understand recipe metadata (LICENSE, HOMEPAGE, etc.)
- [ ] Understand checksums (SRC_URI, LIC_FILES_CHKSUM)
- [ ] Can navigate recipe work directory
- [ ] Can read build logs (temp/log.do_*)
- [ ] Understand do_install task

**Build time:** ~5 minutes  
**Recipe lines:** ~20 lines  
**Success criteria:** Playable game on target hardware

---

## 17. Complete Recipe Reference

**Final `ninvaders_0.1.1.bb`:**
```python
SUMMARY = "nInvaders - ncurses-based Space Invaders clone"
DESCRIPTION = "A terminal-based Space Invaders game using the ncurses library. \
Control your ship and defend against descending aliens!"
HOMEPAGE = "https://ninvaders.sourceforge.net/"
SECTION = "games"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=8ca43cbc842c2336e835926c2166c28b"

DEPENDS = "ncurses"

SRC_URI = "http://downloads.sourceforge.net/ninvaders/ninvaders-${PV}.tar.gz"
SRC_URI[sha256sum] = "0e20b62aa8fe4a8e8ec977a5b3834f0648dd606c20c0aae903d9a96fc2aba16c"

# Fix for GCC 10+ multiple definition errors
CFLAGS:append = " -fcommon"

# Ensure cross-compiler is used
EXTRA_OEMAKE = "'CC=${CC}' 'CFLAGS=${CFLAGS} -I${STAGING_INCDIR}' 'LDFLAGS=${LDFLAGS}'"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${B}/nInvaders ${D}${bindir}/ninvaders
}
```

---

## 18. Additional Resources

**Yocto Recipe Writing:**
- BitBake User Manual - Syntax: https://docs.yoctoproject.org/bitbake/user-manual/
- Yocto Dev Manual - Writing Recipes: https://docs.yoctoproject.org/dev-manual/new-recipe.html
- Variable Reference: https://docs.yoctoproject.org/ref-manual/variables.html

**OpenEmbedded Layers:**
- Layer Index (search existing recipes): https://layers.openembedded.org/
- Recipe Style Guide: https://www.openembedded.org/wiki/Styleguide

**Debugging:**
- BitBake Logging: https://docs.yoctoproject.org/dev-manual/debugging.html
- Devshell Usage: https://docs.yoctoproject.org/dev-manual/dev-manual-common-tasks.html#using-a-development-shell

---

**End of Lab 12**

*The Guide rates this lab: **Mostly Harmless** ⭐⭐⭐⭐*

You can now create BitBake recipes for custom applications, handle dependencies, and integrate software into Yocto-based Linux distributions. The next lab will teach you how to organize recipes into proper layers for maintainability and reusability.
