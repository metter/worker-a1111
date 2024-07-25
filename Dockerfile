# Use a base image with CUDA support
FROM nvidia/cuda:11.8.0-runtime-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    LD_PRELOAD=libtcmalloc.so \
    ROOT=/stable-diffusion-webui \
    PYTHONUNBUFFERED=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    git \
    python3 \
    python3-venv \
    python3-pip \
    python3-dev \
    libgl1 \
    libglib2.0-0 \
    fonts-dejavu-core \
    rsync \
    nano \
    jq \
    moreutils \
    aria2 \
    libgoogle-perftools-dev \
    procps \
    gcc \
    g++ \
    build-essential \
    python3-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install torch packages
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# Install Python dependencies (Worker Template)
COPY builder/requirements.txt /requirements.txt
RUN pip install --upgrade pip && \
    pip install --upgrade -r /requirements.txt --no-cache-dir && \
    rm /requirements.txt

# Clone A1111 repository
RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git ${ROOT}

# Set working directory
WORKDIR ${ROOT}

# Checkout specific version
RUN git checkout feee37d75f1b168768014e4634dcb156ee649c05

# Download the SDXL model
RUN wget -q -O ${ROOT}/model.safetensors https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors

# Copy initialize.sh and make it executable
COPY builder/initialize.sh ${ROOT}/initialize.sh
RUN chmod +x ${ROOT}/initialize.sh

# Run initialize.sh to install A1111 and its dependencies
RUN ${ROOT}/initialize.sh

# Copy embeddings and loras
COPY embeddings ${ROOT}/embeddings
COPY loras ${ROOT}/models/Lora

# Install remote_syslog2 for Papertrail
RUN wget https://github.com/papertrail/remote_syslog2/releases/download/v0.20/remote_syslog_linux_amd64.tar.gz && \
    tar xzf ./remote_syslog*.tar.gz && \
    cp ./remote_syslog/remote_syslog /usr/local/bin/ && \
    rm -r ./remote_syslog_linux_amd64.tar.gz ./remote_syslog

# Create a config file for remote_syslog
RUN echo "files:" >> /etc/log_files.yml && \
    echo "  - /var/log/runpod_handler.log" >> /etc/log_files.yml && \
    echo "destination:" >> /etc/log_files.yml && \
    echo "  host: logs.papertrailapp.com" >> /etc/log_files.yml && \
    echo "  port: 27472" >> /etc/log_files.yml && \
    echo "  protocol: tls" >> /etc/log_files.yml

# Copy Papertrail script
COPY builder/papertrail.sh /papertrail.sh
RUN chmod +x /papertrail.sh

# COPY builder/test_input.json ${ROOT}/test_input.json

# Copy source files
COPY src/ /

RUN ls -l / && cat /rp_handler.py

# Set up entry point
RUN chmod +x /start.sh

CMD ["/start.sh"]