-- Giao diện người chơi: token, thanh XP, nút gõ code, train AI, GPU, quà đăng nhập, IPO,
-- shop Robux, cảnh báo bị trộm. Toàn bộ UI dựng bằng code, tự co giãn theo màn hình
-- (nút to, chữ to, tránh nút nhảy và joystick trên điện thoại).

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
local openPanel = nil -- "AI" | "Gpu" | "Daily" | "Ipo" | "Shop" | nil

local FONT = Enum.Font.BuilderSansBold
local FONT_BLACK = Enum.Font.BuilderSansExtraBold
local COLORS = {
	bg = Color3.fromRGB(14, 14, 28),
	card = Color3.fromRGB(30, 30, 52),
	cyan = Color3.fromRGB(0, 210, 255),
	purple = Color3.fromRGB(160, 80, 255),
	pink = Color3.fromRGB(255, 70, 170),
	gold = Color3.fromRGB(255, 205, 60),
	green = Color3.fromRGB(60, 220, 120),
	red = Color3.fromRGB(255, 70, 80),
	robux = Color3.fromRGB(0, 180, 110),
	disabled = Color3.fromRGB(75, 75, 95),
	text = Color3.fromRGB(245, 245, 255),
	muted = Color3.fromRGB(170, 170, 200),
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

local function fmtTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
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

-- ================= Khung UI chính =================

local gui = new("ScreenGui", {
	Name = "TycoonUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets, -- né tai thỏ / thanh hệ thống
})

-- Co giãn toàn bộ UI theo màn hình: máy tính ~1, điện thoại nhỏ hơn nhưng không quá bé
local uiScale = new("UIScale", { Parent = gui })
local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local size = camera.ViewportSize
	uiScale.Scale = math.clamp(math.min(size.X / 1150, size.Y / 680), 0.7, 1.15)
end
updateScale()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

-- Màn hình chớp màu (đỏ khi bị trộm, vàng khi tiến hoá...)
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

-- ---------- Thanh trên ----------
local topBar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 6),
	Size = UDim2.fromOffset(380, 150),
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
	Size = UDim2.fromOffset(300, 50),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 0.1,
	Font = FONT_BLACK,
	TextSize = 30,
	TextColor3 = COLORS.gold,
	RichText = true,
	Text = "🪙 ...",
	Parent = topBar,
}, { corner(25), stroke(COLORS.gold, 2, 0.4) })

local xpBar = new("Frame", {
	LayoutOrder = 2,
	Size = UDim2.fromOffset(380, 32),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 0.1,
	ClipsDescendants = true,
	Parent = topBar,
}, { corner(16), stroke(COLORS.purple, 2, 0.4) })
local xpFill = new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	Parent = xpBar,
}, { corner(16), gradient(COLORS.purple, COLORS.cyan) })
local xpLabel = new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 18,
	TextColor3 = COLORS.text,
	TextStrokeTransparency = 0.4,
	ZIndex = 2,
	Text = "🤖 AI Lv.1",
	Parent = xpBar,
})

local statusLabel = new("TextLabel", {
	LayoutOrder = 3,
	Size = UDim2.fromOffset(380, 28),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 0.25,
	Font = FONT,
	TextSize = 16,
	TextColor3 = COLORS.cyan,
	Text = "",
	Visible = false,
	Parent = topBar,
}, { corner(14) })

-- Băng rôn khi đang ôm ổ dữ liệu trộm được
local carryBanner = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 165),
	Size = UDim2.fromOffset(460, 44),
	BackgroundColor3 = COLORS.pink,
	Font = FONT_BLACK,
	TextSize = 20,
	TextColor3 = COLORS.text,
	Text = "",
	Visible = false,
	Parent = gui,
}, { corner(22), gradient(COLORS.pink, COLORS.purple) })

local toastLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 215),
	Size = UDim2.fromOffset(480, 46),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 19,
	TextColor3 = COLORS.text,
	TextTransparency = 1,
	TextWrapped = true,
	Text = "",
	ZIndex = 40,
	Parent = gui,
}, { corner(14) })

local toastVersion = 0
local function toast(message)
	toastVersion += 1
	local version = toastVersion
	toastLabel.Text = message
	toastLabel.TextTransparency = 0
	toastLabel.BackgroundTransparency = 0.1
	task.delay(3, function()
		if version == toastVersion then
			TweenService:Create(toastLabel, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		end
	end)
end

-- ---------- Nút gõ code (bên phải, cao hơn nút nhảy của điện thoại) ----------
local codeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -24, 0.5, 0),
	Size = UDim2.fromOffset(130, 130),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Font = FONT_BLACK,
	TextSize = 22,
	TextColor3 = COLORS.text,
	TextStrokeTransparency = 0.5,
	TextWrapped = true,
	Text = "💻\nGÕ CODE",
	Parent = gui,
}, { corner(65), gradient(COLORS.cyan, COLORS.purple, 45), stroke(COLORS.text, 3, 0.5) })

