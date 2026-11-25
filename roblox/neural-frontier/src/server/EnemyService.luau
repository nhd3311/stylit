-- Quái: mỗi vùng một loài quái có model riêng + 1 boss/vùng. Bay lơ lửng, thấy người chơi gần thì đuổi
-- theo và đâm gây sát thương. Người chơi hạ quái bằng kỹ năng Pulse và đội bot tự bắn.
--   • Server chỉ giữ "thân" vô hình (khung va chạm + thanh máu). Model đẹp do client dựng
--     (shared/EnemyModels + client/Enemies) nên mượt và không tốn băng thông.
--   • Quái ⭐ Elite (1/12): to hơn, ánh vàng, máu x5, thưởng x4, có cơ hội rơi capsule miễn phí.
--   • Boss có 3 phase (giận dữ dần: nhanh hơn, đánh đau hơn) và chiêu có báo trước bằng vòng đỏ
--     dưới đất (Slam / Nova) để người chơi né, phase 2+ gọi đệ. Ai góp sát thương đều được thưởng,
--     và mỗi người có cơ hội nhận bot SECRET của boss đó.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerService = require(script.Parent.PlayerService)

local EnemyService = {}

local STEP = 0.25
local ELITE_CHANCE = 1 / 12
local ELITE = { hp = 5, damage = 1.5, reward = 4, size = 1.4, capsuleChance = 1 / 6 }
local PHASE_AT = { 0.66, 0.33 } -- % máu chuyển sang phase 2 / phase 3
local PHASE_RAGE = { 1, 1.25, 1.5 } -- hệ số tốc độ + sát thương theo phase
local ATTACK_EVERY = { 7, 5.5, 4 } -- giây giữa 2 chiêu theo phase
local TELEGRAPH = 1.4 -- giây báo trước trước khi chiêu nổ
local MAX_MINIONS = 4

local enemies = {} -- danh sách quái (kể cả đệ boss đang sống)
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
	enemy.body:SetAttribute("Hp", math.max(0, enemy.hp))
end

-- thân vô hình: khung va chạm hình cầu + đèn + biển tên/thanh máu. Thuộc tính cho client dựng model.
local function makeBody(def, size, isBoss, elite)
	local body = Instance.new("Part")
	body.Name = def.name
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.one * size
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.CastShadow = false
	body.Transparency = 1
	body:SetAttribute("Model", def.model or "Drone")
	body:SetAttribute("Color", def.color)
	body:SetAttribute("Size", size)
	body:SetAttribute("Boss", isBoss)
	body:SetAttribute("Elite", elite)
	body:SetAttribute("Phase", 1)
	local light = Instance.new("PointLight")
	light.Color = if elite then Color3.fromRGB(255, 210, 80) else def.color
	light.Range = size * 2.5
	light.Brightness = 1.2
	light.Parent = body

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(if isBoss then 260 elseif elite then 130 else 90, if isBoss then 46 else 26)
	gui.StudsOffset = Vector3.new(0, size * 0.95 + 1.5, 0)
	gui.MaxDistance = if isBoss then 200 else 70
	gui.AlwaysOnTop = isBoss
	gui.LightInfluence = 0
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0.55, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.BuilderSansExtraBold
	name.TextScaled = true
	name.TextColor3 = if isBoss then Color3.fromRGB(255, 120, 160) elseif elite then Color3.fromRGB(255, 215, 90) else Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.Text = (if isBoss then "👑 " elseif elite then "⭐ ELITE " else "") .. def.name
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

local function newEnemy(def, zone, isBoss, elite, minion)
	local size = if isBoss then def.size else 3 * (if elite then ELITE.size else 1) * (if minion then 0.8 else 1)
	local body, fill = makeBody(def, size, isBoss, elite)
	local maxHp = def.hp * (if elite then ELITE.hp else 1) * (if minion then 0.6 else 1)
	body:SetAttribute("MaxHp", maxHp)
	return {
		def = def,
		zone = zone,
		isBoss = isBoss,
		elite = elite,
		minion = minion,
		size = size,
		hover = if isBoss then size * 0.8 else 4,
		aggro = if isBoss then 70 else 40,
		maxHp = maxHp,
		body = body,
		fill = fill,
		lastHit = 0,
		phase = 1,
		nextAttack = 0,
		minions = {},
	}
end

local function spawn(enemy, at)
	enemy.hp = enemy.maxHp
	enemy.home = at or randomPoint(enemy.zone)
	enemy.alive = true
	enemy.contributors = {}
	enemy.phase = 1
	enemy.nextAttack = os.clock() + ATTACK_EVERY[1]
	enemy.body:SetAttribute("Phase", 1)
	enemy.body.CFrame = CFrame.new(enemy.home + Vector3.new(0, enemy.hover, 0))
	updateBar(enemy)
	enemy.body.Parent = folder
