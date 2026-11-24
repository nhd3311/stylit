-- Giao diện người chơi phong cách sci-fi / hologram (chữ hiển thị tiếng Anh):
--   • thẻ phi công: level, XP, máu, credits (số đếm chạy lên)
--   • thanh vùng + thanh ba lô data, thẻ nhiệm vụ, chip boost đang chạy
--   • dock kỹ năng (Q E R F + G thu thập) có vòng hồi chiêu và đếm giây
--   • menu trái và các bảng Bots / Gear / Missions / Shop, thẻ bot có mô hình 3D xoay
-- Toàn bộ dựng bằng code, không cần ảnh upload, tự co giãn theo màn hình.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local Fx = require(script.Parent:WaitForChild("Fx"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local state = nil
local openPanel = nil
local cooldownUntil = {} -- [coreId] = os.clock() lúc hết hồi chiêu
local short = Config.Short

-- ================= Theme =================

local DISPLAY = Font.fromEnum(Enum.Font.Michroma) -- chữ tiêu đề kiểu tương lai
local BODY = Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.Bold)
local BODY_LIGHT = Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.SemiBold)
local WHITE = Color3.new(1, 1, 1)
local C = {
	void = Color3.fromRGB(5, 9, 20),
	glass = Color3.fromRGB(12, 20, 40),
	glassHi = Color3.fromRGB(28, 44, 80),
	line = Color3.fromRGB(70, 110, 170),
	cyan = Color3.fromRGB(0, 230, 255),
	blue = Color3.fromRGB(60, 120, 255),
	magenta = Color3.fromRGB(255, 60, 200),
	violet = Color3.fromRGB(150, 100, 255),
	lime = Color3.fromRGB(110, 255, 150),
	gold = Color3.fromRGB(255, 210, 80),
	red = Color3.fromRGB(255, 70, 90),
	robux = Color3.fromRGB(0, 190, 115),
	off = Color3.fromRGB(48, 56, 80),
	text = Color3.fromRGB(235, 245, 255),
	muted = Color3.fromRGB(135, 155, 200),
}
local CORE_COLORS = { Pulse = C.magenta, Dash = C.lime, Overclock = C.gold, Shield = C.violet }
local MENU = {
	{ id = "Bots", label = "BOTS", title = "BOT SQUAD", icon = "🤖", color = C.magenta },
	{ id = "Gear", label = "GEAR", title = "GEAR LAB", icon = "🎒", color = C.cyan },
	{ id = "Quests", label = "MISSIONS", title = "MISSIONS", icon = "📜", color = C.gold },
	{ id = "Shop", label = "SHOP", title = "POWER SHOP", icon = "💎", color = C.violet },
}
local MENU_BY_ID = {}
for _, entry in MENU do
	MENU_BY_ID[entry.id] = entry
end

-- ================= Hàm dựng UI =================

local function new(className, props, children)
	local inst = Instance.new(className)
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end
local function corner(radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end
local function stroke(color, thickness, transparency)
	return new("UIStroke", { Color = color, Thickness = thickness or 1.5, Transparency = transparency or 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function vgradient(top, bottom)
	return new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 })
end
local function text(props)
	local merged = { BackgroundTransparency = 1, FontFace = BODY, TextColor3 = C.text, TextSize = 14 }
	for key, value in props do
		merged[key] = value
	end
	return new("TextLabel", merged)
end
local function tween(inst, seconds, goal, style, direction)
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end
local function esc(s) -- chữ đưa vào RichText
	return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
local function stat(n) -- chỉ số bot: giữ 1 số lẻ khi nhỏ
	if n < 10 then
		return (string.format("%.1f", n):gsub("%.0$", ""))
	end
	return short(n)
end
local function fire(action, ...)
	remotes.Action:FireServer(action, ...)
end

-- vệt sáng quét ngang định kỳ trên nút / thanh
local sweeps = {}
local function sweepLayer(parent, radius, strength)
	local layer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 4, Parent = parent }, { corner(radius) })
	table.insert(sweeps, new("UIGradient", {
		Rotation = 20,
		Offset = Vector2.new(-1, 0),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, strength or 0.75),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = layer,
	}))
end

-- di chuột thì phóng to nhẹ, bấm thì nhún
local function hoverable(button)
	local scale = new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		tween(scale, 0.12, { Scale = 1.05 })
	end)
	button.MouseLeave:Connect(function()
		tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		tween(scale, 0.06, { Scale = 0.93 })
	end)
	button.MouseButton1Up:Connect(function()
		tween(scale, 0.1, { Scale = 1.05 })
	end)
end

-- khung kính tối có viền neon
local function glass(props, accent, radius)
	local frame = new("Frame", props)
	frame.BackgroundColor3 = WHITE
	frame.BackgroundTransparency = props.BackgroundTransparency or 0.12
	frame.BorderSizePixel = 0
	vgradient(C.glassHi, C.glass).Parent = frame
	corner(radius or 10).Parent = frame
	stroke(accent or C.cyan, 1.2, 0.35).Parent = frame
	return frame
end

-- 4 góc ngoặc kiểu HUD
local function brackets(frame, color, length)
	local made = {}
	length = length or 12
	for _, anchor in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local position = UDim2.new(anchor.X, if anchor.X == 0 then -3 else 3, anchor.Y, if anchor.Y == 0 then -3 else 3)
		for _, size in { UDim2.fromOffset(length, 2), UDim2.fromOffset(2, length) } do
			table.insert(made, new("Frame", { AnchorPoint = anchor, Position = position, Size = size, BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 6, Parent = frame }))
		end
	end
	return made
end

-- thanh chia vạch (XP, máu, data, nhiệm vụ)
local function bar(parent, position, size, colorA, colorB, segments)
	local back = new("Frame", { Position = position, Size = size, BackgroundColor3 = C.void, BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = parent }, { corner(5) })
	local outline = stroke(colorA, 1, 0.45)
	outline.Parent = back
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ClipsDescendants = true, Parent = back }, { corner(5) })
	local grad = new("UIGradient", { Color = ColorSequence.new(colorA, colorB), Parent = fill })
	sweepLayer(fill, 5, 0.55)
	for i = 1, (segments or 1) - 1 do
		new("Frame", { Position = UDim2.new(i / segments, -1, 0, 0), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = C.void, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 2, Parent = back })
	end
	local label = text({ Size = UDim2.fromScale(1, 1), TextSize = 13, TextStrokeTransparency = 0.45, RichText = true, ZIndex = 3, Text = "", Parent = back })
	return { back = back, fill = fill, grad = grad, label = label, outline = outline }
