-- Ultimate Farm Script v7.0 – Two farm modes (TP & Tween), Auto-collect, NoClip, Hotkeys, Save points, Infinite tools,
-- plus GodMode (no damage), Fly (WASD), and Auto-build.
-- Run in a Roblox executor (Synapse X, Krnl, etc.).
-- All features integrated with a tabbed GUI.

local player = game.Players.LocalPlayer
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")

-- === CONFIGURATION ===
local gravityNormal = workspace.Gravity
local farmMode = "TP"  -- "TP" or "Tween"
local destinations = {
    CFrame.new(-51.566, 65, 1369.09),
    CFrame.new(-51.566, 65, 2139.09),
    CFrame.new(-51.566, 65, 2909.09),
    CFrame.new(-51.566, 65, 3679.09),
    CFrame.new(-51.566, 65, 4449.09),
    CFrame.new(-51.566, 65, 5219.09),
    CFrame.new(-51.566, 65, 5989.09),
    CFrame.new(-51.566, 65, 6759.09),
    CFrame.new(-51.566, 65, 7529.09),
    CFrame.new(-51.566, 65, 8299.09),
    CFrame.new(-55.907, -360.99, 9489.307),
}
local userPoints = {} -- saved custom points

-- === STATE ===
local autoFarmEnabled = false
local antiAfkEnabled = false
local infiniteGoldEnabled = false
local autoCollectEnabled = false
local infiniteToolsEnabled = false
local noClipEnabled = false
local godModeEnabled = true   -- always on
local flyEnabled = false
local farmTask = nil
local collectionTask = nil
local currentCharacter = player.Character
local humanoid = currentCharacter and currentCharacter:FindFirstChild("Humanoid")
local rootPart = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")

-- === HELPER FUNCTIONS ===
local function getChar()
    local c = player.Character
    if not c then return nil, nil, nil end
    local r = c:FindFirstChild("HumanoidRootPart")
    local h = c:FindFirstChild("Humanoid")
    return c, h, r
end

-- === GOD MODE (prevents all damage: water, fall, enemies) ===
local function setGodMode(enabled)
    local c, h, r = getChar()
    if not h then return end
    if enabled then
        h.MaxHealth = math.huge
        h.Health = math.huge
        h.BreakJointsOnDeath = false
        h:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
        h:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
        -- Disable damage from parts
        h:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
        h:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
    else
        h.MaxHealth = 100
        h.BreakJointsOnDeath = true
        h:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
        h:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
        h:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        h:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
    end
end

local function setNoClip(enabled)
    local c, h, r = getChar()
    if not r then return end
    if enabled then
        r.CanCollide = false
        r.CFrame = r.CFrame
    else
        r.CanCollide = true
    end
end

-- Infinite tools (durability, ammo)
local function makeToolsInfinite()
    local c = player.Character
    if not c then return end
    for _, tool in ipairs(c:GetChildren()) do
        if tool:IsA("Tool") then
            local val = tool:FindFirstChild("Durability") or tool:FindFirstChild("Ammo") or tool:FindFirstChild("Value")
            if val and val:IsA("NumberValue") then
                val.Value = 999999
            end
            local handle = tool:FindFirstChild("Handle")
            if handle then
                local attrs = handle:GetAttributes()
                for k,v in pairs(attrs) do
                    if type(v) == "number" and (string.find(k:lower(), "durab") or string.find(k:lower(), "ammo")) then
                        handle:SetAttribute(k, 999999)
                    end
                end
            end
        end
    end
end

-- Auto-collect resources (click on parts)
local function autoCollectLoop()
    while autoCollectEnabled do
        local char, hum, root = getChar()
        if not root then task.wait(1) continue end
        local radius = 50
        local found = false
        for _, part in ipairs(workspace:GetDescendants()) do
            if part:IsA("BasePart") and part:FindFirstChild("Value") then
                local dist = (part.Position - root.Position).Magnitude
                if dist < radius then
                    local collectEvent = game.ReplicatedStorage:FindFirstChild("CollectResource") or
                                         game.ReplicatedStorage:FindFirstChild("Gather") or
                                         game.ReplicatedStorage:FindFirstChild("Collect")
                    if collectEvent then
                        collectEvent:FireServer(part)
                    else
                        local args = {part}
                        game:GetService("ReplicatedStorage").RemoteEvent:FireServer(unpack(args))
                    end
                    found = true
                    break
                end
            end
        end
        if not found then
            task.wait(2)
        else
            task.wait(0.3)
        end
    end
end

-- === FARM MODES ===
local function tpMode(cf)
    local c, h, r = getChar()
    if not r then return end
    workspace.Gravity = 0
    r.CFrame = cf
    local center = cf.Position
    local radius = 6
    local steps = 24
    for i = 1, steps do
        if not autoFarmEnabled then return end
        local angle = (i / steps) * math.pi * 2
        local pos = center + Vector3.new(math.cos(angle)*radius, 0, math.sin(angle)*radius)
        r.CFrame = CFrame.lookAt(pos, center)
        task.wait(1.5 / steps)
    end
    workspace.Gravity = gravityNormal
