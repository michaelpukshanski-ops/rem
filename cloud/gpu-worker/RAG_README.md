# 🧠 REM Local RAG System

**Query your voice transcriptions using natural language - 100% local, 100% free!**

Ask questions like:
- "What did I say about AWS deployment?"
- "When did I mention the project deadline?"
- "Summarize all my thoughts on the new feature"

Get AI-powered answers with source citations, all running on your Mac Mini M4.

## ✨ Features

- 🔍 **Semantic Search** - Find by meaning, not just keywords
- 💬 **Natural Language** - Ask questions in plain English
- 🤖 **Local LLM** - Llama 3.2 runs on your Mac (no cloud!)
- 📚 **Source Citations** - See which recordings answers came from
- ⚡ **Fast** - Optimized for Apple Silicon M4
- 💰 **Free** - Zero API costs, zero cloud fees
- 🔐 **Private** - Your data never leaves your machine

## 🚀 Quick Start

```bash
# 1. One-time setup (~10 minutes)
./scripts/setup-rag-system.sh

# 2. Sync your transcripts from S3
cd cloud/gpu-worker && source venv/bin/activate
python3 scripts/sync-transcripts.py

# 3. Index them for search
python3 src/indexer.py

# 4. Start asking questions!
python3 src/query_memory.py "What did I say about AWS?"

# Or use interactive mode
python3 src/query_memory.py --interactive
```

## 📋 What You Need

- Mac Mini M4 (or any Apple Silicon Mac)
- macOS 12.0+
- 10GB free disk space
- Homebrew installed

## 🎯 How It Works

```
Your Voice → Transcription → S3 Storage
                                ↓
                         Local Sync
                                ↓
                    Embedding Generation
                                ↓
                    ChromaDB Vector Store
                                ↓
            Natural Language Query → Semantic Search
                                ↓
                    Retrieved Context → Local LLM
                                ↓
                    Answer with Sources!
```

## 💡 Example Queries

```bash
# Find specific information
python3 src/query_memory.py "What did I decide about the database?"

# Time-based queries
python3 src/query_memory.py "What did I discuss last week?"

# Summarization
python3 src/query_memory.py "Summarize my thoughts on the project"

# Action items
python3 src/query_memory.py "What action items did I mention?"

# Interactive mode for multiple questions
python3 src/query_memory.py --interactive
```

## 📚 Documentation

- **[Setup Guide](../../docs/RAG_SETUP_GUIDE.md)** - Detailed installation and usage
- **[Quick Reference](../../docs/RAG_QUICK_REFERENCE.md)** - Common commands and tips
- **[System Design](../../docs/RAG_SYSTEM_DESIGN.md)** - Technical architecture

## 🔧 Components

### Scripts
- `scripts/sync-transcripts.py` - Download transcripts from S3
- `src/indexer.py` - Create embeddings and index
- `src/query_memory.py` - Query interface

### Configuration
- `src/rag_config.py` - System configuration
- `requirements-rag.txt` - Python dependencies

### Storage
- `~/.rem/transcripts/` - Local transcript cache
- `~/.rem/chroma/` - Vector database
- `~/.rem/sync_metadata.json` - Sync state

## 🔄 Keeping Updated

### Manual Sync
```bash
# Run periodically to get new transcripts
python3 scripts/sync-transcripts.py
python3 src/indexer.py
```

### Automatic Sync
The GPU worker auto-indexes new transcripts! Just keep it running:
```bash
python3 src/worker.py
```

## 💰 Cost Breakdown

| Component | Cost |
|-----------|------|
| Ollama (LLM) | **$0** - Free & open source |
| ChromaDB | **$0** - Free & open source |
| Embeddings | **$0** - Free & open source |
| S3 Download | **~$0.001** - One-time, pennies |
| **Total** | **$0/month** ✅ |

Compare to:
- OpenAI GPT-4: ~$0.03 per 1K tokens
- Pinecone Vector DB: $70/month minimum

## 📊 Performance

On Mac Mini M4:
- **Sync**: ~100 transcripts/minute
- **Indexing**: ~50 transcripts/minute
- **Query**: ~1-2 seconds
- **Memory**: ~1-2GB RAM

## 🔐 Privacy

- ✅ Everything runs locally
- ✅ No data sent to cloud AI services
- ✅ Transcripts stay on your machine
- ✅ Open source components

## 🆘 Troubleshooting

```bash
# Ollama not running?
brew services start ollama

# Collection not found?
python3 src/indexer.py

# No transcripts?
python3 scripts/sync-transcripts.py

# Need help?
python3 src/query_memory.py --help
```

## 🎓 Tips

1. Use **interactive mode** for multiple queries
2. Keep **worker running** for auto-indexing
3. **Sync regularly** to get new transcripts
4. Use **specific questions** for better results
5. **Check sources** to verify information

## 🚀 Advanced Usage

```bash
# Re-index everything
python3 src/indexer.py --reindex

# Get more results
python3 src/query_memory.py "question" --top-k 10

# Search only (no LLM)
python3 src/query_memory.py "search term" --search-only

# Verbose logging
python3 src/query_memory.py "question" --verbose
```

## 🤝 Contributing

This is part of the REM (Recording & Memory) system. See main README for more info.

## 📄 License

Same as REM project.

---

**Built with:**
- [Ollama](https://ollama.ai/) - Local LLM runtime
- [ChromaDB](https://www.trychroma.com/) - Vector database
- [Sentence Transformers](https://www.sbert.net/) - Embeddings
- [Llama 3.2](https://ai.meta.com/llama/) - Language model

**Enjoy your local AI memory system! 🧠**

