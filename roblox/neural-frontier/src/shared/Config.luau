-- Toàn bộ số liệu cân bằng + chữ người chơi thấy (tiếng Anh) + ID kiếm Robux.
-- Chú thích code là tiếng Việt.
--
-- Vòng lặp: dẫn đội bot vào vùng → bot hút Data Shards vào ba lô + bắn drone
-- → về Hub upload data đổi Credits + XP → mua/nâng bot, ba lô → lên level mở vùng mới, đánh boss.

local Config = {}

Config.GameName = "Neural Frontier"
Config.StartingCredits = 50
Config.AutosaveInterval = 120

-- ===== Người chơi =====
Config.Player = {
	BaseHealth = 100,
	HealthPerLevel = 12,
	BasePower = 6, -- sát thương Pulse ở level 1
	PowerPerLevel = 3,
	XpBase = 60,
	XpGrowth = 1.35,
	MaxLevel = 60,
	HarvestCooldown = 0.35, -- bấm thu thập tay
	HarvestRange = 14,
	WalkSpeed = 18,
	TurboSpeed = 26,
}

-- ===== Ba lô (tier) =====
Config.Backpacks = {
	{ name = "Pocket Drive", capacity = 60, price = 0 },
	{ name = "USB Stick", capacity = 200, price = 300 },
	{ name = "SSD Pack", capacity = 600, price = 2000 },
	{ name = "Server Pack", capacity = 1800, price = 12000 },
	{ name = "Data Vault", capacity = 5000, price = 60000 },
	{ name = "Cloud Core", capacity = 15000, price = 300000 },
	{ name = "Quantum Cache", capacity = 50000, price = 1500000 },
}

