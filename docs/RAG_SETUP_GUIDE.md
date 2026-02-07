# REM Local RAG System - Setup Guide

## 🎯 What is This?

A local AI system that lets you query all your voice transcriptions using natural language. Ask questions like "What did I say about AWS?" and get answers with source citations - all running on your Mac Mini M4 with **zero cloud costs**.

## ✨ Features

- 🔍 **Semantic Search**: Find information by meaning, not just keywords
- 💬 **Natural Language Queries**: Ask questions in plain English
- 🤖 **Local LLM**: Llama 3.2 runs entirely on your Mac Mini
- 📚 **Source Citations**: See which recordings answers came from
- ⚡ **Fast**: Optimized for Apple Silicon M4
- 💰 **Free**: No API costs, no cloud fees

## 📋 Prerequisites

- Mac Mini M4 (or any Apple Silicon Mac)
- macOS 12.0 or later
- Homebrew installed
- Python 3.9 or later
- At least 10GB free disk space

## 🚀 Installation

### Step 1: Run the Setup Script

```bash
cd /Users/michaelminipc/repos/rem
chmod +x scripts/setup-rag-system.sh
./scripts/setup-rag-system.sh
```

This will:
- ✅ Install Ollama
- ✅ Download Llama 3.2 model (~2GB)
- ✅ Install Python dependencies
- ✅ Download embedding model (~80MB)
- ✅ Create local storage directories

**Time**: ~10-15 minutes (mostly downloading models)

### Step 2: Verify Installation

```bash
# Check Ollama is running
ollama list

# Should show:
# NAME              ID              SIZE      MODIFIED
# llama3.2:3b       ...             2.0 GB    ...
```

## 📥 Initial Data Sync

### Sync Transcripts from S3

```bash
cd cloud/gpu-worker
source venv/bin/activate
python3 scripts/sync-transcripts.py
```

**What it does:**
- Downloads all transcripts from S3 to `~/.rem/transcripts/`
- Only downloads new/updated files (incremental sync)
- Tracks sync state in `~/.rem/sync_metadata.json`

**Options:**
```bash
# Full sync (re-download everything)
python3 scripts/sync-transcripts.py --full-sync

# Verbose output
python3 scripts/sync-transcripts.py --verbose
```

### Index Transcripts

```bash
python3 src/indexer.py
```

**What it does:**
- Chunks transcripts into semantic segments
- Generates embeddings for each chunk
- Stores in ChromaDB vector database at `~/.rem/chroma/`

**Options:**
```bash
# Re-index everything (clears existing index)
python3 src/indexer.py --reindex

# Index a specific file
python3 src/indexer.py --file ~/.rem/transcripts/michael/usb-uploader/recording123.json

# Verbose output
python3 src/indexer.py --verbose
```

**Time**: ~1-2 minutes per 100 transcripts

## 💬 Querying Your Memories

### Single Question

```bash
python3 src/query_memory.py "What did I say about AWS?"
```

### Interactive Mode

```bash
python3 src/query_memory.py --interactive
```

Then ask multiple questions:
```
💭 Your question: What did I discuss about the project deadline?
💭 Your question: Find all mentions of the database
💭 Your question: exit
```

### Search Only (No LLM)

```bash
python3 src/query_memory.py "AWS deployment" --search-only
```

Shows matching transcript chunks without generating an answer.

### Advanced Options

```bash
# Get more results
python3 src/query_memory.py "AWS" --top-k 10

# Hide source citations
python3 src/query_memory.py "AWS" --no-sources

# Verbose logging
python3 src/query_memory.py "AWS" --verbose
```

## 🔄 Keeping Data in Sync

### Manual Sync

Run periodically to get new transcripts:

```bash
cd cloud/gpu-worker
source venv/bin/activate
python3 scripts/sync-transcripts.py
python3 src/indexer.py
```

### Automatic Sync

The GPU worker automatically indexes new transcripts as they're created! Just keep the worker running:

```bash
cd cloud/gpu-worker
source venv/bin/activate
python3 src/worker.py
```

When a new recording is transcribed, it's automatically added to the RAG system.

## 📊 Storage Locations

```
~/.rem/
├── transcripts/          # Downloaded transcripts from S3
│   └── michael/
│       └── usb-uploader/
│           └── *.json
├── chroma/              # Vector database
│   └── [ChromaDB files]
├── sync_metadata.json   # Sync state tracking
└── config.json          # User configuration (future)
```

## 🔧 Troubleshooting

### "Ollama not available"

```bash
# Start Ollama service
brew services start ollama

# Check status
brew services list | grep ollama
```

### "Collection not found"

You need to index transcripts first:

```bash
python3 src/indexer.py
```

### "No transcripts found"

Sync from S3 first:

```bash
python3 scripts/sync-transcripts.py
```

### Slow queries

- First query is slower (loading models)
- Subsequent queries are faster (~1-2 seconds)
- Consider using a smaller `--top-k` value

### Out of memory

- Close other applications
- Reduce `chunk_size` in `src/rag_config.py`
- Use a smaller LLM model: `ollama pull llama3.2:1b`

## 🎓 Tips for Good Questions

### ✅ Good Questions

- "What did I say about the AWS deployment?"
- "When did I mention the project deadline?"
- "Find all discussions about the budget"
- "What decisions did I make about the database?"
- "Summarize my thoughts on the new feature"

### ❌ Won't Work

- "What's the weather?" (not in your transcripts)
- "Calculate 2+2" (not a memory query)
- Questions about things you never talked about

## 📈 Performance

On Mac Mini M4:

- **Sync**: ~100 transcripts/minute
- **Indexing**: ~50 transcripts/minute  
- **Query**: ~1-2 seconds end-to-end
- **Memory**: ~1-2GB RAM during queries

## 🔐 Privacy

- ✅ Everything runs locally on your Mac Mini
- ✅ No data sent to cloud AI services
- ✅ Transcripts stay on your machine
- ✅ Ollama and ChromaDB are open source

## 🆘 Getting Help

Type `help` in interactive mode for tips:

```bash
python3 src/query_memory.py --interactive
💭 Your question: help
```

## 🎉 Next Steps

1. ✅ Sync your transcripts
2. ✅ Index them
3. ✅ Start asking questions!
4. 🔄 Keep the worker running for auto-indexing

Enjoy your local AI memory system! 🧠

