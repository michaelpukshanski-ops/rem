# REM RAG System - Quick Reference

## 🚀 Quick Start

```bash
# 1. Setup (one-time)
./scripts/setup-rag-system.sh

# 2. Sync transcripts
cd cloud/gpu-worker && source venv/bin/activate
python3 scripts/sync-transcripts.py

# 3. Index transcripts
python3 src/indexer.py

# 4. Query!
python3 src/query_memory.py "What did I say about AWS?"
```

## 📝 Common Commands

### Sync Transcripts

```bash
# Incremental sync (only new files)
python3 scripts/sync-transcripts.py

# Full sync (re-download everything)
python3 scripts/sync-transcripts.py --full-sync
```

### Index Transcripts

```bash
# Index new transcripts
python3 src/indexer.py

# Re-index everything
python3 src/indexer.py --reindex

# Index specific file
python3 src/indexer.py --file path/to/transcript.json
```

### Query

```bash
# Single question
python3 src/query_memory.py "your question here"

# Interactive mode
python3 src/query_memory.py --interactive

# Search only (no LLM answer)
python3 src/query_memory.py "search term" --search-only

# More results
python3 src/query_memory.py "question" --top-k 10

# No source citations
python3 src/query_memory.py "question" --no-sources
```

## 🔧 Maintenance

### Check Status

```bash
# Check Ollama
ollama list
brew services list | grep ollama

# Check collection size
python3 -c "import chromadb; from rag_config import RAG_CONFIG; c = chromadb.PersistentClient(path=str(RAG_CONFIG['chroma_dir'])); print(f'Chunks: {c.get_collection(RAG_CONFIG[\"collection_name\"]).count()}')"

# Check synced transcripts
ls -R ~/.rem/transcripts/ | grep .json | wc -l
```

### Update

```bash
# Update dependencies
cd cloud/gpu-worker
source venv/bin/activate
pip install --upgrade -r requirements-rag.txt

# Update Ollama
brew upgrade ollama

# Update Llama model
ollama pull llama3.2:3b
```

### Clean Up

```bash
# Clear vector database
rm -rf ~/.rem/chroma/

# Clear transcript cache
rm -rf ~/.rem/transcripts/

# Clear sync metadata
rm ~/.rem/sync_metadata.json

# Then re-sync and re-index
python3 scripts/sync-transcripts.py
python3 src/indexer.py
```

## 🎯 Example Queries

```bash
# Find specific topics
python3 src/query_memory.py "What did I say about AWS deployment?"

# Time-based
python3 src/query_memory.py "What did I discuss last week about the project?"

# Decision tracking
python3 src/query_memory.py "What decisions did I make about the database?"

# Summarization
python3 src/query_memory.py "Summarize all my thoughts on the new feature"

# Action items
python3 src/query_memory.py "What action items did I mention?"

# People/speakers
python3 src/query_memory.py "What did John say in our meeting?"
```

## ⚙️ Configuration

Edit `cloud/gpu-worker/src/rag_config.py`:

```python
RAG_CONFIG = {
    # Retrieval
    'top_k_results': 5,          # Number of chunks to retrieve
    'min_similarity': 0.3,       # Minimum similarity threshold
    
    # Chunking
    'chunk_size': 500,           # Words per chunk
    'chunk_overlap': 50,         # Overlap between chunks
    
    # LLM
    'llm_model': 'llama3.2:3b',  # Ollama model to use
    'llm_temperature': 0.7,      # Creativity (0-1)
    'llm_max_tokens': 1000,      # Max response length
}
```

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| "Ollama not available" | `brew services start ollama` |
| "Collection not found" | Run `python3 src/indexer.py` |
| "No transcripts found" | Run `python3 scripts/sync-transcripts.py` |
| Slow queries | Reduce `--top-k` or use smaller model |
| Out of memory | Close other apps, use `llama3.2:1b` |

## 📊 File Locations

| What | Where |
|------|-------|
| Transcripts | `~/.rem/transcripts/` |
| Vector DB | `~/.rem/chroma/` |
| Sync metadata | `~/.rem/sync_metadata.json` |
| Scripts | `cloud/gpu-worker/scripts/` |
| Source code | `cloud/gpu-worker/src/` |

## 🔄 Daily Workflow

```bash
# Morning: Sync new transcripts
cd cloud/gpu-worker && source venv/bin/activate
python3 scripts/sync-transcripts.py
python3 src/indexer.py

# Throughout day: Query as needed
python3 src/query_memory.py --interactive

# Or keep worker running for auto-indexing
python3 src/worker.py
```

## 💡 Pro Tips

1. **Use interactive mode** for multiple queries
2. **Keep worker running** for auto-indexing
3. **Sync regularly** to get new transcripts
4. **Use specific questions** for better results
5. **Check sources** to verify information
6. **Try different phrasings** if results aren't good

## 🎓 Learning More

- Full setup guide: `docs/RAG_SETUP_GUIDE.md`
- Technical design: `docs/RAG_SYSTEM_DESIGN.md`
- Configuration: `cloud/gpu-worker/src/rag_config.py`

## 🆘 Help

```bash
# Get help for any command
python3 scripts/sync-transcripts.py --help
python3 src/indexer.py --help
python3 src/query_memory.py --help

# Interactive help
python3 src/query_memory.py --interactive
💭 Your question: help
```

