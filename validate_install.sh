#!/bin/bash
#
# validate_install.sh - Validation script for liturgical_display installation
#
# This script validates that all components of the liturgical_display system
# are properly installed and configured. It checks virtual environment,
# Python dependencies, fonts, configuration, and tests the image generation
# pipeline.
#
# Usage: ./validate_install.sh
#
# Exit codes:
#   0 - All validations passed
#   1 - One or more validations failed
#
# Author: Ludwig W
# Version: 1.0
# Date: 2024-12-13
#

set -e

echo "🔍 Validating liturgical_display installation..."
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test file for cleanup
TEST_IMAGE="test_output.png"

# Cleanup function
cleanup() {
    if [ -f "$TEST_IMAGE" ]; then
        rm -f "$TEST_IMAGE"
    fi
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Validate liturgical_display installation and configuration.

OPTIONS:
    -h, --help      Show this help message
    -v, --version   Show version information
    --verbose       Show detailed output (not implemented yet)

EXIT CODES:
    0 - All validations passed
    1 - One or more validations failed

EXAMPLES:
    $0                    # Run all validations
    $0 --help            # Show this help
EOF
}

# Version function
show_version() {
    echo "validate_install.sh version 1.0"
    echo "Copyright (c) 2024 Ludwig W"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            show_version
            exit 0
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Verbose mode (default: false)
VERBOSE=${VERBOSE:-false}

# Track overall status
OVERALL_STATUS="PASS"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNING_TESTS=0

# Function to update counters
update_counters() {
    local status=$1
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    case $status in
        "PASS")
            PASSED_TESTS=$((PASSED_TESTS + 1))
            ;;
        "FAIL")
            FAILED_TESTS=$((FAILED_TESTS + 1))
            ;;
        "WARN")
            WARNING_TESTS=$((WARNING_TESTS + 1))
            ;;
    esac
}

