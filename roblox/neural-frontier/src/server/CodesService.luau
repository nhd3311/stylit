-- Mã quà (redeem code): người chơi gõ mã ở bảng Codes, server kiểm tra rồi mới phát thưởng.
--   • Mã không phân biệt hoa/thường, bỏ khoảng trắng đầu/cuối.
--   • Mã lạ hoặc đã hết hạn (expires) thì từ chối.
--   • Mỗi mã chỉ dùng 1 lần cho mỗi người chơi: profile.redeemedCodes[code] = true.
--   • Chống dò mã: tối đa RewardsConfig.CodeAttempts.max lần thử mỗi `window` giây mỗi người chơi.
--   • Thưởng: credits (nhân theo level), boost (cộng thêm vào thời gian đang chạy),
--     capsule miễn phí (PlayerService.Hatch). Kho bot đầy thì KHÔNG tiêu mã, báo dọn kho trước.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RewardsConfig = require(ReplicatedStorage.Shared.RewardsConfig)
local PlayerService = require(script.Parent.PlayerService)

local CodesService = {}

local MAX_INPUT = 64 -- chuỗi client gửi dài hơn thế thì bỏ qua luôn
local BOOST_LABELS = { Credits = "x2 Credits", Gather = "x2 Gather", Luck = "x2 Luck", Clones = "x4 Clone Squad" }

local codes = {} -- [MÃ HOA] = định nghĩa trong RewardsConfig.Codes
local attempts = {} -- [player] = { os.clock() của các lần thử gần đây }

-- ================= Tiện ích =================

-- bỏ khoảng trắng đầu/cuối + viết hoa; nil nếu dữ liệu client gửi không hợp lệ
local function normalize(raw)
	if type(raw) ~= "string" or #raw > MAX_INPUT then
		return nil
	end
	return string.upper(string.match(raw, "^%s*(.-)%s*$") or "")
end

-- giới hạn số lần thử trong cửa sổ thời gian; trả về false + số giây phải chờ nếu vượt
local function allowAttempt(player)
	local limit = RewardsConfig.CodeAttempts
	local now = os.clock()
	local list = attempts[player]
	if not list then
		list = {}
		attempts[player] = list
	end
	-- bỏ các lần thử đã quá cửa sổ
	while list[1] and now - list[1] >= limit.window do
		table.remove(list, 1)
	end
	if #list >= limit.max then
		return false, math.max(1, math.ceil(limit.window - (now - list[1])))
	end
	table.insert(list, now)
	return true, 0
end

local function maxBots(player)
	return Config.MaxBots + (if player:GetAttribute("MegaStorage") then Config.MegaStorageBonus else 0)
end

-- "15m", "1h", "1h30m"
local function duration(seconds)
	local minutes = math.max(1, math.floor(seconds / 60))
	if minutes >= 60 then
		local hours, rest = minutes // 60, minutes % 60
		return if rest > 0 then string.format("%dh%dm", hours, rest) else string.format("%dh", hours)
	end
	return string.format("%dm", minutes)
end

-- capsule thưởng của 1 mã ("Best" = capsule Credits xịn nhất đã mở khoá)
local function capsuleFor(profile, capsuleId)
	if capsuleId == "Best" then
		return PlayerService.BestCapsule(profile)
	end
	return capsuleId and Config.CapsuleById[capsuleId]
end

-- ================= Đổi mã =================

