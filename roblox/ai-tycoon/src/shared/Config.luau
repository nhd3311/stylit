-- Toàn bộ số liệu cân bằng game + ID kiếm Robux nằm ở đây.
-- Muốn chỉnh giá, tốc độ, thêm GPU/cấp AI thì chỉ cần sửa file này.

local Config = {}

Config.GameName = "Trùm Công Nghệ"
Config.StartingTokens = 0
Config.AutosaveInterval = 120 -- giây
Config.MaxLabs = 8 -- số người tối đa/server nên đặt = số này

-- ===== Gõ code (click) =====
Config.Click = {
	BaseTokens = 1, -- token mỗi lần click ở AI level 1
	PerLevel = 0.5, -- +0.5 token/click mỗi level AI
	MinInterval = 0.07, -- chống auto-click (tối đa ~14 click/giây)
}

-- ===== Kệ máy chủ =====
Config.Racks = {
	Count = 12,
	FreeRacks = 4, -- có sẵn lúc mới chơi
	BuyableRacks = 8, -- mua thêm bằng token tới kệ thứ 8
	-- kệ 9-12 chỉ dành cho VIP
	BasePrice = 500, -- giá kệ thứ 5, mỗi kệ sau x Multiplier
	Multiplier = 4,
	BufferSeconds = 300, -- mỗi kệ chứa tối đa 5 phút token, đầy thì ngừng đào
}

-- ===== GPU (tier tăng dần) =====
-- rate: token/giây, price: giá lắp hoặc nâng cấp lên tier này, level: AI level cần để mở
Config.Gpus = {
	{ id = "OldCpu", name = "CPU cũ", emoji = "🧮", rate = 1, price = 15, level = 1, color = Color3.fromRGB(150, 150, 150) },
	{ id = "GamingGpu", name = "GPU Gaming", emoji = "🎮", rate = 5, price = 200, level = 3, color = Color3.fromRGB(80, 200, 255) },
	{ id = "ProGpu", name = "GPU Pro", emoji = "💠", rate = 25, price = 2500, level = 6, color = Color3.fromRGB(120, 255, 140) },
	{ id = "TensorCore", name = "Tensor Core", emoji = "🔷", rate = 120, price = 30000, level = 10, color = Color3.fromRGB(255, 220, 60) },
	{ id = "SuperComputer", name = "Siêu máy tính", emoji = "🖥️", rate = 600, price = 350000, level = 15, color = Color3.fromRGB(255, 120, 40) },
	{ id = "QuantumChip", name = "Chip Lượng Tử", emoji = "⚛️", rate = 3000, price = 4000000, level = 22, color = Color3.fromRGB(200, 80, 255) },
}

-- ===== AI =====
Config.AI = {
	MaxLevel = 60,
	XpBase = 100, -- XP để lên level 2
	XpGrowth = 1.6, -- mỗi level cần nhiều hơn x1.6
	ProductionPerLevel = 0.15, -- mỗi level +15% token từ GPU
}

-- Các giai đoạn tiến hoá của AI (tên + màu lõi AI ở giữa phòng lab)
Config.AIStages = {
	{ level = 1, name = "Bot Ngáo", emoji = "🤖", color = Color3.fromRGB(150, 150, 170), size = 4 },
	{ level = 5, name = "Trợ Lý Ảo", emoji = "💬", color = Color3.fromRGB(80, 180, 255), size = 5 },
	{ level = 10, name = "Coder AI", emoji = "💻", color = Color3.fromRGB(80, 255, 160), size = 6 },
	{ level = 18, name = "Thiên Tài Số", emoji = "🧠", color = Color3.fromRGB(255, 210, 60), size = 7 },
	{ level = 28, name = "AGI", emoji = "🌐", color = Color3.fromRGB(255, 100, 60), size = 8.5 },
	{ level = 40, name = "Siêu Trí Tuệ", emoji = "✨", color = Color3.fromRGB(210, 90, 255), size = 10 },
}

-- Offline: GPU vẫn đào khi thoát game, tối đa bấy nhiêu giờ
Config.OfflineHours = 2
Config.VipOfflineHours = 8

-- ===== Kiếm Robux =====
-- Tạo Game Pass / Developer Product trên Creator Dashboard rồi dán ID vào đây.
-- ID = 0 nghĩa là chưa cấu hình: nút mua sẽ báo lỗi thay vì mở bảng mua.
Config.GamePasses = {
	VIP = {
		id = 0,
		name = "⭐ VIP",
		description = "x2 token, +4 kệ VIP, offline 8 giờ, tag VIP",
	},
	AutoCollect = {
		id = 0,
		name = "🤖 Auto Thu Token",
		description = "Token từ GPU tự bay vào ví, không cần đi thu",
	},
}

-- kind = "Boost": bật boost trong `duration` giây (mua thêm thì cộng dồn thời gian)
-- kind = "TimeWarp": nhận ngay số token bằng `hours` giờ đào hiện tại
Config.DevProducts = {
	TokenBoost = { id = 0, kind = "Boost", boost = "Tokens", duration = 15 * 60, name = "🪙 x2 Token (15 phút)" },
	TrainBoost = { id = 0, kind = "Boost", boost = "Training", duration = 15 * 60, name = "🧠 x2 Train AI (15 phút)" },
	TimeWarp1H = { id = 0, kind = "TimeWarp", hours = 1, name = "⏩ Time Warp 1 giờ" },
	TimeWarp6H = { id = 0, kind = "TimeWarp", hours = 6, name = "⏩ Time Warp 6 giờ" },
}

Config.Multipliers = {
	VipTokens = 2,
	TokenBoost = 2,
	TrainBoost = 2,
}

-- ===== Tra cứu nhanh =====
Config.GpuById = {}
Config.GpuTier = {}
for tier, gpu in Config.Gpus do
	Config.GpuById[gpu.id] = gpu
	Config.GpuTier[gpu.id] = tier
end

Config.DevProductById = {}
for key, product in Config.DevProducts do
	if product.id ~= 0 then
		Config.DevProductById[product.id] = key
	end
end

-- XP cần để đi từ `level` lên `level + 1`
function Config.XpToNext(level)
	return math.floor(Config.AI.XpBase * Config.AI.XpGrowth ^ (level - 1))
end

function Config.StageFor(level)
	local current = Config.AIStages[1]
	for _, stage in Config.AIStages do
		if level >= stage.level then
			current = stage
		end
	end
	return current
end

-- Hệ số token từ GPU nhờ level AI (chưa tính VIP/boost)
function Config.LevelMultiplier(level)
	return 1 + Config.AI.ProductionPerLevel * (level - 1)
end

function Config.ClickTokens(level)
	return Config.Click.BaseTokens + Config.Click.PerLevel * (level - 1)
end

-- Giá mở kệ số `index` (nil nếu kệ đó không mua bằng token được)
function Config.RackPrice(index)
	local r = Config.Racks
	if index <= r.FreeRacks or index > r.BuyableRacks then
		return nil
	end
	return math.floor(r.BasePrice * r.Multiplier ^ (index - r.FreeRacks - 1))
end

-- 1234567 -> "1.23M"
function Config.Short(n)
	n = math.floor(n)
	local units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, unit in units do
		if n >= unit[1] then
			local value = n / unit[1]
			if value >= 100 then
				return string.format("%d", math.floor(value)) .. unit[2]
			end
			-- "1.50" -> "1.5", "2.00" -> "2"
			local text = string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
			return text .. unit[2]
		end
	end
	return tostring(n)
end

return Config
