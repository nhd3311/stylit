-- Model AI: thiết kế (loại + kích thước + tính năng) → phát triển theo ngày (điểm Engineer)
-- → ra mắt (giá + chiến dịch marketing) → 4 tờ báo chấm điểm → Hype Feed → người dùng & doanh thu.
-- Kèm AI Arena (đấu với model của 6 công ty đối thủ, đối thủ tự ra model mới theo thời gian)
-- và mở rộng thị trường.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CalendarService = require(script.Parent.CalendarService)
local CompanyService = require(script.Parent.CompanyService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local FactoryService = require(script.Parent.FactoryService)
local StaffService = require(script.Parent.StaffService)
local StockService = require(script.Parent.StockService)

local ModelService = {}

local A = Config.Arena
local notify = CompanyService.Notify
local random = Random.new()
local revenueToday = {} -- [player] = doanh thu ngày gần nhất
local lastRank = {} -- [player] = hạng Arena lần trước (để báo khi đổi hạng)

local function contains(list, value)
	return table.find(list, value) ~= nil
end

local function goodCount(model)
	local modelType = Config.ModelTypeById[model.type]
	local n = 0
	for _, id in model.features do
		if contains(modelType.good, id) then
			n += 1
		end
	end
	return n
end

-- ================= AI Arena =================

local function ensureRivals(profile)
	for _, rival in Config.Stocks do
		if not profile.rivals[rival.id] then
			profile.rivals[rival.id] = {
				version = 1,
				arena = Config.RivalArena(rival, profile.day, random:NextInteger(-30, 30)),
				nextDay = profile.day + random:NextInteger(A.ReleaseDays[1], A.ReleaseDays[2]),
			}
		end
	end
end

local function playerArena(profile)
	local best = 0
	for _, model in profile.models do
		best = math.max(best, model.arena or 0)
	end
	return best
end

-- Bảng xếp hạng: { { name, company, arena, mine } ... } giảm dần, và hạng của người chơi
function ModelService.Ranking(player, profile)
	ensureRivals(profile)
	local list = {}
	for _, rival in Config.Stocks do
		local r = profile.rivals[rival.id]
		table.insert(list, { name = rival.brand .. " " .. r.version, company = rival.name, emoji = rival.emoji, arena = r.arena })
	end
	local mine = playerArena(profile)
	local best = profile.models[1]
	for _, model in profile.models do
		if (model.arena or 0) == mine then
			best = model
			break
		end
	end
	table.insert(list, {
		name = if best then best.name else "—",
		company = player.DisplayName .. " AI",
		emoji = "⭐",
		arena = mine,
		mine = true,
	})
	table.sort(list, function(a, b)
		return a.arena > b.arena
	end)
	local rank = #list
	for i, entry in list do
		if entry.mine then
			rank = i
		end
	end
	return list, rank
end

local function arenaBonus(rank)
	if rank == 1 then
		return 1 + A.ChampionBonus
	elseif rank <= 3 then
		return 1 + A.PodiumBonus
	end
	return 1
end

-- ================= Hype Wall + Hype Feed =================

local function makeFeed(name, score)
	local pool = if score >= 7 then Config.FeedPosts.good elseif score >= 4.5 then Config.FeedPosts.mid else Config.FeedPosts.bad
	local posts = {}
	for _ = 1, 5 do
		local handle = Config.FeedHandles[random:NextInteger(1, #Config.FeedHandles)]
		local text = pool[random:NextInteger(1, #pool)]:gsub("{m}", name)
		table.insert(posts, { handle = handle, text = text })
	end
	return posts
end

local function updateHypeWall(player, profile)
	local _, rank = ModelService.Ranking(player, profile)
	local latest = profile.models[1]
	local lines = {}
	if latest then
		local modelType = Config.ModelTypeById[latest.type]
		table.insert(lines, string.format("<b>%s %s</b>  ⭐ %.1f", modelType.emoji, latest.name, latest.score))
	else
		table.insert(lines, "<b>🚀 COMING SOON...</b>")
	end
	table.insert(lines, string.format("<font color='#FFD84D'>🏆 AI Arena #%d</font>  •  💵 %s/day", rank, Config.Money(revenueToday[player] or 0)))
	for i = 1, math.min(2, #(profile.feed or {})) do
		local post = profile.feed[i]
		table.insert(lines, string.format("<font size='14' color='#AAB4FF'>%s</font> %s", post.handle, post.text))
	end
	CompanyService.SetHypeWall(table.concat(lines, "\n"))
end

-- ================= Thiết kế & phát triển =================

local function startModel(player, profile, typeId, sizeId, features)
	local modelType = type(typeId) == "string" and Config.ModelTypeById[typeId]
	local size = type(sizeId) == "string" and Config.ModelSizeById[sizeId]
	if not modelType or not size or type(features) ~= "table" then
		return
	end
	if profile.dev or profile.pending then
		notify(player, "Your engineers are busy with another model ⏳")
		return
	end
	if not profile.research.done[modelType.requires] then
		notify(player, "Research " .. Config.ResearchById[modelType.requires].name .. " first 🔬", "Open:Research")
		return
	end
	local chosen = {}
	for _, id in features do
		local node = type(id) == "string" and Config.ResearchById[id]
		if node and node.category == "Feature" and profile.research.done[id] and not contains(chosen, id) and #chosen < size.slots then
			table.insert(chosen, id)
		end
	end
	if #chosen == 0 then
		notify(player, "Pick at least one feature for your model 🧩")
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
	local warn = if size.compute > 0 and taken < size.compute then string.format(" (only %d%% of the compute it needs — expect lower scores)", math.floor(taken / size.compute * 100)) else ""
	notify(player, string.format("💻 Started building %s %s%s", modelType.emoji, profile.dev.name, warn))
	CompanyService.PushState(player)
end

local function finishDev(player, profile)
	profile.pending = profile.dev
	profile.dev = nil
	notify(player, string.format("✅ %s is ready! Pick a price and a campaign to launch it 🚀", profile.pending.name), "Open:Model")
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
	local fit, fresh = 0, 0
	for _, id in model.features do
		fit += if contains(modelType.good, id) then 1 else -0.4
		if Config.ResearchById[id].year >= year - 1 then
			fresh += 0.4
		end
	end
	q += math.clamp(fit, -2, 3.5) + math.min(fresh, 1.2)
	q += StaffService.DevSkillAverage(profile) / 25
	q += model.computeRatio * 1.2
	q += size.quality
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
	for _, entry in Config.ReviewComments do
		if score >= entry[1] then
			return entry[2]
		end
	end
	return Config.ReviewComments[#Config.ReviewComments][2]
end

-- Hệ số người dùng chung (chưa tính điểm báo / độ hot / giá) — client dùng để ước tính
local function baseUsers(player, profile, model)
	local modelType = Config.ModelTypeById[model.type]
	local size = Config.ModelSizeById[model.size]
	return modelType.users * size.users * Config.MarketMultiplier(profile.markets)
end

local function hypeFor(player, profile, campaign)
	local hype = campaign.hype * (1 + StaffService.SkillSum(profile, "Marketing") * Config.Sales.MarketingBonus)
	if player:GetAttribute("PRAgency") then
		hype *= Config.PassBonus.PRAgency
	end
	return hype
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
		notify(player, "Research " .. campaign.name .. " first 🔬")
		return
	end
	if campaign.price > 0 and not CompanyService.Spend(player, campaign.price, "run a " .. campaign.name .. " campaign") then
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

	local hype = hypeFor(player, profile, campaign)
	if profile.viral > 0 then
		profile.viral -= 1
		hype *= 2
	end
	local priceFit = price.users
	if price.id == "Premium" and score < 7 then
		priceFit *= 0.6 -- model dở mà bán đắt thì ít người mua
	end
	local peak = baseUsers(player, profile, model) * (score / 10) ^ 2 * hype * priceFit
	local arena = Config.ArenaScore(score, model.size, goodCount(model), profile.day)
	local _, oldRank = ModelService.Ranking(player, profile)

	table.insert(profile.models, 1, {
		name = model.name,
		type = model.type,
		size = model.size,
		score = score,
		arena = arena,
		launchDay = profile.day,
		peak = peak,
		price = price.id,
		users = 0,
		revenue = 0,
		active = true,
	})
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

	-- thống kê cho chuỗi mục tiêu
	profile.launchCount = (profile.launchCount or 0) + 1
	profile.bestScore = math.max(profile.bestScore or 0, score)
	profile.typesLaunched = profile.typesLaunched or {}
	profile.typesLaunched[model.type] = true
	for i, s in Config.ModelSizes do
		if s.id == model.size then
			profile.maxSize = math.max(profile.maxSize or 0, i)
		end
	end

	profile.feed = makeFeed(model.name, score)
	local _, newRank = ModelService.Ranking(player, profile)
	lastRank[player] = newRank
	local modelType = Config.ModelTypeById[model.type]
	CompanyService.Popup(player, {
		kind = "Review",
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
		arena = arena,
		rank = newRank,
		rankUp = newRank < oldRank,
		feed = profile.feed,
	})
	updateHypeWall(player, profile)
	CompanyService.PushState(player)
end

-- ================= Mỗi ngày: doanh số + đối thủ =================

local function dailySales(player, profile, day, rank)
	local total = 0
	local mult = (1 + StaffService.SkillSum(profile, "Marketing") * Config.Sales.MarketingBonus) * arenaBonus(rank) * CompanyService.Modifier(profile, "Users")
	local cashMult = CompanyService.CashMultiplier(player)
	for _, model in profile.models do
		if model.active then
			local age = day - model.launchDay
			local users = Config.UsersAt(model.peak, age) * mult
			local revenue = users * Config.PriceTierById[model.price].perUser * cashMult
			model.users = users
			model.revenue += revenue
			total += revenue
			if age > Config.Sales.MaxDays or (age > Config.Sales.RampDays and users < 1) then
				model.active = false
				model.users = 0
				notify(player, string.format("📦 %s was retired after %d days, earning %s in total", model.name, age, Config.Money(model.revenue)))
			end
		end
	end
	CompanyService.AddCash(player, total)
	revenueToday[player] = total
end

local function rivalReleases(player, profile, day)
	ensureRivals(profile)
	for _, rival in Config.Stocks do
		local r = profile.rivals[rival.id]
		if day >= r.nextDay then
			r.version += 1
			r.arena = math.max(r.arena + 10, Config.RivalArena(rival, day, random:NextInteger(-40, 40)))
			r.nextDay = day + random:NextInteger(A.ReleaseDays[1], A.ReleaseDays[2])
			local jump = random:NextNumber(A.StockJump[1], A.StockJump[2])
			StockService.Jump(rival.id, jump)
			notify(player, string.format("📰 %s %s launched %s %d (Arena %d) — stock +%d%%", rival.emoji, rival.name, rival.brand, r.version, r.arena, math.floor(jump * 100)), "News")
		end
	end
end

function ModelService.RevenuePerDay(player)
	return revenueToday[player] or 0
end

function ModelService.ArenaRank(player)
	local profile = DataService.Profiles[player]
	if not profile then
		return 99
	end
	local _, rank = ModelService.Ranking(player, profile)
	return rank
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
			notify(player, "Move into a " .. Config.Buildings[market.requireBuilding].name .. " before entering " .. market.name .. " 🏢")
			return
		end
		if not CompanyService.Spend(player, market.price, "enter " .. market.name) then
			return
		end
		profile.markets[market.id] = true
		notify(player, string.format("%s You're now selling in %s! Future launches reach more users", market.emoji, market.name), "Evolve")
		CompanyService.PushState(player)
	end)

	CalendarService.RegisterDayHook(function(player, profile, day)
		if profile.dev then
			profile.dev.progress += StaffService.Points(player, profile, "Dev")
			if profile.dev.progress >= Config.ModelSizeById[profile.dev.size].devPoints then
				finishDev(player, profile)
			end
		end
		rivalReleases(player, profile, day)
		local _, rank = ModelService.Ranking(player, profile)
		if lastRank[player] and rank ~= lastRank[player] and #profile.models > 0 then
			if rank < lastRank[player] then
				notify(player, string.format("🏆 You climbed to #%d in the AI Arena!", rank), "Evolve")
			else
				notify(player, string.format("📉 A rival pushed you down to #%d in the AI Arena", rank))
			end
		end
		lastRank[player] = rank
		dailySales(player, profile, day, rank)
		if day % 7 == 0 then
			updateHypeWall(player, profile)
		end
	end)

	CompanyService.RegisterStateProvider(function(player, profile, state)
		local dev = profile.dev
		local devPoints = StaffService.Points(player, profile, "Dev")
		local need = dev and Config.ModelSizeById[dev.size].devPoints
		local ranking, rank = ModelService.Ranking(player, profile)
		local pending = profile.pending
		state.model = {
			dev = dev,
			progress = if dev then math.clamp(dev.progress / need, 0, 1) else 0,
			eta = if dev and devPoints > 0 then math.ceil((need - dev.progress) / devPoints) else 0,
			pending = pending,
			-- ước tính người dùng lúc ra mắt (chưa có điểm báo): client nhân thêm độ hot và giá
			launchBase = if pending then baseUsers(player, profile, pending) * arenaBonus(rank) else 0,
			hypeBase = (1 + StaffService.SkillSum(profile, "Marketing") * Config.Sales.MarketingBonus) * (if player:GetAttribute("PRAgency") then Config.PassBonus.PRAgency else 1),
			history = profile.models,
			viral = profile.viral,
			devPerDay = devPoints,
			feed = profile.feed,
		}
		state.arena = { ranking = ranking, rank = rank, bonus = arenaBonus(rank) }
		state.markets = profile.markets
		state.marketMult = Config.MarketMultiplier(profile.markets)
		state.revenuePerDay = ModelService.RevenuePerDay(player)
	end)
end

function ModelService.OnPlayerLoaded(player)
	local profile = DataService.Profiles[player]
	if profile then
		ensureRivals(profile)
		local _, rank = ModelService.Ranking(player, profile)
		lastRank[player] = rank
		updateHypeWall(player, profile)
	end
end

return ModelService
