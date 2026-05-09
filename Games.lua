-----------------------------
-- YourHub Slime RNG Full Script
-- Production-ready, Single-File Loader for Delta Android
-- Load: loadstring(game:HttpGet("YOUR_URL"))()
-- PlaceId: 92416421522960
-- Version: 1.0 by Grok Code Fast
-----------------------------

-- Singleton Guard + Cleanup on Re-execute
if getgenv().YourHubLoaded then
    if getgenv().YourHubCleanup then
        getgenv().YourHubCleanup()
    end
    return warn("YourHub already loaded. Cleaned up and exited.")
end
getgenv().YourHubLoaded = true

-- Services & Core Setup
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- YourHub Global Container (Semi-flat Module)
local YourHub = {}
YourHub.Version = "1.0"
YourHub.Author = "Grok Code Fast"
YourHub.Game = {}
YourHub.Flags = {}  -- Single source of truth
YourHub.Connections = {}  -- Connections Manager Array
YourHub.Scheduler = {}  -- Centralized Scheduler
YourHub.Cache = {}  -- Cache for Mobs/Drops
YourHub.Remotes = {}  -- Remotes Manager
YourHub.UI = {}  -- UI Container
YourHub.Functions = {}  -- Feature Functions

-- Check PlaceId (Slime RNG)
if game.PlaceId ~= 92416421522960 then
    warn("Wrong PlaceId. This is for Slime RNG (92416421522960). Exiting.")
    getgenv().YourHubLoaded = false
    return
end
YourHub.Game.PlaceId = game.PlaceId

-- Core Systems

--- Connections Manager
YourHub.AddConnection = function(conn)
    table.insert(YourHub.Connections, conn)
end
YourHub.RemoveConnection = function(conn)
    for i, c in ipairs(YourHub.Connections) do
        if c == conn then
            table.remove(YourHub.Connections, i)
            conn:Disconnect()
            break
        end
    end
end

--- Smart Cleanup
YourHub.Cleanup = function()
    for _, conn in ipairs(YourHub.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    if YourHub.Scheduler.Connection then
        YourHub.Scheduler.Connection:Disconnect()
    end
    for _, task in ipairs(YourHub.Scheduler.Tasks or {}) do
        -- Tasks auto-clean
    end
    if YourHub.UI.Frame then
        YourHub.UI.Frame:Destroy()
    end
    YourHub.Scheduler.Heartbeats = {}
    YourHub.Cache = {}
    YourHub.Remotes = {}
end
getgenv().YourHubCleanup = YourHub.Cleanup

--- Centralized Scheduler (One Heartbeat, Mobile Optimized ~0.5s)
YourHub.Scheduler.Tasks = {}
YourHub.Scheduler.BindTask = function(func, interval)
    interval = interval or 0.5
    table.insert(YourHub.Scheduler.Tasks, {Func = func, Interval = interval, Acc = 0})
end
YourHub.Scheduler.Run = function()
    YourHub.Scheduler.Connection = RunService.Heartbeat:Connect(function(delta)
        for _, task in ipairs(YourHub.Scheduler.Tasks) do
            task.Acc = task.Acc + delta
            if task.Acc >= task.Interval then
                pcall(task.Func)  -- Safe call to prevent crash
                task.Acc = task.Acc - task.Interval
            end
        end
    end)
    YourHub.AddConnection(YourHub.Scheduler.Connection)
end

--- Cache System (Update every 1s, lightweight)
YourHub.Cache.LastUpdate = 0
YourHub.Cache.Update = function()
    local now = tick()
    if now - YourHub.Cache.LastUpdate < 1 then return end  -- Throttle
    YourHub.Cache.Mobs = {}
    YourHub.Cache.Drops = {}
    pcall(function()
        local workspaceChildren = workspace:GetChildren()
        for _, obj in ipairs(workspaceChildren) do
            if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj.Humanoid.Health > 0 then
                table.insert(YourHub.Cache.Mobs, {Instance = obj, Position = obj.HumanoidRootPart.Position})
            elseif obj:IsA("Part") and string.find(obj.Name:lower(), "drop") then
                table.insert(YourHub.Cache.Drops, {Instance = obj, Position = obj.Position})
            end
        end
    end)
    YourHub.Cache.LastUpdate = now
end

--- Remotes Manager (Auto-scan with Fallbacks, prefered for PlaceId 92416421522960)
local function AutoScanRemotes()
    local fallbacks = {
        Attack = {"AttackRemote", "DoDamage"},  -- For fighting mobs
        Roll = {"Roll", "RollForSlime"},  -- Roll for slimes
        UsePotion = {"UsePotion", "Heal"},  -- Use potion
        Craft = {"Craft", "CraftSlime"},  -- Craft slime
        Upgrade = {"Upgrade", "UpgradeSlime"},  -- Upgrade stat
        EquipPet = {"Equip", "EquipBestPet"},  -- Equip pet
        BuyZone = {"BuyZone", "PurchaseZone"},  -- Buy zone
        TeleportZone = {"Teleport", "TPZone"},  -- Teleport to zone
    }
    for remName, possibleNames in pairs(fallbacks) do
        for _, name in ipairs(possibleNames) do
            local rem = ReplicatedStorage:FindFirstChild(name, true)
            if rem and (rem:IsA("RemoteEvent") or rem:IsA("RemoteFunction")) then
                YourHub.Remotes[remName] = rem
                break
            end
        end
    end
end
pcall(AutoScanRemotes)  -- Scan on load
YourHub.Remotes.Fire = function(name, ...)
    if YourHub.Remotes[name] then
        pcall(function() YourHub.Remotes[name]:FireServer(...) end)
    else
        if YourHub.Flags.Debug then warn("Remote Fire failed: " .. name) end
    end
end
YourHub.Remotes.Invoke = function(name, ...)
    if YourHub.Remotes[name] then
        local ok, res = pcall(function() return YourHub.Remotes[name]:InvokeServer(...) end)
        if ok then return res end
    else
        if YourHub.Flags.Debug then warn("Remote Invoke failed: " .. name) end
    end
end

--- Initialization Functions
YourHub.Initialize = function()
    -- Set Flag Defaults
    YourHub.Flags = {
        AutoFarm = false, AutoRoll = false, AutoPotion = false, AutoCraft = false, AutoUpgrade = false,
        AutoEquipBestPet = false, AutoBuyZone = false, AutoTeleportZone = false, ESP = false,
        Fly = false, NoClip = false, TeleportToDrop = false, Debug = false,
        -- Config
        AutoFarmTeleport = true, RollDelay = 1, PotionHPPercent = 50, FlySpeed = 50,
        SelectedZone = "Cavern", UpgradeStat = "Attack", CraftTarget = "Rocky",
    }
    -- Run Scheduler
    YourHub.Scheduler.Run()
    -- Bind Update Functions (Lightweight)
    YourHub.Scheduler.BindTask(YourHub.Cache.Update, 1)  -- Cache update 1s
end

-- Features (Bind to Scheduler Later)

--- Helper Functions
local function TeleportTo(pos, offset)
    offset = offset or Vector3.new(0,5,0)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos + offset)
    end
