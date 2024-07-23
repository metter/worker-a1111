# Stage 1: Download all required files and models
FROM alpine:3.14 as downloader

RUN apk add --no-cache git wget

# Clone repositories
RUN git clone https://github.com/CompVis/taming-transformers.git /taming-transformers && \
    cd /taming-transformers && \
    git checkout 24268930bf1dce879235a7fddd0b2355b84d7ea6 && \
    rm -rf data assets **/*.ipynb

RUN git clone https://github.com/Stability-AI/stablediffusion.git /stable-diffusion-stability-ai && \
    cd /stable-diffusion-stability-ai && \
    git checkout 47b6b607fdd31875c9279cd2f4f16b92e4ea958e && \
    rm -rf assets data/**/*.png data/**/*.jpg data/**/*.gif

RUN git clone https://github.com/sczhou/CodeFormer.git /CodeFormer && \
    cd /CodeFormer && \
    git checkout c5b4593074ba6214284d6acd5f1719b6c5d739af && \
    rm -rf assets inputs

RUN git clone https://github.com/salesforce/BLIP.git /BLIP && \
    cd /BLIP && \
    git checkout 48211a1594f1321b00f14c9f7a5b4813144b2fb9

RUN git clone https://github.com/crowsonkb/k-diffusion.git /k-diffusion && \
    cd /k-diffusion && \
    git checkout 5b3af030dd83e0297272d861c19477735d0317ec

RUN git clone https://github.com/pharmapsychotic/clip-interrogator.git /clip-interrogator && \
    cd /clip-interrogator && \
    git checkout 2486589f24165c8e3b303f84e9dbbea318df83e8

RUN git clone https://github.com/Stability-AI/generative-models.git /generative-models && \
    cd /generative-models && \
    git checkout 45c443b316737a4ab6e40413d7794a7f5657c19f

# Download the model
RUN wget -q -O /model.safetensors https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors

# Download remote_syslog2
RUN wget https://github.com/papertrail/remote_syslog2/releases/download/v0.20/remote_syslog_linux_amd64.tar.gz && \
    tar xzf ./remote_syslog*.tar.gz && \
    cp ./remote_syslog/remote_syslog /usr/local/bin/ && \
    rm -r ./remote_syslog_linux_amd64.tar.gz ./remote_syslog

# Stage 2: Build the final image
FROM python:3.10.9-slim as build_final_image

ARG SHA=5ef669de080814067961f28357256e8fe27544f4

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    LD_PRELOAD=libtcmalloc.so \
    ROOT=/stable-diffusion-webui \
    PYTHONUNBUFFERED=1

# Install required packages and system dependencies
RUN apt-get update && \
    apt-get install -y \
    fonts-dejavu-core \
    rsync \
    nano \
    git \
    jq \
    moreutils \
    aria2 \
    wget \
    libgoogle-perftools-dev \
    procps \
    libgl1 \
    libglib2.0-0 \
    gcc \
    g++ \
    build-essential \
    python3-dev && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean -y

# Install torch packages without cache
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# Install Python dependencies (Worker Template)
COPY builder/requirements.txt /requirements.txt
RUN pip install --upgrade pip && \
    pip install --upgrade -r /requirements.txt --no-cache-dir && \
    rm /requirements.txt 

# Clone the stable-diffusion-webui repository and checkout the specific SHA
RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git ${ROOT} && \
    cd ${ROOT} && \
    git reset --hard ${SHA}

# Copy downloaded models and setup
COPY --from=downloader /model.safetensors ${ROOT}/model.safetensors
COPY --from=downloader /taming-transformers ${ROOT}/repositories/taming-transformers
COPY --from=downloader /stable-diffusion-stability-ai ${ROOT}/repositories/stable-diffusion-stability-ai
COPY --from=downloader /CodeFormer ${ROOT}/repositories/CodeFormer
COPY --from=downloader /BLIP ${ROOT}/repositories/BLIP
COPY --from=downloader /k-diffusion ${ROOT}/repositories/k-diffusion
COPY --from=downloader /clip-interrogator ${ROOT}/repositories/clip-interrogator
COPY --from=downloader /generative-models ${ROOT}/repositories/generative-models
COPY --from=downloader /usr/local/bin/remote_syslog /usr/local/bin/remote_syslog

RUN echo "httpx==0.24.1" >> ${ROOT}/requirements_versions.txt && \
    pip install -r ${ROOT}/requirements_versions.txt    

# Install Python dependencies for CodeFormer and others
RUN pip install -r ${ROOT}/repositories/CodeFormer/requirements.txt

# Launch the Python script
RUN python ${ROOT}/launch.py --ckpt ${ROOT}/model.safetensors --skip-torch-cuda-test --no-half --exit

COPY embeddings ${ROOT}/embeddings
COPY loras ${ROOT}/models/Lora

# Create a config file for remote_syslog
RUN echo "files:" >> /etc/log_files.yml && \
    echo "  - /var/log/runpod_handler.log" >> /etc/log_files.yml && \
    echo "destination:" >> /etc/log_files.yml && \
    echo "  host: logs.papertrailapp.com" >> /etc/log_files.yml && \
    echo "  port: 27472" >> /etc/log_files.yml && \
    echo "  protocol: tls" >> /etc/log_files.yml

ADD src .    

# Replace webui.sh functionality with direct implementation if needed
COPY builder/webui.sh ${ROOT}/webui.sh
# Make the script executable and run it without changing the working directory unnecessarily
RUN chmod +x ${ROOT}/webui.sh && ${ROOT}/webui.sh

COPY builder/papertrail.sh /papertrail.sh    
RUN chmod +x /papertrail.sh

# Cleanup and final setup
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Set permissions and specify the command to run
COPY start.sh /start.sh
RUN chmod +x /start.sh
CMD /start.sh