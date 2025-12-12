# AI Enhancements Configuration

This document explains how to enable/disable AI enhancements (embeddings, summaries, topics) in the REM transcription worker.

---

## 🎯 What Are AI Enhancements?

When enabled, the transcription worker uses OpenAI's API to generate:

1. **Embeddings** - 1536-dimension vectors for semantic search
   - Enables finding recordings by meaning, not just keywords
   - Cost: ~$0.00002 per recording

2. **Summaries** - AI-generated 2-3 sentence summaries
   - Quick overview of what was discussed
   - Cost: ~$0.00015 per recording

3. **Topics** - 3-5 key topics extracted from the transcript
   - Enables topic-based filtering and discovery
   - Cost: ~$0.00005 per recording

**Total cost: ~$0.0002 per recording** (~$0.07/month for 1 hour/day usage)

---

## ⚙️ Configuration

### **Option 1: Disable AI Enhancements (Default)**

In your `terraform.tfvars`:

```hcl
enable_ai_enhancements = false
# openai_api_key not needed
```

**Result:**
- ✅ Transcription works normally
- ✅ No OpenAI API calls
- ✅ No OpenAI costs
- ❌ No embeddings, summaries, or topics

---

### **Option 2: Enable AI Enhancements**

In your `terraform.tfvars`:

```hcl
enable_ai_enhancements = true
openai_api_key         = "sk-proj-your-api-key-here"
```

**Result:**
- ✅ Transcription works normally
- ✅ Embeddings, summaries, and topics generated
- ✅ Enhanced search capabilities
- 💰 ~$0.0002 per recording in OpenAI costs

---

## 🔑 Getting an OpenAI API Key

1. Go to https://platform.openai.com/api-keys
2. Sign up or log in
3. Click "Create new secret key"
4. Copy the key (starts with `sk-proj-...`)
5. Add a payment method at https://platform.openai.com/settings/organization/billing/overview
6. Set a usage limit (e.g., $5/month) to prevent unexpected charges

---

## 🚀 Applying Changes

After updating `terraform.tfvars`:

```bash
cd cloud/infra
terraform apply
```

Then force a new deployment to restart the worker with the new configuration:

```bash
aws ecs update-service \
  --cluster rem-transcription-cluster-dev \
  --service rem-transcription-worker-dev \
  --force-new-deployment \
  --region us-east-1
```

Wait 2-3 minutes for the new task to start.

---

## 🔍 Verifying Configuration

Check the worker logs:

```bash
aws logs tail /ecs/rem-transcription-worker-dev \
  --region us-east-1 \
  --since 5m \
  --follow
```

**If AI enhancements are DISABLED:**
```
OpenAI client not configured, skipping embedding generation
OpenAI client not configured, skipping summary generation
OpenAI client not configured, skipping topic extraction
```

**If AI enhancements are ENABLED:**
```
Generated embedding with 1536 dimensions
Generated summary: ...
Extracted topics: [...]
```

---

## 💰 Cost Comparison

| Usage Pattern | Transcription Only | With AI Enhancements |
|---------------|-------------------|---------------------|
| **1 hour/day** | $0.14/month | $0.21/month |
| **2 hours/day** | $0.28/month | $0.42/month |
| **Always-on** | $3.38/month | $3.45/month |

**AI enhancements add ~$0.07/month for 1 hour/day usage.**

---

## ⚠️ Troubleshooting

### Error: "insufficient_quota"

Your OpenAI account has no credits. Add a payment method or buy prepaid credits.

### Error: "invalid_api_key"

Your API key is incorrect or expired. Generate a new one.

### No embeddings/summaries in DynamoDB

Check that `enable_ai_enhancements = true` in your `terraform.tfvars` and that you ran `terraform apply`.

---

## 📚 Related Documentation

- [OpenAI API Pricing](https://openai.com/api/pricing/)
- [OpenAI Error Codes](https://platform.openai.com/docs/guides/error-codes)
- [REM Architecture](../../shared/docs/architecture.md)

