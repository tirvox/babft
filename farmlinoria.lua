-- tirvoxhub – v9: removed spinbot and experimental

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

-- ==================== СЕРВИСЫ ====================
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Lighting = game:GetService("Lighting")

local gravityNormal = workspace.Gravity
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

-- ==================== ФЛАГИ ====================
local autoFarmEnabled = false
local antiAfkEnabled = false
local flyEnabled = false
local farmTask = nil
local infinityJumpEnabled = false
local noclipEnabled = false
local autoStopEnabled = false
local clickTpEnabled = false
local autoClaimGoldEnabled = true
local claimGoldTask = nil
local fullbrightEnabled = false
local fpsBoostEnabled = false
local playerEspEnabled = false
local zoomEnabled = false

-- ==================== FLY ====================
local flyBodyVelocity = nil
local flyBodyGyro = nil
local flyKeys = {W=false, A=false, S=false, D=false, Space=false, Q=false}
local flySpeed = 50

-- ==================== INFINITY JUMP ====================
local jumpHeld = false
local jumpTimer = 0
local JUMP_INTERVAL = 0.1

-- ==================== CLICK TP ====================
local clickTpHeld = false
local mouse = player:GetMouse()

-- ==================== ESP ====================
local espObjects = {}

-- ==================== ВСПОМОГАТЕЛЬНЫЕ ====================
local function getChar()
    local c = player.Character
    if not c then return nil, nil, nil end
    local r = c:FindFirstChild("HumanoidRootPart")
    local h = c:FindFirstChild("Humanoid")
    return c, h, r
end

local function setGodMode()
    local c, h, r = getChar()
    if not h then return end
    h.MaxHealth = math.huge
    h.Health = math.huge
    h.BreakJointsOnDeath = false
    h:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
    h:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
    h:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
    h:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    h:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
    h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
end

-- ==================== AUTO CLAIM GOLD ====================
local claimGoldInterval = 0.5

local function claimGold()
    local claimRemote = workspace:FindFirstChild("ClaimRiverResultsGold")
    if claimRemote then
        pcall(function()
            claimRemote:FireServer()
        end)
    end
end

local function startClaimGoldLoop()
    while autoClaimGoldEnabled do
        claimGold()
        task.wait(claimGoldInterval)
    end
end

