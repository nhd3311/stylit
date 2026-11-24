-- Công ty của người chơi: tòa nhà (Garage → Campus), chỗ làm việc + bàn ghế máy tính,
-- nhân viên ngồi ở bàn, đi lại giữa các tầng, gõ code dạo, tiền và các hệ số.
-- Server là "trọng tài": client chỉ gửi yêu cầu, server tự kiểm tra tiền/quyền rồi mới làm.
--
-- Các service khác cắm vào đây qua:
--   RegisterAction(name, fn)     thêm hành động client được gọi
--   RegisterStateProvider(fn)    thêm field vào State gửi client

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Visuals = require(script.Parent.Visuals)
local WorldService = require(script.Parent.WorldService)

local H = Config.FloorHeight
local ACCENT = Color3.fromRGB(0, 200, 255)

local CompanyService = {}

local remotes
local lot -- lô đất trụ sở (server 1 người nên chỉ có 1)
local sessions = {} -- [player] = { lastAction, lastClick }
local actions = {}
local stateProviders = {}

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

-- Mọi khoản doanh thu $
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

-- Năng suất mỗi nhân viên: bàn ghế máy tính x boost x Điểm Founder
function CompanyService.WorkMultiplier(player)
	local profile = DataService.Profiles[player]
	if not profile then
		return 1
	end
	local mult = Config.EquipmentMult(profile.equip) * Config.FounderMultiplier(profile.founderPoints)
	if CompanyService.BoostOn(profile, "Work") then
		mult *= Config.Multipliers.WorkBoost
	end
	return mult
end

-- ================= Tiền =================

-- Doanh thu (tính vào mốc nâng cấp tòa nhà, bảng xếp hạng, Điểm Founder)
function CompanyService.AddCash(player, amount)
	local profile = DataService.Profiles[player]
	if not profile or amount <= 0 then
		return
	end
	profile.cash += amount
	profile.totalEarned += amount
	profile.runEarned += amount
end

-- Trừ tiền nếu đủ. Trả về true nếu trả được.
function CompanyService.Spend(player, amount, what)
	local profile = DataService.Profiles[player]
	if not profile then
		return false
	end
	if profile.cash < amount then
		notify(player, string.format("Cần %s để %s 💸", Config.Money(amount), what))
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
		stats["$"].Value = math.floor(profile.cash)
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

-- Toạ độ (ở sàn) của chỗ làm việc số `index` (1..sức chứa)
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
	-- đứng gần mặt tiền của tầng, nhìn vào trong
	return floorBase(floor) * CFrame.new(0, 3, b.d / 2 - 5)
end

function CompanyService.Teleport(player, cframe)
	local character = player.Character
	if character and cframe then
		character:PivotTo(cframe)
	end
end

-- Dựng lại chỗ ngồi: bàn ghế máy tính + nhân viên (gọi khi thuê/sa thải/mua bàn/nâng cấp)
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
	local tiers = {
		desk = e.desk.tiers[profile.equip.desk],
		chair = e.chair.tiers[profile.equip.chair],
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
				"👑 Bàn của bạn",
				UDim2.fromScale(6, 1.2),
				Vector3.zero
			)
		else
			local staff = profile.staff[index - 1]
			if staff then
				local role = Config.Roles[staff.role]
				Visuals.BuildPerson(folder, cf, role.color, string.format("%s %s • %d", role.emoji, staff.name, staff.skill))
			end
		end
	end
	folder.Parent = lot.buildingFolder
	lot.seats = folder
end

-- Dựng lại toàn bộ tòa nhà theo cấp hiện tại
function CompanyService.RenderBuilding(player)
	local profile = DataService.Profiles[player]
	if not profile then
		return
	end
	if lot.buildingFolder then
		lot.buildingFolder:Destroy()
		lot.seats = nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "Building"
	local b = building(profile)
	for level = 1, b.floors do
		local base = floorBase(level)
		Visuals.BuildFloorShell(folder, base, b.w, b.d, H, level == 1, ACCENT)
		if b.floors > 1 then
			-- thang máy ở giữa vách sau
			local elevator = Visuals.Part({
				Name = "Elevator",
				Size = Vector3.new(7, 10, 1),
				CFrame = base * CFrame.new(0, 5, -b.d / 2 + 1.2),
				Color = Color3.fromRGB(180, 185, 195),
				Material = Enum.Material.Metal,
				Reflectance = 0.2,
			})
			Visuals.Label(elevator, string.format("🛗 Tầng %d", level), UDim2.fromScale(7, 1.5), Vector3.new(0, 6, 0))
			local prompt = Instance.new("ProximityPrompt")
			prompt.ObjectText = "Thang máy"
			prompt.ActionText = "Chọn tầng"
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
	local rank = Config.CompanyRank(profile.sold)
	local sign = Visuals.BuildRoof(folder, lot.base * CFrame.new(0, b.floors * H - 0.4, 0), b.w, b.d, ACCENT)
	sign.Text = string.format("%s %s\n<font size='26' color='#FFFFFF'>%s • %s</font>", b.emoji, string.upper(player.DisplayName) .. " AI", b.name, rank.name)
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
		notify(player, "Trụ sở đã to nhất rồi, quá trùm 🌆")
		return
	end
	if profile.runEarned < b.requireEarned then
		notify(player, string.format("Doanh thu phải đạt %s mới được lên %s (hiện %s)", Config.Money(b.requireEarned), b.name, Config.Money(profile.runEarned)))
		return
	end
	if not CompanyService.Spend(player, b.price, "nâng cấp lên " .. b.name) then
		return
	end
	profile.building = nextLevel
	notify(player, string.format("🎉 Chuyển trụ sở lên %s %s! Sức chứa %d người", b.emoji, b.name, Config.Capacity(nextLevel)), "Evolve")
	CompanyService.RenderBuilding(player)
	CompanyService.PushState(player)
