if not Addons then
  return
end

local addon = Addons.Register("pojo")
addon.AddonName = "Pojo"
addon:RequestPermissions({ IOWrite, IORead })
local syncNowBtn = addon.CreateToolItem("Sync now")
local autoSyncBtn = addon.CreateToolItem("Auto sync")
local stopAutoSyncBtn = addon.CreateToolItem("Stop auto sync")

local AUTO_SYNC_DELAY = 1

function Add(value)
  local tgt = world
  for i = 1, #value.hierarchy - 1 do
    local child = value.hierarchy[i]
    local childCleaned = string.gsub(child, "^@", "")
    -- ^ clean @folder syntax that is for some reason not available in Polytoria

    if not tgt[childCleaned] then
      local node = Instance.New("Folder")
      node.Name = childCleaned
      node.Parent = tgt
      tgt = node
    else
      tgt = tgt[childCleaned]
    end
  end

  local scriptName = value.hierarchy[#value.hierarchy]
  local scriptC = tgt[scriptName] :: Script?

  if scriptC and scriptC.ClassName == value.type then
    scriptC:LinkWithScriptFile(value.full_path)
    print("Pojo: re-linked " .. value.full_path)
    return
  end

  local newScript = Instance.New(value.type)
  newScript.Name = scriptName
  newScript.Parent = tgt

  if scriptC then
    -- reparent to avoid race condition!!
    for _, child in ipairs(scriptC:GetChildren()) do
      child.Parent = newScript
    end
    scriptC:Destroy()
  end

  newScript:LinkWithScriptFile(value.full_path)
  print("Pojo: re-baked " .. value.full_path)
end

function Remove(value)
  local tgt = world
  for i = 1, #value.hierarchy do
    local child = value.hierarchy[i]
    local childCleaned = string.gsub(child, "^@", "")

    if not tgt[childCleaned] then
      local node = Instance.New("Folder")
      node.Name = childCleaned
      node.Parent = tgt
      tgt = node
    else
      tgt = tgt[childCleaned]
    end
  end
  if tgt then
    print("Pojo: destroying " .. tgt.Name)
    tgt:Destroy()
  end
end

function Sync(arrayOfChanges)
  for _, value in ipairs(arrayOfChanges) do
    if value.operation == "add" then
      Add(value)
    elseif value.operation == "rm" then
      Remove(value)
    end
  end
  if #arrayOfChanges > 0 then
    print("Pojo: all done.")
  end
end

local isInSync = false

function FetchAndSync()
  if isInSync then
    warn("Pojo: cannot double-sync")
    return
  end
  isInSync = true

  local resStr = Http.GetAsync("http://127.0.0.1:8080")
  local isJsonOk, res = pcall(function()
    return json.parse(resStr)
  end)

  if isJsonOk then
    Sync(res)
  else
    print("Pojo: invalid JSON received from server... Is it running?")
  end

  isInSync = false
end

local shouldAutoSync = false

spawn(function()
  while wait(1) do
    if shouldAutoSync then
      FetchAndSync()
    end
  end
end)

autoSyncBtn.Pressed:Connect(function()
  print("Pojo: automatic sync enabled every " .. tostring(AUTO_SYNC_DELAY) .. " second(s)")
  shouldAutoSync = true
end)

stopAutoSyncBtn.Pressed:Connect(function()
  print("Pojo: automatic sync disabled")
  shouldAutoSync = false
end)

syncNowBtn.Pressed:Connect(function()
  FetchAndSync()
end)
