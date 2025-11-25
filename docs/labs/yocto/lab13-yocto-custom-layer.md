# Lab 13: Create a Custom Yocto Layer

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about Yocto:

*"The Yocto Project is a build system of such staggering complexity that it makes the Infinite Improbability Drive look straightforward. However, once you understand it (which will take approximately 42 tries), it's actually quite brilliant."*

## Objectives

Learn to organize recipes into custom layers for maintainability, reusability, and proper project structure following Yocto best practices.

**What You'll Learn:**
- Create custom meta-layers from scratch
- Configure layer priority and dependencies
- Organize recipes within layers
- Integrate layers into build configuration
- Move recipes between layers
- Understand layer indexing

**Time Required:** 1-2 hours

---

## Prerequisites

**Completed Labs:**
- Lab 10-12: Yocto basics and recipe writing

**Knowledge:**
- BitBake recipe structure
- Layer configuration concepts

---

## 1. Why Custom Layers?

### 1.1 Layer Organization Benefits

**Without layers:** All recipes mixed in meta/ or meta-poky/
- Hard to maintain
- Difficult to share
- No clear ownership
- Breaks on Yocto updates

**With custom layers:**
- ✅ Clear separation of concerns
- ✅ Easy to version control separately
- ✅ Shareable across projects
- ✅ Survives Yocto version upgrades
- ✅ Professional project structure

### 1.2 Layer Naming Convention

**Standard format:**
```
meta-<layername>
```

**Examples:**
- `meta-ti`: Texas Instruments BSP
- `meta-openembedded`: Community packages
- `meta-beagleplay`: Custom BeaglePlay layer (your project)

---

## 2. Creating a New Layer

### 2.1 Using bitbake-layers

**Navigate to layers directory:**
```bash
cd ~/yocto-labs
source poky/oe-init-build-env
cd ~/yocto-labs
```

**Create layer structure:**
```bash
bitbake-layers create-layer meta-beagleplay
```

**Output:**
```
NOTE: Starting bitbake server...
Add your new layer with 'bitbake-layers add-layer meta-beagleplay'
```

**Explore structure:**
```bash
cd meta-beagleplay
tree
```

**Generated structure:**
```
meta-beagleplay/
├── conf/
│   └── layer.conf
├── COPYING.MIT
├── README
└── recipes-example/
    └── example/
        └── example_0.1.bb
```

### 2.2 Configure Layer Metadata

**Edit README:**
```bash
nano README
```

**Content:**
```markdown
# meta-beagleplay

Custom Yocto layer for BeaglePlay development projects.

## Dependencies

This layer depends on:
- meta
- meta-oe
- meta-ti

## Contributing

Maintained by: Your Name
Contact: your.email@example.com
```

**Edit layer.conf:**
```bash
nano conf/layer.conf
```

**Review generated configuration:**
```python
# We have a conf and classes directory, add to BBPATH
BBPATH .= ":${LAYERDIR}"

# We have recipes-* directories, add to BBFILES
BBFILES += "${LAYERDIR}/recipes-*/*/*.bb \
            ${LAYERDIR}/recipes-*/*/*.bbappend"

BBFILE_COLLECTIONS += "meta-beagleplay"
BBFILE_PATTERN_meta-beagleplay = "^${LAYERDIR}/"
BBFILE_PRIORITY_meta-beagleplay = "7"

LAYERDEPENDS_meta-beagleplay = "core"
LAYERSERIES_COMPAT_meta-beagleplay = "scarthgap"
```

**Important variables:**
- `BBFILE_PRIORITY`: 7 (higher = higher priority, overrides lower layers)
- `LAYERSERIES_COMPAT`: Must match Yocto release ("scarthgap")
- `LAYERDEPENDS`: Declares required layers

---

## 3. Organizing Recipe Directories

### 3.1 Standard Directory Structure

**Create recipe categories:**
```bash
cd ~/yocto-labs/meta-beagleplay
mkdir -p recipes-core/packagegroups
mkdir -p recipes-games/ninvaders
mkdir -p recipes-kernel/linux
mkdir -p recipes-bsp/u-boot
mkdir -p recipes-graphics
mkdir -p recipes-connectivity
```

**Why categorize?**
- Easier navigation
- Clear purpose
- Matches upstream conventions
- Simplifies layer indexing

### 3.2 Layer Directory Conventions

