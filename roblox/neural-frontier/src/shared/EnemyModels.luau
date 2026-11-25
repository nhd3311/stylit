-- Model riêng cho từng loại quái và boss, dựng bằng Part (dùng chung bộ dụng cụ của BotModels).
-- Mỗi vùng một kiểu quái + một boss có dáng riêng, nhiều màu, có cử động (cánh quạt quay, chân bò,
-- đuôi vung, cánh đập, vòng quay...). Client dựng model và cho bám theo "thân" vô hình của server.
--
--   EnemyModels.Build(modelId, size, color, elite) -> rig (giống BotModels: model, body, pieces, size)
--   BotModels.Pose(rig, cframe, t) để đặt vị trí + chạy hoạt ảnh.
-- Mặt trước là hướng -Z. Kích thước tính theo s = đường kính thân (Config: quái 3, boss 9-18).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotModels = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BotModels"))

local K = BotModels.Kit
local newPart, add, swing, stick, makeRig = K.newPart, K.add, K.swing, K.stick, K.makeRig
local VERTICAL, FACING = K.VERTICAL, K.FACING
local METAL, GOLD, WHITE, NEON = K.METAL, K.GOLD, K.WHITE, K.NEON
local METAL_MAT = Enum.Material.Metal
local GLASS = Enum.Material.Glass
local ICE = Enum.Material.Ice
local ROCK = Enum.Material.Slate

local EnemyModels = {}

local function spin(axis, joint, speed)
	return { kind = "spin", axis = axis, joint = joint, speed = speed }
end

