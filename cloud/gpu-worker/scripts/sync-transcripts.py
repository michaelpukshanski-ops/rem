#!/usr/bin/env python3
"""
REM Transcript Sync Script
Downloads transcripts from S3 to local cache for RAG system.
"""

import os
import sys
import json
import argparse
import logging
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional

import boto3
from botocore.exceptions import ClientError
from dotenv import load_dotenv

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))
from src.rag_config import RAG_CONFIG

# Load environment variables
env_path = Path(__file__).parent.parent / '.env'
load_dotenv(dotenv_path=env_path)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('transcript-sync')

# AWS Configuration
TRANSCRIPTS_BUCKET = os.getenv('TRANSCRIPTS_BUCKET')
AWS_REGION = os.getenv('AWS_REGION', 'us-east-1')

if not TRANSCRIPTS_BUCKET:
    logger.error("TRANSCRIPTS_BUCKET not set in .env file")
    sys.exit(1)

# Initialize S3 client
s3_client = boto3.client('s3', region_name=AWS_REGION)


def load_sync_metadata() -> Dict:
    """Load sync metadata from local cache."""
    metadata_file = RAG_CONFIG['metadata_file']
    if metadata_file.exists():
        with open(metadata_file, 'r') as f:
            return json.load(f)
    return {
        'last_sync': None,
        'synced_files': {},
        'total_files': 0
    }


def save_sync_metadata(metadata: Dict):
    """Save sync metadata to local cache."""
    metadata_file = RAG_CONFIG['metadata_file']
    metadata_file.parent.mkdir(parents=True, exist_ok=True)
    with open(metadata_file, 'w') as f:
        json.dump(metadata, f, indent=2)


def list_s3_transcripts() -> List[Dict]:
    """List all transcript files in S3."""
    logger.info(f"Listing transcripts in s3://{TRANSCRIPTS_BUCKET}/")
    transcripts = []
    
    try:
        paginator = s3_client.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=TRANSCRIPTS_BUCKET)
        
        for page in pages:
            if 'Contents' not in page:
                continue
                
            for obj in page['Contents']:
                key = obj['Key']
                if key.endswith('.json'):
                    transcripts.append({
                        'key': key,
                        'size': obj['Size'],
                        'last_modified': obj['LastModified'].isoformat(),
                        'etag': obj['ETag'].strip('"')
                    })
        
        logger.info(f"Found {len(transcripts)} transcript(s) in S3")
        return transcripts
        
    except ClientError as e:
        logger.error(f"Failed to list S3 objects: {e}")
        return []


def download_transcript(s3_key: str, local_path: Path) -> bool:
    """Download a single transcript from S3."""
    try:
        local_path.parent.mkdir(parents=True, exist_ok=True)
        
        logger.debug(f"Downloading {s3_key} to {local_path}")
        s3_client.download_file(TRANSCRIPTS_BUCKET, s3_key, str(local_path))
        
        return True
        
    except ClientError as e:
        logger.error(f"Failed to download {s3_key}: {e}")
        return False


def sync_transcripts(full_sync: bool = False) -> Dict:
    """
    Sync transcripts from S3 to local cache.
    
    Args:
        full_sync: If True, re-download all files. If False, only download new/updated files.
    
    Returns:
        Dict with sync statistics
    """
    logger.info("Starting transcript sync...")
    
    # Load existing metadata
    metadata = load_sync_metadata()
    synced_files = metadata.get('synced_files', {})
    
    # List S3 transcripts
    s3_transcripts = list_s3_transcripts()
    
    if not s3_transcripts:
        logger.warning("No transcripts found in S3")
        return {'downloaded': 0, 'skipped': 0, 'failed': 0}
    
    stats = {'downloaded': 0, 'skipped': 0, 'failed': 0}
    
    for transcript in s3_transcripts:
        s3_key = transcript['key']
        etag = transcript['etag']
        
        # Determine local path
        # S3 key format: transcripts/userId/deviceId/recordingId.json
        local_path = RAG_CONFIG['transcripts_dir'] / s3_key
        
        # Check if we need to download
        should_download = full_sync or \
                         s3_key not in synced_files or \
                         synced_files[s3_key].get('etag') != etag or \
                         not local_path.exists()
        
        if should_download:
            logger.info(f"Downloading: {s3_key}")
            if download_transcript(s3_key, local_path):
                synced_files[s3_key] = {
                    'etag': etag,
                    'last_modified': transcript['last_modified'],
                    'synced_at': datetime.utcnow().isoformat()
                }
                stats['downloaded'] += 1
            else:
                stats['failed'] += 1
        else:
            logger.debug(f"Skipping (already synced): {s3_key}")
            stats['skipped'] += 1
    
    # Update metadata
    metadata['synced_files'] = synced_files
    metadata['last_sync'] = datetime.utcnow().isoformat()
    metadata['total_files'] = len(synced_files)
    save_sync_metadata(metadata)
    
    return stats


def main():
    parser = argparse.ArgumentParser(description='Sync transcripts from S3 to local cache')
    parser.add_argument('--full-sync', action='store_true', 
                       help='Re-download all files (default: incremental sync)')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Enable verbose logging')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    logger.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    logger.info("REM Transcript Sync")
    logger.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    stats = sync_transcripts(full_sync=args.full_sync)
    
    logger.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    logger.info(f"✅ Sync complete!")
    logger.info(f"   Downloaded: {stats['downloaded']}")
    logger.info(f"   Skipped: {stats['skipped']}")
    logger.info(f"   Failed: {stats['failed']}")
    logger.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")


if __name__ == '__main__':
    main()

