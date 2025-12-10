#!/bin/bash
# Build and push worker Docker image to ECR

set -e

# Get the absolute path to the repository root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🐳 Building and pushing worker Docker image to ECR..."
echo ""

# Get ECR repository URL from Terraform
cd "$REPO_ROOT/cloud/infra"

ECR_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

if [ -z "$ECR_URL" ]; then
  echo "❌ Error: Could not get ECR repository URL from Terraform"
  echo "   Make sure you've deployed the infrastructure first:"
  echo "   cd cloud/infra && terraform apply"
  exit 1
fi

echo "📦 ECR Repository: $ECR_URL"
echo "🌍 AWS Region: $AWS_REGION"
echo ""

# Login to ECR
echo "🔐 Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_URL"

echo "✅ Logged in to ECR"
echo ""

# Build Docker image
echo "🔨 Building Docker image..."
cd "$REPO_ROOT/cloud/gpu-worker"

docker build -t rem-worker:latest .

echo "✅ Docker image built"
echo ""

# Tag image
echo "🏷️  Tagging image..."
docker tag rem-worker:latest "$ECR_URL:latest"

# Also tag with timestamp for versioning
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
docker tag rem-worker:latest "$ECR_URL:$TIMESTAMP"

echo "✅ Image tagged: latest and $TIMESTAMP"
echo ""

# Push to ECR
echo "📤 Pushing to ECR..."
docker push "$ECR_URL:latest"
docker push "$ECR_URL:$TIMESTAMP"

echo ""
echo "✅ Docker image pushed successfully!"
echo ""
echo "📝 Next steps:"
echo "   1. Update ECS service to use new image:"
echo "      aws ecs update-service \\"
echo "        --cluster rem-transcription-cluster-dev \\"
echo "        --service rem-transcription-worker-dev \\"
echo "        --force-new-deployment"
echo ""
echo "   2. Or enable ECS worker:"
echo "      ./scripts/use-ecs-worker.sh"
echo ""
echo "   3. Check status:"
echo "      ./scripts/check-worker-status.sh"

