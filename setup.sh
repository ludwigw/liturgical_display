#!/bin/bash
set -e

# Main setup script for liturgical_display
# This script orchestrates all setup modules and handles configuration

# Parse command line arguments
FORCE_REBUILD=false
NON_INTERACTIVE=false
SKIP_MODULES=""

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
        --skip-modules)
            SKIP_MODULES="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [--force-rebuild] [--non-interactive] [--skip-modules MODULE1,MODULE2]"
            echo ""
            echo "Options:"
            echo "  --force-rebuild    Force rebuild of all components"
            echo "  --non-interactive  Run without user prompts"
            echo "  --skip-modules     Skip specific modules (comma-separated)"
            echo "                     Available modules: epdraw, scriptura, services, python"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Run all modules interactively"
            echo "  $0 --non-interactive                  # Run all modules non-interactively"
            echo "  $0 --force-rebuild --non-interactive # Force rebuild everything"
            echo "  $0 --skip-modules epdraw,services    # Skip ePdraw and services setup"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "🚀 Liturgical Display Setup"
echo "=========================="

# Check if we're in the right directory
if [ ! -f "requirements.txt" ] || [ ! -f "liturgical_display/__init__.py" ]; then
    echo "❌ Error: This script must be run from the liturgical_display project root directory"
    echo "   Make sure you're in the directory containing requirements.txt and liturgical_display/"
    exit 1
fi

# Function to check if a module should be skipped
should_skip_module() {
    local module="$1"
    if [ -n "$SKIP_MODULES" ]; then
        echo "$SKIP_MODULES" | grep -q "$module"
    else
        return 1
    fi
}

# Function to run a setup module
run_module() {
    local module="$1"
    local script="setup_modules/setup_$module.sh"
    
    if [ ! -f "$script" ]; then
        echo "❌ Module script not found: $script"
        return 1
    fi
    
    if should_skip_module "$module"; then
        echo "⏭️  Skipping $module module (--skip-modules)"
        return 0
    fi
    
    echo "🔧 Running $module module..."
    local args=""
    if [ "$FORCE_REBUILD" = "true" ]; then
        args="$args --force-rebuild"
    fi
    if [ "$NON_INTERACTIVE" = "true" ]; then
        args="$args --non-interactive"
    fi
    
    if "$script" $args; then
        echo "✅ $module module completed successfully"
    else
        echo "❌ $module module failed"
        return 1
    fi
}

# --- PYTHON ENVIRONMENT SETUP ---
echo "🐍 Setting up Python environment..."

# Remove existing venv if it exists
if [ -d "venv" ]; then
    echo "Removing existing virtual environment..."
    rm -rf venv
fi

# Create fresh virtual environment with ensurepip
echo "Creating fresh virtual environment..."
python3 -m venv venv --clear

# Activate virtual environment
source venv/bin/activate

# Upgrade pip to latest version
echo "Upgrading pip..."
pip install --upgrade pip

# Install requirements
echo "Installing requirements..."
pip install -r requirements.txt

# Install ImageMagick if not present
if ! command -v convert >/dev/null 2>&1; then
    echo "ImageMagick not found. Installing via apt-get..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y imagemagick
    else
        echo "WARNING: Could not install ImageMagick automatically (apt-get not found). Please install it manually."
    fi
else
    echo "ImageMagick is already installed."
fi

echo "✅ Python environment setup complete"

# --- RUN SETUP MODULES ---
echo ""
echo "🔧 Running setup modules..."

# Run ePdraw setup
run_module "epdraw"

# Run Scriptura API setup
run_module "scriptura"

# Run systemd services setup
run_module "services"

# --- CONFIGURATION SETUP ---
echo ""
echo "⚙️  Setting up configuration..."

USER_HOME="$HOME"
PROJECT_DIR="$(pwd)"
BACKUP_FILE="config.yml.bak"

# If config.yml exists, read current values
if [ -f "config.yml" ]; then
    CURRENT_VCOM=$(grep '^vcom:' "config.yml" | awk '{print $2}')
    # Extract OpenAI key, handling both quoted and unquoted formats
    CURRENT_OPENAI_KEY=$(grep '^openai_api_key:' "config.yml" | sed -E 's/^openai_api_key: *"?([^"]*)"?$/\1/' | sed 's/^your-openai-api-key-here$//')
    echo "Existing config.yml found."
    echo "Backing up current config.yml to config.yml.bak."
    cp "config.yml" "config.yml.bak"
