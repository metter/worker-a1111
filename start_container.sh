#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name: start_container.sh
# Description: Runs the ComfyUI Docker container with GPU support, exposes
#              necessary ports, and overrides the default start command.
# Usage:        ./start_container.sh
# -----------------------------------------------------------------------------

# ----------------------------- Configuration ---------------------------------

# **Docker Image Name**
# Replace this with the name/tag of your Docker image.
IMAGE_NAME="comfyui-flux-fast-dev"

# **Docker Container Name**
# Choose a name for your running container.
CONTAINER_NAME="comfyui-flux"

# **Port Configuration**
# Host port to access ComfyUI (e.g., http://localhost:8188)
HOST_PORT=8188

# Container port where ComfyUI is running.
CONTAINER_PORT=8188

# **Override Start Command**
# Specify the command to override the Docker image's default CMD.
# Example: Running the existing start.sh script with additional arguments.
# You can modify this as per your requirements.
OVERRIDE_CMD="/start.sh"

# -----------------------------------------------------------------------------

# Function to display script usage
usage() {
    echo "Usage: $0 [--image IMAGE_NAME] [--name CONTAINER_NAME] [--host-port HOST_PORT] [--container-port CONTAINER_PORT] [--cmd OVERRIDE_CMD]"
    echo
    echo "Options:"
    echo "  --image          Docker image name (default: $IMAGE_NAME)"
    echo "  --name           Docker container name (default: $CONTAINER_NAME)"
    echo "  --host-port      Host port to map (default: $HOST_PORT)"
    echo "  --container-port Container port to map (default: $CONTAINER_PORT)"
    echo "  --cmd            Override start command (default: $OVERRIDE_CMD)"
    echo "  -h, --help       Display this help message"
    exit 1
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --image) IMAGE_NAME="$2"; shift ;;
        --name) CONTAINER_NAME="$2"; shift ;;
        --host-port) HOST_PORT="$2"; shift ;;
        --container-port) CONTAINER_PORT="$2"; shift ;;
        --cmd) OVERRIDE_CMD="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# ----------------------------- Pre-flight Checks ----------------------------

# Check if Docker is installed
if ! command -v docker &> /dev/null
then
    echo "Error: Docker is not installed. Please install Docker to proceed."
    exit 1
fi

# Check if NVIDIA Docker runtime is available
if ! docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi &> /dev/null
then
    echo "Error: NVIDIA Docker runtime not found or GPU drivers not installed."
    echo "Ensure that NVIDIA drivers and Docker's NVIDIA runtime are correctly installed."
    exit 1
fi

# ----------------------------- Container Management --------------------------

# Check if a container with the same name already exists
if [ "$(docker ps -a -q -f name=^/${CONTAINER_NAME}$)" ]; then
    echo "A container named '${CONTAINER_NAME}' already exists."
    
    # Prompt the user to decide whether to remove it
    read -p "Do you want to stop and remove the existing container? (y/N): " choice
    case "$choice" in 
      y|Y ) 
          docker stop ${CONTAINER_NAME}
          docker rm ${CONTAINER_NAME}
          echo "Existing container '${CONTAINER_NAME}' has been stopped and removed."
          ;;
      * ) 
          echo "Exiting without starting a new container."
          exit 0
          ;;
    esac
fi

# ----------------------------- Run the Container ------------------------------

echo "Starting Docker container '${CONTAINER_NAME}' from image '${IMAGE_NAME}'..."
docker run -d \
    --gpus all \
    --name ${CONTAINER_NAME} \
    -p ${HOST_PORT}:${CONTAINER_PORT} \
    ${IMAGE_NAME} \
    ${OVERRIDE_CMD}

# ----------------------------- Post-run Verification --------------------------

# Wait for a few seconds to allow the container to initialize
sleep 5

# Check if the container is running
if [ "$(docker ps -q -f name=^/${CONTAINER_NAME}$)" ]; then
    echo "Container '${CONTAINER_NAME}' is running."
    echo "Access ComfyUI at http://localhost:${HOST_PORT}"
else
    echo "Failed to start container '${CONTAINER_NAME}'. Check Docker logs for details."
    exit 1
fi
