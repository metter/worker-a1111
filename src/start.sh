#!/bin/bash

# Redirect stdout and stderr of this script to /var/log/runpod_handler.log
# exec > /var/log/runpod_handler.log 2>&1

echo "Worker Initiated"
/papertrail.sh &
echo "papertrail initialised"

echo "Starting WebUI API"
python /stable-diffusion-webui/webui.py --skip-python-version-check --skip-torch-cuda-test --skip-install --ckpt /stable-diffusion-webui/model.safetensors --opt-sdp-attention --disable-safe-unpickle --port 3000 --api --nowebui --skip-version-check --no-hashing --no-download-sd-model --no-half --xformers --opt-channelslast &

echo "Starting RunPod Handler"
python -u /rp_handler.py