end

function actions.BuyWorkstation(player, profile)
	if profile.workstations >= Config.Capacity(profile.building) then
		notify(player, "Hết chỗ rồi! Nâng cấp tòa nhà để kê thêm bàn 🏢", "Open:Company")
		return
	end
	local e = Config.Equipment
	-- chỗ mới được trang bị luôn theo chuẩn hiện tại của công ty
	local price = Config.WorkstationPrice + e.desk.tiers[profile.equip.desk].price + e.chair.tiers[profile.equip.chair].price + e.pc.tiers[profile.equip.pc].price
	if not CompanyService.Spend(player, price, "mua chỗ làm việc") then
		return
	end
	profile.workstations += 1
	notify(player, string.format("🪑 Đã kê thêm 1 chỗ làm việc (%d/%d)", profile.workstations, Config.Capacity(profile.building)), "Collect")
	CompanyService.RenderSeats(player)
	CompanyService.PushState(player)
end

function actions.UpgradeEquipment(player, profile, session, kind)
	local group = type(kind) == "string" and Config.Equipment[kind]
	if not group then
		return
	end
	local nextTier = profile.equip[kind] + 1
	local tier = group.tiers[nextTier]
	if not tier then
		notify(player, group.name .. " đã xịn nhất rồi 🔥")
		return
	end
	if tier.research and not profile.research.done[tier.research] then
		notify(player, "Cần nghiên cứu " .. Config.ResearchById[tier.research].name .. " trước 🔬", "Open:Research")
		return
	end
	local price = tier.price * profile.workstations
	if not CompanyService.Spend(player, price, "nâng cấp " .. tier.name .. " cho cả công ty") then
		return
	end
	profile.equip[kind] = nextTier
	notify(player, string.format("✨ Cả công ty đã dùng %s! Hiệu suất x%.2f", tier.name, Config.EquipmentMult(profile.equip)), "Evolve")
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
	}).Parent = model
	for _, x in { -38, 38 } do
		for _, z in { 12, 46 } do
			Visuals.Part({
				Name = "Trunk",
				Size = Vector3.new(1.2, 6, 1.2),
				CFrame = origin * CFrame.new(x, 3, z),
				Color = Color3.fromRGB(100, 70, 45),
				Material = Enum.Material.Wood,
			}).Parent = model
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
	model.Parent = workspace:WaitForChild("Lots")
	return {
		model = model,
		origin = origin,
		base = origin * CFrame.new(0, 0, -22), -- tâm chân tòa nhà, cửa quay về +Z
		spawn = origin * CFrame.new(0, 4, 40),
	}
end

-- ================= Vòng đời người chơi =================

local function teleportHome(player, character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root and sessions[player] then
		task.wait() -- đợi SpawnLocation đặt nhân vật xong rồi mới dịch chuyển
		character:PivotTo(lot.spawn)
	end
end

function CompanyService.OnPlayerLoaded(player, profile)
	if lot.owner then
		player:Kick("Server này chỉ dành cho 1 người chơi, vào server khác nha!")
		return
	end
	lot.owner = player
	lot.model:SetAttribute("OwnerUserId", player.UserId)
	sessions[player] = { lastAction = 0, lastClick = 0 }

	-- dọn data hỏng: tier vượt giới hạn, chỗ ngồi vượt sức chứa
	for kind, group in Config.Equipment do
		profile.equip[kind] = math.clamp(profile.equip[kind] or 1, 1, #group.tiers)
	end
	profile.building = math.clamp(profile.building, 1, #Config.Buildings)
	profile.workstations = math.clamp(profile.workstations, 1, Config.Capacity(profile.building))

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("NumberValue")
	cash.Name = "$"
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
		if lot.buildingFolder then
			lot.buildingFolder:Destroy()
			lot.buildingFolder = nil
			lot.seats = nil
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
