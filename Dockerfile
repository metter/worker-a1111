# Use the official Ubuntu base image
FROM nvidia/cuda:12.2.0-base-ubuntu20.04

# Set the timezone to Zurich
RUN echo "tzdata tzdata/Areas select Europe" | debconf-set-selections && \
    echo "tzdata tzdata/Zones/Europe select Zurich" | debconf-set-selections

# Set DEBIAN_FRONTEND to noninteractive to prevent timezone prompts
ENV DEBIAN_FRONTEND=noninteractive

# Update package lists and install necessary packages
RUN apt-get update && \
    apt-get install -y fonts-dejavu-core rsync git jq moreutils aria2 wget libgoogle-perftools-dev procps libgl1-mesa-glx libglib2.0-0 && \
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

# Clone the repository
RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cd stable-diffusion-webui && \
    git reset --hard 5ef669de080814067961f28357256e8fe27544f4 && \
    pip install -r requirements_versions.txt && \
    pip install xformers && \
    wget -O model.safetensors https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors

# Launch the Python script
RUN python stable-diffusion-webui/launch.py --ckpt stable-diffusion-webui/model.safetensors --skip-torch-cuda-test --no-half --exit
RUN pip install open_clip_torch

# Install Python dependencies (Worker Template)
COPY builder/requirements.txt /requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip && \
    pip install --upgrade -r /requirements.txt --no-cache-dir && \
    rm /requirements.txt

ADD src .

#COPY builder/cache.py /stable-diffusion-webui/cache.py
#RUN cd /stable-diffusion-webui && python3.10 cache.py --use-cpu=all --ckpt /model.safetensors

# Cleanup section (Worker Template)
RUN apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

RUN chmod +x /start.sh
CMD /start.sh