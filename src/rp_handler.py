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

CLIENT_ID = str(uuid.uuid4())

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
    
    # Use the global CLIENT_ID
    payload = {
        "prompt": workflow,
        "client_id": CLIENT_ID
    }
    
    response = requests.post(f"http://{COMFY_HOST}/prompt", json=payload)
    logger.info(f"Queue Response: {response.text}")
    
    result = response.json()
    if 'prompt_id' not in result:
        logger.error(f"Invalid response format: {result}")
        raise ValueError("No prompt_id in response")
    
    prompt_id = result['prompt_id']
    queue_position = result.get('number', 0)
    logger.info(f"Prompt queued with ID: {prompt_id} at position: {queue_position}")
    
    return prompt_id
    
def get_history(prompt_id):
    logger.info(f"=== HISTORY REQUEST START for {prompt_id} ===")
    response = requests.get(f"http://{COMFY_HOST}/history/{prompt_id}")
    logger.info(f"Status Code: {response.status_code}")
    logger.info(f"Raw History Response: {response.text}")
    logger.info("=== HISTORY REQUEST END ===")
    return response.json()

def wait_for_job_complete(prompt_id):
    logger.info(f"Waiting for job completion: {prompt_id}")
    
    try:
        ws = setup_websocket()
        
        while True:
            out = ws.recv()
            if isinstance(out, str):
                message = json.loads(out)
                logger.debug(f"WebSocket message: {message}")
                
                if message['type'] == 'executing':
                    data = message['data']
                    if data['prompt_id'] == prompt_id:
                        if data['node'] is None:
                            # Execution is complete
                            break
                        else:
                            logger.info(f"Executing node: {data['node']}")
            else:
                # Binary data (preview images)
                logger.debug("Received binary preview data")
                continue
        
        # Get the final results from history
        history = get_history(prompt_id)
        if prompt_id in history:
            return history[prompt_id]['outputs']
        else:
            raise ValueError("Prompt not found in history after completion")
            
    except Exception as e:
        logger.error(f"WebSocket error: {str(e)}")
        raise
    finally:
        try:
            ws.close()
        except:
            pass

def process_output_images(outputs):
    logger.info(f"Processing outputs: {outputs}")
    
    results = {}
    # Check for direct base64 output from node 38
    if "38" in outputs:
        node_output = outputs["38"]
        if "images" in node_output:
            # Handle file-based output
            for image in node_output["images"]:
                image_path = os.path.join(COMFY_OUTPUT_PATH, 
                                        image["subfolder"], 
                                        image["filename"])
                with open(image_path, "rb") as f:
                    results["38"] = base64.b64encode(f.read()).decode('utf-8')
        elif "data" in node_output:
            # Handle direct base64 output
            results["38"] = node_output["data"]
    
    if not results:
        raise ValueError("No output images found in response")
    
    return results

def check_comfy_status():
    try:
        # Check system stats
        response = requests.get(f"http://{COMFY_HOST}/system_stats")
        logger.debug(f"System stats: {response.text}")
        
        # Check object info
        response = requests.get(f"http://{COMFY_HOST}/object_info")
        logger.debug(f"Object info available: {list(response.json().keys())}")
        
        # Check queue
        response = requests.get(f"http://{COMFY_HOST}/queue")
        logger.debug(f"Queue status: {response.text}")
        
    except Exception as e:
        logger.error(f"Error checking ComfyUI status: {str(e)}")

def handler(event):
    logger.info("Handler started")
    try:
        check_comfy_status()
        
        input_data = event["input"]
        workflow = input_data.get("workflow")
        if not workflow:
            raise ValueError("No workflow provided")

        images = input_data.get("images", [])
        
        # Check server and upload images
        check_server(f"http://{COMFY_HOST}", 
                    COMFY_API_AVAILABLE_MAX_RETRIES, 
                    COMFY_API_AVAILABLE_INTERVAL_MS)

        upload_result = upload_images(images)
        if upload_result["status"] == "error":
            return upload_result

        # Queue prompt and wait for completion using WebSocket
        prompt_id = queue_prompt(workflow)
        outputs = wait_for_job_complete(prompt_id)
        
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
        logger.error(error_message, exc_info=True)
        return {"status": "error", "message": error_message}

def setup_websocket():
    ws = websocket.WebSocket()
    ws.settimeout(30)  # 30 second timeout
    ws.connect(f"ws://{COMFY_HOST}/ws?clientId={CLIENT_ID}")
    return ws

if __name__ == "__main__":
    logger.info("Starting RunPod handler")
    runpod.serverless.start({"handler": handler})