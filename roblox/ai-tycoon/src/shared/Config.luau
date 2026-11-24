-- Toàn bộ số liệu cân bằng game + ID kiếm Robux nằm ở đây.
-- Chữ người chơi nhìn thấy (name, desc, text...) là tiếng Anh; chú thích code là tiếng Việt.
--
-- Vòng lặp: thuê nhân sự + mua bàn ghế máy tính → nghiên cứu R&D → xưởng sản xuất ⚡ compute
-- → thiết kế & phát triển model AI → ra mắt (giá + marketing) → báo chấm điểm → doanh số
-- → leo hạng AI Arena, xử lý sự kiện, nâng cấp tòa nhà, mở thị trường, mua cổ phần.

local Config = {}

Config.GameName = "AI Empire: Garage to AGI"
Config.StartingCash = 8000
Config.AutosaveInterval = 120

-- ===== Thời gian trong game =====
-- 1 tháng = 30 ngày, 1 năm = 360 ngày. Ngày 0 = 01/01/StartYear.
Config.Calendar = {
	StartYear = 2015,
	SecondsPerDay = 3, -- ở tốc độ x1
	Speeds = { 0, 1, 2, 5 }, -- ⏸ ▶ ⏩ ⏭ (x5 cần VIP hoặc Time Machine)
	FastSpeedIndex = 4,
}
Config.MonthNames = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

Config.Click = { BaseCash = 5, MinInterval = 0.07 }

-- ===== Tòa nhà (requireEarned: doanh thu lượt này phải đạt mốc) =====
Config.FloorHeight = 14
Config.Buildings = {
	{ name = "Garage", emoji = "🏚️", price = 0, requireEarned = 0, w = 30, d = 24, floors = 1, cols = 2, rows = 2 },
	{ name = "Small Office", emoji = "🏠", price = 15000, requireEarned = 25000, w = 44, d = 32, floors = 1, cols = 4, rows = 2 },
	{ name = "Big Office", emoji = "🏢", price = 120000, requireEarned = 250000, w = 56, d = 44, floors = 1, cols = 4, rows = 4 },
	{ name = "2-Floor Building", emoji = "🏬", price = 1200000, requireEarned = 2500000, w = 64, d = 50, floors = 2, cols = 5, rows = 4 },
	{ name = "3-Floor HQ", emoji = "🏙️", price = 10000000, requireEarned = 25000000, w = 64, d = 50, floors = 3, cols = 5, rows = 4 },
	{ name = "4-Floor Campus", emoji = "🌆", price = 80000000, requireEarned = 250000000, w = 72, d = 56, floors = 4, cols = 6, rows = 4 },
	{ name = "Tech Tower", emoji = "🗼", price = 600000000, requireEarned = 2500000000, w = 76, d = 60, floors = 6, cols = 6, rows = 5 },
	{ name = "Global HQ", emoji = "🌐", price = 5000000000, requireEarned = 25000000000, w = 76, d = 60, floors = 8, cols = 6, rows = 5 },
}

-- ===== Bàn ghế, máy tính (nâng cấp áp cho cả công ty; price = tiền MỖI chỗ) =====
Config.WorkstationPrice = 800
Config.Equipment = {
	desk = {
		name = "Desks",
		tiers = {
			{ name = "Wooden Desk", mult = 1, price = 0, color = Color3.fromRGB(150, 110, 70) },
			{ name = "Standing Desk", mult = 1.1, price = 400, color = Color3.fromRGB(235, 235, 235) },
			{ name = "Smart Desk", mult = 1.25, price = 3000, color = Color3.fromRGB(40, 40, 50), research = "SmartOffice" },
		},
	},
	chair = {
		name = "Chairs",
		tiers = {
			{ name = "Plastic Chair", mult = 1, price = 0, color = Color3.fromRGB(60, 120, 200) },
			{ name = "Office Chair", mult = 1.15, price = 300, color = Color3.fromRGB(30, 30, 35) },
			{ name = "Ergonomic Chair", mult = 1.3, price = 2000, color = Color3.fromRGB(200, 60, 60), research = "Ergonomics" },
		},
	},
	pc = {
		name = "Computers",
		tiers = {
			{ name = "Old PC", mult = 1, price = 0, color = Color3.fromRGB(220, 210, 180) },
			{ name = "Office PC", mult = 1.3, price = 1000 },
			{ name = "AI Workstation", mult = 1.7, price = 8000, research = "Workstation" },
			{ name = "Super Workstation", mult = 2.3, price = 60000, research = "SuperWorkstation" },
		},
	},
}