end

local function tweenMode(cf)
    local c, h, r = getChar()
    if not r then return end
    -- Disable gravity during movement to prevent falling into water
    workspace.Gravity = 0
    local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local goal = {CFrame = cf}
    local tween = TweenService:Create(r, tweenInfo, goal)
    tween:Play()
    tween.Completed:Wait()
    -- stay 1 second
    task.wait(1)
    workspace.Gravity = gravityNormal
end

local function farmLoop()
    local modeFunc = (farmMode == "TP") and tpMode or tweenMode
    while autoFarmEnabled do
        local c, h, r = getChar()
        if not r then task.wait(1) continue end
        for i, cf in ipairs(destinations) do
            if not autoFarmEnabled then return end
            modeFunc(cf)
            if infiniteGoldEnabled then
                local ls = player:FindFirstChild("leaderstats")
                if ls then
                    for _, stat in ipairs(ls:GetChildren()) do
                        if stat:IsA("NumberValue") and string.find(stat.Name:lower(), "gold") then
                            stat.Value = 999999
                        end
                    end
                end
            end
            if infiniteToolsEnabled then
                makeToolsInfinite()
            end
            task.wait(0.1)
        end
        if farmMode == "TP" then
            workspace.Gravity = gravityNormal
        end
        task.wait(1)
    end
end

-- === SAVE / LOAD POINTS ===
local function savePoint(name, cf)
    userPoints[name] = cf
end

local function loadPoints()
    return userPoints
end

-- === FLY MODE (WASD controls) ===
local flyBodyVelocity = nil
local flyKeys = {W=false, A=false, S=false, D=false, Space=false, Q=false}
local flySpeed = 50

local function toggleFly()
    flyEnabled = not flyEnabled
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if flyEnabled then
        if flyBodyVelocity then flyBodyVelocity:Destroy() end
        flyBodyVelocity = Instance.new("BodyVelocity")
        flyBodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        flyBodyVelocity.Velocity = Vector3.new(0,0,0)
        flyBodyVelocity.Parent = root
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            hum.PlatformStand = true
            hum.WalkSpeed = 0
        end
        workspace.Gravity = 0
    else
        if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity = nil end
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            hum.PlatformStand = false
            hum.WalkSpeed = 16
        end
        workspace.Gravity = gravityNormal
    end
end

-- Fly key handlers
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    local key = input.KeyCode
    if key == Enum.KeyCode.W then flyKeys.W = true
    elseif key == Enum.KeyCode.A then flyKeys.A = true
    elseif key == Enum.KeyCode.S then flyKeys.S = true
    elseif key == Enum.KeyCode.D then flyKeys.D = true
    elseif key == Enum.KeyCode.Space then flyKeys.Space = true
    elseif key == Enum.KeyCode.Q then flyKeys.Q = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    local key = input.KeyCode
    if key == Enum.KeyCode.W then flyKeys.W = false
    elseif key == Enum.KeyCode.A then flyKeys.A = false
    elseif key == Enum.KeyCode.S then flyKeys.S = false
    elseif key == Enum.KeyCode.D then flyKeys.D = false
    elseif key == Enum.KeyCode.Space then flyKeys.Space = false
    elseif key == Enum.KeyCode.Q then flyKeys.Q = false end
end)

RunService.Heartbeat:Connect(function()
    if not flyEnabled then return end
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root or not flyBodyVelocity then return end

    local move = Vector3.new(0,0,0)
    if flyKeys.W then move = move + root.CFrame.LookVector end
    if flyKeys.S then move = move - root.CFrame.LookVector end
    if flyKeys.A then move = move - root.CFrame.RightVector end
    if flyKeys.D then move = move + root.CFrame.RightVector end
    if flyKeys.Space then move = move + Vector3.new(0,1,0) end
    if flyKeys.Q then move = move - Vector3.new(0,1,0) end

    if move.Magnitude > 0 then
        move = move.Unit * flySpeed
    end
    flyBodyVelocity.Velocity = move
end)

-- === AUTO-BUILD (instant place blocks in pattern) ===
local buildEnabled = false
local buildPattern = {
    function(pos, orientation)
        local blocks = {}
        for x = -2, 2 do
            for z = -2, 2 do
                local cf = CFrame.new(pos.X + x, pos.Y, pos.Z + z)
                table.insert(blocks, {cf, "Wood"})
            end
        end
        return blocks
    end
}

local function placeBlock(cf, material)
    local placeEvent = game.ReplicatedStorage:FindFirstChild("BuildEvent") or
                       game.ReplicatedStorage:FindFirstChild("PlaceBlock")
    if placeEvent then
        placeEvent:FireServer(cf, material)
    else
        local tool = player.Backpack:FindFirstChild(material) or player.Character:FindFirstChild(material)
        if tool and tool:IsA("Tool") then
            tool.Parent = player.Character
            tool:Activate()
            local mouse = player:GetMouse()
            if mouse.Target then
                local pos = mouse.Hit.Position + Vector3.new(0, 1, 0)
                tool:FireServer(pos)
            end
        end
    end
