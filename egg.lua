-- ═══════════════════════════════════════════════════
-- BREAK & STEAL AN EGG — STEALTH AUTO-FARM v2
-- Fix "Bật không lên" + Fix 267 + Auto pickup
-- ═══════════════════════════════════════════════════

print("[EggFarmer] Script bắt đầu load...")

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local VirtualUser        = game:GetService("VirtualUser")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local LP                 = Players.LocalPlayer

-- CONFIG
local CONFIG = {
    WALK_SPEED      = 55,
    JUMP_POWER      = 65,
    TP_DISTANCE_MAX = 250,
    LOOP_DELAY      = 1.0,
    RANDOM_DELAY    = 0.3,
    SAFE_ZONE       = nil,
    USE_FIRE_TOUCH  = true,   -- BẬT lên để nhặt trứng bằng touch
    WALK_LAST_LEG   = true,   -- Đi bộ 25 studs cuối để chắc chắn nhặt
}

local State = {
    AutoFarm  = false,
    AntiAFK   = true,
    SpeedHack = false,
    Collected = 0,
    Failed    = 0,
    EggCount  = 0,
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
    if hum then pcall(function() hum.WalkSpeed = s end) end
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

-- Bay mượt bằng Tween (không bị 267)
local function stealthMove(targetPos)
    if State.Panic then return false end
    local _, hum, root = getCharacter()
    if not hum or not root then return false end

    local currentPos = root.Position
    local dist = (currentPos - targetPos).Magnitude
    if dist > CONFIG.TP_DISTANCE_MAX then
        local direction = (targetPos - currentPos).Unit
        targetPos = currentPos + (direction * CONFIG.TP_DISTANCE_MAX)
        dist = CONFIG.TP_DISTANCE_MAX
    end
    if dist < 2 then return true end

    pcall(function()
        root.Velocity = Vector3.zero
        root.AssemblyLinearVelocity = Vector3.zero
    end)

    local duration = math.clamp(dist / 180, 0.12, 0.7)
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

    local success = pcall(function()
        local tween = TweenService:Create(root, tweenInfo, {CFrame = CFrame.new(targetPos)})
        tween:Play()
        tween.Completed:Wait()
    end)

    if success then
        pcall(function()
            root.Velocity = Vector3.zero
            root.AssemblyLinearVelocity = Vector3.zero
        end)
    end
    return success
end

-- Đi bộ thật tới vị trí (fallback để nhặt trứng)
local function walkToPos(targetPos, timeout)
    local _, hum, root = getCharacter()
    if not hum or not root then return false end
    
    local reached = false
    local startTime = os.clock()
    
    -- Reset velocity rồi MoveTo
    pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        hum:MoveTo(targetPos)
    end)
    
    while os.clock() - startTime < (timeout or 1.5) do
        local _, _, r = getCharacter()
        if not r then break end
        if (r.Position - targetPos).Magnitude < 4 then
            reached = true
            break
        end
        task.wait(0.05)
    end
    
    pcall(function()
        local _, h2 = getCharacter()
        if h2 then h2:MoveTo(root.Position) end -- stop
    end)
    
    return reached
end

local function isEggObject(obj)
    if not obj then return false end
    local name = string.lower(obj.Name)
    -- Bắt các tên: Egg, Egg_Common, EggRare, Trung, EggSpawn...
    return string.find(name, "egg")   ~= nil
        or string.find(name, "trung") ~= nil
end

local function findEggs()
    local eggs = {}
    local function scan(obj, depth)
        if depth > 6 then return end
        if not obj or obj == LP.Character then return end
        if isEggObject(obj) then
            local part
            if obj:IsA("BasePart") then part = obj
            elseif obj:IsA("Model") then part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            else part = obj:FindFirstChildWhichIsA("BasePart") end
            if part and part.Parent then
                table.insert(eggs, part)
            end
            -- KHÔNG return ở đây, tiếp tục scan con của nó
        end
        pcall(function()
            for _, child in ipairs(obj:GetChildren()) do
                scan(child, depth + 1)
            end
        end)
    end
    scan(workspace, 0)
    return eggs
end

local function pickBestEgg()
    local eggs = findEggs()
    State.EggCount = #eggs
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
            end
        end)
        -- Ưu tiên trứng gần + to
        local score = (size * 5 * rarity) - (dist * 2)
        if score > bestScore then
            bestScore = score
            best = egg
        end
    end
    return best
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