end
local function setBar(b, ratio)
	tween(b.fill, 0.25, { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1) })
end

-- nút bấm dùng trong bảng. confirm = chữ hiện ra để bấm lần 2 xác nhận
local function button(props)
	local color = props.Color or C.cyan
	local b = new("TextButton", {
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = props.Size,
		AutoButtonColor = false,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		FontFace = BODY,
		TextSize = props.TextSize or 15,
		TextColor3 = C.text,
		TextStrokeTransparency = 0.7,
		TextWrapped = true,
		Text = props.Text,
		Parent = props.Parent,
	}, { corner(8), stroke(color:Lerp(WHITE, 0.35), 1, 0.35) })
	new("Frame", { Size = UDim2.new(1, 0, 0.5, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.88, BorderSizePixel = 0, Parent = b }, { corner(8) })
	if props.onClick then
		hoverable(b)
		local armed = false
		b.Activated:Connect(function()
			if props.confirm and not armed then
				armed = true
				local oldText, oldColor = b.Text, b.BackgroundColor3
				b.Text = props.confirm
				b.BackgroundColor3 = C.red
				task.delay(2, function()
					if b.Parent then
						armed = false
						b.Text = oldText
						b.BackgroundColor3 = oldColor
					end
				end)
				return
			end
			armed = false
			props.onClick()
		end)
	end
	return b
end

-- mô hình bot 3D trong thẻ (ViewportFrame), lắc nhẹ trong RenderStepped
local previews = {}
local function botViewport(parent, bot, level, size)
	local viewport = new("ViewportFrame", { Size = size, BackgroundTransparency = 1, Ambient = Color3.fromRGB(150, 160, 190), LightColor = WHITE, LightDirection = Vector3.new(-0.6, -1, 0.4), Parent = parent })
	local s = bot.size * (1 + ((level or 1) - 1) * 0.04)
	local model = Instance.new("Model")
	local body = new("Part", { Anchored = true, Shape = Enum.PartType.Ball, Size = Vector3.one * s, Color = Color3.fromRGB(235, 240, 250), Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(), Parent = model })
	new("Part", { Anchored = true, Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.42, Color = bot.color, Material = Enum.Material.Neon, CFrame = CFrame.new(0, 0, -s * 0.32), Parent = model })
	new("Part", { Anchored = true, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, s * 1.7, s * 1.7), Color = bot.color, Material = Enum.Material.Neon, Transparency = 0.35, CFrame = CFrame.Angles(0, 0, math.pi / 2), Parent = model })
	model.PrimaryPart = body
	model.Parent = viewport
	local camera = new("Camera", { FieldOfView = 35, CFrame = CFrame.lookAt(Vector3.new(s * 1.2, s * 0.8, -s * 3.6), Vector3.zero), Parent = viewport })
	viewport.CurrentCamera = camera
	table.insert(previews, { model = model, phase = math.random() * 6, bob = s * 0.06 })
	return viewport
end

-- ================= Khung màn hình =================

local gui = new("ScreenGui", { Name = "FrontierUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets })
local uiScale = new("UIScale", { Parent = gui })
local function updateScale()
	local camera = workspace.CurrentCamera
	if camera then
		uiScale.Scale = math.clamp(math.min(camera.ViewportSize.X / 1280, camera.ViewportSize.Y / 720), 0.55, 1.15)
	end
end
updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

-- tối nhẹ mép trên/dưới cho chữ HUD dễ đọc
for _, spec in { { 0, 90 }, { 1, 270 } } do
	new("Frame", { AnchorPoint = Vector2.new(0, spec[1]), Position = UDim2.fromScale(0, spec[1]), Size = UDim2.new(1, 0, 0, 110), BackgroundColor3 = C.void, BorderSizePixel = 0, Parent = gui }, {
		new("UIGradient", { Rotation = spec[2], Transparency = NumberSequence.new(0.6, 1) }),
	})
end

local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.red, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 50, Parent = gui })
local function flashScreen(color, amount)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = amount or 0.65
	tween(flash, 0.6, { BackgroundTransparency = 1 })
end
Effects.OnHurt = function()
	flashScreen(C.red, 0.75)
end

-- ---------- Thẻ phi công (trên trái) ----------
local pilot = glass({ Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(300, 74), Parent = gui }, C.cyan)
brackets(pilot, C.cyan, 12)
new("Frame", { Position = UDim2.fromOffset(14, 13), Size = UDim2.fromOffset(48, 48), Rotation = 45, BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = pilot }, {
	corner(8),
	new("UIGradient", { Color = ColorSequence.new(C.violet, C.cyan), Rotation = -45 }),
	stroke(WHITE, 1.5, 0.3),
})
local levelText = text({ Position = UDim2.fromOffset(14, 13), Size = UDim2.fromOffset(48, 48), FontFace = DISPLAY, TextSize = 17, TextStrokeTransparency = 0.5, Text = "1", Parent = pilot })
text({ Position = UDim2.fromOffset(76, 8), Size = UDim2.fromOffset(136, 18), FontFace = DISPLAY, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = string.upper(player.DisplayName), Parent = pilot })
text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(76, 14), FontFace = DISPLAY, TextSize = 7, TextColor3 = C.cyan, TextXAlignment = Enum.TextXAlignment.Right, Text = "BOT TAMER", Parent = pilot })
local xpBar = bar(pilot, UDim2.fromOffset(76, 31), UDim2.new(1, -88, 0, 14), C.violet, C.cyan, 10)
local xpText = text({ Position = UDim2.fromOffset(76, 49), Size = UDim2.new(1, -88, 0, 16), FontFace = BODY_LIGHT, TextSize = 13, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = pilot })

local hpBar = bar(gui, UDim2.fromOffset(10, 86), UDim2.fromOffset(300, 20), C.lime, C.cyan, 10)
local HP_OK = ColorSequence.new(C.lime, C.cyan)
local HP_LOW = ColorSequence.new(C.red, C.magenta)