-- ===== Nhân sự =====
Config.Roles = {
	Dev = { name = "Engineer", emoji = "💻", color = Color3.fromRGB(60, 140, 255), desc = "Builds models (dev points)" },
	Research = { name = "Researcher", emoji = "🔬", color = Color3.fromRGB(170, 100, 255), desc = "Unlocks tech (R&D points)" },
	Marketing = { name = "Marketer", emoji = "📣", color = Color3.fromRGB(255, 120, 60), desc = "More hype & users" },
	Engineer = { name = "Hardware Tech", emoji = "🔧", color = Color3.fromRGB(60, 200, 120), desc = "Boosts factory output" },
}
Config.RoleOrder = { "Dev", "Research", "Marketing", "Engineer" }
Config.Founder = { name = "You (Founder)", skill = 40 }
Config.Staff = {
	CandidatesPerRole = 2,
	RefreshPrice = 500,
	SalaryBase = 300,
	SalaryPerSkill = 12,
	SalaryGrowthPerYear = 0.06,
	TrainCostPerSkill = 25,
	TrainAmount = 5,
	MaxSkill = 100,
	HeadhunterBonus = 15,
	LegendSkill = 90,
}
Config.FirstNames = { "Alex", "Sam", "Jordan", "Taylor", "Riley", "Casey", "Morgan", "Jamie", "Avery", "Quinn", "Kai", "Noah", "Mia", "Leo", "Zoe", "Liam", "Emma", "Yuki", "Minh", "Linh", "Arjun", "Priya", "Diego", "Sofia", "Omar", "Lena", "Hana", "Ivan", "Chen", "Amara" }
Config.LastNames = { "Smith", "Nguyen", "Park", "Garcia", "Kim", "Patel", "Tanaka", "Silva", "Müller", "Chen", "Lopez", "Brown", "Tran", "Sato", "Khan", "Rossi" }
-- màu da / màu quần ngẫu nhiên cho avatar nhân viên
Config.SkinTones = {
	Color3.fromRGB(255, 220, 185),
	Color3.fromRGB(234, 192, 150),
	Color3.fromRGB(198, 145, 105),
	Color3.fromRGB(141, 95, 65),
	Color3.fromRGB(92, 60, 40),
}
Config.PantsColors = { Color3.fromRGB(40, 45, 60), Color3.fromRGB(30, 30, 35), Color3.fromRGB(90, 70, 55), Color3.fromRGB(60, 80, 120) }

-- ===== Xưởng sản xuất compute =====
Config.Factory = {
	BuildPrice = 10000,
	RequireBuilding = 2,
	LinePrices = { 5000, 30000, 200000, 1500000 },
	EngineerBonus = 1 / 200,
}
Config.FactoryTiers = {
	{ name = "CPU Servers", emoji = "🧮", rate = 10, price = 0, color = Color3.fromRGB(150, 150, 160) },
	{ name = "GPU Cluster", emoji = "🎮", rate = 50, price = 12000, research = "GpuCluster", color = Color3.fromRGB(80, 200, 255) },
	{ name = "Custom TPU", emoji = "🔷", rate = 250, price = 120000, research = "CustomTpu", color = Color3.fromRGB(255, 210, 60) },
	{ name = "3nm Chips", emoji = "💠", rate = 1200, price = 1200000, research = "Chip3nm", color = Color3.fromRGB(120, 255, 160) },
	{ name = "Quantum Core", emoji = "⚛️", rate = 6000, price = 12000000, research = "Quantum", color = Color3.fromRGB(200, 80, 255) },
}

