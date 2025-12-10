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

# Copy application code
COPY src/ ./src/

# Set environment variables for CPU-only mode
ENV WHISPER_DEVICE=cpu
ENV WHISPER_COMPUTE_TYPE=float32
ENV LOG_LEVEL=INFO

# Run the worker
CMD ["python", "src/worker.py"]