-- ===== Bot AI: lấy từ Capsule (không mua thẳng) =====
-- gather: data/giây khi đứng trong vùng, attack: sát thương/giây lên quái gần nhất
-- value: "giá trị" bot tính bằng Credits (giá nâng cấp + tiền Recycle 30%)
-- form: dáng thú máy trong BotModels (Orb, Cat, Fox, Beetle, Owl, Jelly, Dragon)
Config.Bots = {
	-- 🌿 Meadow Capsule
	{ id = "Scout", name = "Scout Orb", rarity = "Common", gather = 1, attack = 1, value = 60, form = "Orb", color = Color3.fromRGB(120, 220, 255), size = 1.2 },
	{ id = "Byte", name = "Byte Kitty", rarity = "Common", gather = 1.5, attack = 1, value = 80, form = "Cat", color = Color3.fromRGB(140, 190, 255), size = 1.3 },
	{ id = "Miner", name = "Miner Beetle", rarity = "Rare", gather = 3, attack = 1.5, value = 300, form = "Beetle", color = Color3.fromRGB(255, 200, 80), size = 1.4 },
	{ id = "Glitch", name = "Glitch Fox", rarity = "Epic", gather = 3, attack = 5, value = 900, form = "Fox", color = Color3.fromRGB(255, 90, 140), size = 1.5 },
	{ id = "Pixel", name = "Pixel Owl", rarity = "Legendary", gather = 8, attack = 8, value = 4000, form = "Owl", color = Color3.fromRGB(255, 225, 90), accent = Color3.fromRGB(80, 230, 255), size = 1.7 },
	-- 🏜️ Canyon Capsule
	{ id = "Guard", name = "Guard Beetle", rarity = "Common", gather = 3, attack = 8, value = 2000, form = "Beetle", color = Color3.fromRGB(230, 90, 80), size = 1.5 },
	{ id = "Laser", name = "Laser Orb", rarity = "Common", gather = 5, attack = 10, value = 2500, form = "Orb", color = Color3.fromRGB(255, 60, 200), size = 1.5 },
	{ id = "Dune", name = "Dune Kitty", rarity = "Rare", gather = 9, attack = 9, value = 8000, form = "Cat", color = Color3.fromRGB(240, 180, 110), size = 1.6 },
	{ id = "Harvester", name = "Harvester Jelly", rarity = "Epic", gather = 20, attack = 8, value = 25000, form = "Jelly", color = Color3.fromRGB(120, 255, 140), size = 1.7 },
	{ id = "Drake", name = "Sun Drake", rarity = "Legendary", gather = 30, attack = 35, value = 120000, form = "Dragon", color = Color3.fromRGB(255, 150, 40), accent = Color3.fromRGB(255, 240, 120), size = 2 },
	-- 🌃 Spires Capsule
	{ id = "Titan", name = "Titan Beetle", rarity = "Common", gather = 20, attack = 45, value = 45000, form = "Beetle", color = Color3.fromRGB(170, 110, 255), size = 1.8 },
	{ id = "Jelly", name = "Neon Jelly", rarity = "Common", gather = 40, attack = 20, value = 50000, form = "Jelly", color = Color3.fromRGB(80, 230, 255), size = 1.8 },
	{ id = "Volt", name = "Volt Fox", rarity = "Rare", gather = 45, attack = 55, value = 180000, form = "Fox", color = Color3.fromRGB(90, 160, 255), accent = Color3.fromRGB(255, 255, 120), size = 1.9 },
	{ id = "Void", name = "Void Owl", rarity = "Epic", gather = 80, attack = 90, value = 600000, form = "Owl", color = Color3.fromRGB(110, 60, 190), accent = Color3.fromRGB(255, 80, 220), size = 2 },
	{ id = "Quantum", name = "Quantum Dragon", rarity = "Legendary", gather = 150, attack = 150, value = 3000000, form = "Dragon", color = Color3.fromRGB(235, 242, 255), accent = Color3.fromRGB(0, 230, 255), size = 2.2 },
	-- 💎 Neon Capsule (Robux)
	{ id = "Holo", name = "Holo Kitty", rarity = "Epic", gather = 25, attack = 25, value = 150000, form = "Cat", color = Color3.fromRGB(0, 255, 220), accent = Color3.fromRGB(255, 120, 255), size = 1.7 },
	{ id = "Prism", name = "Prism Fox", rarity = "Epic", gather = 35, attack = 40, value = 220000, form = "Fox", color = Color3.fromRGB(255, 120, 255), accent = Color3.fromRGB(120, 255, 255), size = 1.8 },
	{ id = "Aurora", name = "Aurora Owl", rarity = "Legendary", gather = 90, attack = 90, value = 800000, form = "Owl", color = Color3.fromRGB(120, 255, 200), accent = Color3.fromRGB(180, 120, 255), size = 2 },
	{ id = "Nova", name = "Nova Dragon", rarity = "Mythic", gather = 220, attack = 220, value = 3000000, form = "Dragon", color = Color3.fromRGB(255, 80, 160), accent = Color3.fromRGB(255, 220, 90), size = 2.4 },
	{ id = "Singularity", name = "Singularity", rarity = "Mythic", gather = 500, attack = 500, value = 8000000, form = "Orb", color = Color3.fromRGB(190, 120, 255), accent = Color3.fromRGB(255, 255, 255), size = 2.6 },
}
Config.RarityColors = {
	Common = Color3.fromRGB(170, 180, 200),
	Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(180, 90, 255),
	Legendary = Color3.fromRGB(255, 200, 60),
	Mythic = Color3.fromRGB(255, 70, 200),
}
Config.RarityOrder = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5 }
-- Luck chỉ nhân trọng số của các độ hiếm này (tỉ lệ hiển thị luôn tính sẵn luck)
Config.LuckRarities = { Epic = true, Legendary = true, Mythic = true }

