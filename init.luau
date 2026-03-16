--[[
    __      __          _            _       ______       _   _ _            _____                                       __      _____  
    \ \    / /         (_)          ( )     |  ____|     | | (_) |          / ____|                                      \ \    / /__ \ 
     \ \  / /   _ _ __  ___  ___   _|/ ___  | |__   _ __ | |_ _| |_ _   _  | (___  _ __   __ ___      ___ __   ___ _ __   \ \  / /   ) |
      \ \/ / | | | '_ \| \ \/ / | | | / __| |  __| | '_ \| __| | __| | | |  \___ \| '_ \ / _` \ \ /\ / / '_ \ / _ \ '__|   \ \/ /   / / 
       \  /| |_| | | | | |>  <| |_| | \__ \ | |____| | | | |_| | |_| |_| |  ____) | |_) | (_| |\ V  V /| | | |  __/ |       \  /   / /_ 
        \/  \__, |_| |_|_/_/\_\\__,_| |___/ |______|_| |_|\__|_|\__|\__, | |_____/| .__/ \__,_| \_/\_/ |_| |_|\___|_|        \/   |____|
             __/ |                                                   __/ |        | |                                                   
            |___/                                                   |___/         |_|
]]--

if getgenv().VynixuEntitySpawnerV2 then return getgenv().VynixuEntitySpawnerV2 end

loadstring(game:HttpGet("https://raw.githubusercontent.com/RegularVynixu/Utilities/main/Functions.lua"))()

-- \\ Services // --

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- \\ Variables // --

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local CollisionPart = Character:WaitForChild("CollisionPart", 3) or Character:WaitForChild("Collision", 3)
local Camera = workspace.CurrentCamera
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("RemotesFolder") :: Folder
local GameStats = ReplicatedStorage:WaitForChild("GameStats") :: Folder
local CurrentRooms = workspace:WaitForChild("CurrentRooms") :: Folder

local Assets = {
	Repentance = LoadCustomInstance("https://github.com/RegularVynixu/Utilities/raw/refs/heads/main/Doors/Entity%20Spawner/Assets/Repentance.rbxm")
}
local Modules = {
	Module_Events = require(ReplicatedStorage.ModulesClient.Module_Events :: ModuleScript),
	Main_Game = require(PlayerGui.MainUI.Initiator.Main_Game :: ModuleScript),
	Earthquake = require(Remotes.RequestAsset:InvokeServer("Earthquake") :: ModuleScript)
}
local Storage = {
    Ambient = {},
	DeathTypes = {
		["Yellow"] = {"yellow", "curious"},
		["Blue"] = {"blue", "guiding"}
	}
}

local CONST = {
	BASE_ENTITY_SPEED = 65,
	ATTR = {
		ENTITY = {
			Running = false,
			CustomEntity = true,
			Paused = false,
			BeingBanished = false,
			Despawning = false,
			Damage = true,
			LastEnteredRoom = -1
		},
		PLAYER = {
			SpawnProtection = 5
		}
	},
	DEFAULT = {
		CONFIG = {
			Entity = {
				Name = "Template Entity",
				Asset = "https://github.com/RegularVynixu/Utilities/raw/refs/heads/main/Doors/Entity%20Spawner/Assets/Entities/Rush.rbxm",
				HeightOffset = 0
			},
			Movement = {
				Speed = 100,
				Delay = 2,
				Reversed = false
			},
			Damage = {
				Enabled = true,
				Range = 40,
				Amount = 125
			},
			Rebounding = {
				Enabled = true,
				Type = "Ambush", -- "Blitz"
				Min = 2,
				Max = 4,
				Delay = 2
			},
			Lights = {
				Flicker = {
					Enabled = true,
					Duration = 1
				},
				Shatter = true,
				Repair = false
			},
			Earthquake = {
				Enabled = true
			},
			CameraShake = {
				Enabled = true,
				Values = {1.5, 20, 0.1, 1}, -- Magnitude, Roughness, FadeIn, FadeOut
				Range = 100
			},
			Crucifixion = {
				Type = "Curious", -- "Guiding"
				Enabled = true,
				Range = 40,
				Resist = false,
				Break = true
			},
			Death = {
				Type = "Guiding", -- "Curious"
				Hints = {"Death", "Hints", "Go", "Here"},
				Cause = ""
			}
		},
		DEBUG = {
			OnSpawned = function() end,
			OnStartMoving = function() end,
			OnReachedNode = function() end,
			OnEnterRoom = function() end,
			OnLookAt = function() end,
			OnRebounding = function() end,
			OnDespawning = function() end,
			OnDespawned = function() end,
			OnDamagePlayer = function() end,
			CrucifixionOverwrite = nil
		}
	}
}

