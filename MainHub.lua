--[=[
    FLATINIUM HUB (ULTRA-SMOOTH SLIDERS, 3D FLY, FLING & BRING)
    - Compact UI Frame with White Outline & Black/Grey Gradient
    - Red "X" Exit Button with saved progress persistence
    - True 3D Camera-Relative Flight & ESP
    - Player Fling & Bring Systems (Dropdowns & Chat Commands)
]=]

local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Global Saved Progress State
_G.SavedSettings = _G.SavedSettings or {
    WalkSpeed = 16,
    JumpHeight = 7.2,
    FlyActive = false,
    EspActive = false
}

-- Active Handles
local flyBodyVelocity = nil
local flyBodyGyro = nil

-- Cleanup existing GUI
if CoreGui:FindFirstChild("FlatiniumHub") then
    CoreGui.FlatiniumHub:Destroy()
end

-- Helper Functions
local function GetCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function GetHumanoid()
    local char = GetCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- 1. WalkSpeed
local function SetWalkSpeed(value)
    _G.SavedSettings.WalkSpeed = value
    local hum = GetHumanoid()
    if hum then hum.WalkSpeed = value end
end

-- 2. JumpHeight
local function SetJumpHeight(value)
    _G.SavedSettings.JumpHeight = value
    local hum = GetHumanoid()
    if hum then
        if hum.UseJumpPower then
            hum.JumpPower = value
        else
            hum.JumpHeight = value
        end
    end
end

-- 3. True 3D Free-Flight Logic
local function UpdateFlyMovement()
    if not _G.SavedSettings.FlyActive then return end
    local char = GetCharacter()
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = GetHumanoid()
    if not root or not hum then return end

    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    
    local moveDirection = hum.MoveDirection
    local speed = _G.SavedSettings.WalkSpeed

    if moveDirection.Magnitude > 0 then
        local camCFrame = Camera.CFrame
        local cameraRelativeDir = (camCFrame.RightVector * moveDirection.X + camCFrame.LookVector * -moveDirection.Z).Unit
        local upDownFactor = camCFrame.LookVector.Y
        
        if moveDirection.Z < 0 then
            flyBodyVelocity.Velocity = (cameraRelativeDir + Vector3.new(0, upDownFactor, 0)).Unit * speed * 1.5
        else
            flyBodyVelocity.Velocity = cameraRelativeDir * speed * 1.5
        end
    end

    flyBodyGyro.CFrame = CFrame.new(root.Position, root.Position + Camera.CFrame.LookVector * Vector3.new(1, 0, 1))
end

local function ToggleFly(state)
    local char = GetCharacter()
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = GetHumanoid()
    if not char or not root or not hum then return end

    _G.SavedSettings.FlyActive = state

    if state then
        if not flyBodyVelocity then
            flyBodyVelocity = Instance.new("BodyVelocity")
            flyBodyVelocity.Name = "FlyVelocity"
            flyBodyVelocity.MaxForce = Vector3.new(1, 1, 1) * 10^7
            flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            flyBodyVelocity.Parent = root
        end

        if not flyBodyGyro then
            flyBodyGyro = Instance.new("BodyGyro")
            flyBodyGyro.Name = "FlyGyro"
            flyBodyGyro.MaxTorque = Vector3.new(1, 1, 1) * 10^7
            flyBodyGyro.CFrame = root.CFrame
            flyBodyGyro.Parent = root
        end

        hum.PlatformStand = true
        RunService:BindToRenderStep("FlyLoop", Enum.RenderPriority.Camera.Value + 1, UpdateFlyMovement)
    else
        hum.PlatformStand = false
        if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity = nil end
        if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro = nil end
        RunService:UnbindFromRenderStep("FlyLoop")
    end
end

-- 4. Fling Mechanics (Sandbox Physics)
local function FlingPlayer(targetPlayer)
    if not targetPlayer or targetPlayer == LocalPlayer then return end
    local char = GetCharacter()
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    local targetChar = targetPlayer.Character
    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    
    if rootPart and targetRoot then
        local bav = Instance.new("BodyAngularVelocity")
        bav.Name = "FlingSpin"
        bav.MaxTorque = Vector3.new(0, math.huge, 0)
        bav.AngularVelocity = Vector3.new(0, 99999, 0)
        bav.Parent = rootPart

        local startTime = tick()
        local connection
        connection = RunService.RenderStepped:Connect(function()
            if not targetRoot or not rootPart or (tick() - startTime > 1.5) then
                bav:Destroy()
                connection:Disconnect()
            else
                rootPart.CFrame = targetRoot.CFrame
            end
        end)
    end