-- ==================== NOCLIP ====================
RunService.Stepped:Connect(function()
    if noclipEnabled then
        local c = player.Character
        if c then
            for _, part in ipairs(c:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
end)

local function disableNoclip()
    local c = player.Character
    if c then
        for _, part in ipairs(c:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
    end
end

-- ==================== ПОЛЁТ ====================
local function setupFly()
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if flyBodyVelocity then flyBodyVelocity:Destroy() end
    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    flyBodyVelocity.Parent = root
    if flyBodyGyro then flyBodyGyro:Destroy() end
    flyBodyGyro = Instance.new("BodyGyro")
    flyBodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    flyBodyGyro.P = 100000
    flyBodyGyro.CFrame = root.CFrame
    flyBodyGyro.Parent = root
    local hum = char:FindFirstChild("Humanoid")
    if hum then hum.PlatformStand = true end
    workspace.Gravity = 0
end

local function teardownFly()
    if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity = nil end
    if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro = nil end
    local char = player.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then hum.PlatformStand = false end
    end
    workspace.Gravity = gravityNormal
end

local function toggleFly()
    flyEnabled = not flyEnabled
    if flyEnabled then setupFly() else teardownFly() end
end

-- ==================== FULLBRIGHT ====================
local originalLighting = {
    Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
}

local function applyFullbright()
    Lighting.Brightness = 2
    Lighting.ClockTime = 14
    Lighting.FogEnd = 100000
    Lighting.GlobalShadows = false
    Lighting.Ambient = Color3.fromRGB(178, 178, 178)
    Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
end

local function removeFullbright()
    Lighting.Brightness = originalLighting.Brightness
    Lighting.ClockTime = originalLighting.ClockTime
    Lighting.FogEnd = originalLighting.FogEnd
    Lighting.GlobalShadows = originalLighting.GlobalShadows
    Lighting.Ambient = originalLighting.Ambient
    Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
end

-- ==================== FPS BOOST ====================
local function applyFpsBoost()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Material = Enum.Material.SmoothPlastic
            obj.Reflectance = 0
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = 1
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
            obj.Enabled = false
        end
    end
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    if workspace:FindFirstChildOfClass("Terrain") then
        workspace.Terrain.WaterWaveSize = 0
        workspace.Terrain.WaterWaveSpeed = 0
        workspace.Terrain.WaterReflectance = 0
        workspace.Terrain.Decoration = false
    end
    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("PostEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("BloomEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("DepthOfFieldEffect") then
            v.Enabled = false
        end
    end
end

-- ==================== PLAYER ESP ====================
local function createEsp(p)
    if p == player then return end
    local function setup(char)
        if not char then return end
        local hl = Instance.new("Highlight")
        hl.Name = "tirvox_esp"
        hl.FillColor = Color3.fromRGB(255, 0, 0)
        hl.FillTransparency = 0.5
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.OutlineTransparency = 0
        hl.Parent = char
        espObjects[p] = hl
    end
    if p.Character then setup(p.Character) end
    p.CharacterAdded:Connect(function(c) setup(c) end)
end

local function enableEsp()
    for _, p in ipairs(Players:GetPlayers()) do createEsp(p) end
    Players.PlayerAdded:Connect(createEsp)
end

local function disableEsp()
    for p, hl in pairs(espObjects) do hl:Destroy() end
    espObjects = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            local hl = p.Character:FindFirstChild("tirvox_esp")
            if hl then hl:Destroy() end
        end
    end
end

-- ==================== ZOOM UNLOCK ====================
local function enableZoom()
    player.CameraMaxZoomDistance = 999999
    player.CameraMinZoomDistance = 0.5
end

local function disableZoom()
    player.CameraMaxZoomDistance = 128
    player.CameraMinZoomDistance = 0.5
end

-- ==================== ВВОД ====================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if clickTpEnabled and clickTpHeld then
            local c, h, r = getChar()
            if r and mouse.Hit then
                r.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
            end
        end
    end

    if gameProcessed then return end
    local key = input.KeyCode
    
    if Options.FlyKeybind and key == Options.FlyKeybind.Value then
        Toggles.FlyToggle:SetValue(not Toggles.FlyToggle.Value); return
    end
    if Options.InfJumpKeybind and key == Options.InfJumpKeybind.Value then
        Toggles.InfinityJumpToggle:SetValue(not Toggles.InfinityJumpToggle.Value); return
    end
    if Options.NoclipKeybind and key == Options.NoclipKeybind.Value then
        Toggles.NoclipToggle:SetValue(not Toggles.NoclipToggle.Value); return
    end
    if Options.ClickTpKeybind and key == Options.ClickTpKeybind.Value then
        clickTpHeld = true; return
    end

    if key == Enum.KeyCode.W then flyKeys.W = true
    elseif key == Enum.KeyCode.A then flyKeys.A = true
    elseif key == Enum.KeyCode.S then flyKeys.S = true
    elseif key == Enum.KeyCode.D then flyKeys.D = true
    elseif key == Enum.KeyCode.Space then
        flyKeys.Space = true; jumpHeld = true
        if infinityJumpEnabled and not flyEnabled then
            local c, h, r = getChar()
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    elseif key == Enum.KeyCode.Q then flyKeys.Q = true end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    local key = input.KeyCode
    if key == Enum.KeyCode.W then flyKeys.W = false
    elseif key == Enum.KeyCode.A then flyKeys.A = false
    elseif key == Enum.KeyCode.S then flyKeys.S = false
    elseif key == Enum.KeyCode.D then flyKeys.D = false
    elseif key == Enum.KeyCode.Space then flyKeys.Space = false; jumpHeld = false
    elseif key == Enum.KeyCode.Q then flyKeys.Q = false end

    if Options.ClickTpKeybind and key == Options.ClickTpKeybind.Value then
        clickTpHeld = false
    end
end)

-- ==================== HEARTBEAT ====================
RunService.Heartbeat:Connect(function(dt)
    setGodMode()
    if infinityJumpEnabled and not flyEnabled and jumpHeld then
        jumpTimer = jumpTimer + dt
        if jumpTimer >= JUMP_INTERVAL then
            jumpTimer = 0
            local c, h, r = getChar()
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    else
        jumpTimer = 0
    end
    if flyEnabled then
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root and flyBodyVelocity then
                local move = Vector3.new(0, 0, 0)
                local cam = workspace.CurrentCamera
                local camCF = cam and cam.CFrame or root.CFrame
                if flyKeys.W then move = move + camCF.LookVector end
                if flyKeys.S then move = move - camCF.LookVector end
                if flyKeys.A then move = move - camCF.RightVector end
                if flyKeys.D then move = move + camCF.RightVector end
                if flyKeys.Space then move = move + Vector3.new(0, 1, 0) end
                if flyKeys.Q then move = move - Vector3.new(0, 1, 0) end
                if move.Magnitude > 0 then
                    move = move.Unit * flySpeed
                    if flyBodyGyro then
                        flyBodyGyro.CFrame = CFrame.new(root.Position, root.Position + camCF.LookVector)
                    end
                else
                    if autoStopEnabled then root.AssemblyLinearVelocity = Vector3.zero end
                end
                flyBodyVelocity.Velocity = move
            end
        end
    end
    local c, h, r = getChar()
    if r and r.Position.Y < -500 then r.CFrame = destinations[1] end
end)

-- ==================== ФАРМ ====================
local function tpMode(cf)
    local c, h, r = getChar()
    if not r then return end
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
end

local function farmLoop()
    workspace.Gravity = 0
    while autoFarmEnabled do
        local c, h, r = getChar()
        if not r then task.wait(1) continue end
        for i, cf in ipairs(destinations) do
            if not autoFarmEnabled then workspace.Gravity = gravityNormal; return end
            tpMode(cf)
            if autoClaimGoldEnabled and i > 1 and i < #destinations then
                claimGold()
            end
            local delay = Options.FarmDelay and Options.FarmDelay.Value or 0.1
            task.wait(delay)
        end
        task.wait(1)
    end
    workspace.Gravity = gravityNormal
end

-- ==================== AUTOBUY ====================
local autoBuyChestEnabled = false
local autoBuyItemEnabled = false
local autoBuyChestTask = nil
local autoBuyItemTask = nil
local remoteBuy = nil

local function buyItem(itemName, amount)
    if not remoteBuy then
        remoteBuy = workspace:FindFirstChild("ItemBoughtFromShop")
        if not remoteBuy then return false end
    end
    return pcall(function() remoteBuy:InvokeServer(itemName, amount) end)
end

local function autoBuyChestLoop()
    while autoBuyChestEnabled do
        buyItem(Options.AutoBuyChest and Options.AutoBuyChest.Value or "Common Chest",
                Options.ChestAmount and tonumber(Options.ChestAmount.Value) or 1)
        task.wait(Options.ChestInterval and Options.ChestInterval.Value or 5)
    end
end

local function autoBuyItemLoop()
    while autoBuyItemEnabled do
        buyItem(Options.AutoBuyItem and Options.AutoBuyItem.Value or "WoodBlock",
                Options.ItemAmount and tonumber(Options.ItemAmount.Value) or 1)
        task.wait(Options.ItemInterval and Options.ItemInterval.Value or 5)
    end
end

-- ==================== АНТИ-AFK ====================
task.spawn(function()
    while true do
        task.wait(10)
        if antiAfkEnabled then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.K, false, game)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.K, false, game)
        end
    end
end)

