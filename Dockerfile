# Use RunPod's base PyTorch image
FROM runpod/pytorch:2.0.1-py3.10-cuda11.8.0-devel-ubuntu22.04

# Use bash shell with pipefail option
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Set the working directory
WORKDIR /

# Update and upgrade the system packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt install -y \
        fonts-dejavu-core rsync nano git jq moreutils aria2 wget mc libgoogle-perftools-dev procps && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && apt-get clean -y

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

# Clone the ControlNet extension into the WebUI's extensions directory
RUN git clone https://github.com/Mikubill/sd-webui-controlnet.git /stable-diffusion-webui/extensions/sd-webui-controlnet && \
    cd /stable-diffusion-webui/extensions/sd-webui-controlnet && \
    # Checkout the specific commit
    git reset --hard 56cec5b2958edf3b1807b7e7b2b1b5186dbd2f81 && \
    # Install ControlNet's Python dependencies
    pip install --upgrade pip && \
    pip install --upgrade -r /stable-diffusion-webui/extensions/sd-webui-controlnet/requirements.txt --no-cache-dir

RUN mkdir -p /stable-diffusion-webui/models/ControlNet
RUN mkdir -p /stable-diffusion-webui/models/Lora /stable-diffusion-webui/extensions/sd-webui-controlnet/annotator/downloads/clip_vision /stable-diffusion-webui/extensions/sd-webui-controlnet/annotator/downloads/insightface/models/buffalo_l

# Download the IP-Adapter FaceID model and place it in the ControlNet models directory
RUN wget -q -O /stable-diffusion-webui/models/ControlNet/ip-adapter-plus-face_sdxl_vit-h.safetensors \
https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus-face_sdxl_vit-h.safetensors

RUN wget -q -O /stable-diffusion-webui/models/ControlNet/ip-adapter_sdxl.safetensors \
https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl.safetensors

RUN wget -q -O /stable-diffusion-webui/models/ControlNet/ip-adapter_sdxl_vit-h.safetensors \
https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl_vit-h.safetensors

RUN wget -q -O /stable-diffusion-webui/models/ControlNet/ip-adapter_xl.pth \
https://huggingface.co/lllyasviel/sd_control_collection/resolve/main/ip-adapter_xl.pth

RUN wget -q -O /stable-diffusion-webui/models/ControlNet/ip-adapter-faceid_sdxl.pth \
https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid_sdxl.bin

RUN wget -q -O /stable-diffusion-webui/models/ControlNet/ip-adapter-faceid-plusv2_sdxl.pth \
https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl.bin

RUN wget -q -O /stable-diffusion-webui/models/Lora/ip-adapter-faceid_sdxl_lora.safetensors \
https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid_sdxl_lora.safetensors

RUN wget -q -O /stable-diffusion-webui/models/Lora/ip-adapter-faceid-plusv2_sdxl_lora.safetensors \
https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl_lora.safetensors

# Download the Openpose model and place it in the ControlNet models directory
RUN wget -q -O /stable-diffusion-webui/models/ControlNet/controlnet-openpose-sdxl-1.0.safetensors \
https://huggingface.co/xinsir/controlnet-openpose-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors

RUN wget -q -O /stable-diffusion-webui/models/ControlNet/controlnet-openpose-sdxl-1.0_twins.safetensors \
https://huggingface.co/xinsir/controlnet-openpose-sdxl-1.0/resolve/main/diffusion_pytorch_model_twins.safetensors

RUN wget -q -O /stable-diffusion-webui/extensions/sd-webui-controlnet/annotator/downloads/clip_vision/clip_h.pth \
https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/pytorch_model.bin

RUN wget -q -O /stable-diffusion-webui/extensions/sd-webui-controlnet/annotator/downloads/insightface/models/buffalo_l/1k3d68.onnx \
https://huggingface.co/public-data/insightface/resolve/main/models/buffalo_l/1k3d68.onnx

RUN wget -q -O /stable-diffusion-webui/extensions/sd-webui-controlnet/annotator/downloads/insightface/models/buffalo_l/2d106det.onnx \
https://huggingface.co/public-data/insightface/resolve/main/models/buffalo_l/2d106det.onnx

RUN wget -q -O /stable-diffusion-webui/extensions/sd-webui-controlnet/annotator/downloads/insightface/models/buffalo_l/det_10g.onnx \
https://huggingface.co/public-data/insightface/resolve/main/models/buffalo_l/det_10g.onnx

RUN wget -q -O /stable-diffusion-webui/extensions/sd-webui-controlnet/annotator/downloads/insightface/models/buffalo_l/genderage.onnx \
https://huggingface.co/public-data/insightface/resolve/main/models/buffalo_l/genderage.onnx

RUN wget -q -O /stable-diffusion-webui/extensions/sd-webui-controlnet/annotator/downloads/insightface/models/buffalo_l/w600k_r50.onnx \
https://huggingface.co/public-data/insightface/resolve/main/models/buffalo_l/w600k_r50.onnx

# Launch the WebUI to finalize setup (this step installs any remaining dependencies)
RUN python /stable-diffusion-webui/launch.py --model /stable-diffusion-webui/model.safetensors --exit --skip-torch-cuda-test --xformers --no-half --reinstall-xformers --reinstall-torch

# RUN pip install --upgrade torchdynamo
RUN pip install protobuf==3.20.3
RUN pip install xformers==0.0.27.post2

# Copy additional resources
COPY loras /stable-diffusion-webui/models/Lora
COPY src/base64_encoder.py /base64_encoder.py
ADD src . 

# Cleanup and final setup
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Set permissions and specify the command to run
RUN chmod +x /start.sh
CMD /start.sh
