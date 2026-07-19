-- tirvoxhub – фикс: гравитация отключается на всё время фарма, чтобы не падать при любой задержке.
-- Исправлено: в tpMode и tweenMode убрано переключение гравитации, она управляется из farmLoop.
-- Добавлена защита от падения в бездну (телепорт на первую точку при Y < -500).

-- ==================== ЗАГРУЗКА БИБЛИОТЕК ====================
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

-- ==================== ОСНОВНАЯ ЛОГИКА (из Ultimate Farm v7.6) ====================
local player = game.Players.LocalPlayer
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Конфигурация
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
local userPoints = {}

-- Состояния
local autoFarmEnabled = false
local antiAfkEnabled = false
local flyEnabled = false
local farmTask = nil
local currentCharacter = player.Character
local humanoid = currentCharacter and currentCharacter:FindFirstChild("Humanoid")
local rootPart = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")

-- Infinity Jump & Noclip
local infinityJumpEnabled = false
local noclipEnabled = false
local jumpKeyPressed = false
local jumpTimer = 0
local JUMP_INTERVAL = 0.2

-- === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
local function getChar()
    local c = player.Character
    if not c then return nil, nil, nil end
    local r = c:FindFirstChild("HumanoidRootPart")
    local h = c:FindFirstChild("Humanoid")
    return c, h, r
end

-- === GOD MODE (разрешено плавание) ===
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
        h:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
        h:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
        h:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        h:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
    end
end

-- === NOCLIP ===
local function updateNoclip()
    local c = player.Character
    if not c then return end
    for _, part in ipairs(c:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = not noclipEnabled
        end
    end
end

-- === INFINITY JUMP ===
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

-- === ФАРМ (с отключением гравитации на всё время) ===
-- В tpMode и tweenMode убираем переключение гравитации – она управляется из farmLoop
local function tpMode(cf)
    local c, h, r = getChar()
    if not r then return end
    -- гравитация уже отключена в farmLoop, не трогаем
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
    -- гравитацию не восстанавливаем
end

local function tweenMode(cf)
    local c, h, r = getChar()
    if not r then return end
    -- гравитация уже отключена
    local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local goal = {CFrame = cf}
    local tween = TweenService:Create(r, tweenInfo, goal)
    tween:Play()
    tween.Completed:Wait()
    task.wait(1)
    -- гравитацию не восстанавливаем
end

local function farmLoop()
    -- Отключаем гравитацию на всё время фарма
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
    -- Восстанавливаем гравитацию при выходе из цикла
    workspace.Gravity = gravityNormal
end

-- === СОХРАНЕНИЕ ТОЧЕК ===
local function savePoint(name, cf)
    userPoints[name] = cf
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

-- === АНТИ-AFK ===
task.spawn(function()
    while true do
        task.wait(10)
        if antiAfkEnabled then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.K, false, game)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.K, false, game)
        end
    end
end)

-- === ОБРАБОТКА РЕСПАВНА ===
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
    local spd = Options.Speed and Options.Speed.Value or 16
    local jmp = Options.Jump and Options.Jump.Value or 50
    if humanoid then
        humanoid.WalkSpeed = spd
        humanoid.JumpPower = jmp
    end
    updateNoclip()
end)

-- === HEARTBEAT ===
local lastTime = tick()
RunService.Heartbeat:Connect(function()
    local now = tick()
    local dt = now - lastTime
    lastTime = now

    setGodMode(true)
    handleInfinityJump(dt)

    -- Защита от падения в бездну (если вдруг гравитация включилась)
    local c, h, r = getChar()
    if r and r.Position.Y < -500 then
        r.CFrame = destinations[1]
    end
end)