local creditsCard = glass({ Position = UDim2.fromOffset(10, 112), Size = UDim2.fromOffset(300, 52), Parent = gui }, C.gold)
local coin = new("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = C.gold, BorderSizePixel = 0, Parent = creditsCard }, {
	corner(10),
	vgradient(WHITE, Color3.fromRGB(200, 150, 60)),
	stroke(WHITE, 1, 0.5),
})
text({ Size = UDim2.fromScale(1, 1), TextSize = 22, Text = "💳", Parent = coin })
text({ Position = UDim2.fromOffset(56, 5), Size = UDim2.fromOffset(150, 12), FontFace = DISPLAY, TextSize = 7, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Left, Text = "CREDITS", Parent = creditsCard })
local creditsText = text({ Position = UDim2.fromOffset(56, 17), Size = UDim2.fromOffset(160, 30), FontFace = DISPLAY, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, Text = "0", Parent = creditsCard })
new("UIGradient", { Color = ColorSequence.new(WHITE, C.gold), Rotation = 90, Parent = creditsText })

local function creditPopup(amount)
	local label = text({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(90, 24), FontFace = DISPLAY, TextSize = 12, TextColor3 = C.lime, TextStrokeTransparency = 0.4, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5, Text = "+" .. short(amount), Parent = creditsCard })
	tween(label, 0.9, { Position = UDim2.new(1, -10, 0.5, -26), TextTransparency = 1, TextStrokeTransparency = 1 })
	task.delay(0.95, function()
		label:Destroy()
	end)
end

-- ---------- Vùng + ba lô (trên giữa) ----------
local zoneBanner = glass({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(400, 32), Parent = gui }, C.cyan, 16)
local zoneStroke = zoneBanner:FindFirstChildOfClass("UIStroke")
local zoneText = text({ Size = UDim2.fromScale(1, 1), FontFace = DISPLAY, TextSize = 11, Text = "HUB", Parent = zoneBanner })
local dataBar = bar(gui, UDim2.new(0.5, -200, 0, 44), UDim2.fromOffset(400, 26), C.cyan, C.blue, 20)
local DATA_OK = ColorSequence.new(C.cyan, C.blue)
local DATA_FULL = ColorSequence.new(C.magenta, C.red)
local dataFull = false

-- ---------- Nhiệm vụ + boost (trên phải) ----------
local missionCard = glass({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6), Size = UDim2.fromOffset(290, 100), Parent = gui }, C.gold)
brackets(missionCard, C.gold, 12)
local missionTitle = text({ Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(170, 16), FontFace = DISPLAY, TextSize = 9, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = missionCard })
local missionReward = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6), Size = UDim2.fromOffset(96, 20), BackgroundColor3 = C.gold, BackgroundTransparency = 0.75, TextSize = 13, TextColor3 = C.gold, Text = "", Parent = missionCard })
corner(6).Parent = missionReward
local missionText = text({ Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 42), TextSize = 16, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "", Parent = missionCard })
local missionBar = bar(missionCard, UDim2.new(0, 12, 1, -24), UDim2.new(1, -24, 0, 14), C.gold, C.magenta, 5)
missionBar.label.TextSize = 11

local boostList = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 114), Size = UDim2.fromOffset(290, 140), BackgroundTransparency = 1, Parent = gui }, {
	new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder }),
})
local BOOSTS = {
	Credits = { label = "💰 x2 CREDITS", color = C.gold },
	Gather = { label = "💾 x2 GATHER", color = C.cyan },
}
local function renderBoosts()
	for _, child in boostList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not state then
		return
	end
	local function chip(order, label, color)
		local frame = glass({ LayoutOrder = order, Size = UDim2.fromOffset(200, 28), Parent = boostList }, color, 14)
		text({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), FontFace = DISPLAY, TextSize = 9, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Text = label, Parent = frame })
	end
	if state.vip then
		chip(0, "⭐ VIP  <font color='#FFD250'>x2 UPLOADS</font>", C.gold)
	end
	local now = workspace:GetServerTimeNow()
	local order = 1
	for key, expiry in state.boosts or {} do
		local info = BOOSTS[key]
		local left = math.floor(expiry - now)
		if info and left > 0 then
			chip(order, string.format("%s  <font color='#%s'>%d:%02d</font>", info.label, info.color:ToHex(), left // 60, left % 60), info.color)
			order += 1
		end
	end
end

-- ---------- Thông báo nổi ----------
local toastGroup = new("CanvasGroup", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 84), Size = UDim2.fromOffset(540, 42), BackgroundTransparency = 1, GroupTransparency = 1, ZIndex = 20, Parent = gui })
local toastBox = glass({ Size = UDim2.fromScale(1, 1), Parent = toastGroup }, C.cyan)
local toastStroke = toastBox:FindFirstChildOfClass("UIStroke")
local toastStrip = new("Frame", { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = C.cyan, BorderSizePixel = 0, Parent = toastBox }, { corner(2) })
local toastText = text({ Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -28, 1, 0), TextSize = 16, TextWrapped = true, Text = "", Parent = toastBox })
local toastVersion = 0
local function toast(message, seconds, accent)
	toastVersion += 1
	local version = toastVersion
	accent = accent or C.cyan
	toastText.Text = message
	toastStroke.Color = accent
	toastStrip.BackgroundColor3 = accent
	toastGroup.Position = UDim2.new(0.5, 0, 0, 74)
	tween(toastGroup, 0.3, { GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0, 84) }, Enum.EasingStyle.Back)
	task.delay(seconds or 3, function()
		if version == toastVersion then
			tween(toastGroup, 0.4, { GroupTransparency = 1 })
		end
	end)
end

