# Lab Example Code

This directory contains working code examples for all labs in the Hitchhiker's Guide to Embedded Linux.

## DON'T PANIC

The Guide has this to say about example code:

*"Example code is a bit like a towel - you should always know where yours is. More importantly, it should actually work, which is why all examples here are tested automatically via CI/CD. This ensures that when you follow a lab, you won't end up like Arthur Dent trying to make tea in space - frustrated and confused."*

## Structure

```
lab-examples/
├── embedded-linux/          # Labs 1-9 examples
│   ├── lab01-toolchain/
│   ├── lab02-hardware/
│   ├── lab03-bootloader/
│   ├── lab04-kernel/
│   ├── lab05-rootfs/
│   ├── lab06-hardware-devices/
│   ├── lab07-filesystems/
│   ├── lab08-buildroot/
│   └── lab09-application-dev/
├── yocto/                   # Labs 10-18 examples
│   ├── lab10-first-build/
│   ├── lab11-advanced-config/
│   └── ...
├── debugging/               # Labs 19-26 examples
│   ├── lab19-monitoring/
│   ├── lab20-gdb/
│   └── ...
└── common/                  # Shared utilities
    ├── scripts/
    └── configs/
```

## Usage

Each lab directory contains:
- **README.md** - Lab-specific instructions
- **src/** - Source code
- **scripts/** - Helper scripts
- **configs/** - Configuration files
- **Makefile** - Build automation

### Quick Start

```bash
# Navigate to a lab
cd embedded-linux/lab01-toolchain

# Read the README
cat README.md

# Build examples
make

# Clean
make clean
```

## Testing

All examples are automatically tested via GitHub Actions:
- ✅ Code compiles without errors
- ✅ Scripts execute successfully
- ✅ Configuration files are valid
- ✅ Cross-compilation works (where applicable)

See `.github/workflows/test-lab-examples.yml` for CI/CD configuration.

## Platform Support

Examples are primarily tested on:
- **Host**: Ubuntu 24.04 LTS (x86_64)
- **Target**: BeaglePlay (TI AM62x, ARM64)
- **Cross-compiler**: aarch64-linux-gnu-gcc

## Contributing

When adding new examples:
1. Follow the directory structure
2. Include a README.md
3. Add a Makefile with `all` and `clean` targets
4. Ensure code compiles with `-Wall -Wextra`
5. Test on actual hardware when possible

## License

MIT License - Same as parent repository

---

**Remember**: The answer to "How many examples should I test?" is always 42.

*Part of the [Hitchhiker's Guide to Developing](https://github.com/Jofralso/hitchhikers-guide-to-developing)*
