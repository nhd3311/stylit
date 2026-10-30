-- Giao diện người chơi: token, thanh XP của AI, nút gõ code, train AI, bảng GPU, shop Robux.
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
local openPanel = nil -- "AI" | "Gpu" | "Shop" | nil

local FONT = Enum.Font.BuilderSansBold
local COLORS = {
	bg = Color3.fromRGB(20, 22, 34),
	card = Color3.fromRGB(36, 40, 58),
	accent = Color3.fromRGB(80, 200, 255),
	gold = Color3.fromRGB(255, 200, 60),
	robux = Color3.fromRGB(0, 170, 110),
	purple = Color3.fromRGB(150, 90, 255),
	disabled = Color3.fromRGB(80, 80, 95),
	text = Color3.fromRGB(245, 245, 245),
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

local short = Config.Short

local function fmtTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function boostLeft(name)
	if not state then
		return 0
	end
	return math.max(0, (state.boosts[name] or 0) - workspace:GetServerTimeNow())
end

-- ================= Khung UI chính =================

local gui = new("ScreenGui", {
	Name = "TycoonUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local topBar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(340, 130),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	new("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local tokenLabel = new("TextLabel", {
	LayoutOrder = 1,
	Size = UDim2.fromOffset(260, 44),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 0.1,
	Font = FONT,
	TextSize = 26,
	TextColor3 = COLORS.gold,
	RichText = true,
	Text = "🪙 ...",
	Parent = topBar,
}, { corner(22) })

-- Thanh XP của AI
local xpBar = new("Frame", {
	LayoutOrder = 2,
	Size = UDim2.fromOffset(340, 30),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 0.1,
	ClipsDescendants = true,
	Parent = topBar,
}, { corner(15) })
local xpFill = new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = COLORS.purple,
	BorderSizePixel = 0,
	Parent = xpBar,
}, { corner(15) })
local xpLabel = new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 16,
	TextColor3 = COLORS.text,
	TextStrokeTransparency = 0.5,
	ZIndex = 2,
	Text = "🤖 AI Lv.1",
	Parent = xpBar,
})

local boostLabel = new("TextLabel", {
	LayoutOrder = 3,
	Size = UDim2.fromOffset(340, 26),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 0.25,
	Font = FONT,
	TextSize = 15,
	TextColor3 = COLORS.accent,
	Text = "",
	Visible = false,
	Parent = topBar,
}, { corner(13) })

local toastLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 140),
	Size = UDim2.fromOffset(440, 40),
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
			TweenService:Create(toastLabel, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		end
	end)
end

-- ================= Nút gõ code =================

local codeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -20, 1, -20),
	Size = UDim2.fromOffset(150, 150),
	BackgroundColor3 = COLORS.accent,
	Font = FONT,
	TextSize = 22,
	TextColor3 = COLORS.bg,
	TextWrapped = true,
	Text = "💻\nGÕ CODE",
	Parent = gui,
}, { corner(75), new("UIStroke", { Thickness = 4, Color = COLORS.text, Transparency = 0.4 }) })

