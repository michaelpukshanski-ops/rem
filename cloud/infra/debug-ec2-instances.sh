#!/bin/bash
# Debug EC2 Spot instances for REM ECS worker

set -e

REGION="${AWS_REGION:-us-west-2}"
CLUSTER_NAME="rem-transcription-cluster-dev"

echo "========================================="
echo "REM EC2 Spot Instance Diagnostics"
echo "========================================="
echo ""

# 1. Check EC2 instances
echo "1. EC2 Instances Status:"
echo "-------------------------"
aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=REM ECS Spot Worker" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,LaunchTime,PrivateIpAddress,PublicIpAddress]' \
  --output table

echo ""

# 2. Get instance IDs
INSTANCE_IDS=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=REM ECS Spot Worker" "Name=instance-state-name,Values=running,pending" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text)

if [ -z "$INSTANCE_IDS" ]; then
  echo "❌ No instances found!"
  exit 1
fi

echo "Found instances: $INSTANCE_IDS"
echo ""

# 3. Check ECS cluster container instances
echo "2. ECS Container Instances:"
echo "-------------------------"
aws ecs list-container-instances \
  --region "$REGION" \
  --cluster "$CLUSTER_NAME" \
  --query 'containerInstanceArns' \
  --output table

CONTAINER_INSTANCE_COUNT=$(aws ecs list-container-instances \
  --region "$REGION" \
  --cluster "$CLUSTER_NAME" \
  --query 'length(containerInstanceArns)' \
  --output text)

echo ""
echo "Container instances registered: $CONTAINER_INSTANCE_COUNT"
echo ""

# 4. Check system logs for each instance
echo "3. EC2 System Logs (last 50 lines):"
echo "-------------------------"
for INSTANCE_ID in $INSTANCE_IDS; do
  echo ""
  echo "Instance: $INSTANCE_ID"
  echo "---"
  aws ec2 get-console-output \
    --region "$REGION" \
    --instance-id "$INSTANCE_ID" \
    --query 'Output' \
    --output text 2>/dev/null | tail -50 || echo "Console output not available yet"
  echo ""
done

# 5. Check Auto Scaling Group
echo "4. Auto Scaling Group Status:"
echo "-------------------------"
aws autoscaling describe-auto-scaling-groups \
  --region "$REGION" \
  --auto-scaling-group-names "rem-ecs-spot-asg-dev" \
  --query 'AutoScalingGroups[*].[AutoScalingGroupName,DesiredCapacity,MinSize,MaxSize,Instances[*].[InstanceId,LifecycleState,HealthStatus]]' \
  --output table 2>/dev/null || echo "ASG not found or error"

echo ""

# 6. Check ECS service
echo "5. ECS Service Status:"
echo "-------------------------"
aws ecs describe-services \
  --region "$REGION" \
  --cluster "$CLUSTER_NAME" \
  --services "rem-transcription-worker-dev" \
  --query 'services[*].[serviceName,status,runningCount,desiredCount,pendingCount]' \
  --output table

echo ""
echo "========================================="
echo "Diagnostics Complete"
echo "========================================="
echo ""
echo "Common Issues:"
echo "1. If EC2 instances are running but not registered with ECS:"
echo "   - Check IAM instance profile permissions"
echo "   - Check security group allows outbound HTTPS (443)"
echo "   - Check user data script in launch template"
echo ""
echo "2. If instances are stuck in 'pending':"
echo "   - Spot capacity might not be available"
echo "   - Check Spot request status"
echo ""
echo "3. To view detailed logs, SSH into instance:"
echo "   ssh -i your-key.pem ec2-user@<PUBLIC_IP>"
echo "   sudo cat /var/log/ecs/ecs-init.log"
echo "   sudo cat /var/log/ecs/ecs-agent.log"