end

local function removeEnemy(enemy)
	local i = table.find(enemies, enemy)
	if i then
		table.remove(enemies, i)
	end
	enemy.body:Destroy()
end

local function despawnMinions(boss)
	for _, minion in boss.minions do
		if minion.alive then
			minion.alive = false
			PlayerService.Fx("Explode", minion.body.Position, minion.def.color, false)
		end
		removeEnemy(minion)
	end
	table.clear(boss.minions)
end

-- quái thường hồi sinh: có cơ hội thành Elite (dựng lại thân vì kích thước/máu khác)
local function respawnNormal(enemy)
	local elite = random:NextNumber() < ELITE_CHANCE
	if elite ~= enemy.elite then
		local fresh = newEnemy(enemy.def, enemy.zone, false, elite, false)
		local i = table.find(enemies, enemy)
		enemy.body:Destroy()
		if i then
			enemies[i] = fresh
		end
		enemy = fresh
	end
	spawn(enemy)
end

local function kill(enemy, killer)
	enemy.alive = false
	PlayerService.Fx("Explode", enemy.body.Position, if enemy.elite then Color3.fromRGB(255, 210, 80) else enemy.def.color, enemy.isBoss or enemy.elite)
	enemy.body.Parent = nil
	if enemy.isBoss then
		despawnMinions(enemy)
		-- ai góp sát thương đều nhận thưởng (+ cơ hội bot SECRET)
		for player in enemy.contributors do
			if player.Parent then
				PlayerService.OnKill(player, enemy.def, enemy.zone, true)
			end
		end
	elseif killer and killer.Parent then
		if enemy.elite then
			local def = setmetatable({ credits = enemy.def.credits * ELITE.reward, xp = enemy.def.xp * ELITE.reward }, { __index = enemy.def })
			PlayerService.OnKill(killer, def, enemy.zone, false)
			if random:NextNumber() < ELITE.capsuleChance and Config.CapsuleById[enemy.zone.id] then
				PlayerService.GiftCapsule(killer, enemy.zone.id, string.format("⭐ The Elite dropped a free %s!", Config.CapsuleById[enemy.zone.id].name))
			end
		else
			PlayerService.OnKill(killer, enemy.def, enemy.zone, false)
		end
	end
	if enemy.minion then
		removeEnemy(enemy)
		return
	end
	task.delay(if enemy.isBoss then enemy.def.respawn else 8, function()
		if enemy.isBoss then
			spawn(enemy)
			for _, player in Players:GetPlayers() do
				PlayerService.Notify(player, string.format("⚠️ %s has appeared in %s!", enemy.def.name, enemy.zone.name), "Boss")
			end
		else
			respawnNormal(enemy)
		end
	end)
end

local function playersNear(position, radius, zone)
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and (not zone or Config.ZoneAt(root.Position) == zone) and (root.Position - position).Magnitude <= radius then
			table.insert(list, player)
		end
	end
	return list
end

local function setPhase(enemy)
	local ratio = enemy.hp / enemy.maxHp
	local phase = if ratio <= PHASE_AT[2] then 3 elseif ratio <= PHASE_AT[1] then 2 else 1
	if phase > enemy.phase then
		enemy.phase = phase
		enemy.body:SetAttribute("Phase", phase)
		enemy.nextAttack = math.min(enemy.nextAttack, os.clock() + 1.5)
		PlayerService.Fx("Shockwave", enemy.body.Position, enemy.size * 2.5, enemy.def.color)
		for _, player in playersNear(enemy.body.Position, 160, enemy.zone) do
			PlayerService.Notify(player, string.format("😡 %s is ENRAGED! (Phase %d)", enemy.def.name, phase), "Announce")
		end
	end
end

local function damage(enemy, player, amount)
	if not enemy.alive or amount <= 0 then
		return
	end
	enemy.hp -= amount
	enemy.lastDamaged = os.clock()
	enemy.contributors[player] = true
	PlayerService.Fx("Damage", enemy.body.Position + Vector3.new(0, enemy.hover * 0.3, 0), math.floor(amount))
	if enemy.hp <= 0 then
		kill(enemy, player)
	else
		updateBar(enemy)
		if enemy.isBoss then
			setPhase(enemy)
		end
	end
end

-- Pulse của người chơi: trúng mọi quái trong bán kính
local function damageArea(player, position, radius, amount)
	for _, enemy in table.clone(enemies) do
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

-- ================= Chiêu của boss =================

