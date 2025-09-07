#!/bin/bash

# Setup ePdraw for e-ink display generation
# This script handles ePdraw installation and compilation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
EPDRAW_SOURCE_DIR="$PROJECT_ROOT/IT8951-ePaper"
EPDRAW_BIN_DIR="$PROJECT_ROOT/bin"

# Parse command line arguments
FORCE_REBUILD=false
NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force-rebuild)
            FORCE_REBUILD=true
            shift
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--force-rebuild] [--non-interactive]"
            exit 1
            ;;
    esac
done

echo "🔧 Setting up ePdraw for e-ink display generation..."

# Check if epdraw binary already exists
if [ -f "$EPDRAW_BIN_DIR/epdraw" ]; then
    echo "📁 epdraw binary already exists in bin/"
    
    if [ "$FORCE_REBUILD" = "true" ]; then
        echo "🔄 Force rebuild requested, rebuilding epdraw..."
    else
        echo "✅ epdraw already installed"
        exit 0
    fi
fi

# Check if IT8951-ePaper source directory exists
if [ ! -d "$EPDRAW_SOURCE_DIR" ]; then
    echo "📥 Cloning IT8951-ePaper repository..."
    git clone https://github.com/ludwigw/IT8951-ePaper.git "$EPDRAW_SOURCE_DIR"
    cd "$EPDRAW_SOURCE_DIR"
    # No need to checkout refactir, use main
else
    echo "📁 IT8951-ePaper directory exists. Checking for updates..."
    cd "$EPDRAW_SOURCE_DIR"
    OLD_HEAD=$(git rev-parse HEAD)
    git fetch origin
    git pull origin main || true
    NEW_HEAD=$(git rev-parse HEAD)
    if [ "$OLD_HEAD" != "$NEW_HEAD" ]; then
        echo "IT8951-ePaper updated (HEAD changed). Rebuilding epdraw..."
        make clean
    else
        echo "IT8951-ePaper is up to date."
    fi
fi

# Build ePdraw
echo "🔨 Building epdraw..."
make bin/epdraw

# Create bin directory if it doesn't exist
mkdir -p "$EPDRAW_BIN_DIR"

# Copy epdraw to project bin directory
echo "📦 Copying epdraw to project bin directory..."
cp bin/epdraw "$EPDRAW_BIN_DIR/"

# Verify build
if [ -f "$EPDRAW_BIN_DIR/epdraw" ]; then
    echo "✅ epdraw built successfully and installed in bin/"
    chmod +x "$EPDRAW_BIN_DIR/epdraw"
else
    echo "❌ epdraw build failed"
    exit 1
fi

echo "🎉 ePdraw setup complete!"