-- ===== Biến thể bot =====
-- Mỗi bot mở từ capsule có cơ hội ra biến thể: chỉ số và giá trị nhân `mult`.
-- Game Pass Shiny Hunter nhân đôi cơ hội. Fuse: gộp FuseCount bot giống hệt nhau (cùng loại,
-- cùng biến thể) thành 1 bot biến thể kế tiếp (thường -> Shiny -> Holo).
Config.Variants = {
	{ id = "Shiny", name = "Shiny", emoji = "✨", chance = 1 / 40, mult = 1.5, color = Color3.fromRGB(255, 215, 90) },
	{ id = "Holo", name = "Holo", emoji = "🌈", chance = 1 / 400, mult = 3, color = Color3.fromRGB(120, 255, 255) },
}
Config.FuseCount = 5
Config.NextVariant = { [""] = "Shiny", Shiny = "Holo" }

-- ===== Capsule =====
-- price: giá Credits mỗi capsule (nil = chỉ mua bằng Robux). level: level cần để mở.
-- drops: trọng số rơi (cộng lại = 100 => đúng bằng % hiển thị khi không có luck)
-- reward: thưởng khi khám phá đủ bộ trong Bot Database (credits + % gather vĩnh viễn)
Config.Capsules = {
	{
		id = "Meadow", name = "Meadow Capsule", emoji = "🌿", price = 120, level = 1, color = Color3.fromRGB(110, 255, 150),
		drops = { { bot = "Scout", weight = 45 }, { bot = "Byte", weight = 30 }, { bot = "Miner", weight = 17 }, { bot = "Glitch", weight = 7 }, { bot = "Pixel", weight = 1 } },
		reward = { credits = 1000, gather = 0.05 },
	},
	{
		id = "Canyon", name = "Canyon Capsule", emoji = "🏜️", price = 4000, level = 6, color = Color3.fromRGB(255, 170, 70),
		drops = { { bot = "Guard", weight = 45 }, { bot = "Laser", weight = 30 }, { bot = "Dune", weight = 17 }, { bot = "Harvester", weight = 7 }, { bot = "Drake", weight = 1 } },
		reward = { credits = 30000, gather = 0.1 },
	},
	{
		id = "Spires", name = "Spires Capsule", emoji = "🌃", price = 90000, level = 15, color = Color3.fromRGB(180, 100, 255),
		drops = { { bot = "Titan", weight = 45 }, { bot = "Jelly", weight = 30 }, { bot = "Volt", weight = 17 }, { bot = "Void", weight = 7 }, { bot = "Quantum", weight = 1 } },
		reward = { credits = 600000, gather = 0.15 },
	},
	{
		id = "Neon", name = "Neon Capsule", emoji = "💎", price = nil, level = 1, color = Color3.fromRGB(255, 70, 200), premium = true,
		drops = { { bot = "Holo", weight = 50 }, { bot = "Prism", weight = 30 }, { bot = "Aurora", weight = 15 }, { bot = "Nova", weight = 4.5 }, { bot = "Singularity", weight = 0.5 } },
		reward = { credits = 100000, gather = 0.25 },
	},
}
Config.BotSlots = 4
Config.ExtraSlotsPass = 3
Config.MaxBots = 60
-- nâng cấp bot: mỗi cấp +UpgradeBonus chỉ số, giá = value x UpgradeCost x cấp
Config.BotUpgrade = { MaxLevel = 10, UpgradeBonus = 0.25, UpgradeCost = 0.6 }

-- ===== AI Cores (kỹ năng) =====
Config.Cores = {
	{ id = "Pulse", name = "Pulse", emoji = "💥", key = "Q", level = 1, cooldown = 1.2, desc = "Shockwave that damages nearby drones", radius = 16 },
	{ id = "Dash", name = "Dash", emoji = "💨", key = "E", level = 3, cooldown = 4, desc = "Burst forward", power = 90 },
	{ id = "Overclock", name = "Overclock", emoji = "⚡", key = "R", level = 8, cooldown = 30, duration = 10, desc = "x2 bot gather & attack for 10s" },
	{ id = "Shield", name = "Shield", emoji = "🛡️", key = "F", level = 12, cooldown = 25, duration = 6, desc = "Take 70% less damage for 6s", reduction = 0.7 },
}

