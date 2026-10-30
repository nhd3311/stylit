-- Mọi thứ diễn ra trên farm: dựng map, chia farm cho người chơi, trồng/thu hoạch,
-- nuôi thú, bán đồ, mở ô đất. Server là "trọng tài": client chỉ gửi yêu cầu,
-- server tự kiểm tra tiền/quyền rồi mới làm.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local TICK = 1 -- giây giữa mỗi lần cập nhật cây/thú

local SOIL_COLOR = Color3.fromRGB(110, 75, 45)
local LOCKED_COLOR = Color3.fromRGB(70, 70, 70)
local VIP_COLOR = Color3.fromRGB(200, 165, 40)
local GROWING_COLOR = Color3.fromRGB(90, 190, 80)

local FarmService = {}

local remotes -- gán trong Start()
local farmSlots = {} -- [index] = { model, origin, owner, tiles = { [i] = tilePart }, pen }
local sessions = {} -- [player] = { farm, selectedSeed, animalTimers, dirty, lastAction }

-- ================= Tiện ích =================

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

local function makeLabel(parent, text, size, offset)
	local gui = Instance.new("BillboardGui")
	gui.Size = size or UDim2.fromScale(6, 1.5)
	gui.StudsOffset = offset or Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.BuilderSansBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	gui.Parent = parent
	return label
end

local function notify(player, message)
	remotes.Notify:FireClient(player, message)
end

local function now()
	return os.time()
end

local function isVip(player)
	return player:GetAttribute("VIP") == true
end

-- ================= Hệ số nhân (VIP / boost) =================

function FarmService.GetCoinMultiplier(player)
	local profile = DataService.Profiles[player]
	local mult = 1
	if isVip(player) then
		mult *= Config.Multipliers.VipCoins
	end
	if profile and (profile.boosts.Coins or 0) > now() then
		mult *= Config.Multipliers.CoinBoost
	end
	return mult
end

function FarmService.GetGrowthMultiplier(player)
	local profile = DataService.Profiles[player]
	local mult = 1
	if player:GetAttribute("FastGrow") == true then
		mult *= Config.Multipliers.FastGrowPass
	end
	if profile and (profile.boosts.Growth or 0) > now() then
		mult *= Config.Multipliers.GrowBoost
	end
	return mult
end

local function maxAnimals(player)
	return Config.MaxAnimalsPerType + (if isVip(player) then Config.VipExtraAnimals else 0)
end

local function canUsePlot(player, profile, index)
	if index <= profile.unlockedPlots then
		return true
	end
	return index > Config.Plots.BuyablePlots and isVip(player)
end

-- ================= Đồng bộ với client =================

local function updateLeaderstats(player, profile)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Coins.Value = profile.coins
	end
end

function FarmService.PushState(player)
	local profile = DataService.Profiles[player]
	local session = sessions[player]
	if not profile or not session then
		return
	end
	updateLeaderstats(player, profile)
	remotes.State:FireClient(player, {
		coins = profile.coins,
		inventory = profile.inventory,
		animals = profile.animals,
		maxAnimals = maxAnimals(player),
		unlockedPlots = profile.unlockedPlots,
		boosts = profile.boosts,
		selectedSeed = session.selectedSeed,
		coinMult = FarmService.GetCoinMultiplier(player),
		growMult = FarmService.GetGrowthMultiplier(player),
		vip = isVip(player),
		fastGrow = player:GetAttribute("FastGrow") == true,
	})
end

function FarmService.AddCoins(player, amount)
	local profile = DataService.Profiles[player]
	if not profile then
		return
	end
	profile.coins += amount
	FarmService.PushState(player)
end

-- ================= Hiển thị ô đất =================

