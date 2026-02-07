#!/usr/bin/env python3
"""
REM Memory Query Interface
Query your transcribed memories using natural language.
"""

import sys
import argparse
import logging
from typing import List, Dict, Optional
from datetime import datetime

import chromadb
from chromadb.config import Settings
from sentence_transformers import SentenceTransformer
import ollama

from rag_config import RAG_CONFIG, SYSTEM_PROMPTS, ensure_directories

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('query-memory')


class MemoryQuery:
    """Handles querying of indexed transcripts."""
    
    def __init__(self):
        """Initialize the query system."""
        ensure_directories()
        
        logger.info("Initializing query system...")
        
        # Initialize embedding model
        logger.info(f"Loading embedding model: {RAG_CONFIG['embedding_model']}")
        self.embedding_model = SentenceTransformer(RAG_CONFIG['embedding_model'])
        
        # Initialize ChromaDB
        logger.info(f"Connecting to ChromaDB at {RAG_CONFIG['chroma_dir']}")
        self.chroma_client = chromadb.PersistentClient(
            path=str(RAG_CONFIG['chroma_dir']),
            settings=Settings(anonymized_telemetry=False)
        )
        
        # Get collection
        try:
            self.collection = self.chroma_client.get_collection(
                name=RAG_CONFIG['collection_name']
            )
            logger.info(f"Collection loaded: {self.collection.count()} chunks available")
        except Exception as e:
            logger.error(f"Collection not found: {e}")
            logger.error("Run indexer.py first to create the index")
            sys.exit(1)
        
        # Check Ollama
        try:
            ollama.list()
            logger.info(f"Ollama connected, using model: {RAG_CONFIG['llm_model']}")
        except Exception as e:
            logger.error(f"Ollama not available: {e}")
            logger.error("Make sure Ollama is running: brew services start ollama")
            sys.exit(1)
    
    def search(self, query: str, top_k: int = None) -> List[Dict]:
        """
        Search for relevant transcript chunks.
        
        Args:
            query: Natural language query
            top_k: Number of results to return (default from config)
            
        Returns:
            List of relevant chunks with metadata
        """
        if top_k is None:
            top_k = RAG_CONFIG['top_k_results']
        
        logger.info(f"Searching for: '{query}'")
        
        # Generate query embedding
        query_embedding = self.embedding_model.encode(
            query,
            convert_to_numpy=True
        )
        
        # Search ChromaDB
        results = self.collection.query(
            query_embeddings=[query_embedding.tolist()],
            n_results=top_k,
            include=['documents', 'metadatas', 'distances']
        )
        
        # Format results
        chunks = []
        for i in range(len(results['ids'][0])):
            chunk = {
                'id': results['ids'][0][i],
                'text': results['documents'][0][i],
                'metadata': results['metadatas'][0][i],
                'distance': results['distances'][0][i],
                'similarity': 1 - results['distances'][0][i]  # Convert distance to similarity
            }
            
            # Filter by minimum similarity
            if chunk['similarity'] >= RAG_CONFIG['min_similarity']:
                chunks.append(chunk)
        
        logger.info(f"Found {len(chunks)} relevant chunk(s)")
        return chunks
    
    def format_context(self, chunks: List[Dict]) -> str:
        """Format retrieved chunks into context for LLM."""
        if not chunks:
            return "No relevant information found in transcripts."
        
        context_parts = []
        for i, chunk in enumerate(chunks, 1):
            metadata = chunk['metadata']
            
            # Format timestamp
            started_at = metadata.get('startedAt', 'Unknown date')
            if started_at != 'Unknown date':
                try:
                    dt = datetime.fromisoformat(started_at.replace('Z', '+00:00'))
                    started_at = dt.strftime('%Y-%m-%d %H:%M')
                except:
                    pass
            
            # Format chunk info
            chunk_info = f"[Recording {i}]\n"
            chunk_info += f"Date: {started_at}\n"
            chunk_info += f"Recording ID: {metadata.get('recordingId', 'Unknown')}\n"
            chunk_info += f"Device: {metadata.get('deviceId', 'Unknown')}\n"
            chunk_info += f"Time in recording: {metadata.get('start_time', '0')}s - {metadata.get('end_time', '0')}s\n"
            
            if 'topics' in metadata and metadata['topics']:
                chunk_info += f"Topics: {metadata['topics']}\n"
            
            chunk_info += f"\nTranscript:\n{chunk['text']}\n"
            
            context_parts.append(chunk_info)
        
        return "\n" + "="*80 + "\n".join(context_parts)
    
    def query(self, question: str, show_sources: bool = True) -> str:
        """
        Query the memory system with a natural language question.
        
        Args:
            question: Natural language question
            show_sources: Whether to show source citations
            
        Returns:
            Answer from LLM
        """
        # Search for relevant chunks
        chunks = self.search(question)
        
        if not chunks:
            return "I couldn't find any relevant information in your transcripts to answer that question."
        
        # Format context
        context = self.format_context(chunks)
        
        # Build prompt
        prompt = f"""Based on the following transcript excerpts from voice recordings, please answer the question.

{context}

Question: {question}

Answer:"""
        
        # Query LLM
        logger.info("Generating answer with LLM...")
        
        try:
            response = ollama.chat(
                model=RAG_CONFIG['llm_model'],
                messages=[
                    {'role': 'system', 'content': SYSTEM_PROMPTS['query']},
                    {'role': 'user', 'content': prompt}
                ],
                options={
                    'temperature': RAG_CONFIG['llm_temperature'],
                    'num_predict': RAG_CONFIG['llm_max_tokens']
                }
            )
            
            answer = response['message']['content']
            
            # Add sources if requested
            if show_sources:
                answer += "\n\n" + "─" * 80 + "\n"
                answer += f"📚 Sources: {len(chunks)} recording(s)\n"
                for i, chunk in enumerate(chunks, 1):
                    metadata = chunk['metadata']
                    answer += f"  {i}. Recording {metadata.get('recordingId', 'Unknown')[:8]}... "
                    answer += f"({metadata.get('startedAt', 'Unknown date')[:10]})\n"

            return answer

        except Exception as e:
            logger.error(f"Failed to generate answer: {e}")
            return f"Error generating answer: {e}"

    def interactive_mode(self):
        """Run in interactive mode for multiple queries."""
        print("\n" + "="*80)
        print("🧠 REM Memory Query - Interactive Mode")
        print("="*80)
        print(f"📊 Index contains {self.collection.count()} chunks from your transcripts")
        print("\nType your questions below. Type 'exit' or 'quit' to stop.")
        print("Type 'help' for tips on asking good questions.")
        print("="*80 + "\n")

        while True:
            try:
                question = input("\n💭 Your question: ").strip()

                if not question:
                    continue

                if question.lower() in ['exit', 'quit', 'q']:
                    print("\n👋 Goodbye!")
                    break

                if question.lower() == 'help':
                    self.show_help()
                    continue

                print("\n🔍 Searching and generating answer...\n")
                answer = self.query(question)
                print(f"\n💡 Answer:\n{answer}\n")

            except KeyboardInterrupt:
                print("\n\n👋 Goodbye!")
                break
            except Exception as e:
                logger.error(f"Error: {e}")
                print(f"\n❌ Error: {e}\n")

    def show_help(self):
        """Show help for asking good questions."""
        print("\n" + "─"*80)
        print("📖 Tips for asking good questions:")
        print("─"*80)
        print("\n✅ Good questions:")
        print("  • What did I say about the AWS deployment?")
        print("  • When did I mention the project deadline?")
        print("  • Find all discussions about the budget")
        print("  • What decisions did I make about the database?")
        print("  • Summarize my thoughts on the new feature")
        print("\n❌ Questions that won't work well:")
        print("  • What's the weather? (not in your transcripts)")
        print("  • Calculate 2+2 (not a memory query)")
        print("\n💡 The system searches your voice recordings and transcripts,")
        print("   so ask about things you've actually talked about!")
        print("─"*80)


