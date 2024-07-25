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
def wait_for_service():
    log_file = '/var/log/webui_api.log'
    print("Waiting for service to be ready...")
    
    start_time = time.time()
    timeout = 300  # 5 minutes timeout

    while True:
        if os.path.exists(log_file):
            with open(log_file, 'r') as f:
                content = f.read()
                if "Model loaded in" in content:
                    print("Service is ready!")
                    return
        
        # Check for timeout
        if time.time() - start_time > timeout:
            print("Timeout waiting for service to be ready")
            return
        
        time.sleep(0.2)  

def txt2img_inference(inference_request):
    '''
    Run inference using the txt2img API.
    '''
    print("txt2img")
    response = automatic_session.post(url='http://0.0.0.0:3000/sdapi/v1/txt2img',
                                      json=inference_request, timeout=600)
    return response.json()

def img2img_inference(inference_request):
    '''
    Run inference using the img2img API.
    '''
    print("img2img")
    response = automatic_session.post(url='http://0.0.0.0:3000/sdapi/v1/img2img',
                                      json=inference_request, timeout=600)
    return response.json()

# ---------------------------------------------------------------------------- #
#                                RunPod Handler                                #
# ---------------------------------------------------------------------------- #
def handler(event):
    '''
    This is the handler function that will be called by the serverless.
    '''
    print("Handler started:", event)
    print("Pod Tier:", pod_tier if pod_tier is not None else "Not set")

    try:
        print("try loop started")
        input_data = event["input"]

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

        # Display input details
        print(f"Prompt: {input_data.get('prompt', 'N/A')}")
        print(f"Model: {input_data.get('model', 'N/A')}")
        print(f"Steps: {input_data.get('steps', 'N/A')}")
        print(f"CFG Scale: {input_data.get('cfg_scale', 'N/A')}")
        print(f"Width x Height: {input_data.get('width', 'N/A')} x {input_data.get('height', 'N/A')}")
        print(f"Sampler Name: {input_data.get('sampler_name', 'N/A')}")
        print(f"2-Step: {input_data.get('2step', 'N/A')}")
        print(f"Camera: {input_data.get('camera', 'N/A')}")
        print(f"Monochrome: {input_data.get('monochrome', 'N/A')}")
        print(f"Frontpad: {input_data.get('frontpad', 'N/A')}")
        print(f"Backpad: {input_data.get('backpad', 'N/A')}")
        print(f"Negative Prompt: {input_data.get('negative_prompt', 'N/A')}")

        # End separator
        print("")
        print("--------------------------------------")

        # Check if 'img2img' is True in the input data
        if input_data.get("img2img"):
            print("img2img request")
            json_response = img2img_inference(input_data)
            print("image processed")
        else:
            print("txt2img request")
            json_response = txt2img_inference(input_data)
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
    wait_for_service()
    print("WebUI API Service is ready. Starting RunPod...")
    runpod.serverless.start({"handler": handler})