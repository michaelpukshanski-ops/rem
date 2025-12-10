# Local Lambda Debugging Guide

This guide explains how to run and debug Lambda functions locally on your development machine.

## Prerequisites

1. **Node.js 20+** installed
2. **AWS credentials** configured (either via `~/.aws/credentials` or environment variables)
3. **Access to AWS resources** (S3, DynamoDB, SQS)

## Setup

### 1. Install Dependencies

For each Lambda you want to debug, install dependencies:

```bash
# Ingest Audio Lambda
cd cloud/lambdas/ingest-audio
npm install

# Transcription Dispatcher Lambda
cd cloud/lambdas/transcription-dispatcher
npm install

# Query Transcripts Lambda
cd cloud/lambdas/query-transcripts
npm install
```

### 2. Create .env.local Files

Each Lambda needs a `.env.local` file with AWS credentials and environment variables.

#### Ingest Audio Lambda

```bash
cd cloud/lambdas/ingest-audio
cp .env.local.example .env.local
# Edit .env.local with your values
```

Example `.env.local`:
```bash
AWS_REGION=us-east-1
RAW_AUDIO_BUCKET=rem-raw-audio-31ed23ee
DYNAMODB_TABLE=rem-recordings-dev
USER_ID=test-user
API_KEY=your-api-key
```

#### Transcription Dispatcher Lambda

```bash
cd cloud/lambdas/transcription-dispatcher
cp .env.local.example .env.local
# Edit .env.local with your values
```

Example `.env.local`:
```bash
AWS_REGION=us-east-1
RAW_AUDIO_BUCKET=rem-raw-audio-31ed23ee
DYNAMODB_TABLE=rem-recordings-dev
SQS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/454351324462/rem-transcription-jobs-dev
USER_ID=test-user
```

#### Query Transcripts Lambda

```bash
cd cloud/lambdas/query-transcripts
cp .env.local.example .env.local
# Edit .env.local with your values
```

Example `.env.local`:
```bash
AWS_REGION=us-east-1
DYNAMODB_TABLE=rem-recordings-dev
TRANSCRIPTS_BUCKET=rem-transcripts-31ed23ee
USER_ID=test-user
```

## Running Lambdas Locally

### Ingest Audio Lambda

```bash
cd cloud/lambdas/ingest-audio

# Run with default test file (../../../test.wav)
npm run dev

# Run with custom audio file
npm run dev /path/to/your/audio.wav
```

**What it does:**
- Creates a mock multipart/form-data request
- Uploads the audio file to S3
- Creates a DynamoDB record
- Returns the recording ID

### Transcription Dispatcher Lambda

```bash
cd cloud/lambdas/transcription-dispatcher

# Run with default S3 key
npm run dev

# Run with custom S3 key
npm run dev "raw/test-device/2024/12/10/test-device_2024-12-10T10-00-00Z_2024-12-10T10-05-00Z.wav"
```

**What it does:**
- Simulates an S3 ObjectCreated event
- Queries DynamoDB for the recording
- Updates status to TRANSCRIBING
- Sends message to SQS queue

### Query Transcripts Lambda

```bash
cd cloud/lambdas/query-transcripts

# Run with default query
npm run dev

# Run with custom query
npm run dev "search term"

# Run with user ID filter
npm run dev "search term" "user-123"

# Run with device ID filter
npm run dev "search term" "user-123" "device-456"
```

**What it does:**
- Queries DynamoDB for transcripts
- Searches S3 for transcript content
- Returns matching results

## Debugging with VS Code

### 1. Start Debug Mode

```bash
cd cloud/lambdas/ingest-audio
npm run debug
```

This will start the Lambda with the debugger waiting for a connection.

### 2. Attach VS Code Debugger

Create `.vscode/launch.json` in the project root:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "node",
      "request": "attach",
      "name": "Attach to Lambda",
      "port": 9229,
      "restart": true,
      "skipFiles": ["<node_internals>/**"]
    }
  ]
}
```

### 3. Set Breakpoints

1. Open the Lambda source file (e.g., `cloud/lambdas/ingest-audio/src/index.ts`)
2. Click in the gutter to set breakpoints
3. Press F5 or click "Run > Start Debugging"
4. The debugger will attach and pause at your breakpoints

## Debugging with Chrome DevTools

### 1. Start Debug Mode

```bash
cd cloud/lambdas/ingest-audio
npm run debug
```

### 2. Open Chrome DevTools

1. Open Chrome browser
2. Go to `chrome://inspect`
3. Click "Open dedicated DevTools for Node"
4. Your Lambda will appear in the list
5. Click "inspect" to start debugging

## Tips

### Use Console Logs

Add `console.log()` statements in your Lambda code:

```typescript
console.log('Processing event:', JSON.stringify(event, null, 2));
console.log('S3 Key:', s3Key);
console.log('DynamoDB result:', result);
```

These will appear in your terminal when running locally.

### Test with Real AWS Resources

The local test environment uses **real AWS resources** (S3, DynamoDB, SQS). This means:

✅ **Pros:**
- Tests the full integration
- No mocking required
- Catches real AWS permission issues

⚠️ **Cons:**
- Creates real data in AWS
- Costs money (minimal for testing)
- Requires AWS credentials

### Clean Up Test Data

After testing, clean up:

```bash
# Delete test S3 objects
aws s3 rm s3://rem-raw-audio-31ed23ee/raw/test-device/ --recursive

# Delete test DynamoDB records
aws dynamodb delete-item \
  --table-name rem-recordings-dev \
  --key '{"PK":{"S":"test-user"},"SK":{"S":"rec_xxxxx"}}'

# Purge SQS queue
aws sqs purge-queue --queue-url https://sqs.us-east-1.amazonaws.com/.../rem-transcription-jobs-dev
```

## Troubleshooting

### "AWS credentials not found"

Make sure you have AWS credentials configured:

```bash
# Option 1: AWS CLI profile
aws configure

# Option 2: Environment variables in .env.local
AWS_ACCESS_KEY_ID=your-key
AWS_SECRET_ACCESS_KEY=your-secret
```

### "Table/Bucket not found"

Make sure your `.env.local` has the correct resource names. Get them from Terraform:

```bash
cd cloud/infra
terraform output
```

### "Permission denied"

Your AWS credentials need permissions for:
- S3: `s3:PutObject`, `s3:GetObject`
- DynamoDB: `dynamodb:PutItem`, `dynamodb:Query`, `dynamodb:UpdateItem`
- SQS: `sqs:SendMessage`

## Next Steps

Once you've debugged locally and fixed issues:

1. **Rebuild the Lambda:**
   ```bash
   npm run rebuild
   ```

2. **Deploy to AWS:**
   ```bash
   cd cloud/infra
   terraform apply
   ```

3. **Test in production:**
   ```bash
   curl -X POST "https://your-api.execute-api.us-east-1.amazonaws.com/ingest" ...
   ```

