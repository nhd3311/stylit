-- Bảng xếp hạng toàn cầu: 4 bảng vật lý trong Hub, dữ liệu lấy từ OrderedDataStore.
--   • Ghi: mỗi người chơi ~120s/lần (rải đều trong chu kỳ), khi rời game và khi server tắt.
--     Chỉ ghi khi điểm khác lần ghi trước, có kiểm tra ngân sách DataStore trước mỗi lần gọi.
--   • Đọc: top 10 mỗi bảng ~60s/lần, các bảng so le nhau 15s. Tên người chơi tra 1 lần rồi nhớ.
--   • Chưa publish / DataStore không dùng được (DataService.Offline, lỗi trong Studio):
--     bảng hiện "Available after publishing ✨", không ghi gì, và tạm xếp hạng những người
--     đang ở server này để thử trong Studio vẫn thấy dữ liệu.
--
-- Bố trí (chọn 4 bảng): 3 bảng dọc mép đông Hub (x = 50, quay mặt về -X, tâm z = -2 / 17 / 36)
-- và bảng thứ 4 ở mép nam (tâm (31, 50), quay mặt về -Z). Cả 4 ôm trụ đèn góc đông-nam thành
-- hình chữ L. Mép đông không còn chỗ cho bảng thứ 4 (phía bắc là cổng Glitch Floor z -30..-18,
-- phía nam là trụ đèn z 48.5..51.5), còn mép nam đoạn x 23.5..38.5 thì trống hoàn toàn.
-- Glitch Champions đặt sát cổng Glitch Floor nhất; Top Level ở giữa, ngay hướng nhìn từ điểm hồi sinh.
-- Muốn bỏ bảng thứ 4: xoá mục "Collection" trong BOARDS, mọi thứ khác tự chạy theo.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Visuals = require(script.Parent.Visuals)

local LeaderboardService = {}

-- ===== Nhịp đọc/ghi =====
local TOP_N = 10
local READ_INTERVAL = 60 -- mỗi bảng đọc lại sau ~60s (các bảng so le đều nhau)
local FIRST_STAGGER = 3 -- lượt đọc đầu tiên: các bảng cách nhau 3s để sớm có chữ
local WRITE_INTERVAL = 120 -- mỗi người chơi được ghi ~120s/lần, rải đều trong chu kỳ
local IDLE_WAIT = 10 -- server trống / đang offline: 10s sau kiểm tra lại
local LOCAL_TICK = 5 -- chụp điểm người chơi + vẽ bảng chế độ xem trước mỗi 5s (không tốn DataStore)
local NAME_RETRY = 300 -- tra tên lỗi thì 5 phút sau mới thử lại
local CLOSE_TIMEOUT = 20 -- server tắt: chờ ghi xong tối đa 20s
local MAX_SCORE = 2 ^ 53 -- OrderedDataStore chỉ nhận số nguyên; số thực chính xác tới 2^53

-- ===== Hình dáng bảng =====
local BOARD_W = 13.2 -- bề rộng màn hình (tính cả khung neon ~14 stud)
local BOARD_H = 14.2 -- bề cao màn hình (cộng đế, khung, dải tiêu đề, nắp = 18 stud)
local BASE_H = 1
local PPS = 50 -- pixel mỗi stud của SurfaceGui -> canvas 660 x 710
local METAL = Enum.Material.Metal
local NEON = Enum.Material.Neon
local METAL_COLOR = Color3.fromRGB(40, 46, 70) -- kim loại tối của Hub
local TRIM_COLOR = Color3.fromRGB(0, 220, 255) -- viền neon xanh của Hub
local NO_COLLIDE = { CanCollide = false, CastShadow = false }

-- ===== Bố cục màn hình (pixel trên canvas 660 x 710) =====
local PAD = 22
local ROWS_TOP = 134
local ROW_H = 50
local ROW_STEP = 54
local MEDALS = { Color3.fromRGB(255, 210, 70), Color3.fromRGB(215, 225, 240), Color3.fromRGB(230, 150, 90) } -- vàng, bạc, đồng
local RANK_COLOR = Color3.fromRGB(150, 165, 200)
local NAME_COLOR = Color3.fromRGB(235, 240, 255)
local WHITE = Color3.new(1, 1, 1)

local TITLE_FONT = Font.fromEnum(Enum.Font.Michroma)
local BODY_FONT = Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.Bold)
local BODY_LIGHT = Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.SemiBold)
local NUMBER_FONT = Font.fromEnum(Enum.Font.BuilderSansExtraBold)

