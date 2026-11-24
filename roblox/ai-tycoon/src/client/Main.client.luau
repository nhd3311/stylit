-- Giao diện người chơi (tiếng Anh): thẻ chỉ số + lịch + nút tua, mục tiêu, các bảng
-- Company, Staff, R&D, Factory, Model Lab, Arena, Markets, Stocks, Daily, Sell, Shop,
-- popup báo chí chấm điểm + Hype Feed, popup sự kiện có lựa chọn.
-- Toàn bộ UI dựng bằng code, tự co giãn theo màn hình.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Fx = require(script.Parent:WaitForChild("Fx"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local state = nil
local market = { prices = {}, changes = {}, history = {} }
local openPanel = nil
local shopTab = "Featured"

-- lựa chọn đang soạn trong Model Lab
local design = { step = 1, type = nil, size = "Mini", features = {} }
local launchChoice = { price = "Normal", campaign = "Social" }

local FONT = Enum.Font.BuilderSansBold
local FONT_BLACK = Enum.Font.BuilderSansExtraBold
local FONT_LIGHT = Enum.Font.BuilderSans
local COLORS = {
	bg = Color3.fromRGB(11, 13, 24),
	card = Color3.fromRGB(24, 28, 46),
	cardHi = Color3.fromRGB(34, 40, 66),
	cyan = Color3.fromRGB(0, 210, 255),
	purple = Color3.fromRGB(150, 90, 255),
	pink = Color3.fromRGB(255, 70, 170),
	gold = Color3.fromRGB(255, 200, 60),
	green = Color3.fromRGB(50, 210, 120),
	red = Color3.fromRGB(240, 70, 80),
	robux = Color3.fromRGB(0, 175, 110),
	blue = Color3.fromRGB(70, 120, 255),
	orange = Color3.fromRGB(255, 150, 50),
	done = Color3.fromRGB(45, 100, 75),
	selected = Color3.fromRGB(0, 150, 210),
	disabled = Color3.fromRGB(60, 64, 84),
	text = Color3.fromRGB(240, 244, 255),
	muted = Color3.fromRGB(150, 158, 190),
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
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

local function stroke(color, thickness, transparency)
	return new("UIStroke", { Color = color or COLORS.cyan, Thickness = thickness or 1.5, Transparency = transparency or 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function gradient(a, b, rotation)
	return new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rotation or 0 })
end

local short = Config.Short
local money = Config.Money

local function fmtTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function pct(x)
	return math.floor(x * 100 + 0.5)
end

local function boostLeft(name)
	return if state then math.max(0, (state.boosts[name] or 0) - workspace:GetServerTimeNow()) else 0
end

local function fire(action, ...)
	remotes.Action:FireServer(action, ...)
end

local function done(id)
	return state.researchDone[id] == true
end

local function year()
	return Config.YearOf(state.day)
end

-- ================= Khung UI chính =================

local gui = new("ScreenGui", { Name = "EmpireUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets })
local uiScale = new("UIScale", { Parent = gui })
local function updateScale()
	local camera = workspace.CurrentCamera
	if camera then
		local size = camera.ViewportSize
		uiScale.Scale = math.clamp(math.min(size.X / 1200, size.Y / 700), 0.6, 1.1)
	end
end
updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = COLORS.gold, BackgroundTransparency = 1, ZIndex = 50, Active = false, Parent = gui })
local function flashScreen(color)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.65
	TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
end

-- ---------- Thanh trên: thẻ chỉ số ----------
local topBar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 6),
	Size = UDim2.fromOffset(900, 150),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local statRow = new("Frame", { LayoutOrder = 1, Size = UDim2.fromOffset(900, 58), BackgroundTransparency = 1, Parent = topBar }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})

-- thẻ có nhãn nhỏ phía trên, giá trị to phía dưới
local function statCard(order, width, caption, accent)
	local card = new("Frame", { LayoutOrder = order, Size = UDim2.fromOffset(width, 58), BackgroundColor3 = COLORS.bg, BackgroundTransparency = 0.08, Parent = statRow }, {
		corner(14),
		stroke(accent, 1.5, 0.55),
	})
	new("Frame", { Size = UDim2.new(0, 4, 1, -16), Position = UDim2.fromOffset(6, 8), BackgroundColor3 = accent, BorderSizePixel = 0, Parent = card }, { corner(2) })
	new("TextLabel", { Position = UDim2.fromOffset(16, 6), Size = UDim2.new(1, -20, 0, 14), BackgroundTransparency = 1, Font = FONT, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COLORS.muted, Text = caption, Parent = card })
	local value = new("TextLabel", { Position = UDim2.fromOffset(16, 22), Size = UDim2.new(1, -20, 0, 30), BackgroundTransparency = 1, Font = FONT_BLACK, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, RichText = true, TextColor3 = COLORS.text, Text = "...", Parent = card })
	return value, card
end

local dateValue, dateCard = statCard(1, 230, "AI EMPIRE", COLORS.cyan)
dateValue.Size = UDim2.new(0, 120, 0, 30)
local speedButtons = {}
for index, icon in { "⏸", "▶", "⏩", "⏭" } do
	local button = new("TextButton", {
		Position = UDim2.new(0, 112 + (index - 1) * 28, 0, 18),
		Size = UDim2.fromOffset(26, 30),
		BackgroundColor3 = COLORS.card,
		Font = FONT_BLACK,
		TextSize = 14,
		TextColor3 = COLORS.text,
		Text = icon,
		Parent = dateCard,
	}, { corner(8) })
	button.MouseButton1Click:Connect(function()
		fire("SetSpeed", index)
	end)
	speedButtons[index] = button
end
local cashValue = statCard(2, 190, "CASH", COLORS.green)
local computeValue = statCard(3, 150, "COMPUTE", COLORS.gold)
local teamValue = statCard(4, 140, "TEAM • MORALE", COLORS.blue)
local arenaValue = statCard(5, 120, "AI ARENA", COLORS.pink)

-- dải mục tiêu
local goalBar = new("Frame", { LayoutOrder = 2, Size = UDim2.fromOffset(560, 34), BackgroundColor3 = COLORS.bg, BackgroundTransparency = 0.12, ClipsDescendants = true, Parent = topBar }, { corner(17), stroke(COLORS.gold, 1.5, 0.6) })
local goalFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = COLORS.gold, BackgroundTransparency = 0.75, BorderSizePixel = 0, Parent = goalBar })
local goalLabel = new("TextLabel", { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Font = FONT, TextSize = 15, RichText = true, TextColor3 = COLORS.text, ZIndex = 2, Parent = goalBar })

local workLabel = new("TextLabel", { LayoutOrder = 3, Size = UDim2.fromOffset(560, 26), BackgroundColor3 = COLORS.bg, BackgroundTransparency = 0.3, Font = FONT, TextSize = 14, RichText = true, TextColor3 = COLORS.cyan, Visible = false, Parent = topBar }, { corner(13) })

local toastLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 165),
	Size = UDim2.fromOffset(560, 50),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 17,
	TextColor3 = COLORS.text,
	TextTransparency = 1,
	TextWrapped = true,
	ZIndex = 40,
	Parent = gui,
}, { corner(14) })
local toastVersion = 0
local function toast(message, seconds)
	toastVersion += 1
	local version = toastVersion
	toastLabel.Text = message
	toastLabel.TextTransparency = 0
	toastLabel.BackgroundTransparency = 0.08
	task.delay(seconds or 3.5, function()
		if version == toastVersion then
			TweenService:Create(toastLabel, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		end
	end)
end

-- ---------- Nút code dạo ----------
local codeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -20, 0.68, 0),
	Size = UDim2.fromOffset(112, 112),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Font = FONT_BLACK,
	TextSize = 17,
	TextColor3 = COLORS.text,
	TextStrokeTransparency = 0.5,
	TextWrapped = true,
	Text = "💻\nFREELANCE",
	Parent = gui,
}, { corner(56), gradient(COLORS.green, COLORS.cyan, 45), stroke(COLORS.text, 3, 0.5) })

