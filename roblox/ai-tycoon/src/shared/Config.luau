-- Toàn bộ số liệu cân bằng game + ID kiếm Robux nằm ở đây.
-- Muốn chỉnh giá, tốc độ, thêm tầng/GPU/nghiên cứu/sản phẩm thì chỉ cần sửa file này.
--
-- Hai loại tiền:
--   🪙 Token (sức mạnh tính toán): GPU đào ra. Dùng train AI, nghiên cứu, phát triển sản phẩm.
--   💵 Tiền ($): gõ code dạo + sản phẩm AI đã ra mắt. Dùng xây tầng, mua GPU, mua cổ phiếu.

local Config = {}

Config.GameName = "Trùm Công Nghệ: Thung Lũng AI"
Config.StartingCash = 50
Config.AutosaveInterval = 120 -- giây
Config.MaxLots = 8 -- số người tối đa/server nên đặt = số này

-- ===== Gõ code dạo (click) =====
Config.Click = {
	BaseCash = 2, -- $ gốc mỗi lần click, nhân với mọi hệ số thu nhập (AI level, VIP, boost...)
	MinInterval = 0.07, -- chống auto-click (tối đa ~14 click/giây)
}

-- ===== Tòa nhà =====
-- Xây lần lượt từ dưới lên. kind quyết định trong tầng có gì:
--   Lobby: sảnh, máy thu token, két dữ liệu, kệ máy chủ | Server: kệ máy chủ
--   Lab: nghiên cứu + lõi AI | Studio: phát triển sản phẩm | AICenter / CEO: bonus
Config.FloorHeight = 14
Config.Floors = {
	{ id = "Lobby", name = "Sảnh & Gara", emoji = "🚪", price = 0, kind = "Lobby", racks = 4 },
	{ id = "ServerA", name = "Phòng Server A", emoji = "🖥️", price = 400, kind = "Server", racks = 4 },
	{ id = "Lab", name = "Lab R&D", emoji = "🔬", price = 2500, kind = "Lab" },
	{ id = "Studio", name = "Studio Sản Phẩm", emoji = "🚀", price = 12000, kind = "Studio" },
	{ id = "ServerB", name = "Phòng Server B", emoji = "🖥️", price = 50000, kind = "Server", racks = 4 },
	{ id = "AICenter", name = "Trung Tâm AI", emoji = "🧠", price = 200000, kind = "AICenter", desc = "Train AI hiệu quả x1.5" },
	{ id = "DataCenter", name = "Data Center", emoji = "🏭", price = 900000, kind = "Server", racks = 4 },
	{ id = "CEO", name = "Văn Phòng CEO", emoji = "👔", price = 4000000, kind = "CEO", desc = "+25% thu nhập, mở khoá Bán công ty" },
	{ id = "Penthouse", name = "Penthouse VIP", emoji = "⭐", price = 0, kind = "Server", racks = 4, vip = true },
}
Config.AICenterTrainBonus = 1.5
Config.CeoIncomeBonus = 1.25

-- ===== Kệ máy chủ =====
Config.Racks = {
	BufferSeconds = 300, -- mỗi kệ chứa tối đa 5 phút token, đầy thì ngừng đào
}

-- ===== GPU (tier tăng dần) =====
-- rate: token/giây, price: $ để lắp hoặc nâng lên tier này, level: AI level cần để mở
Config.Gpus = {
	{ id = "OldCpu", name = "CPU cũ", emoji = "🧮", rate = 1, price = 25, level = 1, color = Color3.fromRGB(150, 150, 150) },
	{ id = "GamingGpu", name = "GPU Gaming", emoji = "🎮", rate = 5, price = 250, level = 3, color = Color3.fromRGB(80, 200, 255) },
	{ id = "ProGpu", name = "GPU Pro", emoji = "💠", rate = 25, price = 3000, level = 6, color = Color3.fromRGB(120, 255, 140) },
	{ id = "TensorCore", name = "Tensor Core", emoji = "🔷", rate = 120, price = 35000, level = 10, color = Color3.fromRGB(255, 220, 60) },
	{ id = "SuperComputer", name = "Siêu máy tính", emoji = "🖥️", rate = 600, price = 400000, level = 15, color = Color3.fromRGB(255, 120, 40) },
	{ id = "QuantumChip", name = "Chip Lượng Tử", emoji = "⚛️", rate = 3000, price = 5000000, level = 22, color = Color3.fromRGB(200, 80, 255) },
}

