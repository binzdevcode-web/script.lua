-- ═══════════════════════════════════════════════════
-- BREAK & STEAL AN EGG — AUTO-FARM SCRIPT
-- Chạy được trên: Delta, Fluxus, Arceus X (Mobile)
--                 Krnl, Synapse X, Fluxus PC
-- Features: Speed Hack, Auto Farm, Auto Tele, Anti-AFK
-- ═══════════════════════════════════════════════════

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer

-- ═══════════════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════════════
local CONFIG = {
    WALK_SPEED      = 150,
    JUMP_POWER      = 120,
    TP_OFFSET       = Vector3.new(0, 4, 0),
    LOOP_DELAY      = 0.35,
    TOUCH_DURATION  = 0.15,
    SAFE_ZONE       = nil,   -- sẽ tự lấy vị trí hiện tại lúc bật script
    USE_FIRE_TOUCH  = true,  -- bật nếu game cần "touch" để nhặt trứng
}

-- ═══════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════
local State = {
    AutoFarm  = false,
    AntiAFK   = true,
    SpeedHack = false,
    Collected = 0,
    Failed    = 0,
    LastEgg   = nil,
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
    if hum then hum.WalkSpeed = s end
end

local function setJump(j)
    local _, hum = getCharacter()
    if hum then
        pcall(function() hum.UseJumpPower = true end)
        pcall(function() hum.JumpPower = j end)
    end
end

local function teleportTo(cf)
    local _, _, root = getCharacter()
    if not root then return false end
    pcall(function() root.CFrame = cf end)
    return true
end

local function isEggObject(obj)
    if not obj then return false end
    local name = string.lower(obj.Name)
    return string.find(name, "egg")   ~= nil
        or string.find(name, "trung") ~= nil
        or string.find(name, "trứng") ~= nil
end

local function isSafeObject(obj)
    local name = string.lower(obj.Name)
    return string.find(name, "safe")  ~= nil
        or string.find(name, "base")  ~= nil
        or string.find(name, "spawn") ~= nil
        or string.find(name, "home")  ~= nil
end

local function findEggs()
    local eggs = {}
    local function scan(obj)
        if not obj or obj == LP.Character then return end
        if isEggObject(obj) then
            local part
            if obj:IsA("BasePart") then
                part = obj
            elseif obj:IsA("Model") then
                part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            else
                part = obj:FindFirstChildWhichIsA("BasePart")
            end
            if part and part.Parent then
                table.insert(eggs, part)
            end
            return
        end
        pcall(function()
            for _, child in ipairs(obj:GetChildren()) do
                scan(child)
            end
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
            if egg:GetAttribute("Rarity") then
                rarity = tonumber(egg:GetAttribute("Rarity")) or 1
            elseif egg.Parent and egg.Parent:GetAttribute("Rarity") then
                rarity = tonumber(egg.Parent:GetAttribute("Rarity")) or 1
            end
        end)
        -- score: ưu tiên to + hiếm, trừ khoảng cách
        local score = (size * 8 * rarity) - (dist * 0.4)
        if score > bestScore then
            bestScore = score
            best = egg
        end
    end
    return best
end

local function fireTouch(part, st)
    if not firetouchinterest then return false end
    local _, _, root = getCharacter()
    if not root then return false end
    pcall(function() firetouchinterest(root, part, st) end)
    return true
end

local function autoDetectSafeZone()
    local _, _, root = getCharacter()
    if not root then return nil end
    local bestPos, bestDist = nil, math.huge
    local function scan(obj)
        if isSafeObject(obj) then
            local part = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
            if part then
                local d = (root.Position - part.Position).Magnitude
                if d < bestDist then
                    bestDist = d
                    bestPos  = part.Position
                end
            end
        end
        pcall(function()
            for _, c in ipairs(obj:GetChildren()) do scan(c) end
        end)
    end
    scan(workspace)
    return bestPos
end

-- ═══════════════════════════════════════════════════
-- ANTI-AFK
-- ═══════════════════════════════════════════════════
LP.Idled:Connect(function()
    if not State.AntiAFK then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- fallback: gửi phím W định kỳ
task.spawn(function()
    while task.wait(30) do
        if not State.AntiAFK then continue end
        pcall(function()
            VirtualInputManager:SendKeyEvent(true,  "W", false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, "W", false, game)
        end)
    end
end)

-- ═══════════════════════════════════════════════════
-- CHARACTER RESPAWN → re-apply speed
-- ═══════════════════════════════════════════════════
LP.CharacterAdded:Connect(function()
    task.wait(1.5)
    if State.SpeedHack then
        setSpeed(CONFIG.WALK_SPEED)
        setJump(CONFIG.JUMP_POWER)
    end
    if not CONFIG.SAFE_ZONE then
        local _, _, root = getCharacter()
        if root then CONFIG.SAFE_ZONE = root.CFrame end
    end
end)

-- giữ speed không bị game reset
task.spawn(function()
    while task.wait(1) do
        if State.SpeedHack then
            local _, hum = getCharacter()
            if hum and hum.WalkSpeed ~= CONFIG.WALK_SPEED then
                hum.WalkSpeed = CONFIG.WALK_SPEED
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════
-- AUTO FARM LOOP
-- ═══════════════════════════════════════════════════
task.spawn(function()
    -- lưu vị trí ban đầu làm safe zone
    task.wait(2)
    local _, _, root = getCharacter()
    if root and not CONFIG.SAFE_ZONE then
        CONFIG.SAFE_ZONE = root.CFrame
    end

    while task.wait(CONFIG.LOOP_DELAY) do
        if not State.AutoFarm then continue end
        if not getCharacter() then continue end

        local egg = pickBestEgg()
        if not egg then
            State.Failed = State.Failed + 1
            continue
        end

        State.LastEgg = egg

        -- 1. Teleport tới trứng
        teleportTo(CFrame.new(egg.Position + CONFIG.TP_OFFSET))
        task.wait(0.12)

        -- 2. Touch để nhặt
        if CONFIG.USE_FIRE_TOUCH and firetouchinterest then
            fireTouch(egg, 0)
            task.wait(CONFIG.TOUCH_DURATION)
            fireTouch(egg, 1)
        end
        task.wait(0.15)

        -- 3. Teleport về safe zone
        if CONFIG.SAFE_ZONE then
            teleportTo(CONFIG.SAFE_ZONE)
            task.wait(0.15)
        end

        State.Collected = State.Collected + 1
        if updateGUI then updateGUI() end
    end
end)

-- ═══════════════════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════════════════
local CoreGui = pcall(function() return game:GetService("CoreGui") end) and game:GetService("CoreGui") or game.Players.LocalPlayer:WaitForChild("PlayerGui")

if CoreGui:FindFirstChild("EggFarmGUI") then
    CoreGui.EggFarmGUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "EggFarmGUI"
ScreenGui.ResetOnSpawn    = false
ScreenGui.IgnoreGuiInset  = true
ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent          = CoreGui

-- Nút nhỏ mở panel (mobile-friendly)
local MiniBtn = Instance.new("TextButton")
MiniBtn.Name              = "MiniBtn"
MiniBtn.Size              = UDim2.new(0, 64, 0, 64)
MiniBtn.Position          = UDim2.new(0, 20, 0.5, -32)
MiniBtn.BackgroundColor3  = Color3.fromRGB(201, 71, 104)
MiniBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
MiniBtn.Text              = "🥚"
MiniBtn.TextScaled        = true
MiniBtn.Font              = Enum.Font.GothamBold
MiniBtn.BorderSizePixel   = 0
MiniBtn.AutoButtonColor   = false
MiniBtn.Parent            = ScreenGui
Instance.new("UICorner", MiniBtn).CornerRadius = UDim.new(1, 0)

local miniStroke = Instance.new("UIStroke", MiniBtn)
miniStroke.Color = Color3.fromRGB(255, 200, 220)
miniStroke.Thickness = 2
miniStroke.Transparency = 0.4

-- Panel chính
local Main = Instance.new("Frame")
Main.Name              = "Main"
Main.Size              = UDim2.new(0, 300, 0, 400)
Main.Position          = UDim2.new(0.5, -150, 0.5, -200)
Main.BackgroundColor3  = Color3.fromRGB(28, 18, 26)
Main.BorderSizePixel   = 0
Main.Visible           = false
Main.Parent            = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)

local mainStroke = Instance.new("UIStroke", Main)
mainStroke.Color = Color3.fromRGB(201, 71, 104)
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.5

-- Title bar
local Title = Instance.new("Frame")
Title.Size             = UDim2.new(1, 0, 0, 44)
Title.BackgroundColor3 = Color3.fromRGB(60, 30, 50)
Title.BorderSizePixel  = 0
Title.Parent           = Main
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 14)

local TitleFix = Instance.new("Frame")
TitleFix.Size              = UDim2.new(1, 0, 0, 22)
TitleFix.Position          = UDim2.new(0, 0, 0, 22)
TitleFix.BackgroundColor3  = Color3.fromRGB(60, 30, 50)
TitleFix.BorderSizePixel   = 0
TitleFix.Parent            = Title

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size                = UDim2.new(1, -50, 1, 0)
TitleLabel.Position            = UDim2.new(0, 16, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text                = "🥚  EGG FARMER"
TitleLabel.TextColor3          = Color3.fromRGB(255, 220, 230)
TitleLabel.TextXAlignment      = Enum.TextXAlignment.Left
TitleLabel.Font                = Enum.Font.GothamBold
TitleLabel.TextSize            = 15
TitleLabel.Parent              = Title

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size              = UDim2.new(0, 32, 0, 32)
CloseBtn.Position          = UDim2.new(1, -40, 0, 6)
CloseBtn.BackgroundColor3  = Color3.fromRGB(200, 60, 80)
CloseBtn.Text              = "✕"
CloseBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
CloseBtn.Font              = Enum.Font.GothamBold
CloseBtn.TextSize          = 16
CloseBtn.BorderSizePixel   = 0
CloseBtn.AutoButtonColor   = false
CloseBtn.Parent            = Title
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(1, 0)

-- Nội dung
local List = Instance.new("Frame")
List.Size                = UDim2.new(1, -24, 1, -60)
List.Position            = UDim2.new(0, 12, 0, 56)
List.BackgroundTransparency = 1
List.Parent              = Main

local function makeBtn(y, h)
    local b = Instance.new("TextButton")
    b.Size              = UDim2.new(1, 0, 0, h or 48)
    b.Position          = UDim2.new(0, 0, 0, y)
    b.BackgroundColor3  = Color3.fromRGB(50, 35, 50)
    b.Text              = ""
    b.TextColor3        = Color3.fromRGB(255, 255, 255)
    b.Font              = Enum.Font.GothamMedium
    b.TextSize          = 14
    b.BorderSizePixel   = 0
    b.AutoButtonColor   = false
    b.Parent            = List
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    return b
end

local SpeedBtn = makeBtn(0)
local FarmBtn  = makeBtn(58)
local AFKBtn   = makeBtn(116)
local SafeBtn  = makeBtn(174)

-- Stats
local Stats = Instance.new("TextLabel")
Stats.Size              = UDim2.new(1, 0, 0, 46)
Stats.Position          = UDim2.new(0, 0, 0, 234)
Stats.BackgroundColor3  = Color3.fromRGB(40, 25, 40)
Stats.TextColor3        = Color3.fromRGB(220, 200, 220)
Stats.Font              = Enum.Font.Gotham
Stats.TextSize          = 13
Stats.BorderSizePixel   = 0
Stats.Text              = "  Chưa lấy được trứng nào"
Stats.TextXAlignment    = Enum.TextXAlignment.Left
Stats.Parent            = List
Instance.new("UICorner", Stats).CornerRadius = UDim.new(0, 10)

-- Log
local LogLbl = Instance.new("TextLabel")
LogLbl.Size             = UDim2.new(1, 0, 0, 60)
LogLbl.Position         = UDim2.new(0, 0, 0, 288)
LogLbl.BackgroundColor3 = Color3.fromRGB(25, 15, 25)
LogLbl.TextColor3       = Color3.fromRGB(160, 150, 170)
LogLbl.Font             = Enum.Font.Code
LogLbl.TextSize         = 11
LogLbl.BorderSizePixel  = 0
LogLbl.Text             = "  > sẵn sàng"
LogLbl.TextXAlignment   = Enum.TextXAlignment.Left
LogLbl.TextYAlignment   = Enum.TextYAlignment.Top
LogLbl.TextWrapped      = true
LogLbl.Parent           = List
Instance.new("UICorner", LogLbl).CornerRadius = UDim.new(0, 10)

local function log(msg)
    LogLbl.Text = "  > " .. msg
end

function updateGUI()
    Stats.Text = "  🥚 Đã lấy: " .. State.Collected .. "  •  Lỗi: " .. State.Failed
end

-- Update trạng thái nút
local function setBtnState(btn, label, on)
    btn.Text = label .. (on and "   [ON]" or "   [OFF]")
    btn.BackgroundColor3 = on and Color3.fromRGB(80, 150, 100) or Color3.fromRGB(50, 35, 50)
end

setBtnState(SpeedBtn, "⚡  Speed Hack", false)
setBtnState(FarmBtn,  "🌾  Auto Farm",  false)
setBtnState(AFKBtn,   "💤  Anti AFK",   true)
SafeBtn.Text = "📍  Đặt vùng an toàn"
SafeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)

-- Handlers
SpeedBtn.MouseButton1Click:Connect(function()
    State.SpeedHack = not State.SpeedHack
    setBtnState(SpeedBtn, "⚡  Speed Hack", State.SpeedHack)
    if State.SpeedHack then
        setSpeed(CONFIG.WALK_SPEED)
        setJump(CONFIG.JUMP_POWER)
        log("speed hack bật: " .. CONFIG.WALK_SPEED)
    else
        setSpeed(16)
        setJump(50)
        log("speed hack tắt")
    end
end)

FarmBtn.MouseButton1Click:Connect(function()
    State.AutoFarm = not State.AutoFarm
    setBtnState(FarmBtn, "🌾  Auto Farm", State.AutoFarm)
    log(State.AutoFarm and "bắt đầu farm trứng..." or "dừng farm")
end)

AFKBtn.MouseButton1Click:Connect(function()
    State.AntiAFK = not State.AntiAFK
    setBtnState(AFKBtn, "💤  Anti AFK", State.AntiAFK)
    log(State.AntiAFK and "anti-afk bật" or "anti-afk tắt")
end)

SafeBtn.MouseButton1Click:Connect(function()
    local _, _, root = getCharacter()
    if root then
        CONFIG.SAFE_ZONE = root.CFrame
        SafeBtn.Text = "📍  Đã đặt vùng an toàn ✓"
        log("safe zone: " .. tostring(math.floor(root.Position.X)) .. ", " .. tostring(math.floor(root.Position.Z)))
        task.delay(2, function()
            SafeBtn.Text = "📍  Đặt vùng an toàn"
        end)
    end
end)

MiniBtn.MouseButton1Click:Connect(function()
    Main.Visible = true
    MiniBtn.Visible = false
end)

CloseBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
    MiniBtn.Visible = true
end)

-- Drag cho PC + Mobile
local dragging, dragStart, startPos
Title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos  = Main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

-- ─── INIT ───
log("script đã tải ✓ bấm 🥚 để mở panel")
updateGUI()
print("[Egg Farmer] loaded. Click 🥚 to open.")
