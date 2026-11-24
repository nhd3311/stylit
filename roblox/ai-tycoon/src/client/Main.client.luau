-- Giao diện người chơi: lịch + nút tua, tiền, compute, và các bảng:
-- Công ty, Nhân sự, R&D, Xưởng, Model AI, Thị trường, Cổ phiếu, Quà, Bán công ty, Shop,
-- cùng popup báo chí chấm điểm khi ra mắt model.
-- Toàn bộ UI dựng bằng code, tự co giãn theo màn hình (nút to, chữ to, né nút nhảy trên điện thoại).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Fx = require(script.Parent:WaitForChild("Fx"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local state = nil -- snapshot mới nhất từ server
local market = { prices = {}, changes = {}, history = {} }
local openPanel = nil

-- lựa chọn đang soạn trong bảng Model AI
local design = { type = nil, size = "Mini", features = {} }
local launchChoice = { price = "Normal", campaign = "None" }

local FONT = Enum.Font.BuilderSansBold
local FONT_BLACK = Enum.Font.BuilderSansExtraBold
local COLORS = {
	bg = Color3.fromRGB(14, 16, 28),
	card = Color3.fromRGB(30, 33, 52),
	cyan = Color3.fromRGB(0, 200, 255),
	purple = Color3.fromRGB(160, 90, 255),
	pink = Color3.fromRGB(255, 70, 170),
	gold = Color3.fromRGB(255, 205, 60),
	green = Color3.fromRGB(60, 210, 120),
	red = Color3.fromRGB(240, 70, 80),
	robux = Color3.fromRGB(0, 175, 110),
	blue = Color3.fromRGB(60, 120, 255),
	orange = Color3.fromRGB(255, 150, 50),
	done = Color3.fromRGB(60, 110, 80),
	selected = Color3.fromRGB(0, 160, 220),
	disabled = Color3.fromRGB(75, 78, 98),
	text = Color3.fromRGB(245, 245, 255),
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
	return new("UIStroke", {
		Color = color or COLORS.cyan,
		Thickness = thickness or 2,
		Transparency = transparency or 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
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
	if not state then
		return 0
	end
	return math.max(0, (state.boosts[name] or 0) - workspace:GetServerTimeNow())
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

local gui = new("ScreenGui", {
	Name = "TycoonUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
})

local uiScale = new("UIScale", { Parent = gui })
local function updateScale()
	local camera = workspace.CurrentCamera
	if camera then
		local size = camera.ViewportSize
		uiScale.Scale = math.clamp(math.min(size.X / 1150, size.Y / 680), 0.65, 1.15)
	end
end
updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local flash = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = COLORS.gold,
	BackgroundTransparency = 1,
	ZIndex = 50,
	Active = false,
	Parent = gui,
})
local function flashScreen(color)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.6
	TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
end

-- ---------- Thanh trên: lịch + tốc độ, tiền + compute, việc đang chạy ----------
local topBar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 6),
	Size = UDim2.fromOffset(480, 170),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local function hRow(order, height)
	return new("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(480, height),
		BackgroundTransparency = 1,
		Parent = topBar,
	}, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
end

local dateRow = hRow(1, 44)
local dateLabel = new("TextLabel", {
	LayoutOrder = 0,
	Size = UDim2.fromOffset(190, 44),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 0.1,
	Font = FONT_BLACK,
	TextSize = 22,
	TextColor3 = COLORS.text,
	Text = "📅 ...",
	Parent = dateRow,
}, { corner(22), stroke(COLORS.cyan, 2, 0.4) })

local speedButtons = {}
for index, icon in { "⏸", "▶", "⏩", "⏭" } do
	local button = new("TextButton", {
		LayoutOrder = index,
		Size = UDim2.fromOffset(52, 44),
		BackgroundColor3 = COLORS.card,
		Font = FONT_BLACK,
		TextSize = 22,
		TextColor3 = COLORS.text,
		Text = icon,
		Parent = dateRow,
	}, { corner(12) })
	button.MouseButton1Click:Connect(function()
		fire("SetSpeed", index)
	end)
	speedButtons[index] = button
end

local moneyRow = hRow(2, 44)
local function pill(color)
	return new("TextLabel", {
		Size = UDim2.fromOffset(236, 44),
		BackgroundColor3 = COLORS.bg,
		BackgroundTransparency = 0.1,
		Font = FONT_BLACK,
		TextSize = 21,
		TextColor3 = color,
		RichText = true,
		Text = "...",
		Parent = moneyRow,
	}, { corner(22), stroke(color, 2, 0.4) })
end
local cashLabel = pill(COLORS.green)
local computeLabel = pill(COLORS.gold)

local statusLabel = new("TextLabel", {
	LayoutOrder = 3,
	Size = UDim2.fromOffset(480, 26),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 0.25,
	Font = FONT,
	TextSize = 15,
	TextColor3 = COLORS.cyan,
	Visible = false,
	Parent = topBar,
}, { corner(13) })

local workLabel = new("TextLabel", {
	LayoutOrder = 4,
	Size = UDim2.fromOffset(480, 26),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 0.25,
	Font = FONT,
	TextSize = 15,
	TextColor3 = COLORS.text,
	Visible = false,
	Parent = topBar,
}, { corner(13) })

local toastLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 185),
	Size = UDim2.fromOffset(540, 50),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 18,
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
	toastLabel.BackgroundTransparency = 0.1
	task.delay(seconds or 3.5, function()
		if version == toastVersion then
			TweenService:Create(toastLabel, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		end
	end)
end

-- ---------- Nút code dạo (bên phải, cao hơn nút nhảy) ----------
local codeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -24, 0.66, 0),
	Size = UDim2.fromOffset(118, 118),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Font = FONT_BLACK,
	TextSize = 19,
	TextColor3 = COLORS.text,
	TextStrokeTransparency = 0.5,
	TextWrapped = true,
	Text = "💻\nCODE DẠO",
	Parent = gui,
}, { corner(59), gradient(COLORS.green, COLORS.cyan, 45), stroke(COLORS.text, 3, 0.5) })