local function popText(text, color, origin)
	local pop = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = origin or UDim2.new(1, -76 + math.random(-40, 40), 0.68, -86),
		Size = UDim2.fromOffset(160, 34),
		BackgroundTransparency = 1,
		Font = FONT_BLACK,
		TextSize = 24,
		TextColor3 = color or COLORS.green,
		TextStrokeTransparency = 0.3,
		Text = text,
		ZIndex = 30,
		Parent = gui,
	})
	local tween = TweenService:Create(pop, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = pop.Position - UDim2.fromOffset(0, 70), TextTransparency = 1, TextStrokeTransparency = 1 })
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
	fire("Click")
	if state then
		popText("+" .. money(state.clickCash))
	end
	codeButton.Size = UDim2.fromOffset(102, 102)
	TweenService:Create(codeButton, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(112, 112) }):Play()
end)

-- ---------- Menu ----------
local LEFT_MENU = {
	{ id = "Company", text = "🏢 Company", color = COLORS.gold },
	{ id = "Staff", text = "👥 Staff", color = COLORS.blue },
	{ id = "Research", text = "🔬 R&D", color = COLORS.purple },
	{ id = "Factory", text = "🏭 Factory", color = COLORS.orange },
	{ id = "Model", text = "🧠 Model Lab", color = COLORS.pink },
	{ id = "Arena", text = "🏆 Arena", color = COLORS.cardHi },
	{ id = "Markets", text = "🌏 Markets", color = COLORS.cardHi },
}
local RIGHT_MENU = {
	{ id = "Stocks", text = "📈 Stocks", color = COLORS.green },
	{ id = "Daily", text = "🎁 Daily", color = COLORS.pink },
	{ id = "Sell", text = "💼 Sell", color = COLORS.cardHi },
	{ id = "Shop", text = "💎 Shop", color = COLORS.robux },
}
local function menuColumn(anchor, position, count)
	return new("Frame", { AnchorPoint = anchor, Position = position, Size = UDim2.fromOffset(140, count * 50), BackgroundTransparency = 1, Parent = gui }, {
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
end
local leftMenu = menuColumn(Vector2.new(0, 0.5), UDim2.new(0, 12, 0.55, 0), #LEFT_MENU)
local rightMenu = menuColumn(Vector2.new(1, 0), UDim2.new(1, -12, 0, 170), #RIGHT_MENU)
local badges = {}

-- ---------- Bảng giữa màn hình ----------
local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.58),
	Size = UDim2.new(0, 620, 0.72, 0),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 0.03,
	Visible = false,
	ZIndex = 10,
	Parent = gui,
}, { corner(20), stroke(COLORS.cyan, 1.5, 0.45), new("UISizeConstraint", { MaxSize = Vector2.new(620, 660), MinSize = Vector2.new(300, 280) }) })
local panelTitle = new("TextLabel", { Position = UDim2.fromOffset(20, 10), Size = UDim2.new(1, -90, 0, 30), BackgroundTransparency = 1, Font = FONT_BLACK, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COLORS.text, ZIndex = 11, Parent = panel })
local panelSubtitle = new("TextLabel", { Position = UDim2.fromOffset(20, 40), Size = UDim2.new(1, -90, 0, 18), BackgroundTransparency = 1, Font = FONT_LIGHT, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COLORS.muted, ZIndex = 11, Parent = panel })
local closeButton = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = COLORS.cardHi, Font = FONT_BLACK, TextSize = 20, TextColor3 = COLORS.text, Text = "✕", ZIndex = 11, Parent = panel }, { corner(20) })
local content = new("ScrollingFrame", {
	Position = UDim2.fromOffset(14, 68),
	Size = UDim2.new(1, -28, 1, -80),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = COLORS.cyan,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ZIndex = 11,
	Parent = panel,
}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

local function clearContent()
	for _, child in content:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local orderCounter = 0
local function nextOrder()
	orderCounter += 1
	return orderCounter
end

local function sectionTitle(text)
	new("TextLabel", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Font = FONT_BLACK, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COLORS.gold, Text = text, ZIndex = 12, Parent = content })
end

-- Một dòng: chữ bên trái + 0..2 nút bên phải. buttons = { { text, color, onClick }, ... }
local function row(text, buttons, height)
	local frame = new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, -8, 0, height or 68), BackgroundColor3 = COLORS.card, ZIndex = 12, Parent = content }, { corner(12) })
	buttons = buttons or {}
	local buttonWidth = if #buttons >= 2 then 104 else 140
	local label = new("TextLabel", {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -28 - #buttons * (buttonWidth + 8), 1, 0),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 15,
		TextWrapped = true,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.text,
		Text = text,
		ZIndex = 13,
		Parent = frame,
	})
	local made = {}
	for i, spec in buttons do
		local button = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12 - (#buttons - i) * (buttonWidth + 8), 0.5, 0),
			Size = UDim2.fromOffset(buttonWidth, 44),
			BackgroundColor3 = spec[2] or COLORS.cyan,
			AutoButtonColor = spec[3] ~= nil,
			Font = FONT_BLACK,
			TextSize = 14,
			TextColor3 = COLORS.text,
			TextWrapped = true,
			Text = spec[1],
			ZIndex = 13,
			Parent = frame,
		}, { corner(10) })
		if spec[3] then
			button.MouseButton1Click:Connect(spec[3])
		end
		made[i] = button
	end
	return label, made[1], made[2], frame
end

local function info(text, height)
	return (row("<font color='#969EBE'>" .. text .. "</font>", nil, height or 52))
end

-- Lưới nút chọn
local function chips(items, cellWidth, cellHeight)
	local frame = new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 12, Parent = content }, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(cellWidth or 182, cellHeight or 54), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, item in items do
		local button = new("TextButton", {
			LayoutOrder = i,
			BackgroundColor3 = item.color or COLORS.card,
			AutoButtonColor = item.onClick ~= nil,
			Font = FONT,
			TextSize = 13,
			TextWrapped = true,
			RichText = true,
			TextColor3 = COLORS.text,
			Text = item.text,
			ZIndex = 13,
			Parent = frame,
		}, { corner(10), if item.selected then stroke(COLORS.cyan, 2.5, 0) else stroke(COLORS.text, 1, 0.9) })
		if item.onClick then
			button.MouseButton1Click:Connect(item.onClick)
		end
	end
end

-- thanh tiến độ nhỏ trong 1 dòng
local function bar(frame, ratio, color)
	local track = new("Frame", { Name = "ProgressTrack", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -6), Size = UDim2.new(0.5, 0, 0, 5), BackgroundColor3 = COLORS.cardHi, BorderSizePixel = 0, ZIndex = 13, Parent = frame }, { corner(3) })
	new("Frame", { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 14, Parent = track }, { corner(3) })
end

-- ================= Giá Robux =================

local priceCache = {}
local function fillRobuxPrice(button, id, infoType)
	if id == 0 then
		button.Text = "Set ID"
		return
	end
	local cacheKey = tostring(infoType) .. id
	if priceCache[cacheKey] then
		button.Text = "R$ " .. priceCache[cacheKey]
		return
	end
	button.Text = "R$ ..."
	task.spawn(function()
		local ok, result = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
		if ok and result and result.PriceInRobux then
			priceCache[cacheKey] = result.PriceInRobux
			if button.Parent then
				button.Text = "R$ " .. result.PriceInRobux
			end
		end
	end)
end

-- ================= Các bảng =================

local panels = {}
local panelUpdate = nil
local renderPanel

local function openOther(name)
	return function()
		openPanel = name
		renderPanel()
	end
end

local function researchSig()
	local count = 0
	for _ in state.researchDone do
		count += 1
	end
	return tostring(state.research.current) .. "|" .. count .. "|" .. year()
end

