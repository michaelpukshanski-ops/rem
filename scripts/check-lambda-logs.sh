#!/bin/bash

# REM System - Lambda Logs Checker
# Quickly check CloudWatch logs for Lambda functions

set -e

ENVIRONMENT=${1:-dev}
LAMBDA_NAME=${2:-ingest-audio}

LOG_GROUP="/aws/lambda/rem-${LAMBDA_NAME}-${ENVIRONMENT}"

echo "🔍 Checking Lambda logs: $LOG_GROUP"
echo "========================================"
echo ""

# Check if log group exists
if ! aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$LOG_GROUP"; then
  echo "❌ Log group not found: $LOG_GROUP"
  echo ""
  echo "Available Lambda functions:"
  echo "  - ingest-audio"
  echo "  - transcription-dispatcher"
  echo "  - query-transcripts"
  echo ""
  echo "Usage: $0 [environment] [lambda-name]"
  echo "Example: $0 dev ingest-audio"
  exit 1
fi

echo "📋 Recent logs (last 5 minutes):"
echo ""

# Tail logs from last 5 minutes
aws logs tail "$LOG_GROUP" --since 5m --format short

echo ""
echo "========================================"
echo "✅ Done"
echo ""
echo "To follow logs in real-time, run:"
echo "  aws logs tail $LOG_GROUP --follow"

