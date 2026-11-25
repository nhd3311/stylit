-- Cài đặt của người chơi: âm lượng nhạc/hiệu ứng, đồ hoạ thấp, ẩn đội bot người khác,
-- cỡ giao diện, hiện số sát thương.
-- Client tự áp dụng ngay ở máy mình rồi gửi CẢ BẢNG qua action "SaveSettings".
-- Server là "trọng tài": chỉ đọc các field đã biết (field lạ bỏ qua), sai kiểu thì giữ giá trị cũ,
-- số thì kẹp vào khoảng cho phép; rồi lưu vào profile.settings (DataService ghi xuống DataStore
-- như mọi data khác) và gửi lại cho client trong state.settings (StateExtras).

local Players = game:GetService("Players")

local PlayerService = require(script.Parent.PlayerService)

local SettingsService = {}

-- khoảng cách tối thiểu giữa 2 lần lưu của 1 người chơi (giây)
local SAVE_INTERVAL = 0.5

-- luật cho từng field: kiểu + khoảng giá trị + mặc định
local RULES = {
	musicVolume = { kind = "number", min = 0, max = 1, default = 0.6 },
	sfxVolume = { kind = "number", min = 0, max = 1, default = 0.8 },
	lowGraphics = { kind = "boolean", default = false },
	hideOtherSquads = { kind = "boolean", default = false },
	uiScale = { kind = "number", min = 0.8, max = 1.25, default = 1 },
	showDamageNumbers = { kind = "boolean", default = true },
}

-- bảng mặc định, đóng băng để không ai sửa nhầm (cần bảng sửa được thì table.clone)
local defaults = {}
for key, rule in RULES do
	defaults[key] = rule.default
end
SettingsService.Defaults = table.freeze(defaults)

-- [player] = { last = os.clock() lần lưu gần nhất, queued = bảng sạch đang chờ lưu, scheduled = đã hẹn giờ chưa }
local throttles = {}

-- số hữu hạn (loại NaN và vô cực)
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
	-- làm tròn 2 chữ số để không lưu số lẻ kiểu 0.30000000000000004
	return math.round(math.clamp(value, rule.min, rule.max) * 100) / 100
end

-- Bảng cài đặt sạch (bảng mới): bắt đầu từ `base` (cài đặt hiện tại, thiếu thì dùng mặc định),
-- chỉ đọc các field đã biết trong `input`. Field thiếu / sai kiểu giữ giá trị của `base`.
function SettingsService.Sanitize(input, base)
	if type(base) ~= "table" then
		base = defaults
	end
	local result = {}
	for key, rule in RULES do
		local fallback = clean(key, base[key], rule.default)
		result[key] = if type(input) == "table" then clean(key, input[key], fallback) else fallback
	end
	return result
end

-- Đảm bảo profile.settings luôn là bảng hợp lệ: data cũ chưa có, bị hỏng, hay lỡ bị đóng băng.
-- Sửa tại chỗ (không tạo bảng mới mỗi giây vì StateExtras gọi hàm này liên tục).
local function ensure(profile)
	local settings = profile.settings
	if type(settings) ~= "table" or table.isfrozen(settings) then
		settings = SettingsService.Sanitize(settings, nil)
		profile.settings = settings
		return settings
	end
	-- xoá field lạ (gán nil cho key đang có trong lúc duyệt là hợp lệ)
	for key in settings do
		if RULES[key] == nil then
			settings[key] = nil
		end
	end
	for key, rule in RULES do
		local value = clean(key, settings[key], rule.default)
		if settings[key] ~= value then
			settings[key] = value
		end
	end
	return settings
end

-- action "SaveSettings"(tbl): client gửi cả bảng cài đặt
local function save(player, profile, _session, input)
	if type(input) ~= "table" then
		return
	end
	local slot = throttles[player]
	if not slot then
		slot = { last = -math.huge, queued = nil, scheduled = false }
		throttles[player] = slot
	end
	-- làm sạch ngay (không giữ bảng của client); nền là bảng đang chờ lưu nếu có
	local settings = SettingsService.Sanitize(input, slot.queued or ensure(profile))
	local now = os.clock()
	local wait = SAVE_INTERVAL - (now - slot.last)
	if wait <= 0 then
		slot.last = now
		slot.queued = nil
		profile.settings = settings
		return
	end
	-- gửi dồn dập: chỉ giữ bảng mới nhất, hết khoảng chờ mới lưu (không mất lần chỉnh cuối cùng)
	slot.queued = settings
	if slot.scheduled then
		return
	end
	slot.scheduled = true
	task.delay(wait, function()
		slot.scheduled = false
		local queued = slot.queued
		slot.queued = nil
		-- người chơi đã thoát thì thôi (profile đã được lưu lúc thoát)
		if queued and throttles[player] == slot and player.Parent then
			slot.last = os.clock()
			profile.settings = queued
		end
	end)
end

function SettingsService.Start()
	PlayerService.AddAction("SaveSettings", save)
	-- gửi kèm state mỗi giây: client đọc state.settings ở lần state đầu tiên để áp dụng
	PlayerService.StateExtras.settings = function(_player, profile)
		return ensure(profile)
	end
	Players.PlayerRemoving:Connect(function(player)
		throttles[player] = nil
	end)
end

return SettingsService
