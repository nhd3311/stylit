-- Toàn bộ số liệu cân bằng game + ID kiếm Robux nằm ở đây.
-- Muốn chỉnh giá, thời gian, thêm nghiên cứu/loại model/thị trường thì chỉ cần sửa file này.
--
-- Vòng lặp: thuê nhân sự + mua bàn ghế máy tính → nghiên cứu R&D → xưởng sản xuất ⚡ compute
-- → thiết kế & phát triển model AI → ra mắt (giá + marketing) → báo chấm điểm → doanh số
-- → đủ tiền thì nâng cấp tòa nhà, thuê thêm người, mở rộng thị trường, mua cổ phần.

local Config = {}

Config.GameName = "Trùm Công Nghệ: Từ Garage Đến AGI"
Config.StartingCash = 8000
Config.AutosaveInterval = 120

-- ===== Thời gian trong game =====
-- 1 tháng = 30 ngày, 1 năm = 360 ngày cho dễ tính. Ngày 0 = 01/01/StartYear.
Config.Calendar = {
	StartYear = 2015,
	SecondsPerDay = 3, -- ở tốc độ x1
	Speeds = { 0, 1, 2, 5 }, -- ⏸ ▶ ⏩ ⏭ (x5 cần Game Pass Cỗ Máy Thời Gian hoặc VIP)
	FastSpeedIndex = 4,
}

-- ===== Gõ code dạo (click) =====
Config.Click = {
	BaseCash = 5,
	MinInterval = 0.07, -- chống auto-click
}

-- ===== Tòa nhà =====
-- requireEarned: tổng doanh thu từ trước tới nay phải đạt mốc này mới được mua cấp đó.
-- cols x rows chỗ ngồi mỗi tầng.
Config.FloorHeight = 14
Config.Buildings = {
	{ name = "Garage", emoji = "🏚️", price = 0, requireEarned = 0, w = 30, d = 24, floors = 1, cols = 2, rows = 2 },
	{ name = "Văn phòng nhỏ", emoji = "🏠", price = 15000, requireEarned = 25000, w = 44, d = 32, floors = 1, cols = 4, rows = 2 },
	{ name = "Văn phòng lớn", emoji = "🏢", price = 120000, requireEarned = 250000, w = 56, d = 44, floors = 1, cols = 4, rows = 4 },
	{ name = "Tòa nhà 2 tầng", emoji = "🏬", price = 1200000, requireEarned = 2500000, w = 56, d = 44, floors = 2, cols = 4, rows = 4 },
	{ name = "Trụ sở 3 tầng", emoji = "🏙️", price = 10000000, requireEarned = 25000000, w = 56, d = 44, floors = 3, cols = 4, rows = 4 },
	{ name = "Campus 4 tầng", emoji = "🌆", price = 80000000, requireEarned = 250000000, w = 56, d = 44, floors = 4, cols = 4, rows = 4 },
}

-- ===== Bàn ghế, máy tính =====
-- Mỗi chỗ làm việc = 1 bàn + 1 ghế + 1 PC. Nâng cấp là áp cho cả công ty.
-- mult: nhân hiệu suất làm việc; price: tiền nâng cấp MỖI chỗ; research: nghiên cứu cần trước.
Config.WorkstationPrice = 800
Config.Equipment = {
	desk = {
		name = "Bàn",
		tiers = {
			{ name = "Bàn gỗ", mult = 1, price = 0, color = Color3.fromRGB(150, 110, 70) },
			{ name = "Bàn đứng", mult = 1.1, price = 400, color = Color3.fromRGB(235, 235, 235) },
			{ name = "Bàn thông minh", mult = 1.25, price = 3000, color = Color3.fromRGB(40, 40, 50), research = "SmartOffice" },
		},
	},
	chair = {
		name = "Ghế",
		tiers = {
			{ name = "Ghế nhựa", mult = 1, price = 0, color = Color3.fromRGB(60, 120, 200) },
			{ name = "Ghế văn phòng", mult = 1.15, price = 300, color = Color3.fromRGB(30, 30, 35) },
			{ name = "Ghế công thái học", mult = 1.3, price = 2000, color = Color3.fromRGB(200, 60, 60), research = "Ergonomics" },
		},
	},
	pc = {
		name = "Máy tính",
		tiers = {
			{ name = "PC cũ", mult = 1, price = 0, color = Color3.fromRGB(220, 210, 180) },
			{ name = "PC văn phòng", mult = 1.3, price = 1000 },
			{ name = "Máy trạm AI", mult = 1.7, price = 8000, research = "Workstation" },
			{ name = "Siêu máy trạm", mult = 2.3, price = 60000, research = "SuperWorkstation" },
		},
	},
}

