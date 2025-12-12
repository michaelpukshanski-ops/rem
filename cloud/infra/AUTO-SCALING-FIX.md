# Auto-Scaling Fix: Visible + NotVisible Messages

## 🐛 The Problem

**Symptom:** ECS service scales to 0 even when there are messages in the SQS queue.

**Root Cause:** The previous auto-scaling configuration only tracked `ApproximateNumberOfMessagesVisible`, which doesn't include **in-flight messages** (messages being processed by workers).

### What Was Happening:

```
1. Message arrives in SQS
   → Visible = 1, NotVisible = 0

2. Worker polls SQS and receives message
   → Visible = 0, NotVisible = 1 (message is "in-flight" for 15 minutes)

3. Auto-scaling sees Visible = 0
   → Scales to 0 tasks

4. Worker gets killed mid-transcription! 💥
```

### Additional Issues:

- **Statistic = "Average"**: Worst choice for binary "is there work?" questions
  - If metric bounces between 0 and 1, average is often < 1
  - Auto-scaling interprets this as "no work" and scales in

- **Target Tracking on Visible only**: Doesn't account for work in progress
  - 15-minute visibility timeout means messages are NotVisible for a long time
  - Auto-scaling thinks queue is empty while work is being processed

---

## ✅ The Solution

### **CloudWatch Metric Math Expression:**

```
backlog = ApproximateNumberOfMessagesVisible + ApproximateNumberOfMessagesNotVisible
```

This tracks **total work** (queued + in-progress).

### **Step Scaling Policies:**

Instead of Target Tracking, we use **Step Scaling** with exact capacity:

1. **Scale OUT** when `backlog >= 1`:
   - Set desired count to `var.ecs_max_tasks`
   - Evaluation: 1 minute
   - Cooldown: 60 seconds

2. **Scale IN** when `backlog < 1` for 5 minutes:
   - Set desired count to `0`
   - Evaluation: 5 periods × 1 minute = 5 minutes
   - Cooldown: 300 seconds

### **Statistic Changed:**

- **Before**: `Average` (unreliable for binary checks)
- **After**: `Maximum` (if it was ever 1 during the period, treat it as 1)

---

## 📊 How It Works Now

### **Scenario 1: Message Arrives**

```
00:00 - Message arrives
        → Visible = 1, NotVisible = 0, Backlog = 1

01:00 - CloudWatch evaluates metric
        → Backlog >= 1 → Trigger scale-out alarm

01:01 - ECS starts Fargate task
        → Desired count = 3 (max_tasks)

01:30 - Task is RUNNING

02:00 - Worker polls SQS
        → Visible = 0, NotVisible = 1, Backlog = 1
        → Auto-scaling sees Backlog = 1 → KEEPS RUNNING ✅

17:00 - Worker finishes transcription (15 minutes later)
        → Deletes message from SQS
        → Visible = 0, NotVisible = 0, Backlog = 0

22:00 - 5 minutes of Backlog = 0
        → Trigger scale-in alarm
        → Desired count = 0

22:01 - ECS stops task
```

### **Scenario 2: Multiple Messages**

```
00:00 - 5 messages arrive
        → Visible = 5, Backlog = 5

01:00 - Scale out to 3 tasks (max_tasks)

02:00 - 3 workers each poll 1 message
        → Visible = 2, NotVisible = 3, Backlog = 5
        → Auto-scaling sees Backlog = 5 → KEEPS 3 TASKS ✅

17:00 - First 3 messages processed
        → Visible = 2, NotVisible = 0, Backlog = 2
        → Auto-scaling sees Backlog = 2 → KEEPS 3 TASKS ✅

18:00 - 2 workers poll remaining messages
        → Visible = 0, NotVisible = 2, Backlog = 2
        → Auto-scaling sees Backlog = 2 → KEEPS 3 TASKS ✅

33:00 - All messages processed
        → Visible = 0, NotVisible = 0, Backlog = 0

38:00 - 5 minutes of Backlog = 0
        → Scale in to 0 tasks
```

---

## 🚀 Applying the Fix

### **Step 1: Apply Terraform**

```bash
cd cloud/infra
terraform apply
```

This will create:
- 2 CloudWatch alarms (scale-out, scale-in)
- 2 Step Scaling policies
- Metric math expressions for backlog calculation

### **Step 2: Verify CloudWatch Alarms**

```bash
aws cloudwatch describe-alarms \
  --alarm-name-prefix "rem-" \
  --region us-east-1
```

Expected alarms:
- `rem-trigger-scale-out-dev`
- `rem-trigger-scale-in-dev`

### **Step 3: Test**

Upload a recording and watch the auto-scaling:

```bash
# Watch ECS service
watch -n 5 'aws ecs describe-services \
  --cluster rem-transcription-cluster-dev \
  --services rem-transcription-worker-dev \
  --region us-east-1 \
  --query "services[0].[desiredCount,runningCount]" \
  --output table'

# Watch SQS metrics
watch -n 5 'aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/454351324462/rem-transcription-jobs-dev \
  --attribute-names ApproximateNumberOfMessagesVisible,ApproximateNumberOfMessagesNotVisible \
  --region us-east-1'
```

---

## 📈 Monitoring

### **CloudWatch Dashboard**

Create a dashboard to visualize the metrics:

1. Go to CloudWatch → Dashboards → Create dashboard
2. Add widgets for:
   - `ApproximateNumberOfMessagesVisible`
   - `ApproximateNumberOfMessagesNotVisible`
   - Metric math: `visible + notvisible`
   - ECS `DesiredCount` and `RunningCount`

### **Expected Behavior**

✅ **Correct:**
- Backlog > 0 → Desired count = max_tasks
- Backlog = 0 for 5 minutes → Desired count = 0

❌ **Incorrect (old behavior):**
- Visible = 0, NotVisible > 0 → Desired count = 0 (WRONG!)

---

## 🎯 Key Improvements

| Aspect | Before | After |
|--------|--------|-------|
| **Metric** | Visible only | Visible + NotVisible |
| **Statistic** | Average | Maximum |
| **Policy Type** | Target Tracking | Step Scaling |
| **Scale-out** | ~2-3 min | ~1-2 min |
| **Scale-in** | Immediate (buggy) | 5 min cooldown |
| **Mid-processing kills** | ❌ Yes | ✅ No |

---

## 💡 Credits

Thanks to ChatGPT for identifying the root cause and suggesting the robust fix!