local function popText(text, color, origin)
	local pop = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = origin or UDim2.new(1, -83 + math.random(-40, 40), 0.66, -88),
		Size = UDim2.fromOffset(160, 34),
		BackgroundTransparency = 1,
		Font = FONT_BLACK,
		TextSize = 26,
		TextColor3 = color or COLORS.green,
		TextStrokeTransparency = 0.3,
		Text = text,
		ZIndex = 30,
		Parent = gui,
	})
	local tween = TweenService:Create(pop, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = pop.Position - UDim2.fromOffset(0, 70),
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
	fire("Click")
	if state then
		popText("+" .. money(state.clickCash))
	end
	codeButton.Size = UDim2.fromOffset(108, 108)
	TweenService:Create(codeButton, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(118, 118) }):Play()
end)

-- ---------- Menu ----------
local LEFT_MENU = {
	{ id = "Company", text = "🏢 Công ty", color = COLORS.gold },
	{ id = "Staff", text = "👥 Nhân sự", color = COLORS.blue },
	{ id = "Research", text = "🔬 R&D", color = COLORS.purple },
	{ id = "Factory", text = "🏭 Xưởng", color = COLORS.orange },
	{ id = "Model", text = "🧠 Model AI", color = COLORS.pink },
	{ id = "Markets", text = "🌏 Thị trường", color = COLORS.card },
}
local RIGHT_MENU = {
	{ id = "Stocks", text = "📈 Cổ phần", color = COLORS.green },
	{ id = "Daily", text = "🎁 Quà", color = COLORS.pink },
	{ id = "Sell", text = "💼 Bán cty", color = COLORS.card },
	{ id = "Shop", text = "💎 Shop", color = COLORS.robux },
}

local function menuColumn(anchor, position, count)
	return new("Frame", {
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(142, count * 56),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
end
local leftMenu = menuColumn(Vector2.new(0, 0.5), UDim2.new(0, 12, 0.47, 0), #LEFT_MENU)
local rightMenu = menuColumn(Vector2.new(1, 0), UDim2.new(1, -12, 0, 64), #RIGHT_MENU)

local badges = {}

-- ---------- Bảng giữa màn hình ----------
local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.57),
	Size = UDim2.new(0, 580, 0.7, 0),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 0.04,
	Visible = false,
	ZIndex = 10,
	Parent = gui,
}, {
	corner(20),
	stroke(COLORS.cyan, 2, 0.35),
	new("UISizeConstraint", { MaxSize = Vector2.new(580, 640), MinSize = Vector2.new(300, 280) }),
})

local panelTitle = new("TextLabel", {
	Position = UDim2.fromOffset(18, 10),
	Size = UDim2.new(1, -80, 0, 40),
	BackgroundTransparency = 1,
	Font = FONT_BLACK,
	TextSize = 24,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = COLORS.text,
	ZIndex = 11,
	Parent = panel,
})

local closeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 10),
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = COLORS.red,
	Font = FONT_BLACK,
	TextSize = 22,
	TextColor3 = COLORS.text,
	Text = "✕",
	ZIndex = 11,
	Parent = panel,
}, { corner(22) })

local content = new("ScrollingFrame", {
	Position = UDim2.fromOffset(14, 62),
	Size = UDim2.new(1, -28, 1, -76),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 8,
	ScrollBarImageColor3 = COLORS.cyan,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ZIndex = 11,
	Parent = panel,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
})

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
	new("TextLabel", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = FONT_BLACK,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.gold,
		Text = text,
		ZIndex = 12,
		Parent = content,
	})
end

-- Một dòng: chữ bên trái + 0..2 nút bên phải. buttons = { { text, color, onClick }, ... }
-- Trả về label, các nút.
local function row(text, buttons, height)
	local frame = new("Frame", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, -10, 0, height or 72),
		BackgroundColor3 = COLORS.card,
		ZIndex = 12,
		Parent = content,
	}, { corner(14) })
	buttons = buttons or {}
	local buttonWidth = if #buttons >= 2 then 104 else 144
	local label = new("TextLabel", {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -28 - #buttons * (buttonWidth + 8), 1, 0),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 16,
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
			Size = UDim2.fromOffset(buttonWidth, 48),
			BackgroundColor3 = spec[2] or COLORS.cyan,
			AutoButtonColor = spec[3] ~= nil,
			Font = FONT_BLACK,
			TextSize = 15,
			TextColor3 = COLORS.text,
			TextWrapped = true,
			Text = spec[1],
			ZIndex = 13,
			Parent = frame,
		}, { corner(12) })
		if spec[3] then
			button.MouseButton1Click:Connect(spec[3])
		end
		made[i] = button
	end
	return label, made[1], made[2]
end

local function info(text, height)
	return (row("<font color='#AAAACC'>" .. text .. "</font>", nil, height or 56))
end

-- Lưới nút chọn (cho chọn loại model, kích thước, tính năng, giá, chiến dịch)
local function chips(items)
	local frame = new("Frame", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 12,
		Parent = content,
	}, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(170, 54), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, item in items do
		local button = new("TextButton", {
			LayoutOrder = i,
			BackgroundColor3 = item.color,
			AutoButtonColor = item.onClick ~= nil,
			Font = FONT,
			TextSize = 14,
			TextWrapped = true,
			RichText = true,
			TextColor3 = COLORS.text,
			Text = item.text,
			ZIndex = 13,
			Parent = frame,
		}, { corner(10) })
		if item.onClick then
			button.MouseButton1Click:Connect(item.onClick)
		end
	end
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
		local ok, result = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
		if ok and result and result.PriceInRobux then
			priceCache[cacheKey] = result.PriceInRobux
			if button.Parent then
				button.Text = "R$ " .. result.PriceInRobux
			end
		end
	end)
end

-- ================= Nội dung từng bảng =================
-- Mỗi bảng dựng khung 1 lần và có thể trả về hàm update chạy mỗi lần có State mới.
-- Hàm update tự gọi renderPanel() khi cấu trúc đổi (để không vẽ lại bảng liên tục làm trượt cú bấm).

local panels = {}
local panelUpdate = nil
local renderPanel

local function openOther(name)
	return function()
		openPanel = name
		renderPanel()
	end
end