end

local function autoBuild()
    if not buildEnabled then return end
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local pos = root.Position
    local pattern = buildPattern[1]
    if pattern then
        for _, block in ipairs(pattern(pos, root.CFrame)) do
            placeBlock(block[1], block[2])
            task.wait(0.05)
        end
    end
end

-- Toggle Auto-build key (F7)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F7 then
        buildEnabled = not buildEnabled
        if buildEnabled then
            autoBuild()
        end
    end
end)

-- === GUI CREATION (Tabbed) ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UltimateFarmV7"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Parent = screenGui
MainFrame.Size = UDim2.new(0, 450, 0, 320)
MainFrame.Position = UDim2.new(0.5, -225, 0.5, -160)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
MainFrame.BackgroundTransparency = 0.1
MainFrame.ClipsDescendants = false

-- Shadow and corners
local shadow = Instance.new("Frame")
shadow.Parent = MainFrame
shadow.Size = UDim2.new(1, 12, 1, 12)
shadow.Position = UDim2.new(0, -6, 0, -6)
shadow.BackgroundColor3 = Color3.fromRGB(0,0,0)
shadow.BackgroundTransparency = 0.6
shadow.ZIndex = 0
local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 14)
shadowCorner.Parent = shadow

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = MainFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(120, 120, 220)
stroke.Thickness = 2
stroke.Transparency = 0.2
stroke.Parent = MainFrame

-- Title bar (drag)
local TitleBar = Instance.new("Frame")
TitleBar.Parent = MainFrame
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 70)
TitleBar.BackgroundTransparency = 0.4
TitleBar.ZIndex = 2
local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 14)
titleCorner.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Parent = TitleBar
TitleLabel.Size = UDim2.new(1, -40, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Ultimate Farm v7.0"
TitleLabel.TextColor3 = Color3.fromRGB(230, 230, 255)
TitleLabel.TextScaled = true
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 3

local MinButton = Instance.new("TextButton")
MinButton.Parent = TitleBar
MinButton.Size = UDim2.new(0, 28, 0, 28)
MinButton.Position = UDim2.new(1, -33, 0, 3.5)
MinButton.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
MinButton.Text = "−"
MinButton.TextColor3 = Color3.fromRGB(255,255,255)
MinButton.TextSize = 22
MinButton.Font = Enum.Font.GothamBold
MinButton.ZIndex = 3
local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 7)
minCorner.Parent = MinButton

-- Content container
local Content = Instance.new("Frame")
Content.Parent = MainFrame
Content.Size = UDim2.new(1, 0, 1, -35)
Content.Position = UDim2.new(0, 0, 0, 35)
Content.BackgroundTransparency = 1

-- Tab buttons
local TabContainer = Instance.new("Frame")
TabContainer.Parent = Content
TabContainer.Size = UDim2.new(1, 0, 0, 30)
TabContainer.BackgroundTransparency = 1

local tabs = {"Farm", "Player", "Misc", "Points"}
local tabButtons = {}
local panels = {}