-- ---------- Banner lên cấp ----------
local levelGroup = new("CanvasGroup", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(580, 120), BackgroundTransparency = 1, GroupTransparency = 1, ZIndex = 30, Parent = gui })
local levelScale = new("UIScale", { Parent = levelGroup })
local levelTitle = text({ Size = UDim2.new(1, 0, 0, 66), FontFace = DISPLAY, TextSize = 44, Text = "LEVEL UP", Parent = levelGroup })
new("UIGradient", { Color = ColorSequence.new(WHITE, C.gold), Rotation = 90, Parent = levelTitle })
new("UIStroke", { Color = C.void, Thickness = 3, Transparency = 0.2, Parent = levelTitle })
new("Frame", { Position = UDim2.new(0.1, 0, 0, 68), Size = UDim2.new(0.8, 0, 0, 2), BackgroundColor3 = C.gold, BorderSizePixel = 0, Parent = levelGroup }, {
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }),
})
local levelSub = text({ Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 30), TextSize = 20, TextStrokeTransparency = 0.4, Text = "", Parent = levelGroup })
local levelVersion = 0
local function showLevelUp(message)
	levelVersion += 1
	local version = levelVersion
	levelSub.Text = message
	levelScale.Scale = 0.6
	levelGroup.GroupTransparency = 0
	tween(levelScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.4, function()
		if version == levelVersion then
			tween(levelGroup, 0.5, { GroupTransparency = 1 })
		end
	end)
end

-- ---------- Cảnh báo boss ----------
local bossGroup = new("CanvasGroup", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 136), Size = UDim2.fromOffset(620, 58), BackgroundTransparency = 1, GroupTransparency = 1, ZIndex = 25, Parent = gui })
local bossBox = glass({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.05, Parent = bossGroup }, C.red)
text({ Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, 16), FontFace = DISPLAY, TextSize = 9, TextColor3 = C.red, Text = "⚠  WARNING · BOSS SIGNAL DETECTED  ⚠", Parent = bossBox })
local bossText = text({ Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 30), TextSize = 18, Text = "", Parent = bossBox })
local bossVersion = 0
local function showBoss(message)
	bossVersion += 1
	local version = bossVersion
	bossText.Text = message
	task.spawn(function()
		for _ = 1, 3 do
			if version ~= bossVersion then
				return
			end
			bossGroup.GroupTransparency = 0
			task.wait(0.25)
			bossGroup.GroupTransparency = 0.5
			task.wait(0.15)
		end
		bossGroup.GroupTransparency = 0
		task.wait(4)
		if version == bossVersion then
			tween(bossGroup, 0.5, { GroupTransparency = 1 })
		end
	end)
end

-- ================= Dock kỹ năng (dưới giữa) =================

local dock = glass({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(5 * 70 + 4 * 8 + 24, 96), BackgroundTransparency = 0.25, Parent = gui }, C.cyan, 16)
brackets(dock, C.cyan, 14)
local dockRow = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = dock }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local tiles = {}
local function abilityTile(order, emoji, key, name, color, onPress)
	local b = new("TextButton", { LayoutOrder = order, Size = UDim2.fromOffset(70, 78), AutoButtonColor = false, BackgroundColor3 = WHITE, BorderSizePixel = 0, Text = "", Parent = dockRow }, {
		corner(12),
		vgradient(color:Lerp(C.void, 0.3), color:Lerp(C.void, 0.75)),
		stroke(color, 1.6, 0.15),
	})
	text({ Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 40), TextSize = 28, Text = emoji, Parent = b })
	text({ Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 16), FontFace = DISPLAY, TextSize = 7, Text = string.upper(name), Parent = b })
	local keyChip = text({ Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C.void, BackgroundTransparency = 0.25, FontFace = DISPLAY, TextSize = 9, TextColor3 = color:Lerp(WHITE, 0.5), Text = key, Parent = b })
	corner(5).Parent = keyChip
	local shade = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = C.void, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 5, Parent = b }, { corner(12) })
	local timer = text({ Size = UDim2.fromScale(1, 1), FontFace = DISPLAY, TextSize = 18, TextStrokeTransparency = 0.3, ZIndex = 6, Text = "", Parent = b })
	local lock = text({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.void, BackgroundTransparency = 0.2, FontFace = DISPLAY, TextSize = 10, TextColor3 = C.muted, ZIndex = 7, Visible = false, Text = "", Parent = b })
	corner(12).Parent = lock
	sweepLayer(b, 12, 0.8)
	hoverable(b)
	b.Activated:Connect(onPress)
	return { shade = shade, timer = timer, lock = lock }
end

local function useCore(core)
	if not state then
		return
	end
	if state.level < core.level then
		toast(string.format("%s %s unlocks at level %d", core.emoji, core.name, core.level), 3, C.red)
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

tiles.Harvest = abilityTile(0, "💾", "G", "Harvest", C.cyan, harvest)
for i, core in Config.Cores do
	tiles[core.id] = abilityTile(i, core.emoji, core.key, core.name, CORE_COLORS[core.id] or C.cyan, function()
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
		harvest() -- bấm chuột trái vào thế giới cũng là thu thập
	end
end)

-- ================= Bảng (panel) =================

local panel = glass({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 700, 0.76, 0), BackgroundTransparency = 0.05, Visible = false, Active = true, ZIndex = 10, Parent = gui }, C.cyan, 14)
new("UISizeConstraint", { MaxSize = Vector2.new(700, 620), MinSize = Vector2.new(320, 300), Parent = panel })
local panelStroke = panel:FindFirstChildOfClass("UIStroke")
panelStroke.Thickness = 1.6
local panelBrackets = brackets(panel, C.cyan, 18)
local panelScale = new("UIScale", { Parent = panel })
local header = new("Frame", { Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = C.cyan, BackgroundTransparency = 0.85, BorderSizePixel = 0, Parent = panel }, { corner(14) })
local headerLine = new("Frame", { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = C.cyan, BorderSizePixel = 0, Parent = panel }, {
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }),
})
local panelTitle = text({ Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -90, 0, 54), FontFace = DISPLAY, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = panel })
local closeButton = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0, 27), Size = UDim2.fromOffset(38, 38), AutoButtonColor = false, BackgroundColor3 = C.red, BackgroundTransparency = 0.6, FontFace = DISPLAY, TextSize = 14, TextColor3 = C.text, Text = "✕", Parent = panel }, {
	corner(10),
	stroke(C.red, 1.2, 0.2),
})
hoverable(closeButton)
local content = new("ScrollingFrame", { Position = UDim2.fromOffset(14, 64), Size = UDim2.new(1, -28, 1, -76), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, ScrollBarImageColor3 = C.cyan, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = panel }, {
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 10) }),
})