def main():
    parser = argparse.ArgumentParser(
        description='Query your transcribed memories using natural language',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Ask a single question
  python3 query_memory.py "What did I say about AWS?"

  # Interactive mode
  python3 query_memory.py --interactive

  # Search only (no LLM answer)
  python3 query_memory.py "project deadline" --search-only
        """
    )

    parser.add_argument('question', nargs='?', help='Question to ask')
    parser.add_argument('--interactive', '-i', action='store_true',
                       help='Run in interactive mode')
    parser.add_argument('--search-only', action='store_true',
                       help='Only search, don\'t generate LLM answer')
    parser.add_argument('--top-k', type=int, default=None,
                       help=f'Number of results to retrieve (default: {RAG_CONFIG["top_k_results"]})')
    parser.add_argument('--no-sources', action='store_true',
                       help='Don\'t show source citations')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Enable verbose logging')

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    # Initialize query system
    query_system = MemoryQuery()

    # Interactive mode
    if args.interactive:
        query_system.interactive_mode()
        return

    # Single question mode
    if not args.question:
        parser.print_help()
        print("\n❌ Error: Please provide a question or use --interactive mode")
        sys.exit(1)

    if args.search_only:
        # Search only mode
        chunks = query_system.search(args.question, top_k=args.top_k)

        if not chunks:
            print("\n❌ No relevant information found.")
            return

        print(f"\n✅ Found {len(chunks)} relevant chunk(s):\n")
        for i, chunk in enumerate(chunks, 1):
            metadata = chunk['metadata']
            print(f"[{i}] Recording: {metadata.get('recordingId', 'Unknown')}")
            print(f"    Date: {metadata.get('startedAt', 'Unknown')}")
            print(f"    Similarity: {chunk['similarity']:.2%}")
            print(f"    Text: {chunk['text'][:200]}...")
            print()
    else:
        # Full query mode with LLM
        answer = query_system.query(args.question, show_sources=not args.no_sources)
        print(f"\n💡 Answer:\n{answer}\n")


if __name__ == '__main__':
    main()

