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

# 2. Check if Tailscale is authenticated
echo ""
echo "2. Checking Tailscale authentication..."
if tailscale status >/dev/null 2>&1; then
    print_status "PASS" "Tailscale is authenticated"
    TAILSCALE_STATUS=$(tailscale status --json 2>/dev/null | grep -o '"Online":true' || echo "")
    if [ -n "$TAILSCALE_STATUS" ]; then
        print_status "PASS" "Tailscale is online"
    else
        print_status "WARN" "Tailscale appears to be offline"
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

# 4. Prompt for hostname if not provided
if [ -z "$HOSTNAME" ]; then
    echo ""
    echo "4. Setting up Funnel hostname..."
    echo "Please enter a hostname for your Tailscale Funnel (e.g., 'liturgical-display'):"
    echo "This will create a URL like: https://your-hostname.your-tailnet.ts.net"
    read -r HOSTNAME
    
    if [ -z "$HOSTNAME" ]; then
        print_status "FAIL" "Hostname is required"
        exit 1
    fi
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

# 6. Start the Funnel
echo ""
echo "6. Starting Tailscale Funnel..."
echo "Starting funnel for hostname: $HOSTNAME on port: $PORT"
echo "This may take a moment..."

# Start the funnel
FUNNEL_OUTPUT=$(tailscale funnel $HOSTNAME:$PORT 2>&1)
FUNNEL_EXIT=$?

if [ $FUNNEL_EXIT -eq 0 ]; then
    print_status "PASS" "Tailscale Funnel started successfully"
    echo ""
    echo "🎉 Your liturgical display is now accessible at:"
    echo "   https://$HOSTNAME.$(tailscale status --json 2>/dev/null | grep -o '"TailnetName":"[^"]*"' | cut -d'"' -f4).ts.net"
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
else
    print_status "FAIL" "Failed to start Tailscale Funnel"
    echo "Error output:"
    echo "$FUNNEL_OUTPUT"
    echo ""
    echo "Common issues:"
    echo "1. Funnel may not be enabled on your Tailscale account"
    echo "2. Hostname may already be in use"
    echo "3. Port may not be accessible"
    echo ""
    echo "To enable Funnel on your account:"
    echo "1. Go to https://login.tailscale.com/admin/settings/keys"
    echo "2. Enable 'Tailscale Funnel'"
    echo "3. Try running this script again"
    exit 1
fi

echo ""
echo "✅ Tailscale Funnel setup complete!"
echo ""
echo "Your liturgical display web server is now accessible from anywhere"
echo "through your secure Tailscale Funnel." 