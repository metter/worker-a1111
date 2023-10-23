#!/bin/bash

echo "Worker Initiated"


echo "Starting WebUI API"
python /stable-diffusion-webui/webui.py --skip-python-version-check --skip-torch-cuda-test --ckpt /stable-diffusion-webui/model.safetensors --vae-path /stable-diffusion-webui/models/VAE/sdxl_vae.safetensors --medvram-sdxl --opt-sdp-attention --disable-safe-unpickle --port 3000 --api --nowebui --skip-version-check --no-half-vae --no-hashing --no-download-sd-model &

echo "Starting RunPod Handler"
python -u /rp_handler.py


   

