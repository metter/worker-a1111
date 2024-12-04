# Use RunPod's base PyTorch image
FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

# Use bash shell with pipefail option
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Set the working directory
WORKDIR /

# Update and upgrade the system packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt install -y \
        fonts-dejavu-core rsync nano git jq moreutils aria2 wget mc libgoogle-perftools-dev procps cmake make

# Clone the specific version of Forge Stable Diffusion WebUI
RUN git clone https://github.com/lllyasviel/stable-diffusion-webui-forge.git && \
    cd stable-diffusion-webui-forge && \
    git reset --hard bae1bba891508f9970f72edd7a70336a54557dc1

# Install Python dependencies
COPY builder/requirements.txt /requirements.txt
RUN pip install --upgrade pip && \
    pip install --upgrade -r /requirements.txt --no-cache-dir && \
    rm /requirements.txt

RUN mkdir -p /stable-diffusion-webui-forge/models/ControlNet
RUN mkdir -p /stable-diffusion-webui-forge/models/Lora
RUN mkdir -p /stable-diffusion-webui-forge/models/ControlNetPreprocessor/openpose

RUN wget -q -O /stable-diffusion-webui-forge/model.safetensors \
https://huggingface.co/lllyasviel/flux1-dev-bnb-nf4/resolve/main/flux1-dev-bnb-nf4-v2.safetensors

RUN wget -q -O /stable-diffusion-webui-forge/models/ControlNetPreprocessor/openpose/body_pose_model.pth \
https://huggingface.co/lllyasviel/Annotators/resolve/main/body_pose_model.pth

RUN wget -q -O /stable-diffusion-webui-forge/models/ControlNetPreprocessor/openpose/hand_pose_model.pth \
https://huggingface.co/lllyasviel/Annotators/resolve/main/hand_pose_model.pth

RUN wget -q -O /stable-diffusion-webui-forge/models/ControlNetPreprocessor/openpose/facenet.pth \
https://huggingface.co/lllyasviel/Annotators/resolve/main/facenet.pth

# Launch the WebUI to finalize setup (this step installs any remaining dependencies)
RUN python /stable-diffusion-webui-forge/launch.py --model /stable-diffusion-webui-forge/model.safetensors --exit --skip-torch-cuda-test --xformers --no-half --reinstall-xformers

# Copy additional resources
COPY loras /stable-diffusion-webui-forge/models/Lora
COPY src/base64_encoder.py /base64_encoder.py
ADD src . 

# Cleanup and final setup
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Set permissions and specify the command to run
RUN chmod +x /start.sh
CMD /start.sh
