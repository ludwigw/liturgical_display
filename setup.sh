#!/bin/bash
set -e

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

# Build epdraw tool if not already present or if IT8951-ePaper has updates
REBUILD_EP=0
if [ ! -f "bin/epdraw" ]; then
    echo "epdraw tool not found, will build."
    REBUILD_EP=1
fi

if [ -d "IT8951-ePaper" ]; then
    echo "IT8951-ePaper directory exists. Checking for updates..."
    cd IT8951-ePaper
    OLD_HEAD=$(git rev-parse HEAD)
    git fetch origin
    git pull origin main || true
    NEW_HEAD=$(git rev-parse HEAD)
    if [ "$OLD_HEAD" != "$NEW_HEAD" ]; then
        echo "IT8951-ePaper updated (HEAD changed). Rebuilding epdraw..."
        make clean
        REBUILD_EP=1
    else
        echo "IT8951-ePaper is up to date."
    fi
    cd ..
else
    echo "Cloning IT8951-ePaper repository..."
    git clone https://github.com/ludwigw/IT8951-ePaper.git
    cd IT8951-ePaper
    # No need to checkout refactir, use main
    REBUILD_EP=1
    cd ..
fi

if [ $REBUILD_EP -eq 1 ]; then
    echo "Building epdraw tool..."
    cd IT8951-ePaper
    make bin/epdraw
    echo "Copying epdraw to project bin directory..."
    mkdir -p ../bin
    cp bin/epdraw ../bin/
    cd ..
    echo "epdraw tool built successfully!"
else
    echo "epdraw tool already exists in bin/ directory and is up to date."
fi

echo "Setup complete! Virtual environment is ready."
echo ""
echo "Next steps:"
echo "1. Edit config.yml to match your environment"
if [ "$USER_OPENAI_KEY" = "your-openai-api-key-here" ]; then
    echo "2. Add your OpenAI API key to config.yml for reflection generation"
    echo "3. Test the workflow: source venv/bin/activate && python3 -m liturgical_display.main"
    echo "4. (Optional) Enable systemd service for daily runs"
else
    echo "2. Test the workflow: source venv/bin/activate && python3 -m liturgical_display.main"
    echo "3. Test reflection generation: source venv/bin/activate && python tests/test_reflection.py"
    echo "4. (Optional) Enable systemd service for daily runs"
fi

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

# Parse arguments for non-interactive mode
NON_INTERACTIVE=0
for arg in "$@"; do
  if [ "$arg" = "--non-interactive" ]; then
    NON_INTERACTIVE=1
  fi
done

# --- CONFIGURATION SETUP ---
USER_HOME="$HOME"
PROJECT_DIR="$(pwd)"  # Get the actual project directory where setup.sh is run from
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

if [ $NON_INTERACTIVE -eq 1 ]; then
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
EOF

echo "config.yml written. You can edit this file to further customize your setup."

# --- SCRIPTURA API SETUP ---
echo ""
echo "Setting up local Scriptura API..."

# Check if we should install Scriptura API
if [ $NON_INTERACTIVE -eq 1 ]; then
    INSTALL_SCRIPTURA="${INSTALL_SCRIPTURA:-Y}"
else
    echo "Do you want to install and configure local Scriptura API? (Y/n)"
    echo "This will eliminate rate limiting and provide faster Bible text access."
    read -r INSTALL_SCRIPTURA
fi

if [ -z "$INSTALL_SCRIPTURA" ] || [ "$INSTALL_SCRIPTURA" = "Y" ] || [ "$INSTALL_SCRIPTURA" = "y" ]; then
    echo "Installing local Scriptura API..."
    
    # Run the Scriptura setup script
    if [ -f "setup_scriptura_local.sh" ]; then
        chmod +x setup_scriptura_local.sh
        ./setup_scriptura_local.sh
        
        # Update config.yml to use local Scriptura
        echo "Updating config.yml to use local Scriptura API..."
        sed -i.bak 's/use_local: false/use_local: true/' config.yml
        rm -f config.yml.bak
        
        echo "✅ Local Scriptura API installed and configured!"
        echo "   - API will run on port 8081"
        echo "   - Config updated to use local instance"
        echo "   - No more rate limiting issues"
    else
        echo "❌ setup_scriptura_local.sh not found. Skipping Scriptura setup."
    fi