| Directory | Purpose | Examples |
|-----------|---------|----------|
| `recipes-core/` | System essentials | init, base packages |
| `recipes-kernel/` | Kernel and modules | linux, kernel modules |
| `recipes-bsp/` | Board support | bootloaders, firmware |
| `recipes-graphics/` | GUI applications | Wayland, X11 apps |
| `recipes-connectivity/` | Networking | WiFi, Bluetooth tools |
| `recipes-games/` | Game applications | Your games |
| `recipes-extended/` | Optional packages | Development tools |

---

## 4. Moving Recipes to Custom Layer

### 4.1 Identify Current Recipe Location

```bash
cd ~/yocto-labs/build
bitbake-layers show-recipes ninvaders
```

**Output:**
```
ninvaders:
  meta-poky        0.1.1
```

Recipe is currently in `meta-poky` (not recommended).

### 4.2 Move nInvaders Recipe

**Copy recipe to custom layer:**
```bash
cd ~/yocto-labs
cp -r poky/meta-poky/recipes-extended/ninvaders \
     meta-beagleplay/recipes-games/
```

**Remove from meta-poky:**
```bash
rm -rf poky/meta-poky/recipes-extended/ninvaders
```

**Verify new location:**
```bash
cd ~/yocto-labs/build
bitbake-layers show-recipes ninvaders
```

**Expected error:**
```
Nothing PROVIDES 'ninvaders'
```

Layer not yet integrated!

---

## 5. Integrating Layer into Build

### 5.1 Add Layer to bblayers.conf

**Option 1: Manual edit**
```bash
nano conf/bblayers.conf
```

**Add line:**
```
BBLAYERS ?= " \
  ... (existing layers) ...
  /home/user/yocto-labs/meta-beagleplay \
"
```

**Option 2: Use bitbake-layers (recommended)**
```bash
bitbake-layers add-layer ~/yocto-labs/meta-beagleplay
```

**Output:**
```
NOTE: Starting bitbake server...
NOTE: Added layer '/home/user/yocto-labs/meta-beagleplay' to build/conf/bblayers.conf
```

### 5.2 Verify Layer Integration

```bash
bitbake-layers show-layers
```

**Output should include:**
```
layer                 path                                      priority
==================================================================================
...
meta-beagleplay       /home/user/yocto-labs/meta-beagleplay     7
```

**Check recipe now found:**
```bash
bitbake-layers show-recipes ninvaders
```

**Output:**
```
ninvaders:
  meta-beagleplay  0.1.1
```

✅ Success!

---

## 6. Creating Package Groups in Custom Layer

### 6.1 Create Games Package Group

```bash
cd ~/yocto-labs/meta-beagleplay
nano recipes-core/packagegroups/packagegroup-beagleplay-games.bb
```

**Content:**
```python
SUMMARY = "BeaglePlay games package group"
DESCRIPTION = "Collection of terminal-based games for BeaglePlay"
LICENSE = "MIT"

inherit packagegroup

RDEPENDS:${PN} = " \
    ninvaders \
"
```

### 6.2 Use Package Group in Image

**Edit local.conf:**
```bash
cd ~/yocto-labs/build
nano conf/local.conf
```

**Replace individual package with group:**
```
# Old:
# IMAGE_INSTALL:append = " ninvaders"

# New:
IMAGE_INSTALL:append = " packagegroup-beagleplay-games"
```

**Rebuild:**
```bash
bitbake core-image-minimal
```

---

## 7. Layer Dependencies

### 7.1 Declare Layer Dependencies

**Edit layer.conf:**
```bash
cd ~/yocto-labs/meta-beagleplay
nano conf/layer.conf
```

**Add dependencies:**
```python
LAYERDEPENDS_meta-beagleplay = " \
    core \
    openembedded-layer \
    meta-ti-bsp \
"
```

**Why declare dependencies?**
- BitBake validates required layers present
- Documents layer requirements
- Prevents cryptic build errors

### 7.2 Version Compatibility

**Ensure Yocto version compatibility:**
```python
LAYERSERIES_COMPAT_meta-beagleplay = "scarthgap"
```

**For multi-version support:**
```python
LAYERSERIES_COMPAT_meta-beagleplay = "kirkstone scarthgap"
```

---

## 8. Advanced Layer Management

### 8.1 Check Layer Dependencies

```bash
bitbake-layers show-layers
bitbake-layers check-layers
```

**Output (if OK):**
```
NOTE: All layers are compatible with the current Yocto version
```

### 8.2 Show Layer Recipes