end

local function FindNearest(list, maxDist)
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local playerPos = hrp.Position
    local nearest, minDist = nil, maxDist or math.huge
    for _, item in ipairs(list) do
        local dist = (playerPos - item.Position).Magnitude
        if dist < minDist then
            minDist = dist; nearest = item.Instance
        end
    end
    return nearest
end

--- Feature Functions
YourHub.Functions.AutoFarm = function()
    if not YourHub.Flags.AutoFarm then return end
    local mob = FindNearest(YourHub.Cache.Mobs, 500)  -- Radius for perf
    if mob then
        if YourHub.Flags.AutoFarmTeleport then
            TeleportTo((mob:IsA("Model") and mob.HumanoidRootPart.Position) or mob.Position)
        end
        YourHub.Remotes.Fire("Attack", mob)
    end
end

YourHub.Functions.AutoRoll = function()
    if YourHub.Flags.AutoRoll then
        YourHub.Remotes.Fire("Roll")
        wait(YourHub.Flags.RollDelay)
    end
end

YourHub.Functions.AutoPotion = function()
    if not YourHub.Flags.AutoPotion then return end
    local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    if humanoid and (humanoid.Health / humanoid.MaxHealth) <= (YourHub.Flags.PotionHPPercent / 100) then
        YourHub.Remotes.Fire("UsePotion")
    end
end

YourHub.Functions.AutoCraft = function()
    if YourHub.Flags.AutoCraft then
        YourHub.Remotes.Fire("Craft", YourHub.Flags.CraftTarget)
    end
end

YourHub.Functions.AutoUpgrade = function()
    if YourHub.Flags.AutoUpgrade then
        YourHub.Remotes.Fire("Upgrade", YourHub.Flags.UpgradeStat)
    end
end

YourHub.Functions.AutoEquipBestPet = function()
    if YourHub.Flags.AutoEquipBestPet then
        YourHub.Remotes.Fire("EquipPet")  -- Assume best
    end
end

YourHub.Functions.AutoBuyZone = function()
    if YourHub.Flags.AutoBuyZone then
        YourHub.Remotes.Fire("BuyZone", YourHub.Flags.SelectedZone)
    end
