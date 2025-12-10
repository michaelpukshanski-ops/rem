#!/bin/bash
set -e

echo "🔨 Building Docker image locally..."
echo ""

# Build for Linux AMD64 (Lambda architecture)
docker build --platform linux/amd64 -t rem-transcription-worker:latest .

echo ""
echo "✅ Docker image built successfully!"
echo ""
echo "📊 Image: rem-transcription-worker:latest"
echo ""
echo "Next steps:"
echo "1. Deploy infrastructure with Terraform (creates ECR repo)"
echo "2. Tag and push image to ECR"
echo ""
echo "See LAMBDA-MIGRATION-GUIDE.md for detailed instructions"

