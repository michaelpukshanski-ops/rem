# Lambda Docker Image for Transcription Worker
# Supports larger dependencies (up to 10 GB vs 250 MB for layers)

FROM public.ecr.aws/lambda/python:3.11

# Install system dependencies for building Python packages
RUN yum install -y \
    gcc \
    gcc-c++ \
    make \
    pkgconfig \
    ffmpeg-devel \
    && yum clean all

# Copy requirements first (for better layer caching)
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy function code
COPY src/ ${LAMBDA_TASK_ROOT}/

# Set the CMD to your handler
CMD [ "handler.handler" ]

