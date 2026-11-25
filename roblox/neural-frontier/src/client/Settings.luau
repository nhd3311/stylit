-- Cài đặt ở máy người chơi: áp dụng ngay (âm lượng, đồ hoạ thấp, ẩn đội bot người khác,
-- cỡ giao diện, số sát thương) + bảng SETTINGS trong menu.
--   Settings.Apply(tbl)          áp dụng cả bảng (Main gọi 1 lần với state.settings của state đầu tiên)
--   Settings.Get(key)            đọc 1 giá trị; Get() không có key -> bản sao cả bảng
--   Settings.Set(key, v, fire?)  đổi 1 giá trị: áp dụng ngay + hẹn lưu lên server
--   Settings.Reset(fire?)        đưa mọi thứ về mặc định
--   Settings.OnChanged(fn)       fn(key, value) mỗi khi 1 giá trị đổi; trả về hàm huỷ đăng ký
--   Settings.OnUiScale(fn)       fn(scale) để Main nhân vào UIScale của ScreenGui; trả về hàm huỷ
--   Settings.Renderer(ctx)       vẽ bảng SETTINGS (không giữ trạng thái, vẽ lại bao nhiêu lần cũng được)
--   Settings.Defaults            bảng mặc định (đóng băng)
-- Trong 1 phiên chơi, client là nguồn sự thật; server chỉ lưu lại để lần sau vào game dùng tiếp.
-- Thuộc tính đặt trên LocalPlayer (chỉ ở máy mình) cho script khác đọc mà không cần require:
--   Settings_HideOthers, Settings_LowGraphics, Settings_DamageNumbers

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local Settings = {}

-- luật từng field: phải giống hệt SettingsService.luau phía server
local RULES = {
	musicVolume = { kind = "number", min = 0, max = 1, default = 0.6 },
	sfxVolume = { kind = "number", min = 0, max = 1, default = 0.8 },
	lowGraphics = { kind = "boolean", default = false },
	hideOtherSquads = { kind = "boolean", default = false },
	uiScale = { kind = "number", min = 0.8, max = 1.25, default = 1 },
	showDamageNumbers = { kind = "boolean", default = true },
}

local SAVE_GAP = 0.6 -- giây giữa 2 lần gửi (server nhận ~1 lần / 0.5 s, PlayerService chặn action dồn trong 0.15 s)
local LOCAL_GRACE = 2 -- vừa chỉnh tay thì bỏ qua bảng (có thể cũ) từ server trong 2 giây

-- chế độ đồ hoạ thấp: thư mục cần tắt hiệu ứng, loại hiệu ứng tắt bằng Enabled, hiệu ứng ánh sáng
local FX_ROOTS = { World = true, ClientFx = true, HabitatFx = true }
local FX_CLASSES = {
	ParticleEmitter = true,
	Fire = true,
	Smoke = true,
	Sparkles = true,
	Trail = true,
	PointLight = true,
	SpotLight = true,
	SurfaceLight = true,
}
local LIGHTING_OFF = {
	BloomEffect = { "Enabled", false },
	SunRaysEffect = { "Enabled", false },
	DepthOfFieldEffect = { "Enabled", false },
	Atmosphere = { "Density", 0 },
}

-- bố cục nút tự vẽ trong dòng của bảng (pixel)
local EDGE = 12 -- lề phải
local GAP = 8
local STEP_BUTTON = 44 -- nút − / +
local READOUT = 96 -- ô hiện %
local TOGGLE_BUTTON = 120
local STEPPER_WIDTH = STEP_BUTTON * 2 + READOUT + GAP * 2 + EDGE
local TOGGLE_WIDTH = TOGGLE_BUTTON + EDGE

local defaults = {}
local current = {} -- giá trị đang dùng (bảng thường, sửa được)
for key, rule in RULES do
	defaults[key] = rule.default
	current[key] = rule.default
end
Settings.Defaults = table.freeze(defaults)

