#!/bin/bash
set -e

echo "🔨 Building Lambda Function Package..."

# Create temporary build directory
BUILD_DIR="build"
rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR

# Copy source code
echo "📦 Copying source code..."
cp -r src/* $BUILD_DIR/

# Create zip file
echo "🗜️  Creating function.zip..."
cd $BUILD_DIR
zip -r ../function.zip . -q
cd ..

# Clean up
rm -rf $BUILD_DIR

echo "✅ Function built: function.zip"
echo "📊 Function size: $(du -h function.zip | cut -f1)"

echo ""
echo "Next step: Build the layer with ./build-layer.sh"

