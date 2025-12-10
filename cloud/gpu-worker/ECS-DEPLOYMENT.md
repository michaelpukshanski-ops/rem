# ECS Fargate Deployment Guide

This guide explains how to deploy the transcription worker to AWS ECS Fargate and switch between local and cloud workers.

## Overview

You have two options for running the transcription worker:

1. **Local Worker** - Run `python src/worker.py` on your machine (FREE)
2. **ECS Fargate Worker** - Run on AWS Fargate Spot (~$5-10/month)

Both workers poll the same SQS queue, so you can easily switch between them.

---

## Initial Setup (One-time)

### 1. Deploy Infrastructure

```bash
cd cloud/infra
terraform apply
```

This creates:
- ECR repository for Docker images
- ECS cluster and task definition
- ECS service (initially disabled, desired count = 0)
- Auto-scaling based on SQS queue depth
- CloudWatch Logs for monitoring

### 2. Build and Push Docker Image

```bash
# From project root
./scripts/build-and-push-worker.sh
```

This will:
- Build the Docker image
- Login to ECR
- Push image to ECR with `latest` and timestamped tags

---

## Switching Between Workers

### Use Local Worker (Default)

```bash
./scripts/use-local-worker.sh
```

This stops the ECS service and sets desired count to 0.

Then start your local worker:
```bash
cd cloud/gpu-worker
source venv/bin/activate
python src/worker.py
```

**Cost:** $0/month

---

### Use ECS Fargate Worker

```bash
./scripts/use-ecs-worker.sh
```

This starts the ECS service with desired count = 1.

**Important:** Stop your local worker first!
```bash
pkill -f worker.py
```

**Cost:** ~$5-10/month (with auto-scaling)

---

## Monitoring

### Check Worker Status

```bash
./scripts/check-worker-status.sh
```

Shows:
- ECS worker status (running/stopped)
- Local worker status (running/stopped)
- SQS queue depth
- Recommendations

### View ECS Logs

```bash
./scripts/view-ecs-logs.sh
```

Or in AWS Console:
- CloudWatch → Log Groups → `/ecs/rem-transcription-worker-dev`

---

## Auto-Scaling

The ECS service automatically scales based on SQS queue depth:

- **Scale Up:** When messages > 1, adds tasks (max 3)
- **Scale Down:** When queue empty for 5 minutes, scales to 0

This means:
- **No jobs:** 0 tasks running = $0/hour
- **Jobs in queue:** 1-3 tasks running = ~$0.01/hour per task
- **Monthly cost:** Only pay for actual processing time

---

## Cost Breakdown

### ECS Fargate Spot (1 vCPU, 2GB RAM)

| Usage Pattern | Monthly Cost |
|---------------|--------------|
| Always running (24/7) | ~$9 |
| 2 hours/day | ~$0.75 |
| Auto-scale (queue-based) | ~$0.50-$2 |
| Per 5-min transcription | ~$0.001 |

### Local Worker

| Usage Pattern | Monthly Cost |
|---------------|--------------|
| Any | $0 |

---

## Updating the Worker Code

When you make changes to `src/worker.py`:

### For Local Worker
```bash
# Just restart it
pkill -f worker.py
cd cloud/gpu-worker
python src/worker.py
```

### For ECS Worker
```bash
# Rebuild and push image
./scripts/build-and-push-worker.sh

# Force ECS to use new image
aws ecs update-service \
  --cluster rem-transcription-cluster-dev \
  --service rem-transcription-worker-dev \
  --force-new-deployment
```

---

## Troubleshooting

### ECS task keeps stopping

Check logs:
```bash
./scripts/view-ecs-logs.sh
```

Common issues:
- Missing environment variables
- IAM permissions
- Docker image build errors

### Both workers running

```bash
./scripts/check-worker-status.sh
```

Will warn you if both are running. Stop one:
```bash
# Stop local
pkill -f worker.py

# OR stop ECS
./scripts/use-local-worker.sh
```

### No workers running

```bash
./scripts/check-worker-status.sh
```

Will warn you. Start one:
```bash
# Start local
cd cloud/gpu-worker && python src/worker.py

# OR start ECS
./scripts/use-ecs-worker.sh
```

---

## Recommendations

### For Development
Use **local worker** - it's free and easier to debug.

### For Production
Use **ECS Fargate** with auto-scaling - it's hands-off and only costs when processing.

### For Cost Optimization
- Use Fargate Spot (already configured, 70% cheaper)
- Enable auto-scaling (already configured)
- Use smaller Whisper model (`base` instead of `large`)

---

## Advanced Configuration

Edit `cloud/infra/variables.tf`:

```hcl
# Enable/disable ECS worker
variable "enable_ecs_worker" {
  default = false  # Set to true to enable by default
}

# CPU and memory
variable "ecs_cpu" {
  default = 1024  # 1 vCPU
}

variable "ecs_memory" {
  default = 2048  # 2 GB
}

# Auto-scaling
variable "ecs_min_tasks" {
  default = 0  # Scale to 0 when idle
}

variable "ecs_max_tasks" {
  default = 3  # Max concurrent tasks
}

# Whisper model
variable "whisper_model" {
  default = "base"  # tiny, base, small, medium, large-v2
}
```

Then apply:
```bash
cd cloud/infra
terraform apply
```

---

## Summary

| Command | Purpose |
|---------|---------|
| `./scripts/use-local-worker.sh` | Switch to local worker |
| `./scripts/use-ecs-worker.sh` | Switch to ECS worker |
| `./scripts/check-worker-status.sh` | Check what's running |
| `./scripts/view-ecs-logs.sh` | View ECS logs |
| `./scripts/build-and-push-worker.sh` | Update ECS image |

**Default:** Local worker (free, manual start)  
**Alternative:** ECS Fargate (auto-scaling, ~$5-10/month)

