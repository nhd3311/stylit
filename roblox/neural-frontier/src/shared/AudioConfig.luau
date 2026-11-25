-- Cấu hình âm thanh của Neural Frontier (nhạc nền + hiệu ứng). Chú thích tiếng Việt.
--
-- CÁCH ĐIỀN ID:
--   • Vào Creator Store (create.roblox.com/store/audio), tìm theo từ khoá gợi ý ở mỗi dòng,
--     mở trang âm thanh rồi chép dãy số trong đường link, dán vào `id` (dạng số hoặc chuỗi đều được).
--   • Cũng nhận chuỗi đầy đủ "rbxassetid://<số>" hoặc file có sẵn trong máy "rbxasset://sounds/...".
--   • id = 0 nghĩa là CHƯA CHỌN: game im lặng ở chỗ đó, không báo lỗi.
--   • Chỉ dùng âm thanh công khai trên Creator Store hoặc do chính bạn / nhóm của game upload,
--     nếu không Roblox sẽ chặn (âm thanh bị câm).
--
-- Trường của mỗi hiệu ứng (SFX):
--   id            : asset id (0 = chưa có)
--   volume        : âm lượng gốc 0..1 (còn nhân thêm âm lượng SoundGroup và thanh chỉnh của người chơi)
--   pitchVariance : lệch cao độ ngẫu nhiên ±tỉ lệ (0.1 = ±10%) để tiếng lặp lại đỡ nhàm
--   throttle      : (tuỳ chọn) khoảng cách tối thiểu giữa 2 lần phát, giây. Mặc định DefaultThrottle
--   voices        : (tuỳ chọn) số Sound tối đa phát chồng cùng lúc. Mặc định DefaultVoices

local AudioConfig = {}

-- Âm lượng gốc của 2 SoundGroup trong SoundService (thanh chỉnh 0..1 của người chơi nhân thêm vào)
AudioConfig.Groups = { Music = 0.8, SFX = 1 }

AudioConfig.CrossfadeTime = 1.5 -- giây chuyển mượt giữa 2 bài nhạc
AudioConfig.MusicFallback = "Hub" -- khu vực chưa có nhạc thì mượn bài này (để trống id thì im lặng)
AudioConfig.DefaultThrottle = 0.03 -- chống phát trùng cùng 1 khung hình
AudioConfig.DefaultVoices = 4
AudioConfig.RollOff = { min = 12, max = 160 } -- âm 3D: nghe rõ trong `min` stud, tắt hẳn ở `max` stud
AudioConfig.BossMusicRange = 90 -- Audio.AutoTrack: đứng trong khoảng này quanh boss thì bật nhạc boss
AudioConfig.WarpDistance = 80 -- Audio.AutoTrack: vị trí nhảy xa hơn mức này trong 1 nhịp = bị dịch chuyển
AudioConfig.TrackInterval = 0.25 -- Audio.AutoTrack: giây giữa 2 lần kiểm tra vị trí

-- ===== Nhạc nền theo khu vực (tự lặp, chuyển mượt) =====
AudioConfig.Music = {
	Hub = { id = 0, volume = 0.35 }, -- thành phố sci-fi an toàn: synthwave nhẹ, thân thiện, nhịp vừa ("sci-fi lobby", "chill synthwave")
	Habitat = { id = 0, volume = 0.35 }, -- khu vườn nuôi bot: lo-fi / ambient ấm áp, thư giãn ("cozy", "lofi", "relaxing")
	Meadow = { id = 0, volume = 0.35 }, -- Byte Meadow: vui tươi, nhẹ nhàng, marimba/chuông điện tử ("happy adventure", "calm game")
	Canyon = { id = 0, volume = 0.35 }, -- Circuit Canyon: sa mạc phiêu lưu, bass nảy, guitar synth ("desert", "western synth")
	Spires = { id = 0, volume = 0.35 }, -- Neon Spires: cyberpunk đêm, trống mạnh hơn ("cyberpunk", "neon city", "synthwave")
	Frost = { id = 0, volume = 0.35 }, -- Frost: ambient lạnh, chuông pha lê, pad ngân dài ("ice", "winter", "crystal ambient")
	Magma = { id = 0, volume = 0.35 }, -- Magma: trống nặng, bass gầm, căng thẳng ("lava", "volcano", "intense")
	Rift = { id = 0, volume = 0.35 }, -- Rift: glitch, méo tiếng, bí ẩn, hơi tối ("glitch", "dark mysterious", "void")
	Citadel = { id = 0, volume = 0.35 }, -- Citadel trên mây: hoành tráng, thiêng liêng, dàn dây/hợp xướng ("heavenly", "epic orchestral")
	Event = { id = 0, volume = 0.35 }, -- minigame Glitch Floor: nhanh, gấp gáp, chiptune/EDM ("arcade minigame", "fast chiptune")
	Boss = { id = 0, volume = 0.35 }, -- đánh boss: dồn dập, trống trận, căng thẳng, loop liền mạch ("boss battle", "intense combat")
}

