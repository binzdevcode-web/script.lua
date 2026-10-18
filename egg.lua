-- ═══════════════════════════════════════════════════
-- BREAK & STEAL AN EGG — STEALTH AUTO-FARM (FIX 267)
-- Chạy trên: Delta, Fluxus, Arceus X, Krnl, Wave, Solara
-- Anti-Kick: Tween di chuyển, Clear Velocity, Random Delay
-- ═══════════════════════════════════════════════════

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local VirtualUser        = game:GetService("VirtualUser")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local LP                 = Players.LocalPlayer

-- ═══════════════════════════════════════════════════
-- CONFIG (Đã hạ mức để tránh Anti-Cheat 267)
-- ═══════════════════════════════════════════════════
local CONFIG = {
    WALK_SPEED      = 55,     -- Max khuyên dùng: 55-60. Lên 100+ dễ bị 267
    JUMP_POWER      = 65,     -- Mức an toàn
    TP_DISTANCE_MAX = 250,    -- Bay tối đa 250 studs/lần, tránh flag
    LOOP_DELAY      = 1.2,    -- Nghỉ 1.2s giữa các lần nhặt để tránh spam
    RANDOM_DELAY    = 0.4,    -- Delay ngẫu nhiên thêm (chống pattern detect)
    SAFE_ZONE       = nil,
    USE_FIRE_TOUCH  = false,  -- Đặt false vì đôi khi firetouch cũng bị flag
}

local State = {
    AutoFarm  = false,
    AntiAFK   = true,
    SpeedHack = false,
    Collected = 0,
    Failed    = 0,
    Panic     = false,
}

-- ═══════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════
local function getCharacter()
    local char = LP.Character
    if not char then return nil end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return nil end
    return char, hum, root
end

local function setSpeed(s)
    local _, hum = getCharacter()
    if hum then 
        pcall(function()
            hum.WalkSpeed = s
        end)
    end
end

local function setJump(j)
    local _, hum = getCharacter()
    if hum then
        pcall(function() 
            hum.UseJumpPower = true 
            hum.JumpPower = j 
        end)
    end
end

-- HÀM BAY MƯỢT (Không dùng CFrame Set trực tiếp nữa)
local function stealthMove(targetPos)
    if State.Panic then return false end
    local _, hum, root = getCharacter()
    if not hum or not root then return false end
    
    local currentPos = root.Position
    local dist = (currentPos - targetPos).Magnitude
    
    -- Nếu khoảng cách quá xa, chia nhỏ để bay từng khúc
    if dist > CONFIG.TP_DISTANCE_MAX then
        local direction = (targetPos - currentPos).Unit
        targetPos = currentPos + (direction * CONFIG.TP_DISTANCE_MAX)
        dist = CONFIG.TP_DISTANCE_MAX
    end

    -- Xoá vận tốc cũ (Anti-cheat không thấy quán tính lạ)
    pcall(function() 
        root.Velocity = Vector3.zero 
        root.AssemblyLinearVelocity = Vector3.zero
    end)

    -- Dùng Tween để bay mượt như đang chạy bình thường
    local duration = math.clamp(dist / 160, 0.15, 0.8) -- Bay max 0.8s, min 0.15s
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    
    local success, err = pcall(function()
        local tween = TweenService:Create(root, tweenInfo, {CFrame = CFrame.new(targetPos)})
        tween:Play()
        tween.Completed:Wait()
    end)
    
    if not success then return false end
    
    -- Reset lần nữa cho chắc
    pcall(function() 
        root.Velocity = Vector3.zero 
        root.AssemblyLinearVelocity = Vector3.zero
    end)
    
    return true
end

local function isEggObject(obj)
    if not obj then return false end
    local name = string.lower(obj.Name)
    return string.find(name, "egg")   ~= nil
        or string.find(name, "trung") ~= nil
end

local function findEggs()
    local eggs = {}
    local function scan(obj)
        if not obj or obj == LP.Character then return end
        if isEggObject(obj) then
            local part
            if obj:IsA("BasePart") then part = obj
            elseif obj:IsA("Model") then part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            else part = obj:FindFirstChildWhichIsA("BasePart") end
            if part and part.Parent then table.insert(eggs, part) end
            return
        end
        pcall(function()
            for _, child in ipairs(obj:GetChildren()) do scan(child) end
        end)
    end
    scan(workspace)
    return eggs
end

local function pickBestEgg()
    local eggs = findEggs()
    if #eggs == 0 then return nil end
    local _, _, root = getCharacter()
    if not root then return eggs[1] end

    local best, bestScore = nil, -math.huge
    for _, egg in ipairs(eggs) do
        local dist = (root.Position - egg.Position).Magnitude
        local size = math.max(egg.Size.X, egg.Size.Y, egg.Size.Z)
        local rarity = 1
        pcall(function()
            if egg:GetAttribute("Rarity") then rarity = tonumber(egg:GetAttribute("Rarity")) or 1 end
        end)
        -- Ưu tiên trứng gần trước để giảm rủi ro (Bay xa dễ bị detect)
        local score = (size * 5 * rarity) - (dist * 2)
        if score > bestScore then
            bestScore = score
            best = egg
        end
    end
    return best
