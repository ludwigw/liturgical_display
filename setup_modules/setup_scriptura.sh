#!/bin/bash

# Setup Scriptura API locally
# This script handles the enhanced Scriptura API installation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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

echo "🔧 Setting up Scriptura API locally..."

# Run the existing scriptura setup script
"$PROJECT_ROOT/setup_scriptura_local.sh"

echo "🎉 Scriptura API setup complete!"
