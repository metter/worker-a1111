#!/bin/bash

# Redirect stdout and stderr of this script to /var/log/runpod_handler.log
exec > /var/log/runpod_handler.log 2>&1

echo "Worker Initiated"
/papertrail.sh &
echo "papertrail initialised"

echo "Starting WebUI API"
python /stable-diffusion-webui/webui.py --skip-python-version-check --skip-torch-cuda-test --skip-install --ckpt /model.safetensors --lowram --opt-sdp-attention --disable-safe-unpickle --port 3000 --api --nowebui --skip-version-check  --no-hashing --no-half --no-download-sd-model &

echo "Starting RunPod Handler"
python -u /rp_handler.py
