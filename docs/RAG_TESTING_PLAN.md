# REM RAG System - Testing Plan

## 🧪 Testing Checklist

### Phase 1: Installation & Setup

- [ ] **Install Ollama**
  ```bash
  brew install ollama
  brew services start ollama
  ollama list  # Should show service running
  ```

- [ ] **Download Llama Model**
  ```bash
  ollama pull llama3.2:3b
  ollama list  # Should show llama3.2:3b
  ```

- [ ] **Install Python Dependencies**
  ```bash
  cd cloud/gpu-worker
  source venv/bin/activate
  pip install -r requirements-rag.txt
  ```

- [ ] **Verify Directories Created**
  ```bash
  ls -la ~/.rem/
  # Should show: transcripts/, chroma/ directories
  ```

### Phase 2: Data Sync

- [ ] **Sync Transcripts from S3**
  ```bash
  python3 scripts/sync-transcripts.py
  # Should download transcripts to ~/.rem/transcripts/
  ```

- [ ] **Verify Transcripts Downloaded**
  ```bash
  find ~/.rem/transcripts/ -name "*.json" | wc -l
  # Should show number of transcript files
  ```

- [ ] **Check Sync Metadata**
  ```bash
  cat ~/.rem/sync_metadata.json
  # Should show last_sync timestamp and synced_files
  ```

### Phase 3: Indexing

- [ ] **Index Transcripts**
  ```bash
  python3 src/indexer.py
  # Should create embeddings and populate ChromaDB
  ```

- [ ] **Verify Index Created**
  ```bash
  python3 -c "import chromadb; from rag_config import RAG_CONFIG; c = chromadb.PersistentClient(path=str(RAG_CONFIG['chroma_dir'])); print(f'Chunks: {c.get_collection(RAG_CONFIG[\"collection_name\"]).count()}')"
  # Should show number of indexed chunks
  ```

- [ ] **Test Re-indexing**
  ```bash
  python3 src/indexer.py --reindex
  # Should clear and rebuild index
  ```

### Phase 4: Querying

- [ ] **Test Single Query**
  ```bash
  python3 src/query_memory.py "test query"
  # Should return answer with sources
  ```

- [ ] **Test Search-Only Mode**
  ```bash
  python3 src/query_memory.py "test" --search-only
  # Should show matching chunks without LLM answer
  ```

- [ ] **Test Interactive Mode**
  ```bash
  python3 src/query_memory.py --interactive
  # Should enter interactive prompt
  # Type: help
  # Type: test question
  # Type: exit
  ```

- [ ] **Test Top-K Parameter**
  ```bash
  python3 src/query_memory.py "test" --top-k 10
  # Should retrieve 10 results instead of default 5
  ```

- [ ] **Test No Sources**
  ```bash
  python3 src/query_memory.py "test" --no-sources
  # Should not show source citations
  ```

### Phase 5: Integration

- [ ] **Test Auto-Indexing in Worker**
  ```bash
  # Start worker
  python3 src/worker.py
  
  # Upload a new recording via USB watcher
  # Worker should automatically index the new transcript
  # Check logs for "Auto-indexed transcript" message
  ```

- [ ] **Verify New Transcript Searchable**
  ```bash
  # Query for content from the newly uploaded recording
  python3 src/query_memory.py "content from new recording"
  # Should find the new transcript
  ```

### Phase 6: Performance

- [ ] **Measure Sync Speed**
  ```bash
  time python3 scripts/sync-transcripts.py --full-sync
  # Should complete in reasonable time (~1-2 min per 100 transcripts)
  ```

- [ ] **Measure Indexing Speed**
  ```bash
  time python3 src/indexer.py --reindex
  # Should complete in reasonable time (~2-3 min per 100 transcripts)
  ```

- [ ] **Measure Query Speed**
  ```bash
  time python3 src/query_memory.py "test query"
  # Should complete in 1-3 seconds
  ```

### Phase 7: Error Handling

- [ ] **Test Without Ollama Running**
  ```bash
  brew services stop ollama
  python3 src/query_memory.py "test"
  # Should show error: "Ollama not available"
  ```

- [ ] **Test Without Index**
  ```bash
  rm -rf ~/.rem/chroma/
  python3 src/query_memory.py "test"
  # Should show error: "Collection not found"
  ```

- [ ] **Test Without Transcripts**
  ```bash
  rm -rf ~/.rem/transcripts/
  python3 src/indexer.py
  # Should show error: "No transcript files found"
  ```

## 🎯 Test Scenarios

### Scenario 1: First-Time Setup

1. Run setup script
2. Sync transcripts
3. Index transcripts
4. Ask a question
5. Verify answer with sources

### Scenario 2: Daily Usage

1. Sync new transcripts
2. Index new transcripts
3. Ask multiple questions in interactive mode
4. Verify answers are relevant

### Scenario 3: Auto-Indexing

1. Start worker
2. Upload new recording
3. Wait for transcription
4. Query for new content
5. Verify it's searchable

### Scenario 4: Re-indexing

1. Make changes to config
2. Re-index all transcripts
3. Verify queries still work
4. Check performance

## ✅ Success Criteria

- [ ] All installation steps complete without errors
- [ ] Transcripts sync successfully from S3
- [ ] Indexing creates embeddings for all transcripts
- [ ] Queries return relevant results
- [ ] Sources are cited correctly
- [ ] Interactive mode works smoothly
- [ ] Auto-indexing works with worker
- [ ] Performance meets targets:
  - Sync: <1 min per 100 transcripts
  - Index: <2 min per 100 transcripts
  - Query: <3 seconds
- [ ] Error messages are clear and helpful
- [ ] Documentation is accurate

## 🐛 Known Issues to Test

- [ ] Tilde expansion in paths
- [ ] JSON parsing errors
- [ ] ChromaDB persistence
- [ ] Ollama connection issues
- [ ] Memory usage with large collections
- [ ] Concurrent access to ChromaDB

## 📊 Test Data

Use these test queries to verify system works:

1. **Specific topic**: "What did I say about [topic]?"
2. **Time-based**: "What did I discuss last week?"
3. **Decision tracking**: "What decisions did I make?"
4. **Summarization**: "Summarize my thoughts on [topic]"
5. **Action items**: "What action items did I mention?"

## 🔄 Regression Testing

After any code changes, re-run:

1. Sync test
2. Index test
3. Query test
4. Auto-index test

## 📝 Test Results

Document results here:

```
Date: ___________
Tester: ___________

Phase 1 (Setup): ☐ Pass ☐ Fail
Phase 2 (Sync): ☐ Pass ☐ Fail
Phase 3 (Index): ☐ Pass ☐ Fail
Phase 4 (Query): ☐ Pass ☐ Fail
Phase 5 (Integration): ☐ Pass ☐ Fail
Phase 6 (Performance): ☐ Pass ☐ Fail
Phase 7 (Errors): ☐ Pass ☐ Fail

Notes:
_________________________________
_________________________________
_________________________________
```

