#!/bin/bash
# Delete all data for a specific user from REM system
# Usage: ./delete-user-data.sh <user_id>
#
# This script deletes:
# 1. All DynamoDB records for the user
# 2. All S3 transcripts for the user
# 3. All S3 raw audio files for devices associated with the user

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration - get from terraform outputs or set manually
REGION="${AWS_REGION:-us-east-1}"
DYNAMODB_TABLE="${DYNAMODB_TABLE:-rem-recordings-dev}"
RAW_AUDIO_BUCKET="${RAW_AUDIO_BUCKET:-}"
TRANSCRIPTS_BUCKET="${TRANSCRIPTS_BUCKET:-}"

# Check arguments
if [ -z "$1" ]; then
    echo -e "${RED}Error: User ID required${NC}"
    echo "Usage: $0 <user_id>"
    echo ""
    echo "Example: $0 default-user"
    echo ""
    echo "Environment variables (optional):"
    echo "  AWS_REGION         - AWS region (default: us-east-1)"
    echo "  DYNAMODB_TABLE     - DynamoDB table name"
    echo "  RAW_AUDIO_BUCKET   - S3 bucket for raw audio"
    echo "  TRANSCRIPTS_BUCKET - S3 bucket for transcripts"
    exit 1
fi

USER_ID="$1"

echo "========================================="
echo "REM - Delete User Data"
echo "========================================="
echo ""
echo -e "${YELLOW}User ID: ${USER_ID}${NC}"
echo "Region: ${REGION}"
echo ""

# Try to get bucket names from terraform if not set
if [ -z "$RAW_AUDIO_BUCKET" ] || [ -z "$TRANSCRIPTS_BUCKET" ]; then
    echo "Attempting to get bucket names from Terraform..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    INFRA_DIR="${SCRIPT_DIR}/../infra"
    
    if [ -d "$INFRA_DIR" ]; then
        cd "$INFRA_DIR"
        RAW_AUDIO_BUCKET=$(terraform output -raw raw_audio_bucket_name 2>/dev/null || echo "")
        TRANSCRIPTS_BUCKET=$(terraform output -raw transcripts_bucket_name 2>/dev/null || echo "")
        DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name 2>/dev/null || echo "$DYNAMODB_TABLE")
        cd - > /dev/null
    fi
fi

if [ -z "$RAW_AUDIO_BUCKET" ] || [ -z "$TRANSCRIPTS_BUCKET" ]; then
    echo -e "${RED}Error: Could not determine bucket names${NC}"
    echo "Please set RAW_AUDIO_BUCKET and TRANSCRIPTS_BUCKET environment variables"
    exit 1
fi

echo "DynamoDB Table: ${DYNAMODB_TABLE}"
echo "Raw Audio Bucket: ${RAW_AUDIO_BUCKET}"
echo "Transcripts Bucket: ${TRANSCRIPTS_BUCKET}"
echo ""

# Confirmation
echo -e "${RED}WARNING: This will permanently delete ALL data for user '${USER_ID}'${NC}"
read -p "Are you sure you want to continue? (type 'yes' to confirm): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "========================================="
echo "Step 1: Query DynamoDB for user records"
echo "========================================="

# Query all records for the user
RECORDS=$(aws dynamodb query \
    --table-name "$DYNAMODB_TABLE" \
    --key-condition-expression "PK = :userId" \
    --expression-attribute-values "{\":userId\": {\"S\": \"$USER_ID\"}}" \
    --projection-expression "SK, s3KeyRaw, GSI1PK" \
    --region "$REGION" \
    --output json)

RECORD_COUNT=$(echo "$RECORDS" | jq '.Items | length')
echo "Found ${RECORD_COUNT} records for user '${USER_ID}'"

if [ "$RECORD_COUNT" -eq 0 ]; then
    echo "No records found. Nothing to delete."
    exit 0
fi

# Extract device IDs for raw audio deletion
DEVICE_IDS=$(echo "$RECORDS" | jq -r '.Items[].GSI1PK.S // empty' | sort -u)
echo "Devices: $(echo $DEVICE_IDS | tr '\n' ' ')"
echo ""

echo "========================================="
echo "Step 2: Delete S3 transcripts"
echo "========================================="

# Delete transcripts for this user
TRANSCRIPT_PREFIX="transcripts/${USER_ID}/"
echo "Deleting objects with prefix: s3://${TRANSCRIPTS_BUCKET}/${TRANSCRIPT_PREFIX}"

TRANSCRIPT_COUNT=$(aws s3 ls "s3://${TRANSCRIPTS_BUCKET}/${TRANSCRIPT_PREFIX}" --recursive --region "$REGION" 2>/dev/null | wc -l | tr -d ' ')
echo "Found ${TRANSCRIPT_COUNT} transcript files"

if [ "$TRANSCRIPT_COUNT" -gt 0 ]; then
    aws s3 rm "s3://${TRANSCRIPTS_BUCKET}/${TRANSCRIPT_PREFIX}" --recursive --region "$REGION"
    echo -e "${GREEN}Transcripts deleted${NC}"
else
    echo "No transcripts to delete"
fi

echo ""
echo "========================================="
echo "Step 3: Delete S3 raw audio files"
echo "========================================="

# Delete raw audio for each device
for DEVICE_ID in $DEVICE_IDS; do
    if [ -n "$DEVICE_ID" ]; then
        RAW_PREFIX="raw/${DEVICE_ID}/"
        echo "Deleting objects with prefix: s3://${RAW_AUDIO_BUCKET}/${RAW_PREFIX}"
        
        RAW_COUNT=$(aws s3 ls "s3://${RAW_AUDIO_BUCKET}/${RAW_PREFIX}" --recursive --region "$REGION" 2>/dev/null | wc -l | tr -d ' ')
        echo "Found ${RAW_COUNT} raw audio files for device ${DEVICE_ID}"
        
        if [ "$RAW_COUNT" -gt 0 ]; then
            aws s3 rm "s3://${RAW_AUDIO_BUCKET}/${RAW_PREFIX}" --recursive --region "$REGION"
            echo -e "${GREEN}Raw audio deleted for device ${DEVICE_ID}${NC}"
        fi
    fi
done

echo ""
echo "========================================="
echo "Step 4: Delete DynamoDB records"
echo "========================================="

# Delete each record from DynamoDB
DELETED=0
echo "$RECORDS" | jq -c '.Items[]' | while read -r ITEM; do
    SK=$(echo "$ITEM" | jq -r '.SK.S')
    
    aws dynamodb delete-item \
        --table-name "$DYNAMODB_TABLE" \
        --key "{\"PK\": {\"S\": \"$USER_ID\"}, \"SK\": {\"S\": \"$SK\"}}" \
        --region "$REGION"
    
    echo "Deleted record: ${SK}"
done

echo -e "${GREEN}Deleted ${RECORD_COUNT} DynamoDB records${NC}"

echo ""
echo "========================================="
echo -e "${GREEN}✅ All data for user '${USER_ID}' has been deleted${NC}"
echo "========================================="

