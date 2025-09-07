#!/bin/bash

# Setup Enhanced Scriptura API locally
# This script sets up the enhanced Scriptura API with smart parsing capabilities

set -e

SCRIPTURA_DIR="scriptura-api"
SCRIPTURA_REPO="https://github.com/ludwigw/ScripturaAPI.git"
SCRIPTURA_PORT=8081

echo "🚀 Setting up Scriptura API locally..."

# Check if scriptura directory exists
if [ -d "$SCRIPTURA_DIR" ]; then
    echo "📁 Scriptura directory already exists, updating..."
    cd "$SCRIPTURA_DIR"
    
    # Ensure we're pointing to the correct fork
    echo "🔄 Updating remote URL to enhanced fork..."
    git remote set-url origin "$SCRIPTURA_REPO"
    git remote add upstream https://github.com/AlexLamper/ScripturaAPI.git 2>/dev/null || true
    
    # Clean up any local changes and untracked files
    echo "🧹 Cleaning up local changes..."
    git stash push -m "Setup script cleanup $(date)" 2>/dev/null || true
    git clean -fd 2>/dev/null || true
    
    # Fetch and checkout the enhanced parsing branch
    echo "📥 Fetching enhanced parsing branch..."
    git fetch origin
    git checkout feature/enhanced-parsing
    git pull origin feature/enhanced-parsing
else
    echo "📥 Cloning enhanced Scriptura API repository with parsing capabilities..."
    git clone "$SCRIPTURA_REPO" "$SCRIPTURA_DIR"
    cd "$SCRIPTURA_DIR"
    git checkout feature/enhanced-parsing
    git remote add upstream https://github.com/AlexLamper/ScripturaAPI.git
fi

# Ensure we're in the scriptura-api directory
echo "📍 Current directory: $(pwd)"
echo "📁 Contents: $(ls -la)"

# Create virtual environment for Scriptura
if [ ! -d "venv" ] || [ ! -f "venv/bin/activate" ]; then
    if [ -d "venv" ]; then
        echo "🐍 Virtual environment exists but is incomplete, recreating..."
        rm -rf venv
    else
        echo "🐍 Creating virtual environment for Scriptura..."
    fi
    python3 -m venv venv
    echo "✅ Virtual environment created"
else
    echo "✅ Virtual environment already exists and is complete"
fi

# Ensure virtual environment is properly created
if [ ! -f "venv/bin/activate" ]; then
    echo "❌ Virtual environment creation failed!"
    echo "📁 Current directory contents: $(ls -la)"
    echo "📁 venv directory contents: $(ls -la venv/ 2>/dev/null || echo 'venv directory not found')"
    exit 1
fi

# Activate virtual environment and install dependencies
echo "📦 Installing Scriptura dependencies..."
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Create .env file for configuration
if [ ! -f ".env" ]; then
    echo "⚙️ Creating .env configuration file..."
    cat > .env << EOF
# Scriptura API Configuration
DATABASE_URL=sqlite:///./scriptura.db
API_KEY=local-dev-key-$(date +%s)
STRIPE_SECRET_KEY=sk_test_dummy
STRIPE_PUBLISHABLE_KEY=pk_test_dummy
CORS_ORIGINS=http://localhost:8080,http://127.0.0.1:8080
PORT=$SCRIPTURA_PORT
EOF
    echo "✅ Created .env file with local configuration"
else
    echo "📄 .env file already exists, skipping creation"
fi

# Initialize database
echo "🗄️ Initializing database..."
python -c "
from models import Base
from sqlalchemy import create_engine
import os
from dotenv import load_dotenv

load_dotenv()
engine = create_engine(os.getenv('DATABASE_URL', 'sqlite:///./scriptura.db'))
Base.metadata.create_all(bind=engine)
print('Database initialized successfully')
"

echo "✅ Enhanced Scriptura API setup complete!"
echo ""
echo "🧠 Features included:"
echo "   - Smart Bible reference parsing"
echo "   - Discontinuous ranges (Psalm 104:26-36,37)"
echo "   - Cross-chapter references (John 3:16-4:1)"
echo "   - Optional verses (Luke 1:39-45[46-55])"
echo "   - Alternative readings (Baruch 5:1-9 or Malachi 3:1-4)"
echo "   - All complex reference types supported"
echo ""
echo "🔧 To start Scriptura API locally:"
echo "   cd $SCRIPTURA_DIR"
echo "   source venv/bin/activate"
echo "   uvicorn main:app --host 0.0.0.0 --port $SCRIPTURA_PORT"
echo ""
echo "🌐 API will be available at: http://localhost:$SCRIPTURA_PORT"
echo "📚 Documentation: http://localhost:$SCRIPTURA_PORT/docs"
echo "🧠 Parsing endpoints: /api/parse/reference/{ref}"
echo ""
echo "🔄 Next steps:"
echo "   1. Start Scriptura API locally"
echo "   2. Test parsing endpoints"
echo "   3. Update systemd services for production"
