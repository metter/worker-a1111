#!/bin/bash

# Start webui.py in the background
python /stable-diffusion-webui/webui.py --no-half --ckpt /stable-diffusion-webui/model.safetensors --api &

# Sleep for 35 seconds
sleep 35

# Kill the Python process
pkill -TERM -f "python /stable-diffusion-webui/webui.py"