-- ===== Nhân sự =====
-- Điểm/ngày = kỹ năng / 10 x hiệu suất chỗ ngồi. Lương trả ngày 1 mỗi tháng.
Config.Roles = {
	Dev = { name = "Lập trình viên", emoji = "💻", color = Color3.fromRGB(60, 140, 255), desc = "Tạo điểm phát triển model" },
	Research = { name = "Nhà nghiên cứu", emoji = "🔬", color = Color3.fromRGB(170, 100, 255), desc = "Tạo điểm R&D" },
	Marketing = { name = "Marketing", emoji = "📣", color = Color3.fromRGB(255, 120, 60), desc = "Tăng độ hot khi ra mắt + doanh số" },
	Engineer = { name = "Kỹ sư", emoji = "🔧", color = Color3.fromRGB(60, 200, 120), desc = "Tăng sản lượng xưởng" },
}
Config.RoleOrder = { "Dev", "Research", "Marketing", "Engineer" }
Config.Founder = { name = "Bạn (Founder)", skill = 40 } -- làm cả lập trình lẫn nghiên cứu, không lương
Config.Staff = {
	CandidatesPerRole = 2,
	RefreshPrice = 500, -- tìm ứng viên mới ngay (không thì tự đổi đầu mỗi tháng)
	SalaryBase = 300,
	SalaryPerSkill = 12, -- lương/tháng = SalaryBase + kỹ năng x SalaryPerSkill (x hệ số theo năm)
	SalaryGrowthPerYear = 0.06,
	TrainCostPerSkill = 25, -- đào tạo +5 kỹ năng = kỹ năng hiện tại x giá này
	TrainAmount = 5,
	MaxSkill = 100,
	HeadhunterBonus = 15,
}
Config.FirstNames = { "An", "Bình", "Châu", "Dũng", "Giang", "Hà", "Hải", "Hiếu", "Hoa", "Huy", "Khánh", "Lan", "Linh", "Long", "Mai", "Minh", "Nam", "Ngọc", "Phong", "Phúc", "Quân", "Quỳnh", "Sơn", "Tâm", "Thảo", "Thắng", "Trang", "Trung", "Tú", "Vy" }
Config.LastNames = { "Nguyễn", "Trần", "Lê", "Phạm", "Hoàng", "Huỳnh", "Phan", "Vũ", "Võ", "Đặng", "Bùi", "Đỗ" }

-- ===== Xưởng sản xuất compute =====
Config.Factory = {
	BuildPrice = 10000,
	RequireBuilding = 2,
	LinePrices = { 5000, 30000, 200000, 1500000 }, -- giá mua dây chuyền thứ 1..4
	EngineerBonus = 1 / 200, -- mỗi điểm kỹ năng kỹ sư +0.5% sản lượng
}
-- price: tiền nâng 1 dây chuyền lên tier này; rate: ⚡/ngày
Config.FactoryTiers = {
	{ name = "Server CPU", emoji = "🧮", rate = 10, price = 0, color = Color3.fromRGB(150, 150, 160) },
	{ name = "Cụm GPU", emoji = "🎮", rate = 50, price = 12000, research = "GpuCluster", color = Color3.fromRGB(80, 200, 255) },
	{ name = "Chip TPU tự thiết kế", emoji = "🔷", rate = 250, price = 120000, research = "CustomTpu", color = Color3.fromRGB(255, 210, 60) },
	{ name = "Chip 3nm", emoji = "💠", rate = 1200, price = 1200000, research = "Chip3nm", color = Color3.fromRGB(120, 255, 160) },
	{ name = "Máy tính lượng tử", emoji = "⚛️", rate = 6000, price = 12000000, research = "Quantum", color = Color3.fromRGB(200, 80, 255) },
}

