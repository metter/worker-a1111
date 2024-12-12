# Stage 1: Downloading Stage
FROM alpine:3.18 AS downloader

# Install necessary tools for downloading files
RUN apk add --no-cache bash git wget

# Create the required directories for models and custom nodes
RUN mkdir -p /downloads/models/sams \
    /downloads/models/grounding-dino \
    /downloads/models/inpaint/brushnet_xl \
    /downloads/models/clip \
    /downloads/models/vae \
    /downloads/models/sam2 \
    /downloads/models/antelopev2 \
    /downloads/models/qresearch/doubutsu-2b-pt-756 \
    /downloads/models/qresearch/doubutsu-2b-lora-756-docci \
    /downloads/models/checkpoints \
    /downloads/models/controlnet \
    /downloads/models/ipadapter \
    /downloads/models/loras \
    /downloads/models/clip_vision \
    /downloads/custom_nodes \
    /downloads/models/unet

# Set the working directory for downloading
WORKDIR /downloads   

# Define build argument for Hugging Face token
ARG HUGGINGFACE_ACCESS_TOKEN
ENV HUGGINGFACE_ACCESS_TOKEN=${HUGGINGFACE_ACCESS_TOKEN}

# Clone the ComfyUI repository and reset to a specific commit
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /downloads/ComfyUI && \
    cd /downloads/ComfyUI && \
    git reset --hard 9a616b81c15cec7f5ddcbc12e349f1adc03fad67  

# Download the required models
WORKDIR /downloads/models

# Download the flux1-schnell-fp8.safetensors model with authentication
RUN wget --progress=dot:giga \
    --header="Authorization: Bearer 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" \
    -O /downloads/models/unet/flux1-schnell-fp8.safetensors \
    https://huggingface.co/Comfy-Org/flux1-schnell/resolve/main/flux1-schnell-fp8.safetensors

# Download the flux1-dev.safetensors model with authentication
RUN wget --progress=dot:giga \
    --header="Authorization: Bearer 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" \
    -O /downloads/models/unet/flux1-dev.safetensors \
    https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors   

# CLIP
RUN wget --progress=dot:giga -O /downloads/models/clip/clip_l.safetensors \
    https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors

RUN wget --progress=dot:giga -O /downloads/models/clip/t5xxl_fp8_e4m3fn.safetensors \
    https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors

RUN wget --progress=dot:giga -O /downloads/models/clip/t5xxl_fp16.safetensors \
    https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors    
    
# VAE
RUN wget --progress=dot:giga -O /downloads/models/vae/flux-schnell-vae.safetensors \
    https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/vae/diffusion_pytorch_model.safetensors  
    
RUN wget --progress=dot:giga \
    --header="Authorization: Bearer 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" \
    -O /downloads/models/vae/flux-dev-vae.safetensors \
    https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/vae/diffusion_pytorch_model.safetensors    
    
# ControlNet
RUN wget --progress=dot:giga -O /downloads/models/controlnet/FLUX-1-dev-ControlNet-Union-Pro.safetensors \
    https://huggingface.co/Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro/resolve/main/diffusion_pytorch_model.safetensors

# Clip Vision
RUN wget --progress=dot:giga -O /downloads/models/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors \
    https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors   

# Grounding DINO
RUN wget --progress=dot:giga -O /downloads/models/grounding-dino/groundingdino_swinb_cogcoor.pth \
    https://huggingface.co/ShilongLiu/GroundingDINO/resolve/main/groundingdino_swinb_cogcoor.pth 

# SAM Models
RUN wget --progress=dot:giga -O /downloads/models/sams/sam2_hiera_base_plus.pt \
    https://dl.fbaipublicfiles.com/segment_anything_2/072824/sam2_hiera_base_plus.pt

RUN wget --progress=dot:giga -O /downloads/models/sams/sam2_hiera_large.pt \
    https://dl.fbaipublicfiles.com/segment_anything_2/072824/sam2_hiera_large.pt    

# QResearch Models
RUN wget --progress=dot:giga -O /downloads/models/qresearch/doubutsu-2b-pt-756/doubutsu-2b-pt-756.bin \
    https://huggingface.co/qresearch/doubutsu-2b-pt-756/resolve/main/pytorch_model.bin