function panels.Company()
	local b = Config.Buildings[state.building]
	panelTitle.Text = string.format("%s %s", b.emoji, b.name)
	panelSubtitle.Text = "Grow from a garage into a global HQ"
	local sig = string.format("%d|%d|%d%d%d", state.building, state.workstations, state.equip.desk, state.equip.chair, state.equip.pc)

	sectionTitle("🏢 HEADQUARTERS")
	local nextB = Config.Buildings[state.building + 1]
	local upgradeLabel, upgradeButton, _, upgradeFrame
	if nextB then
		upgradeLabel, upgradeButton, _, upgradeFrame = row("", { { "Move " .. money(nextB.price), COLORS.gold, function()
			fire("UpgradeBuilding")
		end } }, 82)
	else
		row("🌐 You own the biggest HQ in the valley!")
	end
	-- lộ trình các cấp tòa nhà
	local path = {}
	for i, building in Config.Buildings do
		table.insert(path, (if i == state.building then "<b><font color='#00D2FF'>" .. building.emoji .. "</font></b>" elseif i < state.building then building.emoji else "<font transparency='0.6'>" .. building.emoji .. "</font>"))
	end
	info("Path: " .. table.concat(path, " → "), 40)

	sectionTitle(string.format("🪑 DESKS (%d/%d)", state.workstations, state.capacity))
	local e = Config.Equipment
	local seatPrice = Config.WorkstationPrice + e.desk.tiers[state.equip.desk].price + e.chair.tiers[state.equip.chair].price + e.pc.tiers[state.equip.pc].price
	if state.workstations < state.capacity then
		row("Add a desk + chair + computer\n<font color='#969EBE'>Every employee needs one. Desk 1 is yours.</font>", { { "Buy " .. money(seatPrice), COLORS.green, function()
			fire("BuyWorkstation")
		end } })
	else
		info("No room for more desks. Move into a bigger building!")
	end

	sectionTitle(string.format("⚙️ EQUIPMENT (efficiency x%.2f)", state.equipMult))
	for _, kind in { "desk", "chair", "pc" } do
		local group = e[kind]
		local current = group.tiers[state.equip[kind]]
		local nextTier = group.tiers[state.equip[kind] + 1]
		local text = string.format("<b>%s:</b> %s (x%.2f)", group.name, current.name, current.mult)
		if not nextTier then
			row(text .. "\n<font color='#7CFF9A'>Top tier</font>", { { "🔥 Max", COLORS.done } })
		elseif nextTier.research and not done(nextTier.research) then
			row(text .. string.format("\n<font color='#969EBE'>Next: %s (x%.2f)</font>", nextTier.name, nextTier.mult), { { "🔬 " .. Config.ResearchById[nextTier.research].name, COLORS.disabled, openOther("Research") } })
		else
			row(text .. string.format("\n<font color='#969EBE'>Next: %s (x%.2f) • %s × %d desks</font>", nextTier.name, nextTier.mult, money(nextTier.price), state.workstations), { { "Upgrade " .. money(nextTier.price * state.workstations), COLORS.blue, function()
				fire("UpgradeEquipment", kind)
			end } })
		end
	end

	if b.floors > 1 then
		sectionTitle("🛗 ELEVATOR")
		local items = { { text = "🏠 Front yard", color = COLORS.cyan, onClick = function()
			fire("Home")
			openPanel = nil
			renderPanel()
		end } }
		for floor = 1, b.floors do
			table.insert(items, { text = "Floor " .. floor, color = COLORS.blue, onClick = function()
				fire("GoFloor", floor)
				openPanel = nil
				renderPanel()
			end })
		end
		chips(items, 120, 44)
	end

	return function()
		if string.format("%d|%d|%d%d%d", state.building, state.workstations, state.equip.desk, state.equip.chair, state.equip.pc) ~= sig then
			renderPanel()
			return
		end
		if upgradeLabel and nextB then
			local ready = state.runEarned >= nextB.requireEarned
			upgradeLabel.Text = string.format(
				"Next: <b>%s %s</b> • %d desks, %d floors\n%s",
				nextB.emoji,
				nextB.name,
				Config.Capacity(state.building + 1),
				nextB.floors,
				if ready then "<font color='#7CFF9A'>✅ Revenue goal reached</font>" else string.format("<font color='#FF9A9A'>Revenue %s / %s</font>", money(state.runEarned), money(nextB.requireEarned))
			)
			upgradeButton.BackgroundColor3 = if ready and state.cash >= nextB.price then COLORS.gold else COLORS.disabled
			local old = upgradeFrame:FindFirstChild("ProgressTrack")
			if old then
				old:Destroy()
			end
			bar(upgradeFrame, state.runEarned / nextB.requireEarned, COLORS.gold)
		end
	end
end

local function moraleColor(m)
	return if m >= 70 then COLORS.green elseif m >= 40 then COLORS.gold else COLORS.red
end

