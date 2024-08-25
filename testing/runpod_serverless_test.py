import os
import requests
import base64
import json
import logging
from dotenv import load_dotenv

prompt = "a medium shot of a clean shaven 16 year old man entering a room"

style_padding = " 4k, hasselblad, hd, digital art, high quality, masterpiece, vector art, digital art, pencil art, colour, sketch, ink art"

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Load environment variables from .env file
load_dotenv()

# Retrieve environment variables
RUNPOD_SERVER_PAID_ID = os.getenv('RUNPOD_SERVER_PAID_ID')
RUNPOD_API_KEY = os.getenv('RUNPOD_API_KEY')

# Define the URL and headers
url = f'https://api.runpod.ai/v2/{RUNPOD_SERVER_PAID_ID}/runsync'
headers = {
    'Content-Type': 'application/json',
    'Authorization': f'Bearer {RUNPOD_API_KEY}'
}

# Function to encode image to Base64
def encode_image_to_base64(image_path: str) -> str:
    try:
        with open(image_path, "rb") as image_file:
            base64_image = base64.b64encode(image_file.read()).decode('utf-8')
        return base64_image
    except Exception as e:
        raise Exception(f"Failed to encode image to Base64: {str(e)}")

# Function to decode Base64 and save image, and also save the Base64 string to a .base64 file
def decode_base64_to_image(base64_string: str, output_path: str) -> None:
    try:
        missing_padding = len(base64_string) % 4
        if missing_padding:
            base64_string += '=' * (4 - missing_padding)
        
        image_data = base64.b64decode(base64_string)
        
        with open(output_path, "wb") as image_file:
            image_file.write(image_data)
        logging.info(f"Image saved to {output_path}")
        
        base64_file_path = output_path + '.base64'
        with open(base64_file_path, "w") as base64_file:
            base64_file.write(base64_string)
        logging.info(f"Base64 string saved to {base64_file_path}")
        
    except Exception as e:
        logging.error(f"Failed to decode and save image: {str(e)}")

# Function to truncate Base64 strings for logging
def truncate_base64(base64_string: str, length: int = 15) -> str:
    return base64_string[:length] + '...' if len(base64_string) > length else base64_string

# Function to truncate Base64 strings under keys "image" or "images" only in the log copy
def truncate_base64_in_json(data, length: int = 15):
    if isinstance(data, dict):
        for key, value in data.items():
            if key in ['image', 'images', 'input_image']:
                if isinstance(value, str):
                    data[key] = truncate_base64(value, length)
                elif isinstance(value, list):
                    data[key] = [truncate_base64(item, length) if isinstance(item, str) else item for item in value]
            elif isinstance(value, (dict, list)):
                truncate_base64_in_json(value, length)
    elif isinstance(data, list):
        for i, item in enumerate(data):
            if isinstance(item, dict):
                truncate_base64_in_json(item, length)

# Main processing logic
image_path = os.path.join(os.getcwd(), 'characters', '0000_european_16_male.png')
base64_image = encode_image_to_base64(image_path)

payload = {
    "input": {
        "id": 7,
        "negative_prompt": "",
        "sampler_name": "Euler a",
        "steps": 22,
        "cfg_scale": 7,
        "width": 1360,
        "height": 768,
        "prompt": prompt + ", " + style_padding,
        "faceid": True,
        "controlnet": {
            "input_image": base64_image,
            "module": "ip-adapter_face_id",
            "model": "ip-adapter-faceid_sdxl [59ee31a3]",
            "weight": 1.0,
            "low_vram": False,
            "processor_res": 512,
            "threshold_a": 0.0,
            "threshold_b": 255.0,
            "guidance": 1.0,
            "guidance_start": 0.0,
            "guidance_end": 1.0,
            "guessmode": False,
            "resize_mode": "Scale to Fit (Inner Fit)"
        }
    }
}

payload2 = {
    "input": {
        "id": 7,
        "negative_prompt": "",
        "sampler_name": "Euler a",
        "steps": 22,
        "cfg_scale": 7,
        "width": 1360,
        "height": 768,
        "prompt": prompt + ", " + style_padding,
        "faceid": False,
        "alwayson_scripts": {
            "ControlNet": {
                "args": [
                    {
                    "batch_images": "",
                    "control_mode": "Balanced",
                    "enabled": True,
                    "guidance_end": 1,
                    "guidance_start": 0,
                    "image":  base64_image,
                    "input_mode": "simple",
                    "is_ui": False,
                    "loopback": False,
                    "low_vram": False,
                    "model": "ip-adapter-faceid_sdxl [59ee31a3]",
                    "module": "ip-adapter-auto",
                    "output_dir": "",
                    "pixel_perfect": True,
                    "resize_mode": "Crop and Resize",
                    "weight": 1
                    }
                ]
                }
            }
        }
    }


# Create a truncated copy for logging
truncated_payload = json.loads(json.dumps(payload2, default=str))
truncate_base64_in_json(truncated_payload)
logging.info("Payload: " + json.dumps(truncated_payload, indent=2))

# Send the full payload
response = requests.post(url, headers=headers, json=payload2)

# Log the response status code
logging.info(f"Response Status Code: {response.status_code}")

try:
    response_json = response.json()

    # Create a truncated copy for logging
    truncated_response = json.loads(json.dumps(response_json, default=str))
    truncate_base64_in_json(truncated_response)
    logging.info("Response JSON: " + json.dumps(truncated_response, indent=2))

    # Extract and decode the image if present in the full response
    if 'output' in response_json and 'images' in response_json['output']:
        image_base64 = response_json['output']['images'][0]  # Full string from the API response
        output_image_path = os.path.join(os.getcwd(), 'outputs', 'output_image.png')
        decode_base64_to_image(image_base64, output_image_path)
    else:
        logging.warning("No image found in the response.")
except json.JSONDecodeError as e:
    logging.error(f"Failed to decode JSON response: {str(e)}")
    logging.error(f"Response Text: {response.text}")
