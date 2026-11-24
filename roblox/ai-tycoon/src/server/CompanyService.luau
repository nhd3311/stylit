-- Công ty của người chơi: tòa nhà (Garage → Global HQ), chỗ làm việc + bàn ghế máy tính,
-- nhân viên là avatar ngồi ở bàn, nội thất theo cấp, màn hình Hype Wall ở sảnh,
-- đi lại giữa các tầng, code dạo, tiền và các hệ số.
-- Server là "trọng tài": client chỉ gửi yêu cầu, server tự kiểm tra tiền/quyền rồi mới làm.
--
-- Các service khác cắm vào đây qua RegisterAction(name, fn) và RegisterStateProvider(fn).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Visuals = require(script.Parent.Visuals)
local WorldService = require(script.Parent.WorldService)

local H = Config.FloorHeight
local ACCENT = Color3.fromRGB(0, 200, 255)
local GOLD = Color3.fromRGB(255, 200, 60)

local CompanyService = {}

local remotes
local lot -- lô đất trụ sở (server 1 người nên chỉ có 1)
local sessions = {} -- [player] = { lastAction, lastClick }
local actions = {}
local stateProviders = {}
local avatars = {} -- [staffId] = Model (giữ lại giữa các lần vẽ cho đỡ tạo lại)
local creating = {} -- [staffId] = true khi đang tạo avatar

-- ================= Tiện ích =================

function CompanyService.Notify(player, message, action)
	remotes.Notify:FireClient(player, message, action)
end
local notify = CompanyService.Notify

function CompanyService.NotifyAll(message, action)
	remotes.Notify:FireAllClients(message, action)
end

function CompanyService.Popup(player, data)
	remotes.Popup:FireClient(player, data)
end

local function isVip(player)
	return player:GetAttribute("VIP") == true
end

function CompanyService.BoostOn(profile, name)
	return (profile.boosts[name] or 0) > os.time()
end

-- Hiệu ứng tạm thời từ sự kiện (Users, Compute, Research, Dev)
function CompanyService.Modifier(profile, kind)
	local mult = 1
	for _, mod in profile.modifiers do
		if mod.kind == kind and mod.untilDay >= profile.day then
			mult *= mod.mult
		end
	end
	return mult
end

function CompanyService.RegisterAction(name, handler)
	actions[name] = handler
end

function CompanyService.RegisterStateProvider(provider)
	table.insert(stateProviders, provider)
end

function CompanyService.IsActive(player)
	return sessions[player] ~= nil
end

-- ================= Hệ số nhân =================

function CompanyService.CashMultiplier(player)
	local profile = DataService.Profiles[player]
	if not profile then
		return 1
	end
	local mult = Config.FounderMultiplier(profile.founderPoints)
	if isVip(player) then
		mult *= Config.Multipliers.Vip
	end
	if CompanyService.BoostOn(profile, "Cash") then
		mult *= Config.Multipliers.CashBoost
	end
	return mult
end

-- Năng suất mỗi nhân viên (chưa tính tinh thần riêng từng người)
function CompanyService.WorkMultiplier(player)
	local profile = DataService.Profiles[player]
	if not profile then
		return 1
	end
	local mult = Config.EquipmentMult(profile.equip) * Config.FounderMultiplier(profile.founderPoints)
	if CompanyService.BoostOn(profile, "Work") then
		mult *= Config.Multipliers.WorkBoost
	end
	if player:GetAttribute("GoldenOffice") then
		mult *= Config.PassBonus.GoldenOffice
	end
	return mult
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

function CompanyService.Spend(player, amount, what)
	local profile = DataService.Profiles[player]
	if not profile then
		return false
	end
	if profile.cash < amount then
		notify(player, string.format("You need %s to %s 💸", Config.Money(amount), what))
		return false
	end
	profile.cash -= amount
	return true
end

-- ================= Đồng bộ với client =================

