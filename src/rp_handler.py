import time
import runpod
import requests
from requests.adapters import HTTPAdapter, Retry

# Setup requests session with retries
automatic_session = requests.Session()
retries = Retry(total=10, backoff_factor=0.1, status_forcelist=[502, 503, 504])
automatic_session.mount('http://', HTTPAdapter(max_retries=retries))

# Logging functions for structured output
def log_info(message):
    print(f"[INFO] {message}")

def log_warning(message):
    print(f"[WARNING] {message}")

def log_error(message):
    print(f"[ERROR] {message}")

def log_success(message):
    print(f"[SUCCESS] {message}")

# ---------------------------------------------------------------------------- #
#                              Automatic Functions                             #
# ---------------------------------------------------------------------------- #
def wait_for_service(url):
    '''
    Check if the service is ready to receive requests.
    '''
    while True:
        try:
            response = requests.get(url)
            if response.status_code == 200:
                log_success("Service is ready to receive requests.")
                return
            else:
                log_warning("Service is up but returned a non-200 status code. Retrying...")
        except requests.exceptions.RequestException as e:
            log_warning(f"Service not ready yet. Retrying... Error: {e}")
        except Exception as err:
            log_error(f"Unexpected error: {err}")
        time.sleep(0.2)

def txt2img_inference(inference_request):
    '''
    Run inference using the txt2img API.
    '''
    log_info("Initiating txt2img inference...")
    try:
        response = automatic_session.post(url='http://127.0.0.1:3000/sdapi/v1/txt2img',
                                          json=inference_request, timeout=600)
        if response.status_code == 200:
            log_success("txt2img inference completed successfully.")
            return response.json()
        else:
            log_error(f"Failed to complete txt2img inference. Status Code: {response.status_code}")
            return None
    except requests.exceptions.RequestException as e:
        log_error(f"Request failed: {e}")
        return None

def img2img_inference(inference_request):
    '''
    Run inference using the img2img API.
    '''
    log_info("Initiating img2img inference...")
    try:
        response = automatic_session.post(url='http://127.0.0.1:3000/sdapi/v1/img2img',
                                          json=inference_request, timeout=600)
        if response.status_code == 200:
            log_success("img2img inference completed successfully.")
            return response.json()
        else:
            log_error(f"Failed to complete img2img inference. Status Code: {response.status_code}")
            return None
    except requests.exceptions.RequestException as e:
        log_error(f"Request failed: {e}")
        return None

# ---------------------------------------------------------------------------- #
#                                RunPod Handler                                #
# ---------------------------------------------------------------------------- #
def handler(event):
    '''
    This is the handler function that will be called by the serverless framework.
    '''
    log_info(f"Handler started with event: {event}")

    try:
        input_data = event["input"]

        if input_data.get("img2img"):
            log_info("Processing img2img request...")
            json_response = img2img_inference(input_data)
        else:
            log_info("Processing txt2img request...")
            json_response = txt2img_inference(input_data)

        if json_response:
            log_success("Inference request processed successfully.")
        else:
            log_error("Failed to process inference request.")

        return json_response
    except Exception as e:
        error_message = f"An unexpected error occurred: {e}"
        log_error(error_message)
        return {"detail": [{"loc": ["handler"], "msg": error_message, "type": "handler_error"}]}

if __name__ == "__main__":
    wait_for_service(url='http://127.0.0.1:3000/internal/sysinfo')
    runpod.serverless.start({"handler": handler})
