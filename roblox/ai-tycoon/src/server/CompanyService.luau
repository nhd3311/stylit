-- Công ty của người chơi: lô đất, tòa nhà xây theo tầng, thang máy, kệ GPU, gõ code dạo,
-- máy thu token, train AI, và mọi hệ số nhân $ / token.
-- Server là "trọng tài": client chỉ gửi yêu cầu, server tự kiểm tra tiền/quyền rồi mới làm.
--
-- Các service khác cắm vào đây qua:
--   RegisterAction(name, fn)     thêm hành động client được gọi
--   RegisterStateProvider(fn)    thêm field vào State gửi client
--   RegisterTerminalHook(fn)     chạy khi người chơi bấm Máy thu token

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Visuals = require(script.Parent.Visuals)
local WorldService = require(script.Parent.WorldService)

local TICK = 1
local COLORS = Visuals.Colors
local H = Config.FloorHeight
local BUILDING_W, BUILDING_D = 56, 44
local RACK_X = { -21, -13.5, 13.5, 21 } -- vị trí 4 kệ trong 1 tầng (hai bên thang máy)
local ACCENTS = {
	Color3.fromRGB(0, 200, 255),
	Color3.fromRGB(255, 90, 170),
	Color3.fromRGB(120, 255, 140),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(170, 110, 255),
	Color3.fromRGB(255, 130, 60),
	Color3.fromRGB(80, 255, 230),
	Color3.fromRGB(255, 80, 80),
}

local CompanyService = {}

local remotes
local lots = {} -- [index] = lot (xem buildLot)
local sessions = {} -- [player] = { lot, lastAction, lastClick }
local actions = {}
local stateProviders = {}
local terminalHooks = {}

-- ================= Tiện ích =================

function CompanyService.Notify(player, message, action)
	remotes.Notify:FireClient(player, message, action)
end
local notify = CompanyService.Notify

function CompanyService.NotifyAll(message, action)
	remotes.Notify:FireAllClients(message, action)
end

local function isVip(player)
	return player:GetAttribute("VIP") == true
end

local function hasAutoCollect(player)
	return player:GetAttribute("AutoCollect") == true
end

local function boostOn(profile, name)
	return (profile.boosts[name] or 0) > os.time()
end

function CompanyService.RegisterAction(name, handler)
	actions[name] = handler
end

function CompanyService.RegisterStateProvider(provider)
	table.insert(stateProviders, provider)
end

function CompanyService.RegisterTerminalHook(hook)
	table.insert(terminalHooks, hook)
end

function CompanyService.GetLots()
	return lots
end

function CompanyService.GetLot(player)
	local session = sessions[player]
	return session and session.lot
end

-- Tầng `floorIndex` đã dùng được chưa (Penthouse cần VIP)
function CompanyService.HasFloor(player, profile, floorIndex)
	local floor = Config.Floors[floorIndex]
	if not floor then
		return false
	end
	if floor.vip then
		return isVip(player)
	end
	return floorIndex <= profile.floorsBuilt
end

local function floorIndexOf(id)
	for index, floor in Config.Floors do
		if floor.id == id then
			return index
		end
	end
	return nil
end
CompanyService.FloorIndexOf = floorIndexOf

-- ================= Hệ số nhân =================

local function effects(profile)
	return Config.ResearchEffects(profile.research.done)
end

-- Hệ số cho mọi khoản $ (click, sản phẩm, ra mắt, ổ dữ liệu, quà...)
function CompanyService.CashMultiplier(player)
	local profile = DataService.Profiles[player]
	if not profile then
		return 1
	end
	local mult = Config.LevelMultiplier(profile.ai.level) * Config.FounderMultiplier(profile.founderPoints)
	if isVip(player) then
		mult *= Config.Multipliers.VipCash
	end
	if boostOn(profile, "Cash") then
		mult *= Config.Multipliers.CashBoost
	end
	if CompanyService.HasFloor(player, profile, floorIndexOf("CEO")) then
		mult *= Config.CeoIncomeBonus
	end
	return mult * (1 + effects(profile).income)
end

-- Hệ số token từ GPU
function CompanyService.TokenMultiplier(player)
	local profile = DataService.Profiles[player]
	if not profile then
		return 1
	end
	local mult = Config.LevelMultiplier(profile.ai.level) * Config.FounderMultiplier(profile.founderPoints)
	if boostOn(profile, "Tokens") then
		mult *= Config.Multipliers.TokenBoost
	end
	return mult * (1 + effects(profile).gpu)