-- ===== AI =====
Config.AI = {
	MaxLevel = 60,
	XpBase = 100, -- XP (token) để lên level 2
	XpGrowth = 1.55, -- mỗi level cần nhiều hơn x1.55
	BonusPerLevel = 0.12, -- mỗi level +12% cả $ lẫn token
}

-- Các giai đoạn tiến hoá của AI (tên + màu lõi AI ở tầng Lab)
Config.AIStages = {
	{ level = 1, name = "Bot Ngáo", emoji = "🤖", color = Color3.fromRGB(150, 150, 170), size = 4 },
	{ level = 5, name = "Trợ Lý Ảo", emoji = "💬", color = Color3.fromRGB(80, 180, 255), size = 5 },
	{ level = 10, name = "Coder AI", emoji = "💻", color = Color3.fromRGB(80, 255, 160), size = 6 },
	{ level = 18, name = "Thiên Tài Số", emoji = "🧠", color = Color3.fromRGB(255, 210, 60), size = 7 },
	{ level = 28, name = "AGI", emoji = "🌐", color = Color3.fromRGB(255, 100, 60), size = 8 },
	{ level = 40, name = "Siêu Trí Tuệ", emoji = "✨", color = Color3.fromRGB(210, 90, 255), size = 9 },
}

-- ===== Cây nghiên cứu (R&D) =====
-- cost: token, time: giây, requires: các nghiên cứu phải xong trước. Cần tầng Lab R&D.
-- effect: gpu/income/launch/research/dev = cộng % ; unlock = mở khoá sản phẩm
Config.Research = {
	{ id = "Cooling", name = "Làm mát bằng nước", emoji = "💧", cost = 150, time = 30, requires = {}, effect = { gpu = 0.2 } },
	{ id = "NeuralNet", name = "Mạng Nơ-ron", emoji = "🕸️", cost = 300, time = 45, requires = {}, effect = { unlock = "Chatbot" } },
	{ id = "Marketing", name = "Marketing", emoji = "📣", cost = 800, time = 60, requires = { "NeuralNet" }, effect = { launch = 0.25 } },
	{ id = "Parallel", name = "Tính toán song song", emoji = "⚙️", cost = 2000, time = 90, requires = { "Cooling" }, effect = { gpu = 0.3 } },
	{ id = "Transformer", name = "Transformer", emoji = "🔁", cost = 3000, time = 120, requires = { "NeuralNet" }, effect = { unlock = "Translator", income = 0.15 } },
	{ id = "Automation", name = "Tự động hoá", emoji = "🤖", cost = 8000, time = 150, requires = { "Parallel" }, effect = { research = 0.25, dev = 0.25 } },
	{ id = "Diffusion", name = "Mô hình Khuếch tán", emoji = "🎨", cost = 12000, time = 180, requires = { "Transformer" }, effect = { unlock = "ArtAI" } },
	{ id = "Sales", name = "Đội Sales", emoji = "💼", cost = 25000, time = 240, requires = { "Marketing" }, effect = { income = 0.25 } },
	{ id = "RL", name = "Học tăng cường", emoji = "🎮", cost = 60000, time = 300, requires = { "Diffusion" }, effect = { unlock = "SelfDriving" } },
	{ id = "CustomChip", name = "Chip tự thiết kế", emoji = "🔷", cost = 150000, time = 420, requires = { "Automation" }, effect = { gpu = 0.5 } },
	{ id = "Multimodal", name = "Đa phương thức", emoji = "🌈", cost = 400000, time = 600, requires = { "RL" }, effect = { unlock = "DoctorAI" } },
	{ id = "GlobalBrand", name = "Thương hiệu toàn cầu", emoji = "🌍", cost = 1000000, time = 900, requires = { "Sales", "Multimodal" }, effect = { income = 0.5, launch = 0.5 } },
	{ id = "AGI", name = "AGI", emoji = "✨", cost = 5000000, time = 1800, requires = { "Multimodal", "CustomChip" }, effect = { unlock = "AGI" } },
}

