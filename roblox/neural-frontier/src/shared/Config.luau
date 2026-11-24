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

-- ===== Bot AI (mua bằng Credits, mỗi lần mua thêm 1 con) =====
-- gather: data/giây khi đứng trong vùng, attack: sát thương/giây lên quái gần nhất
Config.Bots = {
	{ id = "Scout", name = "Scout Bot", rarity = "Common", gather = 1, attack = 1, price = 100, color = Color3.fromRGB(120, 220, 255), size = 1.2 },
	{ id = "Miner", name = "Miner Bot", rarity = "Common", gather = 3, attack = 1, price = 750, color = Color3.fromRGB(255, 200, 80), size = 1.3 },
	{ id = "Guard", name = "Guard Bot", rarity = "Rare", gather = 1, attack = 6, price = 1500, color = Color3.fromRGB(255, 90, 90), size = 1.4 },
	{ id = "Laser", name = "Laser Bot", rarity = "Rare", gather = 3, attack = 12, price = 6000, color = Color3.fromRGB(255, 60, 200), size = 1.4 },
	{ id = "Harvester", name = "Harvester X", rarity = "Epic", gather = 14, attack = 4, price = 18000, color = Color3.fromRGB(120, 255, 140), size = 1.6 },
	{ id = "Titan", name = "Titan Drone", rarity = "Epic", gather = 8, attack = 30, price = 70000, color = Color3.fromRGB(170, 110, 255), size = 1.9 },
	{ id = "Quantum", name = "Quantum Bot", rarity = "Legendary", gather = 40, attack = 40, price = 300000, color = Color3.fromRGB(255, 255, 255), size = 2.1 },
}
Config.RarityColors = {
	Common = Color3.fromRGB(170, 180, 200),
	Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(180, 90, 255),
	Legendary = Color3.fromRGB(255, 200, 60),
}
Config.BotSlots = 4
Config.ExtraSlotsPass = 3
Config.MaxBots = 40
-- nâng cấp bot: mỗi cấp +UpgradeBonus chỉ số, giá = giá gốc x UpgradeCost x cấp
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
-- dataMult: hệ số data/giây; nodes: số tinh thể data; terrain: chất liệu nền
Config.Zones = {
	{
		id = "Meadow", name = "Byte Meadow", emoji = "🌿", level = 1, center = Vector3.new(0, 0, -170), size = 150,
		dataMult = 1, nodes = 22, nodeValue = 6, terrain = Enum.Material.Grass, crystal = Color3.fromRGB(80, 230, 255),
		enemy = { name = "Rogue Drone", hp = 30, damage = 6, speed = 10, credits = 12, xp = 8, count = 7, color = Color3.fromRGB(255, 80, 80) },
		boss = { name = "Glitch King", hp = 900, damage = 18, speed = 8, credits = 600, xp = 250, respawn = 120, color = Color3.fromRGB(255, 40, 120), size = 9 },
	},
	{
		id = "Canyon", name = "Circuit Canyon", emoji = "🏜️", level = 6, center = Vector3.new(0, 0, -400), size = 170,
		dataMult = 4, nodes = 24, nodeValue = 25, terrain = Enum.Material.Sand, crystal = Color3.fromRGB(255, 190, 60),
		enemy = { name = "Scrap Hunter", hp = 220, damage = 18, speed = 12, credits = 90, xp = 45, count = 8, color = Color3.fromRGB(255, 140, 40) },
		boss = { name = "Rust Titan", hp = 9000, damage = 45, speed = 9, credits = 6000, xp = 1800, respawn = 150, color = Color3.fromRGB(200, 100, 30), size = 12 },
	},
	{
		id = "Spires", name = "Neon Spires", emoji = "🌃", level = 15, center = Vector3.new(0, 0, -650), size = 180,
		dataMult = 16, nodes = 26, nodeValue = 110, terrain = Enum.Material.Basalt, crystal = Color3.fromRGB(200, 90, 255),
		enemy = { name = "Neon Wraith", hp = 1500, damage = 55, speed = 15, credits = 650, xp = 260, count = 9, color = Color3.fromRGB(160, 60, 255) },
		boss = { name = "Overmind", hp = 80000, damage = 130, speed = 10, credits = 60000, xp = 15000, respawn = 180, color = Color3.fromRGB(120, 0, 255), size = 15 },
	},
}
Config.NodeRespawn = 25
Config.Hub = { center = Vector3.new(0, 0, 0), radius = 45 }