function panels.Staff()
	panelTitle.Text = "👥 Staff & Departments"
	panelSubtitle.Text = "Hire, train and keep your team happy"
	local function signature()
		local sig = #state.staff .. "|" .. #state.candidates .. "|" .. state.workstations .. "|" .. state.partyIn
		for _, s in state.staff do
			sig ..= s.id .. ":" .. s.skill .. ":" .. math.floor(s.morale / 5) .. ","
		end
		for role, level in state.departments do
			sig ..= role .. level
		end
		return sig
	end
	local sig = signature()
	local free = state.workstations - 1 - #state.staff
	local p = state.points
	row(string.format(
		"💸 Wages <b>%s</b>/mo • 🪑 Free desks <b>%d</b>\n💻 %s dev/day • 🔬 %s R&D/day • 😊 Morale <b>%d%%</b>",
		money(state.payroll),
		free,
		short(p.Dev),
		short(p.Research),
		math.floor(state.morale)
	), { { if state.partyIn > 0 then string.format("🎉 in %dd", state.partyIn) else "🎉 Party " .. money(state.partyPrice), if state.partyIn > 0 then COLORS.disabled else COLORS.pink, function()
		fire("Party")
	end } }, 64)

	sectionTitle("🧩 DEPARTMENTS")
	for _, role in Config.RoleOrder do
		local dept = Config.Departments[role]
		local level = state.departments[role] or 1
		local nextSpec = Config.DepartmentLevels[level + 1]
		local text = string.format("%s <b>%s</b> Lv.%d • +%d%% %s output", dept.emoji, dept.name, level, pct(Config.DepartmentMult(level) - 1), Config.Roles[role].name)
		if not nextSpec then
			row(text, { { "🔥 Max", COLORS.done } }, 54)
		elseif state.building < nextSpec.requireBuilding then
			row(text .. "\n<font color='#969EBE'>Next level needs a " .. Config.Buildings[nextSpec.requireBuilding].name .. "</font>", { { "🔒 " .. money(nextSpec.price), COLORS.disabled } }, 60)
		else
			row(text, { { "Expand " .. money(nextSpec.price), Config.Roles[role].color, function()
				fire("UpgradeDepartment", role)
			end } }, 54)
		end
	end

	sectionTitle(string.format("👔 YOUR TEAM (%d)", #state.staff + 1))
	row(string.format("👑 <b>%s</b> • skill %d\n<font color='#969EBE'>Builds models and researches</font>", Config.Founder.name, Config.Founder.skill), nil, 56)
	for _, s in state.staff do
		local role = Config.Roles[s.role]
		local _, _, _, frame = row(string.format("%s <b>%s</b> • %s\n<font color='#969EBE'>Skill <b>%d</b> • %s/mo • morale %d%%</font>", role.emoji, s.name, role.name, s.skill, money(s.salary), math.floor(s.morale)), {
			{ if s.skill >= Config.Staff.MaxSkill then "Max" else "📚 " .. money(s.skill * Config.Staff.TrainCostPerSkill), COLORS.blue, function()
				fire("Train", s.id)
			end },
			{ "Fire", COLORS.red, function()
				fire("Fire", s.id)
			end },
		}, 70)
		bar(frame, s.morale / 100, moraleColor(s.morale))
	end

	sectionTitle("📋 CANDIDATES (new ones every month)")
	if free <= 0 then
		row("<font color='#FF9A9A'>No free desk! Buy another workstation to hire.</font>", { { "🪑 Buy desk", COLORS.gold, openOther("Company") } })
	end
	for i, c in state.candidates do
		local role = Config.Roles[c.role]
		row(string.format("%s <b>%s</b> • %s\n<font color='#969EBE'>Skill <b>%d</b> • %s/mo • %s</font>", role.emoji, c.name, role.name, c.skill, money(c.salary), role.desc), {
			{ "Hire", if free > 0 then COLORS.green else COLORS.disabled, function()
				fire("Hire", i)
			end },
		}, 70)
	end
	row("Not impressed? Find new candidates now", { { "🔄 " .. money(Config.Staff.RefreshPrice), COLORS.cyan, function()
		fire("RefreshCandidates")
	end } }, 56)

	return function()
		if signature() ~= sig then
			renderPanel()
		end
	end
end

function panels.Research()
	panelTitle.Text = "🔬 Research Lab"
	panelSubtitle.Text = "New tech appears year by year — " .. year()
	local sig = researchSig()
	local currentLabel, _, _, currentFrame = row("", nil, 64)
	for _, category in Config.ResearchCategories do
		sectionTitle(string.upper(category.name))
		for _, node in Config.Research do
			if node.category ~= category.id then
				continue
			end
			local missing = {}
			for _, req in node.requires do
				if not done(req) then
					table.insert(missing, Config.ResearchById[req].name)
				end
			end
			local perDay = math.max(state.research.perDay, 0.01)
			local text = string.format("%s <b>%s</b>\n<font color='#969EBE'>%s RP (~%d days) • invented %d</font>", node.emoji, node.name, short(node.cost), math.ceil(node.cost / perDay), node.year)
			if done(node.id) then
				row(text, { { "✅ Done", COLORS.done } }, 60)
			elseif state.research.current == node.id then
				row(text, { { "⏳ Working", COLORS.purple } }, 60)
			elseif year() < node.year then
				row(text, { { "📅 " .. node.year, COLORS.disabled } }, 60)
			elseif #missing > 0 then
				row(text .. "\n<font color='#FF9A9A'>Needs: " .. table.concat(missing, ", ") .. "</font>", { { "🔒", COLORS.disabled } }, 80)
			else
				row(text, { { "Research", if state.research.current then COLORS.disabled else COLORS.purple, function()
					fire("StartResearch", node.id)
				end } }, 60)
			end
		end
	end
	return function()
		if researchSig() ~= sig then
			renderPanel()
			return
		end
		local r = state.research
		local old = currentFrame:FindFirstChild("ProgressTrack")
		if old then
			old:Destroy()
		end
		if r.current then
			local node = Config.ResearchById[r.current]
			currentLabel.Text = string.format("⏳ Researching <b>%s %s</b>: %d%% (~%d days)\n🔬 %s RP/day", node.emoji, node.name, pct(r.progress), r.eta, short(r.perDay))
			bar(currentFrame, r.progress, COLORS.purple)
		else
			currentLabel.Text = string.format("<font color='#969EBE'>The lab is idle. Pick something below.</font>\n🔬 %s RP/day (hire researchers to go faster)", short(r.perDay))
		end
	end
end

function panels.Factory()
	panelTitle.Text = "🏭 Compute Factory"
	panelSubtitle.Text = "Bigger models need more ⚡ compute"
	local f = state.factory
	local sig = tostring(f.built) .. "|" .. table.concat(f.lines, ",") .. "|" .. researchSig()
	local summary
	if not f.built then
		local need = Config.Buildings[Config.Factory.RequireBuilding]
		info("The factory produces ⚡ compute for Standard/Large/Ultra models. Short on compute = lower review scores.", 56)
		row(string.format("🏗️ <b>Build the factory</b> on the lot next door\n<font color='#969EBE'>Needs a %s %s</font>", need.emoji, need.name), { { "Build " .. money(Config.Factory.BuildPrice), if state.building >= Config.Factory.RequireBuilding then COLORS.orange else COLORS.disabled, function()
			fire("BuildFactory")
		end } })
	else
		summary = row("", nil, 56)
		sectionTitle("⚙️ PRODUCTION LINES")
		for i, tier in f.lines do
			local t = Config.FactoryTiers[tier]
			local nextT = Config.FactoryTiers[tier + 1]
			local text = string.format("%s <b>Line %d: %s</b>\n<font color='#969EBE'>%s ⚡/day</font>", t.emoji, i, t.name, short(t.rate))
			if not nextT then
				row(text, { { "🔥 Max", COLORS.done } })
			elseif nextT.research and not done(nextT.research) then
				row(text, { { "🔬 " .. Config.ResearchById[nextT.research].name, COLORS.disabled, openOther("Research") } })
			else
				row(text .. string.format("\n<font color='#969EBE'>→ %s %s: %s ⚡/day</font>", nextT.emoji, nextT.name, short(nextT.rate)), { { "Upgrade " .. money(nextT.price), COLORS.orange, function()
					fire("UpgradeLine", i)
				end } }, 80)
			end
		end
		local linePrice = Config.Factory.LinePrices[#f.lines + 1]
		if linePrice then
			row("➕ Add a new production line (starts as CPU Servers)", { { "Buy " .. money(linePrice), COLORS.green, function()
				fire("BuyLine")
			end } })
		end
		info("🔧 Hire Hardware Techs to boost the whole factory (+0.5% per skill point).", 46)
	end
	return function()
		local ff = state.factory
		if tostring(ff.built) .. "|" .. table.concat(ff.lines, ",") .. "|" .. researchSig() ~= sig then
			renderPanel()
			return
		end
		if summary then
			summary.Text = string.format("⚡ Stored: <b>%s</b>\nProducing <b>%s ⚡/day</b>", short(ff.compute), short(ff.perDay))
		end
	end
end

-- ---------- Model Lab (wizard từng bước) ----------

local function modelSig()
	local m = state.model
	return (if m.dev then "dev" .. m.dev.name else "") .. (if m.pending then "pend" .. m.pending.name else "") .. "|" .. researchSig() .. "|" .. #m.history .. "|" .. design.step
end

local function stepper()
	local items = {}
	for i, name in { "Type", "Size", "Features", "Review" } do
		table.insert(items, {
			text = string.format("<b>%d</b> %s", i, name),
			color = if design.step == i then COLORS.selected elseif design.step > i then COLORS.done else COLORS.card,
			selected = design.step == i,
			onClick = if i < design.step or (i == 2 and design.type) or (i >= 3 and design.type) then function()
				design.step = i
				renderPanel()
			end else nil,
		})
	end
	chips(items, 134, 40)
end

local function previewCard()
	local modelType = design.type and Config.ModelTypeById[design.type]
	local size = Config.ModelSizeById[design.size]
	if not modelType then
		return
	end
	local good = 0
	local icons = {}
	for _, id in design.features do
		table.insert(icons, Config.ResearchById[id].emoji)
		if table.find(modelType.good, id) then
			good += 1
		end
	end
	local devPerDay = math.max(state.model.devPerDay, 0.01)
	local arenaGuess = Config.ArenaScore(7, size.id, good, state.day)
	local computeWarn = if size.compute > state.factory.compute then string.format("  <font color='#FF9A9A'>⚠️ only %s/%s ⚡</font>", short(state.factory.compute), short(size.compute)) else ""
	row(string.format(
		"%s <b>%s %s</b> • %s %s\n<font color='#969EBE'>~%d days • %s⚡%s • fit %d/%d ⭐ • Arena ~%d if reviews are 7/10</font>",
		modelType.emoji,
		modelType.brand,
		size.name,
		table.concat(icons, " "),
		if #icons == 0 then "(no features yet)" else "",
		math.ceil(size.devPoints / devPerDay),
		short(size.compute),
		computeWarn,
		good,
		#design.features,
		arenaGuess
	), nil, 64)
end

local function designView()
	stepper()
	previewCard()
	if design.step == 1 then
		sectionTitle("WHAT ARE YOU BUILDING?")
		local items = {}
		for _, t in Config.ModelTypes do
			local unlocked = done(t.requires)
			table.insert(items, {
				text = if unlocked then string.format("%s <b>%s</b>\n%s users base", t.emoji, t.name, short(t.users)) else "🔒 " .. t.name .. "\n" .. Config.ResearchById[t.requires].name,
				color = if design.type == t.id then COLORS.selected elseif unlocked then COLORS.card else COLORS.disabled,
				selected = design.type == t.id,
				onClick = if unlocked then function()
					design.type = t.id
					design.features = {}
					design.step = 2
					renderPanel()
				end else nil,
			})
		end
		chips(items)
		if not done("Text") then
			info("Research 📝 Language Processing in the 🔬 R&D lab to unlock your first model type.", 46)
		end
	elseif design.step == 2 then
		sectionTitle("HOW BIG?")
		local items = {}
		for _, s in Config.ModelSizes do
			table.insert(items, {
				text = string.format("<b>%s</b>\n%s dev • %s⚡ • %d features", s.name, short(s.devPoints), short(s.compute), s.slots),
				color = if design.size == s.id then COLORS.selected else COLORS.card,
				selected = design.size == s.id,
				onClick = function()
					design.size = s.id
					while #design.features > s.slots do
						table.remove(design.features)
					end
					design.step = 3
					renderPanel()
				end,
			})
		end
		chips(items)
	elseif design.step == 3 then
		local modelType = Config.ModelTypeById[design.type]
		local size = Config.ModelSizeById[design.size]
		sectionTitle(string.format("PICK FEATURES (%d/%d) • ⭐ = fits a %s", #design.features, size.slots, modelType.name))
		local items = {}
		for _, node in Config.Research do
			if node.category == "Feature" and done(node.id) then
				local picked = table.find(design.features, node.id) ~= nil
				local good = table.find(modelType.good, node.id) ~= nil
				table.insert(items, {
					text = string.format("%s %s%s", node.emoji, node.name, if good then " ⭐" else ""),
					color = if picked then COLORS.selected else COLORS.card,
					selected = picked,
					onClick = function()
						local at = table.find(design.features, node.id)
						if at then
							table.remove(design.features, at)
						elseif #design.features < size.slots then
							table.insert(design.features, node.id)
						else
							toast("This size fits up to " .. size.slots .. " features")
						end
						renderPanel()
					end,
				})
			end
		end
		chips(items)
		row("Happy with the features?", { { "Next →", if #design.features > 0 then COLORS.blue else COLORS.disabled, function()
			if #design.features > 0 then
				design.step = 4
				renderPanel()
			end
		end } }, 56)
	else
		sectionTitle("READY TO BUILD")
		info("Your engineers will work on it every day. Hire more Engineers to finish sooner. Fitting features (⭐), fresh tech, skilled engineers and enough compute all raise the review score.", 70)
		row("Start development", { { "🚀 Build it", if #design.features > 0 then COLORS.pink else COLORS.disabled, function()
			fire("StartModel", design.type, design.size, design.features)
			design.features = {}
			design.step = 1
		end } }, 56)
	end
end

local function launchView()
	local pending = state.model.pending
	local modelType = Config.ModelTypeById[pending.type]
	info(string.format("🎉 <b>%s %s</b> is finished! Choose a price and a campaign, then launch.", modelType.emoji, pending.name), 50)
	local priceTier = Config.PriceTierById[launchChoice.price]
	-- ước tính người dùng lúc đỉnh nếu báo chấm 7/10
	local function estimate(campaign, price)
		return state.model.launchBase * 0.49 * campaign.hype * state.model.hypeBase * price.users * (if state.model.viral > 0 then 2 else 1)
	end
	sectionTitle("1. PRICE")
	local items = {}
	for _, p in Config.PriceTiers do
		table.insert(items, {
			text = string.format("<b>%s</b>\n$%.2f per user/day • x%.1f users", p.name, p.perUser, p.users),
			color = if launchChoice.price == p.id then COLORS.selected else COLORS.card,
			selected = launchChoice.price == p.id,
			onClick = function()
				launchChoice.price = p.id
				renderPanel()
			end,
		})
	end
	chips(items, 272, 50)
	sectionTitle("2. MARKETING CAMPAIGN")
	items = {}
	for _, c in Config.Campaigns do
		local unlocked = not c.research or done(c.research)
		table.insert(items, {
			text = string.format("%s <b>%s</b>\n%s • ~%s users", c.emoji, if unlocked then c.name else "🔒 " .. c.name, if c.price > 0 then money(c.price) else "Free", short(estimate(c, priceTier))),
			color = if launchChoice.campaign == c.id then COLORS.selected elseif unlocked then COLORS.card else COLORS.disabled,
			selected = launchChoice.campaign == c.id,
			onClick = if unlocked then function()
				launchChoice.campaign = c.id
				renderPanel()
			end else nil,
		})
	end
	chips(items)
	local campaign = Config.CampaignById[launchChoice.campaign]
	local revenueGuess = estimate(campaign, priceTier) * priceTier.perUser * state.cashMult
	row(string.format(
		"<b>Launch cost: %s</b> • you have %s\n<font color='#969EBE'>Peak ~%s users/day, ~%s/day revenue (if reviews are 7/10)%s</font>",
		money(campaign.price),
		money(state.cash),
		short(estimate(campaign, priceTier)),
		money(revenueGuess),
		if state.model.viral > 0 then " • 🔥 Viral x2" else ""
	), { { "🚀 LAUNCH!", COLORS.pink, function()
		fire("Launch", launchChoice.price, launchChoice.campaign)
	end } }, 72)
end

function panels.Model()
	panelTitle.Text = "🧠 Model Lab"
	panelSubtitle.Text = "Design, build and launch AI models"
	local sig = modelSig()
	local m = state.model
	local devLabel, devFrame
	if m.dev then
		local modelType = Config.ModelTypeById[m.dev.type]
		local icons = {}
		for _, id in m.dev.features do
			table.insert(icons, Config.ResearchById[id].emoji)
		end
		devLabel, _, _, devFrame = row("", nil, 66)
		info(string.format("Building %s <b>%s</b> (%s) with %s. More Engineers = faster!", modelType.emoji, m.dev.name, Config.ModelSizeById[m.dev.size].name, table.concat(icons, " ")), 46)
	elseif m.pending then
		launchView()
	else
		designView()
	end
	if #m.history > 0 then
		sectionTitle("📊 LAUNCHED MODELS")
		for _, model in m.history do
			local modelType = Config.ModelTypeById[model.type]
			row(string.format(
				"%s <b>%s</b> • ⭐ <b>%.1f</b> • 🏆 %d %s\n<font color='#969EBE'>%s users • %s total • %s</font>",
				modelType.emoji,
				model.name,
				model.score,
				model.arena or 0,
				if model.active then "<font color='#7CFF9A'>● on sale</font>" else "<font color='#6E7491'>● retired</font>",
				short(model.users),
				money(model.revenue),
				Config.DateText(model.launchDay)
			), nil, 58)
		end
	end
	return function()
		if modelSig() ~= sig then
			renderPanel()
			return
		end
		local mm = state.model
		if devLabel and mm.dev then
			devLabel.Text = string.format("💻 <b>%s</b>: %d%% (~%d days)\n%s dev points/day", mm.dev.name, pct(mm.progress), mm.eta, short(mm.devPerDay))
			local old = devFrame:FindFirstChild("ProgressTrack")
			if old then
				old:Destroy()
			end
			bar(devFrame, mm.progress, COLORS.pink)
		end
	end
end

function panels.Arena()
	panelTitle.Text = "🏆 AI Arena"
	panelSubtitle.Text = "Your best model vs. every rival lab"
	local function signature()
		local parts = {}
		for _, e in state.arena.ranking do
			table.insert(parts, e.name .. e.arena)
		end
		return table.concat(parts, ",")
	end
	local sig = signature()
	info(string.format("#1 gives <b>+%d%%</b> users on every model, top 3 gives <b>+%d%%</b>. Rivals launch new models over time, so keep shipping!", pct(Config.Arena.ChampionBonus), pct(Config.Arena.PodiumBonus)), 52)
	for i, entry in state.arena.ranking do
		local medal = ({ "🥇", "🥈", "🥉" })[i] or ("#" .. i)
		local _, _, _, frame = row(string.format("%s  %s <b>%s</b>\n<font color='#969EBE'>%s</font>", medal, entry.emoji, entry.name, entry.company), { { tostring(entry.arena), if entry.mine then COLORS.pink else COLORS.cardHi } }, 58)
		if entry.mine then
			frame.BackgroundColor3 = Color3.fromRGB(60, 30, 70)
		end
	end
	if state.model.feed then
		sectionTitle("📱 HYPE FEED")
		for _, post in state.model.feed do
			row(string.format("<font color='#AAB4FF'><b>%s</b></font>  %s", post.handle, post.text), nil, 46)
		end
	end
	return function()
		if signature() ~= sig then
			renderPanel()
		end
	end
end

function panels.Markets()
	panelTitle.Text = "🌏 Markets"
	panelSubtitle.Text = string.format("More markets = more users for every future launch (x%.1f now)", state.marketMult)
	local sig = state.building .. "|"
	for id in state.markets do
		sig ..= id
	end
	for _, m in Config.Markets do
		local text = string.format("%s <b>%s</b>\n<font color='#969EBE'>+%.1f users • needs %s</font>", m.emoji, m.name, m.mult, Config.Buildings[m.requireBuilding].name)
		if state.markets[m.id] then
			row(text, { { "✅ Open", COLORS.done } }, 60)
		elseif state.building < m.requireBuilding then
			row(text, { { "🔒 " .. money(m.price), COLORS.disabled } }, 60)
		else
			row(text, { { "Enter " .. money(m.price), COLORS.blue, function()
				fire("ExpandMarket", m.id)
			end } }, 60)
		end
	end
	return function()
		local now = state.building .. "|"
		for id in state.markets do
			now ..= id
		end
		if now ~= sig then
			renderPanel()
		end
	end
end

local function sparkline(parent, id)
	local holder = new("Frame", { Position = UDim2.new(0, 12, 0, 52), Size = UDim2.new(0.45, 0, 0, 40), BackgroundTransparency = 1, ZIndex = 13, Parent = parent }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 1) }),
	})
	local bars = {}
	for i = 1, 24 do
		bars[i] = new("Frame", { Size = UDim2.new(1 / 24, -1, 0, 2), BorderSizePixel = 0, BackgroundColor3 = COLORS.green, ZIndex = 13, Parent = holder })
	end
	return function()
		local h = market.history[id] or {}
		local n = #h
		local lo, hi = math.huge, -math.huge
		for i = math.max(1, n - 23), n do
			lo = math.min(lo, h[i])
			hi = math.max(hi, h[i])
		end
		for i = 1, 24 do
			local value = h[n - 24 + i]
			local b = bars[i]
			if value then
				local t = if hi > lo then (value - lo) / (hi - lo) else 0.5
				b.Size = UDim2.new(1 / 24, -1, 0.15 + 0.85 * t, 0)
				local prev = h[n - 24 + i - 1]
				b.BackgroundColor3 = if prev and value < prev then COLORS.red else COLORS.green
				b.Visible = true
			else
				b.Visible = false
			end
		end
	end
end

local function smallButton(parent, text, color, onClick, width)
	local button = new("TextButton", { Size = UDim2.fromOffset(width or 92, 38), BackgroundColor3 = color, Font = FONT_BLACK, TextSize = 14, TextColor3 = COLORS.text, Text = text, ZIndex = 13, Parent = parent }, { corner(10) })
	button.MouseButton1Click:Connect(onClick)
	return button
end

function panels.Stocks()
	panelTitle.Text = "📈 Stock Market"
	panelSubtitle.Text = string.format("Invest in rival tech companies • %d%% fee per trade", pct(Config.Market.Fee))
	info("Rival launches make their stock jump — watch the 🏆 Arena for hints! Selling your company also sells your portfolio.", 46)
	local updaters = {}
	for i, stock in Config.Stocks do
		local frame = new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, -8, 0, 146), BackgroundColor3 = COLORS.card, ZIndex = 12, Parent = content }, { corner(12) })
		local title = new("TextLabel", { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 42), BackgroundTransparency = 1, Font = FONT, TextSize = 16, RichText = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COLORS.text, ZIndex = 13, Parent = frame })
		local holding = new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 52), Size = UDim2.new(0.5, -12, 0, 40), BackgroundTransparency = 1, Font = FONT, TextSize = 14, RichText = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = COLORS.text, ZIndex = 13, Parent = frame })
		local drawChart = sparkline(frame, stock.id)
		local buttons = new("Frame", { Position = UDim2.new(0, 12, 1, -46), Size = UDim2.new(1, -24, 0, 38), BackgroundTransparency = 1, ZIndex = 13, Parent = frame }, {
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
		})
		smallButton(buttons, "Buy 1", COLORS.green, function()
			fire("BuyStock", stock.id, 1)
		end, 80)
		smallButton(buttons, "Buy 10", COLORS.green, function()
			fire("BuyStock", stock.id, 10)
		end, 80)
		smallButton(buttons, "Buy max", COLORS.green, function()
			fire("BuyStock", stock.id, "max")
		end, 96)
		smallButton(buttons, "Sell all", COLORS.red, function()
			fire("SellStock", stock.id, "all")
		end, 96)
		updaters[i] = function()
			local price = market.prices[stock.id] or stock.base
			local c = market.changes[stock.id] or 0
			title.Text = string.format("%s <b>%s</b> (%s)   <b>$%.2f</b>  %s", stock.emoji, stock.name, stock.id, price, if c >= 0 then string.format("<font color='#4CFF7A'>▲ %.1f%%</font>", c * 100) else string.format("<font color='#FF5A5A'>▼ %.1f%%</font>", -c * 100))
			local h = state.stocks and state.stocks[stock.id]
			if h and h.qty > 0 then
				local value = h.qty * price
				local pnl = value - h.cost
				holding.Text = string.format("You own <b>%d</b> = %s\n%s%s</font> (%s%d%%)", h.qty, money(value), if pnl >= 0 then "<font color='#4CFF7A'>+" else "<font color='#FF5A5A'>", money(pnl), if pnl >= 0 then "+" else "", pct(pnl / math.max(1, h.cost)))
			else
				holding.Text = "<font color='#969EBE'>No shares yet</font>"
			end
			drawChart()
		end
	end
	return function()
		for _, update in updaters do
			update()
		end
	end