-- ===== Sản phẩm AI =====
-- devTokens: token để làm v1, devTime: giây, launchCash: $ nhận khi ra mắt v1, income: $/giây của v1.
-- Mỗi phiên bản mới: tốn token x VersionCost, thời gian x VersionTime, thu nhập x VersionIncome.
-- Cần tầng Studio Sản Phẩm, và nghiên cứu mở khoá tương ứng.
Config.Products = {
	{ id = "Chatbot", name = "Chatbot CSKH", emoji = "💬", devTokens = 500, devTime = 60, launchCash = 300, income = 3 },
	{ id = "Translator", name = "AI Dịch Thuật", emoji = "🌐", devTokens = 5000, devTime = 120, launchCash = 4000, income = 25 },
	{ id = "ArtAI", name = "AI Vẽ Tranh", emoji = "🎨", devTokens = 25000, devTime = 240, launchCash = 25000, income = 120 },
	{ id = "SelfDriving", name = "Xe Tự Lái", emoji = "🚗", devTokens = 150000, devTime = 420, launchCash = 200000, income = 700 },
	{ id = "DoctorAI", name = "AI Bác Sĩ", emoji = "🩺", devTokens = 900000, devTime = 600, launchCash = 1500000, income = 4000 },
	{ id = "AGI", name = "Siêu AI (AGI)", emoji = "✨", devTokens = 6000000, devTime = 1200, launchCash = 12000000, income = 25000 },
}
Config.ProductVersions = {
	Max = 10,
	VersionCost = 1.8,
	VersionTime = 1.25,
	VersionIncome = 1.7,
	VersionLaunch = 1.5,
}

-- ===== Sàn chứng khoán =====
-- Giá đi ngẫu nhiên quanh giá gốc, thỉnh thoảng có tin tức làm giá nhảy mạnh. Chỉ dùng $ trong game.
Config.Stocks = {
	{ id = "NRS", name = "NeuroSoft", emoji = "🧠", base = 120, vol = 0.035 },
	{ id = "CVT", name = "ChipViet", emoji = "🔷", base = 45, vol = 0.05 },
	{ id = "CLM", name = "CloudMây", emoji = "☁️", base = 300, vol = 0.025 },
	{ id = "RBF", name = "RoboFarm", emoji = "🤖", base = 18, vol = 0.07 },
	{ id = "QLP", name = "QuantumLeap", emoji = "⚛️", base = 900, vol = 0.04 },
	{ id = "DRV", name = "AutoDrive", emoji = "🚗", base = 75, vol = 0.06 },
}
Config.Market = {
	Tick = 8, -- giây giữa 2 lần cập nhật giá
	Fee = 0.01, -- phí 1% mỗi lệnh mua/bán
	History = 40, -- số điểm giá giữ lại để vẽ biểu đồ
	NewsChance = 0.05, -- xác suất có tin tức mỗi tick
	Reversion = 0.04, -- lực kéo giá về quanh giá gốc
}
Config.StockNews = {
	up = { "ra mắt sản phẩm đột phá", "ký hợp đồng tỷ đô", "lãi kỷ lục quý này", "được quỹ lớn rót vốn" },
	down = { "bị hacker tấn công", "CEO bất ngờ từ chức", "sản phẩm bị lỗi hàng loạt", "bị phạt vì độc quyền" },
}

