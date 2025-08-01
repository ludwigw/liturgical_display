#!/bin/bash
#
# setup_tailscale_funnel.sh - Setup script for Tailscale Funnel access
#
# This script helps configure Tailscale Funnel to make the liturgical display
# web server accessible from the internet through a secure tunnel.
#
# Usage: ./setup_tailscale_funnel.sh [OPTIONS]
#
# Options:
#   --hostname <name>    Specify the hostname for the funnel (e.g., "liturgical-display")
#   --port <port>        Specify the local port (default: 8080)
#   --help               Show this help message
#
# Prerequisites:
#   1. Tailscale installed and authenticated
#   2. Tailscale Funnel enabled on your account
#   3. Web server running on the specified port
#
# Author: Ludwig W
# Version: 1.0
# Date: 2025-01-08
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
HOSTNAME=""
PORT="8080"

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Setup Tailscale Funnel for the liturgical display web server.

OPTIONS:
    --hostname <name>    Specify the hostname for the funnel (e.g., "liturgical-display")
    --port <port>        Specify the local port (default: 8080)
    --help               Show this help message

EXAMPLES:
    $0 --hostname liturgical-display
    $0 --hostname my-liturgical --port 8080

PREREQUISITES:
    1. Tailscale installed and authenticated
    2. Tailscale Funnel enabled on your account
    3. Web server running on the specified port

For more information, see: https://tailscale.com/kb/1223/tailscale-funnel/
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --hostname)
            HOSTNAME="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

echo "🔧 Setting up Tailscale Funnel for liturgical display web server..."
echo "================================================"
echo ""
echo "This script will:"
echo "1. Check if Tailscale is installed and authenticated"
echo "2. Start Tailscale if it's offline"
echo "3. Verify the web server is running"
echo "4. Set up a secure funnel for remote access"
echo "5. Provide you with a public URL for your display"
echo ""

# Function to print status
print_status() {
    local status=$1
    local message=$2
    
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✅ $message${NC}"
    elif [ "$status" = "FAIL" ]; then
        echo -e "${RED}❌ $message${NC}"
    elif [ "$status" = "WARN" ]; then
        echo -e "${YELLOW}⚠️  $message${NC}"
    elif [ "$status" = "INFO" ]; then
        echo -e "${BLUE}ℹ️  $message${NC}"
    fi
}

# 1. Check if Tailscale is installed
echo ""
echo "1. Checking Tailscale installation..."
if command -v tailscale >/dev/null 2>&1; then
    print_status "PASS" "Tailscale is installed"
else
    print_status "FAIL" "Tailscale is not installed"
    echo ""
    echo "Please install Tailscale first:"
    echo "  curl -fsSL https://tailscale.com/install.sh | sh"
    echo "  sudo tailscale up"
    exit 1
fi

# 2. Check if Tailscale is authenticated and online
echo ""
echo "2. Checking Tailscale authentication and status..."
if tailscale status >/dev/null 2>&1; then
    print_status "PASS" "Tailscale is authenticated"
    
    # Check if Tailscale is online using multiple methods
    TAILSCALE_ONLINE=false
    
    # Method 1: Check if we have an IP address assigned
    TAILSCALE_IP=$(tailscale status --json 2>/dev/null | grep -o '"TailscaleIPs":\["[^"]*"' | head -1 | grep -o '"[^"]*"' | head -1 | tr -d '"')
    if [ -n "$TAILSCALE_IP" ] && [ "$TAILSCALE_IP" != "null" ]; then
        TAILSCALE_ONLINE=true
    fi
    
    # Method 2: Check if we can reach the Tailscale DNS
    if [ "$TAILSCALE_ONLINE" = false ]; then
        if ping -c 1 -W 2 100.100.100.100 >/dev/null 2>&1; then
            TAILSCALE_ONLINE=true
        fi
    fi
    
    if [ "$TAILSCALE_ONLINE" = true ]; then
        print_status "PASS" "Tailscale is online"
    else
        print_status "WARN" "Tailscale appears to be offline, attempting to start..."
        echo "Starting Tailscale..."
        if sudo tailscale up >/dev/null 2>&1; then
            print_status "PASS" "Tailscale started successfully"
            # Wait a moment for connection to establish
            sleep 3
        else
            print_status "FAIL" "Failed to start Tailscale"
            echo ""
            echo "Please start Tailscale manually:"
            echo "  sudo tailscale up"
            exit 1
        fi
    fi