-- ===== Cây nghiên cứu =====
-- cost: điểm R&D, year: năm sớm nhất được nghiên cứu, requires: nghiên cứu trước đó.
-- category: Feature (tính năng model) | Component (linh kiện xưởng) | Office | Marketing
Config.Research = {
	-- Tính năng model
	{ id = "Text", category = "Feature", name = "Xử lý ngôn ngữ", emoji = "📝", cost = 30, year = 2015, requires = {} },
	{ id = "Translate", category = "Feature", name = "Dịch máy", emoji = "🌐", cost = 120, year = 2015, requires = { "Text" } },
	{ id = "Vision", category = "Feature", name = "Nhận diện ảnh", emoji = "👁️", cost = 250, year = 2016, requires = {} },
	{ id = "Voice", category = "Feature", name = "Giọng nói", emoji = "🎙️", cost = 450, year = 2017, requires = { "Text" } },
	{ id = "Transformer", category = "Feature", name = "Kiến trúc Transformer", emoji = "🔁", cost = 900, year = 2017, requires = { "Text" } },
	{ id = "ImageGen", category = "Feature", name = "Tạo ảnh", emoji = "🎨", cost = 1600, year = 2018, requires = { "Vision", "Transformer" } },
	{ id = "Code", category = "Feature", name = "Sinh code", emoji = "⌨️", cost = 3000, year = 2019, requires = { "Transformer" } },
	{ id = "Video", category = "Feature", name = "Tạo video", emoji = "🎬", cost = 9000, year = 2021, requires = { "ImageGen" } },
	{ id = "Reasoning", category = "Feature", name = "Lập luận", emoji = "🧩", cost = 16000, year = 2022, requires = { "Code" } },
	{ id = "Multimodal", category = "Feature", name = "Đa phương thức", emoji = "🌈", cost = 30000, year = 2023, requires = { "Voice", "Video" } },
	{ id = "Agent", category = "Feature", name = "Tác tử AI", emoji = "🤖", cost = 60000, year = 2024, requires = { "Reasoning" } },
	{ id = "AGI", category = "Feature", name = "AGI", emoji = "✨", cost = 250000, year = 2027, requires = { "Multimodal", "Agent" } },
	-- Linh kiện cho xưởng
	{ id = "GpuCluster", category = "Component", name = "Cụm GPU", emoji = "🎮", cost = 300, year = 2016, requires = {} },
	{ id = "CustomTpu", category = "Component", name = "Chip TPU tự thiết kế", emoji = "🔷", cost = 4000, year = 2019, requires = { "GpuCluster" } },
	{ id = "Chip3nm", category = "Component", name = "Chip 3nm", emoji = "💠", cost = 25000, year = 2023, requires = { "CustomTpu" } },
	{ id = "Quantum", category = "Component", name = "Máy tính lượng tử", emoji = "⚛️", cost = 150000, year = 2028, requires = { "Chip3nm" } },
	-- Văn phòng
	{ id = "Ergonomics", category = "Office", name = "Ghế công thái học", emoji = "🪑", cost = 200, year = 2015, requires = {} },
	{ id = "Workstation", category = "Office", name = "Máy trạm AI", emoji = "🖥️", cost = 700, year = 2016, requires = {} },
	{ id = "SmartOffice", category = "Office", name = "Văn phòng thông minh", emoji = "🏢", cost = 2500, year = 2018, requires = { "Ergonomics" } },
	{ id = "SuperWorkstation", category = "Office", name = "Siêu máy trạm", emoji = "⚡", cost = 20000, year = 2022, requires = { "Workstation" } },
	-- Marketing
	{ id = "Influencer", category = "Marketing", name = "Hợp tác KOL", emoji = "🤳", cost = 250, year = 2016, requires = {} },
	{ id = "TvAds", category = "Marketing", name = "Quảng cáo TV", emoji = "📺", cost = 600, year = 2017, requires = {} },
	{ id = "LaunchEvent", category = "Marketing", name = "Sự kiện ra mắt", emoji = "🎤", cost = 2000, year = 2018, requires = { "Influencer" } },
	{ id = "GlobalCampaign", category = "Marketing", name = "Chiến dịch toàn cầu", emoji = "🌍", cost = 20000, year = 2022, requires = { "LaunchEvent", "TvAds" } },
}
Config.ResearchCategories = {
	{ id = "Feature", name = "🧠 Tính năng model" },
	{ id = "Component", name = "🏭 Linh kiện xưởng" },
	{ id = "Office", name = "🪑 Văn phòng" },
	{ id = "Marketing", name = "📣 Marketing" },
}

