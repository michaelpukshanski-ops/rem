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