local function renderTile(player, index)
	local session = sessions[player]
	local profile = DataService.Profiles[player]
	if not session or not profile then
		return
	end
	local tile = session.farm.tiles[index]
	local prompt = tile.Prompt
	local crop = tile:FindFirstChild("Crop")
	local plot = profile.plots[tostring(index)]

	if not canUsePlot(player, profile, index) then
		if crop then
			crop:Destroy()
		end
		if index > Config.Plots.BuyablePlots then
			tile.Color = VIP_COLOR
			tile.Material = Enum.Material.Neon
			tile.Transparency = 0.5
			prompt.ActionText = "⭐ Cần VIP"
		else
			tile.Color = LOCKED_COLOR
			tile.Material = Enum.Material.Slate
			tile.Transparency = 0
			prompt.ActionText = string.format("🔒 Mở ô (%d coin)", Config.PlotPrice(index) or 0)
		end
		prompt.ObjectText = "Ô đất " .. index
		return
	end

	tile.Color = SOIL_COLOR
	tile.Material = Enum.Material.Ground
	tile.Transparency = 0

	if not plot then
		if crop then
			crop:Destroy()
		end
		local seed = Config.CropById[session.selectedSeed]
		prompt.ObjectText = "Ô đất trống"
		prompt.ActionText = string.format("Trồng %s %s (%d🪙)", seed.emoji, seed.name, seed.seedPrice)
		return
	end

	local info = Config.CropById[plot.crop]
	local ratio = math.clamp(plot.progress / info.growTime, 0, 1)
	if not crop then
		crop = makePart({
			Name = "Crop",
			CanCollide = false,
			CanQuery = false,
			Material = Enum.Material.SmoothPlastic,
		})
		crop.Parent = tile
	end
	local height = 0.6 + 2.4 * ratio
	crop.Size = Vector3.new(1 + 2 * ratio, height, 1 + 2 * ratio)
	crop.CFrame = tile.CFrame * CFrame.new(0, tile.Size.Y / 2 + height / 2, 0)

	if ratio >= 1 then
		crop.Shape = Enum.PartType.Ball
		crop.Size = Vector3.new(3, 3, 3)
		crop.CFrame = tile.CFrame * CFrame.new(0, tile.Size.Y / 2 + 1.5, 0)
		crop.Color = info.color
		crop.Material = Enum.Material.Neon
		prompt.ObjectText = info.emoji .. " " .. info.name .. " đã chín!"
		prompt.ActionText = "Thu hoạch"
	else
		crop.Shape = Enum.PartType.Block
		crop.Color = GROWING_COLOR
		crop.Material = Enum.Material.SmoothPlastic
		local remaining = math.ceil((info.growTime - plot.progress) / FarmService.GetGrowthMultiplier(player))
		prompt.ObjectText = info.emoji .. " " .. info.name
		prompt.ActionText = string.format("Đang lớn %d%% (còn %ds)", math.floor(ratio * 100), remaining)
	end
end

local function renderAllTiles(player)
	for index = 1, Config.TotalPlots() do
		renderTile(player, index)
	end
end

-- ================= Hiển thị chuồng thú =================

local function renderPen(player)
	local session = sessions[player]
	local profile = DataService.Profiles[player]
	if not session or not profile then
		return
	end
	local pen = session.farm.pen
	for _, animal in Config.Animals do
		local existing = {}
		for _, child in pen:GetChildren() do
			if child.Name == animal.id then
				table.insert(existing, child)
			end
		end
		local want = profile.animals[animal.id] or 0
		for i = #existing + 1, want do
			local size = if animal.id == "Chicken" then 1.5 else 3
			local body = makePart({
				Name = animal.id,
				Size = Vector3.new(size, size, size * 1.4),
				Color = animal.color,
				CanCollide = false,
				Material = Enum.Material.SmoothPlastic,
			})
			local spot = pen.Floor.CFrame * CFrame.new(math.random(-15, 15), size / 2 + 0.5, math.random(-8, 8))
			body.CFrame = spot * CFrame.Angles(0, math.rad(math.random(0, 359)), 0)
			makeLabel(body, animal.emoji, UDim2.fromScale(2.5, 2.5), Vector3.new(0, size, 0))
			body.Parent = pen
		end
		for i = #existing, want + 1, -1 do
			existing[i]:Destroy()
		end
	end
end

-- Cho thú đi lang thang cho đỡ buồn
local function wanderAnimals(pen)
	for _, child in pen:GetChildren() do
		if child:IsA("BasePart") and Config.AnimalById[child.Name] and math.random() < 0.35 then
			local target = pen.Floor.CFrame
				* CFrame.new(math.random(-15, 15), child.Size.Y / 2 + 0.5, math.random(-8, 8))
				* CFrame.Angles(0, math.rad(math.random(0, 359)), 0)
			TweenService:Create(child, TweenInfo.new(2.5, Enum.EasingStyle.Sine), { CFrame = target }):Play()
		end
	end