-- ===== Cây nghiên cứu (cost: điểm R&D, year: năm sớm nhất) =====
Config.Research = {
	{ id = "Text", category = "Feature", name = "Language Processing", emoji = "📝", cost = 30, year = 2015, requires = {} },
	{ id = "Translate", category = "Feature", name = "Machine Translation", emoji = "🌐", cost = 120, year = 2015, requires = { "Text" } },
	{ id = "Vision", category = "Feature", name = "Computer Vision", emoji = "👁️", cost = 250, year = 2016, requires = {} },
	{ id = "Voice", category = "Feature", name = "Speech", emoji = "🎙️", cost = 450, year = 2017, requires = { "Text" } },
	{ id = "Transformer", category = "Feature", name = "Transformer", emoji = "🔁", cost = 900, year = 2017, requires = { "Text" } },
	{ id = "ImageGen", category = "Feature", name = "Image Generation", emoji = "🎨", cost = 1600, year = 2018, requires = { "Vision", "Transformer" } },
	{ id = "Code", category = "Feature", name = "Code Generation", emoji = "⌨️", cost = 3000, year = 2019, requires = { "Transformer" } },
	{ id = "Video", category = "Feature", name = "Video Generation", emoji = "🎬", cost = 9000, year = 2021, requires = { "ImageGen" } },
	{ id = "Reasoning", category = "Feature", name = "Reasoning", emoji = "🧩", cost = 16000, year = 2022, requires = { "Code" } },
	{ id = "Multimodal", category = "Feature", name = "Multimodal", emoji = "🌈", cost = 30000, year = 2023, requires = { "Voice", "Video" } },
	{ id = "Agent", category = "Feature", name = "AI Agents", emoji = "🤖", cost = 60000, year = 2024, requires = { "Reasoning" } },
	{ id = "AGI", category = "Feature", name = "AGI", emoji = "✨", cost = 250000, year = 2027, requires = { "Multimodal", "Agent" } },
	{ id = "GpuCluster", category = "Component", name = "GPU Cluster", emoji = "🎮", cost = 300, year = 2016, requires = {} },
	{ id = "CustomTpu", category = "Component", name = "Custom TPU", emoji = "🔷", cost = 4000, year = 2019, requires = { "GpuCluster" } },
	{ id = "Chip3nm", category = "Component", name = "3nm Chips", emoji = "💠", cost = 25000, year = 2023, requires = { "CustomTpu" } },
	{ id = "Quantum", category = "Component", name = "Quantum Core", emoji = "⚛️", cost = 150000, year = 2028, requires = { "Chip3nm" } },
	{ id = "Ergonomics", category = "Office", name = "Ergonomics", emoji = "🪑", cost = 200, year = 2015, requires = {} },
	{ id = "Workstation", category = "Office", name = "AI Workstations", emoji = "🖥️", cost = 700, year = 2016, requires = {} },
	{ id = "SmartOffice", category = "Office", name = "Smart Office", emoji = "🏢", cost = 2500, year = 2018, requires = { "Ergonomics" } },
	{ id = "SuperWorkstation", category = "Office", name = "Super Workstations", emoji = "⚡", cost = 20000, year = 2022, requires = { "Workstation" } },
	{ id = "Influencer", category = "Marketing", name = "Influencer Deals", emoji = "🤳", cost = 250, year = 2016, requires = {} },
	{ id = "TvAds", category = "Marketing", name = "TV Ads", emoji = "📺", cost = 600, year = 2017, requires = {} },
	{ id = "LaunchEvent", category = "Marketing", name = "Launch Events", emoji = "🎤", cost = 2000, year = 2018, requires = { "Influencer" } },
	{ id = "GlobalCampaign", category = "Marketing", name = "Global Campaigns", emoji = "🌍", cost = 20000, year = 2022, requires = { "LaunchEvent", "TvAds" } },
}
Config.ResearchCategories = {
	{ id = "Feature", name = "🧠 Model Features" },
	{ id = "Component", name = "🏭 Factory Components" },
	{ id = "Office", name = "🪑 Office" },
	{ id = "Marketing", name = "📣 Marketing" },
}

