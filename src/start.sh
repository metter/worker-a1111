#!/bin/bash

echo "Worker Initiated"

echo "Starting WebUI API"
python3.10 /stable-diffusion-webui/webui.py --skip-python-version-check --skip-torch-cuda-test --no-tests --skip-install --ckpt /model.safetensors --lowram --opt-sdp-attention --disable-safe-unpickle --port 3000 --api --nowebui --skip-version-check  --no-hashing --no-download-sd-model &

echo "Starting RunPod Handler"
python3.10 -u /rp_handler.py
