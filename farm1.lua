-- [ ЗАГРУЗЧИК САТОШИ v1.3 - ДВА СКРИПТА ] --

local secret_key = "zhjkbn"

-- Сюда вставляй зашифрованные строки
local encrypted_default = "35.6.8.e.b.z.l.y.c.f.g.2a.16.n.m.u.2x.1k.x.1c.1b.1u.u.1e.2z.2x.t.1n.1f.1o.14.36.2u.2u.1f.1f.1e.30.1g.16.1r.1c.1m.1i.24.1y.1i.24.22.1l.1j.2b.1o.1i.1x.3i.1u.1q.22.3h.23.1r.2f.2l.26.2g.48.26.28.27.23.2q.4e.27.2e.26.2h.3z.2z.2h.2x.2g.2s.2p.2l.2f.35.3b.4l.2k.2y.2t.4q.4g.4q.4m.50.5g" 
local encrypted_linoria = "loadstring(game:HttpGet('https://raw.githubusercontent.com/tirvox/babft/main/farmlinoria.lua'))()"

local function decrypt(data, key)
    local decrypted = ""
    local i = 1
    for part in string.gmatch(data, "[^%.]+") do
        local val = tonumber(part, 36)
        local xor_val = val - i
        local key_byte = string.byte(key, (i - 1) % #key + 1)
        local original_byte = bit32.bxor(xor_val, key_byte)
        if original_byte < 0 then original_byte = 0 end
        if original_byte > 255 then original_byte = original_byte % 256 end
        decrypted = decrypted .. string.char(original_byte)
        i = i + 1
    end
    return decrypted
end

local function runScript(encrypted_str)
    local success, result = pcall(decrypt, encrypted_str, secret_key)
    if success then
        local func, err = loadstring(result)
        if func then func() else warn("Ошибка загрузки: " .. tostring(err)) end
    else
        warn("Ошибка расшифровки: " .. tostring(result))
    end
end

-- GUI выбора
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 200, 0, 150)
MainFrame.Position = UDim2.new(0.5, -100, 0.5, -75)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)

local function createButton(text, pos, scriptData)
    local btn = Instance.new("TextButton", MainFrame)
    btn.Size = UDim2.new(0, 180, 0, 40)
    btn.Position = pos
    btn.Text = text
    btn.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
        runScript(scriptData)
    end)
end

createButton("Загрузить Default", UDim2.new(0, 10, 0, 10), encrypted_default)
createButton("Загрузить Linoria", UDim2.new(0, 10, 0, 60), encrypted_linoria)