function CompanyService.PushState(player)
	local profile = DataService.Profiles[player]
	if not profile or not sessions[player] then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Cash.Value = math.floor(profile.cash)
	end
	local state = {
		cash = profile.cash,
		day = profile.day,
		speed = profile.speed,
		building = profile.building,
		workstations = profile.workstations,
		capacity = Config.Capacity(profile.building),
		equip = profile.equip,
		equipMult = Config.EquipmentMult(profile.equip),
		workMult = CompanyService.WorkMultiplier(player),
		cashMult = CompanyService.CashMultiplier(player),
		clickCash = Config.Click.BaseCash * CompanyService.CashMultiplier(player),
		totalEarned = profile.totalEarned,
		runEarned = profile.runEarned,
		boosts = profile.boosts,
		vip = isVip(player),
		fastUnlocked = isVip(player) or player:GetAttribute("TimeMachine") == true,
		founderPoints = profile.founderPoints,
		sold = profile.sold,
		researchDone = profile.research.done,
		shields = profile.shields,
	}
	for _, provider in stateProviders do
		provider(player, profile, state)
	end
	remotes.State:FireClient(player, state)
end

-- ================= Tòa nhà =================

local function building(profile)
	return Config.Buildings[profile.building]
end

local function seatCFrame(profile, index)
	local b = building(profile)
	local perFloor = b.cols * b.rows
	local floor = (index - 1) // perFloor + 1
	local i = (index - 1) % perFloor
	local c, r = i % b.cols, i // b.cols
	local cellW = (b.w - 12) / b.cols
	local cellD = (b.d - 14) / b.rows
	local x = -b.w / 2 + 6 + (c + 0.5) * cellW
	local z = -b.d / 2 + 5 + (r + 0.5) * cellD
	return lot.base * CFrame.new(x, (floor - 1) * H + 0.6, z), floor
end

local function floorBase(level)
	return lot.base * CFrame.new(0, (level - 1) * H + 0.6, 0)
end

function CompanyService.FloorSpawn(player, floor)
	local profile = DataService.Profiles[player]
	if not profile then
		return nil
	end
	local b = building(profile)
	if floor < 1 or floor > b.floors then
		return nil
	end
	return floorBase(floor) * CFrame.new(0, 3, b.d / 2 - 5)
end

function CompanyService.Teleport(player, cframe)
	local character = player.Character
	if character and cframe then
		character:PivotTo(cframe)
	end
end

-- Màn hình Hype Wall ở sảnh (ModelService cập nhật nội dung)
function CompanyService.SetHypeWall(text)
	if lot.hypeWall and lot.hypeWall.Parent then
		lot.hypeWall.Text = text
	end
	lot.hypeText = text
end

-- Xếp chỗ theo phòng ban: nhân viên cùng vai trò ngồi cạnh nhau. Ghế 1 luôn của Founder.
-- Trả về { [staffId] = số ghế } và danh sách nhân viên theo thứ tự ghế.
local ROLE_RANK = {}
for i, role in Config.RoleOrder do
	ROLE_RANK[role] = i
end
local function seatOrder(profile)
	local ordered = table.clone(profile.staff)
	table.sort(ordered, function(a, b)
		if a.role ~= b.role then
			return ROLE_RANK[a.role] < ROLE_RANK[b.role]
		end
		return a.id < b.id
	end)
	local seatOf = {}
	for i, staff in ordered do
		seatOf[staff.id] = i + 1
	end
	return seatOf, ordered
end

