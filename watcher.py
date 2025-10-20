import os
import time
import json
import google.generativeai as genai

try:
    gemini_api_key = os.environ.get("GOOGLE_API_KEY")
    if not gemini_api_key:
        gemini_api_key = "PASTE_YOUR_NEW_SECRET_API_KEY_HERE"
        if gemini_api_key == "PASTE_YOUR_NEW_SECRET_API_KEY_HERE":
            raise ValueError("Gemini API key is not set. Please update GOOGLE_API_KEY environment variable or the code.")
    genai.configure(api_key=gemini_api_key)
except ValueError as e:
    print(f"FATAL ERROR: {e}")
    exit()
except Exception as e:
    print(f"FATAL ERROR: Could not configure Gemini API. Details: {e}")
    exit()

TEMP_FOLDER = './temp' 
REQUEST_FILE = os.path.join(TEMP_FOLDER, 'request.json')
RESPONSE_FILE = os.path.join(TEMP_FOLDER, 'response.json')

try:
    os.makedirs(TEMP_FOLDER, exist_ok=True)
except Exception as e:
    print(f"FATAL ERROR: Could not create temp directory '{TEMP_FOLDER}'. Check permissions. Details: {e}")
    exit()

model = genai.GenerativeModel('gemini-1.0-pro')
print("--- Python Watcher is running ---")
print(f"Watching for requests in: {os.path.abspath(TEMP_FOLDER)}")

while True:
    try:
        if os.path.exists(REQUEST_FILE):
            print("Request file found! Processing...")
            
            with open(REQUEST_FILE, 'r') as f:
                game_state = json.load(f)
            
            os.remove(REQUEST_FILE) 
            
            player_dialogue = game_state.get('last_player_dialogue', '...')
            
            prompt = f"""You are Helios, a helpful AI crewmate in Barotrauma. A human crewmate said: "{player_dialogue}". Respond in a single, short sentence. Your personality is professional and helpful. Respond ONLY with a valid JSON object containing a "dialogue" field. Example: {{"dialogue": "Affirmative."}}"""
            
            print(f"Sending to Gemini: '{player_dialogue}'")
            response = model.generate_content(prompt)
            
            with open(RESPONSE_FILE, 'w') as f:
                f.write(response.text)
                
            print(f"Response written to {RESPONSE_FILE}")

    except Exception as e:
        print(f"An error occurred in watcher.py: {e}")
        error_response = {"dialogue": "AI brain temporarily offline due to an error."}
        try:
            with open(RESPONSE_FILE, 'w') as f:
                json.dump(error_response, f)
        except Exception as file_e:
            print(f"Error writing fallback response to file: {file_e}")

        if os.path.exists(REQUEST_FILE):
            try:
                os.remove(REQUEST_FILE)
            except Exception as remove_e:
                print(f"Error removing stuck request file: {remove_e}")
            
    time.sleep(5)