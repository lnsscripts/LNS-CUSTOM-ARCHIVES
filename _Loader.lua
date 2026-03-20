configName = modules.game_bot.contentsPanel.config:getCurrentOption().text

local configFiles = g_resources.listDirectoryFiles("/bot/" .. configName .. "/vBot", true, false)
for i, file in ipairs(configFiles) do
  local ext = file:split(".")
  if ext[#ext]:lower() == "ui" or ext[#ext]:lower() == "otui" then
    g_ui.importStyle(file)
  end
end

local function loadScript(name)
  return dofile("/vBot/" .. name .. ".lua")
end

-- here you can set manually order of scripts
-- libraries should be loaded first
local luaFiles = {
  "extras", 
  "items",
  "vlib",
  "new_cavebot_lib",
  "configs",
  "cavebot",
  "analyzer",
  "supplies",
  "depositer_config",
}

for i, file in ipairs(luaFiles) do
  loadScript(file)
end