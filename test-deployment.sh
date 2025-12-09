#!/bin/bash

# REM System - Deployment Test Script

set -e

echo "🧪 REM System Deployment Test"
echo "================================"
echo ""

# Get Terraform outputs
echo "📋 Getting Terraform outputs..."
cd cloud/infra
API_URL=$(terraform output -raw api_gateway_url)
API_KEY=$(terraform output -raw api_key)
cd ../..

echo "✅ API Gateway URL: $API_URL"
echo "✅ API Key: ${API_KEY:0:10}..."
echo ""

# Test 1: Health check (if you add one)
echo "🔍 Test 1: API Gateway connectivity"
echo "Testing: $API_URL/query"
RESPONSE=$(curl -s -X POST "$API_URL/query" \
  -H "Content-Type: application/json" \
  -d '{"userId":"test","query":"test","limit":1}')

if [ $? -eq 0 ]; then
  echo "✅ API Gateway is reachable"
  echo "Response: $RESPONSE"
else
  echo "❌ API Gateway is not reachable"
  exit 1
fi
echo ""

# Test 2: Check S3 buckets
echo "🔍 Test 2: Checking S3 buckets"
RAW_BUCKET=$(aws s3 ls | grep rem-raw-audio | awk '{print $3}')
TRANSCRIPTS_BUCKET=$(aws s3 ls | grep rem-transcripts | awk '{print $3}')

if [ -n "$RAW_BUCKET" ]; then
  echo "✅ Raw audio bucket exists: $RAW_BUCKET"
else
  echo "❌ Raw audio bucket not found"
fi

if [ -n "$TRANSCRIPTS_BUCKET" ]; then
  echo "✅ Transcripts bucket exists: $TRANSCRIPTS_BUCKET"
else
  echo "❌ Transcripts bucket not found"
fi
echo ""

# Test 3: Check DynamoDB table
echo "🔍 Test 3: Checking DynamoDB table"
TABLE_STATUS=$(aws dynamodb describe-table --table-name rem-recordings-dev --query 'Table.TableStatus' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$TABLE_STATUS" = "ACTIVE" ]; then
  echo "✅ DynamoDB table is active"
else
  echo "❌ DynamoDB table not found or not active"
fi
echo ""

# Test 4: Check SQS queue
echo "🔍 Test 4: Checking SQS queue"
QUEUE_URL=$(aws sqs list-queues --queue-name-prefix rem-transcription-jobs --query 'QueueUrls[0]' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$QUEUE_URL" != "NOT_FOUND" ] && [ "$QUEUE_URL" != "None" ]; then
  echo "✅ SQS queue exists: $QUEUE_URL"
else
  echo "❌ SQS queue not found"
fi
echo ""

# Test 5: Check Lambda functions
echo "🔍 Test 5: Checking Lambda functions"
LAMBDAS=("rem-ingest-audio-dev" "rem-transcription-dispatcher-dev" "rem-query-transcripts-dev")

for LAMBDA in "${LAMBDAS[@]}"; do
  STATUS=$(aws lambda get-function --function-name "$LAMBDA" --query 'Configuration.State' --output text 2>/dev/null || echo "NOT_FOUND")
  if [ "$STATUS" = "Active" ]; then
    echo "✅ Lambda function active: $LAMBDA"
  else
    echo "❌ Lambda function not found or not active: $LAMBDA"
  fi
done
echo ""

# Summary
echo "================================"
echo "🎉 Deployment test complete!"
echo ""
echo "Next steps:"
echo "1. Configure GPU worker .env file"
echo "2. Run: make run-worker"
echo "3. Configure and flash ESP32"
echo "4. Test end-to-end recording"
echo ""
echo "API Details:"
echo "  URL: $API_URL"
echo "  Key: $API_KEY"

