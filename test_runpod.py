import json
import base64
from src.rp_handler import handler

# Read the base64 string from the file
with open('characters/0001_european_16_male.base64', 'r') as file:
    base64_image_data = file.read().strip()

# Simulate a RunPod event with the necessary input
test_event = {
    "id": "test-id",
    "status": "test-status",
    "delayTime": 0,
    "input": {
        "prompt": "a man smiling to the camera",
        "model": "stable-diffusion-v1-4",
        "steps": 15,
        "cfg_scale": 7.5,
        "width": 512,
        "height": 512,
        "sampler_name": "Euler a",
        "camera": "default",
        "monochrome": False,
        "frontpad": 0,
        "backpad": 0,
        "negative_prompt": "low quality, bad anatomy",
        "img2img": False,
        "mode" : "faceid",
        "controlnet": {
            "input_image": base64_image_data,  # Use the base64 data from the file
            "module": "ip-adapter_face_id", 
            "model": "ip-adapter-faceid_sdxl [59ee31a3]", 
            "weight": 1.0,
            "low_vram": True,
            "processor_res": 512,
            "threshold_a": 0.0,
            "threshold_b": 255.0,
            "enabled": True,
            "guidance": 1.0,
            "guidance_start": 0.0,
            "guidance_end": 1.0,
            "guessmode": False,
            "resize_mode": "Scale to Fit (Inner Fit)"
        }
    }
}

# Call the handler function with the simulated event
response = handler(test_event)

# Truncate the base64 string for display in the console
truncated_base64_image = response["images"][0][:15] + "..." if len(response["images"][0]) > 15 else response["images"][0]

# Print the truncated response
truncated_response = response.copy()
truncated_response["images"][0] = truncated_base64_image
print(json.dumps(truncated_response, indent=4))

# Extract the full base64 image string from the response
full_base64_image = response["images"][0]

# Decode the base64 image to save it as a file
image_data = base64.b64decode(full_base64_image)

# Save the image as a PNG file
with open("output_image.png", "wb") as image_file:
    image_file.write(image_data)

print("Image saved as output_image.png")