local function popText(text, color, origin)
	local pop = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = origin or UDim2.new(1, -89 + math.random(-40, 40), 0.5, -90),
		Size = UDim2.fromOffset(160, 34),
		BackgroundTransparency = 1,
		Font = FONT_BLACK,
		TextSize = 26,
		TextColor3 = color or COLORS.gold,
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
		popText("+" .. short(state.clickTokens))
	end
	codeButton.Size = UDim2.fromOffset(120, 120)
	TweenService:Create(codeButton, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(130, 130) }):Play()
end)

-- ---------- Menu bên trái ----------
local MENU = {
	{ id = "AI", text = "🧠 AI", color = COLORS.purple },
	{ id = "Gpu", text = "🖥️ GPU", color = COLORS.card },
	{ id = "Daily", text = "🎁 Quà", color = COLORS.pink },
	{ id = "Ipo", text = "📈 IPO", color = COLORS.card },
	{ id = "Shop", text = "💎 Shop", color = COLORS.robux },
}

local menu = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.45, 0),
	Size = UDim2.fromOffset(130, #MENU * 60),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local badges = {}

-- ---------- Bảng (panel) giữa màn hình ----------
local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.new(0, 520, 0.68, 0),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 0.05,
	Visible = false,
	ZIndex = 10,
	Parent = gui,
}, {
	corner(20),
	stroke(COLORS.cyan, 2, 0.35),
	new("UISizeConstraint", { MaxSize = Vector2.new(520, 600), MinSize = Vector2.new(300, 280) }),
})

local panelTitle = new("TextLabel", {
	Position = UDim2.fromOffset(18, 10),
	Size = UDim2.new(1, -80, 0, 40),
	BackgroundTransparency = 1,
	Font = FONT_BLACK,
	TextSize = 26,
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
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.gold,
		Text = text,
		ZIndex = 12,
		Parent = content,
	})
end

-- Một dòng: chữ bên trái + nút bên phải (nút có thể không có). Trả về button, label.
local function row(order, text, buttonText, buttonColor, onClick, height)
	local frame = new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -10, 0, height or 70),
		BackgroundColor3 = COLORS.card,
		ZIndex = 12,
		Parent = content,
	}, { corner(14) })
	local label = new("TextLabel", {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, if buttonText then -168 else -28, 1, 0),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 17,
		TextWrapped = true,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.text,
		Text = text,
		ZIndex = 13,
		Parent = frame,
	})
	if not buttonText then
		return nil, label
	end
	local button = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(140, 48), -- nút to cho ngón tay
		BackgroundColor3 = buttonColor or COLORS.cyan,
		AutoButtonColor = onClick ~= nil,
		Font = FONT_BLACK,
		TextSize = 17,
		TextColor3 = COLORS.text,
		TextWrapped = true,
		Text = buttonText,
		ZIndex = 13,
		Parent = frame,
	}, { corner(12) })
	if onClick then
		button.MouseButton1Click:Connect(onClick)
	end
	return button, label
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
-- Mỗi bảng dựng khung 1 lần và (tuỳ chọn) trả về hàm update để đổi chữ tại chỗ mỗi giây.
-- Không vẽ lại cả bảng mỗi giây vì sẽ làm trượt cú bấm nút.

local panels = {}
local panelUpdate = nil
local renderPanel

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
				"Train bằng <b>%d%%</b> token\n<font color='#AAAACC'>+%s XP</font>%s",
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
	row(0, "<font color='#AAAACC'>Đi tới kệ máy chủ, bấm <b>E</b> để lắp/nâng cấp. Token gom về <b>Máy thu token</b>.</font>")
	local levelMult = Config.LevelMultiplier(state.level)
	for i, gpu in Config.Gpus do
		local unlocked = state.level >= gpu.level
		row(
			i,
			string.format(
				"%s <b>%s</b>  %s/s\n<font color='#AAAACC'>Giá %s token • %s</font>",
				gpu.emoji,
				gpu.name,
				short(gpu.rate * levelMult),
				short(gpu.price),
				if unlocked then "✅ Đã mở khoá" else "🔒 Cần AI Lv." .. gpu.level
			)
		)
	end
end

