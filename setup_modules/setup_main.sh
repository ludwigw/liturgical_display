#!/bin/bash

# Individual module runner
# This script runs individual setup modules with consistent flags

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Parse command line arguments
MODULE=""
FORCE_REBUILD=false
NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --module)
            MODULE="$2"
            shift 2
            ;;
        --force-rebuild)
            FORCE_REBUILD=true
            shift
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        --help)
            echo "Usage: $0 --module MODULE_NAME [--force-rebuild] [--non-interactive]"
            echo ""
            echo "Available modules: epdraw, scriptura, services"
            echo ""
            echo "Examples:"
            echo "  $0 --module epdraw                    # Run ePdraw setup"
            echo "  $0 --module scriptura --force-rebuild # Force rebuild Scriptura"
            echo "  $0 --module services --non-interactive # Run services non-interactively"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

if [ -z "$MODULE" ]; then
    echo "❌ Module name required"
    echo "Use --help for usage information"
    exit 1
fi

echo "🔧 Running $MODULE module..."

# Run the specified module
ARGS=""
if [ "$FORCE_REBUILD" = "true" ]; then
    ARGS="$ARGS --force-rebuild"
fi
if [ "$NON_INTERACTIVE" = "true" ]; then
    ARGS="$ARGS --non-interactive"
fi

"$SCRIPT_DIR/setup_$MODULE.sh" $ARGS

echo "🎉 Module $MODULE completed successfully!"
