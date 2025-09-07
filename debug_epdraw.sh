#!/bin/bash

# Debug ePdraw issues
# This script helps diagnose why ePdraw is failing

set -e

echo "🔍 ePdraw Diagnostic Script"
echo "=========================="

# Check for ePdraw binary in the expected location
EPDRAW_BINARY="bin/epdraw"

if [ -f "$EPDRAW_BINARY" ]; then
    echo "✅ Found ePdraw binary in bin/epdraw"
else
    echo "❌ ePdraw binary not found in bin/epdraw"
    echo "💡 Run: ./setup_modules/setup_main.sh --module epdraw --force-rebuild"
    exit 1
fi

# Check if epdraw is executable
if [ ! -x "$EPDRAW_BINARY" ]; then
    echo "❌ epdraw binary not executable"
    echo "💡 Fixing permissions..."
    chmod +x "$EPDRAW_BINARY"
    echo "✅ Fixed permissions"
fi

# Test epdraw with a simple command
echo "🧪 Testing epdraw..."

# Try to get version or help
if "$EPDRAW_BINARY" --help >/dev/null 2>&1; then
    echo "✅ epdraw responds to --help"
elif "$EPDRAW_BINARY" -h >/dev/null 2>&1; then
    echo "✅ epdraw responds to -h"
else
    echo "❌ epdraw doesn't respond to help flags"
    echo "🔍 Trying to run epdraw directly..."
    "$EPDRAW_BINARY" 2>&1 || echo "Exit code: $?"
    
    # Check if this is a build issue vs runtime issue
    if [ ! -f "IT8951-ePaper/bin/epdraw" ]; then
        echo ""
        echo "⚠️  epdraw binary not found in source directory"
        echo "💡 This usually means the build failed due to missing dependencies"
        echo "   - On Raspberry Pi: Install bcm2835 library"
        echo "   - On macOS: epdraw cannot be built (hardware-specific)"
        echo "   - For testing: Use Docker or mock epdraw"
    fi
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

# Check for bcm2835 library (Raspberry Pi specific)
if [ ! -f "/usr/include/bcm2835.h" ] && [ ! -f "/usr/local/include/bcm2835.h" ]; then
    missing_deps+=("libbcm2835-dev")
fi

if [ ${#missing_deps[@]} -gt 0 ]; then
    echo "❌ Missing dependencies: ${missing_deps[*]}"
    echo "💡 Install with: sudo apt-get install ${missing_deps[*]}"
    echo "   Note: epdraw requires Raspberry Pi hardware and bcm2835 library"
else
    echo "✅ All basic dependencies present"
fi

# Check file permissions
echo "🔍 Checking file permissions..."
ls -la "$EPDRAW_BINARY"

echo "🎉 ePdraw diagnostic complete!"