local function createTab(name, order)
    local btn = Instance.new("TextButton")
    btn.Parent = TabContainer
    btn.Size = UDim2.new(1/#tabs, -4, 1, -4)
    btn.Position = UDim2.new(order/#tabs, 2, 0, 2)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200, 200, 255)
    btn.TextSize = 16
    btn.Font = Enum.Font.Gotham
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn
    tabButtons[name] = btn

    local panel = Instance.new("Frame")
    panel.Parent = Content
    panel.Size = UDim2.new(1, 0, 1, -30)
    panel.Position = UDim2.new(0, 0, 0, 30)
    panel.BackgroundTransparency = 1
    panel.Visible = (order == 0)
    panels[name] = panel
    return panel
end

-- === Farm Tab ===
local farmPanel = createTab("Farm", 0)

-- Mode selection
local modeLabel = Instance.new("TextLabel")
modeLabel.Parent = farmPanel
modeLabel.Size = UDim2.new(0, 100, 0, 20)
modeLabel.Position = UDim2.new(0.05, 0, 0.05, 0)
modeLabel.BackgroundTransparency = 1
modeLabel.Text = "Mode: TP"
modeLabel.TextColor3 = Color3.fromRGB(200,200,255)
modeLabel.TextSize = 14
modeLabel.Font = Enum.Font.Gotham

local modeDropdown = Instance.new("TextButton")
modeDropdown.Parent = farmPanel
modeDropdown.Size = UDim2.new(0, 80, 0, 25)
modeDropdown.Position = UDim2.new(0.35, 0, 0.05, 0)
modeDropdown.BackgroundColor3 = Color3.fromRGB(50,50,80)
modeDropdown.Text = "TP"
modeDropdown.TextColor3 = Color3.fromRGB(255,255,255)
modeDropdown.TextSize = 16
modeDropdown.Font = Enum.Font.Gotham
local ddCorner = Instance.new("UICorner")
ddCorner.CornerRadius = UDim.new(0, 6)
ddCorner.Parent = modeDropdown

local toggleMode = false
modeDropdown.MouseButton1Click:Connect(function()
    toggleMode = not toggleMode
    farmMode = toggleMode and "Tween" or "TP"
    modeDropdown.Text = farmMode
    modeLabel.Text = "Mode: " .. farmMode
end)

-- Start/Stop Farm
local FarmBtn = Instance.new("TextButton")
FarmBtn.Parent = farmPanel
FarmBtn.Size = UDim2.new(0, 150, 0, 35)
FarmBtn.Position = UDim2.new(0.1, 0, 0.25, 0)
FarmBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 130)
FarmBtn.Text = "Start Farm"
FarmBtn.TextColor3 = Color3.fromRGB(255,255,255)
FarmBtn.TextSize = 20
FarmBtn.Font = Enum.Font.Gotham
local fCorner = Instance.new("UICorner")
fCorner.CornerRadius = UDim.new(0, 8)
fCorner.Parent = FarmBtn
local fStroke = Instance.new("UIStroke")
fStroke.Color = Color3.fromRGB(160, 160, 255)
fStroke.Thickness = 1.5
fStroke.Parent = FarmBtn

local FarmIndicator = Instance.new("ImageLabel")
FarmIndicator.Parent = FarmBtn
FarmIndicator.Size = UDim2.new(0, 22, 0, 22)
FarmIndicator.Position = UDim2.new(1, -28, 0.5, -11)
FarmIndicator.BackgroundTransparency = 1
FarmIndicator.Image = "rbxassetid://5552526748"
FarmIndicator.ImageColor3 = Color3.fromRGB(255,0,0)

-- Anti-AFK
local AntiAfkBtn = Instance.new("TextButton")
AntiAfkBtn.Parent = farmPanel
AntiAfkBtn.Size = UDim2.new(0, 150, 0, 35)
AntiAfkBtn.Position = UDim2.new(0.55, 0, 0.25, 0)
AntiAfkBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 130)
AntiAfkBtn.Text = "Anti AFK"
AntiAfkBtn.TextColor3 = Color3.fromRGB(255,255,255)
AntiAfkBtn.TextSize = 20
AntiAfkBtn.Font = Enum.Font.Gotham
local aCorner = Instance.new("UICorner")
aCorner.CornerRadius = UDim.new(0, 8)
aCorner.Parent = AntiAfkBtn
local aStroke = Instance.new("UIStroke")
aStroke.Color = Color3.fromRGB(160, 160, 255)
aStroke.Thickness = 1.5
aStroke.Parent = AntiAfkBtn

local AfkIndicator = Instance.new("ImageLabel")
AfkIndicator.Parent = AntiAfkBtn
AfkIndicator.Size = UDim2.new(0, 22, 0, 22)
AfkIndicator.Position = UDim2.new(1, -28, 0.5, -11)
AfkIndicator.BackgroundTransparency = 1
AfkIndicator.Image = "rbxassetid://5552526748"
AfkIndicator.ImageColor3 = Color3.fromRGB(255,0,0)

-- Auto-collect toggle
local CollectBtn = Instance.new("TextButton")
CollectBtn.Parent = farmPanel
CollectBtn.Size = UDim2.new(0, 150, 0, 35)
CollectBtn.Position = UDim2.new(0.1, 0, 0.6, 0)
CollectBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 130)
CollectBtn.Text = "Auto-Collect"
CollectBtn.TextColor3 = Color3.fromRGB(255,255,255)
CollectBtn.TextSize = 18
CollectBtn.Font = Enum.Font.Gotham
local cCorner = Instance.new("UICorner")
cCorner.CornerRadius = UDim.new(0, 8)
cCorner.Parent = CollectBtn
local cStroke = Instance.new("UIStroke")
cStroke.Color = Color3.fromRGB(160, 160, 255)
cStroke.Thickness = 1.5
cStroke.Parent = CollectBtn

local CollectIndicator = Instance.new("ImageLabel")
CollectIndicator.Parent = CollectBtn
CollectIndicator.Size = UDim2.new(0, 22, 0, 22)
CollectIndicator.Position = UDim2.new(1, -28, 0.5, -11)
CollectIndicator.BackgroundTransparency = 1
CollectIndicator.Image = "rbxassetid://5552526748"
CollectIndicator.ImageColor3 = Color3.fromRGB(255,0,0)

-- === Player Tab ===
local playerPanel = createTab("Player", 1)