-- ===== Vùng (zone) =====
-- center: tâm vùng; size: kích thước bãi; level: level cần để qua cổng
-- dataMult: hệ số data/giây; nodes: số tinh thể data; crystal: màu tinh thể
Config.Zones = {
	{
		id = "Meadow", name = "Byte Meadow", emoji = "🌿", level = 1, center = Vector3.new(0, 0, -170), size = 150,
		dataMult = 1, nodes = 22, nodeValue = 6, crystal = Color3.fromRGB(80, 230, 255),
		enemy = { name = "Rogue Drone", hp = 30, damage = 6, speed = 10, credits = 12, xp = 8, count = 7, color = Color3.fromRGB(255, 80, 80) },
		boss = { name = "Glitch King", hp = 900, damage = 18, speed = 8, credits = 600, xp = 250, respawn = 120, color = Color3.fromRGB(255, 40, 120), size = 9 },
	},
	{
		id = "Canyon", name = "Circuit Canyon", emoji = "🏜️", level = 6, center = Vector3.new(0, 0, -400), size = 170,
		dataMult = 4, nodes = 24, nodeValue = 25, crystal = Color3.fromRGB(255, 190, 60),
		enemy = { name = "Scrap Hunter", hp = 220, damage = 18, speed = 12, credits = 90, xp = 45, count = 8, color = Color3.fromRGB(255, 140, 40) },
		boss = { name = "Rust Titan", hp = 9000, damage = 45, speed = 9, credits = 6000, xp = 1800, respawn = 150, color = Color3.fromRGB(200, 100, 30), size = 12 },
	},
	{
		id = "Spires", name = "Neon Spires", emoji = "🌃", level = 15, center = Vector3.new(0, 0, -650), size = 180,
		dataMult = 16, nodes = 26, nodeValue = 110, crystal = Color3.fromRGB(200, 90, 255),
		enemy = { name = "Neon Wraith", hp = 1500, damage = 55, speed = 15, credits = 650, xp = 260, count = 9, color = Color3.fromRGB(160, 60, 255) },
		boss = { name = "Overmind", hp = 80000, damage = 130, speed = 10, credits = 60000, xp = 15000, respawn = 180, color = Color3.fromRGB(120, 0, 255), size = 15 },
	},
}
Config.NodeRespawn = 25
Config.Hub = { center = Vector3.new(0, 0, 0), radius = 45 }

-- ===== Nhiệm vụ của Unit-0 ở Hub =====
-- check: uploaded (data), kills, bots (số bot sở hữu), discovered (số loại bot đã gặp), level, boss (id vùng), backpack (tier)
Config.Quests = {
	{ text = "Upload 50 data at the Hub", check = "uploaded", target = 50, reward = 150 },
	{ text = "Open a Meadow Capsule at the Capsule Lab", check = "bots", target = 2, reward = 200 },
	{ text = "Defeat 5 Rogue Drones", check = "kills", target = 5, reward = 300 },
	{ text = "Upgrade your backpack", check = "backpack", target = 2, reward = 400 },
	{ text = "Reach level 3 and unlock Dash", check = "level", target = 3, reward = 600 },
	{ text = "Own 4 bots", check = "bots", target = 4, reward = 1200 },
	{ text = "Discover 4 different bots", check = "discovered", target = 4, reward = 1500 },
	{ text = "Win a Glitch Floor event", check = "eventWins", target = 1, reward = 2500 },
	{ text = "Defeat the Glitch King", check = "boss", target = "Meadow", reward = 3000 },
	{ text = "Reach level 6 to open Circuit Canyon", check = "level", target = 6, reward = 4000 },
	{ text = "Upload 5,000 data", check = "uploaded", target = 5000, reward = 8000 },
	{ text = "Defeat 50 enemies", check = "kills", target = 50, reward = 15000 },
	{ text = "Defeat the Rust Titan", check = "boss", target = "Canyon", reward = 40000 },
	{ text = "Reach level 15 to open Neon Spires", check = "level", target = 15, reward = 80000 },
	{ text = "Upload 500,000 data", check = "uploaded", target = 500000, reward = 300000 },
	{ text = "Defeat the Overmind", check = "boss", target = "Spires", reward = 1000000 },
}

