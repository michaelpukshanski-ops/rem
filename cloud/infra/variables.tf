# REM Infrastructure Variables

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "rem"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "user_id" {
  description = "Default user ID for recordings"
  type        = string
  default     = "default-user"
}

variable "api_key_value" {
  description = "API key for ESP32 authentication (leave empty to auto-generate)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "openai_api_key" {
  description = "OpenAI API key for embeddings and summarization"
  type        = string
  default     = ""
  sensitive   = true
}

variable "huggingface_token" {
  description = "HuggingFace token for pyannote.audio speaker diarization models"
  type        = string
  default     = ""
  sensitive   = true
}

variable "api_throttle_rate_limit" {
  description = "API Gateway throttle rate limit (requests per second)"
  type        = number
  default     = 10
}

variable "api_throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 20
}

variable "lambda_runtime" {
  description = "Lambda runtime for Node.js functions"
  type        = string
  default     = "nodejs20.x"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512
}

variable "s3_raw_audio_bucket_name" {
  description = "S3 bucket name for raw audio files (must be globally unique)"
  type        = string
  default     = ""  # Will be auto-generated if empty
}

variable "s3_transcripts_bucket_name" {
  description = "S3 bucket name for transcripts (must be globally unique)"
  type        = string
  default     = ""  # Will be auto-generated if empty
}

variable "dynamodb_read_capacity" {
  description = "DynamoDB read capacity units"
  type        = number
  default     = 5
}

variable "dynamodb_write_capacity" {
  description = "DynamoDB write capacity units"
  type        = number
  default     = 5
}

variable "sqs_visibility_timeout" {
  description = "SQS message visibility timeout in seconds"
  type        = number
  default     = 900  # 15 minutes for transcription processing
}

variable "sqs_message_retention" {
  description = "SQS message retention period in seconds"
  type        = number
  default     = 1209600  # 14 days
}

# ============================================================================
# ECS Variables
# ============================================================================

variable "enable_ecs_worker" {
  description = "Enable ECS Fargate worker (set to false to use local worker)"
  type        = bool
  default     = false
}

variable "ecs_cpu" {
  description = "CPU units for ECS task (1024 = 1 vCPU)"
  type        = number
  default     = 1024  # 1 vCPU
}

variable "ecs_memory" {
  description = "Memory for ECS task in MB"
  type        = number
  default     = 2048  # 2 GB
}

variable "ecs_min_tasks" {
  description = "Minimum number of ECS tasks"
  type        = number
  default     = 0
}

variable "ecs_max_tasks" {
  description = "Maximum number of ECS tasks"
  type        = number
  default     = 3
}

variable "ecs_target_queue_messages" {
  description = "Target number of SQS messages per ECS task for auto-scaling"
  type        = number
  default     = 1
}

variable "whisper_model" {
  description = "Whisper model to use (tiny, base, small, medium, large-v2, large-v3)"
  type        = string
  default     = "base"
}

variable "vpc_id" {
  description = "VPC ID for ECS tasks (leave empty to use default VPC)"
  type        = string
  default     = ""
}

variable "ecs_subnets" {
  description = "Subnet IDs for ECS tasks (leave empty to use default VPC subnets)"
  type        = list(string)
  default     = []
}

variable "enable_api_gateway_logging" {
  description = "Enable CloudWatch logging for API Gateway"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project   = "REM"
    ManagedBy = "Terraform"
  }
}

