# S3 Buckets for REM System

# Raw audio files bucket
resource "aws_s3_bucket" "raw_audio" {
  bucket = local.raw_audio_bucket_name
  
  tags = {
    Name = "REM Raw Audio Storage"
  }
}

resource "aws_s3_bucket_versioning" "raw_audio" {
  bucket = aws_s3_bucket.raw_audio.id
  
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "raw_audio" {
  bucket = aws_s3_bucket.raw_audio.id

  rule {
    id     = "delete-old-recordings"
    status = "Enabled"

    filter {}  # Apply to all objects

    expiration {
      days = 90  # Keep raw audio for 90 days
    }
  }
}

resource "aws_s3_bucket_notification" "raw_audio" {
  bucket = aws_s3_bucket.raw_audio.id

  # Trigger on WAV files (from ESP32)
  lambda_function {
    lambda_function_arn = aws_lambda_function.transcription_dispatcher.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "raw/"
    filter_suffix       = ".wav"
  }

  # Trigger on MP3 files (from upload script)
  lambda_function {
    lambda_function_arn = aws_lambda_function.transcription_dispatcher.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "raw/"
    filter_suffix       = ".mp3"
  }

  depends_on = [aws_lambda_permission.allow_s3_transcription_dispatcher]
}

# Transcripts bucket
resource "aws_s3_bucket" "transcripts" {
  bucket = local.transcripts_bucket_name
  
  tags = {
    Name = "REM Transcripts Storage"
  }
}

resource "aws_s3_bucket_versioning" "transcripts" {
  bucket = aws_s3_bucket.transcripts.id
  
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "transcripts" {
  bucket = aws_s3_bucket.transcripts.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    filter {}  # Apply to all objects

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }
  }
}

# Block public access for both buckets
resource "aws_s3_bucket_public_access_block" "raw_audio" {
  bucket = aws_s3_bucket.raw_audio.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "transcripts" {
  bucket = aws_s3_bucket.transcripts.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CORS configuration for raw audio bucket (for ESP32 uploads)
resource "aws_s3_bucket_cors_configuration" "raw_audio" {
  bucket = aws_s3_bucket.raw_audio.id
  
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["*"]  # Restrict this in production
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