end

-- 5. Bring Mechanics (Sandbox Teleportation)
local function BringPlayer(targetPlayer)
    if not targetPlayer or targetPlayer == LocalPlayer then return end
    local char = GetCharacter()
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    local targetChar = targetPlayer.Character
    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")

    if rootPart and targetRoot then
        targetRoot.CFrame = rootPart.CFrame + Vector3.new(0, 3, 0)
    end
end

-- 6. ESP
local function UpdateESP()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local highlight = char:FindFirstChild("ESPHighlight")
            if _G.SavedSettings.EspActive then
                if not highlight then
                    highlight = Instance.new("Highlight")
                    highlight.Name = "ESPHighlight"
                    highlight.FillColor = Color3.fromRGB(255, 0, 0)
                    highlight.FillTransparency = 0.5
                    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                    highlight.OutlineTransparency = 0
                    highlight.Adornee = char
                    highlight.Parent = char
                end
            else
                if highlight then highlight:Destroy() end
            end
        end
    end
end

local function ToggleESP(state)
    _G.SavedSettings.EspActive = state
    UpdateESP()

    if state then
        RunService:BindToRenderStep("ESPLoop", Enum.RenderPriority.Camera.Value, UpdateESP)
    else
        RunService:UnbindFromRenderStep("ESPLoop")
        for _, player in pairs(Players:GetPlayers()) do
            if player.Character and player.Character:FindFirstChild("ESPHighlight") then
                player.Character.ESPHighlight:Destroy()
            end
        end
    end
end

-- Chat Commands Support (/fly, /unfly, /fling [username], /bring [username])
LocalPlayer.Chatted:Connect(function(message)
    local msg = string.lower(message)
    if msg == "/fly" then ToggleFly(true)
    elseif msg == "/unfly" then ToggleFly(false)
    elseif string.sub(msg, 1, 7) == "/fling " then
        local targetName = string.sub(message, 8)
        for _, player in pairs(Players:GetPlayers()) do
            if string.lower(player.Name) == string.lower(targetName) or string.lower(player.DisplayName) == string.lower(targetName) then
                FlingPlayer(player)
                break
            end
        end
    elseif string.sub(msg, 1, 7) == "/bring " then
        local targetName = string.sub(message, 8)
        for _, player in pairs(Players:GetPlayers()) do
            if string.lower(player.Name) == string.lower(targetName) or string.lower(player.DisplayName) == string.lower(targetName) then
                BringPlayer(player)
                break
            end
        end
    end
end)

-- Re-apply saved progress on character spawn
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    SetWalkSpeed(_G.SavedSettings.WalkSpeed)
    SetJumpHeight(_G.SavedSettings.JumpHeight)
end)

--========================================
-- COMPACT GUI BUILDING
--========================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FlatiniumHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 280, 0, 390)
MainFrame.Position = UDim2.new(0.5, -140, 0.5, -195)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 2
MainStroke.Color = Color3.fromRGB(255, 255, 255)
MainStroke.Parent = MainFrame

local MainGradient = Instance.new("UIGradient")
MainGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 50, 50))
})
MainGradient.Rotation = 90
MainGradient.Parent = MainFrame

-- Top Header Bar
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 35)
TopBar.BackgroundTransparency = 1
TopBar.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -40, 1, 0)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Flatinium Hub"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

-- Red Exit (X) Button
local ExitBtn = Instance.new("TextButton")
ExitBtn.Name = "ExitButton"
ExitBtn.Size = UDim2.new(0, 24, 0, 24)
ExitBtn.Position = UDim2.new(1, -29, 0.5, -12)
ExitBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
ExitBtn.Text = "X"
ExitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ExitBtn.Font = Enum.Font.GothamBold
ExitBtn.TextSize = 12
ExitBtn.AutoButtonColor = false
ExitBtn.Parent = TopBar

local ExitCorner = Instance.new("UICorner")
ExitCorner.CornerRadius = UDim.new(0, 6)
ExitCorner.Parent = ExitBtn

ExitBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    print("Flatinium Hub Exited. Settings successfully preserved!")
end)

-- Content Scroll Area
local ContentFrame = Instance.new("ScrollingFrame")
ContentFrame.Size = UDim2.new(1, -16, 1, -45)
ContentFrame.Position = UDim2.new(0, 8, 0, 40)
ContentFrame.BackgroundTransparency = 1
ContentFrame.ScrollBarThickness = 2
ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 400)
ContentFrame.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Parent = ContentFrame

