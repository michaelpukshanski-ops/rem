#!/usr/bin/env python3
"""
REM GPU Worker - Whisper Transcription Service

Polls SQS for transcription jobs, downloads audio from S3,
transcribes using Whisper, and stores results back to S3 and DynamoDB.
"""

import os
import sys
import json
import time
import tempfile
import logging
from datetime import datetime
from decimal import Decimal
from typing import Dict, List, Optional, Any
from pathlib import Path

import boto3
from botocore.exceptions import ClientError
from faster_whisper import WhisperModel
from dotenv import load_dotenv
from openai import OpenAI

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=getattr(logging, os.getenv('LOG_LEVEL', 'INFO')),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('rem-worker')

# AWS clients
s3_client = boto3.client('s3', region_name=os.getenv('AWS_REGION', 'us-east-1'))
sqs_client = boto3.client('sqs', region_name=os.getenv('AWS_REGION', 'us-east-1'))
dynamodb = boto3.resource('dynamodb', region_name=os.getenv('AWS_REGION', 'us-east-1'))

# OpenAI client
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
openai_client = OpenAI(api_key=OPENAI_API_KEY) if OPENAI_API_KEY else None

# Configuration
SQS_QUEUE_URL = os.getenv('SQS_QUEUE_URL')
RAW_AUDIO_BUCKET = os.getenv('RAW_AUDIO_BUCKET')
TRANSCRIPTS_BUCKET = os.getenv('TRANSCRIPTS_BUCKET')
DYNAMODB_TABLE = os.getenv('DYNAMODB_TABLE')
WHISPER_MODEL = os.getenv('WHISPER_MODEL', 'base')
WHISPER_DEVICE = os.getenv('WHISPER_DEVICE', 'cuda')
WHISPER_COMPUTE_TYPE = os.getenv('WHISPER_COMPUTE_TYPE', 'float16')
POLL_INTERVAL = int(os.getenv('POLL_INTERVAL', '5'))
MAX_MESSAGES = int(os.getenv('MAX_MESSAGES', '1'))
VISIBILITY_TIMEOUT = int(os.getenv('VISIBILITY_TIMEOUT', '900'))

# Validate configuration
required_vars = [
    'SQS_QUEUE_URL', 'RAW_AUDIO_BUCKET', 'TRANSCRIPTS_BUCKET', 'DYNAMODB_TABLE'
]
missing_vars = [var for var in required_vars if not os.getenv(var)]
if missing_vars:
    logger.error(f"Missing required environment variables: {', '.join(missing_vars)}")
    sys.exit(1)

# Initialize Whisper model
logger.info(f"Loading Whisper model: {WHISPER_MODEL} on {WHISPER_DEVICE}")
try:
    whisper_model = WhisperModel(
        WHISPER_MODEL,
        device=WHISPER_DEVICE,
        compute_type=WHISPER_COMPUTE_TYPE
    )
    logger.info("Whisper model loaded successfully")
except Exception as e:
    logger.error(f"Failed to load Whisper model: {e}")
    sys.exit(1)


def download_audio_from_s3(bucket: str, key: str, local_path: str) -> bool:
    """Download audio file from S3 to local path."""
    try:
        logger.info(f"Downloading s3://{bucket}/{key}")
        s3_client.download_file(bucket, key, local_path)
        logger.info(f"Downloaded to {local_path}")
        return True
    except ClientError as e:
        logger.error(f"Failed to download from S3: {e}")
        return False


def transcribe_audio(audio_path: str) -> Optional[Dict[str, Any]]:
    """Transcribe audio file using Whisper."""
    try:
        logger.info(f"Transcribing {audio_path}")
        start_time = time.time()
        
        segments, info = whisper_model.transcribe(
            audio_path,
            beam_size=5,
            vad_filter=True,  # Voice activity detection
            vad_parameters=dict(min_silence_duration_ms=500)
        )
        
        # Convert segments to list
        segment_list = []
        full_text_parts = []
        
        for segment in segments:
            segment_dict = {
                'id': segment.id,
                'start': round(segment.start, 2),
                'end': round(segment.end, 2),
                'text': segment.text.strip()
            }
            segment_list.append(segment_dict)
            full_text_parts.append(segment.text.strip())
        
        duration = time.time() - start_time
        
        result = {
            'language': info.language,
            'language_probability': round(info.language_probability, 4),
            'duration_seconds': round(info.duration, 2),
            'segments': segment_list,
            'full_text': ' '.join(full_text_parts),
            'transcription_time': round(duration, 2),
            'whisper_model': WHISPER_MODEL
        }
        
        logger.info(f"Transcription complete in {duration:.2f}s")
        logger.info(f"Detected language: {info.language} ({info.language_probability:.2%})")
        logger.info(f"Found {len(segment_list)} segments")

        return result
    except Exception as e:
        logger.error(f"Transcription failed: {e}")
        return None