-- Trạng thái hiển thị của bảng: dòng phụ dưới tiêu đề, chân bảng, chữ khi bảng trống
local MODES = {
	loading = { status = "Loading… ⏳", color = Color3.fromRGB(160, 205, 235), footer = "", empty = nil },
	global = {
		status = "GLOBAL · ALL SERVERS",
		color = Color3.fromRGB(150, 235, 255),
		footer = "🔄 Updates every minute  ·  ● in this server",
		empty = "Be the first on this board! 🚀",
	},
	offline = {
		status = "Available after publishing ✨",
		color = Color3.fromRGB(255, 215, 110),
		footer = "Preview · players in this server",
		empty = "No scores in this server yet",
	},
	retry = { status = "Reconnecting… ⏳", color = Color3.fromRGB(255, 190, 120), footer = "🔄 Updates every minute", empty = nil },
}

-- ================= Cách tính điểm =================

-- Ép về số nguyên hợp lệ cho OrderedDataStore: bỏ NaN/âm, chặn trần 2^53
local function toScore(n)
	if type(n) ~= "number" or n ~= n then
		return 0
	end
	return math.clamp(math.floor(n), 0, MAX_SCORE)
end

-- Level * 1000 + tiến độ XP (0..999): cùng level thì ai gần lên level hơn xếp trên
local function levelScore(profile)
	local level = math.max(1, toScore(profile.level))
	local xp = if type(profile.xp) == "number" then profile.xp else 0
	local need = Config.XpToNext(level)
	local progress = if need > 0 then xp / need else 0
	if progress ~= progress then
		progress = 0
	end
	return toScore(level * 1000 + math.floor(math.clamp(progress, 0, 1) * 999))
end

-- Số loại bot đã khám phá trong Bot Database
local function collectionScore(profile)
	local count = 0
	for _, owned in profile.discovered or {} do
		if owned then
			count += 1
		end
	end
	return count
end

local function hubPos(x, z)
	return Config.Hub.center + Vector3.new(x, 0, z)
end

local FACE_WEST = Vector3.new(-1, 0, 0) -- bảng mép đông nhìn vào tâm Hub
local FACE_NORTH = Vector3.new(0, 0, -1) -- bảng mép nam nhìn vào tâm Hub

-- Mỗi bảng: id nội bộ, tên OrderedDataStore, tiêu đề, màu riêng, vị trí chân bảng (mặt sàn y = 0),
-- hướng mặt trước, cách tính điểm từ profile, cách hiện điểm
local BOARDS = {
	{
		id = "Wins",
		store = "NF_TopWins",
		title = "🟥 GLITCH CHAMPIONS",
		accent = Color3.fromRGB(255, 60, 90),
		pos = hubPos(50, -2), -- sát cổng Glitch Floor
		facing = FACE_WEST,
		score = function(profile)
			return toScore(profile.stats and profile.stats.eventWins)
		end,
		format = function(value)
			return Config.Short(value) .. (if value == 1 then " win" else " wins")
		end,
	},
	{
		id = "Level",
		store = "NF_TopLevel",
		title = "🏆 TOP LEVEL",
		accent = Color3.fromRGB(255, 200, 70),
		pos = hubPos(50, 17), -- giữa hàng, đối diện điểm hồi sinh (0, 4, 20)
		facing = FACE_WEST,
		score = levelScore,
		format = function(value)
			return "Lv." .. math.floor(value / 1000)
		end,
	},
	{
		id = "Earned",
		store = "NF_TopEarned",
		title = "💰 RICHEST",
		accent = Color3.fromRGB(80, 255, 160),
		pos = hubPos(50, 36),
		facing = FACE_WEST,
		score = function(profile)
			return toScore(profile.totalEarned)
		end,
		format = function(value)
			return "💳 " .. Config.Short(value)
		end,
	},
	{
		id = "Collection",
		store = "NF_TopCollection",
		title = "📚 TOP COLLECTORS",
		accent = Color3.fromRGB(190, 120, 255),
		pos = hubPos(31, 50), -- mép nam, cạnh trụ đèn góc đông-nam
		facing = FACE_NORTH,
		score = collectionScore,
		format = function(value)
			return Config.Short(value) .. "/" .. #Config.Bots
		end,
	},
}

-- ================= Trạng thái =================

