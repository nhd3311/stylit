-- Tiến trình dài hạn: quà đăng nhập 7 ngày và Bán công ty (rebirth).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CompanyService = require(script.Parent.CompanyService)
local FactoryService = require(script.Parent.FactoryService)
local ModelService = require(script.Parent.ModelService)

local ProgressService = {}

local notify = CompanyService.Notify

local function today()
	return Config.DayNumber(os.time())
end

-- Ngày quà kế tiếp trong chuỗi (bỏ lỡ 1 ngày là về ngày 1, hết 7 ngày quay vòng).
-- Đã nhận hôm nay thì trả về ngày của quà ngày mai.
local function nextStreak(daily)
	local d = today()
	if daily.lastClaimDay == d or daily.lastClaimDay == d - 1 then
		return daily.streak % #Config.Daily + 1
	end
	return 1
end

local function dailyAmount(player, day)
	local reward = Config.Daily[day]
	return math.max(reward.min, math.floor(ModelService.RevenuePerDay(player) * reward.days))
end

local function claimDaily(player, profile)
	local daily = profile.daily
	if daily.lastClaimDay >= today() then
		notify(player, "Already claimed today. Come back tomorrow 🎁")
		return
	end
	local day = nextStreak(daily)
	local reward = Config.Daily[day]
	local amount = dailyAmount(player, day)
	CompanyService.AddCash(player, amount)
	for boost, seconds in reward.boosts or {} do
		profile.boosts[boost] = math.max(os.time(), profile.boosts[boost] or 0) + seconds
	end
	daily.lastClaimDay = today()
	daily.streak = day
	local extra = if reward.boosts then " + x2 revenue for 30 min 🚀" else ""
	notify(player, string.format("🎁 Day %d reward: +%s%s", day, Config.Money(amount), extra), "Collect")
	CompanyService.PushState(player)
end

local function founderPoints(player, profile)
	return Config.FounderPointsFor(profile.runEarned, player:GetAttribute("FounderPlus") == true)
end

local function sellCompany(player, profile)
	if profile.building < Config.Rebirth.RequiredBuilding then
		local b = Config.Buildings[Config.Rebirth.RequiredBuilding]
		notify(player, string.format("Reach the %s %s before you can sell 💼", b.emoji, b.name))
		return
	end
	local points = founderPoints(player, profile)
	if points < 1 then
		notify(player, "Your company isn't worth enough yet. Earn more first!")
		return
	end

	-- reset toàn bộ tài sản của lượt này, chỉ giữ thành tích và Điểm Founder
	profile.founderPoints += points
	profile.sold += 1
	profile.cash = Config.StartingCash
	profile.runEarned = 0
	profile.day = 0
	profile.building = 1
	profile.workstations = 1
	profile.equip = { desk = 1, chair = 1, pc = 1 }
	profile.staff = {}
	profile.candidates = {}
	profile.research = { done = {}, current = nil }
	profile.factory = { built = false, lines = {}, compute = 0 }
	profile.dev = nil
	profile.pending = nil
	profile.models = {}
	profile.brandCount = {}
	profile.markets = { Home = true }
	profile.stocks = {}
	profile.departments = { Dev = 1, Research = 1, Marketing = 1, Engineer = 1 }
	profile.rivals = {}
	profile.modifiers = {}
	profile.event = nil
	profile.goal = 1
	profile.lastParty = -999
	profile.launchCount = 0
	profile.bestScore = 0
	profile.maxSize = 0
	profile.typesLaunched = {}
	profile.feed = nil

	local rank = Config.CompanyRank(profile.sold)
	notify(
		player,
		string.format(
			"🤝 Company sold! +%d Founder Points (total %d, revenue & output x%.1f). New title: %s",
			points,
			profile.founderPoints,
			Config.FounderMultiplier(profile.founderPoints),
			rank.name
		),
		"Evolve"
	)
	CompanyService.RenderBuilding(player)
	FactoryService.Render(player)
	CompanyService.PushState(player)
end

function ProgressService.Start()
	CompanyService.RegisterAction("ClaimDaily", function(player, profile)
		claimDaily(player, profile)
	end)
	CompanyService.RegisterAction("SellCompany", function(player, profile)
		sellCompany(player, profile)
	end)

	CompanyService.RegisterStateProvider(function(player, profile, state)
		local day = nextStreak(profile.daily)
		state.daily = {
			claimable = profile.daily.lastClaimDay < today(),
			streak = profile.daily.streak,
			nextDay = day,
			nextAmount = dailyAmount(player, day),
			-- giây tới 0h UTC hôm sau, lúc mở quà tiếp theo
			resetIn = (today() + 1) * 86400 - os.time(),
		}
		state.sellPoints = founderPoints(player, profile)
	end)
end

return ProgressService
