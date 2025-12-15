# Terraform Outputs for REM Infrastructure

# ============================================================================
# API Gateway Outputs
# ============================================================================

output "api_gateway_url" {
  description = "API Gateway endpoint URL (use this in ESP32 secrets.h)"
  value       = "${aws_apigatewayv2_api.rem.api_endpoint}/ingest"
}

output "api_gateway_query_url" {
  description = "API Gateway query endpoint URL (for ChatGPT integration)"
  value       = "${aws_apigatewayv2_api.rem.api_endpoint}/query"
}

output "api_gateway_recordings_url" {
  description = "API Gateway list recordings endpoint URL"
  value       = "${aws_apigatewayv2_api.rem.api_endpoint}/recordings"
}

output "api_gateway_transcript_url" {
  description = "API Gateway get transcript endpoint URL (append /{recordingId})"
  value       = "${aws_apigatewayv2_api.rem.api_endpoint}/transcript"
}

output "api_gateway_user_url" {
  description = "API Gateway user lookup endpoint URL"
  value       = "${aws_apigatewayv2_api.rem.api_endpoint}/user"
}

output "api_gateway_base_url" {
  description = "API Gateway base URL (for ChatGPT GPT configuration)"
  value       = aws_apigatewayv2_api.rem.api_endpoint
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = aws_apigatewayv2_api.rem.id
}

# ============================================================================
# API Key Output
# ============================================================================

output "api_key" {
  description = "API key for ESP32 authentication (use this in ESP32 secrets.h)"
  value       = local.api_key
  sensitive   = true
}

# ============================================================================
# S3 Bucket Outputs
# ============================================================================

output "raw_audio_bucket_name" {
  description = "S3 bucket name for raw audio files"
  value       = aws_s3_bucket.raw_audio.id
}

output "raw_audio_bucket_arn" {
  description = "S3 bucket ARN for raw audio files"
  value       = aws_s3_bucket.raw_audio.arn
}

output "transcripts_bucket_name" {
  description = "S3 bucket name for transcripts"
  value       = aws_s3_bucket.transcripts.id
}

output "transcripts_bucket_arn" {
  description = "S3 bucket ARN for transcripts"
  value       = aws_s3_bucket.transcripts.arn
}

# ============================================================================
# DynamoDB Outputs
# ============================================================================

output "dynamodb_table_name" {
  description = "DynamoDB table name for recordings metadata"
  value       = aws_dynamodb_table.recordings.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN"
  value       = aws_dynamodb_table.recordings.arn
}

output "users_table_name" {
  description = "DynamoDB table name for users"
  value       = aws_dynamodb_table.users.name
}

output "users_table_arn" {
  description = "DynamoDB users table ARN"
  value       = aws_dynamodb_table.users.arn
}

# ============================================================================
# SQS Outputs
# ============================================================================

output "sqs_queue_url" {
  description = "SQS queue URL for transcription jobs (use this in GPU worker)"
  value       = aws_sqs_queue.transcription_jobs.url
}

output "sqs_queue_arn" {
  description = "SQS queue ARN for transcription jobs"
  value       = aws_sqs_queue.transcription_jobs.arn
}

output "sqs_dlq_url" {
  description = "SQS dead letter queue URL"
  value       = aws_sqs_queue.transcription_dlq.url
}

# ============================================================================
# Lambda Outputs
# ============================================================================

output "ingest_lambda_arn" {
  description = "Ingest audio Lambda function ARN"
  value       = aws_lambda_function.ingest_audio.arn
}

output "transcription_dispatcher_lambda_arn" {
  description = "Transcription dispatcher Lambda function ARN"
  value       = aws_lambda_function.transcription_dispatcher.arn
}

output "query_lambda_arn" {
  description = "Query transcripts Lambda function ARN"
  value       = aws_lambda_function.query_transcripts.arn
}

# ============================================================================
# Configuration Summary
# ============================================================================

output "esp32_configuration" {
  description = "Configuration values for ESP32 (copy to secrets.h)"
  value = {
    API_GATEWAY_URL = "${aws_apigatewayv2_api.rem.api_endpoint}/ingest"
    API_KEY         = local.api_key
    USER_ID         = var.user_id
  }
  sensitive = true
}

output "gpu_worker_configuration" {
  description = "Configuration values for GPU worker (copy to .env)"
  value = {
    AWS_REGION         = var.aws_region
    SQS_QUEUE_URL      = aws_sqs_queue.transcription_jobs.url
    RAW_AUDIO_BUCKET   = aws_s3_bucket.raw_audio.id
    TRANSCRIPTS_BUCKET = aws_s3_bucket.transcripts.id
    DYNAMODB_TABLE     = aws_dynamodb_table.recordings.name
  }
}

# ============================================================================
# ECS Outputs
# ============================================================================

output "ecr_repository_url" {
  description = "ECR repository URL for worker Docker image"
  value       = aws_ecr_repository.worker.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.transcription.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.worker.name
}

output "ecs_worker_enabled" {
  description = "Whether ECS worker is enabled"
  value       = var.enable_ecs_worker
}

output "ecs_capacity_provider" {
  description = "ECS capacity provider (Fargate Spot)"
  value       = "FARGATE_SPOT"
}

output "ecs_logs_group" {
  description = "CloudWatch Logs group for ECS worker tasks (application logs)"
  value       = aws_cloudwatch_log_group.worker.name
}

output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    region              = var.aws_region
    environment         = var.environment
    api_endpoint        = aws_apigatewayv2_api.rem.api_endpoint
    raw_audio_bucket    = aws_s3_bucket.raw_audio.id
    transcripts_bucket  = aws_s3_bucket.transcripts.id
    dynamodb_table      = aws_dynamodb_table.recordings.name
    sqs_queue           = aws_sqs_queue.transcription_jobs.name
  }
}