-- ===== Bán công ty (Rebirth) =====
-- Cần xây tới Văn Phòng CEO. Reset tiền, token, tòa nhà, GPU, AI, nghiên cứu, sản phẩm, cổ phiếu.
-- Đổi lại nhận Điểm Founder: mỗi điểm +10% $ và token vĩnh viễn.
-- Điểm = sqrt($ kiếm được trong lượt này / Divisor)
Config.Rebirth = {
	RequiredFloor = 8,
	Divisor = 250000,
	FounderBonus = 0.1,
	PassMultiplier = 1.5, -- Game Pass Founder+ cho thêm 50% điểm
}

-- Danh hiệu theo số lần bán công ty (hiện trên nóc tòa nhà)
Config.CompanyRanks = {
	{ sold = 0, name = "Startup Gara" },
	{ sold = 1, name = "Startup Gọi Vốn" },
	{ sold = 3, name = "Kỳ Lân 🦄" },
	{ sold = 6, name = "Big Tech" },
	{ sold = 10, name = "Đế Chế Công Nghệ 👑" },
}

-- ===== Quà đăng nhập 7 ngày =====
-- Thưởng $ = max(min, thu nhập $ trong `minutes` phút). Ngày 7 tặng thêm boost.
Config.Daily = {
	{ minutes = 5, min = 200 },
	{ minutes = 10, min = 600 },
	{ minutes = 15, min = 1500 },
	{ minutes = 20, min = 4000 },
	{ minutes = 30, min = 10000 },
	{ minutes = 45, min = 25000 },
	{ minutes = 60, min = 60000, boosts = { Cash = 30 * 60 } },
}

-- ===== Phi vụ đánh cắp dữ liệu =====
-- Két ở sảnh mỗi tòa nhà tự sinh ổ dữ liệu ($). Người khác lẻn vào trộm, mang về Máy thu của mình.
Config.Heist = {
	DriveInterval = 45,
	MaxDrives = 5,
	DriveValueSeconds = 90, -- 1 ổ = 90 giây thu nhập $ của chủ tòa nhà
	MinDriveValue = 30,
	StealHold = 1.5,
	MasterStealHold = 0.5,
	MaxCarry = 1,
	MasterMaxCarry = 2,
	CarrySpeed = 11,
	NormalSpeed = 16,
	StealCooldown = 20,
	NewbieLevel = 3,
	TagDistance = 6,
}

Config.Leaderboard = {
	UpdateInterval = 300,
	Size = 10,
}

-- Offline: GPU + sản phẩm vẫn chạy khi thoát game, tối đa bấy nhiêu giờ
Config.OfflineHours = 2
Config.VipOfflineHours = 8

-- ===== Kiếm Robux =====
-- Tạo Game Pass / Developer Product trên Creator Dashboard rồi dán ID vào đây.
-- ID = 0 nghĩa là chưa cấu hình: nút mua sẽ báo lỗi thay vì mở bảng mua.
Config.GamePasses = {
	VIP = { id = 0, name = "⭐ VIP", description = "x2 $, Penthouse VIP 4 kệ máy, offline 8 giờ, tag VIP" },
	AutoCollect = { id = 0, name = "🤖 Auto Thu Token", description = "Token từ GPU tự vào ví, khỏi đi thu" },
	MasterThief = { id = 0, name = "🕵️ Siêu Đạo Chích", description = "Trộm nhanh gấp 3, ôm 2 ổ, chạy không bị chậm" },
	FounderPlus = { id = 0, name = "🏅 Founder+", description = "+50% Điểm Founder mỗi lần bán công ty" },
	StarterPack = { id = 0, name = "🎁 Gói Khởi Nghiệp", description = "Nhận 1 lần: 3 GPU Gaming + $5.000 + Mega Boost 30 phút" },
}

