# Stage 1: Downloading Stage
FROM runpod/pytorch:3.10-2.0.0-117 as downloader

# Use bash shell with pipefail option
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install necessary tools for downloading files
RUN apt-get update && \
    apt-get install -y wget git && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && apt-get clean -y

# Create the required directories for models and custom nodes
RUN mkdir -p /downloads/models/checkpoints /downloads/models/controlnet /downloads/custom_nodes

# Set the working directory for downloading
WORKDIR /downloads    

# Clone the ComfyUI repository and reset to a specific commit
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /downloads/ComfyUI && \
    cd /downloads/ComfyUI && \
    git reset --hard f1c2301697cb1cd538f8d4190741935548bb6734

# Clone the custom nodes repositories
WORKDIR /downloads/custom_nodes

RUN git clone https://github.com/Fannovel16/comfyui_controlnet_aux /downloads/custom_nodes/comfyui_controlnet_aux && \
    cd /downloads/custom_nodes/comfyui_controlnet_aux && \
    git reset --hard df91818a3c5bd5126998a2b76c8e5d3081fc37d7

RUN git clone https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet /downloads/custom_nodes/comfyui_advanced_controlnet && \
    cd /downloads/custom_nodes/comfyui_advanced_controlnet && \
    git reset --hard 74d0c56ab3ba69663281390cc1b2072107939f96

RUN git clone https://github.com/Acly/comfyui-tooling-nodes.git /downloads/custom_nodes/comfyui_tooling_nodes && \
    cd /downloads/custom_nodes/comfyui_tooling_nodes && \
    git reset --hard f986f6a44275023aa816f73a9329374c4350e729  

RUN git clone https://github.com/lldacing/comfyui-easyapi-nodes.git /downloads/custom_nodes/comfyui_easyapi_nodes && \
    cd /downloads/custom_nodes/comfyui_easyapi_nodes && \
    git reset --hard c11ff7751659b03b9b1442e5f41d41f7b3ccd85f     

# Download the required models
WORKDIR /downloads/models

RUN wget -q -O /downloads/models/checkpoints/sd_xl_base_1.0.safetensors \
    https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors

RUN wget -q -O /downloads/models/controlnet/ip-adapter-plus-face_sdxl_vit-h.safetensors \
    https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus-face_sdxl_vit-h.safetensors

RUN wget -q -O /downloads/models/controlnet/ip-adapter_sdxl.safetensors \
    https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl.safetensors

RUN wget -q -O /downloads/models/controlnet/ip-adapter_sdxl_vit-h.safetensors \
    https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl_vit-h.safetensors

RUN wget -q -O /downloads/models/controlnet/ip-adapter_xl.pth \
    https://huggingface.co/lllyasviel/sd_control_collection/resolve/main/ip-adapter_xl.pth

RUN wget -q -O /downloads/models/controlnet/ip-adapter-faceid_sdxl.bin \
    https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid_sdxl.bin

RUN wget -q -O /downloads/models/controlnet/ip-adapter-faceid_sdxl_lora.safetensors \
    https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid_sdxl_lora.safetensors

RUN wget -q -O /downloads/models/controlnet/controlnet-openpose-sdxl-1.0.safetensors \
    https://huggingface.co/xinsir/controlnet-openpose-sdxl-1.0/blob/main/diffusion_pytorch_model.safetensors

RUN wget -q -O /downloads/models/controlnet/controlnet-openpose-sdxl-1.0_twins.safetensors \
    https://huggingface.co/xinsir/controlnet-openpose-sdxl-1.0/blob/main/diffusion_pytorch_model_twins.safetensors

RUN wget -q -O /downloads/models/controlnet/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors \
    https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors   


# Stage 2: Final Setup Stage
FROM runpod/pytorch:3.10-2.0.0-117

# Use bash shell with pipefail option
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Set the working directory
WORKDIR /

# Copy files from the downloader stage
COPY --from=downloader /downloads/ComfyUI /ComfyUI
COPY --from=downloader /downloads/models /ComfyUI/models

# Copy all custom nodes
COPY --from=downloader /downloads/custom_nodes /ComfyUI/custom_nodes

# Install system dependencies
RUN apt-get update && \
    apt-get upgrade -y && \
    apt install -y \
        fonts-dejavu-core rsync nano git jq moreutils aria2 wget mc libgoogle-perftools-dev procps && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && apt-get clean -y

# Install Python dependencies
COPY builder/requirements.txt /requirements.txt
RUN pip install --upgrade pip && \
    pip install --upgrade -r /requirements.txt --no-cache-dir && \
    rm /requirements.txt

# Install dependencies for ComfyUI
RUN cd /ComfyUI && \
    pip install --upgrade -r requirements.txt --no-cache-dir

# Install dependencies for comfyui_controlnet_aux
RUN cd /ComfyUI/custom_nodes/comfyui_controlnet_aux && \
    pip install --upgrade -r requirements.txt --no-cache-dir  

# Install dependencies for comfyui-easyapi-nodes
RUN cd /ComfyUI/custom_nodes/comfyui_easyapi_nodes && \
    pip install --upgrade -r requirements.txt --no-cache-dir     

# Copy the dryrun.sh script into the container
COPY builder/dryrun.sh /ComfyUI/dryrun.sh
RUN chmod +x /ComfyUI/dryrun.sh
RUN /ComfyUI/dryrun.sh

# Copy additional resources
COPY embeddings /ComfyUI/models/embeddings
COPY loras /ComfyUI/models/loras
COPY characters /characters
COPY src/base64_encoder.py /base64_encoder.py
ADD src . 

# Download and install remote_syslog2
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

# Set up Papertrail (logging)
COPY builder/papertrail.sh /papertrail.sh    
RUN chmod +x /papertrail.sh

# Cleanup and final setup
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Set permissions and specify the command to run
RUN chmod +x /start.sh
CMD /start.sh