-- ═══════════════════════════════════════════════════
-- AUTO FARM LOOP (đã fix nhặt trứng)
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
            if log then log("không tìm thấy trứng nào") end
            task.wait(2)
            continue
        end

        task.wait(math.random() * CONFIG.RANDOM_DELAY)

        -- 1. Bay tới gần trứng (cách 25 studs để chuẩn bị đi bộ vào)
        local _, _, root2 = getCharacter()
        if not root2 then continue end
        
        local eggPos = egg.Position
        local dirToEgg = (eggPos - root2.Position).Unit
        local approachPos = eggPos - (dirToEgg * 25) + Vector3.new(0, 3, 0)
        
        stealthMove(approachPos)
        task.wait(0.15)

        -- 2. Fire touch nếu có (touch nhanh, không cần đi bộ nhiều)
        if CONFIG.USE_FIRE_TOUCH and firetouchinterest then
            pcall(function()
                local _, _, r = getCharacter()
                if r then
                    firetouchinterest(r, egg, 0)
                    task.wait(0.06)
                    firetouchinterest(r, egg, 1)
                end
            end)
            task.wait(0.1)
        end

        -- 3. WALK vào trứng (fallback 100% nhặt được)
        if CONFIG.WALK_LAST_LEG then
            walkToPos(eggPos, 1.2)
        end

        task.wait(0.2)

        -- 4. Bay về safe zone
        if CONFIG.SAFE_ZONE then
            stealthMove(CONFIG.SAFE_ZONE.Position + Vector3.new(0, 3, 0))
        end

        State.Collected = State.Collected + 1
        if updateGUI then updateGUI() end
    end
end)

-- Reset Speed
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
-- GUI (fallback PlayerGui nếu CoreGui không cho)
-- ═══════════════════════════════════════════════════
local function getGuiParent()
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then
        local test = Instance.new("ScreenGui")
        local ok2 = pcall(function() test.Parent = cg end)
        test:Destroy()
        if ok2 then return cg end
    end
    return LP:WaitForChild("PlayerGui")
end

local GUIParent = getGuiParent()

if GUIParent:FindFirstChild("EggFarmGUI") then
    GUIParent.EggFarmGUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "EggFarmGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = GUIParent

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
Main.Size = UDim2.new(0, 300, 0, 440)
Main.Position = UDim2.new(0.5, -150, 0.5, -220)
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
TitleLabel.Text = "🥚 EGG FARMER v2"
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
local PanicBtn = makeBtn(232, 40)

PanicBtn.BackgroundColor3 = Color3.fromRGB(140, 30, 40)
PanicBtn.Text = "🛑 PANIC STOP"
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
LogLbl.Size = UDim2.new(1, 0, 0, 70)
LogLbl.Position = UDim2.new(0, 0, 0, 340)
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

function log(msg)
    LogLbl.Text = "  > " .. msg
    print("[EggFarmer] " .. msg)
end

function updateGUI()
    Stats.Text = "  🥚 Đã lấy: " .. State.Collected
        .. "  •  Lỗi: " .. State.Failed
        .. "  •  Trứng: " .. State.EggCount
end

local function setBtnState(btn, label, on)
    btn.Text = label .. (on and "   [ON]" or "   [OFF]")
    btn.BackgroundColor3 = on and Color3.fromRGB(80, 150, 100) or Color3.fromRGB(50, 35, 50)
end

setBtnState(SpeedBtn, "⚡ Speed (An Toàn)", false)
setBtnState(FarmBtn,  "🌾 Auto Farm", false)
setBtnState(AFKBtn,   "💤 Anti AFK", true)
SafeBtn.Text = "📍 Đặt vùng an toàn"
SafeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)

SpeedBtn.MouseButton1Click:Connect(function()
    State.SpeedHack = not State.SpeedHack
    setBtnState(SpeedBtn, "⚡ Speed (An Toàn)", State.SpeedHack)
    if State.SpeedHack then
        setSpeed(CONFIG.WALK_SPEED)
        setJump(CONFIG.JUMP_POWER)
        log("speed 55 bật")
    else
        setSpeed(16); setJump(50)
        log("speed tắt")
    end
end)

FarmBtn.MouseButton1Click:Connect(function()
    State.AutoFarm = not State.AutoFarm
    setBtnState(FarmBtn, "🌾 Auto Farm", State.AutoFarm)
    if State.AutoFarm then
        -- test scan ngay lần đầu
        local eggs = findEggs()
        State.EggCount = #eggs
        log("bắt đầu farm. Tìm thấy " .. #eggs .. " trứng")
        updateGUI()
    else
        log("dừng farm")
    end
end)

AFKBtn.MouseButton1Click:Connect(function()
    State.AntiAFK = not State.AntiAFK
    setBtnState(AFKBtn, "💤 Anti AFK", State.AntiAFK)
end)

SafeBtn.MouseButton1Click:Connect(function()
    local _, _, root = getCharacter()
    if root then
        CONFIG.SAFE_ZONE = root.CFrame
        SafeBtn.Text = "📍 Đã đặt ✓"
        log("safe zone đã đặt")
        task.delay(2, function() SafeBtn.Text = "📍 Đặt vùng an toàn" end)
    end
end)

PanicBtn.MouseButton1Click:Connect(function()
    State.Panic = true
    State.AutoFarm = false
    State.SpeedHack = false
    setSpeed(16); setJump(50)
    setBtnState(FarmBtn, "🌾 Auto Farm", false)
    setBtnState(SpeedBtn, "⚡ Speed (An Toàn)", false)
    log("PANIC STOP — dừng 10s")
    Main.Visible = false
    MiniBtn.Visible = true
    task.delay(10, function()
        State.Panic = false
        log("sẵn sàng lại")
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

log("script đã tải ✓ bấm 🥚")
updateGUI()
