import os
import json
from flask import Flask, request, jsonify
import google.generativeai as genai

try:
    gemini_api_key = os.environ.get("GOOGLE_API_KEY")
    if not gemini_api_key:
        gemini_api_key = "PASTE_YOUR_NEW_SECRET_API_KEY_HERE"
        if gemini_api_key == "PASTE_YOUR_NEW_SECRET_API_KEY_HERE":
             raise ValueError("Gemini API key is not set. Please update GOOGLE_API_KEY environment variable or the code.")

    genai.configure(api_key=gemini_api_key)

    model = genai.GenerativeModel('gemini-2.5-pro')
    print("Gemini API configured successfully.")

except Exception as e:
    print(f"FATAL ERROR during initialization: {e}")
    exit()

app = Flask(__name__)
print("Flask web server initialized.")

def get_ai_response(player_dialogue):
    """Takes player message, calls Gemini, returns AI dialogue."""
    try:
        prompt = f"""You are Helios, a helpful AI crewmate in Barotrauma. A human crewmate said: "{player_dialogue}". 
        Respond in a single, short sentence. Your personality is professional and helpful. 
        Respond ONLY with a valid JSON object containing a "dialogue" field. 
        Example: {{"dialogue": "Affirmative, captain."}}"""
        
        print(f"Sending to Gemini: '{player_dialogue}'")
        response = model.generate_content(prompt)

        raw_response_text = response.text.strip()
        print(f"Raw response text from Gemini: '{raw_response_text}'")
        
        dialogue_text = ""

        try:
            ai_response_json = json.loads(raw_response_text)
            dialogue_text = ai_response_json.get("dialogue", "Error: AI response malformed (JSON missing 'dialogue' key).")
        except json.JSONDecodeError:
            print("Warning: Gemini did not return valid JSON. Using raw text as dialogue.")
            dialogue_text = raw_response_text.strip('"`') 
            if not dialogue_text:
                 dialogue_text = "..."
                
        print(f"Final dialogue to send: '{dialogue_text}'")
        return dialogue_text

    except Exception as e:
        print(f"An error occurred calling Gemini API: {e}")
        return "AI brain temporarily offline."

@app.route('/get-ai-response', methods=['POST'])
def handle_game_request():
    """Handles POST requests from the Lua mod."""
    try:
        data = request.get_json()

        if not data or 'last_player_dialogue' not in data:
            print("Received bad request from game. Missing 'last_player_dialogue'. Data:", data)
            return jsonify({"error": "No 'last_player_dialogue' provided"}), 400

        player_message = data['last_player_dialogue']
        
        print(f"Received message from game: '{player_message}'")
        
        ai_dialogue = get_ai_response(player_message)

        return jsonify({"dialogue": ai_dialogue})
        
    except Exception as e:
        print(f"Critical error in request handler: {e}")
        error_response = {"dialogue": "Critical error in AI core logic."}
        return jsonify(error_response), 500


if __name__ == '__main__':
    print("--- Starting Barotrauma AI Server ---")
    print("Listening on http://127.0.0.1:5000")
    app.run(host='127.0.0.1', port=5000)