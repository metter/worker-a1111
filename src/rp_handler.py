import json
import time
import runpod
import requests
from requests.adapters import HTTPAdapter, Retry
import os
import base64

automatic_session = requests.Session()
retries = Retry(total=10, backoff_factor=0.1, status_forcelist=[502, 503, 504])
automatic_session.mount('http://', HTTPAdapter(max_retries=retries))
pod_tier = os.getenv('Tier', 'standard')

# ---------------------------------------------------------------------------- #
#                              Automatic Functions                             #
# ---------------------------------------------------------------------------- #
def truncate_string(s, max_length=15):
    '''
    Truncate a string to a specified length and append '...' if it exceeds that length.
    '''
    return (s[:max_length] + '...') if len(s) > max_length else s

def wait_for_service(url):
    '''
    Check if the service is ready to receive requests.
    '''
    while True:
        try:
            requests.get(url)
            return
        except requests.exceptions.RequestException:
            print(f"{pod_tier} - Service not ready yet. Retrying...")
        except Exception as err:
            print(f"{pod_tier} - Error: {err}")

        time.sleep(0.2)

def txt2img_inference(inference_request):
    '''
    Run inference using the txt2img API.
    '''
    print(f"{pod_tier} - txt2img")
    print(f"{pod_tier} - {json.dumps(inference_request, indent=4)}")
    response = automatic_session.post(url='http://127.0.0.1:3000/sdapi/v1/txt2img',
                                      json=inference_request, timeout=600)
    return response.json()

def img2img_inference(inference_request):
    '''
    Run inference using the img2img API.
    '''
    print(f"{pod_tier} - img2img")
    print(f"{pod_tier} - {json.dumps(inference_request, indent=4)}")
    response = automatic_session.post(url='http://127.0.0.1:3000/sdapi/v1/img2img',
                                      json=inference_request, timeout=600)
    return response.json()

def encode_image_to_base64(character_id: str) -> str:
    try:
        # Define the path to the characters folder
        characters_folder = '/characters'

        # Build the file path based on the character_id
        file_path = os.path.join(characters_folder, f'{character_id}.png')
        print(f'Attempting to find image at path: {file_path}')

        # Check if the file exists
        if not os.path.isfile(file_path):
            raise FileNotFoundError(f'Image not found: {file_path}')

        # Read the image file and encode it in base64
        with open(file_path, 'rb') as image_file:
            base64_image = base64.b64encode(image_file.read()).decode('utf-8')

        # Return the base64 string
        return base64_image

    except Exception as e:
        # Handle potential errors and raise an appropriate exception
        raise Exception(f'Failed to encode image for character {character_id}: {str(e)}')
    
# ---------------------------------------------------------------------------- #
#                                RunPod Handler                                #
# ---------------------------------------------------------------------------- #
def handler(event):
    '''
    This is the handler function that will be called by the serverless.
    '''     

    print(f"{pod_tier} - Handler started:\n{json.dumps(event, indent=2)}")
    print(f"{pod_tier} - Pod Tier: {pod_tier}")

    try:
        print(f"{pod_tier} - try loop started")
        input = event.get("input", {})  # Use original event without truncation for processing

        # Top separator
        print(f"{pod_tier} - ")
        print(f"{pod_tier} - --------------------------------------")
        print(f"{pod_tier} - Request Details:")
        print(f"{pod_tier} - --------------------------------------")

        # Display the primary details of the request
        print(f"{pod_tier} - ID: {event.get('id', 'N/A')}")
        print(f"{pod_tier} - Status: {event.get('status', 'N/A')}")
        print(f"{pod_tier} - Delay Time: {event.get('delayTime', 'N/A')} seconds")

        # Separator for input details
        print(f"{pod_tier} - ")
        print(f"{pod_tier} - --------------------------------------")
        print(f"{pod_tier} - Input Details:")
        print(f"{pod_tier} - --------------------------------------")

        # Print the input data
        print(f"{pod_tier} - {json.dumps(event.get('input', {}), indent=4)}")
        
        # End separator
        print(f"{pod_tier} - ")
        print(f"{pod_tier} - --------------------------------------")
        
        #encode base64 
        if (input and 
            "alwayson_scripts" in input and 
            "ControlNet" in input["alwayson_scripts"] and 
            "args" in input["alwayson_scripts"]["ControlNet"] and 
            len(input["alwayson_scripts"]["ControlNet"]["args"]) > 0):
            print("valid controlnet request")
            
            controlnet_args = event["input"]["alwayson_scripts"]["ControlNet"]["args"][0]
            if "image" in controlnet_args:
                character_id = controlnet_args["image"]
                try:
                    base64_string = encode_image_to_base64(character_id)
                    input["alwayson_scripts"]["ControlNet"]["args"][0]["image"] = base64_string
                    print(f"{pod_tier} - Image successfully encoded to base64")
                except Exception as e:
                    print(f"{pod_tier} - Error encoding image: {str(e)}")

        # Check if 'img2img' is True in the input data
        if input.get("img2img"):  # Using 'get' to prevent KeyError if 'img2img' doesn't exist
            print(f"{pod_tier} - img2img request")
            print(f"{pod_tier} - Payload to be sent:", json.dumps(input, indent=4))
            json_response = img2img_inference(input)  # Make an img2img request
            print(f"{pod_tier} - image processed")
        else:
            print(f"{pod_tier} - txt2img request")
            print(f"{pod_tier} - Payload to be sent:", json.dumps(input, indent=4))
            json_response = txt2img_inference(input)  # Make a txt2img request
            print(f"{pod_tier} - image received")

        print(f"{pod_tier} - return")

        # Return the response
        return json_response
    except Exception as e:
        # Return a JSON error response
        error_message = "An error occurred: " + str(e)
        error_response = {
            "detail": [
                {
                    "loc": ["handler"],
                    "msg": error_message,
                    "type": "handler_error"
                }
            ]
        }
        print(f"{pod_tier} - error:", error_message)
        return error_response
    
if __name__ == "__main__":
    wait_for_service(url='http://127.0.0.1:3000/internal/sysinfo')
    print(f"{pod_tier} - WebUI API Service is ready. Starting RunPod...")
    runpod.serverless.start({"handler": handler})
