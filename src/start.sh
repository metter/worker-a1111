#!/bin/bash

echo "Worker Initiated"

while true; do
    #echo "Starting WebUI API"
    #python /stable-diffusion-webui/webui.py --skip-python-version-check --skip-torch-cuda-test --ckpt /stable-diffusion-webui/model.safetensors --lowram --opt-sdp-attention --disable-safe-unpickle --port 3000 --api --nowebui --skip-version-check  --no-hashing --no-download-sd-model &

    #echo "Starting RunPod Handler"
    #python -u /rp_handler.py

    # Sleep for a while before restarting the loop
    sleep 5  # You can adjust the sleep duration as needed
done