end

-- ================= Hành động của người chơi =================

local function onTilePrompt(player, slot, index)
	local session = sessions[player]
	local profile = DataService.Profiles[player]
	if not session or not profile then
		return
	end
	if session.farm ~= slot then
		notify(player, "Đây là farm của người khác nha 😅")
		return
	end

	if not canUsePlot(player, profile, index) then
		if index > Config.Plots.BuyablePlots then
			remotes.Notify:FireClient(player, "Ô này chỉ dành cho VIP ⭐ Mở Shop VIP để mua nha!", "OpenShop")
			return
		end
		if index ~= profile.unlockedPlots + 1 then
			notify(player, "Mở ô trước đó trước đã nha!")
			return
		end
		local price = Config.PlotPrice(index)
		if not price or profile.coins < price then
			notify(player, string.format("Cần %d coin để mở ô này 🪙", price or 0))
			return
		end
		profile.coins -= price
		profile.unlockedPlots = index
		notify(player, "Đã mở thêm ô đất mới! 🎉")
		renderAllTiles(player)
		FarmService.PushState(player)
		return
	end

	local key = tostring(index)
	local plot = profile.plots[key]
	if not plot then
		local seed = Config.CropById[session.selectedSeed]
		if profile.coins < seed.seedPrice then
			notify(player, string.format("Không đủ coin mua hạt %s (%d🪙)", seed.name, seed.seedPrice))
			return
		end
		profile.coins -= seed.seedPrice
		profile.plots[key] = { crop = seed.id, progress = 0 }
		renderTile(player, index)
		FarmService.PushState(player)
		return
	end

	local info = Config.CropById[plot.crop]
	if plot.progress >= info.growTime then
		profile.plots[key] = nil
		profile.inventory[info.id] = (profile.inventory[info.id] or 0) + 1
		renderTile(player, index)
		FarmService.PushState(player)
	end
end

local actions = {}

function actions.SelectSeed(player, profile, session, cropId)
	if type(cropId) ~= "string" or not Config.CropById[cropId] then
		return
	end
	session.selectedSeed = cropId
	renderAllTiles(player)
	FarmService.PushState(player)
end

function actions.SellAll(player, profile)
	local total = 0
	for itemId, count in profile.inventory do
		local _, price = Config.ItemInfo(itemId)
		total += price * count
	end
	if total <= 0 then
		notify(player, "Kho trống trơn, đi thu hoạch đã nha 🌾")
		return
	end
	local earned = math.floor(total * FarmService.GetCoinMultiplier(player))
	table.clear(profile.inventory)
	profile.coins += earned
	profile.totalEarned += earned
	notify(player, string.format("Bán được +%d coin 🤑", earned))
	FarmService.PushState(player)
end

function actions.BuyAnimal(player, profile, session, animalId)
	local animal = type(animalId) == "string" and Config.AnimalById[animalId]
	if not animal then
		return
	end
	local owned = profile.animals[animal.id] or 0
	if owned >= maxAnimals(player) then
		local hint = if isVip(player) then "" else " Mua VIP để thêm chỗ ⭐"
		notify(player, "Chuồng " .. animal.name .. " đầy rồi!" .. hint)
		return
	end
	if profile.coins < animal.price then
		notify(player, string.format("Cần %d coin để mua %s", animal.price, animal.name))
		return
	end
	profile.coins -= animal.price
	profile.animals[animal.id] = owned + 1
	notify(player, string.format("Đã mua 1 %s %s!", animal.emoji, animal.name))
	renderPen(player)
	FarmService.PushState(player)
end

local function onAction(player, actionName, ...)
	local session = sessions[player]
	local profile = DataService.Profiles[player]
	local handler = type(actionName) == "string" and actions[actionName]
	if not session or not profile or not handler then
		return
	end
	-- chống spam remote
	local t = os.clock()
	if t - session.lastAction < 0.15 then
		return
	end
	session.lastAction = t
	handler(player, profile, session, ...)
