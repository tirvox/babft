-- tirvoxhub – фикс автофарма + Autobuy + Auto Claim Gold (оптимизированный)

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
    Title = 'tirvoxhub',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

-- ==================== ОСНОВНАЯ ЛОГИКА (из старого рабочего скрипта) ====================
local player = game.Players.LocalPlayer
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local gravityNormal = workspace.Gravity
local farmMode = "TP"
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

local autoFarmEnabled = false
local antiAfkEnabled = false
local flyEnabled = false
local farmTask = nil

local infinityJumpEnabled = false
local noclipEnabled = false
local jumpKeyPressed = false
local jumpTimer = 0
local JUMP_INTERVAL = 0.2

-- ==================== AUTOBUY (тихий) ====================
local autoBuyChestEnabled = false
local autoBuyItemEnabled = false
local autoBuyChestTask = nil
local autoBuyItemTask = nil
local remoteBuy = nil

-- ==================== AUTO CLAIM GOLD (оптимизированный) ====================
local autoClaimGoldEnabled = false
local claimGoldTask = nil
local claimGoldInterval = 0.5  -- настраиваемый интервал (по умолчанию 0.5 с)

local function startClaimGoldLoop()
    local claimGoldRemote = workspace:FindFirstChild("ClaimRiverResultsGold")
    if not claimGoldRemote then return end

    while autoClaimGoldEnabled do
        pcall(function()
            claimGoldRemote:FireServer()
        end)
        task.wait(claimGoldInterval)
    end
end

-- === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
local function getChar()
    local c = player.Character
    if not c then return nil, nil, nil end
    local r = c:FindFirstChild("HumanoidRootPart")
    local h = c:FindFirstChild("Humanoid")
    return c, h, r
end

local function setGodMode(enabled)
    local c, h, r = getChar()
    if not h then return end
    if enabled then
        h.MaxHealth = math.huge
        h.Health = math.huge
        h.BreakJointsOnDeath = false
        h:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
        h:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
        h:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        h:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
        h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
    else
        h.MaxHealth = 100
        h.BreakJointsOnDeath = true
    end
end

local function updateNoclip()
    local c = player.Character
    if not c then return end
    for _, part in ipairs(c:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = not noclipEnabled
        end
    end
end

local function handleInfinityJump(dt)
    if not infinityJumpEnabled then return end
    if flyEnabled then return end
    local c, h, r = getChar()
    if not h then return end
    if jumpKeyPressed then
        jumpTimer = jumpTimer + dt
        if jumpTimer >= JUMP_INTERVAL then
            jumpTimer = 0
            h.Jump = true
            h:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    else
        jumpTimer = 0
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Space then
        jumpKeyPressed = true
    end
end)
UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Space then
        jumpKeyPressed = false
    end
end)

-- === ФАРМ ===
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

local function tweenMode(cf)
    local c, h, r = getChar()
    if not r then return end
    local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local goal = {CFrame = cf}
    local tween = TweenService:Create(r, tweenInfo, goal)
    tween:Play()
    tween.Completed:Wait()
    task.wait(1)
end

local function farmLoop()
    workspace.Gravity = 0
    local modeFunc = (farmMode == "TP") and tpMode or tweenMode
    while autoFarmEnabled do
        local c, h, r = getChar()
        if not r then task.wait(1) continue end
        for i, cf in ipairs(destinations) do
            if not autoFarmEnabled then
                workspace.Gravity = gravityNormal
                return
            end
            modeFunc(cf)
            local delay = Options.FarmDelay and Options.FarmDelay.Value or 0.1
            task.wait(delay)
        end
        task.wait(1)
    end
    workspace.Gravity = gravityNormal
end

-- === AUTOBUY ===
local function buyItem(itemName, amount)
    if not remoteBuy then
        remoteBuy = workspace:FindFirstChild("ItemBoughtFromShop")
        if not remoteBuy then return false end
    end
    local success, err = pcall(function()
        remoteBuy:InvokeServer(itemName, amount)
    end)
    return success
