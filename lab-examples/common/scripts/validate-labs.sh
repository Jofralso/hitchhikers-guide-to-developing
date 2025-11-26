#!/bin/bash
#
# validate-labs.sh - Validate lab documentation and code examples
#
# DON'T PANIC - This script checks that all labs are properly structured
#
# The Guide says: "A good validation script is like a paranoid android -
# it checks everything, assumes nothing, and reports problems with 
# excruciating detail."

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Functions
print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Lab Validation - DON'T PANIC                  ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_pass() {
    local message="$1"
    ((TOTAL_CHECKS++))
    ((PASSED_CHECKS++))
    echo -e "${GREEN}✓${NC} $message"
}

check_fail() {
    local message="$1"
    ((TOTAL_CHECKS++))
    ((FAILED_CHECKS++))
    echo -e "${RED}✗${NC} $message"
}

check_warn() {
    local message="$1"
    echo -e "${YELLOW}⚠${NC} $message"
}

check_file_exists() {
    local file="$1"
    local description="$2"
    
    if [ -f "$file" ]; then
        check_pass "$description: $file"
        return 0
    else
        check_fail "$description: $file (NOT FOUND)"
        return 1
    fi
}

check_dir_exists() {
    local dir="$1"
    local description="$2"
    
    if [ -d "$dir" ]; then
        check_pass "$description: $dir"
        return 0
    else
        check_fail "$description: $dir (NOT FOUND)"
        return 1
    fi
}

check_makefile() {
    local makefile="$1"
    local lab="$2"
    
    if [ ! -f "$makefile" ]; then
        check_fail "$lab: Makefile not found"
        return 1
    fi
    
    # Check for required targets
    local required_targets=("all" "clean" "help")
    local missing_targets=()
    
    for target in "${required_targets[@]}"; do
        if ! grep -q "^${target}:" "$makefile" && ! grep -q "^\.PHONY:.*${target}" "$makefile"; then
            missing_targets+=("$target")
        fi
    done
    
    if [ ${#missing_targets[@]} -eq 0 ]; then
        check_pass "$lab: Makefile has required targets"
    else
        check_fail "$lab: Makefile missing targets: ${missing_targets[*]}"
        return 1
    fi
    
    return 0
}

check_lab_readme() {
    local readme="$1"
    local lab="$2"
    
    if [ ! -f "$readme" ]; then
        check_fail "$lab: README.md not found"
        return 1
    fi
    
    # Check for required sections
    local required_sections=(
        "DON'T PANIC"
        "Prerequisites"
        "Quick Start"
    )
    
    local missing_sections=()
    
    for section in "${required_sections[@]}"; do
        if ! grep -qi "$section" "$readme"; then
            missing_sections+=("$section")
        fi
    done
    
    if [ ${#missing_sections[@]} -eq 0 ]; then
        check_pass "$lab: README.md has required sections"
    else
        check_warn "$lab: README.md missing recommended sections: ${missing_sections[*]}"
    fi
    
    return 0
}

# Main validation
print_header

echo "Validating lab structure..."
echo ""

# Check main lab-examples directory
echo "=== Checking Lab Examples Structure ==="
check_dir_exists "lab-examples" "Main lab-examples directory"
check_file_exists "lab-examples/README.md" "Main README"
echo ""

# Check Embedded Linux labs
echo "=== Checking Embedded Linux Labs ==="
LAB_DIR="lab-examples/embedded-linux"

if [ -d "$LAB_DIR" ]; then
    # Lab 1 - Toolchain
    LAB="Lab 1 (Toolchain)"
    LAB_PATH="$LAB_DIR/lab01-toolchain"
    
    if [ -d "$LAB_PATH" ]; then
        check_dir_exists "$LAB_PATH" "$LAB directory"
        check_file_exists "$LAB_PATH/README.md" "$LAB README"
        check_file_exists "$LAB_PATH/Makefile" "$LAB Makefile"
        check_dir_exists "$LAB_PATH/src" "$LAB source directory"
        check_file_exists "$LAB_PATH/src/hello.c" "$LAB source code"
        check_makefile "$LAB_PATH/Makefile" "$LAB"
        check_lab_readme "$LAB_PATH/README.md" "$LAB"
    else
        check_fail "$LAB: Directory not found"
    fi
    
    echo ""
    
    # Add more labs here as they are created
    # Lab 2, Lab 3, etc.
    
else
    check_fail "Embedded Linux labs directory not found"
fi

# Check for common utilities
echo "=== Checking Common Utilities ==="
check_dir_exists "lab-examples/common" "Common utilities directory"
echo ""

# Summary
echo "╔════════════════════════════════════════════════╗"
echo "║  Validation Summary                            ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "Total checks:  $TOTAL_CHECKS"
echo -e "${GREEN}Passed:       $PASSED_CHECKS${NC}"

if [ $FAILED_CHECKS -gt 0 ]; then
    echo -e "${RED}Failed:       $FAILED_CHECKS${NC}"
else
    echo -e "${GREEN}Failed:       $FAILED_CHECKS${NC}"
fi

echo ""

if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ All validation checks passed!              ║${NC}"
    echo -e "${GREEN}║                                                ║${NC}"
    echo -e "${GREEN}║  DON'T PANIC - Everything looks good!         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ✗ Validation failed with $FAILED_CHECKS error(s)           ║${NC}"
    echo -e "${RED}║                                                ║${NC}"
    echo -e "${RED}║  Please fix the issues above.                  ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════╝${NC}"
    exit 1
fi