-- ===== Model AI =====
-- requires: nghiên cứu cần để làm loại này; good: tính năng hợp; users: lượng người dùng gốc lúc đỉnh
Config.ModelTypes = {
	{ id = "Chatbot", name = "Chatbot", emoji = "💬", requires = "Text", good = { "Text", "Translate", "Transformer", "Reasoning", "Agent" }, users = 2000, brand = "ChatViet" },
	{ id = "Translator", name = "Dịch thuật", emoji = "🌐", requires = "Translate", good = { "Translate", "Text", "Voice", "Transformer" }, users = 5000, brand = "DịchNhanh" },
	{ id = "VoiceAssistant", name = "Trợ lý giọng nói", emoji = "🎙️", requires = "Voice", good = { "Voice", "Text", "Translate", "Agent" }, users = 15000, brand = "AloAI" },
	{ id = "ImageAI", name = "AI vẽ tranh", emoji = "🎨", requires = "ImageGen", good = { "ImageGen", "Vision", "Transformer" }, users = 40000, brand = "VẽVời" },
	{ id = "CodeAI", name = "AI lập trình", emoji = "⌨️", requires = "Code", good = { "Code", "Reasoning", "Text", "Agent" }, users = 100000, brand = "CodeMate" },
	{ id = "VideoAI", name = "AI làm video", emoji = "🎬", requires = "Video", good = { "Video", "ImageGen", "Voice", "Multimodal" }, users = 250000, brand = "PhimAI" },
	{ id = "Assistant", name = "Trợ lý đa năng", emoji = "🌈", requires = "Multimodal", good = { "Multimodal", "Reasoning", "Agent", "Voice", "Vision" }, users = 800000, brand = "Nova" },
	{ id = "AGI", name = "Siêu AI (AGI)", emoji = "✨", requires = "AGI", good = { "AGI", "Agent", "Reasoning", "Multimodal" }, users = 5000000, brand = "Genesis" },
}
-- devPoints: điểm phát triển cần, compute: ⚡ cần (thiếu thì trừ điểm), slots: số tính năng tối đa
Config.ModelSizes = {
	{ id = "Mini", name = "Mini", devPoints = 60, compute = 0, slots = 2, quality = 0, users = 0.6 },
	{ id = "Standard", name = "Vừa", devPoints = 250, compute = 300, slots = 3, quality = 0.5, users = 1 },
	{ id = "Large", name = "Lớn", devPoints = 1200, compute = 3000, slots = 4, quality = 1, users = 1.8 },
	{ id = "Ultra", name = "Siêu lớn", devPoints = 6000, compute = 30000, slots = 6, quality = 1.5, users = 3 },
}
-- Giá bán: perUser = $/người dùng/ngày, users = hệ số lượng người dùng
Config.PriceTiers = {
	{ id = "Free", name = "Miễn phí (quảng cáo)", perUser = 0.01, users = 2.2 },
	{ id = "Cheap", name = "Giá rẻ", perUser = 0.04, users = 1.4 },
	{ id = "Normal", name = "Giá vừa", perUser = 0.08, users = 1 },
	{ id = "Premium", name = "Cao cấp", perUser = 0.18, users = 0.5 },
}
-- Chiến dịch marketing khi ra mắt
Config.Campaigns = {
	{ id = "None", name = "Không quảng cáo", emoji = "🤐", price = 0, hype = 1 },
	{ id = "Social", name = "Mạng xã hội", emoji = "📱", price = 500, hype = 1.3 },
	{ id = "Influencer", name = "KOL review", emoji = "🤳", price = 3000, hype = 1.6, research = "Influencer" },
	{ id = "TvAds", name = "Quảng cáo TV", emoji = "📺", price = 8000, hype = 1.8, research = "TvAds" },
	{ id = "LaunchEvent", name = "Sự kiện ra mắt", emoji = "🎤", price = 40000, hype = 2.3, research = "LaunchEvent" },
	{ id = "GlobalCampaign", name = "Chiến dịch toàn cầu", emoji = "🌍", price = 400000, hype = 3.2, research = "GlobalCampaign" },
}
Config.Reviewers = { "TechVN", "AI Weekly", "Báo Số", "Góc Công Nghệ" }
Config.Sales = {
	RampDays = 7, -- số ngày đạt đỉnh
	DecayDays = 70, -- sau đỉnh giảm dần theo e^(-t / DecayDays)
	MaxDays = 300, -- quá ngày này thì ngừng bán
	RepeatPenaltyDays = 180, -- ra cùng loại quá dày thì bị trừ điểm
	MarketingBonus = 1 / 150, -- mỗi điểm kỹ năng marketing +0.67% người dùng
	HistorySize = 30,
}

