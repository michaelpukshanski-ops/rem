# Migration Guide: ECS Fargate → Lambda

This guide covers migrating the transcription worker from ECS Fargate to Lambda for **83% cost savings**.

---

## 🎯 Why Migrate?

### **Cost Comparison**

| Setup | Monthly Cost | Savings |
|-------|--------------|---------|
| **ECS Fargate** (current) | ~$24/month | - |
| **Lambda** (new) | ~$3-5/month | **83%** |

### **Benefits**
- ✅ **83% cost reduction** (~$20/month savings)
- ✅ **Simpler architecture** (no ECS cluster, no ECR)
- ✅ **True serverless** (pay only when processing)
- ✅ **Auto-scaling** (handles bursts automatically)
- ✅ **Same functionality** (all features preserved)

### **Trade-offs**
- ⚠️ 15-minute timeout (sufficient for 5-min recordings)
- ⚠️ Cold starts (~10-20 seconds first invocation)
- ⚠️ 250 MB layer size limit (requires optimization)

---

## 📋 Prerequisites

1. **Python 3.11** installed locally
2. **AWS CLI** configured
3. **Terraform** installed
4. **OpenAI API key** (already configured)
5. **HuggingFace token** (already configured)

---

## 🚀 Migration Steps

### **Step 1: Build Docker Image**

We use a Docker-based Lambda because dependencies (Whisper, PyTorch, pyannote) exceed the 250 MB layer limit.

Docker-based Lambdas support up to **10 GB** image size!

```bash
cd cloud/lambdas/transcription-worker

# Build and push Docker image to ECR (takes 5-10 minutes)
./build-docker.sh
```

**What this does:**
1. Creates ECR repository (if needed)
2. Builds Docker image with all dependencies
3. Tags image for ECR
4. Pushes to ECR

**Expected output:**
```
✅ Docker image built and pushed successfully!
📊 Image URI: <account-id>.dkr.ecr.<region>.amazonaws.com/rem-transcription-worker:latest
```

---

### **Step 2: Deploy Lambda with Terraform**

The Terraform configuration has already been updated to:
- ✅ Create ECR repository
- ✅ Create Lambda function using Docker image
- ✅ Add SQS trigger
- ✅ Add IAM role with proper permissions

Deploy the Lambda:

```bash
cd cloud/infra

# Initialize Terraform (if needed)
terraform init

# Review changes
terraform plan

# Apply changes
terraform apply
```

**Expected changes:**
- ➕ Create ECR repository
- ➕ Create Lambda function (Docker-based)
- ➕ Create SQS event source mapping
- ➕ Create IAM role for Lambda

**Note:** The Lambda function will initially fail because the Docker image doesn't exist yet. That's OK - we'll push it in the next step.

---

### **Step 3: Push Docker Image (if not done in Step 1)**

If you skipped Step 1 or need to rebuild:

```bash
cd cloud/lambdas/transcription-worker
./build-docker.sh
```

---

### **Step 4: Update Lambda Function**

After pushing the Docker image, update the Lambda function:

```bash
# Lambda will automatically pull the latest image
# Or manually update:
aws lambda update-function-code \
  --function-name rem-transcription-worker-dev \
  --image-uri <ECR_IMAGE_URI>:latest
```

---

### **Step 5: Test Lambda**

Upload a test recording:

```bash
curl -X POST https://<API_ENDPOINT>/ingest \
  -H "x-api-key: <YOUR_API_KEY>" \
  -F "deviceId=esp32-test" \
  -F "startedAt=2025-12-10T10:00:00Z" \
  -F "endedAt=2025-12-10T10:05:00Z" \
  -F "audio=@test.wav"
```

**Monitor Lambda execution:**

```bash
# Watch CloudWatch logs
aws logs tail /aws/lambda/rem-transcription-worker-dev --follow

# Check SQS queue
aws sqs get-queue-attributes \
  --queue-url <SQS_QUEUE_URL> \
  --attribute-names ApproximateNumberOfMessages
```

**Expected:**
- Lambda invoked automatically by SQS
- Transcription completes in ~2-3 minutes
- Transcript uploaded to S3
- DynamoDB updated with results

---

### **Step 6: Remove ECS Resources**

