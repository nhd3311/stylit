-- Thế giới: nền Terrain, Hub (trạm upload, Bot Forge, robot Unit-0), 3 vùng nối nhau bằng đường,
-- cổng level, tinh thể data (thu thập tay), cây/đá/tháp neon trang trí.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Visuals = require(script.Parent.Visuals)

local WorldService = {}

local world -- Folder chứa mọi thứ
local nodes = {} -- [part] = { zone, active }
local random = Random.new(42)

-- callback cho PlayerService khi người chơi bấm E ở các trạm
WorldService.OnUpload = nil
WorldService.OnOpen = nil -- (player, panelName)

local function prompt(parent, objectText, actionText, distance)
	local p = Instance.new("ProximityPrompt")
	p.ObjectText = objectText
	p.ActionText = actionText
	p.HoldDuration = 0
	p.MaxActivationDistance = distance or 12
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

-- ================= Địa hình =================

local function buildTerrain()
	local terrain = workspace.Terrain
	-- nền cỏ toàn map (mặt trên ở y = 0)
	terrain:FillBlock(CFrame.new(0, -5, -330), Vector3.new(800, 10, 1000), Enum.Material.Grass)
	-- nền từng vùng
	for _, zone in Config.Zones do
		terrain:FillBlock(CFrame.new(zone.center + Vector3.new(0, -1, 0)), Vector3.new(zone.size, 2.2, zone.size), zone.terrain)
	end
	-- đường lát từ Hub chạy qua các vùng
	terrain:FillBlock(CFrame.new(0, -0.9, -380), Vector3.new(14, 2, 760), Enum.Material.Pavement)
	-- đồi bao quanh hai bên cho có cảm giác thung lũng
	for i = 0, 11 do
		local z = 40 - i * 75
		for _, side in { -1, 1 } do
			terrain:FillBall(Vector3.new(side * random:NextNumber(230, 280), -20, z), random:NextNumber(55, 80), if i % 3 == 0 then Enum.Material.Rock else Enum.Material.Grass)
		end
	end
	-- vách đá Circuit Canyon
	local canyon = Config.ZoneById.Canyon
	for _, side in { -1, 1 } do
		for i = -3, 3 do
			terrain:FillBall(canyon.center + Vector3.new(side * (canyon.size / 2 + 6), 4, i * 24), random:NextNumber(14, 20), Enum.Material.Sandstone)
		end
	end
end

-- ================= Trang trí =================

local function tree(position, scale)
	Visuals.Part({ Name = "Trunk", Size = Vector3.new(1.4, 6, 1.4) * scale, CFrame = CFrame.new(position + Vector3.new(0, 3 * scale, 0)), Color = Color3.fromRGB(110, 75, 50), Material = Enum.Material.Wood, Parent = world })
	for i, h in { 6.5, 9, 11.2 } do
		Visuals.Part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (7 - i * 1.6) * scale,
			CFrame = CFrame.new(position + Vector3.new(0, h * scale, 0)),
			Color = Color3.fromRGB(70 + i * 15, 170 + i * 10, 80),
			Material = Enum.Material.Grass,
			CanCollide = false,
			Parent = world,
		})
	end
end

local function rock(position, scale)
	Visuals.Part({
		Name = "Rock",
		Size = Vector3.new(4, 3, 3.4) * scale,
		CFrame = CFrame.new(position + Vector3.new(0, 1.2 * scale, 0)) * CFrame.Angles(random:NextNumber(-0.3, 0.3), random:NextNumber(0, 6), random:NextNumber(-0.3, 0.3)),
		Color = Color3.fromRGB(170, 130, 90),
		Material = Enum.Material.Slate,
		Parent = world,
	})
end

local function spire(position, height, color)
	local s = Visuals.Part({ Name = "Spire", Size = Vector3.new(3, height, 3), CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = Color3.fromRGB(30, 25, 50), Material = Enum.Material.Glass, Reflectance = 0.2, Parent = world })
	local cap = Visuals.Part({ Name = "SpireNeon", Size = Vector3.new(3.4, 1, 3.4), CFrame = s.CFrame * CFrame.new(0, height / 2, 0), Color = color, Material = Enum.Material.Neon, CanCollide = false, Parent = world })
	cap:SetAttribute("Blink", true)
	Visuals.Light(cap, color, 22, 2)
end

