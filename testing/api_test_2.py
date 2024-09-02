import requests
import json
import base64

# The API endpoint
url = "http://127.0.0.1:8188"

# Your workflow JSON
workflow = {
    
  "3": {
    "inputs": {
      "seed": 933556066385684,
      "steps": 20,
      "cfg": 8,
      "sampler_name": "euler",
      "scheduler": "normal",
      "denoise": 1,
      "model": [
        "10",
        0
      ],
      "positive": [
        "6",
        0
      ],
      "negative": [
        "7",
        0
      ],
      "latent_image": [
        "5",
        0
      ]
    },
    "class_type": "KSampler",
    "_meta": {
      "title": "KSampler"
    }
  },
  "4": {
    "inputs": {
      "ckpt_name": "sd_xl_base_1.0.safetensors"
    },
    "class_type": "CheckpointLoaderSimple",
    "_meta": {
      "title": "Load Checkpoint"
    }
  },
  "5": {
    "inputs": {
      "width": 1360,
      "height": 768,
      "batch_size": 1
    },
    "class_type": "EmptyLatentImage",
    "_meta": {
      "title": "Empty Latent Image"
    }
  },
  "6": {
    "inputs": {
      "text": "A colour cinematic storyboard, sketch, drawing, colour\"\n\na wide shot of ((THE WOMAN)), wearing a casual dress, (in a vibrant garden:0.9), standing with hands on hips, surrounded by colorful flowers and greenery, sunlight filtering through leaves\n\nCinematic, Digital Art, Watercolor, Sketching, Detailed, pixlineart\nXCYP Sunshine Illustration",
      "clip": [
        "10",
        1
      ]
    },
    "class_type": "CLIPTextEncode",
    "_meta": {
      "title": "CLIP Text Encode (Prompt)"
    }
  },
  "7": {
    "inputs": {
      "text": "(photo:1.2), photographic, (twins), (double), (too many limbs), (deformed, distorted, disfigured:1.3), (eyes to camera), (looking at camera), (saturated) (grain) (deformed) (lowres) (lowpoly) (CG) (3d) (blurry) (out-of-focus) (depth_of_field) (duplicate) (watermark) (label) (signature) (text) (cropped) Easynegative_promptative, sexy, naked, picture in picture, frame, multiple people, off screen, (deformed, distorted, disfigured:1.3), (photo photography photograph) (saturated) (grain) (deformed) (poorly drawn) (sexy)",
      "clip": [
        "10",
        1
      ]
    },
    "class_type": "CLIPTextEncode",
    "_meta": {
      "title": "CLIP Text Encode (Prompt)"
    }
  },
  "8": {
    "inputs": {
      "samples": [
        "3",
        0
      ],
      "vae": [
        "4",
        2
      ]
    },
    "class_type": "VAEDecode",
    "_meta": {
      "title": "VAE Decode"
    }
  },
  "10": {
    "inputs": {
      "lora_name": "fresh_ideas_2.safetensors",
      "strength_model": 0.7000000000000001,
      "strength_clip": 1,
      "model": [
        "4",
        0
      ],
      "clip": [
        "4",
        1
      ]
    },
    "class_type": "LoraLoader",
    "_meta": {
      "title": "Load LoRA"
    }
  },
  "15": {
    "inputs": {
      "images": [
        "8",
        0
      ]
    },
    "class_type": "ImageToBase64",
    "_meta": {
      "title": "Image To Base64"
    }
  }
}

# Prepare the prompt
prompt = {
    "prompt": workflow,
    "client_id": "your_client_id"  # You can use any unique identifier here
}

# Send the request to queue the prompt
response = requests.post(url, json=prompt)
response_json = response.json()

# Get the prompt id from the response
prompt_id = response_json['prompt_id']

# Now we need to wait for the job to complete
# You might want to implement a polling mechanism here
# For simplicity, we'll just wait for a while
import time
time.sleep(10)  # Wait for 10 seconds

# Now, let's check the history to get our results
history_url = f"http://127.0.0.1:8188/history/{prompt_id}"
history_response = requests.get(history_url)
history_json = history_response.json()

# The base64 string should be in the outputs of node 15
base64_string = history_json['outputs']['15']['images'][0]

# If you want to save this as an image:
image_data = base64.b64decode(base64_string)
with open('output.png', 'wb') as f:
    f.write(image_data)

print("Image saved as output.png")