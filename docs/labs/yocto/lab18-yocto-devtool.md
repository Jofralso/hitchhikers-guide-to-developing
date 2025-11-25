# Lab 18: Using devtool

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about debugging:

*"Debugging is the art of figuring out why your code doesn't work, as opposed to why you thought it would work. This is similar to the difference between what Deep Thought calculated (42) and what everyone expected (a useful answer). Both are technically correct, but only one is helpful."*

## Objectives

Master devtool for streamlined recipe development, modification, and upgrades with automated workflow management.

**What You'll Learn:**
- Use devtool for recipe creation
- Modify recipes in workspace
- Generate patches automatically
- Upgrade recipes to new versions
- Deploy changes to target
- Finalize recipes in layers

**Time Required:** 1-2 hours

---

## Prerequisites

**Completed Labs:**
- Lab 13-17: Custom layers, recipes, SDK

---

## 1. Understanding devtool

### 1.1 What is devtool?

**devtool** automates:
- Recipe creation from upstream sources
- Source code modification with patch generation
- Recipe upgrades to new versions
- Deploy to target for testing
- Integration back into layers

**Workspace concept:**
- Temporary layer for development
- Isolated from main layers
- Easy to finalize or discard

---

## 2. Creating Recipes with devtool

### 2.1 Add New Recipe

```bash
cd ~/yocto-labs/build
source ~/yocto-labs/poky/oe-init-build-env

devtool add --version 2.10 https://ftp.gnu.org/gnu/hello/hello-2.10.tar.gz
```

**Output:**
```
INFO: Creating workspace layer in .../build/workspace
INFO: Recipe .../workspace/recipes/hello/hello_2.10.bb has been created
```

### 2.2 Explore Workspace

```bash
tree workspace/ | head -20
```

**Structure:**
```
workspace/
├── appends/
│   └── hello_2.10.bbappend
├── conf/
│   └── layer.conf
├── recipes/
│   └── hello/
│       └── hello_2.10.bb
└── sources/
    └── hello/
        ├── configure
        ├── Makefile.in
        └── src/hello.c
```

**Key points:**
- `recipes/`: Generated recipe
- `sources/`: Editable source code
- `appends/`: Workspace-specific overrides

---

## 3. Building with devtool

### 3.1 Build Recipe

```bash
devtool build hello
```

**Sources from workspace, not downloads.**

### 3.2 Deploy to Target

```bash
devtool deploy-target hello root@192.168.0.100
```

**Installs directly on target over SSH.**

### 3.3 Test on Target

```bash
ssh root@192.168.0.100
hello
# Output: Hello, world!
```

---

## 4. Modifying Recipes

### 4.1 Edit Source Code

```bash
cd workspace/sources/hello
nano src/hello.c
```

**Change:**
```c
printf ("Hello from BeaglePlay!\n");
```

### 4.2 Rebuild and Deploy

```bash
devtool build hello
devtool deploy-target hello root@192.168.0.100
```

**Test:**
```bash
ssh root@192.168.0.100 hello
# Output: Hello from BeaglePlay!
```

### 4.3 Generate Patches

**Commit changes:**
```bash
cd workspace/sources/hello
git add src/hello.c
git commit -m "Customize hello message for BeaglePlay"
```

**Update recipe with patches:**
```bash
devtool update-recipe hello
```

**Patches automatically added to recipe!**

---

## 5. Upgrading Recipes

### 5.1 Upgrade to New Version

```bash
devtool upgrade hello --version 2.12
```

**devtool:**
- Downloads new version
- Updates recipe
- Applies existing patches (if compatible)
- Reports conflicts

### 5.2 Handle Upgrade Issues

**If patches fail:**
```bash
cd workspace/sources/hello
# Manually fix conflicts
git add .
git commit
```

**Update recipe:**
```bash
devtool update-recipe hello
```

---

## 6. Finalizing Recipes

### 6.1 Move to Layer

```bash
devtool finish hello ~/yocto-labs/meta-beagleplay
```

**Recipe moved to:**
```
meta-beagleplay/recipes-hello/hello/hello_2.10.bb
```

**Workspace cleaned up.**

### 6.2 Build from Layer

```bash
bitbake hello
```

**Now builds from meta-beagleplay, not workspace.**

---

## 7. Advanced devtool

### 7.1 Edit Existing Recipe

```bash
devtool modify ninvaders
```

**Opens in workspace for editing.**

### 7.2 Reset Workspace

```bash
devtool reset hello
```

**Removes from workspace, reverts to layer version.**

### 7.3 Status Overview

```bash
devtool status
```

**Lists all recipes in workspace.**

---

## 8. Key Takeaways

**Accomplished:**
1. ✅ Created recipes with devtool
2. ✅ Modified source code
3. ✅ Generated patches automatically
4. ✅ Upgraded recipes
5. ✅ Deployed to target for testing
6. ✅ Finalized recipes in layers

**Skills Gained:**
- Automated recipe development
- Patch generation workflow
- Recipe upgrade process
- Rapid iteration with deploy-target

---

## 9. Verification Checklist

- [ ] devtool add creates recipe
- [ ] devtool build succeeds
- [ ] devtool deploy-target installs on BeaglePlay
- [ ] Source modifications generate patches
- [ ] devtool finish moves recipe to layer
- [ ] Recipe builds from layer after finish

---

**End of Lab 18**

*The Guide rates this lab: **Mostly Harmless** ⭐⭐⭐⭐*

devtool revolutionizes recipe development with automated workflows, patch management, and seamless integration, making Yocto development faster and more reliable.

---

**End of Yocto Track (Labs 10-18)**

You've completed a comprehensive journey through the Yocto Project, from basic builds to advanced recipe development, custom layers, and professional SDK workflows. You're now equipped to build production-ready embedded Linux distributions.