local Module = {
    ActiveEntities = {}
}

-- \\ Functions // --

local function CloneTable(tbl: any): any
    local new = {}
    for key, value in next, tbl do
        if typeof(value) == "table" then
            new[key] = CloneTable(value)
        else
            new[key] = value
        end
    end
    return new
end

function ApplyConfigDefaults(tbl, defaults)
    local new = CloneTable(tbl)
    for key, value in next, defaults do
        if new[key] == nil then
            if typeof(value) == "table" then
                new[key] = CloneTable(value)
            else
                new[key] = value
            end

        elseif typeof(value) == "table" then
            if typeof(new[key]) ~= "table" then
                new[key] = {}
            end
            new[key] = ApplyConfigDefaults(new[key], value)
        end
    end
    return new
end

local function OnCharacterAdded(char: Model)
	LastRespawn = tick()

	Character = char
	Humanoid = char:WaitForChild("Humanoid")
    CollisionPart = char:WaitForChild("CollisionPart", 3) or char:WaitForChild("Collision", 3)
end

local function GetCurrentRoom(latest: boolean): Model?
    if latest then
        return CurrentRooms:GetChildren()[#CurrentRooms:GetChildren()]
    end
    return CurrentRooms:FindFirstChild(LocalPlayer:GetAttribute("CurrentRoom"))
end

local function GetRoomAtPoint(vector3: Vector3): Model?
	local whitelist = {}
	for _, room in next, CurrentRooms:GetChildren() do
		local p = room:FindFirstChild(room.Name)
		if p then
			whitelist[#whitelist + 1] = p
		end
	end

	if #whitelist > 0 then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = whitelist
		params.CollisionGroup = "BaseCheck"

		local result = workspace:Raycast(vector3, Vector3.new(0, -100, 0), params)
		if result then
			for _, room in next, CurrentRooms:GetChildren() do
				if result.Instance.Parent == room then
					return room
				end
			end
		end
	end
	return
end

local function FixRoomLights(room: Model)
    local roomEntrance = room:FindFirstChild("RoomEntrance")
	if not roomEntrance then return end

    -- Clear shards
    for _, c in next, Camera:GetChildren() do
        if c.Name == "Piece" then
            c:Destroy()
        end
    end
    
    -- Set room ambient
    Modules.Module_Events.toggle(room, true, Storage.Ambient[room])

    -- Fix lights
    local stuff = {}
    for _, d in next, room:GetDescendants() do
        if d:IsA("Model") and (d.Name == "LightStand" or d.Name == "Chandelier") then
            table.insert(stuff, d)
        end
    end

    local random = Random.new(tick())
    for _, v in next, stuff do
        if v:GetAttribute("Shattered") then
			local r1 = random:NextInteger(-10, 10) / 50
			local r2 = random:NextInteger(5, 20) / 100
	
			task.delay((roomEntrance.Position - v.PrimaryPart.Position).Magnitude / 150 + r1, function()
				local neon = v:FindFirstChild("Neon", true)
				for _, d in next, v:GetDescendants() do
					if d:IsA("Light") then
						TweenService:Create(d, TweenInfo.new(r2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
							Brightness = d:GetAttribute("OGBrightness")
						}):Play()
					elseif d:IsA("Sound") then
						TweenService:Create(d, TweenInfo.new(r2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
							Volume = d:GetAttribute("OGVolume")
						}):Play()
					end
				end
				if neon then
					neon.Transparency = 0.9
					neon.Material = Enum.Material.Neon
					TweenService:Create(neon, TweenInfo.new(r2, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {
						Transparency = 0.2
					}):Play()
					task.wait(r2)
				end
				v:SetAttribute("Shattered", nil)
			end)
		end
    end
end

local function PlayerHasItemEquipped(name: string): boolean
	local tool = Character:FindFirstChildOfClass("Tool")
	if tool and tool.Name == name then
		return true, tool
	end
	return false
end

local function CrucifixEntity(entity: any, tool: Tool)
	local model = entity.Model
	local config = entity.Config

	local resist = config.Crucifixion.Resist

	local toolPivot = tool:GetPivot()
	local entityPivot = model:GetPivot()

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {Character, model}
	local result = workspace:Raycast(entityPivot.Position, Vector3.new(0, -1000, 0), params)
	if not result then return end

	-- Setup
	model:SetAttribute("BeingBanished", true)

	local repentance = Assets.Repentance:Clone()
	local crucifix = repentance.Crucifix
	local pentagram = repentance.Pentagram
	local entityPart = repentance.Entity
	local sound = (config.Crucifixion.Resist and crucifix.SoundFail or crucifix.Sound)
	local shaker = Modules.Main_Game.camShaker:StartShake(5, 20, 2, Vector3.new())

	local function waitUntil(t: number)
		repeat RunService.RenderStepped:Wait() until sound.TimePosition >= t
	end
	local function fadeOut()
		for _, c in next, pentagram:GetChildren() do
			if c.Name == "BeamFlat" then
				task.delay(c:GetAttribute("Delay"), function()
					TweenService:Create(c, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
						Brightness = 0
					}):Play()
				end)
			end
		end
	end

	repentance:PivotTo(CFrame.new(result.Position))
	crucifix.CFrame = toolPivot
	repentance.Entity.CFrame = entityPivot
    crucifix.BodyPosition.Position = (CollisionPart.CFrame * CFrame.new(0.5, 3, -6)).Position
	repentance.Parent = workspace
	sound:Play()

	task.spawn(function()
		while model.Parent and repentance.Parent do
			model:PivotTo(entityPart.CFrame)
			task.wait()
		end
		model:Destroy()
	end)

	-- Animation
	TweenService:Create(pentagram.Circle, TweenInfo.new(2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), { CFrame = pentagram.Circle.CFrame - Vector3.new(0, 25, 0) }):Play()
	TweenService:Create(crucifix.BodyAngularVelocity, TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { AngularVelocity = Vector3.new(0, 40, 0) }):Play()
	task.delay(2, pentagram.Circle.Destroy, pentagram.Circle)

	task.spawn(function()
		waitUntil(2.625)
		TweenService:Create(pentagram.Base.LightAttach.LightBright, TweenInfo.new(1.5, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut), {
			Brightness = 5,
			Range = 40
		}):Play()
		TweenService:Create(crucifix.Light, TweenInfo.new(1.5, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut), {
			Brightness = 11.25,
			Range = 30
		}):Play()
		task.wait(1.5)
		TweenService:Create(pentagram.Base.LightAttach.LightBright, TweenInfo.new(1.5, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut), {
			Brightness = 0,
			Range = 0
		}):Play()
		TweenService:Create(crucifix.Light, TweenInfo.new(1.5, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut), {
			Brightness = 0,
			Range = 0
		}):Play()

		if resist == false then
			TweenService:Create(crucifix.Light, TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut), { Brightness = 15, Range = 40 }):Play()
			shaker:StartFadeOut(3)
			fadeOut()
			TweenService:Create(crucifix.BodyAngularVelocity, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { AngularVelocity = Vector3.new() }):Play()
		end
	end)

	-- Actions
	if resist == false then
		waitUntil(2)
		TweenService:Create(entityPart, TweenInfo.new(3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { CFrame = repentance.Entity.CFrame - Vector3.new(0, 25, 0) }):Play()
		
        for _, v in next, model:GetDescendants() do
			if
				v:IsA("Sound")
				and not v:GetAttribute("VolumeIgnore")
			then
                TweenService:Create(v, TweenInfo.new(3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Volume = 0 }):Play()
            end
        end
        
        waitUntil(6.75)
	else
		waitUntil(4)
		TweenService:Create(crucifix.BodyAngularVelocity, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { AngularVelocity = Vector3.new() }):Play()
		TweenService:Create(pentagram.Base.LightAttach.LightBright, TweenInfo.new(1.5, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut), { Brightness = 0, Range = 0, Color = Color3.fromRGB(255, 116, 130) }):Play()
		TweenService:Create(crucifix.Light, TweenInfo.new(1.5, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut), { Brightness = 0, Range = 0, Color = Color3.fromRGB(255, 116, 130) }):Play()
		shaker:StartFadeOut(3)
		task.spawn(function()
			local color = Instance.new("Color3Value")
			color.Value = Color3.fromRGB(137, 207, 255)

			local tween = TweenService:Create(color, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Value = Color3.fromRGB(255, 116, 130) })
			tween:Play()

			while tween.PlaybackState == Enum.PlaybackState.Playing do
				for _, d in next, repentance:GetDescendants() do
					if d.ClassName == "Beam" then
						d.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, color.Value), ColorSequenceKeypoint.new(1, color.Value)}

					elseif d.Name == "Crucifix" then
						d.Color = color.Value
					end
				end
				task.wait()
			end
		end)
		waitUntil(9.625)
	end

	-- Crucifix explode
	TweenService:Create(repentance.Crucifix, TweenInfo.new(1), { Size = repentance.Crucifix.Size * 3, Transparency = 1 }):Play()
	TweenService:Create(repentance.Pentagram.Base.LightAttach.LightBright, TweenInfo.new(1), { Brightness = 0, Range = 0 }):Play()
	TweenService:Create(repentance.Crucifix.Light, TweenInfo.new(1), { Brightness = 0, Range = 0 }):Play()

	if not resist then
		repentance.Crucifix.ExplodeParticle:Emit(math.random(20, 30))
		Modules.Main_Game.camShaker:ShakeOnce(7.5, 7.5, 0.25, 1.5)
	else
		model:SetAttribute("BeingBanished", false)
		model:SetAttribute("Paused", false)
		fadeOut()
	end
	task.delay(5, repentance.Destroy, repentance)
