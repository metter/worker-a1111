import os
import requests
import json
import logging
from dotenv import load_dotenv

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

# Function to decode Base64 and save image
def decode_base64_to_image(base64_string: str, output_path: str) -> None:
    import base64
    try:
        image_data = base64.b64decode(base64_string)
        with open(output_path, "wb") as image_file:
            image_file.write(image_data)
        logging.info(f"Image saved to {output_path}")
    except Exception as e:
        logging.error(f"Failed to decode and save image: {str(e)}")

# Load the workflow from the JSON file
with open('simple_image_api.json', 'r') as f:
    workflow = json.load(f)

# Prepare the payload
payload = {
    "input": {
        "workflow": workflow
    }
}

# Log the payload (excluding the workflow details for brevity)
logging.info("Sending request with workflow")

# Send the payload
response = requests.post(url, headers=headers, json=payload)

# Log the response status code
logging.info(f"Response Status Code: {response.status_code}")

try:
    response_json = response.json()
    
    # Log the response (you might want to truncate this if it's too long)
    logging.info("Response JSON: " + json.dumps(response_json, indent=2))

    # Extract and decode the image if present in the response
    if 'output' in response_json and 'images' in response_json['output']:
        for node_id, image_base64 in response_json['output']['images'].items():
            output_image_path = os.path.join(os.getcwd(), 'outputs', f'output_image_{node_id}.png')
            decode_base64_to_image(image_base64, output_image_path)
    else:
        logging.warning("No image found in the response.")
except json.JSONDecodeError as e:
    logging.error(f"Failed to decode JSON response: {str(e)}")
    logging.error(f"Response Text: {response.text}")