local applied = false -- Apply đã chạy lần nào chưa (bảng từ server)
local lastLocalEdit = -math.huge
local changeListeners = {}
local scaleListeners = {}

-- ================= Kiểm tra giá trị =================

local function finite(x)
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

-- 1 giá trị hợp lệ cho field `key`; sai kiểu thì trả về `fallback`
local function clean(key, value, fallback)
	local rule = RULES[key]
	if rule.kind == "boolean" then
		return if type(value) == "boolean" then value else fallback
	end
	if not finite(value) then
		return fallback
	end
	return math.round(math.clamp(value, rule.min, rule.max) * 100) / 100
end

-- ================= Âm lượng (module Audio do agent khác viết) =================

local audio = nil -- bảng module Audio; nil = chưa có / tải lỗi

local function callAudio(method, value)
	if audio == nil then
		return
	end
	local ok, err = pcall(function()
		local fn = audio[method]
		if type(fn) == "function" then
			fn(value)
		end
	end)
	if not ok then
		warn("[Settings] Audio." .. method .. " bị lỗi:", err)
	end
end

local function applyVolumes()
	callAudio("SetMusicVolume", current.musicVolume)
	callAudio("SetSfxVolume", current.sfxVolume)
end

-- tải Audio sau khi module này trả về (tránh require vòng nếu Audio cũng require Settings)
task.defer(function()
	local folder = script.Parent
	local inst = folder and (folder:FindFirstChild("Audio") or folder:WaitForChild("Audio", 10))
	if not inst or not inst:IsA("ModuleScript") then
		return -- chưa có module Audio: bỏ qua âm lượng
	end
	local ok, result = pcall(require, inst)
	if ok and type(result) == "table" then
		audio = result
		applyVolumes()
	else
		warn("[Settings] Không tải được module Audio:", result)
	end
end)

-- ================= Đồ hoạ thấp =================
-- Tắt hiệu ứng bằng cách ghi đè 1 thuộc tính (Enabled / Density / GlobalShadows) và nhớ giá trị gốc.
-- Trong lúc bật, nếu game bật lại (server sao chép xuống, vd. tinh thể mọc lại bật PointLight + Sparks)
-- thì nhớ giá trị mới rồi tắt tiếp; nếu game tự tắt thì lúc khôi phục giữ tắt.

local lowOn = false
local lowToken = 0 -- tăng mỗi lần bật/tắt; handler của lượt cũ thấy khác token thì tự bỏ qua
local managed = {} -- [inst] = { props = { [prop] = giá trị gốc }, writes = { [prop] = số lần mình tự ghi }, conns = {} }
local lowConns = {} -- kết nối chung của chế độ thấp (DescendantAdded, ChildAdded)
local watchedRoots = {} -- [thư mục] = true

local function forget(inst)
	local rec = managed[inst]
	if rec then
		managed[inst] = nil
		for _, conn in rec.conns do
			conn:Disconnect()
		end
	end
end

local function suppress(inst, prop, off)
	local rec = managed[inst]
	if rec and rec.props[prop] ~= nil then
		return -- đã quản lý rồi
	end
	local ok, original = pcall(function()
		return inst[prop]
	end)
	if not ok or original == nil then
		return
	end
	if not rec then
		rec = { props = {}, writes = {}, conns = {} }
		managed[inst] = rec
		table.insert(rec.conns, inst.Destroying:Connect(function()
			forget(inst)
		end))
	end
	rec.props[prop] = original
	rec.writes[prop] = 0
	local token = lowToken
	local function force()
		if inst[prop] ~= off then
			rec.writes[prop] += 1
			inst[prop] = off
		end
	end
	-- nối handler TRƯỚC khi tự ghi để lần ghi đầu cũng được đếm (đúng cả kiểu sự kiện Immediate lẫn Deferred)
	table.insert(rec.conns, inst:GetPropertyChangedSignal(prop):Connect(function()
		if token ~= lowToken then
			return
		end
		if inst[prop] == off then
			-- sự kiện do chính mình ghi thì bỏ qua; còn lại là game tự tắt -> khôi phục cũng giữ tắt
			if rec.writes[prop] > 0 then
				rec.writes[prop] -= 1
			else
				rec.props[prop] = off
			end
		else
			-- game vừa bật lại: nhớ giá trị mới để khôi phục đúng, rồi tắt tiếp
			rec.props[prop] = inst[prop]
			pcall(force)
		end
	end))
	pcall(force)
