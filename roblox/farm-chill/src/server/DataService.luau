-- Lưu/tải dữ liệu người chơi bằng DataStore.
-- Dữ liệu sống trong RAM (Profiles[player]) và được ghi xuống định kỳ,
-- khi người chơi thoát, khi server tắt, và NGAY LẬP TỨC sau mỗi giao dịch Robux.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local STORE_NAME = "FarmChill_v1"
local MAX_RETRIES = 5
local MAX_PURCHASE_HISTORY = 100

local store = DataStoreService:GetDataStore(STORE_NAME)

local DataService = {}
DataService.Profiles = {} :: { [Player]: any }

local function defaultData()
	local animals = {}
	for _, animal in Config.Animals do
		animals[animal.id] = 0
	end
	return {
		coins = Config.StartingCoins,
		inventory = {}, -- [itemId] = số lượng
		plots = {}, -- ["1".."12"] = { crop = id, progress = giây đã lớn }
		unlockedPlots = Config.Plots.FreePlots,
		animals = animals,
		boosts = {}, -- [tên boost] = os.time() lúc hết hạn
		purchases = {}, -- danh sách PurchaseId đã xử lý (chống cộng 2 lần)
		lastSave = os.time(),
		totalEarned = 0,
	}
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

local function withRetry(fn)
	local lastErr
	for attempt = 1, MAX_RETRIES do
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
	local ok, data = withRetry(function()
		return store:GetAsync(keyFor(player))
	end)
	if not ok then
		-- Không tải được thì KHÔNG cho chơi, tránh ghi đè data thật bằng data trống
		player:Kick("Không tải được dữ liệu, vào lại sau ít phút nha 🙏")
		return nil
	end
	if not player.Parent then
		return nil
	end

	local profile = reconcile(data or {}, defaultData())
	DataService.Profiles[player] = profile
	return profile
end

function DataService.Save(player: Player): boolean
	local profile = DataService.Profiles[player]
	if not profile then
		return false
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
