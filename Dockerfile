# Use RunPod's base PyTorch image
FROM runpod/pytorch:2.0.1-py3.10-cuda11.8.0-devel-ubuntu22.04

# Use bash shell with pipefail option
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Set the working directory
WORKDIR /

# Set CUDA environment variables
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}
ENV PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python

# Update and upgrade the system packages (including CUDA-related packages)
RUN apt-get update && \
    apt-get upgrade -y && \
    apt install -y \
        fonts-dejavu-core rsync nano git jq moreutils aria2 wget mc \
        libgoogle-perftools-dev procps \
        cuda-toolkit-11-8 \
        libcudnn8 \
        libcudnn8-dev \
        python3-libnvinfer \
        python3-libnvinfer-dev && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && apt-get clean -y

# Install optimization packages (inference-focused)
RUN pip install --no-cache-dir \
    ninja \
    triton \
    cuda-python \
    onnx \
    onnxruntime-gpu \
    tensorrt \
    protobuf==3.20.3

# Clone the specific version of AUTOMATIC1111 Stable Diffusion WebUI
RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cd stable-diffusion-webui && \
    git reset --hard 82a973c04367123ae98bd9abdf80d9eda9b910e2

RUN wget -q -O /stable-diffusion-webui/model.safetensors \
    https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors

# Install Python dependencies
COPY builder/requirements.txt /requirements.txt
RUN pip install --upgrade pip && \
    pip install --upgrade -r /requirements.txt --no-cache-dir && \
    rm /requirements.txt

# Set up the model
RUN cd /stable-diffusion-webui && \
    pip install --upgrade pip && \
    pip install --upgrade -r requirements.txt --no-cache-dir

# Clone the ControlNet extension
RUN git clone https://github.com/Mikubill/sd-webui-controlnet.git /stable-diffusion-webui/extensions/sd-webui-controlnet && \
    cd /stable-diffusion-webui/extensions/sd-webui-controlnet && \
    git reset --hard 56cec5b2958edf3b1807b7e7b2b1b5186dbd2f81 && \
    pip install --upgrade pip && \
    pip install --upgrade -r /stable-diffusion-webui/extensions/sd-webui-controlnet/requirements.txt --no-cache-dir

# Create necessary directories
RUN mkdir -p /stable-diffusion-webui/models/ControlNet && \
    mkdir -p /stable-diffusion-webui/models/Lora && \
    mkdir -p /stable-diffusion-webui/extensions/sd-webui-controlnet/annotator/downloads/clip_vision && \
    mkdir -p /stable-diffusion-webui/extensions/sd-webui-controlnet/annotator/downloads/insightface/models/buffalo_l && \
    mkdir -p /stable-diffusion-webui/models/VAE-approx

# Download VAE model
RUN wget -q -O /stable-diffusion-webui/models/VAE-approx/vaeapprox-sdxl.pt \
    https://huggingface.co/ashleykleynhans/a1111-models/resolve/main/VAE-approx/vaeapprox-sdxl.pt

# Download IP-Adapter models
RUN wget -q -O /stable-diffusion-webui/models/ControlNet/ip-adapter-plus-face_sdxl_vit-h.safetensors \
    https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus-face_sdxl_vit-h.safetensors && \
    wget -q -O /stable-diffusion-webui/models/ControlNet/ip-adapter_sdxl.safetensors \
    https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl.safetensors && \
    wget -q -O /stable-diffusion-webui/models/ControlNet/ip-adapter_sdxl_vit-h.safetensors \
    https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl_vit-h.safetensors && \
    wget -q -O /stable-diffusion-webui/models/ControlNet/ip-adapter_xl.pth \
    https://huggingface.co/lllyasviel/sd_control_collection/resolve/main/ip-adapter_xl.pth && \
    wget -q -O /stable-diffusion-webui/models/ControlNet/ip-adapter-faceid_sdxl.pth \
    https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid_sdxl.bin && \
    wget -q -O /stable-diffusion-webui/models/ControlNet/ip-adapter-faceid-plusv2_sdxl.pth \
    https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl.bin

# Download Lora models
RUN wget -q -O /stable-diffusion-webui/models/Lora/ip-adapter-faceid_sdxl_lora.safetensors \
    https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid_sdxl_lora.safetensors && \
    wget -q -O /stable-diffusion-webui/models/Lora/ip-adapter-faceid-plusv2_sdxl_lora.safetensors \
    https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl_lora.safetensors

# Download Openpose models
RUN wget -q -O /stable-diffusion-webui/models/ControlNet/controlnet-openpose-sdxl-1.0.safetensors \
    https://huggingface.co/xinsir/controlnet-openpose-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors && \
    wget -q -O /stable-diffusion-webui/models/ControlNet/controlnet-openpose-sdxl-1.0_twins.safetensors \
    https://huggingface.co/xinsir/controlnet-openpose-sdxl-1.0/resolve/main/diffusion_pytorch_model_twins.safetensors

# Download additional models and files
RUN wget -q -O /stable-diffusion-webui/extensions/sd-webui-controlnet/annotator/downloads/clip_vision/clip_h.pth \
    https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/pytorch_model.bin

# Download InsightFace models
RUN wget -q -O /stable-diffusion-webui/extensions/sd-webui-controlnet/annotator/downloads/insightface/models/buffalo_l/1k3d68.onnx \
    https://huggingface.co/public-data/insightface/resolve/main/models/buffalo_l/1k3d68.onnx && \
    wget -q -O /stable-diffusion-webui/extensions/sd-webui-controlnet/annotator/downloads/insightface/models/buffalo_l/2d106det.onnx \
    https://huggingface.co/public-data/insightface/resolve/main/models/buffalo_l/2d106det.onnx && \
    wget -q -O /stable-diffusion-webui/extensions/sd-webui-controlnet/annotator/downloads/insightface/models/buffalo_l/det_10g.onnx \
    https://huggingface.co/public-data/insightface/resolve/main/models/buffalo_l/det_10g.onnx && \
    wget -q -O /stable-diffusion-webui/extensions/sd-webui-controlnet/annotator/downloads/insightface/models/buffalo_l/genderage.onnx \
    https://huggingface.co/public-data/insightface/resolve/main/models/buffalo_l/genderage.onnx && \
    wget -q -O /stable-diffusion-webui/extensions/sd-webui-controlnet/annotator/downloads/insightface/models/buffalo_l/w600k_r50.onnx \
    https://huggingface.co/public-data/insightface/resolve/main/models/buffalo_l/w600k_r50.onnx

RUN python -c "import torch; print(torch.__version__)" && \
    pip install xformers==0.0.28.post3 --index-url https://download.pytorch.org/whl/cu124
    
    # Launch WebUI with optimization flags
RUN python /stable-diffusion-webui/launch.py \
    --ckpt /stable-diffusion-webui/model.safetensors \
    --exit \
    --skip-torch-cuda-test \
    --xformers \
    --no-half \
    --opt-split-attention \
    --opt-channelslast \
    --opt-sdp-attention
   # --reinstall-torch

# Verify CUDA installation
RUN python -c "import torch; print('CUDA available:', torch.cuda.is_available()); print('CUDA version:', torch.version.cuda)"

# Copy additional resources
COPY loras /stable-diffusion-webui/models/Lora
COPY src/base64_encoder.py /base64_encoder.py
ADD src .

# Cleanup
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Set permissions and specify the command to run
RUN chmod +x /start.sh
CMD /start.sh