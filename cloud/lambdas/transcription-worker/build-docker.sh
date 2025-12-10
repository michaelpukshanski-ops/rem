#!/bin/bash
set -e

echo "🐳 Building Docker-based Lambda for Transcription Worker..."
echo ""

# Get AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "us-east-1")

# ECR repository name
ECR_REPO="rem-transcription-worker"
IMAGE_TAG="latest"
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

echo "📋 Configuration:"
echo "   AWS Account: $AWS_ACCOUNT_ID"
echo "   AWS Region: $AWS_REGION"
echo "   ECR Repository: $ECR_REPO"
echo "   Image URI: $ECR_URI:$IMAGE_TAG"
echo ""

# Create ECR repository if it doesn't exist
echo "📦 Creating ECR repository (if needed)..."
aws ecr describe-repositories --repository-names $ECR_REPO --region $AWS_REGION 2>/dev/null || \
  aws ecr create-repository --repository-name $ECR_REPO --region $AWS_REGION

echo ""
echo "🔨 Building Docker image..."
docker build --platform linux/amd64 -t $ECR_REPO:$IMAGE_TAG .

echo ""
echo "🏷️  Tagging image for ECR..."
docker tag $ECR_REPO:$IMAGE_TAG $ECR_URI:$IMAGE_TAG

echo ""
echo "🔐 Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_URI

echo ""
echo "⬆️  Pushing image to ECR..."
docker push $ECR_URI:$IMAGE_TAG

echo ""
echo "✅ Docker image built and pushed successfully!"
echo ""
echo "📊 Image URI: $ECR_URI:$IMAGE_TAG"
echo ""
echo "Next steps:"
echo "1. Update Terraform to use this image URI"
echo "2. Run: terraform apply in cloud/infra"

