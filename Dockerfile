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
        fonts-dejavu-core rsync nano git jq moreutils aria2 wget libgoogle-perftools-dev procps && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && apt-get clean -y

# Clone the specific version of AUTOMATIC1111 Stable Diffusion WebUI
RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cd stable-diffusion-webui && \
    git reset --hard 82a973c04367123ae98bd9abdf80d9eda9b910e2

# Download the model
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

# Clone the ControlNet extension into the WebUI's extensions directory
RUN git clone https://github.com/Mikubill/sd-webui-controlnet.git /stable-diffusion-webui/extensions/sd-webui-controlnet && \
    cd /stable-diffusion-webui/extensions/sd-webui-controlnet && \
    # Checkout the specific commit
    git reset --hard 56cec5b2958edf3b1807b7e7b2b1b5186dbd2f81 && \
    # Install ControlNet's Python dependencies
    pip install --upgrade pip && \
    pip install --upgrade -r /stable-diffusion-webui/extensions/sd-webui-controlnet/requirements.txt --no-cache-dir

# Download the IP-Adapter FaceID model and place it in the ControlNet models directory
RUN wget -q -O /stable-diffusion-webui/extensions/sd-webui-controlnet/models/ip-adapter-faceid-plusv2_sdxl.bin \
https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid_sdxl.bin


# Launch the WebUI to finalize setup (this step installs any remaining dependencies)
RUN python /stable-diffusion-webui/launch.py --model /stable-diffusion-webui/model.safetensors --exit --skip-torch-cuda-test --xformers --no-half --reinstall-xformers

# Copy additional resources
COPY embeddings /stable-diffusion-webui/embeddings
COPY loras /stable-diffusion-webui/models/Lora
COPY characters /characters
ADD src . 

# Set up Papertrail (logging)
COPY builder/papertrail.sh /papertrail.sh    
RUN chmod +x /papertrail.sh

# Cleanup and final setup
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Set permissions and specify the command to run
RUN chmod +x /start.sh
CMD /start.sh
