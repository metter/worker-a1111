#!/bin/bash

# Navigate to the ComfyUI directory
cd /ComfyUI || { echo "ComfyUI directory not found!"; exit 1; }

# Start ComfyUI in the background
python main.py --cpu --disable-auto-launch --verbose &

# Get the process ID of the last command run in the background
COMFYUI_PID=$!

# Wait for 20 seconds
sleep 20

# Shut down ComfyUI
kill $COMFYUI_PID

echo "ComfyUI started and stopped successfully."
