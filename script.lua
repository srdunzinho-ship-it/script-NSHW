local _ENV = (getgenv or getrenv or getfenv)()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer

local CombatEvent = ReplicatedStorage.BetweenSides.Remotes.Events.CombatEvent
local ToolEvent = ReplicatedStorage.BetweenSides.Remotes.Events.ToolsEvent
local Enemys = workspace.Playability.Enemys

local Settings = {
    ClickV2 = false,
    TweenSpeed = 125,
    SelectedTool = "CombatType",
    BringMobDistance = 35,
    FastAttackSpeed = 0.03,
    KillRange = 100, -- Aumentado para 100
    SwitchTargetDelay = 0.5, -- Delay para trocar de alvo após matar
}

local EquippedTool = nil
local CurrentTarget = nil
local LastTargetHealth = 0
local LastTargetSwitch = 0

local Connections = _ENV.rz_connections or {} do
    _ENV.rz_connections = Connections
    
    for i = 1, #Connections do
        Connections[i]:Disconnect()
    end
    
    table.clear(Connections)
end

local function IsAlive(Character)
    if Character then
        local Humanoid = Character:FindFirstChildOfClass("Humanoid")
        return Humanoid and Humanoid.Health > 0
    end
end

local BodyVelocity do
    BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.Velocity = Vector3.zero
    BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    BodyVelocity.P = 1000
    
    if _ENV.tween_bodyvelocity then
        _ENV.tween_bodyvelocity:Destroy()
    end
    
    _ENV.tween_bodyvelocity = BodyVelocity
    
    local CanCollideObjects = {}
    
    local function AddObjectToBaseParts(Object)
        if Object:IsA("BasePart") and Object.CanCollide then
            table.insert(CanCollideObjects, Object)
        end
    end
    
    local function RemoveObjectsFromBaseParts(BasePart)
        local index = table.find(CanCollideObjects, BasePart)
        
        if index then
            table.remove(CanCollideObjects, index)
        end
    end
    
    local function NewCharacter(Character)
        table.clear(CanCollideObjects)
        
        for _, Object in Character:GetDescendants() do AddObjectToBaseParts(Object) end
        Character.DescendantAdded:Connect(AddObjectToBaseParts)
        Character.DescendantRemoving:Connect(RemoveObjectsFromBaseParts)
    end
    
    table.insert(Connections, Player.CharacterAdded:Connect(NewCharacter))
    task.spawn(NewCharacter, Player.Character)
    
    local function NoClipOnStepped(Character)
        if _ENV.OnFarm then
            for i = 1, #CanCollideObjects do
                CanCollideObjects[i].CanCollide = false
            end
        elseif Character.PrimaryPart and not Character.PrimaryPart.CanCollide then
            for i = 1, #CanCollideObjects do
                CanCollideObjects[i].CanCollide = true
            end
        end
    end
    
    local function UpdateVelocityOnStepped(Character)
        local BasePart = Character:FindFirstChild("UpperTorso")
        local Humanoid = Character:FindFirstChild("Humanoid")
        local BodyVelocity = _ENV.tween_bodyvelocity
        
        if _ENV.OnFarm and BasePart and Humanoid and Humanoid.Health > 0 then
            if BodyVelocity.Parent ~= BasePart then
                BodyVelocity.Parent = BasePart
            end
        elseif BodyVelocity.Parent then
            BodyVelocity.Parent = nil
        end
        
        if BodyVelocity.Velocity ~= Vector3.zero and (not Humanoid or not Humanoid.SeatPart or not _ENV.OnFarm) then
            BodyVelocity.Velocity = Vector3.zero
        end
    end
    
    table.insert(Connections, RunService.Stepped:Connect(function()
        local Character = Player.Character
        
        if IsAlive(Character) then
            UpdateVelocityOnStepped(Character)
            NoClipOnStepped(Character)
            
            -- Aumenta a distância de renderização
            if _ENV.OnFarm then
                pcall(function()
                    sethiddenproperty(Player, "SimulationRadius", math.huge)
                    sethiddenproperty(Player, "MaxSimulationRadius", math.huge)
                end)
            end
        end
    end))
