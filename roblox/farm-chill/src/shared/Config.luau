-- Toàn bộ số liệu cân bằng game + ID kiếm Robux nằm ở đây.
-- Muốn chỉnh giá, thời gian, thêm cây/thú thì chỉ cần sửa file này.

local Config = {}

Config.GameName = "Farm Chill"
Config.StartingCoins = 50
Config.AutosaveInterval = 120 -- giây
Config.MaxFarms = 8 -- số người tối đa/server nên đặt = số này

-- ===== Ô đất =====
Config.Plots = {
	Columns = 4,
	Rows = 3, -- hàng cuối cùng chỉ dành cho VIP
	Spacing = 9,
	FreePlots = 4, -- số ô có sẵn lúc mới chơi
	BuyablePlots = 8, -- mua thêm bằng coin tới ô thứ 8
	VipPlots = 4, -- ô 9-12 chỉ VIP
	-- Giá mở ô thứ n = BasePrice * Multiplier^(n - FreePlots - 1)
	BasePrice = 150,
	Multiplier = 2.2,
}

-- ===== Cây trồng =====
-- seedPrice: giá gieo 1 ô, sellPrice: giá bán 1 nông sản, growTime: giây
Config.Crops = {
	{ id = "Wheat", emoji = "🌾", name = "Lúa mì", seedPrice = 5, sellPrice = 10, growTime = 15, color = Color3.fromRGB(232, 200, 90) },
	{ id = "Carrot", emoji = "🥕", name = "Cà rốt", seedPrice = 20, sellPrice = 45, growTime = 40, color = Color3.fromRGB(240, 130, 40) },
	{ id = "Tomato", emoji = "🍅", name = "Cà chua", seedPrice = 60, sellPrice = 140, growTime = 90, color = Color3.fromRGB(220, 50, 50) },
	{ id = "Watermelon", emoji = "🍉", name = "Dưa hấu", seedPrice = 200, sellPrice = 480, growTime = 180, color = Color3.fromRGB(60, 170, 70) },
	{ id = "Pumpkin", emoji = "🎃", name = "Bí ngô", seedPrice = 600, sellPrice = 1500, growTime = 300, color = Color3.fromRGB(245, 150, 30) },
	{ id = "DragonFruit", emoji = "🐉", name = "Thanh long", seedPrice = 2000, sellPrice = 5200, growTime = 600, color = Color3.fromRGB(230, 40, 140) },
}

-- ===== Vật nuôi =====
-- Thú tự đẻ sản phẩm vào kho mỗi `interval` giây (khi người chơi đang online)
Config.Animals = {
	{ id = "Chicken", emoji = "🐔", name = "Gà", price = 250, product = "Egg", interval = 20, color = Color3.fromRGB(250, 250, 245) },
	{ id = "Cow", emoji = "🐄", name = "Bò", price = 1500, product = "Milk", interval = 45, color = Color3.fromRGB(90, 70, 60) },
	{ id = "Pig", emoji = "🐖", name = "Heo", price = 6000, product = "Truffle", interval = 90, color = Color3.fromRGB(255, 170, 180) },
}
Config.MaxAnimalsPerType = 6
Config.VipExtraAnimals = 2

-- Sản phẩm từ thú (nông sản từ cây dùng luôn id của cây)
Config.Products = {
	Egg = { name = "Trứng", emoji = "🥚", sellPrice = 15 },
	Milk = { name = "Sữa", emoji = "🥛", sellPrice = 70 },
	Truffle = { name = "Nấm truffle", emoji = "🍄", sellPrice = 260 },
}

-- ===== Kiếm Robux =====
-- Tạo Game Pass / Developer Product trên Creator Dashboard rồi dán ID vào đây.
-- ID = 0 nghĩa là chưa cấu hình: nút mua sẽ báo lỗi thay vì mở bảng mua.
Config.GamePasses = {
	VIP = {
		id = 0,
		name = "⭐ VIP",
		description = "x2 coin khi bán, +4 ô đất VIP, +2 chuồng mỗi loại thú, tag VIP",
	},
	FastGrow = {
		id = 0,
		name = "🌱 Cây Lớn Nhanh",
		description = "Cây lớn nhanh x1.5 vĩnh viễn (kể cả lúc offline)",
	},
}

-- kind = "Boost": bật boost trong `duration` giây (mua thêm thì cộng dồn thời gian)
-- kind = "Coins": cộng coin ngay
-- kind = "InstantGrow": tất cả cây đang trồng chín ngay
Config.DevProducts = {
	CoinBoost = { id = 0, kind = "Boost", boost = "Coins", duration = 15 * 60, name = "💰 x2 Coin (15 phút)" },
	GrowBoost = { id = 0, kind = "Boost", boost = "Growth", duration = 15 * 60, name = "⚡ x2 Tốc độ lớn (15 phút)" },
	InstantGrow = { id = 0, kind = "InstantGrow", name = "🌟 Chín ngay tất cả cây" },
	Coins1K = { id = 0, kind = "Coins", amount = 1000, name = "🪙 1.000 Coin" },
	Coins10K = { id = 0, kind = "Coins", amount = 12000, name = "🪙 12.000 Coin (+20%)" },
}

Config.Multipliers = {
	VipCoins = 2,
	CoinBoost = 2,
	FastGrowPass = 1.5,
	GrowBoost = 2,
}

-- ===== Tra cứu nhanh =====
Config.CropById = {} :: { [string]: any }
for _, crop in Config.Crops do
	Config.CropById[crop.id] = crop
end

Config.AnimalById = {} :: { [string]: any }
for _, animal in Config.Animals do
	Config.AnimalById[animal.id] = animal
end

Config.DevProductById = {} :: { [number]: string }
for key, product in Config.DevProducts do
	if product.id ~= 0 then
		Config.DevProductById[product.id] = key
	end
end

function Config.TotalPlots(): number
	return Config.Plots.Columns * Config.Plots.Rows
end

-- Giá để mở ô đất số `index` (nil nếu ô đó không mua bằng coin được)
function Config.PlotPrice(index: number): number?
	local p = Config.Plots
	if index <= p.FreePlots or index > p.BuyablePlots then
		return nil
	end
	return math.floor(p.BasePrice * p.Multiplier ^ (index - p.FreePlots - 1))
end

-- Lấy tên, giá bán, emoji của bất kỳ món nào trong kho
function Config.ItemInfo(itemId: string): (string, number, string)
	local crop = Config.CropById[itemId]
	if crop then
		return crop.name, crop.sellPrice, crop.emoji
	end
	local product = Config.Products[itemId]
	if product then
		return product.name, product.sellPrice, product.emoji
	end
	return itemId, 0, "❔"
end

return Config