-- Tạo (hoặc dời) avatar của 1 nhân viên tới ghế số `seatIndex`
local function placeAvatar(profile, staff, seatIndex)
	local seat = seatCFrame(profile, seatIndex)
	local model = avatars[staff.id]
	if model and model.Parent then
		Visuals.SeatAvatar(model, seat)
		return
	end
	if creating[staff.id] then
		return
	end
	creating[staff.id] = true
	task.spawn(function()
		local role = Config.Roles[staff.role]
		local skin = Config.SkinTones[staff.id % #Config.SkinTones + 1]
		local pants = Config.PantsColors[staff.id % #Config.PantsColors + 1]
		local avatar = Visuals.BuildAvatar(staff.name, role.color, pants, skin)
		creating[staff.id] = nil
		if not avatar then
			-- không tạo được avatar thật (VD lỗi API): dùng hình khối thay thế
			avatar = Instance.new("Model")
			avatar.Name = staff.name
			Visuals.BuildPerson(avatar, CFrame.new(), role.color, role.emoji .. " " .. staff.name)
			avatar.PrimaryPart = avatar:FindFirstChild("Torso")
		end
		-- trong lúc chờ tạo, nhân viên có thể đã nghỉ hoặc đổi chỗ
		local current = DataService.Profiles[lot.owner]
		if not current or not lot.avatarFolder then
			avatar:Destroy()
			return
		end
		local seatIndex = seatOrder(current)[staff.id]
		if not seatIndex then
			avatar:Destroy()
			return
		end
		avatars[staff.id] = avatar
		if avatar:FindFirstChild("HumanoidRootPart") then
			Visuals.SeatAvatar(avatar, seatCFrame(current, seatIndex))
		else
			avatar:PivotTo(seatCFrame(current, seatIndex))
		end
		avatar.Parent = lot.avatarFolder
	end)
end

local function clearAvatars()
	for id, model in avatars do
		model:Destroy()
		avatars[id] = nil
	end
end

-- Dựng lại bàn ghế + xếp nhân viên vào chỗ (gọi khi thuê/sa thải/mua bàn/nâng cấp)
function CompanyService.RenderSeats(player)
	local profile = DataService.Profiles[player]
	if not profile or not lot.buildingFolder then
		return
	end
	if lot.seats then
		lot.seats:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Seats"
	local e = Config.Equipment
	local golden = player:GetAttribute("GoldenOffice") == true
	local tiers = {
		desk = if golden then { color = GOLD } else e.desk.tiers[profile.equip.desk],
		chair = if golden then { color = Color3.fromRGB(40, 30, 20) } else e.chair.tiers[profile.equip.chair],
		pc = e.pc.tiers[profile.equip.pc],
		pcIndex = profile.equip.pc,
	}
	local capacity = Config.Capacity(profile.building)
	for index = 1, math.min(profile.workstations, capacity) do
		local cf = seatCFrame(profile, index)
		Visuals.BuildWorkstation(folder, cf, tiers)
		if index == 1 then
			Visuals.Label(
				Visuals.Part({ Name = "FounderTag", Size = Vector3.one, CFrame = cf * CFrame.new(0, 5.5, 0), Transparency = 1, CanCollide = false, Parent = folder }),
				"👑 Your desk",
				UDim2.fromScale(6, 1.2),
				Vector3.zero
			)
		end
	end
	-- khu phòng ban: thảm màu dưới mỗi chỗ ngồi + biển tên ở chỗ đầu tiên của mỗi phòng
	local seatOf, ordered = seatOrder(profile)
	local b = building(profile)
	local cellW = (b.w - 12) / b.cols
	local cellD = (b.d - 14) / b.rows
	local lastRole
	for _, staff in ordered do
		local seat = seatOf[staff.id]
		if seat <= capacity then
			local cf = seatCFrame(profile, seat)
			local role = Config.Roles[staff.role]
			Visuals.Part({
				Name = "DeptRug",
				Size = Vector3.new(cellW - 0.6, 0.06, cellD - 0.4),
				CFrame = cf * CFrame.new(0, 0.13, 0.6),
				Color = role.color,
				Material = Enum.Material.Fabric,
				Transparency = 0.35,
				CanCollide = false,
				CanQuery = false,
				Parent = folder,
			})
			if staff.role ~= lastRole then
				lastRole = staff.role
				local dept = Config.Departments[staff.role]
				local level = profile.departments[staff.role] or 1
				Visuals.Label(
					Visuals.Part({ Name = "DeptSign", Size = Vector3.one, CFrame = cf * CFrame.new(0, 8.5, 0), Transparency = 1, CanCollide = false, Parent = folder }),
					string.format("%s %s • Lv.%d", dept.emoji, string.upper(dept.name), level),
					UDim2.fromScale(12, 1.8),
					Vector3.zero,
					role.color
				)
			end
		end
	end
	folder.Parent = lot.buildingFolder
	lot.seats = folder

	-- nhân viên: dời người cũ, tạo người mới, bỏ người đã nghỉ
	local employed = {}
	for _, staff in ordered do
		employed[staff.id] = true
		if seatOf[staff.id] <= capacity then
			placeAvatar(profile, staff, seatOf[staff.id])
		end
	end
	for id, model in avatars do
		if not employed[id] then
			model:Destroy()
			avatars[id] = nil
		end
	end
end

-- Nội thất theo cấp tòa nhà (đặt quanh mép phòng để không đụng bàn làm việc)
local function furnish(folder, profile, b)
	local lobby = floorBase(1)
	if profile.building == 1 then
		Visuals.Workbench(folder, lobby * CFrame.new(-b.w / 2 + 4, 0, b.d / 2 - 6) * CFrame.Angles(0, math.pi / 2, 0))
		Visuals.Sofa(folder, lobby * CFrame.new(b.w / 2 - 4, 0, b.d / 2 - 6) * CFrame.Angles(0, -math.pi / 2, 0), Color3.fromRGB(120, 90, 60))
		Visuals.Plant(folder, lobby * CFrame.new(-b.w / 2 + 2, 0, -b.d / 2 + 2), 0.9)
	else
		Visuals.CoffeeBar(folder, lobby * CFrame.new(-b.w / 2 + 5, 0, b.d / 2 - 5))
		Visuals.Sofa(folder, lobby * CFrame.new(b.w / 2 - 6, 0, b.d / 2 - 4) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(50, 55, 75))
		for level = 1, b.floors do
			local base = floorBase(level)
			for _, x in { -b.w / 2 + 2, b.w / 2 - 2 } do
				for _, z in { -b.d / 2 + 2, b.d / 2 - 2 } do
					Visuals.Plant(folder, base * CFrame.new(x, 0, z))
				end
			end
			Visuals.Whiteboard(folder, base * CFrame.new(-b.w / 2 + 0.5, 6, 0) * CFrame.Angles(0, -math.pi / 2, 0))
		end
	end
	-- màn hình Hype Wall trên vách sau của sảnh
	lot.hypeWall = Visuals.Screen(folder, lobby * CFrame.new(0, 8, -b.d / 2 + 0.8) * CFrame.Angles(0, math.pi, 0), math.min(b.w - 10, 26), 5.5)
	lot.hypeWall.Text = lot.hypeText or "🚀 COMING SOON..."
end

function CompanyService.RenderBuilding(player)
	local profile = DataService.Profiles[player]
	if not profile then
		return
	end
	if lot.buildingFolder then
		lot.buildingFolder:Destroy()
		lot.seats = nil
		lot.avatarFolder = nil
		clearAvatars()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Building"
	local b = building(profile)
	local accent = if player:GetAttribute("GoldenOffice") then GOLD else ACCENT
	for level = 1, b.floors do
		local base = floorBase(level)
		Visuals.BuildFloorShell(folder, base, b.w, b.d, H, level == 1, accent, if profile.building == 1 then "garage" else nil)
		if b.floors > 1 then
			local elevator = Visuals.Part({
				Name = "Elevator",
				Size = Vector3.new(7, 10, 1),
				CFrame = base * CFrame.new(-b.w / 2 + 6, 5, -b.d / 2 + 1.2),
				Color = Color3.fromRGB(180, 185, 195),
				Material = Enum.Material.Metal,
				Reflectance = 0.2,
			})
			Visuals.Label(elevator, string.format("🛗 Floor %d", level), UDim2.fromScale(7, 1.5), Vector3.new(0, 6, 0))
			local prompt = Instance.new("ProximityPrompt")
			prompt.ObjectText = "Elevator"
			prompt.ActionText = "Choose floor"
			prompt.HoldDuration = 0
			prompt.RequiresLineOfSight = false
			prompt.Parent = elevator
			prompt.Triggered:Connect(function(who)
				if who == player then
					notify(who, "", "Open:Company")
				end
			end)
			elevator.Parent = folder
		end
	end
	if profile.building >= 2 then
		Visuals.Entrance(folder, lot.base * CFrame.new(0, 0, b.d / 2), accent)
	end
	furnish(folder, profile, b)

	local rank = Config.CompanyRank(profile.sold)
	local sign = Visuals.BuildRoof(folder, lot.base * CFrame.new(0, b.floors * H - 0.4, 0), b.w, b.d, accent)
	sign.Text = string.format("%s %s AI\n<font size='26' color='#FFFFFF'>%s • %s</font>", b.emoji, string.upper(player.DisplayName), b.name, rank.name)
	local avatarFolder = Instance.new("Folder")
	avatarFolder.Name = "Staff"
	avatarFolder.Parent = folder
	lot.avatarFolder = avatarFolder
	folder.Parent = lot.model
	lot.buildingFolder = folder
	CompanyService.RenderSeats(player)
end

-- ================= Hành động =================

function actions.Click(player, profile, session)
	local t = os.clock()
	if t - session.lastClick < Config.Click.MinInterval then
		return
	end
	session.lastClick = t
	CompanyService.AddCash(player, Config.Click.BaseCash * CompanyService.CashMultiplier(player))
	profile.totalClicks += 1
end

function actions.UpgradeBuilding(player, profile)
	local nextLevel = profile.building + 1
	local b = Config.Buildings[nextLevel]
	if not b then
		notify(player, "You already own the biggest HQ in the valley 🌐")
		return
	end
	if profile.runEarned < b.requireEarned then
		notify(player, string.format("Reach %s revenue to unlock %s (now %s)", Config.Money(b.requireEarned), b.name, Config.Money(profile.runEarned)))
		return
	end
	if not CompanyService.Spend(player, b.price, "move into the " .. b.name) then
		return
	end
	profile.building = nextLevel
	notify(player, string.format("🎉 Welcome to your new %s %s! Room for %d people", b.emoji, b.name, Config.Capacity(nextLevel)), "Evolve")
	CompanyService.RenderBuilding(player)
	CompanyService.PushState(player)
end

function actions.BuyWorkstation(player, profile)
	if profile.workstations >= Config.Capacity(profile.building) then
		notify(player, "No room left! Upgrade your building for more desks 🏢", "Open:Company")
		return
	end
	local e = Config.Equipment
	local price = Config.WorkstationPrice + e.desk.tiers[profile.equip.desk].price + e.chair.tiers[profile.equip.chair].price + e.pc.tiers[profile.equip.pc].price
	if not CompanyService.Spend(player, price, "buy a desk") then
		return
	end
	profile.workstations += 1
	notify(player, string.format("🪑 New desk added (%d/%d)", profile.workstations, Config.Capacity(profile.building)), "Collect")
	CompanyService.RenderSeats(player)
	CompanyService.PushState(player)
end

function actions.UpgradeEquipment(player, profile, session, kind)
	local group = type(kind) == "string" and Config.Equipment[kind]
	if not group then
		return
	end
	local nextTier = group.tiers[profile.equip[kind] + 1]
	if not nextTier then
		notify(player, group.name .. " are already top tier 🔥")
		return
	end
	if nextTier.research and not profile.research.done[nextTier.research] then
		notify(player, "Research " .. Config.ResearchById[nextTier.research].name .. " first 🔬", "Open:Research")
		return
	end
	if not CompanyService.Spend(player, nextTier.price * profile.workstations, "upgrade to " .. nextTier.name) then
		return
	end
	profile.equip[kind] += 1
	notify(player, string.format("✨ Everyone now has a %s! Efficiency x%.2f", nextTier.name, Config.EquipmentMult(profile.equip)), "Evolve")
	CompanyService.RenderSeats(player)
	CompanyService.PushState(player)
end

function actions.GoFloor(player, profile, session, floor)
	if type(floor) == "number" then
		CompanyService.Teleport(player, CompanyService.FloorSpawn(player, floor))
	end
end

function actions.Home(player)
	CompanyService.Teleport(player, lot.spawn)
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

-- ================= Lô đất =================

local function buildLot()
	local origin = WorldService.LotOrigin(WorldService.HQLot)
	local model = Instance.new("Folder")
	model.Name = "HQ"
	model:SetAttribute("OwnerUserId", 0)
	Visuals.Part({
		Name = "Ground",
		Size = Vector3.new(85, 0.6, 105),
		CFrame = origin * CFrame.new(0, -0.15, 0),
		Color = Color3.fromRGB(165, 165, 170),
		Material = Enum.Material.Concrete,
		Parent = model,
	})
	-- lối đi lát gạch từ vỉa hè vào cửa
	Visuals.Part({
		Name = "Walkway",
		Size = Vector3.new(10, 0.1, 30),
		CFrame = origin * CFrame.new(0, 0.2, 37),
		Color = Color3.fromRGB(200, 195, 185),
		Material = Enum.Material.Pavement,
		Parent = model,
	})
	for _, x in { -38, 38 } do
		for _, z in { 12, 46 } do
			Visuals.Part({
				Name = "Trunk",
				Size = Vector3.new(1.2, 6, 1.2),
				CFrame = origin * CFrame.new(x, 3, z),
				Color = Color3.fromRGB(100, 70, 45),
				Material = Enum.Material.Wood,
				Parent = model,
			})
			Visuals.Part({
				Name = "Leaves",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 6.5,
				CFrame = origin * CFrame.new(x, 7.5, z),
				Color = Color3.fromRGB(70, 150, 70),
				Material = Enum.Material.Grass,
				CanCollide = false,
				Parent = model,
			})
		end
	end
	model.Parent = workspace:WaitForChild("Lots")
	return {
		model = model,
		origin = origin,
		base = origin * CFrame.new(0, 0, -22),
		spawn = origin * CFrame.new(0, 4, 40),
	}
end

-- ================= Vòng đời người chơi =================

local function teleportHome(player, character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root and sessions[player] then
		task.wait()
		character:PivotTo(lot.spawn)
	end
end

function CompanyService.OnPlayerLoaded(player, profile)
	if lot.owner then
		player:Kick("This is a single-player server. Please join another one!")
		return
	end
	lot.owner = player
	lot.model:SetAttribute("OwnerUserId", player.UserId)
	sessions[player] = { lastAction = 0, lastClick = 0 }

	-- dọn data hỏng hoặc từ bản cũ
	for kind, group in Config.Equipment do
		profile.equip[kind] = math.clamp(profile.equip[kind] or 1, 1, #group.tiers)
	end
	profile.building = math.clamp(profile.building, 1, #Config.Buildings)
	profile.workstations = math.clamp(profile.workstations, 1, Config.Capacity(profile.building))
	for id in profile.markets do
		if not Config.MarketById[id] then
			profile.markets[id] = nil -- thị trường đổi tên ở bản mới
		end
	end
	profile.markets.Home = true

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Parent = leaderstats
	leaderstats.Parent = player

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
	if not sessions[player] then
		return
	end
	sessions[player] = nil
	if lot.owner == player then
		lot.owner = nil
		lot.model:SetAttribute("OwnerUserId", 0)
		clearAvatars()
		if lot.buildingFolder then
			lot.buildingFolder:Destroy()
			lot.buildingFolder = nil
			lot.seats = nil
			lot.avatarFolder = nil
		end
	end
end

function CompanyService.Start(remoteFolder)
	remotes = remoteFolder
	local lotsFolder = Instance.new("Folder")
	lotsFolder.Name = "Lots"
	lotsFolder.Parent = workspace
	lot = buildLot()
	remotes.Action.OnServerEvent:Connect(onAction)
end

return CompanyService