-- ===== Hiệu ứng âm thanh =====
AudioConfig.SFX = {
	-- ----- Giao diện (2D) -----
	Click = { id = 0, volume = 0.5, pitchVariance = 0.05, throttle = 0.03, voices = 3 }, -- bấm nút: "click"/"pop" bong bóng ngắn < 0.2s ("ui click", "bubble button")
	Hover = { id = 0, volume = 0.25, pitchVariance = 0.08, throttle = 0.05, voices = 2 }, -- rê chuột qua nút: "tick" rất nhẹ, mềm, < 0.1s ("ui hover", "soft tick")
	PanelOpen = { id = 0, volume = 0.45, pitchVariance = 0.03, throttle = 0.15 }, -- mở bảng: whoosh hologram bật lên ("hologram open", "ui swoosh")
	PanelClose = { id = 0, volume = 0.4, pitchVariance = 0.03, throttle = 0.15 }, -- đóng bảng: whoosh ngược / tắt hologram, ngắn ("ui close", "power down short")
	Error = { id = 0, volume = 0.45, pitchVariance = 0, throttle = 0.25 }, -- bị từ chối / thiếu tiền / bị khoá: "buzz" 2 nốt trầm ("error", "denied beep")

	-- ----- Thu thập -----
	Harvest = { id = 0, volume = 0.5, pitchVariance = 0.12, throttle = 0.06, voices = 5 }, -- hút tinh thể data (3D): "ting" pha lê + lấp lánh ngắn ("crystal pickup", "sparkle")
	Upload = { id = 0, volume = 0.6, pitchVariance = 0, throttle = 0.5 }, -- upload data ở Hub: bíp truyền dữ liệu đi lên rồi "ding" hoàn tất, 1-2s ("data transfer", "upload complete")
	Coin = { id = 0, volume = 0.4, pitchVariance = 0.1, throttle = 0.08 }, -- nhận credits: "cha-ching" / xu leng keng ngắn ("coin pickup", "cash")

	-- ----- Tiến trình -----
	LevelUp = { id = 0, volume = 0.7, pitchVariance = 0, throttle = 0.5 }, -- lên cấp: jingle/fanfare tươi sáng 1-2s ("level up", "power up jingle")
	Quest = { id = 0, volume = 0.6, pitchVariance = 0, throttle = 0.3 }, -- xong nhiệm vụ / thông báo vui: jingle ngắn ("quest complete", "achievement")
	Daily = { id = 0, volume = 0.6, pitchVariance = 0, throttle = 0.3 }, -- nhận quà ngày: mở hộp quà + chuông lấp lánh ("gift open", "reward chime")

	-- ----- Mở capsule -----
	HatchShake = { id = 0, volume = 0.55, pitchVariance = 0.05, throttle = 0.2 }, -- capsule rung lắc: lạch cạch kim loại / máy rung, dài ~1-2s ("rattle", "mechanical shake")
	HatchPop = { id = 0, volume = 0.7, pitchVariance = 0.05, throttle = 0.2 }, -- bung nắp: "pop" + xì hơi ("pop", "burst", "air hiss")
	RevealCommon = { id = 0, volume = 0.5, pitchVariance = 0, throttle = 0.2 }, -- ra bot Common: "ting" đơn giản, nhẹ ("simple reveal", "ding")
	RevealRare = { id = 0, volume = 0.55, pitchVariance = 0, throttle = 0.2 }, -- ra bot Rare: chuông 2-3 nốt sáng hơn ("rare item", "chime")
	RevealEpic = { id = 0, volume = 0.6, pitchVariance = 0, throttle = 0.2 }, -- ra bot Epic: hợp âm phép thuật lấp lánh ("epic reveal", "magic sparkle")
	RevealLegendary = { id = 0, volume = 0.7, pitchVariance = 0, throttle = 0.2 }, -- ra bot Legendary: fanfare vàng hoành tráng, có kèn/hợp xướng ("legendary", "epic fanfare")
	RevealMythic = { id = 0, volume = 0.75, pitchVariance = 0, throttle = 0.2 }, -- ra bot Mythic: hoành tráng nhất, bùng năng lượng + hợp xướng thiên thần ("mythic", "heavenly choir")
	Shiny = { id = 0, volume = 0.55, pitchVariance = 0, throttle = 0.2 }, -- biến thể ✨ Shiny: lấp lánh "twinkle" kim tuyến, phát chồng lên Reveal ("twinkle", "glitter")
	Holo = { id = 0, volume = 0.6, pitchVariance = 0, throttle = 0.2 }, -- biến thể 🌈 Holo: synth shimmer cầu vồng, ngân dài hơn Shiny ("shimmer", "rainbow magic")
	Void = { id = 0, volume = 0.65, pitchVariance = 0, throttle = 0.2 }, -- biến thể 🌌 Void: tiếng hút trầm của hố đen + ngân sáng ("black hole", "deep whoosh", "cosmic")
	RevealSecret = { id = 0, volume = 0.8, pitchVariance = 0, throttle = 0.2 }, -- ra bot SECRET: hợp xướng + chuông + bùng nổ, hoành tráng hơn cả Mythic ("secret reveal", "divine", "ultra rare")
	Fuse = { id = 0, volume = 0.65, pitchVariance = 0, throttle = 0.2 }, -- gộp bot (Fuse): hút năng lượng vào rồi bùng ra ("energy charge", "merge", "fusion")

	-- ----- Kỹ năng (AI Cores) -----
	Pulse = { id = 0, volume = 0.6, pitchVariance = 0.06, throttle = 0.1 }, -- Pulse: sóng xung kích điện từ "vùm" trầm ("shockwave", "energy blast")
	Dash = { id = 0, volume = 0.55, pitchVariance = 0.08, throttle = 0.1 }, -- Dash: lướt gió nhanh ("dash", "swoosh")
	Overclock = { id = 0, volume = 0.6, pitchVariance = 0, throttle = 0.3 }, -- Overclock: động cơ/điện rít lên tăng tốc ("power up", "electric surge", "charge up")
	Shield = { id = 0, volume = 0.6, pitchVariance = 0, throttle = 0.3 }, -- Shield: khiên năng lượng bật lên "vzzm" ("force field", "shield activate")

	-- ----- Chiến đấu -----
	BotShot = { id = 0, volume = 0.3, pitchVariance = 0.15, throttle = 0.08, voices = 6 }, -- bot bắn (3D): laser "pew" nhỏ, rất ngắn < 0.2s vì bắn liên tục ("laser", "blaster pew")
	Hit = { id = 0, volume = 0.35, pitchVariance = 0.15, throttle = 0.05, voices = 6 }, -- trúng quái (3D): "tink"/"thud" kim loại ngắn ("impact", "metal hit")
	Hurt = { id = 0, volume = 0.55, pitchVariance = 0.1, throttle = 0.25 }, -- chính mình bị đánh (2D): nhiễu sóng chói / "oof" điện tử ngắn ("damage", "glitch hit")
	Explode = { id = 0, volume = 0.6, pitchVariance = 0.12, throttle = 0.05 }, -- quái/drone nổ (3D): nổ robot vừa phải ("explosion", "robot destroyed")
	BossAlert = { id = 0, volume = 0.7, pitchVariance = 0, throttle = 1 }, -- boss xuất hiện: còi báo động trầm, đáng sợ 2-3s ("alarm", "warning siren")

	-- ----- Sự kiện Glitch Floor -----
	Countdown = { id = 0, volume = 0.6, pitchVariance = 0, throttle = 0.3 }, -- đếm 3-2-1: 1 tiếng "bíp" ngắn ("countdown beep")
	Go = { id = 0, volume = 0.7, pitchVariance = 0, throttle = 0.3 }, -- GO!: "bíp" cao, dài hơn hoặc còi xuất phát ("start horn", "go beep")
	Win = { id = 0, volume = 0.75, pitchVariance = 0, throttle = 1 }, -- thắng lượt: fanfare chiến thắng 2-4s ("victory", "win jingle")
	Eliminated = { id = 0, volume = 0.6, pitchVariance = 0, throttle = 1 }, -- bị loại / rơi khỏi sàn: "wah-wah" thua hoặc tiếng rơi + nhiễu ("fail", "lose", "fall")

	-- ----- Khác -----
	Bubble = { id = 0, volume = 0.3, pitchVariance = 0.2, throttle = 0.06, voices = 3 }, -- bong bóng ở nút menu: "bloop" nhỏ ("bubble pop")
	Warp = { id = 0, volume = 0.6, pitchVariance = 0.03, throttle = 0.5 }, -- dịch chuyển (Warp, vào/ra Glitch Floor): whoosh cổng không gian ("teleport", "portal warp")
}

return AudioConfig
