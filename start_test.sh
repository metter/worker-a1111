#!/bin/bash

# Kill any process running on port 3000
echo "Killing any process running on port 3000..."
lsof -t -i :3000 | xargs -r kill -9

# Wait for the processes to be terminated
sleep 2

# Start the WebUI API
echo "Starting WebUI API"
# python stable-diffusion-webui-forge/webui.py --listen --skip-python-version-check --skip-torch-cuda-test --skip-install --ckpt stable-diffusion-webui/model.safetensors --opt-sdp-attention --disable-safe-unpickle --port 3000 --api --skip-version-check --no-hashing --no-download-sd-model --no-half --medvram --xformers &
python stable-diffusion-webui-forge/webui.py --listen --port 3000 --api --ckpt stable-diffusion-webui-forge/model.safetensors --no-half --medvram --xformers &
