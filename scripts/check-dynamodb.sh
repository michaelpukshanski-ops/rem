#!/bin/bash

# Check DynamoDB records for debugging

TABLE_NAME="rem-recordings-dev"

echo "📊 Checking DynamoDB Table: ${TABLE_NAME}"
echo "========================================"
echo ""

# Scan all records
echo "Recent recordings:"
aws dynamodb scan \
  --table-name ${TABLE_NAME} \
  --limit 10 \
  --output json | jq -r '.Items[] | "RecordingID: \(.recordingId.S)\nDevice: \(.deviceId.S)\nS3 Key: \(.s3KeyRaw.S)\nStatus: \(.status.S)\nCreated: \(.createdAt.S)\n---"'

echo ""
echo "Total records:"
aws dynamodb scan \
  --table-name ${TABLE_NAME} \
  --select COUNT \
  --output json | jq '.Count'

