#!/usr/bin/env python3
"""
REM Transcription Worker Lambda
Processes SQS messages, transcribes audio with Whisper, and stores results.
"""

import os
import json
import tempfile
import logging
from datetime import datetime
from decimal import Decimal
from typing import Dict, List, Optional, Any

import boto3
import torch
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients (initialized once, reused across invocations)
s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

# Configuration from environment
RAW_AUDIO_BUCKET = os.getenv('RAW_AUDIO_BUCKET')
TRANSCRIPTS_BUCKET = os.getenv('TRANSCRIPTS_BUCKET')
DYNAMODB_TABLE = os.getenv('DYNAMODB_TABLE')
WHISPER_MODEL = os.getenv('WHISPER_MODEL', 'base')
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
HUGGINGFACE_TOKEN = os.getenv('HUGGINGFACE_TOKEN')

# Determine device (CUDA for NVIDIA, MPS for Mac, CPU otherwise)
DEVICE = "cuda" if torch.cuda.is_available() else "mps" if torch.backends.mps.is_available() else "cpu"
logger.info(f"Using device: {DEVICE}")

# Lazy-loaded heavy dependencies (loaded once per container lifecycle)
whisper_model = None
openai_client = None
diarization_pipeline = None


def get_whisper_model():
    """Lazy-load Whisper model (expensive operation)."""
    global whisper_model
    if whisper_model is None:
        logger.info(f"Loading Whisper model: {WHISPER_MODEL} on {DEVICE}")
        import whisper
        whisper_model = whisper.load_model(WHISPER_MODEL, device=DEVICE, download_root='/tmp/whisper-models')
        logger.info("Whisper model loaded")
    return whisper_model


def get_openai_client():
    """Lazy-load OpenAI client."""
    global openai_client
    if openai_client is None and OPENAI_API_KEY:
        from openai import OpenAI
        openai_client = OpenAI(api_key=OPENAI_API_KEY)
        logger.info("OpenAI client initialized")
    return openai_client


def get_diarization_pipeline():
    """Lazy-load speaker diarization pipeline."""
    global diarization_pipeline
    if diarization_pipeline is None and HUGGINGFACE_TOKEN:
        try:
            from pyannote.audio import Pipeline
            diarization_pipeline = Pipeline.from_pretrained(
                "pyannote/speaker-diarization-3.1",
                use_auth_token=HUGGINGFACE_TOKEN,
                cache_dir='/tmp/pyannote-models'
            )
            diarization_pipeline.to(torch.device(DEVICE))
            logger.info(f"Diarization pipeline loaded on {DEVICE}")
        except Exception as e:
            logger.warning(f"Failed to load diarization pipeline: {e}")
            diarization_pipeline = False  # Mark as attempted
    return diarization_pipeline if diarization_pipeline is not False else None


def download_audio_from_s3(bucket: str, key: str, local_path: str) -> bool:
    """Download audio file from S3 to local path."""
    try:
        logger.info(f"Downloading s3://{bucket}/{key} to {local_path}")
        s3_client.download_file(bucket, key, local_path)
        logger.info(f"Download successful")
        return True
    except ClientError as e:
        logger.error(f"Failed to download from S3: {e}")
        return False


def transcribe_audio(audio_path: str) -> Optional[Dict[str, Any]]:
    """Transcribe audio file using Whisper."""
    try:
        model = get_whisper_model()
        logger.info(f"Starting transcription of {audio_path}")
        
        segments, info = model.transcribe(
            audio_path,
            beam_size=5,
            vad_filter=True,
            vad_parameters=dict(min_silence_duration_ms=500)
        )
        
        # Convert segments to list
        segment_list = []
        for segment in segments:
            segment_list.append({
                'id': segment.id,
                'start': round(segment.start, 2),
                'end': round(segment.end, 2),
                'text': segment.text.strip()
            })
        
        full_text = ' '.join([s['text'] for s in segment_list])
        
        logger.info(f"Transcription complete: {len(segment_list)} segments, "
                   f"{info.duration:.2f}s duration, language: {info.language}")
        
        return {
            'segments': segment_list,
            'full_text': full_text,
            'language': info.language,
            'duration_seconds': round(info.duration, 2),
            'whisper_model': WHISPER_MODEL
        }
    except Exception as e:
        logger.error(f"Transcription failed: {e}")
        return None


def generate_embedding(text: str) -> Optional[List[float]]:
    """Generate embedding for text using OpenAI."""
    client = get_openai_client()
    if not client:
        return None

    try:
        response = client.embeddings.create(
            model="text-embedding-3-small",
            input=text[:8000]
        )
        return response.data[0].embedding
    except Exception as e:
        logger.error(f"Failed to generate embedding: {e}")
        return None


