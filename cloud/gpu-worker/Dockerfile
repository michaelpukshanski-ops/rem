# REM GPU Worker - Dockerfile for ECS Fargate (CPU-only)
# This runs the transcription worker on AWS Fargate Spot instances

FROM python:3.9-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Pre-download Whisper model during build (so it doesn't need internet at runtime)
# This downloads the model to /root/.cache/huggingface/
RUN python -c "from faster_whisper import WhisperModel; print('Downloading Whisper base model...'); model = WhisperModel('base', device='cpu', compute_type='float32', download_root='/root/.cache/huggingface'); print('Model downloaded successfully!')"

# Verify the model was downloaded
RUN ls -lah /root/.cache/huggingface/ && du -sh /root/.cache/huggingface/

# Copy application code
COPY src/ ./src/

# Set environment variables for CPU-only mode
ENV WHISPER_DEVICE=cpu
ENV WHISPER_COMPUTE_TYPE=float32
ENV LOG_LEVEL=INFO
ENV HF_HOME=/root/.cache/huggingface

# Run the worker
CMD ["python", "src/worker.py"]