-- Speed
local speedLabel = Instance.new("TextLabel")
speedLabel.Parent = playerPanel
speedLabel.Size = UDim2.new(0, 100, 0, 20)
speedLabel.Position = UDim2.new(0.05, 0, 0.05, 0)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Speed: 16"
speedLabel.TextColor3 = Color3.fromRGB(200,200,255)
speedLabel.TextSize = 14
speedLabel.Font = Enum.Font.Gotham

local speedSlider = Instance.new("TextBox")
speedSlider.Parent = playerPanel
speedSlider.Size = UDim2.new(0, 80, 0, 25)
speedSlider.Position = UDim2.new(0.4, 0, 0.05, 0)
speedSlider.BackgroundColor3 = Color3.fromRGB(50,50,80)
speedSlider.Text = "16"
speedSlider.TextColor3 = Color3.fromRGB(255,255,255)
speedSlider.TextSize = 16
speedSlider.Font = Enum.Font.Gotham
local slCorner = Instance.new("UICorner")
slCorner.CornerRadius = UDim.new(0, 6)
slCorner.Parent = speedSlider

-- Jump
local jumpLabel = Instance.new("TextLabel")
jumpLabel.Parent = playerPanel
jumpLabel.Size = UDim2.new(0, 100, 0, 20)
jumpLabel.Position = UDim2.new(0.05, 0, 0.2, 0)
jumpLabel.BackgroundTransparency = 1
jumpLabel.Text = "Jump: 50"
jumpLabel.TextColor3 = Color3.fromRGB(200,200,255)
jumpLabel.TextSize = 14
jumpLabel.Font = Enum.Font.Gotham

local jumpSlider = Instance.new("TextBox")
jumpSlider.Parent = playerPanel
jumpSlider.Size = UDim2.new(0, 80, 0, 25)
jumpSlider.Position = UDim2.new(0.4, 0, 0.2, 0)
jumpSlider.BackgroundColor3 = Color3.fromRGB(50,50,80)
jumpSlider.Text = "50"
jumpSlider.TextColor3 = Color3.fromRGB(255,255,255)
jumpSlider.TextSize = 16
jumpSlider.Font = Enum.Font.Gotham
local jlCorner = Instance.new("UICorner")
jlCorner.CornerRadius = UDim.new(0, 6)
jlCorner.Parent = jumpSlider

-- Gravity
local gravLabel = Instance.new("TextLabel")
gravLabel.Parent = playerPanel
gravLabel.Size = UDim2.new(0, 100, 0, 20)
gravLabel.Position = UDim2.new(0.05, 0, 0.35, 0)
gravLabel.BackgroundTransparency = 1
gravLabel.Text = "Gravity: 196"
gravLabel.TextColor3 = Color3.fromRGB(200,200,255)
gravLabel.TextSize = 14
gravLabel.Font = Enum.Font.Gotham

local gravSlider = Instance.new("TextBox")
gravSlider.Parent = playerPanel
gravSlider.Size = UDim2.new(0, 80, 0, 25)
gravSlider.Position = UDim2.new(0.4, 0, 0.35, 0)
gravSlider.BackgroundColor3 = Color3.fromRGB(50,50,80)
gravSlider.Text = "196.2"
gravSlider.TextColor3 = Color3.fromRGB(255,255,255)
gravSlider.TextSize = 16
gravSlider.Font = Enum.Font.Gotham
local glCorner = Instance.new("UICorner")
glCorner.CornerRadius = UDim.new(0, 6)
glCorner.Parent = gravSlider

-- Apply button
local applyBtn = Instance.new("TextButton")
applyBtn.Parent = playerPanel
applyBtn.Size = UDim2.new(0, 120, 0, 30)
applyBtn.Position = UDim2.new(0.05, 0, 0.5, 0)
applyBtn.BackgroundColor3 = Color3.fromRGB(60,60,120)
applyBtn.Text = "Apply"
applyBtn.TextColor3 = Color3.fromRGB(255,255,255)
applyBtn.TextSize = 18
applyBtn.Font = Enum.Font.Gotham
local apCorner = Instance.new("UICorner")
apCorner.CornerRadius = UDim.new(0, 8)
apCorner.Parent = applyBtn

-- Infinite Gold
local goldBtn = Instance.new("TextButton")
goldBtn.Parent = playerPanel
goldBtn.Size = UDim2.new(0, 150, 0, 35)
goldBtn.Position = UDim2.new(0.55, 0, 0.5, 0)
goldBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 130)
goldBtn.Text = "Infinite Gold"
goldBtn.TextColor3 = Color3.fromRGB(255,255,255)
goldBtn.TextSize = 18
goldBtn.Font = Enum.Font.Gotham
local gCorner = Instance.new("UICorner")
gCorner.CornerRadius = UDim.new(0, 8)
gCorner.Parent = goldBtn
local gStroke = Instance.new("UIStroke")
gStroke.Color = Color3.fromRGB(255, 215, 0)
gStroke.Thickness = 1.5
gStroke.Parent = goldBtn