RUN wget --progress=dot:giga -O /downloads/models/qresearch/doubutsu-2b-pt-756/added_tokens.json \
    https://huggingface.co/qresearch/doubutsu-2b-pt-756/resolve/main/added_tokens.json

RUN wget --progress=dot:giga -O /downloads/models/qresearch/doubutsu-2b-pt-756/config.json  \
    https://huggingface.co/qresearch/doubutsu-2b-pt-756/resolve/main/config.json    

RUN wget --progress=dot:giga -O /downloads/models/qresearch/doubutsu-2b-pt-756/special_tokens_map.json  \
    https://huggingface.co/qresearch/doubutsu-2b-pt-756/resolve/main/special_tokens_map.json     
        
RUN wget --progress=dot:giga -O /downloads/models/qresearch/doubutsu-2b-pt-756/tokenizer.json  \
    https://huggingface.co/qresearch/doubutsu-2b-pt-756/resolve/main/tokenizer.json 

RUN wget --progress=dot:giga -O /downloads/models/qresearch/doubutsu-2b-pt-756/tokenizer_config.json  \
    https://huggingface.co/qresearch/doubutsu-2b-pt-756/resolve/main/tokenizer_config.json

RUN wget --progress=dot:giga -O /downloads/models/qresearch/doubutsu-2b-pt-756/vocab.json  \
    https://huggingface.co/qresearch/doubutsu-2b-pt-756/resolve/main/vocab.json    
    
RUN wget --progress=dot:giga -O /downloads/models/qresearch/doubutsu-2b-pt-756/configuration_doubutsu_next.py  \
    https://huggingface.co/qresearch/doubutsu-2b-pt-756/resolve/main/configuration_doubutsu_next.py 

RUN wget --progress=dot:giga -O /downloads/models/qresearch/modeling_doubutsu_next.py  \
    https://huggingface.co/qresearch/doubutsu-2b-pt-756/resolve/main/modeling_doubutsu_next.py  

RUN wget --progress=dot:giga -O /downloads/models/qresearch/doubutsu-2b-pt-756/utils.py  \
    https://huggingface.co/qresearch/doubutsu-2b-pt-756/resolve/main/utils.py
          
RUN wget --progress=dot:giga -O /downloads/models/qresearch/doubutsu-2b-lora-756-docci/doubutsu-2b-lora-756-docci.safetensors \
    https://huggingface.co/qresearch/doubutsu-2b-lora-756-docci/resolve/main/adapter_model.safetensors  

RUN wget --progress=dot:giga -O /downloads/models/qresearch/doubutsu-2b-lora-756-docci/adapter_config.json  \
    https://huggingface.co/qresearch/doubutsu-2b-lora-756-docci/resolve/main/adapter_config.json     

# Additional SAM and Grounding DINO Models
RUN wget -q -O /downloads/models/sam2/sam2_hiera_tiny.pt \
    https://dl.fbaipublicfiles.com/segment_anything_2/072824/sam2_hiera_tiny.pt

RUN wget -q -O /downloads/models/grounding-dino/GroundingDINO_SwinT_OGC.cfg.py \
    https://huggingface.co/ShilongLiu/GroundingDINO/resolve/main/GroundingDINO_SwinT_OGC.cfg.py

RUN wget -q -O /downloads/models/grounding-dino/groundingdino_swint_ogc.pth \
    https://huggingface.co/ShilongLiu/GroundingDINO/resolve/main/groundingdino_swint_ogc.pth

# Antelopev2 Models
RUN wget -q -O /downloads/models/antelopev2/1k3d68.onnx \
    https://huggingface.co/camenduru/show/resolve/main/insightface/models/antelopev2/1k3d68.onnx

RUN wget -q -O /downloads/models/antelopev2/2d106det.onnx \
    https://huggingface.co/camenduru/show/resolve/main/insightface/models/antelopev2/2d106det.onnx    

RUN wget -q -O /downloads/models/antelopev2/genderage.onnx \
    https://huggingface.co/camenduru/show/resolve/main/insightface/models/antelopev2/genderage.onnx

RUN wget -q -O /downloads/models/antelopev2/glintr100.onnx \
    https://huggingface.co/camenduru/show/resolve/main/insightface/models/antelopev2/glintr100.onnx

