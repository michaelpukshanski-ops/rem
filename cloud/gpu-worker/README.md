# REM GPU Worker - Whisper Transcription Service

Python worker that polls SQS for transcription jobs, downloads audio from S3, transcribes using Whisper, and stores results.

## Prerequisites

### Hardware
- **GPU-enabled machine** (recommended for faster transcription)
  - NVIDIA GPU with CUDA support
  - At least 4GB VRAM for base model, 8GB+ for larger models
- **CPU-only** mode is supported but much slower

### Software
- Python 3.9 or higher
- CUDA Toolkit 11.8+ (for GPU acceleration)
- cuDNN 8.x (for GPU acceleration)
- FFmpeg (for audio processing)

## Installation

### 1. Install System Dependencies

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install python3-pip python3-venv ffmpeg
```

#### macOS
```bash
brew install python ffmpeg
```

### 2. Install CUDA (for GPU support)

Follow NVIDIA's official guide: https://developer.nvidia.com/cuda-downloads

Verify installation:
```bash
nvidia-smi
nvcc --version
```

### 3. Create Python Virtual Environment

```bash
cd cloud/gpu-worker
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 4. Install Python Dependencies

```bash
pip install -r requirements.txt
```

### 5. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` with your AWS credentials and configuration from Terraform outputs:

```bash
# Get values from Terraform
cd ../infra
terraform output gpu_worker_configuration
```

## Configuration

### Whisper Models

Choose a model based on your hardware and accuracy needs:

| Model | VRAM | Speed | Accuracy |
|-------|------|-------|----------|
| tiny  | ~1GB | Fastest | Lowest |
| base  | ~1GB | Fast | Good |
| small | ~2GB | Medium | Better |
| medium| ~5GB | Slow | Great |
| large-v3 | ~10GB | Slowest | Best |

Set in `.env`:
```bash
WHISPER_MODEL=base
```

### Device Configuration

**GPU (recommended):**
```bash
WHISPER_DEVICE=cuda
WHISPER_COMPUTE_TYPE=float16
```

**CPU (slower):**
```bash
WHISPER_DEVICE=cpu
WHISPER_COMPUTE_TYPE=float32
```

## Running the Worker

### Development

```bash
source venv/bin/activate
python src/worker.py
```

### Production (with systemd)

Create `/etc/systemd/system/rem-worker.service`:

```ini
[Unit]
Description=REM GPU Transcription Worker
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/path/to/rem/cloud/gpu-worker
Environment="PATH=/path/to/rem/cloud/gpu-worker/venv/bin"
ExecStart=/path/to/rem/cloud/gpu-worker/venv/bin/python src/worker.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable rem-worker
sudo systemctl start rem-worker
sudo systemctl status rem-worker
```

View logs:
```bash
sudo journalctl -u rem-worker -f
```

### Production (with Docker)

Create `Dockerfile`:
```dockerfile
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y python3-pip ffmpeg
WORKDIR /app
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY src/ ./src/
COPY .env .

CMD ["python3", "src/worker.py"]
```

Build and run:
```bash
docker build -t rem-worker .
docker run --gpus all --env-file .env rem-worker
```

## How It Works

1. **Poll SQS**: Long-polls the transcription jobs queue
2. **Download Audio**: Downloads WAV file from S3 raw audio bucket
3. **Transcribe**: Runs Whisper on the audio file
4. **Upload Results**: Stores transcript JSON and TXT in S3
5. **Update Metadata**: Updates DynamoDB with transcription status
6. **Delete Message**: Removes job from SQS queue

## Monitoring

### Logs

The worker logs to stdout with the following levels:
- **INFO**: Normal operation, job processing
- **WARNING**: Recoverable errors
- **ERROR**: Failed jobs, AWS errors
- **DEBUG**: Detailed processing information

Set log level in `.env`:
```bash
LOG_LEVEL=INFO
```

### Metrics to Monitor

- **SQS Queue Depth**: Number of pending transcription jobs
- **Processing Time**: Time per transcription
- **GPU Utilization**: `nvidia-smi` or CloudWatch
- **Error Rate**: Failed transcriptions

### CloudWatch Integration (Optional)

Install CloudWatch agent to send logs and metrics:
```bash
pip install watchtower
```

## Troubleshooting

### CUDA Out of Memory

Reduce model size or batch size:
```bash
WHISPER_MODEL=base  # Use smaller model
MAX_MESSAGES=1      # Process one at a time
```

### Slow Transcription

- Ensure GPU is being used: Check `nvidia-smi` during transcription
- Use smaller model for faster processing
- Check CUDA/cuDNN installation

### AWS Permissions

Ensure IAM user/role has permissions for:
- SQS: ReceiveMessage, DeleteMessage
- S3: GetObject (raw audio), PutObject (transcripts)
- DynamoDB: UpdateItem

### FFmpeg Not Found

Install FFmpeg:
```bash
# Ubuntu
sudo apt install ffmpeg

# macOS
brew install ffmpeg
```

## Scaling

### Multiple Workers

Run multiple worker instances to process jobs in parallel:
- Each worker polls the same SQS queue
- SQS ensures each message is processed only once
- Scale based on queue depth

### Auto-Scaling

Use AWS Auto Scaling with GPU instances:
- Monitor SQS queue depth
- Scale up when queue > threshold
- Scale down when queue is empty

### Cost Optimization

- Use Spot Instances for GPU workers (70-90% cheaper)
- Stop workers when queue is empty
- Use smaller models for acceptable accuracy

## Performance

Typical transcription times (5-minute audio):

| Model | GPU (RTX 3090) | CPU (16 cores) |
|-------|----------------|----------------|
| tiny  | ~10s | ~2min |
| base  | ~15s | ~3min |
| small | ~30s | ~6min |
| medium| ~60s | ~15min |
| large | ~120s | ~30min |

## Alternative: OpenAI Whisper

To use the original OpenAI Whisper instead of faster-whisper:

1. Update `requirements.txt`:
```
openai-whisper>=20231117
```

2. Modify `worker.py` to use `whisper.load_model()` and `whisper.transcribe()`

Note: faster-whisper is typically 4x faster with similar accuracy.

