#!/bin/bash
# Upload a long audio file to REM system by splitting into 5-minute chunks
# Usage: ./upload-audio-file.sh <audio_file_path> [device_id]
#
# Requirements: ffmpeg, curl, jq
# The file's creation time is used as the recording start time

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
CHUNK_DURATION_SEC=300  # 5 minutes
SAMPLE_RATE=16000
CHANNELS=1
REGION="${AWS_REGION:-us-east-1}"

# Check arguments
if [ -z "$1" ]; then
    echo -e "${RED}Error: Audio file path required${NC}"
    echo "Usage: $0 <audio_file_path> [device_id]"
    echo ""
    echo "Examples:"
    echo "  $0 /path/to/recording.mp3"
    echo "  $0 /path/to/recording.wav my-device-001"
    echo ""
    echo "Environment variables:"
    echo "  API_GATEWAY_URL - API Gateway ingest URL (or auto-detect from terraform)"
    echo "  API_KEY         - API key for authentication (or auto-detect from terraform)"
    exit 1
fi

AUDIO_FILE="$1"
DEVICE_ID="${2:-manual-upload}"

# Check if file exists
if [ ! -f "$AUDIO_FILE" ]; then
    echo -e "${RED}Error: File not found: $AUDIO_FILE${NC}"
    exit 1
fi

# Check dependencies
for cmd in ffmpeg ffprobe curl jq; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: $cmd is required but not installed${NC}"
        exit 1
    fi
done

echo "========================================="
echo "REM - Upload Audio File"
echo "========================================="
echo ""
echo -e "${CYAN}File: ${AUDIO_FILE}${NC}"
echo "Device ID: ${DEVICE_ID}"
echo ""

# Get API configuration from terraform if not set
if [ -z "$API_GATEWAY_URL" ] || [ -z "$API_KEY" ]; then
    echo "Getting API configuration from Terraform..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    INFRA_DIR="${SCRIPT_DIR}/../infra"
    
    if [ -d "$INFRA_DIR" ]; then
        cd "$INFRA_DIR"
        API_GATEWAY_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
        API_KEY=$(terraform output -raw api_key 2>/dev/null || echo "")
        cd - > /dev/null
    fi
fi

if [ -z "$API_GATEWAY_URL" ] || [ -z "$API_KEY" ]; then
    echo -e "${RED}Error: Could not determine API configuration${NC}"
    echo "Please set API_GATEWAY_URL and API_KEY environment variables"
    exit 1
fi

echo "API URL: ${API_GATEWAY_URL}"
echo ""

# Get file creation time (use modification time as fallback)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - use birth time if available, otherwise modification time
    FILE_TIMESTAMP=$(stat -f "%B" "$AUDIO_FILE" 2>/dev/null || stat -f "%m" "$AUDIO_FILE")
else
    # Linux - use modification time (birth time not always available)
    FILE_TIMESTAMP=$(stat -c "%Y" "$AUDIO_FILE")
fi

# Get audio duration
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO_FILE")
DURATION_INT=${DURATION%.*}

echo "File timestamp: $(date -r $FILE_TIMESTAMP '+%Y-%m-%d %H:%M:%S')"
echo "Audio duration: ${DURATION_INT} seconds ($(($DURATION_INT / 60)) minutes)"
echo ""

# Calculate number of chunks
NUM_CHUNKS=$(( ($DURATION_INT + $CHUNK_DURATION_SEC - 1) / $CHUNK_DURATION_SEC ))
echo "Will create ${NUM_CHUNKS} chunks of ${CHUNK_DURATION_SEC} seconds each"
echo ""

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "========================================="
echo "Step 1: Converting and splitting audio"
echo "========================================="

# Split audio into chunks (MP3 format for smaller size)
for ((i=0; i<NUM_CHUNKS; i++)); do
    START_SEC=$((i * CHUNK_DURATION_SEC))
    CHUNK_FILE="${TEMP_DIR}/chunk_${i}.mp3"

    echo -n "Creating chunk $((i+1))/${NUM_CHUNKS} (${START_SEC}s - $((START_SEC + CHUNK_DURATION_SEC))s)... "

    ffmpeg -y -i "$AUDIO_FILE" \
        -ss $START_SEC \
        -t $CHUNK_DURATION_SEC \
        -ar $SAMPLE_RATE \
        -ac $CHANNELS \
        -b:a 64k \
        "$CHUNK_FILE" \
        -loglevel error

    echo -e "${GREEN}OK${NC} ($(du -h "$CHUNK_FILE" | cut -f1))"
done

echo ""
echo "========================================="
echo "Step 2: Uploading chunks"
echo "========================================="

UPLOADED=0
FAILED=0

for ((i=0; i<NUM_CHUNKS; i++)); do
    CHUNK_FILE="${TEMP_DIR}/chunk_${i}.mp3"
    START_SEC=$((i * CHUNK_DURATION_SEC))
    END_SEC=$((START_SEC + CHUNK_DURATION_SEC))
    
    # Calculate timestamps
    CHUNK_START_TIMESTAMP=$((FILE_TIMESTAMP + START_SEC))
    CHUNK_END_TIMESTAMP=$((FILE_TIMESTAMP + END_SEC))
    
    # Convert to ISO 8601
    if [[ "$OSTYPE" == "darwin"* ]]; then
        STARTED_AT=$(date -u -r $CHUNK_START_TIMESTAMP '+%Y-%m-%dT%H:%M:%SZ')
        ENDED_AT=$(date -u -r $CHUNK_END_TIMESTAMP '+%Y-%m-%dT%H:%M:%SZ')
    else
        STARTED_AT=$(date -u -d "@$CHUNK_START_TIMESTAMP" '+%Y-%m-%dT%H:%M:%SZ')
        ENDED_AT=$(date -u -d "@$CHUNK_END_TIMESTAMP" '+%Y-%m-%dT%H:%M:%SZ')
    fi
    
    echo -n "Uploading chunk $((i+1))/${NUM_CHUNKS} (${STARTED_AT})... "
    
    # Upload via curl
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_GATEWAY_URL" \
        -H "x-api-key: $API_KEY" \
        -F "deviceId=$DEVICE_ID" \
        -F "startedAt=$STARTED_AT" \
        -F "endedAt=$ENDED_AT" \
        -F "file=@$CHUNK_FILE;type=audio/mpeg")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "201" ]; then
        RECORDING_ID=$(echo "$BODY" | jq -r '.recordingId // "unknown"')
        echo -e "${GREEN}OK${NC} (recordingId: ${RECORDING_ID})"
        ((UPLOADED++))
    else
        echo -e "${RED}FAILED${NC} (HTTP $HTTP_CODE)"
        echo "  Response: $BODY"
        ((FAILED++))
    fi
    
    # Small delay between uploads
    sleep 1
done

echo ""
echo "========================================="
echo "Summary"
echo "========================================="
echo -e "Uploaded: ${GREEN}${UPLOADED}${NC}"
echo -e "Failed:   ${RED}${FAILED}${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All chunks uploaded successfully!${NC}"
else
    echo -e "${YELLOW}⚠️  Some chunks failed to upload${NC}"
    exit 1
fi

