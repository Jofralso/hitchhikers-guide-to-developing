# Makefile for Lab 1 - Cross-Compilation Toolchain
#
# DON'T PANIC - This Makefile builds for both native (x86_64) and cross (ARM64)
#
# The Guide says: "A good Makefile is like a babel fish for build systems -
# it translates your intent into actions, regardless of the architecture."

# Compiler settings
CC_NATIVE = gcc
CC_CROSS = aarch64-linux-gnu-gcc

# Compiler flags
CFLAGS = -Wall -Wextra -std=c11 -O2
LDFLAGS =

# Source and build directories
SRC_DIR = src
BUILD_DIR = build

# Source files
SOURCES = $(wildcard $(SRC_DIR)/*.c)

# Targets
TARGET_NATIVE = $(BUILD_DIR)/hello-x86_64
TARGET_CROSS = $(BUILD_DIR)/hello-arm64
TARGET_CROSS_STATIC = $(BUILD_DIR)/hello-arm64-static

# Default target
.PHONY: all
all: native cross

# Create build directory
$(BUILD_DIR):
	@echo "Creating build directory..."
	@mkdir -p $(BUILD_DIR)

# Native compilation (runs on your PC)
.PHONY: native
native: $(BUILD_DIR)
	@echo "╔═══════════════════════════════════════════╗"
	@echo "║  Compiling for Native (x86_64)            ║"
	@echo "╚═══════════════════════════════════════════╝"
	$(CC_NATIVE) $(CFLAGS) $(SOURCES) -o $(TARGET_NATIVE) $(LDFLAGS)
	@echo "✓ Native binary created: $(TARGET_NATIVE)"
	@file $(TARGET_NATIVE)
	@echo ""

# Cross compilation (runs on BeaglePlay)
.PHONY: cross
cross: $(BUILD_DIR)
	@echo "╔═══════════════════════════════════════════╗"
	@echo "║  Cross-Compiling for ARM64 (BeaglePlay)   ║"
	@echo "╚═══════════════════════════════════════════╝"
	$(CC_CROSS) $(CFLAGS) $(SOURCES) -o $(TARGET_CROSS) $(LDFLAGS)
	@echo "✓ ARM64 binary created: $(TARGET_CROSS)"
	@file $(TARGET_CROSS)
	@echo ""

# Cross compilation with static linking (standalone binary)
.PHONY: cross-static
cross-static: $(BUILD_DIR)
	@echo "╔═══════════════════════════════════════════╗"
	@echo "║  Cross-Compiling for ARM64 (Static)       ║"
	@echo "╚═══════════════════════════════════════════╝"
	$(CC_CROSS) $(CFLAGS) -static $(SOURCES) -o $(TARGET_CROSS_STATIC) $(LDFLAGS)
	@echo "✓ ARM64 static binary created: $(TARGET_CROSS_STATIC)"
	@file $(TARGET_CROSS_STATIC)
	@echo ""

# Test native binary
.PHONY: test-native
test-native: native
	@echo "╔═══════════════════════════════════════════╗"
	@echo "║  Testing Native Binary                    ║"
	@echo "╚═══════════════════════════════════════════╝"
	@./$(TARGET_NATIVE)

# Test cross-compiled binary with QEMU
.PHONY: test-cross
test-cross: cross
	@echo "╔═══════════════════════════════════════════╗"
	@echo "║  Testing ARM64 Binary with QEMU           ║"
	@echo "╚═══════════════════════════════════════════╝"
	@if command -v qemu-aarch64 >/dev/null 2>&1; then \
		qemu-aarch64 -L /usr/aarch64-linux-gnu $(TARGET_CROSS); \
	else \
		echo "⚠ QEMU not installed. Install with:"; \
		echo "  sudo apt install qemu-user"; \
	fi

# Test static binary with QEMU (no library dependencies)
.PHONY: test-static
test-static: cross-static
	@echo "╔═══════════════════════════════════════════╗"
	@echo "║  Testing ARM64 Static Binary with QEMU    ║"
	@echo "╚═══════════════════════════════════════════╝"
	@if command -v qemu-aarch64 >/dev/null 2>&1; then \
		qemu-aarch64 $(TARGET_CROSS_STATIC); \
	else \
		echo "⚠ QEMU not installed. Install with:"; \
		echo "  sudo apt install qemu-user"; \
	fi

# Run all tests
.PHONY: test
test: test-native test-cross

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@echo "✓ Clean complete"

# Check if cross-compiler is installed
.PHONY: check-toolchain
check-toolchain:
	@echo "Checking for cross-compilation toolchain..."
	@if command -v $(CC_CROSS) >/dev/null 2>&1; then \
		echo "✓ $(CC_CROSS) found"; \
		$(CC_CROSS) --version | head -1; \
	else \
		echo "✗ $(CC_CROSS) not found"; \
		echo "  Install with: sudo apt install gcc-aarch64-linux-gnu"; \
		exit 1; \
	fi

# Display help
.PHONY: help
help:
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║  Lab 1: Cross-Compilation Toolchain - Build Targets      ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Available targets:"
	@echo "  make all              - Build both native and cross binaries"
	@echo "  make native           - Build for x86_64 (your PC)"
	@echo "  make cross            - Build for ARM64 (BeaglePlay)"
	@echo "  make cross-static     - Build static ARM64 binary"
	@echo "  make test             - Test both native and cross binaries"
	@echo "  make test-native      - Run native binary"
	@echo "  make test-cross       - Run ARM64 binary with QEMU"
	@echo "  make test-static      - Run static ARM64 binary with QEMU"
	@echo "  make check-toolchain  - Verify cross-compiler installation"
	@echo "  make clean            - Remove build artifacts"
	@echo "  make help             - Show this help"
	@echo ""
	@echo "DON'T PANIC - Start with 'make check-toolchain' first!"
	@echo ""

.DEFAULT_GOAL := help
