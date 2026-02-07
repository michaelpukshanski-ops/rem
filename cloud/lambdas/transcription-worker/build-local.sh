#!/bin/bash
set -e

echo "🔨 Building Docker image locally..."
echo ""

# Build for local architecture (Mac Mini M1/M2/M3)
docker build -t rem-transcription-worker:latest .

echo ""
echo "✅ Docker image built successfully!"
echo ""
echo "📊 Image: rem-transcription-worker:latest"
echo ""
echo "To run locally:"
echo "docker run -v ~/.aws:/root/.aws -e AWS_PROFILE=default -e RAW_AUDIO_BUCKET=... -e TRANSCRIPTS_BUCKET=... -e DYNAMODB_TABLE=... rem-transcription-worker:latest"
