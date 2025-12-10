# REM Project - Deployment Status

**Last Updated:** 2024-12-09

## ✅ Completed

1. **AWS Infrastructure Deployed**
   - API Gateway: `rem-api-dev`
   - Lambda Functions: `rem-ingest-audio-dev`, `rem-transcription-dispatcher-dev`, `rem-query-transcripts-dev`
   - S3 Buckets: `rem-raw-audio-31ed23ee`, `rem-transcripts-31ed23ee`
   - DynamoDB Table: `rem-recordings-dev`
   - SQS Queue: `rem-transcription-jobs-dev`

2. **Lambda Build Fixed**
   - ✅ Fixed package.json to include node_modules in deployment ZIP
   - ✅ Removed `lifecycle { ignore_changes = [source_code_hash] }` from lambda.tf
   - ✅ All Lambda functions now deploy with dependencies

3. **GPU Worker Configuration**
   - ✅ Created `.env` file with Terraform outputs
   - ✅ Script: `scripts/setup-gpu-worker-env.sh`

4. **Audio Upload Working**
   - ✅ Successfully uploaded test audio file via API Gateway
   - ✅ File stored in S3: `s3://rem-raw-audio-31ed23ee/raw/test-device/...`
   - ✅ DynamoDB record created with status: `UPLOADED`

## ⚠️ Current Issue

**S3 Event Notification Not Triggering Transcription Dispatcher**

- Audio file uploaded to S3 successfully
- DynamoDB record shows status `UPLOADED`
- **Problem:** No message in SQS queue (should have 1 message)
- **Likely Cause:** S3 event notification not triggering `transcription-dispatcher` Lambda

## 🔍 Next Steps to Debug

### 1. Check S3 Event Notification Configuration
```bash
cd cloud/infra
RAW_BUCKET=$(terraform output -raw raw_audio_bucket_name)
aws s3api get-bucket-notification-configuration --bucket ${RAW_BUCKET}
```

Should show Lambda function configuration. If empty `{}`, notification wasn't created.

### 2. Check Transcription Dispatcher Logs
```bash
./scripts/check-lambda-logs.sh dev transcription-dispatcher
```

Look for:
- No logs = Lambda never triggered
- Error logs = Lambda triggered but failed

### 3. Check Lambda Permission
```bash
aws lambda get-policy \
  --function-name rem-transcription-dispatcher-dev \
  --query 'Policy' \
  --output text | jq .
```

Should show S3 has permission to invoke Lambda.

### 4. Manual Test - Trigger Dispatcher
```bash
# Get S3 key of uploaded file
RAW_BUCKET=$(terraform output -raw raw_audio_bucket_name)
S3_KEY=$(aws s3 ls s3://${RAW_BUCKET}/raw/test-device/ --recursive | awk '{print $4}' | head -1)

# Update test event
sed -i.bak "s|REPLACE_WITH_YOUR_BUCKET_NAME|${RAW_BUCKET}|g" scripts/test-s3-event.json
sed -i.bak "s|REPLACE_WITH_YOUR_S3_KEY|${S3_KEY}|g" scripts/test-s3-event.json

# Invoke Lambda manually
aws lambda invoke \
  --function-name rem-transcription-dispatcher-dev \
  --payload file://scripts/test-s3-event.json \
  --cli-binary-format raw-in-base64-out \
  response.json

# Check response
cat response.json
```

### 5. If Notification Missing - Redeploy
```bash
cd cloud/infra
terraform apply
```

## 📝 Working Commands

### Upload Audio File
```bash
cd cloud/infra
API_URL=$(terraform output -raw api_gateway_url)
API_KEY=$(terraform output -raw api_key)

curl -X POST "${API_URL}/ingest" \
  -H "x-api-key: ${API_KEY}" \
  -F "file=@test.wav" \
  -F "deviceId=test-device" \
  -F "startedAt=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  -F "endedAt=$(date -u -v+5M +%Y-%m-%dT%H:%M:%SZ)"
```

### Check SQS Queue
```bash
QUEUE_URL=$(terraform output -raw sqs_queue_url)
aws sqs get-queue-attributes \
  --queue-url ${QUEUE_URL} \
  --attribute-names ApproximateNumberOfMessages
```

### Start GPU Worker
```bash
make run-worker
```

## 🎯 Expected Flow

1. **Upload Audio** → API Gateway → `ingest-audio` Lambda
2. **Store in S3** → `s3://rem-raw-audio-31ed23ee/raw/...`
3. **Create DynamoDB Record** → Status: `UPLOADED`
4. **S3 Event Triggers** → `transcription-dispatcher` Lambda
5. **Update Status** → `TRANSCRIBING`
6. **Queue SQS Job** → Message sent to SQS
7. **GPU Worker Processes** → Downloads audio, transcribes, uploads transcript
8. **Update Status** → `TRANSCRIBED`

## 📊 Status Progression

```
UPLOADED → TRANSCRIBING → TRANSCRIBED
   ↑            ↑              ↑
ingest-    dispatcher      GPU worker
 audio       Lambda
```

## 🔧 Useful Scripts

- `./scripts/check-lambda-logs.sh [env] [lambda-name]` - Check CloudWatch logs
- `./scripts/setup-gpu-worker-env.sh` - Generate GPU worker .env file
- `./test-deployment.sh` - Test AWS resources
- `make build-lambdas` - Build all Lambda functions
- `make run-worker` - Start GPU worker

## 📚 Resources

- Terraform outputs: `cd cloud/infra && terraform output`
- Lambda logs: AWS Console → CloudWatch → Log groups
- S3 buckets: AWS Console → S3
- DynamoDB: AWS Console → DynamoDB → Tables
- SQS: AWS Console → SQS → Queues

