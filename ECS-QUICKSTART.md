# ECS Fargate Quick Start

Switch between local and cloud transcription workers in seconds!

---

## 🚀 Initial Setup (One-time, ~10 minutes)

### 1. Deploy ECS Infrastructure

```bash
cd cloud/infra
terraform apply
```

**What this creates:**
- ✅ ECR repository for Docker images
- ✅ ECS cluster and service (initially disabled)
- ✅ Auto-scaling configuration
- ✅ CloudWatch Logs

**Cost:** Infrastructure is free when not running tasks.

---

### 2. Build and Push Docker Image

```bash
./scripts/build-and-push-worker.sh
```

**What this does:**
- Builds Docker image from `cloud/gpu-worker/`
- Pushes to ECR
- Tags with `latest` and timestamp

**Time:** ~2-5 minutes (depending on internet speed)

---

## 🔄 Daily Usage

### Option A: Use Local Worker (FREE)

```bash
# Stop ECS worker
./scripts/use-local-worker.sh

# Start local worker
cd cloud/gpu-worker
source venv/bin/activate
python src/worker.py
```

**When to use:**
- ✅ Development and testing
- ✅ You have your computer on anyway
- ✅ Want to save money

**Cost:** $0/month

---

### Option B: Use ECS Fargate Worker (~$5-10/month)

```bash
# Stop local worker (if running)
pkill -f worker.py

# Start ECS worker
./scripts/use-ecs-worker.sh
```

**When to use:**
- ✅ Production/always-on
- ✅ Don't want to keep computer running
- ✅ Want auto-scaling

**Cost:** ~$5-10/month with auto-scaling (only pay when processing)

---

## 📊 Check Status Anytime

```bash
./scripts/check-worker-status.sh
```

**Shows:**
- ECS worker status (running/stopped)
- Local worker status (running/stopped)
- SQS queue depth
- Warnings if both or neither are running

---

## 📋 View ECS Logs

```bash
./scripts/view-ecs-logs.sh
```

Or in AWS Console:
- CloudWatch → Log Groups → `/ecs/rem-transcription-worker-dev`

---

## 🔧 Update Worker Code

### For Local Worker
```bash
# Just restart it
pkill -f worker.py
cd cloud/gpu-worker
python src/worker.py
```

### For ECS Worker
```bash
# Rebuild and push
./scripts/build-and-push-worker.sh

# Force ECS to use new image
aws ecs update-service \
  --cluster rem-transcription-cluster-dev \
  --service rem-transcription-worker-dev \
  --force-new-deployment
```

---

## 💰 Cost Comparison

| Worker Type | Setup | Monthly Cost | When to Use |
|-------------|-------|--------------|-------------|
| **Local** | 5 min | $0 | Development, testing |
| **ECS Fargate** | 10 min | ~$5-10 | Production, always-on |

### ECS Cost Breakdown
- **Fargate Spot:** ~$0.01244/hour (1 vCPU, 2GB RAM)
- **Auto-scaling:** Scales to 0 when queue empty
- **Typical usage:** 2-4 hours/day = ~$1-2/month
- **Heavy usage:** 24/7 = ~$9/month

---

## 🎯 Recommended Workflow

### Development
1. Use **local worker** while developing
2. Test changes immediately
3. Free!

### Production
1. Deploy to **ECS Fargate**
2. Enable auto-scaling
3. Forget about it - it just works!

---

## 📚 Full Documentation

- **ECS Deployment Guide:** `cloud/gpu-worker/ECS-DEPLOYMENT.md`
- **Local Debugging:** `LAMBDA-DEBUG-QUICKSTART.md`
- **Architecture:** `shared/docs/architecture.md`

---

## 🆘 Troubleshooting

### Both workers running
```bash
./scripts/check-worker-status.sh
# Will warn you - stop one of them
```

### No workers running
```bash
./scripts/check-worker-status.sh
# Will warn you - start one of them
```

### ECS task keeps stopping
```bash
./scripts/view-ecs-logs.sh
# Check for errors
```

### Can't push to ECR
```bash
# Re-login
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <ECR_URL>
```

---

## 🎉 Summary

**4 Simple Commands:**

```bash
# Setup (once)
terraform apply
./scripts/build-and-push-worker.sh

# Switch to local
./scripts/use-local-worker.sh

# Switch to ECS
./scripts/use-ecs-worker.sh

# Check status
./scripts/check-worker-status.sh
```

**That's it!** You can now easily switch between local and cloud workers. 🚀

