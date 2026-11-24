-- Model AI: thiết kế (loại + kích thước + tính năng) → phát triển theo ngày (điểm lập trình)
-- → ra mắt (chọn giá + chiến dịch marketing) → 4 tờ báo chấm điểm → người dùng và doanh thu mỗi ngày.
-- Kèm mở rộng thị trường (nhân lượng người dùng).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CalendarService = require(script.Parent.CalendarService)
local CompanyService = require(script.Parent.CompanyService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local FactoryService = require(script.Parent.FactoryService)
local StaffService = require(script.Parent.StaffService)

local ModelService = {}

local notify = CompanyService.Notify
local random = Random.new()
local revenueToday = {} -- [player] = doanh thu ngày gần nhất

local COMMENTS = {
	{ 9, "Siêu phẩm! Cả ngành phải dè chừng 🔥" },
	{ 8, "Rất ấn tượng, đáng dùng thử ngay" },
	{ 7, "Tốt, có vài điểm sáng" },
	{ 5.5, "Tạm ổn, chưa có gì đột phá" },
	{ 4, "Hơi thất vọng, còn nhiều lỗi" },
	{ 0, "Thảm hoạ... về làm lại đi 😬" },
}

local function contains(list, value)
	return table.find(list, value) ~= nil
end

local function typeUnlocked(profile, modelType)
	return profile.research.done[modelType.requires] == true
end

-- ================= Thiết kế & phát triển =================

local function startModel(player, profile, typeId, sizeId, features)
	local modelType = type(typeId) == "string" and Config.ModelTypeById[typeId]
	local size = type(sizeId) == "string" and Config.ModelSizeById[sizeId]
	if not modelType or not size or type(features) ~= "table" then
		return
	end
	if profile.dev or profile.pending then
		notify(player, "Đội lập trình đang bận với model khác ⏳")
		return
	end
	if not typeUnlocked(profile, modelType) then
		notify(player, "Cần nghiên cứu " .. Config.ResearchById[modelType.requires].name .. " trước 🔬", "Open:Research")
		return
	end
	-- lọc tính năng: phải là tính năng model đã nghiên cứu, không trùng, không quá số slot
	local chosen = {}
	for _, id in features do
		local node = type(id) == "string" and Config.ResearchById[id]
		if node and node.category == "Feature" and profile.research.done[id] and not contains(chosen, id) and #chosen < size.slots then
			table.insert(chosen, id)
		end
	end
	if #chosen == 0 then
		notify(player, "Chọn ít nhất 1 tính năng cho model nha 🧩")
		return
	end

	local taken = FactoryService.Take(profile, size.compute)
	local count = (profile.brandCount[modelType.id] or 0) + 1
	profile.brandCount[modelType.id] = count
	profile.dev = {
		type = modelType.id,
		size = size.id,
		features = chosen,
		name = modelType.brand .. " " .. count,
		progress = 0,
		computeRatio = if size.compute > 0 then taken / size.compute else 1,
	}
	local warn = if size.compute > 0 and taken < size.compute then string.format(" (thiếu ⚡ compute: chỉ có %d%%, model sẽ kém hơn)", math.floor(taken / size.compute * 100)) else ""
	notify(player, string.format("💻 Bắt đầu phát triển %s %s%s", modelType.emoji, profile.dev.name, warn))
	CompanyService.PushState(player)
end

local function finishDev(player, profile)
	profile.pending = profile.dev
	profile.dev = nil
	notify(player, string.format("✅ %s đã hoàn thành! Chọn giá bán và chiến dịch marketing để ra mắt 🚀", profile.pending.name), "Open:Model")
end

function ModelService.FinishNow(player)
	local profile = DataService.Profiles[player]
	if not profile or not profile.dev then
		return false
	end
	finishDev(player, profile)
	CompanyService.PushState(player)
	return true
end

-- ================= Chấm điểm =================

local function quality(profile, model)
	local modelType = Config.ModelTypeById[model.type]
	local size = Config.ModelSizeById[model.size]
	local year = Config.YearOf(profile.day)
	local q = 2.5

	-- tính năng hợp với loại model thì cộng, lạc đề thì trừ
	local fit, fresh = 0, 0
	for _, id in model.features do
		fit += if contains(modelType.good, id) then 1 else -0.4
		-- công nghệ mới ra (trong 1 năm gần đây) được báo chí khen
		if Config.ResearchById[id].year >= year - 1 then
			fresh += 0.4
		end
	end
	q += math.clamp(fit, -2, 3.5) + math.min(fresh, 1.2)
	q += StaffService.DevSkillAverage(profile) / 25
	q += model.computeRatio * 1.2
	q += size.quality

	-- ra cùng loại quá dày thì người dùng chán
	for _, old in profile.models do
		if old.type == model.type and profile.day - old.launchDay < Config.Sales.RepeatPenaltyDays then
			q -= 0.8
			break
		end
	end
	q += random:NextNumber(-0.7, 0.7)
	return math.clamp(q, 1, 10)
end

local function commentFor(score)
	for _, entry in COMMENTS do
		if score >= entry[1] then
			return entry[2]
		end
	end
	return COMMENTS[#COMMENTS][2]
end

-- ================= Ra mắt =================

local function launch(player, profile, priceId, campaignId)
	local model = profile.pending
	local price = type(priceId) == "string" and Config.PriceTierById[priceId]
	local campaign = type(campaignId) == "string" and Config.CampaignById[campaignId]
	if not model or not price or not campaign then
		return
	end
	if campaign.research and not profile.research.done[campaign.research] then
		notify(player, "Chưa nghiên cứu kênh " .. campaign.name .. " 🔬")
		return
	end
	if campaign.price > 0 and not CompanyService.Spend(player, campaign.price, "chạy chiến dịch " .. campaign.name) then
		return
	end

	local q = quality(profile, model)
	local scores, sum = {}, 0
	for _, reviewer in Config.Reviewers do
		local s = math.clamp(math.floor(q + random:NextNumber(-1, 1) + 0.5), 1, 10)
		table.insert(scores, { name = reviewer, score = s })
		sum += s
	end
	local score = math.floor(sum / #scores * 10 + 0.5) / 10

	local hype = campaign.hype * (1 + StaffService.SkillSum(profile, "Marketing") * Config.Sales.MarketingBonus)
	if profile.viral > 0 then
		profile.viral -= 1
		hype *= 2
	end
	local modelType = Config.ModelTypeById[model.type]
	local size = Config.ModelSizeById[model.size]
	local priceFit = price.users
	if price.id == "Premium" and score < 7 then
		priceFit *= 0.6 -- model dở mà bán đắt thì ít người mua
	end
	local peak = modelType.users * size.users * (score / 10) ^ 2 * hype * priceFit * Config.MarketMultiplier(profile.markets)

	table.insert(profile.models, 1, {
		name = model.name,
		type = model.type,
		score = score,
		launchDay = profile.day,
		peak = peak,
		price = price.id,
		users = 0,
		revenue = 0,
		active = true,
	})
	-- giữ lịch sử gọn: bỏ bớt model cũ đã ngừng bán
	while #profile.models > Config.Sales.HistorySize do
		local removed = false
		for i = #profile.models, 1, -1 do
			if not profile.models[i].active then
				table.remove(profile.models, i)
				removed = true
				break
			end
		end
		if not removed then
			break
		end
	end
	profile.pending = nil

	CompanyService.Popup(player, {
		name = model.name,
		emoji = modelType.emoji,
		typeName = modelType.name,
		scores = scores,
		score = score,
		comment = commentFor(score),
		peak = peak,
		hype = hype,
		campaign = campaign.name,
		price = price.name,
	})
	CompanyService.PushState(player)
end

-- ================= Doanh số mỗi ngày =================

local function dailySales(player, profile, day)
	local total = 0
	local marketing = 1 + StaffService.SkillSum(profile, "Marketing") * Config.Sales.MarketingBonus
	local cashMult = CompanyService.CashMultiplier(player)
	for _, model in profile.models do
		if model.active then
			local age = day - model.launchDay
			local users = Config.UsersAt(model.peak, age) * marketing
			local perUser = Config.PriceTierById[model.price].perUser
			local revenue = users * perUser * cashMult
			model.users = users
			model.revenue += revenue
			total += revenue
			if age > Config.Sales.MaxDays or (age > Config.Sales.RampDays and users < 1) then
				model.active = false
				model.users = 0
				notify(player, string.format("📦 %s đã ngừng bán sau %d ngày, tổng doanh thu %s", model.name, age, Config.Money(model.revenue)))
			end
		end
	end
	CompanyService.AddCash(player, total)
	revenueToday[player] = total
end

function ModelService.RevenuePerDay(player)
	return revenueToday[player] or 0
end

function ModelService.Start()
	CompanyService.RegisterAction("StartModel", function(player, profile, session, typeId, sizeId, features)
		startModel(player, profile, typeId, sizeId, features)
	end)
	CompanyService.RegisterAction("Launch", function(player, profile, session, priceId, campaignId)
		launch(player, profile, priceId, campaignId)
	end)
	CompanyService.RegisterAction("ExpandMarket", function(player, profile, session, marketId)
		local market = type(marketId) == "string" and Config.MarketById[marketId]
		if not market or profile.markets[market.id] then
			return
		end
		if profile.building < market.requireBuilding then
			notify(player, "Cần lên " .. Config.Buildings[market.requireBuilding].name .. " mới đủ tầm mở thị trường này 🏢")
			return
		end
		if not CompanyService.Spend(player, market.price, "mở thị trường " .. market.name) then
			return
		end
		profile.markets[market.id] = true
		notify(player, string.format("%s Đã mở rộng sang %s! Model ra mắt sau này có thêm nhiều người dùng", market.emoji, market.name), "Evolve")
		CompanyService.PushState(player)
	end)

	CalendarService.RegisterDayHook(function(player, profile, day)
		if profile.dev then
			profile.dev.progress += StaffService.Points(player, profile, "Dev")
			if profile.dev.progress >= Config.ModelSizeById[profile.dev.size].devPoints then
				finishDev(player, profile)
			end
		end
		dailySales(player, profile, day)
	end)

	CompanyService.RegisterStateProvider(function(player, profile, state)
		local dev = profile.dev
		local devPoints = StaffService.Points(player, profile, "Dev")
		local need = dev and Config.ModelSizeById[dev.size].devPoints
		state.model = {
			dev = dev,
			progress = if dev then math.clamp(dev.progress / need, 0, 1) else 0,
			eta = if dev and devPoints > 0 then math.ceil((need - dev.progress) / devPoints) else 0,
			pending = profile.pending,
			history = profile.models,
			viral = profile.viral,
			devPerDay = devPoints,
		}
		state.markets = profile.markets
		state.marketMult = Config.MarketMultiplier(profile.markets)
		state.revenuePerDay = ModelService.RevenuePerDay(player)
	end)
end

return ModelService
