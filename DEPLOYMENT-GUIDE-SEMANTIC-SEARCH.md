# Deployment Guide: Semantic Search with OpenAI

## 🎯 What You're Deploying

Your REM system now has **semantic search** powered by OpenAI! This means:

✅ **Meaning-based search** - Find memories by what they mean, not just keywords  
✅ **AI summaries** - Each recording gets a 2-3 sentence summary  
✅ **Topic extraction** - Automatically tagged with 3-5 topics  
✅ **Hybrid search** - Combines keyword matching (30%) + semantic similarity (70%)  

---

## 📋 Prerequisites

1. **OpenAI API Key** - You mentioned you have one!
2. **AWS credentials** configured
3. **Docker** installed (for building worker)
4. **Terraform** installed

---

## 🚀 Step-by-Step Deployment

### Step 1: Set Your OpenAI API Key

```bash
cd cloud/infra

# Add your OpenAI API key to terraform.tfvars
echo 'openai_api_key = "sk-YOUR-OPENAI-API-KEY-HERE"' >> terraform.tfvars
```

**Important:** Replace `sk-YOUR-OPENAI-API-KEY-HERE` with your actual OpenAI API key!

---

### Step 2: Deploy Infrastructure

This updates Lambda and ECS environment variables to include the OpenAI API key.

```bash
cd cloud/infra
terraform apply
```

Review the changes and type `yes` when prompted.

**Expected changes:**
- Lambda environment variables updated (OPENAI_API_KEY added)
- ECS task definition updated (OPENAI_API_KEY added)

---

### Step 3: Build and Deploy Query Lambda

```bash
cd cloud/lambdas/query-transcripts

# Install new dependencies (openai package)
npm install

# Build and package
npm run build

# Deploy with Terraform
cd ../../infra
terraform apply
```

---

### Step 4: Build and Deploy Worker

This is the most important step - the worker now generates embeddings!

```bash
cd /path/to/rem  # Your repo root

# Build Docker image with new dependencies
./scripts/build-and-push-worker.sh
```

**This will:**
1. Install `openai` Python package
2. Build Docker image for linux/amd64
3. Push to ECR
4. ECS will automatically pull and deploy

**Expected build time:** 5-15 minutes (cross-platform build)

---

### Step 5: Verify Deployment

#### Check ECS Worker Status

```bash
./scripts/check-worker-status.sh
```

Expected output:
```
📦 ECS FARGATE WORKER
✅ ECS worker is ACTIVE (1 task running)
```

#### Check Lambda Deployment

```bash
cd cloud/infra
terraform output api_endpoint
```

You should see your API endpoint URL.

---

## 🧪 Testing Semantic Search

### Test 1: Upload a Test Recording

Use your ESP32 or upload a test audio file:

```bash
# If you have a test WAV file
curl -X POST "$(terraform output -raw api_endpoint)/ingest" \
  -H "x-api-key: $(terraform output -raw api_key)" \
  -F "deviceId=test-device" \
  -F "startedAt=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  -F "endedAt=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  -F "file=@test.wav"
```

### Test 2: Wait for Transcription

Watch the ECS logs to see the AI enhancements being generated:

```bash
./scripts/view-ecs-logs.sh
```

You should see:
```
Transcription complete in X.XXs
Generating AI enhancements...
Generating embedding for text (XXX chars)
Generated embedding with 1536 dimensions
Generating summary for text (XXX chars)
Generated summary: ...
Extracting topics from text (XXX chars)
Extracted topics: ['topic1', 'topic2', ...]
```

### Test 3: Query with Semantic Search

```bash
API_ENDPOINT=$(cd cloud/infra && terraform output -raw api_endpoint)

# Semantic search example
curl -X POST "${API_ENDPOINT}/query" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "default-user",
    "query": "feeling stressed about work",
    "limit": 5
  }'
```

**Expected response:**
```json
{
  "success": true,
  "summary": "Found 3 relevant memories from your past recordings.",
  "memories": [
    {
      "timestamp": "2025-12-10T14:30:00.000Z",
      "text": "I've been really overwhelmed with the project deadline...",
      "context": "Recorded on 12/10/2025 at 2:30 PM",
      "relevance": 0.92
    }
  ],
  "totalMatches": 3
}
```

---

## 💰 Cost Estimation

### OpenAI API Costs

**Embeddings** (`text-embedding-3-small`):
- Cost: $0.02 per 1M tokens
- 5-min recording: ~1,000 tokens
- **Cost per recording: $0.00002** (basically free!)

**Summaries** (`gpt-4o-mini`):
- Cost: $0.15 per 1M input tokens, $0.60 per 1M output tokens
- Per recording: ~1,000 input + 50 output tokens
- **Cost per recording: $0.00018**

**Topics** (`gpt-4o-mini`):
- Similar to summaries
- **Cost per recording: ~$0.00015**

**Total per recording: ~$0.00035** (less than a penny!)

**For 1,000 recordings: ~$0.35** 🎉

---

## 🔍 Troubleshooting

### Issue: "OpenAI client not configured"

**Cause:** OpenAI API key not set in environment variables

**Fix:**
1. Check terraform.tfvars has `openai_api_key = "sk-..."`
2. Run `terraform apply` to update environment variables
3. Rebuild and redeploy worker

### Issue: Worker fails with "openai module not found"

**Cause:** Docker image not rebuilt with new dependencies

**Fix:**
```bash
./scripts/build-and-push-worker.sh
```

### Issue: Query Lambda fails with "Cannot find module 'openai'"

**Cause:** Lambda not rebuilt with new dependencies

**Fix:**
```bash
cd cloud/lambdas/query-transcripts
npm install
npm run build
cd ../../infra
terraform apply
```

---

## 🎉 Success Indicators

You'll know it's working when:

1. ✅ ECS logs show "Generated embedding with 1536 dimensions"
2. ✅ ECS logs show "Generated summary: ..."
3. ✅ ECS logs show "Extracted topics: [...]"
4. ✅ Query responses include high relevance scores (0.7-1.0)
5. ✅ Semantic queries return relevant results even without exact keywords

---

## 📊 What's Next?

Now that you have semantic search, you can:

1. **Ask ChatGPT about your memories** using the `/query` endpoint
2. **Search by meaning** - "when was I happy?" instead of exact phrases
3. **View AI summaries** of your recordings
4. **Browse by topics** to find related memories

### Remaining Enhancements

- [ ] **Phase 4: Speaker Diarization** - Identify different speakers
- [ ] **Phase 5: API Authentication** - Secure the endpoint

Ready to implement these? Just ask! 🚀

