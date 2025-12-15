#!/usr/bin/env python3
"""
Speaker Service - Voice profile management and speaker identification

Handles:
- Extracting voice embeddings from audio segments
- Matching speakers against known profiles
- Saving and updating speaker profiles in DynamoDB
"""

import os
import logging
from typing import Dict, List, Optional, Any, Tuple
from decimal import Decimal

import boto3
import numpy as np
from botocore.exceptions import ClientError

logger = logging.getLogger('rem-worker.speaker')

# AWS clients
dynamodb = boto3.resource('dynamodb', region_name=os.getenv('AWS_REGION', 'us-east-1'))
SPEAKERS_TABLE = os.getenv('SPEAKERS_TABLE', 'rem-speakers-dev')

# Embedding model (lazy loaded)
_embedding_model = None


def get_embedding_model():
    """Lazy load the speaker embedding model."""
    global _embedding_model
    if _embedding_model is None:
        try:
            from pyannote.audio import Model, Inference
            logger.info("Loading speaker embedding model...")
            _embedding_model = Inference(
                Model.from_pretrained(
                    "pyannote/embedding",
                    use_auth_token=os.getenv('HUGGINGFACE_TOKEN')
                ),
                window="whole"
            )
            logger.info("Speaker embedding model loaded successfully")
        except Exception as e:
            logger.error(f"Failed to load speaker embedding model: {e}")
            _embedding_model = None
    return _embedding_model


def extract_speaker_embedding(audio_path: str, start: float, end: float) -> Optional[List[float]]:
    """Extract voice embedding for a specific segment of audio."""
    model = get_embedding_model()
    if model is None:
        return None
    
    try:
        from pyannote.core import Segment
        segment = Segment(start, end)
        embedding = model.crop(audio_path, segment)
        return embedding.tolist()
    except Exception as e:
        logger.error(f"Failed to extract speaker embedding: {e}")
        return None


def cosine_similarity(a: List[float], b: List[float]) -> float:
    """Calculate cosine similarity between two embeddings."""
    a_np = np.array(a)
    b_np = np.array(b)
    return float(np.dot(a_np, b_np) / (np.linalg.norm(a_np) * np.linalg.norm(b_np)))


def get_user_speakers(user_id: str) -> List[Dict[str, Any]]:
    """Get all speaker profiles for a user."""
    try:
        table = dynamodb.Table(SPEAKERS_TABLE)
        response = table.query(
            KeyConditionExpression='userId = :uid',
            ExpressionAttributeValues={':uid': user_id}
        )
        speakers = response.get('Items', [])
        
        # Convert Decimal embeddings back to float
        for speaker in speakers:
            if 'embedding' in speaker:
                speaker['embedding'] = [float(x) for x in speaker['embedding']]
        
        return speakers
    except ClientError as e:
        logger.error(f"Failed to get speakers: {e}")
        return []


def save_speaker(
    user_id: str,
    speaker_id: str,
    name: Optional[str] = None,
    embedding: Optional[List[float]] = None,
    sample_count: int = 1
) -> bool:
    """Save or update a speaker profile."""
    try:
        table = dynamodb.Table(SPEAKERS_TABLE)
        
        item = {
            'userId': user_id,
            'speakerId': speaker_id,
            'name': name or speaker_id,
            'sampleCount': sample_count,
            'createdAt': boto3.dynamodb.conditions.Attr('createdAt').not_exists(),
        }
        
        if embedding:
            item['embedding'] = [Decimal(str(x)) for x in embedding]
        
        # Use update to handle both create and update
        update_parts = ['#name = :name', 'sampleCount = :count', 'updatedAt = :now']
        attr_names = {'#name': 'name'}
        attr_values = {
            ':name': name or speaker_id,
            ':count': sample_count,
            ':now': boto3.dynamodb.conditions.Attr('updatedAt').not_exists()
        }
        
        if embedding:
            update_parts.append('embedding = :emb')
            attr_values[':emb'] = [Decimal(str(x)) for x in embedding]
        
        from datetime import datetime
        attr_values[':now'] = datetime.utcnow().isoformat() + 'Z'
        
        table.update_item(
            Key={'userId': user_id, 'speakerId': speaker_id},
            UpdateExpression='SET ' + ', '.join(update_parts) + 
                           ', createdAt = if_not_exists(createdAt, :now)',
            ExpressionAttributeNames=attr_names,
            ExpressionAttributeValues=attr_values
        )
        
        logger.info(f"Saved speaker profile: {speaker_id} for user {user_id}")
        return True
    except ClientError as e:
        logger.error(f"Failed to save speaker: {e}")
        return False


