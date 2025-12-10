#!/bin/bash
set -e

echo "🔨 Building Lambda Layer for Transcription Worker..."
echo ""
echo "⚠️  NOTE: This layer will be LARGE (~500-800 MB uncompressed)"
echo "   Lambda layers have a 250 MB limit when zipped."
echo "   We'll need to use a Docker-based Lambda instead."
echo ""
echo "Building anyway for reference..."
echo ""

# Create layer directory structure
LAYER_DIR="layer"
PYTHON_DIR="$LAYER_DIR/python"

rm -rf $LAYER_DIR
mkdir -p $PYTHON_DIR

echo "📦 Installing Python dependencies..."
echo "   This may take 5-10 minutes..."

# Install dependencies to layer directory
pip install -r requirements.txt -t $PYTHON_DIR --platform manylinux2014_x86_64 --only-binary=:all: --upgrade --no-cache-dir

echo ""
echo "🗜️  Creating layer zip..."

cd $LAYER_DIR
zip -r ../transcription-worker-layer.zip . -q
cd ..

echo "✅ Layer built: transcription-worker-layer.zip"
echo "📊 Layer size: $(du -h transcription-worker-layer.zip | cut -f1)"

# Check if layer is too large (250 MB limit)
LAYER_SIZE=$(stat -f%z transcription-worker-layer.zip 2>/dev/null || stat -c%s transcription-worker-layer.zip)
MAX_SIZE=$((250 * 1024 * 1024))

echo ""
if [ $LAYER_SIZE -gt $MAX_SIZE ]; then
    echo "❌ Layer size exceeds 250 MB limit!"
    echo "   Actual size: $(echo "scale=2; $LAYER_SIZE / 1024 / 1024" | bc) MB"
    echo ""
    echo "📦 SOLUTION: Use Docker-based Lambda instead"
    echo "   See: build-docker.sh"
else
    echo "✅ Layer size OK (under 250 MB limit)"
    echo ""
    echo "Next steps:"
    echo "1. Run: terraform apply in cloud/infra"
fi

