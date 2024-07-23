#!/bin/bash

# Set the Python environment
export PYTHON=python3
export PYTHONUNBUFFERED=1

# Install dependencies
pip install -r requirements.txt
pip install -r requirements_versions.txt

# Run the launch script to install A1111 and its dependencies
python3 launch.py --skip-torch-cuda-test --skip-python-version-check --ckpt /stable-diffusion-webui/model.safetensors --no-half --no-half-vae --no-download-sd-model --exit

# Apply the patch for torchvision
sed -i 's/from torchvision.transforms.functional_tensor import rgb_to_grayscale/from torchvision.transforms.functional import rgb_to_grayscale/' /usr/local/lib/python3.10/site-packages/basicsr/data/degradations.py

echo "A1111 installation completed."