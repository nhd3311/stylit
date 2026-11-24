-- Giao diện người chơi (tiếng Anh): level/XP, máu, ba lô, credits, nhiệm vụ, nút kỹ năng
-- (phím Q E R F, bấm chuột / phím G để thu thập), bảng Bots / Gear / Quests / Shop.
-- Toàn bộ UI dựng bằng code, tự co giãn theo màn hình.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local Fx = require(script.Parent:WaitForChild("Fx"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local state = nil
local openPanel = nil
local cooldownUntil = {} -- [coreId] = os.clock() hết hồi chiêu

local FONT = Enum.Font.BuilderSansBold
local FONT_BLACK = Enum.Font.BuilderSansExtraBold
local COLORS = {
	bg = Color3.fromRGB(12, 14, 26),
	card = Color3.fromRGB(26, 30, 50),
	cardHi = Color3.fromRGB(38, 44, 72),
	cyan = Color3.fromRGB(0, 215, 255),
	purple = Color3.fromRGB(150, 90, 255),
	pink = Color3.fromRGB(255, 80, 170),
	gold = Color3.fromRGB(255, 205, 60),
	green = Color3.fromRGB(60, 220, 120),
	red = Color3.fromRGB(240, 70, 80),
	robux = Color3.fromRGB(0, 175, 110),
	disabled = Color3.fromRGB(60, 64, 84),
	text = Color3.fromRGB(240, 244, 255),
	muted = Color3.fromRGB(150, 158, 190),
}

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
local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 12) })
end
local function stroke(color, t, tr)
	return new("UIStroke", { Color = color, Thickness = t or 1.5, Transparency = tr or 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function gradient(a, b, rot)
	return new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rot or 0 })
end
local short = Config.Short
local function fire(action, ...)
	remotes.Action:FireServer(action, ...)
end

-- ================= Khung =================

local gui = new("ScreenGui", { Name = "FrontierUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets })
local uiScale = new("UIScale", { Parent = gui })
local function updateScale()
	local camera = workspace.CurrentCamera
	if camera then
		uiScale.Scale = math.clamp(math.min(camera.ViewportSize.X / 1200, camera.ViewportSize.Y / 700), 0.6, 1.1)
	end
end
updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = COLORS.red, BackgroundTransparency = 1, ZIndex = 50, Active = false, Parent = gui })
local function flashScreen(color, amount)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = amount or 0.65
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
end
Effects.OnHurt = function()
	flashScreen(COLORS.red, 0.75)
end

-- thanh có chữ đè lên
local function meter(parent, position, size, color, order)
	local back = new("Frame", { LayoutOrder = order, Position = position, Size = size, BackgroundColor3 = COLORS.bg, BackgroundTransparency = 0.1, ClipsDescendants = true, Parent = parent }, { corner(10), stroke(color, 1.5, 0.5) })
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = back }, { corner(10), gradient(color, color:Lerp(Color3.new(1, 1, 1), 0.35), 0) })
	local label = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = FONT_BLACK, TextSize = 15, TextColor3 = COLORS.text, TextStrokeTransparency = 0.4, RichText = true, ZIndex = 2, Parent = back })
	return fill, label
end

-- ---------- Góc trên trái: level + XP ----------
local levelBadge = new("TextLabel", { Position = UDim2.fromOffset(12, 60), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = COLORS.purple, Font = FONT_BLACK, TextSize = 26, TextColor3 = COLORS.text, Text = "1", Parent = gui }, { corner(32), stroke(COLORS.text, 2, 0.4), gradient(COLORS.purple, COLORS.cyan, 45) })
local xpFill, xpLabel = meter(gui, UDim2.fromOffset(84, 70), UDim2.fromOffset(220, 22), COLORS.purple)
local creditsLabel = new("TextLabel", { Position = UDim2.fromOffset(84, 98), Size = UDim2.fromOffset(220, 26), BackgroundTransparency = 1, Font = FONT_BLACK, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COLORS.gold, TextStrokeTransparency = 0.5, Text = "💳 0", Parent = gui })

-- ---------- Trên giữa: vùng + ba lô ----------
local zoneLabel = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(320, 30), BackgroundColor3 = COLORS.bg, BackgroundTransparency = 0.25, Font = FONT_BLACK, TextSize = 17, TextColor3 = COLORS.text, Text = "🏙️ Hub", Parent = gui }, { corner(15) })
local packFill, packLabel = meter(gui, UDim2.new(0.5, -170, 0, 44), UDim2.fromOffset(340, 30), COLORS.cyan)