-- ===== Thị trường =====
Config.Markets = {
	{ id = "VN", name = "Việt Nam", emoji = "🇻🇳", price = 0, mult = 1, requireBuilding = 1 },
	{ id = "SEA", name = "Đông Nam Á", emoji = "🌴", price = 50000, mult = 1.5, requireBuilding = 2 },
	{ id = "Asia", name = "Châu Á", emoji = "🏯", price = 600000, mult = 3, requireBuilding = 3 },
	{ id = "Europe", name = "Châu Âu", emoji = "🏰", price = 4000000, mult = 4, requireBuilding = 4 },
	{ id = "NorthAmerica", name = "Bắc Mỹ", emoji = "🗽", price = 15000000, mult = 6, requireBuilding = 5 },
	{ id = "Global", name = "Toàn cầu", emoji = "🌍", price = 80000000, mult = 10, requireBuilding = 6 },
}

-- ===== Cổ phần công ty công nghệ =====
-- Các công ty đối thủ, có trụ sở thật trong thành phố. Giá chỉ là $ trong game.
Config.Stocks = {
	{ id = "NRS", name = "NeuroSoft", emoji = "🧠", base = 120, vol = 0.035, color = Color3.fromRGB(90, 140, 255) },
	{ id = "CVT", name = "ChipViet", emoji = "🔷", base = 45, vol = 0.05, color = Color3.fromRGB(60, 200, 220) },
	{ id = "CLM", name = "CloudMây", emoji = "☁️", base = 300, vol = 0.025, color = Color3.fromRGB(220, 220, 240) },
	{ id = "RBF", name = "RoboFarm", emoji = "🤖", base = 18, vol = 0.07, color = Color3.fromRGB(120, 220, 90) },
	{ id = "QLP", name = "QuantumLeap", emoji = "⚛️", base = 900, vol = 0.04, color = Color3.fromRGB(190, 90, 255) },
	{ id = "DRV", name = "AutoDrive", emoji = "🚗", base = 75, vol = 0.06, color = Color3.fromRGB(255, 130, 60) },
}
Config.Market = {
	Tick = 8,
	Fee = 0.01,
	History = 40,
	NewsChance = 0.05,
	Reversion = 0.04,
}
Config.StockNews = {
	up = { "ra mắt sản phẩm đột phá", "ký hợp đồng tỷ đô", "lãi kỷ lục quý này", "được quỹ lớn rót vốn" },
	down = { "bị hacker tấn công", "CEO bất ngờ từ chức", "sản phẩm bị lỗi hàng loạt", "bị phạt vì độc quyền" },
}