-- UI Helper Elements
local Color_Text = Color3.fromRGB(240, 240, 240)
local Color_Toggle_Bg = Color3.fromRGB(35, 35, 35)
local Color_Slider_Bg = Color3.fromRGB(45, 45, 45)

-- ULTRA-SMOOTH SLIDER BUILDER
local function CreateSlider(name, min, max, default, callback)
    local SliderFrame = Instance.new("Frame")
    SliderFrame.Size = UDim2.new(1, 0, 0, 40)
    SliderFrame.BackgroundColor3 = Color_Slider_Bg
    SliderFrame.Parent = ContentFrame
    Instance.new("UICorner", SliderFrame).CornerRadius = UDim.new(0, 5)

    local Title = Instance.new("TextLabel")
    Title.Position = UDim2.new(0, 8, 0, 2)
    Title.Size = UDim2.new(0.5, 0, 0, 18)
    Title.BackgroundTransparency = 1
    Title.Text = name
    Title.TextColor3 = Color_Text
    Title.Font = Enum.Font.GothamSemibold
    Title.TextSize = 11
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = SliderFrame

    local ValueLabel = Instance.new("TextLabel")
    ValueLabel.Position = UDim2.new(0.5, -8, 0, 2)
    ValueLabel.Size = UDim2.new(0.5, 0, 0, 18)
    ValueLabel.BackgroundTransparency = 1
    ValueLabel.Text = tostring(default)
    ValueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ValueLabel.Font = Enum.Font.GothamBold
    ValueLabel.TextSize = 11
    ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    ValueLabel.Parent = SliderFrame

    local SliderBack = Instance.new("Frame")
    SliderBack.Position = UDim2.new(0, 8, 0, 24)
    SliderBack.Size = UDim2.new(1, -16, 0, 6)
    SliderBack.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    SliderBack.Parent = SliderFrame
    Instance.new("UICorner", SliderBack).CornerRadius = UDim.new(1, 0)

    local SliderFill = Instance.new("Frame")
    SliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    SliderFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    SliderFill.Parent = SliderBack
    Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(1, 0)

    local SliderBtn = Instance.new("TextButton")
    SliderBtn.Size = UDim2.new(1, 0, 1, 0)
    SliderBtn.BackgroundTransparency = 1
    SliderBtn.Text = ""
    SliderBtn.Parent = SliderBack

    local dragging = false

    local function UpdateSlider(inputObj)
        local absPos = SliderBack.AbsolutePosition.X
        local absSize = SliderBack.AbsoluteSize.X
        local inputX = inputObj.Position.X
        
        local percentage = math.clamp((inputX - absPos) / absSize, 0, 1)
        SliderFill.Size = UDim2.new(percentage, 0, 1, 0)
        
        local value = math.floor(min + (max - min) * percentage)
        ValueLabel.Text = tostring(value)
        pcall(callback, value)
    end

    SliderBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            UpdateSlider(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            UpdateSlider(input)
        end
    end)
end

