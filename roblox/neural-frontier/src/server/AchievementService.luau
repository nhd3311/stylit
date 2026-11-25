-- Thành tựu (achievement) + huy hiệu Roblox (badge).
--   • Danh sách nằm ở RewardsConfig.Achievements; mỗi mục có check/target để tự đánh giá từ hồ sơ.
--   • Mở khoá lưu ở profile.achievements[key] = os.time() lúc mở.
--   • Khi mở: trao badge Roblox (bỏ qua nếu badgeId = 0), thưởng ít credits (nhân theo level),
--     báo toast "🏅 Achievement unlocked: ...". Client nhận state.achievements = bảng các key đã mở.
--   • Check(player, profile) xét lại MỌI điều kiện từ hồ sơ, nên chạy được cả khi không có sự kiện:
--     gọi lúc vào game + mỗi 5 giây. Có PlayerService.On thì nghe thêm sự kiện để mở khoá ngay.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RewardsConfig = require(ReplicatedStorage.Shared.RewardsConfig)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)

local AchievementService = {}

local CHECK_INTERVAL = 5

local ownedBadges = {} -- [player] = { [badgeId] = true (đã có) | false (đang xử lý) }: cache UserHasBadgeAsync
local badgesSynced = {} -- [player] = true khi đã thử trao lại badge cho thành tựu mở từ trước
local checking = {} -- [player] = true khi đang Check (chặn gọi lồng nhau qua hook)

-- ================= Badge Roblox =================

-- Trao badge (chạy nền vì gọi web). Đã có hoặc đang xử lý thì bỏ qua; lỗi thì để lần vào game sau thử lại.
local function awardBadge(player, badgeId)
	if type(badgeId) ~= "number" or badgeId == 0 then
		return
	end
	local owned = ownedBadges[player]
	if not owned then
		owned = {}
		ownedBadges[player] = owned
	end
	if owned[badgeId] ~= nil then
		return
	end
	owned[badgeId] = false
	task.spawn(function()
		local hasOk, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, badgeId)
		if hasOk and has then
			owned[badgeId] = true
			return
		end
		if not player.Parent then
			owned[badgeId] = nil
			return
		end
		local ok, result = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, badgeId)
		if ok and result then
			owned[badgeId] = true
		else
			owned[badgeId] = nil
			warn("[AchievementService] Không trao được badge", badgeId, "cho", player.Name, result)
		end
	end)
end

-- ================= Điều kiện =================

local function countKeys(map)
	local n = 0
	for _ in map or {} do
		n += 1
	end
	return n
end

local function ensure(profile)
	profile.achievements = profile.achievements or {}
	return profile.achievements
end

-- Đã từng mở capsule chưa, suy từ hồ sơ (dùng cho người chơi cũ / khi thiếu sự kiện "Hatched").
-- Bot khởi đầu và bot tặng kèm Starter Pack là quà, không tính.
local function hasHatched(profile)
	if next(profile.variants or {}) ~= nil or (profile.stats.fused or 0) > 0 then
		return true
	end
	local gifted = 1 + (if profile.starterPack then 1 else 0)
	return #profile.bots > gifted or countKeys(profile.discovered) > gifted
end

-- có/từng khám phá 1 bot độ hiếm `rarity` (xét cả Bot Database lẫn bot đang sở hữu)
local function hasRarity(profile, rarity)
	for botId in profile.discovered or {} do
		local bot = Config.BotById[botId]
		if bot and bot.rarity == rarity then
			return true
		end
	end
	for _, entry in profile.bots do
		local bot = Config.BotById[entry.type]
		if bot and bot.rarity == rarity then
			return true
		end
	end
	return false
end

-- có/từng có 1 bot biến thể `variant` (Shiny / Holo)
local function hasVariant(profile, variant)
	for _, kinds in profile.variants or {} do
		if kinds[variant] then
			return true
		end
	end
	for _, entry in profile.bots do
		if entry.variant == variant then
			return true
		end
	end
	return false
end

local function homeCount(profile)
	local n = 0
	for _, entry in profile.bots do
		if entry.home then
			n += 1
		end
	end
	return n
end

-- check (trong RewardsConfig) -> hàm(profile, target) trả về true khi đạt
local CHECKS = {
	joined = function()
		return true
	end,
	hatched = function(profile)
		return hasHatched(profile)
	end,
	rarity = function(profile, target)
		return hasRarity(profile, target)
	end,
	variant = function(profile, target)
		return hasVariant(profile, target)
	end,
	level = function(profile, target)
		return (profile.level or 1) >= target
	end,
	boss = function(profile, target)
		return (profile.stats.bosses or {})[target] == true
	end,
	eventWins = function(profile, target)
		return (profile.stats.eventWins or 0) >= target
	end,
	sets = function(profile, target)
		return countKeys(profile.claimedSets) >= target
	end,
	discovered = function(profile, target)
		return countKeys(profile.discovered) >= target
	end,
	habitat = function(profile, target)
		return homeCount(profile) >= target
	end,
	fused = function(profile, target)
		return (profile.stats.fused or 0) >= target
	end,
}

-- ================= Mở khoá =================