-- ===== Bán công ty (Rebirth) =====
Config.Rebirth = {
	RequiredBuilding = 6,
	Divisor = 1000000,
	FounderBonus = 0.1, -- mỗi Điểm Founder +10% doanh thu, +10% điểm làm việc
	PassMultiplier = 1.5,
}
Config.CompanyRanks = {
	{ sold = 0, name = "Startup Garage" },
	{ sold = 1, name = "Startup Gọi Vốn" },
	{ sold = 3, name = "Kỳ Lân 🦄" },
	{ sold = 6, name = "Big Tech" },
	{ sold = 10, name = "Đế Chế Công Nghệ 👑" },
}

-- ===== Quà đăng nhập 7 ngày ($ = max(min, doanh thu trung bình x số ngày game)) =====
Config.Daily = {
	{ days = 3, min = 1000 },
	{ days = 5, min = 2500 },
	{ days = 7, min = 5000 },
	{ days = 10, min = 10000 },
	{ days = 14, min = 20000 },
	{ days = 20, min = 40000 },
	{ days = 30, min = 80000, boosts = { Cash = 30 * 60 } },
}

Config.Leaderboard = { UpdateInterval = 300, Size = 10 }

-- ===== Kiếm Robux =====
-- ID = 0 nghĩa là chưa cấu hình: nút mua sẽ báo lỗi thay vì mở bảng mua.
Config.GamePasses = {
	VIP = { id = 0, name = "⭐ VIP", description = "x1.5 doanh thu, mở tua x5, tag VIP" },
	TimeMachine = { id = 0, name = "⏭️ Cỗ Máy Thời Gian", description = "Mở khoá tua nhanh x5" },
	Headhunter = { id = 0, name = "🎯 Săn Đầu Người", description = "Ứng viên giỏi hơn +15 kỹ năng, thêm 1 ứng viên mỗi vai trò" },
	FounderPlus = { id = 0, name = "🏅 Founder+", description = "+50% Điểm Founder mỗi lần bán công ty" },
	StarterPack = { id = 0, name = "🎁 Gói Khởi Nghiệp", description = "Nhận 1 lần: $25.000 + 2 chỗ làm việc + 1 lập trình viên giỏi" },
}
Config.StarterPack = { cash = 25000, workstations = 2, devSkill = 65 }

