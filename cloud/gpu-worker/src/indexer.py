#!/usr/bin/env python3
"""
REM Transcript Indexer
Creates embeddings from transcripts and stores them in ChromaDB for semantic search.
"""

import os
import sys
import json
import argparse
import logging
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from datetime import datetime

import chromadb
from chromadb.config import Settings
from sentence_transformers import SentenceTransformer

from rag_config import RAG_CONFIG, TRANSCRIPT_METADATA_FIELDS, ensure_directories

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('indexer')


class TranscriptIndexer:
    """Handles indexing of transcripts into ChromaDB."""
    
    def __init__(self):
        """Initialize the indexer with embedding model and vector database."""
        ensure_directories()
        
        logger.info("Initializing indexer...")
        
        # Initialize embedding model
        logger.info(f"Loading embedding model: {RAG_CONFIG['embedding_model']}")
        self.embedding_model = SentenceTransformer(RAG_CONFIG['embedding_model'])
        
        # Initialize ChromaDB
        logger.info(f"Connecting to ChromaDB at {RAG_CONFIG['chroma_dir']}")
        self.chroma_client = chromadb.PersistentClient(
            path=str(RAG_CONFIG['chroma_dir']),
            settings=Settings(anonymized_telemetry=False)
        )
        
        # Get or create collection
        self.collection = self.chroma_client.get_or_create_collection(
            name=RAG_CONFIG['collection_name'],
            metadata={"hnsw:space": RAG_CONFIG['distance_metric']}
        )
        
        logger.info(f"Collection '{RAG_CONFIG['collection_name']}' ready")
        logger.info(f"Current collection size: {self.collection.count()} chunks")
    
    def chunk_transcript(self, transcript: Dict) -> List[Dict]:
        """
        Split transcript into semantic chunks.
        
        Args:
            transcript: Transcript JSON object
            
        Returns:
            List of chunks with text and metadata
        """
        chunks = []
        segments = transcript.get('segments', [])
        
        if not segments:
            logger.warning(f"No segments found in transcript {transcript.get('recordingId')}")
            return chunks
        
        # Combine segments into chunks based on word count
        current_chunk = []
        current_word_count = 0
        chunk_index = 0
        
        for segment in segments:
            text = segment.get('text', '').strip()
            if not text:
                continue
            
            words = text.split()
            word_count = len(words)
            
            # Add segment to current chunk
            current_chunk.append(segment)
            current_word_count += word_count
            
            # Check if chunk is large enough
            if current_word_count >= RAG_CONFIG['chunk_size']:
                # Create chunk
                chunk_text = ' '.join([s.get('text', '') for s in current_chunk])
                chunk_start = current_chunk[0].get('start', 0)
                chunk_end = current_chunk[-1].get('end', 0)
                
                chunks.append({
                    'text': chunk_text,
                    'chunk_index': chunk_index,
                    'start_time': chunk_start,
                    'end_time': chunk_end,
                    'word_count': current_word_count
                })
                
                # Start new chunk with overlap
                overlap_words = RAG_CONFIG['chunk_overlap']
                if overlap_words > 0 and len(current_chunk) > 1:
                    # Keep last segment for overlap
                    current_chunk = [current_chunk[-1]]
                    current_word_count = len(current_chunk[0].get('text', '').split())
                else:
                    current_chunk = []
                    current_word_count = 0
                
                chunk_index += 1
        
        # Add remaining segments as final chunk
        if current_chunk:
            chunk_text = ' '.join([s.get('text', '') for s in current_chunk])
            chunk_start = current_chunk[0].get('start', 0)
            chunk_end = current_chunk[-1].get('end', 0)
            
            chunks.append({
                'text': chunk_text,
                'chunk_index': chunk_index,
                'start_time': chunk_start,
                'end_time': chunk_end,
                'word_count': current_word_count
            })
        
        return chunks
    
    def extract_metadata(self, transcript: Dict, chunk: Dict) -> Dict:
        """Extract metadata from transcript and chunk."""
        metadata = {}
        
        # Extract transcript-level metadata
        for field in TRANSCRIPT_METADATA_FIELDS:
            if field in transcript:
                value = transcript[field]
                # Convert to string for ChromaDB compatibility
                metadata[field] = str(value) if value is not None else ''
        
        # Add chunk-level metadata
        metadata['chunk_index'] = str(chunk['chunk_index'])
        metadata['start_time'] = str(chunk['start_time'])
        metadata['end_time'] = str(chunk['end_time'])
        metadata['word_count'] = str(chunk['word_count'])
        
        # Add full text if available (for context)
        if 'fullText' in transcript:
            metadata['full_text_preview'] = transcript['fullText'][:200]
        
        # Add AI enhancements if available
        if 'summary' in transcript:
            metadata['summary'] = transcript['summary'][:500]
        if 'topics' in transcript and transcript['topics']:
            metadata['topics'] = ', '.join(transcript['topics'][:5])
        
        return metadata
    
    def index_transcript(self, transcript_path: Path) -> Tuple[int, int]:
        """
        Index a single transcript file.
        
        Args:
            transcript_path: Path to transcript JSON file
            
        Returns:
            Tuple of (chunks_added, chunks_skipped)
        """
        try:
            with open(transcript_path, 'r') as f:
                transcript = json.load(f)
            
            recording_id = transcript.get('recordingId')
            if not recording_id:
                logger.warning(f"No recordingId in {transcript_path}")
                return (0, 0)
            
            # Check if already indexed
            existing = self.collection.get(
                where={"recordingId": recording_id}
            )
            
            if existing['ids']:
                logger.debug(f"Already indexed: {recording_id}")
                return (0, len(existing['ids']))

            # Chunk the transcript
            chunks = self.chunk_transcript(transcript)

            if not chunks:
                logger.warning(f"No chunks created for {recording_id}")
                return (0, 0)

            logger.info(f"Indexing {recording_id}: {len(chunks)} chunk(s)")

            # Prepare data for ChromaDB
            ids = []
            texts = []
            metadatas = []

            for chunk in chunks:
                chunk_id = f"{recording_id}_chunk_{chunk['chunk_index']}"
                ids.append(chunk_id)
                texts.append(chunk['text'])
                metadatas.append(self.extract_metadata(transcript, chunk))

            # Generate embeddings
            logger.debug(f"Generating embeddings for {len(texts)} chunk(s)")
            embeddings = self.embedding_model.encode(
                texts,
                batch_size=RAG_CONFIG['batch_size'],
                show_progress_bar=False,
                convert_to_numpy=True
            )

            # Add to ChromaDB
            self.collection.add(
                ids=ids,
                embeddings=embeddings.tolist(),
                documents=texts,
                metadatas=metadatas
            )

            logger.info(f"✅ Indexed {recording_id}: {len(chunks)} chunk(s)")
            return (len(chunks), 0)

        except Exception as e:
            logger.error(f"Failed to index {transcript_path}: {e}")
            return (0, 0)

    def index_all_transcripts(self, reindex: bool = False) -> Dict:
        """
        Index all transcripts in the local cache.

        Args:
            reindex: If True, re-index all transcripts. If False, skip already indexed.

        Returns:
            Dict with indexing statistics
        """
        transcripts_dir = RAG_CONFIG['transcripts_dir']

        if not transcripts_dir.exists():
            logger.error(f"Transcripts directory not found: {transcripts_dir}")
            logger.error("Run sync-transcripts.py first to download transcripts")
            return {'indexed': 0, 'skipped': 0, 'failed': 0}

        # Find all transcript JSON files
        transcript_files = list(transcripts_dir.rglob('*.json'))

        if not transcript_files:
            logger.warning(f"No transcript files found in {transcripts_dir}")
            return {'indexed': 0, 'skipped': 0, 'failed': 0}

        logger.info(f"Found {len(transcript_files)} transcript file(s)")

        # Clear collection if reindexing
        if reindex:
            logger.warning("Reindexing: clearing existing collection")
            self.chroma_client.delete_collection(RAG_CONFIG['collection_name'])
            self.collection = self.chroma_client.create_collection(
                name=RAG_CONFIG['collection_name'],
                metadata={"hnsw:space": RAG_CONFIG['distance_metric']}
            )

        stats = {'indexed': 0, 'skipped': 0, 'failed': 0, 'total_chunks': 0}

        for i, transcript_file in enumerate(transcript_files, 1):
            logger.info(f"[{i}/{len(transcript_files)}] Processing {transcript_file.name}")

            chunks_added, chunks_skipped = self.index_transcript(transcript_file)

            if chunks_added > 0:
                stats['indexed'] += 1
                stats['total_chunks'] += chunks_added
            elif chunks_skipped > 0:
                stats['skipped'] += 1
            else:
                stats['failed'] += 1

        return stats