Config.StarterPack = {
	cash = 5000,
	gpu = "GamingGpu",
	gpuCount = 3,
	boosts = { Cash = 30 * 60, Tokens = 30 * 60, Research = 30 * 60 },
}

-- kind = "Boost": bật các boost trong `boosts` (tên = số giây, mua thêm thì cộng dồn)
-- kind = "TimeWarp": nhận ngay $ và token bằng `hours` giờ hoạt động
-- kind = "Instant": xong ngay nghiên cứu ("Research") hoặc sản phẩm đang làm ("Dev")
Config.DevProducts = {
	CashBoost = { id = 0, kind = "Boost", boosts = { Cash = 15 * 60 }, name = "💵 x2 Tiền (15 phút)" },
	TokenBoost = { id = 0, kind = "Boost", boosts = { Tokens = 15 * 60 }, name = "🪙 x2 Token (15 phút)" },
	ResearchBoost = { id = 0, kind = "Boost", boosts = { Research = 30 * 60 }, name = "🔬 x2 Tốc độ R&D (30 phút)" },
	MegaBoost = {
		id = 0,
		kind = "Boost",
		boosts = { Cash = 30 * 60, Tokens = 30 * 60, Research = 30 * 60 },
		name = "🚀 Mega Boost: x2 $, Token, R&D (30 phút)",
	},
	InstantResearch = { id = 0, kind = "Instant", target = "Research", name = "⚡ Xong ngay nghiên cứu đang chạy" },
	InstantDev = { id = 0, kind = "Instant", target = "Dev", name = "⚡ Ra mắt ngay sản phẩm đang làm" },
	TimeWarp1H = { id = 0, kind = "TimeWarp", hours = 1, name = "⏩ Time Warp 1 giờ" },
	TimeWarp6H = { id = 0, kind = "TimeWarp", hours = 6, name = "⏩ Time Warp 6 giờ" },
	TimeWarp24H = { id = 0, kind = "TimeWarp", hours = 24, name = "⏩ Time Warp 24 giờ" },
	Shield1H = { id = 0, kind = "Boost", boosts = { Shield = 60 * 60 }, name = "🛡️ Khiên chống trộm 1 giờ" },
	Shield8H = { id = 0, kind = "Boost", boosts = { Shield = 8 * 60 * 60 }, name = "🛡️ Khiên chống trộm 8 giờ" },
}

-- Thứ tự hiển thị trong Shop
Config.ShopSections = {
	{ title = "🔥 Gói hot", items = { { "pass", "StarterPack" }, { "product", "MegaBoost" }, { "pass", "VIP" } } },
	{ title = "⭐ Game Pass (mua 1 lần, dùng mãi)", items = { { "pass", "AutoCollect" }, { "pass", "MasterThief" }, { "pass", "FounderPlus" } } },
	{ title = "⚡ Boost (mua thêm cộng dồn thời gian)", items = { { "product", "CashBoost" }, { "product", "TokenBoost" }, { "product", "ResearchBoost" } } },
	{ title = "⏱️ Xong ngay", items = { { "product", "InstantResearch" }, { "product", "InstantDev" } } },
	{ title = "⏩ Time Warp (nhận $ + token ngay)", items = { { "product", "TimeWarp1H" }, { "product", "TimeWarp6H" }, { "product", "TimeWarp24H" } } },
	{ title = "🛡️ Khiên chống trộm", items = { { "product", "Shield1H" }, { "product", "Shield8H" } } },
}

Config.Multipliers = {
	VipCash = 2,
	CashBoost = 2,
	TokenBoost = 2,
	ResearchBoost = 2,
}

-- ===== Tra cứu nhanh =====
Config.GpuById = {}
Config.GpuTier = {}
for tier, gpu in Config.Gpus do
	Config.GpuById[gpu.id] = gpu
	Config.GpuTier[gpu.id] = tier
