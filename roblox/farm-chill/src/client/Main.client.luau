-- Giao diện người chơi: coin, chọn hạt giống, kho đồ, mua thú, shop Robux.
-- Toàn bộ UI dựng bằng code nên không cần kéo thả gì trong Studio.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local state = nil -- snapshot mới nhất từ server
local openPanel = nil -- "Inventory" | "Animals" | "Shop" | nil

local FONT = Enum.Font.BuilderSansBold
local COLORS = {
	bg = Color3.fromRGB(30, 34, 44),
	card = Color3.fromRGB(45, 50, 64),
	accent = Color3.fromRGB(110, 200, 90),
	gold = Color3.fromRGB(255, 200, 60),
	robux = Color3.fromRGB(0, 170, 110),
	text = Color3.fromRGB(245, 245, 245),
	muted = Color3.fromRGB(170, 175, 190),
}

-- ================= Tiện ích =================

local function new(className, props, children)
	local inst = Instance.new(className)
	for key, value in props or {} do
		inst[key] = value
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	return inst
end

local function corner(radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

local function fmt(n)
	local s = tostring(math.floor(n))
	local result = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	return (result:gsub("^%.", ""))
end

local function fmtTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function boostLeft(name)
	if not state then
		return 0
	end
	return math.max(0, (state.boosts[name] or 0) - serverNow())
end

local function coinMult()
	if not state then
		return 1
	end
	local m = 1
	if state.vip then
		m *= Config.Multipliers.VipCoins
	end
	if boostLeft("Coins") > 0 then
		m *= Config.Multipliers.CoinBoost
	end
	return m
end

local function growMult()
	if not state then
		return 1
	end
	local m = 1
	if state.fastGrow then
		m *= Config.Multipliers.FastGrowPass
	end
	if boostLeft("Growth") > 0 then
		m *= Config.Multipliers.GrowBoost
	end
	return m
end

-- ================= Khung UI chính =================

local gui = new("ScreenGui", {
	Name = "FarmUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local topBar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(320, 80),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	new("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local coinLabel = new("TextLabel", {
	LayoutOrder = 1,
	Size = UDim2.fromOffset(220, 44),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 0.15,
	Font = FONT,
	TextSize = 26,
	TextColor3 = COLORS.gold,
	Text = "🪙 ...",
	Parent = topBar,
}, { corner(22) })

local boostLabel = new("TextLabel", {
	LayoutOrder = 2,
	Size = UDim2.fromOffset(320, 28),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 0.25,
	Font = FONT,
	TextSize = 16,
	TextColor3 = COLORS.accent,
	Text = "",
	Visible = false,
	Parent = topBar,
}, { corner(14) })

local toastLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 100),
	Size = UDim2.fromOffset(420, 40),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 18,
	TextColor3 = COLORS.text,
	TextTransparency = 1,
	TextWrapped = true,
	Text = "",
	Parent = gui,
}, { corner(12) })

local toastVersion = 0
local function toast(message)
	toastVersion += 1
	local version = toastVersion
	toastLabel.Text = message
	toastLabel.TextTransparency = 0
	toastLabel.BackgroundTransparency = 0.1
	task.delay(2.5, function()
		if version == toastVersion then
			local info = TweenInfo.new(0.4)
			TweenService:Create(toastLabel, info, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		end
	end)
end

-- ================= Thanh chọn hạt giống =================

local seedBar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.fromOffset(#Config.Crops * 88, 84),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local seedButtons = {}
for order, crop in Config.Crops do
	local stroke = new("UIStroke", { Thickness = 3, Color = COLORS.accent, Enabled = false })
	local button = new("TextButton", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(82, 84),
		BackgroundColor3 = COLORS.bg,
		BackgroundTransparency = 0.1,
		AutoButtonColor = true,
		Font = FONT,
		TextSize = 14,
		TextColor3 = COLORS.text,
		Text = string.format("%s\n%s\n%s🪙", crop.emoji, crop.name, fmt(crop.seedPrice)),
		Parent = seedBar,
	}, { corner(12), stroke })
	button.MouseButton1Click:Connect(function()
		remotes.Action:FireServer("SelectSeed", crop.id)
	end)
	seedButtons[crop.id] = stroke
end

-- ================= Menu bên trái =================

local menu = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.5, 0),
	Size = UDim2.fromOffset(120, 3 * 54),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

-- ================= Bảng (panel) giữa màn hình =================

local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0, 460, 0.6, 0),
	BackgroundColor3 = COLORS.bg,
	Visible = false,
	Parent = gui,
}, {
	corner(16),
	new("UISizeConstraint", { MaxSize = Vector2.new(460, 520), MinSize = Vector2.new(280, 260) }),
})

local panelTitle = new("TextLabel", {
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.new(1, -70, 0, 36),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 24,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = COLORS.text,
	Parent = panel,
})

local closeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = Color3.fromRGB(200, 70, 70),
	Font = FONT,
	TextSize = 20,
	TextColor3 = COLORS.text,
	Text = "✕",
	Parent = panel,
}, { corner(18) })

