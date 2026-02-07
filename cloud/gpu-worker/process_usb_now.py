#!/usr/bin/env python3
"""
Manual USB processor - processes all mounted USB drives immediately
Use this to manually trigger processing without waiting for new insertions
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Import from usb_watcher_mac
from usb_watcher_mac import (
    get_mounted_volumes,
    process_volume,
    logger,
    RAW_AUDIO_BUCKET,
    SQS_QUEUE_URL
)

def main():
    # Get user ID and device ID from environment or command line
    user_id = os.getenv('REM_USER_ID') or (sys.argv[1] if len(sys.argv) > 1 else None)
    device_id = os.getenv('REM_DEVICE_ID') or (sys.argv[2] if len(sys.argv) > 2 else 'usb-uploader')
    
    if not user_id:
        logger.error("User ID required. Set REM_USER_ID env var or pass as first argument")
        sys.exit(1)
    
    if not RAW_AUDIO_BUCKET or not SQS_QUEUE_URL:
        logger.error("Missing AWS configuration. Check .env file")
        sys.exit(1)
    
    logger.info("🔄 Manual USB Processing")
    logger.info(f"User ID: {user_id}, Device ID: {device_id}")
    logger.info("")
    
    # Get all mounted volumes
    volumes = get_mounted_volumes()
    
    if not volumes:
        logger.info("❌ No USB drives found")
        return
    
    logger.info(f"✅ Found {len(volumes)} USB drive(s)")
    logger.info("")
    
    # Process each volume
    for volume in volumes:
        logger.info(f"📁 Processing: {volume}")
        process_volume(volume, user_id, device_id)
        logger.info("")
    
    logger.info("✅ Done!")

if __name__ == '__main__':
    main()