-- ===== Nhiệm vụ của Unit-0 ở Hub =====
-- check: collect (data upload), kills, buy (số bot sở hữu), level, boss (id vùng), backpack (tier)
Config.Quests = {
	{ text = "Upload 50 data at the Hub", check = "uploaded", target = 50, reward = 150 },
	{ text = "Buy a Scout Bot", check = "bots", target = 2, reward = 200 },
	{ text = "Defeat 5 Rogue Drones", check = "kills", target = 5, reward = 300 },
	{ text = "Upgrade your backpack", check = "backpack", target = 2, reward = 400 },
	{ text = "Reach level 3 and unlock Dash", check = "level", target = 3, reward = 600 },
	{ text = "Own 4 bots", check = "bots", target = 4, reward = 1200 },
	{ text = "Defeat the Glitch King", check = "boss", target = "Meadow", reward = 3000 },
	{ text = "Reach level 6 to open Circuit Canyon", check = "level", target = 6, reward = 4000 },
	{ text = "Upload 5,000 data", check = "uploaded", target = 5000, reward = 8000 },
	{ text = "Defeat 50 enemies", check = "kills", target = 50, reward = 15000 },
	{ text = "Defeat the Rust Titan", check = "boss", target = "Canyon", reward = 40000 },
	{ text = "Reach level 15 to open Neon Spires", check = "level", target = 15, reward = 80000 },
	{ text = "Upload 500,000 data", check = "uploaded", target = 500000, reward = 300000 },
	{ text = "Defeat the Overmind", check = "boss", target = "Spires", reward = 1000000 },
}

-- ===== Kiếm Robux =====
-- ID = 0 nghĩa là chưa cấu hình.
Config.GamePasses = {
	VIP = { id = 0, name = "⭐ VIP", description = "x2 Credits from uploads, VIP chat tag" },
	BotSlots = { id = 0, name = "🤖 +3 Bot Slots", description = "Bring 3 more bots into battle" },
	BigBackpack = { id = 0, name = "🎒 Big Backpack", description = "x2 backpack capacity forever" },
	AutoUpload = { id = 0, name = "📡 Auto Upload", description = "Data uploads itself when your backpack is full" },
	TurboBoots = { id = 0, name = "👟 Turbo Boots", description = "Run much faster" },
}
-- kind: Boost (boosts = { tên = giây thật }) | Credits (minutes: số phút thu nhập, min)
Config.DevProducts = {
	CreditBoost = { id = 0, kind = "Boost", boosts = { Credits = 15 * 60 }, name = "💰 x2 Credits (15 min)" },
	GatherBoost = { id = 0, kind = "Boost", boosts = { Gather = 15 * 60 }, name = "💾 x2 Gather (15 min)" },
	MegaBoost = { id = 0, kind = "Boost", boosts = { Credits = 30 * 60, Gather = 30 * 60 }, name = "🚀 Mega Boost (30 min)" },
	CreditsSmall = { id = 0, kind = "Credits", minutes = 10, min = 1000, name = "💳 Credit Pack S" },
	CreditsLarge = { id = 0, kind = "Credits", minutes = 60, min = 10000, name = "💳 Credit Pack L" },
}
Config.ShopRobux = {
	{ "pass", "VIP" },
	{ "pass", "BotSlots" },
	{ "pass", "BigBackpack" },
	{ "pass", "AutoUpload" },
	{ "pass", "TurboBoots" },
	{ "product", "MegaBoost" },
	{ "product", "CreditBoost" },
	{ "product", "GatherBoost" },
	{ "product", "CreditsSmall" },
	{ "product", "CreditsLarge" },
}
Config.Multipliers = { Vip = 2, CreditBoost = 2, GatherBoost = 2 }

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

-- chỉ số 1 bot theo cấp nâng
function Config.BotStat(bot, level, stat)
	return bot[stat] * (1 + Config.BotUpgrade.UpgradeBonus * ((level or 1) - 1))
end

function Config.BotUpgradePrice(bot, level)
	return math.floor(bot.price * Config.BotUpgrade.UpgradeCost * level)
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
