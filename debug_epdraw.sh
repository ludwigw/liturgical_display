#!/bin/bash

# Debug ePdraw issues
# This script helps diagnose why ePdraw is failing

set -e

EPDRAW_DIR="epdraw"

echo "🔍 ePdraw Diagnostic Script"
echo "=========================="

# Check if ePdraw directory exists
if [ ! -d "$EPDRAW_DIR" ]; then
    echo "❌ ePdraw directory not found"
    echo "💡 Run: ./setup_modules/setup_main.sh false epdraw true"
    exit 1
fi

echo "✅ ePdraw directory exists"

# Check if epdraw binary exists
if [ ! -f "$EPDRAW_DIR/epdraw" ]; then
    echo "❌ epdraw binary not found"
    echo "💡 Run: ./setup_modules/setup_main.sh false epdraw true"
    exit 1
fi

echo "✅ epdraw binary exists"

# Check if epdraw is executable
if [ ! -x "$EPDRAW_DIR/epdraw" ]; then
    echo "❌ epdraw binary not executable"
    echo "💡 Fixing permissions..."
    chmod +x "$EPDRAW_DIR/epdraw"
    echo "✅ Fixed permissions"
fi

# Test epdraw with a simple command
echo "🧪 Testing epdraw..."
cd "$EPDRAW_DIR"

# Try to get version or help
if ./epdraw --help >/dev/null 2>&1; then
    echo "✅ epdraw responds to --help"
elif ./epdraw -h >/dev/null 2>&1; then
    echo "✅ epdraw responds to -h"
else
    echo "❌ epdraw doesn't respond to help flags"
    echo "🔍 Trying to run epdraw directly..."
    ./epdraw 2>&1 || echo "Exit code: $?"
fi

# Check for missing dependencies
echo "🔍 Checking for common dependencies..."
missing_deps=()

if ! command -v gcc >/dev/null 2>&1; then
    missing_deps+=("gcc")
fi

if ! command -v make >/dev/null 2>&1; then
    missing_deps+=("make")
fi

if ! command -v git >/dev/null 2>&1; then
    missing_deps+=("git")
fi

if [ ${#missing_deps[@]} -gt 0 ]; then
    echo "❌ Missing dependencies: ${missing_deps[*]}"
    echo "💡 Install with: sudo apt-get install ${missing_deps[*]}"
else
    echo "✅ All basic dependencies present"
fi

# Check file permissions
echo "🔍 Checking file permissions..."
ls -la epdraw

echo "🎉 ePdraw diagnostic complete!"