local accent = C.cyan
local function applyAccent(color)
	accent = color
	panelStroke.Color = color
	header.BackgroundColor3 = color
	headerLine.BackgroundColor3 = color
	content.ScrollBarImageColor3 = color
	for _, piece in panelBrackets do
		piece.BackgroundColor3 = color
	end
end

local order = 0
local function nextOrder()
	order += 1
	return order
end
local function clear()
	for _, child in content:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	order = 0
end
local function section(title, right)
	local frame = new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Parent = content })
	text({ Size = UDim2.new(0.5, 0, 1, 0), FontFace = DISPLAY, TextSize = 10, TextColor3 = accent, TextXAlignment = Enum.TextXAlignment.Left, Text = "◆ " .. title, Parent = frame })
	if right then
		text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.6, 0, 1, 0), FontFace = BODY_LIGHT, TextSize = 14, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Right, RichText = true, Text = right, Parent = frame })
	end
	new("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = accent, BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = frame })
end
local function grid(cellSize)
	return new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = content }, {
		new("UIGridLayout", { CellSize = cellSize, CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
end
local function chip(parent, label, color, textColor, anchorRight)
	local c = text({
		AnchorPoint = Vector2.new(if anchorRight then 1 else 0, 0),
		Position = if anchorRight then UDim2.new(1, -6, 0, 6) else UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = color,
		BackgroundTransparency = 0.1,
		FontFace = DISPLAY,
		TextSize = 7,
		TextColor3 = textColor or C.void,
		Text = label,
		ZIndex = 3,
		Parent = parent,
	})
	corner(4).Parent = c
	new("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), Parent = c })
	return c
end

-- dòng: icon trái, tiêu đề + dòng phụ, tối đa 2 nút phải
local function row(opts)
	local height = opts.height or 60
	local frame = new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = C.glassHi, BackgroundTransparency = if opts.dim then 0.75 else 0.4, BorderSizePixel = 0, Parent = content }, {
		corner(10),
		stroke(opts.accent or C.line, 1, if opts.accent then 0.2 else 0.65),
	})
	if opts.accent then
		new("Frame", { Position = UDim2.fromOffset(0, 10), Size = UDim2.new(0, 3, 1, -20), BackgroundColor3 = opts.accent, BorderSizePixel = 0, Parent = frame }, { corner(2) })
	end
	local left = 16
	if opts.icon then
		local tile = new("Frame", { Position = UDim2.new(0, 12, 0.5, -20), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = opts.iconColor or C.cyan, BackgroundTransparency = if opts.dim then 0.6 else 0.15, BorderSizePixel = 0, Parent = frame }, {
			corner(10),
			stroke(WHITE, 1, 0.6),
		})
		text({ Size = UDim2.fromScale(1, 1), TextSize = 20, Text = opts.icon, Parent = tile })
		left = 64
	end
	local buttons = opts.buttons or {}
	local width = 128
	local right = #buttons * (width + 8) + 12
	text({
		Position = UDim2.fromOffset(left, 0),
		Size = UDim2.new(1, -left - right, 1, 0),
		RichText = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 16,
		TextTransparency = if opts.dim then 0.4 else 0,
		Text = string.format("%s\n<font size='13' color='#%s'>%s</font>", esc(opts.title), C.muted:ToHex(), esc(opts.sub or "")),
		Parent = frame,
	})
	for i, spec in buttons do
		button({ Parent = frame, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12 - (#buttons - i) * (width + 8), 0.5, 0), Size = UDim2.fromOffset(width, 36), Text = spec.text, Color = spec.color, onClick = spec.onClick })
	end
	return frame
end

-- thẻ bot: mô hình 3D + độ hiếm + tên + chỉ số. tag = "ACTIVE" / "RESERVE" / nil (lò rèn)
local function botCard(parent, bot, level, cardOrder, tag)
	local rarity = Config.RarityColors[bot.rarity] or C.cyan
	local card = new("Frame", { LayoutOrder = cardOrder, BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = parent }, {
		corner(12),
		vgradient(rarity:Lerp(C.void, 0.5), C.glass),
		stroke(rarity, if tag == "ACTIVE" then 2 else 1.2, if tag == "RESERVE" then 0.6 else 0.15),
	})
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 50), Size = UDim2.fromOffset(84, 84), BackgroundColor3 = rarity, BackgroundTransparency = 0.78, BorderSizePixel = 0, Parent = card }, { corner(42) })
	botViewport(card, bot, level, UDim2.new(1, 0, 0, 96))
	chip(card, string.upper(bot.rarity), rarity)
	if tag then
		local active = tag == "ACTIVE"
		chip(card, tag, if active then C.lime else C.off, if active then C.void else C.muted, true)
	end
	text({
		Position = UDim2.fromOffset(8, 96),
		Size = UDim2.new(1, -16, 0, 20),
		TextSize = 15,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = if tag then string.format("%s <font color='#%s'>Lv.%d</font>", esc(bot.name), rarity:ToHex(), level) else esc(bot.name),
		Parent = card,
	})
	text({ Position = UDim2.fromOffset(8, 116), Size = UDim2.new(1, -16, 0, 18), FontFace = BODY_LIGHT, TextSize = 13, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("💾 %s/s   ⚔ %s dps", stat(Config.BotStat(bot, level, "gather")), stat(Config.BotStat(bot, level, "attack"))), Parent = card })
	return card
end

local priceCache = {}
local function fillPrice(b, id, infoType)
	if id == 0 then
		b.Text = "SET ID"
		return
	end
	local key = tostring(infoType) .. id
	if priceCache[key] then
		b.Text = "R$ " .. priceCache[key]
		return
	end
	task.spawn(function()
		local ok, result = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
		if ok and result and result.PriceInRobux then
			priceCache[key] = result.PriceInRobux
			if b.Parent then
				b.Text = "R$ " .. result.PriceInRobux
			end
		end
	end)
end

local function shopCard(parent, cardOrder, name, description, color, owned, id, infoType, onBuy)
	local emoji, title = name:match("^(%S+)%s+(.+)$")
	local card = new("Frame", { LayoutOrder = cardOrder, BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = parent }, {
		corner(12),
		vgradient(color:Lerp(C.void, 0.5), C.glass),
		stroke(color, 1.3, 0.25),
	})
	text({ Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(42, 42), TextSize = 30, Text = emoji or "💎", Parent = card })
	text({ Position = UDim2.fromOffset(58, 10), Size = UDim2.new(1, -66, 0, 42), FontFace = DISPLAY, TextSize = 10, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Text = string.upper(title or name), Parent = card })
	text({ Position = UDim2.fromOffset(12, 58), Size = UDim2.new(1, -24, 0, 56), FontFace = BODY_LIGHT, TextSize = 14, TextColor3 = C.muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = description, Parent = card })
	if owned then
		button({ Parent = card, Position = UDim2.new(0, 10, 1, -44), Size = UDim2.new(1, -20, 0, 34), Text = "✓ OWNED", Color = C.glassHi })
	else
		local b = button({ Parent = card, Position = UDim2.new(0, 10, 1, -44), Size = UDim2.new(1, -20, 0, 34), Text = "R$ ...", Color = C.robux, onClick = onBuy })
		fillPrice(b, id, infoType)
	end
end

local panels = {}

function panels.Bots()
	local equippedSet = {}
	for _, i in state.equipped do
		equippedSet[i] = true
	end
	section("ACTIVE SQUAD", string.format("%d/%d deployed  ·  💾 %s/s  ·  ⚔ %s dps", #state.equipped, state.slots, stat(state.gather), stat(state.attack)))
	local squad = grid(UDim2.fromOffset(150, 204))
	-- bot đang ra trận lên trước, bot dự bị phía sau
	local list = table.clone(state.equipped)
	for i in state.bots do
		if not equippedSet[i] then
			table.insert(list, i)
		end
	end
	for cardOrder, i in list do
		local entry = state.bots[i]
		local bot = entry and Config.BotById[entry.type]
		if bot then
			local maxed = entry.level >= Config.BotUpgrade.MaxLevel
			local price = Config.BotUpgradePrice(bot, entry.level)
			local card = botCard(squad, bot, entry.level, cardOrder, if equippedSet[i] then "ACTIVE" else "RESERVE")
			button({
				Parent = card,
				Position = UDim2.new(0, 8, 1, -38),
				Size = UDim2.new(1, -56, 0, 30),
				Text = if maxed then "MAX" else "⬆ " .. short(price),
				Color = if not maxed and state.credits >= price then C.violet else C.off,
				onClick = if maxed then nil else function()
					fire("UpgradeBot", i)
				end,
			})
			button({
				Parent = card,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 1, -38),
				Size = UDim2.fromOffset(40, 30),
				Text = "♻",
				Color = C.glassHi,
				confirm = "OK?",
				onClick = function()
					fire("RecycleBot", i)
				end,
			})
		end
	end
	section("BOT FORGE", "Recycle ♻ refunds 30%")
	local forge = grid(UDim2.fromOffset(150, 186))
	for cardOrder, bot in Config.Bots do
		local card = botCard(forge, bot, 1, cardOrder, nil)
		button({
			Parent = card,
			Position = UDim2.new(0, 8, 1, -38),
			Size = UDim2.new(1, -16, 0, 30),
			Text = "💳 " .. short(bot.price),
			Color = if state.credits >= bot.price then C.lime:Lerp(C.void, 0.35) else C.off,
			onClick = function()
				fire("BuyBot", bot.id)
			end,
		})
	end
end

function panels.Gear()
	local mult = if player:GetAttribute("BigBackpack") then 2 else 1
	section("STORAGE MODULES", "Equipped: <b>" .. esc(Config.Backpacks[state.backpack].name) .. "</b>")
	for i, pack in Config.Backpacks do
		local label, color, onClick
		if i <= state.backpack then
			label = if i == state.backpack then "✓ EQUIPPED" else "OWNED"
			color = C.glassHi
		elseif i == state.backpack + 1 then
			label = "💳 " .. short(pack.price)
			color = if state.credits >= pack.price then C.lime:Lerp(C.void, 0.35) else C.off
			onClick = function()
				fire("BuyBackpack")
			end
		else
			label = "🔒 " .. short(pack.price)
			color = C.off
		end
		row({
			icon = "🎒",
			iconColor = C.cyan:Lerp(C.violet, (i - 1) / math.max(1, #Config.Backpacks - 1)),
			title = pack.name,
			sub = "Holds " .. short(pack.capacity * mult) .. " data",
			accent = if i == state.backpack then C.cyan else nil,
			dim = i > state.backpack + 1,
			buttons = { { text = label, color = color, onClick = onClick } },
			height = 58,
		})
	end
	section("AI CORES", "Unlocked by leveling up")
	for _, core in Config.Cores do
		local unlocked = state.level >= core.level
		row({
			icon = core.emoji,
			iconColor = CORE_COLORS[core.id],
			title = string.format("%s  [%s]", string.upper(core.name), core.key),
			sub = string.format("%s · %ss cooldown", core.desc, core.cooldown),
			accent = if unlocked then CORE_COLORS[core.id] else nil,
			dim = not unlocked,
			buttons = { { text = if unlocked then "✓ ONLINE" else "🔒 LV." .. core.level, color = if unlocked then C.glassHi else C.off } },
			height = 60,
		})
	end
end

function panels.Quests()
	local current = if state.quest then state.quest.index else #Config.Quests + 1
	section("UNIT-0 DIRECTIVES", string.format("%d / %d complete", current - 1, #Config.Quests))
	for i, quest in Config.Quests do
		local done, active = i < current, i == current
		local sub = "+" .. short(quest.reward) .. " credits"
		if active then
			sub ..= string.format("  ·  progress %s / %s", short(state.quest.value), short(state.quest.target))
		end
		row({
			icon = if done then "✓" elseif active then "▶" else "🔒",
			iconColor = if done then C.lime:Lerp(C.void, 0.3) elseif active then C.gold else C.off,
			title = quest.text,
			sub = sub,
			accent = if active then C.gold else nil,
			dim = not done and not active,
			height = 56,
		})
	end
end

local PASS_COLORS = { VIP = C.gold, BotSlots = C.magenta, BigBackpack = C.cyan, AutoUpload = C.blue, TurboBoots = C.lime }
local PRODUCT_COLORS = { MegaBoost = C.magenta, CreditBoost = C.gold, GatherBoost = C.cyan, CreditsSmall = C.gold, CreditsLarge = C.gold }

function panels.Shop()
	local hero = new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 76), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = content }, {
		corner(12),
		new("UIGradient", { Color = ColorSequence.new(C.violet:Lerp(C.void, 0.2), C.magenta:Lerp(C.void, 0.35)) }),
		stroke(C.magenta, 1.2, 0.3),
	})
	sweepLayer(hero, 12, 0.7)
	text({ Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -36, 0, 30), FontFace = DISPLAY, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Text = "⚡ POWER UP YOUR SQUAD", Parent = hero })
	text({ Position = UDim2.fromOffset(18, 40), Size = UDim2.new(1, -36, 0, 24), FontFace = BODY_LIGHT, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Text = "Every item does exactly what it says. No random rolls.", Parent = hero })

	section("GAME PASSES · FOREVER")
	local passes = grid(UDim2.fromOffset(204, 168))
	section("BOOSTS & PACKS")
	local products = grid(UDim2.fromOffset(204, 168))

	local passOrder, productOrder = 0, 0
	for _, item in Config.ShopRobux do
		local kind, key = item[1], item[2]
		if kind == "pass" then
			local pass = Config.GamePasses[key]
			passOrder += 1
			shopCard(passes, passOrder, pass.name, pass.description, PASS_COLORS[key] or C.violet, player:GetAttribute(key) == true, pass.id, Enum.InfoType.GamePass, function()
				if pass.id == 0 then
					toast("Set this Game Pass ID in Config.luau 🛠️", 3, C.gold)
				else
					MarketplaceService:PromptGamePassPurchase(player, pass.id)
				end
			end)
		else
			local product = Config.DevProducts[key]
			local description = if product.kind == "Credits"
				then string.format("Instant credits: about %d min of gathering in your best zone (at least %s).", product.minutes, short(product.min))
				else "Starts instantly. The timer runs in real time."
			productOrder += 1
			shopCard(products, productOrder, product.name, description, PRODUCT_COLORS[key] or C.cyan, false, product.id, Enum.InfoType.Product, function()
				if product.id == 0 then
					toast("Set this Developer Product ID in Config.luau 🛠️", 3, C.gold)
				else
					MarketplaceService:PromptProductPurchase(player, product.id)
				end
			end)
		end
	end
end

-- chữ ký: chỉ vẽ lại bảng khi thứ hiển thị trong bảng thật sự đổi
local function panelSignature()
	local parts = { openPanel, state.level, state.backpack, state.slots, #state.bots }
	for _, bot in Config.Bots do
		table.insert(parts, if state.credits >= bot.price then "1" else "0")
	end
	for _, entry in state.bots do
		local bot = Config.BotById[entry.type]
		table.insert(parts, entry.type .. entry.level .. (if bot and state.credits >= Config.BotUpgradePrice(bot, entry.level) then "1" else "0"))
	end
	local nextPack = Config.Backpacks[state.backpack + 1]
	table.insert(parts, if nextPack and state.credits >= nextPack.price then "1" else "0")
	if openPanel == "Quests" and state.quest then
		table.insert(parts, state.quest.index .. ":" .. state.quest.value)
	end
	for key in Config.GamePasses do
		table.insert(parts, tostring(player:GetAttribute(key)))
	end
	return table.concat(parts, "|")
end

local lastSig
local function renderPanel(animate)
	local entry = openPanel and MENU_BY_ID[openPanel]
	if not entry or not state then
		openPanel = nil
		panel.Visible = false
		return
	end
	applyAccent(entry.color)
	panelTitle.Text = entry.icon .. "  " .. entry.title
	local scroll = content.CanvasPosition
	clear()
	panels[openPanel]()
	content.CanvasPosition = if animate then Vector2.zero else scroll
	lastSig = panelSignature()
	if animate or not panel.Visible then
		panelScale.Scale = 0.88
		tween(panelScale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	panel.Visible = true
end

closeButton.Activated:Connect(function()
	openPanel = nil
	renderPanel()
end)

-- ================= Menu trái =================

local menu = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 40), Size = UDim2.fromOffset(200, #MENU * 64), BackgroundTransparency = 1, Parent = gui }, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local badges = {}
for i, entry in MENU do
	local b = new("TextButton", { LayoutOrder = i, Size = UDim2.fromOffset(200, 56), AutoButtonColor = false, BackgroundColor3 = WHITE, BackgroundTransparency = 0.08, BorderSizePixel = 0, Text = "", Parent = menu }, {
		corner(12),
		new("UIGradient", { Color = ColorSequence.new(entry.color:Lerp(C.void, 0.45), C.glass) }),
	})
	local edge = stroke(entry.color, 1.6, 0.15)
	edge.Parent = b
	local tile = new("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(44, 44), BackgroundColor3 = entry.color, BorderSizePixel = 0, Parent = b }, {
		corner(10),
		vgradient(WHITE, Color3.fromRGB(170, 170, 190)),
		stroke(WHITE, 1, 0.5),
	})
	text({ Size = UDim2.fromScale(1, 1), TextSize = 24, Text = entry.icon, Parent = tile })
	text({ Position = UDim2.fromOffset(62, 0), Size = UDim2.new(1, -70, 1, 0), FontFace = DISPLAY, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Text = entry.label, Parent = b })
	local badge = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = C.red, BackgroundTransparency = 0, FontFace = DISPLAY, TextSize = 11, Text = "!", Visible = false, ZIndex = 8, Parent = b })
	corner(10).Parent = badge
	stroke(WHITE, 1.5, 0).Parent = badge
	badges[entry.id] = badge
	sweepLayer(b, 12, 0.8)
	hoverable(b)
	if entry.id == "Shop" then
		TweenService:Create(edge, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.75 }):Play()
	end
	b.Activated:Connect(function()
		openPanel = if openPanel == entry.id then nil else entry.id
		renderPanel(true)
	end)
end

-- có món mua được thì hiện chấm "!" trên menu
local function anyBotDeal()
	local owned = {}
	for _, entry in state.bots do
		owned[entry.type] = true
	end
	for _, bot in Config.Bots do
		if not owned[bot.id] and state.credits >= bot.price then
			return true
		end
	end
	for _, i in state.equipped do
		local entry = state.bots[i]
		local bot = entry and Config.BotById[entry.type]
		if bot and entry.level < Config.BotUpgrade.MaxLevel and state.credits >= Config.BotUpgradePrice(bot, entry.level) then
			return true
		end
	end
	return false
end

-- ================= HUD =================

local shownCredits = 0
local lastCredits = nil

local function renderHud()
	if not state then
		return
	end
	levelText.Text = tostring(state.level)
	setBar(xpBar, state.xp / math.max(1, state.xpNext))
	xpText.Text = string.format("XP %s / %s", short(state.xp), short(state.xpNext))
	if lastCredits and state.credits > lastCredits + 0.5 then
		creditPopup(state.credits - lastCredits)
	end
	lastCredits = state.credits

	local zone = state.zone and Config.ZoneById[state.zone]
	zoneText.Text = if zone then string.format("%s  SECTOR · %s", zone.emoji, string.upper(zone.name)) else "🏙️  HUB · SAFE ZONE"
	zoneStroke.Color = if zone then zone.crystal else C.cyan
	local pack = math.clamp(state.data / math.max(1, state.capacity), 0, 1)
	setBar(dataBar, pack)
	dataFull = pack >= 1
	dataBar.grad.Color = if dataFull then DATA_FULL else DATA_OK
	dataBar.label.Text = if dataFull
		then "🎒 STORAGE FULL · UPLOAD AT THE HUB 📡"
		else string.format("🎒 %s / %s DATA   <font color='#9BE7FF'>+%s/s</font>", short(state.data), short(state.capacity), stat(state.gather * (if zone then zone.dataMult else 0)))

	if state.quest then
		missionCard.Visible = true
		missionTitle.Text = string.format("◆ MISSION %d/%d", state.quest.index, state.quest.total)
		missionReward.Text = "+" .. short(state.quest.reward) .. " 💳"
		missionText.Text = state.quest.text
		setBar(missionBar, state.quest.value / math.max(1, state.quest.target))
		missionBar.label.Text = string.format("%s / %s", short(state.quest.value), short(state.quest.target))
	else
		missionCard.Visible = false
	end

	for _, core in Config.Cores do
		local tile = tiles[core.id]
		tile.lock.Visible = state.level < core.level
		tile.lock.Text = "🔒\nLV." .. core.level
	end

	badges.Bots.Visible = anyBotDeal()
	local nextPack = Config.Backpacks[state.backpack + 1]
	badges.Gear.Visible = nextPack ~= nil and state.credits >= nextPack.price
	renderBoosts()

	if openPanel and panelSignature() ~= lastSig then
		renderPanel()
	end
end

-- mỗi khung hình: máu, hồi chiêu, số credits chạy, ba lô đầy nhấp nháy, bot 3D lắc lư
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local ratio = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
		hpBar.fill.Size = UDim2.fromScale(ratio, 1)
		hpBar.label.Text = string.format("❤ %d / %d", math.floor(humanoid.Health), math.floor(humanoid.MaxHealth))
		hpBar.grad.Color = if ratio < 0.3 then HP_LOW else HP_OK
	end
	for _, core in Config.Cores do
		local tile = tiles[core.id]
		local left = (cooldownUntil[core.id] or 0) - t
		if left > 0 then
			tile.shade.Size = UDim2.fromScale(1, math.clamp(left / core.cooldown, 0, 1))
			tile.timer.Text = if left >= 1 then tostring(math.ceil(left)) else string.format("%.1f", left)
		elseif tile.timer.Text ~= "" then
			tile.shade.Size = UDim2.fromScale(1, 0)
			tile.timer.Text = ""
		end
	end
	if state then
		local diff = state.credits - shownCredits
		shownCredits = if math.abs(diff) < 1 then state.credits else shownCredits + diff * math.min(1, dt * 8)
		creditsText.Text = short(shownCredits)
	end
	dataBar.outline.Color = if dataFull then C.magenta else C.cyan
	dataBar.outline.Transparency = if dataFull then 0.5 - 0.5 * math.sin(t * 8) else 0.45
	for i = #previews, 1, -1 do
		local p = previews[i]
		if not p.model.Parent then
			table.remove(previews, i)
		else
			p.model:PivotTo(CFrame.Angles(0, math.sin(t * 1.3 + p.phase) * 0.7, 0) + Vector3.new(0, math.sin(t * 2.2 + p.phase) * p.bob, 0))
		end
	end
end)

