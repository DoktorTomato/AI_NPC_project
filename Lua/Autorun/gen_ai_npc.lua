print(">>>> GEN AI NPC SCRIPT LOADED <<<<")

local thinkTimer = 0
local thinkInterval = 5.0

local PYTHON_SERVER_URL = "http://127.0.0.1:5000/get-ai-response"

local json = {}
do
  json._version = "0.1.2"
  local decode
  local function decode_error(str, pos, msg)
    local line, col = 1, 1
    for i = 1, pos - 1 do
      if str:sub(i, i) == "\n" then line = line + 1; col = 1 else col = col + 1 end
    end
    error(string.format("%s at line %d col %d", msg, line, col))
  end
  local function next_char(str, pos)
    pos = pos + 1
    local c = str:sub(pos, pos)
    return (c ~= "" and c or nil), pos
  end
  local function next_white(str, pos)
    while true do
      local c; c, pos = next_char(str, pos)
      if not c or not c:match("%s") then return c, pos end
    end
  end
  local function decode_string(str, pos)
    local res = ""
    while true do
      local c, new_pos = next_char(str, pos)
      if not c then decode_error(str, pos, "unterminated string") end
      if c == '"' then return res, new_pos
      elseif c == '\\' then
        local c2; c2, new_pos = next_char(str, new_pos)
        if c2 == '"' then res = res .. '"' elseif c2 == '\\' then res = res .. '\\' elseif c2 == '/' then res = res .. '/'
        elseif c2 == 'b' then res = res .. '\b' elseif c2 == 'f' then res = res .. '\f' elseif c2 == 'n' then res = res .. '\n'
        elseif c2 == 'r' then res = res .. '\r' elseif c2 == 't' then res = res .. '\t'
        else new_pos = new_pos + 4 end 
        pos = new_pos
      else res = res .. c; pos = new_pos end
    end
  end
  local function decode_number(str, pos)
    local num_str = str:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
    if not num_str then decode_error(str, pos, "invalid number") end
    return tonumber(num_str), pos + #num_str
  end
  local function decode_literal(str, pos)
    local literals = {["true"]=true, ["false"]=false, ["null"]=nil}
    for lit, val in pairs(literals) do
      if str:sub(pos, pos + #lit - 1) == lit then return val, pos + #lit end
    end
    decode_error(str, pos, "invalid literal")
  end
  local function decode_array(str, pos)
    local res = {}
    local c
    c, pos = next_white(str, pos)
    if c == ']' then return res, pos end
    while true do
      local val; val, pos = decode(str, pos)
      table.insert(res, val)
      c, pos = next_white(str, pos)
      if c == ']' then return res, pos end
      if c ~= ',' then decode_error(str, pos, "expected ']' or ','") end
    end
  end
  local function decode_object(str, pos)
    local res = {}
    local c
    c, pos = next_white(str, pos)
    if c == '}' then return res, pos end
    while true do
      local key; key, pos = decode_string(str, pos)
      c, pos = next_white(str, pos)
      if c ~= ':' then decode_error(str, pos, "expected ':'") end
      local val; val, pos = decode(str, pos)
      res[key] = val
      c, pos = next_white(str, pos)
      if c == '}' then return res, pos end
      if c ~= ',' then decode_error(str, pos, "expected '}' or ','") end
    end
  end
  decode = function(str, pos)
    local c; c, pos = next_white(str, pos or 0)
    if not c then decode_error(str, pos, "empty string") end
    if c == '"' then return decode_string(str, pos)
    elseif c == '{' then return decode_object(str, pos)
    elseif c == '[' then return decode_array(str, pos)
    elseif c:match("[-%d]") then return decode_number(str, pos)
    else return decode_literal(str, pos) end
  end
  json.decode = decode
  function json.encode(val)
      local t = type(val)
      if t == "table" then
          local res = {}
          local is_arr = (#val > 0)
          if is_arr then
            for _, v in ipairs(val) do table.insert(res, json.encode(v)) end
            return "[" .. table.concat(res, ",") .. "]"
          else
            for k, v in pairs(val) do table.insert(res, '"'..tostring(k)..'":' .. json.encode(v)) end
            return "{" .. table.concat(res, ",") .. "}"
          end
      elseif t == "string" then return '"' .. val .. '"'
      elseif t == "number" or t == "boolean" then return tostring(val)
      else return "null" end
  end
end

local function sanitize_json_string(str)
    if not str then return "" end
    local start_pos = str:find("{")
    local last_brace = 0
    local i = str:len()
    while i > 0 do
        if str:sub(i, i) == "}" then
            last_brace = i
            break
        end
        i = i - 1
    end
    if start_pos and last_brace > 0 then
        return str:sub(start_pos, last_brace)
    end
    return str
end

local function get_bot_context(char)
    local context = {}

    context.health = math.floor(char.Vitality)
    if char.CharacterHealth then
        context.oxygen = math.floor(char.CharacterHealth.OxygenAmount)
    else
        context.oxygen = 100 
    end

    if char.CurrentHull then
        context.room_name = char.CurrentHull.RoomName or "Unknown Room"
    else
        context.room_name = "Outside Submarine"
    end

    context.inventory = {}
    local inventory = char.Inventory
    if inventory then
        for item in inventory.AllItems do
            table.insert(context.inventory, item.Name)
        end
    end
    if #context.inventory == 0 then
        table.insert(context.inventory, "Nothing")
    end

    context.nearby_entities = {}
    for other in Character.CharacterList do
        if other ~= char and not other.IsDead then
            if Vector2.Distance(char.WorldPosition, other.WorldPosition) < 500 then
                local name = other.Name
                if other.SpeciesName ~= "Human" then
                    name = other.SpeciesName 
                end
                table.insert(context.nearby_entities, name)
            end
        end
    end
    if #context.nearby_entities == 0 then
        table.insert(context.nearby_entities, "No one")
    end
    
    return context
end

local function execute_ai_action(character, action, player_char)
    local controller = character.AIController
    if not controller then return end

    print("Executing Order: " .. action)

    if action == "FOLLOW" and player_char then
        -- Order: Follow the player
        local orderPrefab = OrderPrefab.Get("follow")
        -- SetOrder(Order, Option, Target, Giver)
        character.SetOrder(orderPrefab, nil, player_char, player_char)
    
    elseif action == "STOP" then
        -- Order: Dismiss / Wait
        local orderPrefab = OrderPrefab.Get("wait")
        character.SetOrder(orderPrefab, nil, character, nil)
        character.ClearOrders() -- Clear previous orders

    elseif action == "REPAIR" then
        -- Order: Repair Hull & Devices
        local fixLeaks = OrderPrefab.Get("fixleaks")
        local fixItems = OrderPrefab.Get("repairsystems")
        character.SetOrder(fixLeaks, nil, character.CurrentHull, nil)
        character.AddOrder(fixItems, nil, character.CurrentHull, nil)

    elseif action == "FIGHT" then
        -- Order: Fight Intruders
        local fight = OrderPrefab.Get("fightintruders")
        character.SetOrder(fight, nil, character.CurrentHull, nil)
    end
end

function onServerResponse(responseBody)
    if not responseBody then return end

    local cleanBody = sanitize_json_string(responseBody)
    local success, response_data = pcall(json.decode, cleanBody)
    
    if success and response_data then
        for character in Character.CharacterList do
            if character.SpeciesName == "Human" and character.Info.Name == "Helios" and not character.IsDead then
                if response_data.dialogue then
                    character.Speak(response_data.dialogue, ChatMessageType.Radio)
                    print("AI Companion spoke: " .. response_data.dialogue)
                end
                if response_data.action then
                    execute_ai_action(character, response_data.action, Character.Controlled)
                end
                return 
            end
        end
    else
        print("[ERROR] JSON Decode Failed.")
        print("Raw: " .. tostring(cleanBody))
        print("Error: " .. tostring(response_data))
    end
end

function onChatMessage(message, client)
    if client and client.Character and client.Character.Info.Name == "Helios" then return end

    local command, args = message:match("(!%S+)%s*(.*)")
    if not command or command:lower() ~= "!helios" then return end
    
    local playerMessage = args
    if playerMessage == "" then return end

    print("Command received for Helios: '" .. playerMessage .. "'.")

    local aiBot = nil
    for character in Character.CharacterList do
        if character.SpeciesName == "Human" and character.Info.Name == "Helios" and not character.IsDead then
            aiBot = character
            break
        end
    end

    if aiBot then
        local botStatus = get_bot_context(aiBot)
        local gameState = { 
            last_player_dialogue = playerMessage,
            status = botStatus 
        }
        
        local jsonData = json.encode(gameState)
        Networking.HttpPost(PYTHON_SERVER_URL, onServerResponse, jsonData, "application/json")
        return true 
    end
    return false
end

Hook.Add("chatmessage", "GenAI_OnChatMessage", onChatMessage)

Game.AddCommand("taghelios", "Turns the nearest human into Helios", function()
    local player = Character.Controlled
    if not player then 
        print("Error: You must be controlling a character.") 
        return 
    end

    local closestChar = nil
    local minDistance = 200 

    for char in Character.CharacterList do
        if char ~= player and char.SpeciesName == "Human" and not char.IsDead then
            local dist = Vector2.Distance(player.WorldPosition, char.WorldPosition)
            if dist < minDistance then
                minDistance = dist
                closestChar = char
            end
        end
    end

    if closestChar then
        closestChar.Info.Name = "Helios"
        local headset = ItemPrefab.GetItemPrefab("headset")
        Entity.Spawner.AddItemToSpawnQueue(headset, closestChar.Inventory, nil, nil, function(item)
            closestChar.Inventory.TryPutItem(item, 3, true, false, closestChar, true)
        end)
        print("Success! The crewmate '" .. closestChar.Name .. "' has been upgraded to Helios.")
    else
        print("Error: No human found nearby. Stand closer!")
    end
end)

Hook.Add("think", "Helios_Autonomy", function()
    -- Only run if a Round is active
    if not Game.RoundStarted then return end

    -- Ticker Logic
    thinkTimer = thinkTimer + 1.0 / 60.0 -- Lua runs at 60fps usually
    if thinkTimer < thinkInterval then return end
    thinkTimer = 0 -- Reset timer

    -- FIND HELIOS
    local helios = nil
    for char in Character.CharacterList do
        if char.SpeciesName == "Human" and char.Info.Name == "Helios" and not char.IsDead then
            helios = char
            break
        end
    end
    if not helios then return end

    -- CHECK TRIGGERS (Only bother the AI if something happens)
    local should_trigger_ai = false
    local trigger_reason = ""

    -- Trigger 1: Pain (Health dropped below 80)
    if helios.Vitality < 80 then
        should_trigger_ai = true
        trigger_reason = "I am injured!"
    end

    -- Trigger 2: Monsters nearby
    for other in Character.CharacterList do
        if other.SpeciesName ~= "Human" and not other.IsDead then
             if Vector2.Distance(helios.WorldPosition, other.WorldPosition) < 500 then
                 should_trigger_ai = true
                 trigger_reason = "There is a monster (" .. other.SpeciesName .. ") right next to me!"
                 break
             end
        end
    end

    -- EXECUTE (Send to Python unprompted)
    if should_trigger_ai then
        -- We construct a "fake" message from the system to prompt the AI
        print("Triggering Autonomous AI: " .. trigger_reason)
        
        local botStatus = get_bot_context(helios)
        local gameState = { 
            last_player_dialogue = "[SYSTEM EVENT]: " .. trigger_reason,
            status = botStatus 
        }
        local jsonData = json.encode(gameState)
        Networking.HttpPost(PYTHON_SERVER_URL, onServerResponse, jsonData, "application/json")
        
        -- Increase interval so he doesn't spam scream every 5 seconds
        thinkTimer = -10 -- Wait 15 seconds before checking again
    end
end)