end

-- Tốc độ nghiên cứu / phát triển sản phẩm (1 = bình thường)
function CompanyService.ResearchSpeed(player, kind)
	local profile = DataService.Profiles[player]
	if not profile then
		return 1
	end
	local fx = effects(profile)
	local speed = 1 + (if kind == "dev" then fx.dev else fx.research)
	if boostOn(profile, "Research") then
		speed *= Config.Multipliers.ResearchBoost
	end
	return speed
end

function CompanyService.LaunchMultiplier(player)
	local profile = DataService.Profiles[player]
	return CompanyService.CashMultiplier(player) * (1 + (if profile then effects(profile).launch else 0))
end

local function rackRate(player, rack)
	local gpu = Config.GpuById[rack.gpu]
	return if gpu then gpu.rate * CompanyService.TokenMultiplier(player) else 0
end

-- Token/giây của cả tòa nhà
function CompanyService.TokenRate(player)
	local profile = DataService.Profiles[player]
	if not profile then
		return 0
	end
	local total = 0
	for key, rack in profile.racks do
		local slot = Config.RackSlots[tonumber(key)]
		if slot and CompanyService.HasFloor(player, profile, slot.floor) then
			total += rackRate(player, rack)
		end
	end
	return total
end

-- $/giây từ các sản phẩm đã ra mắt
function CompanyService.CashRate(player)
	local profile = DataService.Profiles[player]
	if not profile then
		return 0
	end
	return Config.ProductIncome(profile.products) * CompanyService.CashMultiplier(player)
end

-- ================= Tiền =================

function CompanyService.AddCash(player, amount)
	local profile = DataService.Profiles[player]
	if not profile or amount <= 0 then
		return
	end
	profile.cash += amount
	profile.totalEarned += amount
	profile.runEarned += amount
end

function CompanyService.AddTokens(player, amount)
	local profile = DataService.Profiles[player]
	if profile and amount > 0 then
		profile.tokens += amount
	end
end

-- ================= Đồng bộ với client =================

function CompanyService.PushState(player)
	local profile = DataService.Profiles[player]
	if not profile or not sessions[player] then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats["$"].Value = math.floor(profile.cash)
		stats["AI Lv"].Value = profile.ai.level
	end

	local buffered = 0
	for _, rack in profile.racks do
		buffered += rack.buffer or 0
	end

	local state = {
		cash = profile.cash,
		tokens = profile.tokens,
		cashRate = CompanyService.CashRate(player),
		tokenRate = CompanyService.TokenRate(player),
		buffered = buffered,
		level = profile.ai.level,
		xp = profile.ai.xp,
		xpNext = Config.XpToNext(profile.ai.level),
		floorsBuilt = profile.floorsBuilt,
		boosts = profile.boosts,
		clickCash = Config.Click.BaseCash * CompanyService.CashMultiplier(player),
		trainBonus = if CompanyService.HasFloor(player, profile, floorIndexOf("AICenter")) then Config.AICenterTrainBonus else 1,
		vip = isVip(player),
		autoCollect = hasAutoCollect(player),
		founderPoints = profile.founderPoints,
		sold = profile.sold,
		runEarned = profile.runEarned,
	}
	for _, provider in stateProviders do
		provider(player, profile, state)
	end
	remotes.State:FireClient(player, state)
end

-- ================= Tòa nhà =================

-- Độ cao (tầng thứ mấy tính từ đất) của tầng `floorIndex`. Penthouse luôn nằm trên cùng.
local function levelOf(profile, floorIndex)
	if Config.Floors[floorIndex].vip then
		return profile.floorsBuilt + 1
	end
	return floorIndex
end

local function floorBase(lot, level)
	return lot.base * CFrame.new(0, (level - 1) * H + 0.6, 0)
end

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

-- Bàn/máy có nút E mở 1 bảng UI ở client
local function station(parent, cframe, size, color, title, actionText, panel, owner)
	local part = Visuals.Part({
		Name = "Station",
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
	})
	Visuals.Label(part, title, UDim2.fromScale(10, 2), Vector3.new(0, size.Y / 2 + 1.5, 0))
	local prompt = makePrompt(part, title, actionText)
	prompt.Triggered:Connect(function(player)
		if player == owner then
			notify(player, "", "Open:" .. panel)
		end
	end)
	part.Parent = parent
	return part
