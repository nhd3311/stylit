-- Lưu/tải dữ liệu người chơi bằng DataStore.
-- Dữ liệu sống trong RAM (Profiles[player]) và được ghi xuống định kỳ,
-- khi người chơi thoát, khi server tắt, và NGAY LẬP TỨC sau mỗi giao dịch Robux.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local STORE_NAME = "AITycoon_v1"
local MAX_RETRIES = 5
local MAX_PURCHASE_HISTORY = 100
local SCHEMA_VERSION = 4

-- Game chưa publish thì GetDataStore báo lỗi ngay. Bắt lỗi để vẫn chơi thử được
-- ở "chế độ thử": data mới tinh, không tải, không lưu.
local storeOk, store = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
if not storeOk then
	warn("[DataService] Chưa dùng được DataStore (game chưa publish?). Chế độ thử: KHÔNG lưu data.", store)
	store = nil
end

local DataService = {}
DataService.Profiles = {} :: { [Player]: any }
DataService.Offline = store == nil -- true = chế độ thử, không đụng tới DataStore

local function defaultData()
	return {
		schemaVersion = SCHEMA_VERSION,
		cash = Config.StartingCash,
		day = 0, -- số ngày game đã trôi qua từ 01/01/StartYear
		speed = 2, -- vị trí trong Config.Calendar.Speeds (2 = x1)
		building = 1, -- cấp tòa nhà (Config.Buildings)
		workstations = 1, -- số chỗ làm việc đã mua (chỗ 1 của Founder)
		equip = { desk = 1, chair = 1, pc = 1 },
		staff = {}, -- { id, name, role, skill, salary }
		nextStaffId = 1,
		candidates = {}, -- danh sách ứng viên, đổi mỗi tháng
		research = { done = {}, current = nil }, -- current = { id, progress }
		factory = { built = false, lines = {}, compute = 0 }, -- lines = { tier, ... }
		dev = nil, -- model đang làm: { type, size, features, name, progress, computeRatio }
		pending = nil, -- model làm xong chờ ra mắt (giống dev)
		models = {}, -- lịch sử model đã ra mắt
		brandCount = {}, -- [type] = số phiên bản đã ra (đặt tên ChatViet 1, 2...)
		markets = { VN = true },
		viral = 0, -- số lần ra mắt được x2 độ hot (mua gói Viral)
		stocks = {}, -- [mã] = { qty, cost }
		boosts = {}, -- [tên boost] = os.time() lúc hết hạn
		purchases = {},
		lastSave = os.time(),
		totalEarned = 0, -- tổng doanh thu từ trước tới nay (bảng xếp hạng)
		runEarned = 0, -- doanh thu từ lần bán công ty gần nhất (mốc tòa nhà, Điểm Founder)
		totalClicks = 0,
		founderPoints = 0,
		sold = 0,
		daily = { lastClaimDay = 0, streak = 0 },
		starterClaimed = false,
	}
end

-- Nâng data đời cũ lên schema hiện tại. Chạy TRƯỚC reconcile.
local function migrate(data)
	local version = data.schemaVersion or 1
	if version < 4 then
		-- v4 là game quản lý công ty kiểu mới: làm lại lượt chơi từ đầu,
		-- giữ thành tích, quà, đồ đã mua, Điểm Founder (v2 gọi là cổ phiếu IPO)
		return {
			schemaVersion = SCHEMA_VERSION,
			founderPoints = data.founderPoints or data.shares or 0,
			sold = data.sold or data.ipoCount or 0,
			daily = data.daily,
			starterClaimed = data.starterClaimed,
			purchases = data.purchases,
			boosts = data.boosts,
			totalEarned = data.totalEarned or 0,
		}
	end
	return data
end

-- Bù các field mới thêm vào sau này cho data cũ
local function reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) == "table" then
			reconcile(data[key], value)
		end
	end
	return data
end

local function withRetry(fn, attempts)
	local lastErr
	for attempt = 1, attempts or MAX_RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		task.wait(attempt) -- chờ lâu dần: 1s, 2s, 3s...
	end
	return false, lastErr
end

local function keyFor(player: Player)
	return "player_" .. player.UserId
end

function DataService.Load(player: Player)
	if DataService.Offline then
		local profile = defaultData()
		DataService.Profiles[player] = profile
		return profile
	end

	-- Trong Studio thử 1 lần thôi cho nhanh (thường lỗi do chưa bật API Services)
	local ok, data = withRetry(function()
		return store:GetAsync(keyFor(player))
	end, if RunService:IsStudio() then 1 else MAX_RETRIES)
	if not ok then
		if RunService:IsStudio() then
			warn("[DataService] Không tải được data (bật Game Settings > Security > Enable Studio Access to API Services). Chế độ thử: KHÔNG lưu data.", data)
			DataService.Offline = true
			return DataService.Load(player)
		end
		-- Trên server thật: không tải được thì KHÔNG cho chơi, tránh ghi đè data thật bằng data trống
		player:Kick("Không tải được dữ liệu, vào lại sau ít phút nha 🙏")
		return nil
	end
	if not player.Parent then
		return nil
	end

	local profile = if data then reconcile(migrate(data), defaultData()) else defaultData()
	DataService.Profiles[player] = profile
	return profile
end

function DataService.Save(player: Player): boolean
	local profile = DataService.Profiles[player]
	if not profile then
		return false
	end
	if DataService.Offline then
		return true -- chế độ thử: coi như đã lưu
	end
	profile.lastSave = os.time()
	local ok, err = withRetry(function()
		return store:UpdateAsync(keyFor(player), function()
			return profile
		end)
	end)
	if not ok then
		warn("[DataService] Lưu thất bại cho", player.Name, err)
	end
	return ok
end

function DataService.Release(player: Player)
	DataService.Save(player)
	DataService.Profiles[player] = nil
end

function DataService.HasProcessedPurchase(profile, purchaseId: string): boolean
	return table.find(profile.purchases, purchaseId) ~= nil
end

function DataService.MarkPurchase(profile, purchaseId: string)
	table.insert(profile.purchases, purchaseId)
	while #profile.purchases > MAX_PURCHASE_HISTORY do
		table.remove(profile.purchases, 1)
	end
end

function DataService.Start()
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player in DataService.Profiles do
				task.spawn(DataService.Save, player)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in DataService.Profiles do
			pending += 1
			task.spawn(function()
				DataService.Save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
end

return DataService