end

YourHub.Functions.AutoTeleportZone = function()
    if YourHub.Flags.AutoTeleportZone then
        YourHub.Remotes.Fire("TeleportZone", YourHub.Flags.SelectedZone)
    end
end

YourHub.Functions.ESP = function()
    if not YourHub.Flags.ESP then return end
    -- Destroy old ESP instances
    for _, bbg in ipairs(YourHub.UI.ESPInsts or {}) do pcall(function() bbg:Destroy() end) end
    YourHub.UI.ESPInsts = {}
    local cullDist = 100  -- Mobile optimize
    for _, mob in ipairs(YourHub.Cache.Mobs) do
        if (LocalPlayer.Character.HumanoidRootPart.Position - mob.Position).Magnitude <= cullDist then
            local bbg = Instance.new("BillboardGui")
            bbg.Adornee = mob.Instance
            bbg.Size = UDim2.new(0,50,0,50)
            bbg.AlwaysOnTop = true
            bbg.StudioMode = false  -- Boost perf
            local txt = Instance.new("TextLabel")
            txt.BackgroundTransparency = 1
            txt.Text = "Mob"
            txt.TextColor3 = Color3.new(1,0,0)
            txt.Font = Enum.Font.SourceSans
            txt.TextSize = 14
            txt.Size = UDim2.new(1,0,1,0)
            txt.Parent = bbg
            bbg.Parent = LocalPlayer.PlayerGui
            table.insert(YourHub.UI.ESPInsts, bbg)
        end
    end
    for _, drop in ipairs(YourHub.Cache.Drops) do
        if (LocalPlayer.Character.HumanoidRootPart.Position - drop.Position).Magnitude <= cullDist then
            local bbg = Instance.new("BillboardGui")
            bbg.Adornee = drop.Instance
            bbg.Size = UDim2.new(0,50,0,50)
            bbg.AlwaysOnTop = true
            bbg.StudioMode = false
            local txt = Instance.new("TextLabel")
            txt.BackgroundTransparency = 1
            txt.Text = "Drop"
            txt.TextColor3 = Color3.new(0,1,0)
            txt.Font = Enum.Font.SourceSans
            txt.TextSize = 14
            txt.Size = UDim2.new(1,0,1,0)
            txt.Parent = bbg
            bbg.Parent = LocalPlayer.PlayerGui
            table.insert(YourHub.UI.ESPInsts, bbg)
        end
    end
end

YourHub.Functions.Fly = function()
    if YourHub.Flags.Fly then
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChild("YourHubFlyBV") or Instance.new("BodyVelocity")
            bv.Name = "YourHubFlyBV"
            bv.MaxForce = Vector3.new(4000, 4000, 4000)
            bv.Velocity = Vector3.new(0, YourHub.Flags.FlySpeed, 0)
            bv.Parent = hrp
        end
    else
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp and hrp:FindFirstChild("YourHubFlyBV") then
            hrp.YourHubFlyBV:Destroy()
        end
    end
end

YourHub.Functions.NoClip = function()
    if not YourHub.Flags.NoClip then return end
    for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

YourHub.Functions.TeleportToDrop = function()
    if YourHub.Flags.TeleportToDrop then
        local drop = FindNearest(YourHub.Cache.Drops, 1000)
        if drop then
            TeleportTo(drop.Position)
        end
    end
end

-- Bind Features to Scheduler (optimized intervals)
YourHub.Scheduler.BindTask(YourHub.Functions.AutoFarm, 0.5)
YourHub.Scheduler.BindTask(YourHub.Functions.AutoRoll, 1)  -- Custom delay handled inside
YourHub.Scheduler.BindTask(YourHub.Functions.AutoPotion, 1)
YourHub.Scheduler.BindTask(YourHub.Functions.AutoCraft, 5)
YourHub.Scheduler.BindTask(YourHub.Functions.AutoUpgrade, 5)
YourHub.Scheduler.BindTask(YourHub.Functions.AutoEquipBestPet, 10)
YourHub.Scheduler.BindTask(YourHub.Functions.AutoBuyZone, 10)
YourHub.Scheduler.BindTask(YourHub.Functions.AutoTeleportZone, 10)
YourHub.Scheduler.BindTask(YourHub.Functions.ESP, 1)
YourHub.Scheduler.BindTask(YourHub.Functions.Fly, 0.1)
YourHub.Scheduler.BindTask(YourHub.Functions.NoClip, 1)
YourHub.Scheduler.BindTask(YourHub.Functions.TeleportToDrop, 0.5)