end

function panels.Daily()
	panelTitle.Text = "🎁 Daily Rewards"
	panelSubtitle.Text = "Log in every day — miss one and the streak resets"
	local daily = state.daily
	local builtClaimable = daily.claimable
	local timerLabel = row("", nil, 46)
	for day, reward in Config.Daily do
		local isDone = (daily.claimable and day < daily.nextDay) or (not daily.claimable and day <= daily.streak)
		local isNext = day == daily.nextDay
		local extra = if reward.boosts then " + 🚀 x2 revenue 30 min" else ""
		local amountText = if isNext then money(daily.nextAmount) else "≥ " .. money(reward.min)
		local text = string.format("<b>Day %d</b>  %s\n<font color='#969EBE'>%s%s</font>", day, if isDone then "✅" else "", amountText, extra)
		if isNext and daily.claimable then
			row(text, { { "🎁 Claim", COLORS.pink, function()
				fire("ClaimDaily")
			end } }, 58)
		else
			row(text, nil, 58)
		end
	end
	return function()
		if state.daily.claimable ~= builtClaimable then
			renderPanel()
			return
		end
		timerLabel.Text = if state.daily.claimable then "<b>🎉 A reward is waiting for you!</b>" else string.format("⏳ Next reward in <b>%s</b>", fmtTime(state.daily.resetIn))
	end