end

-- Gọi từ MonetizationService khi mua "Chín ngay"
function FarmService.InstantGrow(player)
	local profile = DataService.Profiles[player]
	if not profile then
		return
	end
	for _, plot in profile.plots do
		local info = Config.CropById[plot.crop]
		if info then
			plot.progress = info.growTime
		end
	end
	renderAllTiles(player)
end

-- Gọi khi quyền VIP thay đổi (vừa mua xong)
function FarmService.Refresh(player)
	if sessions[player] then
		renderAllTiles(player)
		FarmService.PushState(player)
	end
end

-- ================= Dựng map =================

local function buildFarm(index)
	local col = (index - 1) % 4
	local row = math.floor((index - 1) / 4)
	local origin = CFrame.new((col - 1.5) * 95, 0, (row - 0.5) * 120)
	if row == 1 then
		origin *= CFrame.Angles(0, math.pi, 0) -- hàng sau quay mặt vào giữa
	end

	local model = Instance.new("Folder")
	model.Name = "Farm" .. index
	model:SetAttribute("OwnerUserId", 0)

	makePart({
		Name = "Ground",
		Size = Vector3.new(85, 1, 105),
		CFrame = origin * CFrame.new(0, -0.4, 0),
		Color = Color3.fromRGB(95, 160, 70),
		Material = Enum.Material.Grass,
	}).Parent = model

	local signPost = makePart({
		Name = "Sign",
		Size = Vector3.new(1, 8, 1),
		CFrame = origin * CFrame.new(0, 4, -48),
		Color = Color3.fromRGB(120, 85, 50),
		Material = Enum.Material.Wood,
	})
	signPost.Parent = model
	local signLabel = makeLabel(signPost, "🌾 Farm trống", UDim2.fromScale(16, 3), Vector3.new(0, 6, 0))

	local tiles = {}
	local p = Config.Plots
	for r = 1, p.Rows do
		for c = 1, p.Columns do
			local i = (r - 1) * p.Columns + c
			local tile = makePart({
				Name = "Tile" .. i,
				Size = Vector3.new(7, 1, 7),
				CFrame = origin * CFrame.new((c - (p.Columns + 1) / 2) * p.Spacing, 0.2, -30 + (r - 1) * p.Spacing),
				Color = SOIL_COLOR,
				Material = Enum.Material.Ground,
			})
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "Prompt"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt.ActionText = "..."
			prompt.Parent = tile
			tile.Parent = model
			tiles[i] = tile
		end
	end

	local pen = Instance.new("Folder")
	pen.Name = "Pen"
	local penFloor = makePart({
		Name = "Floor",
		Size = Vector3.new(40, 0.4, 24),
		CFrame = origin * CFrame.new(0, 0.2, 22),
		Color = Color3.fromRGB(200, 170, 110),
		Material = Enum.Material.Sand,
	})
	penFloor.Parent = pen
	local fences = {
		{ Vector3.new(40, 3, 0.6), Vector3.new(0, 1.5, -12) },
		{ Vector3.new(40, 3, 0.6), Vector3.new(0, 1.5, 12) },
		{ Vector3.new(0.6, 3, 24), Vector3.new(-20, 1.5, 0) },
		{ Vector3.new(0.6, 3, 24), Vector3.new(20, 1.5, 0) },
	}
	for _, fence in fences do
		makePart({
			Name = "Fence",
			Size = fence[1],
			CFrame = penFloor.CFrame * CFrame.new(fence[2]),
			Color = Color3.fromRGB(150, 105, 60),
			Material = Enum.Material.WoodPlanks,
		}).Parent = pen
	end
	makeLabel(penFloor, "🐾 Chuồng thú", UDim2.fromScale(10, 2), Vector3.new(0, 6, 0))
	pen.Parent = model

	model.Parent = workspace:WaitForChild("Farms")

	local slot = {
		index = index,
		model = model,
		origin = origin,
		spawn = origin * CFrame.new(0, 4, 42) * CFrame.Angles(0, 0, 0),
		tiles = tiles,
		pen = pen,
		signLabel = signLabel,
		owner = nil,
	}
	for i, tile in tiles do
		tile.Prompt.Triggered:Connect(function(player)
			onTilePrompt(player, slot, i)
		end)
	end
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
		character:PivotTo(session.farm.spawn)
	end
