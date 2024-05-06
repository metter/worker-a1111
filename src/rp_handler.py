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
    response = automatic_session.post(url='http://127.0.0.1:3000/sdapi/v1/txt2img',
                                      json=inference_request, timeout=600)
    return response.json()

def img2img_inference(inference_request):
    '''
    Run inference using the img2img API.
    '''
    print("img2img")
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
        print(f"ID: {event['id']}")
        print(f"Status: {event['status']}")
        print(f"Delay Time: {event['delayTime']} seconds")

        # Separator for input details
        print("")
        print("--------------------------------------")
        print("Input Details:")
        print("--------------------------------------")

        # Display input details
        print(f"Prompt: {input_data['prompt']}")
        print(f"Model: {input_data['model']}")
        print(f"Steps: {input_data['steps']}")
        print(f"CFG Scale: {input_data['cfg_scale']}")
        print(f"Width x Height: {input_data['width']} x {input_data['height']}")
        print(f"Sampler Name: {input_data['sampler_name']}")
        print(f"2-Step: {input_data['2step']}")
        print(f"Camera: {input_data['camera']}")
        print(f"Monochrome: {input_data['monochrome']}")
        print(f"Frontpad: {input_data['frontpad']}")
        print(f"Backpad: {input_data['backpad']}")
        print(f"Negative Prompt: {input_data['negative_prompt']}")

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

if __name__ == "__main__":
    wait_for_service(url='http://127.0.0.1:3000/internal/sysinfo')
    print("WebUI API Service is ready. Starting RunPod...")
    runpod.serverless.start({"handler": handler})