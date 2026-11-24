-- Mọi thứ diễn ra trong phòng lab: dựng map, chia lab cho người chơi, gõ code,
-- lắp/nâng cấp GPU, thu token, train AI. Server là "trọng tài": client chỉ gửi
-- yêu cầu, server tự kiểm tra tiền/quyền rồi mới làm.
--
-- Các service khác (Heist, Progress...) cắm vào đây qua:
--   RegisterAction(name, fn)       thêm hành động client được gọi
--   RegisterStateProvider(fn)      thêm field vào State gửi client
--   RegisterTerminalHook(fn)       chạy khi người chơi bấm Máy thu token

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Visuals = require(script.Parent.Visuals)

local TICK = 1 -- giây giữa mỗi lần GPU đào token
local COLORS = Visuals.Colors

local LabService = {}

local remotes -- gán trong Start()
local labSlots = {} -- [index] = { model, racks, core, coreLabel, signLabel, terminal, spawn, origin, owner }
local sessions = {} -- [player] = { lab, lastAction, lastClick }
local actions = {}
local stateProviders = {}
local terminalHooks = {}

-- ================= Tiện ích =================

function LabService.Notify(player, message, action)
	remotes.Notify:FireClient(player, message, action)
end
local notify = LabService.Notify

local function isVip(player)
	return player:GetAttribute("VIP") == true
end

local function hasAutoCollect(player)
	return player:GetAttribute("AutoCollect") == true
end

function LabService.RegisterAction(name, handler)
	actions[name] = handler
end

function LabService.RegisterStateProvider(provider)
	table.insert(stateProviders, provider)
end

function LabService.RegisterTerminalHook(hook)
	table.insert(terminalHooks, hook)
end

function LabService.GetLabs()
	return labSlots
end

function LabService.GetLab(player)
	local session = sessions[player]
	return session and session.lab
end

-- ================= Hệ số nhân =================

-- VIP + boost + cổ phiếu IPO (áp cho cả click lẫn GPU)
function LabService.GetTokenMultiplier(player)
	local profile = DataService.Profiles[player]
	local mult = 1
	if isVip(player) then
		mult *= Config.Multipliers.VipTokens
	end
	if profile then
		if (profile.boosts.Tokens or 0) > os.time() then
			mult *= Config.Multipliers.TokenBoost
		end
		mult *= Config.ShareMultiplier(profile.shares)
	end
	return mult
end

function LabService.GetTrainMultiplier(player)
	local profile = DataService.Profiles[player]
	if profile and (profile.boosts.Training or 0) > os.time() then
		return Config.Multipliers.TrainBoost
	end
	return 1
end

-- Token/giây của 1 kệ
local function rackRate(player, profile, rack)
	local gpu = Config.GpuById[rack.gpu]
	if not gpu then
		return 0
	end
	return gpu.rate * Config.LevelMultiplier(profile.ai.level) * LabService.GetTokenMultiplier(player)
end

-- Tổng token/giây của cả lab
function LabService.GetRate(player)
	local profile = DataService.Profiles[player]
	if not profile then
		return 0
	end
	local total = 0
	for _, rack in profile.racks do
		total += rackRate(player, profile, rack)
	end
	return total
end

local function canUseRack(player, profile, index)
	if index <= profile.unlockedRacks then
		return true
	end
	return index > Config.Racks.BuyableRacks and isVip(player)
end

-- ================= Đồng bộ với client =================

function LabService.PushState(player)
	local profile = DataService.Profiles[player]
	if not profile or not sessions[player] then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Tokens.Value = math.floor(profile.tokens)
		stats["AI Lv"].Value = profile.ai.level
	end

	local buffered = 0
	for _, rack in profile.racks do
		buffered += rack.buffer or 0
	end

	local state = {
		tokens = profile.tokens,
		rate = LabService.GetRate(player),
		buffered = buffered,
		level = profile.ai.level,
		xp = profile.ai.xp,
		xpNext = Config.XpToNext(profile.ai.level),
		unlockedRacks = profile.unlockedRacks,
		boosts = profile.boosts,
		clickTokens = Config.ClickTokens(profile.ai.level) * LabService.GetTokenMultiplier(player),
		vip = isVip(player),
		autoCollect = hasAutoCollect(player),
	}
	for _, provider in stateProviders do
		provider(player, profile, state)
	end
	remotes.State:FireClient(player, state)
end

