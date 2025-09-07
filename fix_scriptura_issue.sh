#!/bin/bash

# Scriptura API Issue Fix Script
# This script fixes common Scriptura API setup issues

set -e

echo "🔧 Scriptura API Issue Fix Script"
echo "================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    local status=$1
    local message=$2
    case $status in
        "PASS") echo -e "${GREEN}✅ $message${NC}" ;;
        "FAIL") echo -e "${RED}❌ $message${NC}" ;;
        "WARN") echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "INFO") echo -e "${BLUE}ℹ️  $message${NC}" ;;
    esac
}

# Get current user and project directory
CURRENT_USER=$(whoami)
PROJECT_DIR=$(pwd)
echo "Current user: $CURRENT_USER"
echo "Project directory: $PROJECT_DIR"
echo ""

# 1. Fix ownership and permissions
echo "1. Fixing ownership and permissions..."
if [ -d "scriptura-api" ]; then
    print_status "INFO" "Fixing ownership of scriptura-api directory..."
    sudo chown -R $CURRENT_USER:$CURRENT_USER $PROJECT_DIR/scriptura-api/
    print_status "PASS" "Ownership fixed"
    
    print_status "INFO" "Setting proper permissions..."
    chmod -R 755 $PROJECT_DIR/scriptura-api/
    print_status "PASS" "Permissions set"
else
    print_status "WARN" "scriptura-api directory not found - will need to run setup"
fi

# 2. Check if scriptura-api is properly set up
echo ""
echo "2. Checking scriptura-api setup..."
if [ -d "scriptura-api" ]; then
    if [ ! -d "scriptura-api/venv" ]; then
        print_status "WARN" "Virtual environment missing - recreating..."
        cd scriptura-api
        python3 -m venv venv
        source venv/bin/activate
        pip install --upgrade pip
        pip install -r requirements.txt
        cd ..
        print_status "PASS" "Virtual environment recreated"
    else
        print_status "PASS" "Virtual environment exists"
    fi
    
    if [ ! -f "scriptura-api/.env" ]; then
        print_status "WARN" "Configuration file missing - creating..."
        cat > scriptura-api/.env << EOF
# Scriptura API Configuration
DATABASE_URL=sqlite:///./scriptura.db
API_KEY=local-dev-key-$(date +%s)
STRIPE_SECRET_KEY=sk_test_dummy
STRIPE_PUBLISHABLE_KEY=pk_test_dummy
CORS_ORIGINS=http://localhost:8080,http://127.0.0.1:8080
PORT=8081
EOF
        print_status "PASS" "Configuration file created"
    else
        print_status "PASS" "Configuration file exists"
    fi
else
    print_status "FAIL" "scriptura-api directory not found - need to run setup first"
    echo "Run: ./setup.sh"
    exit 1
fi

# 3. Fix systemd service file
echo ""
echo "3. Fixing systemd service file..."
if [ -f "systemd/scriptura-api.service" ]; then
    print_status "INFO" "Updating systemd service file..."
    
    # Create the service file with correct paths and user
    sed "s|{{PROJECT_DIR}}|$PROJECT_DIR|g" systemd/scriptura-api.service | sed "s|{{USER}}|$CURRENT_USER|g" > /tmp/scriptura-api.service
    
    # Install the service file
    sudo cp /tmp/scriptura-api.service /etc/systemd/system/scriptura-api.service
    print_status "PASS" "Service file updated"
    
    # Show the service file for verification
    echo "Service file contents:"
    cat /tmp/scriptura-api.service
    echo ""
    
    # Also check if the service file has the right security settings
    if grep -q "ProtectHome=false" /tmp/scriptura-api.service; then
        print_status "PASS" "Service file has correct security settings"
    else
        print_status "WARN" "Service file may have restrictive security settings"
    fi
else
    print_status "FAIL" "Service template not found"
    exit 1
fi

# 4. Reload and restart services
echo ""
echo "4. Reloading and restarting services..."
print_status "INFO" "Stopping scriptura-api service..."
sudo systemctl stop scriptura-api.service 2>/dev/null || true

print_status "INFO" "Reloading systemd..."
sudo systemctl daemon-reload

