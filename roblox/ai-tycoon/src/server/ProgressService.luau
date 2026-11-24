-- Tiến trình dài hạn: quà đăng nhập 7 ngày và Bán công ty (rebirth).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CompanyService = require(script.Parent.CompanyService)

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
	return math.max(reward.min, math.floor(CompanyService.CashRate(player) * reward.minutes * 60))
end

local function claimDaily(player, profile)
	local daily = profile.daily
	if daily.lastClaimDay >= today() then
		notify(player, "Hôm nay nhận quà rồi, mai quay lại nha 🎁")
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
	local extra = if reward.boosts then " + x2 Tiền 30 phút 🚀" else ""
	notify(player, string.format("🎁 Quà ngày %d: +%s%s", day, Config.Money(amount), extra), "Collect")
	CompanyService.PushState(player)
end

local function founderPoints(player, profile)
	return Config.FounderPointsFor(profile.runEarned, player:GetAttribute("FounderPlus") == true)
end

local function sellCompany(player, profile)
	if profile.floorsBuilt < Config.Rebirth.RequiredFloor then
		local floor = Config.Floors[Config.Rebirth.RequiredFloor]
		notify(player, string.format("Cần xây tới %s %s mới bán công ty được 💼", floor.emoji, floor.name))
		return
	end
	local points = founderPoints(player, profile)
	if points < 1 then
		notify(player, "Công ty chưa đủ giá trị để bán, kiếm thêm tiền đã!")
		return
	end

	-- reset toàn bộ tài sản của lượt này, chỉ giữ thành tích và Điểm Founder
	profile.founderPoints += points
	profile.sold += 1
	profile.cash = Config.StartingCash
	profile.tokens = 0
	profile.runEarned = 0
	profile.ai = { level = 1, xp = 0 }
	profile.floorsBuilt = 1
	profile.racks = {}
	profile.research = { done = {}, current = nil }
	profile.products = {}
	profile.dev = nil
	profile.stocks = {}

	local rank = Config.CompanyRank(profile.sold)
	notify(
		player,
		string.format(
			"🤝 Bán công ty thành công! +%d Điểm Founder (tổng %d, thu nhập x%.1f). Danh hiệu: %s",
			points,
			profile.founderPoints,
			Config.FounderMultiplier(profile.founderPoints),
			rank.name
		),
		"Evolve"
	)
	CompanyService.NotifyAll(string.format("📰 %s vừa bán công ty và trở thành %s!", player.DisplayName, rank.name))
	CompanyService.ResetBuilding(player)
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