-- ===== Model AI =====
Config.ModelTypes = {
	{ id = "Chatbot", name = "Chatbot", emoji = "💬", requires = "Text", good = { "Text", "Translate", "Transformer", "Reasoning", "Agent" }, users = 2000, brand = "Chatty" },
	{ id = "Translator", name = "Translator", emoji = "🌐", requires = "Translate", good = { "Translate", "Text", "Voice", "Transformer" }, users = 5000, brand = "Lingo" },
	{ id = "VoiceAssistant", name = "Voice Assistant", emoji = "🎙️", requires = "Voice", good = { "Voice", "Text", "Translate", "Agent" }, users = 15000, brand = "Echo" },
	{ id = "ImageAI", name = "Image AI", emoji = "🎨", requires = "ImageGen", good = { "ImageGen", "Vision", "Transformer" }, users = 40000, brand = "Pixie" },
	{ id = "CodeAI", name = "Coding AI", emoji = "⌨️", requires = "Code", good = { "Code", "Reasoning", "Text", "Agent" }, users = 100000, brand = "CodeWing" },
	{ id = "VideoAI", name = "Video AI", emoji = "🎬", requires = "Video", good = { "Video", "ImageGen", "Voice", "Multimodal" }, users = 250000, brand = "Reel" },
	{ id = "Assistant", name = "Super Assistant", emoji = "🌈", requires = "Multimodal", good = { "Multimodal", "Reasoning", "Agent", "Voice", "Vision" }, users = 800000, brand = "Nova" },
	{ id = "AGI", name = "AGI", emoji = "✨", requires = "AGI", good = { "AGI", "Agent", "Reasoning", "Multimodal" }, users = 5000000, brand = "Genesis" },
}
Config.ModelSizes = {
	{ id = "Mini", name = "Mini", devPoints = 60, compute = 0, slots = 2, quality = 0, users = 0.6, arena = 0 },
	{ id = "Standard", name = "Standard", devPoints = 250, compute = 300, slots = 3, quality = 0.5, users = 1, arena = 40 },
	{ id = "Large", name = "Large", devPoints = 1200, compute = 3000, slots = 4, quality = 1, users = 1.8, arena = 90 },
	{ id = "Ultra", name = "Ultra", devPoints = 6000, compute = 30000, slots = 6, quality = 1.5, users = 3, arena = 150 },
}
Config.PriceTiers = {
	{ id = "Free", name = "Free (ads)", perUser = 0.01, users = 2.2 },
	{ id = "Cheap", name = "Budget", perUser = 0.04, users = 1.4 },
	{ id = "Normal", name = "Standard", perUser = 0.08, users = 1 },
	{ id = "Premium", name = "Premium", perUser = 0.18, users = 0.5 },
}
Config.Campaigns = {
	{ id = "None", name = "No marketing", emoji = "🤐", price = 0, hype = 1 },
	{ id = "Social", name = "Social media", emoji = "📱", price = 500, hype = 1.3 },
	{ id = "Influencer", name = "Influencers", emoji = "🤳", price = 3000, hype = 1.6, research = "Influencer" },
	{ id = "TvAds", name = "TV ads", emoji = "📺", price = 8000, hype = 1.8, research = "TvAds" },
	{ id = "LaunchEvent", name = "Launch event", emoji = "🎤", price = 40000, hype = 2.3, research = "LaunchEvent" },
	{ id = "GlobalCampaign", name = "Global campaign", emoji = "🌍", price = 400000, hype = 3.2, research = "GlobalCampaign" },
}
Config.Reviewers = { "TechPulse", "AI Weekly", "ByteReview", "FutureLab" }
Config.ReviewComments = {
	{ 9, "Masterpiece. The whole industry is on notice 🔥" },
	{ 8, "Seriously impressive. Try it today." },
	{ 7, "Solid release with real highlights." },
	{ 5.5, "Okay, but nothing groundbreaking." },
	{ 4, "Disappointing and buggy." },
	{ 0, "A disaster. Back to the drawing board 😬" },
}
Config.Sales = {
	RampDays = 7,
	DecayDays = 70,
	MaxDays = 300,
	RepeatPenaltyDays = 180,
	MarketingBonus = 1 / 150,
	HistorySize = 30,
}

-- ===== AI Arena: model của bạn đấu với model của 6 công ty đối thủ =====
-- Điểm Arena model của bạn = điểm báo x ScorePoints + bonus kích thước + bonus tính năng hợp + bonus năm.
-- Đối thủ ra model mới mỗi ReleaseDays ngày (ngẫu nhiên ±), điểm tăng theo năm.
Config.Arena = {
	ScorePoints = 80,
	GoodFeaturePoints = 15,
	YearPoints = 12,
	ReleaseDays = { 120, 240 },
	ChampionBonus = 0.25, -- đứng #1: +25% người dùng mọi model
	PodiumBonus = 0.1, -- top 3: +10%
	StockJump = { 0.06, 0.18 }, -- đối thủ ra model mới: cổ phiếu của họ nhảy
}
-- arena: điểm khởi đầu năm 2015, growth: điểm tăng mỗi năm, brand: tên model của họ
Config.Stocks = {
	{ id = "NRS", name = "NeuroSoft", emoji = "🧠", base = 120, vol = 0.035, color = Color3.fromRGB(90, 140, 255), brand = "Synapse", arena = 380, growth = 70 },
	{ id = "SPK", name = "SiliconPeak", emoji = "🔷", base = 45, vol = 0.05, color = Color3.fromRGB(60, 200, 220), brand = "Summit", arena = 330, growth = 62 },
	{ id = "CLN", name = "CloudNine", emoji = "☁️", base = 300, vol = 0.025, color = Color3.fromRGB(220, 220, 240), brand = "Cirrus", arena = 400, growth = 66 },
	{ id = "RBF", name = "RoboFarm", emoji = "🤖", base = 18, vol = 0.07, color = Color3.fromRGB(120, 220, 90), brand = "Harvest", arena = 280, growth = 55 },
	{ id = "QLP", name = "QuantumLeap", emoji = "⚛️", base = 900, vol = 0.04, color = Color3.fromRGB(190, 90, 255), brand = "Q", arena = 350, growth = 80 },
	{ id = "DRV", name = "AutoDrive", emoji = "🚗", base = 75, vol = 0.06, color = Color3.fromRGB(255, 130, 60), brand = "Pilot", arena = 300, growth = 60 },
}
Config.Market = { Tick = 8, Fee = 0.01, History = 40, NewsChance = 0.05, Reversion = 0.04 }
Config.StockNews = {
	up = { "beats earnings", "lands a billion-dollar deal", "posts record profits", "raises a mega round" },
	down = { "gets hacked", "loses its CEO", "recalls a buggy product", "is fined for antitrust" },
}

