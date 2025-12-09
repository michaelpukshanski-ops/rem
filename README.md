# REM - Recording & Memory System

A complete IoT-to-cloud audio recording and transcription system that captures continuous audio on ESP32 devices, uploads to AWS, transcribes using Whisper, and provides a queryable API for ChatGPT integration.

## System Overview

```
┌─────────────┐
│   ESP32     │  Records audio continuously
│  (I2S Mic)  │  Stores locally with timestamps
└──────┬──────┘  Uploads when WiFi available
       │
       │ HTTPS POST (multipart/form-data)
       ▼
┌─────────────────────────────────────────────────────────┐
│                      AWS Cloud                          │
│                                                         │
│  ┌──────────────┐      ┌─────────────┐                │
│  │ API Gateway  │─────▶│   Ingest    │                │
│  │  (HTTP API)  │      │   Lambda    │                │
│  └──────────────┘      └──────┬──────┘                │
│                               │                         │
│                               ▼                         │
│                    ┌──────────────────┐                │
│                    │  S3: raw-audio   │                │
│                    └────────┬─────────┘                │
│                             │ S3 Event                 │
│                             ▼                           │
│                    ┌──────────────────┐                │
│                    │  Transcription   │                │
│                    │   Dispatcher     │                │
│                    │    (Lambda)      │                │
│                    └────────┬─────────┘                │
│                             │                           │
│                             ▼                           │
│                    ┌──────────────────┐                │
│                    │   SQS Queue      │                │
│                    │ (Transcription   │                │
│                    │     Jobs)        │                │
│                    └────────┬─────────┘                │
│                             │                           │
└─────────────────────────────┼───────────────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │   GPU Worker     │  Runs on GPU instance
                    │   (Whisper)      │  Polls SQS
                    └────────┬─────────┘
                             │
                             ▼
              ┌──────────────────────────────┐
              │  S3: transcripts             │
              │  DynamoDB: RemRecordings     │
              └──────────────┬───────────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  Query Lambda    │  ChatGPT integration
                    │  (API Gateway)   │  Keyword + time search
                    └──────────────────┘
```

## Repository Structure

```
rem/
├── README.md                          # This file
├── esp32/                             # ESP32 firmware (PlatformIO)
│   ├── platformio.ini
│   ├── src/main.cpp
│   ├── include/
│   │   ├── config.h
│   │   └── secrets.h.example
│   └── README.md
├── cloud/                             # AWS cloud components
│   ├── infra/                         # Terraform infrastructure
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── s3.tf
│   │   ├── dynamodb.tf
│   │   ├── sqs.tf
│   │   ├── lambda.tf
│   │   ├── apigw.tf
│   │   └── iam.tf
│   ├── lambdas/
│   │   ├── ingest-audio/              # Receives uploads from ESP32
│   │   │   ├── src/index.ts
│   │   │   ├── package.json
│   │   │   └── tsconfig.json
│   │   ├── transcription-dispatcher/  # Triggers transcription jobs
│   │   │   ├── src/index.ts
│   │   │   ├── package.json
│   │   │   └── tsconfig.json
│   │   └── query-transcripts/         # ChatGPT query API
│   │       ├── src/index.ts
│   │       ├── package.json
│   │       └── tsconfig.json
│   └── gpu-worker/                    # Whisper transcription worker
│       ├── src/worker.py
│       ├── requirements.txt
│       ├── .env.example
│       └── README.md
└── shared/
    ├── types/                         # Shared TypeScript types
    │   └── index.ts
    └── docs/                          # Documentation
        └── api-protocol.md

```

## Quick Start

### 1. Deploy AWS Infrastructure

```bash
cd cloud/infra
terraform init
terraform plan
terraform apply
```

Note the outputs: `api_gateway_url`, `api_key`, `sqs_queue_url`

### 2. Build and Deploy Lambda Functions

```bash
# Ingest Lambda
cd cloud/lambdas/ingest-audio
npm install
npm run build
# Deploy via Terraform or manually zip and upload

# Repeat for other lambdas
```

### 3. Configure and Flash ESP32

```bash
cd esp32
cp include/secrets.h.example include/secrets.h
# Edit secrets.h with your WiFi and API credentials
pio run --target upload
pio device monitor
```

### 4. Run GPU Worker

```bash
cd cloud/gpu-worker
pip install -r requirements.txt
cp .env.example .env
# Edit .env with AWS credentials and queue URL
python src/worker.py
```

## Components

### ESP32 Firmware
- Continuous audio recording via I2S microphone
- 5-minute WAV file chunks with timestamps
- Local storage management (SPIFFS)
- Automatic upload when WiFi available
- Exponential backoff retry logic

### Ingest Lambda
- Receives multipart audio uploads
- Stores raw audio in S3 with organized structure
- Creates DynamoDB records for tracking
- API key authentication

### Transcription Dispatcher
- S3 event-triggered Lambda
- Enqueues transcription jobs to SQS
- Decouples upload from transcription

### GPU Worker
- Polls SQS for transcription jobs
- Downloads audio from S3
- Runs Whisper (faster-whisper)
- Stores transcripts and updates DynamoDB

### Query Lambda
- Keyword and time-based search
- Returns relevant transcript segments
- Designed for ChatGPT tool/action integration
- Extensible for future semantic search

## Configuration

See individual component READMEs for detailed configuration:
- `esp32/README.md` - ESP32 setup and flashing
- `cloud/infra/README.md` - Terraform variables and deployment
- `cloud/gpu-worker/README.md` - GPU worker setup

## License

Private project

