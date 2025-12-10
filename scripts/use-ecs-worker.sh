#!/bin/bash
# Switch to using ECS Fargate worker (stop local worker)

set -e

# Get the absolute path to the repository root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔄 Switching to ECS FARGATE worker mode..."
echo ""

# Get ECS cluster and service names from Terraform
cd "$REPO_ROOT/cloud/infra"

CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "")
SERVICE_NAME=$(terraform output -raw ecs_service_name 2>/dev/null || echo "")

# Fallback to default names if Terraform outputs not available
if [ -z "$CLUSTER_NAME" ]; then
  CLUSTER_NAME="rem-transcription-cluster-dev"
fi

if [ -z "$SERVICE_NAME" ]; then
  SERVICE_NAME="rem-transcription-worker-dev"
fi

echo "📊 Current ECS status:"
aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --query 'services[0].{DesiredCount:desiredCount,RunningCount:runningCount}' \
  --output table

echo ""
echo "▶️  Starting ECS Fargate worker..."

aws ecs update-service \
  --cluster "$CLUSTER_NAME" \
  --service "$SERVICE_NAME" \
  --desired-count 1 \
  --no-cli-pager > /dev/null

echo "✅ ECS worker started (desired count = 1)"
echo ""
echo "⚠️  IMPORTANT: Stop your local worker if it's running!"
echo "   Check for running worker process:"
echo "   ps aux | grep worker.py"
echo ""
echo "   Kill local worker:"
echo "   pkill -f worker.py"
echo ""
echo "📝 Monitor ECS worker:"
echo "   ./scripts/check-worker-status.sh"
echo "   ./scripts/view-ecs-logs.sh"
echo ""
echo "💡 The worker will auto-scale based on SQS queue depth:"
echo "   - Scales up when messages > 1"
echo "   - Scales down to 0 when queue is empty for 5 minutes"

