-- Mã quà (redeem code). Nằm ở ServerScriptService nên client không đọc được → có thể để mã bí mật.
-- Thêm mã mới: thêm 1 dòng vào bảng Codes (khoá viết HOA), publish lại là dùng được.

local CodesConfig = {}

-- ===== Mã quà =====
-- Khoá = mã viết HOA (người chơi gõ hoa/thường đều được, khoảng trắng đầu/cuối bị bỏ).
-- rewards.credits: credits gốc, nhân theo level người chơi (Config.ScaledCredits)
-- rewards.boosts: { tên = giây } cộng thêm vào boost đang chạy. Tên: Credits, Gather, Luck, Clones
-- rewards.capsule: "Best" (capsule Credits xịn nhất đã mở khoá) hoặc id capsule; count: số capsule mở ngay
-- expires: mốc os.time() (giây, UTC) hết hạn; nil = không hết hạn
-- note: ghi chú cho người làm game (không hiện cho người chơi)
CodesConfig.Codes = {
	RELEASE = {
		rewards = { credits = 1000, boosts = { Credits = 15 * 60 } },
		expires = nil,
		note = "Launch: credits + x2 Credits boost",
	},
	NEONBOTS = {
		rewards = { boosts = { Luck = 15 * 60, Gather = 15 * 60 } },
		expires = nil,
		note = "Launch: x2 Luck + x2 Gather",
	},
	FREECAPSULE = {
		rewards = { capsule = "Best", count = 1 },
		expires = nil,
		note = "Launch: 1 free capsule (best one the player has unlocked)",
	},
	LAUNCHWEEK = {
		rewards = { credits = 2500, boosts = { Clones = 10 * 60 } },
		expires = 1798761600, -- 2027-01-01 00:00 UTC: đổi theo ngày ra mắt thật, hoặc để nil
		note = "Limited-time launch week code (example of an expiring code)",
	},
}

-- Chống dò mã: tối đa `max` lần thử trong `window` giây cho mỗi người chơi
CodesConfig.CodeAttempts = { max = 5, window = 60 }

return CodesConfig
