print("GEN AI NPC SCRIPT LOADED")

local REQUEST_FILE_PATH = "..\\..\\temp\\request.json"
local RESPONSE_FILE_PATH = "..\\..\\temp\\response.json"

function onChatMessage(message, client)
    if message:lower() == "check" then
        return
    end

    if client and client.Character and client.Character.SpeciesName == "GenAICompanion" then
        return
    end

    print("Player message received: '" .. message .. "'.")

    for _, character in ipairs(Character.CharacterList) do
        if character.SpeciesName == "GenAICompanion" and not character.IsDead then
            print("Found GenAICompanion. Writing to request file...")
            
            local gameState = { last_player_dialogue = message }
            
            local file, err = io.open(REQUEST_FILE_PATH, "w")
            if file then
                file:write(JSON.Encode(gameState))
                file:close()
                print("Request file written successfully.")
            else
                print("Failed to write request file! Error: " .. tostring(err))
            end
            return
        end
    end
end

function checkForResponse(message, client)
    if message:lower() ~= "check" then
        return
    end

    print("Command received. Checking for response file...")

    local file = io.open(RESPONSE_FILE_PATH, "r")
    
    if file then
        local response_text = file:read("*a")
        file:close()
        
        os.remove(RESPONSE_FILE_PATH)
        
        print("Response file found! Processing...")
        
        local success, response_data = JSON.TryDecode(response_text)
        if success and response_data and response_data.dialogue then
            for _, character in ipairs(Character.GetList()) do
                if character.SpeciesName == "GenAICompanion" and not character.IsDead then
                    character.Say(response_data.dialogogue, ChatMessageType.Default, false, false)
                end
            end
        else
            Debug.LogError("Failed to decode JSON from response file. Content: " .. tostring(response_text))
        end
    else
        print("No response file found yet.")
    end

    return true
end

Hook.Add("chatmessage", "GenAI_OnChatMessage", onChatMessage)
Hook.Add("chatmessage", "GenAI_OnChatRecieve", checkForResponse)

print(">>>> SCRIPT IS READY. Chat to send, use 'check' command to receive. <<<<")