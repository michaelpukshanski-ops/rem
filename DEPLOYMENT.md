# REM System - Complete Deployment Guide

This guide walks you through deploying the entire REM system from scratch.

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured (`aws configure`)
- Terraform >= 1.0
- Node.js >= 20.x
- Python >= 3.9
- PlatformIO (for ESP32)
- ESP32 development board with I2S microphone

## Step-by-Step Deployment

### Phase 1: Deploy Cloud Infrastructure

#### 1.1 Build Lambda Functions

```bash
# Build ingest-audio Lambda
cd cloud/lambdas/ingest-audio
npm install
npm run build

# Build transcription-dispatcher Lambda
cd ../transcription-dispatcher
npm install
npm run build

# Build query-transcripts Lambda
cd ../query-transcripts
npm install
npm run build

cd ../../..
```

#### 1.2 Deploy with Terraform

```bash
cd cloud/infra

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy infrastructure
terraform apply

# Save outputs
terraform output > outputs.txt
terraform output -json > outputs.json
```

#### 1.3 Note Important Outputs

```bash
# Get API Gateway URL for ESP32
terraform output api_gateway_url

# Get API Key (sensitive)
terraform output -raw api_key

# Get GPU worker configuration
terraform output gpu_worker_configuration
```

### Phase 2: Configure and Deploy ESP32

#### 2.1 Create Secrets File

```bash
cd ../../esp32
cp include/secrets.h.example include/secrets.h
```

#### 2.2 Edit secrets.h

```cpp
#define WIFI_SSID "YourWiFiNetwork"
#define WIFI_PASSWORD "YourWiFiPassword"
#define API_GATEWAY_URL "https://xxxxx.execute-api.us-east-1.amazonaws.com/ingest"
#define API_KEY "your-api-key-from-terraform"
#define USER_ID "default-user"
```

#### 2.3 Build and Flash

```bash
# Build firmware
pio run

# Upload to ESP32
pio run --target upload

# Monitor serial output
pio device monitor
```

#### 2.4 Verify ESP32 Operation

Watch serial monitor for:
- WiFi connection success
- I2S initialization
- Recording started
- File uploads (when WiFi available)

### Phase 3: Deploy GPU Worker

#### 3.1 Prepare GPU Instance

**Option A: AWS EC2 GPU Instance**
```bash
# Launch g4dn.xlarge or similar
# Install CUDA and cuDNN
# SSH into instance
```

**Option B: Local GPU Machine**
```bash
# Ensure CUDA and cuDNN are installed
nvidia-smi  # Verify GPU
```

#### 3.2 Install Dependencies

```bash
cd cloud/gpu-worker

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install requirements
pip install -r requirements.txt
```

#### 3.3 Configure Environment

```bash
cp .env.example .env
```

Edit `.env` with values from Terraform outputs:
```bash
AWS_REGION=us-east-1
SQS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/.../rem-transcription-jobs-dev
RAW_AUDIO_BUCKET=rem-raw-audio-xxxx
TRANSCRIPTS_BUCKET=rem-transcripts-xxxx
DYNAMODB_TABLE=rem-recordings-dev
WHISPER_MODEL=base
WHISPER_DEVICE=cuda
```

#### 3.4 Test Worker

```bash
# Run worker
python src/worker.py
```

Watch for:
- Whisper model loading
- SQS polling
- Job processing (when ESP32 uploads audio)

#### 3.5 Production Deployment (Optional)

**Using systemd:**
```bash
sudo cp rem-worker.service /etc/systemd/system/
sudo systemctl enable rem-worker
sudo systemctl start rem-worker
```

**Using Docker:**
```bash
docker build -t rem-worker .
docker run --gpus all --env-file .env rem-worker
```

### Phase 4: Testing End-to-End

#### 4.1 Test ESP32 Upload

1. Power on ESP32
2. Wait for WiFi connection
3. Let it record for 5+ minutes
4. Check serial monitor for upload success
5. Verify in AWS Console:
   - S3: Check raw-audio bucket for WAV file
   - DynamoDB: Check recordings table for entry

