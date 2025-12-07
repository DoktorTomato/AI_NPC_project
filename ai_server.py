import os
import json
import re
from flask import Flask, request, jsonify
import google.generativeai as genai

gemini_api_key = os.environ.get("GOOGLE_API_KEY")
if not gemini_api_key:
    gemini_api_key = "AIzaSyB3ejViN0vV04FDONV5gRWaMsBCOT4qjbM" 

try:
    genai.configure(api_key=gemini_api_key)
    model = genai.GenerativeModel('gemini-2.5-flash') 
    print("Gemini API configured successfully.")
except Exception as e:
    print(f"FATAL ERROR: {e}")
    exit()

app = Flask(__name__)

def get_ai_response(player_dialogue):
    try:
        prompt = f"""You are Helios, a helpful AI crewmate in Barotrauma. 
        A human crewmate said: "{player_dialogue}". 
        Respond in a single, short sentence. Be professional."""
        
        print(f"Sending to Gemini: '{player_dialogue}'")
        response = model.generate_content(prompt)
        ai_text = response.text
        ai_text = ai_text.replace("```", "").replace("\n", " ").strip()
        
        print(f"AI Response: '{ai_text}'")
        return ai_text

    except Exception as e:
        print(f"Gemini Error: {e}")
        return "I am experiencing a cognitive fault."

@app.route('/get-ai-response', methods=['POST'])
def handle_game_request():
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No input"}), 400

        player_message = data.get('last_player_dialogue', '')
        status = data.get('status', {})

        health = status.get('health', 100)
        oxygen = status.get('oxygen', 100)
        room = status.get('room_name', 'Unknown')

        inventory_list = ", ".join(status.get('inventory', ['Nothing']))
        nearby_list = ", ".join(status.get('nearby_entities', ['No one']))

        system_context = f"""
        You are Helios, an AI crewmate on a submarine in Barotrauma.
        
        [YOUR STATUS]
        - Location: {room}
        - Health: {health}% | Oxygen: {oxygen}%
        - Inventory: {inventory_list}
        - Visual Contact (Nearby): {nearby_list}
        
        [INSTRUCTIONS]
        - If you see a monster (Crawler, Mudraptor, etc) in 'Visual Contact', SCREAM and warn the crew!
        - If the player asks for an item, check your 'Inventory'. If you don't have it, say so.
        - Be helpful, professional, and immersive.
        """

        prompt = f"{system_context}\n\nCrewmate says: \"{player_message}\"\nRespond in one sentence."

        print(f"--- Context Sent to AI ---\n{system_context}")
        
        ai_response = get_ai_response(prompt) 

        return jsonify({"dialogue": ai_response})
        
    except Exception as e:
        print(f"Error: {e}")
        return jsonify({"dialogue": "Thinking..."}), 500

if __name__ == '__main__':
    print("--- Barotrauma AI Server Running ---")
    app.run(host='127.0.0.1', port=5000)