def update_speaker_embedding(
    user_id: str,
    speaker_id: str,
    new_embedding: List[float],
    current_embedding: Optional[List[float]] = None,
    current_sample_count: int = 0
) -> bool:
    """Update speaker embedding with running average."""
    if current_embedding and current_sample_count > 0:
        # Calculate running average
        new_count = current_sample_count + 1
        avg_embedding = [
            (current_embedding[i] * current_sample_count + new_embedding[i]) / new_count
            for i in range(len(new_embedding))
        ]
    else:
        avg_embedding = new_embedding
        new_count = 1
    
    return save_speaker(user_id, speaker_id, embedding=avg_embedding, sample_count=new_count)


def match_speaker(
    user_id: str,
    embedding: List[float],
    threshold: float = 0.75
) -> Tuple[Optional[str], Optional[str], float]:
    """
    Match an embedding against known speakers.
    
    Returns:
        Tuple of (speaker_id, speaker_name, similarity_score)
        Returns (None, None, 0.0) if no match found above threshold
    """
    speakers = get_user_speakers(user_id)
    
    if not speakers:
        return None, None, 0.0
    
    best_match = None
    best_name = None
    best_score = 0.0
    
    for speaker in speakers:
        if 'embedding' not in speaker:
            continue
        
        similarity = cosine_similarity(embedding, speaker['embedding'])
        
        if similarity > best_score:
            best_score = similarity
            best_match = speaker['speakerId']
            best_name = speaker.get('name', speaker['speakerId'])
    
    if best_score >= threshold:
        logger.info(f"Matched speaker {best_name} with similarity {best_score:.3f}")
        return best_match, best_name, best_score
    
    logger.info(f"No speaker match found (best score: {best_score:.3f})")
    return None, None, best_score


def identify_speakers_in_recording(
    audio_path: str,
    user_id: str,
    speaker_segments: List[Dict[str, Any]],
    transcript_segments: List[Dict[str, Any]]
) -> Tuple[List[Dict[str, Any]], Dict[str, str]]:
    """
    Identify speakers in a recording and update profiles.
    
    Args:
        audio_path: Path to audio file
        user_id: User ID for speaker profiles
        speaker_segments: Diarization output with speaker labels
        transcript_segments: Transcript segments with speaker assignments
    
    Returns:
        Tuple of (updated_segments, speaker_mapping)
        speaker_mapping maps temporary IDs (SPEAKER_00) to persistent IDs/names
    """
    if not speaker_segments:
        return transcript_segments, {}
    
    # Get unique speakers from diarization
    unique_speakers = list(set(seg['speaker'] for seg in speaker_segments))
    logger.info(f"Identifying {len(unique_speakers)} speakers...")
    
    # Extract embedding for each speaker (use longest segment)
    speaker_embeddings = {}
    for speaker in unique_speakers:
        # Find longest segment for this speaker
        speaker_segs = [s for s in speaker_segments if s['speaker'] == speaker]
        if not speaker_segs:
            continue
        
        longest = max(speaker_segs, key=lambda s: s['end'] - s['start'])
        duration = longest['end'] - longest['start']
        
        # Only extract if segment is long enough (at least 2 seconds)
        if duration >= 2.0:
            embedding = extract_speaker_embedding(audio_path, longest['start'], longest['end'])
            if embedding:
                speaker_embeddings[speaker] = embedding
    
    # Match each speaker against known profiles
    speaker_mapping = {}  # Maps temp ID -> (persistent_id, name)
    
    for temp_id, embedding in speaker_embeddings.items():
        matched_id, matched_name, score = match_speaker(user_id, embedding)
        
        if matched_id:
            # Found a match - update the profile with new sample
            speaker_mapping[temp_id] = (matched_id, matched_name)
            
            # Get current speaker data for running average
            speakers = get_user_speakers(user_id)
            current = next((s for s in speakers if s['speakerId'] == matched_id), None)
            
            if current:
                update_speaker_embedding(
                    user_id, matched_id, embedding,
                    current.get('embedding'),
                    current.get('sampleCount', 0)
                )
        else:
            # New speaker - create profile with temp ID
            new_id = f"speaker_{len(get_user_speakers(user_id)) + 1}"
            save_speaker(user_id, new_id, name=None, embedding=embedding)
            speaker_mapping[temp_id] = (new_id, new_id)
    
    # Update transcript segments with persistent speaker IDs
    for segment in transcript_segments:
        temp_id = segment.get('speaker')
        if temp_id and temp_id in speaker_mapping:
            persistent_id, name = speaker_mapping[temp_id]
            segment['speakerId'] = persistent_id
            segment['speakerName'] = name
        else:
            # Keep original if no mapping
            segment['speakerId'] = temp_id
            segment['speakerName'] = temp_id
    
    # Convert mapping for return
    result_mapping = {k: v[1] for k, v in speaker_mapping.items()}
    
    return transcript_segments, result_mapping