-- ---------- Góc trên phải: nhiệm vụ ----------
local questCard = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 60), Size = UDim2.fromOffset(270, 86), BackgroundColor3 = COLORS.bg, BackgroundTransparency = 0.12, Parent = gui }, { corner(14), stroke(COLORS.gold, 1.5, 0.5) })
local questTitle = new("TextLabel", { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 18), BackgroundTransparency = 1, Font = FONT, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COLORS.gold, Text = "QUEST", Parent = questCard })
local questText = new("TextLabel", { Position = UDim2.fromOffset(12, 24), Size = UDim2.new(1, -24, 0, 36), BackgroundTransparency = 1, Font = FONT_BLACK, TextSize = 15, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COLORS.text, Parent = questCard })
local questFill = meter(questCard, UDim2.new(0, 12, 1, -20), UDim2.new(1, -24, 0, 10), COLORS.gold)

-- ---------- Dưới giữa: máu + kỹ năng ----------
local hpFill, hpLabel = meter(gui, UDim2.new(0.5, -170, 1, -138), UDim2.fromOffset(340, 24), COLORS.green)
local abilityBar = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.fromOffset(5 * 76, 72), BackgroundTransparency = 1, Parent = gui }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local abilityButtons = {}
local function abilityButton(order, emoji, key, color, onPress)
	local button = new("TextButton", { LayoutOrder = order, Size = UDim2.fromOffset(68, 68), BackgroundColor3 = color, Font = FONT_BLACK, TextSize = 28, TextColor3 = COLORS.text, Text = emoji, AutoButtonColor = true, Parent = abilityBar }, { corner(18), stroke(COLORS.text, 2, 0.5) })
	new("TextLabel", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -2), Size = UDim2.fromOffset(20, 16), BackgroundTransparency = 1, Font = FONT_BLACK, TextSize = 13, TextColor3 = COLORS.text, Text = key, ZIndex = 3, Parent = button })
	local shade = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 2, Parent = button }, { corner(18) })
	local lock = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Font = FONT_BLACK, TextSize = 13, TextColor3 = COLORS.text, Text = "", Visible = false, ZIndex = 4, Parent = button }, { corner(18) })
	button.MouseButton1Click:Connect(onPress)
	return { button = button, shade = shade, lock = lock }
end

local function toastFactory()
	local label = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 84), Size = UDim2.fromOffset(520, 44), BackgroundColor3 = COLORS.bg, BackgroundTransparency = 1, Font = FONT, TextSize = 17, TextColor3 = COLORS.text, TextTransparency = 1, TextWrapped = true, ZIndex = 40, Parent = gui }, { corner(12) })
	local version = 0
	return function(message, seconds)
		version += 1
		local v = version
		label.Text = message
		label.TextTransparency = 0
		label.BackgroundTransparency = 0.08
		task.delay(seconds or 3, function()
			if v == version then
				TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			end
		end)
	end
end
local toast = toastFactory()

-- ================= Kỹ năng =================

local function useCore(core)
	if not state then
		return
	end
	if state.level < core.level then
		toast(string.format("%s %s unlocks at level %d", core.emoji, core.name, core.level))
		return
	end
	local t = os.clock()
	if (cooldownUntil[core.id] or 0) > t then
		return
	end
	cooldownUntil[core.id] = t + core.cooldown
	if core.id == "Dash" then
		-- client sở hữu vật lý nhân vật nên tự đẩy về phía trước
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = root.CFrame.LookVector * core.power + Vector3.new(0, 12, 0)
		end
	end
	fire("UseCore", core.id)
end

local function harvest()
	fire("Harvest")
end

abilityButtons.Harvest = abilityButton(0, "💾", "G", COLORS.cyan, harvest)
for i, core in Config.Cores do
	abilityButtons[core.id] = abilityButton(i, core.emoji, core.key, ({ COLORS.pink, COLORS.green, COLORS.gold, COLORS.purple })[i], function()
		useCore(core)
	end)
end

local KEYS = { [Enum.KeyCode.G] = "Harvest" }
for _, core in Config.Cores do
	KEYS[Enum.KeyCode[core.key]] = core.id
end
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local id = KEYS[input.KeyCode]
	if id == "Harvest" then
		harvest()
	elseif id then
		useCore(Config.CoreById[id])
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		harvest() -- bấm chuột trái ngoài UI cũng là thu thập
	end
end)

-- ================= Menu + bảng =================

