import os
import base64

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

# Example usage
if __name__ == "__main__":
    try:
        character_id = "example_character"
        base64_string = encode_image_to_base64(character_id)
        print("Base64 encoded image:", base64_string)
    except Exception as e:
        print("Error:", str(e))
