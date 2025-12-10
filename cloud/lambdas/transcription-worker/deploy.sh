#!/bin/bash
set -e

echo "🚀 Deploying Transcription Worker Lambda"
echo "=========================================="
echo ""

# Step 1: Build and push Docker image
echo "Step 1: Building Docker image..."
./build-docker.sh

echo ""
echo "Step 2: Deploying with Terraform..."
cd ../../infra

# Deploy infrastructure
terraform init -upgrade
terraform apply -auto-approve

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Next steps:"
echo "1. Test the Lambda function"
echo "2. Monitor CloudWatch logs: /aws/lambda/rem-transcription-worker-dev"
echo "3. Remove ECS resources once confident"