local folder -- workspace.Leaderboards
local boards = {} -- { def, store, status, footer, rows, mode, loaded, busy }
local storesOk = false -- mở được đủ OrderedDataStore lúc khởi động
local studioBlocked = false -- Studio chưa bật API Services: thôi gọi DataStore cả phiên

local nameCache = {} -- [userId] = tên tài khoản
local nameRetryAt = {} -- [userId] = os.clock() được phép tra lại sau lần lỗi
local snapshot = {} -- [userId] = điểm chụp gần nhất (dự phòng khi profile đã bị giải phóng lúc rời game)
local lastWritten = {} -- [userId] = { [boardId] = điểm đã ghi thành công }
local queued = {} -- [userId] = điểm mới nhất đang chờ ghi
local writing = {} -- [userId] = true khi đang có luồng ghi cho người này
local pendingWrites = 0

local function isOffline()
	return DataService.Offline or not storesOk or studioBlocked
end

local function onStoreError(context, err)
	if RunService:IsStudio() then
		-- giống DataService: trong Studio lỗi DataStore gần như luôn do chưa bật API Services
		if not studioBlocked then
			warn("[LeaderboardService] DataStore không dùng được trong Studio, chuyển sang chế độ xem trước:", context, err)
		end
		studioBlocked = true
	else
		warn("[LeaderboardService]", context, "thất bại:", err)
	end
end

-- Còn ngân sách cho loại request này không (đọc ngân sách lỗi thì cứ thử, lệnh gọi vẫn nằm trong pcall).
-- Tra Enum bằng tên ngay trong pcall để luồng ghi không bao giờ bị lỗi giữa chừng (kẹt cờ writing).
local function hasBudget(requestTypeName)
	local ok, budget = pcall(function()
		return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType[requestTypeName])
	end)
	return not ok or budget >= 1
end

local function safeScore(def, profile)
	local ok, value = pcall(def.score, profile)
	return if ok then value else 0
end

local function scoresOf(profile)
	local scores = {}
	for _, def in BOARDS do
		scores[def.id] = safeScore(def, profile)
	end
	return scores
end

-- Tên hiển thị: người đang ở server dùng DisplayName, còn lại tra tên tài khoản (pcall + nhớ)
local function nameFor(userId)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.Name
		return player.DisplayName
	end
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local retryAt = nameRetryAt[userId]
	if userId <= 0 or (retryAt and os.clock() < retryAt) then
		return "Unknown Player"
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	if ok and type(name) == "string" and name ~= "" then
		nameCache[userId] = name
		nameRetryAt[userId] = nil
		return name
	end
	nameRetryAt[userId] = os.clock() + NAME_RETRY
	return "Unknown Player"
end

-- ================= Dựng bảng =================

local function newFrame(parent, size, position, color, transparency)
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency
	frame.Parent = parent
	return frame
end

