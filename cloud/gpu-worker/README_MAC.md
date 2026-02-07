# REM GPU Worker - macOS Setup (Mac Mini with Apple Silicon)

This guide is for running the REM transcription worker on a Mac Mini with Apple Silicon (M1/M2/M3).

## Features

1. **USB Auto-Detection**: Automatically detects when you plug in a USB flash drive
2. **Auto-Upload**: Uploads audio files from USB to S3
3. **GPU Transcription**: Uses Mac's Neural Engine for fast Whisper transcription
4. **Auto-Start**: Runs automatically on boot via LaunchAgent

## Quick Setup

```bash
cd cloud/gpu-worker
chmod +x setup_mac.sh
./setup_mac.sh
```

The setup script will:
- Install Homebrew (if needed)
- Install Python 3.11 and FFmpeg
- Create Python virtual environment
- Install all dependencies
- Create `.env` configuration file
- Setup LaunchAgent for auto-start

## Configuration

Edit `.env` file with your settings:

```bash
# Get AWS configuration from Terraform
cd ../../infra
terraform output

# Copy values to .env
nano ../cloud/gpu-worker/.env
```

Required settings:
- `AWS_REGION`: Your AWS region (us-east-1)
- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
- `RAW_AUDIO_BUCKET`: S3 bucket for raw audio
- `TRANSCRIPTS_BUCKET`: S3 bucket for transcripts
- `SQS_QUEUE_URL`: SQS queue URL
- `DYNAMODB_TABLE`: DynamoDB table name
- `REM_USER_ID`: Your Clerk user ID
- `OPENAI_API_KEY`: OpenAI API key (optional, for AI features)

## Apple Silicon GPU Configuration

Mac Mini M4 uses Apple's GPU via Metal Performance Shaders (MPS). Configuration in `.env`:

**Option 1: Explicit GPU (Recommended for M4)**
```bash
WHISPER_MODEL=base           # or small, medium, large-v3
WHISPER_DEVICE=mps           # Use Metal Performance Shaders (Apple GPU)
WHISPER_COMPUTE_TYPE=float16 # Best for Apple Silicon GPU
```

**Option 2: Auto (CPU + Neural Engine)**
```bash
WHISPER_MODEL=base
WHISPER_DEVICE=cpu           # Auto-uses Neural Engine
WHISPER_COMPUTE_TYPE=int8    # Optimized for efficiency
```

The M4's GPU is powerful - use `mps` device for best performance!

### Performance on Apple Silicon

Typical transcription times for 5-minute audio:

| Model | M1 | M2 | M3 | M4 (GPU) |
|-------|----|----|-----|----------|
| tiny  | ~20s | ~15s | ~12s | ~8s |
| base  | ~30s | ~25s | ~20s | ~15s |
| small | ~60s | ~45s | ~35s | ~25s |
| medium| ~120s | ~90s | ~70s | ~50s |
| large-v3 | ~240s | ~180s | ~140s | ~100s |

**M4 with MPS (GPU) is ~40% faster than M3!**

## USB Watcher

### How It Works

1. Monitors `/Volumes` for new USB drives
2. Scans for audio files (.wav, .mp3, .m4a, .flac)
3. Uploads to S3 raw audio bucket
4. Sends transcription job to SQS
5. Marks files as processed (won't re-upload)

### Start USB Watcher

**Auto-start on boot:**
```bash
launchctl load ~/Library/LaunchAgents/com.rem.usbwatcher.plist
```

**Manual start:**
```bash
cd cloud/gpu-worker
source venv/bin/activate
python3 usb_watcher_mac.py
```

### Stop USB Watcher

```bash
launchctl unload ~/Library/LaunchAgents/com.rem.usbwatcher.plist
```

### View Logs

```bash
# USB watcher logs
tail -f ~/Library/Logs/rem-usb-watcher.log

# Error logs
tail -f ~/Library/Logs/rem-usb-watcher-error.log
```

## GPU Transcription Worker

The worker processes transcription jobs from SQS queue.

### Start Worker

```bash
cd cloud/gpu-worker
source venv/bin/activate
python3 src/worker.py
```

### Run as Background Service

Create `~/Library/LaunchAgents/com.rem.worker.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.rem.worker</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/YOUR_USERNAME/WebstormProjects/rem/cloud/gpu-worker/venv/bin/python3</string>
        <string>/Users/YOUR_USERNAME/WebstormProjects/rem/cloud/gpu-worker/src/worker.py</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Users/YOUR_USERNAME/WebstormProjects/rem/cloud/gpu-worker</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/Users/YOUR_USERNAME/Library/Logs/rem-worker.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/YOUR_USERNAME/Library/Logs/rem-worker-error.log</string>
</dict>
</plist>
```

Then:
```bash
launchctl load ~/Library/LaunchAgents/com.rem.worker.plist
```

## Testing

### Test USB Detection

1. Start USB watcher manually
2. Plug in USB drive with audio files
3. Check logs for upload progress

### Test Transcription

```bash
source venv/bin/activate
python3 -c "
from faster_whisper import WhisperModel
model = WhisperModel('base', device='cpu', compute_type='int8')
segments, info = model.transcribe('test.wav')
for segment in segments:
    print(segment.text)
"
```

## Troubleshooting

### USB Not Detected

Check if volume is mounted:
```bash
ls /Volumes
```

### Slow Transcription

- Use smaller model (`tiny` or `base`)
- Check Activity Monitor for CPU usage
- Ensure no other heavy processes running

### Import Errors

```bash
source venv/bin/activate
pip install --upgrade -r requirements.txt
```

## Workflow

1. **Record on ESP32** → Saves to USB flash drive
2. **Plug USB into Mac Mini** → USB watcher detects
3. **Auto-upload to S3** → Files uploaded to raw bucket
4. **Transcription job queued** → SQS message sent
5. **Worker processes** → Whisper transcribes on Mac GPU
6. **Results stored** → Transcript in S3 + DynamoDB updated
7. **Search in dashboard** → Query memories via web app


