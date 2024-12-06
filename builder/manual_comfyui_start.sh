#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name: manual_start_comfyui.sh
# Description: Manually starts ComfyUI, binding it to all network interfaces
#              (0.0.0.0) to make it accessible externally.
# Usage:        ./manual_start_comfyui.sh
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status
set -e

# ----------------------------- Configuration ---------------------------------

# **ComfyUI Directory**
# Replace this with the path to your ComfyUI installation directory.
COMFYUI_DIR="/ComfyUI"

# **Python Executable**
# Specify the Python executable to use. If using a virtual environment, ensure
# that it points to the Python within the virtual environment.
PYTHON_EXEC="python"

# **Additional Python Options**
# Add any additional Python options or environment variables if necessary.
# For example, to set the number of threads:
# PYTHON_OPTS="--threads 4"
PYTHON_OPTS=""

# **ComfyUI Start Command**
# The command to start ComfyUI. Adjust the port if necessary.
COMFYUI_CMD="main.py --host 0.0.0.0 --port 8188"

# -----------------------------------------------------------------------------

# --------------------------- Function Definitions ----------------------------

# Function to display script usage
usage() {
    echo "Usage: $0 [--comfyui-dir DIR] [--python-exec PYTHON] [--port PORT]"
    echo
    echo "Options:"
    echo "  --comfyui-dir DIR    Path to ComfyUI installation directory (default: $COMFYUI_DIR)"
    echo "  --python-exec PYTHON  Python executable to use (default: $PYTHON_EXEC)"
    echo "  --port PORT          Port to run ComfyUI on (default: 8188)"
    echo "  -h, --help           Display this help message"
    exit 1
}

# Function to parse command-line arguments
parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --comfyui-dir)
                COMFYUI_DIR="$2"
                shift 2
                ;;
            --python-exec)
                PYTHON_EXEC="$2"
                shift 2
                ;;
            --port)
                PORT="$2"
                COMFYUI_CMD="main.py --host 0.0.0.0 --port $2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Unknown parameter passed: $1"
                usage
                ;;
        esac
    done
}

# ----------------------------- Argument Parsing ------------------------------

# Parse the command-line arguments
parse_args "$@"

# --------------------------- Pre-flight Checks -------------------------------

# Check if the ComfyUI directory exists
if [ ! -d "$COMFYUI_DIR" ]; then
    echo "Error: ComfyUI directory '$COMFYUI_DIR' does not exist."
    exit 1
fi

# Check if the Python executable exists
if ! command -v "$PYTHON_EXEC" &> /dev/null; then
    echo "Error: Python executable '$PYTHON_EXEC' not found."
    exit 1
fi

# ----------------------------- Start ComfyUI ---------------------------------

echo "Starting ComfyUI..."
echo "Directory: $COMFYUI_DIR"
echo "Python Executable: $PYTHON_EXEC"
echo "Command: $PYTHON_EXEC $PYTHON_OPTS $COMFYUI_CMD"

# Navigate to the ComfyUI directory
cd "$COMFYUI_DIR"

# Activate virtual environment if it exists
if [ -f "venv/bin/activate" ]; then
    echo "Activating virtual environment..."
    source venv/bin/activate
fi

# Start ComfyUI
exec "$PYTHON_EXEC" $PYTHON_OPTS $COMFYUI_CMD
