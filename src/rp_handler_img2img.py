import time
import runpod
import requests
from requests.adapters import HTTPAdapter, Retry
import logging

# Configure logging
logging.basicConfig(filename='/var/log/runpod_handler.log', level=logging.INFO, format='%(asctime)s %(levelname)s:%(message)s')

automatic_session = requests.Session()
retries = Retry(total=10, backoff_factor=0.1, status_forcelist=[502, 503, 504])
automatic_session.mount('http://', HTTPAdapter(max_retries=retries))

def wait_for_service(url):
    '''Check if the service is ready to receive requests.'''
    while True:
        try:
            response = requests.get(url)
            if response.status_code == 200:
                logging.info("Service is ready.")
                return
            else:
                logging.warning("Unexpected status code: %s", response.status_code)
        except requests.exceptions.RequestException as e:
            logging.warning("Service not ready yet. Retrying... Error: %s", str(e))
        except Exception as err:
            logging.error("Error: %s", str(err))
        time.sleep(0.2)

def assemble_prompt(input_data, assembly_instructions):
    '''Replace the placeholders in the assembly instructions with corresponding values.'''
    return assembly_instructions.replace(
        "[frontpad]", input_data.get("frontpad", "")
    ).replace(
        "[backpad]", input_data.get("backpad", "")
    ).replace(
        "[camera]", input_data.get("camera", "")
    ).replace(
        "[prompt]", input_data.get("prompt", "")
    ).replace(
        "[lora]", input_data.get("lora", "")
    )

def txt2img_inference(inference_request):
    '''Run inference using the txt2img API.'''
    logging.info("Starting txt2img inference with request: %s", inference_request)
    try:
        response = automatic_session.post(url='http://127.0.0.1:3000/sdapi/v1/txt2img', json=inference_request, timeout=600)
        response.raise_for_status()  # This will raise an HTTPError if the HTTP request returned an unsuccessful status code
        logging.info("txt2img inference successful. Status code: %s", response.status_code)
    except requests.RequestException as e:
        logging.error("txt2img request failed: %s", e)
        raise  # Re-throwing the exception to be handled by the calling function
    return response.json()

def img2img_inference(inference_request):
    '''Run inference using the img2img API.'''
    logging.info("Starting img2img inference with request: %s", inference_request)
    try:
        response = automatic_session.post(url='http://127.0.0.1:3000/sdapi/v1/img2img', json=inference_request, timeout=600)
        response.raise_for_status()  # This will raise an HTTPError if the HTTP request returned an unsuccessful status code
        logging.info("img2img inference successful. Status code: %s", response.status_code)
    except requests.RequestException as e:
        logging.error("img2img request failed: %s", e)
        raise  # Re-throwing the exception to be handled by the calling function
    return response.json()

def handler(event):
    '''This is the handler function that will be called by the serverless.'''
    logging.info("Handler started: %s", event)

    input_data = event.get("input", {})
    inference_type = "img2img" if input_data.get("img2img") else "txt2img"
    logging.info("Inference type determined: %s", inference_type)

    try:
        logging.info("try loop started")
        
        # Get the assembly instructions from the "pos" field
        assembly_instructions = input_data.get("pos", "")
        assembled_prompt = assemble_prompt(input_data, assembly_instructions)

        logging.info("%s_assembled_prompt: %s", inference_type, assembled_prompt)

        # Update the input data with the assembled prompt
        input_data["prompt"] = assembled_prompt

        logging.info("requesting image")
        # Map the inference type to its corresponding function
        inference_functions = {
            "txt2img": txt2img_inference,
            "img2img": img2img_inference
        }
        
        logging.info("requesting image for %s inference", inference_type)
        json_response = inference_functions[inference_type](input_data)
        logging.info("image received, response: %s", json_response)
        return json_response

    except Exception as e:
        error_message = "An error occurred: " + str(e)
        logging.error("Handler error: %s", error_message)  # Log the error message with error level
        error_response = {
            "detail": [
                {
                    "loc": ["handler"],
                    "msg": error_message,
                    "type": "handler_error"
                }
            ]
        }
        return error_response

if __name__ == "__main__":
    wait_for_service(url='http://127.0.0.1:3000/internal/sysinfo')
    logging.info("WebUI API Service is ready. Starting RunPod...")
    runpod.serverless.start({"handler": handler})
