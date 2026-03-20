g_ui.loadUIFromString([[
TargetBotLootingPanel < Panel
  layout:
    type: verticalBox
    fit-children: true

  HorizontalSeparator
    margin-top: 5

  Label
    margin-top: 5
    text: ITEMS PARA LOTEAR
    color: orange
    font: verdana-9px
    text-align: center    

  BotContainer
    id: items
    margin-top: 3
  
  BotSwitch
    id: everyItem
    !text: tr("COLETAR TUDO")
    font: verdana-9px
    margin-top: 2

  HorizontalSeparator
    margin-top: 3

  Panel
    id: selectedItemsPanel
    height: 45

    BotTextEdit
      id: names
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 5
      font: verdana-11px-rounded

    BotSwitch
      id: selectedItems
      anchors.top: names.bottom
      anchors.left: names.left
      anchors.right: names.right
      !text: tr("SMARTING LOOT")
      font: verdana-9px
      margin-top: 3

  HorizontalSeparator
    margin-top: 5

  Label
    margin-top: 5
    text: BP/BAG PARA MOVER LOOT
    font: verdana-9px
    color: orange
    text-align: center

  BotContainer
    id: containers
    margin-top: 3
    height: 34
  
  Panel
    id: maxDangerPanel
    height: 20
    margin-top: 5
    visible: false

    BotTextEdit
      id: value
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      margin-right: 6
      width: 80

    Label
      anchors.left: parent.left
      anchors.verticalCenter: prev.verticalCenter
      text: Max. danger:
      margin-left: 5

  Panel
    id: minCapacityPanel
    height: 20
    margin-top: 3
    visible: false

    BotTextEdit
      id: value
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      margin-right: 6
      width: 80

    Label
      anchors.left: parent.left
      anchors.verticalCenter: prev.verticalCenter
      text: Min. capacity:
      margin-left: 5
  
  Panel
    id: delayOptionsPanel
    height: 45
    margin-top: 3

    BotTextEdit
      id: openDelay
      anchors.right: parent.right
      anchors.top: parent.top
      margin-right: 6
      width: 80

    Label
      anchors.left: parent.left
      anchors.verticalCenter: prev.verticalCenter
      text: Open delay:
      font: verdana-9px
      margin-left: 5

    BotTextEdit
      id: moveDelay
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      margin-top: 23
      margin-right: 6
      width: 80

    Label
      anchors.left: parent.left
      anchors.verticalCenter: prev.verticalCenter
      text: Move delay:
      font: verdana-9px
      margin-left: 5
]])

TargetBot.Looting = {}
TargetBot.Looting.list = {}

local ui
local items = {}
local containers = {}
local itemsById = {}
local containersById = {}
local dontSave = false

local function trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function safeRead(path)
  if not g_resources or not g_resources.readFileContents then
    return nil
  end
  local ok, content = pcall(function() return g_resources.readFileContents(path) end)
  if not ok or not content or content == "" then return nil end
  return content
end