function panels.Daily()
	panelTitle.Text = "🎁 Quà đăng nhập 7 ngày"
	local daily = state.daily
	local builtClaimable = daily.claimable
	row(0, "<font color='#AAAACC'>Vào game mỗi ngày để nhận quà to dần. Bỏ lỡ 1 ngày là chuỗi về lại ngày 1!</font>")
	local _, timerLabel = row(1, "")
	for day, reward in Config.Daily do
		local done = (daily.claimable and day < daily.nextDay) or (not daily.claimable and day <= daily.streak)
		local isNext = day == daily.nextDay
		local extra = if reward.boosts then " + 🚀 x2 Token 30 phút" else ""
		local amountText = if isNext then short(daily.nextAmount) else "≥ " .. short(reward.min)
		local text = string.format("<b>Ngày %d</b>  %s\n<font color='#AAAACC'>🪙 %s token%s</font>", day, if done then "✅" else "", amountText, extra)
		if isNext and daily.claimable then
			row(day + 1, text, "🎁 Nhận", COLORS.pink, function()
				fire("ClaimDaily")
			end)
		else
			row(day + 1, text)
		end
	end
	return function()
		if state.daily.claimable ~= builtClaimable then
			renderPanel()
			return
		end
		timerLabel.Text = if state.daily.claimable
			then "<b>🎉 Có quà đang chờ bạn!</b>"
			else string.format("⏳ Quà tiếp theo sau <b>%s</b>", fmtTime(state.daily.resetIn))
	end
end

local ipoConfirmUntil = 0
function panels.Ipo()
	local rank = Config.CompanyRank(state.ipoCount)
	panelTitle.Text = "📈 IPO • " .. rank.name
	row(
		0,
		"<font color='#AAAACC'>Bán công ty ra sàn: reset token, GPU, kệ và level AI. Đổi lại nhận <b>cổ phiếu</b>, mỗi cổ phiếu <b>+10% token vĩnh viễn</b>.</font>",
		nil,
		nil,
		nil,
		84
	)
	local _, holdingLabel = row(1, "")
	local _, projectLabel = row(2, "")
	local button = row(3, "<b>Sẵn sàng rung chuông chưa?</b>", "🔔 IPO", COLORS.gold, function()
		if os.clock() < ipoConfirmUntil then
			ipoConfirmUntil = 0
			fire("Ipo")
		else
			ipoConfirmUntil = os.clock() + 4
			toast("⚠️ IPO sẽ reset lab! Bấm IPO lần nữa trong 4 giây để xác nhận")
		end
	end)
	return function()
		holdingLabel.Text = string.format(
			"Đang có: <b>📈 %d cổ phiếu</b> (token x%.1f) • Đã IPO %d lần",
			state.shares,
			Config.ShareMultiplier(state.shares),
			state.ipoCount
		)
		local ready = state.level >= Config.Rebirth.MinLevel and state.ipoShares >= 1
		local need = if state.level < Config.Rebirth.MinLevel
			then string.format("\n<font color='#FF7070'>Cần AI Lv.%d (hiện Lv.%d)</font>", Config.Rebirth.MinLevel, state.level)
			else ""
		projectLabel.Text = string.format(
			"IPO bây giờ nhận: <b><font color='#FFD84D'>+%d cổ phiếu</font></b>\n<font color='#AAAACC'>Token kiếm lượt này: %s</font>%s",
			state.ipoShares,
			short(state.runEarned),
			need
		)
		local confirming = os.clock() < ipoConfirmUntil
		button.Text = if confirming then "Chắc chưa? Bấm lại!" else "🔔 IPO"
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
				local owned = player:GetAttribute(key) == true
				local text = string.format("<b>%s</b>\n<font color='#AAAACC'>%s</font>", pass.name, pass.description)
				if owned then
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
					extra = string.format("<font color='#AAAACC'>Nhận ngay ≈ %s token</font>", short(state.rate * product.hours * 3600))
				else
					local active = {}
					for boost in product.boosts do
						local left = boostLeft(boost)
						if left > 0 then
							table.insert(active, fmtTime(left))
						end
					end
					extra = if #active > 0
						then "<font color='#7CFC00'>Đang chạy: còn " .. table.concat(active, " / ") .. "</font>"
						else "<font color='#AAAACC'>Mua thêm cộng dồn thời gian</font>"
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

for order, entry in MENU do
	local button = new("TextButton", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(130, 52),
		BackgroundColor3 = entry.color,
		BackgroundTransparency = 0.05,
		Font = FONT_BLACK,
		TextSize = 21,
		TextColor3 = COLORS.text,
		Text = entry.text,
		Parent = menu,
	}, { corner(14), stroke(COLORS.text, 1.5, 0.7) })
	-- chấm đỏ báo có thứ đang chờ (quà chưa nhận, IPO sẵn sàng)
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

-- ================= Nhận dữ liệu từ server =================

