# Phase 4 & 5 Deployment Guide: Speaker Diarization + API Authentication

This guide covers deploying **Phase 4 (Speaker Diarization)** and **Phase 5 (API Authentication)** enhancements to your REM system.

---

## 🎯 What's New

### Phase 4: Speaker Diarization ✅
- **Automatic speaker identification** using pyannote.audio
- **Speaker labels** assigned to each transcript segment
- **Speaker filtering** in search queries
- **Multi-speaker support** with speaker count tracking

### Phase 5: API Authentication ✅
- **API key validation** on all endpoints
- **Rate limiting** at API Gateway level
- **Throttling protection** against abuse
- **Configurable limits** for production use

---

## 📋 Prerequisites

### 1. HuggingFace Token (Required for Speaker Diarization)

Speaker diarization uses pyannote.audio models from HuggingFace.

**Get your token:**
1. Go to https://huggingface.co/settings/tokens
2. Create a new token (read access is sufficient)
3. Accept the pyannote model license:
   - Visit https://huggingface.co/pyannote/speaker-diarization-3.1
   - Click "Agree and access repository"

**Save your token** - you'll need it for deployment.

### 2. OpenAI API Key (Already configured in Phase 1-3)

You should already have this from the semantic search implementation.

### 3. API Key (Already exists)

Your REM system already has an API key in `cloud/infra/main.tf`. This is now enforced on all endpoints.

---

## 🚀 Deployment Steps

### Step 1: Set Environment Variables

Create or update `cloud/infra/terraform.tfvars`:

```hcl
# Existing variables
aws_region     = "us-east-1"
project_name   = "rem"
environment    = "dev"
user_id        = "default-user"
whisper_model  = "base"

# OpenAI API Key (from Phase 1-3)
openai_api_key = "sk-proj-..."

# NEW: HuggingFace Token for Speaker Diarization
huggingface_token = "hf_..."

# NEW: API Rate Limiting (optional - defaults shown)
api_throttle_rate_limit  = 10   # requests per second
api_throttle_burst_limit = 20   # burst capacity
```

**Security Note:** Never commit `terraform.tfvars` to git! It's already in `.gitignore`.

### Step 2: Deploy Infrastructure

```bash
cd cloud/infra

# Initialize Terraform (if not already done)
terraform init

# Review changes
terraform plan

# Apply changes
terraform apply
```

**Expected changes:**
- ECS task definition updated with `HUGGINGFACE_TOKEN`
- Lambda functions updated with `HUGGINGFACE_TOKEN`
- API Gateway throttling settings updated
- No resource recreation needed (just updates)

### Step 3: Build and Push Updated Docker Image

The worker now includes pyannote.audio dependencies.

```bash
cd cloud/gpu-worker

# Build for AMD64 (required for ECS Fargate)
docker build --platform linux/amd64 -t rem-worker:latest .

# Tag for ECR
docker tag rem-worker:latest <AWS_ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/rem-worker:latest

# Login to ECR
aws ecr get-login-password --region <REGION> | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com

# Push to ECR
docker push <AWS_ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/rem-worker:latest
```

**Note:** Replace `<AWS_ACCOUNT_ID>` and `<REGION>` with your values.

### Step 4: Deploy Updated Lambda Functions

```bash
cd cloud/lambdas/query-transcripts

# Install dependencies
npm install

# Build
npm run build

# Deploy (using existing script or Terraform)
cd ../../infra
terraform apply -target=aws_lambda_function.query_transcripts
```

### Step 5: Force ECS Task Update

Force ECS to pull the new Docker image:

```bash
aws ecs update-service \
  --cluster rem-cluster-dev \
  --service rem-worker-service-dev \
  --force-new-deployment \
  --region <REGION>
```

---

## 🧪 Testing

### Test 1: Upload Audio with Speaker Diarization

Upload a recording with multiple speakers:

```bash
curl -X POST https://<API_ENDPOINT>/ingest \
  -H "x-api-key: <YOUR_API_KEY>" \
  -F "deviceId=esp32-test" \
  -F "startedAt=2025-12-10T10:00:00Z" \
  -F "endedAt=2025-12-10T10:05:00Z" \
  -F "audio=@conversation.wav"
```

