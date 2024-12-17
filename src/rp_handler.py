import sys
import runpod
import json
import requests
import uuid
import base64
import logging
import os
import time
from io import BytesIO
from PIL import Image
import websocket
from runpod.serverless.utils import rp_logger

COMFY_HOST = "127.0.0.1:8188"
COMFY_API_AVAILABLE_INTERVAL_MS = 50
COMFY_API_AVAILABLE_MAX_RETRIES = 500
COMFY_POLLING_INTERVAL_MS = int(os.environ.get("COMFY_POLLING_INTERVAL_MS", 250))
COMFY_POLLING_MAX_RETRIES = int(os.environ.get("COMFY_POLLING_MAX_RETRIES", 500))
COMFY_OUTPUT_PATH = os.environ.get("COMFY_OUTPUT_PATH", "/ComfyUI/output")

def safe_log_data(data, max_length=100):
    """Safely log data by truncating potential base64 strings."""
    if isinstance(data, dict):
        safe_dict = {}
        for k, v in data.items():
            if isinstance(v, str) and len(v) > max_length and ('base64' in k.lower() or ';base64,' in v):
                safe_dict[k] = f"<base64_data length={len(v)}>"
            else:
                safe_dict[k] = safe_log_data(v, max_length)
        return safe_dict
    elif isinstance(data, list):
        return [safe_log_data(item, max_length) for item in data]
    elif isinstance(data, str) and len(data) > max_length and ';base64,' in data:
        return f"<base64_data length={len(data)}>"
    return data

def check_server(url, retries=500, delay=50):
    for i in range(retries):
        try:
            response = requests.get(url)
            if response.status_code == 200:
                rp_logger.info("ComfyUI API is reachable")
                return True
        except requests.RequestException as e:
            rp_logger.warning(f"Attempt {i+1}/{retries}: Server not ready. Error: {str(e)}")
        time.sleep(delay / 1000)
    rp_logger.error(f"Failed to connect to server at {url} after {retries} attempts.")
    return False

def upload_images(images):
    if not images:
        return {"status": "success", "message": "No images to upload", "details": []}

    responses = []
    upload_errors = []

    rp_logger.info("Uploading image(s)")

    for image in images:
        name = image["name"]
        image_data = image["image"]
        blob = base64.b64decode(image_data)

        files = {
            "image": (name, BytesIO(blob), "image/png"),
            "overwrite": (None, "true"),
        }

        response = requests.post(f"http://{COMFY_HOST}/upload/image", files=files)
        if response.status_code != 200:
            upload_errors.append(f"Error uploading {name}: {response.text}")
        else:
            responses.append(f"Successfully uploaded {name}")

    if upload_errors:
        rp_logger.error("Image(s) upload completed with errors")
        return {
            "status": "error",
            "message": "Some images failed to upload",
            "details": upload_errors,
        }

    rp_logger.info("Image(s) upload completed successfully")
    return {
        "status": "success",
        "message": "All images uploaded successfully",
        "details": responses,
    }

def queue_prompt(workflow, client_id):
    rp_logger.info("Queuing prompt")

    payload = {
        "prompt": workflow,
        "client_id": client_id
    }
    
    response = requests.post(f"http://{COMFY_HOST}/prompt", json=payload)
    rp_logger.info(f"Queue Response: {response.text}")
    
    result = response.json()
    if 'prompt_id' not in result:
        rp_logger.error(f"Invalid response format: {result}")
        raise ValueError("No prompt_id in response")
    
    prompt_id = result['prompt_id']
    queue_position = result.get('number', 0)
    rp_logger.info(f"Prompt queued with ID: {prompt_id} at position: {queue_position}")
    
    return prompt_id

def get_history(prompt_id):
    rp_logger.info(f"=== HISTORY REQUEST START for {prompt_id} ===")
    response = requests.get(f"http://{COMFY_HOST}/history/{prompt_id}")
    rp_logger.info(f"Status Code: {response.status_code}")
    rp_logger.info(f"Raw History Response: {response.text}")
    rp_logger.info("=== HISTORY REQUEST END ===")
    return response.json()

def wait_for_job_complete(prompt_id, client_id):
    rp_logger.info(f"Waiting for job completion: {prompt_id}")
    ws = None
    try:
        ws = setup_websocket(client_id)
        
        while True:
            out = ws.recv()
            if isinstance(out, str):
                message = json.loads(out)
                rp_logger.debug(f"WebSocket message: {message}")

                if message.get('type') == 'executing':
                    data = message.get('data', {})
                    if data.get('prompt_id') == prompt_id:
                        if data.get('node') is None:
                            # Execution is complete
                            break
                        else:
                            rp_logger.info(f"Executing node: {data['node']}")
            else:
                # Binary data (preview images)
                rp_logger.debug("Received binary preview data")
                continue

        # Get the final results from history
        history = get_history(prompt_id)
        if prompt_id in history and 'outputs' in history[prompt_id]:
            return history[prompt_id]['outputs']
        else:
            raise ValueError("Prompt not found in history after completion")

    except Exception as e:
        rp_logger.error(f"WebSocket error: {str(e)}", exc_info=True)
        raise
    finally:
        if ws:
            ws.close()