end

local sellConfirmUntil = 0
function panels.Sell()
	local rank = Config.CompanyRank(state.sold)
	panelTitle.Text = "💼 Sell Your Company"
	panelSubtitle.Text = "Current title: " .. rank.name
	local need = Config.Buildings[Config.Rebirth.RequiredBuilding]
	info(string.format(
		"Sell to a mega-corp: you lose cash, building, staff, R&D, factory, models, markets and stocks, and time rewinds to %d. You keep <b>Founder Points</b>: each one gives <b>+%d%% revenue and output forever</b>. Requires the %s %s.",
		Config.Calendar.StartYear,
		pct(Config.Rebirth.FounderBonus),
		need.emoji,
		need.name
	), 92)
	local holdingLabel = row("", nil, 52)
	local projectLabel = row("", nil, 60)
	local _, button = row("<b>Ready to sign the deal?</b>", { { "🤝 Sell", COLORS.gold, function()
		if os.clock() < sellConfirmUntil then
			sellConfirmUntil = 0
			fire("SellCompany")
		else
			sellConfirmUntil = os.clock() + 4
			toast("⚠️ Selling resets everything! Tap Sell again within 4 seconds to confirm")
		end
	end } }, 56)
	return function()
		holdingLabel.Text = string.format("You have <b>🏅 %d Founder Points</b> (x%.1f) • Companies sold: %d", state.founderPoints, Config.FounderMultiplier(state.founderPoints), state.sold)
		local ready = state.building >= Config.Rebirth.RequiredBuilding and state.sellPoints >= 1
		local missing = if state.building < Config.Rebirth.RequiredBuilding then string.format("\n<font color='#FF7070'>Needs %s (you have %s)</font>", need.name, Config.Buildings[state.building].name) else ""
		projectLabel.Text = string.format("Selling now gives <b><font color='#FFD84D'>+%d Founder Points</font></b>\n<font color='#969EBE'>Revenue this run: %s</font>%s", state.sellPoints, money(state.runEarned), missing)
		local confirming = os.clock() < sellConfirmUntil
		button.Text = if confirming then "Sure? Tap again!" else "🤝 Sell"
		button.BackgroundColor3 = if not ready then COLORS.disabled elseif confirming then COLORS.red else COLORS.gold
	end