-- ===== Hype Feed: bình luận ảo trên mạng xã hội khi ra mắt ({m} = tên model) =====
Config.FeedHandles = { "@techbro", "@ai_daily", "@pixelqueen", "@devlife", "@nerdalert", "@gadgetguru", "@cryptokid", "@momof3", "@startupsam", "@prof_ml", "@gamerzz", "@newsbot" }
Config.FeedPosts = {
	good = { "{m} just wrote my whole essay 🤯", "ok {m} is actually insane", "switching to {m} today, no regrets", "{m} > everything else. fight me", "my boss thinks I'm a genius thanks to {m}", "{m} is the future fr 🚀" },
	mid = { "{m} is fine I guess", "tried {m}, it's... decent?", "{m} has potential, needs work", "not bad {m}, not bad", "{m} hallucinated my birthday lol" },
	bad = { "{m} told me 2+2=5 💀", "uninstalling {m}", "who approved {m}??", "{m} is a scam bro", "{m} crashed 3 times in 1 minute" },
}

-- ===== Sự kiện ngẫu nhiên (game tạm dừng chờ bạn chọn) =====
-- cost: tính theo số ngày doanh thu (tối thiểu minCost). effect: modifier tạm thời / tiền / nhân viên.
-- modifier kinds: Users, Compute, Research, Dev (nhân), days: số ngày hiệu lực
Config.Events = {
	Chance = 1 / 75, -- mỗi ngày (sau ngày 30)
	List = {
		{
			id = "GpuShortage", emoji = "🔥", title = "Global GPU shortage!", text = "Chip supply collapses worldwide.",
			choices = {
				{ label = "Wait it out", effect = { modifier = "Compute", mult = 0.5, days = 60 } },
				{ label = "Pay premium suppliers", costDays = 20, minCost = 3000 },
			},
		},
		{
			id = "ViralMeme", emoji = "😂", title = "Your AI became a meme!", text = "Everyone is posting screenshots of your model.",
			choices = {
				{ label = "Ride the wave", effect = { modifier = "Users", mult = 1.5, days = 30 } },
				{ label = "Sell meme merch", effect = { cashDays = 12, minCash = 2000 } },
			},
		},
		{
			id = "DataLeak", emoji = "🕳️", title = "Security hole found!", text = "A hacker reports a bug that could leak user chats.",
			bad = true,
			choices = {
				{ label = "Pay the bug bounty", costDays = 6, minCost = 1500 },
				{ label = "Ignore it", effect = { modifier = "Users", mult = 0.7, days = 45 } },
			},
		},
		{
			id = "StarResearcher", emoji = "🌟", title = "A star researcher wants in!", text = "A famous professor offers to join your lab.",
			choices = {
				{ label = "Hire them (skill 90)", effect = { hire = "Research", skill = 90 } },
				{ label = "Not now" },
			},
		},
		{
			id = "VcOffer", emoji = "💼", title = "VC wants to invest", text = "A big fund offers cash, but expects fast growth.",
			choices = {
				{ label = "Take the money", effect = { cashDays = 40, minCash = 20000, modifier = "Users", mult = 0.9, days = 90 } },
				{ label = "Stay independent" },
			},
		},
		{
			id = "Hackathon", emoji = "🧑‍🔬", title = "Host a hackathon?", text = "Students want to hack on your models for a weekend.",
			choices = {
				{ label = "Host it", costDays = 4, minCost = 1000, effect = { modifier = "Research", mult = 1.5, days = 30 } },
				{ label = "Skip" },
			},
		},
		{
			id = "Lawsuit", emoji = "⚖️", title = "Patent lawsuit!", text = "A rival claims you copied their tech.",
			bad = true,
			choices = {
				{ label = "Settle quietly", costDays = 10, minCost = 2500 },
				{ label = "Fight in court", effect = { gamble = true, costDays = 25, minCost = 6000 } },
			},
		},
		{
			id = "Crunch", emoji = "☕", title = "Crunch time?", text = "Your team offers to work overtime before the next launch.",
			choices = {
				{ label = "Order pizza & crunch", costDays = 3, minCost = 800, effect = { modifier = "Dev", mult = 1.6, days = 20 } },
				{ label = "Protect work-life balance" },
			},
		},
	},
}

