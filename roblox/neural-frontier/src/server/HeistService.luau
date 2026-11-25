-- ⚡ Core Heist: vòng PvP cướp lõi data (EventService gọi Run, thay phiên với Glitch Floor).
--   • Mỗi người được 1 KHO (bệ tròn màu riêng) quanh đấu trường. Lõi data rơi khắp sàn,
--     lõi càng hiếm càng nhiều điểm; giây thứ 60 có MEGA CORE ở giữa.
--   • Chạm lõi là nhặt (tối đa MaxCarry). Đứng vào kho của mình là cất hết: điểm trong kho mới tính.
--   • Pulse (Q) gần người khác: đẩy văng họ và cướp một nửa số lõi họ đang cầm (Shield chặn được).
--   • Đứng trong kho đối thủ: cứ RaidEvery giây trộm RaidShare điểm trong kho (chủ đứng giữ kho thì chặn).
--   • Rơi khỏi sàn / chết: rơi hết lõi đang cầm, quay về kho.
--   • Hết giờ: xếp hạng theo điểm trong kho, ai cũng có Credits; hạng 1 có thêm capsule miễn phí.
-- Chỉ tranh đồ trong vòng chơi, KHÔNG ai mất bot hay Credits thật.
-- Client đọc: workspace "HeistBoard" ("Tên:điểm;..."), attribute người chơi "HeistCarry" / "HeistBank".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local Visuals = require(script.Parent.Visuals)
local WorldService = require(script.Parent.WorldService)

local HeistService = {}

local H = Config.Heist
local NEON = Enum.Material.Neon
local VAULT_COLORS = {
	Color3.fromRGB(0, 220, 255),
	Color3.fromRGB(255, 70, 200),
	Color3.fromRGB(110, 255, 150),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(255, 140, 60),
	Color3.fromRGB(160, 110, 255),
	Color3.fromRGB(255, 80, 90),
	Color3.fromRGB(235, 245, 255),
}

local arena -- { center, top, half, folder, vaults = { { pos, color, label, pad } } }
local live = false
local racers = {} -- [player] = { vault, carried = { số điểm }, bank, stunUntil, lastSteal, raidTarget, raidTime, warnedAt, tag }
local cores = {} -- { part, value }
local rng = Random.new()

local function now()
	return workspace:GetServerTimeNow()
end

local function rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function sum(list)
	local total = 0
	for _, v in list do
		total += v
	end
	return total
end

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function colorFor(value)
	if value >= H.MegaCore.value then
		return H.MegaCore.color
	end
	local best = H.Cores[1].color
	for _, kind in H.Cores do
		if value >= kind.value then
			best = kind.color
		end
	end
	return best
end

-- ================= Đấu trường =================

local function block(name, size, cf, color, material, extra)
	local part = Visuals.Part({ Name = name, Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic, Parent = arena.folder })
	for key, value in extra or {} do
		part[key] = value
	end
	return part
end

