# REM System Architecture

## Overview

REM (Recording & Memory) is a distributed audio recording and transcription system consisting of:
- **Edge Device**: ESP32 with I2S microphone for continuous audio recording
- **Cloud Backend**: AWS serverless infrastructure for storage and processing
- **GPU Worker**: Whisper-based transcription service
- **Query API**: ChatGPT-compatible search interface

## System Components

### 1. ESP32 Edge Device

**Hardware:**
- ESP32 microcontroller (dual-core, WiFi-enabled)
- I2S MEMS microphone (INMP441 or similar)
- SD card or SPIFFS for local storage

**Firmware Features:**
- Continuous audio recording at 16kHz, 16-bit, mono
- 5-minute WAV file chunks with timestamps
- Local storage with automatic cleanup
- Periodic WiFi connection for uploads
- Multipart form-data HTTP uploads
- Upload tracking and retry logic

**Data Flow:**
```
Microphone → I2S → ESP32 → SPIFFS → WiFi → API Gateway
```

### 2. Cloud Infrastructure (AWS)

#### API Gateway (HTTP API)
- **Endpoint 1**: `POST /ingest` - Receives audio uploads from ESP32
- **Endpoint 2**: `POST /query` - Handles transcript search queries
- Features: API key authentication, CORS, throttling, CloudWatch logging

#### Lambda Functions

**Ingest Audio Lambda** (Node.js 20.x)
- Triggered by: API Gateway `/ingest` endpoint
- Function: Parse multipart upload, store in S3, create DynamoDB record
- Memory: 1024 MB
- Timeout: 30 seconds

**Transcription Dispatcher Lambda** (Node.js 20.x)
- Triggered by: S3 ObjectCreated events on raw audio bucket
- Function: Enqueue transcription jobs to SQS
- Memory: 512 MB
- Timeout: 30 seconds

**Query Transcripts Lambda** (Node.js 20.x)
- Triggered by: API Gateway `/query` endpoint
- Function: Search transcripts by keyword and time range
- Memory: 512 MB
- Timeout: 30 seconds

#### S3 Buckets

**Raw Audio Bucket** (`rem-raw-audio-{suffix}`)
- Stores: Original WAV files from ESP32
- Structure: `raw/{deviceId}/{YYYY}/{MM}/{DD}/{deviceId}_{start}_{end}.wav`
- Lifecycle: Delete after 90 days
- Event: Triggers transcription-dispatcher Lambda

**Transcripts Bucket** (`rem-transcripts-{suffix}`)
- Stores: Transcription results (JSON and TXT)
- Structure: `transcripts/{userId}/{deviceId}/{recordingId}.json`
- Lifecycle: IA after 30 days, Glacier after 90 days

#### DynamoDB Table

**Table**: `rem-recordings-{env}`
- Primary Key: `PK` (userId), `SK` (recordingId)
- GSI: `DeviceTimeIndex` - `GSI1PK` (deviceId), `GSI1SK` (startedAt)
- Auto-scaling: 5-100 RCU/WCU
- Point-in-time recovery: Enabled

**Record Schema:**
```json
{
  "PK": "default-user",
  "SK": "recording-id-uuid",
  "GSI1PK": "esp32-AABBCCDDEEFF",
  "GSI1SK": "2025-12-09T14:30:00Z",
  "recordingId": "uuid",
  "deviceId": "esp32-AABBCCDDEEFF",
  "s3KeyRaw": "raw/...",
  "transcriptS3Key": "transcripts/...",
  "status": "TRANSCRIBED",
  "language": "en",
  "durationSeconds": 300.5,
  "fileSizeBytes": 4800000,
  "createdAt": "2025-12-09T14:35:10Z",
  "updatedAt": "2025-12-09T14:37:25Z"
}
```

#### SQS Queues

**Transcription Jobs Queue** (`rem-transcription-jobs-{env}`)
- Purpose: Asynchronous job queue for GPU worker
- Visibility timeout: 15 minutes
- Message retention: 14 days
- DLQ: After 3 failed attempts

**Dead Letter Queue** (`rem-transcription-jobs-dlq-{env}`)
- Purpose: Failed transcription jobs
- CloudWatch alarm: Triggers when messages > 0

### 3. GPU Worker

**Runtime Environment:**
- Python 3.9+
- CUDA 11.8+ (for GPU acceleration)
- faster-whisper library

**Processing Pipeline:**
1. Long-poll SQS queue (20-second wait)
2. Download audio from S3 raw bucket
3. Transcribe with Whisper (VAD-filtered)
4. Upload JSON/TXT to S3 transcripts bucket
5. Update DynamoDB record (status, language, duration)
6. Delete SQS message

**Whisper Models:**
- tiny: ~1GB VRAM, fastest
- base: ~1GB VRAM, good accuracy (default)
- small: ~2GB VRAM, better accuracy
- medium: ~5GB VRAM, great accuracy
- large-v3: ~10GB VRAM, best accuracy

**Scalability:**
- Multiple workers can poll same queue
- Each worker processes one job at a time (configurable)
- Auto-scaling based on SQS queue depth

### 4. Query API

**Search Algorithm:**
1. Query DynamoDB for recordings in time range
2. Filter by status = "TRANSCRIBED"
3. Download transcript JSON from S3
4. Keyword matching across segments
5. Relevance scoring (keyword matches / total keywords)
6. Sort by relevance, return top N results