-- ===== Quà đăng nhập mỗi ngày =====
-- Chuỗi 7 ngày; lỡ 1 ngày thì quay lại ngày 1. Credits nhân theo level (Config.ScaledCredits).
-- capsule = "Best": capsule Credits xịn nhất đã mở khoá.
Config.DailyRewards = {
	{ credits = 150 },
	{ capsule = "Best" },
	{ credits = 500 },
	{ boost = "Luck", minutes = 15 },
	{ credits = 1500 },
	{ boost = "Gather", minutes = 30 },
	{ capsule = "Neon" },
}

-- ===== Sự kiện Glitch Floor =====
-- Sàn đấu bay bên phải Hub: ô sàn nhấp nháy đỏ rồi rơi, trụ lại cuối cùng thì thắng.
Config.Event = {
	Interval = 300, -- giây chờ giữa 2 lượt
	LobbyTime = 25, -- thời gian mời tham gia trước khi bắt đầu
	MaxTime = 90, -- trụ hết thời gian này cũng thắng
	ArenaCenter = Vector3.new(175, 50, 0),
	Grid = 9,
	TileSize = 8,
	WinCredits = 500,
	PlayCredits = 100,
}

-- ===== Kiếm Robux =====
-- ID = 0 nghĩa là chưa cấu hình.
-- paidRandom = true: liên quan tới vật phẩm ngẫu nhiên trả tiền. Người chơi ở nơi luật cấm
-- (PolicyService.ArePaidRandomItemsRestricted) sẽ KHÔNG thấy và không mua được các món này.
Config.GamePasses = {
	VIP = { id = 0, name = "⭐ VIP", description = "x2 Credits from uploads, VIP chat tag" },
	LuckyScanner = { id = 0, name = "🍀 Lucky Scanner", description = "x1.5 luck on every capsule, forever", paidRandom = true },
	TripleHatch = { id = 0, name = "🥚 Triple Hatch", description = "Open 3 credit capsules at once", paidRandom = true },
	ShinyHunter = { id = 0, name = "✨ Shiny Hunter", description = "x2 chance for Shiny and Holo bots", paidRandom = true },
	RapidFire = { id = 0, name = "⚡ Rapid Fire", description = "Your bots attack 2x faster" },
	AutoHarvest = { id = 0, name = "🤖 Auto Harvest", description = "Your squad harvests nearby crystals for you" },
	DataShield = { id = 0, name = "🛡️ Data Shield", description = "Keep your data when you get knocked out" },
	CoreOverdrive = { id = 0, name = "🔋 Core Overdrive", description = "Abilities recharge 2x faster" },
	ZoneWarp = { id = 0, name = "🌀 Zone Warp", description = "Teleport to any unlocked zone instantly" },
	MegaStorage = { id = 0, name = "📦 Mega Storage", description = "+60 bot storage" },
	BotSlots = { id = 0, name = "🤖 +3 Bot Slots", description = "Bring 3 more bots into battle" },
	BigBackpack = { id = 0, name = "🎒 Big Backpack", description = "x2 backpack capacity forever" },
	AutoUpload = { id = 0, name = "📡 Auto Upload", description = "Data uploads itself when your backpack is full" },
	TurboBoots = { id = 0, name = "👟 Turbo Boots", description = "Run much faster" },
}
-- kind: Boost (boosts = { tên = giây thật }: Credits, Gather, Luck, Clones) | Credits (minutes: số phút thu nhập, min)
--       Capsule (capsule = id, count = số capsule mở ngay)
--       Bundle (gói cố định, không ngẫu nhiên: bot chắc chắn + credits + boost; once = chỉ bán 1 lần)
Config.DevProducts = {
	StarterPack = { id = 0, kind = "Bundle", once = true, bot = "Holo", credits = 5000, boosts = { Credits = 30 * 60, Gather = 30 * 60 }, name = "🎁 Starter Pack" },
	NeonCapsule1 = { id = 0, kind = "Capsule", capsule = "Neon", count = 1, name = "💎 Neon Capsule x1", paidRandom = true },
	NeonCapsule3 = { id = 0, kind = "Capsule", capsule = "Neon", count = 3, name = "💎 Neon Capsule x3", paidRandom = true },
	NeonCapsule10 = { id = 0, kind = "Capsule", capsule = "Neon", count = 10, name = "💎 Neon Capsule x10", paidRandom = true },
	LuckBoost = { id = 0, kind = "Boost", boosts = { Luck = 15 * 60 }, name = "🍀 x2 Luck (15 min)", paidRandom = true },
	CreditBoost = { id = 0, kind = "Boost", boosts = { Credits = 30 * 60 }, name = "💰 x2 Credits (30 min)" },
	CloneSquad = { id = 0, kind = "Boost", boosts = { Clones = 15 * 60 }, name = "👥 x4 Clone Squad (15 min)" },
	-- ServerBoost: bật cho CẢ server (mọi người cùng hưởng, cả server được báo tên người mua)
	ServerLuck = { id = 0, kind = "ServerBoost", boost = "Luck", seconds = 15 * 60, name = "🌍 Server x2 Luck (15 min)", paidRandom = true },
	GatherBoost = { id = 0, kind = "Boost", boosts = { Gather = 15 * 60 }, name = "💾 x2 Gather (15 min)" },
	MegaBoost = { id = 0, kind = "Boost", boosts = { Credits = 30 * 60, Gather = 30 * 60 }, name = "🚀 Mega Boost (30 min)" },
	-- Credits mua được capsule nên cũng tính là paidRandom
	CreditsSmall = { id = 0, kind = "Credits", minutes = 10, min = 1000, name = "💳 Credit Pack S", paidRandom = true },
	CreditsLarge = { id = 0, kind = "Credits", minutes = 60, min = 10000, name = "💳 Credit Pack L", paidRandom = true },
}
-- thứ tự trong bảng Shop (Neon Capsule nằm ở Capsule Lab)
Config.ShopRobux = {
	{ "pass", "VIP" },
	{ "pass", "LuckyScanner" },
	{ "pass", "TripleHatch" },
	{ "pass", "ShinyHunter" },
	{ "pass", "RapidFire" },
	{ "pass", "AutoHarvest" },
	{ "pass", "DataShield" },
	{ "pass", "CoreOverdrive" },
	{ "pass", "ZoneWarp" },
	{ "pass", "MegaStorage" },
	{ "pass", "BotSlots" },
	{ "pass", "BigBackpack" },
	{ "pass", "AutoUpload" },
	{ "pass", "TurboBoots" },
	{ "product", "MegaBoost" },
	{ "product", "CloneSquad" },
	{ "product", "ServerLuck" },
	{ "product", "LuckBoost" },
	{ "product", "CreditBoost" },
	{ "product", "GatherBoost" },
	{ "product", "CreditsSmall" },
	{ "product", "CreditsLarge" },
}
Config.NeonProducts = { "NeonCapsule1", "NeonCapsule3", "NeonCapsule10" }
Config.Multipliers = { Vip = 2, CreditBoost = 2, GatherBoost = 2, LuckBoost = 2, LuckyPass = 1.5, ServerLuck = 2 }
-- Clone Squad: số bản sao hologram của bot mạnh nhất và % sức mạnh mỗi bản sao
Config.Clones = { count = 4, power = 0.5 }
Config.MegaStorageBonus = 60
Config.AutoHarvestRange = 30

