# Use the official Ubuntu base image
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu20.04

# Set DEBIAN_FRONTEND to noninteractive to prevent timezone prompts
ENV DEBIAN_FRONTEND=noninteractive

# Update package lists and install necessary packages
RUN apt-get update && \
    apt-get install -y fonts-dejavu-core rsync git curl jq moreutils aria2 wget libgoogle-perftools-dev procps libgl1-mesa-glx libglib2.0-0 && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean -y

# Install build essentials and Python dependencies
RUN apt-get update && \
    apt-get install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev && \
    wget https://www.python.org/ftp/python/3.10.9/Python-3.10.9.tar.xz && \
    tar -xf Python-3.10.9.tar.xz && \
    cd Python-3.10.9 && \
    ./configure --enable-optimizations && \
    make -j$(nproc) && \
    make altinstall && \
    cd .. && \
    rm -rf Python-3.10.9 Python-3.10.9.tar.xz && \
    apt-get install -y python3-pip && \
    ln -s /usr/local/bin/pip3.10 /usr/local/bin/pip && \
    python3.10 --version \
    pip --version

# Create symbolic links for python
RUN ln -s /usr/local/bin/python3.10 /usr/local/bin/python

# Install PyTorch
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
RUN pip install --upgrade clip-anytorch==2.4.0 
RUN pip install open_clip_torch

#install Nvidia drivers
RUN curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list \
  && \
    apt-get update

RUN apt-get install -y nvidia-container-toolkit    

# Install Python dependencies (Worker Template)
COPY builder/requirements.txt /requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip && \
    pip install --upgrade -r /requirements.txt --no-cache-dir && \
    rm /requirements.txt 

# Clone the repository
RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cd stable-diffusion-webui && \
    git reset --hard 5ef669de080814067961f28357256e8fe27544f4 && \
    pip install -r requirements_versions.txt && \
    wget -O model.safetensors https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors

# Launch the Python script
RUN python /stable-diffusion-webui/launch.py --ckpt /stable-diffusion-webui/model.safetensors --skip-torch-cuda-test --no-half --exit

# Start webui.py in the background
COPY builder/webui.sh /webui.sh
RUN chmod +x /webui.sh && /webui.sh
RUN rm /webui.sh

ADD src .

# get SDXL VAE
RUN cd stable-diffusion-webui/models/VAE \
    wget -O sdxl_vae.safetensors https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors

# copy embeddings
COPY embeddings /stable-diffusion-webui/embeddings

# Download remote_syslog2
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

COPY builder/papertrail.sh /papertrail.sh    
RUN chmod +x /papertrail.sh

# Ensure remote_syslog starts with the container
RUN echo "#!/bin/bash" > /start.sh && \
    echo "remote_syslog -D --pid-file=/var/run/remote_syslog.pid -c /etc/log_files.yml &" >> /start.sh && \
    echo "set -e" >> /start.sh && \
    # Adding a command to keep the script running or handle errors might be beneficial here
    chmod +x /start.sh
    
# Cleanup section (Worker Template)
RUN apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

CMD /start.sh