-- ghi nhận 1 thành tựu + thưởng credits + trao badge; trả về số credits đã thưởng
local function grant(player, profile, achievement)
	ensure(profile)[achievement.key] = os.time()
	local credits = 0
	local base = achievement.reward and achievement.reward.credits
	if type(base) == "number" and base > 0 then
		credits = Config.ScaledCredits(base, profile.level)
		PlayerService.AddCredits(player, credits)
	end
	awardBadge(player, achievement.badgeId)
	return credits
end

-- 1 toast cho cả loạt (toast mới đè toast cũ nên gộp lại cho người chơi đọc được)
local function announce(player, list, credits)
	if #list == 0 then
		return
	end
	local reward = if credits > 0 then string.format(" +%s credits", Config.Short(credits)) else ""
	local message
	if #list == 1 then
		message = string.format("🏅 Achievement unlocked: %s %s!%s", list[1].icon, list[1].name, reward)
	else
		local names = {}
		for i = 1, math.min(2, #list) do
			table.insert(names, list[i].name)
		end
		local more = if #list > 2 then string.format(" and %d more", #list - 2) else ""
		message = string.format("🏅 Achievement unlocked: %s%s!%s", table.concat(names, ", "), more, reward)
	end
	PlayerService.Notify(player, message, "Reward")
	PlayerService.PushState(player)
end

-- xét mọi thành tựu chưa mở; `forced` = { [key] = true } các thành tựu biết chắc vừa đạt (từ sự kiện)
local function evaluate(player, profile, forced)
	local unlocked = ensure(profile)
	local newly, credits = {}, 0
	for _, achievement in RewardsConfig.Achievements do
		if not unlocked[achievement.key] then
			local test = CHECKS[achievement.check]
			local met = (forced and forced[achievement.key]) or (test and test(profile, achievement.target))
			if met then
				credits += grant(player, profile, achievement)
				table.insert(newly, achievement)
			end
		end
	end
	-- lần đầu trong phiên: trao lại badge cho thành tựu mở từ trước
	-- (badge id mới điền sau, hoặc lần trước gọi web lỗi)
	if not badgesSynced[player] then
		badgesSynced[player] = true
		for _, achievement in RewardsConfig.Achievements do
			if unlocked[achievement.key] then
				awardBadge(player, achievement.badgeId)
			end
		end
	end
	announce(player, newly, credits)
	return #newly
end

local function run(player, profile, forced)
	profile = profile or DataService.Profiles[player]
	if not profile or not player.Parent or checking[player] then
		return 0
	end
	checking[player] = true
	local ok, result = pcall(evaluate, player, profile, forced)
	checking[player] = nil
	if not ok then
		warn("[AchievementService] Lỗi khi xét thành tựu cho", player.Name, result)
		return 0
	end
	return result
end

-- Xét lại mọi điều kiện từ hồ sơ, mở khoá những gì vừa đạt. Trả về số thành tựu vừa mở.
function AchievementService.Check(player, profile)
	return run(player, profile, nil)
end

-- Mở khoá thẳng 1 thành tựu theo key (cho service khác khi có điều kiện riêng). Trả về true nếu vừa mở.
function AchievementService.Unlock(player, key, profile)
	if not RewardsConfig.AchievementByKey[key] then
		warn("[AchievementService] Không có thành tựu", key)
		return false
	end
	return run(player, profile, { [key] = true }) > 0
end

-- đã mở thành tựu `key` chưa
function AchievementService.Has(profile, key)
	return profile ~= nil and profile.achievements ~= nil and profile.achievements[key] ~= nil
end

-- ================= Khởi động =================

function AchievementService.Start()
	-- cảnh báo lỗi cấu hình sớm
	local seen = {}
	for _, achievement in RewardsConfig.Achievements do
		if seen[achievement.key] then
			warn("[AchievementService] Key thành tựu bị trùng:", achievement.key)
		end
		seen[achievement.key] = true
		if not CHECKS[achievement.check] then
			warn("[AchievementService] Thành tựu", achievement.key, "có check lạ:", achievement.check)
		end
	end

	PlayerService.StateExtras.achievements = function(_, profile)
		return ensure(profile)
	end

	-- Kênh sự kiện của PlayerService (nếu có): mở khoá ngay thay vì chờ vòng 5 giây
	if PlayerService.On then
		local function recheck(player, profile)
			AchievementService.Check(player, profile)
		end
		PlayerService.On("Loaded", recheck)
		PlayerService.On("Hatched", function(player, profile)
			run(player, profile, { FirstCapsule = true })
		end)
		PlayerService.On("Fused", function(player, profile)
			run(player, profile, { Fusion = true })
		end)
		PlayerService.On("LevelUp", recheck)
		PlayerService.On("BossKilled", recheck)
		PlayerService.On("EventWin", recheck)
		PlayerService.On("SetClaimed", recheck)
	end
	-- đội/kho bot đổi (đặt bot vào Habitat, Starter Pack...): xét luôn
	table.insert(PlayerService.BotsChanged, function(player, profile)
		AchievementService.Check(player, profile)
	end)

	-- vòng dự phòng: không cần sự kiện vẫn mở khoá được (kể cả lúc vừa vào game)
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for player, profile in DataService.Profiles do
				AchievementService.Check(player, profile)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		ownedBadges[player] = nil
		badgesSynced[player] = nil
		checking[player] = nil
	end)
end

return AchievementService
