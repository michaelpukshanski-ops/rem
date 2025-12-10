#!/bin/bash
# Switch to using local GPU worker (stop ECS Fargate)

set -e

# Get the absolute path to the repository root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔄 Switching to LOCAL worker mode..."
echo ""

# Get ECS cluster and service names from Terraform
cd "$REPO_ROOT/cloud/infra"

CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "")
SERVICE_NAME=$(terraform output -raw ecs_service_name 2>/dev/null || echo "")

if [ -z "$CLUSTER_NAME" ] || [ -z "$SERVICE_NAME" ]; then
  echo "❌ Error: Could not get ECS cluster/service names from Terraform"
  echo "   Make sure you've deployed the infrastructure first."
  exit 1
fi

echo "📊 Current ECS status:"
aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --query 'services[0].{DesiredCount:desiredCount,RunningCount:runningCount}' \
  --output table

echo ""
echo "⏸️  Stopping ECS Fargate worker..."

aws ecs update-service \
  --cluster "$CLUSTER_NAME" \
  --service "$SERVICE_NAME" \
  --desired-count 0 \
  --no-cli-pager > /dev/null

echo "✅ ECS worker stopped (desired count = 0)"
echo ""
echo "📝 Next steps:"
echo "   1. Start your local worker:"
echo "      cd cloud/gpu-worker"
echo "      source venv/bin/activate"
echo "      python src/worker.py"
echo ""
echo "   2. Or run in background:"
echo "      nohup python src/worker.py > worker.log 2>&1 &"
echo ""
echo "   3. Check status anytime:"
echo "      ./scripts/check-worker-status.sh"

