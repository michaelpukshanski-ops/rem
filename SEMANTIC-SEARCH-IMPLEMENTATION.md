# Semantic Search Implementation Plan

## Phase 1: Semantic Search with Embeddings ✅ IN PROGRESS

### Overview
Add vector embeddings to enable semantic search - find memories by meaning, not just keywords.

### Architecture

```
┌──────────────────┐
│  GPU Worker      │
│  1. Transcribe   │
│  2. Generate     │
│     Embeddings   │ ← OpenAI text-embedding-3-small
│  3. Upload       │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│   DynamoDB       │
│  + embeddings    │ ← New field: array of floats
│  + summary       │ ← New field: text summary
└──────────────────┘

┌──────────────────┐
│ Query Lambda     │
│  1. Embed query  │ ← OpenAI embedding
│  2. Cosine sim   │ ← Calculate similarity
│  3. Hybrid rank  │ ← Keywords + semantic
└──────────────────┘
```

### Changes Made

#### 1. Infrastructure ✅
- [x] Added `openai_api_key` variable to `cloud/infra/variables.tf`
- [x] Added `OPENAI_API_KEY` to Lambda environment variables
- [x] Added `OPENAI_API_KEY` to ECS task definition

#### 2. Dependencies ✅
- [x] Added `openai>=1.0.0` to `cloud/gpu-worker/requirements.txt`
- [x] Added `openai` to `cloud/lambdas/query-transcripts/package.json`

#### 3. Worker Updates ✅
- [x] Add embedding generation function
- [x] Generate embeddings for full transcript
- [x] Generate embeddings for each segment
- [x] Generate AI summary using GPT-4o-mini
- [x] Extract topics from transcripts
- [x] Store embeddings, summary, and topics in DynamoDB
- [x] Add error handling for OpenAI API

#### 4. Query Lambda Updates ✅
- [x] Add embedding generation for query
- [x] Implement cosine similarity calculation
- [x] Implement hybrid search (keywords + semantic)
- [x] Rank results by combined score

### Data Model

#### DynamoDB Record (Enhanced)
```json
{
  "PK": "default-user",
  "SK": "recording-id-uuid",
  "recordingId": "uuid",
  "deviceId": "esp32-AABBCCDDEEFF",
  "s3KeyRaw": "raw/...",
  "transcriptS3Key": "transcripts/...",
  "status": "TRANSCRIBED",
  "language": "en",
  "durationSeconds": 300.5,
  "embedding": [0.123, -0.456, ...],  // NEW: 1536 dimensions
  "summary": "Discussed project deadlines...",  // NEW: AI summary
  "topics": ["work", "deadlines", "meetings"],  // NEW: extracted topics
  "createdAt": "2025-12-09T14:35:10Z",
  "updatedAt": "2025-12-09T14:37:25Z"
}
```

#### Transcript JSON (Enhanced)
```json
{
  "recordingId": "uuid",
  "userId": "default-user",
  "deviceId": "esp32-AABBCCDDEEFF",
  "language": "en",
  "segments": [
    {
      "id": 0,
      "start": 0.0,
      "end": 5.2,
      "text": "Hello, this is a test recording.",
      "embedding": [0.123, -0.456, ...]  // NEW: per-segment embedding
    }
  ],
  "fullText": "Hello, this is a test recording...",
  "embedding": [0.789, -0.234, ...],  // NEW: full transcript embedding
  "summary": "Test recording discussing...",  // NEW: AI summary
  "topics": ["test", "recording"],  // NEW: extracted topics
  "durationSeconds": 300.5,
  "transcribedAt": "2025-12-09T14:37:25Z",
  "whisperModel": "base"
}
```

### OpenAI API Usage

#### Embedding Model
- **Model**: `text-embedding-3-small`
- **Dimensions**: 1536
- **Cost**: $0.02 per 1M tokens
- **Speed**: ~1000 tokens/sec

#### Example Cost
- 5-min recording: ~1,000 tokens
- Cost per recording: $0.00002
- 1,000 recordings: $0.02
- **Very affordable!** ✅

### Search Algorithm

#### Hybrid Search
1. **Keyword Search** (existing)
   - Split query into keywords
   - Match against transcript text
   - Score: keyword_matches / total_keywords

2. **Semantic Search** (new)
   - Generate embedding for query
   - Calculate cosine similarity with each recording
   - Score: cosine_similarity (0-1)

3. **Combined Score**
   - `final_score = (keyword_score * 0.3) + (semantic_score * 0.7)`
   - Semantic weighted higher for meaning-based search
   - Adjustable weights

#### Cosine Similarity
```typescript
function cosineSimilarity(a: number[], b: number[]): number {
  const dotProduct = a.reduce((sum, val, i) => sum + val * b[i], 0);
  const magnitudeA = Math.sqrt(a.reduce((sum, val) => sum + val * val, 0));
  const magnitudeB = Math.sqrt(b.reduce((sum, val) => sum + val * val, 0));
  return dotProduct / (magnitudeA * magnitudeB);
}
```

### Deployment Steps

1. **Set OpenAI API Key**
   ```bash
   cd cloud/infra
   echo 'openai_api_key = "sk-..."' >> terraform.tfvars
   ```

2. **Deploy Infrastructure**
   ```bash
   terraform apply
   ```

3. **Build and Deploy Worker**
   ```bash
   ./scripts/build-and-push-worker.sh
   ```

4. **Build and Deploy Query Lambda**
   ```bash
   ./scripts/deploy-query-lambda.sh
   ```

5. **Test**
   ```bash
   # Upload a test recording
   # Query with semantic search
   curl -X POST "https://your-api.com/query" \
     -H "Content-Type: application/json" \
     -d '{"userId":"default-user","query":"feeling stressed about work","limit":5}'
   ```

### Next Phases

## Phase 2: Summarization
- Generate AI summaries of recordings
- Daily/weekly summary aggregation
- Include in ChatGPT responses

## Phase 3: Topic Extraction
- Extract topics from transcripts
- Enable topic-based search
- Show trending topics over time

## Phase 4: Speaker Diarization
- Identify different speakers
- Attribute quotes to speakers
- Search by speaker

## Phase 5: API Authentication
- Add API key authentication
- Rate limiting
- Usage tracking

---

## Progress Tracking

- [x] Phase 1: Infrastructure setup
- [x] Phase 1: Worker implementation
- [x] Phase 1: Query Lambda implementation
- [ ] Phase 1: Deployment and testing
- [x] Phase 2: Summarization (BONUS: Already implemented!)
- [x] Phase 3: Topic Extraction (BONUS: Already implemented!)
- [ ] Phase 4: Speaker Diarization
- [ ] Phase 5: API Authentication