#### 4.2 Test Transcription

1. Check SQS queue for message
2. GPU worker should pick up job
3. Monitor worker logs for transcription progress
4. Verify in AWS Console:
   - S3: Check transcripts bucket for JSON/TXT
   - DynamoDB: Status should be "TRANSCRIBED"

#### 4.3 Test Query API

```bash
curl -X POST https://your-api-gateway-url/query \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "default-user",
    "query": "test",
    "limit": 5
  }'
```

Expected response with matching segments.

### Phase 5: ChatGPT Integration (Optional)

#### 5.1 Create Custom GPT

1. Go to ChatGPT → Create a GPT
2. Configure action with query endpoint
3. Add OpenAPI schema (see `shared/docs/api-protocol.md`)
4. Test queries like "What did I say about X yesterday?"

#### 5.2 Example Queries

- "What did I discuss in my recordings yesterday?"
- "Find mentions of 'project deadline' in the last week"
- "What conversations did I have about vacation?"

## Monitoring and Maintenance

### CloudWatch Dashboards

Create dashboard to monitor:
- API Gateway requests and errors
- Lambda invocations and duration
- SQS queue depth
- DynamoDB read/write capacity

### Alarms

Set up alarms for:
- DLQ messages (transcription failures)
- Lambda errors
- API Gateway 5xx errors
- High SQS queue depth

### Logs

Check logs in CloudWatch:
- `/aws/apigateway/rem-dev`
- `/aws/lambda/rem-ingest-audio-dev`
- `/aws/lambda/rem-transcription-dispatcher-dev`
- `/aws/lambda/rem-query-transcripts-dev`

## Troubleshooting

### ESP32 Not Uploading

1. Check WiFi credentials
2. Verify API Gateway URL and API key
3. Check serial monitor for errors
4. Verify network connectivity

### Transcription Not Working

1. Check SQS queue for messages
2. Verify GPU worker is running
3. Check worker logs for errors
4. Verify AWS credentials and permissions

### Query Returns No Results

1. Verify recordings are transcribed (check DynamoDB)
2. Check S3 transcripts bucket
3. Test with broader query terms
4. Check time range filters

## Cost Estimation

**Monthly costs (approximate):**
- API Gateway: $3.50/million requests
- Lambda: $0.20/million requests (with free tier)
- S3: $0.023/GB storage
- DynamoDB: $1.25/million writes (with free tier)
- SQS: $0.40/million requests (with free tier)
- GPU Instance (g4dn.xlarge): ~$0.50/hour = $360/month if running 24/7

**Cost optimization:**
- Use Spot Instances for GPU worker (70% savings)
- Stop GPU worker when not needed
- Use S3 lifecycle policies (already configured)
- Use DynamoDB on-demand pricing for variable workloads

## Scaling

### Horizontal Scaling

- **ESP32**: Add more devices (each with unique device ID)
- **GPU Workers**: Run multiple instances polling same queue
- **Lambda**: Auto-scales automatically

### Vertical Scaling

- **Lambda**: Increase memory allocation
- **DynamoDB**: Increase provisioned capacity or use on-demand
- **GPU**: Use larger instance types (g4dn.2xlarge, etc.)

## Security Hardening

1. **API Key Rotation**: Regularly rotate API keys
2. **VPC**: Deploy Lambda in VPC with private subnets
3. **Encryption**: Enable S3 bucket encryption (already enabled for DynamoDB)
4. **IAM**: Use least-privilege IAM policies
5. **API Gateway**: Add rate limiting and WAF rules
6. **Secrets Manager**: Store secrets in AWS Secrets Manager instead of environment variables

## Backup and Recovery

1. **DynamoDB**: Point-in-time recovery enabled
2. **S3**: Enable versioning for critical buckets
3. **Terraform State**: Use remote state with locking (S3 + DynamoDB)
4. **Code**: Regular git commits and backups

## Next Steps

1. Add semantic search with vector embeddings
2. Implement user authentication
3. Add web dashboard for browsing recordings
4. Support multiple users
5. Add real-time transcription
6. Implement speaker diarization
7. Add mobile app for playback