end

local function renderRack(player, slotIndex)
	local session = sessions[player]
	local profile = DataService.Profiles[player]
	if not session or not profile then
		return
	end
	local info = Config.RackSlots[slotIndex]
	local floorData = session.lot.floors[info.floor]
	local rackPart = floorData and floorData.racks[slotIndex]
	if not rackPart then
		return
	end
	local prompt = rackPart.Prompt
	local label = rackPart.Info.Text
	local rack = profile.racks[tostring(slotIndex)]

	if not rack then
		local first = Config.Gpus[1]
		Visuals.PaintRack(rackPart, nil)
		label.Text = "Trống"
		prompt.ObjectText = "Kệ trống"
		prompt.ActionText = string.format("Lắp %s %s (%s)", first.emoji, first.name, Config.Money(first.price))
		return
	end

	local gpu = Config.GpuById[rack.gpu]
	local nextGpu = Config.Gpus[Config.GpuTier[rack.gpu] + 1]
	Visuals.PaintRack(rackPart, gpu.color)
	prompt.ObjectText = string.format("%s %s • %s🪙/s", gpu.emoji, gpu.name, Config.Short(rackRate(player, rack)))
	if not nextGpu then
		prompt.ActionText = "Đã max cấp 🔥"
	elseif profile.ai.level < nextGpu.level then
		prompt.ActionText = string.format("Cần AI Lv.%d để lên %s", nextGpu.level, nextGpu.name)
	else
		prompt.ActionText = string.format("Nâng lên %s %s (%s)", nextGpu.emoji, nextGpu.name, Config.Money(nextGpu.price))
	end
	if hasAutoCollect(player) then
		label.Text = gpu.emoji
	else
		local full = (rack.buffer or 0) >= rackRate(player, rack) * Config.Racks.BufferSeconds
		label.Text = string.format("%s 🪙%s%s", gpu.emoji, Config.Short(rack.buffer or 0), if full then " <font color='#ff5050'>ĐẦY!</font>" else "")
	end
end

local function renderAllRacks(player)
	for slotIndex in Config.RackSlots do
		renderRack(player, slotIndex)
	end
end

local function onRackPrompt(player, lot, slotIndex)
	local session = sessions[player]
	local profile = DataService.Profiles[player]
	if not session or not profile or session.lot ~= lot then
		return
	end
	local key = tostring(slotIndex)
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
	if profile.cash < target.price then
		notify(player, string.format("Cần %s để mua %s 💵", Config.Money(target.price), target.name))
		return
	end
	profile.cash -= target.price
	if rack then
		rack.gpu = target.id
	else
		profile.racks[key] = { gpu = target.id, buffer = 0 }
	end
	notify(player, string.format("Đã lắp %s %s!", target.emoji, target.name), "Collect")
	renderRack(player, slotIndex)
	CompanyService.PushState(player)
end