local function newLabel(parent, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextColor3 = NAME_COLOR
	label.TextStrokeTransparency = 0.7
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = ""
	for key, value in props do
		label[key] = value
	end
	label.Parent = parent
	return label
end

local function round(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

-- Màn hình SurfaceGui ở mặt trước tấm bảng: tiêu đề, dòng trạng thái, 10 dòng xếp hạng, chân bảng
local function buildScreen(slab, def)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Screen"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	-- màn hình tự phát sáng: lúc hoàng hôn vẫn đọc rõ, không bị đèn neon xung quanh nhuộm màu
	gui.LightInfluence = 0
	gui.Brightness = 1
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local panel = newFrame(gui, UDim2.fromScale(1, 1), UDim2.new(), WHITE, 0.08)
	panel.Name = "Panel"
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(24, 28, 52), Color3.fromRGB(10, 12, 26))
	gradient.Rotation = 90
	gradient.Parent = panel

	local title = newLabel(panel, {
		Name = "Title",
		Size = UDim2.new(1, -PAD * 2, 0, 64),
		Position = UDim2.fromOffset(PAD, 16),
		FontFace = TITLE_FONT,
		Text = def.title,
		TextColor3 = def.accent:Lerp(WHITE, 0.4),
		TextScaled = true,
		TextTruncate = Enum.TextTruncate.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.45,
	})
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = 40
	fit.Parent = title

	local status = newLabel(panel, {
		Name = "Status",
		Size = UDim2.new(1, -PAD * 2, 0, 30),
		Position = UDim2.fromOffset(PAD, 84),
		FontFace = BODY_LIGHT,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	newFrame(panel, UDim2.new(1, -PAD * 2, 0, 3), UDim2.fromOffset(PAD, 122), def.accent, 0.15).Name = "Divider"

	local rows = {}
	for i = 1, TOP_N do
		local medal = MEDALS[i]
		-- top 3 nền ánh màu huy chương, các dòng sau xen kẽ đậm nhạt
		local fade = if medal then 0.84 elseif i % 2 == 0 then 0.95 else 0.91
		local row = newFrame(panel, UDim2.new(1, -PAD * 2, 0, ROW_H), UDim2.fromOffset(PAD, ROWS_TOP + (i - 1) * ROW_STEP), medal or WHITE, fade)
		row.Name = "Row" .. i
		round(row, 8)
		if medal then
			local bar = newFrame(row, UDim2.new(0, 6, 1, -14), UDim2.fromOffset(4, 7), medal, 0)
			bar.Name = "Medal"
			round(bar, 3)
		end
		newLabel(row, {
			Name = "Rank",
			Size = UDim2.fromOffset(64, ROW_H),
			Position = UDim2.fromOffset(14, 0),
			FontFace = NUMBER_FONT,
			TextSize = 30,
			Text = "#" .. i,
			TextColor3 = medal or RANK_COLOR,
			TextTruncate = Enum.TextTruncate.None,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		-- chấm xanh: người này đang ở cùng server
		local dot = newFrame(row, UDim2.fromOffset(10, 10), UDim2.new(0, 84, 0.5, -5), TRIM_COLOR, 0)
		dot.Name = "Online"
		dot.Visible = false
		round(dot, 5)
		local name = newLabel(row, {
			Name = "PlayerName",
			Size = UDim2.fromOffset(330, ROW_H),
			Position = UDim2.fromOffset(100, 0),
			FontFace = BODY_FONT,
			TextSize = 28,
			TextColor3 = medal or NAME_COLOR,
		})
		local value = newLabel(row, {
			Name = "Value",
			Size = UDim2.fromOffset(170, ROW_H),
			Position = UDim2.new(1, -182, 0, 0),
			FontFace = NUMBER_FONT,
			TextSize = 28,
			TextColor3 = def.accent:Lerp(WHITE, 0.55),
			TextTruncate = Enum.TextTruncate.None,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		rows[i] = { name = name, value = value, dot = dot }
	end

	local footer = newLabel(panel, {
		Name = "Footer",
		Size = UDim2.new(1, -PAD * 2, 0, 24),
		Position = UDim2.fromOffset(PAD, 678),
		FontFace = BODY_LIGHT,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(125, 145, 185),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	gui.Parent = slab
	return status, footer, rows
end

-- Bảng vật lý: đế kim loại, tấm màn hình tối, khung neon 4 cạnh, dải tiêu đề màu riêng, nắp trên.
-- Gốc toạ độ ở chân bảng (mặt sàn), trục -Z cục bộ = hướng mặt trước.
local function buildBoard(def)
	local model = Instance.new("Model")
	model.Name = def.id .. "Board"
	local origin = CFrame.lookAt(def.pos, def.pos + def.facing)
	local function piece(name, size, offset, color, material, extra)
		local props = { Name = name, Size = size, CFrame = origin * CFrame.new(offset), Color = color, Material = material, Parent = model }
		for key, value in extra or {} do
			props[key] = value
		end
		return Visuals.Part(props)
	end

	local W, H = BOARD_W, BOARD_H
	local screenY = BASE_H + 0.4 -- đáy màn hình (nằm trên thanh khung dưới)
	local topY = screenY + H -- đỉnh màn hình
	piece("Base", Vector3.new(W + 1.8, BASE_H, 3), Vector3.new(0, BASE_H / 2, 0), METAL_COLOR, METAL)
	piece("BaseTrim", Vector3.new(W + 2, 0.2, 3.2), Vector3.new(0, BASE_H - 0.1, 0), TRIM_COLOR, NEON, NO_COLLIDE)
	local slab = piece("Slab", Vector3.new(W, H, 1), Vector3.new(0, screenY + H / 2, 0), METAL_COLOR, METAL)
	-- khung neon nằm ngoài mép màn hình nên không che chữ
	for _, side in { -1, 1 } do
		piece("Frame", Vector3.new(0.4, H + 0.8, 1.3), Vector3.new(side * (W / 2 + 0.2), screenY + H / 2, 0), TRIM_COLOR, NEON, NO_COLLIDE)
	end
	piece("Frame", Vector3.new(W + 0.8, 0.4, 1.3), Vector3.new(0, screenY - 0.2, 0), TRIM_COLOR, NEON, NO_COLLIDE)
	piece("Frame", Vector3.new(W + 0.8, 0.4, 1.3), Vector3.new(0, topY + 0.2, 0), TRIM_COLOR, NEON, NO_COLLIDE)
	-- dải tiêu đề mang màu riêng của bảng + nắp kim loại trên cùng (đỉnh ở y = 18)
	local strip = piece("TitleStrip", Vector3.new(W + 0.8, 1.6, 1.5), Vector3.new(0, topY + 1.2, 0), def.accent, NEON, NO_COLLIDE)
	piece("Cap", Vector3.new(W + 1.4, 0.4, 1.9), Vector3.new(0, topY + 2.2, 0), METAL_COLOR, METAL)
	Visuals.Light(strip, def.accent, 16, 1.2)

	local status, footer, rows = buildScreen(slab, def)
	model.Parent = folder
	return { def = def, store = nil, status = status, footer = footer, rows = rows, mode = nil, loaded = false, busy = false }
end

-- ================= Hiển thị =================

-- entries = { { userId, value, name } } đã sắp xếp; chỉ lấy 10 dòng đầu
local function render(board, entries, modeName)
	local mode = MODES[modeName]
	board.mode = modeName
	board.status.Text = mode.status
	board.status.TextColor3 = mode.color
	board.footer.Text = mode.footer
	for i, row in board.rows do
		local entry = entries[i]
		if entry then
			row.name.Text = entry.name
			row.name.TextTransparency = 0
			row.value.Text = board.def.format(entry.value)
			row.dot.Visible = modeName == "global" and Players:GetPlayerByUserId(entry.userId) ~= nil
		else
			-- dòng trống: dòng đầu báo bảng còn trống, các dòng sau chỉ là gạch mờ
			row.name.Text = if i == 1 and mode.empty then mode.empty else "—"
			row.name.TextTransparency = 0.55
			row.value.Text = ""
			row.dot.Visible = false
		end
	end
end

-- Chế độ xem trước (chưa publish): xếp hạng người chơi đang ở server này từ DataService.Profiles
local function renderOffline(board)
	local entries = {}
	for player, profile in DataService.Profiles do
		local value = safeScore(board.def, profile)
		if value > 0 and player.Parent then
			table.insert(entries, { userId = player.UserId, value = value, name = player.DisplayName })
		end
	end
	table.sort(entries, function(a, b)
		if a.value ~= b.value then
			return a.value > b.value
		end
		return a.name < b.name
	end)
	render(board, entries, "offline")
end

-- Đọc top 10 toàn cầu của 1 bảng
local function refreshGlobal(board)
	if not hasBudget("GetSortedAsync") then
		return -- hết ngân sách: giữ dữ liệu cũ, lượt sau đọc lại
	end
	local store = board.store
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, TOP_N):GetCurrentPage()
	end)
	if not ok then
		onStoreError("GetSortedAsync(" .. board.def.store .. ")", page)
		if isOffline() then
			renderOffline(board)
		elseif not board.loaded then
			render(board, {}, "retry")
		end
		-- đã có dữ liệu cũ thì giữ nguyên, lỗi tạm thời không xoá bảng
		return
	end
	local entries = {}
	for _, item in page do
		local userId = tonumber(item.key)
		local value = tonumber(item.value)
		if userId and value and #entries < TOP_N then
			table.insert(entries, { userId = userId, value = value })
		end
	end
	for _, entry in entries do
		entry.name = nameFor(entry.userId)
	end
	board.loaded = true
	render(board, entries, "global")
end

local function refresh(board)
	if board.busy then
		return
	end
	board.busy = true
	local ok, err = pcall(function()
		if isOffline() then
			renderOffline(board)
		else
			refreshGlobal(board)
		end
	end)
	board.busy = false
	if not ok then
		warn("[LeaderboardService] Lỗi cập nhật bảng", board.def.id, err)
	end
end

-- ================= Ghi điểm =================

-- Ghi điểm của 1 người lên mọi bảng (chỉ bảng có điểm đổi). Một người chỉ có 1 luồng ghi;
-- gọi chồng lúc đang ghi thì điểm mới được xếp hàng và luồng đang chạy ghi tiếp.
local function pushScores(userId, scores)
	if userId <= 0 then
		return -- id âm = người chơi giả trong Studio (Player1, Player2...), không đưa lên bảng thật
	end
	queued[userId] = scores
	if writing[userId] then
		return
	end
	writing[userId] = true
	pendingWrites += 1
	while queued[userId] do
		local current = queued[userId]
		queued[userId] = nil
		for _, board in boards do
			local id = board.def.id
			local value = current[id]
			local written = lastWritten[userId]
			local changed = not written or written[id] ~= value
			if board.store and value and value > 0 and changed and not isOffline() then
				if hasBudget("SetIncrementSortedAsync") then
					local ok, err = pcall(board.store.SetAsync, board.store, tostring(userId), value)
					if ok then
						lastWritten[userId] = lastWritten[userId] or {}
						lastWritten[userId][id] = value
					else
						onStoreError("SetAsync(" .. board.def.store .. ")", err)
					end
				end
				-- hết ngân sách: bỏ qua lần này, chu kỳ sau (hoặc lúc rời game) ghi lại
			end
		end
	end
	writing[userId] = nil
	pendingWrites -= 1
end

-- ================= Khởi động =================

local started = false

function LeaderboardService.Start()
	if started then
		return
	end
	started = true

	folder = Instance.new("Folder")
	folder.Name = "Leaderboards"

	-- Chưa publish thì GetOrderedDataStore báo lỗi ngay -> chế độ xem trước
	storesOk = not DataService.Offline
	for _, def in BOARDS do
		local board = buildBoard(def)
		if storesOk then
			local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, def.store)
			if ok then
				board.store = store
			else
				storesOk = false
				warn("[LeaderboardService] Không mở được OrderedDataStore (game chưa publish?). Bảng chỉ hiện chế độ xem trước.", store)
			end
		end
		table.insert(boards, board)
	end
	folder.Parent = workspace

	for _, board in boards do
		if isOffline() then
			renderOffline(board)
		else
			render(board, {}, "loading")
		end
	end

	-- Đọc: lượt đầu nạp nhanh từng bảng, sau đó xoay vòng mỗi bảng ~60s, các bảng so le đều nhau
	task.spawn(function()
		for _, board in boards do
			task.spawn(refresh, board)
			task.wait(FIRST_STAGGER)
		end
		task.wait(math.max(0, READ_INTERVAL - FIRST_STAGGER * #boards))
		while true do
			for _, board in boards do
				task.spawn(refresh, board)
				task.wait(READ_INTERVAL / #boards)
			end
		end
	end)

	-- Ghi: mỗi chu kỳ ~120s lần lượt từng người chơi, rải đều để không dồn request
	task.spawn(function()
		while true do
			local list = {}
			for player in DataService.Profiles do
				table.insert(list, player)
			end
			if #list == 0 or isOffline() then
				task.wait(IDLE_WAIT)
			else
				local gap = WRITE_INTERVAL / #list
				for _, player in list do
					local profile = DataService.Profiles[player]
					if profile and player.Parent and not isOffline() then
						task.spawn(pushScores, player.UserId, scoresOf(profile))
					end
					task.wait(gap)
				end
			end
		end
	end)

	-- Mỗi 5s: chụp điểm (dự phòng cho lúc rời game) + cập nhật bảng xem trước khi offline
	task.spawn(function()
		while true do
			for player, profile in DataService.Profiles do
				snapshot[player.UserId] = scoresOf(profile)
			end
			if isOffline() then
				for _, board in boards do
					renderOffline(board)
				end
			end
			task.wait(LOCAL_TICK)
		end
	end)

	-- Rời game: ghi lần cuối. Profile có thể đã bị DataService.Release giải phóng -> dùng bản chụp.
	Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId
		nameCache[userId] = player.Name
		local profile = DataService.Profiles[player]
		local scores = if profile then scoresOf(profile) else snapshot[userId]
		if scores and not isOffline() then
			pushScores(userId, scores)
		end
		-- dọn bộ nhớ nếu người này không quay lại server trong lúc chờ ghi
		if not writing[userId] and not Players:GetPlayerByUserId(userId) then
			snapshot[userId] = nil
			lastWritten[userId] = nil
		end
	end)

	-- Server tắt: đẩy điểm còn lại rồi chờ các luồng ghi xong (có giới hạn thời gian)
	game:BindToClose(function()
		if isOffline() then
			return
		end
		for player, profile in DataService.Profiles do
			task.spawn(pushScores, player.UserId, scoresOf(profile))
		end
		local deadline = os.clock() + CLOSE_TIMEOUT
		while pendingWrites > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
end

return LeaderboardService