end

local function handleFx(inst)
	if FX_CLASSES[inst.ClassName] then
		suppress(inst, "Enabled", false)
		if inst:IsA("ParticleEmitter") then
			pcall(inst.Clear, inst) -- xoá luôn hạt đang bay cho thấy hiệu quả ngay
		end
	end
end

local function handleLighting(inst)
	local rule = LIGHTING_OFF[inst.ClassName]
	if rule then
		suppress(inst, rule[1], rule[2])
	end
end

local function watchRoot(root)
	if watchedRoots[root] then
		return
	end
	watchedRoots[root] = true
	local token = lowToken
	for _, inst in root:GetDescendants() do
		handleFx(inst)
	end
	-- hiệu ứng thêm sau (bot mới, tinh thể, Habitat...) cũng bị tắt khi chế độ thấp đang bật
	table.insert(lowConns, root.DescendantAdded:Connect(function(inst)
		if token == lowToken then
			handleFx(inst)
		end
	end))
end

local function enableLow()
	lowToken += 1
	local token = lowToken
	suppress(Lighting, "GlobalShadows", false)
	for _, child in Lighting:GetChildren() do
		handleLighting(child)
	end
	table.insert(lowConns, Lighting.ChildAdded:Connect(function(child)
		if token == lowToken then
			handleLighting(child)
		end
	end))
	for _, child in workspace:GetChildren() do
		if FX_ROOTS[child.Name] then
			watchRoot(child)
		end
	end
	-- thư mục chưa có lúc bật (World chưa tải xong...) thì đợi nó xuất hiện
	table.insert(lowConns, workspace.ChildAdded:Connect(function(child)
		if token == lowToken and FX_ROOTS[child.Name] then
			watchRoot(child)
		end
	end))
end

local function restoreAll()
	lowToken += 1 -- vô hiệu mọi handler cũ trước khi ghi lại giá trị gốc
	for _, conn in lowConns do
		conn:Disconnect()
	end
	table.clear(lowConns)
	table.clear(watchedRoots)
	local list = managed
	managed = {}
	for inst, rec in list do
		for _, conn in rec.conns do
			conn:Disconnect()
		end
		for prop, value in rec.props do
			pcall(function()
				inst[prop] = value
			end)
		end
	end
end

local function setLowGraphics(on)
	on = on == true
	if on == lowOn then
		return
	end
	lowOn = on
	if on then
		enableLow()
	else
		restoreAll()
	end
end

-- ================= Áp dụng =================

local function setAttributes()
	pcall(function()
		player:SetAttribute("Settings_HideOthers", current.hideOtherSquads)
		player:SetAttribute("Settings_LowGraphics", current.lowGraphics)
		player:SetAttribute("Settings_DamageNumbers", current.showDamageNumbers)
	end)
end

local function applyScale()
	for _, fn in table.clone(scaleListeners) do
		local ok, err = pcall(fn, current.uiScale)
		if not ok then
			warn("[Settings] Hàm OnUiScale bị lỗi:", err)
		end
	end
end

local function applyKey(key)
	if key == "musicVolume" then
		callAudio("SetMusicVolume", current.musicVolume)
	elseif key == "sfxVolume" then
		callAudio("SetSfxVolume", current.sfxVolume)
	elseif key == "lowGraphics" then
		setLowGraphics(current.lowGraphics)
		setAttributes()
	elseif key == "uiScale" then
		applyScale()
	else
		setAttributes() -- hideOtherSquads, showDamageNumbers: script khác tự đọc
	end