-- Dựng nội thất theo loại tầng
local function furnish(lot, folder, floorIndex, base, owner)
	local floor = Config.Floors[floorIndex]
	local floorData = { folder = folder, racks = {} }

	-- thang máy ở giữa vách sau, tầng nào cũng có
	local elevator = Visuals.Part({
		Name = "Elevator",
		Size = Vector3.new(8, 10, 1),
		CFrame = base * CFrame.new(0, 5, -BUILDING_D / 2 + 1.2),
		Color = Color3.fromRGB(180, 185, 195),
		Material = Enum.Material.Metal,
		Reflectance = 0.2,
	})
	Visuals.Label(elevator, "🛗 Thang máy", UDim2.fromScale(8, 1.6), Vector3.new(0, 6.2, 0))
	makePrompt(elevator, "Thang máy", "Chọn tầng").Triggered:Connect(function(player)
		if player == owner then
			notify(player, "", "Open:Elevator")
		end
	end)
	elevator.Parent = folder

	-- tên tầng
	Visuals.Label(
		Visuals.Part({ Name = "FloorTag", Size = Vector3.one, CFrame = base * CFrame.new(0, 11, -BUILDING_D / 2 + 1.2), Transparency = 1, CanCollide = false }),
		string.format("%s Tầng %d: %s", floor.emoji, floorIndex, floor.name),
		UDim2.fromScale(18, 2),
		Vector3.zero
	).Parent.Parent.Parent = folder

	-- kệ máy chủ
	if floor.racks then
		local n = 0
		for slotIndex, info in Config.RackSlots do
			if info.floor == floorIndex then
				n += 1
				local rackPart = Visuals.BuildRack(base * CFrame.new(RACK_X[n], 4, -BUILDING_D / 2 + 5))
				rackPart.Name = "Rack" .. slotIndex
				Visuals.Label(rackPart, "", UDim2.fromScale(7, 1.6), Vector3.new(0, 5.5, 0)).Parent.Name = "Info"
				makePrompt(rackPart).Triggered:Connect(function(player)
					onRackPrompt(player, lot, slotIndex)
				end)
				rackPart.Parent = folder
				floorData.racks[slotIndex] = rackPart
			end
		end
	end

	if floor.kind == "Lobby" then
		local terminal = Visuals.Part({
			Name = "Terminal",
			Size = Vector3.new(4, 4, 2),
			CFrame = base * CFrame.new(-16, 2, 12),
			Color = Color3.fromRGB(40, 220, 140),
			Material = Enum.Material.Neon,
		})
		Visuals.Light(terminal, terminal.Color, 12, 1.5)
		Visuals.Label(terminal, "🪙 Máy thu token", UDim2.fromScale(10, 2), Vector3.new(0, 4, 0))
		makePrompt(terminal, "Máy thu token", "Thu tất cả", 10).Triggered:Connect(function(player)
			CompanyService.OnTerminal(player, lot)
		end)
		terminal.Parent = folder
		lot.terminal = terminal
		station(folder, base * CFrame.new(0, 1.75, 6), Vector3.new(12, 3.5, 3), Color3.fromRGB(235, 235, 240), "🏗️ Lễ tân: Xây tầng", "Xem", "Build", owner)
	elseif floor.kind == "Lab" then
		Visuals.Part({
			Name = "Pedestal",
			Size = Vector3.new(7, 2, 7),
			CFrame = base * CFrame.new(0, 1, 0),
			Color = COLORS.metal,
			Material = Enum.Material.Metal,
		}).Parent = folder
		local stage = Config.AIStages[1]
		floorData.core = Visuals.BuildCore(folder, base * CFrame.new(0, 7, 0), stage.color)
		floorData.coreLabel = Visuals.Label(floorData.core, "🤖 AI", UDim2.fromScale(14, 2.5), Vector3.new(0, 7, 0))
		station(folder, base * CFrame.new(-18, 2, 12), Vector3.new(6, 4, 3), Color3.fromRGB(90, 140, 255), "🔬 Bàn nghiên cứu", "Mở R&D", "Research", owner)
		station(folder, base * CFrame.new(18, 2, 12), Vector3.new(6, 4, 3), Color3.fromRGB(170, 100, 255), "🧠 Train AI", "Mở", "AI", owner)
	elseif floor.kind == "Studio" then
		for i, x in { -16, -6, 4 } do
			station(folder, base * CFrame.new(x, 1.75, 4), Vector3.new(7, 3.5, 3), Color3.fromRGB(60, 60, 70), if i == 2 then "🚀 Bàn phát triển" else "💻", "Sản phẩm", "Products", owner)
		end
		local screen = Visuals.Part({
			Name = "LaunchScreen",
			Size = Vector3.new(20, 9, 0.5),
			CFrame = base * CFrame.new(12, 6, 18), -- mặt trước (-Z) nhìn vào trong phòng
			Color = Color3.fromRGB(15, 15, 25),
			Material = Enum.Material.SmoothPlastic,
		})
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.BuilderSansExtraBold
		text.TextScaled = true
		text.RichText = true
		text.TextColor3 = Color3.fromRGB(120, 220, 255)
		text.Text = "🚀 SẴN SÀNG RA MẮT"
		text.Parent = gui
		gui.Parent = screen
		screen.Parent = folder
		floorData.screen = text
	elseif floor.kind == "AICenter" then
		for i = 1, 6 do
			local pillar = Visuals.Part({
				Name = "NeuralPillar",
				Size = Vector3.new(2, 11, 2),
				CFrame = base * CFrame.new(-20 + (i - 1) * 8, 5.5, 4),
				Color = Color3.fromRGB(170, 100, 255),
				Material = Enum.Material.Neon,
				Transparency = 0.3,
			})
			pillar:SetAttribute("Blink", true)
			pillar.Parent = folder
		end
		station(folder, base * CFrame.new(0, 2, 14), Vector3.new(8, 4, 3), Color3.fromRGB(170, 100, 255), "🧠 Train AI (x1.5)", "Mở", "AI", owner)
	elseif floor.kind == "CEO" then
		station(folder, base * CFrame.new(0, 1.75, 4), Vector3.new(14, 3.5, 5), Color3.fromRGB(90, 60, 40), "👔 Bàn CEO: Bán công ty", "Mở", "Sell", owner)
		Visuals.Part({
			Name = "Sofa",
			Size = Vector3.new(12, 3, 4),
			CFrame = base * CFrame.new(-16, 1.5, 14),
			Color = Color3.fromRGB(40, 40, 50),
			Material = Enum.Material.Fabric,
		}).Parent = folder
		station(folder, base * CFrame.new(18, 2, 14), Vector3.new(6, 4, 3), Color3.fromRGB(0, 170, 110), "📈 Bảng chứng khoán", "Mở", "Stocks", owner)
	end
	return floorData
