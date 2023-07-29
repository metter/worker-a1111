# ---------------------------------------------------------------------------- #
#                         Stage 1: Download the models                         #
# ---------------------------------------------------------------------------- #
FROM alpine/git:2.36.2 as download

COPY builder/clone.sh /clone.sh

# Clone the repos and clean unnecessary files
RUN . /clone.sh taming-transformers https://github.com/CompVis/taming-transformers.git  && \
    rm -rf data assets **/*.ipynb

RUN . /clone.sh stable-diffusion-stability-ai https://github.com/Stability-AI/stablediffusion.git && \
    rm -rf assets data/**/*.png data/**/*.jpg data/**/*.gif

RUN . /clone.sh CodeFormer https://github.com/sczhou/CodeFormer.git  && \
    rm -rf assets inputs

RUN . /clone.sh BLIP https://github.com/salesforce/BLIP.git  && \
    . /clone.sh k-diffusion https://github.com/crowsonkb/k-diffusion.git  && \
    . /clone.sh clip-interrogator https://github.com/pharmapsychotic/clip-interrogator 

# Clone and clean the Generative Models repository
RUN . /clone.sh generative-models https://github.com/Stability-AI/generative-models.git  && \
    rm -rf data assets **/*.ipynb    

# RUN wget -O model.safetensors https://civitai.com/api/download/models/15236 

# ---------------------------------------------------------------------------- #
#                        Stage 3: Build the final image                        #
# ---------------------------------------------------------------------------- #
FROM python:3.10.9-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    LD_PRELOAD=libtcmalloc.so \
    ROOT=/stable-diffusion-webui \
    PYTHONUNBUFFERED=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && \
    apt install -y \
    fonts-dejavu-core rsync git jq moreutils aria2 wget libgoogle-perftools-dev procps && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && apt-get clean -y

RUN --mount=type=cache,target=/cache --mount=type=cache,target=/root/.cache/pip \
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

RUN --mount=type=cache,target=/root/.cache/pip \
    git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cd stable-diffusion-webui && \
    pip install -r requirements_versions.txt

COPY --from=download /repositories/ ${ROOT}/repositories/
#COPY --from=download /model.safetensors /model.safetensors

# Install the Generative Models repository's requirements and the repository itself
WORKDIR ${ROOT}/repositories/generative-models
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m venv .pt13 \
    && source .pt13/bin/activate \
    && pip install -r requirements/pt13.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m venv .pt2 \
    && source .pt2/bin/activate \
    && pip install -r requirements/pt2.txt
RUN pip install .

# Install sdata for training
RUN pip install -e git+https://github.com/Stability-AI/datapipelines.git@main#egg=sdata



COPY /sd_xl_base_1.0.safetensors /model.safetensors
RUN mkdir -p ${ROOT}/interrogate && cp -r ${ROOT}/repositories/clip-interrogator/clip_interrogator/data/. ${ROOT}/interrogate || true
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r ${ROOT}/repositories/CodeFormer/requirements.txt

# Install Python dependencies (Worker Template)
COPY builder/requirements.txt /requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip && \
    pip install --upgrade -r /requirements.txt --no-cache-dir && \
    rm /requirements.txt

RUN --mount=type=cache,target=/root/.cache/pip \
    cd stable-diffusion-webui && \
    git fetch && \
    git checkout dev && \
    pip install -r requirements_versions.txt    

ADD src .

COPY builder/cache.py /stable-diffusion-webui/cache.py
RUN cd /stable-diffusion-webui && python cache.py --use-cpu=all --ckpt /model.safetensors

WORKDIR /extensions
RUN git clone https://github.com/Mikubill/sd-webui-controlnet.git
RUN git clone https://github.com/Extraltodeus/multi-subject-render.git

WORKDIR /

# Copy the models and embeddings directories from the host to the container
COPY test_input.json /
COPY models/Lora /stable-diffusion-webui/models/Lora
COPY models/ControlNet /stable-diffusion-webui/models/ControlNet
COPY models/openpose /stable-diffusion-webui/models/openpose
COPY embeddings /stable-diffusion-webui/embeddings

# Cleanup section (Worker Template)
RUN apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

RUN chmod +x /start.sh
CMD /start.sh
