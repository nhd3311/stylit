-- Giao diện người chơi: $ + token, thanh XP, nút gõ code dạo, và các bảng:
-- Xây tầng, Thang máy, R&D, Sản phẩm, Chứng khoán, AI, Quà, Bán công ty, Shop.
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

local function effectText(effect)
	local parts = {}
	local names = {
		gpu = "token từ GPU",
		income = "thu nhập $",
		launch = "tiền ra mắt",
		research = "tốc độ R&D",
		dev = "tốc độ phát triển",
	}
	for key, label in names do
		if effect[key] then
			table.insert(parts, string.format("+%d%% %s", pct(effect[key]), label))
		end
	end
	if effect.unlock then
		local product = Config.ProductById[effect.unlock]
		table.insert(parts, "Mở khoá " .. product.emoji .. " " .. product.name)
	end
	return table.concat(parts, ", ")
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
	BackgroundColor3 = COLORS.red,
	BackgroundTransparency = 1,
	ZIndex = 50,
	Active = false,
	Parent = gui,
})
local function flashScreen(color)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.55
	TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
end

-- ---------- Thanh trên: $ + token, XP, trạng thái ----------
local topBar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 6),
	Size = UDim2.fromOffset(460, 160),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local moneyRow = new("Frame", {
	LayoutOrder = 1,
	Size = UDim2.fromOffset(460, 48),
	BackgroundTransparency = 1,
	Parent = topBar,
}, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8) }),
})

local function pill(color)
	return new("TextLabel", {
		Size = UDim2.fromOffset(226, 48),
		BackgroundColor3 = COLORS.bg,
		BackgroundTransparency = 0.1,
		Font = FONT_BLACK,
		TextSize = 24,
		TextColor3 = color,
		RichText = true,
		Text = "...",
		Parent = moneyRow,
	}, { corner(24), stroke(color, 2, 0.4) })
end
local cashLabel = pill(COLORS.green)
local tokenLabel = pill(COLORS.gold)

local xpBar = new("Frame", {
	LayoutOrder = 2,
	Size = UDim2.fromOffset(400, 28),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 0.1,
	ClipsDescendants = true,
	Parent = topBar,
}, { corner(14), stroke(COLORS.purple, 2, 0.4) })
local xpFill = new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	Parent = xpBar,
}, { corner(14), gradient(COLORS.purple, COLORS.cyan) })
local xpLabel = new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 17,
	TextColor3 = COLORS.text,
	TextStrokeTransparency = 0.4,
	ZIndex = 2,
	Parent = xpBar,
})

local statusLabel = new("TextLabel", {
	LayoutOrder = 3,
	Size = UDim2.fromOffset(460, 26),
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
	Size = UDim2.fromOffset(460, 26),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 0.25,
	Font = FONT,
	TextSize = 15,
	TextColor3 = COLORS.text,
	Visible = false,
	Parent = topBar,
}, { corner(13) })

local carryBanner = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 175),
	Size = UDim2.fromOffset(470, 44),
	BackgroundColor3 = COLORS.pink,
	Font = FONT_BLACK,
	TextSize = 19,
	TextColor3 = COLORS.text,
	Visible = false,
	Parent = gui,
}, { corner(22), gradient(COLORS.pink, COLORS.purple) })

local toastLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 225),
	Size = UDim2.fromOffset(520, 48),
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
	task.delay(seconds or 3, function()
		if version == toastVersion then
			TweenService:Create(toastLabel, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		end
	end)
end

-- ---------- Nút gõ code dạo (bên phải, cao hơn nút nhảy) ----------
local codeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -24, 0.64, 0),
	Size = UDim2.fromOffset(124, 124),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Font = FONT_BLACK,
	TextSize = 20,
	TextColor3 = COLORS.text,
	TextStrokeTransparency = 0.5,
	TextWrapped = true,
	Text = "💻\nCODE DẠO",
	Parent = gui,
}, { corner(62), gradient(COLORS.green, COLORS.cyan, 45), stroke(COLORS.text, 3, 0.5) })

local function popText(text, color, origin)
	local pop = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = origin or UDim2.new(1, -86 + math.random(-40, 40), 0.64, -90),
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
	codeButton.Size = UDim2.fromOffset(114, 114)
	TweenService:Create(codeButton, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(124, 124) }):Play()
end)