local function renderHud()
	if not state then
		return
	end
	tokenLabel.Text = string.format("🪙 %s <font size='18' color='#7CFC00'>+%s/s</font>", short(state.tokens), short(state.rate))

	local stage = Config.StageFor(state.level)
	local ratio = if state.xpNext > 0 then math.clamp(state.xp / state.xpNext, 0, 1) else 1
	xpFill.Size = UDim2.fromScale(ratio, 1)
	xpLabel.Text = string.format("%s %s • Lv.%d  (%d%%)", stage.emoji, stage.name, state.level, math.floor(ratio * 100))

	local parts = {}
	if state.vip then
		table.insert(parts, "⭐ VIP")
	end
	if (state.shares or 0) > 0 then
		table.insert(parts, string.format("📈 x%.1f", Config.ShareMultiplier(state.shares)))
	end
	local tokenLeft = boostLeft("Tokens")
	if tokenLeft > 0 then
		table.insert(parts, "🪙x2 " .. fmtTime(tokenLeft))
	end
	local trainLeft = boostLeft("Training")
	if trainLeft > 0 then
		table.insert(parts, "🧠x2 " .. fmtTime(trainLeft))
	end
	local shieldLeft = boostLeft("Shield")
	if shieldLeft > 0 then
		table.insert(parts, "🛡️ " .. fmtTime(shieldLeft))
	end
	if not state.autoCollect and state.buffered >= 1 then
		table.insert(parts, "📦 " .. short(state.buffered))
	end
	statusLabel.Text = table.concat(parts, "  •  ")
	statusLabel.Visible = #parts > 0

	local carryingCount = state.carrying or 0
	carryBanner.Visible = carryingCount > 0
	if carryingCount > 0 then
		carryBanner.Text = string.format("💾 Đang ôm %d ổ (+%s) → chạy về Máy thu token!", carryingCount, short(state.carryValue))
	end

	if state.daily then
		badges.Daily.Visible = state.daily.claimable
	end
	badges.Ipo.Visible = state.level >= Config.Rebirth.MinLevel and (state.ipoShares or 0) >= 1
end

remotes.State.OnClientEvent:Connect(function(newState)
	local first = state == nil
	state = newState
	renderHud()
	if panelUpdate then
		panelUpdate()
	end
	-- Lần đầu vào game mà có quà chưa nhận thì mở luôn bảng quà
	if first and state.daily and state.daily.claimable then
		openPanel = "Daily"
		renderPanel()
	end
end)

remotes.Notify.OnClientEvent:Connect(function(message, action)
	toast(message)
	if action == "OpenShop" then
		openPanel = "Shop"
		renderPanel()
	elseif action == "LevelUp" then
		flashScreen(COLORS.purple)
	elseif action == "Evolve" then
		flashScreen(COLORS.gold)
	elseif action == "Alarm" then
		flashScreen(COLORS.red)
		task.delay(0.35, flashScreen, COLORS.red)
	elseif action == "Collect" then
		popText("💰", COLORS.green, UDim2.new(0.5, 0, 0, 120))
	elseif action == "Heist" then
		flashScreen(COLORS.pink)
	end
end)

-- Cập nhật đồng hồ boost + chữ trên bảng mỗi giây (kể cả khi server chưa gửi State mới)
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
-- Prompt có attribute ForOthers (nút trộm) chỉ hiện ở lab người khác,
-- các prompt còn lại chỉ hiện ở lab của mình.

local labs = workspace:WaitForChild("Labs")

local function applyPrompt(lab, prompt)
	local owner = lab:GetAttribute("OwnerUserId")
	local mine = owner == player.UserId
	if prompt:GetAttribute("ForOthers") then
		prompt.Enabled = not mine and owner ~= 0
		prompt.HoldDuration = if player:GetAttribute("MasterThief") then Config.Heist.MasterStealHold else Config.Heist.StealHold
	else
		prompt.Enabled = mine
	end
end

local function applyOwnership(lab)
	for _, inst in lab:GetDescendants() do
		if inst:IsA("ProximityPrompt") then
			applyPrompt(lab, inst)
		end
	end
end

local function watchLab(lab)
	applyOwnership(lab)
	lab:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		applyOwnership(lab)
	end)
	lab.DescendantAdded:Connect(function(inst)
		if inst:IsA("ProximityPrompt") then
			applyPrompt(lab, inst)
		end
	end)
end
for _, lab in labs:GetChildren() do
	watchLab(lab)
end
labs.ChildAdded:Connect(watchLab)
player:GetAttributeChangedSignal("MasterThief"):Connect(function()
	for _, lab in labs:GetChildren() do
		applyOwnership(lab)
	end
end)

Fx.Start(labs)

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
