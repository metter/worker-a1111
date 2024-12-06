#!/bin/bash

# Redirect stdout and stderr of this script to /var/log/runpod_handler.log
# exec > /var/log/runpod_handler.log 2>&1

echo "Worker Initiated"

echo "Starting WebUI API"
python /ComfyUI/main.py --listen --port 8188 --disable-auto-launch --verbose &

echo "Starting RunPod Handler"
python -u /rp_handler.py