-- kind = "Boost": bật boost (tên = số giây thật, cộng dồn) | "Skip": tua ngay `days` ngày
-- kind = "Instant": xong ngay R&D ("Research") hoặc model đang làm ("Dev") | "Hype": lần ra mắt tới x2 độ hot
Config.DevProducts = {
	CashBoost = { id = 0, kind = "Boost", boosts = { Cash = 15 * 60 }, name = "💵 x2 Doanh thu (15 phút)" },
	WorkBoost = { id = 0, kind = "Boost", boosts = { Work = 30 * 60 }, name = "⚡ x2 Năng suất nhân viên (30 phút)" },
	MegaBoost = { id = 0, kind = "Boost", boosts = { Cash = 30 * 60, Work = 30 * 60 }, name = "🚀 Mega Boost: x2 Doanh thu + Năng suất (30 phút)" },
	Viral = { id = 0, kind = "Hype", name = "🔥 Viral: lần ra mắt tới x2 độ hot" },
	InstantResearch = { id = 0, kind = "Instant", target = "Research", name = "⚡ Xong ngay nghiên cứu đang chạy" },
	InstantDev = { id = 0, kind = "Instant", target = "Dev", name = "⚡ Xong ngay model đang phát triển" },
	SkipMonth = { id = 0, kind = "Skip", days = 30, name = "⏩ Tua ngay 1 tháng" },
	SkipQuarter = { id = 0, kind = "Skip", days = 90, name = "⏩ Tua ngay 1 quý" },
}
Config.ShopSections = {
	{ title = "🔥 Gói hot", items = { { "pass", "StarterPack" }, { "product", "MegaBoost" }, { "pass", "VIP" } } },
	{ title = "⭐ Game Pass (mua 1 lần, dùng mãi)", items = { { "pass", "TimeMachine" }, { "pass", "Headhunter" }, { "pass", "FounderPlus" } } },
	{ title = "⚡ Boost (mua thêm cộng dồn thời gian)", items = { { "product", "CashBoost" }, { "product", "WorkBoost" }, { "product", "Viral" } } },
	{ title = "⏱️ Xong ngay", items = { { "product", "InstantResearch" }, { "product", "InstantDev" } } },
	{ title = "⏩ Tua thời gian", items = { { "product", "SkipMonth" }, { "product", "SkipQuarter" } } },
}
Config.Multipliers = { Vip = 1.5, CashBoost = 2, WorkBoost = 2 }

-- ===== Tra cứu nhanh =====
Config.ResearchById = {}
for _, node in Config.Research do
	Config.ResearchById[node.id] = node
end
Config.ModelTypeById = {}
for _, t in Config.ModelTypes do
	Config.ModelTypeById[t.id] = t
end
Config.ModelSizeById = {}
for _, s in Config.ModelSizes do
	Config.ModelSizeById[s.id] = s
end
Config.PriceTierById = {}
for _, p in Config.PriceTiers do
	Config.PriceTierById[p.id] = p
end
Config.CampaignById = {}
for _, c in Config.Campaigns do
	Config.CampaignById[c.id] = c
end
Config.MarketById = {}
for _, m in Config.Markets do
	Config.MarketById[m.id] = m
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

-- ===== Công thức =====

function Config.Capacity(level)
	local b = Config.Buildings[level]
	return b.floors * b.cols * b.rows
end

-- "12/03/2016"
function Config.DateText(day)
	local year = Config.Calendar.StartYear + day // 360
	local month = (day % 360) // 30 + 1
	return string.format("%02d/%02d/%d", day % 30 + 1, month, year)
end

function Config.YearOf(day)
	return Config.Calendar.StartYear + day // 360
end

function Config.Salary(skill, day)
	local s = Config.Staff
	local inflation = (1 + s.SalaryGrowthPerYear) ^ (Config.YearOf(day) - Config.Calendar.StartYear)
	return math.floor((s.SalaryBase + skill * s.SalaryPerSkill) * inflation)
end

function Config.EquipmentMult(equip)
	local e = Config.Equipment
	return e.desk.tiers[equip.desk].mult * e.chair.tiers[equip.chair].mult * e.pc.tiers[equip.pc].mult
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

function Config.MarketMultiplier(markets)
	local total = 0
	for id in markets or {} do
		local m = Config.MarketById[id]
		if m then
			total += m.mult
		end
	end
	return math.max(1, total)
end

-- Số người dùng của model ở ngày thứ `age` kể từ ra mắt (tăng tới đỉnh rồi giảm dần)
function Config.UsersAt(peak, age)
	local s = Config.Sales
	if age < 0 or age > s.MaxDays then
		return 0
	end
	local ramp = math.min(1, (age + 1) / s.RampDays)
	local decay = math.exp(-math.max(0, age - s.RampDays) / s.DecayDays)
	return peak * ramp * decay
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
			local text = string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
			return sign .. text .. unit[2]
		end
	end
	return sign .. tostring(n)
end

function Config.Money(n)
	if n < 0 then
		return "-$" .. Config.Short(-n)
	end
	return "$" .. Config.Short(n)
end

return Config