-- vùng nổ có báo trước: client vẽ vòng đỏ đầy dần trong TELEGRAPH giây, rồi nổ
local function blast(enemy, center, radius, power)
	PlayerService.Fx("Telegraph", center, radius, TELEGRAPH, enemy.def.color)
	task.delay(TELEGRAPH, function()
		if not enemy.alive then
			return
		end
		PlayerService.Fx("Shockwave", center, radius, enemy.def.color)
		for _, player in playersNear(center, radius + 2) do
			PlayerService.Damage(player, enemy.def.damage * power * PHASE_RAGE[enemy.phase])
			PlayerService.Fx("Hurt", player)
		end
	end)
end

local function summon(enemy)
	for i = #enemy.minions, 1, -1 do
		if not enemy.minions[i].alive then
			table.remove(enemy.minions, i)
		end
	end
	local count = math.min(MAX_MINIONS - #enemy.minions, enemy.phase)
	for _ = 1, count do
		local minion = newEnemy(enemy.zone.enemy, enemy.zone, false, false, true)
		table.insert(enemies, minion)
		table.insert(enemy.minions, minion)
		spawn(minion, enemy.body.Position - Vector3.new(0, enemy.hover, 0) + Vector3.new(random:NextNumber(-12, 12), 0, random:NextNumber(-12, 12)))
	end
	if count > 0 then
		PlayerService.Fx("Shockwave", enemy.body.Position, enemy.size * 1.5, enemy.def.color)
	end
end

local function bossAttack(enemy, target)
	local root = rootOf(target)
	if not root then
		return
	end
	local roll = random:NextNumber()
	if enemy.phase >= 2 and roll < 0.25 then
		summon(enemy)
	elseif roll < 0.6 then
		-- Slam: đập xuống chỗ người chơi đang đứng (chạy ra khỏi vòng đỏ là né được)
		blast(enemy, root.Position - Vector3.new(0, 2.5, 0), 10 + enemy.size * 0.4, 1.6)
	else
		-- Nova: sóng nổ quanh boss, đứng xa ra là né được
		local ground = enemy.body.Position - Vector3.new(0, enemy.hover, 0)
		blast(enemy, ground, 16 + enemy.size * 0.8, 1.3)
	end
end

-- ================= AI =================

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
	local rage = if enemy.isBoss then PHASE_RAGE[enemy.phase] else 1
	local goal
	if target then
		local root = rootOf(target)
		goal = root.Position + Vector3.new(0, enemy.hover * 0.5, 0)
		-- đủ gần thì đâm
		if targetDist <= enemy.size / 2 + 4 and os.clock() - enemy.lastHit > 1 then
			enemy.lastHit = os.clock()
			PlayerService.Damage(target, enemy.def.damage * rage * (if enemy.elite then ELITE.damage else 1))
			PlayerService.Fx("Hurt", target)
		end
		if enemy.isBoss and os.clock() >= enemy.nextAttack then
			enemy.nextAttack = os.clock() + ATTACK_EVERY[enemy.phase]
			bossAttack(enemy, target)
		end
	else
		-- không ai gần: bay lòng vòng quanh chỗ xuất hiện; boss hồi dần máu khi không ai đánh
		if not enemy.wander or (enemy.wander - pos).Magnitude < 3 then
			enemy.wander = enemy.home + Vector3.new(random:NextNumber(-14, 14), enemy.hover, random:NextNumber(-14, 14))
		end
		goal = enemy.wander
		if enemy.isBoss and enemy.hp < enemy.maxHp and os.clock() - (enemy.lastDamaged or 0) > 12 then
			enemy.hp = math.min(enemy.maxHp, enemy.hp + enemy.maxHp * 0.01)
			updateBar(enemy)
		end
	end
	local offset = goal - pos
	local step = math.min(offset.Magnitude, enemy.def.speed * rage * STEP)
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
		for _ = 1, zone.enemy.count do
			local enemy = newEnemy(zone.enemy, zone, false, random:NextNumber() < ELITE_CHANCE, false)
			table.insert(enemies, enemy)
			spawn(enemy)
		end
		local boss = newEnemy(zone.boss, zone, true, false, false)
		table.insert(enemies, boss)
		spawn(boss)
	end

	-- AI quái
	task.spawn(function()
		while true do
			task.wait(STEP)
			for _, enemy in table.clone(enemies) do
				think(enemy)
			end
		end
	end)

	-- Đội bot của mỗi người chơi tự bắn quái gần nhất mỗi giây (Rapid Fire: mỗi 0.5 giây)
	task.spawn(function()
		local beat = 0
		while true do
			task.wait(0.5)
			beat += 1
			for _, player in Players:GetPlayers() do
				local root = rootOf(player)
				if root and (beat % 2 == 0 or player:GetAttribute("RapidFire")) then
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
