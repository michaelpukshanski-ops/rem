# Lambda Functions for REM System

# ============================================================================
# Ingest Audio Lambda
# ============================================================================

resource "aws_lambda_function" "ingest_audio" {
  filename         = "${path.module}/../lambdas/ingest-audio/dist/function.zip"
  function_name    = "${var.project_name}-ingest-audio-${var.environment}"
  role            = aws_iam_role.ingest_audio_lambda.arn
  handler         = "index.handler"
  source_code_hash = fileexists("${path.module}/../lambdas/ingest-audio/dist/function.zip") ? filebase64sha256("${path.module}/../lambdas/ingest-audio/dist/function.zip") : null
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = 1024  # Larger for file uploads
  
  environment {
    variables = local.common_lambda_environment
  }
  
  tags = {
    Name = "REM Ingest Audio"
  }
  
  lifecycle {
    ignore_changes = [source_code_hash]
  }
}

resource "aws_cloudwatch_log_group" "ingest_audio" {
  name              = "/aws/lambda/${aws_lambda_function.ingest_audio.function_name}"
  retention_in_days = 14
}

# ============================================================================
# Transcription Dispatcher Lambda
# ============================================================================

resource "aws_lambda_function" "transcription_dispatcher" {
  filename         = "${path.module}/../lambdas/transcription-dispatcher/dist/function.zip"
  function_name    = "${var.project_name}-transcription-dispatcher-${var.environment}"
  role            = aws_iam_role.transcription_dispatcher_lambda.arn
  handler         = "index.handler"
  source_code_hash = fileexists("${path.module}/../lambdas/transcription-dispatcher/dist/function.zip") ? filebase64sha256("${path.module}/../lambdas/transcription-dispatcher/dist/function.zip") : null
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size
  
  environment {
    variables = local.common_lambda_environment
  }
  
  tags = {
    Name = "REM Transcription Dispatcher"
  }
  
  lifecycle {
    ignore_changes = [source_code_hash]
  }
}

resource "aws_cloudwatch_log_group" "transcription_dispatcher" {
  name              = "/aws/lambda/${aws_lambda_function.transcription_dispatcher.function_name}"
  retention_in_days = 14
}

# Permission for S3 to invoke transcription dispatcher
resource "aws_lambda_permission" "allow_s3_transcription_dispatcher" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transcription_dispatcher.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw_audio.arn
}

# ============================================================================
# Query Transcripts Lambda
# ============================================================================

resource "aws_lambda_function" "query_transcripts" {
  filename         = "${path.module}/../lambdas/query-transcripts/dist/function.zip"
  function_name    = "${var.project_name}-query-transcripts-${var.environment}"
  role            = aws_iam_role.query_transcripts_lambda.arn
  handler         = "index.handler"
  source_code_hash = fileexists("${path.module}/../lambdas/query-transcripts/dist/function.zip") ? filebase64sha256("${path.module}/../lambdas/query-transcripts/dist/function.zip") : null
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size
  
  environment {
    variables = local.common_lambda_environment
  }
  
  tags = {
    Name = "REM Query Transcripts"
  }
  
  lifecycle {
    ignore_changes = [source_code_hash]
  }
}

resource "aws_cloudwatch_log_group" "query_transcripts" {
  name              = "/aws/lambda/${aws_lambda_function.query_transcripts.function_name}"
  retention_in_days = 14
}

# ============================================================================
# Lambda Insights (Optional - for enhanced monitoring)
# ============================================================================

# Uncomment to enable Lambda Insights
# resource "aws_lambda_layer_version" "lambda_insights" {
#   layer_name = "LambdaInsightsExtension"
#   compatible_runtimes = [var.lambda_runtime]
# }

