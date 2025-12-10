#!/bin/bash
# View ECS worker logs from CloudWatch

set -e

# Get the absolute path to the repository root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Get log group from Terraform
cd "$REPO_ROOT/cloud/infra"

LOG_GROUP=$(terraform output -raw ecs_logs_group 2>/dev/null || echo "")

# Fallback to default name if Terraform output not available
if [ -z "$LOG_GROUP" ]; then
  LOG_GROUP="/ecs/rem-transcription-worker-dev"
fi

echo "📋 Viewing ECS worker logs from: $LOG_GROUP"
echo "   Press Ctrl+C to stop"
echo ""

# Tail logs (requires awslogs or use aws logs tail if available)
if command -v awslogs &> /dev/null; then
  awslogs get "$LOG_GROUP" --watch
else
  # Fallback to manual polling
  echo "💡 Tip: Install awslogs for better log viewing: pip install awslogs"
  echo ""
  
  # Get latest log stream
  STREAM=$(aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP" \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --query 'logStreams[0].logStreamName' \
    --output text)
  
  if [ "$STREAM" = "None" ] || [ -z "$STREAM" ]; then
    echo "❌ No log streams found. Worker may not have started yet."
    exit 1
  fi
  
  echo "📄 Latest log stream: $STREAM"
  echo ""
  
  # Fetch logs
  aws logs get-log-events \
    --log-group-name "$LOG_GROUP" \
    --log-stream-name "$STREAM" \
    --limit 100 \
    --query 'events[*].[timestamp,message]' \
    --output text | \
    while IFS=$'\t' read -r timestamp message; do
      date_str=$(date -r $((timestamp / 1000)) '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")
      echo "[$date_str] $message"
    done
  
  echo ""
  echo "💡 For live tail, install: pip install awslogs"
  echo "   Then run: awslogs get $LOG_GROUP --watch"
fi