end

local function autoBuyChestLoop()
    while autoBuyChestEnabled do
        local chest = Options.AutoBuyChest and Options.AutoBuyChest.Value or "Common Chest"
        local amount = Options.ChestAmount and Options.ChestAmount.Value or 1
        buyItem(chest, amount)
        local interval = Options.ChestInterval and Options.ChestInterval.Value or 5
        task.wait(interval)
    end
end

local function autoBuyItemLoop()
    while autoBuyItemEnabled do
        local item = Options.AutoBuyItem and Options.AutoBuyItem.Value or "WoodBlock"
        local amount = Options.ItemAmount and Options.ItemAmount.Value or 1
        buyItem(item, amount)
        local interval = Options.ItemInterval and Options.ItemInterval.Value or 5
        task.wait(interval)
    end
end

-- === ПОЛЁТ ===
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
    if move.Magnitude > 0 then move = move.Unit * flySpeed end
    flyBodyVelocity.Velocity = move
end)

-- Анти-AFK
task.spawn(function()
    while true do
        task.wait(10)
        if antiAfkEnabled then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.K, false, game)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.K, false, game)
        end
    end
end)

-- Обработка респавна
player.CharacterAdded:Connect(function(newChar)
    currentCharacter = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    rootPart = newChar:WaitForChild("HumanoidRootPart")
    setGodMode(true)
    if autoFarmEnabled then
        if farmTask then coroutine.close(farmTask); farmTask = nil end
        farmTask = coroutine.create(farmLoop)
        coroutine.resume(farmTask)
    end
    if autoClaimGoldEnabled then
        if claimGoldTask then coroutine.close(claimGoldTask); claimGoldTask = nil end
        claimGoldTask = coroutine.create(startClaimGoldLoop)
        coroutine.resume(claimGoldTask)
    end
    local spd = Options.Speed and Options.Speed.Value or 16
    local jmp = Options.Jump and Options.Jump.Value or 50
    if humanoid then
        humanoid.WalkSpeed = spd
        humanoid.JumpPower = jmp
    end
    updateNoclip()
end)

local lastTime = tick()
RunService.Heartbeat:Connect(function()
    local now = tick()
    local dt = now - lastTime
    lastTime = now

    setGodMode(true)
    handleInfinityJump(dt)

    local c, h, r = getChar()
    if r and r.Position.Y < -500 then
        r.CFrame = destinations[1]
    end
end)

