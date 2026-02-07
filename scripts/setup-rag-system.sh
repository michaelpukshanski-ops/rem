#!/bin/bash
# Setup script for REM Local RAG System
# Run this on your Mac Mini to install all dependencies

set -e

echo "🚀 Setting up REM Local RAG System"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ This script is designed for macOS only"
    exit 1
fi

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not found. Please install from https://brew.sh"
    exit 1
fi

echo "✅ Homebrew found"
echo ""

# Install Ollama
echo "📦 Installing Ollama..."
if command -v ollama &> /dev/null; then
    echo "✅ Ollama already installed"
else
    brew install ollama
    echo "✅ Ollama installed"
fi
echo ""

# Start Ollama service
echo "🔧 Starting Ollama service..."
brew services start ollama
sleep 3
echo "✅ Ollama service started"
echo ""

# Pull Llama 3.2 model
echo "📥 Downloading Llama 3.2 3B model (this may take a few minutes)..."
ollama pull llama3.2:3b
echo "✅ Llama 3.2 model downloaded"
echo ""

# Install Python dependencies
echo "📦 Installing Python dependencies..."
cd "$(dirname "$0")/../cloud/gpu-worker"

if [ ! -d "venv" ]; then
    echo "❌ Virtual environment not found. Please run setup first:"
    echo "   cd cloud/gpu-worker && python3 -m venv venv"
    exit 1
fi

source venv/bin/activate

# Install PyTorch with MPS support
echo "📦 Installing PyTorch for Apple Silicon..."
pip3 install --upgrade pip
pip3 install torch torchvision torchaudio

# Install RAG dependencies
echo "📦 Installing RAG dependencies..."
pip3 install -r requirements-rag.txt

echo "✅ Python dependencies installed"
echo ""

# Create local storage directories
echo "📁 Creating local storage directories..."
mkdir -p ~/.rem/transcripts
mkdir -p ~/.rem/chroma
echo "✅ Directories created"
echo ""

# Download embedding model (will be cached)
echo "📥 Downloading embedding model (one-time, ~80MB)..."
python3 -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')"
echo "✅ Embedding model downloaded"
echo ""

# Test Ollama
echo "🧪 Testing Ollama..."
if ollama list | grep -q "llama3.2:3b"; then
    echo "✅ Ollama is working correctly"
else
    echo "⚠️  Llama model not found, attempting to pull again..."
    ollama pull llama3.2:3b
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ RAG System Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Sync transcripts from S3:"
echo "   cd cloud/gpu-worker"
echo "   source venv/bin/activate"
echo "   python3 scripts/sync-transcripts.py"
echo ""
echo "2. Index transcripts:"
echo "   python3 src/indexer.py"
echo ""
echo "3. Query your memories:"
echo "   python3 src/query_memory.py \"What did I say about AWS?\""
echo ""
echo "🎉 Enjoy your local AI memory system!"