end

local function applyAll()
	applyVolumes()
	setLowGraphics(current.lowGraphics)
	setAttributes()
	applyScale()
end

local function emitChanged(keys)
	if #keys == 0 then
		return
	end
	for _, fn in table.clone(changeListeners) do
		for _, key in keys do
			local ok, err = pcall(fn, key, current[key])
			if not ok then
				warn("[Settings] Hàm OnChanged bị lỗi:", err)
			end
		end
	end
end

-- ================= Lưu lên server =================
-- Gửi ngay lần đầu, bấm dồn dập thì gom lại gửi bảng mới nhất sau SAVE_GAP giây.

local saveFire = nil -- ctx.fire gần nhất (Renderer truyền vào)
local lastSent = -math.huge
local saveScheduled = false

local function defaultFire(action, ...)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("Action")
	if remote then
		remote:FireServer(action, ...)
	end
end

local function sendNow()
	lastSent = os.clock()
	local ok, err = pcall(saveFire or defaultFire, "SaveSettings", table.clone(current))
	if not ok then
		warn("[Settings] Không gửi được SaveSettings:", err)
	end
end

local function queueSave(fire)
	if type(fire) == "function" then
		saveFire = fire
	end
	if saveScheduled then
		return
	end
	local remaining = SAVE_GAP - (os.clock() - lastSent)
	if remaining <= 0 then
		sendNow()
		return
	end
	saveScheduled = true
	task.delay(remaining, function()
		saveScheduled = false
		sendNow()
	end)
end

-- ================= API =================

function Settings.Apply(incoming)
	-- vừa chỉnh tay xong thì bỏ qua bảng từ server (có thể là bản cũ chưa kịp lưu) để khỏi nhảy ngược
	if applied and os.clock() - lastLocalEdit < LOCAL_GRACE then
		return
	end
	if type(incoming) ~= "table" then
		incoming = {}
	end
	local changed = {}
	for key in RULES do
		local value = clean(key, incoming[key], current[key])
		if value ~= current[key] then
			current[key] = value
			table.insert(changed, key)
		end
	end
	applied = true
	applyAll()
	emitChanged(changed)
end

function Settings.Get(key)
	if key == nil then
		return table.clone(current)
	end
	return current[key]
end

function Settings.Set(key, value, fire)
	if RULES[key] == nil then
		return false
	end
	local nextValue = clean(key, value, current[key])
	if nextValue == current[key] then
		return false
	end
	current[key] = nextValue
	lastLocalEdit = os.clock()
	applyKey(key)
	emitChanged({ key })
	queueSave(fire)
	return true
end

function Settings.Reset(fire)
	local changed = {}
	for key, rule in RULES do
		if current[key] ~= rule.default then
			current[key] = rule.default
			table.insert(changed, key)
		end
	end
	lastLocalEdit = os.clock()
	applyAll()
	emitChanged(changed)
	queueSave(fire) -- gửi cả khi không đổi gì để server chắc chắn khớp
	return #changed > 0
end

function Settings.OnChanged(fn)
	if type(fn) ~= "function" then
		return function() end
	end
	table.insert(changeListeners, fn)
	return function()
		local index = table.find(changeListeners, fn)
		if index then
			table.remove(changeListeners, index)
		end
	end
end

-- gọi fn ngay với cỡ hiện tại (mặc định 1 khi chưa có state), rồi mỗi lần đổi
function Settings.OnUiScale(fn)
	if type(fn) ~= "function" then
		return function() end
	end
	table.insert(scaleListeners, fn)
	local ok, err = pcall(fn, current.uiScale)
	if not ok then
		warn("[Settings] Hàm OnUiScale bị lỗi:", err)
	end
	return function()
		local index = table.find(scaleListeners, fn)
		if index then
			table.remove(scaleListeners, index)
		end
	end
end

-- ================= Bảng SETTINGS =================

