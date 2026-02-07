"""
REM RAG System Configuration
Centralized configuration for the local RAG system.
"""

from pathlib import Path
import os

# Base directory for REM data
REM_HOME = Path.home() / '.rem'

# RAG System Configuration
RAG_CONFIG = {
    # Storage paths
    'rem_home': REM_HOME,
    'transcripts_dir': REM_HOME / 'transcripts',
    'chroma_dir': REM_HOME / 'chroma',
    'metadata_file': REM_HOME / 'sync_metadata.json',
    'config_file': REM_HOME / 'config.json',
    
    # Embedding model
    'embedding_model': 'sentence-transformers/all-MiniLM-L6-v2',
    'embedding_dimension': 384,
    
    # LLM configuration
    'llm_model': 'llama3.2:3b',
    'llm_temperature': 0.7,
    'llm_max_tokens': 1000,
    
    # ChromaDB configuration
    'collection_name': 'rem_transcripts',
    'distance_metric': 'cosine',
    
    # Chunking configuration
    'chunk_size': 500,  # words per chunk
    'chunk_overlap': 50,  # words overlap between chunks
    
    # Query configuration
    'top_k_results': 5,  # Number of chunks to retrieve
    'min_similarity': 0.3,  # Minimum similarity score (0-1)
    
    # Performance
    'batch_size': 32,  # Batch size for embedding generation
    'device': 'mps' if os.getenv('WHISPER_DEVICE') == 'mps' else 'cpu',  # Use MPS if available
}

# Ensure directories exist
def ensure_directories():
    """Create necessary directories if they don't exist."""
    for key in ['rem_home', 'transcripts_dir', 'chroma_dir']:
        path = RAG_CONFIG[key]
        path.mkdir(parents=True, exist_ok=True)

# System prompts for LLM
SYSTEM_PROMPTS = {
    'query': """You are a helpful AI assistant that answers questions based on the user's past voice recordings and transcriptions.

Your task is to:
1. Analyze the provided transcript excerpts
2. Answer the user's question accurately based ONLY on the information in the transcripts
3. Include specific details like dates, times, speakers, and context when available
4. If the transcripts don't contain enough information to answer the question, say so clearly
5. Cite which recording(s) the information came from

Be concise but thorough. Use a friendly, conversational tone.""",

    'summarize': """You are a helpful AI assistant that summarizes voice recordings and transcriptions.

Your task is to:
1. Read the provided transcript
2. Create a clear, concise summary of the main points
3. Highlight key topics, decisions, and action items
4. Maintain the original context and meaning

Be objective and comprehensive."""
}

# Metadata fields to extract from transcripts
TRANSCRIPT_METADATA_FIELDS = [
    'recordingId',
    'userId', 
    'deviceId',
    'startedAt',
    'endedAt',
    'durationSeconds',
    'language',
    'whisperModel',
    'transcribedAt'
]

# Optional AI enhancement fields
AI_ENHANCEMENT_FIELDS = [
    'summary',
    'topics',
    'speakers'
]

