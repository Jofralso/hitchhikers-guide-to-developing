# Submodule Planning

## Overview

This document defines the planned Git submodules for organizing different research domains.

## Submodule Architecture

Each submodule is an independent Git repository focused on a specific engineering domain.

## Planned Submodules

### 1. embedded-linux-labs [TODO]

Personal embedded Linux learning labs and experiments

### 2. yocto-projects [TODO]

Yocto Project build system research and custom distributions

### 3. linux-kernel-debugging [TODO]

Linux kernel debugging techniques and tools

### 4. device-drivers [TODO]

Linux device driver development

### 5. realtime-systems [TODO]

Real-time Linux (PREEMPT-RT, Xenomai)

### 6. build-systems [TODO]

CMake, Meson, Autotools research

### 7. devops-homelab [TODO]

Infrastructure automation and CI/CD pipeline

### 8. hardware-platforms [TODO]

SBC and microcontroller platform documentation

### 9. network-protocols [TODO]

Protocol implementation and analysis

### 10. system-performance [TODO]

Performance analysis and optimization

## Creation Priority

Recommended order:

1. hardware-platforms (foundation)
2. embedded-linux-labs (core skills)
3. build-systems (compilation understanding)
4. device-drivers (hardware interfacing)
5. linux-kernel-debugging (debugging capabilities)
6. yocto-projects (distribution building)
7. devops-homelab (automation)
8-10. Remaining domains as needed

---

**Last Updated**: November 2025

### 1. embedded-linux-labs

**Purpose**: Personal embedded Linux learning labs and experiments

**Scope**:
- Embedded Linux lab exercises and personal notes
- Custom board configurations and experiments
- Toolchain setup documentation
- Kernel compilation and deployment procedures
- Root filesystem creation techniques
- Device tree exploration and customization

**Structure**:
```
embedded-linux-labs/
├── README.md
├── labs/
│   ├── lab01-toolchain-setup/
│   ├── lab02-kernel-compilation/
│   ├── lab03-bootloader-config/
│   ├── lab04-rootfs-creation/
│   ├── lab05-device-drivers/
│   └── ...
├── notes/
│   ├── concepts/
│   └── references/
├── artifacts/
│   ├── configs/
│   ├── patches/
│   └── scripts/
└── hardware/
    └── platform-configs/
```

**Key Topics**:
- Cross-compilation toolchains (building from source, using pre-built)
- U-Boot configuration and customization
- Linux kernel configuration and compilation
- BusyBox-based filesystem construction
- Device tree bindings and modifications
- Network booting (TFTP, NFS root)
- Debugging embedded systems

---

### 2. yocto-projects

**Purpose**: Yocto Project build system research and custom distribution development

**Scope**:
- BitBake fundamentals
- Layer creation and management
- Recipe development
- Custom image definitions
- SDK generation
- Package management

**Structure**:
```
yocto-projects/
├── README.md
├── meta-custom/
│   ├── conf/
│   ├── recipes-core/
│   ├── recipes-apps/
│   └── recipes-kernel/
├── builds/
│   ├── minimal-image/
│   ├── development-image/
│   └── production-image/
├── documentation/
│   ├── layer-design.md
│   ├── recipe-writing.md
│   └── debugging-builds.md
└── scripts/
    └── build-automation/
```

**Key Topics**:
- BitBake execution model
- Recipe syntax and variables
- Layer dependencies
- Image customization
- Package feeds
- SDK deployment

---

### 3. linux-kernel-debugging

**Purpose**: Comprehensive Linux kernel debugging techniques and tools

**Scope**:
- Kernel module development
- Debugging methodologies
- Tracing and profiling
- Crash analysis
- Performance optimization
- Static and dynamic analysis