-- ===== Tra cứu nhanh =====
local function index(list)
	local map = {}
	for i, item in list do
		map[item.id] = item
		item.index = i
	end
	return map
end
Config.BotById = index(Config.Bots)
Config.CoreById = index(Config.Cores)
Config.ZoneById = index(Config.Zones)
Config.CapsuleById = index(Config.Capsules)
Config.VariantById = index(Config.Variants)
for _, capsule in Config.Capsules do
	for _, drop in capsule.drops do
		Config.BotById[drop.bot].capsule = capsule.id
	end
end
Config.DevProductById = {}
for key, product in Config.DevProducts do
	if product.id ~= 0 then
		Config.DevProductById[product.id] = key
	end
end

-- ===== Công thức =====

function Config.XpToNext(level)
	return math.floor(Config.Player.XpBase * Config.Player.XpGrowth ^ (level - 1))
end

function Config.MaxHealth(level)
	return Config.Player.BaseHealth + Config.Player.HealthPerLevel * (level - 1)
end

function Config.Power(level)
	return Config.Player.BasePower + Config.Player.PowerPerLevel * (level - 1)
end

function Config.VariantMult(variant)
	local v = variant and Config.VariantById[variant]
	return if v then v.mult else 1
end
-- tên hiển thị kèm biến thể: "✨ Shiny Byte Kitty"
function Config.BotLabel(bot, variant)
	local v = variant and Config.VariantById[variant]
	return if v then string.format("%s %s %s", v.emoji, v.name, bot.name) else bot.name