end

local PlayerTP do
    local TweenCreator = {} do
        TweenCreator.__index = TweenCreator
        
        local tweens = {}
        local EasingStyle = Enum.EasingStyle.Linear
        
        function TweenCreator.new(obj, time, prop, value)
            local self = setmetatable({}, TweenCreator)
            
            self.tween = TweenService:Create(obj, TweenInfo.new(time, EasingStyle), { [prop] = value })
            self.tween:Play()
            self.value = value
            self.object = obj
            
            if tweens[obj] then
                tweens[obj]:destroy()
            end
            
            tweens[obj] = self
            return self
        end
        
        function TweenCreator:destroy()
            self.tween:Pause()
            self.tween:Destroy()
            
            tweens[self.object] = nil
            setmetatable(self, nil)
        end
        
        function TweenCreator:stopTween(obj)
            if obj and tweens[obj] then
                tweens[obj]:destroy()
            end
        end
    end
    
    local function TweenStopped()
        if not BodyVelocity.Parent and IsAlive(Player.Character) then
            TweenCreator:stopTween(Player.Character:FindFirstChild("HumanoidRootPart"))
        end
    end
    
    local lastCFrame = nil
    local lastTeleport = 0
    
    PlayerTP = function(TargetCFrame)
        if not IsAlive(Player.Character) or not Player.Character.PrimaryPart then
            return false
        elseif (tick() - lastTeleport) <= 0.3 and lastCFrame == TargetCFrame then
            return false
        end
        
        local Character = Player.Character
        local Humanoid = Character.Humanoid
        local PrimaryPart = Character.PrimaryPart
        
        if Humanoid.Sit then Humanoid.Sit = false return end
        
        lastTeleport = tick()
        lastCFrame = TargetCFrame
        _ENV.OnFarm = true
        
        local teleportPosition = TargetCFrame.Position
        local Distance = (PrimaryPart.Position - teleportPosition).Magnitude
        
        if Distance < 15 then
            PrimaryPart.CFrame = TargetCFrame
            return TweenCreator:stopTween(PrimaryPart)
        end
        
        TweenCreator.new(PrimaryPart, Distance / Settings.TweenSpeed, "CFrame", TargetCFrame)
    end
    
    table.insert(Connections, BodyVelocity:GetPropertyChangedSignal("Parent"):Connect(TweenStopped))
end

local CurrentTime = workspace:GetServerTimeNow()

-- Sistema de ataque super melhorado
local function FastAttack()
    if not IsAlive(Player.Character) then return end
    local Tool = Player.Character:FindFirstChildOfClass("Tool")
    if not Tool then return end
    
    CurrentTime = workspace:GetServerTimeNow()
    
    pcall(function()
        -- Ativa múltiplas vezes para garantir hit
        for i = 1, 5 do
            Tool:Activate()
            task.wait(0.001)
        end
        
        -- Remove todos os cooldowns possíveis
        local Handle = Tool:FindFirstChild("Handle")
        if Handle then
            for _, child in pairs(Handle:GetChildren()) do
                if child.Name:lower():find("cooldown") or child.Name:lower():find("debounce") then
                    if child:IsA("BoolValue") then
                        child.Value = false
                    elseif child:IsA("NumberValue") or child:IsA("IntValue") then
                        child.Value = 0
                    end
                end
            end
            
            -- Ativa som de ataque
            local Sound = Handle:FindFirstChildOfClass("Sound")
            if Sound then 
                Sound.Volume = 0 -- Remove som para performance
                Sound:Play() 
            end
        end
        
        -- Eventos melhorados
        for i = 1, 3 do
            pcall(function()
                ToolEvent:FireServer("Effects", i)
                ToolEvent:FireServer("Activate", i)
            end)
            task.wait(0.001)
        end
        
        -- Sistema ClickV2 super melhorado
        if Settings.ClickV2 then
            for i = 1, 8 do
                pcall(function()
                    Tool:Activate()
                    -- Simula cliques do mouse
                    local VirtualInput = game:GetService("VirtualInputManager")
                    VirtualInput:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                    task.wait(0.001)
                    VirtualInput:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                end)
                task.wait(0.005)
            end
        end
    end)
