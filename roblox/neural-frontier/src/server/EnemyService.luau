-- Quái: drone nổi loạn ở mỗi vùng + 1 boss/vùng. Bay lơ lửng, thấy người chơi gần thì đuổi theo
-- và đâm gây sát thương. Người chơi hạ quái bằng kỹ năng Pulse và đội bot tự bắn.
-- Boss: ai góp sát thương đều được thưởng khi boss chết.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerService = require(script.Parent.PlayerService)
local Visuals = require(script.Parent.Visuals)

local EnemyService = {}

local STEP = 0.25
local enemies = {} -- danh sách quái
local folder
local random = Random.new()

local function rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function randomPoint(zone)
	return zone.center + Vector3.new(random:NextNumber(-0.4, 0.4) * zone.size, 0, random:NextNumber(-0.4, 0.4) * zone.size)
end

local function updateBar(enemy)
	local ratio = math.clamp(enemy.hp / enemy.maxHp, 0, 1)
	enemy.fill.Size = UDim2.fromScale(ratio, 1)
	enemy.fill.BackgroundColor3 = if ratio > 0.5 then Color3.fromRGB(80, 230, 120) elseif ratio > 0.2 then Color3.fromRGB(255, 200, 60) else Color3.fromRGB(255, 70, 70)
end

