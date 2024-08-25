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
    print(json.dumps(inference_request, indent=4))
    response = automatic_session.post(url='http://127.0.0.1:3000/sdapi/v1/txt2img',
                                      json=inference_request, timeout=600)
    return response.json()

def img2img_inference(inference_request):
    '''
    Run inference using the img2img API.
    '''
    print("img2img")
    print(json.dumps(inference_request, indent=4))
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
    
    # Create a copy of the event for logging, with truncated input_image
    log_event = event.copy()
    
    if "controlnet" in log_event.get("input", {}) and "input_image" in log_event["input"].get("controlnet", {}):
        log_event["input"]["controlnet"]["input_image"] = truncate_string(log_event["input"]["controlnet"]["input_image"])

    print("Handler started:", log_event)
    print("Pod Tier:", pod_tier if pod_tier is not None else "Not set")

    try:
        print("try loop started")
        input = event.get("input", {})  # Use original event without truncation for processing

        # Top separator
        print("")
        print("--------------------------------------")
        print("Request Details:")
        print("--------------------------------------")

        # Display the primary details of the request
        print(f"ID: {event.get('id', 'N/A')}")
        print(f"Status: {event.get('status', 'N/A')}")
        print(f"Delay Time: {event.get('delayTime', 'N/A')} seconds")

        # Separator for input details
        print("")
        print("--------------------------------------")
        print("Input Details:")
        print("--------------------------------------")

        # Print the input data, but with truncated input_image in the log output
        print(json.dumps(log_event.get('input', {}), indent=4))

        # Check if 'faceid' mode is set
        if input.get("faceid"):
            print("FaceID mode detected. Adding ControlNet args")
            
            # Add ControlNet settings to the request, if provided
            input["alwayson_scripts"] = {
                "controlnet": {
                    "args": [
                        {
                            "image": input.get("controlnet", {}).get("input_image", ""),
                            "module": input.get("controlnet", {}).get("module", ""),
                            "model": input.get("controlnet", {}).get("model", ""),
                            "weight": input.get("controlnet", {}).get("weight", ""),
                            "mask": input.get("controlnet", {}).get("mask", ""),
                            "resize_mode": input.get("controlnet", {}).get("resize_mode", ""),
                            "low_vram": input.get("controlnet", {}).get("low_vram", False),
                            "processor_res": input.get("controlnet", {}).get("processor_res", 512),
                            "threshold_a": input.get("controlnet", {}).get("threshold_a", 0),
                            "threshold_b": input.get("controlnet", {}).get("threshold_b", 0),
                            "enabled": True,
                            "guidance_start": input.get("controlnet", {}).get("guidance_start", 0),
                            "guidance_end": input.get("controlnet", {}).get("guidance_end", 1),
                            "guessmode": input.get("controlnet", {}).get("guessmode", False)
                        }
                    ]
                }
            }
            
            print(json.dumps(log_event.get('input', {}), indent=4))
        
        input.pop("controlnet", None)
        # End separator
        print("")
        print("--------------------------------------")

        # Check if 'img2img' is True in the input data
        if input.get("img2img"):  # Using 'get' to prevent KeyError if 'img2img' doesn't exist
            print("img2img request")
            print("Payload to be sent:", json.dumps(input, indent=4))
            json_response = img2img_inference(input)  # Make an img2img request
            print("image processed")
        else:
            print("txt2img request")
            print("Payload to be sent:", json.dumps(input, indent=4))
            json_response = txt2img_inference(input)  # Make a txt2img request
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
    
if __name__ == "__main__":
    wait_for_service(url='http://127.0.0.1:3000/internal/sysinfo')
    print("WebUI API Service is ready. Starting RunPod...")
    runpod.serverless.start({"handler": handler})
