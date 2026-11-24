-- Hiệu ứng chạy ở máy người chơi: đội bot bay theo mọi người chơi (đọc attribute "Bots"),
-- tia laser bot bắn, vòng Pulse, số sát thương, nổ, hút data, lên level, hào quang kỹ năng.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Effects = {}

local fxFolder = Instance.new("Folder")
fxFolder.Name = "ClientFx"
fxFolder.Parent = workspace

local squads = {} -- [player] = { key = "Scout:1,...", bots = { model ... } }

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		p[key] = value
	end
	p.Parent = props.Parent or fxFolder
	return p
end

local function fadeAndDestroy(inst, duration, goal)
	local tween = TweenService:Create(inst, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tween.Completed:Connect(function()
		inst:Destroy()
	end)
	tween:Play()
end

-- ================= Đội bot =================

-- 1 bot: thân cầu + mắt neon + vòng cánh quạt + vệt sáng (Trail)
local function makeBot(bot, level)
	local model = Instance.new("Model")
	model.Name = bot.name
	local size = bot.size * (1 + (level - 1) * 0.04)
	local body = part({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.one * size, Color = Color3.fromRGB(240, 242, 250), Material = Enum.Material.SmoothPlastic, Parent = model })
	local eye = part({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.42, Color = bot.color, Material = Enum.Material.Neon, Parent = model })
	local ring = part({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, size * 1.7, size * 1.7), Color = bot.color, Material = Enum.Material.Neon, Transparency = 0.45, Parent = model })
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0, size * 0.3)
	a0.Parent = body
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0, -size * 0.3)
	a1.Parent = body
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(bot.color)
	trail.LightEmission = 1
	trail.Lifetime = 0.35
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = body
	local light = Instance.new("PointLight")
	light.Color = bot.color
	light.Range = 6
	light.Brightness = 1.2
	light.Parent = eye
	if bot.rarity == "Legendary" or bot.rarity == "Epic" then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(bot.color)
		sparkle.LightEmission = 1
		sparkle.Rate = 6
		sparkle.Lifetime = NumberRange.new(0.5, 1)
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0) })
		sparkle.Parent = body
	end
	model.PrimaryPart = body
	model.Parent = fxFolder
	return { model = model, body = body, eye = eye, ring = ring, size = size, color = bot.color, pos = nil, phase = math.random() * 6 }
end

local function rebuildSquad(player)
	local key = player:GetAttribute("Bots") or ""
	local squad = squads[player]
	if squad and squad.key == key then
		return
	end
	if squad then
		for _, b in squad.bots do
			b.model:Destroy()
		end
	end
	squad = { key = key, bots = {} }
	for entry in key:gmatch("[^,]+") do
		local id, level = entry:match("(%w+):(%d+)")
		local bot = id and Config.BotById[id]
		if bot then
			table.insert(squad.bots, makeBot(bot, tonumber(level)))
		end
	end
	squads[player] = squad
end

local function watchPlayer(player)
	rebuildSquad(player)
	player:GetAttributeChangedSignal("Bots"):Connect(function()
		rebuildSquad(player)
	end)
end

-- bot bay quanh sau lưng chủ thành vòng cung, nhún nhẹ, mắt nhìn về hướng chủ đang nhìn
local function updateSquads(dt)
	local t = os.clock()
	for player, squad in squads do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not player.Parent then
			for _, b in squad.bots do
				b.model:Destroy()
			end
			squads[player] = nil
		elseif root then
			local count = #squad.bots
			for i, b in squad.bots do
				local angle = math.rad(-70 + (i - 0.5) / math.max(count, 1) * 140)
				local radius = 5 + (i % 2) * 1.5
				local offset = Vector3.new(math.sin(angle) * radius, 3.5 + math.sin(t * 3 + b.phase) * 0.6, math.cos(angle) * radius)
				local target = (root.CFrame * CFrame.new(offset)).Position
				b.pos = if b.pos then b.pos:Lerp(target, math.min(1, dt * 6)) else target
				local look = root.CFrame.LookVector
				local cf = CFrame.lookAt(b.pos, b.pos + look)
				b.body.CFrame = cf
				b.eye.CFrame = cf * CFrame.new(0, 0, -b.size * 0.32)
				b.ring.CFrame = cf * CFrame.Angles(0, t * 6 + b.phase, 0) * CFrame.Angles(0, 0, math.pi / 2)
			end
		end
	end