**List all recipes in layer:**
```bash
bitbake-layers show-recipes -i meta-beagleplay
```

**Find overlayed recipes:**
```bash
bitbake-layers show-overlayed
```

Shows recipes provided by multiple layers.

### 8.3 Layer Priority Resolution

**When multiple layers provide same recipe:**
- Higher `BBFILE_PRIORITY` wins
- Same priority = first in `BBLAYERS` wins

**Check effective recipe:**
```bash
bitbake-layers show-recipes -b ninvaders
```

---

## 9. Version Control for Layers

### 9.1 Initialize Git Repository

```bash
cd ~/yocto-labs/meta-beagleplay
git init
git add .
git commit -m "Initial commit: meta-beagleplay layer"
```

### 9.2 Create .gitignore

```bash
nano .gitignore
```

**Content:**
```
# Temporary files
*.swp
*.swo
*~

# Build artifacts (should never be in layer)
tmp/
build/
```

### 9.3 Tag Releases

```bash
git tag -a v1.0 -m "Release 1.0 - BeaglePlay games support"
```

---

## 10. Layer Distribution

### 10.1 Create Distribution Script

**For easy layer sharing:**
```bash
cd ~/yocto-labs/meta-beagleplay
nano setup-layer.sh
```

**Content:**
```bash
#!/bin/bash
LAYER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Adding meta-beagleplay layer from: $LAYER_DIR"
bitbake-layers add-layer "$LAYER_DIR"
echo "Layer added successfully!"
```

```bash
chmod +x setup-layer.sh
```

**Usage:**
```bash
source poky/oe-init-build-env
../meta-beagleplay/setup-layer.sh
```

---

## 11. Going Further

### 11.1 Submit to Layer Index

Yocto maintains a searchable index: https://layers.openembedded.org/

**To submit:**
1. Host layer on public Git repository (GitHub, GitLab)
2. Submit via web form
3. Maintain layer compatibility

### 11.2 Create Multi-Layer Project

**Example structure:**
```
yocto-beagleplay/
├── poky/
├── meta-openembedded/
├── meta-ti/
├── meta-beagleplay/         # Board-specific
├── meta-beagleplay-apps/    # Application layer
└── meta-beagleplay-prod/    # Production configuration
```

---

## 12. Troubleshooting

**Problem:** `ERROR: Layer 'meta-beagleplay' has incompatible version`

**Solution:**
```python
# Update layer.conf
LAYERSERIES_COMPAT_meta-beagleplay = "scarthgap"
```

---

**Problem:** Recipe not found after adding layer

**Solution:**
```bash
# Verify layer path correct
bitbake-layers show-layers

# Check recipe directory structure
ls -R meta-beagleplay/recipes-*/

# Re-parse recipes
bitbake -e | grep BBFILES
```

---

**Problem:** Layer priority conflicts

**Solution:**
```bash
# Check priorities
bitbake-layers show-layers

# Adjust in layer.conf
BBFILE_PRIORITY_meta-beagleplay = "10"  # Higher priority
```

---

## 13. Key Takeaways

**Accomplished:**
1. ✅ Created professional layer structure
2. ✅ Organized recipes by category
3. ✅ Moved recipes to custom layer
4. ✅ Declared layer dependencies
5. ✅ Integrated layer into build
6. ✅ Created reusable package groups

**Best Practices Learned:**
- Never modify meta/ or meta-poky/
- Use custom layers for all customizations
- Version control layers separately
- Document layer dependencies
- Follow naming conventions

**Next Steps:**
- **Lab 14**: Extend recipes with bbappend
- **Lab 15**: Custom machine configurations
- **Lab 16**: Create custom distribution images

---

## 14. Verification Checklist

- [ ] `meta-beagleplay` layer created
- [ ] Layer added to `bblayers.conf`
- [ ] `bitbake-layers show-layers` includes meta-beagleplay
- [ ] ninvaders recipe moved to custom layer
- [ ] Package group created for games
- [ ] Layer priority set to 7
- [ ] Layer dependencies declared
- [ ] Build succeeds with custom layer
- [ ] Recipes organized in appropriate directories

**Success criteria:** Clean layer structure following Yocto conventions

---

**End of Lab 13**

*The Guide rates this lab: **Mostly Harmless** ⭐⭐⭐⭐*

Your recipes are now properly organized in a custom layer, ready for version control, sharing, and long-term maintenance. This professional structure will scale as your project grows.