end

local function IsPlayerProtected(): boolean
	return (tick() - LastRespawn) <= LocalPlayer:GetAttribute("SpawnProtection")
end

local function DamagePlayer(entity: any)
	if Humanoid.Health <= 0 or IsPlayerProtected() then return end
		
    local config = entity.Config
    local newHealth = math.clamp(Humanoid.Health - config.Damage.Amount, 0, Humanoid.MaxHealth)

    if newHealth == 0 then
        -- Death hints
        if #config.Death.Hints > 0 then
            -- Get death type
            local colour;
            for name, values in next, Storage.DeathTypes do
                if table.find(values, config.Death.Type:lower()) then
                    colour = name
                end
            end
            if not colour then
                for _, c in next, PlayerGui.MainUI.Initiator.Main_Game.Health.Music:GetChildren() do
                    if c.Name:lower() == config.Death.Type:lower() then
                        colour = c.Name
                    end
                end
            end
            if not colour then
                colour = "Blue"
            end
            
            -- Set death hints and type (thanks oogy)
            if firesignal then
                firesignal(Remotes.DeathHint.OnClientEvent, config.Death.Hints, colour)
            else
                warn(debug.traceback("function 'firesignal' not supported by exploit, ignoring death hints"))
            end
        end

        -- Set death cause
        local cause = config.Death.Cause
        if typeof(cause) == "string" and cause ~= "" then
            GameStats["Player_".. LocalPlayer.Name].Total.DeathCause.Value = cause
        end
    end

    -- Update health
    Humanoid.Health = newHealth
    task.spawn(entity.RunCallback, entity, "OnDamagePlayer", newHealth)