function LabService.AddTokens(player, amount)
	local profile = DataService.Profiles[player]
	if not profile or amount <= 0 then
		return
	end
	profile.tokens += amount
	profile.totalEarned += amount
	profile.runEarned += amount
end

-- ================= Hiển thị =================

local function renderRack(player, index)
	local session = sessions[player]
	local profile = DataService.Profiles[player]
	if not session or not profile then
		return
	end
	local rackPart = session.lab.racks[index]
	local prompt = rackPart.Prompt
	local label = rackPart.Info.Text
	local rack = profile.racks[tostring(index)]

	if not canUseRack(player, profile, index) then
		rackPart.Color = COLORS.locked
		rackPart.Transparency = 0.6
		label.Text = ""
		prompt.ObjectText = "Kệ " .. index
		if index > Config.Racks.BuyableRacks then
			Visuals.PaintRack(rackPart, COLORS.vip)
			prompt.ActionText = "⭐ Cần VIP"
		else
			Visuals.PaintRack(rackPart, nil)
			prompt.ActionText = "🔒 Mở kệ (" .. Config.Short(Config.RackPrice(index) or 0) .. " token)"
		end
		return
	end

	rackPart.Color = COLORS.rack
	rackPart.Transparency = 0

	if not rack then
		local first = Config.Gpus[1]
		Visuals.PaintRack(rackPart, nil)
		label.Text = "Trống"
		prompt.ObjectText = "Kệ trống"
		prompt.ActionText = string.format("Lắp %s %s (%s)", first.emoji, first.name, Config.Short(first.price))
		return
	end

	local gpu = Config.GpuById[rack.gpu]
	local nextGpu = Config.Gpus[Config.GpuTier[rack.gpu] + 1]
	Visuals.PaintRack(rackPart, gpu.color)
	prompt.ObjectText = string.format("%s %s • %s/s", gpu.emoji, gpu.name, Config.Short(rackRate(player, profile, rack)))
	if not nextGpu then
		prompt.ActionText = "Đã max cấp 🔥"
	elseif profile.ai.level < nextGpu.level then
		prompt.ActionText = string.format("Cần AI Lv.%d để lên %s", nextGpu.level, nextGpu.name)
	else
		prompt.ActionText = string.format("Nâng lên %s %s (%s)", nextGpu.emoji, nextGpu.name, Config.Short(nextGpu.price))
	end

	if hasAutoCollect(player) then
		label.Text = gpu.emoji
	else
		local cap = rackRate(player, profile, rack) * Config.Racks.BufferSeconds
		local full = (rack.buffer or 0) >= cap
		label.Text = string.format("%s 🪙%s%s", gpu.emoji, Config.Short(rack.buffer or 0), if full then " <font color='#ff5050'>ĐẦY!</font>" else "")
	end
end

local function renderAllRacks(player)
	for index = 1, Config.Racks.Count do
		renderRack(player, index)
	end
end

local function renderCore(player)
	local session = sessions[player]
	local profile = DataService.Profiles[player]
	if not session or not profile then
		return
	end
	local stage = Config.StageFor(profile.ai.level)
	Visuals.PaintCore(session.lab.core, stage.color, stage.size)
	session.lab.coreLabel.Text = string.format("%s %s • Lv.%d", stage.emoji, stage.name, profile.ai.level)
end

local function renderSign(player)
	local session = sessions[player]
	local profile = DataService.Profiles[player]
	if not session or not profile then
		return
	end
	local rank = Config.CompanyRank(profile.ipoCount)
	local shares = if profile.shares > 0 then string.format("  📈 %d cổ phiếu", profile.shares) else ""
	session.lab.signLabel.Text = string.format(
		"🏢 %s Corp.\n<font size='20' color='#FFD84D'>%s%s</font>",
		player.DisplayName,
		rank.name,
		shares
	)
end

-- Vẽ lại toàn bộ lab (sau IPO, sau khi nhận Gói Khởi Nghiệp...)
function LabService.RenderAll(player)
	renderAllRacks(player)
	renderCore(player)
	renderSign(player)
end

-- ================= Hành động của người chơi =================

