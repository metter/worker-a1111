#!/bin/bash


echo "Worker Initiated"


echo "Starting WebUI API"
python3 /stable-diffusion-webui/webui.py --skip-python-version-check --skip-torch-cuda-test --skip-install --ckpt /stable-diffusion-webui/model.safetensors --lowram --opt-sdp-attention --disable-safe-unpickle --port 3000 --api --nowebui --skip-version-check --no-hashing --no-download-sd-model --no-half &

echo "Starting RunPod Handler"
python3 -u /rp_handler.py

echo "Script Ended"
