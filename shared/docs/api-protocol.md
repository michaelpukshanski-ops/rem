# REM API Protocol Documentation

This document describes the API endpoints and data formats used in the REM system.

## API Endpoints

### 1. Ingest Audio (ESP32 → Cloud)

**Endpoint:** `POST /ingest`

**Authentication:** API Key via `x-api-key` header

**Content-Type:** `multipart/form-data`

**Request Fields:**
- `deviceId` (string, required): Unique device identifier (e.g., "esp32-AABBCCDDEEFF")
- `startedAt` (string, required): Recording start time in ISO 8601 format
- `endedAt` (string, required): Recording end time in ISO 8601 format
- `file` (binary, required): WAV audio file

**Example Request:**
```http
POST /ingest HTTP/1.1
Host: api.rem.example.com
x-api-key: your-api-key-here
Content-Type: multipart/form-data; boundary=----WebKitFormBoundary

------WebKitFormBoundary
Content-Disposition: form-data; name="deviceId"

esp32-AABBCCDDEEFF
------WebKitFormBoundary
Content-Disposition: form-data; name="startedAt"

2025-12-09T14:30:00Z
------WebKitFormBoundary
Content-Disposition: form-data; name="endedAt"

2025-12-09T14:35:00Z
------WebKitFormBoundary
Content-Disposition: form-data; name="file"; filename="recording.wav"
Content-Type: audio/wav

[binary audio data]
------WebKitFormBoundary--
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "recordingId": "550e8400-e29b-41d4-a716-446655440000",
  "message": "Audio uploaded successfully"
}
```

**Error Responses:**
- `401 Unauthorized`: Invalid API key
- `400 Bad Request`: Missing required fields or invalid data
- `500 Internal Server Error`: Server-side error

---

### 2. Query Transcripts (ChatGPT → Cloud)

**Endpoint:** `POST /query`

**Content-Type:** `application/json`

**Request Body:**
```json
{
  "userId": "default-user",
  "query": "What did I discuss about the project deadline?",
  "from": "2025-12-01T00:00:00Z",
  "to": "2025-12-09T23:59:59Z",
  "limit": 10
}
```

**Request Fields:**
- `userId` (string, required): User identifier
- `query` (string, required): Search query (keywords)
- `from` (string, optional): Start of time range (ISO 8601)
- `to` (string, optional): End of time range (ISO 8601)
- `limit` (number, optional): Maximum results to return (default: 10)

**Success Response (200 OK):**
```json
{
  "success": true,
  "results": [
    {
      "recordingId": "550e8400-e29b-41d4-a716-446655440000",
      "deviceId": "esp32-AABBCCDDEEFF",
      "recordingStartedAt": "2025-12-09T14:30:00Z",
      "segmentStart": 45.2,
      "segmentEnd": 52.8,
      "text": "We need to finish the project by Friday to meet the deadline.",
      "relevanceScore": 0.85
    },
    {
      "recordingId": "660e8400-e29b-41d4-a716-446655440001",
      "deviceId": "esp32-AABBCCDDEEFF",
      "recordingStartedAt": "2025-12-08T10:15:00Z",
      "segmentStart": 120.5,
      "segmentEnd": 128.3,
      "text": "The project deadline was moved to next Monday.",
      "relevanceScore": 0.75
    }
  ],
  "totalMatches": 2
}
```

**Error Responses:**
- `400 Bad Request`: Missing required fields
- `500 Internal Server Error`: Server-side error

---

## Data Formats

### Recording Metadata (DynamoDB)

```json
{
  "PK": "default-user",
  "SK": "550e8400-e29b-41d4-a716-446655440000",
  "GSI1PK": "esp32-AABBCCDDEEFF",
  "GSI1SK": "2025-12-09T14:30:00Z",
  "recordingId": "550e8400-e29b-41d4-a716-446655440000",
  "deviceId": "esp32-AABBCCDDEEFF",
  "s3KeyRaw": "raw/esp32-AABBCCDDEEFF/2025/12/09/esp32-AABBCCDDEEFF_2025-12-09T14-30-00Z_2025-12-09T14-35-00Z.wav",
  "startedAt": "2025-12-09T14:30:00Z",
  "endedAt": "2025-12-09T14:35:00Z",
  "status": "TRANSCRIBED",
  "transcriptS3Key": "transcripts/default-user/esp32-AABBCCDDEEFF/550e8400-e29b-41d4-a716-446655440000.json",
  "language": "en",
  "durationSeconds": 300.5,
  "fileSizeBytes": 4800000,
  "createdAt": "2025-12-09T14:35:10Z",
  "updatedAt": "2025-12-09T14:37:25Z"
}
```

### Transcript Data (S3 JSON)

```json
{
  "recordingId": "550e8400-e29b-41d4-a716-446655440000",
  "userId": "default-user",
  "deviceId": "esp32-AABBCCDDEEFF",
  "language": "en",
  "segments": [
    {
      "id": 0,
      "start": 0.0,
      "end": 5.2,
      "text": "Hello, this is a test recording."
    },
    {
      "id": 1,
      "start": 5.5,
      "end": 12.8,
      "text": "We're discussing the project deadline today."
    }
  ],
  "fullText": "Hello, this is a test recording. We're discussing the project deadline today.",
  "durationSeconds": 300.5,
  "transcribedAt": "2025-12-09T14:37:25Z",
  "whisperModel": "base"
}
```

### SQS Transcription Job Message

```json
{
  "recordingId": "550e8400-e29b-41d4-a716-446655440000",
  "bucket": "rem-raw-audio-abc123",
  "key": "raw/esp32-AABBCCDDEEFF/2025/12/09/esp32-AABBCCDDEEFF_2025-12-09T14-30-00Z_2025-12-09T14-35-00Z.wav",
  "userId": "default-user",
  "deviceId": "esp32-AABBCCDDEEFF",
  "startedAt": "2025-12-09T14:30:00Z",
  "endedAt": "2025-12-09T14:35:00Z"
}
```

## Status Flow

1. **UPLOADED**: Audio file uploaded to S3, DynamoDB record created
2. **TRANSCRIBING**: Transcription job enqueued in SQS
3. **TRANSCRIBED**: Transcription complete, results stored
4. **ERROR**: Transcription failed (check DLQ)

## ChatGPT Integration

To use REM as a ChatGPT action/tool:

1. Create a GPT or use the Actions API
2. Configure the action with the query endpoint
3. Provide the OpenAPI schema (see below)
4. ChatGPT can now query your recordings

### OpenAPI Schema Example

```yaml
openapi: 3.0.0
info:
  title: REM Query API
  version: 1.0.0
servers:
  - url: https://your-api-gateway-url.amazonaws.com
paths:
  /query:
    post:
      summary: Query audio transcripts
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [userId, query]
              properties:
                userId:
                  type: string
                query:
                  type: string
                from:
                  type: string
                  format: date-time
                to:
                  type: string
                  format: date-time
                limit:
                  type: integer
      responses:
        '200':
          description: Successful query
```