**Response Format:**
```json
{
  "success": true,
  "results": [
    {
      "recordingId": "uuid",
      "deviceId": "esp32-xxx",
      "recordingStartedAt": "2025-12-09T14:30:00Z",
      "segmentStart": 45.2,
      "segmentEnd": 52.8,
      "text": "Matching segment text...",
      "relevanceScore": 0.85
    }
  ],
  "totalMatches": 5
}
```

## Data Flow Diagram

```
┌─────────────┐
│   ESP32     │
│ + I2S Mic   │
└──────┬──────┘
       │ WAV chunks (5 min)
       │ HTTP POST multipart/form-data
       ▼
┌─────────────────┐
│  API Gateway    │
│   /ingest       │
└────────┬────────┘
         │
         ▼
┌──────────────────┐      ┌─────────────┐
│ Ingest Lambda    │─────▶│  S3 Raw     │
│ (TypeScript)     │      │  Audio      │
└────────┬─────────┘      └──────┬──────┘
         │                       │ S3 Event
         ▼                       ▼
┌─────────────────┐      ┌──────────────────┐
│   DynamoDB      │      │ Dispatcher Lambda│
│   Recordings    │      │  (TypeScript)    │
└─────────────────┘      └────────┬─────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │   SQS Queue     │
                         │ Transcription   │
                         │     Jobs        │
                         └────────┬────────┘
                                  │ Long poll
                                  ▼
                         ┌─────────────────┐
                         │  GPU Worker     │
                         │  (Python +      │
                         │   Whisper)      │
                         └────────┬────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                           ▼
           ┌─────────────────┐        ┌─────────────────┐
           │ S3 Transcripts  │        │   DynamoDB      │
           │  (JSON + TXT)   │        │   (Update)      │
           └─────────────────┘        └─────────────────┘
                    │
                    │ Query
                    ▼
           ┌─────────────────┐
           │  Query Lambda   │
           │  (TypeScript)   │
           └────────┬────────┘
                    │
                    ▼
           ┌─────────────────┐
           │  API Gateway    │
           │    /query       │
           └────────┬────────┘
                    │
                    ▼
           ┌─────────────────┐
           │    ChatGPT      │
           │   (Optional)    │
           └─────────────────┘
```

## Security Architecture

### Authentication & Authorization
- **ESP32 → API**: API key in `x-api-key` header
- **GPU Worker → AWS**: IAM role or access keys
- **ChatGPT → API**: API key or OAuth (future)

### Encryption
- **In Transit**: HTTPS/TLS for all API calls
- **At Rest**: 
  - S3: Server-side encryption (SSE-S3)
  - DynamoDB: Encryption at rest enabled
  - SQS: Server-side encryption

### IAM Policies
- **Ingest Lambda**: S3 PutObject, DynamoDB PutItem
- **Dispatcher Lambda**: DynamoDB Query, SQS SendMessage
- **Query Lambda**: DynamoDB Query, S3 GetObject
- **GPU Worker**: SQS ReceiveMessage/DeleteMessage, S3 GetObject/PutObject, DynamoDB UpdateItem

## Monitoring & Observability

### CloudWatch Metrics
- API Gateway: Request count, latency, 4xx/5xx errors
- Lambda: Invocations, duration, errors, throttles
- SQS: Messages sent, received, queue depth
- DynamoDB: Read/write capacity, throttles

### CloudWatch Logs
- API Gateway access logs
- Lambda function logs
- GPU worker logs (via CloudWatch agent)

### CloudWatch Alarms
- DLQ messages > 0
- Lambda error rate > threshold
- API Gateway 5xx errors
- SQS queue depth > threshold

## Scalability Considerations

### Horizontal Scaling
- **ESP32**: Add more devices (each with unique ID)
- **Lambda**: Auto-scales to handle load
- **GPU Workers**: Run multiple instances
- **DynamoDB**: Auto-scaling enabled

### Vertical Scaling
- **Lambda**: Increase memory allocation
- **GPU Worker**: Use larger instance types
- **DynamoDB**: Increase provisioned capacity

### Performance Optimization
- **ESP32**: Compress audio before upload (future)
- **Lambda**: Optimize cold starts with provisioned concurrency
- **GPU Worker**: Batch processing (future)
- **Query**: Add ElasticSearch for full-text search (future)

## Cost Optimization

### Current Architecture
- Serverless-first: Pay only for what you use
- S3 lifecycle policies: Automatic cost reduction
- DynamoDB auto-scaling: Right-size capacity
- Spot Instances: 70% savings on GPU workers

### Future Optimizations
- Lambda@Edge: Reduce latency for global users
- S3 Intelligent-Tiering: Automatic storage class optimization
- Reserved Instances: For predictable GPU workloads
- Compression: Reduce storage and transfer costs

## Future Enhancements

1. **Real-time Transcription**: WebSocket streaming
2. **Speaker Diarization**: Identify different speakers
3. **Semantic Search**: Vector embeddings + similarity search
4. **Multi-language**: Automatic language detection
5. **Mobile App**: iOS/Android for playback and search
6. **Web Dashboard**: Browse and manage recordings
7. **Multi-user**: User authentication and isolation
8. **Edge Processing**: On-device transcription for privacy