else
    print_status "FAIL" "Tailscale is not authenticated"
    echo ""
    echo "Please authenticate Tailscale:"
    echo "  sudo tailscale up"
    exit 1
fi

# 3. Check if web server is running
echo ""
echo "3. Checking web server status..."
if curl -s http://localhost:$PORT/ >/dev/null 2>&1; then
    print_status "PASS" "Web server is running on port $PORT"
else
    print_status "WARN" "Web server is not responding on port $PORT"
    echo ""
    echo "Please start the web server first:"
    echo "  source venv/bin/activate"
    echo "  python3 -m liturgical_display.main"
    echo ""
    echo "Or run the web server directly:"
    echo "  source venv/bin/activate"
    echo "  python3 -m liturgical_display.web_server"
fi

# 4. Set default hostname (will be assigned by Tailscale)
if [ -z "$HOSTNAME" ]; then
    HOSTNAME="liturgical-display"
    echo ""
    echo "4. Using default hostname: $HOSTNAME"
    echo "Note: Tailscale will assign the actual hostname automatically"
fi

# 5. Check if Funnel is already running
echo ""
echo "5. Checking existing Funnel configuration..."
EXISTING_FUNNEL=$(tailscale funnel list 2>/dev/null | grep "$HOSTNAME" || echo "")
if [ -n "$EXISTING_FUNNEL" ]; then
    print_status "WARN" "Funnel for hostname '$HOSTNAME' already exists"
    echo "Existing configuration:"
    echo "$EXISTING_FUNNEL"
    echo ""
    echo "Do you want to update the existing funnel? (y/N)"
    read -r UPDATE_FUNNEL
    if [[ ! "$UPDATE_FUNNEL" =~ ^[Yy]$ ]]; then
        echo "Funnel setup cancelled."
        exit 0
    fi
fi

# 6. Verify Tailscale is fully connected
echo ""
echo "6. Verifying Tailscale connection..."
# Try multiple methods to check if Tailscale is online
TAILSCALE_ONLINE=false

# Method 1: Check if we can get status without errors
if tailscale status >/dev/null 2>&1; then
    # Method 2: Check if we have an IP address assigned
    TAILSCALE_IP=$(tailscale status --json 2>/dev/null | grep -o '"TailscaleIPs":\["[^"]*"' | head -1 | grep -o '"[^"]*"' | head -1 | tr -d '"')
    if [ -n "$TAILSCALE_IP" ] && [ "$TAILSCALE_IP" != "null" ]; then
        TAILSCALE_ONLINE=true
    fi
    
    # Method 3: Check if we can reach the Tailscale DNS
    if [ "$TAILSCALE_ONLINE" = false ]; then
        if ping -c 1 -W 2 100.100.100.100 >/dev/null 2>&1; then
            TAILSCALE_ONLINE=true
        fi
    fi
fi

if [ "$TAILSCALE_ONLINE" = false ]; then
    print_status "FAIL" "Tailscale is not online. Please check your connection."
    echo ""
    echo "Current Tailscale status:"
    tailscale status 2>/dev/null || echo "Could not get Tailscale status"
    echo ""
    echo "Try running: sudo tailscale up"
    exit 1
fi
print_status "PASS" "Tailscale is online and ready for funnel setup"