-- ===== Phòng ban (1 phòng ban cho mỗi vai trò) =====
-- Mỗi cấp +BonusPerLevel năng suất cho vai trò đó. requireBuilding: cấp tòa nhà cần để mua cấp này.
Config.Departments = {
	Dev = { name = "Engineering", emoji = "💻" },
	Research = { name = "Research Lab", emoji = "🔬" },
	Marketing = { name = "Marketing", emoji = "📣" },
	Engineer = { name = "Hardware", emoji = "🔧" },
}
Config.DepartmentLevels = {
	{ price = 0, requireBuilding = 1 },
	{ price = 20000, requireBuilding = 2 },
	{ price = 150000, requireBuilding = 3 },
	{ price = 1500000, requireBuilding = 4 },
	{ price = 15000000, requireBuilding = 6 },
}
Config.DepartmentBonusPerLevel = 0.15
function Config.DepartmentMult(level)
	return 1 + Config.DepartmentBonusPerLevel * ((level or 1) - 1)
end

-- ===== Tinh thần nhân viên =====
-- Điểm làm việc nhân thêm hệ số theo tinh thần: 50% tinh thần → x0.85, 100% → x1.2.
-- Mỗi tháng tụt MonthlyDrop; nợ lương tụt thêm; dưới QuitBelow thì nghỉ việc.
Config.Morale = {
	Start = 75,
	MonthlyDrop = 6,
	UnpaidDrop = 15,
	TrainGain = 5,
	PartyGain = 25,
	PartyBase = 1000,
	PartyPerStaff = 200,
	PartyCooldownDays = 30,
	QuitBelow = 20,
}
function Config.MoraleMult(morale)
	return 0.55 + (morale or 75) / 100 * 0.65
end

-- ===== Chuỗi mục tiêu (hướng dẫn + thưởng) =====
-- check: tên điều kiện, server kiểm tra trong GoalService. target: con số cần đạt.
Config.Goals = {
	{ text = "Research Language Processing", check = "research", target = "Text", reward = 2000 },
	{ text = "Start building your first model", check = "devStarted", reward = 2000 },
	{ text = "Launch your first AI model", check = "launches", target = 1, reward = 4000 },
	{ text = "Buy a second desk", check = "workstations", target = 2, reward = 2000 },
	{ text = "Hire your first employee", check = "staff", target = 1, reward = 3000 },
	{ text = "Throw a team party", check = "party", reward = 3000 },
	{ text = "Earn $25K in revenue", check = "earned", target = 25000, reward = 5000 },
	{ text = "Move into a Small Office", check = "building", target = 2, reward = 10000 },
	{ text = "Build your compute factory", check = "factory", reward = 10000 },
	{ text = "Launch a Standard (or bigger) model", check = "sizeLaunched", target = 2, reward = 15000 },
	{ text = "Get a 7+ review score", check = "bestScore", target = 7, reward = 20000 },
	{ text = "Expand to Southeast Asia", check = "market", target = "SEA", reward = 30000 },
	{ text = "Reach top 3 in the AI Arena", check = "arenaRank", target = 3, reward = 50000 },
	{ text = "Grow your team to 8 people", check = "staff", target = 7, reward = 60000 },
	{ text = "Move into a Big Office", check = "building", target = 3, reward = 100000 },
	{ text = "Launch a Large model", check = "sizeLaunched", target = 3, reward = 200000 },
	{ text = "Become #1 in the AI Arena", check = "arenaRank", target = 1, reward = 400000 },
	{ text = "Get a perfect 9+ review", check = "bestScore", target = 9, reward = 800000 },
	{ text = "Move into a 2-Floor Building", check = "building", target = 4, reward = 1500000 },
	{ text = "Research Multimodal AI", check = "research", target = "Multimodal", reward = 3000000 },
	{ text = "Open a 3-Floor HQ", check = "building", target = 5, reward = 8000000 },
	{ text = "Build the 4-Floor Campus", check = "building", target = 6, reward = 30000000 },
	{ text = "Launch AGI", check = "typeLaunched", target = "AGI", reward = 100000000 },
	{ text = "Raise the Tech Tower", check = "building", target = 7, reward = 500000000 },
	{ text = "Open your Global HQ", check = "building", target = 8, reward = 3000000000 },
}

