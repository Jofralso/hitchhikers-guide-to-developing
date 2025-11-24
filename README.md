<!-- SHIELDS -->
<div align="center">

![GitHub last commit](https://img.shields.io/github/last-commit/Jofralso/hitchhikers-guide-to-developing)
![GitHub repo size](https://img.shields.io/github/repo-size/Jofralso/hitchhikers-guide-to-developing)
![GitHub stars](https://img.shields.io/github/stars/Jofralso/hitchhikers-guide-to-developing?style=social)
![GitHub forks](https://img.shields.io/github/forks/Jofralso/hitchhikers-guide-to-developing?style=social)
![License](https://img.shields.io/github/license/Jofralso/hitchhikers-guide-to-developing)

</div>

<!-- LOGO/HEADER -->
<div align="center">
  <h1>🚀 The Hitchhiker's Guide to Developing</h1>
  <h3>Don't Panic</h3>
  
  <p>
    A comprehensive, mostly accurate, and occasionally entertaining journey through<br>
    systems engineering, embedded development, and infrastructure automation.
  </p>
  
  <p>
    <a href="#the-guides-purpose"><strong>Explore the Guide »</strong></a>
    <br />
    <br />
    <a href="THE-JOURNEY.md">Read The Journey</a>
    ·
    <a href="ROADMAP.md">View Roadmap</a>
    ·
    <a href="https://github.com/Jofralso/hitchhikers-guide-to-developing/issues">Report Bug</a>
    ·
    <a href="https://github.com/Jofralso/hitchhikers-guide-to-developing/issues">Request Feature</a>
  </p>
</div>

---

<!-- TABLE OF CONTENTS -->
<details>
<summary>📚 Table of Contents</summary>

- [Purpose](#purpose)
- [Architecture](#architecture)
- [Planned Submodules](#chapters-in-the-guide-active-research-domains)
- [Focus Areas](#focus-areas)
- [Documentation Standards](#documentation-standards)
- [Getting Started](#getting-started)
- [Learning Path](#learning-path)
- [Research Methodology](#research-methodology)
- [Hardware Platforms](#hardware-platforms)
- [Current Status](#current-status)
- [Contributing](#contributing-mostly-harmless)
- [Support](#support-the-guide)
- [License](#license)

</details>

---

## Purpose

A meta-repository for organizing learning across multiple engineering domains using Git submodules. Each submodule represents a focused area of study.

**Read**: [THE-JOURNEY.md](THE-JOURNEY.md) for the philosophy behind this guide.

## Architecture

This repository aggregates multiple focused research areas as Git submodules. Each submodule is an independent repository with its own documentation and experiments.

### Chapters in the Guide (Active Research Domains)

```
hitchhikers-guide-to-developing/
├── embedded-linux-labs/       # Embedded Linux experiments and learning
├── yocto-projects/            # Yocto Project build system research and custom distributions
├── linux-kernel-debugging/    # Linux kernel debugging techniques and case studies
├── device-drivers/            # Linux device driver development
├── realtime-systems/          # Real-time Linux (PREEMPT-RT, Xenomai)
├── build-systems/             # CMake, Meson, Autotools research
├── devops-homelab/            # Infrastructure automation and CI/CD pipeline
├── hardware-platforms/        # SBC and microcontroller platform documentation
├── network-protocols/         # Protocol implementation and analysis
└── system-performance/        # Performance analysis and optimization
```

## Focus Areas

- Embedded Linux development and board bring-up
- Yocto Project and build systems
- Linux kernel development and debugging
- DevOps infrastructure automation
- Hardware platform integration

## Documentation Standards

- Clear technical writing
- Reproducible procedures
- Cited references
- Systematic methodology
- Document both successes and failures

## Repository Structure

```
.
├── README.md                  # This file
├── ARCHITECTURE.md            # Repository organization philosophy
├── ROADMAP.md                 # Learning path and milestones
├── BIBLIOGRAPHY.md            # Collected references and resources
├── docs/
│   ├── methodologies/         # Research and documentation methods
│   ├── standards/             # Coding and documentation standards
│   └── templates/             # Document templates
├── artifacts/
│   ├── configurations/        # Reusable configuration files
│   ├── scripts/              # Automation scripts
│   └── datasets/             # Benchmark and test data
└── [submodules]/             # Individual research domains
```

## Getting Started

### Prerequisites

- Linux host system (Ubuntu 22.04 LTS or equivalent)
- Git with submodule support
- Basic development tools (gcc, make, cmake)

### Clone Repository

```bash
git clone --recursive https://github.com/Jofralso/hitchhikers-guide-to-developing.git
cd hitchhikers-guide-to-developing
```

### Work with Submodules

```bash
# Initialize specific submodule
git submodule update --init <submodule-name>

# Update all submodules
git submodule update --remote --merge
```

## Learning Path

See [ROADMAP.md](ROADMAP.md) for the recommended learning progression and milestones.

## Contributing: Mostly Harmless

This is a personal research repository, but like the Hitchhiker's Guide itself, the methodologies and documentation are designed to be useful to other travelers navigating the cosmos of software development.

### Submodule Creation Workflow

1. Create independent repository for specific domain
2. Develop initial structure and documentation
3. Add as submodule to this meta-repository
4. Update this README with domain description

## Research Methodology

Each domain follows a structured approach:

1. Define objectives
2. Research background
3. Document procedures
4. Record observations
5. Analyze results
6. Draw conclusions

See `docs/templates/` for documentation templates.

## Hardware Platforms

Available hardware is documented in the `hardware-platforms/` submodule (to be created).

## Support the Guide

If this guide has helped you on your journey through the galaxy of software development, consider supporting its continued development:

<div align="center">

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Support%20The%20Guide-yellow.svg?style=for-the-badge&logo=buy-me-a-coffee)](https://buymeacoffee.com/jofralso)

**Or support through:**

[![GitHub Sponsors](https://img.shields.io/badge/GitHub%20Sponsors-Support-pink.svg?style=for-the-badge&logo=github)](https://github.com/sponsors/Jofralso)
[![PayPal](https://img.shields.io/badge/PayPal-Donate-blue.svg?style=for-the-badge&logo=paypal)](https://paypal.me/jofralso)

</div>

Your support helps maintain this guide, create more comprehensive documentation, and acquire hardware for testing across different platforms. Every contribution is appreciated and helps keep the guide freely available to all travelers through the development universe.

### What Your Support Enables

- 💻 Acquisition of additional hardware platforms for testing
- 📚 More comprehensive documentation and tutorials
- 🔬 Deeper research into advanced topics
- ⚡ Faster response to issues and questions
- 🌟 New chapters and research domains

---

## Current Status

**Phase**: Initial setup and planning

**Next Steps**:

- [TODO] Create first submodules
- [TODO] Begin domain-specific documentation
- [TODO] Set up development environment

---

## Acknowledgments

- Douglas Adams, for the inspiration
- The embedded Linux and open source communities
- All who document and share their knowledge

---

## Statistics

<div align="center">

![GitHub commit activity](https://img.shields.io/github/commit-activity/m/Jofralso/hitchhikers-guide-to-developing)
![GitHub contributors](https://img.shields.io/github/contributors/Jofralso/hitchhikers-guide-to-developing)

**Guide First Published**: November 2025

**Last Revision**: November 2025

**Answer to Life, the Universe, and Everything**: Still 42, but now we're documenting the questions

</div>

---

## License

MIT License - See [LICENSE](LICENSE) file for details.

This research is conducted for educational purposes. All external materials are properly attributed.

---

<div align="center">
  
**Remember: Don't Panic, Always Know Where Your Documentation Is**

Made with ☕ and a profound appreciation for towels

</div>
