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