local function onRackPrompt(player, slot, index)
	local session = sessions[player]
	local profile = DataService.Profiles[player]
	if not session or not profile then
		return
	end
	if session.lab ~= slot then
		notify(player, "Đây là lab của người khác nha 😅")
		return
	end

	if not canUseRack(player, profile, index) then
		if index > Config.Racks.BuyableRacks then
			notify(player, "Kệ này chỉ dành cho VIP ⭐", "OpenShop")
			return
		end
		if index ~= profile.unlockedRacks + 1 then
			notify(player, "Mở kệ trước đó trước đã nha!")
			return
		end
		local price = Config.RackPrice(index)
		if not price or profile.tokens < price then
			notify(player, "Cần " .. Config.Short(price or 0) .. " token để mở kệ này 🪙")
			return
		end
		profile.tokens -= price
		profile.unlockedRacks = index
		notify(player, "Đã mở thêm kệ máy chủ! 🎉")
		renderAllRacks(player)
		LabService.PushState(player)
		return
	end

	local key = tostring(index)
	local rack = profile.racks[key]
	local target = if rack then Config.Gpus[Config.GpuTier[rack.gpu] + 1] else Config.Gpus[1]
	if not target then
		notify(player, "GPU này max cấp rồi, đỉnh của chóp 🔥")
		return
	end
	if profile.ai.level < target.level then
		notify(player, string.format("AI cần Lv.%d mới dùng được %s. Train AI thêm đi! 🧠", target.level, target.name))
		return
	end
	if profile.tokens < target.price then
		notify(player, string.format("Cần %s token cho %s 🪙", Config.Short(target.price), target.name))
		return
	end
	profile.tokens -= target.price
	if rack then
		rack.gpu = target.id
	else
		profile.racks[key] = { gpu = target.id, buffer = 0 }
	end
	notify(player, string.format("Đã lắp %s %s!", target.emoji, target.name))
	renderRack(player, index)
	LabService.PushState(player)
end

local function collectAll(profile)
	local total = 0
	for _, rack in profile.racks do
		total += rack.buffer or 0
		rack.buffer = 0
	end
	return total
end

local function onTerminalPrompt(player, slot)
	local session = sessions[player]
	local profile = DataService.Profiles[player]
	if not session or not profile or session.lab ~= slot then
		return
	end
	local handled = false
	for _, hook in terminalHooks do
		if hook(player) then
			handled = true
		end
	end
	local total = collectAll(profile)
	if total >= 1 then
		LabService.AddTokens(player, total)
		notify(player, "Thu được +" .. Config.Short(total) .. " token 🤑", "Collect")
	elseif not handled then
		notify(player, "Chưa có token nào để thu. Lắp GPU đi anh em! 🖥️")
	end
	renderAllRacks(player)
	LabService.PushState(player)
end

function actions.Click(player, profile, session)
	local t = os.clock()
	if t - session.lastClick < Config.Click.MinInterval then
		return
	end
	session.lastClick = t
	LabService.AddTokens(player, Config.ClickTokens(profile.ai.level) * LabService.GetTokenMultiplier(player))
	profile.totalClicks += 1
	-- không PushState ở đây: vòng tick 1 giây sẽ gửi, đỡ spam mạng
end

function actions.Train(player, profile, session, fraction)
	if fraction ~= 0.1 and fraction ~= 0.5 and fraction ~= 1 then
		return
	end
	if profile.ai.level >= Config.AI.MaxLevel then
		notify(player, "AI đã max level, quá trùm rồi 👑")
		return
	end
	local amount = math.floor(profile.tokens * fraction)
	if amount < 1 then
		notify(player, "Không đủ token để train. Đi gõ code kiếm thêm đi! 💻")
		return
	end
	profile.tokens -= amount
	profile.ai.xp += amount * LabService.GetTrainMultiplier(player)

	local startLevel = profile.ai.level
	while profile.ai.level < Config.AI.MaxLevel and profile.ai.xp >= Config.XpToNext(profile.ai.level) do
		profile.ai.xp -= Config.XpToNext(profile.ai.level)
		profile.ai.level += 1
	end
	if profile.ai.level >= Config.AI.MaxLevel then
		profile.ai.xp = 0
	end

	if profile.ai.level > startLevel then
		local oldStage = Config.StageFor(startLevel)
		local stage = Config.StageFor(profile.ai.level)
		if stage ~= oldStage then
			notify(player, string.format("🎉 AI tiến hoá thành %s %s!", stage.emoji, stage.name), "Evolve")
		else
			local bonus = math.floor((Config.LevelMultiplier(profile.ai.level) - 1) * 100 + 0.5)
			notify(player, string.format("🧠 AI lên Lv.%d! Token +%d%%", profile.ai.level, bonus), "LevelUp")
		end
		renderCore(player)
		renderAllRacks(player)
	end
	LabService.PushState(player)
end

