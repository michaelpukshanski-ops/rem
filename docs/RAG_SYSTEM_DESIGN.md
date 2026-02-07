# REM Local RAG System - Technical Design

## Overview
A local Retrieval-Augmented Generation (RAG) system that enables natural language querying of all transcriptions stored in S3, running entirely on Mac Mini M4 with zero cloud costs.

## Architecture Components

### 1. Data Storage Layer
- **S3 Transcripts**: Source of truth (existing)
- **Local Cache**: `~/.rem/transcripts/` - Downloaded JSON transcripts
- **Vector Database**: ChromaDB at `~/.rem/chroma/` - Embeddings for semantic search
- **Index Metadata**: `~/.rem/index.json` - Tracks sync state and indexed files

### 2. Services Layer

#### Sync Service
- Downloads new/updated transcripts from S3
- Maintains local cache for fast access
- Incremental sync (only new files)
- Handles network failures gracefully

#### Embedding Service
- Model: `sentence-transformers/all-MiniLM-L6-v2`
- Generates 384-dimensional embeddings
- Chunks transcripts into semantic segments
- Optimized for Apple Silicon (MPS backend)

#### LLM Service
- Ollama with Llama 3.2 (3B parameters)
- Runs locally via Metal Performance Shaders
- Generates answers from retrieved context
- Includes source citations

### 3. Application Layer

#### sync-transcripts.py
```
Purpose: Download and sync transcripts from S3
Usage: python3 sync-transcripts.py [--full-sync]
Features:
  - Incremental sync by default
  - Full sync option to re-download everything
  - Progress tracking
  - Error recovery
```

#### indexer.py
```
Purpose: Create embeddings and populate vector database
Usage: python3 indexer.py [--reindex]
Features:
  - Chunks transcripts into segments
  - Generates embeddings
  - Stores in ChromaDB with metadata
  - Deduplication
```

#### query_memory.py
```
Purpose: Interactive query interface
Usage: python3 query_memory.py "What did I say about AWS?"
Features:
  - Natural language queries
  - Semantic search across all transcripts
  - LLM-generated answers
  - Source citations (recording ID, timestamp)
  - Interactive mode
```

## Data Flow

### Initial Setup
1. User runs `sync-transcripts.py` → Downloads all transcripts from S3
2. User runs `indexer.py` → Creates embeddings and populates ChromaDB
3. System ready for queries

### Query Flow
1. User asks question via `query_memory.py`
2. Question converted to embedding
3. ChromaDB finds top-k similar transcript segments
4. Retrieved segments + question sent to Ollama
5. LLM generates answer with sources
6. Answer displayed to user

### Auto-Update Flow
1. Worker creates new transcript → Saves to S3
2. Worker calls indexer to add to ChromaDB
3. New transcript immediately searchable

## Technical Specifications

### Embedding Model
- **Model**: sentence-transformers/all-MiniLM-L6-v2
- **Dimensions**: 384
- **Size**: ~80MB
- **Speed**: ~500 sentences/sec on M4
- **Quality**: Good balance of speed and accuracy

### Vector Database
- **Database**: ChromaDB
- **Storage**: Persistent on disk
- **Distance Metric**: Cosine similarity
- **Index Type**: HNSW (Hierarchical Navigable Small World)

### LLM
- **Model**: Llama 3.2 3B
- **Size**: ~2GB
- **Context Window**: 8K tokens
- **Speed**: ~30 tokens/sec on M4
- **Quantization**: Q4_K_M (4-bit for speed)

### Chunking Strategy
- **Method**: Semantic chunking by segments
- **Size**: ~200-500 words per chunk
- **Overlap**: 50 words between chunks
- **Metadata**: Recording ID, timestamp, speaker, device

## File Structure
```
~/.rem/
├── transcripts/          # Local transcript cache
│   ├── user1/
│   │   ├── device1/
│   │   │   └── recording1.json
│   └── ...
├── chroma/              # ChromaDB vector database
│   └── ...
├── index.json           # Sync metadata
└── config.json          # User configuration

cloud/gpu-worker/
├── src/
│   ├── indexer.py       # Embedding indexer
│   ├── query_memory.py  # Query interface
│   └── rag_service.py   # Shared RAG utilities
└── scripts/
    └── sync-transcripts.py  # S3 sync script
```

## Dependencies
```
chromadb>=0.4.22
sentence-transformers>=2.3.1
ollama>=0.1.6
torch>=2.1.0
```

## Performance Targets
- **Sync**: 100 transcripts/minute
- **Indexing**: 50 transcripts/minute
- **Query**: <2 seconds end-to-end
- **Memory**: <2GB RAM during queries

## Future Enhancements
- Web UI for queries
- Real-time sync daemon
- Multi-user support
- Advanced filters (date range, speaker, device)
- Export search results