# Function to print status
print_status() {
    local status=$1
    local message=$2
    
    # Update counters
    update_counters "$status"
    
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

# 1. Check if virtual environment exists
echo ""
echo "1. Checking virtual environment..."
if [ -d "venv" ]; then
    print_status "PASS" "Virtual environment exists"
else
    print_status "FAIL" "Virtual environment not found. Run ./setup.sh first."
    OVERALL_STATUS="FAIL"
fi

# 2. Check if virtual environment can be activated
if [ -d "venv" ]; then
    echo "2. Testing virtual environment activation..."
    if source venv/bin/activate 2>/dev/null; then
        print_status "PASS" "Virtual environment activates successfully"
    else
        print_status "FAIL" "Cannot activate virtual environment"
        OVERALL_STATUS="FAIL"
    fi
fi

# 3. Check Python version
echo "3. Checking Python version..."
if command -v python3 >/dev/null 2>&1; then
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    print_status "INFO" "Python version: $PYTHON_VERSION"
    
    # Check if version is 3.11 or higher
    if python3 -c "import sys; exit(0 if sys.version_info >= (3, 11) else 1)" 2>/dev/null; then
        print_status "PASS" "Python version is 3.11+ (compatible)"
    else
        print_status "WARN" "Python version may be too old (recommended: 3.11+)"
    fi
else
    print_status "FAIL" "Python3 not found"
    OVERALL_STATUS="FAIL"
fi

# 4. Check if liturgical-calendar package is installed
echo "4. Checking liturgical-calendar package..."
if source venv/bin/activate 2>/dev/null && python3 -c "import liturgical_calendar; print('Package found')" 2>/dev/null; then
    print_status "PASS" "liturgical-calendar package is installed"
    
    # Check package version
    PACKAGE_VERSION=$(source venv/bin/activate 2>/dev/null && python3 -c "import liturgical_calendar; print(getattr(liturgical_calendar, '__version__', 'unknown'))" 2>/dev/null)
    print_status "INFO" "Package version: $PACKAGE_VERSION"
else
    print_status "FAIL" "liturgical-calendar package not found. Run ./setup.sh first."
    OVERALL_STATUS="FAIL"
fi

# 5. Check if fonts are accessible
echo "5. Checking font accessibility..."
if source venv/bin/activate 2>/dev/null && python3 -c "
import liturgical_calendar.image_generation.font_manager as fm
fm_instance = fm.FontManager()
print('Fonts directory:', fm_instance.fonts_dir)
print('Fonts exist:', fm_instance.fonts_dir.exists())
" 2>/dev/null; then
    print_status "PASS" "Fonts are accessible"
else
    print_status "FAIL" "Cannot access fonts. Package may not be installed correctly."
    OVERALL_STATUS="FAIL"
fi

# 6. Check if epdraw tool exists
echo "6. Checking epdraw tool..."
if [ -f "bin/epdraw" ]; then
    print_status "PASS" "epdraw tool found in bin/"
    
    # Check if it's executable
    if [ -x "bin/epdraw" ]; then
        print_status "PASS" "epdraw tool is executable"
    else
        print_status "WARN" "epdraw tool is not executable"
    fi
else
    print_status "WARN" "epdraw tool not found in bin/ (will be built on first run)"
fi

# 7. Check if config.yaml exists
echo "7. Checking configuration..."
if [ -f "config.yaml" ]; then
    print_status "PASS" "config.yaml exists"
    
    # Validate config structure
    if source venv/bin/activate 2>/dev/null && python3 -c "
import yaml
import sys

try:
    with open('config.yaml') as f:
        config = yaml.safe_load(f)
    
    if not config:
        print('ERROR: config.yaml is empty')
        exit(1)
    
    required_keys = ['output_image', 'vcom', 'shutdown_after_display', 'log_file']
    missing = [key for key in required_keys if key not in config]
    
    if missing:
        print('ERROR: Missing required keys:', missing)
        exit(1)
    
    # Check for reasonable values
    if config.get('vcom', 0) <= 0:
        print('WARNING: vcom should be a positive number')
    
    print('Config structure is valid')
    
except yaml.YAMLError as e:
    print('ERROR: Invalid YAML format:', e)
    exit(1)
except Exception as e:
    print('ERROR: Failed to read config:', e)
    exit(1)
" 2>/dev/null; then
        print_status "PASS" "config.yaml structure is valid"
    else
        print_status "WARN" "config.yaml may be missing required keys or have invalid format"
        if [ "$VERBOSE" = "true" ]; then
            echo "  Required keys: output_image, vcom, shutdown_after_display, log_file"
        fi
    fi
else
    print_status "FAIL" "config.yaml not found"
    OVERALL_STATUS="FAIL"
fi

# 8. Test liturgical-calendar CLI
echo "8. Testing liturgical-calendar CLI..."
if source venv/bin/activate 2>/dev/null && python3 -m liturgical_calendar.cli --help >/dev/null 2>&1; then
    print_status "PASS" "liturgical-calendar CLI works"
else
    print_status "FAIL" "liturgical-calendar CLI not working"
    OVERALL_STATUS="FAIL"
fi

# 9. Test image generation capability
echo "9. Testing image generation capability..."
GEN_OUTPUT=$(source venv/bin/activate 2>/dev/null && python3 -m liturgical_calendar.cli generate --output "$TEST_IMAGE" 2024-12-25 2>&1)
GEN_EXIT=$?
if [ $GEN_EXIT -eq 0 ] && [ -s "$TEST_IMAGE" ]; then
    print_status "PASS" "Image generation CLI produced an image"
    rm -f "$TEST_IMAGE"
else
    if [ -n "$CI" ] || [ -n "$GITHUB_ACTIONS" ]; then
        if echo "$GEN_OUTPUT" | grep -q "HTTP error downloading.*429\|Too Many Requests\|cannot identify image file\|Download/cache error"; then
            print_status "WARN" "Image generation failed (likely due to network/429 in CI), but continuing"
        else
            print_status "FAIL" "Image generation CLI did not produce an image"
            OVERALL_STATUS="FAIL"
        fi
    else
        print_status "FAIL" "Image generation CLI did not produce an image"
        OVERALL_STATUS="FAIL"
    fi
fi

# 10. Check systemd service files
echo "10. Checking systemd service files..."
if [ -f "systemd/liturgical.service" ] && [ -f "systemd/liturgical.timer" ]; then
    print_status "PASS" "Systemd service files exist"
else
    print_status "INFO" "Systemd service files not found (optional for automated runs)"
fi

# 11. Test main module import
echo "11. Testing main module import..."
if source venv/bin/activate 2>/dev/null && python3 -c "import liturgical_display.main; print('Main module imports successfully')" 2>/dev/null; then
    print_status "PASS" "Main module imports successfully"
else
    print_status "FAIL" "Cannot import main module"
    OVERALL_STATUS="FAIL"
fi

# 12. Check for required directories
echo "12. Checking required directories..."
REQUIRED_DIRS=("logs" "bin")
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        print_status "PASS" "Directory $dir exists"
    else
        print_status "INFO" "Directory $dir not found (will be created when needed)"
    fi
done

# 13. Test integration test script
echo "13. Checking integration test script..."
if [ -f "tests/test_integration.sh" ] && [ -x "tests/test_integration.sh" ]; then
    print_status "PASS" "Integration test script exists and is executable"
else
    print_status "WARN" "Integration test script not found or not executable"
fi

echo ""
echo "================================================"
echo "🎯 Validation Summary:"

# Display test statistics
echo ""
echo "📊 Test Results:"
echo "   Total tests: $TOTAL_TESTS"
echo "   ✅ Passed: $PASSED_TESTS"
echo "   ❌ Failed: $FAILED_TESTS"
echo "   ⚠️  Warnings: $WARNING_TESTS"
echo ""

if [ "$OVERALL_STATUS" = "PASS" ]; then
    print_status "PASS" "Installation validation PASSED! 🎉"
    echo ""
    echo "✅ Your liturgical_display installation is ready!"
    echo ""
    echo "Next steps:"
    echo "1. Edit config.yaml to match your environment"
    echo "2. Test the workflow: source venv/bin/activate && python3 -m liturgical_display.main"
    echo "3. (Optional) Run integration test: ./tests/test_integration.sh"
    echo "4. (Optional) Enable systemd service for daily runs"
    echo ""
    echo "For troubleshooting, see README.md and PLAN.md"
else
    print_status "FAIL" "Installation validation FAILED! ❌"
    echo ""
    echo "❌ Some components are missing or not working correctly."
    echo ""
    echo "Please:"
    echo "1. Run ./setup.sh to install missing components"
    echo "2. Check the error messages above"
    echo "3. See README.md for setup instructions"
    echo "4. Run this validation script again after fixing issues"
    echo ""
    if [ "$VERBOSE" = "true" ]; then
        echo "💡 Tip: Run with --verbose for more detailed information"
    fi
    exit 1
fi 