end

-- ================= Hiệu ứng đánh / thu thập =================

local function laser(from, to, color)
	local dist = (to - from).Magnitude
	local beam = part({ Size = Vector3.new(0.25, 0.25, dist), CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2), Color = color, Material = Enum.Material.Neon })
	fadeAndDestroy(beam, 0.2, { Transparency = 1, Size = Vector3.new(0.05, 0.05, dist) })
end

local function floatingText(position, text, color, size)
	local anchor = part({ Size = Vector3.one * 0.1, CFrame = CFrame.new(position), Transparency = 1 })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansExtraBold
	label.TextSize = size or 24
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	gui.Parent = anchor
	TweenService:Create(anchor, TweenInfo.new(0.8), { CFrame = CFrame.new(position + Vector3.new(math.random(-15, 15) / 10, 4, 0)) }):Play()
	fadeAndDestroy(label, 0.8, { TextTransparency = 1, TextStrokeTransparency = 1 })
	task.delay(0.85, function()
		anchor:Destroy()
	end)
end

local function ring(position, radius, color, duration)
	local disc = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2, 2), CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), Color = color, Material = Enum.Material.Neon, Transparency = 0.2 })
	fadeAndDestroy(disc, duration or 0.4, { Size = Vector3.new(0.3, radius * 2, radius * 2), Transparency = 1 })
end

local function burst(position, color, size)
	local ball = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1, CFrame = CFrame.new(position), Color = color, Material = Enum.Material.Neon, Transparency = 0.1 })
	fadeAndDestroy(ball, 0.45, { Size = Vector3.one * (size or 8), Transparency = 1 })
end

local handlers = {}

function handlers.Pulse(position, radius)
	ring(position - Vector3.new(0, 2, 0), radius, Color3.fromRGB(0, 220, 255), 0.4)
	burst(position, Color3.fromRGB(150, 240, 255), 6)
end

function handlers.Damage(position, amount)
	floatingText(position, Config.Short(amount), Color3.fromRGB(255, 230, 120), 22)
end

function handlers.Explode(position, color, isBoss)
	burst(position, color, if isBoss then 30 else 10)
	ring(position, if isBoss then 30 else 10, color, 0.5)
end

function handlers.Harvest(position, color, amount)
	burst(position, color, 5)
	if amount and amount > 0 then
		floatingText(position + Vector3.new(0, 2, 0), "+" .. Config.Short(amount) .. " 💾", color, 22)
	end
end

function handlers.Gather(player, color)
	local squad = squads[player]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if squad and root then
		-- bot quét tia xuống đất như đang hút data
		for _, b in squad.bots do
			if b.pos and math.random() < 0.5 then
				laser(b.pos, root.Position + Vector3.new(math.random(-6, 6), -3, math.random(-6, 6)), color)
			end
		end
	end
end

function handlers.BotShot(player, target)
	local squad = squads[player]
	if squad then
		for _, b in squad.bots do
			if b.pos then
				laser(b.pos, target, b.color)
			end
		end
	end
end

function handlers.LevelUp(position)
	ring(position - Vector3.new(0, 2.5, 0), 14, Color3.fromRGB(255, 220, 60), 0.8)
	burst(position, Color3.fromRGB(255, 240, 150), 12)
end

function handlers.Aura(player, color, duration)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local aura = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 8, CFrame = root.CFrame, Color = color, Material = Enum.Material.ForceField, Transparency = 0.2 })
	local conn = RunService.RenderStepped:Connect(function()
		if root.Parent then
			aura.CFrame = root.CFrame
		end
	end)
	task.delay(duration, function()
		conn:Disconnect()
		aura:Destroy()
	end)
end

Effects.OnHurt = nil -- Main gán: chớp đỏ màn hình khi chính mình bị đánh

function handlers.Hurt(player)
	if player == Players.LocalPlayer and Effects.OnHurt then
		Effects.OnHurt()
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		burst(root.Position, Color3.fromRGB(255, 60, 60), 4)
	end
end

function Effects.Start(fxRemote)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	RunService.RenderStepped:Connect(updateSquads)
	fxRemote.OnClientEvent:Connect(function(kind, ...)
		local handler = handlers[kind]
		if handler then
			handler(...)
		end
	end)
end

return Effects