local GoldIndicator = Instance.new("ImageLabel")
GoldIndicator.Parent = goldBtn
GoldIndicator.Size = UDim2.new(0, 22, 0, 22)
GoldIndicator.Position = UDim2.new(1, -28, 0.5, -11)
GoldIndicator.BackgroundTransparency = 1
GoldIndicator.Image = "rbxassetid://5552526748"
GoldIndicator.ImageColor3 = Color3.fromRGB(255,0,0)

-- NoClip toggle
local noclipBtn = Instance.new("TextButton")
noclipBtn.Parent = playerPanel
noclipBtn.Size = UDim2.new(0, 150, 0, 35)
noclipBtn.Position = UDim2.new(0.55, 0, 0.15, 0)
noclipBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 130)
noclipBtn.Text = "NoClip"
noclipBtn.TextColor3 = Color3.fromRGB(255,255,255)
noclipBtn.TextSize = 18
noclipBtn.Font = Enum.Font.Gotham
local nCorner = Instance.new("UICorner")
nCorner.CornerRadius = UDim.new(0, 8)
nCorner.Parent = noclipBtn
local nStroke = Instance.new("UIStroke")
nStroke.Color = Color3.fromRGB(160, 160, 255)
nStroke.Thickness = 1.5
nStroke.Parent = noclipBtn

local NoclipIndicator = Instance.new("ImageLabel")
NoclipIndicator.Parent = noclipBtn
NoclipIndicator.Size = UDim2.new(0, 22, 0, 22)
NoclipIndicator.Position = UDim2.new(1, -28, 0.5, -11)
NoclipIndicator.BackgroundTransparency = 1
NoclipIndicator.Image = "rbxassetid://5552526748"
NoclipIndicator.ImageColor3 = Color3.fromRGB(255,0,0)

-- Infinite Tools
local toolsBtn = Instance.new("TextButton")
toolsBtn.Parent = playerPanel
toolsBtn.Size = UDim2.new(0, 150, 0, 35)
toolsBtn.Position = UDim2.new(0.1, 0, 0.15, 0)
toolsBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 130)
toolsBtn.Text = "Inf Tools"
toolsBtn.TextColor3 = Color3.fromRGB(255,255,255)
toolsBtn.TextSize = 18
toolsBtn.Font = Enum.Font.Gotham
local tCorner = Instance.new("UICorner")
tCorner.CornerRadius = UDim.new(0, 8)
tCorner.Parent = toolsBtn
local tStroke = Instance.new("UIStroke")
tStroke.Color = Color3.fromRGB(160, 160, 255)
tStroke.Thickness = 1.5
tStroke.Parent = toolsBtn

local ToolsIndicator = Instance.new("ImageLabel")
ToolsIndicator.Parent = toolsBtn
ToolsIndicator.Size = UDim2.new(0, 22, 0, 22)
ToolsIndicator.Position = UDim2.new(1, -28, 0.5, -11)
ToolsIndicator.BackgroundTransparency = 1
ToolsIndicator.Image = "rbxassetid://5552526748"
ToolsIndicator.ImageColor3 = Color3.fromRGB(255,0,0)

-- === Misc Tab ===
local miscPanel = createTab("Misc", 2)

local miscLabel = Instance.new("TextLabel")
miscLabel.Parent = miscPanel
miscLabel.Size = UDim2.new(1, -20, 0, 30)
miscLabel.Position = UDim2.new(0, 10, 0.05, 0)
miscLabel.BackgroundTransparency = 1
miscLabel.Text = "Hotkeys: F1-Farm, F2-AFK, F3-Gold, F4-Noclip, F5-Collect, F6-Fly, F7-Build"
miscLabel.TextColor3 = Color3.fromRGB(150,150,200)
miscLabel.TextSize = 16
miscLabel.Font = Enum.Font.Gotham

local hotkeyInfo = Instance.new("TextLabel")
hotkeyInfo.Parent = miscPanel
hotkeyInfo.Size = UDim2.new(1, -20, 0, 20)
hotkeyInfo.Position = UDim2.new(0, 10, 0.2, 0)
hotkeyInfo.BackgroundTransparency = 1
hotkeyInfo.Text = "F1: Farm, F2: Anti-AFK, F3: Gold, F4: NoClip, F5: Collect, F6: Fly, F7: Build"
hotkeyInfo.TextColor3 = Color3.fromRGB(200,200,255)
hotkeyInfo.TextSize = 14
hotkeyInfo.Font = Enum.Font.Gotham

-- === Points Tab ===
local pointsPanel = createTab("Points", 3)

-- Save current position
local saveBtn = Instance.new("TextButton")
saveBtn.Parent = pointsPanel
saveBtn.Size = UDim2.new(0, 150, 0, 35)
saveBtn.Position = UDim2.new(0.1, 0, 0.1, 0)
saveBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 130)
saveBtn.Text = "Save Current"
saveBtn.TextColor3 = Color3.fromRGB(255,255,255)
saveBtn.TextSize = 18
saveBtn.Font = Enum.Font.Gotham
local sCorner = Instance.new("UICorner")
sCorner.CornerRadius = UDim.new(0, 8)
sCorner.Parent = saveBtn

