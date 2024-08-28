import json
import time
import runpod
import requests
from requests.adapters import HTTPAdapter, Retry
import os
import base64
from PIL import Image, ImageDraw
import io
import sys
import numpy as np
import logging

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

automatic_session = requests.Session()
retries = Retry(total=10, backoff_factor=0.1, status_forcelist=[502, 503, 504])
automatic_session.mount('http://', HTTPAdapter(max_retries=retries))
pod_tier = os.getenv('Tier', 'standard')

def truncate_string(s, max_length=15):
    return (s[:max_length] + '...') if len(s) > max_length else s

def wait_for_service(url):
    while True:
        try:
            requests.get(url)
            logger.info(f"{pod_tier} - Service is ready")
            return
        except requests.exceptions.RequestException:
            logger.warning(f"{pod_tier} - Service not ready yet. Retrying...")
        except Exception as err:
            logger.error(f"{pod_tier} - Error: {err}")
        time.sleep(0.2)

def txt2img_inference(inference_request):
    logger.info(f"{pod_tier} - Starting txt2img inference")
    logger.debug(f"{pod_tier} - Inference request: {json.dumps(inference_request, indent=4)}")
    response = automatic_session.post(url='http://127.0.0.1:3000/sdapi/v1/txt2img',
                                      json=inference_request, timeout=600)
    logger.info(f"{pod_tier} - txt2img inference completed")
    return response.json()

def img2img_inference(inference_request):
    logger.info(f"{pod_tier} - Starting img2img inference")
    logger.debug(f"{pod_tier} - Inference request: {json.dumps(inference_request, indent=4)}")
    response = automatic_session.post(url='http://127.0.0.1:3000/sdapi/v1/img2img',
                                      json=inference_request, timeout=600)
    logger.info(f"{pod_tier} - img2img inference completed")
    return response.json()

def encode_image_to_base64(character_id: str) -> str:
    try:
        characters_folder = '/characters'
        file_path = os.path.join(characters_folder, f'{character_id}.png')
        logger.info(f'Attempting to find image at path: {file_path}')

        if not os.path.isfile(file_path):
            raise FileNotFoundError(f'Image not found: {file_path}')

        with open(file_path, 'rb') as image_file:
            base64_image = base64.b64encode(image_file.read()).decode('utf-8')

        logger.info(f'Successfully encoded image for {character_id}')
        return base64_image

    except Exception as e:
        logger.error(f'Failed to encode image for character {character_id}: {str(e)}')
        raise

def generate_mask(width, height, divisions):
    masks = []
    cumulative = 0
    for i, fraction in enumerate(divisions):
        mask = Image.new('RGB', (width, height), color=(0, 0, 0))  # Change 'L' to 'RGB'
        draw = ImageDraw.Draw(mask)
        left = int(cumulative * width)
        right = int((cumulative + fraction) * width)
        draw.rectangle([left, 0, right, height], fill=(255, 255, 255))  # White rectangle
        
        buffered = io.BytesIO()
        mask.save(buffered, format="PNG")
        mask_base64 = base64.b64encode(buffered.getvalue()).decode('utf-8')
        masks.append(mask_base64)
        
        cumulative += fraction
    
    return masks

def handler(event):
    logger.info(f"{pod_tier} - Handler started")
    logger.debug(f"{pod_tier} - Event: {json.dumps(event, indent=2)}")

    try:
        input = event.get("input", {})
        logger.info(f"{pod_tier} - Processing input")
        logger.debug(f"{pod_tier} - Input: {json.dumps(input, indent=4)}")

        if (input and 
            "alwayson_scripts" in input and 
            "ControlNet" in input["alwayson_scripts"] and 
            "args" in input["alwayson_scripts"]["ControlNet"] and 
            len(input["alwayson_scripts"]["ControlNet"]["args"]) > 0):
            
            logger.info("Valid ControlNet request detected")
            
            if "division" in input:
                divisions = input["division"]
                width = int(input.get("width", 1360))
                height = int(input.get("height", 768))
                
                masks = generate_mask(width, height, divisions)
                
                for i, args in enumerate(input["alwayson_scripts"]["ControlNet"]["args"]):
                    if i < len(masks):
                        args["effective_region_mask"] = masks[i]
                        logger.info(f"Assigned mask to ControlNet arg {i}")
            
            for i, controlnet_args in enumerate(input["alwayson_scripts"]["ControlNet"]["args"]):
                if "image" in controlnet_args:
                    character_id = controlnet_args["image"]
                    try:
                        base64_string = encode_image_to_base64(character_id)
                        input["alwayson_scripts"]["ControlNet"]["args"][i]["image"] = base64_string
                        logger.info(f"Image successfully encoded to base64 for ControlNet arg {i}")
                    except Exception as e:
                        logger.error(f"Error encoding image for ControlNet arg {i}: {str(e)}")

        if input.get("img2img"):
            logger.info(f"{pod_tier} - Processing img2img request")
            json_response = img2img_inference(input)
        else:
            logger.info(f"{pod_tier} - Processing txt2img request")
            json_response = txt2img_inference(input)

        logger.info(f"{pod_tier} - Processing completed")
        return json_response
    
    except Exception as e:
        error_message = f"An error occurred: {str(e)}"
        logger.error(error_message)
        error_response = {
            "detail": [
                {
                    "loc": ["handler"],
                    "msg": error_message,
                    "type": "handler_error"
                }
            ]
        }
        return error_response

def test_mask_generation():
    test_divisions = [0.2, 0.5, 0.3]
    width, height = 1360, 768
    masks = generate_mask(width, height, test_divisions)
    
    for i, mask_base64 in enumerate(masks):
        with open(f"test_mask_{i+1}.base64", "w") as f:
            f.write(mask_base64)
    
    logger.info(f"Generated {len(masks)} test masks and saved as .base64 files.")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--test":
        test_mask_generation()
    elif len(sys.argv) > 1 and sys.argv[1] == "--test_input":
        if len(sys.argv) > 2:
            test_input = json.loads(sys.argv[2])
            handler({"input": test_input})
        else:
            logger.error("No test input provided")
    else:
        wait_for_service(url='http://127.0.0.1:3000/internal/sysinfo')
        logger.info(f"{pod_tier} - WebUI API Service is ready. Starting RunPod...")
        runpod.serverless.start({"handler": handler})