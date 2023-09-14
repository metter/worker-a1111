# Use the official Ubuntu base image
FROM ubuntu:latest

# Set the timezone to Zurich
RUN echo "tzdata tzdata/Areas select Europe" | debconf-set-selections && \
    echo "tzdata tzdata/Zones/Europe select Zurich" | debconf-set-selections

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

# Install PyTorch
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# Clone the repository
RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cd stable-diffusion-webui && \
    git reset --hard 5ef669de080814067961f28357256e8fe27544f4 && \
    pip install -r requirements_versions.txt && \
    wget -O model.safetensors https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors

# Launch the Python script
RUN python3.10 stable-diffusion-webui/launch.py --skip-torch-cuda-test --ckpt stable-diffusion-webui/model.safetensors --no-half --exit
