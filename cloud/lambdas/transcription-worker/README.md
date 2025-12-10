# REM Transcription Worker Lambda

Lambda function that processes audio transcription jobs from SQS.

## Features

- **Whisper Transcription**: CPU-optimized with int8 quantization
- **Speaker Diarization**: Identifies different speakers using pyannote.audio
- **AI Enhancements**: Embeddings, summaries, and topic extraction via OpenAI
- **SQS Integration**: Triggered automatically by SQS messages
- **Cost Optimized**: ~83% cheaper than ECS Fargate

## Architecture

```
SQS Queue → Lambda (triggered) → S3 + DynamoDB
```

## Dependencies

This Lambda requires a Lambda Layer with heavy dependencies:
- faster-whisper
- pyannote.audio
- torch
- torchaudio
- openai

See `build-layer.sh` for layer creation.

## Configuration

Environment variables:
- `RAW_AUDIO_BUCKET`: S3 bucket with raw audio files
- `TRANSCRIPTS_BUCKET`: S3 bucket for transcript JSON
- `DYNAMODB_TABLE`: DynamoDB table name
- `WHISPER_MODEL`: Whisper model size (default: base)
- `OPENAI_API_KEY`: OpenAI API key for embeddings/summaries
- `HUGGINGFACE_TOKEN`: HuggingFace token for pyannote models

## Lambda Configuration

- **Memory**: 3008 MB (recommended for Whisper base model)
- **Timeout**: 900 seconds (15 minutes)
- **Ephemeral Storage**: 2048 MB (for model caching in /tmp)
- **Runtime**: Python 3.11

## Deployment

See `LAMBDA-DEPLOYMENT-GUIDE.md` for full deployment instructions.

Quick deploy:
```bash
./build-layer.sh
cd ../../../infra
terraform apply
```

## Cost Comparison

**ECS Fargate** (previous):
- 8 hours/day processing
- ~$24/month

**Lambda** (current):
- Pay per invocation
- ~$3-5/month
- **83% savings!**

## Performance

Processing time per 5-minute recording:
- Transcription: ~60-90 seconds
- Diarization: ~30-60 seconds
- AI enhancements: ~15-30 seconds
- **Total**: ~2-3 minutes

## Monitoring

CloudWatch Logs: `/aws/lambda/rem-transcription-worker-dev`

Key metrics:
- Invocation count
- Duration
- Errors
- Throttles