-- vòng các khối nhỏ bay quanh tâm (mảnh vỡ, sao, khối pixel)
local function orbit(rig, s, count, radius, y, size, colors, speed, shape)
	for k = 0, count - 1 do
		local a = k / count * math.pi * 2
		local color = colors[k % #colors + 1]
		add(rig, newPart(shape or "Block", Vector3.one * size * s, color, NEON), CFrame.new(math.cos(a) * radius * s, (y + math.sin(a * 2) * 0.08) * s, math.sin(a) * radius * s) * CFrame.Angles(math.pi / 4, a, math.pi / 4), spin("Y", Vector3.zero, speed))
	end
end

local builders = {}

-- ================= Quái thường =================

-- 🌿 Rogue Drone: vỏ trắng, mắt to giận dữ, cánh quạt trên đầu, 2 tay kẹp
function builders.Drone(s, c)
	local rig = makeRig(newPart("Ellipsoid", Vector3.new(1, 0.75, 1) * s, Color3.fromRGB(240, 244, 252)))
	add(rig, newPart("Cylinder", Vector3.new(0.12 * s, 1.04 * s, 1.04 * s), c, NEON), VERTICAL)
	add(rig, newPart("Ball", Vector3.one * 0.5 * s, Color3.fromRGB(40, 50, 90)), CFrame.new(0, 0.04 * s, -0.3 * s))
	add(rig, newPart("Ball", Vector3.one * 0.3 * s, c, NEON), CFrame.new(0, 0.04 * s, -0.45 * s))
	for side = -1, 1, 2 do
		-- lông mày giận dữ
		add(rig, newPart("Block", Vector3.new(0.24, 0.06, 0.06) * s, c:Lerp(Color3.new(0, 0, 0), 0.3)), CFrame.new(side * 0.12 * s, 0.3 * s, -0.42 * s) * CFrame.Angles(0, 0, side * 0.45))
		local pinch = swing("X", Vector3.new(side * 0.4 * s, -0.15 * s, -0.1 * s), 4, 0.4, side)
		stick(rig, s, Vector3.new(side * 0.4, -0.15, -0.1) * s, Vector3.new(side * 0.5, -0.5, -0.35) * s, 0.08 * s, METAL, nil, pinch)
		add(rig, newPart("Ball", Vector3.one * 0.18 * s, c, NEON), CFrame.new(Vector3.new(side * 0.5, -0.55, -0.38) * s), pinch)
	end
	stick(rig, s, Vector3.new(0, 0.35, 0) * s, Vector3.new(0.001, 0.6, 0) * s, 0.1 * s, METAL)
	local rotor = spin("Y", Vector3.zero, 18)
	for k = 0, 1 do
		add(rig, newPart("Block", Vector3.new(1.35, 0.04, 0.16) * s, c:Lerp(WHITE, 0.4)), CFrame.new(0, 0.62 * s, 0) * CFrame.Angles(0, k * math.pi / 2, 0), rotor)
	end
	add(rig, newPart("Ball", Vector3.one * 0.3 * s, c, NEON, 0.35), CFrame.new(0, -0.42 * s, 0))
	return rig
end

-- 🏜️ Scrap Hunter: bọ cạp máy, càng kẹp + đuôi cong có ngòi neon
function builders.Scorpion(s, c)
	local shell = Color3.fromRGB(210, 130, 70)
	local rig = makeRig(newPart("Ellipsoid", Vector3.new(1.1, 0.5, 1.3) * s, shell))
	add(rig, newPart("Ellipsoid", Vector3.new(0.8, 0.3, 0.9) * s, shell:Lerp(WHITE, 0.25)), CFrame.new(0, 0.14 * s, 0.05 * s))
	add(rig, newPart("Ellipsoid", Vector3.new(0.7, 0.35, 0.45) * s, METAL), CFrame.new(0, 0.02 * s, -0.62 * s))
	for side = -1, 1, 2 do
		for k = 0, 1 do
			add(rig, newPart("Ball", Vector3.one * 0.1 * s, c, NEON), CFrame.new(side * (0.08 + k * 0.12) * s, 0.14 * s, -0.8 * s))
		end
		stick(rig, s, Vector3.new(side * 0.35, 0, -0.55) * s, Vector3.new(side * 0.6, 0.05, -0.95) * s, 0.12 * s, shell)
		local snap = swing("Y", Vector3.new(side * 0.6 * s, 0.05 * s, -0.95 * s), 6, 0.25, side)
		add(rig, newPart("Ellipsoid", Vector3.new(0.32, 0.22, 0.45) * s, shell:Lerp(c, 0.4)), CFrame.new(side * 0.62 * s, 0.05 * s, -1.15 * s), snap)
		add(rig, newPart("Ellipsoid", Vector3.new(0.1, 0.1, 0.32) * s, c, NEON), CFrame.new(side * 0.5 * s, 0.05 * s, -1.18 * s))
		for k = 1, 3 do
			local z = -0.35 + k * 0.25
			local step = swing("X", Vector3.new(side * 0.45 * s, -0.05 * s, z * s), 8, 0.3, k * 1.7 + side)
			stick(rig, s, Vector3.new(side * 0.45, -0.05, z) * s, Vector3.new(side * 0.85, -0.42, z + 0.05) * s, 0.07 * s, METAL, nil, step)
		end
	end
	local tail = swing("X", Vector3.new(0, 0.1 * s, 0.6 * s), 3, 0.15)
	for k, spec in { { 0.15, 0.75, 0.36 }, { 0.45, 0.98, 0.32 }, { 0.82, 0.98, 0.28 }, { 1.05, 0.72, 0.24 } } do
		add(rig, newPart("Ball", Vector3.one * spec[3] * s, if k % 2 == 0 then shell else shell:Lerp(WHITE, 0.2)), CFrame.new(0, spec[1] * s, spec[2] * s), tail)
	end
	add(rig, newPart("Ellipsoid", Vector3.new(0.14, 0.14, 0.42) * s, c, NEON), CFrame.new(0, 0.98 * s, 0.45 * s) * CFrame.Angles(0.5, 0, 0), tail)
	return rig
end

-- 🌃 Neon Wraith: áo choàng hologram tím nhiều lớp, mặt nạ trắng mắt khe, 2 bàn tay sáng
function builders.Wraith(s, c)
	local rig = makeRig(newPart("Ellipsoid", Vector3.new(0.9, 0.85, 0.9) * s, c:Lerp(WHITE, 0.15)))
	for k, spec in { { -0.35, 1.0 }, { -0.75, 0.8 }, { -1.1, 0.55 } } do
		add(rig, newPart("Ellipsoid", Vector3.new(spec[2], 0.6, spec[2]) * s, c, NEON, 0.35 + k * 0.1), CFrame.new(0, spec[1] * s, 0.05 * s), swing("X", Vector3.new(0, -0.2 * s, 0), 2.2, 0.08 * k, k))
	end
	add(rig, newPart("Ellipsoid", Vector3.new(0.5, 0.55, 0.14) * s, Color3.fromRGB(245, 245, 255)), CFrame.new(0, -0.02 * s, -0.4 * s))
	for side = -1, 1, 2 do
		add(rig, newPart("Ellipsoid", Vector3.new(0.14, 0.06, 0.04) * s, c, NEON), CFrame.new(side * 0.11 * s, 0.06 * s, -0.48 * s) * CFrame.Angles(0, 0, -side * 0.3))
		local reach = swing("X", Vector3.new(side * 0.45 * s, 0, 0), 2.5, 0.35, side)
		add(rig, newPart("Ball", Vector3.one * 0.28 * s, c:Lerp(WHITE, 0.4), NEON, 0.1), CFrame.new(side * 0.72 * s, -0.25 * s, -0.35 * s), reach)
	end
	for k = -1, 1 do
		add(rig, newPart("Block", Vector3.new(0.06, 0.24, 0.24) * s, c:Lerp(WHITE, 0.5), NEON), CFrame.new(k * 0.18 * s, (0.48 - math.abs(k) * 0.05) * s, 0.05 * s) * CFrame.Angles(math.pi / 4, 0, k * 0.3))
	end
	return rig
end

-- ❄️ Frost Sentinel: lõi sáng trong khối pha lê xoay, gai băng trên dưới, mảnh băng bay quanh
function builders.Sentinel(s, c)
	local rig = makeRig(newPart("Ball", Vector3.one * 0.55 * s, c, NEON))
	add(rig, newPart("Block", Vector3.one * 0.72 * s, Color3.fromRGB(190, 235, 255), GLASS, 0.45), CFrame.Angles(math.pi / 4, 0, math.pi / 4), spin("Y", Vector3.zero, 0.9))
	for _, dir in { 1, -1 } do
		add(rig, newPart("Block", Vector3.new(0.26, 0.8, 0.26) * s, Color3.fromRGB(215, 245, 255), ICE), CFrame.new(0, dir * 0.6 * s, 0) * CFrame.Angles(0, math.pi / 4, 0))
		add(rig, newPart("Block", Vector3.new(0.12, 0.5, 0.12) * s, c, NEON), CFrame.new(0, dir * 0.85 * s, 0) * CFrame.Angles(0, math.pi / 4, 0))
	end
	add(rig, newPart("Ball", Vector3.one * 0.22 * s, WHITE, NEON), CFrame.new(0, 0, -0.42 * s))
	orbit(rig, s, 5, 0.85, 0, 0.16, { Color3.fromRGB(200, 245, 255), c }, 1.3)
	return rig
end

-- 🌋 Magma Crawler: nhện đá nóng chảy, vết nứt dung nham, 6 chân bò, 3 mắt vàng
function builders.Crawler(s, c)
	local rock = Color3.fromRGB(150, 70, 45)
	local lava = Color3.fromRGB(255, 140, 40)
	local rig = makeRig(newPart("Ellipsoid", Vector3.new(1.0, 0.55, 1.1) * s, rock, ROCK))
	for _, spec in { { 0.2, 0.1, 0.4 }, { -0.25, -0.1, -0.6 }, { 0.05, 0.3, 1.2 }, { -0.1, -0.3, 0.2 } } do
		add(rig, newPart("Block", Vector3.new(0.05, 0.03, 0.5) * s, lava, NEON), CFrame.new(spec[1] * s, 0.27 * s, spec[2] * s) * CFrame.Angles(0, spec[3], 0))
	end
	add(rig, newPart("Ball", Vector3.one * 0.5 * s, lava, NEON, 0.3), CFrame.new(0, 0, 0.45 * s))
	add(rig, newPart("Ellipsoid", Vector3.new(0.55, 0.4, 0.45) * s, rock, ROCK), CFrame.new(0, 0.05 * s, -0.6 * s))
	for k = -1, 1 do
		add(rig, newPart("Ball", Vector3.one * 0.12 * s, Color3.fromRGB(255, 230, 80), NEON), CFrame.new(k * 0.13 * s, (0.14 - math.abs(k) * 0.04) * s, -0.8 * s))
	end
	for side = -1, 1, 2 do
		add(rig, newPart("Ellipsoid", Vector3.new(0.06, 0.18, 0.06) * s, lava, NEON), CFrame.new(side * 0.08 * s, -0.12 * s, -0.82 * s))
		for k = 1, 3 do
			local z = -0.45 + k * 0.28
			local step = swing("Y", Vector3.new(side * 0.4 * s, 0, z * s), 7, 0.3, k * 2 + side)
			local knee = Vector3.new(side * 0.85, 0.35, z - 0.05) * s
			stick(rig, s, Vector3.new(side * 0.4, 0, z) * s, knee, 0.1 * s, rock, ROCK, step)
			stick(rig, s, knee, Vector3.new(side * 1.15, -0.4, z - 0.1) * s, 0.08 * s, rock:Lerp(lava, 0.35), nil, step)
		end
	end
	return rig
end

-- 🌀 Rift Phantom: con mắt glitch phát sáng, khối pixel bay quanh, xúc tu đung đưa
function builders.Phantom(s, c)
	local rig = makeRig(newPart("Ball", Vector3.one * s, c, NEON, 0.45))
	add(rig, newPart("Ball", Vector3.one * 0.66 * s, Color3.fromRGB(250, 245, 255)), CFrame.new(0, 0, -0.12 * s))
	add(rig, newPart("Ball", Vector3.one * 0.36 * s, Color3.fromRGB(60, 255, 230), NEON), CFrame.new(0, 0, -0.34 * s))
	add(rig, newPart("Ball", Vector3.one * 0.16 * s, Color3.fromRGB(40, 20, 70)), CFrame.new(0, 0, -0.48 * s))
	orbit(rig, s, 6, 0.85, 0.1, 0.16, { c, Color3.fromRGB(60, 255, 230), WHITE }, 2.2)
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local x, z = math.cos(a) * 0.25, math.sin(a) * 0.25
		local sway = swing(if k % 2 == 0 then "X" else "Z", Vector3.new(x, -0.4, z) * s, 2.5, 0.35, k)
		stick(rig, s, Vector3.new(x, -0.4, z) * s, Vector3.new(x * 1.6, -1.1, z * 1.6) * s, 0.09 * s, c:Lerp(WHITE, 0.2), NEON, sway)
		add(rig, newPart("Ball", Vector3.one * 0.15 * s, Color3.fromRGB(60, 255, 230), NEON), CFrame.new(Vector3.new(x * 1.6, -1.12, z * 1.6) * s), sway)
	end
	return rig
end

-- ☁️ Aegis Drone: drone thiên thần trắng-vàng, hào quang, cánh lông vũ, khiên có chữ thập sáng
function builders.Seraph(s, c)
	local rig = makeRig(newPart("Ellipsoid", Vector3.new(0.8, 0.9, 0.8) * s, Color3.fromRGB(252, 250, 242)))
	add(rig, newPart("Cylinder", Vector3.new(0.1 * s, 0.84 * s, 0.84 * s), GOLD, METAL_MAT), CFrame.new(0, -0.1 * s, 0) * VERTICAL)
	add(rig, newPart("Block", Vector3.new(0.45, 0.1, 0.05) * s, c, NEON), CFrame.new(0, 0.12 * s, -0.38 * s))
	add(rig, newPart("Cylinder", Vector3.new(0.06 * s, 0.6 * s, 0.6 * s), GOLD, NEON, 0.1), CFrame.new(0, 0.62 * s, 0) * VERTICAL, spin("Y", Vector3.new(0, 0.62 * s, 0), 3))
	for side = -1, 1, 2 do
		local flap = swing("Z", Vector3.new(side * 0.3 * s, 0.15 * s, 0.2 * s), 4, side * 0.35)
		for k = 1, 3 do
			local len = 0.45 + k * 0.18
			add(rig, newPart("Ellipsoid", Vector3.new(len, 0.06, 0.24) * s, Color3.fromRGB(255, 252, 240):Lerp(GOLD, k / 4), if k == 3 then NEON else nil), CFrame.new(side * (0.3 + len / 2) * s, (0.3 - k * 0.07) * s, (0.15 + k * 0.08) * s) * CFrame.Angles(0, side * 0.2 * k, side * 0.25), flap)
		end
	end
	add(rig, newPart("Cylinder", Vector3.new(0.08 * s, 0.7 * s, 0.7 * s), GOLD, METAL_MAT), CFrame.new(0, -0.2 * s, -0.55 * s) * FACING)
	add(rig, newPart("Block", Vector3.new(0.08, 0.45, 0.04) * s, c, NEON), CFrame.new(0, -0.2 * s, -0.6 * s))
	add(rig, newPart("Block", Vector3.new(0.3, 0.08, 0.04) * s, c, NEON), CFrame.new(0, -0.12 * s, -0.6 * s))
	return rig
end

-- ================= Boss =================

-- 👑 Glitch King: đầu màn hình có mặt pixel, vương miện, áo choàng neon, khối pixel bay quanh, quyền trượng
function builders.King(s, c)
	local rig = makeRig(newPart("Block", Vector3.new(0.9, 0.78, 0.8) * s, c:Lerp(WHITE, 0.2)))
	add(rig, newPart("Block", Vector3.new(0.72, 0.56, 0.04) * s, Color3.fromRGB(40, 50, 110)), CFrame.new(0, 0, -0.41 * s))
	for side = -1, 1, 2 do
		add(rig, newPart("Block", Vector3.new(0.14, 0.14, 0.03) * s, WHITE, NEON), CFrame.new(side * 0.17 * s, 0.09 * s, -0.44 * s))
	end
	for k = -2, 2 do
		add(rig, newPart("Block", Vector3.new(0.08, 0.06, 0.03) * s, c, NEON), CFrame.new(k * 0.08 * s, (-0.14 + (if math.abs(k) == 2 then 0.05 else 0)) * s, -0.44 * s))
	end
	-- vương miện
	add(rig, newPart("Block", Vector3.new(0.8, 0.12, 0.7) * s, GOLD, METAL_MAT), CFrame.new(0, 0.45 * s, 0))
	for k = -2, 2 do
		add(rig, newPart("Block", Vector3.new(0.12, 0.3, 0.12) * s, GOLD, METAL_MAT), CFrame.new(k * 0.17 * s, (0.62 + (if k == 0 then 0.06 else 0)) * s, -0.3 * s) * CFrame.Angles(0, 0, math.pi / 4))
		add(rig, newPart("Ball", Vector3.one * 0.08 * s, if k % 2 == 0 then Color3.fromRGB(60, 255, 230) else c, NEON), CFrame.new(k * 0.17 * s, 0.47 * s, -0.36 * s))
	end
	-- áo choàng + vai
	add(rig, newPart("Block", Vector3.new(0.95, 1.1, 0.05) * s, c, NEON, 0.3), CFrame.new(0, -0.55 * s, 0.42 * s) * CFrame.Angles(0.2, 0, 0), swing("X", Vector3.new(0, -0.1 * s, 0.4 * s), 1.8, 0.12))
	for side = -1, 1, 2 do
		add(rig, newPart("Ball", Vector3.one * 0.32 * s, GOLD, METAL_MAT), CFrame.new(side * 0.5 * s, -0.3 * s, 0))
		local hand = swing("X", Vector3.new(side * 0.6 * s, -0.3 * s, 0), 2, 0.3, side)
		add(rig, newPart("Block", Vector3.one * 0.26 * s, c:Lerp(WHITE, 0.35)), CFrame.new(side * 0.72 * s, -0.6 * s, -0.25 * s), hand)
	end
	-- quyền trượng lơ lửng
	local wave = swing("Z", Vector3.new(0.9 * s, -0.2 * s, -0.1 * s), 1.5, 0.25)
	stick(rig, s, Vector3.new(0.9, -0.8, -0.1) * s, Vector3.new(0.95, 0.4, -0.1) * s, 0.07 * s, GOLD, METAL_MAT, wave)
	add(rig, newPart("Ball", Vector3.one * 0.22 * s, Color3.fromRGB(60, 255, 230), NEON), CFrame.new(Vector3.new(0.95, 0.5, -0.1) * s), wave)
	orbit(rig, s, 8, 1.15, 0.1, 0.1, { c, Color3.fromRGB(60, 255, 230), GOLD }, 1.2)
	return rig
end

-- ⚙️ Rust Titan: mech khổng lồ, kính chắn sáng, vai giáp, 2 tay đấm, ống xả trên lưng
function builders.Titan(s, c)
	local rust = Color3.fromRGB(205, 120, 60)
	local rig = makeRig(newPart("Block", Vector3.new(1.0, 0.8, 0.7) * s, rust))
	add(rig, newPart("Ball", Vector3.one * 0.3 * s, c:Lerp(Color3.fromRGB(255, 200, 60), 0.5), NEON), CFrame.new(0, 0.05 * s, -0.33 * s))
	add(rig, newPart("Block", Vector3.new(0.46, 0.34, 0.42) * s, METAL, METAL_MAT), CFrame.new(0, 0.58 * s, -0.05 * s))
	add(rig, newPart("Block", Vector3.new(0.4, 0.09, 0.04) * s, Color3.fromRGB(80, 230, 255), NEON), CFrame.new(0, 0.6 * s, -0.27 * s))
	stick(rig, s, Vector3.new(0.15, 0.75, 0) * s, Vector3.new(0.2, 1.05, 0.05) * s, 0.04 * s, METAL)
	add(rig, newPart("Ball", Vector3.one * 0.08 * s, Color3.fromRGB(255, 80, 60), NEON), CFrame.new(Vector3.new(0.2, 1.08, 0.05) * s))
	for side = -1, 1, 2 do
		add(rig, newPart("Block", Vector3.new(0.45, 0.28, 0.6) * s, rust:Lerp(WHITE, 0.15), METAL_MAT), CFrame.new(side * 0.68 * s, 0.38 * s, 0) * CFrame.Angles(0, 0, side * -0.25))
		add(rig, newPart("Block", Vector3.new(0.47, 0.05, 0.62) * s, c, NEON), CFrame.new(side * 0.68 * s, 0.25 * s, 0) * CFrame.Angles(0, 0, side * -0.25))
		local punch = swing("X", Vector3.new(side * 0.7 * s, 0.25 * s, 0), 1.6, 0.45, if side < 0 then 0 else math.pi)
		add(rig, newPart("Block", Vector3.new(0.3, 0.6, 0.32) * s, METAL, METAL_MAT), CFrame.new(side * 0.72 * s, -0.15 * s, 0), punch)
		add(rig, newPart("Block", Vector3.new(0.48, 0.42, 0.48) * s, rust), CFrame.new(side * 0.72 * s, -0.62 * s, -0.05 * s), punch)
		add(rig, newPart("Block", Vector3.new(0.5, 0.06, 0.5) * s, c, NEON), CFrame.new(side * 0.72 * s, -0.42 * s, -0.05 * s), punch)
		stick(rig, s, Vector3.new(side * 0.25, 0.3, 0.35) * s, Vector3.new(side * 0.3, 0.75, 0.5) * s, 0.14 * s, METAL, METAL_MAT)
		add(rig, newPart("Ball", Vector3.one * 0.14 * s, c, NEON), CFrame.new(Vector3.new(side * 0.3, 0.8, 0.52) * s))
	end
	add(rig, newPart("Ball", Vector3.one * 0.45 * s, c, NEON, 0.4), CFrame.new(0, -0.55 * s, 0))
	return rig
end

-- 🧠 Overmind: bộ não khổng lồ, gân neon, 3 mắt, dây cáp đung đưa, vòng năng lượng xoay
function builders.Overmind(s, c)
	local brain = Color3.fromRGB(220, 140, 240)
	local rig = makeRig(newPart("Ellipsoid", Vector3.new(1.0, 0.8, 1.1) * s, brain))
	add(rig, newPart("Block", Vector3.new(0.03, 0.42, 1.05) * s, c, NEON), CFrame.new(0, 0.2 * s, 0))
	for _, spec in { { 0.25, 0.3, -0.2 }, { -0.25, 0.3, -0.2 }, { 0.28, 0.28, 0.25 }, { -0.28, 0.28, 0.25 }, { 0.38, 0.05, 0 }, { -0.38, 0.05, 0 } } do
		add(rig, newPart("Ellipsoid", Vector3.new(0.3, 0.2, 0.36) * s, brain:Lerp(WHITE, 0.25)), CFrame.new(spec[1] * s, spec[2] * s, spec[3] * s))
	end
	for k = -1, 1 do
		local y = if k == 0 then 0.05 else -0.08
		add(rig, newPart("Ball", Vector3.one * 0.22 * s, WHITE), CFrame.new(k * 0.25 * s, y * s, -0.47 * s))
		add(rig, newPart("Ball", Vector3.one * 0.12 * s, c, NEON), CFrame.new(k * 0.25 * s, y * s, -0.57 * s))
	end
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local x, z = math.cos(a) * 0.3, math.sin(a) * 0.3
		local sway = swing(if k % 2 == 0 then "X" else "Z", Vector3.new(x, -0.3, z) * s, 1.8, 0.3, k)
		stick(rig, s, Vector3.new(x, -0.3, z) * s, Vector3.new(x * 1.8, -1.0, z * 1.8) * s, 0.07 * s, if k % 2 == 0 then METAL else c, if k % 2 == 0 then nil else NEON, sway)
		add(rig, newPart("Ball", Vector3.one * 0.1 * s, c, NEON), CFrame.new(Vector3.new(x * 1.8, -1.02, z * 1.8) * s), sway)
	end
	add(rig, newPart("Cylinder", Vector3.new(0.05 * s, 1.9 * s, 1.9 * s), c, NEON, 0.4), CFrame.Angles(0.35, 0, 0) * VERTICAL, spin("Y", Vector3.zero, 0.8))
	return rig
end

-- 🧊 Cryo Colossus: golem pha lê băng, lõi xanh rực, cụm tinh thể trên vai, nắm đấm băng
function builders.Colossus(s, c)
	local ice = Color3.fromRGB(170, 220, 255)
	local rig = makeRig(newPart("Block", Vector3.new(0.9, 0.9, 0.6) * s, ice, ICE))
	add(rig, newPart("Ball", Vector3.one * 0.34 * s, c, NEON), CFrame.new(0, 0.05 * s, -0.28 * s))
	add(rig, newPart("Block", Vector3.new(0.44, 0.38, 0.4) * s, ice:Lerp(WHITE, 0.3), ICE), CFrame.new(0, 0.66 * s, 0))
	for side = -1, 1, 2 do
		add(rig, newPart("Block", Vector3.new(0.09, 0.07, 0.04) * s, WHITE, NEON), CFrame.new(side * 0.1 * s, 0.68 * s, -0.21 * s))
		for k = 0, 2 do
			add(rig, newPart("Block", Vector3.new(0.14, 0.5 - k * 0.1, 0.14) * s, if k == 1 then c else Color3.fromRGB(220, 245, 255), if k == 1 then NEON else GLASS, if k == 1 then 0 else 0.25), CFrame.new(side * (0.45 + k * 0.1) * s, (0.62 + k * 0.05) * s, (k - 1) * 0.12 * s) * CFrame.Angles(0, 0, -side * (0.3 + k * 0.2)) * CFrame.Angles(0, math.pi / 4, 0))
		end
		local smash = swing("X", Vector3.new(side * 0.62 * s, 0.3 * s, 0), 1.4, 0.4, if side < 0 then 0 else math.pi)
		add(rig, newPart("Block", Vector3.new(0.3, 0.65, 0.3) * s, ice, ICE), CFrame.new(side * 0.66 * s, -0.08 * s, 0), smash)
		add(rig, newPart("Block", Vector3.new(0.46, 0.46, 0.46) * s, Color3.fromRGB(210, 240, 255), GLASS, 0.2), CFrame.new(side * 0.66 * s, -0.6 * s, 0) * CFrame.Angles(0, math.pi / 4, 0), smash)
		add(rig, newPart("Ball", Vector3.one * 0.2 * s, c, NEON), CFrame.new(side * 0.66 * s, -0.6 * s, 0), smash)
	end
	orbit(rig, s, 6, 1.0, -0.2, 0.12, { WHITE, c }, 0.9, "Ball")
	return rig
end

-- 🔥 Forge Tyrant: golem dung nham, sừng, vương miện lửa, búa nung đỏ
function builders.Tyrant(s, c)
	local rock = Color3.fromRGB(150, 65, 45)
	local lava = Color3.fromRGB(255, 130, 30)
	local rig = makeRig(newPart("Block", Vector3.new(1.0, 0.9, 0.7) * s, rock, ROCK))
	for _, spec in { { 0.2, 0.2, 0.5 }, { -0.25, -0.15, -0.6 }, { 0.1, -0.3, 1.1 } } do
		add(rig, newPart("Block", Vector3.new(0.5, 0.05, 0.03) * s, lava, NEON), CFrame.new(spec[1] * s, spec[2] * s, -0.36 * s) * CFrame.Angles(0, 0, spec[3]))
	end
	add(rig, newPart("Ball", Vector3.one * 0.3 * s, Color3.fromRGB(255, 220, 80), NEON), CFrame.new(0, 0.05 * s, -0.33 * s))
	add(rig, newPart("Block", Vector3.new(0.5, 0.4, 0.45) * s, rock, ROCK), CFrame.new(0, 0.65 * s, 0))
	for side = -1, 1, 2 do
		add(rig, newPart("Block", Vector3.new(0.1, 0.06, 0.04) * s, Color3.fromRGB(255, 230, 80), NEON), CFrame.new(side * 0.12 * s, 0.68 * s, -0.23 * s))
		stick(rig, s, Vector3.new(side * 0.22, 0.78, 0) * s, Vector3.new(side * 0.5, 1.15, -0.1) * s, 0.12 * s, Color3.fromRGB(70, 50, 45), nil)
		add(rig, newPart("Ball", Vector3.one * 0.1 * s, lava, NEON), CFrame.new(Vector3.new(side * 0.5, 1.17, -0.1) * s))
		add(rig, newPart("Ball", Vector3.one * 0.36 * s, rock, ROCK), CFrame.new(side * 0.6 * s, 0.32 * s, 0))
	end
	for k = -1, 1 do
		add(rig, newPart("Ellipsoid", Vector3.new(0.14, 0.32 - math.abs(k) * 0.08, 0.14) * s, if k == 0 then Color3.fromRGB(255, 220, 80) else lava, NEON, 0.1), CFrame.new(k * 0.13 * s, 0.98 * s, 0), swing("Z", Vector3.new(0, 0.86 * s, 0), 9 + k, 0.12, k))
	end
	-- tay trái: nắm đấm; tay phải: búa
	local left = swing("X", Vector3.new(-0.65 * s, 0.3 * s, 0), 1.5, 0.3)
	add(rig, newPart("Block", Vector3.new(0.3, 0.6, 0.3) * s, rock, ROCK), CFrame.new(-0.7 * s, -0.1 * s, 0), left)
	add(rig, newPart("Block", Vector3.new(0.42, 0.4, 0.42) * s, rock:Lerp(lava, 0.3)), CFrame.new(-0.7 * s, -0.55 * s, 0), left)
	local hammer = swing("X", Vector3.new(0.65 * s, 0.3 * s, 0), 1.2, 0.6, math.pi)
	add(rig, newPart("Block", Vector3.new(0.3, 0.6, 0.3) * s, rock, ROCK), CFrame.new(0.7 * s, -0.1 * s, 0), hammer)
	stick(rig, s, Vector3.new(0.7, -0.4, 0) * s, Vector3.new(0.7, -0.45, -0.9) * s, 0.09 * s, Color3.fromRGB(90, 70, 60), nil, hammer)
	add(rig, newPart("Block", Vector3.new(0.6, 0.45, 0.4) * s, METAL, METAL_MAT), CFrame.new(0.7 * s, -0.45 * s, -1.05 * s), hammer)
	add(rig, newPart("Block", Vector3.new(0.62, 0.08, 0.42) * s, lava, NEON), CFrame.new(0.7 * s, -0.45 * s, -1.05 * s), hammer)
	return rig
end

-- 🦋 The Glitch Queen: váy jelly nhiều tầng, vương miện cao, cánh bướm neon đập chậm, vòng glitch xoay
function builders.Queen(s, c)
	local rig = makeRig(newPart("Ellipsoid", Vector3.new(0.5, 0.7, 0.4) * s, c:Lerp(WHITE, 0.25)))
	for k, spec in { { -0.4, 0.8 }, { -0.7, 1.05 }, { -0.95, 1.25 } } do
		add(rig, newPart("Ellipsoid", Vector3.new(spec[2], 0.45, spec[2]) * s, c, NEON, 0.25 + k * 0.1), CFrame.new(0, spec[1] * s, 0), swing("Z", Vector3.new(0, -0.3 * s, 0), 1.6, 0.05 * k, k))
	end
	add(rig, newPart("Ball", Vector3.one * 0.38 * s, Color3.fromRGB(250, 240, 255)), CFrame.new(0, 0.55 * s, 0))
	for side = -1, 1, 2 do
		add(rig, newPart("Ball", Vector3.one * 0.08 * s, Color3.fromRGB(60, 255, 230), NEON), CFrame.new(side * 0.08 * s, 0.57 * s, -0.17 * s))
		-- cánh bướm: 2 cánh trên to, 2 cánh dưới nhỏ
		local flap = swing("Y", Vector3.new(side * 0.12 * s, 0.1 * s, 0.2 * s), 2.2, side * 0.35)
		add(rig, newPart("Ellipsoid", Vector3.new(1.1, 0.9, 0.04) * s, c, NEON, 0.25), CFrame.new(side * 0.62 * s, 0.35 * s, 0.3 * s) * CFrame.Angles(0, side * 0.3, side * -0.35), flap)
		add(rig, newPart("Ellipsoid", Vector3.new(0.7, 0.6, 0.03) * s, Color3.fromRGB(60, 255, 230), NEON, 0.2), CFrame.new(side * 0.5 * s, -0.2 * s, 0.3 * s) * CFrame.Angles(0, side * 0.3, side * 0.4), flap)
		add(rig, newPart("Ball", Vector3.one * 0.16 * s, c:Lerp(WHITE, 0.4), NEON), CFrame.new(side * 0.38 * s, 0.05 * s, -0.12 * s), swing("X", Vector3.new(side * 0.25 * s, 0.25 * s, 0), 1.8, 0.3, side))
	end
	for k = -2, 2 do
		add(rig, newPart("Block", Vector3.new(0.06, 0.3 + (2 - math.abs(k)) * 0.12, 0.06) * s, if k == 0 then Color3.fromRGB(60, 255, 230) else GOLD, if k == 0 then NEON else METAL_MAT), CFrame.new(k * 0.08 * s, (0.88 + (2 - math.abs(k)) * 0.05) * s, 0) * CFrame.Angles(0, 0, -k * 0.12))
	end
	add(rig, newPart("Cylinder", Vector3.new(0.05 * s, 2.1 * s, 2.1 * s), Color3.fromRGB(60, 255, 230), NEON, 0.4), CFrame.Angles(0.25, 0, -0.2) * VERTICAL, spin("Y", Vector3.zero, -1))
	orbit(rig, s, 6, 1.25, -0.3, 0.09, { c, Color3.fromRGB(60, 255, 230) }, 1.6)
	return rig
end

-- ☀️ Celestial Core: mặt trời vàng, 3 vòng quỹ đạo xoay chéo, cánh sáng, sao bay quanh
function builders.Celestial(s, c)
	local rig = makeRig(newPart("Ball", Vector3.one * 0.8 * s, Color3.fromRGB(255, 220, 110), NEON))
	add(rig, newPart("Ball", Vector3.one * 1.05 * s, Color3.fromRGB(255, 245, 200), NEON, 0.7))
	for k, tilt in { 0, 1.0, -1.0 } do
		add(rig, newPart("Cylinder", Vector3.new(0.06 * s, (1.55 + k * 0.2) * s, (1.55 + k * 0.2) * s), if k == 2 then Color3.fromRGB(140, 200, 255) else GOLD, NEON, 0.2), CFrame.Angles(tilt, 0, tilt * 0.4) * VERTICAL, spin(if k == 1 then "Y" elseif k == 2 then "X" else "Z", Vector3.zero, 0.6 + k * 0.25))
	end
	for side = -1, 1, 2 do
		local flap = swing("Z", Vector3.new(side * 0.4 * s, 0, 0.1 * s), 1.2, side * 0.25)
		for k = 1, 3 do
			add(rig, newPart("Ellipsoid", Vector3.new(0.9 + k * 0.15, 0.05, 0.22) * s, Color3.fromRGB(255, 250, 235):Lerp(GOLD, k / 4), NEON, 0.15), CFrame.new(side * (0.85 + k * 0.08) * s, (0.35 - k * 0.15) * s, 0.25 * s) * CFrame.Angles(0, side * 0.25, side * (0.5 - k * 0.25)), flap)
		end
	end
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		add(rig, newPart("Block", Vector3.new(0.08, 0.28, 0.08) * s, GOLD, NEON), CFrame.new(math.cos(a) * 0.32 * s, 0.6 * s, math.sin(a) * 0.32 * s) * CFrame.Angles(0, -a, 0.3), spin("Y", Vector3.zero, 0.5))
	end
	orbit(rig, s, 8, 1.35, 0, 0.09, { WHITE, Color3.fromRGB(140, 200, 255), GOLD }, 0.7, "Ball")
	return rig
end

-- ================= API =================

-- elite: quái tinh anh (thân vàng ánh kim + vòng hào quang vàng)
function EnemyModels.Build(modelId, size, color, elite)
	local builder = builders[modelId] or builders.Drone
	local rig = builder(size, color)
	if elite then
		for _, part in rig.model:GetDescendants() do
			if part:IsA("BasePart") and part.Material ~= NEON then
				part.Color = part.Color:Lerp(GOLD, 0.45)
				part.Reflectance = 0.15
			end
		end
		add(rig, newPart("Cylinder", Vector3.new(0.06 * size, 1.5 * size, 1.5 * size), GOLD, NEON, 0.3), CFrame.new(0, -0.35 * size, 0) * VERTICAL, spin("Y", Vector3.zero, 2))
	end
	rig.size = size
	BotModels.Pose(rig, CFrame.new(), 0)
	return rig
end

function EnemyModels.Has(modelId)
	return builders[modelId] ~= nil
end

return EnemyModels