def main():
    parser = argparse.ArgumentParser(description='Index transcripts for RAG system')
    parser.add_argument('--reindex', action='store_true',
                       help='Re-index all transcripts (clears existing index)')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Enable verbose logging')
    parser.add_argument('--file', type=str,
                       help='Index a specific transcript file')

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    logger.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    logger.info("REM Transcript Indexer")
    logger.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    indexer = TranscriptIndexer()

    if args.file:
        # Index single file
        file_path = Path(args.file)
        if not file_path.exists():
            logger.error(f"File not found: {file_path}")
            sys.exit(1)

        chunks_added, chunks_skipped = indexer.index_transcript(file_path)
        logger.info(f"Chunks added: {chunks_added}, skipped: {chunks_skipped}")
    else:
        # Index all transcripts
        stats = indexer.index_all_transcripts(reindex=args.reindex)

        logger.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        logger.info(f"✅ Indexing complete!")
        logger.info(f"   Transcripts indexed: {stats['indexed']}")
        logger.info(f"   Total chunks: {stats['total_chunks']}")
        logger.info(f"   Skipped: {stats['skipped']}")
        logger.info(f"   Failed: {stats['failed']}")
        logger.info(f"   Collection size: {indexer.collection.count()} chunks")
        logger.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")


if __name__ == '__main__':
    main()