else
    CURRENT_VCOM="-1.18"
    CURRENT_OPENAI_KEY=""
fi

if [ "$NON_INTERACTIVE" = "true" ]; then
    # Use env var or default for VCOM
    USER_VCOM="${VCOM:-$CURRENT_VCOM}"
    # Use env var or current value for OpenAI key
    USER_OPENAI_KEY="${OPENAI_API_KEY:-$CURRENT_OPENAI_KEY}"
else
    echo ""
    echo "Please enter the VCOM value for your eInk display (see sticker on FPC cable) [default: $CURRENT_VCOM]:"
    read -r USER_VCOM
    if [ -z "$USER_VCOM" ]; then
        USER_VCOM="$CURRENT_VCOM"
    fi
    
    echo ""
    if [ -n "$CURRENT_OPENAI_KEY" ]; then
        echo "Please enter your OpenAI API key for reflection generation [current: ${CURRENT_OPENAI_KEY:0:20}...] (or press Enter to keep current):"
    else
        echo "Please enter your OpenAI API key for reflection generation (or press Enter to skip):"
    fi
    read -r USER_OPENAI_KEY
    if [ -z "$USER_OPENAI_KEY" ]; then
        if [ -n "$CURRENT_OPENAI_KEY" ]; then
            USER_OPENAI_KEY="$CURRENT_OPENAI_KEY"
            echo "✅ Keeping existing OpenAI API key"
        else
            USER_OPENAI_KEY="your-openai-api-key-here"
            echo "⚠️  OpenAI API key not provided. You can add it later by editing config.yml"
        fi
    else
        echo "✅ OpenAI API key will be configured"
    fi
fi

OUTPUT_IMAGE="$PROJECT_DIR/today.png"
LOG_FILE="$PROJECT_DIR/logs/display.log"

# Write new config.yml
echo "Writing config.yml with detected defaults..."
cat > "config.yml" <<EOF
# Main config.yml for liturgical_display
# Package handles its own caching internally

# Display settings
output_image: $OUTPUT_IMAGE
vcom: $USER_VCOM
shutdown_after_display: false
log_file: $LOG_FILE

# Web server configuration
web_server:
  enabled: true
  host: "0.0.0.0"
  port: 8080
  debug: false

# API Keys for reflection generation
openai_api_key: "$USER_OPENAI_KEY"
# Note: Scriptura API is free and doesn't require an API key

# Scriptura API configuration
scriptura:
  use_local: true   # Set to true to use local Scriptura instance
  local_port: 8081  # Port for local Scriptura API
  version: "asv"    # Default Bible version
EOF

echo "config.yml written. You can edit this file to further customize your setup."

# --- VALIDATION ---
echo ""
echo "🔍 Running installation validation..."
echo "================================================"

if [ -f "validate_install.sh" ] && [ -x "validate_install.sh" ]; then
    if ./validate_install.sh; then
        echo ""
        echo "🎉 Setup and validation completed successfully!"
        echo "✅ Your liturgical_display installation is ready to use."
    else
        echo ""
        echo "⚠️  Setup completed, but validation found some issues."
        echo "Please review the validation output above and address any problems."
        echo "You can run './validate_install.sh' again to re-check after fixing issues."
        exit 1
    fi
else
    echo "⚠️  Validation script not found or not executable."
    echo "Setup completed, but please run './validate_install.sh' manually to verify the installation."
fi

echo ""
echo "🌐 SERVICES RUNNING:"
echo "   - Web server: http://localhost:8080"
echo "   - Scriptura API: http://localhost:8081"
echo "   - Scriptura docs: http://localhost:8081/docs"
echo ""
echo "📝 CONFIGURATION:"
echo "   - Main config: config.yml"
echo "   - Web server runs continuously"
echo "   - Daily display updates via systemd timer"
echo "   - Local Scriptura API eliminates rate limiting"
echo ""
echo "🎉 Setup complete! All modules installed and configured."