-- vệt sáng quét qua nút/thanh mỗi vài giây
task.spawn(function()
	while true do
		task.wait(2.6)
		for i = #sweeps, 1, -1 do
			local g = sweeps[i]
			if not g.Parent or not g.Parent.Parent then
				table.remove(sweeps, i)
			else
				g.Offset = Vector2.new(-1, 0)
				tween(g, 0.9, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine)
			end
		end
	end
end)

-- đồng hồ boost đếm ngược
task.spawn(function()
	while true do
		task.wait(1)
		renderBoosts()
	end
end)

-- ================= Sự kiện từ server =================

remotes.State.OnClientEvent:Connect(function(newState)
	local first = state == nil
	state = newState
	renderHud()
	if first then
		toast("👋 Welcome, Bot Tamer! Enter 🌿 Byte Meadow, gather data, then upload it at the Hub 📡", 7)
	end
end)

local function accentFor(message, action)
	if action == "Reward" then
		return C.lime
	elseif message:find("^💀") or message:find("^You need") or message:find("🔒") then
		return C.red
	end
	return C.cyan
end

remotes.Notify.OnClientEvent:Connect(function(message, action)
	if type(action) == "string" and action:sub(1, 5) == "Open:" then
		openPanel = action:sub(6)
		renderPanel(true)
	elseif action == "LevelUp" then
		flashScreen(C.gold, 0.7)
		showLevelUp(message)
		return
	elseif action == "Boss" then
		flashScreen(C.magenta, 0.7)
		showBoss(message)
		return
	end
	if message ~= "" then
		toast(message, 3, accentFor(message, action))
	end
end)

Effects.Start(remotes:WaitForChild("Fx"))
Fx.Start(workspace:WaitForChild("World"))
gui.Parent = player:WaitForChild("PlayerGui")