end

function panels.Shop()
	panelTitle.Text = "💎 Shop"
	panelSubtitle.Text = "Boost your empire"
	local tabs = {}
	for _, tab in Config.ShopTabs do
		table.insert(tabs, {
			text = "<b>" .. tab.name .. "</b>",
			color = if shopTab == tab.id then COLORS.selected else COLORS.card,
			selected = shopTab == tab.id,
			onClick = function()
				shopTab = tab.id
				renderPanel()
			end,
		})
	end
	chips(tabs, 92, 38)
	local current
	for _, tab in Config.ShopTabs do
		if tab.id == shopTab then
			current = tab
		end
	end
	for _, item in current.items do
		local kind, key = item[1], item[2]
		if kind == "pass" then
			local pass = Config.GamePasses[key]
			local text = string.format("<b>%s</b>\n<font color='#969EBE'>%s</font>", pass.name, pass.description)
			if player:GetAttribute(key) == true then
				row(text, { { "✅ Owned", COLORS.done } }, 74)
			else
				local _, button = row(text, { { "R$ ...", COLORS.robux, function()
					if pass.id == 0 then
						toast("Set this Game Pass ID in Config.luau 🛠️")
					else
						MarketplaceService:PromptGamePassPurchase(player, pass.id)
					end
				end } }, 74)
				fillRobuxPrice(button, pass.id, Enum.InfoType.GamePass)
			end
		else
			local product = Config.DevProducts[key]
			local extra
			if product.kind == "Skip" then
				extra = string.format("Revenue ≈ %s (wages still apply)", money((state.revenuePerDay or 0) * product.days))
			elseif product.kind == "Funding" then
				extra = string.format("You get ≈ %s right now", money(math.max(product.minCash, (state.revenuePerDay or 0) * product.cashDays)))
			elseif product.kind == "Instant" then
				local busy = if product.target == "Research" then state.research.current ~= nil else state.model.dev ~= nil
				extra = if busy then "<font color='#7CFC00'>Something is in progress</font>" else "Nothing is running right now"
			elseif product.kind == "Hype" then
				extra = string.format("Viral charges: %d", state.model.viral)
			elseif product.kind == "Legend" then
				extra = "Skill " .. Config.Staff.LegendSkill .. " in your smallest department"
			elseif product.kind == "Shield" then
				extra = string.format("Shields ready: %d", state.shields or 0)
			else
				local active = {}
				for boost in product.boosts do
					local left = boostLeft(boost)
					if left > 0 then
						table.insert(active, fmtTime(left))
					end
				end
				extra = if #active > 0 then "<font color='#7CFC00'>Active: " .. table.concat(active, " / ") .. " left</font>" else "Stacks if you buy more"
			end
			local _, button = row("<b>" .. product.name .. "</b>\n<font color='#969EBE'>" .. extra .. "</font>", { { "R$ ...", COLORS.robux, function()
				if product.id == 0 then
					toast("Set this Developer Product ID in Config.luau 🛠️")
				else
					MarketplaceService:PromptProductPurchase(player, product.id)
				end
			end } }, 74)
			fillRobuxPrice(button, product.id, Enum.InfoType.Product)
		end
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
	orderCounter = 0
	panelSubtitle.Text = ""
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

local function addMenuButtons(column, entries)
	for order, entry in entries do
		local button = new("TextButton", {
			LayoutOrder = order,
			Size = UDim2.fromOffset(140, 44),
			BackgroundColor3 = entry.color,
			BackgroundTransparency = 0.05,
			Font = FONT_BLACK,
			TextSize = 16,
			TextColor3 = COLORS.text,
			Text = entry.text,
			Parent = column,
		}, { corner(12), stroke(COLORS.text, 1, 0.8) })
		badges[entry.id] = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = COLORS.red, Font = FONT_BLACK, TextSize = 13, TextColor3 = COLORS.text, Text = "!", Visible = false, ZIndex = 3, Parent = button }, { corner(10) })
		button.MouseButton1Click:Connect(function()
			togglePanel(entry.id)
		end)
	end
end
addMenuButtons(leftMenu, LEFT_MENU)
addMenuButtons(rightMenu, RIGHT_MENU)

-- ================= Popup: báo chí chấm điểm / sự kiện =================

local function modal(width, height, accent)
	local overlay = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 60, Active = true, Parent = gui })
	local card = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(width, height), BackgroundColor3 = COLORS.bg, ZIndex = 61, Parent = overlay }, { corner(20), stroke(accent, 2.5, 0.2) })
	local list = new("Frame", { Position = UDim2.fromOffset(20, 16), Size = UDim2.new(1, -40, 1, -32), BackgroundTransparency = 1, ZIndex = 62, Parent = card }, {
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	local order = 0
	local function line(text, size, color, height, font)
		order += 1
		return new("TextLabel", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, height or 28), BackgroundTransparency = 1, Font = font or FONT_BLACK, TextSize = size, TextWrapped = true, RichText = true, TextColor3 = color or COLORS.text, Text = text, ZIndex = 63, Parent = list })
	end
	local function button(text, color, onClick)
		order += 1
		local b = new("TextButton", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = color, Font = FONT_BLACK, TextSize = 16, TextColor3 = COLORS.text, TextWrapped = true, RichText = true, Text = text, ZIndex = 63, Parent = list }, { corner(12) })
		b.MouseButton1Click:Connect(function()
			overlay:Destroy()
			onClick()
		end)
		return b
	end
	return line, button, overlay