**Structure**:
```
linux-kernel-debugging/
├── README.md
├── techniques/
│   ├── printk-debugging/
│   ├── kgdb-setup/
│   ├── ftrace-tracing/
│   ├── perf-profiling/
│   └── ebpf-analysis/
├── case-studies/
│   ├── null-pointer-dereference/
│   ├── deadlock-analysis/
│   └── memory-leak-detection/
├── tools/
│   ├── scripts/
│   └── utilities/
├── modules/
│   └── example-drivers/
└── documentation/
    └── methodology.md
```

**Key Topics**:
- Dynamic debug and printk
- KGDB remote debugging
- Ftrace function tracing
- Perf event analysis
- eBPF programs
- Crash dump analysis with crash utility

---

### 4. device-drivers

**Purpose**: Linux device driver development and hardware interfacing

**Scope**:
- Character device drivers
- Platform drivers
- Device tree integration
- Interrupt handling
- DMA operations
- Driver frameworks

**Structure**:
```
device-drivers/
├── README.md
├── char-drivers/
│   ├── simple-char/
│   ├── ioctl-interface/
│   └── multiple-minors/
├── platform-drivers/
│   ├── gpio-driver/
│   ├── i2c-device/
│   └── spi-device/
├── devicetree/
│   ├── bindings/
│   └── examples/
├── frameworks/
│   ├── input-subsystem/
│   ├── iio-framework/
│   └── misc-devices/
└── documentation/
    └── driver-model.md
```

**Key Topics**:
- Module initialization
- File operations
- Device registration
- Platform bus
- Device tree bindings
- Kernel APIs

---

### 5. realtime-systems

**Purpose**: Real-time Linux investigation and deterministic behavior

**Scope**:
- PREEMPT-RT patch analysis
- Latency measurement and optimization
- Real-time scheduling
- Interrupt handling
- Comparison with alternatives

**Structure**:
```
realtime-systems/
├── README.md
├── preempt-rt/
│   ├── kernel-config/
│   ├── build-procedure/
│   └── optimization/
├── benchmarking/
│   ├── cyclictest/
│   ├── rt-tests/
│   └── custom-benchmarks/
├── analysis/
│   ├── latency-sources/
│   ├── irq-analysis/
│   └── scheduling-study/
├── alternatives/
│   ├── xenomai/
│   └── bare-metal-comparison/
└── documentation/
    └── real-time-concepts.md
```

**Key Topics**:
- RT patch configuration
- Threaded interrupts
- Priority inheritance
- CPU isolation
- Latency tracing

---

### 6. build-systems

**Purpose**: Study of modern build system tools and methodologies

**Scope**:
- CMake projects
- Meson builds
- Autotools analysis
- Make patterns
- Cross-platform builds

**Structure**:
```
build-systems/
├── README.md
├── cmake/
│   ├── basics/
│   ├── modern-patterns/
│   ├── cross-compilation/
│   └── package-config/
├── meson/
│   ├── projects/
│   └── cross-files/
├── make/
│   ├── patterns/
│   └── recursive-make/
├── autotools/
│   └── analysis/
└── documentation/
    └── comparison.md
```

**Key Topics**:
- Target-based builds
- Dependency management
- Toolchain files
- Out-of-tree builds
- Build optimization

---

### 7. devops-homelab

**Purpose**: Infrastructure automation and CI/CD pipeline for all research domains

**Scope**:
- Infrastructure as Code
- Container orchestration
- Automated testing
- Monitoring and logging
- Cross-compilation farm

**Structure**:
```
devops-homelab/
├── README.md
├── ARCHITECTURE.md
├── infrastructure/
│   ├── terraform/
│   ├── ansible/
│   └── docker-compose/
├── kubernetes/
│   ├── manifests/
│   └── helm-charts/
├── ci-cd/
│   ├── jenkins/
│   ├── gitlab-ci/
│   └── github-actions/
├── monitoring/
│   ├── prometheus/
│   ├── grafana/
│   └── loki/
├── networking/
│   ├── dns/
│   ├── reverse-proxy/
│   └── vpn/
└── documentation/
    ├── deployment-guide.md
    └── operations.md
```