local function onAction(player, actionName, ...)
	local session = sessions[player]
	local profile = DataService.Profiles[player]
	local handler = type(actionName) == "string" and actions[actionName]
	if not session or not profile or not handler then
		return
	end
	-- Click có chống spam riêng, các hành động khác giới hạn 0.15s/lần
	if actionName ~= "Click" then
		local t = os.clock()
		if t - session.lastAction < 0.15 then
			return
		end
		session.lastAction = t
	end
	handler(player, profile, session, ...)
end

-- Gọi từ MonetizationService khi mua Time Warp
function LabService.TimeWarp(player, hours)
	local amount = LabService.GetRate(player) * hours * 3600
	LabService.AddTokens(player, amount)
	return amount
end

-- Gọi khi quyền VIP / Auto Collect thay đổi (vừa mua xong)
function LabService.Refresh(player)
	local profile = DataService.Profiles[player]
	if sessions[player] and profile then
		if hasAutoCollect(player) then
			LabService.AddTokens(player, collectAll(profile))
		end
		LabService.RenderAll(player)
		LabService.PushState(player)
	end
end

-- ================= Dựng map =================

local function makePrompt(parent, objectText, actionText, distance)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = distance or 9
	prompt.RequiresLineOfSight = false
	prompt.ObjectText = objectText or ""
	prompt.ActionText = actionText or "..."
	prompt.Parent = parent
	return prompt
end

local function buildLab(index)
	local col = (index - 1) % 4
	local row = math.floor((index - 1) / 4)
	local origin = CFrame.new((col - 1.5) * 95, 0, (row - 0.5) * 120)
	if row == 1 then
		origin *= CFrame.Angles(0, math.pi, 0) -- hàng sau quay mặt vào giữa
	end

	local model = Instance.new("Folder")
	model.Name = "Lab" .. index
	model:SetAttribute("OwnerUserId", 0)

	Visuals.BuildFloor(model, origin, 85, 105)
	Visuals.BuildGate(model, origin * CFrame.new(0, 0, 50), COLORS.grid)

	local signPost = Visuals.Part({
		Name = "Sign",
		Size = Vector3.new(1, 8, 1),
		CFrame = origin * CFrame.new(0, 4, -48),
		Color = COLORS.metal,
		Material = Enum.Material.Metal,
	})
	signPost.Parent = model
	local signLabel = Visuals.Label(signPost, "🏢 Lab trống", UDim2.fromScale(22, 5), Vector3.new(0, 8, 0))

	-- 12 kệ: 2 hàng x 6
	local racks = {}
	for i = 1, Config.Racks.Count do
		local r = math.floor((i - 1) / 6)
		local c = (i - 1) % 6
		local rackPart = Visuals.BuildRack(origin * CFrame.new((c - 2.5) * 9, 4, -36 + r * 12))
		rackPart.Name = "Rack" .. i
		Visuals.Label(rackPart, "", UDim2.fromScale(7, 1.6), Vector3.new(0, 5.5, 0)).Parent.Name = "Info"
		makePrompt(rackPart)
		rackPart.Parent = model
		racks[i] = rackPart
	end

	-- Lõi AI ở giữa phòng
	Visuals.Part({
		Name = "Pedestal",
		Size = Vector3.new(7, 2, 7),
		CFrame = origin * CFrame.new(0, 1, 2),
		Color = COLORS.metal,
		Material = Enum.Material.Metal,
	}).Parent = model
	local core = Visuals.BuildCore(model, origin * CFrame.new(0, 8, 2), Config.AIStages[1].color)
	local coreLabel = Visuals.Label(core, "🤖 AI", UDim2.fromScale(14, 2.5), Vector3.new(0, 8, 0))

	-- Máy thu token
	local terminal = Visuals.Part({
		Name = "Terminal",
		Size = Vector3.new(4, 4, 2),
		CFrame = origin * CFrame.new(0, 2, 20),
		Color = Color3.fromRGB(40, 220, 140),
		Material = Enum.Material.Neon,
	})
	Visuals.Light(terminal, terminal.Color, 12, 2)
	Visuals.Label(terminal, "🪙 Máy thu token", UDim2.fromScale(10, 2), Vector3.new(0, 4, 0))
	local terminalPrompt = makePrompt(terminal, "Máy thu token", "Thu tất cả", 10)
	terminal.Parent = model

	model.Parent = workspace:WaitForChild("Labs")

	local slot = {
		index = index,
		model = model,
		origin = origin,
		spawn = origin * CFrame.new(0, 4, 42),
		racks = racks,
		core = core,
		coreLabel = coreLabel,
		signLabel = signLabel,
		terminal = terminal,
		owner = nil,
	}
	for i, rackPart in racks do
		rackPart.Prompt.Triggered:Connect(function(player)
			onRackPrompt(player, slot, i)
		end)
	end
	terminalPrompt.Triggered:Connect(function(player)
		onTerminalPrompt(player, slot)
	end)
	return slot