end

local function DealDamage(Enemies)
    CurrentTime = workspace:GetServerTimeNow()
    
    CombatEvent:FireServer("DealDamage", {
        CallTime = CurrentTime,
        DelayTime = 0,
        Combo = 1,
        Results = Enemies,
        Damage = math.random(50, 150),
        CriticalHit = math.random(1, 10) <= 3,
    })
end

-- Função simples para encontrar mobs próximos
local function FindNearbyMobs()
    local nearbyMobs = {}
    local playerPos = Player.Character and Player.Character.HumanoidRootPart and Player.Character.HumanoidRootPart.Position
    
    if not playerPos then return nearbyMobs end
    
    -- Busca em workspace.Playability.Enemys
    for _, island in pairs(workspace.Playability.Enemys:GetChildren()) do
        for _, mob in pairs(island:GetChildren()) do
            local humanoid = mob:FindFirstChildOfClass("Humanoid")
            local rootPart = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Torso") or mob:FindFirstChild("LowerTorso")
            
            if humanoid and rootPart and humanoid.Health > 0 then
                local distance = (playerPos - rootPart.Position).Magnitude
                if distance <= Settings.KillRange then
                    table.insert(nearbyMobs, {
                        mob = mob,
                        rootPart = rootPart,
                        humanoid = humanoid,
                        distance = distance
                    })
                end
            end
        end
    end
    
    -- Ordena por distância (mais próximo primeiro)
    table.sort(nearbyMobs, function(a, b)
        return a.distance < b.distance
    end)
    
    return nearbyMobs
end

local function GetClosestMob()
    local nearbyMobs = FindNearbyMobs()
    
    -- Se tem um alvo atual, verifica se ainda está vivo e próximo
    if CurrentTarget then
        local humanoid = CurrentTarget:FindFirstChildOfClass("Humanoid")
        local rootPart = CurrentTarget:FindFirstChild("HumanoidRootPart") or CurrentTarget:FindFirstChild("Torso") or CurrentTarget:FindFirstChild("LowerTorso")
        
        if humanoid and rootPart and humanoid.Health > 0 then
            local playerPos = Player.Character and Player.Character.HumanoidRootPart and Player.Character.HumanoidRootPart.Position
            if playerPos then
                local distance = (playerPos - rootPart.Position).Magnitude
                if distance <= Settings.KillRange then
                    -- Se a vida do alvo mudou (tomou dano), continue com ele
                    if humanoid.Health ~= LastTargetHealth then
                        LastTargetHealth = humanoid.Health
                        return CurrentTarget
                    end
                    -- Se está ha muito tempo no mesmo alvo sem tomar dano, troca
                    if tick() - LastTargetSwitch < 3 then
                        return CurrentTarget
                    end
                end
            end
        end
        
        -- Alvo morreu ou saiu de alcance, procura novo
        print("🔄 Trocando de alvo...")
        CurrentTarget = nil
        LastTargetSwitch = tick()
    end
    
    -- Procura novo alvo
    if #nearbyMobs > 0 then
        CurrentTarget = nearbyMobs[1].mob
        LastTargetHealth = nearbyMobs[1].humanoid.Health
        LastTargetSwitch = tick()
        print("🎯 Novo alvo:", CurrentTarget.Name)
        return CurrentTarget
    end
    
    return nil
end

-- Sistema de trazer mobs próximos
local function BringNearbyMobs(targetPosition)
    if not _ENV.BringMob then return 0 end
    
    local nearbyMobs = FindNearbyMobs()
    local broughtCount = 0
    
    for _, mobData in pairs(nearbyMobs) do
        local mob = mobData.mob
        local rootPart = mobData.rootPart
        local humanoid = mobData.humanoid
        
        if rootPart and humanoid and humanoid.Health > 0 then
            -- Desabilita colisão e aumenta o tamanho
            rootPart.CanCollide = false
            rootPart.Size = Vector3.new(Settings.BringMobDistance, Settings.BringMobDistance, Settings.BringMobDistance)
            
            -- Move o mob para a posição do alvo
            rootPart.CFrame = targetPosition
            
            -- Cria BodyVelocity para manter posição
            local bodyVelocity = rootPart:FindFirstChild("BodyVelocity")
            if not bodyVelocity then
                bodyVelocity = Instance.new("BodyVelocity")
                bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
                bodyVelocity.Velocity = Vector3.new(0, 0, 0)
                bodyVelocity.Parent = rootPart
            end
            
            broughtCount = broughtCount + 1
        end
    end
    
    return broughtCount