end

-- ═══════════════════════════════════════════════════
-- ANTI-AFK (Bypass loại này an toàn, không bị 267)
-- ═══════════════════════════════════════════════════
LP.Idled:Connect(function()
    if not State.AntiAFK then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- ═══════════════════════════════════════════════════
-- AUTO FARM LOOP (Stealth Mode)
-- ═══════════════════════════════════════════════════
task.spawn(function()
    task.wait(2)
    local _, _, root = getCharacter()
    if root and not CONFIG.SAFE_ZONE then
        CONFIG.SAFE_ZONE = root.CFrame
    end

    while task.wait(CONFIG.LOOP_DELAY) do
        if not State.AutoFarm or State.Panic then continue end
        if not getCharacter() then continue end

        local egg = pickBestEgg()
        if not egg then
            State.Failed = State.Failed + 1
            if updateGUI then updateGUI() end
            continue
        end

        -- Thêm delay ngẫu nhiên để tránh bị bắt pattern
        task.wait(math.random() * CONFIG.RANDOM_DELAY)

        -- 1. Bay tới trứng (bằng Tween)
        stealthMove(egg.Position + Vector3.new(0, 3, 0))
        task.wait(0.4)

        -- 2. Nhặt trứng (chỉ dùng touch nếu bật)
        if CONFIG.USE_FIRE_TOUCH and firetouchinterest then
            pcall(function()
                local _, _, root2 = getCharacter()
                if root2 then
                    firetouchinterest(root2, egg, 0)
                    task.wait(0.1)
                    firetouchinterest(root2, egg, 1)
                end
            end)
        else
            -- Đứng đè lên trứng tự nhặt
            task.wait(0.3)
        end

        -- 3. Bay về safe zone
        if CONFIG.SAFE_ZONE then
            stealthMove(CONFIG.SAFE_ZONE.Position)
        end

        State.Collected = State.Collected + 1
        if updateGUI then updateGUI() end
    end
end)

-- Reset Speed nếu bị kéo về
task.spawn(function()
    while task.wait(1) do
        if State.SpeedHack and not State.Panic then
            local _, hum = getCharacter()
            if hum and hum.WalkSpeed ~= CONFIG.WALK_SPEED then
                pcall(function() hum.WalkSpeed = CONFIG.WALK_SPEED end)
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════════════════
local CoreGui = pcall(function() return game:GetService("CoreGui") end) and game:GetService("CoreGui") or game.Players.LocalPlayer:WaitForChild("PlayerGui")
if CoreGui:FindFirstChild("EggFarmGUI") then CoreGui.EggFarmGUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "EggFarmGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui

local MiniBtn = Instance.new("TextButton")
MiniBtn.Size = UDim2.new(0, 64, 0, 64)
MiniBtn.Position = UDim2.new(0, 20, 0.5, -32)
MiniBtn.BackgroundColor3 = Color3.fromRGB(201, 71, 104)
MiniBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MiniBtn.Text = "🥚"
MiniBtn.TextScaled = true
MiniBtn.Font = Enum.Font.GothamBold
MiniBtn.BorderSizePixel = 0
MiniBtn.Parent = ScreenGui
Instance.new("UICorner", MiniBtn).CornerRadius = UDim.new(1, 0)

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 300, 0, 430)
Main.Position = UDim2.new(0.5, -150, 0.5, -215)
Main.BackgroundColor3 = Color3.fromRGB(28, 18, 26)
Main.BorderSizePixel = 0
Main.Visible = false
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)

local Title = Instance.new("Frame")
Title.Size = UDim2.new(1, 0, 0, 44)
Title.BackgroundColor3 = Color3.fromRGB(60, 30, 50)
Title.BorderSizePixel = 0
Title.Parent = Main
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 14)

local TitleFix = Instance.new("Frame")
TitleFix.Size = UDim2.new(1, 0, 0, 22)
TitleFix.Position = UDim2.new(0, 0, 0, 22)
TitleFix.BackgroundColor3 = Color3.fromRGB(60, 30, 50)
TitleFix.BorderSizePixel = 0
TitleFix.Parent = Title

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -50, 1, 0)
TitleLabel.Position = UDim2.new(0, 16, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🥚 STEALTH FARMER"
TitleLabel.TextColor3 = Color3.fromRGB(255, 220, 230)
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 15
TitleLabel.Parent = Title

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -40, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 80)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = Title
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(1, 0)

local List = Instance.new("Frame")
List.Size = UDim2.new(1, -24, 1, -60)
List.Position = UDim2.new(0, 12, 0, 56)
List.BackgroundTransparency = 1
List.Parent = Main