local function redeem(player, profile, session, rawCode)
	local code = normalize(rawCode)
	if not code or code == "" then
		PlayerService.Notify(player, "🎟️ Type a code first!")
		return
	end
	local allowed, wait = allowAttempt(player)
	if not allowed then
		PlayerService.Notify(player, string.format("⏳ Too many tries! Wait %ds and try again.", wait))
		return
	end
	profile.redeemedCodes = profile.redeemedCodes or {}

	local def = codes[code]
	if not def then
		PlayerService.Notify(player, "❌ Invalid code. Check the spelling and try again!")
		return
	end
	if profile.redeemedCodes[code] then
		PlayerService.Notify(player, string.format("🎟️ You already redeemed %s!", code))
		return
	end
	if def.expires and os.time() >= def.expires then
		PlayerService.Notify(player, "⌛ This code has expired. Follow us for new codes!")
		return
	end

	local rewards = def.rewards or {}
	local capsule = capsuleFor(profile, rewards.capsule)
	local count = if capsule then math.max(1, math.floor(tonumber(rewards.count) or 1)) else 0
	-- kho bot đầy: chưa tiêu mã để người chơi dọn kho rồi đổi lại
	if count > 0 and #profile.bots + count > maxBots(player) then
		PlayerService.Notify(player, "🤖 Bot storage is full. Recycle some bots, then redeem this code again!")
		return
	end

	-- đánh dấu TRƯỚC khi phát thưởng: lỗi giữa chừng cũng không đổi được lần 2
	profile.redeemedCodes[code] = true
	local parts = {}

	local base = tonumber(rewards.credits)
	if base and base > 0 then
		local amount = Config.ScaledCredits(base, profile.level)
		PlayerService.AddCredits(player, amount)
		table.insert(parts, "+" .. Config.Short(amount) .. " credits")
	end

	-- boost: cộng thêm vào thời gian còn lại (hết rồi thì tính từ bây giờ); sắp tên cho thông báo ổn định
	local names = {}
	for name, seconds in rewards.boosts or {} do
		if BOOST_LABELS[name] and type(seconds) == "number" and seconds > 0 then
			table.insert(names, name)
		end
	end
	table.sort(names)
	for _, name in names do
		local seconds = rewards.boosts[name]
		profile.boosts[name] = math.max(os.time(), profile.boosts[name] or 0) + seconds
		table.insert(parts, BOOST_LABELS[name] .. " " .. duration(seconds))
	end

	if capsule then
		table.insert(parts, if count == 1 then "a free " .. capsule.name else string.format("%d free %ss", count, capsule.name))
	end

	local summary = if #parts > 0 then table.concat(parts, " · ") else "Thanks for playing!"
	PlayerService.Notify(player, string.format("🎉 Code %s redeemed! %s", code, summary), "Reward")
	if capsule then
		-- Hatch tự đẩy state mới cho client và chạy hoạt cảnh mở capsule
		PlayerService.Hatch(player, profile, capsule, count)
	else
		PlayerService.PushState(player)
	end
end

-- ================= Khởi động =================

-- dựng bảng tra theo mã viết hoa + cảnh báo lỗi cấu hình (để người làm game sửa sớm)
local function buildCodes()
	for rawCode, def in RewardsConfig.Codes do
		local code = string.upper(rawCode)
		if codes[code] then
			warn("[CodesService] Mã bị trùng (khác hoa/thường):", rawCode)
		end
		codes[code] = def
		local rewards = def.rewards or {}
		local capsuleId = rewards.capsule
		if capsuleId and capsuleId ~= "Best" and not Config.CapsuleById[capsuleId] then
			warn("[CodesService] Mã", code, "có capsule không tồn tại:", capsuleId)
		end
		for name, seconds in rewards.boosts or {} do
			if not BOOST_LABELS[name] or type(seconds) ~= "number" then
				warn("[CodesService] Mã", code, "có boost không hợp lệ:", name, seconds)
			end
		end
		if def.expires ~= nil and type(def.expires) ~= "number" then
			warn("[CodesService] Mã", code, "có expires không phải số os.time()")
		end
	end
end

function CodesService.Start()
	buildCodes()
	PlayerService.AddAction("RedeemCode", redeem)
	-- client hiện danh sách mã đã dùng ở bảng Codes
	PlayerService.StateExtras.redeemedCodes = function(_, profile)
		profile.redeemedCodes = profile.redeemedCodes or {}
		return profile.redeemedCodes
	end
	Players.PlayerRemoving:Connect(function(player)
		attempts[player] = nil
	end)
end

return CodesService
