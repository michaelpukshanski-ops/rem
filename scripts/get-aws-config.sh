#!/bin/bash
# Get AWS configuration for REM project

set -e

echo "🔍 Fetching AWS Configuration..."
echo ""

# Get region
REGION=${AWS_REGION:-us-east-1}
echo "📍 Region: $REGION"
echo ""

# Get AWS Account ID (try multiple methods)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

if [ -z "$ACCOUNT_ID" ]; then
    # Try getting from existing SQS queue if it exists
    ACCOUNT_ID=$(aws sqs list-queues --region $REGION 2>/dev/null | grep -o '[0-9]\{12\}' | head -1 || echo "")
fi

if [ -z "$ACCOUNT_ID" ]; then
    echo "⚠️  Could not auto-detect AWS Account ID"
    echo "   Please enter your AWS Account ID (12 digits):"
    read -r ACCOUNT_ID
fi

echo "✅ AWS Account ID: $ACCOUNT_ID"
echo ""

# Find SQS queue
echo "🔍 Finding SQS queue..."
QUEUE_URL=$(aws sqs list-queues --region $REGION --query "QueueUrls[?contains(@, 'rem-transcription-jobs')]" --output text 2>/dev/null || echo "")

if [ -z "$QUEUE_URL" ]; then
    echo "❌ SQS queue not found"
else
    echo "✅ SQS Queue URL: $QUEUE_URL"
fi
echo ""

# Find S3 buckets
echo "🔍 Finding S3 buckets..."
RAW_BUCKET=$(aws s3 ls | grep rem-raw-audio | awk '{print $3}' | head -1)
TRANSCRIPTS_BUCKET=$(aws s3 ls | grep rem-transcripts | awk '{print $3}' | head -1)

if [ -z "$RAW_BUCKET" ]; then
    echo "❌ Raw audio bucket not found"
else
    echo "✅ Raw Audio Bucket: $RAW_BUCKET"
fi

if [ -z "$TRANSCRIPTS_BUCKET" ]; then
    echo "❌ Transcripts bucket not found"
else
    echo "✅ Transcripts Bucket: $TRANSCRIPTS_BUCKET"
fi
echo ""

# Find DynamoDB table
echo "🔍 Finding DynamoDB table..."
DYNAMODB_TABLE=$(aws dynamodb list-tables --region $REGION --query "TableNames[?contains(@, 'rem-recordings')]" --output text 2>/dev/null || echo "")

if [ -z "$DYNAMODB_TABLE" ]; then
    echo "❌ DynamoDB table not found"
else
    echo "✅ DynamoDB Table: $DYNAMODB_TABLE"
fi
echo ""

# Generate .env file
echo "📝 Generating .env file..."
echo ""

cat > cloud/gpu-worker/.env << EOF
# AWS Configuration
AWS_REGION=$REGION

# AWS Resources
RAW_AUDIO_BUCKET=$RAW_BUCKET
TRANSCRIPTS_BUCKET=$TRANSCRIPTS_BUCKET
SQS_QUEUE_URL=$QUEUE_URL
DYNAMODB_TABLE=$DYNAMODB_TABLE

# Whisper Configuration for Mac M4
# Note: faster-whisper doesn't support MPS yet, use CPU with optimizations
# The M4's Neural Engine will still accelerate some operations
WHISPER_MODEL=base
WHISPER_DEVICE=cpu
WHISPER_COMPUTE_TYPE=int8

# Cache directory (use local user directory, not /root)
HF_HOME=~/.cache/huggingface
TRANSFORMERS_CACHE=~/.cache/huggingface

# Optional: AI Features (get from https://platform.openai.com/api-keys)
OPENAI_API_KEY=

# Optional: Speaker Diarization (get from https://huggingface.co/settings/tokens)
HUGGINGFACE_TOKEN=

# REM User Configuration
REM_USER_ID=michael
REM_DEVICE_ID=usb-uploader

# Logging
LOG_LEVEL=INFO
EOF

echo "✅ .env file created at: cloud/gpu-worker/.env"
echo ""
echo "📋 Configuration Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "AWS_REGION=$REGION"
echo "RAW_AUDIO_BUCKET=$RAW_BUCKET"
echo "TRANSCRIPTS_BUCKET=$TRANSCRIPTS_BUCKET"
echo "SQS_QUEUE_URL=$QUEUE_URL"
echo "DYNAMODB_TABLE=$DYNAMODB_TABLE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🚀 Next steps:"
echo "   1. Add your OpenAI API key to cloud/gpu-worker/.env (optional)"
echo "   2. Start the worker: cd cloud/gpu-worker && source venv/bin/activate && python3 src/worker.py"