**Key Topics**:
- Terraform infrastructure
- Ansible playbooks
- Docker containerization
- Kubernetes deployment
- Prometheus monitoring
- GitLab CI/CD pipelines

---

### 8. hardware-platforms

**Purpose**: Documentation and projects for all available SBC and microcontroller platforms

**Scope**:
- Platform-specific configurations
- Hardware interface documentation
- Benchmark comparisons
- Project implementations

**Structure**:
```
hardware-platforms/
├── README.md
├── INVENTORY.md
├── raspberry-pi/
│   ├── models/
│   ├── gpio-projects/
│   ├── configurations/
│   └── benchmarks/
├── beagleplay/
│   ├── getting-started/
│   ├── projects/
│   └── wireless-capabilities/
├── pico/
│   ├── micropython/
│   ├── c-sdk/
│   └── pio-examples/
├── arduino/
│   ├── projects/
│   └── libraries/
├── esp32/
│   ├── esp-idf/
│   ├── arduino-framework/
│   └── wifi-projects/
└── cross-platform/
    └── comparison-studies/
```

**Key Topics**:
- Platform specifications
- GPIO interfacing
- Communication protocols
- Power management
- Performance characteristics

---

### 9. network-protocols

**Purpose**: Protocol implementation, analysis, and network programming

**Scope**:
- Socket programming
- Protocol implementation
- Network analysis
- Performance testing

**Structure**:
```
network-protocols/
├── README.md
├── tcp-ip/
│   ├── socket-programming/
│   ├── packet-analysis/
│   └── performance-testing/
├── implementations/
│   ├── custom-protocols/
│   └── protocol-parsers/
├── analysis/
│   ├── wireshark-captures/
│   └── performance-studies/
└── documentation/
    └── protocol-design.md
```

**Key Topics**:
- Socket API
- TCP/UDP implementation
- Raw sockets
- Packet capture and analysis

---

### 10. system-performance

**Purpose**: System-level performance analysis and optimization

**Scope**:
- Profiling methodologies
- Performance metrics
- Optimization techniques
- Benchmarking

**Structure**:
```
system-performance/
├── README.md
├── profiling/
│   ├── cpu-profiling/
│   ├── memory-profiling/
│   └── io-profiling/
├── optimization/
│   ├── cache-optimization/
│   ├── memory-optimization/
│   └── compiler-optimization/
├── benchmarks/
│   ├── standard-benchmarks/
│   └── custom-benchmarks/
└── documentation/
    └── methodology.md
```

**Key Topics**:
- Perf analysis
- Cache analysis
- Memory profiling
- I/O performance

## Submodule Management

### Creation Workflow

1. Create independent repository on GitHub/GitLab
2. Initialize with README and basic structure
3. Add as submodule: `git submodule add <url> <path>`
4. Document in main repository README
5. Update ROADMAP with learning milestones

### Maintenance

- Each submodule maintains independent version control
- Main repository tracks specific commits of submodules
- Updates pulled selectively or collectively

### Integration Points

- Shared artifacts stored in main repository
- Cross-references documented in READMEs
- DevOps homelab integrates all domains

## Priority Order

Recommended creation sequence:

1. **hardware-platforms** - Foundation for all hardware work
2. **embedded-linux-labs** - Core embedded Linux skills
3. **build-systems** - Understanding compilation processes
4. **device-drivers** - Hardware interfacing
5. **linux-kernel-debugging** - Debugging capabilities
6. **yocto-projects** - Distribution building
7. **devops-homelab** - Automation infrastructure
8. **realtime-systems** - Advanced RT topics
9. **network-protocols** - Network programming
10. **system-performance** - Optimization techniques

---

**Document Version**: 1.0

**Last Updated**: November 2025

**Next Action**: Create hardware-platforms repository
