# ---------------------------------------------------------------------------- #
#                         Stage 1: Download the models                         #
# ---------------------------------------------------------------------------- #
FROM alpine/git:2.36.2 as download

COPY builder/clone.sh /clone.sh

# Clone the repos and clean unnecessary files
#RUN . /clone.sh taming-transformers https://github.com/CompVis/taming-transformers.git 24268930bf1dce879235a7fddd0b2355b84d7ea6 && \
#    rm -rf data assets **/*.ipynb

RUN . /clone.sh stable-diffusion-stability-ai https://github.com/Stability-AI/stablediffusion.git cf1d67a6fd5ea1aa600c4df58e5b47da45f6bdbf && \
    rm -rf assets data/**/*.png data/**/*.jpg data/**/*.gif

RUN . /clone.sh CodeFormer https://github.com/sczhou/CodeFormer.git c5b4593074ba6214284d6acd5f1719b6c5d739af && \
    rm -rf assets inputs

RUN . /clone.sh BLIP https://github.com/salesforce/BLIP.git 48211a1594f1321b00f14c9f7a5b4813144b2fb9 && \
    . /clone.sh k-diffusion https://github.com/crowsonkb/k-diffusion.git 5b3af030dd83e0297272d861c19477735d0317ec && \
    . /clone.sh clip-interrogator https://github.com/pharmapsychotic/clip-interrogator 2486589f24165c8e3b303f84e9dbbea318df83e8 && \
    . /clone.sh generative-models https://github.com/Stability-AI/generative-models.git 45c443b316737a4ab6e40413d7794a7f5657c19f

WORKDIR /download
RUN wget -O model.safetensors https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors 
RUN wget -O sdxl_vae.safetensors https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors 


# ---------------------------------------------------------------------------- #
#                         Stage 2: Build the final image                       #
# ---------------------------------------------------------------------------- #
FROM python:3.10-buster

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    ROOT=/stable-diffusion-webui \
    PYTHONUNBUFFERED=1 

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root
RUN apt-get update && \
    apt install -y \
    fonts-dejavu-core rsync git jq moreutils aria2 wget libgoogle-perftools-dev procps nano mc fish && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && apt-get clean -y

ENV LD_PRELOAD=libtcmalloc.so  

# Clone the repository
RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git /stable-diffusion-webui

WORKDIR /stable-diffusion-webui

# Reset to the specific commit and install requirements
RUN git reset --hard 5ef669de080814067961f28357256e8fe27544f4 && \
    pip install -r requirements_versions.txt

#copy from download stage
COPY --from=download /repositories/ ${ROOT}/repositories/
COPY --from=download /download/model.safetensors ${ROOT}/model.safetensors
COPY --from=download /download/sdxl_vae.safetensors ${ROOT}/models/Stablediffusion/VAE/sdxl_vae.safetensors

WORKDIR /stable-diffusion-webu
RUN python launch.py --skip-torch-cuda-test --exit

# Cleanup section (Worker Template)
RUN apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

RUN chmod +x /start.sh
CMD /start.sh