end

Config.ResearchById = {}
for _, node in Config.Research do
	Config.ResearchById[node.id] = node
end

Config.ProductById = {}
Config.ProductUnlockedBy = {} -- [productId] = researchId
for _, product in Config.Products do
	Config.ProductById[product.id] = product
end
for _, node in Config.Research do
	if node.effect.unlock then
		Config.ProductUnlockedBy[node.effect.unlock] = node.id
	end
end

Config.StockById = {}
for _, stock in Config.Stocks do
	Config.StockById[stock.id] = stock
end

Config.DevProductById = {}
for key, product in Config.DevProducts do
	if product.id ~= 0 then
		Config.DevProductById[product.id] = key
	end
end

-- Danh sách ô kệ máy: { floor = số tầng, slot = 1..4 }, đánh số liên tục từ tầng dưới lên
Config.RackSlots = {}
for floorIndex, floor in Config.Floors do
	for slot = 1, floor.racks or 0 do
		table.insert(Config.RackSlots, { floor = floorIndex, slot = slot })
	end
end

-- ===== Công thức =====

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

function Config.LevelMultiplier(level)
	return 1 + Config.AI.BonusPerLevel * (level - 1)
end

function Config.FounderMultiplier(points)
	return 1 + Config.Rebirth.FounderBonus * (points or 0)
end

function Config.FounderPointsFor(runEarned, hasFounderPlus)
	local points = math.sqrt(math.max(0, runEarned) / Config.Rebirth.Divisor)
	if hasFounderPlus then
		points *= Config.Rebirth.PassMultiplier
	end
	return math.floor(points)
end

function Config.CompanyRank(sold)
	local current = Config.CompanyRanks[1]
	for _, rank in Config.CompanyRanks do
		if (sold or 0) >= rank.sold then
			current = rank
		end
	end
	return current
end

-- Phiên bản `version` (1..Max) của sản phẩm: chi phí, thời gian, thu nhập, tiền ra mắt
function Config.ProductVersion(product, version)
	local v = Config.ProductVersions
	local step = version - 1
	return {
		devTokens = math.floor(product.devTokens * v.VersionCost ^ step),
		devTime = math.floor(product.devTime * v.VersionTime ^ step),
		income = product.income * v.VersionIncome ^ step,
		launchCash = math.floor(product.launchCash * v.VersionLaunch ^ step),
	}
end

-- Cộng dồn hiệu ứng của các nghiên cứu đã xong: { gpu, income, launch, research, dev }
function Config.ResearchEffects(done)
	local total = { gpu = 0, income = 0, launch = 0, research = 0, dev = 0 }
	for id in done or {} do
		local node = Config.ResearchById[id]
		if node then
			for key, value in node.effect do
				if type(value) == "number" then
					total[key] += value
				end
			end
		end
	end
	return total
end

-- Tổng $/giây gốc (chưa nhân hệ số) của các sản phẩm đã ra mắt
function Config.ProductIncome(products)
	local total = 0
	for id, version in products or {} do
		local product = Config.ProductById[id]
		if product and version > 0 then
			total += Config.ProductVersion(product, version).income
		end
	end
	return total
end

function Config.DayNumber(unixTime)
	return math.floor(unixTime / 86400)
end

-- 1234567 -> "1.23M"
function Config.Short(n)
	n = math.floor(n)
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	local units = { { 1e15, "Q" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, unit in units do
		if n >= unit[1] then
			local value = n / unit[1]
			if value >= 100 then
				return sign .. string.format("%d", math.floor(value)) .. unit[2]
			end
			-- "1.50" -> "1.5", "2.00" -> "2"
			local text = string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
			return sign .. text .. unit[2]
		end
	end
	return sign .. tostring(n)
end

function Config.Money(n)
	return "$" .. Config.Short(n)
end

return Config