-- Thu hẹp ô chữ của dòng để chữ dài tự xuống hàng, không đè lên nút tự vẽ bên phải
local function reserveRight(frame, width)
	for _, child in frame:GetChildren() do
		if child:IsA("TextLabel") and child.Size.X.Scale == 1 then
			child.Size = UDim2.new(1, child.Size.X.Offset - width, child.Size.Y.Scale, child.Size.Y.Offset)
		end
	end
end

-- dòng chuẩn của bảng (ctx.row) + chỗ trống bên phải cho nút; ctx.row không trả về khung thì tạo dòng phụ
local function controlRow(ctx, opts, width)
	local frame = ctx.row(opts)
	if typeof(frame) == "Instance" and frame:IsA("GuiObject") then
		reserveRight(frame, width)
		return frame
	end
	return ctx.new("Frame", { LayoutOrder = ctx.nextOrder(), Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Parent = ctx.content })
end

-- dòng có nút − / + và ô % kèm thanh nhỏ. spec: key, icon, color, title, sub, step (theo %)
local function stepperRow(ctx, change, refreshers, spec)
	local C = ctx.C
	local rule = RULES[spec.key]
	local minP, maxP = math.round(rule.min * 100), math.round(rule.max * 100)
	local frame = controlRow(ctx, { icon = spec.icon, iconColor = spec.color, title = spec.title, sub = spec.sub, height = 64, buttons = {} }, STEPPER_WIDTH)
	local buttonColor = spec.color:Lerp(C.void, 0.25)

	local function percent()
		return math.round(current[spec.key] * 100)
	end
	-- nhảy tới mốc kế tiếp theo bước (65% bấm + thành 70%, bấm − thành 60%)
	local function stepBy(direction)
		local p = percent()
		local target = if direction > 0 then (math.floor(p / spec.step) + 1) * spec.step else (math.ceil(p / spec.step) - 1) * spec.step
		change(spec.key, math.clamp(target, minP, maxP) / 100)
	end

	local box = ctx.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(EDGE + STEP_BUTTON + GAP), 0.5, -2),
		Size = UDim2.fromOffset(READOUT, 36),
		BackgroundColor3 = C.void,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = frame,
	}, {
		ctx.new("UICorner", { CornerRadius = UDim.new(0, 8) }),
		ctx.new("UIStroke", { Color = spec.color, Thickness = 1, Transparency = 0.55 }),
	})
	local readout = ctx.text({ Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 22), TextSize = 17, Text = "", Parent = box })
	local track = ctx.new("Frame", { Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(1, -20, 0, 5), BackgroundColor3 = C.off, BorderSizePixel = 0, Parent = box }, {
		ctx.new("UICorner", { CornerRadius = UDim.new(0, 3) }),
	})
	local fill = ctx.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = spec.color, BorderSizePixel = 0, Parent = track }, {
		ctx.new("UICorner", { CornerRadius = UDim.new(0, 3) }),
	})
	local minus = ctx.button({
		Parent = frame,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(EDGE + STEP_BUTTON + GAP + READOUT + GAP), 0.5, 0),
		Size = UDim2.fromOffset(STEP_BUTTON, 40),
		Text = "−",
		Color = buttonColor,
		TextSize = 22,
		onClick = function()
			stepBy(-1)
		end,
	})
	local plus = ctx.button({
		Parent = frame,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -EDGE, 0.5, 0),
		Size = UDim2.fromOffset(STEP_BUTTON, 40),
		Text = "+",
		Color = buttonColor,
		TextSize = 22,
		onClick = function()
			stepBy(1)
		end,
	})

	local function refresh()
		local p = percent()
		readout.Text = p .. "%"
		fill.Size = UDim2.fromScale(math.clamp((p - minP) / math.max(1, maxP - minP), 0, 1), 1)
		-- chạm mốc thì nút xám lại
		if minus then
			minus.BackgroundColor3 = if p <= minP then C.off else buttonColor
		end
		if plus then
			plus.BackgroundColor3 = if p >= maxP then C.off else buttonColor
		end
	end
	table.insert(refreshers, refresh)
	refresh()
