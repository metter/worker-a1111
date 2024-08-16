# Use RunPod's base PyTorch image
FROM runpod/pytorch:3.10-2.0.0-117

# Use bash shell with pipefail option
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Set the working directory
WORKDIR /

# Update and upgrade the system packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt install -y \
    fonts-dejavu-core rsync nano git jq moreutils aria2 wget libgoogle-perftools-dev procps wget && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && apt-get clean -y

# Clone the specific version of AUTOMATIC1111 Stable Diffusion WebUI
RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cd stable-diffusion-webui && \
    git reset --hard 82a973c04367123ae98bd9abdf80d9eda9b910e2

RUN wget -q -O stable-diffusion-webui/model.safetensors https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors    

# Install Python dependencies
COPY builder/requirements.txt /requirements.txt
RUN pip install --upgrade pip && \
    pip install --upgrade -r /requirements.txt --no-cache-dir && \
    rm /requirements.txt

# Set up the model
RUN cd /stable-diffusion-webui && \
    pip install --upgrade pip && \
    pip install --upgrade -r requirements.txt --no-cache-dir

# Install torch packages without cache
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121    

RUN python /stable-diffusion-webui/launch.py --model /stable-diffusion-webui/model.safetensors --exit --skip-torch-cuda-test --xformers --no-half --reinstall-xformers

COPY embeddings /stable-diffusion-webui/embeddings
COPY loras /stable-diffusion-webui/models/Lora
ADD src . 

COPY builder/papertrail.sh /papertrail.sh    
RUN chmod +x /papertrail.sh

# Cleanup and final setup
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Set permissions and specify the command to run
RUN chmod +x /start.sh
CMD /start.sh