local content = new("ScrollingFrame", {
	Position = UDim2.fromOffset(12, 56),
	Size = UDim2.new(1, -24, 1, -68),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = panel,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local function clearContent()
	for _, child in content:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function sectionTitle(order, text)
	new("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.gold,
		Text = text,
		Parent = content,
	})
end

-- Một dòng: chữ bên trái + nút bên phải (nút có thể không có)
local function row(order, text, buttonText, buttonColor, onClick)
	local frame = new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 60),
		BackgroundColor3 = COLORS.card,
		Parent = content,
	}, { corner(10) })
	new("TextLabel", {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, if buttonText then -140 else -24, 1, 0),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 15,
		TextWrapped = true,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.text,
		Text = text,
		Parent = frame,
	})
	if buttonText then
		local button = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(118, 40),
			BackgroundColor3 = buttonColor or COLORS.accent,
			AutoButtonColor = onClick ~= nil,
			Font = FONT,
			TextSize = 15,
			TextColor3 = COLORS.text,
			Text = buttonText,
			Parent = frame,
		}, { corner(10) })
		if onClick then
			button.MouseButton1Click:Connect(onClick)
		end
		return button
	end
	return nil
end

-- ================= Giá Robux (lấy từ Roblox, có cache) =================

local priceCache = {}
local function fillRobuxPrice(button, id, infoType)
	if id == 0 then
		button.Text = "Chưa có ID"
		return
	end
	local cacheKey = tostring(infoType) .. id
	if priceCache[cacheKey] then
		button.Text = "R$ " .. priceCache[cacheKey]
		return
	end
	button.Text = "R$ ..."
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
		if ok and info and info.PriceInRobux then
			priceCache[cacheKey] = info.PriceInRobux
			if button.Parent then
				button.Text = "R$ " .. info.PriceInRobux
			end
		end
	end)
end

local function promptPass(pass)
	if pass.id == 0 then
		toast("Chưa điền ID Game Pass trong Config.luau 🛠️")
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.id)
end

local function promptProduct(product)
	if product.id == 0 then
		toast("Chưa điền ID Developer Product trong Config.luau 🛠️")
		return
	end
	MarketplaceService:PromptProductPurchase(player, product.id)
end

-- ================= Nội dung từng bảng =================

local panels = {}

function panels.Inventory()
	panelTitle.Text = "🎒 Kho đồ"
	local items = {}
	local total = 0
	for itemId, count in state.inventory do
		if count > 0 then
			local name, price, emoji = Config.ItemInfo(itemId)
			total += price * count
			table.insert(items, { name = name, price = price, emoji = emoji, count = count })
		end
	end
	table.sort(items, function(a, b)
		return a.price * a.count > b.price * b.count
	end)

	local mult = coinMult()
	local earn = math.floor(total * mult)
	local multText = if mult > 1 then string.format(" <font color='#7CFC00'>(x%g)</font>", mult) else ""
	row(0, string.format("Tổng giá trị: <b>%s🪙</b>%s", fmt(earn), multText), "💰 Bán hết", COLORS.gold, function()
		remotes.Action:FireServer("SellAll")
	end)

	if #items == 0 then
		row(1, "<font color='#aaaaaa'>Kho trống. Ra ruộng thu hoạch hoặc nuôi thú nha!</font>")
	end
	for i, item in items do
		row(i + 1, string.format("%s %s  <b>x%d</b>\n<font color='#aaaaaa'>%s🪙 / cái</font>", item.emoji, item.name, item.count, fmt(item.price)))
	end
end