local function buildArena()
	local world = workspace:FindFirstChild("World") or workspace
	local folder = Instance.new("Folder")
	folder.Name = "HeistArena"
	folder.Parent = world
	local c = H.ArenaCenter
	local half = H.Size / 2
	arena = { center = c, top = c.Y, half = half, folder = folder, vaults = {} }

	-- sàn ô cờ 6x6 + lưới neon
	local n = 6
	local tile = H.Size / n
	for i = 0, n - 1 do
		for j = 0, n - 1 do
			local pos = c + Vector3.new(-half + tile * (i + 0.5), -1, -half + tile * (j + 0.5))
			block("HeistTile", Vector3.new(tile, 2, tile), CFrame.new(pos), if (i + j) % 2 == 0 then Color3.fromRGB(30, 34, 60) else Color3.fromRGB(40, 46, 78))
		end
	end
	for k = 0, n do
		local offset = -half + k * tile
		block("HeistGridX", Vector3.new(H.Size, 0.1, 0.35), CFrame.new(c + Vector3.new(0, 0.05, offset)), Color3.fromRGB(0, 200, 255), NEON, { CanCollide = false, Transparency = 0.45 })
		block("HeistGridZ", Vector3.new(0.35, 0.1, H.Size), CFrame.new(c + Vector3.new(offset, 0.05, 0)), Color3.fromRGB(0, 200, 255), NEON, { CanCollide = false, Transparency = 0.45 })
	end
	-- tường thấp quanh sàn, viền neon hồng
	for _, spec in { { Vector3.new(0, 0, -half - 1), Vector3.new(H.Size + 4, 7, 2) }, { Vector3.new(0, 0, half + 1), Vector3.new(H.Size + 4, 7, 2) }, { Vector3.new(-half - 1, 0, 0), Vector3.new(2, 7, H.Size + 4) }, { Vector3.new(half + 1, 0, 0), Vector3.new(2, 7, H.Size + 4) } } do
		local wall = block("HeistWall", spec[2], CFrame.new(c + spec[1] + Vector3.new(0, 3.5, 0)), Color3.fromRGB(44, 48, 80), Enum.Material.Metal)
		block("HeistWallStrip", Vector3.new(spec[2].X + 0.1, 0.4, spec[2].Z + 0.1), wall.CFrame * CFrame.new(0, 3.4, 0), Color3.fromRGB(255, 70, 200), NEON, { CanCollide = false })
	end
	-- khối chắn để nấp / chạy vòng khi bị đuổi
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2 + math.pi / 8
		local pos = c + Vector3.new(math.cos(a) * 30, 3, math.sin(a) * 30)
		local cover = block("HeistCover", Vector3.new(9, 6, 3), CFrame.lookAt(pos, Vector3.new(c.X, pos.Y, c.Z)), Color3.fromRGB(56, 62, 100), Enum.Material.Metal)
		block("HeistCoverStrip", Vector3.new(9.1, 0.35, 3.1), cover.CFrame * CFrame.new(0, 2.6, 0), Color3.fromRGB(0, 220, 255), NEON, { CanCollide = false })
	end
	-- bục giữa (MEGA CORE xuất hiện ở đây)
	local stage = block("HeistStage", Vector3.new(1.6, 22, 22), CFrame.new(c + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(60, 50, 110), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	block("HeistStageRing", Vector3.new(1.7, 23, 23), stage.CFrame, H.MegaCore.color, NEON, { Shape = Enum.PartType.Cylinder, CanCollide = false, Transparency = 0.5 })
	local sign = block("HeistSign", Vector3.new(1, 1, 1), CFrame.new(c + Vector3.new(0, 22, 0)), Color3.new(1, 1, 1), nil, { Transparency = 1, CanCollide = false })
	Visuals.Label(sign, "⚡ CORE HEIST\n<font size='20' color='#9BE8FF'>Grab cores · Bank them · Steal from rivals</font>", UDim2.fromScale(40, 9), Vector3.zero, Color3.fromRGB(255, 160, 230), 400)

	-- 8 kho: 4 góc + 4 giữa cạnh
	local edge = half - 12
	local spots = { Vector3.new(-edge, 0, -edge), Vector3.new(edge, 0, edge), Vector3.new(edge, 0, -edge), Vector3.new(-edge, 0, edge), Vector3.new(0, 0, -edge), Vector3.new(0, 0, edge), Vector3.new(-edge, 0, 0), Vector3.new(edge, 0, 0) }
	for i, offset in spots do
		local color = VAULT_COLORS[i]
		local pos = c + offset
		local pad = block("VaultPad", Vector3.new(0.5, H.VaultRadius * 2, H.VaultRadius * 2), CFrame.new(pos + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, NEON, { Shape = Enum.PartType.Cylinder, CanCollide = false, Transparency = 0.55 })
		block("VaultRim", Vector3.new(0.6, H.VaultRadius * 2 + 0.8, H.VaultRadius * 2 + 0.8), pad.CFrame, color:Lerp(Color3.new(1, 1, 1), 0.3), NEON, { Shape = Enum.PartType.Cylinder, CanCollide = false, Transparency = 0.2 })
		local outward = Vector3.new(offset.X, 0, offset.Z).Unit
		local pillarPos = pos + outward * (H.VaultRadius + 1.5) + Vector3.new(0, 5, 0)
		local pillar = block("VaultPillar", Vector3.new(2, 10, 2), CFrame.new(pillarPos), Color3.fromRGB(50, 56, 90), Enum.Material.Metal)
		block("VaultCrystal", Vector3.new(1.6, 1.6, 1.6), CFrame.new(pillarPos + Vector3.new(0, 6, 0)) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), color, NEON, { CanCollide = false })
		Visuals.Light(pillar, color, 18, 1.5)
		local label = Visuals.Label(pillar, "VAULT", UDim2.fromScale(10, 3.2), Vector3.new(0, 10, 0), color:Lerp(Color3.new(1, 1, 1), 0.4), 170)
		arena.vaults[i] = { pos = pos, color = color, label = label }
	end
end

-- ================= Hiển thị =================

local function setVaultLabel(index, owner, state, raided)
	local vault = arena.vaults[index]
	if not owner then
		vault.label.Text = "VAULT"
		return
	end
	vault.label.Text = string.format("%s%s\n<font size='22'>🏦 %d pts</font>", if raided then "🚨 " else "", owner.DisplayName, state.bank)
end

local function updateTag(player, state)
	local carried = sum(state.carried)
	player:SetAttribute("HeistCarry", carried)
	player:SetAttribute("HeistBank", state.bank)
	if state.tag then
		state.tag.Enabled = #state.carried > 0
		state.tag.Text.Text = string.format("🔷 x%d  <font color='#FFD75A'>+%d</font>", #state.carried, carried)
	end
end

local function makeTag(player, color)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local label = Visuals.Label(head, "", UDim2.fromScale(5, 1.3), Vector3.new(0, 2.6, 0), color, 120)
	label.Parent.Name = "HeistTag"
	label.Parent.Enabled = false
	return label.Parent
end

local function publishBoard()
	local list = {}
	for player, state in racers do
		table.insert(list, { name = player.DisplayName, bank = state.bank })
	end
	table.sort(list, function(a, b)
		return a.bank > b.bank
	end)
	local parts = {}
	for k = 1, math.min(5, #list) do
		table.insert(parts, list[k].name:gsub("[:;]", "") .. ":" .. list[k].bank)
	end
	workspace:SetAttribute("HeistBoard", table.concat(parts, ";"))
end

-- ================= Lõi data =================

local function rollKind()
	local total = 0
	for _, kind in H.Cores do
		total += kind.weight
	end
	local r = rng:NextNumber() * total
	for _, kind in H.Cores do
		r -= kind.weight
		if r <= 0 then
			return kind
		end
	end
	return H.Cores[1]
end

local function randomSpot()
	local half = arena.half - 16
	return arena.center + Vector3.new(rng:NextNumber(-half, half), 2.2, rng:NextNumber(-half, half))
end

local function spawnCore(value, pos)
	local color = colorFor(value)
	local size = 1.3 + math.log(value + 1) * 0.45
	local part = Instance.new("Part")
	part.Name = "DataCore"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = Vector3.one * size
	part.CFrame = CFrame.new(pos or randomSpot()) * CFrame.Angles(math.pi / 4, 0, math.pi / 4)
	part.Color = color
	part.Material = NEON
	part:SetAttribute("Spin", 2) -- client/Fx xoay
	Visuals.Light(part, color, 8 + size * 2, 2)
	if value >= 6 then
		Visuals.Label(part, "+" .. value, UDim2.fromScale(3, 1.2), Vector3.new(0, size + 0.8, 0), color, 80)
	end
	part.Parent = arena.folder
	table.insert(cores, { part = part, value = value })
end

local function clearCores()
	for _, core in cores do
		core.part:Destroy()
	end
	table.clear(cores)
end

-- rơi hết lõi đang cầm ra quanh một điểm (hoặc chỗ ngẫu nhiên nếu rơi khỏi sàn)
local function dropAll(state, around)
	for _, value in state.carried do
		local pos = if around then around + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)) else randomSpot()
		pos = Vector3.new(math.clamp(pos.X, arena.center.X - arena.half + 4, arena.center.X + arena.half - 4), arena.top + 2.2, math.clamp(pos.Z, arena.center.Z - arena.half + 4, arena.center.Z + arena.half - 4))
		spawnCore(value, pos)
	end
	table.clear(state.carried)
end

local function toVault(player, state)
	local vault = arena.vaults[state.vault]
	local character = player.Character
	if character and character.PrimaryPart then
		local at = vault.pos + Vector3.new(0, 4, 0)
		character:PivotTo(CFrame.lookAt(at, Vector3.new(arena.center.X, at.Y, arena.center.Z)))
	end
end

-- ================= Luật chơi =================

local function bank(player, state)
	local amount = sum(state.carried)
	table.clear(state.carried)
	state.bank += amount
	local vault = arena.vaults[state.vault]
	PlayerService.Fx("Harvest", vault.pos + Vector3.new(0, 2, 0), vault.color, amount)
	PlayerService.Notify(player, string.format("🏦 Banked +%d! Vault: %d pts", amount, state.bank), "Reward")
	setVaultLabel(state.vault, player, state, false)
	updateTag(player, state)
end

-- Pulse gần đối thủ: đẩy văng + cướp nửa số lõi họ cầm (lõi giá trị cao trước)
local function onPulse(player, _profile, data)
	local state = live and racers[player]
	if not state or typeof(data.position) ~= "Vector3" then
		return
	end
	local t = os.clock()
	local canSteal = t - state.lastSteal >= H.StealCooldown
	local stole = 0
	for other, victim in racers do
		local root = other ~= player and rootOf(other)
		if root and (root.Position - data.position).Magnitude <= H.StealRadius + 2 then
			local away = Vector3.new(root.Position.X - data.position.X, 0, root.Position.Z - data.position.Z)
			local dir = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
			PlayerService.Fx("Knockback", other, dir * 70 + Vector3.new(0, 35, 0))
			if canSteal and #victim.carried > 0 then
				if PlayerService.IsShielded(other) then
					PlayerService.Notify(player, string.format("🛡️ %s's Shield blocked your steal!", other.DisplayName))
				else
					table.sort(victim.carried, function(a, b)
						return a > b
					end)
					local take = math.ceil(#victim.carried / 2)
					local taken = 0
					for _ = 1, take do
						local value = table.remove(victim.carried, 1)
						if #state.carried < H.MaxCarry then
							table.insert(state.carried, value)
						else
							spawnCore(value, root.Position + Vector3.new(rng:NextNumber(-5, 5), -0.8, rng:NextNumber(-5, 5)))
						end
						taken += value
					end
					stole += taken
					victim.stunUntil = t + H.StunTime
					PlayerService.Notify(other, string.format("💥 %s stole %d pts from you! Chase them down!", player.DisplayName, taken), "EventOut")
					updateTag(other, victim)
				end
			end
		end
	end
	if stole > 0 then
		state.lastSteal = t
		PlayerService.Notify(player, string.format("🦹 You stole %d pts! Bank them at your vault!", stole), "Reward")
		updateTag(player, state)
	end
end

local function tick(dt)
	local t = os.clock()
	for player, state in racers do
		if not player.Parent then
			racers[player] = nil
			continue
		end
		local root = rootOf(player)
		if not root then
			continue
		end
		local pos = root.Position
		-- rơi khỏi sàn, chết rồi hồi sinh ở Hub, hoặc bỏ chạy: rơi hết lõi, về kho
		if pos.Y < arena.top - 15 or flatDistance(pos, arena.center) > arena.half * 1.5 + 10 then
			if #state.carried > 0 then
				dropAll(state, nil)
				PlayerService.Notify(player, "💥 You dropped your cores!", "EventOut")
			end
			toVault(player, state)
			updateTag(player, state)
			continue
		end
		local changed = false
		-- nhặt lõi
		if t >= state.stunUntil then
			for i = #cores, 1, -1 do
				if #state.carried >= H.MaxCarry then
					break
				end
				local core = cores[i]
				if (core.part.Position - pos).Magnitude <= H.PickupRange then
					table.insert(state.carried, core.value)
					PlayerService.Fx("Harvest", core.part.Position, core.part.Color, 0)
					core.part:Destroy()
					table.remove(cores, i)
					changed = true
				end
			end
		end
		-- cất vào kho của mình
		local own = arena.vaults[state.vault]
		if flatDistance(pos, own.pos) <= H.VaultRadius then
			state.raidTarget = nil
			if #state.carried > 0 then
				bank(player, state)
				changed = false
			end
		else
			-- đứng trong kho đối thủ: trộm dần
			local target = nil
			for other, owner in racers do
				if other ~= player and owner.bank > 0 and flatDistance(pos, arena.vaults[owner.vault].pos) <= H.VaultRadius then
					target = other
					break
				end
			end
			if target ~= state.raidTarget then
				state.raidTarget, state.raidTime = target, 0
			end
			if target then
				local owner = racers[target]
				local ownerRoot = rootOf(target)
				local defended = ownerRoot ~= nil and flatDistance(ownerRoot.Position, arena.vaults[owner.vault].pos) <= H.VaultRadius
				if defended then
					state.raidTime = 0
				else
					state.raidTime += dt
					if state.raidTime >= H.RaidEvery and #state.carried < H.MaxCarry then
						state.raidTime = 0
						local amount = math.max(1, math.floor(owner.bank * H.RaidShare))
						owner.bank -= amount
						table.insert(state.carried, amount)
						changed = true
						setVaultLabel(owner.vault, target, owner, true)
						updateTag(target, owner)
						PlayerService.Notify(player, string.format("💰 Raided %d pts from %s's vault! Run home!", amount, target.DisplayName), "Reward")
						if t - (owner.warnedAt or 0) > 3 then
							owner.warnedAt = t
							PlayerService.Notify(target, string.format("🚨 %s is raiding your vault! Get back there!", player.DisplayName), "EventOut")
						end
					end
				end
			end
		end
		if changed then
			updateTag(player, state)
		end
	end
end

-- ================= Một vòng =================

local function reward(player, rank, score, playerCount)
	local profile = DataService.Profiles[player]
	if not profile or not player.Parent then
		return
	end
	local won = rank == 1 and score > 0 and playerCount > 1
	local credits = Config.ScaledCredits((if won then H.WinCredits else H.PlayCredits) + score * H.PointCredits, profile.level)
	PlayerService.AddCredits(player, credits)
	if won then
		profile.stats.eventWins = (profile.stats.eventWins or 0) + 1
		profile.stats.heistWins = (profile.stats.heistWins or 0) + 1
		PlayerService.Emit("EventWin", player, profile)
		local capsule = PlayerService.BestCapsule(profile)
		PlayerService.Notify(player, string.format("🏆 HEIST CHAMPION! %d pts · +%s credits and a free %s", score, Config.Short(credits), capsule.name), "EventWin")
		PlayerService.Hatch(player, profile, capsule, 1)
	else
		PlayerService.Notify(player, string.format("⚡ Core Heist: #%d with %d pts · +%s credits", rank, score, Config.Short(credits)), "Reward")
		PlayerService.PushState(player)
	end
end

local function cleanup()
	live = false
	for player, state in racers do
		if state.tag then
			state.tag:Destroy()
		end
		if player.Parent then
			player:SetAttribute("HeistCarry", nil)
			player:SetAttribute("HeistBank", nil)
		end
	end
	racers = {}
	clearCores()
	for i in arena.vaults do
		setVaultLabel(i, nil)
	end
	workspace:SetAttribute("HeistBoard", "")
end

-- list: người chơi đã JOIN và còn nhân vật. setPhase(name, endsAt) của EventService.
function HeistService.Run(list, setPhase)
	cleanup()
	while #list > H.MaxPlayers do
		local extra = table.remove(list)
		PlayerService.Notify(extra, "⚡ Core Heist is full! You'll get a spot next time.")
	end
	for i, player in list do
		local state = { vault = i, carried = {}, bank = 0, stunUntil = 0, lastSteal = 0, raidTime = 0 }
		racers[player] = state
		toVault(player, state)
		state.tag = makeTag(player, arena.vaults[i].color)
		setVaultLabel(i, player, state, false)
		updateTag(player, state)
		PlayerService.Notify(player, "", "EventCountdown")
	end
	publishBoard()
	setPhase("Live", now() + 3 + H.Duration)
	task.wait(3)
	live = true
	for _ = 1, H.StartCores do
		spawnCore(rollKind().value)
	end
	for player in racers do
		PlayerService.Notify(player, "⚡ Grab cores, bank them at YOUR vault, Pulse (Q) rivals to steal!", "Announce")
	end

	local start = os.clock()
	local lastSpawn, lastBoard = start, start
	local megaDone = false
	while os.clock() - start < H.Duration do
		local dt = task.wait(0.1)
		tick(dt)
		local t = os.clock()
		if next(racers) == nil then
			break
		end
		if t - lastSpawn >= H.SpawnEvery and #cores < H.MaxCores then
			lastSpawn = t
			spawnCore(rollKind().value)
		end
		if not megaDone and t - start >= H.MegaCore.at then
			megaDone = true
			spawnCore(H.MegaCore.value, arena.center + Vector3.new(0, 4.2, 0))
			for player in racers do
				PlayerService.Notify(player, string.format("💎 MEGA CORE (+%d) spawned in the center!", H.MegaCore.value), "Boss")
			end
		end
		if t - lastBoard >= 0.5 then
			lastBoard = t
			publishBoard()
		end
	end
	live = false

	-- kết quả: lõi đang cầm mà chưa cất thì không tính
	local ranking = {}
	for player, state in racers do
		table.insert(ranking, { player = player, bank = state.bank })
	end
	table.sort(ranking, function(a, b)
		return a.bank > b.bank
	end)
	for rank, entry in ranking do
		reward(entry.player, rank, entry.bank, #ranking)
	end
	local top = ranking[1]
	local summary = if top and top.bank > 0 then string.format("⚡ Core Heist champion: %s with %d pts!", top.player.DisplayName, top.bank) else "⚡ Core Heist ended!"
	for _, player in Players:GetPlayers() do
		if not racers[player] then
			PlayerService.Notify(player, summary, "Announce")
		end
	end
	publishBoard()
	-- ăn mừng vài giây rồi về Hub
	task.wait(4)
	for player in racers do
		if player.Parent and rootOf(player) then
			player.Character:PivotTo(WorldService.HubSpawn())
		end
	end
	cleanup()
end

-- gọi khi vòng bị lỗi giữa chừng
function HeistService.Reset()
	if arena then
		cleanup()
	end
end

function HeistService.Start()
	buildArena()
	PlayerService.On("Pulse", onPulse)
	Players.PlayerRemoving:Connect(function(player)
		local state = racers[player]
		if state then
			racers[player] = nil
			if live then
				dropAll(state, nil)
			end
			setVaultLabel(state.vault, nil)
		end
	end)
end

return HeistService
