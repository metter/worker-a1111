#!/bin/bash

# Add debugging statements
echo "Debug: Current directory: $(pwd)"
echo "Debug: Contents of current directory:"
ls -l

# Start webui.py in the background
python /stable-diffusion-webui/webui.py --no-half --ckpt /stable-diffusion-webui/model.safetensors --api --skip-python-version-check --skip-torch-cuda-test --skip-version-check --no-half-vae --no-hashing &

# Sleep for 35 seconds
echo "Debug: Sleeping for 35 seconds..."
sleep 35

# Kill the Python process
echo "Debug: Killing the Python process..."
pkill -TERM -f "python /stable-diffusion-webui/webui.py"