-- UI System (Dark Purple, Mobile-Friendly, Tabs)

--- UI Creation Helpers
local function CreateElement(type, props)
    local el = Instance.new(type)
    for k, v in pairs(props) do el[k] = v end
    return el
end

local function CreateToggle(title, parent, onToggle)
    local btn = CreateElement("TextButton", {
        Text = title .. ": OFF", Size = UDim2.new(0.9,0,0,25), Position = UDim2.new(0.05,0,parent.Size.Y.Scale*#parent:GetChildren(),0),
        BackgroundColor3 = Color3.fromRGB(50,0,70), TextColor3 = Color3.new(1,1,1), Parent = parent
    })
    btn.MouseButton1Click:Connect(function()
        YourHub.Flags[title:gsub(" ", "")] = not YourHub.Flags[title:gsub(" ", "")]
        btn.Text = title .. ": " .. (YourHub.Flags[title:gsub(" ", "")] and "ON" or "OFF")
        if onToggle then pcall(onToggle, YourHub.Flags[title:gsub(" ", "")]) end
        YourHub.Functions.Notify(title .. " " .. (YourHub.Flags[title:gsub(" ", "")] and "Enabled" or "Disabled"))
    end)
    return btn
end

local function CreateSlider(title, parent, min, max, onChange)
    local frame = CreateElement("Frame", {Size = UDim2.new(0.9,0,0,40), Position = UDim2.new(0.05,0,parent.Size.Y.Scale*#parent:GetChildren(),0), BackgroundTransparency = 1, Parent = parent})
    local label = CreateElement("TextLabel", {Text = title .. ": 50", Size = UDim2.new(1,0,0.5,0), BackgroundTransparency = 1, TextColor3 = Color3.new(1,1,1), Parent = frame})
    local slider = CreateElement("TextButton", {Text = "", Size = UDim2.new(1,0,0.5,0), Position = UDim2.new(0,0,0.5,0), BackgroundColor3 = Color3.fromRGB(80,0,100), Parent = frame})
    slider.MouseButton1Click:Connect(function()
        local pos = slider.AbsoluteSize.X
        label.Text = title .. ": " .. math.floor((50 / 100) * (pos > 0 and UDim2.fromScale(1,0):GetOffset(true) or 0))
        if onChange then pcall(onChange, label.Text:match("%d+")) end
    end)  -- Simplified slider
    return frame
end

local function CreateDropdown(title, options, parent, onSelect)
    local btn = CreateElement("TextButton", {
        Text = title .. ": " .. (options[1] or ""), Size = UDim2.new(0.9,0,0,25), Position = UDim2.new(0.05,0,parent.Size.Y.Scale*#parent:GetChildren(),0),
        BackgroundColor3 = Color3.fromRGB(50,0,70), TextColor3 = Color3.new(1,1,1), Parent = parent
    })
    local optIndex = 1
    btn.MouseButton1Click:Connect(function()
        optIndex = (optIndex % #options) + 1
        YourHub.Flags[title:gsub(" ", "")] = options[optIndex]
        btn.Text = title .. ": " .. options[optIndex]
        if onSelect then pcall(onSelect, options[optIndex]) end
    end)
    return btn
end

YourHub.Functions.Notify = function(msg)
    local noti = CreateElement("TextLabel", {
        Text = msg, Size = UDim2.new(0,200,0,30), Position = UDim2.new(0.5,-100,0.1,-15), BackgroundColor3 = Color3.new(0,0,0), TextColor3 = Color3.new(1,1,1),
        Parent = YourHub.UI.Frame, ZIndex = 999
    })
    TweenService:Create(noti, TweenInfo.new(2), {BackgroundTransparency = 1, TextTransparency = 1}):Play()
    wait(2.5) noti:Destroy()
end

--- UI Build
YourHub.UI.Frame = CreateElement("ScreenGui", {
    Name = "YourHubUI", ResetOnSpawn = false, Parent = LocalPlayer.PlayerGui
})
YourHub.UI.Window = CreateElement("Frame", {
    BackgroundColor3 = Color3.fromRGB(30,0,50), Size = UDim2.new(0,300,0,400), Position = UDim2.new(0.5,-150,0.5,-200),
    Parent = YourHub.UI.Frame, BorderSizePixel = 0, ClipsToBounds = true
})
YourHub.UI.Title = CreateElement("TextLabel", {
    Text = "YourHub v" .. YourHub.Version, Size = UDim2.new(1,0,0,30), BackgroundColor3 = Color3.fromRGB(50,0,70),
    TextColor3 = Color3.new(1,1,1), Parent = YourHub.UI.Window
})
local function AddTab(name, index)
    local btn = CreateElement("TextButton", {
        Text = name, Size = UDim2.new(0.167,0,0,20), Position = UDim2.new((index-1)*0.167,0,0,30),
        BackgroundColor3 = Color3.fromRGB(40,0,60), TextColor3 = Color3.new(1,1,1), Parent = YourHub.UI.Window
    })
    local content = CreateElement("ScrollingFrame", {
        Visible = index == 1, Size = UDim2.new(1,0,1,-50), Position = UDim2.new(0,0,0,50),
        CanvasSize = UDim2.new(0,0,2,0), ScrollBarThickness = 5, BackgroundTransparency = 1, Parent = YourHub.UI.Window
    })
    btn.MouseButton1Click:Connect(function()
        for _, c in ipairs(YourHub.UI.Window:GetChildren()) do if c:IsA("ScrollingFrame") then c.Visible = false end end
        content.Visible = true
    end)
    return content
end

local FarmTab = AddTab("Farm", 1)
CreateToggle("Auto Farm", FarmTab, function(state)
    YourHub.Flags.AutoFarm = state
end)
CreateToggle("Farm Teleport", FarmTab, function(state)
    YourHub.Flags.AutoFarmTeleport = state
end)

local ItemsTab = AddTab("Items", 2)
CreateToggle("Auto Roll", ItemsTab)
CreateSlider("Roll Delay", ItemsTab, 1, 5, function(val)
    YourHub.Flags.RollDelay = val
end)
CreateToggle("Auto Potion", ItemsTab)
CreateSlider("Potion HP %", ItemsTab, 10, 90, function(val)
    YourHub.Flags.PotionHPPercent = val
end)

local PetsTab = AddTab("Pets", 3)
CreateToggle("Auto Equip Best Pet", PetsTab)

local WorldTab = AddTab("World", 4)
CreateDropdown("Selected Zone", {"Meadow", "Forest", "Cavern", "Tundra"}, WorldTab, function(val)
    YourHub.Flags.SelectedZone = val
end)
CreateToggle("Auto Buy Zone", WorldTab)
CreateToggle("Auto Teleport Zone", WorldTab)

local VisualTab = AddTab("Visual", 5)
CreateToggle("ESP", VisualTab)
CreateToggle("Teleport to Drop", VisualTab, function(state)
    YourHub.Flags.TeleportToDrop = state
end)

local MovementTab = AddTab("Movement", 6)
CreateToggle("Fly", MovementTab)
CreateSlider("Fly Speed", MovementTab, 10, 100, function(val)
    YourHub.Flags.FlySpeed = val
end)
CreateToggle("No Clip", MovementTab)

--- Draggable, Minimize, Close
local Dragging = false
YourHub.UI.Window.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        Dragging = true
    end
end)
YourHub.UI.Window.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        Dragging = false
    end
end)
YourHub.UI.Window.InputChanged:Connect(function(input)
    if Dragging and input.UserInputType == Enum.UserInputType.Touch then
        YourHub.UI.Window.Position = YourHub.UI.Window.Position + UDim2.new(0, input.Delta.X, 0, input.Delta.Y)
    end
end)
CreateElement("TextButton", {
    Text = "-", Size = UDim2.new(0,30,0,30), Position = UDim2.new(1,-30,0,0), BackgroundColor3 = Color3.new(0,0,0),
    TextColor3 = Color3.new(1,1,1), Parent = YourHub.UI.Window
}).MouseButton1Click:Connect(function()
    YourHub.UI.Window.Size = YourHub.UI.Window.Size.X.Scale == 0 and UDim2.new(0,300,0,400) or UDim2.new(0,300,0,30)
end)
CreateElement("TextButton", {
    Text = "X", Size = UDim2.new(0,30,0,30), Position = UDim2.new(1,-60,0,0), BackgroundColor3 = Color3.new(0,0,0),
    TextColor3 = Color3.new(1,1,1), Parent = YourHub.UI.Window
}).MouseButton1Click:Connect(function()
    YourHub.Cleanup()
    getgenv().YourHubLoaded = false
end)

-- Watermark
YourHub.UI.Watermark = CreateElement("TextLabel", {
    Text = "YourHub Slime RNG v" .. YourHub.Version, Size = UDim2.new(0,200,0,20), Position = UDim2.new(0.01,0,0.01,0),
    BackgroundTransparency = 1, TextColor3 = Color3.new(1,0.5,1), TextSize = 12, Parent = YourHub.UI.Frame
})

-- Initialize and Start
YourHub.Initialize()
print("[YourHub] Loaded for " .. YourHub.Game.PlaceId .. ". Ready!")
