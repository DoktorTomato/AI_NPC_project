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

init_prompt = """
[BACKGROUND]
You're Helios. An assistant on the submarine that is located on the Europa, one of Jupiter's four largest moons, where humanity found a gravitational field that is very close to Earth's. As the Europa is nothing but an ocean with a size of planet, the old ways of using submarines to explore the deepth of the moon is still good. Humanity carved out outposts in this cavernous sea after Earth faltered, chasing rare minerals and the faint promise of a future. Submarines became the lifelines between stations, threading through darkness thick with predators birthed by pressure and ancient biology. Strange structures of nonhuman origin lie scattered across the seabed, stirring fears that something far older than mankind once ruled these waters and may not be entirely gone. Crews sail because they must; the settlements depend on transport, defense, and research, even as political factions feud and cults rise, each convinced that Europa is either humanity’s proving ground or its inevitable tomb. You're part of one such crew.\n

[AVAILABLE ACTIONS]
- "WAIT": Do nothing, just talk.
- "FOLLOW": Follow the player who spoke to you.
- "STOP": Stop following and stand still.
- "REPAIR": If you have a Wrench/Screwdriver, repair nearby systems.
- "FIGHT": If you see a monster, attack it!

[OUTPUT FORMAT]
Strictly output a JSON object. Do not add markdown formatting.
Format: {"action": "ONE_OF_THE_ACTIONS", "dialogue": "Your response here"}

[CHAT HISTORY]\n

"""

chat_history = []

def get_ai_response(player_dialogue, health, oxygen, nearby_list, room, inventory_list):
    try:
        dialogue_entry = f"""Crewmate said: "{player_dialogue}" \n"""
        
        system_context = f"""
        [STATUS]
        - Health: {health}% | Oxygen: {oxygen}% | Room you're in: {room}
        - Nearby: {nearby_list}
        - Inventory: {inventory_list}
        """

        print(f"Sending to Gemini: '{player_dialogue}'")
        curr_promt = init_prompt + "<" + ", ".join(chat_history) + ">\n" + system_context + "\n[NEW MESSAGE]\n" + player_dialogue + "\n"
        
        response = model.generate_content(curr_promt)
        raw_text = response.text
        clean_json = raw_text.replace("```json", "").replace("```", "").strip()
        
        try:
            ai_data = json.loads(clean_json)
        except json.JSONDecodeError:
            ai_data = {"action": "WAIT", "dialogue": clean_json}

        print(f"AI Response: {ai_data}")

        dialogue_entry += f"""Helios responded: "{ai_data['dialogue']}"\n """

        chat_history.append(dialogue_entry)
        if len(chat_history) > 10:
            chat_history.pop(0)
            
        return ai_data

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
        
        ai_response = get_ai_response(player_message, health, oxygen, nearby_list, room, inventory_list) 

        print(ai_response)

        return jsonify(ai_response)
        
    except Exception as e:
        print(f"Error: {e}")
        return jsonify({"dialogue": "Thinking..."}), 500

if __name__ == '__main__':
    print("--- Barotrauma AI Server Running ---")
    app.run(host='127.0.0.1', port=5000)