end

local function destroyFloor(lot, floorIndex)
	local data = lot.floors[floorIndex]
	if data then
		data.folder:Destroy()
		lot.floors[floorIndex] = nil
	end
end

-- Dựng tòa nhà cho khớp với data: thêm tầng còn thiếu, dời Penthouse + nóc lên trên cùng
function CompanyService.RenderBuilding(player)
	local session = sessions[player]
	local profile = DataService.Profiles[player]
	if not session or not profile then
		return
	end
	local lot = session.lot
	for floorIndex, floor in Config.Floors do
		local has = CompanyService.HasFloor(player, profile, floorIndex)
		local level = levelOf(profile, floorIndex)
		local data = lot.floors[floorIndex]
		if data and (not has or data.level ~= level) then
			destroyFloor(lot, floorIndex)
			data = nil
		end
		if has and not data then
			local folder = Instance.new("Folder")
			folder.Name = "Floor" .. floorIndex
			local base = floorBase(lot, level)
			Visuals.BuildFloorShell(folder, base, BUILDING_W, BUILDING_D, H, floor.kind == "Lobby", if floor.vip then COLORS.vip else lot.accent)
			data = furnish(lot, folder, floorIndex, base, player)
			data.level = level
			data.base = base
			folder.Parent = lot.model
			lot.floors[floorIndex] = data
		end
	end

	-- nóc nhà
	local topLevel = profile.floorsBuilt + (if isVip(player) then 1 else 0)
	if lot.roof and lot.roofLevel ~= topLevel then
		lot.roof:Destroy()
		lot.roof = nil
	end
	if not lot.roof then
		lot.roof = Instance.new("Folder")
		lot.roof.Name = "Roof"
		-- -0.4 để mái khít ngay trên mép kính của tầng cao nhất (giống cách đặt sàn các tầng)
		lot.roofLabel = Visuals.BuildRoof(lot.roof, lot.base * CFrame.new(0, topLevel * H - 0.4, 0), BUILDING_W, BUILDING_D, lot.accent)
		lot.roofLevel = topLevel
		lot.roof.Parent = lot.model
	end
	local rank = Config.CompanyRank(profile.sold)
	lot.roofLabel.Text = string.format("%s CORP\n<font size='30' color='#FFFFFF'>%s</font>", string.upper(player.DisplayName), rank.name)

	renderAllRacks(player)
	CompanyService.RenderCore(player)
end

function CompanyService.RenderCore(player)
	local session = sessions[player]
	local profile = DataService.Profiles[player]
	local lab = session and session.lot.floors[floorIndexOf("Lab")]
	if not profile or not lab then
		return
	end
	local stage = Config.StageFor(profile.ai.level)
	Visuals.PaintCore(lab.core, stage.color, stage.size)
	lab.coreLabel.Text = string.format("%s %s • Lv.%d", stage.emoji, stage.name, profile.ai.level)
end