-- cổng vào vùng: 2 trụ + thanh ngang + biển tên, khoá level hiện trên biển
local function zoneGate(zone)
	local z = zone.center.Z + zone.size / 2
	local color = zone.crystal
	for _, x in { -12, 12 } do
		local pillar = Visuals.Part({ Name = "GatePillar", Size = Vector3.new(3, 18, 3), CFrame = CFrame.new(x, 9, z), Color = Color3.fromRGB(40, 44, 60), Material = Enum.Material.Metal, Parent = world })
		Visuals.Part({ Name = "GateGlow", Size = Vector3.new(0.6, 17, 3.2), CFrame = pillar.CFrame * CFrame.new(-math.sign(x) * 1.7, 0, 0), Color = color, Material = Enum.Material.Neon, CanCollide = false, Parent = world })
	end
	local beam = Visuals.Part({ Name = "GateBeam", Size = Vector3.new(27, 2.4, 3), CFrame = CFrame.new(0, 19, z), Color = color, Material = Enum.Material.Neon, Parent = world })
	Visuals.Light(beam, color, 30, 2.5)
	local lock = if zone.level > 1 then string.format("\n<font size='22' color='#FFD84D'>🔒 Level %d</font>", zone.level) else ""
	Visuals.Label(beam, string.format("%s %s%s", zone.emoji, string.upper(zone.name), lock), UDim2.fromScale(30, 7), Vector3.new(0, 5, 0), Color3.new(1, 1, 1), 400)
end

-- ================= Tinh thể data =================

local function setNode(part, active)
	nodes[part].active = active
	part.Transparency = if active then 0.15 else 1
	part.PointLight.Enabled = active
	part.Sparks.Enabled = active
end

-- Lấy tinh thể còn data gần `position` nhất trong bán kính `range`
function WorldService.NearestNode(position, range)
	local best, bestDist
	for part, info in nodes do
		if info.active then
			local dist = (part.Position - position).Magnitude
			if dist <= range and (not bestDist or dist < bestDist) then
				best, bestDist = part, dist
			end
		end
	end
	return best, best and nodes[best].zone
end

-- Thu thập 1 tinh thể: tắt đi rồi tự mọc lại sau NodeRespawn giây
function WorldService.HarvestNode(part)
	if not nodes[part] or not nodes[part].active then
		return false
	end
	setNode(part, false)
	task.delay(Config.NodeRespawn, function()
		if nodes[part] then
			setNode(part, true)
		end
	end)
	return true
end

local function buildNodes(zone)
	for _ = 1, zone.nodes do
		local offset = Vector3.new(random:NextNumber(-0.42, 0.42) * zone.size, 0, random:NextNumber(-0.42, 0.42) * zone.size)
		if math.abs(offset.X) < 9 then
			offset += Vector3.new(14, 0, 0) -- chừa đường đi ở giữa
		end
		local crystal = Visuals.Part({
			Name = "DataNode",
			Size = Vector3.new(2.2, 4.5, 2.2),
			CFrame = CFrame.new(zone.center + offset + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, random:NextNumber(0, 6), math.rad(random:NextNumber(-12, 12))),
			Color = zone.crystal,
			Material = Enum.Material.Neon,
			Transparency = 0.15,
			CanCollide = false,
			Parent = world,
		})
		Visuals.Light(crystal, zone.crystal, 10, 1.5)
		Visuals.Particles(crystal, zone.crystal, 3).Name = "Sparks"
		crystal:SetAttribute("Spin", 0.8)
		nodes[crystal] = { zone = zone, active = true }
	end
end

-- ================= Hub =================

