#!/bin/bash
set -e

echo "🐳 Building Docker-based Lambda for Transcription Worker..."
echo ""

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found!"
    echo ""
    echo "Please provide your AWS account ID and region manually:"
    echo ""
    read -p "AWS Account ID: " AWS_ACCOUNT_ID
    read -p "AWS Region [us-east-1]: " AWS_REGION
    AWS_REGION=${AWS_REGION:-us-east-1}
else
    # Get AWS account ID and region
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=$(aws configure get region || echo "us-east-1")
fi

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
if command -v aws &> /dev/null; then
    echo "📦 Creating ECR repository (if needed)..."
    aws ecr describe-repositories --repository-names $ECR_REPO --region $AWS_REGION 2>/dev/null || \
      aws ecr create-repository --repository-name $ECR_REPO --region $AWS_REGION
else
    echo "⚠️  Skipping ECR repository creation (AWS CLI not available)"
    echo "   Please create the repository manually or run Terraform first"
fi

echo ""
echo "🔨 Building Docker image..."
docker build --platform linux/amd64 -t $ECR_REPO:$IMAGE_TAG .

echo ""
echo "🏷️  Tagging image for ECR..."
docker tag $ECR_REPO:$IMAGE_TAG $ECR_URI:$IMAGE_TAG

if command -v aws &> /dev/null; then
    echo ""
    echo "🔐 Logging in to ECR..."
    aws ecr get-login-password --region $AWS_REGION | \
      docker login --username AWS --password-stdin $ECR_URI

    echo ""
    echo "⬆️  Pushing image to ECR..."
    docker push $ECR_URI:$IMAGE_TAG

    echo ""
    echo "✅ Docker image built and pushed successfully!"
else
    echo ""
    echo "⚠️  AWS CLI not available - skipping ECR push"
    echo ""
    echo "To push manually:"
    echo "1. Login to ECR:"
    echo "   aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URI"
    echo "2. Push image:"
    echo "   docker push $ECR_URI:$IMAGE_TAG"
fi

echo ""
echo "📊 Image URI: $ECR_URI:$IMAGE_TAG"
echo ""
echo "Next steps:"
echo "1. Push image to ECR (if not done above)"
echo "2. Run: terraform apply in cloud/infra"