-- Màn hình ở Studio Sản Phẩm (ProductService cập nhật)
function CompanyService.SetStudioScreen(player, text)
	local lot = CompanyService.GetLot(player)
	local studio = lot and lot.floors[floorIndexOf("Studio")]
	if studio and studio.screen.Text ~= text then
		studio.screen.Text = text
	end
end

-- Toạ độ đứng ở tầng `floorIndex` (đứng trước thang máy, nhìn ra mặt tiền)
function CompanyService.FloorSpawn(player, floorIndex)
	local lot = CompanyService.GetLot(player)
	local profile = DataService.Profiles[player]
	if not lot or not profile then
		return nil
	end
	return floorBase(lot, levelOf(profile, floorIndex)) * CFrame.new(0, 3, -BUILDING_D / 2 + 7) * CFrame.Angles(0, math.pi, 0)
end

-- Bán công ty: dỡ hết tòa nhà rồi dựng lại từ sảnh
function CompanyService.ResetBuilding(player)
	local lot = CompanyService.GetLot(player)
	if not lot then
		return
	end
	for floorIndex in Config.Floors do
		destroyFloor(lot, floorIndex)
	end
	if lot.roof then
		lot.roof:Destroy()
		lot.roof = nil
	end
	CompanyService.RenderBuilding(player)
	CompanyService.Teleport(player, lot.spawn)
end

function CompanyService.Teleport(player, cframe)
	local character = player.Character
	if character and cframe then
		character:PivotTo(cframe)
	end
end

-- ================= Hành động =================

local function collectAll(profile)
	local total = 0
	for _, rack in profile.racks do
		total += rack.buffer or 0
		rack.buffer = 0
	end
	return total
end

function CompanyService.OnTerminal(player, lot)
	local session = sessions[player]
	local profile = DataService.Profiles[player]
	if not session or not profile or session.lot ~= lot then
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
		CompanyService.AddTokens(player, total)
		notify(player, "Thu được +" .. Config.Short(total) .. " 🪙 token", "Collect")
	elseif not handled then
		notify(player, "Chưa có token nào để thu. Lắp GPU đi! 🖥️")
	end
	renderAllRacks(player)
	CompanyService.PushState(player)
end

function actions.Click(player, profile, session)
	local t = os.clock()
	if t - session.lastClick < Config.Click.MinInterval then
		return
	end
	session.lastClick = t
	CompanyService.AddCash(player, Config.Click.BaseCash * CompanyService.CashMultiplier(player))
	profile.totalClicks += 1
	-- không PushState ở đây: vòng tick 1 giây sẽ gửi, đỡ spam mạng
end

function actions.BuildFloor(player, profile)
	local nextIndex = profile.floorsBuilt + 1
	local floor = Config.Floors[nextIndex]
	if not floor or floor.vip then
		notify(player, "Tòa nhà đã cao hết cỡ rồi, quá trùm 🏙️")
		return
	end
	if profile.cash < floor.price then
		notify(player, string.format("Cần %s để xây %s 💵", Config.Money(floor.price), floor.name))
		return
	end
	profile.cash -= floor.price
	profile.floorsBuilt = nextIndex
	notify(player, string.format("🏗️ Đã xây xong Tầng %d: %s %s!", nextIndex, floor.emoji, floor.name), "Evolve")
	CompanyService.RenderBuilding(player)
	CompanyService.PushState(player)
end

function actions.Elevator(player, profile, session, floorIndex)
	if type(floorIndex) ~= "number" or not CompanyService.HasFloor(player, profile, floorIndex) then
		return
	end
	CompanyService.Teleport(player, CompanyService.FloorSpawn(player, floorIndex))
end

function actions.Home(player, profile, session)
	CompanyService.Teleport(player, session.lot.spawn)
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
		notify(player, "Không đủ token để train. Lắp GPU rồi ra Máy thu token đi! 🪙")
		return
	end
	profile.tokens -= amount
	local bonus = if CompanyService.HasFloor(player, profile, floorIndexOf("AICenter")) then Config.AICenterTrainBonus else 1
	profile.ai.xp += amount * bonus

	local startLevel = profile.ai.level
	while profile.ai.level < Config.AI.MaxLevel and profile.ai.xp >= Config.XpToNext(profile.ai.level) do
		profile.ai.xp -= Config.XpToNext(profile.ai.level)
		profile.ai.level += 1
	end
	if profile.ai.level >= Config.AI.MaxLevel then
		profile.ai.xp = 0
	end
	if profile.ai.level > startLevel then
		local stage = Config.StageFor(profile.ai.level)
		if stage ~= Config.StageFor(startLevel) then
			notify(player, string.format("🎉 AI tiến hoá thành %s %s!", stage.emoji, stage.name), "Evolve")
		else
			local bonusPct = math.floor((Config.LevelMultiplier(profile.ai.level) - 1) * 100 + 0.5)
			notify(player, string.format("🧠 AI lên Lv.%d! Thu nhập +%d%%", profile.ai.level, bonusPct), "LevelUp")
		end
		CompanyService.RenderCore(player)
		renderAllRacks(player)
	end
	CompanyService.PushState(player)