else
    echo "Skipping Scriptura API setup. Using remote API (may have rate limits)."
fi

# --- SYSTEMD SETUP ---
# Skip systemd setup in CI environments
if [ "$CI" = "true" ] || [ "$GITHUB_ACTIONS" = "true" ]; then
    echo "CI environment detected, skipping systemd service and timer setup."
else
    if [ $NON_INTERACTIVE -eq 1 ]; then
        ENABLE_SYSTEMD="${ENABLE_SYSTEMD:-Y}"
    else
        echo ""
        echo "Do you want to schedule these to update daily using systemd? (Y/n)"
        read -r ENABLE_SYSTEMD
    fi
    if [ -z "$ENABLE_SYSTEMD" ] || [ "$ENABLE_SYSTEMD" = "Y" ] || [ "$ENABLE_SYSTEMD" = "y" ]; then
        echo "Installing and enabling systemd service and timer..."
        # Substitute {{PROJECT_DIR}} in service file with actual project directory
        sed "s|{{PROJECT_DIR}}|$PROJECT_DIR|g" systemd/liturgical.service > /tmp/liturgical.service
        sudo cp /tmp/liturgical.service /etc/systemd/system/liturgical.service
        sudo cp systemd/liturgical.timer /etc/systemd/system/liturgical.timer
        sudo systemctl daemon-reload
        sudo systemctl enable liturgical.timer
        sudo systemctl start liturgical.timer
        echo "Systemd service and timer installed and enabled for daily runs."
        
        # Install and enable web server service (separate from main service)
        echo "Installing and enabling web server service..."
        
        # Get current user for systemd service
        CURRENT_USER=$(whoami)
        echo "Using current user '$CURRENT_USER' for systemd services"
        
        # Web server now uses config.yml (already created above)
        echo "Web server will use config.yml for configuration"
        
        # Install systemd service with correct user
        sed "s|{{PROJECT_DIR}}|$PROJECT_DIR|g" systemd/liturgical-web.service | sed "s|User=pi|User=$CURRENT_USER|g" > /tmp/liturgical-web.service
        sed "s|{{PROJECT_DIR}}|$PROJECT_DIR|g" systemd/liturgical.service | sed "s|User=pi|User=$CURRENT_USER|g" > /tmp/liturgical.service
        sudo cp /tmp/liturgical-web.service /etc/systemd/system/liturgical-web.service
        sudo cp /tmp/liturgical.service /etc/systemd/system/liturgical.service
        
        # Install Scriptura API service if local Scriptura was installed
        if [ -d "scriptura-api" ]; then
            echo "Installing Scriptura API systemd service..."
            sed "s|{{PROJECT_DIR}}|$PROJECT_DIR|g" systemd/scriptura-api.service | sed "s|{{USER}}|$CURRENT_USER|g" > /tmp/scriptura-api.service
            sudo cp /tmp/scriptura-api.service /etc/systemd/system/scriptura-api.service
            sudo systemctl daemon-reload
            sudo systemctl enable scriptura-api.service
            sudo systemctl start scriptura-api.service
            echo "Scriptura API service installed and started on port 8081"
        fi
        
        sudo systemctl daemon-reload
        sudo systemctl enable liturgical-web.service
        sudo systemctl start liturgical-web.service
        echo "Web server service installed and enabled for automatic startup."
        echo ""
        echo "🌐 SERVICES RUNNING:"
        echo "   - Web server: http://localhost:8080"
        if [ -d "scriptura-api" ]; then
            echo "   - Scriptura API: http://localhost:8081"
            echo "   - Scriptura docs: http://localhost:8081/docs"
        fi
        echo ""
        echo "📝 CONFIGURATION:"
        echo "   - Main config: config.yml"
        echo "   - Web server runs continuously"
        echo "   - Daily display updates via systemd timer"
        if [ -d "scriptura-api" ]; then
            echo "   - Local Scriptura API eliminates rate limiting"
        fi
    else
        echo "Skipping systemd service and timer setup. You can enable it later by running these commands manually."
    fi
fi 