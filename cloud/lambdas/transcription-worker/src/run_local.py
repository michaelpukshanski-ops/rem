#!/usr/bin/env python3
"""
Local runner for REM Transcription Worker.
Polls SQS queue and processes messages using the local GPU (if available).
"""

import os
import time
import json
import logging
import sys
import subprocess
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Add current directory to path to allow imports
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

import boto3
from handler import process_transcription_job, DEVICE

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

def get_terraform_output(output_name):
    """Get output from Terraform state."""
    try:
        # Navigate to infra directory
        infra_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))), 'infra')

        result = subprocess.run(
            ['terraform', 'output', '-raw', output_name],
            cwd=infra_dir,
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to get Terraform output '{output_name}': {e.stderr}")
        return None
    except Exception as e:
        logger.error(f"Error running Terraform: {e}")
        return None

def get_aws_region():
    """Get AWS region from Terraform output or environment."""
    region = os.getenv('AWS_REGION')
    if region:
        return region

    # Try to get from deployment_summary
    summary = get_terraform_output('deployment_summary')
    if summary:
        try:
            # Parse the HCL-like output or JSON output depending on terraform version
            # Assuming it might be a string representation of a map
            import re
            match = re.search(r'region\s*=\s*"([^"]+)"', summary)
            if match:
                return match.group(1)
        except Exception:
            pass

    # Fallback to us-east-1 if not found
    return 'us-east-1'

# Infer configuration from Terraform if not set in environment
SQS_QUEUE_URL = os.getenv('SQS_QUEUE_URL') or get_terraform_output('sqs_queue_url')
RAW_AUDIO_BUCKET = os.getenv('RAW_AUDIO_BUCKET') or get_terraform_output('raw_audio_bucket_name')
TRANSCRIPTS_BUCKET = os.getenv('TRANSCRIPTS_BUCKET') or get_terraform_output('transcripts_bucket_name')
DYNAMODB_TABLE = os.getenv('DYNAMODB_TABLE') or get_terraform_output('dynamodb_table_name')
AWS_REGION = get_aws_region()

# Set environment variables for handler.py
if RAW_AUDIO_BUCKET: os.environ['RAW_AUDIO_BUCKET'] = RAW_AUDIO_BUCKET
if TRANSCRIPTS_BUCKET: os.environ['TRANSCRIPTS_BUCKET'] = TRANSCRIPTS_BUCKET
if DYNAMODB_TABLE: os.environ['DYNAMODB_TABLE'] = DYNAMODB_TABLE
if AWS_REGION: os.environ['AWS_REGION'] = AWS_REGION
# Also set AWS_DEFAULT_REGION for boto3
os.environ['AWS_DEFAULT_REGION'] = AWS_REGION

def poll_queue():
    """Poll SQS queue for new transcription jobs."""
    if not SQS_QUEUE_URL:
        logger.error("SQS_QUEUE_URL could not be determined.")
        logger.error("Please set it in .env or ensure Terraform state is accessible.")
        sys.exit(1)

    if not all([RAW_AUDIO_BUCKET, TRANSCRIPTS_BUCKET, DYNAMODB_TABLE]):
        logger.error("Missing required configuration.")
        logger.error(f"RAW_AUDIO_BUCKET: {RAW_AUDIO_BUCKET}")
        logger.error(f"TRANSCRIPTS_BUCKET: {TRANSCRIPTS_BUCKET}")
        logger.error(f"DYNAMODB_TABLE: {DYNAMODB_TABLE}")
        sys.exit(1)

    # Initialize boto3 client with region
    sqs = boto3.client('sqs', region_name=AWS_REGION)

    logger.info(f"🚀 Starting local worker on device: {DEVICE}")
    logger.info(f"🌍 Region: {AWS_REGION}")
    logger.info(f"📥 Polling queue: {SQS_QUEUE_URL}")
    logger.info(f"🪣  Raw Audio Bucket: {RAW_AUDIO_BUCKET}")
    logger.info(f"📝 Transcripts Bucket: {TRANSCRIPTS_BUCKET}")
    logger.info(f"📊 DynamoDB Table: {DYNAMODB_TABLE}")
    logger.info("Press Ctrl+C to stop")

    while True:
        try:
            # Long polling
            response = sqs.receive_message(
                QueueUrl=SQS_QUEUE_URL,
                MaxNumberOfMessages=1,
                WaitTimeSeconds=20,
                VisibilityTimeout=300  # 5 minutes visibility timeout
            )

            messages = response.get('Messages', [])

            if not messages:
                continue

            for message in messages:
                logger.info(f"📨 Received message: {message['MessageId']}")

                try:
                    body = json.loads(message['Body'])

                    # Process the job
                    start_time = time.time()
                    success = process_transcription_job(body)
                    duration = time.time() - start_time

                    if success:
                        logger.info(f"✅ Processing successful ({duration:.2f}s), deleting message")
                        sqs.delete_message(
                            QueueUrl=SQS_QUEUE_URL,
                            ReceiptHandle=message['ReceiptHandle']
                        )
                    else:
                        logger.error("❌ Processing failed, message will return to queue")

                except json.JSONDecodeError:
                    logger.error("Failed to decode message body")
                except Exception as e:
                    logger.error(f"Error processing message: {e}")

        except KeyboardInterrupt:
            logger.info("Stopping worker...")
            break
        except Exception as e:
            logger.error(f"Error in poll loop: {e}")
            time.sleep(5)

if __name__ == "__main__":
    poll_queue()