end

function FarmService.OnPlayerLoaded(player, profile)
	local slot
	for _, candidate in farmSlots do
		if not candidate.owner then
			slot = candidate
			break
		end
	end
	if not slot then
		player:Kick("Server đầy farm rồi, thử server khác nha!")
		return
	end
	slot.owner = player
	slot.model:SetAttribute("OwnerUserId", player.UserId)
	slot.signLabel.Text = "🌾 Farm của " .. player.DisplayName

	local timers = {}
	for _, animal in Config.Animals do
		timers[animal.id] = 0
	end
	sessions[player] = {
		farm = slot,
		selectedSeed = Config.Crops[1].id,
		animalTimers = timers,
		dirty = false,
		lastAction = 0,
	}

	-- Cây vẫn lớn khi offline (chỉ tính pass vĩnh viễn, không tính boost)
	local offline = math.max(0, now() - (profile.lastSave or now()))
	local offlineMult = if player:GetAttribute("FastGrow") then Config.Multipliers.FastGrowPass else 1
	for key, plot in profile.plots do
		local info = Config.CropById[plot.crop]
		if info then
			plot.progress = math.min(info.growTime, plot.progress + offline * offlineMult)
		else
			profile.plots[key] = nil -- cây đã bị xoá khỏi Config
		end
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = profile.coins
	coins.Parent = leaderstats
	leaderstats.Parent = player

	renderAllTiles(player)
	renderPen(player)
	FarmService.PushState(player)

	player.CharacterAdded:Connect(function(character)
		teleportHome(player, character)
	end)
	if player.Character then
		task.spawn(teleportHome, player, player.Character)
	end
end

function FarmService.OnPlayerRemoving(player)
	local session = sessions[player]
	if not session then
		return
	end
	local slot = session.farm
	sessions[player] = nil
	slot.owner = nil
	slot.model:SetAttribute("OwnerUserId", 0)
	slot.signLabel.Text = "🌾 Farm trống"
	for _, tile in slot.tiles do
		local crop = tile:FindFirstChild("Crop")
		if crop then
			crop:Destroy()
		end
		tile.Color = SOIL_COLOR
		tile.Material = Enum.Material.Ground
		tile.Transparency = 0
		tile.Prompt.ObjectText = ""
		tile.Prompt.ActionText = "..."
	end
	for _, child in slot.pen:GetChildren() do
		if Config.AnimalById[child.Name] then
			child:Destroy()
		end
	end
end

-- ================= Vòng lặp chính =================

local function tick(dt)
	for player, session in sessions do
		local profile = DataService.Profiles[player]
		if not profile then
			continue
		end

		local growMult = FarmService.GetGrowthMultiplier(player)
		for key, plot in profile.plots do
			local info = Config.CropById[plot.crop]
			if info and plot.progress < info.growTime then
				plot.progress = math.min(info.growTime, plot.progress + dt * growMult)
				renderTile(player, tonumber(key))
			end
		end

		for _, animal in Config.Animals do
			local count = profile.animals[animal.id] or 0
			if count > 0 then
				local timer = session.animalTimers[animal.id] + dt
				while timer >= animal.interval do
					timer -= animal.interval
					profile.inventory[animal.product] = (profile.inventory[animal.product] or 0) + count
					session.dirty = true
				end
				session.animalTimers[animal.id] = timer
			end
		end

		if session.dirty then
			session.dirty = false
			FarmService.PushState(player)
		end
	end
end

function FarmService.Start(remoteFolder)
	remotes = remoteFolder

	local farmsFolder = Instance.new("Folder")
	farmsFolder.Name = "Farms"
	farmsFolder.Parent = workspace
	for i = 1, Config.MaxFarms do
		farmSlots[i] = buildFarm(i)
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

	task.spawn(function()
		while true do
			task.wait(3)
			for _, slot in farmSlots do
				if slot.owner then
					wanderAnimals(slot.pen)
				end
			end
		end
	end)
end

return FarmService