local function makeBtn(y, h)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, h or 48)
    b.Position = UDim2.new(0, 0, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(50, 35, 50)
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 14
    b.BorderSizePixel = 0
    b.Parent = List
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    return b
end

local SpeedBtn = makeBtn(0)
local FarmBtn  = makeBtn(58)
local AFKBtn   = makeBtn(116)
local SafeBtn  = makeBtn(174)
local PanicBtn = makeBtn(232, 40) -- Nút PANIC màu đỏ

PanicBtn.BackgroundColor3 = Color3.fromRGB(140, 30, 40)
PanicBtn.Text = "🛑 PANIC STOP (Ẩn & Dừng)"
PanicBtn.Font = Enum.Font.GothamBold

local Stats = Instance.new("TextLabel")
Stats.Size = UDim2.new(1, 0, 0, 46)
Stats.Position = UDim2.new(0, 0, 0, 284)
Stats.BackgroundColor3 = Color3.fromRGB(40, 25, 40)
Stats.TextColor3 = Color3.fromRGB(220, 200, 220)
Stats.Font = Enum.Font.Gotham
Stats.TextSize = 13
Stats.BorderSizePixel = 0
Stats.TextXAlignment = Enum.TextXAlignment.Left
Stats.Parent = List
Instance.new("UICorner", Stats).CornerRadius = UDim.new(0, 10)

local LogLbl = Instance.new("TextLabel")
LogLbl.Size = UDim2.new(1, 0, 0, 60)
LogLbl.Position = UDim2.new(0, 0, 0, 338)
LogLbl.BackgroundColor3 = Color3.fromRGB(25, 15, 25)
LogLbl.TextColor3 = Color3.fromRGB(160, 150, 170)
LogLbl.Font = Enum.Font.Code
LogLbl.TextSize = 11
LogLbl.BorderSizePixel = 0
LogLbl.TextXAlignment = Enum.TextXAlignment.Left
LogLbl.TextYAlignment = Enum.TextYAlignment.Top
LogLbl.TextWrapped = true
LogLbl.Parent = List
Instance.new("UICorner", LogLbl).CornerRadius = UDim.new(0, 10)

local function log(msg) LogLbl.Text = "  > " .. msg end
function updateGUI() Stats.Text = "  🥚 Đã lấy: " .. State.Collected .. "  •  Lỗi: " .. State.Failed end

local function setBtnState(btn, label, on)
    btn.Text = label .. (on and "   [ON]" or "   [OFF]")
    btn.BackgroundColor3 = on and Color3.fromRGB(80, 150, 100) or Color3.fromRGB(50, 35, 50)
end

setBtnState(SpeedBtn, "⚡ Speed (An Toàn)", false)
setBtnState(FarmBtn,  "🌾 Auto Farm (Stealth)", false)
setBtnState(AFKBtn,   "💤 Anti AFK",   true)
SafeBtn.Text = "📍 Đặt vùng an toàn"
SafeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)

SpeedBtn.MouseButton1Click:Connect(function()
    State.SpeedHack = not State.SpeedHack
    setBtnState(SpeedBtn, "⚡ Speed (An Toàn)", State.SpeedHack)
    if State.SpeedHack then
        setSpeed(CONFIG.WALK_SPEED)
        setJump(CONFIG.JUMP_POWER)
        log("speed 55 (an toàn)")
    else
        setSpeed(16)
        setJump(50)
        log("speed tắt")
    end
end)

FarmBtn.MouseButton1Click:Connect(function()
    State.AutoFarm = not State.AutoFarm
    setBtnState(FarmBtn, "🌾 Auto Farm (Stealth)", State.AutoFarm)
    log(State.AutoFarm and "bắt đầu farm (bay mượt)..." or "dừng farm")
end)

AFKBtn.MouseButton1Click:Connect(function()
    State.AntiAFK = not State.AntiAFK
    setBtnState(AFKBtn, "💤 Anti AFK", State.AntiAFK)
    log(State.AntiAFK and "anti-afk bật" or "anti-afk tắt")
end)

SafeBtn.MouseButton1Click:Connect(function()
    local _, _, root = getCharacter()
    if root then
        CONFIG.SAFE_ZONE = root.CFrame
        SafeBtn.Text = "📍 Đã đặt vùng an toàn ✓"
        log("đã đặt safe zone")
        task.delay(2, function() SafeBtn.Text = "📍 Đặt vùng an toàn" end)
    end
end)

PanicBtn.MouseButton1Click:Connect(function()
    State.Panic = true
    State.AutoFarm = false
    State.SpeedHack = false
    setSpeed(16)
    setJump(50)
    setBtnState(FarmBtn, "🌾 Auto Farm (Stealth)", false)
    setBtnState(SpeedBtn, "⚡ Speed (An Toàn)", false)
    log("PANIC: Đã dừng & reset speed")
    Main.Visible = false
    MiniBtn.Visible = true
    task.delay(10, function()
        State.Panic = false 
        log("sẵn sàng hoạt động lại")
    end)
end)

MiniBtn.MouseButton1Click:Connect(function()
    Main.Visible = true
    MiniBtn.Visible = false
end)

CloseBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
    MiniBtn.Visible = true
end)

-- Drag GUI
local dragging, dragStart, startPos
Title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

log("script Stealth đã tải ✓")
updateGUI()
