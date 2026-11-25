-- Mã quà (redeem code) + thành tựu (achievement / badge Roblox).
-- Chữ người chơi thấy là tiếng Anh; chú thích code là tiếng Việt.
--
-- Bảng mã quà nằm riêng ở server (ServerScriptService/CodesConfig) để client không đọc trộm được.

local Config = require(script.Parent:WaitForChild("Config"))

local RewardsConfig = {}

-- ===== Thành tựu =====
-- Danh sách có thứ tự (bảng Achievements hiển thị đúng thứ tự này, chia theo `group`).
-- badgeId: ID badge Roblox (tạo ở Creator Dashboard > Badges). 0 = chưa cấu hình, KHÔNG trao badge.
-- reward.credits: credits gốc, nhân theo level lúc mở khoá (Config.ScaledCredits)
-- check/target: điều kiện để AchievementService tự đánh giá từ hồ sơ người chơi:
--   joined                     vào game
--   hatched                    đã mở ít nhất 1 capsule
--   rarity     = "Epic"...     có/từng khám phá 1 bot độ hiếm đó
--   variant    = "Shiny"|"Holo" có/từng có 1 bot biến thể đó
--   level      = số            đạt level
--   boss       = id vùng       đã hạ boss của vùng (profile.stats.bosses)
--   eventWins  = số            số lần thắng Glitch Floor
--   sets       = số            số bộ Bot Database đã nhận thưởng (profile.claimedSets)
--   discovered = số            số loại bot đã khám phá (profile.discovered)
--   habitat    = số            số bot đang ở Habitat
--   fused      = số            số lần Fuse (profile.stats.fused)

-- mở vùng mới theo level (tên + level lấy từ Config.Zones cho khỏi lệch số)
local function stage(zoneId, badgeId, credits)
	local zone = Config.ZoneById[zoneId]
	return {
		key = "Stage" .. zoneId,
		group = "Stages",
		name = zone.name .. " Pioneer",
		description = string.format("Reach level %d to open %s", zone.level, zone.name),
		icon = zone.emoji,
		badgeId = badgeId,
		reward = { credits = credits },
		check = "level",
		target = zone.level,
	}
end

-- hạ boss của 1 vùng
local function boss(zoneId, badgeId, credits)
	local zone = Config.ZoneById[zoneId]
	local title = (zone.boss.name:gsub("^The ", ""))
	return {
		key = "Boss" .. zoneId,
		group = "Bosses",
		name = title .. " Slayer",
		description = string.format("Defeat the %s in %s", title, zone.name),
		icon = "👑",
		badgeId = badgeId,
		reward = { credits = credits },
		check = "boss",
		target = zoneId,
	}
end

RewardsConfig.Achievements = {
	-- 👋 Khởi đầu
	{ key = "Welcome", group = "Getting Started", name = "Welcome, Pilot", description = "Join Neural Frontier", icon = "👋", badgeId = 0, reward = { credits = 100 }, check = "joined" },
	{ key = "FirstCapsule", group = "Getting Started", name = "First Hatch", description = "Open your first capsule", icon = "🥚", badgeId = 0, reward = { credits = 200 }, check = "hatched" },

	-- 🥚 Mở capsule: độ hiếm + biến thể
	{ key = "FirstEpic", group = "Hatching", name = "Epic Find", description = "Get an Epic bot", icon = "💜", badgeId = 0, reward = { credits = 500 }, check = "rarity", target = "Epic" },
	{ key = "FirstLegendary", group = "Hatching", name = "Living Legend", description = "Get a Legendary bot", icon = "🌟", badgeId = 0, reward = { credits = 2000 }, check = "rarity", target = "Legendary" },
	{ key = "FirstMythic", group = "Hatching", name = "Mythic Tamer", description = "Get a Mythic bot", icon = "🔮", badgeId = 0, reward = { credits = 5000 }, check = "rarity", target = "Mythic" },
	{ key = "FirstShiny", group = "Hatching", name = "So Shiny!", description = "Get a Shiny bot", icon = "✨", badgeId = 0, reward = { credits = 1000 }, check = "variant", target = "Shiny" },
	{ key = "FirstHolo", group = "Hatching", name = "Hologram Hero", description = "Get a Holo bot", icon = "🌈", badgeId = 0, reward = { credits = 3000 }, check = "variant", target = "Holo" },

	-- 🗺️ Mở vùng (Meadow mở sẵn từ level 1 nên không tính)
	stage("Canyon", 0, 1000),
	stage("Spires", 0, 1500),
	stage("Frost", 0, 2000),
	stage("Magma", 0, 2500),
	stage("Rift", 0, 3000),
	stage("Citadel", 0, 4000),

	-- 👑 Hạ boss mỗi vùng
	boss("Meadow", 0, 500),
	boss("Canyon", 0, 1000),
	boss("Spires", 0, 1500),
	boss("Frost", 0, 2000),
	boss("Magma", 0, 2500),
	boss("Rift", 0, 3000),
	boss("Citadel", 0, 5000),

	-- 🏆 Thành thạo
	{ key = "GlitchWinner", group = "Mastery", name = "Last Bot Standing", description = "Win a Glitch Floor event", icon = "🟥", badgeId = 0, reward = { credits = 1500 }, check = "eventWins", target = 1 },
	{ key = "SetCollector", group = "Mastery", name = "Set Collector", description = "Claim a capsule set reward in the Bot Database", icon = "📚", badgeId = 0, reward = { credits = 1500 }, check = "sets", target = 1 },
	{ key = "Collector20", group = "Mastery", name = "Bot Collector", description = "Discover 20 different bots", icon = "🗂️", badgeId = 0, reward = { credits = 3000 }, check = "discovered", target = 20 },
	{ key = "Collector40", group = "Mastery", name = "Master Archivist", description = "Discover 40 different bots", icon = "🏛️", badgeId = 0, reward = { credits = 10000 }, check = "discovered", target = 40 },
	{ key = "HabitatHost", group = "Mastery", name = "Habitat Host", description = "Place a bot in your Habitat", icon = "🏠", badgeId = 0, reward = { credits = 300 }, check = "habitat", target = 1 },
	{ key = "Fusion", group = "Mastery", name = "Fusion Lab", description = "Fuse 5 identical bots into a better variant", icon = "🧬", badgeId = 0, reward = { credits = 1000 }, check = "fused", target = 1 },
}

-- tra cứu nhanh theo key
RewardsConfig.AchievementByKey = {}
for i, achievement in RewardsConfig.Achievements do
	achievement.index = i
	RewardsConfig.AchievementByKey[achievement.key] = achievement
end

return RewardsConfig
