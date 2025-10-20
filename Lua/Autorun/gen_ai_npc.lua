local json = {}

do

  json._version = "0.1.2"

  -------------------------------------------------------------------------------
  -- Decode
  -------------------------------------------------------------------------------

  local
  decode

  local
  function decode_error(str, pos, msg)
    local line = 1
    local col = 1
    for i = 1, pos - 1 do
      if str:sub(i, i) == "\n" then
        line = line + 1
        col = 1
      else
        col = col + 1
      end
    end
    error(string.format("%s at line %d col %d", msg, line, col))
  end

  local
  function next_char(str, pos)
    pos = pos + 1
    local c = str:sub(pos, pos)
    if c == "" then
      return nil
    end
    return c, pos
  end

  local
  function next_white(str, pos)
    while true do
      local c
      c, pos = next_char(str, pos)
      if not c or not c:match("%s") then
        return c, pos
      end
    end
  end

  local
  function decode_string(str, pos)
    local res = ""
    while true do
      local c, new_pos = next_char(str, pos)
      if not c then
        decode_error(str, pos, "unterminated string")
      end
      if c == '"' then
        return res, new_pos
      elseif c == '\\' then
        local c2
        c2, new_pos = next_char(str, new_pos)
        if c2 == '"' then
          res = res .. '"'
        elseif c2 == '\\' then
          res = res .. '\\'
        elseif c2 == '/' then
          res = res .. '/'
        elseif c2 == 'b' then
          res = res .. '\b'
        elseif c2 == 'f' then
          res = res .. '\f'
        elseif c2 == 'n' then
          res = res .. '\n'
        elseif c2 == 'r' then
          res = res .. '\r'
        elseif c2 == 't' then
          res = res .. '\t'
        elseif c2 == 'u' then
          local hex = str:sub(new_pos + 1, new_pos + 4)
          if not hex:match("^[0-9a-fA-F]{4}$") then
            decode_error(str, pos, "invalid unicode escape")
          end
          -- To keep it simple for Barotrauma, we won't handle unicode conversion
          -- This part is often not needed for simple dialogue.
          res = res .. '?'
          new_pos = new_pos + 4
        else
          decode_error(str, pos, "invalid escape char")
        end
        pos = new_pos
      else
        res = res .. c
        pos = new_pos
      end
    end
  end

  local
  function decode_number(str, pos)
    local num_str = str:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
    local n = tonumber(num_str)
    if not n then
      decode_error(str, pos, "invalid number")
    end
    return n, pos + #num_str
  end

  local
  function decode_literal(str, pos)
    local literal_map = {
      ["true"] = true,
      ["false"] = false,
      ["null"] = nil,
    }
    for lit, val in pairs(literal_map) do
      if str:sub(pos, pos + #lit - 1) == lit then
        return val, pos + #lit
      end
    end
    decode_error(str, pos, "invalid literal")
  end

  local
  function decode_array(str, pos)
    local res = {}
    while true do
      local c
      c, pos = next_white(str, pos)
      if not c then
        decode_error(str, pos, "unterminated array")
      end
      if c == ']' then
        return res, pos
      end
      local val
      val, pos = decode(str, pos)
      table.insert(res, val)
      c, pos = next_white(str, pos)
      if c == ']' then
        return res, pos
      end
      if c ~= ',' then
        decode_error(str, pos, "expected ']' or ','")
      end
    end
  end

  local
  function decode_object(str, pos)
    local res = {}
    while true do
      local c
      c, pos = next_white(str, pos)
      if not c then
        decode_error(str, pos, "unterminated object")
      end
      if c == '}' then
        return res, pos
      end
      if c ~= '"' then
        decode_error(str, pos, "expected string for key")
      end
      local key
      key, pos = decode_string(str, pos)
      c, pos = next_white(str, pos)
      if c ~= ':' then
        decode_error(str, pos, "expected ':'")
      end
      local val
      val, pos = decode(str, pos + 1)
      res[key] = val
      c, pos = next_white(str, pos)
      if c == '}' then
        return res, pos
      end
      if c ~= ',' then
        decode_error(str, pos, "expected '}' or ','")
      end
    end
  end

  decode = function(str, pos)
    local c
    c, pos = next_white(str, pos or 0)
    if not c then
      decode_error(str, pos, "empty string")
    end
    if c == '"' then
      return decode_string(str, pos)
    end
    if c == '{' then
      return decode_object(str, pos + 1)
    end
    if c == '[' then
      return decode_array(str, pos + 1)
    end
    if c:match("[-%d]") then
      return decode_number(str, pos)
    end
    return decode_literal(str, pos)
  end

  function
  json.decode(str)
    return decode(str)
  end


  -------------------------------------------------------------------------------
  -- Encode
  -------------------------------------------------------------------------------

  local
  encode

  local
  escape_char_map = {
    ['\\'] = '\\\\',
    ['"'] = '\\"',
    ['\b'] = '\\b',
    ['\f'] = '\\f',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',
  }

  local
  function encode_nil(val)
    return "null"
  end

  local
  function encode_table(val, stack)
    local res = {}
    stack = stack or {}
    if stack[val] then
      error("circular reference")
    end
    stack[val] = true
    if #val > 0 then
      -- Array
      for i = 1, #val do
        table.insert(res, encode(val[i], stack))
      end
      stack[val] = nil
      return "[" .. table.concat(res, ",") .. "]"
    else
      -- Object
      for k, v in pairs(val) do
        if type(k) ~= "string" then
          error("invalid key type:" .. type(k))
        end
        table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
      end
      stack[val] = nil
      return "{" .. table.concat(res, ",") .. "}"
    end
  end

  local
  function encode_string(val)
    return '"' .. val:gsub('[%c"\\]', escape_char_map) .. '"'
  end

  local
  function encode_number(val)
    if val ~= val or val == math.huge or val == -math.huge then
      error("cannot encode NAN or Infinity")
    end
    return string.format("%.14g", val)
  end

  local
  type_func_map = {
    ["nil"] = encode_nil,
    ["table"] = encode_table,
    ["string"] = encode_string,
    ["number"] = encode_number,
    ["boolean"] = tostring,
  }

  encode = function(val, stack)
    local t = type(val)
    local f = type_func_map[t]
    if f then
      return f(val, stack)
    end
    error("unsupported type: " .. t)
  end

  function
  json.encode(val)
    return encode(val)
  end
end

print("GEN AI NPC SCRIPT LOADED (Networking.HttpPost Version)")

local PYTHON_SERVER_URL = "http://127.0.0.1:5000/get-ai-response"

function onServerResponse(responseBody)
    if not responseBody then
        print("HTTP Request Failed! No response body received.")
        return
    end

    print("Received response from Python server. Body: " .. responseBody)

    local success, response_data = pcall(json.decode, responseBody)
    
    if success and response_data and response_data.dialogue then
        for _, character in ipairs(Character.GetList()) do -- Use Character.GetList()
            if character.SpeciesName == "GenAICompanion" and not character.IsDead then
                character.Say(response_data.dialogue, ChatMessageType.Default, false, false)
                print("AI Companion is speaking.")
                return -- We found one, no need to keep looping
            end
        end
    else
        print("Failed to decode JSON from server response. Content: " .. tostring(responseBody))
    end
end

function onChatMessage(message, client)
    if client and client.Character and client.Character.SpeciesName == "GenAICompanion" then
        return
    end

    local command, args = message:match("(!%S+)%s*(.*)")
    if not command or command:lower() ~= "!helios" then
        return -- Message is not for our NPC
    end
    
    local playerMessage = args
    if playerMessage == "" then return end

    print("Command received for Helios: '" .. playerMessage .. "'.")

    local aiFound = false
    for _, character in ipairs(Character.CharacterList) do
        if character.SpeciesName == "GenAICompanion" and not character.IsDead then
            aiFound = true
            break
        end
    end

    if aiFound then
        print("Found GenAICompanion. Sending HTTP request via Networking.HttpPost...")

        local gameState = { last_player_dialogue = playerMessage }
        local jsonData = json.encode(gameState)

        Networking.HttpPost(PYTHON_SERVER_URL, onServerResponse, jsonData, "application/json")
        
        return true
    end
    
    return false
end

Hook.Add("chatmessage", "GenAI_OnChatMessage", onChatMessage)

print(">>>> SCRIPT IS READY. Use '!helios message' to chat. <<<<")