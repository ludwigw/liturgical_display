#!/bin/bash

# Setup systemd services
# This script handles systemd service installation and configuration

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

echo "🔧 Setting up systemd services..."

# Install liturgical-web service
echo "📦 Installing liturgical-web service..."
sudo cp "$PROJECT_ROOT/systemd/liturgical-web.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable liturgical-web.service

# Install scriptura-api service
echo "📦 Installing scriptura-api service..."
sudo cp "$PROJECT_ROOT/systemd/scriptura-api.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable scriptura-api.service

# Start services
echo "🚀 Starting services..."
sudo systemctl start scriptura-api.service
sudo systemctl start liturgical-web.service

echo "🎉 Systemd services setup complete!"