-- ==================== ОБРАБОТКА РЕСПАВНА ====================
player.CharacterAdded:Connect(function(newChar)
    local humanoid = newChar:WaitForChild("Humanoid")
    setGodMode()
    if autoFarmEnabled then
        if farmTask then coroutine.close(farmTask); farmTask = nil end
        farmTask = coroutine.create(farmLoop)
        coroutine.resume(farmTask)
    end
    if flyEnabled then flyBodyVelocity = nil; flyBodyGyro = nil; setupFly() end
    if autoClaimGoldEnabled then
        if claimGoldTask then coroutine.close(claimGoldTask); claimGoldTask = nil end
        claimGoldTask = coroutine.create(startClaimGoldLoop)
        coroutine.resume(claimGoldTask)
    end
    humanoid.WalkSpeed = Options.Speed and Options.Speed.Value or 16
    humanoid.JumpPower = Options.Jump and Options.Jump.Value or 50
end)

-- ==================== ИНТЕРФЕЙС ====================
local Window = Library:CreateWindow({
    Title = 'tirvoxhub', Center = true, AutoShow = true, TabPadding = 8, MenuFadeTime = 0.2
})

local Tabs = {
    Farm = Window:AddTab('Farm'),
    Player = Window:AddTab('Player'),
    Autobuy = Window:AddTab('Autobuy'),
    Misc = Window:AddTab('Misc'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

-- ==================== FARM ====================
local farmGroup = Tabs.Farm:AddLeftGroupbox('Farm Controls')

farmGroup:AddToggle('FarmToggle', {
    Text = 'Auto Farm', Default = false, Tooltip = 'Toggle farming by points (TP mode)',
    Callback = function(val)
        autoFarmEnabled = val
        if autoFarmEnabled then
            if farmTask then coroutine.close(farmTask); farmTask = nil end
            farmTask = coroutine.create(farmLoop); coroutine.resume(farmTask)
        else
            if farmTask then coroutine.close(farmTask); farmTask = nil end
            workspace.Gravity = gravityNormal
        end
    end
})

farmGroup:AddSlider('FarmDelay', {
    Text = 'Delay between points (s)', Default = 0.1, Min = 0, Max = 5, Rounding = 1, Suffix = 's',
    Tooltip = 'Pause after each teleport',
})

farmGroup:AddToggle('AntiAfkToggle', {
    Text = 'Anti AFK', Default = false, Tooltip = 'Simulates K key press every 10s',
    Callback = function(val) antiAfkEnabled = val end
})

farmGroup:AddToggle('AutoClaimGoldToggle', {
    Text = 'Auto Claim Gold', Default = true, Tooltip = 'Collect river gold (skip first & last point)',
    Callback = function(val)
        autoClaimGoldEnabled = val
        if val then
            if claimGoldTask then coroutine.close(claimGoldTask); claimGoldTask = nil end
            claimGoldTask = coroutine.create(startClaimGoldLoop); coroutine.resume(claimGoldTask)
        else
            if claimGoldTask then coroutine.close(claimGoldTask); claimGoldTask = nil end
        end
    end
})

farmGroup:AddSlider('ClaimGoldInterval', {
    Text = 'Gold interval (s)', Default = 0.5, Min = 0.1, Max = 5, Rounding = 2, Suffix = 's',
    Callback = function(val) claimGoldInterval = val end
})

-- ==================== PLAYER — Movement ====================
local moveGroup = Tabs.Player:AddLeftGroupbox('Movement')

moveGroup:AddSlider('Speed', {
    Text = 'Walk Speed', Default = 16, Min = 0, Max = 1000, Rounding = 1,
    Tooltip = 'Character walk speed',
    Callback = function(val) local c, h, r = getChar(); if h then h.WalkSpeed = val end end
})

moveGroup:AddSlider('Jump', {
    Text = 'Jump Power', Default = 50, Min = 0, Max = 500, Rounding = 1,
    Tooltip = 'Jump force',
    Callback = function(val) local c, h, r = getChar(); if h then h.JumpPower = val end end
})

moveGroup:AddSlider('Gravity', {
    Text = 'Gravity', Default = 196.2, Min = -100, Max = 500, Rounding = 1,
    Tooltip = 'World gravity',
    Callback = function(val) workspace.Gravity = val; gravityNormal = val end
})

moveGroup:AddSlider('FlySpeed', {
    Text = 'Fly Speed', Default = 50, Min = 10, Max = 1000, Rounding = 1, Suffix = ' s/s',
    Tooltip = 'Speed in Fly mode',
    Callback = function(val) flySpeed = val end
})

moveGroup:AddToggle('AutoStopToggle', {
    Text = 'Auto Stop', Default = false, Tooltip = 'Instant stop when no keys pressed (Fly)',
    Callback = function(val) autoStopEnabled = val end
})

local flyToggle = moveGroup:AddToggle('FlyToggle', {
    Text = 'Fly Mode', Default = false, Tooltip = 'Flight (WASD + Space/Q, camera-relative)',
    Callback = function(val) if val ~= flyEnabled then toggleFly() end end
})
flyToggle:AddKeyPicker('FlyKeybind', { Default = 'F', Text = 'Fly', SyncToggleState = true, Mode = 'Toggle' })

local infJumpToggle = moveGroup:AddToggle('InfinityJumpToggle', {
    Text = 'Infinity Jump', Default = false, Tooltip = 'Infinite jump while holding Space',
    Callback = function(val) infinityJumpEnabled = val end
})
infJumpToggle:AddKeyPicker('InfJumpKeybind', { Default = 'G', Text = 'Inf Jump', SyncToggleState = true, Mode = 'Toggle' })

local noclipToggle = moveGroup:AddToggle('NoclipToggle', {
    Text = 'Noclip', Default = false, Tooltip = 'Through walls — walking and flying',
    Callback = function(val) noclipEnabled = val; if not val then disableNoclip() end end
})
noclipToggle:AddKeyPicker('NoclipKeybind', { Default = 'H', Text = 'Noclip', SyncToggleState = true, Mode = 'Toggle' })

local clickTpToggle = moveGroup:AddToggle('ClickTpToggle', {
    Text = 'Click TP', Default = false, Tooltip = 'Hold key + click to teleport to mouse',
    Callback = function(val) clickTpEnabled = val end
})
clickTpToggle:AddKeyPicker('ClickTpKeybind', { Default = 'V', Text = 'Click TP', SyncToggleState = false, Mode = 'Hold' })

-- ==================== PLAYER — Visuals ====================
local visGroup = Tabs.Player:AddRightGroupbox('Visuals')

visGroup:AddToggle('FullbrightToggle', {
    Text = 'Fullbright', Default = false, Tooltip = 'Max brightness everywhere',
    Callback = function(val) fullbrightEnabled = val; if val then applyFullbright() else removeFullbright() end end
})

visGroup:AddToggle('FpsBoostToggle', {
    Text = 'FPS Boost', Default = false, Tooltip = 'Lower graphics for more FPS',
    Callback = function(val) fpsBoostEnabled = val; if val then applyFpsBoost() end end
})

visGroup:AddToggle('PlayerEspToggle', {
    Text = 'Player ESP', Default = false, Tooltip = 'See other players through walls',
    Callback = function(val) playerEspEnabled = val; if val then enableEsp() else disableEsp() end end
})

visGroup:AddToggle('ZoomToggle', {
    Text = 'Zoom Unlock', Default = false, Tooltip = 'Remove camera distance limit',
    Callback = function(val) zoomEnabled = val; if val then enableZoom() else disableZoom() end end
})

-- ==================== AUTOBUY ====================
local chestGroup = Tabs.Autobuy:AddLeftGroupbox('Auto Chest Buyer')

chestGroup:AddDropdown('AutoBuyChest', {
    Text = 'Chest type',
    Values = {'Common Chest', 'Uncommon Chest', 'Rare Chest', 'Epic Chest', 'Legendary Chest'},
    Default = 1,
})

chestGroup:AddInput('ChestAmount', {
    Text = 'Amount per buy', Default = '1', Placeholder = '1', Numeric = true,
})

chestGroup:AddButton({ Text = 'Buy now', Func = function()
    buyItem(Options.AutoBuyChest.Value, tonumber(Options.ChestAmount.Value) or 1)
end })

chestGroup:AddToggle('AutoBuyChestEnabled', {
    Text = 'Auto buy chests', Default = false,
    Callback = function(val)
        autoBuyChestEnabled = val
        if val then
            if autoBuyChestTask then coroutine.close(autoBuyChestTask); autoBuyChestTask = nil end
            autoBuyChestTask = coroutine.create(autoBuyChestLoop); coroutine.resume(autoBuyChestTask)
        else
            if autoBuyChestTask then coroutine.close(autoBuyChestTask); autoBuyChestTask = nil end
        end
    end
})

chestGroup:AddSlider('ChestInterval', {
    Text = 'Interval (s)', Default = 5, Min = 1, Max = 60, Rounding = 1, Suffix = 's',
})

local itemGroup = Tabs.Autobuy:AddRightGroupbox('Item Buyer')

itemGroup:AddDropdown('AutoBuyItem', {
    Text = 'Item',
    Values = {
        'Sign', 'BoatMotor', 'Car Parts', 'Parachutes', 'Harpoon', 'Balloons', 'JetPacks',
        'Switch', 'Button', 'LightBulb', 'CameraDome', 'Locked Doors', 'Note',
        'HingeBlocks', 'Pistons', 'Magnets', 'LegacyCarPack', 'SensorBlock', 'Gate',
        'DisplayBlock', 'RemoteController', 'Rope', 'Bar', 'Spring', 'SticksOfTNT',
        'SpikeTrap', 'Cannon', 'CannonTurret', 'SwordMount', 'GunMount', 'CannonMount',
        'WoodBlock', 'SmoothWoodBlock', 'GlassBlock', 'FabricBlock', 'PlasticBlock',
        'GrassBlock', 'RustedBlock', 'BouncyBlock', 'MetalBlock', 'ConcreteBlock',
        'CoalBlock', 'MarbleBlock', 'TitaniumBlock', 'ObsidianBlock', 'CornerWedge', 'Throne'
    },
    Default = 1,
})

itemGroup:AddInput('ItemAmount', {
    Text = 'Amount per buy', Default = '1', Placeholder = '1', Numeric = true,
})

itemGroup:AddButton({ Text = 'Buy now', Func = function()
    buyItem(Options.AutoBuyItem.Value, tonumber(Options.ItemAmount.Value) or 1)
end })

itemGroup:AddToggle('AutoBuyItemEnabled', {
    Text = 'Auto buy items', Default = false,
    Callback = function(val)
        autoBuyItemEnabled = val
        if val then
            if autoBuyItemTask then coroutine.close(autoBuyItemTask); autoBuyItemTask = nil end
            autoBuyItemTask = coroutine.create(autoBuyItemLoop); coroutine.resume(autoBuyItemTask)
        else
            if autoBuyItemTask then coroutine.close(autoBuyItemTask); autoBuyItemTask = nil end
        end
    end
})

itemGroup:AddSlider('ItemInterval', {
    Text = 'Interval (s)', Default = 5, Min = 1, Max = 60, Rounding = 1, Suffix = 's',
})

-- ==================== MISC ====================
local creditsGroup = Tabs.Misc:AddLeftGroupbox('Credits')
creditsGroup:AddLabel('Credits: kiten, tirvox', true)

local gamesGroup = Tabs.Misc:AddRightGroupbox('Games')
gamesGroup:AddLabel('Works in this games:', true)
gamesGroup:AddLabel('• Dingus', true)
gamesGroup:AddLabel('• Build a Boat for Treasure', true)

-- ==================== UI SETTINGS ====================
local menuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')

menuGroup:AddButton({ Text = 'Unload (reset)', Func = function() Library:Unload() end })

local menuKeyLabel = menuGroup:AddLabel('Menu key')
menuKeyLabel:AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu keybind' })

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind', 'FlyKeybind', 'InfJumpKeybind', 'NoclipKeybind', 'ClickTpKeybind' })
ThemeManager:SetFolder('tirvoxhub')
SaveManager:SetFolder('tirvoxhub/configs')
SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])
SaveManager:LoadAutoloadConfig()

-- ==================== СБРОС ====================
local function resetSettings()
    autoFarmEnabled = false; antiAfkEnabled = false; flyEnabled = false
    infinityJumpEnabled = false; noclipEnabled = false; autoStopEnabled = false
    clickTpEnabled = false; autoClaimGoldEnabled = false
    fullbrightEnabled = false; fpsBoostEnabled = false; playerEspEnabled = false
    zoomEnabled = false
    autoBuyChestEnabled = false; autoBuyItemEnabled = false

    if farmTask then coroutine.close(farmTask); farmTask = nil end
    if autoBuyChestTask then coroutine.close(autoBuyChestTask); autoBuyChestTask = nil end
    if autoBuyItemTask then coroutine.close(autoBuyItemTask); autoBuyItemTask = nil end
    if claimGoldTask then coroutine.close(claimGoldTask); claimGoldTask = nil end

    teardownFly(); disableNoclip(); removeFullbright(); disableEsp(); disableZoom()

    workspace.Gravity = gravityNormal
    local c = player.Character
    if c then
        local h = c:FindFirstChild("Humanoid")
        if h then h.WalkSpeed = 16; h.JumpPower = 50; h.PlatformStand = false end
    end
end

Library:OnUnload(function() resetSettings() end)
