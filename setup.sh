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

# Build epdraw tool if not already present
echo "Checking for epdraw tool..."
if [ ! -f "bin/epdraw" ]; then
    echo "Building epdraw tool..."
    
    # Check if IT8951-ePaper is already cloned
    if [ ! -d "IT8951-ePaper" ]; then
        echo "Cloning IT8951-ePaper repository..."
        git clone https://github.com/ludwigw/IT8951-ePaper.git
    fi
    
    cd IT8951-ePaper
    echo "Checking out refactir branch..."
    git checkout refactir
    
    echo "Building epdraw..."
    make bin/epdraw
    
    echo "Copying epdraw to project bin directory..."
    mkdir -p ../bin
    cp bin/epdraw ../bin/
    cd ..
    
    echo "epdraw tool built successfully!"
else
    echo "epdraw tool already exists in bin/ directory."
fi

echo "Setup complete! Virtual environment is ready."
echo ""
echo "Next steps:"
echo "1. Edit config.yaml to match your environment"
echo "2. Test the workflow: source venv/bin/activate && python3 -m liturgical_display.main"
echo "3. (Optional) Enable systemd service for daily runs"

# Prompt to enable systemd timer for daily updates
echo ""
echo "Do you want to schedule these to update daily using systemd? (Y/n)"
read -r enable_systemd
if [ -z "$enable_systemd" ] || [ "$enable_systemd" = "Y" ] || [ "$enable_systemd" = "y" ]; then
    echo "Installing and enabling systemd service and timer..."
    sudo cp systemd/liturgical.service /etc/systemd/system/
    sudo cp systemd/liturgical.timer /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable liturgical.timer
    sudo systemctl start liturgical.timer
    echo "Systemd service and timer installed and enabled for daily runs."
else
    echo "Skipping systemd service and timer setup. You can enable it later by running these commands manually."
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