-- Habitat: đảo nuôi bot + trưng bày bộ sưu tập.
--   • Mỗi người chơi vào server được chia 1 ô vườn (attribute "Plot" = số thứ tự ô).
--   • Bot đặt vào vườn (entry.home = true) không ra trận; chúng đi dạo trong ô (client vẽ)
--     và làm ra Credits cả khi offline, tính theo giờ thật (os.time).
--   • Độ vui giảm dần theo thời gian; cho ăn thì vui lại 100%. Vui càng cao làm càng nhiều.
--   • Kho chứa có giới hạn (CapHours giờ sản lượng), ghé bấm Collect để nhận.
--   • Bệ trưng bày: 3 bot hiếm nhất (attribute "Showcase"), biển tên ghi số bot đã sưu tầm.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)

local HabitatService = {}

local H = Config.Habitat
local plotOwners = {} -- [plotIndex] = player

-- ================= Tính toán =================

local function slots(player)
	return H.Slots + (if player:GetAttribute("BigHabitat") then H.ExtraSlotsPass else 0)
end

local function homeBots(profile)
	local list = {}
	for i, entry in profile.bots do
		if entry.home and Config.BotById[entry.type] then
			table.insert(list, i)
		end
	end
	return list
end

-- hệ số data của vùng xịn nhất đã mở: vườn làm ra nhiều hơn khi người chơi tiến xa
local function bestZoneMult(profile)
	local mult = 1
	for _, zone in Config.Zones do
		if profile.level >= zone.level then
			mult = math.max(mult, zone.dataMult)
		end
	end
	return mult
end

-- credits/giây khi vui 100%
local function rate(player, profile)
	local gather = 0
	for _, i in homeBots(profile) do
		local entry = profile.bots[i]
		gather += Config.BotStat(Config.BotById[entry.type], entry.level, "gather", entry.variant)
	end
	return gather * bestZoneMult(profile) * H.RateFactor
end

local function happiness(profile)
	local hungry = (os.time() - profile.habitat.fedAt) / (H.HungerHours * 3600)
	return math.clamp(100 * (1 - hungry), 0, 100)
end

local function efficiency(profile)
	return H.MinEfficiency + (1 - H.MinEfficiency) * happiness(profile) / 100
end

local function capacity(player, profile)
	return rate(player, profile) * H.CapHours * 3600 * (if player:GetAttribute("BigHabitat") then 2 else 1)
end

-- cộng dồn credits từ lần tính trước tới giờ (gọi trước khi đọc/sửa kho)
local function settle(player, profile)
	local habitat = profile.habitat
	local now = os.time()
	local dt = math.max(0, now - habitat.last)
	habitat.last = now
	if dt > 0 then
		-- không bao giờ làm giảm kho đang có (vd. vừa rút bớt bot làm sức chứa nhỏ lại)
		local filled = math.min(capacity(player, profile), habitat.stored + rate(player, profile) * efficiency(profile) * dt)
		habitat.stored = math.max(habitat.stored, filled)
	end
end

local function feedCost(player, profile)
	return math.max(10, math.ceil(rate(player, profile) * 60))
end

-- ================= Hiển thị =================

