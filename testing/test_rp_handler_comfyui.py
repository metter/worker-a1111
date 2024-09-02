import json
import base64
from PIL import Image
import io
import logging

# Import the handler function from your rp_handler.py
from rp_handler import handler

# Set up logging
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def test_handler():
    # Load a sample ComfyUI workflow
    with open('simple_image_api.json', 'r') as f:
        workflow = json.load(f)

    # Create a mock event object
    event = {
        "id": "test_job_id",
        "input": {
            "workflow": workflow,
            "images": []  # Add any input images here if needed
        }
    }

    logger.info("Starting test handler")
    
    # Call the handler function
    result = handler(event)

    logger.info(f"Handler result: {json.dumps(result, indent=2)}")

    if result["status"] == "success" and "images" in result:
        for node_id, image_base64 in result["images"].items():
            if image_base64:
                # Decode and save the image
                image_data = base64.b64decode(image_base64)
                image = Image.open(io.BytesIO(image_data))
                output_filename = f"test_output_image_{node_id}.png"
                image.save(output_filename)
                logger.info(f"Image generated and saved as {output_filename}")
            else:
                logger.warning(f"No image data for node {node_id}")
    elif result["status"] == "error":
        logger.error(f"Error: {result['message']}")
    else:
        logger.warning(f"Unexpected result: {result}")

if __name__ == "__main__":
    test_handler()