RUN wget -q -O /downloads/models/antelopev2/scrfd_10g_bnkps.onnx \
    https://huggingface.co/camenduru/show/resolve/main/insightface/models/antelopev2/scrfd_10g_bnkps.onnx  
    

# Clip Vision Model
RUN wget -q -O /downloads/models/clip/clip_vision.safetensors \
    https://huggingface.co/shiertier/clip_vision/resolve/main/model.safetensors 

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

RUN git clone https://github.com/nullquant/ComfyUI-BrushNet.git /downloads/custom_nodes/ComfyUI-BrushNet && \
    cd /downloads/custom_nodes/ComfyUI-BrushNet && \
    git reset --hard a510effde1ba9df8324f80bb5fc684b5a62792d4    
    
RUN git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus.git /downloads/custom_nodes/ComfyUI_IPAdapter_plus && \
    cd /downloads/custom_nodes/ComfyUI_IPAdapter_plus && \
    git reset --hard 88a71407c545e4eb0f223294f5b56302ef8696f3  

RUN git clone https://github.com/twri/sdxl_prompt_styler.git /downloads/custom_nodes/sdxl_prompt_styler && \
    cd /downloads/custom_nodes/sdxl_prompt_styler && \
    git reset --hard 51068179927f79dce14f38c6b1984390ab242be2 

RUN git clone https://github.com/alessandrozonta/ComfyUI-OpenPose.git /downloads/custom_nodes/ComfyUI-OpenPose && \
    cd /downloads/custom_nodes/ComfyUI-OpenPose && \
    git reset --hard 8bc6c07576408a6baa5263fb432f69d1d279ef39

RUN git clone https://github.com/rgthree/rgthree-comfy.git /downloads/custom_nodes/rgthree-comfy && \
    cd /downloads/custom_nodes/rgthree-comfy && \
    git reset --hard 98f7a0524bb052a4a65844a69b61c9e8afb592ea

RUN git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git /downloads/custom_nodes/ComfyUI_Comfyroll_CustomNodes && \
    cd /downloads/custom_nodes/ComfyUI_Comfyroll_CustomNodes && \
    git reset --hard d78b780ae43fcf8c6b7c6505e6ffb4584281ceca

RUN git clone https://github.com/BlenderNeko/ComfyUI_ADV_CLIP_emb.git /downloads/custom_nodes/ComfyUI_ADV_CLIP_emb && \
    cd /downloads/custom_nodes/ComfyUI_ADV_CLIP_emb && \
    git reset --hard 63984deefb005da1ba90a1175e21d91040da38ab

# RUN git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git /downloads/custom_nodes/ComfyUI-Impact-Pack && \
#     cd /downloads/custom_nodes/ComfyUI-Impact-Pack && \
#     git reset --hard fd6957097796d0e33092645fc56171b8dc007466

RUN git clone https://github.com/neverbiasu/ComfyUI-SAM2.git /downloads/custom_nodes/ComfyUI-SAM2 && \
    cd /downloads/custom_nodes/ComfyUI-SAM2 && \
    git reset --hard 61a97f2fe8094a1da48b4313394a1e18b529cccf   
        
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git /downloads/custom_nodes/ComfyUI-Manager && \
    cd /downloads/custom_nodes/ComfyUI-Manager && \
    git reset --hard de3cd9fe721020463e3e1c107a257ba1a52b9acd     

RUN git clone https://github.com/crystian/ComfyUI-Crystools.git /downloads/custom_nodes/ComfyUI-Crystools && \
    cd /downloads/custom_nodes/ComfyUI-Crystools && \
    git reset --hard 09d84235d99789447d143c4a4907c2d22e452097     
    
RUN git clone https://github.com/EnragedAntelope/ComfyUI-Doubutsu-Describer.git /downloads/custom_nodes/ComfyUI-Doubutsu-Describer && \
    cd /downloads/custom_nodes/ComfyUI-Doubutsu-Describer && \
    git reset --hard b189b66de6ee5275bc59c101e0fe50fb54604dbd   

RUN git clone https://github.com/WASasquatch/was-node-suite-comfyui.git /downloads/custom_nodes/was-node-suite-comfyui && \
    cd /downloads/custom_nodes/was-node-suite-comfyui && \
    git reset --hard fe7e0884aaf0188248d9abf1e500f5116097fec1

