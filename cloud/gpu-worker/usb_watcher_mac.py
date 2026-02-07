#!/usr/bin/env python3
"""
REM USB Watcher for macOS
Monitors for USB flash drive insertion, processes audio files, and uploads to S3.
Designed for Mac Mini with Apple Silicon GPU acceleration.
"""

import os
import sys
import time
import subprocess
import logging
from pathlib import Path
from typing import List, Optional
import shutil

import boto3
from botocore.exceptions import ClientError
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('usb-watcher')

# AWS Configuration
AWS_REGION = os.getenv('AWS_REGION', 'us-east-1')
RAW_AUDIO_BUCKET = os.getenv('RAW_AUDIO_BUCKET')
SQS_QUEUE_URL = os.getenv('SQS_QUEUE_URL')

# USB Configuration
USB_MOUNT_BASE = '/Volumes'  # macOS mount point
AUDIO_EXTENSIONS = {'.wav', '.mp3', '.m4a', '.flac'}
PROCESSED_MARKER = '.rem_processed'

# AWS clients
s3_client = boto3.client('s3', region_name=AWS_REGION)
sqs_client = boto3.client('sqs', region_name=AWS_REGION)


def get_mounted_volumes() -> List[str]:
    """Get list of currently mounted volumes (excluding system volumes)."""
    volumes = []
    volumes_path = Path(USB_MOUNT_BASE)

    if not volumes_path.exists():
        return volumes

    for volume in volumes_path.iterdir():
        # Skip system volumes
        if volume.name in ['Macintosh HD', 'Preboot', 'Recovery', 'VM', 'Data']:
            continue
        if volume.is_dir():
            volumes.append(str(volume))

    return volumes


def find_audio_files(volume_path: str) -> List[Path]:
    """Find all audio files in the volume."""
    audio_files = []
    volume = Path(volume_path)

    for file_path in volume.rglob('*'):
        if file_path.is_file() and file_path.suffix.lower() in AUDIO_EXTENSIONS:
            # Skip if already processed
            marker = file_path.parent / f"{file_path.name}{PROCESSED_MARKER}"
            if not marker.exists():
                audio_files.append(file_path)

    return audio_files


def upload_to_s3(file_path: Path, user_id: str, device_id: str) -> Optional[str]:
    """Upload audio file to S3 and return S3 key."""
    try:
        # Generate S3 key
        timestamp = int(time.time() * 1000)
        s3_key = f"raw/{user_id}/{device_id}/{timestamp}{file_path.suffix}"

        logger.info(f"Uploading {file_path.name} to s3://{RAW_AUDIO_BUCKET}/{s3_key}")

        s3_client.upload_file(
            str(file_path),
            RAW_AUDIO_BUCKET,
            s3_key,
            ExtraArgs={'ContentType': f'audio/{file_path.suffix[1:]}'}
        )

        logger.info(f"Upload complete: {s3_key}")
        return s3_key

    except ClientError as e:
        logger.error(f"Failed to upload to S3: {e}")
        return None


def send_transcription_job(s3_key: str, user_id: str, device_id: str) -> bool:
    """Send transcription job to SQS."""
    try:
        message = {
            'recordingId': f"{device_id}_{int(time.time() * 1000)}",
            'bucket': RAW_AUDIO_BUCKET,
            'key': s3_key,
            'userId': user_id,
            'deviceId': device_id,
            'startedAt': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
            'endedAt': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
        }

        logger.info(f"Sending transcription job to SQS")

        sqs_client.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=str(message)
        )

        logger.info("Transcription job queued")
        return True

    except ClientError as e:
        logger.error(f"Failed to send SQS message: {e}")
        return False


def mark_as_processed(file_path: Path):
    """Mark file as processed to avoid re-uploading."""
    marker = file_path.parent / f"{file_path.name}{PROCESSED_MARKER}"
    marker.touch()
    logger.info(f"Marked as processed: {file_path.name}")


def process_volume(volume_path: str, user_id: str, device_id: str):
    """Process all audio files in a volume."""
    logger.info(f"Processing volume: {volume_path}")

    audio_files = find_audio_files(volume_path)

    if not audio_files:
        logger.info("No new audio files found")
        return

    logger.info(f"Found {len(audio_files)} audio file(s)")

    for file_path in audio_files:
        logger.info(f"Processing: {file_path.name}")

        # Upload to S3
        s3_key = upload_to_s3(file_path, user_id, device_id)

        if not s3_key:
            logger.error(f"Failed to upload {file_path.name}, skipping")
            continue

        # Send transcription job
        if send_transcription_job(s3_key, user_id, device_id):
            mark_as_processed(file_path)
        else:
            logger.error(f"Failed to queue transcription for {file_path.name}")


def watch_for_usb(user_id: str, device_id: str, poll_interval: int = 5, process_existing: bool = True):
    """Watch for USB drive insertion and process files."""
    logger.info("Starting USB watcher for Mac")
    logger.info(f"User ID: {user_id}, Device ID: {device_id}")
    logger.info(f"Monitoring: {USB_MOUNT_BASE}")

    known_volumes = set(get_mounted_volumes())
    logger.info(f"Currently mounted volumes: {len(known_volumes)}")

    # Process already-mounted volumes on startup
    if process_existing and known_volumes:
        logger.info("Processing existing volumes...")
        for volume in known_volumes:
            logger.info(f"Checking existing volume: {volume}")
            process_volume(volume, user_id, device_id)

    while True:
        try:
            current_volumes = set(get_mounted_volumes())

            # Check for new volumes
            new_volumes = current_volumes - known_volumes

            if new_volumes:
                for volume in new_volumes:
                    logger.info(f"New USB drive detected: {volume}")
                    process_volume(volume, user_id, device_id)

                known_volumes = current_volumes

            time.sleep(poll_interval)

        except KeyboardInterrupt:
            logger.info("Shutting down USB watcher...")
            break
        except Exception as e:
            logger.error(f"Error in watch loop: {e}", exc_info=True)
            time.sleep(poll_interval)


if __name__ == '__main__':
    # Get user ID and device ID from environment or command line
    user_id = os.getenv('REM_USER_ID') or (sys.argv[1] if len(sys.argv) > 1 else None)
    device_id = os.getenv('REM_DEVICE_ID') or (sys.argv[2] if len(sys.argv) > 2 else 'usb-uploader')

    if not user_id:
        logger.error("User ID required. Set REM_USER_ID env var or pass as first argument")
        sys.exit(1)

    if not RAW_AUDIO_BUCKET or not SQS_QUEUE_URL:
        logger.error("Missing AWS configuration. Check .env file")
        sys.exit(1)

    watch_for_usb(user_id, device_id)

