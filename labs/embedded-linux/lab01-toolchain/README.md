# Lab 1: Toolchain Sanity Check

This lab verifies your C toolchain (compiler, linker) and build system.

## Tasks

- Build and run a minimal C program
- Inspect generated binary
- Cross-compile (optional) if you have a cross toolchain installed

## Steps

```sh
# Build
make
# Run
./bin/hello
# Inspect
file ./bin/hello
readelf -h ./bin/hello | sed -n '1,30p'
```

## Cross-Compile (Optional)

Set `CROSS_COMPILE` and `SYSROOT` appropriately, then:

```sh
make clean && make CROSS_COMPILE=aarch64-linux-gnu-
```