-- Số "+X" bay lên mỗi lần click cho đã tay
local function popText(text)
	local pop = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -95 + math.random(-40, 40), 1, -190),
		Size = UDim2.fromOffset(120, 30),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 24,
		TextColor3 = COLORS.gold,
		TextStrokeTransparency = 0.3,
		Text = text,
		Parent = gui,
	})
	local tween = TweenService:Create(pop, TweenInfo.new(0.7), {
		Position = pop.Position - UDim2.fromOffset(0, 60),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween.Completed:Connect(function()
		pop:Destroy()
	end)
	tween:Play()
end

local lastClick = 0
codeButton.MouseButton1Click:Connect(function()
	local t = os.clock()
	if t - lastClick < Config.Click.MinInterval then
		return
	end
	lastClick = t
	remotes.Action:FireServer("Click")
	if state then
		popText("+" .. short(state.clickTokens))
	end
	codeButton.Size = UDim2.fromOffset(140, 140)
	TweenService:Create(codeButton, TweenInfo.new(0.12), { Size = UDim2.fromOffset(150, 150) }):Play()
end)

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
	Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.new(0, 470, 0.6, 0),
	BackgroundColor3 = COLORS.bg,
	Visible = false,
	Parent = gui,
}, {
	corner(16),
	new("UISizeConstraint", { MaxSize = Vector2.new(470, 520), MinSize = Vector2.new(280, 260) }),
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
	local label = new("TextLabel", {
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
		return button, label
	end
	return nil, label
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
local panelUpdate = nil -- hàm cập nhật chữ của bảng đang mở (nếu có)
local renderPanel

-- Bảng AI trả về hàm update để đổi chữ tại chỗ mỗi giây,
-- không vẽ lại cả bảng (vẽ lại sẽ làm trượt cú bấm nút Train)
function panels.AI()
	local builtLevel = state.level
	local stage = Config.StageFor(state.level)
	panelTitle.Text = string.format("%s %s • Lv.%d", stage.emoji, stage.name, state.level)

	local nextStage
	for _, s in Config.AIStages do
		if s.level > state.level then
			nextStage = s
			break
		end
	end
	local _, infoLabel = row(1, "")
	if nextStage then
		row(2, string.format("Tiến hoá tiếp theo: %s <b>%s</b> ở Lv.%d", nextStage.emoji, nextStage.name, nextStage.level))
	end

	sectionTitle(3, "Đổ token vào để train AI (1 token = 1 XP)")
	local fractions = { 0.1, 0.5, 1 }
	local trainRows = {}
	for i, fraction in fractions do
		local button, label = row(4 + i, "", "🧠 Train", COLORS.purple, function()
			remotes.Action:FireServer("Train", fraction)
		end)
		trainRows[i] = { button = button, label = label }
	end

	return function()
		if state.level ~= builtLevel then
			renderPanel()
			return
		end
		infoLabel.Text = string.format(
			"XP: <b>%s / %s</b>\nToken từ GPU: <font color='#7CFC00'>+%d%%</font> nhờ level AI",
			short(state.xp),
			short(state.xpNext),
			math.floor((Config.LevelMultiplier(state.level) - 1) * 100 + 0.5)
		)
		local trainMult = if boostLeft("Training") > 0 then Config.Multipliers.TrainBoost else 1
		local multText = if trainMult > 1 then " <font color='#7CFC00'>(x2 boost!)</font>" else ""
		for i, fraction in fractions do
			local amount = math.floor(state.tokens * fraction)
			trainRows[i].label.Text = string.format(
				"Train bằng <b>%d%%</b> token\n<font color='#aaaaaa'>+%s XP</font>%s",
				math.floor(fraction * 100 + 0.5),
				short(amount * trainMult),
				multText
			)
			trainRows[i].button.BackgroundColor3 = if amount >= 1 then COLORS.purple else COLORS.disabled
		end
	end
end

function panels.Gpu()
	panelTitle.Text = "🖥️ Các loại GPU"
	row(0, "<font color='#aaaaaa'>Đi tới kệ máy chủ trong lab, bấm <b>E</b> để lắp hoặc nâng cấp. Token từ GPU gom về <b>Máy thu token</b>.</font>")
	local levelMult = Config.LevelMultiplier(state.level)
	for i, gpu in Config.Gpus do
		local unlocked = state.level >= gpu.level
		local text = string.format(
			"%s <b>%s</b>  %s/s\n<font color='#aaaaaa'>Giá %s token • %s</font>",
			gpu.emoji,
			gpu.name,
			short(gpu.rate * levelMult),
			short(gpu.price),
			if unlocked then "✅ Đã mở khoá" else "🔒 Cần AI Lv." .. gpu.level
		)
		row(i, text)
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
	for _, key in { "VIP", "AutoCollect" } do
		local pass = Config.GamePasses[key]
		local owned = if key == "VIP" then state.vip else state.autoCollect
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
	for _, key in { "TokenBoost", "TrainBoost", "TimeWarp1H", "TimeWarp6H" } do
		local product = Config.DevProducts[key]
		local extra
		if product.kind == "Boost" then
			local left = boostLeft(product.boost)
			extra = if left > 0
				then string.format("<font color='#7CFC00'>Đang chạy: còn %s</font>", fmtTime(left))
				else "<font color='#aaaaaa'>Mua thêm sẽ cộng dồn thời gian</font>"
		else
			extra = string.format("<font color='#aaaaaa'>Nhận ngay ≈ %s token</font>", short(state.rate * product.hours * 3600))
		end
		local button = row(nextOrder(), "<b>" .. product.name .. "</b>\n" .. extra, "R$ ...", COLORS.robux, function()
			promptProduct(product)
		end)
		fillRobuxPrice(button, product.id, Enum.InfoType.Product)
	end
end

function renderPanel()
	panelUpdate = nil
	if not openPanel or not state then
		panel.Visible = false
		return
	end
	local scroll = content.CanvasPosition
	clearContent()
	panelUpdate = panels[openPanel]()
	if panelUpdate then
		panelUpdate()
	end
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

for order, entry in { { "AI", "🧠 AI" }, { "Gpu", "🖥️ GPU" }, { "Shop", "💎 Shop" } } do
	local button = new("TextButton", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(120, 46),
		BackgroundColor3 = if entry[1] == "Shop" then COLORS.robux elseif entry[1] == "AI" then COLORS.purple else COLORS.bg,
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
	tokenLabel.Text = string.format("🪙 %s <font size='16' color='#7CFC00'>+%s/s</font>", short(state.tokens), short(state.rate))

	local stage = Config.StageFor(state.level)
	local ratio = if state.xpNext > 0 then math.clamp(state.xp / state.xpNext, 0, 1) else 1
	xpFill.Size = UDim2.fromScale(ratio, 1)
	xpLabel.Text = string.format("%s %s • Lv.%d  (%d%%)", stage.emoji, stage.name, state.level, math.floor(ratio * 100))

	local parts = {}
	if state.vip then
		table.insert(parts, "⭐ VIP")
	end
	if state.autoCollect then
		table.insert(parts, "🤖 Auto")
	end
	local tokenLeft = boostLeft("Tokens")
	if tokenLeft > 0 then
		table.insert(parts, "🪙 x2 " .. fmtTime(tokenLeft))
	end
	local trainLeft = boostLeft("Training")
	if trainLeft > 0 then
		table.insert(parts, "🧠 x2 " .. fmtTime(trainLeft))
	end
	if not state.autoCollect and state.buffered >= 1 then
		table.insert(parts, "📦 Chờ thu: " .. short(state.buffered))
	end
	boostLabel.Text = table.concat(parts, "  |  ")
	boostLabel.Visible = #parts > 0
end

remotes.State.OnClientEvent:Connect(function(newState)
	state = newState
	renderHud()
	if panelUpdate then
		panelUpdate()
	end
end)

remotes.Notify.OnClientEvent:Connect(function(message, action)
	toast(message)
	if action == "OpenShop" then
		openPanel = "Shop"
		renderPanel()
	elseif action == "LevelUp" then
		xpBar.BackgroundColor3 = COLORS.gold
		TweenService:Create(xpBar, TweenInfo.new(0.8), { BackgroundColor3 = COLORS.bg }):Play()
	end
end)

-- Cập nhật đồng hồ boost mỗi giây
task.spawn(function()
	while true do
		task.wait(1)
		renderHud()
	end
end)

-- ================= Chỉ hiện nút E trong lab của mình =================

local function applyOwnership(lab)
	local mine = lab:GetAttribute("OwnerUserId") == player.UserId
	for _, inst in lab:GetDescendants() do
		if inst:IsA("ProximityPrompt") then
			inst.Enabled = mine
		end
	end
end

local labs = workspace:WaitForChild("Labs")
local function watchLab(lab)
	applyOwnership(lab)
	lab:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		applyOwnership(lab)
	end)
	lab.DescendantAdded:Connect(function(inst)
		if inst:IsA("ProximityPrompt") then
			applyOwnership(lab)
		end
	end)
end
for _, lab in labs:GetChildren() do
	watchLab(lab)
end
labs.ChildAdded:Connect(watchLab)

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