function panels.Company()
	local b = Config.Buildings[state.building]
	panelTitle.Text = string.format("%s %s", b.emoji, b.name)
	local sig = string.format("%d|%d|%d%d%d", state.building, state.workstations, state.equip.desk, state.equip.chair, state.equip.pc)

	sectionTitle("🏢 Tòa nhà")
	local nextB = Config.Buildings[state.building + 1]
	local upgradeLabel, upgradeButton
	if nextB then
		upgradeLabel, upgradeButton = row("", { { "Nâng cấp " .. money(nextB.price), COLORS.gold, function()
			fire("UpgradeBuilding")
		end } }, 84)
	else
		row("🌆 Đã là <b>Campus</b> to nhất thung lũng!")
	end

	sectionTitle(string.format("🪑 Chỗ làm việc (%d/%d)", state.workstations, state.capacity))
	local e = Config.Equipment
	local seatPrice = Config.WorkstationPrice + e.desk.tiers[state.equip.desk].price + e.chair.tiers[state.equip.chair].price + e.pc.tiers[state.equip.pc].price
	if state.workstations < state.capacity then
		row(string.format("Kê thêm 1 bộ bàn + ghế + máy tính\n<font color='#AAAACC'>Mỗi nhân viên cần 1 chỗ. Bàn 1 là của bạn.</font>"), { { "Mua " .. money(seatPrice), COLORS.green, function()
			fire("BuyWorkstation")
		end } })
	else
		row("<font color='#AAAACC'>Hết chỗ kê bàn. Nâng cấp tòa nhà để có thêm chỗ.</font>")
	end

	sectionTitle(string.format("⚙️ Trang bị cả công ty (hiệu suất x%.2f)", state.equipMult))
	for _, kind in { "desk", "chair", "pc" } do
		local group = e[kind]
		local current = group.tiers[state.equip[kind]]
		local nextTier = group.tiers[state.equip[kind] + 1]
		local text = string.format("<b>%s:</b> %s (x%.2f)", group.name, current.name, current.mult)
		if not nextTier then
			row(text .. "\n<font color='#7CFF9A'>Đã xịn nhất</font>", { { "🔥 Max", COLORS.done } })
		elseif nextTier.research and not done(nextTier.research) then
			row(text .. string.format("\n<font color='#AAAACC'>Tiếp: %s (x%.2f)</font>", nextTier.name, nextTier.mult), { { "🔬 " .. Config.ResearchById[nextTier.research].name, COLORS.disabled, openOther("Research") } })
		else
			row(text .. string.format("\n<font color='#AAAACC'>Tiếp: %s (x%.2f) • %s x %d chỗ</font>", nextTier.name, nextTier.mult, money(nextTier.price), state.workstations), { { "Nâng " .. money(nextTier.price * state.workstations), COLORS.blue, function()
				fire("UpgradeEquipment", kind)
			end } })
		end
	end

	if b.floors > 1 then
		sectionTitle("🛗 Thang máy")
		local function go(floor)
			return function()
				fire("GoFloor", floor)
				openPanel = nil
				renderPanel()
			end
		end
		local items = { { text = "🏠 Sân trước", color = COLORS.cyan, onClick = function()
			fire("Home")
			openPanel = nil
			renderPanel()
		end } }
		for floor = 1, b.floors do
			table.insert(items, { text = "Tầng " .. floor, color = COLORS.blue, onClick = go(floor) })
		end
		chips(items)
	end

	return function()
		if string.format("%d|%d|%d%d%d", state.building, state.workstations, state.equip.desk, state.equip.chair, state.equip.pc) ~= sig then
			renderPanel()
			return
		end
		if upgradeLabel and nextB then
			local ready = state.runEarned >= nextB.requireEarned
			upgradeLabel.Text = string.format(
				"Lên <b>%s %s</b> (%d chỗ, %d tầng)\n%s",
				nextB.emoji,
				nextB.name,
				Config.Capacity(state.building + 1),
				nextB.floors,
				if ready then "<font color='#7CFF9A'>✅ Đã đủ doanh thu</font>" else string.format("<font color='#FF9A9A'>Doanh thu cần %s (hiện %s)</font>", money(nextB.requireEarned), money(state.runEarned))
			)
			upgradeButton.BackgroundColor3 = if ready and state.cash >= nextB.price then COLORS.gold else COLORS.disabled
		end
	end
end