local pointNameInput = Instance.new("TextBox")
pointNameInput.Parent = pointsPanel
pointNameInput.Size = UDim2.new(0, 120, 0, 25)
pointNameInput.Position = UDim2.new(0.5, 0, 0.1, 0)
pointNameInput.BackgroundColor3 = Color3.fromRGB(50,50,80)
pointNameInput.Text = "point1"
pointNameInput.TextColor3 = Color3.fromRGB(255,255,255)
pointNameInput.TextSize = 16
pointNameInput.Font = Enum.Font.Gotham
local pnCorner = Instance.new("UICorner")
pnCorner.CornerRadius = UDim.new(0, 6)
pnCorner.Parent = pointNameInput

-- List of saved points
local pointList = Instance.new("TextLabel")
pointList.Parent = pointsPanel
pointList.Size = UDim2.new(1, -20, 0, 100)
pointList.Position = UDim2.new(0, 10, 0.3, 0)
pointList.BackgroundTransparency = 1
pointList.Text = "Saved points: none"
pointList.TextColor3 = Color3.fromRGB(200,200,255)
pointList.TextSize = 14
pointList.Font = Enum.Font.Gotham
pointList.TextWrapped = true
pointList.TextXAlignment = Enum.TextXAlignment.Left
pointList.TextYAlignment = Enum.TextYAlignment.Top

local tpToPointBtn = Instance.new("TextButton")
tpToPointBtn.Parent = pointsPanel
tpToPointBtn.Size = UDim2.new(0, 150, 0, 35)
tpToPointBtn.Position = UDim2.new(0.1, 0, 0.6, 0)
tpToPointBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 130)
tpToPointBtn.Text = "Teleport to first"
tpToPointBtn.TextColor3 = Color3.fromRGB(255,255,255)
tpToPointBtn.TextSize = 18
tpToPointBtn.Font = Enum.Font.Gotham
local tpCorner = Instance.new("UICorner")
tpCorner.CornerRadius = UDim.new(0, 8)
tpCorner.Parent = tpToPointBtn

local function updatePointList()
    local names = {}
    for k,_ in pairs(userPoints) do table.insert(names, k) end
    if #names == 0 then
        pointList.Text = "Saved points: none"
    else
        pointList.Text = "Saved points: " .. table.concat(names, ", ")
    end
end

saveBtn.MouseButton1Click:Connect(function()
    local c, h, r = getChar()
    if not r then return end
    local name = pointNameInput.Text
    if name == "" then name = "point" .. tostring(#userPoints+1) end
    savePoint(name, r.CFrame)
    updatePointList()
end)

tpToPointBtn.MouseButton1Click:Connect(function()
    local names = {}
    for k,_ in pairs(userPoints) do table.insert(names, k) end
    if #names > 0 then
        local first = names[1]
        local cf = userPoints[first]
        local c, h, r = getChar()
        if r then r.CFrame = cf end
    end
end)

-- === TAB SWITCHING ===
for i, name in ipairs(tabs) do
    tabButtons[name].MouseButton1Click:Connect(function()
        for _, p in pairs(panels) do p.Visible = false end
        panels[name].Visible = true
        for _, btn in pairs(tabButtons) do
            btn.BackgroundColor3 = Color3.fromRGB(50,50,80)
        end
        tabButtons[name].BackgroundColor3 = Color3.fromRGB(80,80,150)
    end)
end
tabButtons["Farm"].BackgroundColor3 = Color3.fromRGB(80,80,150)

-- === DRAGGING ===
local dragData = {dragging = false, start = nil, pos = nil}
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragData.dragging = true
        dragData.start = input.Position
        dragData.pos = MainFrame.Position
    end
end)
TitleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragData.dragging = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragData.dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragData.start
        MainFrame.Position = UDim2.new(
            dragData.pos.X.Scale,
            dragData.pos.X.Offset + delta.X,
            dragData.pos.Y.Scale,
            dragData.pos.Y.Offset + delta.Y
        )
    end
end)

-- === MINIMIZE ===
local minimized = false
MinButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    MinButton.Text = minimized and "+" or "−"
    MainFrame.Size = minimized and UDim2.new(0, 450, 0, 35) or UDim2.new(0, 450, 0, 320)
end)

-- === BUTTON LOGIC ===
-- Farm
FarmBtn.MouseButton1Click:Connect(function()
    autoFarmEnabled = not autoFarmEnabled
    FarmIndicator.ImageColor3 = autoFarmEnabled and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
    FarmBtn.Text = autoFarmEnabled and "Stop Farm" or "Start Farm"
    if autoFarmEnabled then
        if farmTask then coroutine.close(farmTask) end
        farmTask = coroutine.create(farmLoop)
        coroutine.resume(farmTask)
    else
        if farmTask then coroutine.close(farmTask); farmTask = nil end
        workspace.Gravity = gravityNormal
    end
end)