-- ==================== ИНТЕРФЕЙС ====================
local Tabs = {
    Farm = Window:AddTab('Farm'),
    Player = Window:AddTab('Player'),
    Autobuy = Window:AddTab('Autobuy'),
    Misc = Window:AddTab('Misc'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

-- ---- Farm ----
local farmGroup = Tabs.Farm:AddLeftGroupbox('Farm Controls')

farmGroup:AddToggle('FarmToggle', {
    Text = 'Auto Farm',
    Default = false,
    Tooltip = 'Включить/выключить фарм по точкам',
    Callback = function(val)
        autoFarmEnabled = val
        if autoFarmEnabled then
            if farmTask then coroutine.close(farmTask); farmTask = nil end
            farmTask = coroutine.create(farmLoop)
            coroutine.resume(farmTask)
        else
            if farmTask then coroutine.close(farmTask); farmTask = nil end
            workspace.Gravity = gravityNormal
        end
    end
})

farmGroup:AddDropdown('FarmMode', {
    Text = 'Режим фарма',
    Values = {'TP', 'Tween'},
    Default = 1,
    Tooltip = 'TP - телепорт, Tween - плавное перемещение',
    Callback = function(val)
        farmMode = val
    end
})

farmGroup:AddSlider('FarmDelay', {
    Text = 'Задержка между точками (с)',
    Default = 0.1,
    Min = 0,
    Max = 5,
    Rounding = 1,
    Suffix = 'с',
    Tooltip = 'Пауза после каждого телепорта'
})

farmGroup:AddToggle('AntiAfkToggle', {
    Text = 'Anti AFK',
    Default = false,
    Tooltip = 'Имитирует нажатие K каждые 10 с',
    Callback = function(val)
        antiAfkEnabled = val
    end
})

farmGroup:AddToggle('AutoClaimGoldToggle', {
    Text = 'Auto Claim Gold (River)',
    Default = false,
    Tooltip = 'Постоянно собирать золото (интервал настраивается)',
    Callback = function(val)
        autoClaimGoldEnabled = val
        if val then
            if claimGoldTask then coroutine.close(claimGoldTask); claimGoldTask = nil end
            claimGoldTask = coroutine.create(startClaimGoldLoop)
            coroutine.resume(claimGoldTask)
        else
            if claimGoldTask then coroutine.close(claimGoldTask); claimGoldTask = nil end
        end
    end
})

farmGroup:AddSlider('ClaimGoldInterval', {
    Text = 'Интервал сбора золота (с)',
    Default = 0.5,
    Min = 0.1,
    Max = 2,
    Rounding = 2,
    Suffix = 'с',
    Tooltip = 'Чем больше, тем меньше нагрузка (0.1 – максимум)',
    Callback = function(val)
        claimGoldInterval = val
    end
})

-- ---- Player ----
local playerGroup = Tabs.Player:AddLeftGroupbox('Player Settings')

playerGroup:AddSlider('Speed', {
    Text = 'Speed',
    Default = 16,
    Min = 0,
    Max = 200,
    Rounding = 1,
    Tooltip = 'Скорость персонажа',
    Callback = function(val)
        local c, h, r = getChar()
        if h then h.WalkSpeed = val end
    end
})

playerGroup:AddSlider('Jump', {
    Text = 'Jump Power',
    Default = 50,
    Min = 0,
    Max = 300,
    Rounding = 1,
    Tooltip = 'Сила обычного прыжка',
    Callback = function(val)
        local c, h, r = getChar()
        if h then h.JumpPower = val end
    end
})

playerGroup:AddSlider('Gravity', {
    Text = 'Gravity',
    Default = 196.2,
    Min = -100,
    Max = 500,
    Rounding = 1,
    Tooltip = 'Гравитация мира',
    Callback = function(val)
        workspace.Gravity = val
        gravityNormal = val
    end
})

playerGroup:AddToggle('FlyToggle', {
    Text = 'Fly Mode',
    Default = false,
    Tooltip = 'Включить полёт (WASD, Space/Q)',
    Callback = function(val)
        if val ~= flyEnabled then
            toggleFly()
        end
    end
})

playerGroup:AddToggle('InfinityJumpToggle', {
    Text = 'Infinity Jump',
    Default = false,
    Tooltip = 'Бесконечные прыжки при зажатом пробеле',
    Callback = function(val)
        infinityJumpEnabled = val
    end
})

playerGroup:AddToggle('NoclipToggle', {
    Text = 'Noclip',
    Default = false,
    Tooltip = 'Проходить сквозь стены',
    Callback = function(val)
        noclipEnabled = val
        updateNoclip()
    end
})

-- ==================== AUTOBUY ====================
local chestGroup = Tabs.Autobuy:AddLeftGroupbox('Auto Chest Buyer')
chestGroup:AddDropdown('AutoBuyChest', {
    Text = 'Тип сундука',
    Values = {'Common Chest', 'Uncommon Chest', 'Rare Chest', 'Epic Chest', 'Legendary Chest'},
    Default = 1,
})
chestGroup:AddInput('ChestAmount', {
    Text = 'Количество за раз',
    Default = '1',
    Placeholder = '1',
    Numeric = true,
})
chestGroup:AddButton({ Text = 'Купить сейчас', Func = function()
    local chest = Options.AutoBuyChest.Value
    local amount = tonumber(Options.ChestAmount.Value) or 1
    buyItem(chest, amount)
end })
chestGroup:AddToggle('AutoBuyChestEnabled', {
    Text = 'Автопокупка сундуков',
    Default = false,
    Callback = function(val)
        autoBuyChestEnabled = val
        if val then
            if autoBuyChestTask then coroutine.close(autoBuyChestTask); autoBuyChestTask = nil end
            autoBuyChestTask = coroutine.create(autoBuyChestLoop)
            coroutine.resume(autoBuyChestTask)
        else
            if autoBuyChestTask then coroutine.close(autoBuyChestTask); autoBuyChestTask = nil end
        end
    end
})
chestGroup:AddSlider('ChestInterval', {
    Text = 'Интервал (сек)',
    Default = 5,
    Min = 1,
    Max = 60,
    Rounding = 1,
    Suffix = 'с',
})

local itemGroup = Tabs.Autobuy:AddRightGroupbox('Item Buyer')
itemGroup:AddDropdown('AutoBuyItem', {
    Text = 'Предмет',
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
    Text = 'Количество за раз',
    Default = '1',
    Placeholder = '1',
    Numeric = true,
})
itemGroup:AddButton({ Text = 'Купить сейчас', Func = function()
    local item = Options.AutoBuyItem.Value
    local amount = tonumber(Options.ItemAmount.Value) or 1
    buyItem(item, amount)
end })
itemGroup:AddToggle('AutoBuyItemEnabled', {
    Text = 'Автопокупка предметов',
    Default = false,
    Callback = function(val)
        autoBuyItemEnabled = val
        if val then
            if autoBuyItemTask then coroutine.close(autoBuyItemTask); autoBuyItemTask = nil end
            autoBuyItemTask = coroutine.create(autoBuyItemLoop)
            coroutine.resume(autoBuyItemTask)
        else
            if autoBuyItemTask then coroutine.close(autoBuyItemTask); autoBuyItemTask = nil end
        end
    end
})
itemGroup:AddSlider('ItemInterval', {
    Text = 'Интервал (сек)',
    Default = 5,
    Min = 1,
    Max = 60,
    Rounding = 1,
    Suffix = 'с',
})

-- ---- Misc ----
local miscGroup = Tabs.Misc:AddLeftGroupbox('Misc')
miscGroup:AddLabel('Credits: kiten, tirvox', true)
miscGroup:AddLabel('Клавиша меню: End', true)

-- ---- UI Settings ----
local uiGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')
uiGroup:AddButton({ Text = 'Unload (сброс)', Func = function() Library:Unload() end })
uiGroup:AddLabel('Клавиша меню'):AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu keybind' })

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
ThemeManager:SetFolder('tirvoxhub')
SaveManager:SetFolder('tirvoxhub/configs')
SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])
SaveManager:LoadAutoloadConfig()

-- ==================== СБРОС ====================
local function resetSettings()
    autoFarmEnabled = false
    antiAfkEnabled = false
    flyEnabled = false
    infinityJumpEnabled = false
    noclipEnabled = false
    autoBuyChestEnabled = false
    autoBuyItemEnabled = false
    autoClaimGoldEnabled = false
    if farmTask then coroutine.close(farmTask); farmTask = nil end
    if autoBuyChestTask then coroutine.close(autoBuyChestTask); autoBuyChestTask = nil end
    if autoBuyItemTask then coroutine.close(autoBuyItemTask); autoBuyItemTask = nil end
    if claimGoldTask then coroutine.close(claimGoldTask); claimGoldTask = nil end
    if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity = nil end
    workspace.Gravity = gravityNormal
    local c = player.Character
    if c then
        for _, part in ipairs(c:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
        local h = c:FindFirstChild("Humanoid")
        if h then
            h.WalkSpeed = 16
            h.JumpPower = 50
        end
    end
end

Library:OnUnload(function()
    resetSettings()
end)
