-- Tiến trình dài hạn: quà đăng nhập 7 ngày và IPO (rebirth).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LabService = require(script.Parent.LabService)

local ProgressService = {}

local notify = LabService.Notify

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
	return math.max(reward.min, math.floor(LabService.GetRate(player) * reward.minutes * 60))
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
	LabService.AddTokens(player, amount)
	for boost, seconds in reward.boosts or {} do
		profile.boosts[boost] = math.max(os.time(), profile.boosts[boost] or 0) + seconds
	end
	daily.lastClaimDay = today()
	daily.streak = day
	local extra = if reward.boosts then " + x2 Token 30 phút 🚀" else ""
	notify(player, string.format("🎁 Quà ngày %d: +%s token%s", day, Config.Short(amount), extra), "Collect")
	LabService.PushState(player)
end

local function ipoShares(player, profile)
	return Config.SharesFor(profile.runEarned, player:GetAttribute("IPOPlus") == true)
end

local function doIpo(player, profile)
	if profile.ai.level < Config.Rebirth.MinLevel then
		notify(player, string.format("Cần AI Lv.%d mới IPO được 📈", Config.Rebirth.MinLevel))
		return
	end
	local shares = ipoShares(player, profile)
	if shares < 1 then
		notify(player, "Công ty chưa đủ giá trị để IPO, kiếm thêm token đã!")
		return
	end

	profile.shares += shares
	profile.ipoCount += 1
	profile.tokens = 0
	profile.runEarned = 0
	profile.racks = {}
	profile.unlockedRacks = Config.Racks.FreeRacks
	profile.ai = { level = 1, xp = 0 }

	local rank = Config.CompanyRank(profile.ipoCount)
	notify(
		player,
		string.format("🔔 IPO thành công! +%d cổ phiếu (tổng %d, token x%.1f). Công ty giờ là %s!", shares, profile.shares, Config.ShareMultiplier(profile.shares), rank.name),
		"Evolve"
	)
	LabService.RenderAll(player)
	LabService.PushState(player)
end

function ProgressService.Start()
	LabService.RegisterAction("ClaimDaily", function(player, profile)
		claimDaily(player, profile)
	end)
	LabService.RegisterAction("Ipo", function(player, profile)
		doIpo(player, profile)
	end)

	LabService.RegisterStateProvider(function(player, profile, state)
		local day = nextStreak(profile.daily)
		state.daily = {
			claimable = profile.daily.lastClaimDay < today(),
			streak = profile.daily.streak,
			nextDay = day,
			nextAmount = dailyAmount(player, day),
			-- giây tới 0h UTC hôm sau, lúc mở quà tiếp theo
			resetIn = (today() + 1) * 86400 - os.time(),
		}
		state.shares = profile.shares
		state.ipoCount = profile.ipoCount
		state.ipoShares = ipoShares(player, profile)
		state.runEarned = profile.runEarned
	end)
end

return ProgressService