local function buildHub()
	local c = Config.Hub.center
	Visuals.Part({ Name = "Plaza", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, Config.Hub.radius * 2, Config.Hub.radius * 2), CFrame = CFrame.new(c + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(210, 215, 225), Material = Enum.Material.Pavement, Parent = world })
	Visuals.Part({ Name = "PlazaRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.1, 30, 30), CFrame = CFrame.new(c + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(0, 210, 255), Material = Enum.Material.Neon, Transparency = 0.5, CanCollide = false, Parent = world })

	-- Trạm upload: tháp trung tâm có vòng hologram quay
	local tower = Visuals.Part({ Name = "UploadTower", Size = Vector3.new(8, 22, 8), CFrame = CFrame.new(c + Vector3.new(0, 11, -18)), Color = Color3.fromRGB(35, 40, 60), Material = Enum.Material.Metal, Parent = world })
	local core = Visuals.Part({ Name = "UploadCore", Shape = Enum.PartType.Ball, Size = Vector3.one * 7, CFrame = CFrame.new(c + Vector3.new(0, 27, -18)), Color = Color3.fromRGB(0, 220, 255), Material = Enum.Material.Neon, CanCollide = false, Parent = world })
	Visuals.Light(core, core.Color, 40, 3)
	Visuals.Particles(core, core.Color, 12)
	for i, tilt in { 0.4, -0.5 } do
		local ring = Visuals.Part({ Name = "Ring" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 13, 13), CFrame = core.CFrame * CFrame.Angles(tilt, 0, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(150, 240, 255), Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false, Parent = world })
		ring:SetAttribute("Spin", if i == 1 then 1.2 else -0.9)
	end
	Visuals.Label(tower, "📡 UPLOAD STATION", UDim2.fromScale(20, 4), Vector3.new(0, 20, 0), Color3.fromRGB(150, 240, 255), 250)
	local pad = Visuals.Part({ Name = "UploadPad", Size = Vector3.new(16, 0.6, 8), CFrame = CFrame.new(c + Vector3.new(0, 0.6, -10)), Color = Color3.fromRGB(0, 200, 255), Material = Enum.Material.Neon, Transparency = 0.3, Parent = world })
	prompt(pad, "Upload Station", "Upload Data", 14).Triggered:Connect(function(player)
		if WorldService.OnUpload then
			WorldService.OnUpload(player)
		end
	end)
	-- bước lên tấm sáng cũng tự upload
	pad.Touched:Connect(function(hit)
		local player = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
		if player and WorldService.OnUpload then
			WorldService.OnUpload(player, true)
		end
	end)

	-- Bot Forge (shop)
	local forge = Visuals.Part({ Name = "BotForge", Size = Vector3.new(18, 12, 12), CFrame = CFrame.new(c + Vector3.new(-26, 6, 6)) * CFrame.Angles(0, math.rad(60), 0), Color = Color3.fromRGB(255, 170, 60), Material = Enum.Material.SmoothPlastic, Parent = world })
	Visuals.Part({ Name = "ForgeSign", Size = Vector3.new(18.2, 2, 12.2), CFrame = forge.CFrame * CFrame.new(0, 5, 0), Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Neon, CanCollide = false, Parent = world })
	Visuals.Label(forge, "🤖 BOT FORGE", UDim2.fromScale(16, 3.5), Vector3.new(0, 10, 0), Color3.fromRGB(255, 220, 140), 250)
	prompt(forge, "Bot Forge", "Shop bots", 16).Triggered:Connect(function(player)
		if WorldService.OnOpen then
			WorldService.OnOpen(player, "Bots")
		end
	end)

	-- Tech Shop (nâng cấp ba lô)
	local tech = Visuals.Part({ Name = "TechShop", Size = Vector3.new(16, 10, 10), CFrame = CFrame.new(c + Vector3.new(26, 5, 6)) * CFrame.Angles(0, math.rad(-60), 0), Color = Color3.fromRGB(90, 140, 255), Material = Enum.Material.SmoothPlastic, Parent = world })
	Visuals.Label(tech, "🎒 GEAR SHOP", UDim2.fromScale(16, 3.5), Vector3.new(0, 9, 0), Color3.fromRGB(180, 210, 255), 250)
	prompt(tech, "Gear Shop", "Upgrade backpack", 16).Triggered:Connect(function(player)
		if WorldService.OnOpen then
			WorldService.OnOpen(player, "Gear")
		end
	end)

	-- Unit-0: robot giao nhiệm vụ
	local body = Visuals.Part({ Name = "Unit0", Size = Vector3.new(3, 4, 2.4), CFrame = CFrame.new(c + Vector3.new(12, 3, 16)), Color = Color3.fromRGB(235, 240, 250), Material = Enum.Material.SmoothPlastic, Parent = world })
	local head = Visuals.Part({ Name = "Unit0Head", Size = Vector3.new(2.6, 2, 2.2), CFrame = body.CFrame * CFrame.new(0, 3.1, 0), Color = Color3.fromRGB(235, 240, 250), Material = Enum.Material.SmoothPlastic, Parent = world })
	Visuals.Part({ Name = "Visor", Size = Vector3.new(2, 0.6, 0.2), CFrame = head.CFrame * CFrame.new(0, 0.1, -1.15), Color = Color3.fromRGB(0, 220, 255), Material = Enum.Material.Neon, CanCollide = false, Parent = world })
	Visuals.Label(head, "🤖 Unit-0\n<font size='16' color='#FFD84D'>❗ Quests</font>", UDim2.fromScale(7, 2.6), Vector3.new(0, 3, 0))
	prompt(body, "Unit-0", "Talk", 12).Triggered:Connect(function(player)
		if WorldService.OnOpen then
			WorldService.OnOpen(player, "Quests")
		end
	end)

	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2
		tree(c + Vector3.new(math.cos(angle) * 52, 0, math.sin(angle) * 52), 1.1)
	end
end

function WorldService.Start()
	Visuals.SetupLighting()
	world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace
	-- Baseplate của place mặc định đè lên Terrain nên bỏ đi
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	buildTerrain()
	buildHub()
	for _, zone in Config.Zones do
		zoneGate(zone)
		buildNodes(zone)
		for _ = 1, 14 do
			local p = zone.center + Vector3.new(random:NextNumber(-0.48, 0.48) * zone.size, 0, random:NextNumber(-0.48, 0.48) * zone.size)
			if math.abs(p.X) > 10 then
				if zone.id == "Meadow" then
					tree(p, random:NextNumber(0.8, 1.4))
				elseif zone.id == "Canyon" then
					rock(p, random:NextNumber(0.8, 2.2))
				else
					spire(p, random:NextNumber(18, 45), zone.crystal)
				end
			end
		end
	end
end

function WorldService.HubSpawn()
	return CFrame.new(Config.Hub.center + Vector3.new(0, 4, 20))
end

return WorldService