def generate_embedding(text: str) -> Optional[List[float]]:
    """Generate embedding for text using OpenAI."""
    if not openai_client:
        logger.warning("OpenAI client not configured, skipping embedding generation")
        return None

    try:
        logger.info(f"Generating embedding for text ({len(text)} chars)")
        response = openai_client.embeddings.create(
            model="text-embedding-3-small",
            input=text[:8000]  # Limit to ~8k chars to stay within token limits
        )
        embedding = response.data[0].embedding
        logger.info(f"Generated embedding with {len(embedding)} dimensions")
        return embedding
    except Exception as e:
        logger.error(f"Failed to generate embedding: {e}")
        return None


def generate_summary(text: str) -> Optional[str]:
    """Generate AI summary of transcript using OpenAI."""
    if not openai_client:
        logger.warning("OpenAI client not configured, skipping summary generation")
        return None

    try:
        logger.info(f"Generating summary for text ({len(text)} chars)")
        response = openai_client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {
                    "role": "system",
                    "content": "You are a helpful assistant that summarizes voice recordings. "
                               "Create a concise 2-3 sentence summary of the key points."
                },
                {
                    "role": "user",
                    "content": f"Summarize this transcript:\n\n{text[:4000]}"
                }
            ],
            max_tokens=150,
            temperature=0.3
        )
        summary = response.choices[0].message.content.strip()
        logger.info(f"Generated summary: {summary[:100]}...")
        return summary
    except Exception as e:
        logger.error(f"Failed to generate summary: {e}")
        return None


def extract_topics(text: str) -> Optional[List[str]]:
    """Extract topics from transcript using OpenAI."""
    if not openai_client:
        logger.warning("OpenAI client not configured, skipping topic extraction")
        return None

    try:
        logger.info(f"Extracting topics from text ({len(text)} chars)")
        response = openai_client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {
                    "role": "system",
                    "content": "You are a helpful assistant that extracts key topics from voice recordings. "
                               "Return ONLY a comma-separated list of 3-5 single-word or short-phrase topics. "
                               "No explanations, just the topics."
                },
                {
                    "role": "user",
                    "content": f"Extract topics from this transcript:\n\n{text[:4000]}"
                }
            ],
            max_tokens=50,
            temperature=0.3
        )
        topics_str = response.choices[0].message.content.strip()
        topics = [t.strip().lower() for t in topics_str.split(',')]
        logger.info(f"Extracted topics: {topics}")
        return topics
    except Exception as e:
        logger.error(f"Failed to extract topics: {e}")
        return None


def upload_transcript_to_s3(transcript_data: Dict[str, Any], s3_key: str) -> bool:
    """Upload transcript JSON to S3."""
    try:
        logger.info(f"Uploading transcript to s3://{TRANSCRIPTS_BUCKET}/{s3_key}")
        
        s3_client.put_object(
            Bucket=TRANSCRIPTS_BUCKET,
            Key=s3_key,
            Body=json.dumps(transcript_data, indent=2),
            ContentType='application/json'
        )
        
        # Also upload plain text version
        txt_key = s3_key.replace('.json', '.txt')
        s3_client.put_object(
            Bucket=TRANSCRIPTS_BUCKET,
            Key=txt_key,
            Body=transcript_data['fullText'],
            ContentType='text/plain'
        )
        
        logger.info("Transcript uploaded successfully")
        return True
    except ClientError as e:
        logger.error(f"Failed to upload transcript: {e}")
        return False


def update_dynamodb_record(
    user_id: str,
    recording_id: str,
    transcript_s3_key: str,
    language: str,
    duration_seconds: float,
    embedding: Optional[List[float]] = None,
    summary: Optional[str] = None,
    topics: Optional[List[str]] = None,
    status: str = 'TRANSCRIBED'
) -> bool:
    """Update DynamoDB record with transcription results."""
    try:
        table = dynamodb.Table(DYNAMODB_TABLE)

        # Build update expression dynamically
        update_parts = [
            '#status = :status',
            'transcriptS3Key = :key',
            '#language = :lang',
            'durationSeconds = :dur',
            'updatedAt = :now'
        ]

        attr_names = {
            '#status': 'status',
            '#language': 'language'
        }

        attr_values = {
            ':status': status,
            ':key': transcript_s3_key,
            ':lang': language,
            ':dur': Decimal(str(duration_seconds)),
            ':now': datetime.utcnow().isoformat() + 'Z'
        }

        # Add optional fields
        if embedding:
            update_parts.append('embedding = :embedding')
            attr_values[':embedding'] = embedding

        if summary:
            update_parts.append('summary = :summary')
            attr_values[':summary'] = summary

        if topics:
            update_parts.append('topics = :topics')
            attr_values[':topics'] = topics

        update_expression = 'SET ' + ', '.join(update_parts)

        table.update_item(
            Key={
                'PK': user_id,
                'SK': recording_id
            },
            UpdateExpression=update_expression,
            ExpressionAttributeNames=attr_names,
            ExpressionAttributeValues=attr_values
        )

        logger.info(f"DynamoDB record updated: {recording_id}")
        return True
    except ClientError as e:
        logger.error(f"Failed to update DynamoDB: {e}")
        return False


