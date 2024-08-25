#!/bin/bash

# Define the file paths and URL
FILE_PATH="/builder/model.safetensors"
TARGET_PATH="/stable-diffusion-webui/model.safetensors"
DOWNLOAD_URL="https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors"

# Create the target directory if it does not exist
mkdir -p "$(dirname "$TARGET_PATH")"

# Check if the file already exists in the builder folder
if [ -f "$FILE_PATH" ]; then
    echo "File already exists in the builder folder. Copying to target path..."
    cp "$FILE_PATH" "$TARGET_PATH"
else
    echo "File does not exist in the builder folder. Downloading..."
    # Create the builder directory if it does not exist
    mkdir -p "$(dirname "$FILE_PATH")"
    wget -q -O "$FILE_PATH" "$DOWNLOAD_URL"
    # Now copy the downloaded file to the target path
    cp "$FILE_PATH" "$TARGET_PATH"
fi
