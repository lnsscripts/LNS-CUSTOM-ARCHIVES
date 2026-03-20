local BASE_URL = "https://lns-custom-auth.lunasgustavo760.workers.dev"
local BOOTSTRAP_URL = BASE_URL .. "/bootstrap"

local RETRY_DELAY = 2000
local MAX_LOAD_RETRIES = 2

local function later(ms, fn)
  if type(schedule) == "function" then
    return schedule(ms, fn)
  end
  if type(scheduleEvent) == "function" then
    return scheduleEvent(fn, ms)
  end
  if g_dispatcher and type(g_dispatcher.scheduleEvent) == "function" then
    return g_dispatcher:scheduleEvent(fn, ms)
  end
  return fn()
end

local function request(url, cb, headers)
  if HTTP and type(HTTP.get) == "function" then
    return HTTP.get(url, cb, headers)
  end

  if modules and modules.corelib and modules.corelib.HTTP and type(modules.corelib.HTTP.get) == "function" then
    return modules.corelib.HTTP.get(url, cb, headers)
  end

  cb(nil, "http_unavailable")
end

local function jsonDecode(str)
  local pos = 1
  local len = #str

  local function skipWs()
    while pos <= len do
      local c = str:sub(pos, pos)
      if c == " " or c == "\n" or c == "\r" or c == "\t" then
        pos = pos + 1
      else
        break
      end
    end
  end

  local parseValue

  local function parseString()
    if str:sub(pos, pos) ~= '"' then
      error("json_string_expected")
    end

    pos = pos + 1
    local out = {}

    while pos <= len do
      local c = str:sub(pos, pos)

      if c == '"' then
        pos = pos + 1
        return table.concat(out)
      end

      if c == "\\" then
        pos = pos + 1
        local esc = str:sub(pos, pos)

        if esc == '"' then
          out[#out + 1] = '"'
        elseif esc == "\\" then
          out[#out + 1] = "\\"
        elseif esc == "/" then
          out[#out + 1] = "/"
        elseif esc == "b" then
          out[#out + 1] = "\b"
        elseif esc == "f" then
          out[#out + 1] = "\f"
        elseif esc == "n" then
          out[#out + 1] = "\n"
        elseif esc == "r" then
          out[#out + 1] = "\r"
        elseif esc == "t" then
          out[#out + 1] = "\t"
        else
          out[#out + 1] = esc
        end

        pos = pos + 1
      else
        out[#out + 1] = c
        pos = pos + 1
      end
    end

    error("json_string_invalid")
  end

  local function parseNumber()
    local s = str:sub(pos)
    local m = s:match("^%-?%d+%.?%d*[eE]?[%+%-]?%d*")

    if not m or m == "" then
      error("json_number_invalid")
    end

    pos = pos + #m
    return tonumber(m)
  end

  local function parseArray()
    if str:sub(pos, pos) ~= "[" then
      error("json_array_expected")
    end

    pos = pos + 1
    local arr = {}
    skipWs()

    if str:sub(pos, pos) == "]" then
      pos = pos + 1
      return arr
    end

    while true do
      arr[#arr + 1] = parseValue()
      skipWs()

      local c = str:sub(pos, pos)
      if c == "]" then
        pos = pos + 1
        break
      elseif c == "," then
        pos = pos + 1
        skipWs()
      else
        error("json_array_invalid")
      end
    end

    return arr
  end

  local function parseObject()
    if str:sub(pos, pos) ~= "{" then
      error("json_object_expected")
    end

    pos = pos + 1
    local obj = {}
    skipWs()

    if str:sub(pos, pos) == "}" then
      pos = pos + 1
      return obj
    end

    while true do
      skipWs()
      local key = parseString()
      skipWs()

      if str:sub(pos, pos) ~= ":" then
        error("json_colon_expected")
      end

      pos = pos + 1
      skipWs()
      obj[key] = parseValue()
      skipWs()

      local c = str:sub(pos, pos)
      if c == "}" then
        pos = pos + 1
        break
      elseif c == "," then
        pos = pos + 1
        skipWs()
      else
        error("json_object_invalid")
      end
    end

    return obj
  end

  function parseValue()
    skipWs()
    local c = str:sub(pos, pos)

    if c == '"' then
      return parseString()
    elseif c == "{" then
      return parseObject()
    elseif c == "[" then
      return parseArray()
    elseif c == "-" or c:match("%d") then
      return parseNumber()
    elseif str:sub(pos, pos + 3) == "true" then
      pos = pos + 4
      return true
    elseif str:sub(pos, pos + 4) == "false" then
      pos = pos + 5
      return false
    elseif str:sub(pos, pos + 3) == "null" then
      pos = pos + 4
      return nil
    end

    error("json_invalid")
  end

  local value = parseValue()
  skipWs()
  return value
end

local function urlEncode(s)
  s = tostring(s or "")
  s = s:gsub("\n", "\r\n")
  s = s:gsub("([^%w%-_%.~])", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
  return s
end

local function fetchBootstrap(cb)
  request(BOOTSTRAP_URL, function(content, err)
    if err or not content or content == "" then
      return cb(nil, err or "bootstrap_empty")
    end

    local ok, data = pcall(jsonDecode, content)
    if not ok or type(data) ~= "table" then
      return cb(nil, "bootstrap_json_invalid")
    end

    if data.success ~= true then
      return cb(nil, data.error or "bootstrap_failed")
    end

    if type(data.token) ~= "string" or data.token == "" then
      return cb(nil, "bootstrap_missing_token")
    end

    if type(data.loadPath) ~= "string" or data.loadPath == "" then
      return cb(nil, "bootstrap_missing_load_path")
    end

    cb({
      tk = data.token,
      expiresIn = data.expiresIn,
      loadPath = data.loadPath,
      mode = data.mode
    }, nil)
  end)
end

local function fetchPayloadWithBoot(boot, cb)
  if type(boot) ~= "table" then
    return cb(nil, "boot_invalid")
  end

  if type(boot.tk) ~= "string" or boot.tk == "" then
    return cb(nil, "boot_token_invalid")
  end

  if type(boot.loadPath) ~= "string" or boot.loadPath == "" then
    return cb(nil, "load_path_missing")
  end

  local finalUrl = BASE_URL .. boot.loadPath .. "?token=" .. urlEncode(boot.tk)

  request(finalUrl, function(payload, err)
    if err or not payload or payload == "" then
      return cb(nil, err or "payload_empty")
    end

    local ok, parsed = pcall(jsonDecode, payload)
    if not ok or type(parsed) ~= "table" then
      return cb(nil, "payload_json_invalid")
    end

    if parsed.success ~= true then
      return cb(nil, parsed.error or "payload_failed")
    end

    if parsed.mode ~= "signed_plain_v1" then
      return cb(nil, "mode_invalid")
    end

    if type(parsed.script) ~= "string" or parsed.script == "" then
      return cb(nil, "script_missing")
    end

    cb(parsed.script, nil)
  end)
end

local function runDecodedScript(decoded)
  local fn, lerr = loadstring(decoded)
  if not fn then
    return false, "decoded_syntax_error: " .. tostring(lerr)
  end

  local ok, runErr = pcall(fn)
  if not ok then
    return false, "decoded_runtime_error: " .. tostring(runErr)
  end

  return true
end

local function doLoadCustom()
  fetchBootstrap(function(boot, bootErr)
    if not boot then
      print("bootstrap_failed: " .. tostring(bootErr))
      return later(RETRY_DELAY, doLoadCustom)
    end

    local retries = 0

    local function tryLoad(bootData)
      fetchPayloadWithBoot(bootData, function(decoded, loadErr)
        if decoded then
          local ok, runErr = runDecodedScript(decoded)
          if ok then
            return
          end

          print(runErr or "decoded_exec_failed")
          return later(RETRY_DELAY, doLoadCustom)
        end

        if loadErr == "token_expired" or loadErr == "token_already_used" then
          if retries < MAX_LOAD_RETRIES then
            retries = retries + 1

            return fetchBootstrap(function(newBoot, newBootErr)
              if not newBoot then
                print("rebootstrap_failed: " .. tostring(newBootErr))
                return later(RETRY_DELAY, doLoadCustom)
              end

              return tryLoad(newBoot)
            end)
          end
        end

        print("payload_failed: " .. tostring(loadErr))
        return later(RETRY_DELAY, doLoadCustom)
      end)
    end

    tryLoad(boot)
  end)
end

doLoadCustom()
