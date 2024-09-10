#!/bin/bash

# Start log monitoring for OutOfMemoryError
python -c "from rp_handler import monitor_logs_for_oom; monitor_logs_for_oom()" &

echo "Starting WebUI API"
python /stable-diffusion-webui/webui.py --skip-python-version-check --skip-torch-cuda-test --skip-install --ckpt /stable-diffusion-webui/model.safetensors --opt-sdp-attention --disable-safe-unpickle --port 3000 --api --nowebui --skip-version-check --no-hashing --no-download-sd-model --no-half --xformers &

echo "Starting RunPod Handler"
python -u /rp_handler.py
