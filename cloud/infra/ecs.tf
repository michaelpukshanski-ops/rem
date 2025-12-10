# ECS with EC2 Spot Instances for Transcription Worker
# 70-90% cost savings vs Fargate while keeping faster-whisper performance

# ============================================================================
# ECR Repository for Worker Docker Image
# ============================================================================

resource "aws_ecr_repository" "worker" {
  name                 = "${var.project_name}-transcription-worker"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  tags = {
    Name = "REM Transcription Worker"
  }
}

# Lifecycle policy to keep only recent images
resource "aws_ecr_lifecycle_policy" "worker" {
  repository = aws_ecr_repository.worker.name
  
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# ============================================================================
# ECS Cluster with EC2 Capacity Provider
# ============================================================================

resource "aws_ecs_cluster" "transcription" {
  name = "${var.project_name}-transcription-cluster-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "REM Transcription Cluster"
  }
}

# Link capacity provider to cluster
resource "aws_ecs_cluster_capacity_providers" "transcription" {
  cluster_name = aws_ecs_cluster.transcription.name

  capacity_providers = [aws_ecs_capacity_provider.spot.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.spot.name
    weight            = 100
    base              = 0
  }
}

# ============================================================================
# EC2 Spot Instances for ECS
# ============================================================================

# Get latest ECS-optimized AMI
data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Launch template for EC2 Spot instances
resource "aws_launch_template" "ecs_spot" {
  name_prefix   = "${var.project_name}-ecs-spot-"
  image_id      = data.aws_ami.ecs_optimized.id
  instance_type = var.ecs_instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance.name
  }

  # Assign public IP for internet access (needed for ECR, S3, etc.)
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    device_index                = 0
    security_groups             = [aws_security_group.ecs_worker.id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.transcription.name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_SPOT_INSTANCE_DRAINING=true >> /etc/ecs/ecs.config
  EOF
  )

  # Request Spot instances
  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price          = var.ecs_spot_max_price
      spot_instance_type = "one-time"
    }
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "REM ECS Spot Worker"
    }
  }
}

# Auto Scaling Group for EC2 Spot instances
resource "aws_autoscaling_group" "ecs_spot" {
  name                = "${var.project_name}-ecs-spot-asg-${var.environment}"
  vpc_zone_identifier = local.ecs_subnets
  min_size            = 0
  max_size            = var.ecs_max_instances
  desired_capacity    = var.enable_ecs_worker ? 1 : 0

  launch_template {
    id      = aws_launch_template.ecs_spot.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "REM ECS Spot Worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }
}

# ECS Capacity Provider for Spot instances
resource "aws_ecs_capacity_provider" "spot" {
  name = "${var.project_name}-spot-${var.environment}"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_spot.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 100
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 10
    }
  }

  tags = {
    Name = "REM Spot Capacity Provider"
  }
}

# ============================================================================
# IAM Role for EC2 Instances
# ============================================================================

resource "aws_iam_role" "ecs_instance" {
  name = "${var.project_name}-ecs-instance-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "${var.project_name}-ecs-instance-${var.environment}"
  role = aws_iam_role.ecs_instance.name
}

# ============================================================================
# CloudWatch Log Group
# ============================================================================

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/${var.project_name}-transcription-worker-${var.environment}"
  retention_in_days = 7
  
  tags = {
    Name = "REM Worker Logs"
  }
}

# ============================================================================
# ECS Task Definition
# ============================================================================

resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.project_name}-transcription-worker-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  # Note: cpu and memory are defined at container level for EC2 launch type
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  
  container_definitions = jsonencode([{
    name   = "worker"
    image  = "${aws_ecr_repository.worker.repository_url}:latest"
    cpu    = var.ecs_cpu
    memory = var.ecs_memory

    environment = [
      { name = "AWS_REGION", value = var.aws_region },
      { name = "SQS_QUEUE_URL", value = aws_sqs_queue.transcription_jobs.url },
      { name = "RAW_AUDIO_BUCKET", value = aws_s3_bucket.raw_audio.id },
      { name = "TRANSCRIPTS_BUCKET", value = aws_s3_bucket.transcripts.id },
      { name = "DYNAMODB_TABLE", value = aws_dynamodb_table.recordings.name },
      { name = "WHISPER_MODEL", value = var.whisper_model },
      { name = "WHISPER_DEVICE", value = "cpu" },
      { name = "WHISPER_COMPUTE_TYPE", value = "float32" },
      { name = "LOG_LEVEL", value = "INFO" },
      { name = "OPENAI_API_KEY", value = var.openai_api_key },
      { name = "HUGGINGFACE_TOKEN", value = var.huggingface_token }
    ]
    
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.worker.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "worker"
      }
    }
    
    essential = true
  }])
  
  tags = {
    Name = "REM Worker Task"
  }
}

# ============================================================================
# ECS Service
# ============================================================================

resource "aws_ecs_service" "worker" {
  name            = "${var.project_name}-transcription-worker-${var.environment}"
  cluster         = aws_ecs_cluster.transcription.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = var.enable_ecs_worker ? 1 : 0

  # Use EC2 Spot for 70-90% cost savings
  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.spot.name
    weight            = 100
    base              = 0
  }

  network_configuration {
    subnets         = local.ecs_subnets
    security_groups = [aws_security_group.ecs_worker.id]
    # Note: assign_public_ip not supported for EC2 launch type
    # Public IP is assigned by the EC2 instance itself
  }

  # Wait for capacity provider to be ready
  depends_on = [aws_ecs_cluster_capacity_providers.transcription]

  tags = {
    Name = "REM Worker Service"
  }
}

# ============================================================================
# Security Group for ECS Tasks
# ============================================================================

resource "aws_security_group" "ecs_worker" {
  name        = "${var.project_name}-ecs-worker-${var.environment}"
  description = "Security group for ECS transcription worker"
  vpc_id      = local.vpc_id

  # Allow all outbound traffic (needed for AWS API calls, S3, SQS, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "REM ECS Worker SG"
  }
}

# ============================================================================
# IAM Role for ECS Task Execution (pulls image, writes logs)
# ============================================================================

resource "aws_iam_role" "ecs_execution" {
  name = "${var.project_name}-ecs-execution-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ============================================================================
# IAM Role for ECS Task (worker permissions)
# ============================================================================

resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-ecs-task-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task" {
  name = "worker-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.transcription_jobs.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.raw_audio.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.transcripts.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ]
        Resource = aws_dynamodb_table.recordings.arn
      }
    ]
  })
}

# ============================================================================
# Auto Scaling based on SQS Queue Depth
# ============================================================================

resource "aws_appautoscaling_target" "ecs_worker" {
  max_capacity       = var.ecs_max_tasks
  min_capacity       = var.enable_ecs_worker ? var.ecs_min_tasks : 0
  resource_id        = "service/${aws_ecs_cluster.transcription.name}/${aws_ecs_service.worker.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_worker_scale_up" {
  name               = "${var.project_name}-worker-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_worker.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_worker.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_worker.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.ecs_target_queue_messages

    customized_metric_specification {
      metric_name = "ApproximateNumberOfMessagesVisible"
      namespace   = "AWS/SQS"
      statistic   = "Average"

      dimensions {
        name  = "QueueName"
        value = aws_sqs_queue.transcription_jobs.name
      }
    }

    scale_in_cooldown  = 300  # 5 minutes
    scale_out_cooldown = 60   # 1 minute
  }
}