function panels.Staff()
	panelTitle.Text = "👥 Nhân sự"
	local sig = #state.staff .. "|" .. #state.candidates .. "|" .. state.workstations
	for _, s in state.staff do
		sig ..= s.id .. ":" .. s.skill .. ","
	end
	local free = state.workstations - 1 - #state.staff
	local p = state.points
	info(string.format(
		"Lương tháng: <b>%s</b> • Bàn trống: <b>%d</b>\n💻 %s điểm dev/ngày • 🔬 %s điểm R&D/ngày",
		money(state.payroll),
		free,
		short(p.Dev),
		short(p.Research)
	), 60)

	sectionTitle(string.format("👔 Nhân viên (%d)", #state.staff))
	row(string.format("👑 <b>%s</b> • kỹ năng %d\n<font color='#AAAACC'>Làm cả lập trình lẫn nghiên cứu</font>", Config.Founder.name, Config.Founder.skill))
	for _, s in state.staff do
		local role = Config.Roles[s.role]
		local trainCost = s.skill * Config.Staff.TrainCostPerSkill
		row(string.format("%s <b>%s</b> • %s\n<font color='#AAAACC'>Kỹ năng <b>%d</b> • lương %s/tháng</font>", role.emoji, s.name, role.name, s.skill, money(s.salary)), {
			{ if s.skill >= Config.Staff.MaxSkill then "Max" else "📚 " .. money(trainCost), COLORS.blue, function()
				fire("Train", s.id)
			end },
			{ "Cho nghỉ", COLORS.red, function()
				fire("Fire", s.id)
			end },
		})
	end

	sectionTitle("📋 Ứng viên (đổi mới mỗi tháng)")
	if free <= 0 then
		row("<font color='#FF9A9A'>Hết bàn trống! Mua thêm chỗ làm việc để tuyển.</font>", { { "🪑 Mua bàn", COLORS.gold, openOther("Company") } })
	end
	for i, c in state.candidates do
		local role = Config.Roles[c.role]
		row(string.format("%s <b>%s</b> • %s\n<font color='#AAAACC'>Kỹ năng <b>%d</b> • lương %s/tháng • %s</font>", role.emoji, c.name, role.name, c.skill, money(c.salary), role.desc), {
			{ "Tuyển", if free > 0 then COLORS.green else COLORS.disabled, function()
				fire("Hire", i)
			end },
		}, 78)
	end
	row("Không ưng ai? Tìm ứng viên mới ngay", { { "🔄 " .. money(Config.Staff.RefreshPrice), COLORS.cyan, function()
		fire("RefreshCandidates")
	end } })

	return function()
		local now = #state.staff .. "|" .. #state.candidates .. "|" .. state.workstations
		for _, s in state.staff do
			now ..= s.id .. ":" .. s.skill .. ","
		end
		if now ~= sig then
			renderPanel()
		end
	end
end

local function researchSig()
	local count = 0
	for _ in state.researchDone do
		count += 1
	end
	return tostring(state.research.current) .. "|" .. count .. "|" .. year()
end

function panels.Research()
	panelTitle.Text = "🔬 Nghiên cứu R&D"
	local sig = researchSig()
	local currentLabel = row("", nil, 60)
	for _, category in Config.ResearchCategories do
		sectionTitle(category.name)
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
			local text = string.format("%s <b>%s</b>\n<font color='#AAAACC'>%s điểm R&D (~%d ngày) • từ năm %d</font>", node.emoji, node.name, short(node.cost), math.ceil(node.cost / perDay), node.year)
			if done(node.id) then
				row(text, { { "✅ Xong", COLORS.done } })
			elseif state.research.current == node.id then
				row(text, { { "⏳ Đang làm", COLORS.purple } })
			elseif year() < node.year then
				row(text, { { "📅 " .. node.year, COLORS.disabled } })
			elseif #missing > 0 then
				row(text .. "\n<font color='#FF9A9A'>Cần: " .. table.concat(missing, ", ") .. "</font>", { { "🔒", COLORS.disabled } }, 90)
			else
				row(text, { { "Nghiên cứu", if state.research.current then COLORS.disabled else COLORS.purple, function()
					fire("StartResearch", node.id)
				end } })
			end
		end
	end
	return function()
		if researchSig() ~= sig then
			renderPanel()
			return
		end
		local r = state.research
		if r.current then
			local node = Config.ResearchById[r.current]
			currentLabel.Text = string.format("⏳ Đang nghiên cứu <b>%s %s</b>: %d%% (còn ~%d ngày)\n🔬 %s điểm R&D/ngày", node.emoji, node.name, pct(r.progress), r.eta, short(r.perDay))
		else
			currentLabel.Text = string.format("<font color='#AAAACC'>Đội R&D đang rảnh. Chọn 1 công nghệ bên dưới.</font>\n🔬 %s điểm R&D/ngày (thuê thêm nhà nghiên cứu để nhanh hơn)", short(r.perDay))
		end
	end
end

function panels.Factory()
	panelTitle.Text = "🏭 Xưởng compute"
	local f = state.factory
	local sig = tostring(f.built) .. "|" .. table.concat(f.lines, ",") .. "|" .. researchSig()
	local summary
	if not f.built then
		local need = Config.Buildings[Config.Factory.RequireBuilding]
		info("Xưởng sản xuất ⚡ compute để train model Vừa/Lớn/Siêu lớn. Thiếu compute thì model bị chấm điểm thấp.", 64)
		row(string.format("🏗️ <b>Xây xưởng</b> ở lô đất bên cạnh\n<font color='#AAAACC'>Cần %s %s</font>", need.emoji, need.name), { { "Xây " .. money(Config.Factory.BuildPrice), if state.building >= Config.Factory.RequireBuilding then COLORS.orange else COLORS.disabled, function()
			fire("BuildFactory")
		end } })
	else
		summary = row("", nil, 60)
		sectionTitle("⚙️ Dây chuyền")
		for i, tier in f.lines do
			local t = Config.FactoryTiers[tier]
			local nextT = Config.FactoryTiers[tier + 1]
			local text = string.format("%s <b>Dây chuyền %d: %s</b>\n<font color='#AAAACC'>%s ⚡/ngày</font>", t.emoji, i, t.name, short(t.rate))
			if not nextT then
				row(text, { { "🔥 Max", COLORS.done } })
			elseif nextT.research and not done(nextT.research) then
				row(text, { { "🔬 " .. Config.ResearchById[nextT.research].name, COLORS.disabled, openOther("Research") } })
			else
				row(text .. string.format("\n<font color='#AAAACC'>Lên %s %s: %s ⚡/ngày</font>", nextT.emoji, nextT.name, short(nextT.rate)), { { "Nâng " .. money(nextT.price), COLORS.orange, function()
					fire("UpgradeLine", i)
				end } }, 84)
			end
		end
		local linePrice = Config.Factory.LinePrices[#f.lines + 1]
		if linePrice then
			row("➕ Lắp thêm dây chuyền mới (bắt đầu từ Server CPU)", { { "Mua " .. money(linePrice), COLORS.green, function()
				fire("BuyLine")
			end } })
		end
		info("🔧 Thuê thêm Kỹ sư để tăng sản lượng cả xưởng (+0.5% mỗi điểm kỹ năng).", 50)
	end
	return function()
		local ff = state.factory
		if tostring(ff.built) .. "|" .. table.concat(ff.lines, ",") .. "|" .. researchSig() ~= sig then
			renderPanel()
			return
		end
		if summary then
			summary.Text = string.format("⚡ Kho compute: <b>%s</b>\nSản xuất: <b>%s ⚡/ngày</b>", short(ff.compute), short(ff.perDay))
		end
	end
end

local function modelSig()
	local m = state.model
	return (if m.dev then "dev" .. m.dev.name else "") .. (if m.pending then "pend" .. m.pending.name else "") .. "|" .. researchSig() .. "|" .. #m.history
end

local function designView()
	sectionTitle("1️⃣ Loại model")
	local items = {}
	for _, t in Config.ModelTypes do
		local unlocked = done(t.requires)
		table.insert(items, {
			text = if unlocked then t.emoji .. " " .. t.name else "🔒 " .. t.name,
			color = if design.type == t.id then COLORS.selected elseif unlocked then COLORS.card else COLORS.disabled,
			onClick = if unlocked then function()
				design.type = t.id
				renderPanel()
			end else nil,
		})
	end
	chips(items)
	if not design.type then
		info("Chọn 1 loại model để tiếp tục. Loại mới mở khoá qua 🔬 R&D.")
		return
	end
	local modelType = Config.ModelTypeById[design.type]

	sectionTitle("2️⃣ Kích thước")
	items = {}
	for _, s in Config.ModelSizes do
		table.insert(items, {
			text = string.format("<b>%s</b>\n%s dev • %s⚡ • %d tính năng", s.name, short(s.devPoints), short(s.compute), s.slots),
			color = if design.size == s.id then COLORS.selected else COLORS.card,
			onClick = function()
				design.size = s.id
				-- bỏ bớt tính năng nếu vượt số slot mới
				while #design.features > s.slots do
					table.remove(design.features)
				end
				renderPanel()
			end,
		})
	end
	chips(items)
	local size = Config.ModelSizeById[design.size]

	sectionTitle(string.format("3️⃣ Tính năng (%d/%d) • ⭐ = hợp với %s", #design.features, size.slots, modelType.name))
	items = {}
	for _, node in Config.Research do
		if node.category == "Feature" and done(node.id) then
			local picked = table.find(design.features, node.id) ~= nil
			local good = table.find(modelType.good, node.id) ~= nil
			table.insert(items, {
				text = string.format("%s %s%s", node.emoji, node.name, if good then " ⭐" else ""),
				color = if picked then COLORS.selected else COLORS.card,
				onClick = function()
					local at = table.find(design.features, node.id)
					if at then
						table.remove(design.features, at)
					elseif #design.features < size.slots then
						table.insert(design.features, node.id)
					else
						toast("Kích thước này chỉ chứa tối đa " .. size.slots .. " tính năng")
					end
					renderPanel()
				end,
			})
		end
	end
	chips(items)

	local devPerDay = math.max(state.model.devPerDay, 0.01)
	local computeWarn = if size.compute > state.factory.compute
		then string.format("\n<font color='#FF9A9A'>⚠️ Kho chỉ có %s/%s ⚡ — model sẽ bị trừ điểm</font>", short(state.factory.compute), short(size.compute))
		else ""
	row(
		string.format("<b>%s %s %s</b>\n<font color='#AAAACC'>~%d ngày phát triển • cần %s⚡</font>%s", modelType.emoji, modelType.brand, size.name, math.ceil(size.devPoints / devPerDay), short(size.compute), computeWarn),
		{ { "🚀 Bắt đầu", if #design.features > 0 then COLORS.pink else COLORS.disabled, function()
			fire("StartModel", design.type, design.size, design.features)
			design.features = {}
		end } },
		90
	)
end

local function launchView()
	local pending = state.model.pending
	local modelType = Config.ModelTypeById[pending.type]
	info(string.format("✅ <b>%s %s</b> đã sẵn sàng! Chọn giá bán và chiến dịch marketing rồi ra mắt.", modelType.emoji, pending.name), 56)
	sectionTitle("💲 Giá bán")
	local items = {}
	for _, p in Config.PriceTiers do
		table.insert(items, {
			text = string.format("<b>%s</b>\n$%.2f/người/ngày • x%.1f người dùng", p.name, p.perUser, p.users),
			color = if launchChoice.price == p.id then COLORS.selected else COLORS.card,
			onClick = function()
				launchChoice.price = p.id
				renderPanel()
			end,
		})
	end
	chips(items)
	sectionTitle("📣 Chiến dịch marketing")
	items = {}
	for _, c in Config.Campaigns do
		local unlocked = not c.research or done(c.research)
		table.insert(items, {
			text = string.format("%s <b>%s</b>\n%s • độ hot x%.1f", c.emoji, if unlocked then c.name else "🔒 " .. c.name, if c.price > 0 then money(c.price) else "Miễn phí", c.hype),
			color = if launchChoice.campaign == c.id then COLORS.selected elseif unlocked then COLORS.card else COLORS.disabled,
			onClick = if unlocked then function()
				launchChoice.campaign = c.id
				renderPanel()
			end else nil,
		})
	end
	chips(items)
	local viral = if state.model.viral > 0 then string.format("\n🔥 Có %d lần Viral: độ hot x2!", state.model.viral) else ""
	row(string.format("Thị trường hiện tại: <b>x%.1f</b> người dùng%s", state.marketMult, viral), { { "🚀 RA MẮT", COLORS.pink, function()
		fire("Launch", launchChoice.price, launchChoice.campaign)
	end } }, 70)
end

function panels.Model()
	panelTitle.Text = "🧠 Model AI"
	local sig = modelSig()
	local m = state.model
	local devLabel
	if m.dev then
		local modelType = Config.ModelTypeById[m.dev.type]
		local names = {}
		for _, id in m.dev.features do
			table.insert(names, Config.ResearchById[id].emoji)
		end
		devLabel = row("", nil, 70)
		info(string.format("Đang phát triển %s <b>%s</b> (%s) với %s. Thuê thêm lập trình viên để nhanh hơn!", modelType.emoji, m.dev.name, Config.ModelSizeById[m.dev.size].name, table.concat(names, " ")), 56)
	elseif m.pending then
		launchView()
	else
		designView()
	end

	if #m.history > 0 then
		sectionTitle("📊 Model đã ra mắt")
		for _, model in m.history do
			local modelType = Config.ModelTypeById[model.type]
			row(string.format(
				"%s <b>%s</b> • ⭐ <b>%.1f</b>/10 %s\n<font color='#AAAACC'>%s người dùng • tổng %s • ra mắt %s</font>",
				modelType.emoji,
				model.name,
				model.score,
				if model.active then "<font color='#7CFF9A'>● Đang bán</font>" else "<font color='#888899'>● Ngừng bán</font>",
				short(model.users),
				money(model.revenue),
				Config.DateText(model.launchDay)
			), nil, 64)
		end
	end
	return function()
		if modelSig() ~= sig then
			renderPanel()
			return
		end
		local mm = state.model
		if devLabel and mm.dev then
			devLabel.Text = string.format("💻 <b>%s</b>: %d%% (còn ~%d ngày)\n%s điểm dev/ngày", mm.dev.name, pct(mm.progress), mm.eta, short(mm.devPerDay))
		end
	end
end

function panels.Markets()
	panelTitle.Text = "🌏 Mở rộng thị trường"
	local sig = state.building .. "|"
	for id in state.markets do
		sig ..= id
	end
	info(string.format("Càng nhiều thị trường, model ra mắt sau này càng nhiều người dùng. Hiện tại: <b>x%.1f</b>", state.marketMult), 56)
	for _, m in Config.Markets do
		local text = string.format("%s <b>%s</b>\n<font color='#AAAACC'>+%.1f người dùng • cần %s</font>", m.emoji, m.name, m.mult, Config.Buildings[m.requireBuilding].name)
		if state.markets[m.id] then
			row(text, { { "✅ Đã mở", COLORS.done } })
		elseif state.building < m.requireBuilding then
			row(text, { { "🔒 " .. money(m.price), COLORS.disabled } })
		else
			row(text, { { "Mở " .. money(m.price), COLORS.blue, function()
				fire("ExpandMarket", m.id)
			end } })
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

-- Biểu đồ mini: các cột cao thấp theo lịch sử giá
local function sparkline(parent, id)
	local holder = new("Frame", {
		Position = UDim2.new(0, 12, 0, 54),
		Size = UDim2.new(0.45, 0, 0, 40),
		BackgroundTransparency = 1,
		ZIndex = 13,
		Parent = parent,
	}, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 1) }),
	})
	local bars = {}
	for i = 1, 24 do
		bars[i] = new("Frame", {
			Size = UDim2.new(1 / 24, -1, 0, 2),
			BorderSizePixel = 0,
			BackgroundColor3 = COLORS.green,
			ZIndex = 13,
			Parent = holder,
		})
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
			local bar = bars[i]
			if value then
				local t = if hi > lo then (value - lo) / (hi - lo) else 0.5
				bar.Size = UDim2.new(1 / 24, -1, 0.15 + 0.85 * t, 0)
				local prev = h[n - 24 + i - 1]
				bar.BackgroundColor3 = if prev and value < prev then COLORS.red else COLORS.green
				bar.Visible = true
			else
				bar.Visible = false
			end
		end
	end
end

local function smallButton(parent, text, color, onClick, width)
	local button = new("TextButton", {
		Size = UDim2.fromOffset(width or 92, 40),
		BackgroundColor3 = color,
		Font = FONT_BLACK,
		TextSize = 15,
		TextColor3 = COLORS.text,
		Text = text,
		ZIndex = 13,
		Parent = parent,
	}, { corner(10) })
	button.MouseButton1Click:Connect(onClick)
	return button
end

function panels.Stocks()
	panelTitle.Text = "📈 Cổ phần công ty công nghệ"
	info(string.format("Mua cổ phần các công ty đối thủ (trụ sở của họ ở ngay trong thành phố). Giá cập nhật mỗi %ds, phí %d%% mỗi lệnh. Bán công ty thì danh mục cũng bị bán theo.", Config.Market.Tick, pct(Config.Market.Fee)), 64)
	local updaters = {}
	for i, stock in Config.Stocks do
		local frame = new("Frame", {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -10, 0, 150),
			BackgroundColor3 = COLORS.card,
			ZIndex = 12,
			Parent = content,
		}, { corner(14) })
		local title = new("TextLabel", {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -24, 0, 44),
			BackgroundTransparency = 1,
			Font = FONT,
			TextSize = 17,
			RichText = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = COLORS.text,
			ZIndex = 13,
			Parent = frame,
		})
		local holding = new("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 54),
			Size = UDim2.new(0.5, -12, 0, 40),
			BackgroundTransparency = 1,
			Font = FONT,
			TextSize = 15,
			RichText = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = COLORS.text,
			ZIndex = 13,
			Parent = frame,
		})
		local drawChart = sparkline(frame, stock.id)
		local buttons = new("Frame", {
			Position = UDim2.new(0, 12, 1, -48),
			Size = UDim2.new(1, -24, 0, 40),
			BackgroundTransparency = 1,
			ZIndex = 13,
			Parent = frame,
		}, {
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
		})
		smallButton(buttons, "Mua 1", COLORS.green, function()
			fire("BuyStock", stock.id, 1)
		end, 80)
		smallButton(buttons, "Mua 10", COLORS.green, function()
			fire("BuyStock", stock.id, 10)
		end, 80)
		smallButton(buttons, "Mua Max", COLORS.green, function()
			fire("BuyStock", stock.id, "max")
		end, 96)
		smallButton(buttons, "Bán hết", COLORS.red, function()
			fire("SellStock", stock.id, "all")
		end, 96)
		updaters[i] = function()
			local price = market.prices[stock.id] or stock.base
			local c = market.changes[stock.id] or 0
			title.Text = string.format(
				"%s <b>%s</b> (%s)   <b>$%.2f</b>  %s",
				stock.emoji,
				stock.name,
				stock.id,
				price,
				if c >= 0 then string.format("<font color='#4CFF7A'>▲ %.1f%%</font>", c * 100) else string.format("<font color='#FF5A5A'>▼ %.1f%%</font>", -c * 100)
			)
			local h = state.stocks and state.stocks[stock.id]
			if h and h.qty > 0 then
				local value = h.qty * price
				local pnl = value - h.cost
				holding.Text = string.format(
					"Đang giữ <b>%d</b> cp = %s\n%s%s</font> (%s%d%%)",
					h.qty,
					money(value),
					if pnl >= 0 then "<font color='#4CFF7A'>+" else "<font color='#FF5A5A'>",
					money(pnl),
					if pnl >= 0 then "+" else "",
					pct(pnl / math.max(1, h.cost))
				)
			else
				holding.Text = "<font color='#AAAACC'>Chưa có cổ phần</font>"
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
	panelTitle.Text = "🎁 Quà đăng nhập 7 ngày"
	local daily = state.daily
	local builtClaimable = daily.claimable
	info("Vào game mỗi ngày để nhận quà to dần. Bỏ lỡ 1 ngày là chuỗi về lại ngày 1!")
	local timerLabel = row("", nil, 50)
	for day, reward in Config.Daily do
		local isDone = (daily.claimable and day < daily.nextDay) or (not daily.claimable and day <= daily.streak)
		local isNext = day == daily.nextDay
		local extra = if reward.boosts then " + 🚀 x2 Doanh thu 30 phút" else ""
		local amountText = if isNext then money(daily.nextAmount) else "≥ " .. money(reward.min)
		local text = string.format("<b>Ngày %d</b>  %s\n<font color='#AAAACC'>%s%s</font>", day, if isDone then "✅" else "", amountText, extra)
		if isNext and daily.claimable then
			row(text, { { "🎁 Nhận", COLORS.pink, function()
				fire("ClaimDaily")
			end } }, 62)
		else
			row(text, nil, 62)
		end
	end
	return function()
		if state.daily.claimable ~= builtClaimable then
			renderPanel()
			return
		end
		timerLabel.Text = if state.daily.claimable then "<b>🎉 Có quà đang chờ bạn!</b>" else string.format("⏳ Quà tiếp theo sau <b>%s</b>", fmtTime(state.daily.resetIn))
	end