def process_message(message: Dict[str, Any]) -> bool:
    """Process a single SQS message."""
    try:
        body = json.loads(message['Body'])
        receipt_handle = message['ReceiptHandle']
        
        recording_id = body['recordingId']
        bucket = body['bucket']
        key = body['key']
        user_id = body['userId']
        device_id = body['deviceId']
        started_at = body['startedAt']
        ended_at = body['endedAt']
        
        logger.info(f"Processing recording: {recording_id}")
        logger.info(f"Device: {device_id}, Time: {started_at}")
        
        # Create temporary file for audio
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp_file:
            tmp_path = tmp_file.name
        
        try:
            # Download audio
            if not download_audio_from_s3(bucket, key, tmp_path):
                return False
            
            # Transcribe
            transcript_result = transcribe_audio(tmp_path)
            if not transcript_result:
                return False

            full_text = transcript_result['full_text']

            # Generate AI enhancements (embeddings, summary, topics)
            logger.info("Generating AI enhancements...")
            embedding = generate_embedding(full_text)
            summary = generate_summary(full_text)
            topics = extract_topics(full_text)

            # Generate embeddings for each segment
            segments_with_embeddings = []
            for segment in transcript_result['segments']:
                segment_embedding = generate_embedding(segment['text'])
                segment_with_embedding = segment.copy()
                if segment_embedding:
                    segment_with_embedding['embedding'] = segment_embedding
                segments_with_embeddings.append(segment_with_embedding)

            # Prepare transcript data
            transcript_data = {
                'recordingId': recording_id,
                'userId': user_id,
                'deviceId': device_id,
                'language': transcript_result['language'],
                'segments': segments_with_embeddings,
                'fullText': full_text,
                'durationSeconds': transcript_result['duration_seconds'],
                'transcribedAt': datetime.utcnow().isoformat() + 'Z',
                'whisperModel': transcript_result['whisper_model']
            }

            # Add AI enhancements to transcript data
            if embedding:
                transcript_data['embedding'] = embedding
            if summary:
                transcript_data['summary'] = summary
            if topics:
                transcript_data['topics'] = topics

            # Generate S3 key for transcript
            transcript_s3_key = f"transcripts/{user_id}/{device_id}/{recording_id}.json"

            # Upload transcript
            if not upload_transcript_to_s3(transcript_data, transcript_s3_key):
                return False

            # Update DynamoDB
            if not update_dynamodb_record(
                user_id,
                recording_id,
                transcript_s3_key,
                transcript_result['language'],
                transcript_result['duration_seconds'],
                embedding,
                summary,
                topics
            ):
                return False
            
            # Delete message from queue
            sqs_client.delete_message(
                QueueUrl=SQS_QUEUE_URL,
                ReceiptHandle=receipt_handle
            )
            
            logger.info(f"Successfully processed recording: {recording_id}")
            return True
            
        finally:
            # Clean up temporary file
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
    
    except Exception as e:
        logger.error(f"Error processing message: {e}", exc_info=True)
        return False


def poll_and_process():
    """Main worker loop - poll SQS and process messages."""
    logger.info("Starting REM GPU Worker")
    logger.info(f"Queue: {SQS_QUEUE_URL}")
    logger.info(f"Model: {WHISPER_MODEL} on {WHISPER_DEVICE}")
    
    while True:
        try:
            # Poll SQS
            response = sqs_client.receive_message(
                QueueUrl=SQS_QUEUE_URL,
                MaxNumberOfMessages=MAX_MESSAGES,
                WaitTimeSeconds=20,  # Long polling
                VisibilityTimeout=VISIBILITY_TIMEOUT
            )
            
            messages = response.get('Messages', [])
            
            if not messages:
                logger.debug("No messages in queue")
                time.sleep(POLL_INTERVAL)
                continue
            
            logger.info(f"Received {len(messages)} message(s)")
            
            for message in messages:
                process_message(message)
        
        except KeyboardInterrupt:
            logger.info("Shutting down worker...")
            break
        except Exception as e:
            logger.error(f"Error in main loop: {e}", exc_info=True)
            time.sleep(POLL_INTERVAL)


if __name__ == '__main__':
    poll_and_process()