end

local function onAction(player, actionName, ...)
	local session = sessions[player]
	local profile = DataService.Profiles[player]
	local handler = type(actionName) == "string" and actions[actionName]
	if not session or not profile or not handler then
		return
	end
	if actionName ~= "Click" then
		local t = os.clock()
		if t - session.lastAction < 0.15 then
			return
		end
		session.lastAction = t
	end
	handler(player, profile, session, ...)
end

-- Gọi từ MonetizationService khi mua Time Warp: nhận $ và token của `hours` giờ
function CompanyService.TimeWarp(player, hours)
	local cash = CompanyService.CashRate(player) * hours * 3600
	local tokens = CompanyService.TokenRate(player) * hours * 3600
	CompanyService.AddCash(player, cash)
	CompanyService.AddTokens(player, tokens)
	return cash, tokens
end

-- Gọi khi quyền VIP / Auto Collect thay đổi (vừa mua xong)
function CompanyService.Refresh(player)
	local profile = DataService.Profiles[player]
	if sessions[player] and profile then
		if hasAutoCollect(player) then
			CompanyService.AddTokens(player, collectAll(profile))
		end
		CompanyService.RenderBuilding(player)
		CompanyService.PushState(player)
	end
end

-- ================= Lô đất =================

local function buildLot(index)
	local origin = WorldService.LotOrigin(index)
	local model = Instance.new("Folder")
	model.Name = "Lot" .. index
	model:SetAttribute("OwnerUserId", 0)

	-- sân bê tông + bãi đỗ xe phía trước
	Visuals.Part({
		Name = "Ground",
		Size = Vector3.new(85, 0.6, 105),
		CFrame = origin * CFrame.new(0, -0.15, 0),
		Color = Color3.fromRGB(165, 165, 170),
		Material = Enum.Material.Concrete,
	}).Parent = model
	for i = -3, 3 do
		Visuals.Part({
			Name = "ParkingLine",
			Size = Vector3.new(0.3, 0.05, 9),
			CFrame = origin * CFrame.new(i * 7, 0.17, 36),
			Color = Color3.fromRGB(245, 245, 245),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		}).Parent = model
	end
	for _, x in { -38, 38 } do
		for _, z in { 12, 46 } do
			local trunk = Visuals.Part({
				Name = "Trunk",
				Size = Vector3.new(1.2, 6, 1.2),
				CFrame = origin * CFrame.new(x, 3, z),
				Color = Color3.fromRGB(100, 70, 45),
				Material = Enum.Material.Wood,
			})
			trunk.Parent = model
			Visuals.Part({
				Name = "Leaves",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 6.5,
				CFrame = origin * CFrame.new(x, 7.5, z),
				Color = Color3.fromRGB(70, 150, 70),
				Material = Enum.Material.Grass,
				CanCollide = false,
			}).Parent = model
		end
	end

	-- biển lô đất trống
	local sign = Visuals.Part({
		Name = "LotSign",
		Size = Vector3.new(1, 7, 1),
		CFrame = origin * CFrame.new(-30, 3.5, 50),
		Color = COLORS.metal,
		Material = Enum.Material.Metal,
	})
	local signLabel = Visuals.Label(sign, "🏗️ Lô đất trống", UDim2.fromScale(16, 3), Vector3.new(0, 6, 0))
	sign.Parent = model

	model.Parent = workspace:WaitForChild("Lots")
	return {
		index = index,
		model = model,
		origin = origin,
		base = origin * CFrame.new(0, 0, -22), -- tâm chân tòa nhà, mặt tiền (cửa) quay về +Z
		spawn = origin * CFrame.new(0, 4, 40),
		accent = ACCENTS[index],
		signLabel = signLabel,
		floors = {},
		owner = nil,
	}
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
		character:PivotTo(session.lot.spawn)
	end
