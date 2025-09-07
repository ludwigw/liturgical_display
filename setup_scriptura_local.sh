#!/bin/bash

# Setup Scriptura API locally
# This script sets up the Scriptura API to run locally instead of using the remote API

set -e

SCRIPTURA_DIR="scriptura-api"
SCRIPTURA_REPO="https://github.com/AlexLamper/ScripturaAPI.git"
SCRIPTURA_PORT=8081

echo "🚀 Setting up Scriptura API locally..."

# Check if scriptura directory exists
if [ -d "$SCRIPTURA_DIR" ]; then
    echo "📁 Scriptura directory already exists, updating..."
    cd "$SCRIPTURA_DIR"
    git pull origin main
else
    echo "📥 Cloning Scriptura API repository..."
    git clone "$SCRIPTURA_REPO" "$SCRIPTURA_DIR"
    cd "$SCRIPTURA_DIR"
fi

# Create virtual environment for Scriptura
if [ ! -d "venv" ]; then
    echo "🐍 Creating virtual environment for Scriptura..."
    python3 -m venv venv
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

echo "✅ Scriptura API setup complete!"
echo ""
echo "🔧 To start Scriptura API locally:"
echo "   cd $SCRIPTURA_DIR"
echo "   source venv/bin/activate"
echo "   uvicorn main:app --host 0.0.0.0 --port $SCRIPTURA_PORT"
echo ""
echo "🌐 API will be available at: http://localhost:$SCRIPTURA_PORT"
echo "📚 Documentation: http://localhost:$SCRIPTURA_PORT/docs"
echo ""
echo "🔄 Next steps:"
echo "   1. Start Scriptura API locally"
echo "   2. Update ScripturaService to use local instance"
echo "   3. Test all functionality"
echo "   4. Update systemd services for production"