**Expected:** Recording uploaded and queued for transcription.

### Test 2: Check Transcript with Speaker Labels

After transcription completes (~2-5 minutes), download the transcript:

```bash
aws s3 cp s3://rem-transcripts-dev/transcripts/default-user/esp32-test/<RECORDING_ID>.json - | jq
```

**Expected output:**
```json
{
  "segments": [
    {
      "id": 0,
      "start": 0.0,
      "end": 3.5,
      "text": "Hello, how are you?",
      "speaker": "SPEAKER_00",
      "embedding": [...]
    },
    {
      "id": 1,
      "start": 3.5,
      "end": 6.2,
      "text": "I'm doing great, thanks!",
      "speaker": "SPEAKER_01",
      "embedding": [...]
    }
  ],
  "speakers": ["SPEAKER_00", "SPEAKER_01"],
  "speakerCount": 2,
  ...
}
```

### Test 3: Query with Speaker Filter

```bash
curl -X POST https://<API_ENDPOINT>/query \
  -H "x-api-key: <YOUR_API_KEY>" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "default-user",
    "query": "project deadline",
    "speaker": "SPEAKER_00"
  }'
```

**Expected:** Only results from SPEAKER_00.

### Test 4: API Authentication

Test without API key (should fail):

```bash
curl -X POST https://<API_ENDPOINT>/query \
  -H "Content-Type: application/json" \
  -d '{"userId": "default-user", "query": "test"}'
```

**Expected:** `401 Unauthorized`

### Test 5: Rate Limiting

Send rapid requests to test throttling:

```bash
for i in {1..30}; do
  curl -X POST https://<API_ENDPOINT>/query \
    -H "x-api-key: <YOUR_API_KEY>" \
    -H "Content-Type: application/json" \
    -d '{"userId": "default-user", "query": "test"}' &
done
wait
```

**Expected:** Some requests return `429 Too Many Requests` after exceeding rate limit.

---

## 📊 Cost Estimates

### Speaker Diarization
- **pyannote.audio**: Free (open source)
- **Processing time**: +30-60 seconds per recording
- **No additional API costs**

### API Authentication & Rate Limiting
- **API Gateway**: No additional cost
- **Lambda**: No additional cost (minimal validation overhead)

**Total additional cost: ~$0** (just slightly longer processing time)

---

## 🔧 Configuration Options

### Adjust Rate Limits

Edit `cloud/infra/terraform.tfvars`:

```hcl
# For production with higher traffic
api_throttle_rate_limit  = 100  # 100 req/sec
api_throttle_burst_limit = 200  # 200 burst

# For development/testing
api_throttle_rate_limit  = 10   # 10 req/sec
api_throttle_burst_limit = 20   # 20 burst
```

Then run `terraform apply`.

---

## 🎉 Summary

You've successfully deployed:

✅ **Speaker Diarization** - Automatically identifies who said what  
✅ **Speaker Filtering** - Search by specific speaker  
✅ **API Authentication** - Secure endpoints with API key validation  
✅ **Rate Limiting** - Protect against abuse with throttling  

**All 5 enhancement phases are now complete!** 🚀

---

## 🔮 Next Steps

1. **Deploy and test** all features
2. **Update ChatGPT Custom GPT** with speaker filtering capability
3. **Monitor costs** in AWS Cost Explorer
4. **Adjust rate limits** based on usage patterns
5. **Consider additional enhancements**:
   - Custom speaker names (map SPEAKER_00 to "John")
   - Voice activity detection
   - Emotion detection
   - Multi-language support improvements

---

## 📚 Related Documentation

- `SEMANTIC-SEARCH-IMPLEMENTATION.md` - Phases 1-3 technical details
- `DEPLOYMENT-GUIDE-SEMANTIC-SEARCH.md` - Phases 1-3 deployment
- `CHATGPT-INTEGRATION.md` - ChatGPT Custom GPT setup

---

**Questions or issues?** Check CloudWatch logs:
- Worker logs: `/aws/ecs/rem-worker-dev`
- Lambda logs: `/aws/lambda/rem-query-transcripts-dev`
- API Gateway logs: `/aws/apigateway/rem-dev`

