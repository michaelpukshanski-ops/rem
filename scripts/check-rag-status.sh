#!/bin/bash

# REM RAG System - Status Check Script
# This script checks if the RAG system is properly set up

set -e

echo "🔍 REM RAG System - Status Check"
echo "================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check 1: Ollama
echo "1️⃣  Checking Ollama..."
if command -v ollama &> /dev/null; then
    echo -e "${GREEN}✅ Ollama installed${NC}"
    
    if ollama list | grep -q "llama3.2:3b"; then
        echo -e "${GREEN}✅ Llama 3.2 3B model downloaded${NC}"
    else
        echo -e "${YELLOW}⚠️  Llama 3.2 3B model NOT downloaded${NC}"
        echo "   Run: ollama pull llama3.2:3b"
    fi
else
    echo -e "${RED}❌ Ollama NOT installed${NC}"
    echo "   Run: brew install ollama"
fi
echo ""

# Check 2: Python Dependencies
echo "2️⃣  Checking Python dependencies..."
python3 -c "
import sys
try:
    import chromadb
    print('${GREEN}✅ chromadb installed${NC}')
except ImportError:
    print('${RED}❌ chromadb NOT installed${NC}')
    print('   Run: pip3 install -r cloud/gpu-worker/requirements-rag.txt')

try:
    import sentence_transformers
    print('${GREEN}✅ sentence-transformers installed${NC}')
except ImportError:
    print('${RED}❌ sentence-transformers NOT installed${NC}')
    print('   Run: pip3 install -r cloud/gpu-worker/requirements-rag.txt')

try:
    import ollama
    print('${GREEN}✅ ollama-python installed${NC}')
except ImportError:
    print('${RED}❌ ollama-python NOT installed${NC}')
    print('   Run: pip3 install -r cloud/gpu-worker/requirements-rag.txt')
"
echo ""

# Check 3: Directory Structure
echo "3️⃣  Checking directory structure..."
if [ -d "$HOME/.rem" ]; then
    echo -e "${GREEN}✅ ~/.rem directory exists${NC}"
else
    echo -e "${YELLOW}⚠️  ~/.rem directory does not exist${NC}"
    echo "   Will be created on first sync"
fi

if [ -d "$HOME/.rem/transcripts" ]; then
    TRANSCRIPT_COUNT=$(find "$HOME/.rem/transcripts" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$TRANSCRIPT_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✅ $TRANSCRIPT_COUNT transcript(s) synced${NC}"
    else
        echo -e "${YELLOW}⚠️  No transcripts synced yet${NC}"
        echo "   Run: python3 scripts/sync-transcripts.py"
    fi
else
    echo -e "${YELLOW}⚠️  No transcripts synced yet${NC}"
    echo "   Run: python3 scripts/sync-transcripts.py"
fi

if [ -d "$HOME/.rem/chroma" ]; then
    echo -e "${GREEN}✅ ChromaDB directory exists${NC}"
else
    echo -e "${YELLOW}⚠️  ChromaDB not initialized${NC}"
    echo "   Run: python3 src/indexer.py"
fi
echo ""

# Check 4: ChromaDB Index
echo "4️⃣  Checking ChromaDB index..."
python3 -c "
import sys
from pathlib import Path

try:
    import chromadb
    sys.path.insert(0, 'cloud/gpu-worker/src')
    from rag_config import RAG_CONFIG
    
    chroma_dir = Path(RAG_CONFIG['chroma_dir']).expanduser()
    
    if chroma_dir.exists():
        client = chromadb.PersistentClient(path=str(chroma_dir))
        collections = client.list_collections()
        
        if collections:
            for col in collections:
                count = col.count()
                if count > 0:
                    print(f'${GREEN}✅ {count} chunks indexed in ChromaDB${NC}')
                else:
                    print(f'${YELLOW}⚠️  ChromaDB collection exists but is empty${NC}')
                    print('   Run: python3 src/indexer.py')
        else:
            print('${YELLOW}⚠️  No ChromaDB collections found${NC}')
            print('   Run: python3 src/indexer.py')
    else:
        print('${YELLOW}⚠️  ChromaDB not initialized${NC}')
        print('   Run: python3 src/indexer.py')
except ImportError:
    print('${RED}❌ Cannot check ChromaDB (dependencies not installed)${NC}')
except Exception as e:
    print(f'${RED}❌ Error checking ChromaDB: {e}${NC}')
" 2>/dev/null || echo -e "${RED}❌ Cannot check ChromaDB${NC}"
echo ""

# Summary
echo "================================"
echo "📋 Summary"
echo "================================"
echo ""
echo "To set up the RAG system, run these commands in order:"
echo ""
echo "1. Install dependencies:"
echo "   pip3 install -r cloud/gpu-worker/requirements-rag.txt"
echo ""
echo "2. Install Ollama (if not installed):"
echo "   brew install ollama"
echo "   ollama pull llama3.2:3b"
echo ""
echo "3. Sync transcripts from S3:"
echo "   cd cloud/gpu-worker"
echo "   python3 scripts/sync-transcripts.py"
echo ""
echo "4. Index transcripts:"
echo "   python3 src/indexer.py"
echo ""
echo "5. Start querying:"
echo "   python3 src/query_memory.py --interactive"
echo ""
echo "Or run the automated setup script:"
echo "   ./scripts/setup-rag-system.sh"
echo ""