end

local function IsSelectedTool(Tool)
    return Tool:GetAttribute(Settings.SelectedTool)
end

local function EquipCombat(Activate)
    if not IsAlive(Player.Character) then return end
    
    if EquippedTool and IsSelectedTool(EquippedTool) then
        if Activate then
            -- Sistema de ataque melhorado
            FastAttack()
            
            -- Ataque extra com ClickV2
            if Settings.ClickV2 then
                task.spawn(function()
                    for i = 1, 3 do
                        FastAttack()
                        task.wait(0.01)
                    end
                end)
            end
        end
        
        if EquippedTool.Parent == Player.Backpack then
            Player.Character.Humanoid:EquipTool(EquippedTool)
        elseif EquippedTool.Parent ~= Player.Character then
            EquippedTool = nil
        end
        return nil
    end
    
    local Equipped = Player.Character:FindFirstChildOfClass("Tool")
    
    if Equipped and IsSelectedTool(Equipped) then
        EquippedTool = Equipped
        return nil
    end
    
    for _, Tool in Player.Backpack:GetChildren() do
        if Tool:IsA("Tool") and IsSelectedTool(Tool) then
            EquippedTool = Tool
            Player.Character.Humanoid:EquipTool(Tool)
            return nil
        end
    end
end

-- Interface do usuário customizada
local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local ToggleGui = Instance.new("ScreenGui")
ToggleGui.Name = "ToggleFluentUI"
ToggleGui.ResetOnSpawn = false
ToggleGui.IgnoreGuiInset = true
ToggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ToggleGui.Parent = PlayerGui

local Button = Instance.new("ImageButton")
Button.Name = "MobileToggle"
Button.Size = UDim2.new(0, 60, 0, 60)
Button.Position = UDim2.new(0, 120, 0, 160)
Button.AnchorPoint = Vector2.new(0.5, 0.5)
Button.BackgroundTransparency = 1
Button.Image = "rbxassetid://117809658545028"
Button.ZIndex = 1000
Button.Parent = ToggleGui

local dragging = false
local dragStart, startPos
local UIS = game:GetService("UserInputService")

Button.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Button.Position
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

Button.MouseButton1Click:Connect(function()
    local VirtualInput = game:GetService("VirtualInputManager")
    VirtualInput:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
end)

local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/Rizeniii/uifluent/main/main.lua"))()
local colorData = loadstring(game:HttpGet("https://raw.githubusercontent.com/Rizeniii/uifluent/main/color.lua"))()
Fluent.ThemeColor = Color3.fromRGB(colorData.R, colorData.G, colorData.B)