local MENU = {
	{ id = "Bots", text = "🤖 Bots", color = COLORS.pink },
	{ id = "Gear", text = "🎒 Gear", color = COLORS.cyan },
	{ id = "Quests", text = "📜 Quests", color = COLORS.gold },
	{ id = "Shop", text = "💎 Shop", color = COLORS.robux },
}
local menu = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(120, #MENU * 52), BackgroundTransparency = 1, Parent = gui }, {
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local panel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 600, 0.72, 0), BackgroundColor3 = COLORS.bg, BackgroundTransparency = 0.03, Visible = false, ZIndex = 10, Parent = gui }, {
	corner(20),
	stroke(COLORS.cyan, 1.5, 0.45),
	new("UISizeConstraint", { MaxSize = Vector2.new(600, 640), MinSize = Vector2.new(300, 280) }),
})
local panelTitle = new("TextLabel", { Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -90, 0, 32), BackgroundTransparency = 1, Font = FONT_BLACK, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COLORS.text, ZIndex = 11, Parent = panel })
local closeButton = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = COLORS.cardHi, Font = FONT_BLACK, TextSize = 20, TextColor3 = COLORS.text, Text = "✕", ZIndex = 11, Parent = panel }, { corner(20) })
local content = new("ScrollingFrame", { Position = UDim2.fromOffset(14, 56), Size = UDim2.new(1, -28, 1, -68), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = COLORS.cyan, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 11, Parent = panel }, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local order = 0
local function nextOrder()
	order += 1
	return order
end
local function clear()
	for _, child in content:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	order = 0
end
local function section(text)
	new("TextLabel", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Font = FONT_BLACK, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COLORS.gold, Text = text, ZIndex = 12, Parent = content })