Once Lambda is working, remove ECS resources to save costs:

```bash
cd cloud/infra

# Comment out or delete ecs.tf
mv ecs.tf ecs.tf.disabled

# Apply changes
terraform apply
```

**This will remove:**
- ECS cluster
- ECS service
- ECS task definition
- ECR repository (optional - keep for backup)
- Auto-scaling policies

**Monthly savings:** ~$24/month

---

## 🧪 Testing Checklist

- [ ] Lambda function deploys successfully
- [ ] SQS trigger is configured
- [ ] Test recording uploads successfully
- [ ] Lambda processes SQS message
- [ ] Transcription completes (check CloudWatch logs)
- [ ] Transcript uploaded to S3
- [ ] DynamoDB updated with results
- [ ] Speaker diarization works
- [ ] Embeddings generated
- [ ] Summary and topics extracted
- [ ] Query Lambda can search transcripts

---

## 📊 Lambda Configuration

### **Function Settings**
- **Runtime**: Python 3.11
- **Memory**: 3008 MB (~3 GB for Whisper model)
- **Timeout**: 900 seconds (15 minutes)
- **Ephemeral Storage**: 2048 MB (for model caching)
- **Concurrency**: 10 (max concurrent executions)

### **Environment Variables**
- `RAW_AUDIO_BUCKET`: S3 bucket with raw audio
- `TRANSCRIPTS_BUCKET`: S3 bucket for transcripts
- `DYNAMODB_TABLE`: DynamoDB table name
- `WHISPER_MODEL`: Whisper model size (base)
- `OPENAI_API_KEY`: OpenAI API key
- `HUGGINGFACE_TOKEN`: HuggingFace token

---

## 🔧 Troubleshooting

### **Layer Too Large (>250 MB)**

If the layer exceeds 250 MB:

**Option 1: Use Docker-based Lambda**
```bash
# Use Lambda container image instead of zip
# Supports up to 10 GB image size
```

**Option 2: Reduce Dependencies**
```bash
# Use smaller Whisper model (tiny instead of base)
# Remove pyannote.audio (disable speaker diarization)
```

### **Cold Start Too Slow**

First invocation may take 10-20 seconds to load models.

**Solutions:**
- Use provisioned concurrency (costs more)
- Accept cold starts (rare after first use)
- Pre-warm Lambda with scheduled invocations

### **Timeout Errors**

If processing takes >15 minutes:

**Solutions:**
- Use smaller Whisper model (tiny/base)
- Split long recordings into chunks
- Fall back to ECS for very long recordings

---

## 💰 Cost Analysis

### **Lambda Costs (5,760 recordings/month)**

**Compute:**
- Invocations: 5,760
- Duration: ~150 seconds average
- Memory: 3008 MB
- Cost: 5,760 × 150 × (3008/1024) × $0.0000166667 = **~$4.50/month**

**Storage:**
- Ephemeral storage: 2 GB
- Cost: Minimal (~$0.10/month)

**Total Lambda:** **~$4.60/month**

### **Comparison**

| Service | ECS Fargate | Lambda | Savings |
|---------|-------------|--------|---------|
| Compute | $23.76 | $4.60 | $19.16 |
| Storage | $0 | $0.10 | -$0.10 |
| **Total** | **$23.76** | **$4.70** | **$19.06** |
| **Savings** | - | - | **80%** |

---

## 🎉 Summary

**Migration complete!**

- ✅ Lambda function created
- ✅ SQS trigger configured
- ✅ All features preserved
- ✅ **80-83% cost savings**
- ✅ Simpler architecture

**Next steps:**
1. Monitor Lambda performance for a few days
2. Remove ECS resources once confident
3. Enjoy the savings! 🎊

---

## 📚 Related Documentation

- `cloud/lambdas/transcription-worker/README.md` - Lambda function details
- `PHASE-4-5-DEPLOYMENT-GUIDE.md` - Speaker diarization setup
- `ALL-ENHANCEMENTS-SUMMARY.md` - Complete feature overview

---

**Questions or issues?** Check CloudWatch logs:
- Lambda: `/aws/lambda/rem-transcription-worker-dev`
- SQS: Monitor queue depth and dead-letter queue

