#!/bin/bash

# Scriptura API Issue Analysis Script
# This script analyzes the Scriptura API setup and identifies issues

set -e

echo "🔍 Scriptura API Issue Analysis"
echo "================================"

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

# 1. Check if scriptura-api directory exists
echo "1. Checking scriptura-api directory..."
if [ -d "scriptura-api" ]; then
    print_status "PASS" "scriptura-api directory exists"
    
    # Check ownership
    OWNER=$(stat -c '%U' scriptura-api)
    if [ "$OWNER" = "$CURRENT_USER" ]; then
        print_status "PASS" "Directory owned by $CURRENT_USER"
    else
        print_status "FAIL" "Directory owned by $OWNER, should be $CURRENT_USER"
    fi
    
    # Check permissions
    PERMS=$(stat -c '%a' scriptura-api)
    if [ "$PERMS" = "755" ] || [ "$PERMS" = "775" ]; then
        print_status "PASS" "Directory permissions are $PERMS (OK)"
    else
        print_status "WARN" "Directory permissions are $PERMS (might need 755)"
    fi
else
    print_status "FAIL" "scriptura-api directory does not exist"
    echo "   This means the setup script didn't run properly or failed"
fi

# 2. Check scriptura-api contents
echo ""
echo "2. Checking scriptura-api contents..."
if [ -d "scriptura-api" ]; then
    echo "Directory contents:"
    ls -la scriptura-api/
    
    # Check for virtual environment
    if [ -d "scriptura-api/venv" ]; then
        print_status "PASS" "Virtual environment exists"
    else
        print_status "FAIL" "Virtual environment missing"
    fi
    
    # Check for .env file
    if [ -f "scriptura-api/.env" ]; then
        print_status "PASS" "Configuration file exists"
    else
        print_status "FAIL" "Configuration file missing"
    fi
    
    # Check for main.py
    if [ -f "scriptura-api/main.py" ]; then
        print_status "PASS" "Main application file exists"
    else
        print_status "FAIL" "Main application file missing"
    fi
fi

# 3. Check systemd service file
echo ""
echo "3. Checking systemd service file..."
if [ -f "/etc/systemd/system/scriptura-api.service" ]; then
    print_status "PASS" "Service file exists"
    
    echo "Service file contents:"
    cat /etc/systemd/system/scriptura-api.service
    echo ""
    
    # Check if paths are correct
    if grep -q "$PROJECT_DIR" /etc/systemd/system/scriptura-api.service; then
        print_status "PASS" "Service file contains correct project directory"
    else
        print_status "FAIL" "Service file has wrong project directory"
    fi
    
    # Check if user is correct
    if grep -q "User=$CURRENT_USER" /etc/systemd/system/scriptura-api.service; then
        print_status "PASS" "Service file has correct user"
    else
        print_status "FAIL" "Service file has wrong user"
    fi
    
    # Check security settings
    if grep -q "ProtectHome=false" /etc/systemd/system/scriptura-api.service; then
        print_status "PASS" "Service file has correct security settings (ProtectHome=false)"
    else
        print_status "FAIL" "Service file has restrictive security settings that may prevent access to home directory"
    fi
else
    print_status "FAIL" "Service file does not exist"
fi

# 4. Check service status
echo ""
echo "4. Checking service status..."
if systemctl is-active --quiet scriptura-api.service; then
    print_status "PASS" "Service is running"
else
    print_status "FAIL" "Service is not running"
fi

if systemctl is-enabled --quiet scriptura-api.service; then
    print_status "PASS" "Service is enabled"
else
    print_status "WARN" "Service is not enabled"
fi

# 5. Check service logs
echo ""
echo "5. Checking recent service logs..."
echo "Last 10 lines of service logs:"
sudo journalctl -u scriptura-api.service -n 10 --no-pager

# 6. Check port usage
echo ""
echo "6. Checking port usage..."
if netstat -tlnp 2>/dev/null | grep -q ":8081"; then
    print_status "PASS" "Port 8081 is in use"
    netstat -tlnp | grep ":8081"
else
    print_status "FAIL" "Port 8081 is not in use"
fi

# 7. Check config.yml
echo ""
echo "7. Checking config.yml..."
if [ -f "config.yml" ]; then
    print_status "PASS" "config.yml exists"
    
    if grep -q "scriptura:" config.yml; then
        print_status "PASS" "Scriptura configuration found"
        
        if grep -q "use_local: true" config.yml; then
            print_status "PASS" "Config set to use local Scriptura"
        else
            print_status "WARN" "Config not set to use local Scriptura"
        fi
        
        # Show the Scriptura section
        echo "Scriptura configuration:"
        grep -A 4 "scriptura:" config.yml
    else
        print_status "FAIL" "No Scriptura configuration found - this is why it's using remote API!"
        echo "   The web server will default to remote Scriptura API without this config"
    fi
else
    print_status "FAIL" "config.yml does not exist"
fi

# 8. Test API connectivity
echo ""
echo "8. Testing API connectivity..."
if curl -s --connect-timeout 5 "http://localhost:8081/api/versions" >/dev/null 2>&1; then
    print_status "PASS" "Local API is responding"
else
    print_status "FAIL" "Local API is not responding"
fi

if curl -s --connect-timeout 5 "https://www.scriptura-api.com/api/versions" >/dev/null 2>&1; then
    print_status "PASS" "Remote API is responding"
else
    print_status "WARN" "Remote API is not responding"
fi

# 9. Check web server logs
echo ""
echo "9. Checking web server logs for API calls..."
echo "Recent web server logs:"
sudo journalctl -u liturgical-web.service -n 5 --no-pager

# 10. Summary and recommendations
echo ""
echo "================================"
echo "🎯 ANALYSIS SUMMARY"
echo "================================"

# Count issues
ISSUES=0

if [ ! -d "scriptura-api" ]; then
    echo "❌ Issue: scriptura-api directory missing"
    ISSUES=$((ISSUES + 1))
fi

if [ -d "scriptura-api" ] && [ ! -d "scriptura-api/venv" ]; then
    echo "❌ Issue: Virtual environment missing"
    ISSUES=$((ISSUES + 1))
fi

if [ ! -f "/etc/systemd/system/scriptura-api.service" ]; then
    echo "❌ Issue: Systemd service file missing"
    ISSUES=$((ISSUES + 1))
fi

if ! systemctl is-active --quiet scriptura-api.service; then
    echo "❌ Issue: Service not running"
    ISSUES=$((ISSUES + 1))
fi

if ! curl -s --connect-timeout 5 "http://localhost:8081/api/versions" >/dev/null 2>&1; then
    echo "❌ Issue: Local API not responding"
    ISSUES=$((ISSUES + 1))
fi

if [ $ISSUES -eq 0 ]; then
    echo "✅ All checks passed! Scriptura API should be working."
else
    echo "❌ Found $ISSUES issues that need to be fixed."
    echo ""
    echo "🔧 RECOMMENDED FIXES:"
    echo "1. Run: sudo chown -R $CURRENT_USER:$CURRENT_USER $PROJECT_DIR/scriptura-api/"
    echo "2. Run: chmod -R 755 $PROJECT_DIR/scriptura-api/"
    echo "3. Run: sudo systemctl daemon-reload"
    echo "4. Run: sudo systemctl restart scriptura-api.service"
    echo "5. If still failing, re-run: ./setup.sh"
fi

echo ""
echo "📝 Next steps:"
echo "- Fix the identified issues"
echo "- Test the API endpoints"
echo "- Check that readings are loading from local API"
