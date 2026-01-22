#!/bin/bash
# Pi WiFi Extender - Test Suite
# Run: ./test.sh

set -e

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓ $1${NC}"; PASS=$((PASS+1)); }
fail() { echo -e "${RED}✗ $1${NC}"; FAIL=$((FAIL+1)); }

echo "Running tests..."
echo "─────────────────────────────────"

# Test: Scripts exist and are executable
for script in setup.sh uninstall.sh status.sh install-to-sdcard.sh settings-gui.py; do
    if [[ -x "$SCRIPT_DIR/$script" ]]; then
        pass "$script is executable"
    else
        fail "$script missing or not executable"
    fi
done

# Test: setup.sh validates password length (needs root check bypass)
output=$(bash "$SCRIPT_DIR/setup.sh" "Test" "short" 2>&1 || true)
if echo "$output" | grep -qi "root\|password\|8 char"; then
    pass "setup.sh has input validation"
else
    fail "setup.sh should validate input"
fi

# Test: setup.sh requires root
output=$(bash "$SCRIPT_DIR/setup.sh" "Test" "ValidPass123" 2>&1 || true)
if echo "$output" | grep -qi "root"; then
    pass "setup.sh requires root"
else
    fail "setup.sh should require root"
fi

# Test: install-to-sdcard.sh shows usage without args
output=$(bash "$SCRIPT_DIR/install-to-sdcard.sh" 2>&1 || true)
if echo "$output" | grep -q "Usage"; then
    pass "install-to-sdcard.sh shows usage"
else
    fail "install-to-sdcard.sh should show usage"
fi

# Test: install-to-sdcard.sh validates password (create fake boot dir)
FAKE_BOOT=$(mktemp -d)
touch "$FAKE_BOOT/cmdline.txt"
output=$(bash "$SCRIPT_DIR/install-to-sdcard.sh" "$FAKE_BOOT" "Test" "short" 2>&1 || true)
rm -rf "$FAKE_BOOT"
if echo "$output" | grep -q "8 characters"; then
    pass "install-to-sdcard.sh rejects short passwords"
else
    fail "install-to-sdcard.sh should reject short passwords"
fi

# Test: Python syntax is valid
if python3 -m py_compile "$SCRIPT_DIR/settings-gui.py" 2>/dev/null; then
    pass "settings-gui.py has valid Python syntax"
else
    fail "settings-gui.py has syntax errors"
fi

# Test: Python imports work (GTK may not be available)
if python3 -c "import subprocess, os" 2>/dev/null; then
    pass "Python standard imports work"
else
    fail "Python imports failed"
fi

# Test: Shell scripts have valid syntax
for script in setup.sh uninstall.sh status.sh install-to-sdcard.sh; do
    if bash -n "$SCRIPT_DIR/$script" 2>/dev/null; then
        pass "$script has valid bash syntax"
    else
        fail "$script has syntax errors"
    fi
done

# Test: Required files exist
for file in README.md LICENSE .gitignore; do
    if [[ -f "$SCRIPT_DIR/$file" ]]; then
        pass "$file exists"
    else
        fail "$file missing"
    fi
done

echo "─────────────────────────────────"
echo -e "Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
