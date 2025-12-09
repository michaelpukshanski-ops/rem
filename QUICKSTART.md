# REM Quick Start Guide

Get REM up and running in 30 minutes.

## Prerequisites Checklist

- [ ] AWS Account with admin access
- [ ] AWS CLI installed and configured (`aws configure`)
- [ ] Terraform >= 1.0 installed
- [ ] Node.js >= 20.x installed
- [ ] Python >= 3.9 installed
- [ ] PlatformIO installed (for ESP32)
- [ ] ESP32 board with I2S microphone (INMP441 or similar)
- [ ] GPU machine (optional, can use CPU)

## 5-Step Quick Deploy

### Step 1: Clone and Configure (5 min)

```bash
# Clone repository
git clone <your-repo-url>
cd rem

# Configure Terraform
cd cloud/infra
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars - IMPORTANT: Change api_key!
# Generate secure key: openssl rand -base64 32
nano terraform.tfvars

cd ../..
```

### Step 2: Deploy Cloud Infrastructure (10 min)

```bash
# Build and deploy everything
make deploy-infra

# Save the outputs - you'll need these!
make outputs > deployment-outputs.txt
```

**Important outputs to note:**
- `api_gateway_url` - for ESP32
- `api_key` - for ESP32 (sensitive!)
- `gpu_worker_configuration` - for GPU worker

### Step 3: Configure ESP32 (5 min)

```bash
cd esp32

# Create secrets file
cp include/secrets.h.example include/secrets.h

# Edit with your values from Terraform outputs
nano include/secrets.h
```

Set these values (from Terraform outputs):
```cpp
#define API_GATEWAY_URL "https://xxxxx.execute-api.us-east-1.amazonaws.com/ingest"
#define API_KEY "your-api-key-from-terraform"
#define USER_ID "default-user"
```

**Note:** You can leave `WIFI_SSID` and `WIFI_PASSWORD` empty - you'll configure WiFi via web portal after flashing!

### Step 4: Flash ESP32 (5 min)

```bash
# Build and flash
make flash-esp32

# Monitor to verify it's working
make monitor-esp32
```

**Expected output:**
```
I2S initialized
Recording started...
```

### Step 4.5: Configure WiFi via Web Portal (2 min)

1. **Press and hold BOOT button** on ESP32 for 3 seconds
2. **Connect phone to WiFi:** `REM-Setup` (password: `rem12345`)
3. **Browser opens to** `192.168.4.1` (or navigate manually)
4. **Select your WiFi** and enter password
5. **Click Save** - ESP32 restarts and connects!

**Expected output after WiFi config:**
```
WiFi connected!
IP: 192.168.1.xxx
File uploaded: recording_001.wav
```

See [esp32/WIFI_SETUP.md](esp32/WIFI_SETUP.md) for detailed WiFi setup guide.

### Step 5: Start GPU Worker (5 min)

```bash
cd cloud/gpu-worker

# Setup environment
make setup-worker

# Configure .env
cp .env.example .env
nano .env
```

Copy values from `terraform output gpu_worker_configuration`:
```bash
AWS_REGION=us-east-1
SQS_QUEUE_URL=https://sqs...
RAW_AUDIO_BUCKET=rem-raw-audio-xxxx
TRANSCRIPTS_BUCKET=rem-transcripts-xxxx
DYNAMODB_TABLE=rem-recordings-dev
```

```bash
# Start worker
make run-worker
```

**Expected output:**
```
Loading Whisper model: base on cuda
Whisper model loaded successfully
Starting REM GPU Worker
Polling SQS...
```

## Verify It's Working

### 1. Check ESP32 is Recording

Serial monitor should show:
```
Recording started...
Chunk 1 saved: 4800000 bytes
WiFi connected
Uploading: recording_001.wav
Upload successful!
```

### 2. Check S3 Raw Audio

```bash
aws s3 ls s3://rem-raw-audio-xxxx/raw/ --recursive
```

Should see WAV files.

### 3. Check Transcription

