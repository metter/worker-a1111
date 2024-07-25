#!/bin/bash

# Redirect stdout and stderr of this script to /var/log/runpod_handler.log
# exec > /var/log/runpod_handler.log 2>&1

echo "Worker Initiated"
/papertrail.sh &
echo "papertrail initialised"

echo "Starting WebUI API"
python3 /stable-diffusion-webui/webui.py --skip-python-version-check --skip-torch-cuda-test --skip-install --ckpt /stable-diffusion-webui/model.safetensors --lowram --opt-sdp-attention --disable-safe-unpickle --port 3000 --api --nowebui --skip-version-check  --no-hashing --no-half --no-download-sd-model 2>&1 | tee /var/log/webui_api.log &

echo "Starting RunPod Handler"
python3 -u /rp_handler.py