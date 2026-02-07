#!/bin/bash
# REM GPU Worker Setup for macOS (Apple Silicon)
# Sets up the transcription worker and USB watcher on Mac Mini

set -e

echo "=== REM GPU Worker Setup for macOS ==="
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Error: This script is for macOS only"
    exit 1
fi

# Check for Apple Silicon
ARCH=$(uname -m)
if [[ "$ARCH" != "arm64" ]]; then
    echo "Warning: This script is optimized for Apple Silicon (M1/M2/M3)"
    echo "Detected architecture: $ARCH"
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "Working directory: $SCRIPT_DIR"
echo ""

# Step 1: Install Homebrew if not installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "✓ Homebrew already installed"
fi

# Step 2: Install dependencies
echo ""
echo "Installing system dependencies..."
brew install python@3.11 ffmpeg

# Step 3: Create virtual environment
echo ""
echo "Creating Python virtual environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "✓ Virtual environment created"
else
    echo "✓ Virtual environment already exists"
fi

# Step 4: Activate and install Python packages
echo ""
echo "Installing Python dependencies..."
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Step 5: Configure environment
echo ""
if [ ! -f ".env" ]; then
    echo "Creating .env file..."
    cat > .env << 'EOF'
# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=

# S3 Buckets
RAW_AUDIO_BUCKET=
TRANSCRIPTS_BUCKET=

# SQS Queue
SQS_QUEUE_URL=

# DynamoDB
DYNAMODB_TABLE=

# Whisper Configuration for Mac (Apple Silicon M4)
# Use 'mps' for GPU acceleration via Metal Performance Shaders
WHISPER_MODEL=base
WHISPER_DEVICE=mps
WHISPER_COMPUTE_TYPE=float16

# OpenAI API (for embeddings and summarization)
OPENAI_API_KEY=

# HuggingFace Token (for speaker diarization)
HUGGINGFACE_TOKEN=

# REM User Configuration
REM_USER_ID=
REM_DEVICE_ID=usb-uploader

# Logging
LOG_LEVEL=INFO
EOF
    echo "✓ .env file created - PLEASE EDIT IT WITH YOUR CONFIGURATION"
    echo ""
    echo "You need to fill in:"
    echo "  - AWS credentials and resource names (from Terraform output)"
    echo "  - OpenAI API key (optional, for AI features)"
    echo "  - HuggingFace token (optional, for speaker diarization)"
    echo "  - REM_USER_ID (your Clerk user ID)"
    echo ""
    read -p "Press Enter after you've edited .env file..."
else
    echo "✓ .env file already exists"
fi

# Step 6: Test the worker
echo ""
echo "Testing worker setup..."
python3 -c "from faster_whisper import WhisperModel; print('✓ Whisper import successful')"

# Step 7: Setup LaunchAgent for USB watcher
echo ""
echo "Setting up USB watcher auto-start..."

# Update plist with correct paths
PLIST_FILE="com.rem.usbwatcher.plist"
USER_HOME="$HOME"
sed -i '' "s|/Users/michaelpukshanski|$USER_HOME|g" "$PLIST_FILE"

# Copy to LaunchAgents
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCH_AGENTS_DIR"
cp "$PLIST_FILE" "$LAUNCH_AGENTS_DIR/"

echo "✓ LaunchAgent installed"
echo ""
echo "To start USB watcher now:"
echo "  launchctl load ~/Library/LaunchAgents/com.rem.usbwatcher.plist"
echo ""
echo "To stop USB watcher:"
echo "  launchctl unload ~/Library/LaunchAgents/com.rem.usbwatcher.plist"
echo ""
echo "To view logs:"
echo "  tail -f ~/Library/Logs/rem-usb-watcher.log"
echo ""

# Step 8: Instructions
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Edit .env file with your AWS and user configuration"
echo "2. Start the USB watcher: launchctl load ~/Library/LaunchAgents/com.rem.usbwatcher.plist"
echo "3. Or run manually: source venv/bin/activate && python3 usb_watcher_mac.py"
echo ""
echo "For GPU transcription worker (processes from SQS):"
echo "  source venv/bin/activate && python3 src/worker.py"
echo ""