end

-- dòng bật/tắt. spec: key, icon, color, title, sub
local function toggleRow(ctx, change, refreshers, spec)
	local C = ctx.C
	local frame = controlRow(ctx, { icon = spec.icon, iconColor = spec.color, title = spec.title, sub = spec.sub, height = 64, buttons = {} }, TOGGLE_WIDTH)
	local onColor = C.lime:Lerp(C.void, 0.3)
	local b = ctx.button({
		Parent = frame,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -EDGE, 0.5, 0),
		Size = UDim2.fromOffset(TOGGLE_BUTTON, 40),
		Text = "",
		Color = C.off,
		TextSize = 15,
		onClick = function()
			change(spec.key, not current[spec.key])
		end,
	})
	local function refresh()
		if not b then
			return
		end
		local on = current[spec.key] == true
		b.Text = if on then "ON" else "OFF"
		b.BackgroundColor3 = if on then onColor else C.off
	end
	table.insert(refreshers, refresh)
	refresh()
end

-- Vẽ bảng SETTINGS vào ctx.content. Không giữ gì ở cấp module: mọi tham chiếu UI chỉ sống trong 1 lần vẽ.
-- Bấm nút thì áp dụng ngay + cập nhật chữ/thanh tại chỗ (không cần chờ vẽ lại) + hẹn lưu qua ctx.fire.
function Settings.Renderer(ctx)
	local C = ctx.C
	-- Main quên gọi Apply thì lấy bảng từ state lần đầu
	if not applied and type(ctx.state) == "table" and type(ctx.state.settings) == "table" then
		Settings.Apply(ctx.state.settings)
	end

	local refreshers = {}
	local function refreshAll()
		for _, fn in refreshers do
			fn()
		end
	end
	local function change(key, value)
		Settings.Set(key, value, ctx.fire)
		refreshAll()
	end

	ctx.section("🔊 AUDIO", "Changes save automatically")
	stepperRow(ctx, change, refreshers, { key = "musicVolume", icon = "🎵", color = C.violet, title = "Music", sub = "Background music volume", step = 10 })
	stepperRow(ctx, change, refreshers, { key = "sfxVolume", icon = "🔔", color = C.cyan, title = "Sound Effects", sub = "Hits, pickups, hatching and buttons", step = 10 })

	ctx.section("🖥️ GRAPHICS")
	toggleRow(ctx, change, refreshers, { key = "lowGraphics", icon = "⚡", color = C.gold, title = "Low Graphics", sub = "Turns off bloom, shadows, particles and lights for smoother play" })
	toggleRow(ctx, change, refreshers, { key = "hideOtherSquads", icon = "👥", color = C.blue, title = "Hide Other Squads", sub = "Hide other players' bots. Your own squad stays visible." })

	ctx.section("🧭 INTERFACE")
	toggleRow(ctx, change, refreshers, { key = "showDamageNumbers", icon = "💥", color = C.orange, title = "Damage Numbers", sub = "Show damage popups when your squad hits enemies" })
	stepperRow(ctx, change, refreshers, { key = "uiScale", icon = "🔍", color = C.magenta, title = "UI Scale", sub = "Make menus and the HUD bigger or smaller", step = 5 })

	ctx.row({
		icon = "🔄",
		iconColor = C.red,
		title = "Reset to defaults",
		sub = "Put every setting back to how it started",
		height = 64,
		buttons = { {
			text = "RESET",
			color = C.orange:Lerp(C.void, 0.2),
			confirm = "TAP TO CONFIRM",
			onClick = function()
				Settings.Reset(ctx.fire)
				refreshAll()
				if type(ctx.toast) == "function" then
					pcall(ctx.toast, "🔄 Settings reset to defaults", 3, C.cyan)
				end
			end,
		} },
	})
end

return Settings