def process_output_images(outputs):
    rp_logger.info("Starting to process output images.")
    rp_logger.debug(f"Received outputs: {outputs}")
    results = {}
    
    # Log the contents of COMFY_OUTPUT_PATH
    try:
        rp_logger.info(f"Listing contents of COMFY_OUTPUT_PATH: {COMFY_OUTPUT_PATH}")
        output_files = os.listdir(COMFY_OUTPUT_PATH)
        rp_logger.info(f"Files in '{COMFY_OUTPUT_PATH}': {output_files}")
    except Exception as e:
        rp_logger.error(f"Failed to list contents of {COMFY_OUTPUT_PATH}: {str(e)}")
        raise
    
    # Iterate over all nodes in outputs
    for node_id, node_output in outputs.items():
        rp_logger.debug(f"Processing node ID: {node_id}")
        # Check if this node has images
        if "images" in node_output and node_output["images"]:
            rp_logger.info(f"Node {node_id} contains images: {node_output['images']}")
            for image in node_output["images"]:
                subfolder = image.get("subfolder", "")
                filename = image.get("filename", "")
                image_path = os.path.join(COMFY_OUTPUT_PATH, subfolder, filename)
                rp_logger.debug(f"Constructed image path: {image_path}")
                
                # Log existence of the image file
                if not os.path.exists(image_path):
                    rp_logger.error(f"Image not found at path: {image_path}")
                    continue
                else:
                    rp_logger.info(f"Image found at path: {image_path}")
                
                # Optional: Wait briefly to ensure the file is fully written
                time.sleep(0.5)
                
                # Attempt to open and read the image file
                try:
                    with open(image_path, "rb") as f:
                        image_data = f.read()
                        encoded_image = base64.b64encode(image_data).decode('utf-8')
                        results[node_id] = encoded_image
                        rp_logger.info(f"Successfully processed image: {image_path}")
                except Exception as e:
                    rp_logger.error(f"Error reading image {image_path}: {str(e)}")
        
        # If the node output doesn't contain images but maybe has a direct base64 "data" field
        elif "data" in node_output:
            rp_logger.info(f"Node {node_id} contains direct data.")
            data = node_output["data"]
            if isinstance(data, str) and ";base64," in data:
                # Assuming data is a base64 string prefixed with metadata
                try:
                    # Optionally, you can split the metadata if needed
                    base64_data = data.split(";base64,")[-1]
                    # Validate if it's a proper base64 string
                    if len(base64_data) % 4 != 0:
                        base64_data += "=" * (4 - len(base64_data) % 4)
                    # Attempt to decode to ensure it's valid
                    base64.b64decode(base64_data)
                    results[node_id] = base64_data
                    rp_logger.info(f"Successfully processed base64 data for node {node_id}.")
                except Exception as e:
                    rp_logger.error(f"Invalid base64 data in node {node_id}: {str(e)}")
            else:
                # If data is already a pure base64 string
                try:
                    base64.b64decode(data)
                    results[node_id] = data
                    rp_logger.info(f"Successfully processed base64 data for node {node_id}.")
                except Exception as e:
                    rp_logger.error(f"Invalid base64 data in node {node_id}: {str(e)}")
        else:
            rp_logger.warning(f"Node {node_id} does not contain images or data.")
    
    # Final check to ensure some images were processed
    if not results:
        rp_logger.error("No output images found in response.")
        raise ValueError("No output images found in response")
    
    rp_logger.info(f"Processed images: {list(results.keys())}")
    return results

def check_comfy_status():
    try:
        response = requests.get(f"http://{COMFY_HOST}/system_stats")
        rp_logger.debug(f"System stats: {response.text}")

        response = requests.get(f"http://{COMFY_HOST}/object_info")
        rp_logger.debug(f"Object info available: {list(response.json().keys())}")

        response = requests.get(f"http://{COMFY_HOST}/queue")
        rp_logger.debug(f"Queue status: {response.text}")

    except Exception as e:
        rp_logger.error(f"Error checking ComfyUI status: {str(e)}")

def setup_websocket(client_id):
    ws = websocket.WebSocket()
    ws.settimeout(30)  # 30-second timeout
    ws.connect(f"ws://{COMFY_HOST}/ws?clientId={client_id}")
    return ws

def handler(event):
    rp_logger.info("Handler started")
    try:
        # Generate a unique client ID for each request
        client_id = str(uuid.uuid4())
        rp_logger.debug(f"Generated unique client_id: {client_id}")

        check_comfy_status()
        
        input_data = event.get("input", {})
        workflow = input_data.get("workflow")
        if not workflow:
            raise ValueError("No workflow provided")

        images = input_data.get("images", [])

        # Check server readiness
        if not check_server(f"http://{COMFY_HOST}", COMFY_API_AVAILABLE_MAX_RETRIES, COMFY_API_AVAILABLE_INTERVAL_MS):
            raise RuntimeError("ComfyUI server not reachable")

        # Upload any provided images
        upload_result = upload_images(images)
        if upload_result["status"] == "error":
            return upload_result

        # Queue prompt and wait for completion
        prompt_id = queue_prompt(workflow, client_id)
        outputs = wait_for_job_complete(prompt_id, client_id)

        # Process the outputs
        image_results = process_output_images(outputs)

        if not image_results:
            raise ValueError("No images were generated")

        return {
            "status": "success",
            "images": image_results,
            "prompt_id": prompt_id
        }

    except Exception as e:
        error_message = f"An error occurred: {str(e)}"
        rp_logger.error(error_message, exc_info=True)
        return {"status": "error", "message": error_message}


if __name__ == "__main__":
    rp_logger.info("Starting RunPod handler")
    runpod.serverless.start({"handler": handler})