end

local sellConfirmUntil = 0
function panels.Sell()
	local rank = Config.CompanyRank(state.sold)
	panelTitle.Text = "💼 Bán công ty • " .. rank.name
	local need = Config.Buildings[Config.Rebirth.RequiredBuilding]
	info(string.format(
		"Bán công ty cho tập đoàn lớn: mất hết tiền, tòa nhà, nhân sự, R&D, xưởng, model, thị trường và cổ phần; lịch quay về năm %d. Đổi lại nhận <b>Điểm Founder</b>: mỗi điểm <b>+%d%% doanh thu và năng suất vĩnh viễn</b>. Cần lên %s %s.",
		Config.Calendar.StartYear,
		pct(Config.Rebirth.FounderBonus),
		need.emoji,
		need.name
	), 100)
	local holdingLabel = row("")
	local projectLabel = row("")
	local _, button = row("<b>Sẵn sàng ký hợp đồng chưa?</b>", { { "🤝 Bán", COLORS.gold, function()
		if os.clock() < sellConfirmUntil then
			sellConfirmUntil = 0
			fire("SellCompany")
		else
			sellConfirmUntil = os.clock() + 4
			toast("⚠️ Bán công ty sẽ reset tất cả! Bấm Bán lần nữa trong 4 giây để xác nhận")
		end
	end } })
	return function()
		holdingLabel.Text = string.format("Đang có: <b>🏅 %d Điểm Founder</b> (x%.1f) • Đã bán %d công ty", state.founderPoints, Config.FounderMultiplier(state.founderPoints), state.sold)
		local ready = state.building >= Config.Rebirth.RequiredBuilding and state.sellPoints >= 1
		local missing = if state.building < Config.Rebirth.RequiredBuilding then string.format("\n<font color='#FF7070'>Cần %s (hiện %s)</font>", need.name, Config.Buildings[state.building].name) else ""
		projectLabel.Text = string.format("Bán bây giờ nhận: <b><font color='#FFD84D'>+%d Điểm Founder</font></b>\n<font color='#AAAACC'>Doanh thu lượt này: %s</font>%s", state.sellPoints, money(state.runEarned), missing)
		local confirming = os.clock() < sellConfirmUntil
		button.Text = if confirming then "Chắc chưa? Bấm lại!" else "🤝 Bán"
		button.BackgroundColor3 = if not ready then COLORS.disabled elseif confirming then COLORS.red else COLORS.gold
	end