-- Anti AFK
AntiAfkBtn.MouseButton1Click:Connect(function()
    antiAfkEnabled = not antiAfkEnabled
    AfkIndicator.ImageColor3 = antiAfkEnabled and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
end)

-- Auto-Collect
CollectBtn.MouseButton1Click:Connect(function()
    autoCollectEnabled = not autoCollectEnabled
    CollectIndicator.ImageColor3 = autoCollectEnabled and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
    if autoCollectEnabled then
        if collectionTask then coroutine.close(collectionTask) end
        collectionTask = coroutine.create(autoCollectLoop)
        coroutine.resume(collectionTask)
    else
        if collectionTask then coroutine.close(collectionTask); collectionTask = nil end
    end
end)

-- Gold
goldBtn.MouseButton1Click:Connect(function()
    infiniteGoldEnabled = not infiniteGoldEnabled
    GoldIndicator.ImageColor3 = infiniteGoldEnabled and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
end)

-- NoClip
noclipBtn.MouseButton1Click:Connect(function()
    noClipEnabled = not noClipEnabled
    NoclipIndicator.ImageColor3 = noClipEnabled and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
    setNoClip(noClipEnabled)
end)

-- Infinite Tools
toolsBtn.MouseButton1Click:Connect(function()
    infiniteToolsEnabled = not infiniteToolsEnabled
    ToolsIndicator.ImageColor3 = infiniteToolsEnabled and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
    if infiniteToolsEnabled then
        makeToolsInfinite()
    end
end)

-- Apply player settings
applyBtn.MouseButton1Click:Connect(function()
    local speed = tonumber(speedSlider.Text) or 16
    local jump = tonumber(jumpSlider.Text) or 50
    local grav = tonumber(gravSlider.Text) or 196.2
    local c, h, r = getChar()
    if h then
        h.WalkSpeed = speed
        h.JumpPower = jump
    end
    workspace.Gravity = grav
    speedLabel.Text = "Speed: " .. speed
    jumpLabel.Text = "Jump: " .. jump
    gravLabel.Text = "Gravity: " .. grav
end)

-- === HOTKEYS ===
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F1 then
        FarmBtn.MouseButton1Click:Fire()
    elseif input.KeyCode == Enum.KeyCode.F2 then
        AntiAfkBtn.MouseButton1Click:Fire()
    elseif input.KeyCode == Enum.KeyCode.F3 then
        goldBtn.MouseButton1Click:Fire()
    elseif input.KeyCode == Enum.KeyCode.F4 then
        noclipBtn.MouseButton1Click:Fire()
    elseif input.KeyCode == Enum.KeyCode.F5 then
        CollectBtn.MouseButton1Click:Fire()
    elseif input.KeyCode == Enum.KeyCode.F6 then
        toggleFly()
    elseif input.KeyCode == Enum.KeyCode.F7 then
        buildEnabled = not buildEnabled
        if buildEnabled then
            autoBuild()
        end
    end
end)

-- === ANTI-AFK LOOP ===
task.spawn(function()
    while true do
        task.wait(10)
        if antiAfkEnabled then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.K, false, game)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.K, false, game)
        end
    end
end)

-- === RESPAWN HANDLER ===
player.CharacterAdded:Connect(function(newChar)
    currentCharacter = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    rootPart = newChar:WaitForChild("HumanoidRootPart")
    -- Apply GodMode immediately
    setGodMode(true)
    if autoFarmEnabled then
        if farmTask then coroutine.close(farmTask); farmTask = nil end
        farmTask = coroutine.create(farmLoop)
        coroutine.resume(farmTask)
    end
    if noClipEnabled then
        setNoClip(true)
    end
    if infiniteToolsEnabled then
        makeToolsInfinite()
    end
    -- reapply player stats from sliders
    local spd = tonumber(speedSlider.Text) or 16
    local jmp = tonumber(jumpSlider.Text) or 50
    if humanoid then
        humanoid.WalkSpeed = spd
        humanoid.JumpPower = jmp
    end
end)

-- === OPTIMIZATION: heartbeat for godmode, gold and tools injection ===
RunService.Heartbeat:Connect(function()
    -- Keep GodMode always active
    setGodMode(true)
    if infiniteGoldEnabled then
        local ls = player:FindFirstChild("leaderstats")
        if ls then
            for _, stat in ipairs(ls:GetChildren()) do
                if stat:IsA("NumberValue") and string.find(stat.Name:lower(), "gold") then
                    stat.Value = 999999
                end
            end
        end
    end
    if infiniteToolsEnabled then
        makeToolsInfinite()
    end
end)

print("[+] Ultimate Farm v7.0 loaded. Use F1-F7 hotkeys. GodMode active (no damage).")
