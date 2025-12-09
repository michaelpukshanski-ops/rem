# REM Infrastructure - Main Configuration

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
  
  # Uncomment and configure for remote state
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "rem/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = var.tags
  }
}

# Generate random suffix for globally unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

# Generate API key if not provided
resource "random_password" "api_key" {
  length  = 32
  special = false
}

locals {
  api_key                  = var.api_key_value != "" ? var.api_key_value : random_password.api_key.result
  raw_audio_bucket_name    = var.s3_raw_audio_bucket_name != "" ? var.s3_raw_audio_bucket_name : "${var.project_name}-raw-audio-${random_id.suffix.hex}"
  transcripts_bucket_name  = var.s3_transcripts_bucket_name != "" ? var.s3_transcripts_bucket_name : "${var.project_name}-transcripts-${random_id.suffix.hex}"
  
  common_lambda_environment = {
    USER_ID                  = var.user_id
    RAW_AUDIO_BUCKET         = local.raw_audio_bucket_name
    TRANSCRIPTS_BUCKET       = local.transcripts_bucket_name
    DYNAMODB_TABLE           = aws_dynamodb_table.recordings.name
    SQS_QUEUE_URL            = aws_sqs_queue.transcription_jobs.url
    API_KEY                  = local.api_key
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