end

-- ================= Vòng đời người chơi =================

local function teleportHome(player, character)
	local session = sessions[player]
	if not session then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root then
		task.wait() -- đợi SpawnLocation đặt nhân vật xong rồi mới dịch chuyển
		character:PivotTo(session.lab.spawn)
	end
end

function LabService.OnPlayerLoaded(player, profile)
	local slot
	for _, candidate in labSlots do
		if not candidate.owner then
			slot = candidate
			break
		end
	end
	if not slot then
		player:Kick("Server đầy lab rồi, thử server khác nha!")
		return
	end
	slot.owner = player
	slot.model:SetAttribute("OwnerUserId", player.UserId)

	sessions[player] = { lab = slot, lastAction = 0, lastClick = 0 }

	for key, rack in profile.racks do
		if not Config.GpuById[rack.gpu] then
			profile.racks[key] = nil -- GPU đã bị xoá khỏi Config
		end
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local tokens = Instance.new("NumberValue")
	tokens.Name = "Tokens"
	tokens.Parent = leaderstats
	local level = Instance.new("IntValue")
	level.Name = "AI Lv"
	level.Parent = leaderstats
	leaderstats.Parent = player

	-- GPU vẫn đào khi offline (có giới hạn giờ), cộng thẳng vào ví
	local hours = if isVip(player) then Config.VipOfflineHours else Config.OfflineHours
	local offline = math.clamp(os.time() - (profile.lastSave or os.time()), 0, hours * 3600)
	local offlineEarned = math.floor(LabService.GetRate(player) * offline)
	if offlineEarned > 0 then
		LabService.AddTokens(player, offlineEarned)
		task.delay(3, function()
			if player.Parent then
				notify(player, string.format("Lúc bạn vắng mặt, AI đã đào được +%s token 💸", Config.Short(offlineEarned)))
			end
		end)
	end

	LabService.RenderAll(player)
	LabService.PushState(player)

	player.CharacterAdded:Connect(function(character)
		teleportHome(player, character)
	end)
	if player.Character then
		task.spawn(teleportHome, player, player.Character)
	end
end

function LabService.OnPlayerRemoving(player)
	local session = sessions[player]
	if not session then
		return
	end
	local slot = session.lab
	sessions[player] = nil
	slot.owner = nil
	slot.model:SetAttribute("OwnerUserId", 0)
	slot.signLabel.Text = "🏢 Lab trống"
	local first = Config.AIStages[1]
	Visuals.PaintCore(slot.core, first.color, first.size)
	slot.coreLabel.Text = "🤖 AI"
	for _, rackPart in slot.racks do
		rackPart.Color = COLORS.rack
		rackPart.Transparency = 0
		Visuals.PaintRack(rackPart, nil)
		rackPart.Info.Text.Text = ""
		rackPart.Prompt.ObjectText = ""
		rackPart.Prompt.ActionText = "..."
	end
end

-- ================= Vòng lặp chính =================

local function tick(dt)
	for player in sessions do
		local profile = DataService.Profiles[player]
		if not profile then
			continue
		end
		local auto = hasAutoCollect(player)
		for key, rack in profile.racks do
			local rate = rackRate(player, profile, rack)
			if auto then
				LabService.AddTokens(player, rate * dt)
			else
				local cap = rate * Config.Racks.BufferSeconds
				rack.buffer = math.min(cap, (rack.buffer or 0) + rate * dt)
				renderRack(player, tonumber(key))
			end
		end
		LabService.PushState(player)
	end
end

function LabService.Start(remoteFolder)
	remotes = remoteFolder
	Visuals.SetupWorld()

	local labsFolder = Instance.new("Folder")
	labsFolder.Name = "Labs"
	labsFolder.Parent = workspace
	for i = 1, Config.MaxLabs do
		labSlots[i] = buildLab(i)
	end

	remotes.Action.OnServerEvent:Connect(onAction)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK)
			local t = os.clock()
			tick(t - last)
			last = t
		end
	end)
end

return LabService