-- ==================== ИНТЕРФЕЙС ====================
local Tabs = {
    Farm = Window:AddTab('Farm'),
    Player = Window:AddTab('Player'),
    Points = Window:AddTab('Points'),
    Misc = Window:AddTab('Misc'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

local defaultValues = {}

-- ---- Farm ----
local farmGroup = Tabs.Farm:AddLeftGroupbox('Farm Controls')

farmGroup:AddToggle('FarmToggle', {
    Text = 'Auto Farm',
    Default = false,
    Tooltip = 'Включить/выключить фарм по точкам',
    Callback = function(val)
        autoFarmEnabled = val
        if autoFarmEnabled then
            if farmTask then coroutine.close(farmTask) end
            farmTask = coroutine.create(farmLoop)
            coroutine.resume(farmTask)
        else
            if farmTask then coroutine.close(farmTask); farmTask = nil end
            workspace.Gravity = gravityNormal
        end
    end
})
defaultValues['FarmToggle'] = false

farmGroup:AddDropdown('FarmMode', {
    Text = 'Режим фарма',
    Values = {'TP', 'Tween'},
    Default = 1,
    Tooltip = 'TP - телепорт, Tween - плавное перемещение',
    Callback = function(val)
        farmMode = val
    end
})
defaultValues['FarmMode'] = 1

farmGroup:AddSlider('FarmDelay', {
    Text = 'Задержка между точками (с)',
    Default = 0.1,
    Min = 0,
    Max = 5,
    Rounding = 1,
    Suffix = 'с',
    Tooltip = 'Пауза после каждого телепорта (теперь можно ставить любую, падения нет)'
})
defaultValues['FarmDelay'] = 0.1

farmGroup:AddToggle('AntiAfkToggle', {
    Text = 'Anti AFK',
    Default = false,
    Tooltip = 'Имитирует нажатие K каждые 10 с',
    Callback = function(val)
        antiAfkEnabled = val
    end
})
defaultValues['AntiAfkToggle'] = false

-- ---- Player ----
local playerGroup = Tabs.Player:AddLeftGroupbox('Player Settings')

playerGroup:AddSlider('Speed', {
    Text = 'Speed',
    Default = 16,
    Min = 0,
    Max = 200,
    Rounding = 1,
    Suffix = '',
    Tooltip = 'Скорость персонажа',
    Callback = function(val)
        local c, h, r = getChar()
        if h then h.WalkSpeed = val end
    end
})
defaultValues['Speed'] = 16

playerGroup:AddSlider('Jump', {
    Text = 'Jump Power',
    Default = 50,
    Min = 0,
    Max = 300,
    Rounding = 1,
    Suffix = '',
    Tooltip = 'Сила обычного прыжка',
    Callback = function(val)
        local c, h, r = getChar()
        if h then h.JumpPower = val end
    end
})
defaultValues['Jump'] = 50

playerGroup:AddSlider('Gravity', {
    Text = 'Gravity',
    Default = 196.2,
    Min = -100,
    Max = 500,
    Rounding = 1,
    Suffix = '',
    Tooltip = 'Гравитация мира (применяется сразу, но фарм её отключает)',
    Callback = function(val)
        workspace.Gravity = val
        gravityNormal = val
    end
})
defaultValues['Gravity'] = 196.2

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
defaultValues['FlyToggle'] = false

playerGroup:AddToggle('InfinityJumpToggle', {
    Text = 'Infinity Jump',
    Default = false,
    Tooltip = 'Бесконечные прыжки при зажатом пробеле (обычная сила)',
    Callback = function(val)
        infinityJumpEnabled = val
    end
})
defaultValues['InfinityJumpToggle'] = false

playerGroup:AddToggle('NoclipToggle', {
    Text = 'Noclip',
    Default = false,
    Tooltip = 'Проходить сквозь стены',
    Callback = function(val)
        noclipEnabled = val
        updateNoclip()
    end
})
defaultValues['NoclipToggle'] = false

-- ---- Points ----
local pointsGroup = Tabs.Points:AddLeftGroupbox('Save Points')

pointsGroup:AddInput('PointName', {
    Text = 'Название точки',
    Default = 'point1',
    Placeholder = 'Введите имя...',
    Tooltip = 'Имя сохраняемой позиции'
})
defaultValues['PointName'] = 'point1'

pointsGroup:AddButton({
    Text = 'Сохранить текущую позицию',
    Func = function()
        local c, h, r = getChar()
        if not r then return end
        local name = Options.PointName.Value
        if name == '' then name = 'point' .. tostring(#userPoints+1) end
        savePoint(name, r.CFrame)
        updatePointList()
    end,
    Tooltip = 'Сохраняет позицию с указанным именем'
})

local pointLabel = pointsGroup:AddLabel('Сохранённые точки: нет')

function updatePointList()
    local names = {}
    for k,_ in pairs(userPoints) do table.insert(names, k) end
    if #names == 0 then
        pointLabel:SetText('Сохранённые точки: нет')
    else
        pointLabel:SetText('Сохранённые точки: ' .. table.concat(names, ', '))
    end
end

pointsGroup:AddButton({
    Text = 'Телепорт к первой точке',
    Func = function()
        local names = {}
        for k,_ in pairs(userPoints) do table.insert(names, k) end
        if #names > 0 then
            local first = names[1]
            local cf = userPoints[first]
            local c, h, r = getChar()
            if r then r.CFrame = cf end
        end
    end,
    Tooltip = 'Телепортирует к первой сохранённой точке'
})

-- ---- Misc ----
local miscGroup = Tabs.Misc:AddLeftGroupbox('Miscellaneous')

miscGroup:AddLabel('Credits: kiten, tirvox', true)
miscGroup:AddLabel('Меню скрывается/показывается по End (настройка в UI Settings)', true)

miscGroup:AddButton({
    Text = 'Закрыть скрипт (сброс настроек)',
    Func = function()
        Library:Unload()
    end,
    Tooltip = 'Полная выгрузка с возвратом всех настроек по умолчанию',
    DoubleClick = false
})

-- ---- UI Settings ----
local uiGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')

uiGroup:AddButton({
    Text = 'Unload (сброс)',
    Func = function()
        Library:Unload()
    end
})

uiGroup:AddLabel('Клавиша меню'):AddKeyPicker('MenuKeybind', {
    Default = 'End',
    NoUI = true,
    Text = 'Menu keybind'
})

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
    for key, defaultValue in pairs(defaultValues) do
        local obj = Toggles[key] or Options[key]
        if obj and obj.SetValue then
            obj:SetValue(defaultValue)
        end
    end
    autoFarmEnabled = false
    antiAfkEnabled = false
    flyEnabled = false
    infinityJumpEnabled = false
    noclipEnabled = false
    if farmTask then coroutine.close(farmTask); farmTask = nil end
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
