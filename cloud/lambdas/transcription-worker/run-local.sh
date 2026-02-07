#!/bin/bash
set -e

# Check for ffmpeg
if ! command -v ffmpeg &> /dev/null; then
    echo "❌ ffmpeg is not installed. It is required for audio processing."
    echo "Please install it using Homebrew:"
    echo "brew install ffmpeg"
    exit 1
fi

# Check for terraform
if ! command -v terraform &> /dev/null; then
    echo "❌ terraform is not installed. It is required to fetch configuration."
    echo "Please install it using Homebrew:"
    echo "brew tap hashicorp/tap"
    echo "brew install hashicorp/tap/terraform"
    exit 1
fi

# Check for Python 3.11
if ! command -v python3.11 &> /dev/null; then
    echo "⚠️  python3.11 not found, trying python3..."
    PYTHON_CMD=python3
else
    PYTHON_CMD=python3.11
fi

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    $PYTHON_CMD -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
echo "⬇️  Installing dependencies..."
pip install -r requirements.txt

# Check for API keys in .env
if [ ! -f .env ]; then
    echo "⚠️  .env file not found."
    echo "Please create a .env file with your API keys:"
    echo "OPENAI_API_KEY='sk-...'"
    echo "HUGGINGFACE_TOKEN='hf_...'"
    echo ""
    echo "AWS configuration will be fetched from Terraform state."
fi

# Run the worker
echo "🚀 Starting local worker..."
python src/run_local.py
