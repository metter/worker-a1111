import time
import runpod
import requests
from requests.adapters import HTTPAdapter, Retry

LOCAL_URL = "http://127.0.0.1:3000/sdapi/v1"

automatic_session = requests.Session()
retries = Retry(total=10, backoff_factor=0.1, status_forcelist=[502, 503, 504])
automatic_session.mount('http://', HTTPAdapter(max_retries=retries))

# ---------------------------------------------------------------------------- #
#                              Automatic Functions                             #
# ---------------------------------------------------------------------------- #
def wait_for_service(url):
    '''
    Check if the service is ready to receive requests.
    '''
    while True:
        try:
            requests.get(url, timeout=120)
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
    response = automatic_session.post(url=f'{LOCAL_URL}/txt2img',
                                      json=inference_request, timeout=600)
    return response.json()

def img2img_inference(inference_request):
    '''
    Run inference using the img2img API.
    '''
    print("img2img")
    response = automatic_session.post(url='http://{LOCAL_URL}/sdapi/v1/img2img',
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

    try:
        print("try loop started")

        input_data = event["input"]
        prompt = input_data["prompt"]

        # Get the assembly instructions from the "pos" field
        txt2img_assembly_instructions = input_data.get("pos", "")

        # Replace the placeholders in the assembly instructions with corresponding values
        txt2img_assembled_prompt = txt2img_assembly_instructions.replace(
            "[frontpad]", input_data.get("frontpad", "")
        ).replace(
            "[backpad]", input_data.get("backpad", "")
        ).replace(
            "[camera]", input_data.get("camera", "")
        ).replace(
            "[prompt]", prompt  
        ).replace(
            "[lora]", input_data.get("lora", "")
        )

        print("assembled_prompt:", txt2img_assembled_prompt)

        # Update the input data with the assembled prompt
        input_data["prompt"] = txt2img_assembled_prompt

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
    wait_for_service(url=f'{LOCAL_URL}/txt2img')

    print("WebUI API Service is ready. Starting RunPod...")
    runpod.serverless.start({"handler": handler})