local function makeBody(def, size, isBoss)
	local body = Visuals.Part({
		Name = def.name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		Color = Color3.fromRGB(45, 45, 55),
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
	-- mắt neon + 2 cánh
	Visuals.Part({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.45, CFrame = CFrame.new(0, 0, -size * 0.32), Color = def.color, Material = Enum.Material.Neon, CanCollide = false, Parent = body })
	for _, x in { -1, 1 } do
		Visuals.Part({ Name = "Wing", Size = Vector3.new(size * 0.9, size * 0.08, size * 0.4), CFrame = CFrame.new(x * size * 0.75, 0, 0), Color = def.color, Material = Enum.Material.Neon, Transparency = 0.3, CanCollide = false, Parent = body })
	end
	-- các part con đang dùng CFrame tương đối, gắn cố định vào thân
	for _, child in body:GetChildren() do
		if child:IsA("BasePart") then
			child.CFrame = body.CFrame * child.CFrame
			child.Anchored = false
			child.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = child
			weld.Parent = child
		end
	end
	Visuals.Light(body, def.color, size * 2.5, 1.5)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(if isBoss then 260 else 90, if isBoss then 46 else 26)
	gui.StudsOffset = Vector3.new(0, size * 0.8 + 1, 0)
	gui.MaxDistance = if isBoss then 200 else 70
	gui.AlwaysOnTop = isBoss
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0.55, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.BuilderSansExtraBold
	name.TextScaled = true
	name.TextColor3 = if isBoss then Color3.fromRGB(255, 120, 160) else Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.Text = (if isBoss then "👑 " else "") .. def.name
	name.Parent = gui
	local back = Instance.new("Frame")
	back.Position = UDim2.fromScale(0, 0.62)
	back.Size = UDim2.fromScale(1, 0.32)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = back
	gui.Parent = body
	return body, fill
end

local function spawn(enemy)
	enemy.hp = enemy.maxHp
	enemy.home = randomPoint(enemy.zone)
	enemy.alive = true
	enemy.contributors = {}
	enemy.body.CFrame = CFrame.new(enemy.home + Vector3.new(0, enemy.hover, 0))
	enemy.body.Transparency = 0
	for _, child in enemy.body:GetDescendants() do
		if child:IsA("BasePart") then
			child.Transparency = if child.Name == "Wing" then 0.3 else 0
		elseif child:IsA("BillboardGui") or child:IsA("PointLight") then
			child.Enabled = true
		end
	end
	updateBar(enemy)
	enemy.body.Parent = folder
end

local function kill(enemy, killer)
	enemy.alive = false
	PlayerService.Fx("Explode", enemy.body.Position, enemy.def.color, enemy.isBoss)
	enemy.body.Parent = nil
	if enemy.isBoss then
		-- ai góp sát thương đều nhận thưởng
		for player in enemy.contributors do
			if player.Parent then
				PlayerService.OnKill(player, enemy.def, enemy.zone, true)
			end
		end
	elseif killer and killer.Parent then
		PlayerService.OnKill(killer, enemy.def, enemy.zone, false)
	end
	task.delay(if enemy.isBoss then enemy.def.respawn else 8, function()
		spawn(enemy)
		if enemy.isBoss then
			for _, player in Players:GetPlayers() do
				PlayerService.Notify(player, string.format("⚠️ %s has appeared in %s!", enemy.def.name, enemy.zone.name), "Boss")
			end
		end
	end)
end

local function damage(enemy, player, amount)
	if not enemy.alive or amount <= 0 then
		return
	end
	enemy.hp -= amount
	enemy.contributors[player] = true
	PlayerService.Fx("Damage", enemy.body.Position + Vector3.new(0, enemy.hover * 0.3, 0), math.floor(amount))
	if enemy.hp <= 0 then
		kill(enemy, player)
	else
		updateBar(enemy)
	end
end

-- Pulse của người chơi: trúng mọi quái trong bán kính
local function damageArea(player, position, radius, amount)
	for _, enemy in enemies do
		if enemy.alive and (enemy.body.Position - position).Magnitude <= radius + enemy.size / 2 then
			damage(enemy, player, amount)
		end
	end
end

local function nearestEnemy(position, range)
	local best, bestDist
	for _, enemy in enemies do
		if enemy.alive then
			local dist = (enemy.body.Position - position).Magnitude
			if dist <= range and (not bestDist or dist < bestDist) then
				best, bestDist = enemy, dist
			end
		end
	end
	return best
end

local function think(enemy)
	if not enemy.alive then
		return
	end
	local pos = enemy.body.Position
	local target, targetDist
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and Config.ZoneAt(root.Position) == enemy.zone then
			local dist = (root.Position - pos).Magnitude
			if dist <= enemy.aggro and (not targetDist or dist < targetDist) then
				target, targetDist = player, dist
			end
		end
	end
	local goal
	if target then
		local root = rootOf(target)
		goal = root.Position + Vector3.new(0, enemy.hover * 0.5, 0)
		-- đủ gần thì đâm
		if targetDist <= enemy.size / 2 + 4 and os.clock() - enemy.lastHit > 1 then
			enemy.lastHit = os.clock()
			PlayerService.Damage(target, enemy.def.damage)
			PlayerService.Fx("Hurt", target)
		end
	else
		-- không ai gần: bay lòng vòng quanh chỗ xuất hiện
		if not enemy.wander or (enemy.wander - pos).Magnitude < 3 then
			enemy.wander = enemy.home + Vector3.new(random:NextNumber(-14, 14), enemy.hover, random:NextNumber(-14, 14))
		end
		goal = enemy.wander
	end
	local offset = goal - pos
	local step = math.min(offset.Magnitude, enemy.def.speed * STEP)
	if step > 0.05 then
		local nextPos = pos + offset.Unit * step
		local look = Vector3.new(offset.X, 0, offset.Z)
		local cf = if look.Magnitude > 0.1 then CFrame.lookAt(nextPos, nextPos + look) else CFrame.new(nextPos)
		TweenService:Create(enemy.body, TweenInfo.new(STEP, Enum.EasingStyle.Linear), { CFrame = cf }):Play()
	end
end

function EnemyService.Start()
	folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = workspace
	PlayerService.DamageArea = damageArea

	for _, zone in Config.Zones do
		local function add(def, isBoss)
			local size = if isBoss then def.size else 3
			local body, fill = makeBody(def, size, isBoss)
			local enemy = {
				def = def,
				zone = zone,
				isBoss = isBoss,
				size = size,
				hover = if isBoss then size * 0.8 else 4,
				aggro = if isBoss then 70 else 40,
				maxHp = def.hp,
				body = body,
				fill = fill,
				lastHit = 0,
			}
			table.insert(enemies, enemy)
			spawn(enemy)
		end
		for _ = 1, zone.enemy.count do
			add(zone.enemy, false)
		end
		add(zone.boss, true)
	end

	-- AI quái
	task.spawn(function()
		while true do
			task.wait(STEP)
			for _, enemy in enemies do
				think(enemy)
			end
		end
	end)

	-- Đội bot của mỗi người chơi tự bắn quái gần nhất mỗi giây
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local root = rootOf(player)
				if root then
					local enemy = nearestEnemy(root.Position, 26)
					local dps = PlayerService.BotAttack(player)
					if enemy and dps > 0 then
						PlayerService.Fx("BotShot", player, enemy.body.Position)
						damage(enemy, player, dps)
					end
				end
			end
		end
	end)
end

return EnemyService