-- ---------- Menu ----------
local LEFT_MENU = {
	{ id = "Build", text = "🏗️ Xây", color = COLORS.gold },
	{ id = "Elevator", text = "🛗 Thang máy", color = COLORS.card },
	{ id = "Research", text = "🔬 R&D", color = COLORS.blue },
	{ id = "Products", text = "🚀 Sản phẩm", color = COLORS.pink },
	{ id = "Stocks", text = "📈 Cổ phiếu", color = COLORS.green },
	{ id = "AI", text = "🧠 AI", color = COLORS.purple },
}
local RIGHT_MENU = {
	{ id = "Daily", text = "🎁 Quà", color = COLORS.pink },
	{ id = "Sell", text = "💼 Bán cty", color = COLORS.card },
	{ id = "Shop", text = "💎 Shop", color = COLORS.robux },
}

local function menuColumn(anchor, position, count)
	return new("Frame", {
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(138, count * 56),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
end
local leftMenu = menuColumn(Vector2.new(0, 0.5), UDim2.new(0, 12, 0.45, 0), #LEFT_MENU)
local rightMenu = menuColumn(Vector2.new(1, 0), UDim2.new(1, -12, 0, 64), #RIGHT_MENU)

local badges = {}

-- ---------- Bảng giữa màn hình ----------
local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.56),
	Size = UDim2.new(0, 560, 0.7, 0),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 0.04,
	Visible = false,
	ZIndex = 10,
	Parent = gui,
}, {
	corner(20),
	stroke(COLORS.cyan, 2, 0.35),
	new("UISizeConstraint", { MaxSize = Vector2.new(560, 620), MinSize = Vector2.new(300, 280) }),
})

local panelTitle = new("TextLabel", {
	Position = UDim2.fromOffset(18, 10),
	Size = UDim2.new(1, -80, 0, 40),
	BackgroundTransparency = 1,
	Font = FONT_BLACK,
	TextSize = 25,
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

local function sectionTitle(order, text)
	new("TextLabel", {
		LayoutOrder = order,
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

-- Một dòng: chữ bên trái + nút bên phải (nút có thể không có). Trả về button, label, frame.
local function row(order, text, buttonText, buttonColor, onClick, height)
	local frame = new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -10, 0, height or 72),
		BackgroundColor3 = COLORS.card,
		ZIndex = 12,
		Parent = content,
	}, { corner(14) })
	local label = new("TextLabel", {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, if buttonText then -170 else -28, 1, 0),
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
	if not buttonText then
		return nil, label, frame
	end
	local button = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(144, 48),
		BackgroundColor3 = buttonColor or COLORS.cyan,
		AutoButtonColor = onClick ~= nil,
		Font = FONT_BLACK,
		TextSize = 16,
		TextColor3 = COLORS.text,
		TextWrapped = true,
		Text = buttonText,
		ZIndex = 13,
		Parent = frame,
	}, { corner(12) })
	if onClick then
		button.MouseButton1Click:Connect(onClick)
	end
	return button, label, frame
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
-- Mỗi bảng dựng khung 1 lần và có thể trả về hàm update để đổi chữ tại chỗ mỗi giây
-- (không vẽ lại cả bảng vì sẽ làm trượt cú bấm nút). Khi cấu trúc đổi (xây xong tầng,
-- nghiên cứu xong...) hàm update tự gọi renderPanel() để dựng lại.

local panels = {}
local panelUpdate = nil
local renderPanel

local function hasFloor(index)
	local floor = Config.Floors[index]
	if floor.vip then
		return state.vip
	end
	return index <= state.floorsBuilt
end

function panels.Build()
	panelTitle.Text = "🏗️ Xây tòa nhà"
	local builtSig = state.floorsBuilt .. tostring(state.vip)
	row(0, "<font color='#AAAACC'>Xây từng tầng từ dưới lên. Mỗi tầng mở khoá chức năng mới cho công ty.</font>", nil, nil, nil, 56)
	for index, floor in Config.Floors do
		local desc = floor.desc
			or (if floor.racks then string.format("%d kệ máy chủ", floor.racks) else nil)
			or ({ Lab = "Nghiên cứu R&D + lõi AI", Studio = "Phát triển & ra mắt sản phẩm" })[floor.kind]
			or ""
		local text = string.format("%s <b>Tầng %s: %s</b>\n<font color='#AAAACC'>%s</font>", floor.emoji, if floor.vip then "VIP" else tostring(index), floor.name, desc)
		if hasFloor(index) then
			row(index, text, "✅ Đã xây", Color3.fromRGB(60, 110, 80))
		elseif floor.vip then
			row(index, text, "⭐ Cần VIP", COLORS.robux, function()
				openPanel = "Shop"
				renderPanel()
			end)
		elseif index == state.floorsBuilt + 1 then
			row(index, text, "Xây " .. money(floor.price), COLORS.gold, function()
				fire("BuildFloor")
			end)
		else
			row(index, text, "🔒 " .. money(floor.price), COLORS.disabled)
		end
	end
	return function()
		if state.floorsBuilt .. tostring(state.vip) ~= builtSig then
			renderPanel()
		end
	end
end

function panels.Elevator()
	panelTitle.Text = "🛗 Thang máy"
	local sig = state.floorsBuilt .. tostring(state.vip)
	row(0, "🏠 <b>Sân trước tòa nhà</b>", "Đi", COLORS.cyan, function()
		fire("Home")
		openPanel = nil
		renderPanel()
	end)
	-- tầng cao nhất ở trên cùng như bảng thang máy thật
	for index = #Config.Floors, 1, -1 do
		local floor = Config.Floors[index]
		if hasFloor(index) then
			row(#Config.Floors - index + 1, string.format("%s <b>%s</b>", floor.emoji, floor.name), if floor.vip then "⭐ Lên" else "Tầng " .. index, COLORS.blue, function()
				fire("Elevator", index)
				openPanel = nil
				renderPanel()
			end, 60)
		end
	end
	return function()
		if state.floorsBuilt .. tostring(state.vip) ~= sig then
			renderPanel()
		end
	end
end

function panels.Research()
	panelTitle.Text = "🔬 Nghiên cứu R&D"
	local r = state.research
	local doneCount = 0
	for _ in r.done do
		doneCount += 1
	end
	local sig = string.format("%s|%d|%s", tostring(r.current), doneCount, tostring(r.hasLab))
	if not r.hasLab then
		row(0, "🔒 Cần xây tầng <b>🔬 Lab R&D</b> trước", "🏗️ Xây", COLORS.gold, function()
			openPanel = "Build"
			renderPanel()
		end)
	end
	local _, currentLabel = row(1, "")
	for i, node in Config.Research do
		local reqNames = {}
		local ready = true
		for _, req in node.requires do
			if not r.done[req] then
				ready = false
				table.insert(reqNames, Config.ResearchById[req].name)
			end
		end
		local text = string.format("%s <b>%s</b>\n<font color='#9FE2FF'>%s</font>\n<font color='#AAAACC'>🪙 %s • ⏱️ %s</font>", node.emoji, node.name, effectText(node.effect), short(node.cost), fmtTime(node.time))
		if r.done[node.id] then
			row(i + 1, text, "✅ Xong", Color3.fromRGB(60, 110, 80), nil, 86)
		elseif r.current == node.id then
			row(i + 1, text, "⏳ Đang làm", COLORS.blue, nil, 86)
		elseif not ready then
			row(i + 1, text .. "\n<font color='#FF8080'>Cần: " .. table.concat(reqNames, ", ") .. "</font>", "🔒", COLORS.disabled, nil, 100)
		else
			local button = row(i + 1, text, "Nghiên cứu", COLORS.blue, function()
				fire("StartResearch", node.id)
			end, 86)
			button:SetAttribute("TokenCost", node.cost)
		end
	end
	return function()
		local rr = state.research
		local count = 0
		for _ in rr.done do
			count += 1
		end
		if string.format("%s|%d|%s", tostring(rr.current), count, tostring(rr.hasLab)) ~= sig then
			renderPanel()
			return
		end
		if rr.current then
			local node = Config.ResearchById[rr.current]
			currentLabel.Text = string.format("⏳ Đang nghiên cứu <b>%s %s</b>: %d%%  (còn %s)", node.emoji, node.name, pct(rr.progress), fmtTime(rr.remaining))
		else
			currentLabel.Text = "<font color='#AAAACC'>Lab đang rảnh. Chọn 1 công nghệ để nghiên cứu (trả bằng 🪙 token).</font>"
		end
		-- tô xám nút khi chưa đủ token
		for _, child in content:GetDescendants() do
			local cost = child:IsA("TextButton") and child:GetAttribute("TokenCost")
			if cost then
				child.BackgroundColor3 = if state.tokens >= cost and not rr.current then COLORS.blue else COLORS.disabled
			end
		end
	end
end

function panels.Products()
	panelTitle.Text = "🚀 Sản phẩm AI"
	local p = state.products
	local function sigOf(pp)
		local parts = { tostring(pp.dev and (pp.dev.id .. pp.dev.version)), tostring(pp.hasStudio) }
		for _, product in Config.Products do
			table.insert(parts, tostring(pp.versions[product.id] or 0) .. tostring(pp.unlocked[product.id]))
		end
		return table.concat(parts, "|")
	end
	local sig = sigOf(p)
	if not p.hasStudio then
		row(0, "🔒 Cần xây tầng <b>🚀 Studio Sản Phẩm</b> trước", "🏗️ Xây", COLORS.gold, function()
			openPanel = "Build"
			renderPanel()
		end)
	end
	local _, currentLabel = row(1, "")
	for i, product in Config.Products do
		local version = p.versions[product.id] or 0
		local nextVersion = version + 1
		local current = if version > 0 then Config.ProductVersion(product, version) else nil
		local incomeText = if current
			then string.format("Đang bán v%d: <font color='#7CFF9A'>%s/giây</font>", version, money(current.income * p.cashMult))
			else "<font color='#AAAACC'>Chưa ra mắt</font>"
		local text, buttonText, color, onClick
		if nextVersion > Config.ProductVersions.Max then
			text = string.format("%s <b>%s</b>\n%s", product.emoji, product.name, incomeText)
			buttonText, color = "🔥 Bản cuối", Color3.fromRGB(60, 110, 80)
		else
			local spec = Config.ProductVersion(product, nextVersion)
			text = string.format(
				"%s <b>%s</b>\n%s\n<font color='#AAAACC'>v%d: 🪙 %s • ⏱️ %s • ra mắt +%s • %s/giây</font>",
				product.emoji,
				product.name,
				incomeText,
				nextVersion,
				short(spec.devTokens),
				fmtTime(spec.devTime),
				money(spec.launchCash * p.launchMult),
				money(spec.income * p.cashMult)
			)
			if not p.unlocked[product.id] then
				local research = Config.ResearchById[Config.ProductUnlockedBy[product.id]]
				buttonText, color = "🔒 " .. research.name, COLORS.disabled
				onClick = function()
					openPanel = "Research"
					renderPanel()
				end
			elseif p.dev and p.dev.id == product.id then
				buttonText, color = "⏳ Đang làm", COLORS.pink
			else
				buttonText, color = if version == 0 then "Phát triển" else "Lên v" .. nextVersion, COLORS.pink
				onClick = function()
					fire("StartProduct", product.id)
				end
			end
		end
		row(i + 1, text, buttonText, color, onClick, 100)
	end
	return function()
		local pp = state.products
		if sigOf(pp) ~= sig then
			renderPanel()
			return
		end
		if pp.dev then
			local product = Config.ProductById[pp.dev.id]
			currentLabel.Text = string.format("💻 Đang phát triển <b>%s %s v%d</b>: %d%%  (còn %s)", product.emoji, product.name, pp.dev.version, pct(pp.progress), fmtTime(pp.remaining))
		else
			currentLabel.Text = string.format("<font color='#AAAACC'>Studio đang rảnh. Thu nhập sản phẩm: <b>%s/giây</b></font>", money(state.cashRate))
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
				bar.BackgroundColor3 = if i > 1 and h[n - 24 + i - 1] and value < h[n - 24 + i - 1] then COLORS.red else COLORS.green
				bar.Visible = true
			else
				bar.Visible = false
			end
		end
	end
end

function panels.Stocks()
	panelTitle.Text = "📈 Sàn chứng khoán"
	row(0, string.format("<font color='#AAAACC'>Mua thấp bán cao! Giá cập nhật mỗi %ds, phí %d%% mỗi lệnh. Bán công ty thì danh mục cũng bị bán theo.</font>", Config.Market.Tick, pct(Config.Market.Fee)), nil, nil, nil, 56)
	local updaters = {}
	for i, stock in Config.Stocks do
		local frame = new("Frame", {
			LayoutOrder = i,
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
				holding.Text = string.format("Đang giữ <b>%d</b> cp = %s\n%s%s (%s%d%%)", h.qty, money(value), if pnl >= 0 then "<font color='#4CFF7A'>+" else "<font color='#FF5A5A'>", money(pnl) .. "</font>", if pnl >= 0 then "+" else "", pct(pnl / math.max(1, h.cost)))
			else
				holding.Text = "<font color='#AAAACC'>Chưa có cổ phiếu</font>"
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
	sectionTitle(3, "Đổ 🪙 token vào để train AI")
	local fractions = { 0.1, 0.5, 1 }
	local trainRows = {}
	for i, fraction in fractions do
		local button, label = row(3 + i, "", "🧠 Train", COLORS.purple, function()
			fire("Train", fraction)
		end)
		trainRows[i] = { button = button, label = label }
	end
	return function()
		if state.level ~= builtLevel then
			renderPanel()
			return
		end
		infoLabel.Text = string.format(
			"XP: <b>%s / %s</b>\nMỗi level <font color='#7CFC00'>+%d%%</font> cả $ lẫn token (hiện +%d%%)%s",
			short(state.xp),
			short(state.xpNext),
			pct(Config.AI.BonusPerLevel),
			pct(Config.LevelMultiplier(state.level) - 1),
			if state.trainBonus > 1 then "\n🧠 Trung Tâm AI: train x" .. state.trainBonus else ""
		)
		for i, fraction in fractions do
			local amount = math.floor(state.tokens * fraction)
			trainRows[i].label.Text = string.format("Train bằng <b>%d%%</b> token\n<font color='#AAAACC'>+%s XP</font>", pct(fraction), short(amount * state.trainBonus))
			trainRows[i].button.BackgroundColor3 = if amount >= 1 then COLORS.purple else COLORS.disabled
		end
	end
end

function panels.Daily()
	panelTitle.Text = "🎁 Quà đăng nhập 7 ngày"
	local daily = state.daily
	local builtClaimable = daily.claimable
	row(0, "<font color='#AAAACC'>Vào game mỗi ngày để nhận quà to dần. Bỏ lỡ 1 ngày là chuỗi về lại ngày 1!</font>", nil, nil, nil, 56)
	local _, timerLabel = row(1, "", nil, nil, nil, 50)
	for day, reward in Config.Daily do
		local done = (daily.claimable and day < daily.nextDay) or (not daily.claimable and day <= daily.streak)
		local isNext = day == daily.nextDay
		local extra = if reward.boosts then " + 🚀 x2 Tiền 30 phút" else ""
		local amountText = if isNext then money(daily.nextAmount) else "≥ " .. money(reward.min)
		local text = string.format("<b>Ngày %d</b>  %s\n<font color='#AAAACC'>%s%s</font>", day, if done then "✅" else "", amountText, extra)
		if isNext and daily.claimable then
			row(day + 1, text, "🎁 Nhận", COLORS.pink, function()
				fire("ClaimDaily")
			end, 62)
		else
			row(day + 1, text, nil, nil, nil, 62)
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
	local need = Config.Floors[Config.Rebirth.RequiredFloor]
	row(
		0,
		string.format(
			"<font color='#AAAACC'>Bán công ty cho tập đoàn lớn: mất hết tiền, token, tòa nhà, GPU, AI, R&D, sản phẩm và cổ phiếu. Đổi lại nhận <b>Điểm Founder</b>, mỗi điểm <b>+%d%% thu nhập vĩnh viễn</b>. Cần xây tới %s %s.</font>",
			pct(Config.Rebirth.FounderBonus),
			need.emoji,
			need.name
		),
		nil,
		nil,
		nil,
		96
	)
	local _, holdingLabel = row(1, "")
	local _, projectLabel = row(2, "")
	local button = row(3, "<b>Sẵn sàng ký hợp đồng chưa?</b>", "🤝 Bán", COLORS.gold, function()
		if os.clock() < sellConfirmUntil then
			sellConfirmUntil = 0
			fire("SellCompany")
		else
			sellConfirmUntil = os.clock() + 4
			toast("⚠️ Bán công ty sẽ reset tất cả! Bấm Bán lần nữa trong 4 giây để xác nhận")
		end
	end)
	return function()
		holdingLabel.Text = string.format("Đang có: <b>🏅 %d Điểm Founder</b> (thu nhập x%.1f) • Đã bán %d công ty", state.founderPoints, Config.FounderMultiplier(state.founderPoints), state.sold)
		local ready = state.floorsBuilt >= Config.Rebirth.RequiredFloor and state.sellPoints >= 1
		local missing = if state.floorsBuilt < Config.Rebirth.RequiredFloor then string.format("\n<font color='#FF7070'>Cần xây tới tầng %d (hiện %d)</font>", Config.Rebirth.RequiredFloor, state.floorsBuilt) else ""
		projectLabel.Text = string.format("Bán bây giờ nhận: <b><font color='#FFD84D'>+%d Điểm Founder</font></b>\n<font color='#AAAACC'>$ kiếm được lượt này: %s</font>%s", state.sellPoints, money(state.runEarned), missing)
		local confirming = os.clock() < sellConfirmUntil
		button.Text = if confirming then "Chắc chưa? Bấm lại!" else "🤝 Bán"
		button.BackgroundColor3 = if not ready then COLORS.disabled elseif confirming then COLORS.red else COLORS.gold
	end
end

function panels.Shop()
	panelTitle.Text = "💎 Shop"
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	for _, section in Config.ShopSections do
		sectionTitle(nextOrder(), section.title)
		for _, item in section.items do
			local kind, key = item[1], item[2]
			if kind == "pass" then
				local pass = Config.GamePasses[key]
				local text = string.format("<b>%s</b>\n<font color='#AAAACC'>%s</font>", pass.name, pass.description)
				if player:GetAttribute(key) == true then
					row(nextOrder(), text, "✅ Đã có", Color3.fromRGB(60, 110, 80), nil, 78)
				else
					local button = row(nextOrder(), text, "R$ ...", COLORS.robux, function()
						promptPass(pass)
					end, 78)
					fillRobuxPrice(button, pass.id, Enum.InfoType.GamePass)
				end
			else
				local product = Config.DevProducts[key]
				local extra
				if product.kind == "TimeWarp" then
					extra = string.format("<font color='#AAAACC'>Nhận ngay ≈ %s + %s 🪙</font>", money(state.cashRate * product.hours * 3600), short(state.tokenRate * product.hours * 3600))
				elseif product.kind == "Instant" then
					local busy = if product.target == "Research" then state.research.current ~= nil else state.products.dev ~= nil
					extra = if busy then "<font color='#7CFC00'>Đang có việc để làm xong ngay</font>" else "<font color='#AAAACC'>Chưa có gì đang chạy</font>"
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
				local button = row(nextOrder(), "<b>" .. product.name .. "</b>\n" .. extra, "R$ ...", COLORS.robux, function()
					promptProduct(product)
				end, 78)
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
			Size = UDim2.fromOffset(138, 50),
			BackgroundColor3 = entry.color,
			BackgroundTransparency = 0.05,
			Font = FONT_BLACK,
			TextSize = 19,
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

-- ================= Nhận dữ liệu từ server =================

local function renderHud()
	if not state then
		return
	end
	cashLabel.Text = string.format("💵 %s <font size='16' color='#B8FFC8'>+%s/s</font>", money(state.cash), money(state.cashRate))
	tokenLabel.Text = string.format("🪙 %s <font size='16' color='#FFE9A8'>+%s/s</font>", short(state.tokens), short(state.tokenRate))

	local stage = Config.StageFor(state.level)
	local ratio = if state.xpNext > 0 then math.clamp(state.xp / state.xpNext, 0, 1) else 1
	xpFill.Size = UDim2.fromScale(ratio, 1)
	xpLabel.Text = string.format("%s %s • Lv.%d  (%d%%)", stage.emoji, stage.name, state.level, pct(ratio))

	local parts = {}
	if state.vip then
		table.insert(parts, "⭐ VIP")
	end
	if state.founderPoints > 0 then
		table.insert(parts, string.format("🏅 x%.1f", Config.FounderMultiplier(state.founderPoints)))
	end
	for _, b in { { "Cash", "💵x2" }, { "Tokens", "🪙x2" }, { "Research", "🔬x2" }, { "Shield", "🛡️" } } do
		local left = boostLeft(b[1])
		if left > 0 then
			table.insert(parts, b[2] .. " " .. fmtTime(left))
		end
	end
	if not state.autoCollect and state.buffered >= 1 then
		table.insert(parts, "📦 " .. short(state.buffered) .. " 🪙 chờ thu")
	end
	statusLabel.Text = table.concat(parts, "  •  ")
	statusLabel.Visible = #parts > 0

	local work = {}
	if state.research and state.research.current then
		local node = Config.ResearchById[state.research.current]
		table.insert(work, string.format("🔬 %s %d%%", node.name, pct(state.research.progress)))
	end
	if state.products and state.products.dev then
		local product = Config.ProductById[state.products.dev.id]
		table.insert(work, string.format("🚀 %s v%d %d%%", product.name, state.products.dev.version, pct(state.products.progress)))
	end
	workLabel.Text = table.concat(work, "   •   ")
	workLabel.Visible = #work > 0

	local carrying = state.carrying or 0
	carryBanner.Visible = carrying > 0
	if carrying > 0 then
		carryBanner.Text = string.format("💾 Đang ôm %d ổ (+%s) → chạy về Máy thu token ở sảnh nhà mình!", carrying, money(state.carryValue))
	end

	-- chấm đỏ nhắc việc
	badges.Daily.Visible = state.daily ~= nil and state.daily.claimable
	badges.Sell.Visible = state.floorsBuilt >= Config.Rebirth.RequiredFloor and (state.sellPoints or 0) >= 1
	local nextFloor = Config.Floors[state.floorsBuilt + 1]
	badges.Build.Visible = nextFloor ~= nil and not nextFloor.vip and state.cash >= nextFloor.price
	badges.Research.Visible = state.research ~= nil and state.research.hasLab and state.research.current == nil
	badges.Products.Visible = state.products ~= nil and state.products.hasStudio and state.products.dev == nil
end

remotes.State.OnClientEvent:Connect(function(newState)
	local first = state == nil
	state = newState
	renderHud()
	if panelUpdate then
		panelUpdate()
	end
	if first and state.daily and state.daily.claimable then
		openPanel = "Daily"
		renderPanel()
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

remotes.Notify.OnClientEvent:Connect(function(message, action)
	if message ~= "" then
		toast(message, if action == "News" then 5 else 3)
	end
	if type(action) == "string" and action:sub(1, 5) == "Open:" then
		local name = action:sub(6)
		if panels[name] then
			openPanel = name
			renderPanel()
		end
	elseif action == "LevelUp" then
		flashScreen(COLORS.purple)
	elseif action == "Evolve" then
		flashScreen(COLORS.gold)
	elseif action == "Alarm" then
		flashScreen(COLORS.red)
		task.delay(0.35, flashScreen, COLORS.red)
	elseif action == "Collect" then
		popText("💰", COLORS.green, UDim2.new(0.5, 0, 0, 130))
	elseif action == "Heist" then
		flashScreen(COLORS.pink)
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

-- ================= Nút E: của mình / của người khác =================

local lotsFolder = workspace:WaitForChild("Lots")

local function applyPrompt(lot, prompt)
	local owner = lot:GetAttribute("OwnerUserId")
	local mine = owner == player.UserId
	if prompt:GetAttribute("ForOthers") then
		prompt.Enabled = not mine and owner ~= 0
		prompt.HoldDuration = if player:GetAttribute("MasterThief") then Config.Heist.MasterStealHold else Config.Heist.StealHold
	else
		prompt.Enabled = mine
	end
end

local function applyOwnership(lot)
	for _, inst in lot:GetDescendants() do
		if inst:IsA("ProximityPrompt") then
			applyPrompt(lot, inst)
		end
	end
end

local function watchLot(lot)
	applyOwnership(lot)
	lot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		applyOwnership(lot)
	end)
	lot.DescendantAdded:Connect(function(inst)
		if inst:IsA("ProximityPrompt") then
			applyPrompt(lot, inst)
		end
	end)
end
for _, lot in lotsFolder:GetChildren() do
	watchLot(lot)
end
lotsFolder.ChildAdded:Connect(watchLot)
player:GetAttributeChangedSignal("MasterThief"):Connect(function()
	for _, lot in lotsFolder:GetChildren() do
		applyOwnership(lot)
	end
end)

Fx.Start(lotsFolder)
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