-- ===== Thị trường =====
Config.Markets = {
	{ id = "Home", name = "Home Country", emoji = "🏠", price = 0, mult = 1, requireBuilding = 1 },
	{ id = "SEA", name = "Southeast Asia", emoji = "🌴", price = 50000, mult = 1.5, requireBuilding = 2 },
	{ id = "Asia", name = "Asia", emoji = "🏯", price = 600000, mult = 3, requireBuilding = 3 },
	{ id = "Europe", name = "Europe", emoji = "🏰", price = 4000000, mult = 4, requireBuilding = 4 },
	{ id = "NorthAmerica", name = "North America", emoji = "🗽", price = 15000000, mult = 6, requireBuilding = 5 },
	{ id = "Global", name = "Worldwide", emoji = "🌍", price = 80000000, mult = 10, requireBuilding = 6 },
}

-- ===== Bán công ty (Rebirth) =====
Config.Rebirth = { RequiredBuilding = 6, Divisor = 1000000, FounderBonus = 0.1, PassMultiplier = 1.5 }
Config.CompanyRanks = {
	{ sold = 0, name = "Garage Startup" },
	{ sold = 1, name = "Funded Startup" },
	{ sold = 3, name = "Unicorn 🦄" },
	{ sold = 6, name = "Big Tech" },
	{ sold = 10, name = "Tech Empire 👑" },
}

-- ===== Quà đăng nhập 7 ngày ($ = max(min, doanh thu/ngày x days)) =====
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
-- ID = 0 nghĩa là chưa cấu hình.
Config.GamePasses = {
	VIP = { id = 0, name = "⭐ VIP", description = "x1.5 revenue, x5 time speed, VIP chat tag" },
	TimeMachine = { id = 0, name = "⏭️ Time Machine", description = "Unlock x5 time speed" },
	Headhunter = { id = 0, name = "🎯 Headhunter", description = "Candidates +15 skill, +1 candidate per role" },
	GoldenOffice = { id = 0, name = "🏆 Golden Office", description = "+20% staff efficiency and golden furniture" },
	MegaFactory = { id = 0, name = "🏭 Mega Factory", description = "x2 compute production forever" },
	PRAgency = { id = 0, name = "📣 PR Agency", description = "+30% hype on every launch" },
	FounderPlus = { id = 0, name = "🏅 Founder+", description = "+50% Founder Points when you sell" },
	StarterPack = { id = 0, name = "🎁 Starter Pack", description = "One-time: $25K, 2 desks and a skilled engineer" },
}
Config.StarterPack = { cash = 25000, workstations = 2, devSkill = 65 }
Config.PassBonus = { GoldenOffice = 1.2, MegaFactory = 2, PRAgency = 1.3 }

