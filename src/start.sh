#!/bin/bash

# Redirect all output to stdout and stderr
exec > >(tee /dev/fd/1) 2>&1

echo "Worker Initiated"

echo "Starting WebUI API"
# Start ComfyUI in background with explicit output redirection
python /ComfyUI/main.py --listen --port 8188 --disable-auto-launch 2>&1 &

echo "Starting RunPod Handler"
# Start handler in foreground with explicit output redirection
python -u /rp_handler.py 2>&1

echo "RunPod Handler has exited"