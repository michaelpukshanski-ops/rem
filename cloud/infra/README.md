# REM Infrastructure (Terraform)

This directory contains Terraform configuration for deploying the complete REM cloud infrastructure on AWS.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- AWS CLI configured with appropriate credentials
- AWS account with permissions to create:
  - S3 buckets
  - DynamoDB tables
  - Lambda functions
  - API Gateway
  - SQS queues
  - IAM roles and policies
  - CloudWatch log groups

## Quick Start

### 1. Initialize Terraform

```bash
cd cloud/infra
terraform init
```

### 2. Review and Customize Variables

Edit `variables.tf` or create a `terraform.tfvars` file:

```hcl
aws_region  = "us-east-1"
environment = "dev"
user_id     = "your-user-id"

# Optional: specify custom bucket names (must be globally unique)
# s3_raw_audio_bucket_name    = "my-rem-raw-audio"
# s3_transcripts_bucket_name  = "my-rem-transcripts"
```

### 3. Plan Deployment

```bash
terraform plan
```

Review the planned changes carefully.

### 4. Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 5. Get Configuration Values

After deployment, get the configuration values for ESP32 and GPU worker:

```bash
# Get API Gateway URL and API Key for ESP32
terraform output esp32_configuration

# Get SQS and S3 configuration for GPU worker
terraform output gpu_worker_configuration

# Get all outputs
terraform output
```

## Infrastructure Components

### S3 Buckets

- **rem-raw-audio-XXXX**: Stores raw audio files uploaded from ESP32
  - Lifecycle: Auto-delete after 90 days
  - Triggers: S3 event → Transcription Dispatcher Lambda
  
- **rem-transcripts-XXXX**: Stores transcription results
  - Lifecycle: Transition to IA after 30 days, Glacier after 90 days

### DynamoDB Table

- **rem-recordings-{env}**: Stores recording metadata
  - Primary Key: `PK` (userId), `SK` (recordingId)
  - GSI: `DeviceTimeIndex` for querying by device and time
  - Auto-scaling enabled for read/write capacity
  - Point-in-time recovery enabled

### SQS Queues

- **rem-transcription-jobs-{env}**: Queue for transcription jobs
  - Visibility timeout: 15 minutes
  - Dead letter queue configured
  
- **rem-transcription-dlq-{env}**: Dead letter queue for failed jobs
  - CloudWatch alarm configured

### Lambda Functions

1. **rem-ingest-audio-{env}**: Receives audio uploads from ESP32
2. **rem-transcription-dispatcher-{env}**: Triggered by S3, enqueues transcription jobs
3. **rem-query-transcripts-{env}**: Handles query requests from ChatGPT

### API Gateway

- **HTTP API** with two routes:
  - `POST /ingest`: Audio upload endpoint
  - `POST /query`: Transcript query endpoint
- CORS enabled
- CloudWatch logging enabled
- Throttling: 50 req/s, burst 100

## Deployment

### Building Lambda Functions

Before deploying, build the Lambda functions:

```bash
# Build all lambdas
cd cloud/lambdas/ingest-audio
npm install && npm run build

cd ../transcription-dispatcher
npm install && npm run build

cd ../query-transcripts
npm install && npm run build
```

### Updating Lambda Functions

After code changes:

```bash
# Rebuild the specific lambda
cd cloud/lambdas/ingest-audio
npm run build

# Re-apply Terraform
cd ../../infra
terraform apply
```

## Configuration

### Environment Variables

All Lambda functions receive these environment variables:

- `USER_ID`: Default user ID
- `RAW_AUDIO_BUCKET`: S3 bucket for raw audio
- `TRANSCRIPTS_BUCKET`: S3 bucket for transcripts
- `DYNAMODB_TABLE`: DynamoDB table name
- `SQS_QUEUE_URL`: SQS queue URL
- `API_KEY`: API key for authentication

### Customization

Adjust these variables in `variables.tf`:

- `lambda_timeout`: Lambda execution timeout (default: 30s)
- `lambda_memory_size`: Lambda memory allocation (default: 512 MB)
- `dynamodb_read_capacity`: DynamoDB read capacity units
- `dynamodb_write_capacity`: DynamoDB write capacity units
- `sqs_visibility_timeout`: SQS visibility timeout (default: 900s)

## Monitoring

### CloudWatch Logs

- API Gateway logs: `/aws/apigateway/rem-{env}`
- Lambda logs: `/aws/lambda/rem-*-{env}`

### CloudWatch Alarms

- DLQ alarm: Triggers when messages appear in dead letter queue

### Metrics to Monitor

- API Gateway: Request count, latency, 4xx/5xx errors
- Lambda: Invocations, duration, errors, throttles
- DynamoDB: Read/write capacity utilization
- SQS: Messages visible, messages in DLQ

## Cost Optimization

- DynamoDB auto-scaling adjusts capacity based on usage
- S3 lifecycle policies move old data to cheaper storage
- Lambda functions use appropriate memory sizes
- CloudWatch logs retention set to 14 days

## Security

- All S3 buckets block public access
- IAM roles follow least privilege principle
- API key authentication for ESP32 uploads
- Server-side encryption enabled for DynamoDB
- VPC endpoints can be added for private communication

## Cleanup

To destroy all infrastructure:

```bash
terraform destroy
```

**Warning**: This will delete all data including recordings and transcripts!

## Troubleshooting

### Lambda deployment fails

Ensure Lambda zip files exist:
```bash
ls -la ../lambdas/*/dist/function.zip
```

### S3 bucket name conflicts

Bucket names must be globally unique. Set custom names in `terraform.tfvars`:
```hcl
s3_raw_audio_bucket_name = "my-unique-bucket-name"
```

### Permission errors

Ensure your AWS credentials have sufficient permissions to create all resources.

