#!/usr/bin/env sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

log() { printf "[verify] %s\n" "$*"; }

# Verify Lab 1 - Toolchain
lab1() {
  log "Building Lab 1 (Toolchain)"
  cd "$ROOT_DIR/labs/embedded-linux/lab01-toolchain"
  make clean
  make
  ./bin/hello | grep -q "Hello, toolchain!" && log "Lab 1 run OK"
}

main() {
  lab1
  log "All selected labs verified."
}

main "$@"