local function CreateToggle(name, default, callback)
    local ToggleFrame = Instance.new("Frame")
    ToggleFrame.Size = UDim2.new(1, 0, 0, 32)
    ToggleFrame.BackgroundColor3 = Color_Toggle_Bg
    ToggleFrame.Parent = ContentFrame
    Instance.new("UICorner", ToggleFrame).CornerRadius = UDim.new(0, 5)

    local Title = Instance.new("TextLabel")
    Title.Position = UDim2.new(0, 8, 0, 0)
    Title.Size = UDim2.new(0.6, 0, 1, 0)
    Title.BackgroundTransparency = 1
    Title.Text = name
    Title.TextColor3 = Color_Text
    Title.Font = Enum.Font.GothamSemibold
    Title.TextSize = 11
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = ToggleFrame

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Position = UDim2.new(1, -48, 0.5, -9)
    ToggleBtn.Size = UDim2.new(0, 40, 0, 18)
    ToggleBtn.BackgroundColor3 = (default and Color3.fromRGB(50, 220, 50)) or Color3.fromRGB(220, 50, 50)
    ToggleBtn.Text = ""
    ToggleBtn.AutoButtonColor = false
    ToggleBtn.Parent = ToggleFrame
    Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)

    local state = default
    ToggleBtn.MouseButton1Click:Connect(function()
        state = not state
        local targetColor = (state and Color3.fromRGB(50, 220, 50)) or Color3.fromRGB(220, 50, 50)
        TweenService:Create(ToggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
        pcall(callback, state)
    end)
end

-- Player Fling Dropdown Selector
local function CreateFlingDropdown()
    local DropFrame = Instance.new("Frame")
    DropFrame.Size = UDim2.new(1, 0, 0, 32)
    DropFrame.BackgroundColor3 = Color_Toggle_Bg
    DropFrame.ClipsDescendants = true
    DropFrame.Parent = ContentFrame
    Instance.new("UICorner", DropFrame).CornerRadius = UDim.new(0, 5)

    local Title = Instance.new("TextLabel")
    Title.Position = UDim2.new(0, 8, 0, 0)
    Title.Size = UDim2.new(1, -110, 0, 32)
    Title.BackgroundTransparency = 1
    Title.Text = "Fling Players"
    Title.TextColor3 = Color_Text
    Title.Font = Enum.Font.GothamSemibold
    Title.TextSize = 11
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = DropFrame

    local SelectedLabel = Instance.new("TextLabel")
    SelectedLabel.Position = UDim2.new(1, -110, 0, 0)
    SelectedLabel.Size = UDim2.new(0, 100, 0, 32)
    SelectedLabel.BackgroundTransparency = 1
    SelectedLabel.Text = "Select..."
    SelectedLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    SelectedLabel.Font = Enum.Font.Gotham
    SelectedLabel.TextSize = 10
    SelectedLabel.TextXAlignment = Enum.TextXAlignment.Right
    SelectedLabel.Parent = DropFrame

    local InteractBtn = Instance.new("TextButton")
    InteractBtn.Size = UDim2.new(1, 0, 0, 32)
    InteractBtn.BackgroundTransparency = 1
    InteractBtn.Text = ""
    InteractBtn.Parent = DropFrame

    local ListScroll = Instance.new("ScrollingFrame")
    ListScroll.Position = UDim2.new(0, 5, 0, 35)
    ListScroll.Size = UDim2.new(1, -10, 0, 80)
    ListScroll.BackgroundTransparency = 1
    ListScroll.ScrollBarThickness = 2
    ListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    ListScroll.Parent = DropFrame

    local ListLayout = Instance.new("UIListLayout")
    ListLayout.Padding = UDim.new(0, 3)
    ListLayout.Parent = ListScroll

    local isOpen = false
    InteractBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        TweenService:Create(DropFrame, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, (isOpen and 120) or 32)}):Play()
    end)

    local function RefreshList()
        for _, item in pairs(ListScroll:GetChildren()) do
            if item:IsA("TextButton") then item:Destroy() end
        end

        local count = 0
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                count = count + 1
                local PBtn = Instance.new("TextButton")
                PBtn.Size = UDim2.new(1, -6, 0, 22)
                PBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
                PBtn.Text = player.Name
                PBtn.TextColor3 = Color_Text
                PBtn.Font = Enum.Font.Gotham
                PBtn.TextSize = 10
                PBtn.Parent = ListScroll
                Instance.new("UICorner", PBtn).CornerRadius = UDim.new(0, 4)

                PBtn.MouseButton1Click:Connect(function()
                    SelectedLabel.Text = player.Name
                    FlingPlayer(player)
                end)
            end
        end
        ListScroll.CanvasSize = UDim2.new(0, 0, 0, count * 25)
    end

    RefreshList()
end

-- Player Bring Dropdown Selector
local function CreateBringDropdown()
    local DropFrame = Instance.new("Frame")
    DropFrame.Size = UDim2.new(1, 0, 0, 32)
    DropFrame.BackgroundColor3 = Color_Toggle_Bg
    DropFrame.ClipsDescendants = true
    DropFrame.Parent = ContentFrame
    Instance.new("UICorner", DropFrame).CornerRadius = UDim.new(0, 5)

    local Title = Instance.new("TextLabel")
    Title.Position = UDim2.new(0, 8, 0, 0)
    Title.Size = UDim2.new(1, -110, 0, 32)
    Title.BackgroundTransparency = 1
    Title.Text = "Bring Players"
    Title.TextColor3 = Color_Text
    Title.Font = Enum.Font.GothamSemibold
    Title.TextSize = 11
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = DropFrame

    local SelectedLabel = Instance.new("TextLabel")
    SelectedLabel.Position = UDim2.new(1, -110, 0, 0)
    SelectedLabel.Size = UDim2.new(
