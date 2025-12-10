#!/bin/bash
# Check status of both local and ECS workers

set -e

echo "🔍 Checking Worker Status..."
echo ""

# Get Terraform outputs
cd "$(dirname "$0")/../cloud/infra"

CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "")
SERVICE_NAME=$(terraform output -raw ecs_service_name 2>/dev/null || echo "")
QUEUE_URL=$(terraform output -raw sqs_queue_url 2>/dev/null || echo "")

# Check ECS Worker
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 ECS FARGATE WORKER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -n "$CLUSTER_NAME" ] && [ -n "$SERVICE_NAME" ]; then
  aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --query 'services[0].{Status:status,DesiredCount:desiredCount,RunningCount:runningCount,PendingCount:pendingCount}' \
    --output table
  
  RUNNING_TASKS=$(aws ecs list-tasks \
    --cluster "$CLUSTER_NAME" \
    --service-name "$SERVICE_NAME" \
    --query 'taskArns' \
    --output text | wc -w | tr -d ' ')
  
  if [ "$RUNNING_TASKS" -gt 0 ]; then
    echo ""
    echo "✅ ECS worker is ACTIVE ($RUNNING_TASKS task(s) running)"
  else
    echo ""
    echo "⏸️  ECS worker is STOPPED (0 tasks running)"
  fi
else
  echo "❌ ECS not configured"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💻 LOCAL WORKER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

LOCAL_WORKER=$(ps aux | grep "[w]orker.py" || echo "")

if [ -n "$LOCAL_WORKER" ]; then
  echo "✅ Local worker is RUNNING:"
  echo "$LOCAL_WORKER" | awk '{print "   PID: "$2", CPU: "$3"%, MEM: "$4"%"}'
else
  echo "⏸️  Local worker is NOT RUNNING"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📬 SQS QUEUE STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -n "$QUEUE_URL" ]; then
  aws sqs get-queue-attributes \
    --queue-url "$QUEUE_URL" \
    --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
    --query 'Attributes.{Available:ApproximateNumberOfMessages,InFlight:ApproximateNumberOfMessagesNotVisible}' \
    --output table
  
  MESSAGES=$(aws sqs get-queue-attributes \
    --queue-url "$QUEUE_URL" \
    --attribute-names ApproximateNumberOfMessages \
    --query 'Attributes.ApproximateNumberOfMessages' \
    --output text)
  
  if [ "$MESSAGES" -gt 0 ]; then
    echo ""
    echo "⚠️  $MESSAGES message(s) waiting to be processed"
  else
    echo ""
    echo "✅ Queue is empty"
  fi
else
  echo "❌ Queue URL not found"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 RECOMMENDATIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -n "$LOCAL_WORKER" ] && [ "$RUNNING_TASKS" -gt 0 ]; then
  echo "⚠️  WARNING: Both local and ECS workers are running!"
  echo "   They will compete for SQS messages."
  echo "   Run: ./scripts/use-local-worker.sh OR ./scripts/use-ecs-worker.sh"
elif [ -z "$LOCAL_WORKER" ] && [ "$RUNNING_TASKS" -eq 0 ]; then
  echo "⚠️  WARNING: No workers are running!"
  echo "   Messages will not be processed."
  echo "   Run: ./scripts/use-local-worker.sh OR ./scripts/use-ecs-worker.sh"
else
  echo "✅ Worker configuration looks good!"
fi

echo ""