-- bot trong vườn + 3 bot hiếm nhất lên bệ + số bot đã sưu tầm, cho mọi client vẽ
local function publish(player, profile)
	local parts = {}
	for _, i in homeBots(profile) do
		local entry = profile.bots[i]
		table.insert(parts, entry.type .. ":" .. entry.level .. ":" .. (entry.variant or ""))
	end
	player:SetAttribute("Habitat", table.concat(parts, ","))

	local ranked = {}
	for _, entry in profile.bots do
		local bot = Config.BotById[entry.type]
		if bot then
			local score = Config.RarityOrder[bot.rarity] * 10 + (Config.VariantOrder[entry.variant or ""] or 0) * 3 + entry.level * 0.1
			table.insert(ranked, { entry = entry, score = score })
		end
	end
	table.sort(ranked, function(a, b)
		return a.score > b.score
	end)
	local show = {}
	for k = 1, math.min(3, #ranked) do
		local entry = ranked[k].entry
		table.insert(show, entry.type .. ":" .. entry.level .. ":" .. (entry.variant or ""))
	end
	player:SetAttribute("Showcase", table.concat(show, ","))

	local discovered = 0
	for _ in profile.discovered do
		discovered += 1
	end
	player:SetAttribute("Collection", discovered)
end

-- ================= Hành động =================

local function place(player, profile, session, index)
	local entry = type(index) == "number" and profile.bots[index]
	if not entry or not Config.BotById[entry.type] then
		return
	end
	settle(player, profile)
	if entry.home then
		entry.home = nil
		PlayerService.Notify(player, "↩ Bot returned to your squad")
	else
		if #homeBots(profile) >= slots(player) then
			PlayerService.Notify(player, string.format("🏠 Your Habitat is full (%d slots)", slots(player)))
			return
		end
		-- phải còn ít nhất 1 bot đi đánh
		local fighters = 0
		for _, other in profile.bots do
			if not other.home then
				fighters += 1
			end
		end
		if fighters <= 1 then
			PlayerService.Notify(player, "Keep at least one bot in your squad!")
			return
		end
		entry.home = true
		PlayerService.Notify(player, "🏠 " .. Config.BotLabel(Config.BotById[entry.type], entry.variant) .. " moved into your Habitat", "Reward")
	end
	PlayerService.Refresh(player)
end

local function collect(player, profile)
	settle(player, profile)
	local amount = math.floor(profile.habitat.stored)
	if amount < 1 then
		PlayerService.Notify(player, "🏠 Nothing to collect yet. Put bots in your Habitat!")
		return
	end
	profile.habitat.stored -= amount
	PlayerService.AddCredits(player, amount)
	PlayerService.Notify(player, string.format("🏠 Collected %s credits from your Habitat!", Config.Short(amount)), "Reward")
	PlayerService.PushState(player)
end

local function feed(player, profile)
	settle(player, profile)
	if #homeBots(profile) == 0 then
		PlayerService.Notify(player, "🏠 No bots in your Habitat to feed")
		return
	end
	local cost = feedCost(player, profile)
	if profile.credits < cost then
		PlayerService.Notify(player, string.format("You need %s credits to feed your bots", Config.Short(cost)))
		return
	end
	profile.credits -= cost
	profile.habitat.fedAt = os.time()
	PlayerService.Notify(player, "🍖 Your bots are happy! Habitat at 100% efficiency", "Reward")
	PlayerService.PushState(player)
end

-- ================= Ô vườn =================

local function assignPlot(player)
	for i in H.Plots do
		if not plotOwners[i] then
			plotOwners[i] = player
			player:SetAttribute("Plot", i)
			return
		end
	end
	PlayerService.Notify(player, "🏠 All Habitat plots are taken on this server")
end

function HabitatService.Start()
	PlayerService.AddAction("PlaceHome", place)
	PlayerService.AddAction("CollectHabitat", collect)
	PlayerService.AddAction("FeedHabitat", feed)
	table.insert(PlayerService.BotsChanged, publish)
	PlayerService.StateExtras.habitat = function(player, profile)
		settle(player, profile)
		local cap = capacity(player, profile)
		return {
			rate = rate(player, profile),
			efficiency = efficiency(profile),
			happiness = happiness(profile),
			stored = profile.habitat.stored,
			cap = cap,
			feedCost = feedCost(player, profile),
			slots = slots(player),
			count = #homeBots(profile),
			plot = player:GetAttribute("Plot"),
		}
	end
	Players.PlayerAdded:Connect(assignPlot)
	for _, player in Players:GetPlayers() do
		assignPlot(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		for i, owner in plotOwners do
			if owner == player then
				plotOwners[i] = nil
			end
		end
	end)
	-- dữ liệu tải xong trước khi service này chạy thì vẽ luôn
	for player, profile in DataService.Profiles do
		publish(player, profile)
	end
end

return HabitatService