GPU worker logs should show:
```
Received 1 message(s)
Processing recording: 550e8400-...
Downloading s3://rem-raw-audio-xxxx/raw/...
Transcribing...
Transcription complete in 15.2s
Detected language: en (98.5%)
Found 42 segments
Successfully processed recording
```

### 4. Check S3 Transcripts

```bash
aws s3 ls s3://rem-transcripts-xxxx/transcripts/ --recursive
```

Should see JSON and TXT files.

### 5. Test Query API

```bash
API_URL=$(cd cloud/infra && terraform output -raw api_gateway_url)

curl -X POST $API_URL/query \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "default-user",
    "query": "test",
    "limit": 5
  }'
```

Should return matching transcript segments.

## Troubleshooting

### ESP32 Won't Connect to WiFi

1. Check SSID and password in `secrets.h`
2. Ensure 2.4GHz WiFi (ESP32 doesn't support 5GHz)
3. Check serial monitor for error messages

### ESP32 Upload Fails

1. Verify API Gateway URL (should end with `/ingest`)
2. Check API key matches Terraform output
3. Verify network connectivity
4. Check CloudWatch logs for Lambda errors

### GPU Worker Not Processing

1. Check SQS queue has messages: `aws sqs get-queue-attributes --queue-url <url> --attribute-names ApproximateNumberOfMessages`
2. Verify AWS credentials in `.env`
3. Check worker logs for errors
4. Verify CUDA is working: `nvidia-smi`

### No Transcripts Appearing

1. Check GPU worker is running
2. Check SQS DLQ for failed messages
3. Verify S3 event notification is configured (Terraform should do this)
4. Check CloudWatch logs for transcription-dispatcher Lambda

### Query Returns Empty Results

1. Wait for transcription to complete (check DynamoDB status)
2. Use broader search terms
3. Check time range filters
4. Verify transcripts exist in S3

## Next Steps

### Production Hardening

1. **Secure API Key**: Rotate regularly, use AWS Secrets Manager
2. **Enable Encryption**: S3 bucket encryption, DynamoDB encryption at rest
3. **Add Monitoring**: CloudWatch dashboards and alarms
4. **Backup**: Enable S3 versioning, DynamoDB point-in-time recovery
5. **Cost Optimization**: Use Spot Instances for GPU worker

### Feature Enhancements

1. **Multi-User**: Add authentication and user management
2. **Web Dashboard**: Build UI for browsing recordings
3. **Real-Time**: Add WebSocket for live transcription
4. **Speaker Diarization**: Identify different speakers
5. **Semantic Search**: Add vector embeddings for better search

### ChatGPT Integration

1. Create Custom GPT in ChatGPT
2. Add query endpoint as an action
3. Use OpenAPI schema from `shared/docs/api-protocol.md`
4. Ask ChatGPT: "What did I say about X yesterday?"

## Cost Estimate

**First month (with AWS Free Tier):**
- API Gateway: ~$0 (1M requests free)
- Lambda: ~$0 (1M requests free)
- S3: ~$1 (5GB storage)
- DynamoDB: ~$0 (25GB free)
- SQS: ~$0 (1M requests free)
- **GPU Instance**: $360/month if running 24/7

**Cost Optimization:**
- Use Spot Instances: Save 70% on GPU costs
- Stop GPU worker when not needed
- Use smaller Whisper model (tiny/base)

## Support

- **Documentation**: See `README.md` and `DEPLOYMENT.md`
- **API Reference**: See `shared/docs/api-protocol.md`
- **Issues**: Check CloudWatch Logs for errors

## Success Checklist

- [ ] Terraform deployed successfully
- [ ] ESP32 connecting to WiFi
- [ ] ESP32 uploading audio files
- [ ] Audio files appearing in S3 raw bucket
- [ ] GPU worker processing jobs
- [ ] Transcripts appearing in S3 transcripts bucket
- [ ] DynamoDB records showing "TRANSCRIBED" status
- [ ] Query API returning results

**Congratulations! Your REM system is now operational! 🎉**