# 5. Check if Funnel is enabled on the account
echo ""
echo "5. Checking Funnel availability..."
FUNNEL_AVAILABLE=$(tailscale funnel list 2>/dev/null | head -1)
if [[ "$FUNNEL_AVAILABLE" == *"Funnel is not enabled"* ]] || [[ "$FUNNEL_AVAILABLE" == *"not enabled"* ]]; then
    print_status "FAIL" "Tailscale Funnel is not enabled on your account"
    echo ""
    echo "To enable Funnel on your account:"
    echo "1. Go to https://login.tailscale.com/admin/settings/keys"
    echo "2. Enable 'Tailscale Funnel'"
    echo "3. Try running this script again"
    exit 1
fi
print_status "PASS" "Funnel is available on your account"

# 6. Start the Funnel
echo ""
echo "6. Starting Tailscale Funnel..."
echo "Starting funnel for hostname: $HOSTNAME on port: $PORT"
echo "This may take a moment..."

# Start the funnel - use background flag to avoid hanging
FUNNEL_OUTPUT=""
FUNNEL_EXIT=1

# Use background flag to run funnel in background
echo "Starting funnel in background..."
FUNNEL_OUTPUT=$(sudo tailscale funnel --bg $PORT 2>&1)
FUNNEL_EXIT=$?

# Verify the funnel was actually created
if [ $FUNNEL_EXIT -eq 0 ]; then
    echo "Verifying funnel was created..."
    sleep 2
    
    # Check if the funnel appears in the list
    FUNNEL_VERIFIED=$(tailscale funnel list 2>/dev/null | grep -i "$PORT" || echo "")
    if [ -n "$FUNNEL_VERIFIED" ]; then
        print_status "PASS" "Tailscale Funnel started successfully"
        echo ""
        echo "🎉 Your liturgical display is now accessible at:"
        # Get the actual funnel URL from the status
        FUNNEL_URL=$(tailscale funnel status 2>/dev/null | grep -o 'https://[^[:space:]]*' || echo "")
        if [ -n "$FUNNEL_URL" ]; then
            echo "   $FUNNEL_URL"
        else
            echo "   https://your-hostname.your-tailnet.ts.net"
            echo "   (Check 'tailscale funnel status' for the exact URL)"
        fi
        echo ""
        echo "📋 Useful commands:"
        echo "   tailscale funnel list                    # List active funnels"
        echo "   tailscale funnel stop $HOSTNAME         # Stop this funnel"
        echo "   tailscale funnel $HOSTNAME:$PORT        # Restart this funnel"
        echo ""
        echo "🔒 Security notes:"
        echo "   - The funnel is only accessible to devices on your Tailnet"
        echo "   - You can control access through Tailscale ACLs"
        echo "   - The connection is encrypted end-to-end"
        echo ""
        echo "✅ Tailscale Funnel setup complete!"
    else
        print_status "WARN" "Funnel command succeeded but funnel not found in list"
        echo "Command output:"
        echo "$FUNNEL_OUTPUT"
        echo ""
        echo "Current funnel list:"
        tailscale funnel list 2>/dev/null || echo "Could not get funnel list"
        echo ""
        echo "The funnel may still be starting up. Try checking again in a moment:"
        echo "  tailscale funnel list"
        echo "  tailscale funnel status"
    fi
else
    print_status "FAIL" "Failed to start Tailscale Funnel"
    echo "Error output:"
    echo "$FUNNEL_OUTPUT"
    echo ""
    echo "Common issues:"
    echo "1. Funnel may not be enabled on your Tailscale account"
    echo "2. Hostname may already be in use"
    echo "3. Port may not be accessible"
    echo "4. Web server may not be running on the specified port"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check if web server is running: curl http://localhost:$PORT/"
    echo "2. Check funnel status: tailscale funnel status"
    echo "3. Check funnel list: tailscale funnel list"
    echo "4. Try manual funnel command: tailscale funnel $HOSTNAME:$PORT"
    exit 1
fi

echo ""
echo "Your liturgical display web server is now accessible from anywhere"
echo "through your secure Tailscale Funnel." 