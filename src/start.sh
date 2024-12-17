#!/bin/bash

echo "Worker Initiated"

echo "Starting WebUI API"
python /ComfyUI/main.py --listen --port 8188 --disable-auto-launch &

echo "Starting RunPod Handler"
python -u /rp_handler.py

echo "RunPod Handler has exited"