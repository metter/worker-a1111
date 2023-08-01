# ---------------------------------------------------------------------------- #
#                         Stage 1: Download the models                         #
# ---------------------------------------------------------------------------- #
FROM alpine/git:2.36.2 as download

COPY builder/clone.sh /clone.sh

# Clone the repos and clean unnecessary files
RUN . /clone.sh taming-transformers https://github.com/CompVis/taming-transformers.git 24268930bf1dce879235a7fddd0b2355b84d7ea6 && \
    rm -rf data assets **/*.ipynb

RUN . /clone.sh stable-diffusion-stability-ai https://github.com/Stability-AI/stablediffusion.git cf1d67a6fd5ea1aa600c4df58e5b47da45f6bdbf && \
    rm -rf assets data/**/*.png data/**/*.jpg data/**/*.gif

RUN . /clone.sh CodeFormer https://github.com/sczhou/CodeFormer.git c5b4593074ba6214284d6acd5f1719b6c5d739af && \
    rm -rf assets inputs

RUN . /clone.sh BLIP https://github.com/salesforce/BLIP.git 48211a1594f1321b00f14c9f7a5b4813144b2fb9 && \
    . /clone.sh k-diffusion https://github.com/crowsonkb/k-diffusion.git 5b3af030dd83e0297272d861c19477735d0317ec && \
    . /clone.sh clip-interrogator https://github.com/pharmapsychotic/clip-interrogator 2486589f24165c8e3b303f84e9dbbea318df83e8 && \
    . /clone.sh generative-models https://github.com/Stability-AI/generative-models.git

WORKDIR /download
RUN wget -O model.safetensors https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors && ls -la


# ---------------------------------------------------------------------------- #
#                        Stage 2: Clone stable-diffusion-webui                 #
# ---------------------------------------------------------------------------- #
FROM python:3.10.9-slim as clone_webui

# Set the working directory to /stable-diffusion-webui
WORKDIR /stable-diffusion-webui

# Clone the stable-diffusion-webui repository and install its requirements
RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git \
    && cd stable-diffusion-webui \
    && git reset --hard 68f336bd994bed5442ad95bad6b6ad5564a5409a \
    && pip install -r requirements_versions.txt

# ---------------------------------------------------------------------------- #
#                        Stage 3: Build Generative Models                      #
# ---------------------------------------------------------------------------- #
FROM python:3.10.9-slim as generative_models

# Set the working directory to /stable-diffusion-webui/repositories
WORKDIR /stable-diffusion-webui/repositories

# Clone the generative-models repository and install its requirements
RUN git clone https://github.com/Stability-AI/generative-models.git

WORKDIR /stable-diffusion-webui/repositories/generative-models

# Install required packages from pypi inside the virtual environment
RUN python3 -m venv .pt2
RUN . .pt2/bin/activate \
    && pip3 install -r requirements/pt2.txt \
    && pip3 install . \
    && pip3 install -e git+https://github.com/Stability-AI/datapipelines.git@main#egg=sdata \
    && pip install hatch \
    && hatch build -t wheel

# ---------------------------------------------------------------------------- #
#                         Stage 4: Build the final image                        #
# ---------------------------------------------------------------------------- #
FROM python:3.10.9-slim

# Install nano and mc and fish
RUN apt-get update && apt-get install -y nano mc fish && \
    rm -rf /var/lib/apt/lists/*

# Set fish as the default shell for the root user
RUN chsh -s /usr/bin/fish root    

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
    git reset --hard 68f336bd994bed5442ad95bad6b6ad5564a5409a && \
    pip install -r requirements_versions.txt

#copy from download stage
COPY --from=download /repositories/ ${ROOT}/repositories/
COPY --from=download /download/model.safetensors /model.safetensors

# Create a directory for the interrogator data and copy the files
RUN mkdir ${ROOT}/interrogate && cp ${ROOT}/repositories/clip-interrogator/data/* ${ROOT}/interrogate

# Install CodeFormer dependencies
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r ${ROOT}/repositories/CodeFormer/requirements.txt

# Install generative models dependencies
WORKDIR ${ROOT}/repositories/generative-models
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m venv .pt2 \
    && . .pt2/bin/activate \
    && pip3 install -r requirements/pt2.txt \
    && pip3 install . \
    && pip3 install -e git+https://github.com/Stability-AI/datapipelines.git@main#egg=sdata \
    && pip install hatch \
    && hatch build -t wheel    

# Install Python dependencies (Worker Template)
COPY builder/requirements.txt /requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip && \
    pip install --upgrade -r /requirements.txt --no-cache-dir && \
    rm /requirements.txt

# Switch to the specified SHA
ARG SHA=68f336bd994bed5442ad95bad6b6ad5564a5409a 
RUN --mount=type=cache,target=/root/.cache/pip \
    cd stable-diffusion-webui && \
    git fetch && \
    git reset --hard ${SHA} && \
    pip install -r requirements_versions.txt

# Add the source files to the working directory
ADD src .
ADD test_inputs_folder .

# Continue with the rest of the steps
WORKDIR /stable-diffusion-webui

# Activate the virtual environment and install project dependencies
RUN python3 -m venv .pt2
RUN chmod +x .pt2/bin/activate && . .pt2/bin/activate && pip install -r requirements_versions.txt

# Copy the cache.py script and run the cache step
COPY builder/cache.py /stable-diffusion-webui/cache.py
RUN python cache.py --use-cpu=all --ckpt /model.safetensors

WORKDIR /stable-diffusion-webui/extensions

# Clone some extensions
RUN git clone https://github.com/Mikubill/sd-webui-controlnet.git
RUN git clone https://github.com/Extraltodeus/multi-subject-render.git

WORKDIR /

# Copy the models and embeddings directories from the host to the container
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