function panels.Animals()
	panelTitle.Text = "🐾 Mua thú nuôi"
	for i, animal in Config.Animals do
		local owned = state.animals[animal.id] or 0
		local product = Config.Products[animal.product]
		local text = string.format(
			"%s <b>%s</b>  %d/%d\n<font color='#aaaaaa'>Cho %s %s mỗi %ds (%s🪙)</font>",
			animal.emoji,
			animal.name,
			owned,
			state.maxAnimals,
			product.emoji,
			product.name,
			animal.interval,
			fmt(product.sellPrice)
		)
		local full = owned >= state.maxAnimals
		local canAfford = state.coins >= animal.price
		row(
			i,
			text,
			if full then "Đầy chuồng" else fmt(animal.price) .. "🪙",
			if full or not canAfford then Color3.fromRGB(90, 90, 100) else COLORS.accent,
			function()
				remotes.Action:FireServer("BuyAnimal", animal.id)
			end
		)
	end
	if not state.vip then
		row(#Config.Animals + 1, "<font color='#FFD700'>⭐ VIP được thêm 2 chỗ mỗi chuồng!</font>")
	end
end

function panels.Shop()
	panelTitle.Text = "💎 Shop VIP & Boost"
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	sectionTitle(nextOrder(), "Game Pass (mua 1 lần, dùng mãi)")
	for _, key in { "VIP", "FastGrow" } do
		local pass = Config.GamePasses[key]
		local owned = if key == "VIP" then state.vip else state.fastGrow
		local text = string.format("<b>%s</b>\n<font color='#aaaaaa'>%s</font>", pass.name, pass.description)
		if owned then
			row(nextOrder(), text, "✅ Đã có", Color3.fromRGB(70, 110, 80))
		else
			local button = row(nextOrder(), text, "R$ ...", COLORS.robux, function()
				promptPass(pass)
			end)
			fillRobuxPrice(button, pass.id, Enum.InfoType.GamePass)
		end
	end

	sectionTitle(nextOrder(), "Vật phẩm (mua bao nhiêu lần cũng được)")
	for _, key in { "CoinBoost", "GrowBoost", "InstantGrow", "Coins1K", "Coins10K" } do
		local product = Config.DevProducts[key]
		local extra = ""
		if product.kind == "Boost" then
			local left = boostLeft(product.boost)
			extra = if left > 0
				then string.format("\n<font color='#7CFC00'>Đang chạy: còn %s</font>", fmtTime(left))
				else "\n<font color='#aaaaaa'>Mua thêm sẽ cộng dồn thời gian</font>"
		end
		local button = row(nextOrder(), "<b>" .. product.name .. "</b>" .. extra, "R$ ...", COLORS.robux, function()
			promptProduct(product)
		end)
		fillRobuxPrice(button, product.id, Enum.InfoType.Product)
	end
end

local function renderPanel()
	if not openPanel or not state then
		panel.Visible = false
		return
	end
	local scroll = content.CanvasPosition
	clearContent()
	panels[openPanel]()
	panel.Visible = true
	content.CanvasPosition = scroll
end

local function togglePanel(name)
	openPanel = if openPanel == name then nil else name
	renderPanel()
end

closeButton.MouseButton1Click:Connect(function()
	openPanel = nil
	renderPanel()
end)

for order, entry in { { "Inventory", "🎒 Kho" }, { "Animals", "🐾 Thú" }, { "Shop", "💎 Shop" } } do
	local button = new("TextButton", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(120, 46),
		BackgroundColor3 = if entry[1] == "Shop" then COLORS.robux else COLORS.bg,
		BackgroundTransparency = 0.1,
		Font = FONT,
		TextSize = 20,
		TextColor3 = COLORS.text,
		Text = entry[2],
		Parent = menu,
	}, { corner(12) })
	button.MouseButton1Click:Connect(function()
		togglePanel(entry[1])
	end)
end

-- ================= Nhận dữ liệu từ server =================

local function renderHud()
	if not state then
		return
	end
	coinLabel.Text = "🪙 " .. fmt(state.coins)
	for cropId, stroke in seedButtons do
		stroke.Enabled = cropId == state.selectedSeed
	end

	local parts = {}
	if state.vip then
		table.insert(parts, "⭐ VIP")
	end
	local coinLeft = boostLeft("Coins")
	if coinLeft > 0 then
		table.insert(parts, "💰 x2 Coin " .. fmtTime(coinLeft))
	end
	local growLeft = boostLeft("Growth")
	if growLeft > 0 then
		table.insert(parts, "⚡ x2 Lớn " .. fmtTime(growLeft))
	end
	boostLabel.Text = table.concat(parts, "  |  ")
	boostLabel.Visible = #parts > 0
end

remotes.State.OnClientEvent:Connect(function(newState)
	state = newState
	renderHud()
	-- Kho & chuồng đổi liên tục nên vẽ lại; Shop thì thôi để khỏi giật nút giá
	if openPanel == "Inventory" or openPanel == "Animals" then
		renderPanel()
	end
end)

remotes.Notify.OnClientEvent:Connect(function(message, action)
	toast(message)
	if action == "OpenShop" then
		openPanel = "Shop"
		renderPanel()
	end
end)

-- Cập nhật đồng hồ boost mỗi giây
task.spawn(function()
	while true do
		task.wait(1)
		renderHud()
	end
end)

-- ================= Chỉ hiện nút E trên farm của mình =================

local function applyOwnership(farm)
	local mine = farm:GetAttribute("OwnerUserId") == player.UserId
	for _, inst in farm:GetDescendants() do
		if inst:IsA("ProximityPrompt") then
			inst.Enabled = mine
		end
	end
end

local farms = workspace:WaitForChild("Farms")
local function watchFarm(farm)
	applyOwnership(farm)
	farm:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		applyOwnership(farm)
	end)
	farm.DescendantAdded:Connect(function(inst)
		if inst:IsA("ProximityPrompt") then
			applyOwnership(farm)
		end
	end)
end
for _, farm in farms:GetChildren() do
	watchFarm(farm)
end
farms.ChildAdded:Connect(watchFarm)

-- ================= Tag [VIP] trong chat =================

pcall(function()
	TextChatService.OnIncomingMessage = function(message)
		local source = message.TextSource
		local sender = source and Players:GetPlayerByUserId(source.UserId)
		if sender and sender:GetAttribute("VIP") then
			local props = Instance.new("TextChatMessageProperties")
			props.PrefixText = "<font color='#FFD700'>[⭐VIP]</font> " .. message.PrefixText
			return props
		end
		return nil
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")