def generate_summary(text: str) -> Optional[str]:
    """Generate AI summary using OpenAI."""
    client = get_openai_client()
    if not client:
        return None

    try:
        response = client.chat.completions.create(
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
        return response.choices[0].message.content.strip()
    except Exception as e:
        logger.error(f"Failed to generate summary: {e}")
        return None


def extract_topics(text: str) -> Optional[List[str]]:
    """Extract topics using OpenAI."""
    client = get_openai_client()
    if not client:
        return None

    try:
        response = client.chat.completions.create(
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
        return topics
    except Exception as e:
        logger.error(f"Failed to extract topics: {e}")
        return None


def perform_speaker_diarization(audio_path: str) -> Optional[List[Dict[str, Any]]]:
    """Perform speaker diarization."""
    pipeline = get_diarization_pipeline()
    if not pipeline:
        return None

    try:
        logger.info(f"Performing speaker diarization on {audio_path}")
        diarization = pipeline(audio_path)

        speaker_segments = []
        for turn, _, speaker in diarization.itertracks(yield_label=True):
            speaker_segments.append({
                'start': round(turn.start, 2),
                'end': round(turn.end, 2),
                'speaker': speaker
            })

        unique_speakers = set(seg['speaker'] for seg in speaker_segments)
        logger.info(f"Detected {len(unique_speakers)} speakers")
        return speaker_segments
    except Exception as e:
        logger.error(f"Failed to perform diarization: {e}")
        return None


def assign_speakers_to_transcript(
    transcript_segments: List[Dict[str, Any]],
    speaker_segments: Optional[List[Dict[str, Any]]]
) -> List[Dict[str, Any]]:
    """Assign speaker labels to transcript segments."""
    if not speaker_segments:
        return transcript_segments

    for segment in transcript_segments:
        segment_mid = (segment['start'] + segment['end']) / 2

        # Find speaker at midpoint
        speaker = None
        for spk_seg in speaker_segments:
            if spk_seg['start'] <= segment_mid <= spk_seg['end']:
                speaker = spk_seg['speaker']
                break

        # If no exact match, find closest
        if not speaker:
            min_distance = float('inf')
            for spk_seg in speaker_segments:
                overlap_start = max(segment['start'], spk_seg['start'])
                overlap_end = min(segment['end'], spk_seg['end'])

                if overlap_start < overlap_end:
                    speaker = spk_seg['speaker']
                    break
                else:
                    distance = min(
                        abs(segment['start'] - spk_seg['end']),
                        abs(segment['end'] - spk_seg['start'])
                    )
                    if distance < min_distance:
                        min_distance = distance
                        speaker = spk_seg['speaker']

        segment['speaker'] = speaker if speaker else 'SPEAKER_00'

    return transcript_segments


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

        update_expr = 'SET #status = :status, transcriptS3Key = :s3key, #lang = :lang, durationSeconds = :dur, updatedAt = :updated'
        expr_attr_names = {'#status': 'status', '#lang': 'language'}
        expr_attr_values = {
            ':status': status,
            ':s3key': transcript_s3_key,
            ':lang': language,
            ':dur': Decimal(str(duration_seconds)),
            ':updated': datetime.utcnow().isoformat() + 'Z'
        }

        # Add optional fields
        if embedding:
            update_expr += ', embedding = :embedding'
            expr_attr_values[':embedding'] = embedding

        if summary:
            update_expr += ', summary = :summary'
            expr_attr_values[':summary'] = summary

        if topics:
            update_expr += ', topics = :topics'
            expr_attr_values[':topics'] = topics

        table.update_item(
            Key={'PK': user_id, 'SK': recording_id},
            UpdateExpression=update_expr,
            ExpressionAttributeNames=expr_attr_names,
            ExpressionAttributeValues=expr_attr_values
        )

        logger.info("DynamoDB record updated successfully")
        return True
    except ClientError as e:
        logger.error(f"Failed to update DynamoDB: {e}")
        return False


def process_transcription_job(message_body: Dict[str, Any]) -> bool:
    """Process a single transcription job."""
    try:
        bucket = message_body['bucket']
        key = message_body['key']
        user_id = message_body['userId']
        recording_id = message_body['recordingId']
        device_id = message_body['deviceId']

        logger.info(f"Processing recording: {recording_id}")

        # Download audio to /tmp
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False, dir='/tmp') as tmp_file:
            tmp_path = tmp_file.name

        try:
            if not download_audio_from_s3(bucket, key, tmp_path):
                return False

            # Transcribe
            transcript_result = transcribe_audio(tmp_path)
            if not transcript_result:
                return False

            full_text = transcript_result['full_text']

            # Speaker diarization
            logger.info("Performing speaker diarization...")
            speaker_segments = perform_speaker_diarization(tmp_path)
            segments_with_speakers = assign_speakers_to_transcript(
                transcript_result['segments'],
                speaker_segments
            )

            # AI enhancements
            logger.info("Generating AI enhancements...")
            embedding = generate_embedding(full_text)
            summary = generate_summary(full_text)
            topics = extract_topics(full_text)

            # Generate embeddings for segments
            segments_with_embeddings = []
            for segment in segments_with_speakers:
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

            # Add AI enhancements
            if embedding:
                transcript_data['embedding'] = embedding
            if summary:
                transcript_data['summary'] = summary
            if topics:
                transcript_data['topics'] = topics
            if speaker_segments:
                unique_speakers = list(set(seg['speaker'] for seg in segments_with_embeddings if 'speaker' in seg))
                transcript_data['speakers'] = unique_speakers
                transcript_data['speakerCount'] = len(unique_speakers)

            # Upload transcript
            transcript_s3_key = f"transcripts/{user_id}/{device_id}/{recording_id}.json"
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

            logger.info(f"Successfully processed recording: {recording_id}")
            return True

        finally:
            # Clean up temp file
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)

    except Exception as e:
        logger.error(f"Error processing job: {e}", exc_info=True)
        return False


def handler(event, context):
    """Lambda handler for SQS-triggered transcription."""
    logger.info(f"Received event with {len(event.get('Records', []))} records")

    for record in event.get('Records', []):
        try:
            message_body = json.loads(record['body'])
            success = process_transcription_job(message_body)

            if not success:
                # Raise exception to return message to queue
                raise Exception(f"Failed to process job: {message_body.get('recordingId')}")

        except Exception as e:
            logger.error(f"Error processing record: {e}", exc_info=True)
            # Re-raise to trigger SQS retry
            raise

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Processing complete'})
    }
