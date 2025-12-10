#!/bin/bash
# Build and push Docker image to ECR for REM transcription worker

set -e

# Configuration
REGION="${AWS_REGION:-us-east-1}"
REPOSITORY_NAME="rem-transcription-worker"

echo "========================================="
echo "REM Transcription Worker - Build & Push"
echo "========================================="
echo ""

# Get ECR repository URL
echo "1. Getting ECR repository URL..."
ECR_REPO=$(aws ecr describe-repositories \
  --repository-names "$REPOSITORY_NAME" \
  --region "$REGION" \
  --query 'repositories[0].repositoryUri' \
  --output text)

if [ -z "$ECR_REPO" ]; then
  echo "❌ Error: ECR repository '$REPOSITORY_NAME' not found in region $REGION"
  exit 1
fi

echo "   ECR Repository: $ECR_REPO"
echo ""

# Login to ECR
echo "2. Logging in to ECR..."
aws ecr get-login-password --region "$REGION" | \
  docker login --username AWS --password-stdin "$ECR_REPO"
echo ""

# Build the Docker image
echo "3. Building Docker image..."
docker build -t "$REPOSITORY_NAME" .
echo ""

# Tag the image
echo "4. Tagging image as 'latest'..."
docker tag "$REPOSITORY_NAME:latest" "$ECR_REPO:latest"
echo ""

# Push to ECR
echo "5. Pushing image to ECR..."
docker push "$ECR_REPO:latest"
echo ""

# Verify the push
echo "6. Verifying image in ECR..."
aws ecr describe-images \
  --repository-name "$REPOSITORY_NAME" \
  --region "$REGION" \
  --query 'imageDetails[*].[imageTags[0],imagePushedAt,imageSizeInBytes]' \
  --output table
echo ""

echo "========================================="
echo "✅ Build and push complete!"
echo "========================================="
echo ""
echo "Image: $ECR_REPO:latest"
echo ""
echo "Next steps:"
echo "1. ECS will automatically pull the new image"
echo "2. Monitor logs:"
echo "   aws logs tail /ecs/rem-transcription-worker-dev --region $REGION --follow"
echo ""