end

local function showReview(data)
	local line, button = modal(480, 560, COLORS.gold)
	line("📰 THE REVIEWS ARE IN", 16, COLORS.gold)
	line(string.format("%s %s", data.emoji, data.name), 30, COLORS.text, 38)
	local rows = {}
	for i, review in data.scores do
		rows[i] = line(review.name .. ": ...", 18, COLORS.text, 26, FONT)
	end
	local avg = line("", 44, COLORS.gold, 50)
	local comment = line("", 16, COLORS.text, 40, FONT)
	local arena = line("", 15, COLORS.pink, 24, FONT)
	local feed = line("", 13, Color3.fromRGB(170, 180, 255), 70, FONT)
	local close = button("Awesome! 🎉", COLORS.pink, function() end)
	close.Visible = false
	task.spawn(function()
		for i, review in data.scores do
			task.wait(0.6)
			local color = if review.score >= 8 then "#7CFF9A" elseif review.score >= 5 then "#FFE27A" else "#FF8080"
			rows[i].Text = string.format("%s: <font color='%s'><b>%d/10</b></font>", review.name, color, review.score)
		end
		task.wait(0.6)
		avg.Text = string.format("⭐ %.1f / 10", data.score)
		comment.Text = "“" .. data.comment .. "”"
		arena.Text = string.format("🏆 Arena %d • rank #%d%s • ~%s users at peak", data.arena, data.rank, if data.rankUp then " ⬆️" else "", short(data.peak))
		local posts = {}
		for i = 1, math.min(3, #data.feed) do
			table.insert(posts, "<b>" .. data.feed[i].handle .. "</b> " .. data.feed[i].text)
		end
		feed.Text = table.concat(posts, "\n")
		close.Visible = true
		flashScreen(if data.score >= 7 then COLORS.gold else COLORS.red)
	end)
end

local function showEvent(data)
	local line, button = modal(480, 300 + #data.choices * 52, COLORS.cyan)
	line("⚡ BREAKING NEWS", 16, COLORS.cyan)
	line(data.emoji .. " " .. data.title, 26, COLORS.text, 36)
	line(data.text, 16, COLORS.muted, 48, FONT)
	line("Time is paused until you decide.", 13, COLORS.muted, 20, FONT_LIGHT)
	for _, choice in data.choices do
		local label = choice.label .. (if choice.cost then "  <font color='#FFD84D'>(" .. money(choice.cost) .. ")</font>" else "")
		button(label, if choice.index == 1 then COLORS.blue else COLORS.cardHi, function()
			fire("ChooseEvent", choice.index)
		end)
	end
	flashScreen(COLORS.cyan)
end

-- ================= HUD =================

local function renderHud()
	if not state then
		return
	end
	dateValue.Text = Config.DateText(state.day)
	for index, b in speedButtons do
		local locked = index >= Config.Calendar.FastSpeedIndex and not state.fastUnlocked
		b.BackgroundColor3 = if state.speed == index then COLORS.selected elseif locked then COLORS.disabled else COLORS.card
		b.Text = ({ "⏸", "▶", "⏩", if locked then "🔒" else "⏭" })[index]
	end
	cashValue.Text = string.format("%s <font size='13' color='#7CFF9A'>+%s/d</font>", money(state.cash), short(state.revenuePerDay or 0))
	cashValue.TextColor3 = if state.cash < 0 then COLORS.red else COLORS.text
	computeValue.Text = string.format("⚡%s <font size='13' color='#FFE27A'>+%s</font>", short(state.factory.compute), short(state.factory.perDay))
	teamValue.Text = string.format("%d/%d <font size='13' color='#%s'>%d%%</font>", #state.staff + 1, state.capacity, moraleColor(state.morale):ToHex(), math.floor(state.morale))
	arenaValue.Text = if #state.model.history > 0 then "#" .. state.arena.rank else "—"

	if state.goal then
		goalLabel.Text = string.format("🎯 <b>Goal %d/%d:</b> %s  <font color='#FFD84D'>+%s</font>", state.goal.index, state.goal.total, state.goal.text, money(state.goal.reward))
		goalFill.Size = UDim2.fromScale(state.goal.progress, 1)
		goalBar.Visible = true
	else
		goalBar.Visible = false
	end

	local work = {}
	if state.research.current then
		table.insert(work, string.format("🔬 %s %d%%", Config.ResearchById[state.research.current].name, pct(state.research.progress)))
	end
	if state.model.dev then
		table.insert(work, string.format("💻 %s %d%%", state.model.dev.name, pct(state.model.progress)))
	elseif state.model.pending then
		table.insert(work, "🚀 <b>" .. state.model.pending.name .. " is ready to launch!</b>")
	end
	for _, b in { { "Cash", "💵x2" }, { "Work", "⚡x2" }, { "Compute", "🏭x2" } } do
		local left = boostLeft(b[1])
		if left > 0 then
			table.insert(work, b[2] .. " " .. fmtTime(left))
		end
	end
	for _, mod in state.modifiers or {} do
		table.insert(work, string.format("%s x%.1f (%dd)", mod.kind, mod.mult, mod.untilDay - state.day))
	end
	workLabel.Text = table.concat(work, "   •   ")
	workLabel.Visible = #work > 0

	local nextB = Config.Buildings[state.building + 1]
	badges.Company.Visible = nextB ~= nil and state.runEarned >= nextB.requireEarned and state.cash >= nextB.price
	badges.Research.Visible = state.research.current == nil
	badges.Model.Visible = state.model.pending ~= nil or (state.model.dev == nil and done("Text"))
	badges.Staff.Visible = state.workstations - 1 - #state.staff > 0 or (#state.staff > 0 and state.morale < 45 and state.partyIn == 0)
	badges.Daily.Visible = state.daily ~= nil and state.daily.claimable
	badges.Sell.Visible = state.building >= Config.Rebirth.RequiredBuilding and (state.sellPoints or 0) >= 1
end

remotes.State.OnClientEvent:Connect(function(newState)
	local first = state == nil
	state = newState
	renderHud()
	if panelUpdate then
		panelUpdate()
	end
	if first then
		if state.daily and state.daily.claimable then
			openPanel = "Daily"
			renderPanel()
		elseif state.day == 0 then
			toast("👋 Welcome to your garage! Follow the 🎯 goals at the top to build an AI empire.", 8)
		end
	end
end)

remotes.Market.OnClientEvent:Connect(function(data)
	market.prices = data.prices
	market.changes = data.changes
	if data.history then
		market.history = data.history
	else
		for id, price in data.prices do
			local h = market.history[id] or {}
			table.insert(h, price)
			while #h > Config.Market.History do
				table.remove(h, 1)
			end
			market.history[id] = h
		end
	end
	if openPanel == "Stocks" and panelUpdate then
		panelUpdate()
	end
end)

remotes.Popup.OnClientEvent:Connect(function(data)
	if data.kind == "Event" then
		showEvent(data)
	else
		showReview(data)
	end
end)

remotes.Notify.OnClientEvent:Connect(function(message, action)
	if message ~= "" then
		toast(message, if action == "News" then 5 else 3.5)
	end
	if type(action) == "string" and action:sub(1, 5) == "Open:" then
		local name = action:sub(6)
		if panels[name] then
			openPanel = name
			renderPanel()
		end
	elseif action == "Evolve" then
		flashScreen(COLORS.gold)
	elseif action == "Collect" then
		popText("💰", COLORS.green, UDim2.new(0.5, 0, 0, 150))
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		renderHud()
		if panelUpdate and state then
			panelUpdate()
		end
	end
end)

Fx.Start(workspace:WaitForChild("Lots"))
Fx.Start(workspace:WaitForChild("City"))

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