-- kind: Boost (boosts = { tên = giây thật }) | Hype | Skip (days) | Instant (target) |
--       Funding (cashDays, minCash) | Legend (thuê nhân viên kỹ năng 90) | Shield (chặn 1 sự kiện xấu)
Config.DevProducts = {
	CashBoost = { id = 0, kind = "Boost", boosts = { Cash = 15 * 60 }, name = "💵 x2 Revenue (15 min)" },
	WorkBoost = { id = 0, kind = "Boost", boosts = { Work = 30 * 60 }, name = "⚡ x2 Staff Output (30 min)" },
	ComputeBoost = { id = 0, kind = "Boost", boosts = { Compute = 30 * 60 }, name = "🏭 x2 Compute (30 min)" },
	MegaBoost = { id = 0, kind = "Boost", boosts = { Cash = 30 * 60, Work = 30 * 60, Compute = 30 * 60 }, name = "🚀 Mega Boost: x2 everything (30 min)" },
	Viral = { id = 0, kind = "Hype", name = "🔥 Go Viral: next launch x2 hype" },
	InstantResearch = { id = 0, kind = "Instant", target = "Research", name = "⚡ Finish current research" },
	InstantDev = { id = 0, kind = "Instant", target = "Dev", name = "⚡ Finish current model" },
	SkipMonth = { id = 0, kind = "Skip", days = 30, name = "⏩ Skip 1 month" },
	SkipQuarter = { id = 0, kind = "Skip", days = 90, name = "⏩ Skip 1 quarter" },
	SeedRound = { id = 0, kind = "Funding", cashDays = 10, minCash = 10000, name = "🌱 Seed Round" },
	SeriesA = { id = 0, kind = "Funding", cashDays = 40, minCash = 50000, name = "💼 Series A" },
	SeriesB = { id = 0, kind = "Funding", cashDays = 120, minCash = 250000, name = "🏦 Series B" },
	HireLegend = { id = 0, kind = "Legend", name = "🦸 Hire a Legend (skill 90)" },
	CrisisShield = { id = 0, kind = "Shield", name = "🛡️ Crisis Shield (auto-solve next bad event)" },
}
Config.ShopTabs = {
	{ id = "Featured", name = "🔥 Hot", items = { { "pass", "StarterPack" }, { "product", "MegaBoost" }, { "pass", "VIP" }, { "product", "SeriesA" } } },
	{ id = "Passes", name = "⭐ Passes", items = { { "pass", "TimeMachine" }, { "pass", "GoldenOffice" }, { "pass", "MegaFactory" }, { "pass", "PRAgency" }, { "pass", "Headhunter" }, { "pass", "FounderPlus" } } },
	{ id = "Boosts", name = "⚡ Boosts", items = { { "product", "CashBoost" }, { "product", "WorkBoost" }, { "product", "ComputeBoost" }, { "product", "Viral" } } },
	{ id = "Funding", name = "💰 Funding", items = { { "product", "SeedRound" }, { "product", "SeriesA" }, { "product", "SeriesB" } } },
	{ id = "Time", name = "⏩ Time", items = { { "product", "InstantResearch" }, { "product", "InstantDev" }, { "product", "SkipMonth" }, { "product", "SkipQuarter" } } },
	{ id = "Team", name = "🦸 Team", items = { { "product", "HireLegend" }, { "product", "CrisisShield" } } },
}
Config.Multipliers = { Vip = 1.5, CashBoost = 2, WorkBoost = 2, ComputeBoost = 2 }

-- ===== Tra cứu nhanh =====
local function index(list)
	local map = {}
	for _, item in list do
		map[item.id] = item
	end
	return map
end
Config.ResearchById = index(Config.Research)
Config.ModelTypeById = index(Config.ModelTypes)
Config.ModelSizeById = index(Config.ModelSizes)
Config.PriceTierById = index(Config.PriceTiers)
Config.CampaignById = index(Config.Campaigns)
Config.MarketById = index(Config.Markets)
Config.StockById = index(Config.Stocks)
Config.EventById = index(Config.Events.List)
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

-- "Mar 12, 2016"
function Config.DateText(day)
	local year = Config.Calendar.StartYear + day // 360
	local month = (day % 360) // 30 + 1
	return string.format("%s %d, %d", Config.MonthNames[month], day % 30 + 1, year)
end

function Config.MonthText(day)
	return string.format("%s %d", Config.MonthNames[(day % 360) // 30 + 1], Config.Calendar.StartYear + day // 360)
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

function Config.UsersAt(peak, age)
	local s = Config.Sales
	if age < 0 or age > s.MaxDays then
		return 0
	end
	local ramp = math.min(1, (age + 1) / s.RampDays)
	local decay = math.exp(-math.max(0, age - s.RampDays) / s.DecayDays)
	return peak * ramp * decay
end

-- Điểm Arena của model người chơi
function Config.ArenaScore(score, sizeId, goodFeatures, day)
	local a = Config.Arena
	local size = Config.ModelSizeById[sizeId]
	return math.floor(score * a.ScorePoints + size.arena + goodFeatures * a.GoodFeaturePoints + (Config.YearOf(day) - Config.Calendar.StartYear) * a.YearPoints)
end

-- Điểm Arena của model đối thủ ra mắt ở ngày `day`
function Config.RivalArena(rival, day, roll)
	local years = (day / 360)
	return math.floor(rival.arena + rival.growth * years + (roll or 0))
end

function Config.DayNumber(unixTime)
	return math.floor(unixTime / 86400)
end

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