end

function panels.Shop()
	panelTitle.Text = "💎 Shop"
	for _, section in Config.ShopSections do
		sectionTitle(section.title)
		for _, item in section.items do
			local kind, key = item[1], item[2]
			if kind == "pass" then
				local pass = Config.GamePasses[key]
				local text = string.format("<b>%s</b>\n<font color='#AAAACC'>%s</font>", pass.name, pass.description)
				if player:GetAttribute(key) == true then
					row(text, { { "✅ Đã có", COLORS.done } }, 78)
				else
					local _, button = row(text, { { "R$ ...", COLORS.robux, function()
						if pass.id == 0 then
							toast("Chưa điền ID Game Pass trong Config.luau 🛠️")
						else
							MarketplaceService:PromptGamePassPurchase(player, pass.id)
						end
					end } }, 78)
					fillRobuxPrice(button, pass.id, Enum.InfoType.GamePass)
				end
			else
				local product = Config.DevProducts[key]
				local extra
				if product.kind == "Skip" then
					extra = string.format("<font color='#AAAACC'>Doanh thu ≈ %s (lương vẫn phải trả)</font>", money((state.revenuePerDay or 0) * product.days))
				elseif product.kind == "Instant" then
					local busy = if product.target == "Research" then state.research.current ~= nil else state.model.dev ~= nil
					extra = if busy then "<font color='#7CFC00'>Đang có việc để xong ngay</font>" else "<font color='#AAAACC'>Chưa có gì đang chạy</font>"
				elseif product.kind == "Hype" then
					extra = string.format("<font color='#AAAACC'>Đang có %d lần Viral</font>", state.model.viral)
				else
					local active = {}
					for boost in product.boosts do
						local left = boostLeft(boost)
						if left > 0 then
							table.insert(active, fmtTime(left))
						end
					end
					extra = if #active > 0 then "<font color='#7CFC00'>Đang chạy: còn " .. table.concat(active, " / ") .. "</font>" else "<font color='#AAAACC'>Mua thêm cộng dồn thời gian</font>"
				end
				local _, button = row("<b>" .. product.name .. "</b>\n" .. extra, { { "R$ ...", COLORS.robux, function()
					if product.id == 0 then
						toast("Chưa điền ID Developer Product trong Config.luau 🛠️")
					else
						MarketplaceService:PromptProductPurchase(player, product.id)
					end
				end } }, 78)
				fillRobuxPrice(button, product.id, Enum.InfoType.Product)
			end
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
			Size = UDim2.fromOffset(142, 50),
			BackgroundColor3 = entry.color,
			BackgroundTransparency = 0.05,
			Font = FONT_BLACK,
			TextSize = 18,
			TextColor3 = COLORS.text,
			Text = entry.text,
			Parent = column,
		}, { corner(14), stroke(COLORS.text, 1.5, 0.7) })
		badges[entry.id] = new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = COLORS.red,
			Font = FONT_BLACK,
			TextSize = 15,
			TextColor3 = COLORS.text,
			Text = "!",
			Visible = false,
			ZIndex = 3,
			Parent = button,
		}, { corner(11) })
		button.MouseButton1Click:Connect(function()
			togglePanel(entry.id)
		end)
	end