end

function CompanyService.OnPlayerLoaded(player, profile)
	local lot
	for _, candidate in lots do
		if not candidate.owner then
			lot = candidate
			break
		end
	end
	if not lot then
		player:Kick("Thung lũng hết đất rồi, thử server khác nha!")
		return
	end
	lot.owner = player
	lot.model:SetAttribute("OwnerUserId", player.UserId)
	lot.signLabel.Text = "🏢 " .. player.DisplayName .. " Corp."

	sessions[player] = { lot = lot, lastAction = 0, lastClick = 0 }

	for key, rack in profile.racks do
		if not Config.GpuById[rack.gpu] or not Config.RackSlots[tonumber(key)] then
			profile.racks[key] = nil
		end
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("NumberValue")
	cash.Name = "$"
	cash.Parent = leaderstats
	local level = Instance.new("IntValue")
	level.Name = "AI Lv"
	level.Parent = leaderstats
	leaderstats.Parent = player

	-- Lúc offline: GPU vẫn đào, sản phẩm vẫn bán, R&D vẫn chạy (có giới hạn giờ)
	local hours = if isVip(player) then Config.VipOfflineHours else Config.OfflineHours
	local offline = math.clamp(os.time() - (profile.lastSave or os.time()), 0, hours * 3600)
	if offline > 60 then
		local cashEarned = math.floor(CompanyService.CashRate(player) * offline)
		local tokensEarned = math.floor(CompanyService.TokenRate(player) * offline)
		CompanyService.AddCash(player, cashEarned)
		CompanyService.AddTokens(player, tokensEarned)
		if profile.research.current then
			profile.research.current.progress += offline * CompanyService.ResearchSpeed(player, "research")
		end
		if profile.dev then
			profile.dev.progress += offline * CompanyService.ResearchSpeed(player, "dev")
		end
		if cashEarned + tokensEarned > 0 then
			task.delay(3, function()
				if player.Parent then
					notify(player, string.format("Lúc bạn vắng mặt công ty kiếm được +%s và +%s 🪙 💸", Config.Money(cashEarned), Config.Short(tokensEarned)))
				end
			end)
		end
	end

	CompanyService.RenderBuilding(player)
	CompanyService.PushState(player)

	player.CharacterAdded:Connect(function(character)
		teleportHome(player, character)
	end)
	if player.Character then
		task.spawn(teleportHome, player, player.Character)
	end
end

function CompanyService.OnPlayerRemoving(player)
	local session = sessions[player]
	if not session then
		return
	end
	local lot = session.lot
	sessions[player] = nil
	lot.owner = nil
	lot.model:SetAttribute("OwnerUserId", 0)
	lot.signLabel.Text = "🏗️ Lô đất trống"
	for floorIndex in Config.Floors do
		destroyFloor(lot, floorIndex)
	end
	if lot.roof then
		lot.roof:Destroy()
		lot.roof = nil
	end
	lot.terminal = nil
end

-- ================= Vòng lặp chính =================

local function tick(dt)
	for player in sessions do
		local profile = DataService.Profiles[player]
		if not profile then
			continue
		end
		CompanyService.AddCash(player, CompanyService.CashRate(player) * dt)
		local auto = hasAutoCollect(player)
		for key, rack in profile.racks do
			local slotIndex = tonumber(key)
			local slot = Config.RackSlots[slotIndex]
			if not slot or not CompanyService.HasFloor(player, profile, slot.floor) then
				continue
			end
			local rate = rackRate(player, rack)
			if auto then
				CompanyService.AddTokens(player, rate * dt)
			else
				rack.buffer = math.min(rate * Config.Racks.BufferSeconds, (rack.buffer or 0) + rate * dt)
				renderRack(player, slotIndex)
			end
		end
		CompanyService.PushState(player)
	end
end

function CompanyService.Start(remoteFolder)
	remotes = remoteFolder
	local lotsFolder = Instance.new("Folder")
	lotsFolder.Name = "Lots"
	lotsFolder.Parent = workspace
	for i = 1, Config.MaxLots do
		lots[i] = buildLot(i)
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

return CompanyService
