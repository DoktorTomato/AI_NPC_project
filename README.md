# AI_NPC_project
Authors: [Іван Шевчук](https://github.com/DoktorTomato), [Данило Биков](https://github.com/DanyaBykov)

This repo is a project that contains a mod for the Baratrauma game, that adds an AI controlled companion.

## Usage

To use this mod put the content of the repository in the folder 'LocalMods' that is located in the root directory of the Baratrauma game.

Also you need to install one mod: [Lua for Barotrauma](https://steamcommunity.com/sharedfiles/filedetails/?id=2559634234)

Then you may need to install Flask and google-generativeai (as this mod uses Gemini API)
```
pip install flask google-generativeai
```

Then you need to set your Gemini API key as an environment variable and launch the server:
```
export GOOGLE_API_KEY=YOUR_API_KEY
python3 ai_server.py
```

Or pass the key to the server when launching it:
```
GOOGLE_API_KEY=YOUR_API_KEY python3 ai_server.py
```

Now you can launch the game, the mod should automatically load the Lua script and connect to the python server.

To use it in game, you can use the chat command to communicate with him
```
!helios <your message>
```