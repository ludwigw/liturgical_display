#!/bin/bash

# Setup ePdraw for e-ink display generation
# This script handles ePdraw installation and compilation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
EPDRAW_DIR="$PROJECT_ROOT/epdraw"

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

# Check if ePdraw directory exists
if [ -d "$EPDRAW_DIR" ]; then
    echo "📁 ePdraw directory exists"
    
    if [ "$FORCE_REBUILD" = "true" ]; then
        echo "🔄 Force rebuild requested, cleaning ePdraw..."
        rm -rf "$EPDRAW_DIR"
    else
        echo "✅ ePdraw already installed"
        exit 0
    fi
fi

# Clone ePdraw repository
echo "📥 Cloning ePdraw repository..."
git clone https://github.com/pech0rin/epdraw.git "$EPDRAW_DIR"

# Build ePdraw
echo "🔨 Building ePdraw..."
cd "$EPDRAW_DIR"
make clean
make

# Verify build
if [ -f "epdraw" ]; then
    echo "✅ ePdraw built successfully"
    chmod +x epdraw
else
    echo "❌ ePdraw build failed"
    exit 1
fi

echo "🎉 ePdraw setup complete!"
