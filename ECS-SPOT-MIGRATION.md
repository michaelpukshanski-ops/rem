# ECS Fargate → EC2 Spot Migration

## 🎯 Summary

Migrated REM transcription worker from **ECS Fargate** to **ECS with EC2 Spot instances** for **~83% cost savings** while maintaining the same performance with `faster-whisper`.

---

## 💰 Cost Comparison

| Configuration | Monthly Cost | Savings |
|--------------|--------------|---------|
| **ECS Fargate** (before) | ~$24/month | - |
| **ECS Fargate Spot** (previous) | ~$7/month | 70% |
| **ECS EC2 Spot** (now) | ~$3-5/month | **83%** ✅ |
| **Lambda** (alternative) | ~$3-5/month | 83% |

### Why EC2 Spot > Lambda?

1. **Same cost savings** (~83% vs Fargate)
2. **Keep faster-whisper** (4x faster than openai-whisper)
3. **No code changes** (already working)
4. **Spot interruptions OK** (jobs in SQS will retry)

---

## 🔧 What Changed

### Infrastructure (`cloud/infra/ecs.tf`)

#### **Added:**
- ✅ EC2 Launch Template with Spot instances
- ✅ Auto Scaling Group (0-3 instances)
- ✅ ECS Capacity Provider for Spot
- ✅ IAM role for EC2 instances
- ✅ ECS-optimized AMI (Amazon Linux 2)

#### **Updated:**
- ✅ Task definition: `FARGATE` → `EC2` launch type
- ✅ Service: Use EC2 Spot capacity provider
- ✅ Container: CPU/memory at container level (not task level)

#### **Removed:**
- ❌ Fargate-specific settings

### Variables (`cloud/infra/variables.tf`)

#### **Added:**
- `ecs_instance_type` - EC2 instance type (default: `t3.small`)
- `ecs_spot_max_price` - Max Spot price (default: on-demand price)
- `ecs_max_instances` - Max EC2 instances (default: 3)

#### **Updated:**
- `enable_ecs_worker` - Description updated to mention EC2 Spot

---

## 📊 Architecture

### Before (Fargate)
```
SQS → ECS Fargate Task (polling) → S3 + DynamoDB
```

### After (EC2 Spot)
```
SQS → ECS Task on EC2 Spot (polling) → S3 + DynamoDB
       ↑
   Auto Scaling Group (0-3 instances)
   Capacity Provider (managed scaling)
```

---

## 🚀 Deployment

### 1. Deploy Infrastructure

```bash
cd cloud/infra
terraform plan
terraform apply
```

### 2. Build and Push Docker Image

```bash
cd cloud/gpu-worker
./build.sh
```

### 3. Enable Worker

Update `terraform.tfvars`:
```hcl
enable_ecs_worker = true
```

Apply:
```bash
terraform apply
```

### 4. Monitor

```bash
# Check EC2 instances
aws ec2 describe-instances --filters "Name=tag:Name,Values=REM ECS Spot Worker"

# Check ECS tasks
aws ecs list-tasks --cluster rem-transcription-cluster-dev

# Check logs
aws logs tail /ecs/rem-transcription-worker-dev --follow
```

---

## 🔍 Key Configuration

### Instance Type: `t3.small`
- **vCPUs**: 2
- **Memory**: 2 GB
- **On-demand price**: ~$0.0208/hour (~$15/month)
- **Spot price**: ~$0.0062/hour (~$4.5/month) - **70% discount**
- **Sufficient for**: Whisper `base` or `small` model

### Spot Instance Handling
- **Interruption**: ECS drains tasks gracefully
- **SQS visibility timeout**: 15 minutes
- **Job retry**: Automatic (SQS re-queues after timeout)
- **No data loss**: Jobs always complete or retry

---

## 📈 Auto Scaling

### Capacity Provider Scaling
- **Target capacity**: 100%
- **Scales EC2 instances** based on task demand
- **Min instances**: 0 (scales to zero when idle)
- **Max instances**: 3

### Task Auto Scaling
- **Metric**: SQS queue depth
- **Target**: 1 message per task
- **Scale out**: 1 minute cooldown
- **Scale in**: 5 minutes cooldown

---

## ✅ Next Steps

1. ✅ **Deploy infrastructure** with `terraform apply`
2. ✅ **Build and push** Docker image
3. ✅ **Enable worker** with `enable_ecs_worker = true`
4. ✅ **Test** with recording upload
5. ✅ **Monitor** CloudWatch logs and costs

---

## 🎉 Benefits

- ✅ **83% cost savings** (~$20/month saved)
- ✅ **Same performance** (faster-whisper)
- ✅ **Auto-scaling** (0-3 instances)
- ✅ **Fault-tolerant** (Spot interruptions handled)
- ✅ **No code changes** (existing worker code)