end
addMenuButtons(leftMenu, LEFT_MENU)
addMenuButtons(rightMenu, RIGHT_MENU)

-- ================= Popup báo chí chấm điểm =================

local function showReview(data)
	local overlay = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		ZIndex = 60,
		Active = true,
		Parent = gui,
	})
	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 470),
		BackgroundColor3 = COLORS.bg,
		ZIndex = 61,
		Parent = overlay,
	}, { corner(20), stroke(COLORS.gold, 3, 0.2) })
	local list = new("Frame", {
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.new(1, -40, 1, -32),
		BackgroundTransparency = 1,
		ZIndex = 62,
		Parent = card,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	local function line(order, text, size, color, height)
		return new("TextLabel", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, height or 30),
			BackgroundTransparency = 1,
			Font = FONT_BLACK,
			TextSize = size,
			TextWrapped = true,
			RichText = true,
			TextColor3 = color or COLORS.text,
			Text = text,
			ZIndex = 63,
			Parent = list,
		})
	end
	line(1, "📰 BÁO CHÍ CHẤM ĐIỂM", 18, COLORS.gold)
	line(2, string.format("%s %s", data.emoji, data.name), 30, COLORS.text, 40)
	local rows = {}
	for i, review in data.scores do
		rows[i] = line(2 + i, review.name .. ": ...", 20, COLORS.text)
	end
	local avg = line(10, "", 46, COLORS.gold, 54)
	local comment = line(11, "", 18, COLORS.text, 44)
	local sales = line(12, "", 15, Color3.fromRGB(170, 170, 200), 40)
	local close = new("TextButton", {
		LayoutOrder = 13,
		Size = UDim2.fromOffset(200, 46),
		BackgroundColor3 = COLORS.pink,
		Font = FONT_BLACK,
		TextSize = 18,
		TextColor3 = COLORS.text,
		Text = "Tuyệt! 🎉",
		Visible = false,
		ZIndex = 63,
		Parent = list,
	}, { corner(12) })
	close.MouseButton1Click:Connect(function()
		overlay:Destroy()
	end)
	-- lật điểm từng tờ báo cho hồi hộp
	task.spawn(function()
		for i, review in data.scores do
			task.wait(0.6)
			local color = if review.score >= 8 then "#7CFF9A" elseif review.score >= 5 then "#FFE27A" else "#FF8080"
			rows[i].Text = string.format("%s: <font color='%s'>%d/10</font>", review.name, color, review.score)
		end
		task.wait(0.6)
		avg.Text = string.format("⭐ %.1f / 10", data.score)
		comment.Text = "“" .. data.comment .. "”"
		sales.Text = string.format("Giá: %s • %s • độ hot x%.1f\nDự kiến đỉnh ~%s người dùng/ngày", data.price, data.campaign, data.hype, short(data.peak))
		close.Visible = true
		flashScreen(if data.score >= 7 then COLORS.gold else COLORS.red)
	end)