print_status "INFO" "Starting scriptura-api service..."
sudo systemctl start scriptura-api.service

print_status "INFO" "Enabling scriptura-api service..."
sudo systemctl enable scriptura-api.service

# 5. Wait a moment and check status
echo ""
echo "5. Checking service status..."
sleep 3

if systemctl is-active --quiet scriptura-api.service; then
    print_status "PASS" "Service is running"
else
    print_status "FAIL" "Service is not running"
    echo "Service logs:"
    sudo journalctl -u scriptura-api.service -n 10 --no-pager
fi

# 6. Test API connectivity
echo ""
echo "6. Testing API connectivity..."
sleep 2

if curl -s --connect-timeout 10 "http://localhost:8081/api/versions" >/dev/null 2>&1; then
    print_status "PASS" "Local API is responding"
    
    # Test a specific endpoint
    echo "Testing verse endpoint:"
    curl -s "http://localhost:8081/api/verse?book=Psalms&chapter=139&verse=1&version=asv" | head -c 100
    echo "..."
else
    print_status "FAIL" "Local API is not responding"
    echo "Checking port usage:"
    netstat -tlnp | grep ":8081" || echo "Port 8081 not in use"
fi

# 7. Check and fix config.yml
echo ""
echo "7. Checking and fixing config.yml..."
if [ -f "config.yml" ]; then
    if grep -q "scriptura:" config.yml; then
        print_status "PASS" "Scriptura configuration found in config.yml"
        
        if grep -q "use_local: true" config.yml; then
            print_status "PASS" "Config set to use local Scriptura"
        else
            print_status "WARN" "Config not set to use local Scriptura - updating..."
            sed -i.bak 's/use_local: false/use_local: true/' config.yml
            print_status "PASS" "Config updated to use local Scriptura"
        fi
    else
        print_status "FAIL" "No Scriptura configuration found - adding it..."
        
        # Add Scriptura configuration to config.yml
        cat >> config.yml << 'EOF'

# Scriptura API configuration
scriptura:
  use_local: true   # Set to true to use local Scriptura instance
  local_port: 8081  # Port for local Scriptura API
  version: "asv"    # Default Bible version
EOF
        print_status "PASS" "Scriptura configuration added to config.yml"
    fi
else
    print_status "FAIL" "config.yml not found"
fi

# Show the Scriptura section of config.yml
echo "Scriptura configuration in config.yml:"
grep -A 4 "scriptura:" config.yml || echo "No Scriptura section found"

# 8. Final status check
echo ""
echo "================================"
echo "🎯 FINAL STATUS CHECK"
echo "================================"

# Check if everything is working
ALL_GOOD=true

if [ ! -d "scriptura-api" ]; then
    print_status "FAIL" "scriptura-api directory missing"
    ALL_GOOD=false
fi

if [ ! -d "scriptura-api/venv" ]; then
    print_status "FAIL" "Virtual environment missing"
    ALL_GOOD=false
fi

if ! systemctl is-active --quiet scriptura-api.service; then
    print_status "FAIL" "Service not running"
    ALL_GOOD=false
fi

if ! curl -s --connect-timeout 5 "http://localhost:8081/api/versions" >/dev/null 2>&1; then
    print_status "FAIL" "Local API not responding"
    ALL_GOOD=false
fi

if [ "$ALL_GOOD" = true ]; then
    print_status "PASS" "All fixes applied successfully!"
    echo ""
    echo "🌐 Services should now be working:"
    echo "   - Scriptura API: http://localhost:8081"
    echo "   - Web server: http://localhost:8080"
    echo ""
    echo "🧪 Test the web interface to confirm readings are loading from local API"
else
    print_status "FAIL" "Some issues remain - check the output above"
    echo ""
    echo "🔧 Additional troubleshooting:"
    echo "1. Check service logs: sudo journalctl -u scriptura-api.service -f"
    echo "2. Check if port 8081 is in use: netstat -tlnp | grep 8081"
    echo "3. Try manual start: cd scriptura-api && source venv/bin/activate && uvicorn main:app --host 0.0.0.0 --port 8081"
fi