end

local function GetNodesFromRoom(room: Model, reversed: boolean): { BasePart }
	local nodes = {}
	local roomEntrance = room:FindFirstChild("RoomEntrance")
	if roomEntrance then
		local n = roomEntrance:Clone()
		n.Name = "0"
		n.CFrame -= Vector3.new(0, 3, 0)
		nodes[1] = n
	end

	local nodesFolder = room:FindFirstChild("PathfindNodes")
	if nodesFolder then
		for _, n in next, nodesFolder:GetChildren() do
			nodes[#nodes + 1] = n
		end
	end

	local roomExit = room:FindFirstChild("RoomExit")
	if roomExit then
		local index = #nodes + 1
		local n = roomExit:Clone()
		n.Name = index
		n.CFrame -= Vector3.new(0, 3, 0)
		nodes[index] = n
	end

	table.sort(nodes, function(a: BasePart, b: BasePart)
        if reversed then
            return tonumber(a.Name) > tonumber(b.Name)
        else
            return tonumber(a.Name) < tonumber(b.Name)
        end
	end)

	return nodes
end

local function GetPathfindNodesAmbush(config: any): { BasePart }
	local pathfindNodes = {}
    local rooms = CurrentRooms:GetChildren()
    if config.Movement.Reversed == false then
        for i = 1, #rooms, 1 do
            local room = rooms[i]
            local roomNodes = GetNodesFromRoom(room, false)
            for _, node in next, roomNodes do
                pathfindNodes[#pathfindNodes + 1] = node
            end
        end
    else
        for i = #rooms, 1, -1 do
            local room = rooms[i]
            local roomNodes = GetNodesFromRoom(room, true)
            for _, node in next, roomNodes do
                pathfindNodes[#pathfindNodes + 1] = node
            end
        end
    end
	return pathfindNodes
end

local function GetPathfindNodesBlitz(config: any): ({BasePart}, {BasePart})
	local nodesToCurrent, nodesToEnd = {}, {}
	local currentRoomIndex = LocalPlayer:GetAttribute("CurrentRoom")
    local rooms = CurrentRooms:GetChildren()

    if config.Movement.Reversed == false then
        for _, room in next, rooms do
            local roomNodes = GetNodesFromRoom(room, false)
            local roomIndex = tonumber(room.Name)
    
            for _, node in next, roomNodes do
                if roomIndex <= currentRoomIndex then
                    nodesToCurrent[#nodesToCurrent + 1] = node
                else
                    nodesToEnd[#nodesToEnd + 1] = node
                end
            end
        end
    else
        for i = #rooms, 1, -1 do
            local room = rooms[i]
            local roomNodes = GetNodesFromRoom(room, true)
            local roomIndex = tonumber(room.Name)
    
            for _, node in next, roomNodes do
                if roomIndex >= currentRoomIndex then
                    nodesToCurrent[#nodesToCurrent + 1] = node
                else
                    nodesToEnd[#nodesToEnd + 1] = node
                end
            end
        end 
    end

	return nodesToCurrent, nodesToEnd
end

local function EntityMoveTo(model: Model, cframe: CFrame, speed: number)
	local reached = false
	local connection; connection = RunService.Stepped:Connect(function(_, step)
		if not model:GetAttribute("Paused") then
			local pivot = model:GetPivot()
			local difference = (cframe.Position - pivot.Position)
			local unit = difference.Unit
			local magnitude = difference.Magnitude

			if magnitude > 0.1 then
				model:PivotTo(pivot + unit * math.min(step * speed, magnitude))
			else
				connection:Disconnect()
				reached = true
			end
		end
	end)
	repeat RunService.Stepped:Wait() until reached
end

-- \\ Setup // --

for name, value in next, CONST.ATTR.PLAYER do
	LocalPlayer:SetAttribute(name, value)
end

LastRespawn = tick() - LocalPlayer:GetAttribute("SpawnProtection")

LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)

-- \\ Main // --

Module.Create = function(self, config: any): any?
    local newConfig = ApplyConfigDefaults(config, CONST.DEFAULT.CONFIG)
    newConfig.Movement.Speed = CONST.BASE_ENTITY_SPEED / 100 * config.Movement.Speed

    -- Fetch entity model
    local asset = newConfig.Entity.Asset
    local success, entityModel = false, nil

    if typeof(asset) == "Instance" then
        success, entityModel = true, asset
    elseif typeof(asset) == "string" then
        success, entityModel = pcall(function()
			local instance: Instance? = LoadCustomInstance(asset)
			if typeof(instance) == "Instance" then
                if instance.ClassName ~= "Model" then
                    error(string.format(
                        debug.traceback("Entity model Instance invalid, expected Model but got '%s'"),
                        instance.ClassName
                    ))
                    return
                end
			else
				error(debug.traceback("Failed to fetch entity model."))
				return
			end
			return instance
		end)
    end
    if not (success and entityModel) then return end

    -- Entity model preparations
    local rootPart = entityModel.PrimaryPart or entityModel:FindFirstChildWhichIsA("BasePart", true)
    if not rootPart then return end

    rootPart.Anchored = true
    entityModel.PrimaryPart = rootPart

    local name = config.Entity.Name
    if typeof(name) == "string" and name ~= "" then
        entityModel.Name = name
    end

    for attr, val in next, CONST.ATTR.ENTITY do
        entityModel:SetAttribute(attr, val)
    end

    local c = Instance.new("Configuration")
    c.Name = "RoomsEntered"
    c.Parent = entityModel

    return {
        Model = entityModel,
        Config = newConfig,
        Debug = CloneTable(CONST.DEFAULT.DEBUG),
        SetCallback = function(self, key: string, callback: any)
            assert(typeof(key) == "string" and self.Debug[key], debug.traceback("Callback key is invalid."))
            assert(typeof(callback) == "function", debug.traceback("Callback must be a function."))
            if self.Debug[key] then
                self.Debug[key] = callback
            end
        end,
        RunCallback = function(self, key: string, ...: any?)
            local callback = self.Debug[key]
            if typeof(callback) == "function" then
                local success, result = pcall(callback, ...)
                if not success then
                    error(debug.traceback(
                        string.format(
                            "Error in callback: '%s' for entity: '%s':\n%s",
                            key,
                            self.Config.Entity.Name,
                            result
                        )
                    ))
                end
            end
        end,
        IsAlive = function(self): boolean
            return self.Model and self.Model.Parent
        end,
        Pause = function(self)
            if self:IsAlive() then
                self.Model:SetAttribute("Paused", true)
            end
        end,
        Resume = function(self)
            if self:IsAlive() then
                self.Model:SetAttribute("Paused", false)
            end
        end,
        Run = function(self, copyEntity: boolean)
            Module:Run(self, copyEntity)
        end,
        Despawn = function(self)
            if self:IsAlive() then
                self.Model:Destroy()
                local i = table.find(Module.ActiveEntities, self)
                if i then
                    table.remove(Module.ActiveEntities, i)
                end
                task.spawn(self.RunCallback, self, "OnDespawned")
            end
        end
    }
end

Module.Run = function(self, entity: any, copyEntity: boolean)
    if copyEntity == true then
        self:Run(CloneTable(entity), false)
        return
    end

    -- Pre-run checks
    if entity.Model:GetAttribute("Running") then return end
    do
        local rebounding = entity.Config.Rebounding
        if
            rebounding.Enabled
            and (
                rebounding.Min <= 0
                or rebounding.Max <= 0
                or rebounding.Min > rebounding.Max
            )
        then
            error(string.format(
                debug.traceback("Invalid rebounding minmax values: %s - %s"),
                rebounding.Min,
                rebounding.Max
            ))
        end
    end

    -- Setup
    local model = entity.Model
    local config = entity.Config
    local debug = entity.Debug

    model:SetAttribute("Running", true)
    self.ActiveEntities[#self.ActiveEntities + 1] = entity

    -- Spawning
    local spawnPoint: BasePart? = nil
    do
        local rooms = CurrentRooms:GetChildren()
        if config.Movement.Reversed then
            spawnPoint = rooms[#rooms]:FindFirstChild("RoomExit")
        else
            spawnPoint = rooms[1]:FindFirstChild("RoomEntrance")
        end
    end
    if not spawnPoint then
        error(string.format(debug.traceback("Failed to find spawn point for entity: '%s'"), config.Entity.Name))
    end

    model:PivotTo(spawnPoint.CFrame + Vector3.new(0, config.Entity.HeightOffset, 0))
    model.Parent = workspace
    task.spawn(entity.RunCallback, entity, "OnSpawned")

    local currentRoom = GetCurrentRoom(false)
    if currentRoom then
        -- Flickering lights
        if config.Lights.Flicker.Enabled then
            Modules.Module_Events.flicker(currentRoom, config.Lights.Flicker.Duration)
        end

        -- Earthquake
        if config.Earthquake.Enabled then
            task.defer(Modules.Earthquake, Modules.Main_Game, currentRoom)
        end
    end
    
    task.wait(config.Movement.Delay)

    -- Movement
    task.spawn(entity.RunCallback, entity, "OnStartMoving")
    task.spawn(function()
        while
            entity:IsAlive()
            and task.wait()
        do
            if model:GetAttribute("Paused") then continue end
            
            local origin = model:GetPivot().Position
            local charOrigin = CollisionPart.Position
            
            -- In Sight detection
            local inSight = false
            if (charOrigin - origin).Magnitude <= config.Damage.Range then
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = {Character, model}

                inSight = workspace:Raycast(origin, charOrigin - origin, params) == nil
            end

            -- Look detection
            if Humanoid.Health > 0 then
                local _, isVisible = Camera:WorldToViewportPoint(origin)
                if isVisible then
                    task.spawn(entity.RunCallback, entity, "OnLookAt", inSight)
                end
            end

            -- Room detection
            do
                local room = GetRoomAtPoint(origin)
                if room then
                    local index = tonumber(room.Name)
                    if
                        index
                        and index >= 0
                        and index ~= model:GetAttribute("LastEnteredRoom")
                    then
                        model:SetAttribute("LastEnteredRoom", index)

                        local roomsEntered = model:FindFirstChild("RoomsEntered") :: Folder
                        if roomsEntered then
                            local firstTime = roomsEntered:GetAttribute(room.Name) == nil
                            
                            task.spawn(entity.RunCallback, entity, "OnEnterRoom", room, firstTime)

                            if firstTime then
                                roomsEntered:SetAttribute(room.Name, true)
                            end
                            
                            local latestRoom = GetCurrentRoom(true)
                            if room ~= latestRoom then
                                if config.Lights.Shatter then
                                    Modules.Module_Events.shatter(room)
                                elseif config.Lights.Repair then
                                    FixRoomLights(room)
                                end
                            end
                        end
                    end
                end
            end

            -- Crucifix detection
            local usedCrucifix = false
            do
                local crucifixion = config.Crucifixion
                if
                    crucifixion.Enabled
                    and crucifixion.Range > 0
                    and (charOrigin - origin).Magnitude <= crucifixion.Range
                    and inSight
                then
                    local hasTool, tool = PlayerHasItemEquipped("Crucifix")
                    if hasTool and tool and not model:GetAttribute("BeingBanished") then
                        if typeof(debug.CrucifixionOverwrite) == "function" then
                            -- Use custom crucifixion callback
                            entity:RunCallback("CrucifixionOverwrite")
                        else
                            model:SetAttribute("Paused", true)
                            CrucifixEntity(entity, tool)
                        end
                        usedCrucifix = true
                    end
                end
            end

            -- Damage detection
            if
                not model:GetAttribute("Paused")
                and not usedCrucifix
            then
                local damage = config.Damage
                if
                    damage.Enabled
                    and damage.Range > 0
                    and Humanoid.Health > 0
                    and not Character:GetAttribute("Hiding")
                    and model:GetAttribute("Damage")
                    and not model:GetAttribute("BeingBanished")
                    and (charOrigin - origin).Magnitude <= damage.Range
                    and inSight
                then
                    model:SetAttribute("Damage", false)
                    DamagePlayer(entity)
                end
            end

            -- Camera shake
            do
                local camShake = config.CameraShake
                if camShake.Enabled then
                    local mag = (charOrigin - origin).Magnitude
                    if mag <= camShake.Range then
                        local cloned = {}
                        for i, v in next, camShake.Values do
                            cloned[i] = v
                        end

                        cloned[1] = camShake.Values[1] / camShake.Range * (camShake.Range - mag) -- Magnitude
                        cloned[2] = camShake.Values[2] / camShake.Range * (camShake.Range - mag) -- Roughness
                        Modules.Main_Game.camShaker:ShakeOnce(table.unpack(cloned))
                    end
                end
            end
        end
    end)

    -- Pathfinding
    task.spawn(function()
        local reboundType = config.Rebounding.Type:upper()
        if reboundType == "AMBUSH" then
            local pathfindNodes = GetPathfindNodesAmbush(config)
            for _, v in next, pathfindNodes do
                local cframe = v.CFrame + Vector3.new(0, 3 + config.Entity.HeightOffset, 0)
                EntityMoveTo(model, cframe, config.Movement.Speed)
                task.spawn(entity.RunCallback, entity, "OnReachNode", v)
            end
            
            -- Rebounding handling
            if config.Rebounding.Enabled then
                local reboundsCount = math.random(config.Rebounding.Min, config.Rebounding.Max)
                for i = 1, reboundsCount do
                    task.wait(config.Rebounding.Delay)
                    model:SetAttribute("Damage", true)
                    task.spawn(entity.RunCallback, entity, "OnRebounding", true)

                    -- Run backwards through nodes
                    for i = #pathfindNodes, 1, -1 do
                        local v = pathfindNodes[i]
                        local cframe = v.CFrame + Vector3.new(0, 3 + config.Entity.HeightOffset, 0)
                        EntityMoveTo(model, cframe, config.Movement.Speed)
                        task.spawn(entity.RunCallback, entity, "OnReachNode", v)
                    end

                    task.spawn(entity.RunCallback, entity, "OnRebounding", false)
                    task.wait(config.Rebounding.Delay)
                    model:SetAttribute("Damage", true)
                    task.spawn(entity.RunCallback, entity, "OnRebounding", true)
                    pathfindNodes = GetPathfindNodesAmbush(config)

                    -- Run forwards through nodes
                    for _, v in next, pathfindNodes do
                        local cframe = v.CFrame + Vector3.new(0, 3 + config.Entity.HeightOffset, 0)
                        EntityMoveTo(model, cframe, config.Movement.Speed)
                        task.spawn(entity.RunCallback, entity, "OnReachNode", v)
                    end

                    task.spawn(entity.RunCallback, entity, "OnRebounding", false)

                    -- Delay unless last rebound
                    if i < reboundsCount then
                        task.wait(config.Rebounding.Delay)
                    end
                end
            end
        elseif reboundType == "BLITZ" then
            local nodesToCurrent, _ = GetPathfindNodesBlitz(config)
	
            for _, n in next, nodesToCurrent do
                local cframe = n.CFrame + Vector3.new(0, 3 + config.Entity.HeightOffset, 0)
                EntityMoveTo(model, cframe, config.Movement.Speed)
                task.spawn(entity.RunCallback, entity, "OnReachNode", n)
            end
            
            -- Rebound handling
            if config.Rebounding.Enabled then
                local currentRoom = GetCurrentRoom(false)
                if not currentRoom then
                    warn(debug.traceback("Failed to obtain current room."))
                    return
                end

                local roomNodes = GetNodesFromRoom(currentRoom, config.Movement.Reversed)
                if #roomNodes == 1 then
                    warn(debug.traceback("Failed to obtain current room."))
                    return
                end

                local randomNode: BasePart? = nil;
                if config.Movement.Reversed == false then
                    randomNode = roomNodes[math.random(1, #roomNodes - 1)]
                else
                    randomNode = roomNodes[math.random(2, #roomNodes)]
                end
                if not randomNode then
                    warn(debug.traceback("Failed to obtain current room Blitz node."))
                    return
                end

                for _ = 1, math.random(config.Rebounding.Min, config.Rebounding.Max) do
                    model:SetAttribute("Damage", true)
                    task.spawn(entity.RunCallback, entity, "OnRebounding", true)
                    
                    local nodeIndex = tonumber(randomNode.Name)
                    for i = #roomNodes, nodeIndex, -1 do
                        local cframe = roomNodes[math.clamp(i, 1, #roomNodes)].CFrame + Vector3.new(0, 3 + config.Entity.HeightOffset, 0)
                        EntityMoveTo(model, cframe, config.Movement.Speed)
                        task.spawn(entity.RunCallback, entity, "OnReachNode", roomNodes[i])
                    end
                    
                    task.wait(config.Rebounding.Delay)
                    model:SetAttribute("Damage", true)
                    task.spawn(entity.RunCallback, entity, "OnRebounding", false)

                    for i = nodeIndex, #roomNodes do
                        local cframe = roomNodes[math.clamp(i, 1, #roomNodes)].CFrame + Vector3.new(0, 3 + config.Entity.HeightOffset, 0)
                        EntityMoveTo(model, cframe, config.Movement.Speed)
                        task.spawn(entity.RunCallback, entity, "OnReachNode", roomNodes[i])
                    end
                end
            end
            
            local _, updatedToEnd = GetPathfindNodesBlitz(config)
            for _, n in next, updatedToEnd do
                local cframe = n.CFrame + Vector3.new(0, 3 + config.Entity.HeightOffset, 0)
                EntityMoveTo(model, cframe, config.Movement.Speed)
                task.spawn(entity.RunCallback, entity, "OnReachNode", n)
            end
        end

        -- Despawning
        if not model:GetAttribute("Despawning") then
            model:SetAttribute("Despawning", true)
            task.spawn(entity.RunCallback, entity, "OnDespawning")
            EntityMoveTo(model, model:GetPivot() - Vector3.new(0, 300, 0), config.Movement.Speed)
            entity:Despawn()
        end
    end)
end

if not getgenv()._internal_vynixu_entity_spawner then
	getgenv()._internal_vynixu_entity_spawner = true

	local function GetAmbient(room: Model): Color3
		return
            room:GetAttribute("AmbientOriginal") :: Color3
            or room:GetAttribute("Ambient") :: Color3
            or Color3.fromRGB(67, 51, 56)
	end

	for _, room in next, CurrentRooms:GetChildren() do
		Storage.Ambient[room] = GetAmbient(room)
	end

	CurrentRooms.ChildAdded:Connect(function(room: Model)
		Storage.Ambient[room] = GetAmbient(room)
	end)
	
	workspace.DescendantRemoving:Connect(function(instance: Instance)
		if instance.Name == "PathfindNodes" then
			instance:Clone().Parent = instance.Parent
		end
	end)
end

Modules.Clear = function(self)
    for _, entity in next, self.ActiveEntities do
        entity:Despawn()
    end
end

Module.Unload = function(self)
    self:Clear()
    for i, v in self.Connections do
        v:Disconnect()
        self.Connections[i] = nil
    end
    for i in next, self do
        self[i] = nil
    end
end

getgenv().VynixuEntitySpawnerV2 = Module
return Module