end
-- cơ hội ra biến thể (0..1), có pass Shiny Hunter thì x2
function Config.VariantChance(variant, hunter)
	local v = Config.VariantById[variant]
	return v.chance * (if hunter then 2 else 1)
end
-- credits thưởng (quà ngày, sự kiện) tăng theo level để luôn đáng giá
function Config.ScaledCredits(base, level)
	return math.floor(base * 1.22 ^ ((level or 1) - 1))
end

-- chỉ số 1 bot theo cấp nâng và biến thể
function Config.BotStat(bot, level, stat, variant)
	return bot[stat] * (1 + Config.BotUpgrade.UpgradeBonus * ((level or 1) - 1)) * Config.VariantMult(variant)
end

function Config.BotUpgradePrice(bot, level)
	return math.floor(bot.value * Config.BotUpgrade.UpgradeCost * level)
end
function Config.RecycleValue(bot, level, variant)
	return math.floor(bot.value * 0.3 * (1 + 0.5 * ((level or 1) - 1)) * Config.VariantMult(variant))
end

-- Tỉ lệ rơi thật của 1 capsule với hệ số luck: { { bot, chance (0..1) } } theo thứ tự drops
function Config.CapsuleOdds(capsule, luck)
	luck = luck or 1
	local list, total = {}, 0
	for _, drop in capsule.drops do
		local bot = Config.BotById[drop.bot]
		local weight = drop.weight * (if Config.LuckRarities[bot.rarity] then luck else 1)
		table.insert(list, { bot = bot, weight = weight })
		total += weight
	end
	for _, item in list do
		item.chance = item.weight / total
	end
	return list
end
function Config.FormatChance(chance)
	local pct = chance * 100
	if pct >= 10 then
		return string.format("%.0f%%", pct)
	elseif pct >= 1 then
		return (string.format("%.1f", pct):gsub("%.0$", "")) .. "%"
	end
	return (string.format("%.2f", pct):gsub("0$", "")) .. "%"
end

-- vùng mà toạ độ `pos` đang đứng trong (nil nếu ở ngoài)
function Config.ZoneAt(pos)
	for _, zone in Config.Zones do
		local d = pos - zone.center
		if math.abs(d.X) <= zone.size / 2 and math.abs(d.Z) <= zone.size / 2 then
			return zone
		end
	end
	return nil
end

function Config.Short(n)
	n = math.floor(n)
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	for _, unit in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= unit[1] then
			local value = n / unit[1]
			if value >= 100 then
				return sign .. string.format("%d", math.floor(value)) .. unit[2]
			end
			local text = string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
			return sign .. text .. unit[2]
		end
	end
	return sign .. tostring(n)
end

return Config
