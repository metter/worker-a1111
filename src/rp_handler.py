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

# Set up logging
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

COMFY_HOST = "127.0.0.1:8188"
COMFY_API_AVAILABLE_INTERVAL_MS = 50
COMFY_API_AVAILABLE_MAX_RETRIES = 500
COMFY_POLLING_INTERVAL_MS = int(os.environ.get("COMFY_POLLING_INTERVAL_MS", 250))
COMFY_POLLING_MAX_RETRIES = int(os.environ.get("COMFY_POLLING_MAX_RETRIES", 500))
COMFY_OUTPUT_PATH = os.environ.get("COMFY_OUTPUT_PATH", "/ComfyUI/output")

def safe_log_data(data, max_length=100):
    """Safely log data by truncating potential base64 strings"""
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
                logger.info("ComfyUI API is reachable")
                return True
        except requests.RequestException as e:
            logger.warning(f"Attempt {i+1}/{retries}: Server not ready. Error: {str(e)}")
        time.sleep(delay / 1000)
    logger.error(f"Failed to connect to server at {url} after {retries} attempts.")
    return False

def upload_images(images):
    if not images:
        return {"status": "success", "message": "No images to upload", "details": []}

    responses = []
    upload_errors = []

    logger.info("Uploading image(s)")

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
        logger.error("Image(s) upload completed with errors")
        return {
            "status": "error",
            "message": "Some images failed to upload",
            "details": upload_errors,
        }

    logger.info("Image(s) upload completed successfully")
    return {
        "status": "success",
        "message": "All images uploaded successfully",
        "details": responses,
    }

def queue_prompt(workflow):
    logger.info("Queuing prompt")
    prompt_id = str(uuid.uuid4())
    payload = {"prompt": workflow, "client_id": prompt_id}
    
    logger.debug(f"Sending prompt payload: {json.dumps(safe_log_data(payload), indent=2)}")
    
    response = requests.post(f"http://{COMFY_HOST}/prompt", json=payload)
    
    logger.debug(f"Raw response from ComfyUI: {safe_log_data(response.text)}")
    
    result = response.json()
    logger.info(f"Queue prompt response: {json.dumps(safe_log_data(result), indent=2)}")
    
    try:
        result = response.json()
        logger.info(f"Queue prompt response: {json.dumps(result, indent=2)}")
        if 'prompt_id' not in result:
            raise KeyError(f"Expected 'prompt_id' in response, got: {result}")
        
        logger.info(f"Prompt queued with ID: {result['prompt_id']}")
        return result['prompt_id']
    except json.JSONDecodeError:
        logger.error(f"Failed to parse response as JSON: {response.text}")
        raise

def get_history(prompt_id):
    response = requests.get(f"http://{COMFY_HOST}/history/{prompt_id}")
    return response.json()

def wait_for_job_complete(prompt_id):
    logger.info(f"Waiting for job with prompt_id: {prompt_id} to complete")
    retries = 0
    while retries < COMFY_POLLING_MAX_RETRIES:
        history = get_history(prompt_id)
        logger.debug(f"History for prompt {prompt_id}: {json.dumps(history, indent=2)}")
        
        if prompt_id in history:
            outputs = history[prompt_id].get("outputs", {})
            # Check for base64 output from node 38
            if "38" in outputs and outputs["38"].get("data", None):
                logger.info("Job completed with base64 data")
                return outputs
            elif any("images" in node_output for node_output in outputs.values()):
                logger.info("Job completed with image files")
                return outputs
            else:
                logger.debug(f"Job not complete. Current status: {history[prompt_id].get('status', 'unknown')}")
        else:
            logger.warning(f"Prompt ID {prompt_id} not found in history")
        
        time.sleep(COMFY_POLLING_INTERVAL_MS / 1000)
        retries += 1
        logger.debug(f"Retry {retries}/{COMFY_POLLING_MAX_RETRIES}")
    
    raise TimeoutError("Max retries reached while waiting for image generation")

def process_output_images(outputs):
    logger.info("Processing output images")
    logger.debug(f"Outputs: {json.dumps(safe_log_data(outputs), indent=2)}")
 
    results = {}
    for node_id, node_output in outputs.items():
        # Handle direct base64 output from easy imageToBase64 node
        if node_id == "38" and "data" in node_output:
            results[node_id] = node_output["data"]
            logger.info(f"Processed base64 data from node {node_id}")
            continue

        # Handle traditional file-based outputs
        if "images" in node_output:
            for image in node_output["images"]:
                image_path = os.path.join(COMFY_OUTPUT_PATH, image["subfolder"], image["filename"])
                logger.debug(f"Attempting to access image at: {image_path}")
                
                for _ in range(5):
                    if os.path.exists(image_path):
                        try:
                            with open(image_path, "rb") as image_file:
                                encoded_string = base64.b64encode(image_file.read()).decode("utf-8")
                                results[node_id] = encoded_string
                                logger.info(f"Image for node {node_id} processed successfully")
                                break
                        except Exception as e:
                            logger.error(f"Error reading image file: {str(e)}")
                    else:
                        logger.warning(f"Image file not found: {image_path}")
                        time.sleep(1)

    if not results:
        logger.error("No images were processed")
        logger.debug(f"Contents of {COMFY_OUTPUT_PATH}:")
        for root, dirs, files in os.walk(COMFY_OUTPUT_PATH):
            for file in files:
                logger.debug(os.path.join(root, file))

    return results

def handler(event):
    logger.info("Handler started")
    logger.debug(f"Received event: {json.dumps(safe_log_data(event), indent=2)}")
    try:
        input_data = event["input"]
        logger.info(f"Processing input: {json.dumps(safe_log_data(input_data), indent=2)}")
        workflow = input_data.get("workflow")
        if not workflow:
            raise ValueError("No workflow provided in the input")

        images = input_data.get("images", [])

        check_server(f"http://{COMFY_HOST}", COMFY_API_AVAILABLE_MAX_RETRIES, COMFY_API_AVAILABLE_INTERVAL_MS)

        upload_result = upload_images(images)
        if upload_result["status"] == "error":
            return upload_result

        prompt_id = queue_prompt(workflow)
        outputs = wait_for_job_complete(prompt_id)
        
        image_results = process_output_images(outputs)
        
        if not image_results:
            raise ValueError("No images were generated")

        return {"status": "success", "images": image_results}

    except Exception as e:
        error_message = f"An error occurred: {str(e)}"
        logger.error(error_message, exc_info=True)
        return {"status": "error", "message": error_message}

if __name__ == "__main__":
    logger.info("Starting RunPod handler")
    runpod.serverless.start({"handler": handler})