RUN git clone https://github.com/yolain/ComfyUI-Easy-Use.git /downloads/custom_nodes/ComfyUI-Easy-Use && \
    cd /downloads/custom_nodes/ComfyUI-Easy-Use && \
    git reset --hard d416ad21f0d84c04a5b7e68c59e5212525443b8e

# Install Required Plugins
RUN git clone https://github.com/comfyanonymous/ComfyUI_bitsandbytes_NF4.git /downloads/custom_nodes/ComfyUI_bitsandbytes_NF4 && \
    cd /downloads/custom_nodes/ComfyUI_bitsandbytes_NF4 && \
    git reset --hard c13c3b5b264ebf32153c6fa53b96c836746258c3

RUN git clone https://github.com/city96/ComfyUI-GGUF.git /downloads/custom_nodes/ComfyUI-GGUF && \
    cd /downloads/custom_nodes/ComfyUI-GGUF && \
    git reset --hard 851564739d166b888dd9cea80f90dc8219393b52

# Stage 2: Final Setup Stage
FROM cnstark/pytorch:2.3.1-py3.10.15-cuda12.1.0-ubuntu22.04

ENV COMFYUI_PATH=/ComfyUI
ENV COMFYUI_MODEL_PATH=/ComfyUI/models

# Use bash shell with pipefail option
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Set the working directory
WORKDIR /

# Copy files from the downloader stage
COPY --from=downloader /downloads/ComfyUI /ComfyUI
COPY --from=downloader /downloads/models /ComfyUI/models

# Copy all custom nodes
COPY --from=downloader /downloads/custom_nodes /ComfyUI/custom_nodes
RUN cd /ComfyUI/custom_nodes/ComfyUI-Easy-Use && pip install -r requirements.txt
# RUN cd /ComfyUI/custom_nodes/ComfyUI-Impact-Pack && pip install -r requirements.txt

# Install system dependencies
RUN apt-get update && \
    apt-get upgrade -y && \
    apt install -y \
        fonts-dejavu-core \
        rsync \
        nano \
        git \
        jq \
        moreutils \
        aria2 \
        wget \
        mc \
        libgoogle-perftools-dev \
        procps \
        libgl1 \
        libglib2.0-0 \
        ffmpeg \
        libsm6 \
        libxext6 \
        libxrender-dev \
        libgl1-mesa-glx \
        libglib2.0-0 \
        && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && apt-get clean -y

# Install Python dependencies
COPY builder/requirements.txt /requirements.txt
RUN pip install --upgrade pip && \
    pip install --upgrade -r /requirements.txt --no-cache-dir && \
    rm /requirements.txt

COPY builder/manual_comfyui_start.sh /manual_comfyui_start.sh    

# Install dependencies for ComfyUI
RUN cd /ComfyUI && \
    pip install --upgrade -r requirements.txt --no-cache-dir

# Install dependencies for all custom nodes
RUN set -e && for dir in /ComfyUI/custom_nodes/*; do \
    if [ -f "$dir/requirements.txt" ]; then \
        pip install --upgrade -r "$dir/requirements.txt" --no-cache-dir; \
    fi; \
done

# Copy the dryrun.sh script into the container
COPY builder/dryrun.sh /ComfyUI/dryrun.sh
RUN chmod +x /ComfyUI/dryrun.sh
RUN /ComfyUI/dryrun.sh

# Copy additional resources
COPY flux-loras /ComfyUI/models/loras
COPY characters /characters
COPY src/base64_encoder.py /base64_encoder.py
ADD src/rp_handler.py /rp_handler.py

# Install additional Python packages
RUN pip install albucore==0.0.16 websocket-client

RUN pip uninstall -y opencv-python opencv-python-headless || true && \
    pip install --no-cache-dir opencv-python-headless

# Cleanup and final setup
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Expose ComfyUI port
EXPOSE 8188

# Set environment variables
ENV COMFYUI_HOST=0.0.0.0
ENV COMFYUI_PORT=8188

# Set permissions and specify the command to run
COPY src/start.sh /start.sh
RUN chmod +x /start.sh
CMD ["/start.sh"]