local Window = Fluent:CreateWindow({
    Title = "MidNight Hub",
    SubTitle = "NightShadow",
    TabWidth = 160,
    Size = UDim2.fromOffset(400, 300),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

Fluent:ToggleTransparency(false)

local MainTab = Window:AddTab({ Title = "Farm", Icon = "home" })
local ConfigTab = Window:AddTab({ Title = "Config", Icon = "settings" })

-- Tab Principal - NPC Killer
MainTab:AddSection("NPC Killer")

MainTab:AddToggle("KillNearbyMobs", {
    Title = "Kill Nearby Mobs",
    Description = "Mata todos os mobs próximos automaticamente",
    Default = false,
    Callback = function(Value)
        _ENV.OnFarm = Value
        
        if Value then
            task.spawn(function()
                while task.wait(Settings.FastAttackSpeed) and _ENV.OnFarm do
                    local mob = GetClosestMob()
                    if not mob then 
                        continue 
                    end
                    
                    CurrentTarget = mob
                    local rootPart = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Torso") or mob:FindFirstChild("LowerTorso")
                    local humanoid = mob:FindFirstChildOfClass("Humanoid")
                    
                    if rootPart and humanoid and humanoid.Health > 0 then
                        print("⚔️ Atacando:", mob.Name)
                        
                        -- Equipa ferramenta e ataca
                        EquipCombat(true)
                        
                        -- Trazer mobs próximos
                        if _ENV.BringMob then
                            local broughtCount = BringNearbyMobs(rootPart.CFrame)
                            if broughtCount > 0 then
                                print("🧲 Trouxe", broughtCount, "mobs")
                            end
                        end
                        
                        -- Causa dano em todos os mobs próximos
                        local nearbyMobs = FindNearbyMobs()
                        local mobsToHit = {}
                        for _, mobData in pairs(nearbyMobs) do
                            table.insert(mobsToHit, mobData.mob)
                        end
                        
                        if #mobsToHit > 0 then
                            DealDamage(mobsToHit)
                        end
                        
                        -- Teleporta para o mob (8 studs acima)
                        local CFrameAngle = CFrame.Angles(math.rad(-90), 0, 0)
                        PlayerTP((rootPart.CFrame + Vector3.new(0, 8, 0)) * CFrameAngle)
                    end
                end
            end)
        end
    end
})

MainTab:AddToggle("BringMob", {
    Title = "Bring Mob",
    Description = "Puxa todos os mobs próximos para você",
    Default = false,
    Callback = function(Value)
        _ENV.BringMob = Value
    end
})

-- Tab de Configurações
ConfigTab:AddSection("Combat Settings")

ConfigTab:AddToggle("ClickV2", {
    Title = "Click V2",
    Description = "Ataque melhorado",
    Default = false,
    Callback = function(Value)
        Settings.ClickV2 = Value
    end
})

ConfigTab:AddSlider("FastAttackSpeed", {
    Title = "Attack Speed",
    Description = "Velocidade de ataque",
    Default = 0.03,
    Min = 0.01,
    Max = 0.1,
    Rounding = 3,
    Callback = function(Value)
        Settings.FastAttackSpeed = Value
    end
})

ConfigTab:AddSlider("KillRange", {
    Title = "Kill Range",
    Description = "Alcance para matar mobs",
    Default = 100,
    Min = 50,
    Max = 200,
    Rounding = 0,
    Callback = function(Value)
        Settings.KillRange = Value
    end
})

ConfigTab:AddSlider("SwitchTargetDelay", {
    Title = "Target Switch Delay",
    Description = "Delay para trocar de alvo (segundos)",
    Default = 0.5,
    Min = 0.1,
    Max = 2,
    Rounding = 1,
    Callback = function(Value)
        Settings.SwitchTargetDelay = Value
    end
})

ConfigTab:AddSection("Movement Settings")

ConfigTab:AddSlider("TweenSpeed", {
    Title = "Tween Speed",
    Description = "Velocidade de movimento",
    Default = 125,
    Min = 50,
    Max = 300,
    Rounding = 0,
    Callback = function(Value)
        Settings.TweenSpeed = Value
    end
})

ConfigTab:AddSection("BringMob Settings")

ConfigTab:AddSlider("BringMobDistance", {
    Title = "BringMob Size",
    Description = "Tamanho dos mobs quando puxados",
    Default = 35,
    Min = 10,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        Settings.BringMobDistance = Value
    end
})

ConfigTab:AddSection("Tool Settings")

ConfigTab:AddDropdown("ToolType", {
    Title = "Select Tool Type",
    Description = "Tipo de ferramenta para usar",
    Values = {"CombatType", "Sword", "Gun"},
    Default = "CombatType",
    Callback = function(Value)
        Settings.SelectedTool = Value
    end
})

-- Notificação de carregamento
Fluent:Notify({
    Title = "MidNight Hub",
    Content = "Mob Killer carregado com sucesso!",
    Duration = 5
})