local function loadLootItems()
  local cfgName = (type(MyConfigName) == "string" and MyConfigName ~= "" and MyConfigName) or "CUSTOM"
  local content =
    safeRead("/bot/" .. cfgName .. "/loot_items.lua") or
    safeRead("/bot/" .. cfgName .. "/loot_items") or
    safeRead("loot_items.lua")

  if not content then
    warn("[Looting] nao achei loot_items.lua")
    return {}
  end

  local list = {}
  local seen = {}

  for name, idStr in content:gmatch('%["(.-)"%]%s*=%s*(%d+)') do
    local id = tonumber(idStr)
    if id and not seen[id] then
      seen[id] = true
      list[#list + 1] = { name = tostring(name), id = id }
    end
  end

  table.sort(list, function(a, b) return (a.id or 0) < (b.id or 0) end)
  return list
end

local lootItemNameById = {}
for _, e in ipairs(loadLootItems()) do
  if e.id and e.name and e.name ~= "" then
    lootItemNameById[e.id] = e.name
  end
end

local function getLootItemDisplayName(itemId)
  itemId = tonumber(itemId) or 0
  if itemId <= 0 then return nil end
  return lootItemNameById[itemId]
end

local function rebuildNamesFromItems()
  if not ui or not ui.items or not ui.selectedItemsPanel or not ui.selectedItemsPanel.names then
    return
  end

  local list = ui.items:getItems() or {}
  local names = {}
  local seen = {}

  for _, item in ipairs(list) do
    local itemId = tonumber(item.id or 0) or 0
    local itemName = getLootItemDisplayName(itemId)

    if itemName then
      local cleanName = trim(itemName)
      local key = cleanName:lower()

      if cleanName ~= "" and not seen[key] then
        seen[key] = true
        names[#names + 1] = cleanName
      end
    end
  end

  dontSave = true
  ui.selectedItemsPanel.names:setText(table.concat(names, ", "))
  dontSave = false
end

TargetBot.Looting.setup = function()
  ui = UI.createWidget("TargetBotLootingPanel")
  UI.ContainerEx(TargetBot.Looting.onItemsUpdate, true, nil, ui.items)
  UI.ContainerEx(TargetBot.Looting.onContainersUpdate, true, nil, ui.containers)

  ui.everyItem.onClick = function()
    ui.everyItem:setOn(not ui.everyItem:isOn())
    TargetBot.save()
  end

  ui.selectedItemsPanel.selectedItems.onClick = function()
    ui.selectedItemsPanel.selectedItems:setOn(not ui.selectedItemsPanel.selectedItems:isOn())
    TargetBot.save()
  end

  ui.selectedItemsPanel.names.onTextChange = function()
    if dontSave then return end
    TargetBot.save()
  end

  ui.maxDangerPanel.value.onTextChange = function()
    local value = tonumber(ui.maxDangerPanel.value:getText())
    if not value then
      ui.maxDangerPanel.value:setText(0)
    end
    if dontSave then return end
    TargetBot.save()
  end

  ui.minCapacityPanel.value.onTextChange = function()
    local value = tonumber(ui.minCapacityPanel.value:getText())
    if not value then
      ui.minCapacityPanel.value:setText(0)
    end
    if dontSave then return end
    TargetBot.save()
  end

  ui.delayOptionsPanel.openDelay.onTextChange = function()
    local value = tonumber(ui.delayOptionsPanel.openDelay:getText())
    if not value then
      ui.delayOptionsPanel.openDelay:setText(500)
    end
    if dontSave then return end
    TargetBot.save()
  end

  ui.delayOptionsPanel.moveDelay.onTextChange = function()
    local value = tonumber(ui.delayOptionsPanel.moveDelay:getText())
    if not value then
      ui.delayOptionsPanel.moveDelay:setText(300)
    end
    if dontSave then return end
    TargetBot.save()
  end
end

TargetBot.Looting.onItemsUpdate = function()
  rebuildNamesFromItems()
  if dontSave then return end
  TargetBot.save()
  TargetBot.Looting.updateItemsAndContainers()
end

TargetBot.Looting.onContainersUpdate = function()
  if dontSave then return end
  TargetBot.save()
  TargetBot.Looting.updateItemsAndContainers()
end

TargetBot.Looting.update = function(data)
  dontSave = true
  TargetBot.Looting.list = {}
  ui.items:setItems(data['items'] or {})
  ui.containers:setItems(data['containers'] or {})
  ui.everyItem:setOn(data['everyItem'])
  ui.selectedItemsPanel.selectedItems:setOn(data['selectedItems'])
  ui.selectedItemsPanel.names:setText(data['names'] or "")
  ui.maxDangerPanel.value:setText(data['maxDanger'] or 10)
  ui.minCapacityPanel.value:setText(data['minCapacity'] or 100)
  ui.delayOptionsPanel.openDelay:setText(data['openDelay'] or 500)
  ui.delayOptionsPanel.moveDelay:setText(data['moveDelay'] or 300)
  TargetBot.Looting.updateItemsAndContainers()
  rebuildNamesFromItems()
  dontSave = false
  
  vBot.lootConainers = {}
  vBot.lootItems = {}
  for i, item in ipairs(ui.containers:getItems()) do
    table.insert(vBot.lootConainers, item['id'])
  end
  for i, item in ipairs(ui.items:getItems()) do
    table.insert(vBot.lootItems, item['id'])
  end
end

TargetBot.Looting.save = function(data)
  data['items'] = ui.items:getItems()
  data['containers'] = ui.containers:getItems()
  data['maxDanger'] = tonumber(ui.maxDangerPanel.value:getText())
  data['minCapacity'] = tonumber(ui.minCapacityPanel.value:getText())
  data['everyItem'] = ui.everyItem:isOn()
  data['selectedItems'] = ui.selectedItemsPanel.selectedItems:isOn()
  data['names'] = ui.selectedItemsPanel.names:getText()
  data['openDelay'] = ui.delayOptionsPanel.openDelay:getText()
  data['moveDelay'] = ui.delayOptionsPanel.moveDelay:getText()
end

TargetBot.Looting.updateItemsAndContainers = function()
  items = ui.items:getItems()
  containers = ui.containers:getItems()
  itemsById = {}
  containersById = {}

  for i, item in ipairs(items) do
    itemsById[item.id] = 1
  end

  for i, container in ipairs(containers) do
    containersById[container.id] = 1
  end
end

local waitTill = 0
local waitingForContainer = nil
local status = ""
local lastFoodConsumption = 0

TargetBot.Looting.getStatus = function()
  return status
end

TargetBot.Looting.process = function(targets, dangerLevel)
  if (not items[1] and not ui.everyItem:isOn()) or not containers[1] then
    status = ""
    return false
  end

  if dangerLevel > tonumber(ui.maxDangerPanel.value:getText()) then
    status = "High danger"
    return false
  end

  if player:getFreeCapacity() < tonumber(ui.minCapacityPanel.value:getText()) then
    status = "No cap"
    TargetBot.Looting.list = {}
    return false
  end

  local loot = TargetBot.Looting.list[1]
  if loot == nil then
    status = ""
    return false
  end

  if waitTill > now then
    return true
  end
  
  local containers = g_game.getContainers()
  local lootContainers = TargetBot.Looting.getLootContainers(containers)

  if not lootContainers[1] then
    status = "No space"
    return false
  end

  status = "Looting"

  for index, container in pairs(containers) do
    if container.lootContainer then
      TargetBot.Looting.lootContainer(lootContainers, container)
      return true
    end
  end

  local pos = player:getPosition()
  local dist = math.max(math.abs(pos.x - loot.pos.x), math.abs(pos.y - loot.pos.y))
  local maxRange = 40

  if loot.tries > 30 or loot.pos.z ~= pos.z or dist > maxRange then
    table.remove(TargetBot.Looting.list, 1)
    return true
  end

  local tile = g_map.getTile(loot.pos)
  if dist >= 3 or not tile then
    loot.tries = loot.tries + 1
    TargetBot.walkTo(loot.pos, 20, { ignoreNonPathable = true, precision = 2 })
    return true
  end

  local container = tile:getTopUseThing()
  if not container or not container:isContainer() then
    table.remove(TargetBot.Looting.list, 1)
    return true
  end

  waitTill = now + tonumber(ui.delayOptionsPanel.openDelay:getText())
  g_game.open(container)
  waitingForContainer = container:getId()
  loot.tries = loot.tries + 1

  return true
end

TargetBot.Looting.getLootContainers = function(containers)
  local lootContainers = {}
  local openedContainersById = {}
  local toOpen = nil

  for index, container in pairs(containers) do
    openedContainersById[container:getContainerItem():getId()] = 1
    if containersById[container:getContainerItem():getId()] and not container.lootContainer then
      if container:getItemsCount() < container:getCapacity() or container:hasPages() then
        table.insert(lootContainers, container)
      else
        for slot, item in ipairs(container:getItems()) do
          if item:isContainer() and containersById[item:getId()] then
            toOpen = {item, container}
            break
          end
        end
      end
    end
  end

  if not lootContainers[1] then
    if toOpen then
      g_game.open(toOpen[1], toOpen[2])
      waitTill = now + tonumber(ui.delayOptionsPanel.openDelay:getText())
      return lootContainers
    end

    for index, container in pairs(containers) do
      if not containersById[container:getContainerItem():getId()] and not container.lootContainer then
        for slot, item in ipairs(container:getItems()) do
          if item:isContainer() and containersById[item:getId()] then
            g_game.open(item)
            waitTill = now + tonumber(ui.delayOptionsPanel.openDelay:getText())
            return lootContainers
          end
        end
      end
    end

    for slot = InventorySlotFirst, InventorySlotLast do
      local item = getInventoryItem(slot)
      if item and item:isContainer() and not openedContainersById[item:getId()] then
        g_game.open(item)
        waitTill = now + tonumber(ui.delayOptionsPanel.openDelay:getText())
        return lootContainers
      end
    end
  end

  return lootContainers
end

TargetBot.Looting.lootContainer = function(lootContainers, container)
  local nextContainer = nil

  for i, item in ipairs(container:getItems()) do
    if item:isContainer() and not itemsById[item:getId()] then
      nextContainer = item
    elseif itemsById[item:getId()] or (ui.everyItem:isOn() and not item:isContainer()) then
      item.lootTries = (item.lootTries or 0) + 1
      if item.lootTries < 5 then
        return TargetBot.Looting.lootItem(lootContainers, item)
      end
    end
  end

  if nextContainer then
    nextContainer.lootTries = (nextContainer.lootTries or 0) + 1
    if nextContainer.lootTries < 2 then
      g_game.open(nextContainer, container)
      waitTill = now + tonumber(ui.delayOptionsPanel.openDelay:getText())
      waitingForContainer = nextContainer:getId()
      return
    end
  end
  
  container.lootContainer = false
  g_game.close(container)
  table.remove(TargetBot.Looting.list, 1)
end

onTextMessage(function(mode, text)
  if TargetBot.isOff() then return end
  if #TargetBot.Looting.list == 0 then return end
  if string.find(text:lower(), "you are not the owner") then
    table.remove(TargetBot.Looting.list, 1)
  end
end)

TargetBot.Looting.lootItem = function(lootContainers, item)
  if item:isStackable() then
    local count = item:getCount()
    for _, container in ipairs(lootContainers) do
      for slot, citem in ipairs(container:getItems()) do
        if item:getId() == citem:getId() and citem:getCount() < 100 then
          waitTill = now + tonumber(ui.delayOptionsPanel.moveDelay:getText())
          g_game.move(item, container:getSlotPosition(slot - 1), count)
          return
        end
      end
    end
  end

  local container = lootContainers[1]
  waitTill = now + tonumber(ui.delayOptionsPanel.moveDelay:getText())
  g_game.move(item, container:getSlotPosition(container:getItemsCount()), 1)
end

local function sortLootTable()
  if #TargetBot.Looting.list < 2 then return end

  table.sort(TargetBot.Looting.list, function(c1, c2)
    c1.dist = math.abs(posx() - c1.pos.x) + math.abs(posy() - c1.pos.y)
    c2.dist = math.abs(posx() - c2.pos.x) + math.abs(posy() - c2.pos.y)
    return c1.dist > c2.dist
  end)
end

onContainerOpen(function(container, previousContainer)
  if container:getContainerItem():getId() == waitingForContainer then
    container.lootContainer = true
    waitingForContainer = nil
  end
end)

local deadId = 0
local messageId = 0
local messagesIds = {}

onTextMessage(function(mode, text)
  if not TargetBot.isOn() then return end
  if not ui.selectedItemsPanel.selectedItems:isOn() then return end
  if not text:find("Loot of") then return end
  text = text:lower()
  
  if messageId == deadId and messageId > 0 then
    messageId = 0
    deadId = -1
    messagesIds = {}
  else
    messageId = messageId + 1
  end
  
  local names = ui.selectedItemsPanel.names:getText()
  if string.match(names, ",") then
    local data = string.split(names, ",")
    for i, name in pairs(data) do
      if string.match(text, name:lower()) then
        table.insert(messagesIds, messageId)
        return
      end
    end
  else
    if string.match(text, names:lower()) then
      table.insert(messagesIds, messageId)
    end
  end
end)

onCreatureDisappear(function(creature)
  if isInPz() then return end
  if not TargetBot.isOn() then return end
  if not creature:isMonster() then return end
  
  if ui.selectedItemsPanel.selectedItems:isOn() then
    if messageId > deadId then
      deadId = deadId + 1
    end
    if creature:getHealthPercent() > 0 then
      return
    end
    if #messagesIds == 0 then
      return
    end
    if not table.find(messagesIds, deadId) then
      return
    end
  end
  local config = TargetBot.Creature.calculateParams(creature, {})
  if not config.config or config.config.dontLoot then
    return
  end
  local pos = player:getPosition()
  local mpos = creature:getPosition()
  local name = creature:getName()

  if pos.z ~= mpos.z or math.max(math.abs(pos.x - mpos.x), math.abs(pos.y - mpos.y)) > 6 then
    return
  end

  schedule(20, function()
    if not containers[1] then return end
    if TargetBot.Looting.list[20] then return end
    local tile = g_map.getTile(mpos)
    if not tile then return end
    local container = tile:getTopUseThing()
    if not container or not container:isContainer() then return end
    if not findPath(player:getPosition(), mpos, 6, {ignoreNonPathable=true, ignoreCreatures=true, ignoreCost=true}) then
      return
    end
    table.insert(TargetBot.Looting.list, {
      pos = mpos,
      creature = name,
      container = container:getId(),
      added = now,
      tries = 0
    })
    sortLootTable()
    container:setMarked('#000088')
  end)
end)
