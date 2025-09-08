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

# Skip systemd setup in CI environments
if [ "$CI" = "true" ] || [ "$GITHUB_ACTIONS" = "true" ]; then
    echo "CI environment detected, skipping systemd service and timer setup."
    exit 0
fi

# Check if user wants systemd setup
if [ "$NON_INTERACTIVE" = "true" ]; then
    ENABLE_SYSTEMD="${ENABLE_SYSTEMD:-Y}"
else
    echo ""
    echo "Do you want to schedule these to update daily using systemd? (Y/n)"
    read -r ENABLE_SYSTEMD
fi

if [ -z "$ENABLE_SYSTEMD" ] || [ "$ENABLE_SYSTEMD" = "Y" ] || [ "$ENABLE_SYSTEMD" = "y" ]; then
    echo "Installing and enabling systemd service and timer..."
    
    # Get current user for systemd service
    CURRENT_USER=$(whoami)
    echo "Using current user '$CURRENT_USER' for systemd services"
    
    # Install main service and timer
    echo "Installing main liturgical service and timer..."
    sed "s|{{PROJECT_DIR}}|$PROJECT_ROOT|g" "$PROJECT_ROOT/systemd/liturgical.service" | sed "s|{{USER}}|$CURRENT_USER|g" > /tmp/liturgical.service
    sudo cp /tmp/liturgical.service /etc/systemd/system/liturgical.service
    sudo cp "$PROJECT_ROOT/systemd/liturgical.timer" /etc/systemd/system/liturgical.timer
    sudo systemctl daemon-reload
    sudo systemctl enable liturgical.timer
    sudo systemctl start liturgical.timer
    echo "Systemd service and timer installed and enabled for daily runs."
    
    # Install and enable web server service
    echo "Installing and enabling web server service..."
    sed "s|{{PROJECT_DIR}}|$PROJECT_ROOT|g" "$PROJECT_ROOT/systemd/liturgical-web.service" | sed "s|User=pi|User=$CURRENT_USER|g" > /tmp/liturgical-web.service
    sudo cp /tmp/liturgical-web.service /etc/systemd/system/liturgical-web.service
    sudo systemctl daemon-reload
    sudo systemctl enable liturgical-web.service
    sudo systemctl start liturgical-web.service
    echo "Web server service installed and enabled for automatic startup."
    
    # Install Scriptura API service if local Scriptura was installed
    if [ -d "$PROJECT_ROOT/scriptura-api" ]; then
        echo "Installing Scriptura API systemd service..."
        
        # Fix ownership and permissions first
        echo "Setting proper ownership and permissions for Scriptura API..."
        sudo chown -R $CURRENT_USER:$CURRENT_USER $PROJECT_ROOT/scriptura-api/
        chmod -R 755 $PROJECT_ROOT/scriptura-api/
        
        # Stop existing service if running
        sudo systemctl stop scriptura-api.service 2>/dev/null || true
        
        # Create and install service file with proper security settings
        echo "Creating systemd service file with proper security settings..."
        sed "s|{{PROJECT_DIR}}|$PROJECT_ROOT|g" "$PROJECT_ROOT/systemd/scriptura-api.service" | sed "s|{{USER}}|$CURRENT_USER|g" > /tmp/scriptura-api.service
        sudo cp /tmp/scriptura-api.service /etc/systemd/system/scriptura-api.service
        
        # Reload systemd and start service
        sudo systemctl daemon-reload
        sudo systemctl enable scriptura-api.service
        sudo systemctl start scriptura-api.service
        
        # Wait a moment and check if it started successfully
        sleep 5
        if systemctl is-active --quiet scriptura-api.service; then
            echo "✅ Scriptura API service installed and started on port 8081"
        else
            echo "⚠️  Scriptura API service failed to start - checking logs..."
            sudo journalctl -u scriptura-api.service -n 5 --no-pager
            echo "   This may be due to security settings or missing dependencies"
        fi
    fi
    
    echo ""
    echo "🌐 SERVICES RUNNING:"
    echo "   - Web server: http://localhost:8080"
    if [ -d "$PROJECT_ROOT/scriptura-api" ]; then
        echo "   - Scriptura API: http://localhost:8081"
        echo "   - Scriptura docs: http://localhost:8081/docs"
    fi
    echo ""
    echo "📝 CONFIGURATION:"
    echo "   - Main config: config.yml"
    echo "   - Web server runs continuously"
    echo "   - Daily display updates via systemd timer"
    if [ -d "$PROJECT_ROOT/scriptura-api" ]; then
        echo "   - Local Scriptura API eliminates rate limiting"
    fi
    
    # Final verification
    echo ""
    echo "🔍 FINAL VERIFICATION:"
    if [ -d "$PROJECT_ROOT/scriptura-api" ]; then
        if systemctl is-active --quiet scriptura-api.service; then
            echo "   ✅ Scriptura API service is running"
            if curl -s --connect-timeout 5 "http://localhost:8081/api/versions" >/dev/null 2>&1; then
                echo "   ✅ Scriptura API is responding"
            else
                echo "   ⚠️  Scriptura API not responding (may need a moment to start)"
            fi
        else
            echo "   ❌ Scriptura API service is not running"
            echo "      Check logs: sudo journalctl -u scriptura-api.service -f"
        fi
    fi
    
    if systemctl is-active --quiet liturgical-web.service; then
        echo "   ✅ Web server service is running"
    else
        echo "   ❌ Web server service is not running"
    fi
else
    echo "Skipping systemd service and timer setup. You can enable it later by running these commands manually."
fi

echo "🎉 Systemd services setup complete!"
