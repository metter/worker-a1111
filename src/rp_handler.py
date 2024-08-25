import json
import time
import runpod
import requests
from requests.adapters import HTTPAdapter, Retry
import os

automatic_session = requests.Session()
retries = Retry(total=10, backoff_factor=0.1, status_forcelist=[502, 503, 504])
automatic_session.mount('http://', HTTPAdapter(max_retries=retries))
pod_tier = os.getenv('Tier')

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
            print("Service not ready yet. Retrying...")
        except Exception as err:
            print("Error: ", err)

        time.sleep(0.2)

def txt2img_inference(inference_request):
    '''
    Run inference using the txt2img API.
    '''
    print("txt2img")
    print(json.dumps(inference_request['input'], indent=4))
    response = automatic_session.post(url='http://127.0.0.1:3000/sdapi/v1/txt2img',
                                      json=inference_request, timeout=600)
    return response.json()

def img2img_inference(inference_request):
    '''
    Run inference using the img2img API.
    '''
    print("img2img")
    print(json.dumps(inference_request['input'], indent=4))
    response = automatic_session.post(url='http://127.0.0.1:3000/sdapi/v1/img2img',
                                      json=inference_request, timeout=600)
    return response.json()

# ---------------------------------------------------------------------------- #
#                                RunPod Handler                                #
# ---------------------------------------------------------------------------- #
def handler(event):
    '''
    This is the handler function that will be called by the serverless.
    '''
    wait_for_service("localhost:3000/v2/txt2img")
    # Create a copy of the event for logging, with truncated input_image
    log_event = event.copy()
    
    if "controlnet" in log_event["input"] and "input_image" in log_event["input"]["controlnet"]:
        log_event["input"]["controlnet"]["input_image"] = truncate_string(log_event["input"]["controlnet"]["input_image"])

    print("Handler started:", log_event)
    print("Pod Tier:", pod_tier if pod_tier is not None else "Not set")

    try:
        print("try loop started")
        input_data = event["input"]  # Use original event without truncation for processing

        # Top separator
        print("")
        print("--------------------------------------")
        print("Request Details:")
        print("--------------------------------------")

        # Display the primary details of the request
        print(f"ID: {event['id']}")
        print(f"Status: {event['status']}")
        print(f"Delay Time: {event['delayTime']} seconds")

        # Separator for input details
        print("")
        print("--------------------------------------")
        print("Input Details:")
        print("--------------------------------------")

        # Print the input data, but with truncated input_image in the log output
        print(json.dumps(log_event['input'], indent=4))

        # Check if 'mode' is set to 'faceid'
        if input_data.get("mode") == "faceid":
            print("FaceID mode detected")
            
            # Ensure required parameters are present
            if "controlnet" not in input_data:
                raise ValueError("ControlNet parameters are missing for faceid mode")
            
            # Add ControlNet settings to the request
            input_data["alwayson_scripts"] = {
                "controlnet": {
                    "args": [
                        {
                            "image": input_data["controlnet"]["input_image"],
                            "module": input_data["controlnet"]["module"],
                            "model": input_data["controlnet"]["model"],
                            "weight": input_data["controlnet"]["weight"],
                            "mask": input_data.get("controlnet", {}).get("mask", ""),
                            "resize_mode": input_data["controlnet"]["resize_mode"],
                            "low_vram": input_data["controlnet"]["low_vram"],
                            "processor_res": input_data["controlnet"]["processor_res"],
                            "threshold_a": input_data["controlnet"]["threshold_a"],
                            "threshold_b": input_data["controlnet"]["threshold_b"],
                            "enabeled": True,
                            "guidance_start": input_data["controlnet"]["guidance_start"],
                            "guidance_end": input_data["controlnet"]["guidance_end"],
                            "guessmode": input_data["controlnet"]["guessmode"]
                        }
                    ]
                }
            }
        
        # End separator
        print("")
        print("--------------------------------------")

        # Check if 'img2txt' is True in the input data
        if input_data.get("img2img"):  # Using 'get' to prevent KeyError if 'img2img' doesn't exist
            print("img2img request")
            json_response = img2img_inference(input_data)  # Make an img2img request
            print("image processed")
        else:
            print("txt2img request")
            json_response = txt2img_inference(input_data)  # Make a txt2img request
            print("image received")

        print("return")

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
        print("error:", error_message)
        return error_response
