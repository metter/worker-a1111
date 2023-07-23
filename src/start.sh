#!/bin/bash

echo "Worker Initiated"

echo "Starting WebUI API"
python /stable-diffusion-webui/webui.py --skip-python-version-check --skip-torch-cuda-test --no-tests --skip-install --ckpt /models/Stabel-diffusion/sdxl_0.9/stable-diffusion-xl-base-0.9/sd_xl_base_0.9.safetensors --lowram --opt-sdp-attention --disable-safe-unpickle --port 3000 --api --nowebui --skip-version-check  --no-hashing --no-download-sd-model &

echo "Starting RunPod Handler"
python -u /rp_handler.py