end

-- ================= Nhận dữ liệu từ server =================

local function renderHud()
	if not state then
		return
	end
	dateLabel.Text = "📅 " .. Config.DateText(state.day)
	for index, button in speedButtons do
		local locked = index >= Config.Calendar.FastSpeedIndex and not state.fastUnlocked
		button.BackgroundColor3 = if state.speed == index then COLORS.selected elseif locked then COLORS.disabled else COLORS.card
		button.Text = ({ "⏸", "▶", "⏩", if locked then "🔒" else "⏭" })[index]
	end
	cashLabel.Text = string.format("💵 %s <font size='15' color='#B8FFC8'>+%s/ngày</font>", money(state.cash), money(state.revenuePerDay or 0))
	computeLabel.Text = string.format("⚡ %s <font size='15' color='#FFE9A8'>+%s/ngày</font>", short(state.factory.compute), short(state.factory.perDay))
	if state.cash < 0 then
		cashLabel.TextColor3 = COLORS.red
	else
		cashLabel.TextColor3 = COLORS.green
	end

	local parts = {}
	if state.vip then
		table.insert(parts, "⭐ VIP")
	end
	if state.founderPoints > 0 then
		table.insert(parts, string.format("🏅 x%.1f", Config.FounderMultiplier(state.founderPoints)))
	end
	for _, b in { { "Cash", "💵x2" }, { "Work", "⚡x2" } } do
		local left = boostLeft(b[1])
		if left > 0 then
			table.insert(parts, b[2] .. " " .. fmtTime(left))
		end
	end
	table.insert(parts, string.format("👥 %d/%d", #state.staff + 1, state.capacity))
	statusLabel.Text = table.concat(parts, "  •  ")
	statusLabel.Visible = true

	local work = {}
	if state.research.current then
		local node = Config.ResearchById[state.research.current]
		table.insert(work, string.format("🔬 %s %d%%", node.name, pct(state.research.progress)))
	end
	if state.model.dev then
		table.insert(work, string.format("💻 %s %d%%", state.model.dev.name, pct(state.model.progress)))
	elseif state.model.pending then
		table.insert(work, "🚀 " .. state.model.pending.name .. " chờ ra mắt!")
	end
	workLabel.Text = table.concat(work, "   •   ")
	workLabel.Visible = #work > 0

	-- chấm đỏ nhắc việc
	local nextB = Config.Buildings[state.building + 1]
	badges.Company.Visible = nextB ~= nil and state.runEarned >= nextB.requireEarned and state.cash >= nextB.price
	badges.Research.Visible = state.research.current == nil
	badges.Model.Visible = state.model.pending ~= nil or (state.model.dev == nil and done("Text"))
	badges.Staff.Visible = state.workstations - 1 - #state.staff > 0
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
			toast("👋 Chào mừng tới Garage! Mở 🔬 R&D nghiên cứu 'Xử lý ngôn ngữ', rồi vào 🧠 Model AI làm Chatbot đầu tiên!", 8)
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
	showReview(data)
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
		popText("💰", COLORS.green, UDim2.new(0.5, 0, 0, 140))
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

-- ================= Hiệu ứng (nhân viên nhún, băng chuyền, xe, đèn) =================

Fx.Start(workspace:WaitForChild("Lots"))
Fx.Start(workspace:WaitForChild("City"))

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