end
-- dòng: chữ trái + tối đa 2 nút phải. Có thể có ô màu (icon) bên trái.
local function row(text, buttons, height, iconColor)
	local frame = new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, -8, 0, height or 66), BackgroundColor3 = COLORS.card, ZIndex = 12, Parent = content }, { corner(12) })
	local left = 14
	if iconColor then
		new("Frame", { Position = UDim2.fromOffset(12, (height or 66) / 2 - 18), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = iconColor, ZIndex = 13, Parent = frame }, { corner(18), stroke(COLORS.text, 2, 0.6) })
		left = 58
	end
	buttons = buttons or {}
	local w = if #buttons >= 2 then 100 else 130
	new("TextLabel", { Position = UDim2.fromOffset(left, 0), Size = UDim2.new(1, -left - 14 - #buttons * (w + 8), 1, 0), BackgroundTransparency = 1, Font = FONT, TextSize = 15, TextWrapped = true, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COLORS.text, Text = text, ZIndex = 13, Parent = frame })
	local made = {}
	for i, spec in buttons do
		local b = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12 - (#buttons - i) * (w + 8), 0.5, 0), Size = UDim2.fromOffset(w, 42), BackgroundColor3 = spec[2], AutoButtonColor = spec[3] ~= nil, Font = FONT_BLACK, TextSize = 14, TextWrapped = true, TextColor3 = COLORS.text, Text = spec[1], ZIndex = 13, Parent = frame }, { corner(10) })
		if spec[3] then
			b.MouseButton1Click:Connect(spec[3])
		end
		made[i] = b
	end
	return made[1]
end

local panels = {}
local renderPanel

function panels.Bots()
	panelTitle.Text = string.format("🤖 Bot Squad (%d/%d in battle)", math.min(#state.bots, state.slots), state.slots)
	section(string.format("YOUR SQUAD • 💾 %s/s • ⚔️ %s dps", short(state.gather), short(state.attack)))
	local equippedSet = {}
	for _, i in state.equipped do
		equippedSet[i] = true
	end
	-- bot đang ra trận lên trước
	local list = table.clone(state.equipped)
	for i in state.bots do
		if not equippedSet[i] then
			table.insert(list, i)
		end
	end
	for _, i in list do
		local entry = state.bots[i]
		local bot = Config.BotById[entry.type]
		local maxed = entry.level >= Config.BotUpgrade.MaxLevel
		row(string.format(
			"<b>%s</b> Lv.%d  <font color='#%s'>%s</font>%s\n<font color='#969EBE'>💾 %s/s • ⚔️ %s dps</font>",
			bot.name,
			entry.level,
			Config.RarityColors[bot.rarity]:ToHex(),
			bot.rarity,
			if equippedSet[i] then "  <font color='#7CFF9A'>● active</font>" else "  <font color='#6E7491'>● reserve</font>",
			short(Config.BotStat(bot, entry.level, "gather")),
			short(Config.BotStat(bot, entry.level, "attack"))
		), {
			{ if maxed then "Max" else "⬆️ " .. short(Config.BotUpgradePrice(bot, entry.level)), if maxed then COLORS.disabled else COLORS.purple, function()
				fire("UpgradeBot", i)
			end },
			{ "♻️ " .. short(bot.price * 0.3), COLORS.cardHi, function()
				fire("RecycleBot", i)
			end },
		}, 64, bot.color)
	end
	section("BOT FORGE")
	for _, bot in Config.Bots do
		row(string.format("<b>%s</b>  <font color='#%s'>%s</font>\n<font color='#969EBE'>💾 %s/s • ⚔️ %s dps</font>", bot.name, Config.RarityColors[bot.rarity]:ToHex(), bot.rarity, short(bot.gather), short(bot.attack)), {
			{ "💳 " .. short(bot.price), if state.credits >= bot.price then COLORS.green else COLORS.disabled, function()
				fire("BuyBot", bot.id)
			end },
		}, 60, bot.color)
	end
end

function panels.Gear()
	panelTitle.Text = "🎒 Gear"
	section("BACKPACKS")
	for i, pack in Config.Backpacks do
		local cap = pack.capacity * (if player:GetAttribute("BigBackpack") then 2 else 1)
		local text = string.format("<b>%s</b>\n<font color='#969EBE'>Holds %s data</font>", pack.name, short(cap))
		if i <= state.backpack then
			row(text, { { if i == state.backpack then "✅ Equipped" else "Owned", COLORS.cardHi } }, 58)
		elseif i == state.backpack + 1 then
			row(text, { { "💳 " .. short(pack.price), if state.credits >= pack.price then COLORS.green else COLORS.disabled, function()
				fire("BuyBackpack")
			end } }, 58)
		else
			row(text, { { "🔒 " .. short(pack.price), COLORS.disabled } }, 58)
		end
	end
	section("AI CORES (abilities)")
	for _, core in Config.Cores do
		row(string.format("%s <b>%s</b> [%s]\n<font color='#969EBE'>%s • %ss cooldown</font>", core.emoji, core.name, core.key, core.desc, core.cooldown), {
			{ if state.level >= core.level then "✅ Unlocked" else "🔒 Lv." .. core.level, if state.level >= core.level then COLORS.cardHi else COLORS.disabled },
		}, 60)
	end
end

function panels.Quests()
	panelTitle.Text = "📜 Unit-0's Quests"
	for i, quest in Config.Quests do
		local status = if i < state.quest then "✅" elseif i == state.quest then "▶️" else "🔒"
		row(string.format("%s <b>%s</b>\n<font color='#FFD84D'>+%s credits</font>", status, quest.text, short(quest.reward)), nil, 56)
	end
end

local priceCache = {}
local function fillPrice(button, id, infoType)
	if id == 0 then
		button.Text = "Set ID"
		return
	end
	local key = tostring(infoType) .. id
	if priceCache[key] then
		button.Text = "R$ " .. priceCache[key]
		return
	end
	task.spawn(function()
		local ok, result = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
		if ok and result and result.PriceInRobux then
			priceCache[key] = result.PriceInRobux
			if button.Parent then
				button.Text = "R$ " .. result.PriceInRobux
			end
		end
	end)
end

function panels.Shop()
	panelTitle.Text = "💎 Shop"
	for _, item in Config.ShopRobux do
		local kind, key = item[1], item[2]
		if kind == "pass" then
			local pass = Config.GamePasses[key]
			local text = string.format("<b>%s</b>\n<font color='#969EBE'>%s</font>", pass.name, pass.description)
			if player:GetAttribute(key) then
				row(text, { { "✅ Owned", COLORS.cardHi } }, 66)
			else
				local b = row(text, { { "R$ ...", COLORS.robux, function()
					if pass.id == 0 then
						toast("Set this Game Pass ID in Config.luau 🛠️")
					else
						MarketplaceService:PromptGamePassPurchase(player, pass.id)
					end
				end } }, 66)
				fillPrice(b, pass.id, Enum.InfoType.GamePass)
			end
		else
			local product = Config.DevProducts[key]
			local b = row("<b>" .. product.name .. "</b>", { { "R$ ...", COLORS.robux, function()
				if product.id == 0 then
					toast("Set this Developer Product ID in Config.luau 🛠️")
				else
					MarketplaceService:PromptProductPurchase(player, product.id)
				end
			end } }, 56)
			fillPrice(b, product.id, Enum.InfoType.Product)
		end
	end
end

local lastSig
function renderPanel()
	if not openPanel or not state then
		panel.Visible = false
		return
	end
	local scroll = content.CanvasPosition
	clear()
	panels[openPanel]()
	panel.Visible = true
	content.CanvasPosition = scroll
end

closeButton.MouseButton1Click:Connect(function()
	openPanel = nil
	renderPanel()
end)
for i, entry in MENU do
	local b = new("TextButton", { LayoutOrder = i, Size = UDim2.fromOffset(120, 46), BackgroundColor3 = entry.color, Font = FONT_BLACK, TextSize = 17, TextColor3 = COLORS.text, Text = entry.text, Parent = menu }, { corner(12), stroke(COLORS.text, 1, 0.8) })
	b.MouseButton1Click:Connect(function()
		openPanel = if openPanel == entry.id then nil else entry.id
		renderPanel()
	end)
end

-- ================= HUD =================

local function renderHud()
	if not state then
		return
	end
	levelBadge.Text = tostring(state.level)
	local ratio = math.clamp(state.xp / math.max(1, state.xpNext), 0, 1)
	xpFill.Size = UDim2.fromScale(ratio, 1)
	xpLabel.Text = string.format("XP %s / %s", short(state.xp), short(state.xpNext))
	creditsLabel.Text = "💳 " .. short(state.credits)
	local zone = state.zone and Config.ZoneById[state.zone]
	zoneLabel.Text = if zone then zone.emoji .. " " .. zone.name else "🏙️ Hub — upload your data here"
	local pack = math.clamp(state.data / math.max(1, state.capacity), 0, 1)
	packFill.Size = UDim2.fromScale(pack, 1)
	packLabel.Text = if pack >= 1 then "🎒 FULL! Upload at the Hub 📡" else string.format("🎒 %s / %s data  (+%s/s)", short(state.data), short(state.capacity), short(state.gather * (if zone then zone.dataMult else 0)))
	if state.quest then
		questCard.Visible = true
		questTitle.Text = string.format("QUEST %d/%d • +%s 💳", state.quest.index, state.quest.total, short(state.quest.reward))
		questText.Text = state.quest.text
		questFill.Size = UDim2.fromScale(math.clamp(state.quest.value / math.max(1, state.quest.target), 0, 1), 1)
	else
		questCard.Visible = false
	end
	for _, core in Config.Cores do
		local b = abilityButtons[core.id]
		local locked = state.level < core.level
		b.lock.Visible = locked
		b.lock.Text = "Lv." .. core.level
	end
	-- vẽ lại bảng khi số liệu chính đổi (mua, nâng cấp...)
	if openPanel then
		local sig = table.concat({ openPanel, #state.bots, state.backpack, state.level, state.quest and state.quest.index or 0, math.floor(state.credits / 50) }, "|")
		for _, entry in state.bots do
			sig ..= entry.level
		end
		if sig ~= lastSig then
			lastSig = sig
			renderPanel()
		end
	end
end

-- máu + vòng hồi chiêu cập nhật mỗi khung hình
game:GetService("RunService").RenderStepped:Connect(function()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local ratio = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
		hpFill.Size = UDim2.fromScale(ratio, 1)
		hpLabel.Text = string.format("❤️ %d / %d", math.floor(humanoid.Health), math.floor(humanoid.MaxHealth))
	end
	local t = os.clock()
	for _, core in Config.Cores do
		local left = (cooldownUntil[core.id] or 0) - t
		abilityButtons[core.id].shade.Size = UDim2.fromScale(1, math.clamp(left / core.cooldown, 0, 1))
	end
end)

remotes.State.OnClientEvent:Connect(function(newState)
	local first = state == nil
	state = newState
	renderHud()
	if first then
		toast("👋 Welcome, Bot Tamer! Walk into 🌿 Byte Meadow, gather data, then upload it at the Hub 📡", 7)
	end
end)

remotes.Notify.OnClientEvent:Connect(function(message, action)
	if message ~= "" then
		toast(message, if action == "Boss" then 5 else 3)
	end
	if type(action) == "string" and action:sub(1, 5) == "Open:" then
		openPanel = action:sub(6)
		renderPanel()
	elseif action == "LevelUp" then
		flashScreen(COLORS.gold, 0.6)
	elseif action == "Boss" then
		flashScreen(COLORS.pink, 0.6)
	end
end)

Effects.Start(remotes:WaitForChild("Fx"))
Fx.Start(workspace:WaitForChild("World"))
gui.Parent = player:WaitForChild("PlayerGui")
