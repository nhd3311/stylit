-- Dựng "thú máy" cho bot hoàn toàn bằng Part (không cần mesh hay ảnh upload) + hoạt ảnh
-- (vẫy đuôi, đập cánh, xúc tu đung đưa, vòng hào quang quay).
-- Dùng chung cho server (bệ trưng bày) và client (đội bot bay theo, thẻ bot, Database).
--
-- rig = { model, body, pieces = { { part, cf, anim } } }
--   cf   : vị trí của part so với thân (body)
--   anim : nil hoặc { kind = "swing"|"spin", axis = "X"|"Y"|"Z", joint = Vector3, speed, amp, phase }
-- Mỗi khung hình gọi BotModels.Pose(rig, cframe, t) để đặt thân ở cframe và cử động các part.
-- Mặt trước của thú máy là hướng -Z (giống LookVector).

local BotModels = {}

local METAL = Color3.fromRGB(232, 238, 250)
local DARK = Color3.fromRGB(36, 40, 56)
local GOLD = Color3.fromRGB(255, 205, 70)
local SHINY_METAL = Color3.fromRGB(255, 212, 110)
local VOID_SHELL = Color3.fromRGB(70, 32, 130)
local VOID_GLOW = Color3.fromRGB(200, 100, 255)
local WHITE = Color3.new(1, 1, 1)
local NEON = Enum.Material.Neon
local PLASTIC = Enum.Material.SmoothPlastic
local HALF_PI = math.pi / 2

local function newPart(shape, size, color, material, transparency)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape == "Ellipsoid" then
		-- Part khối + SpecialMesh hình cầu = hình bầu dục co giãn theo Size
		p.Shape = Enum.PartType.Block
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	else
		p.Shape = Enum.PartType[shape]
	end
	p.Size = size
	p.Color = color
	-- đánh dấu part kim loại/tối để đổi màu khi là biến thể Shiny/Holo
	if color == METAL then
		p:SetAttribute("Metal", true)
	elseif color == DARK then
		p:SetAttribute("Dark", true)
	end
	p.Material = material or PLASTIC
	p.Transparency = transparency or 0
	return p
end

-- trục của Cylinder (vốn nằm theo X) xoay cho trùng hướng dir trong mặt phẳng YZ
local function alongYZ(dir)
	-- quay (0,0,1) quanh X một góc θ cho ra (0, -sinθ, cosθ)
	local d = dir.Unit
	return CFrame.Angles(math.atan2(-d.Y, d.Z), 0, 0) * CFrame.Angles(0, HALF_PI, 0)
end
local VERTICAL = CFrame.Angles(0, 0, HALF_PI) -- Cylinder dựng đứng / đĩa nằm ngang
local FACING = CFrame.Angles(0, HALF_PI, 0) -- Cylinder quay mặt đĩa về phía trước

local function makeRig(bodyPart)
	local model = Instance.new("Model")
	bodyPart.Name = "Body"
	bodyPart.Parent = model
	model.PrimaryPart = bodyPart
	return { model = model, body = bodyPart, pieces = {} }
end

local function add(rig, part, cf, anim)
	part.Parent = rig.model
	table.insert(rig.pieces, { part = part, cf = cf, anim = anim })
	return part
end

local function swing(axis, joint, speed, amp, phase)
	return { kind = "swing", axis = axis, joint = joint, speed = speed, amp = amp, phase = phase or 0 }
end

-- đẩy nhẹ phía dưới: luồng sáng như động cơ bay
local function thruster(rig, s, color, y, z)
	add(rig, newPart("Ball", Vector3.one * s * 0.28, color, NEON, 0.4), CFrame.new(0, y * s, (z or 0) * s))
end

-- ================= Các dáng =================

local forms = {}

function forms.Orb(s, c, accent)
	local rig = makeRig(newPart("Ball", Vector3.one * s, METAL))
	add(rig, newPart("Cylinder", Vector3.new(0.08 * s, 0.64 * s, 0.64 * s), DARK), CFrame.new(0, 0, -0.27 * s) * FACING)
	add(rig, newPart("Ball", Vector3.one * s * 0.42, c, NEON), CFrame.new(0, 0, -0.32 * s))
	for i, tilt in { 0.35, -0.5 } do
		add(rig, newPart("Cylinder", Vector3.new(0.08 * s, 1.7 * s, 1.7 * s), if i == 1 then c else accent, NEON, 0.4), CFrame.Angles(tilt, 0, 0) * VERTICAL, {
			kind = "spin",
			axis = "Y",
			joint = Vector3.zero,
			speed = if i == 1 then 2.5 else -1.8,
		})
	end
	local wobble = swing("Z", Vector3.new(0, 0.45 * s, 0), 3, 0.25)
	add(rig, newPart("Cylinder", Vector3.new(0.4 * s, 0.06 * s, 0.06 * s), METAL), CFrame.new(0, 0.62 * s, 0) * VERTICAL, wobble)
	add(rig, newPart("Ball", Vector3.one * s * 0.15, accent, NEON), CFrame.new(0, 0.84 * s, 0), wobble)
	thruster(rig, s, c, -0.52)
	return rig
end

local function ear(rig, s, x, y, z, color, inner, tall)
	for side = -1, 1, 2 do
		local tilt = CFrame.Angles(0, 0, math.pi / 4 - side * 0.25)
		local size = if tall then 0.34 else 0.3
		local twitch = swing("Z", Vector3.new(side * x * s, (y - 0.12) * s, z * s), 2.2, 0.08, side)
		add(rig, newPart("Block", Vector3.new(size * s, size * s, 0.12 * s), color), CFrame.new(side * x * s, y * s, z * s) * tilt, twitch)
		add(rig, newPart("Block", Vector3.new(size * 0.55 * s, size * 0.55 * s, 0.04 * s), inner, NEON), CFrame.new(side * x * s, y * s, (z - 0.07) * s) * tilt, twitch)
	end
end

function forms.Cat(s, c, accent)
	local rig = makeRig(newPart("Ball", Vector3.one * s, METAL))
	add(rig, newPart("Block", Vector3.new(0.72 * s, 0.32 * s, 0.12 * s), DARK), CFrame.new(0, 0.02 * s, -0.44 * s))
	for side = -1, 1, 2 do
		add(rig, newPart("Ball", Vector3.one * s * 0.15, c, NEON), CFrame.new(side * 0.17 * s, 0.04 * s, -0.5 * s))
		-- ria mép
		add(rig, newPart("Block", Vector3.new(0.3 * s, 0.02 * s, 0.02 * s), accent, NEON), CFrame.new(side * 0.42 * s, -0.1 * s, -0.36 * s) * CFrame.Angles(0, side * 0.3, side * 0.15))
	end
	ear(rig, s, 0.27, 0.42, -0.05, c, accent, false)
	add(rig, newPart("Ball", Vector3.one * s * 0.62, c), CFrame.new(0, -0.48 * s, 0.18 * s))
	local tail = swing("Y", Vector3.new(0, -0.45 * s, 0.45 * s), 3, 0.5)
	add(rig, newPart("Cylinder", Vector3.new(0.65 * s, 0.09 * s, 0.09 * s), c), CFrame.new(0, -0.25 * s, 0.7 * s) * alongYZ(Vector3.new(0, 0.56, 0.82)), tail)
	add(rig, newPart("Ball", Vector3.one * s * 0.18, accent, NEON), CFrame.new(0, -0.07 * s, 0.97 * s), tail)
	thruster(rig, s, c, -0.8, 0.2)
	return rig
end

function forms.Fox(s, c, accent)
	local rig = makeRig(newPart("Ball", Vector3.one * s, c))
	add(rig, newPart("Ellipsoid", Vector3.new(0.44 * s, 0.32 * s, 0.48 * s), METAL), CFrame.new(0, -0.12 * s, -0.42 * s))
	add(rig, newPart("Ball", Vector3.one * s * 0.11, DARK), CFrame.new(0, -0.06 * s, -0.66 * s))
	for side = -1, 1, 2 do
		add(rig, newPart("Ball", Vector3.one * s * 0.14, accent, NEON), CFrame.new(side * 0.2 * s, 0.1 * s, -0.4 * s))
	end
	ear(rig, s, 0.25, 0.5, 0, c, accent, true)
	add(rig, newPart("Ellipsoid", Vector3.new(0.55 * s, 0.5 * s, 0.78 * s), c), CFrame.new(0, -0.45 * s, 0.3 * s))
	local tail = swing("Y", Vector3.new(0, -0.4 * s, 0.6 * s), 2.5, 0.45)
	add(rig, newPart("Ellipsoid", Vector3.new(0.4 * s, 0.4 * s, 0.85 * s), c), CFrame.new(0, -0.25 * s, 0.98 * s) * CFrame.Angles(0.45, 0, 0), tail)
	add(rig, newPart("Ellipsoid", Vector3.new(0.32 * s, 0.32 * s, 0.36 * s), METAL), CFrame.new(0, -0.02 * s, 1.34 * s), tail)
	add(rig, newPart("Ball", Vector3.one * s * 0.14, accent, NEON), CFrame.new(0, 0.02 * s, 1.5 * s), tail)
	thruster(rig, s, c, -0.78, 0.3)
	return rig
end

function forms.Beetle(s, c, accent)
	local rig = makeRig(newPart("Ellipsoid", Vector3.new(1.1 * s, 0.75 * s, 1.3 * s), c))
	add(rig, newPart("Block", Vector3.new(0.04 * s, 0.06 * s, 1.15 * s), DARK), CFrame.new(0, 0.36 * s, 0.05 * s))
	for _, spot in { Vector3.new(0.25, 0.3, 0.15), Vector3.new(-0.25, 0.3, 0.15), Vector3.new(0.2, 0.28, -0.28), Vector3.new(-0.2, 0.28, -0.28) } do
		add(rig, newPart("Ball", Vector3.one * s * 0.16, accent, NEON), CFrame.new(spot * s))
	end
	add(rig, newPart("Ellipsoid", Vector3.new(0.6 * s, 0.45 * s, 0.45 * s), METAL), CFrame.new(0, -0.05 * s, -0.72 * s))
	for side = -1, 1, 2 do
		add(rig, newPart("Ball", Vector3.one * s * 0.14, c, NEON), CFrame.new(side * 0.17 * s, 0.02 * s, -0.9 * s))
		-- cánh trong suốt đập nhanh
		local flap = swing("Z", Vector3.new(side * 0.15 * s, 0.32 * s, 0.25 * s), 14, side * 0.5)
		add(rig, newPart("Ellipsoid", Vector3.new(0.6 * s, 0.04 * s, 0.95 * s), accent, NEON, 0.5), CFrame.new(side * 0.45 * s, 0.34 * s, 0.25 * s) * CFrame.Angles(0, 0, side * 0.3), flap)
	end
	local horn = Vector3.new(0, 0.7, -0.7)
	add(rig, newPart("Cylinder", Vector3.new(0.42 * s, 0.09 * s, 0.09 * s), METAL), CFrame.new(0, 0.15 * s, -0.95 * s) * alongYZ(horn))
	add(rig, newPart("Ball", Vector3.one * s * 0.14, accent, NEON), CFrame.new(Vector3.new(0, 0.15 * s, -0.95 * s) + horn.Unit * 0.22 * s))
	thruster(rig, s, c, -0.42, 0.1)
	return rig
end

function forms.Owl(s, c, accent)
	local rig = makeRig(newPart("Ellipsoid", Vector3.new(0.95 * s, 1.05 * s, 0.9 * s), c))
	add(rig, newPart("Ellipsoid", Vector3.new(0.62 * s, 0.7 * s, 0.25 * s), METAL), CFrame.new(0, -0.12 * s, -0.36 * s))
	for side = -1, 1, 2 do
		add(rig, newPart("Cylinder", Vector3.new(0.06 * s, 0.38 * s, 0.38 * s), METAL), CFrame.new(side * 0.2 * s, 0.22 * s, -0.41 * s) * FACING)
		add(rig, newPart("Ball", Vector3.one * s * 0.24, accent, NEON), CFrame.new(side * 0.2 * s, 0.22 * s, -0.44 * s))
		add(rig, newPart("Ball", Vector3.one * s * 0.1, DARK), CFrame.new(side * 0.2 * s, 0.22 * s, -0.55 * s))
		add(rig, newPart("Block", Vector3.new(0.2 * s, 0.2 * s, 0.08 * s), c), CFrame.new(side * 0.3 * s, 0.52 * s, -0.05 * s) * CFrame.Angles(0, 0, math.pi / 4 - side * 0.3))
		local flap = swing("Z", Vector3.new(side * 0.42 * s, 0.25 * s, 0.05 * s), 9, side * 0.45)
		add(rig, newPart("Ellipsoid", Vector3.new(0.16 * s, 0.75 * s, 0.6 * s), c:Lerp(DARK, 0.3)), CFrame.new(side * 0.5 * s, -0.05 * s, 0.05 * s), flap)
		add(rig, newPart("Ellipsoid", Vector3.new(0.06 * s, 0.42 * s, 0.42 * s), accent, NEON, 0.2), CFrame.new(side * 0.59 * s, -0.2 * s, 0.08 * s), flap)
	end
	add(rig, newPart("Block", Vector3.one * s * 0.12, GOLD), CFrame.new(0, 0.08 * s, -0.47 * s) * CFrame.Angles(0, 0, math.pi / 4))
	thruster(rig, s, c, -0.58)
	return rig
end

function forms.Jelly(s, c, accent)
	local rig = makeRig(newPart("Ellipsoid", Vector3.new(1.1 * s, 0.8 * s, 1.1 * s), c, NEON, 0.45))
	add(rig, newPart("Ball", Vector3.one * s * 0.45, METAL), CFrame.new(0, -0.05 * s, 0))
	add(rig, newPart("Ball", Vector3.one * s * 0.2, accent, NEON), CFrame.new(0, -0.02 * s, -0.2 * s))
	add(rig, newPart("Cylinder", Vector3.new(0.08 * s, 1.12 * s, 1.12 * s), METAL), CFrame.new(0, -0.2 * s, 0) * VERTICAL)
	for side = -1, 1, 2 do
		add(rig, newPart("Ball", Vector3.one * s * 0.12, DARK), CFrame.new(side * 0.18 * s, 0.05 * s, -0.5 * s))
	end
	for i = 1, 5 do
		local angle = (i - 1) / 5 * math.pi * 2
		local x, z = math.cos(angle) * 0.3 * s, math.sin(angle) * 0.3 * s
		local sway = swing(if i % 2 == 0 then "X" else "Z", Vector3.new(x, -0.25 * s, z), 3, 0.35, i)
		add(rig, newPart("Cylinder", Vector3.new(0.7 * s, 0.08 * s, 0.08 * s), accent, NEON, 0.2), CFrame.new(x, -0.6 * s, z) * VERTICAL, sway)
		add(rig, newPart("Ball", Vector3.one * s * 0.13, accent, NEON), CFrame.new(x, -0.95 * s, z), sway)
	end
	return rig
end

function forms.Dragon(s, c, accent)
	local rig = makeRig(newPart("Ellipsoid", Vector3.new(0.75 * s, 0.7 * s, 1.15 * s), c))
	add(rig, newPart("Ellipsoid", Vector3.new(0.5 * s, 0.45 * s, 0.9 * s), METAL), CFrame.new(0, -0.15 * s, -0.02 * s))
	add(rig, newPart("Ellipsoid", Vector3.new(0.62 * s, 0.5 * s, 0.72 * s), c), CFrame.new(0, 0.42 * s, -0.62 * s))
	add(rig, newPart("Ellipsoid", Vector3.new(0.42 * s, 0.3 * s, 0.45 * s), METAL), CFrame.new(0, 0.32 * s, -0.95 * s))
	for side = -1, 1, 2 do
		add(rig, newPart("Ball", Vector3.one * s * 0.13, accent, NEON), CFrame.new(side * 0.2 * s, 0.5 * s, -0.85 * s))
		add(rig, newPart("Cylinder", Vector3.new(0.42 * s, 0.07 * s, 0.07 * s), METAL), CFrame.new(side * 0.18 * s, 0.74 * s, -0.42 * s) * alongYZ(Vector3.new(0, 0.56, 0.82)))
		-- cánh lớn: xương kim loại + màng neon
		local flap = swing("Z", Vector3.new(side * 0.3 * s, 0.3 * s, 0), 6, side * 0.55)
		add(rig, newPart("Cylinder", Vector3.new(1.15 * s, 0.08 * s, 0.08 * s), METAL), CFrame.new(side * 0.85 * s, 0.36 * s, -0.25 * s), flap)
		add(rig, newPart("Ellipsoid", Vector3.new(1.25 * s, 0.05 * s, 0.8 * s), c:Lerp(accent, 0.5), NEON, 0.35), CFrame.new(side * 0.88 * s, 0.32 * s, 0.08 * s), flap)
	end
	for _, z in { -0.2, 0.1, 0.38 } do
		add(rig, newPart("Block", Vector3.new(0.06 * s, 0.18 * s, 0.18 * s), accent, NEON), CFrame.new(0, (0.36 - math.max(0, z) * 0.1) * s, z * s) * CFrame.Angles(math.pi / 4, 0, 0))
	end
	local tail = swing("Y", Vector3.new(0, 0, 0.5 * s), 2.5, 0.4)
	add(rig, newPart("Ellipsoid", Vector3.new(0.35 * s, 0.32 * s, 0.8 * s), c), CFrame.new(0, -0.08 * s, 0.88 * s) * CFrame.Angles(0.15, 0, 0), tail)
	add(rig, newPart("Block", Vector3.new(0.06 * s, 0.26 * s, 0.26 * s), accent, NEON), CFrame.new(0, -0.06 * s, 1.3 * s) * CFrame.Angles(math.pi / 4, 0, 0), tail)
	return rig
end

-- ---------- dáng mới ----------

-- trục X của part (Cylinder nằm theo X) hướng theo dir; dir không được thẳng đứng tuyệt đối
local function along(pos, dir)
	return CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, HALF_PI, 0)
end

-- thanh trụ nối 2 điểm (xương tay, chân, sừng...)
local function stick(rig, s, a, b, thick, color, material, anim)
	local dir = b - a
	if math.abs(dir.Unit.Y) > 0.999 then
		dir += Vector3.new(0, 0, 0.001)
	end
	return add(rig, newPart("Cylinder", Vector3.new(dir.Magnitude, thick, thick), color, material), along((a + b) / 2, dir), anim)
end

function forms.Bunny(s, c, accent)
	local rig = makeRig(newPart("Ball", Vector3.one * s, METAL))
	add(rig, newPart("Ellipsoid", Vector3.new(0.72 * s, 0.42 * s, 0.14 * s), DARK), CFrame.new(0, 0.05 * s, -0.43 * s))
	for side = -1, 1, 2 do
		add(rig, newPart("Ball", Vector3.one * s * 0.16, c, NEON), CFrame.new(side * 0.16 * s, 0.08 * s, -0.5 * s))
		add(rig, newPart("Ball", Vector3.one * s * 0.13, accent, NEON, 0.35), CFrame.new(side * 0.3 * s, -0.14 * s, -0.38 * s))
		-- tai dài cụp xuống nhịp nhàng
		local flop = swing("X", Vector3.new(side * 0.2 * s, 0.42 * s, 0), 2.4, 0.18, side)
		add(rig, newPart("Ellipsoid", Vector3.new(0.24 * s, 0.85 * s, 0.13 * s), c), CFrame.new(side * 0.2 * s, 0.86 * s, 0.03 * s) * CFrame.Angles(0, 0, -side * 0.18), flop)
		add(rig, newPart("Ellipsoid", Vector3.new(0.12 * s, 0.62 * s, 0.04 * s), accent, NEON), CFrame.new(side * 0.2 * s, 0.86 * s, -0.04 * s) * CFrame.Angles(0, 0, -side * 0.18), flop)
		add(rig, newPart("Ellipsoid", Vector3.new(0.3 * s, 0.18 * s, 0.44 * s), c), CFrame.new(side * 0.24 * s, -0.5 * s, -0.12 * s))
	end
	add(rig, newPart("Ball", Vector3.one * s * 0.1, accent, NEON), CFrame.new(0, -0.06 * s, -0.53 * s))
	add(rig, newPart("Ball", Vector3.one * s * 0.32, WHITE), CFrame.new(0, -0.2 * s, 0.5 * s), swing("Y", Vector3.new(0, -0.2 * s, 0.4 * s), 7, 0.25))
	return rig
end

function forms.Penguin(s, c, accent)
	local rig = makeRig(newPart("Ellipsoid", Vector3.new(0.9 * s, 1.1 * s, 0.85 * s), c))
	add(rig, newPart("Ellipsoid", Vector3.new(0.64 * s, 0.86 * s, 0.32 * s), METAL), CFrame.new(0, -0.1 * s, -0.31 * s))
	for side = -1, 1, 2 do
		add(rig, newPart("Ball", Vector3.one * s * 0.18, METAL), CFrame.new(side * 0.15 * s, 0.28 * s, -0.35 * s))
		add(rig, newPart("Ball", Vector3.one * s * 0.1, accent, NEON), CFrame.new(side * 0.15 * s, 0.28 * s, -0.44 * s))
		local flap = swing("Z", Vector3.new(side * 0.42 * s, 0.15 * s, 0), 5, side * 0.4)
		add(rig, newPart("Ellipsoid", Vector3.new(0.14 * s, 0.64 * s, 0.36 * s), c:Lerp(DARK, 0.2)), CFrame.new(side * 0.5 * s, -0.12 * s, 0) * CFrame.Angles(0, 0, side * 0.25), flap)
		add(rig, newPart("Ellipsoid", Vector3.new(0.3 * s, 0.1 * s, 0.38 * s), GOLD), CFrame.new(side * 0.18 * s, -0.58 * s, -0.12 * s))
	end
	add(rig, newPart("Ellipsoid", Vector3.new(0.22 * s, 0.12 * s, 0.3 * s), GOLD), CFrame.new(0, 0.14 * s, -0.5 * s))
	-- khăn quàng neon + đuôi khăn bay
	add(rig, newPart("Cylinder", Vector3.new(0.13 * s, 0.94 * s, 0.9 * s), accent, NEON, 0.1), CFrame.new(0, 0.06 * s, 0) * VERTICAL)
	add(rig, newPart("Block", Vector3.new(0.16 * s, 0.4 * s, 0.05 * s), accent, NEON, 0.1), CFrame.new(0.18 * s, -0.12 * s, 0.44 * s) * CFrame.Angles(0.3, 0, 0.2), swing("X", Vector3.new(0.18 * s, 0.06 * s, 0.42 * s), 5, 0.3))
	return rig
end

function forms.Mantis(s, c, accent)
	local rig = makeRig(newPart("Ellipsoid", Vector3.new(0.5 * s, 0.55 * s, 0.8 * s), c))
	add(rig, newPart("Ellipsoid", Vector3.new(0.55 * s, 0.5 * s, 0.95 * s), c:Lerp(accent, 0.25)), CFrame.new(0, -0.1 * s, 0.7 * s) * CFrame.Angles(0.2, 0, 0))
	for i, z in { 0.5, 0.75, 1.0 } do
		add(rig, newPart("Ellipsoid", Vector3.new((0.46 - i * 0.06) * s, 0.06 * s, 0.1 * s), accent, NEON), CFrame.new(0, (0.16 - i * 0.07) * s, z * s))
	end
	add(rig, newPart("Ellipsoid", Vector3.new(0.6 * s, 0.4 * s, 0.42 * s), METAL), CFrame.new(0, 0.38 * s, -0.45 * s))
	add(rig, newPart("Ellipsoid", Vector3.new(0.18 * s, 0.12 * s, 0.14 * s), DARK), CFrame.new(0, 0.26 * s, -0.66 * s))
	for side = -1, 1, 2 do
		add(rig, newPart("Ball", Vector3.one * s * 0.25, accent, NEON), CFrame.new(side * 0.27 * s, 0.44 * s, -0.5 * s))
		local twitch = swing("X", Vector3.new(side * 0.1 * s, 0.55 * s, -0.45 * s), 3, 0.2, side)
		stick(rig, s, Vector3.new(side * 0.1, 0.55, -0.45) * s, Vector3.new(side * 0.28, 1.0, -0.7) * s, 0.04 * s, METAL, nil, twitch)
		add(rig, newPart("Ball", Vector3.one * s * 0.1, accent, NEON), CFrame.new(Vector3.new(side * 0.28, 1.0, -0.7) * s), twitch)
		-- tay lưỡi hái: vung lên xuống
		local slash = swing("X", Vector3.new(side * 0.22 * s, 0.05 * s, -0.35 * s), 3.2, 0.35, side * 0.6)
		stick(rig, s, Vector3.new(side * 0.22, 0.05, -0.35) * s, Vector3.new(side * 0.3, 0.35, -0.8) * s, 0.1 * s, METAL, nil, slash)
		add(rig, newPart("Ellipsoid", Vector3.new(0.09 * s, 0.6 * s, 0.16 * s), accent, NEON), CFrame.new(Vector3.new(side * 0.3, 0.1, -0.86) * s) * CFrame.Angles(-0.35, 0, 0), slash)
		local flap = swing("Z", Vector3.new(side * 0.1 * s, 0.25 * s, 0.3 * s), 12, side * 0.35)
		add(rig, newPart("Ellipsoid", Vector3.new(0.5 * s, 0.04 * s, 1.0 * s), accent, NEON, 0.55), CFrame.new(side * 0.32 * s, 0.25 * s, 0.55 * s) * CFrame.Angles(0, -side * 0.15, side * 0.2), flap)
		for _, z in { -0.1, 0.25 } do
			stick(rig, s, Vector3.new(side * 0.2, -0.15, z) * s, Vector3.new(side * 0.45, -0.6, z + 0.05) * s, 0.06 * s, DARK)
		end
	end
	return rig
end

function forms.Phoenix(s, c, accent)
	local rig = makeRig(newPart("Ellipsoid", Vector3.new(0.7 * s, 0.75 * s, 1.0 * s), c))
	add(rig, newPart("Ellipsoid", Vector3.new(0.5 * s, 0.55 * s, 0.6 * s), METAL), CFrame.new(0, -0.12 * s, -0.25 * s))
	add(rig, newPart("Ball", Vector3.one * s * 0.52, c), CFrame.new(0, 0.45 * s, -0.5 * s))
	add(rig, newPart("Ellipsoid", Vector3.new(0.16 * s, 0.14 * s, 0.3 * s), GOLD), CFrame.new(0, 0.4 * s, -0.8 * s) * CFrame.Angles(0.3, 0, 0))
	for side = -1, 1, 2 do
		add(rig, newPart("Ball", Vector3.one * s * 0.13, accent, NEON), CFrame.new(side * 0.16 * s, 0.5 * s, -0.7 * s))
		-- cánh: 3 lông vũ dài dần, màu chuyển từ thân sang accent
		local flap = swing("Z", Vector3.new(side * 0.3 * s, 0.2 * s, 0), 5, side * 0.5)
		for k = 1, 3 do
			local len = 0.55 + k * 0.22
			add(rig, newPart("Ellipsoid", Vector3.new(len * s, 0.06 * s, 0.26 * s), c:Lerp(accent, k / 3), NEON, 0.1), CFrame.new(side * (0.3 + len / 2) * s, (0.24 - k * 0.04) * s, (-0.2 + k * 0.17) * s) * CFrame.Angles(0, side * (0.15 * k), 0), flap)
		end
	end
	-- mào lửa trên đầu
	for k = -1, 1 do
		local flick = swing("X", Vector3.new(0, 0.66 * s, -0.5 * s), 6, 0.15, k)
		add(rig, newPart("Ellipsoid", Vector3.new(0.08 * s, 0.4 * s, 0.14 * s), accent, NEON), CFrame.new(k * 0.08 * s, 0.82 * s, -0.42 * s + math.abs(k) * 0.05 * s) * CFrame.Angles(-0.5, 0, k * 0.35), flick)
	end
	-- đuôi lửa dài
	for k = -1, 1 do
		local sway = swing("Y", Vector3.new(0, -0.05 * s, 0.45 * s), 2.6, 0.3, k * 0.4)
		add(rig, newPart("Ellipsoid", Vector3.new(0.16 * s, 0.07 * s, 1.15 * s), c:Lerp(accent, 0.5 + k * 0.25), NEON, 0.05), CFrame.new(k * 0.14 * s, -0.25 * s, 1.0 * s) * CFrame.Angles(0.35, k * 0.25, 0), sway)
	end
	return rig
end

function forms.Serpent(s, c, accent)
	local rig = makeRig(newPart("Ellipsoid", Vector3.new(0.55 * s, 0.45 * s, 0.72 * s), c))
	add(rig, newPart("Ellipsoid", Vector3.new(0.4 * s, 0.22 * s, 0.4 * s), METAL), CFrame.new(0, -0.12 * s, -0.22 * s))
	for side = -1, 1, 2 do
		add(rig, newPart("Ball", Vector3.one * s * 0.13, accent, NEON), CFrame.new(side * 0.17 * s, 0.1 * s, -0.25 * s))
		add(rig, newPart("Ellipsoid", Vector3.new(0.35 * s, 0.05 * s, 0.3 * s), accent, NEON, 0.25), CFrame.new(side * 0.33 * s, 0.05 * s, 0.05 * s) * CFrame.Angles(0, side * 0.5, side * 0.3), swing("Z", Vector3.new(side * 0.22 * s, 0.05 * s, 0.05 * s), 4, side * 0.3))
	end
	-- thân dài: các đốt nhỏ dần, lượn sóng lệch pha nhau
	local sizes = { 0.5, 0.47, 0.43, 0.38, 0.32, 0.25 }
	for i, size in sizes do
		local z = 0.35 + i * 0.32
		local y = math.sin(i * 0.9) * 0.12
		local wave = swing("Y", Vector3.new(0, 0, 0.3 * s), 2.4, 0.06 + i * 0.03, -i * 0.7)
		add(rig, newPart("Ball", Vector3.one * size * s, if i % 2 == 0 then c else c:Lerp(METAL, 0.25)), CFrame.new(0, y * s, z * s), wave)
		add(rig, newPart("Block", Vector3.new(0.05 * s, size * 0.45 * s, size * 0.45 * s), accent, NEON), CFrame.new(0, (y + size * 0.42) * s, z * s) * CFrame.Angles(math.pi / 4, 0, 0), wave)
	end
	add(rig, newPart("Ball", Vector3.one * s * 0.16, accent, NEON), CFrame.new(0, 0.05 * s, 2.45 * s), swing("Y", Vector3.new(0, 0, 0.3 * s), 2.4, 0.25, -4.9))
	return rig
end

function forms.Golem(s, c, accent)
	local rig = makeRig(newPart("Block", Vector3.new(0.9 * s, 0.8 * s, 0.6 * s), c))
	add(rig, newPart("Ball", Vector3.one * s * 0.32, accent, NEON), CFrame.new(0, 0.04 * s, -0.27 * s))
	add(rig, newPart("Cylinder", Vector3.new(0.06 * s, 0.44 * s, 0.44 * s), METAL), CFrame.new(0, 0.04 * s, -0.3 * s) * FACING)
	add(rig, newPart("Block", Vector3.new(0.5 * s, 0.42 * s, 0.46 * s), METAL), CFrame.new(0, 0.62 * s, 0))
	add(rig, newPart("Block", Vector3.new(0.42 * s, 0.11 * s, 0.05 * s), accent, NEON), CFrame.new(0, 0.66 * s, -0.235 * s))
	for side = -1, 1, 2 do
		add(rig, newPart("Ball", Vector3.one * s * 0.36, c:Lerp(METAL, 0.3)), CFrame.new(side * 0.55 * s, 0.32 * s, 0))
		-- tay to vung ngược nhịp nhau
		local arm = swing("X", Vector3.new(side * 0.62 * s, 0.3 * s, 0), 2.2, 0.35, if side < 0 then 0 else math.pi)
		add(rig, newPart("Block", Vector3.new(0.26 * s, 0.6 * s, 0.28 * s), c), CFrame.new(side * 0.64 * s, -0.05 * s, 0), arm)
		add(rig, newPart("Block", Vector3.new(0.36 * s, 0.32 * s, 0.36 * s), METAL), CFrame.new(side * 0.64 * s, -0.48 * s, 0), arm)
		add(rig, newPart("Block", Vector3.new(0.38 * s, 0.05 * s, 0.38 * s), accent, NEON), CFrame.new(side * 0.64 * s, -0.36 * s, 0), arm)
		add(rig, newPart("Block", Vector3.new(0.3 * s, 0.32 * s, 0.32 * s), c:Lerp(DARK, 0.35)), CFrame.new(side * 0.22 * s, -0.55 * s, 0))
		add(rig, newPart("Block", Vector3.new(0.08 * s, 0.4 * s, 0.05 * s), accent, NEON), CFrame.new(side * 0.25 * s, 0.05 * s, 0.31 * s))
	end
	return rig
end

function forms.Whale(s, c, accent)
	local rig = makeRig(newPart("Ellipsoid", Vector3.new(1.0 * s, 0.8 * s, 1.6 * s), c))
	add(rig, newPart("Ellipsoid", Vector3.new(0.8 * s, 0.5 * s, 1.35 * s), METAL), CFrame.new(0, -0.18 * s, -0.05 * s))
	for k = -1, 1 do
		add(rig, newPart("Ellipsoid", Vector3.new(0.7 * s, 0.04 * s, 0.06 * s), accent, NEON), CFrame.new(0, -0.38 * s, (k * 0.25 - 0.1) * s))
	end
	for side = -1, 1, 2 do
		add(rig, newPart("Ball", Vector3.one * s * 0.2, WHITE), CFrame.new(side * 0.4 * s, 0.05 * s, -0.5 * s))
		add(rig, newPart("Ball", Vector3.one * s * 0.11, accent, NEON), CFrame.new(side * 0.46 * s, 0.05 * s, -0.56 * s))
		local fin = swing("Z", Vector3.new(side * 0.45 * s, -0.15 * s, -0.1 * s), 2.5, side * 0.35)
		add(rig, newPart("Ellipsoid", Vector3.new(0.6 * s, 0.07 * s, 0.32 * s), c:Lerp(accent, 0.35)), CFrame.new(side * 0.68 * s, -0.25 * s, -0.1 * s) * CFrame.Angles(0, 0, -side * 0.35), fin)
	end
	-- đuôi + vây đuôi quẫy lên xuống
	local tail = swing("X", Vector3.new(0, 0, 0.7 * s), 2, 0.25)
	add(rig, newPart("Ellipsoid", Vector3.new(0.38 * s, 0.32 * s, 0.65 * s), c), CFrame.new(0, 0.02 * s, 0.98 * s), tail)
	add(rig, newPart("Ellipsoid", Vector3.new(0.95 * s, 0.08 * s, 0.4 * s), accent, NEON, 0.15), CFrame.new(0, 0.06 * s, 1.3 * s), tail)
	-- vòi phun data trên lưng
	local spout = swing("Z", Vector3.new(0, 0.4 * s, -0.2 * s), 3, 0.15)
	stick(rig, s, Vector3.new(0, 0.38, -0.2) * s, Vector3.new(0, 0.72, -0.22) * s, 0.06 * s, METAL, nil, spout)
	for k = -1, 1 do
		add(rig, newPart("Ball", Vector3.one * s * 0.12, accent, NEON, 0.15), CFrame.new(k * 0.12 * s, (0.78 + (1 - math.abs(k)) * 0.06) * s, -0.22 * s), spout)
	end
	return rig
end

function forms.Crab(s, c, accent)
	local rig = makeRig(newPart("Ellipsoid", Vector3.new(1.2 * s, 0.55 * s, 0.9 * s), c))
	add(rig, newPart("Ellipsoid", Vector3.new(0.9 * s, 0.3 * s, 0.66 * s), c:Lerp(METAL, 0.35)), CFrame.new(0, 0.16 * s, 0.02 * s))
	for _, spot in { Vector3.new(0, 0.3, 0.05), Vector3.new(0.28, 0.24, 0.12), Vector3.new(-0.28, 0.24, 0.12) } do
		add(rig, newPart("Ball", Vector3.one * s * 0.14, accent, NEON), CFrame.new(spot * s))
	end
	add(rig, newPart("Ellipsoid", Vector3.new(0.3 * s, 0.1 * s, 0.1 * s), DARK), CFrame.new(0, -0.05 * s, -0.43 * s))
	for side = -1, 1, 2 do
		-- mắt trên cuống
		local look = swing("Z", Vector3.new(side * 0.18 * s, 0.2 * s, -0.32 * s), 2, 0.2, side)
		stick(rig, s, Vector3.new(side * 0.18, 0.2, -0.32) * s, Vector3.new(side * 0.22, 0.52, -0.36) * s, 0.06 * s, METAL, nil, look)
		add(rig, newPart("Ball", Vector3.one * s * 0.18, METAL), CFrame.new(Vector3.new(side * 0.22, 0.58, -0.36) * s), look)
		add(rig, newPart("Ball", Vector3.one * s * 0.1, accent, NEON), CFrame.new(Vector3.new(side * 0.22, 0.6, -0.44) * s), look)
		-- càng kẹp: lắc khép mở
		stick(rig, s, Vector3.new(side * 0.5, -0.02, -0.2) * s, Vector3.new(side * 0.72, 0.05, -0.62) * s, 0.12 * s, c)
		local snap = swing("Y", Vector3.new(side * 0.72 * s, 0.05 * s, -0.62 * s), 7, 0.22, side)
		add(rig, newPart("Ellipsoid", Vector3.new(0.3 * s, 0.26 * s, 0.42 * s), c:Lerp(accent, 0.3)), CFrame.new(side * 0.76 * s, 0.08 * s, -0.82 * s), snap)
		add(rig, newPart("Ellipsoid", Vector3.new(0.12 * s, 0.14 * s, 0.32 * s), accent, NEON), CFrame.new(side * 0.64 * s, 0.05 * s, -0.86 * s))
		for k = 1, 3 do
			local z = -0.15 + k * 0.17
			local step = swing("X", Vector3.new(side * 0.5 * s, -0.05 * s, z * s), 6, 0.25, k + side)
			stick(rig, s, Vector3.new(side * 0.5, -0.05, z) * s, Vector3.new(side * 0.85, -0.4, z + 0.05) * s, 0.06 * s, METAL, nil, step)
		end
	end
	return rig
end

-- ================= Phụ kiện (traits) =================
-- Mỗi bot có thể có danh sách traits trong Config để trông khác hẳn bot cùng dáng.
-- Đặt quanh "đỉnh đầu" của từng dáng (đơn vị = kích thước bot).
local HEADS = {
	Orb = Vector3.new(0, 0.48, 0),
	Cat = Vector3.new(0, 0.48, -0.05),
	Fox = Vector3.new(0, 0.48, 0),
	Beetle = Vector3.new(0, 0.38, -0.2),
	Owl = Vector3.new(0, 0.55, 0),
	Jelly = Vector3.new(0, 0.42, 0),
	Dragon = Vector3.new(0, 0.66, -0.62),
	Bunny = Vector3.new(0, 0.48, -0.1),
	Penguin = Vector3.new(0, 0.56, 0),
	Mantis = Vector3.new(0, 0.58, -0.45),
	Phoenix = Vector3.new(0, 0.7, -0.5),
	Serpent = Vector3.new(0, 0.24, -0.1),
	Golem = Vector3.new(0, 0.84, 0),
	Whale = Vector3.new(0, 0.42, -0.45),
	Crab = Vector3.new(0, 0.3, 0.05),
}

local traits = {}

function traits.Horns(rig, s, c, accent, h)
	for side = -1, 1, 2 do
		local base = (h + Vector3.new(side * 0.17, -0.04, 0.02)) * s
		local tip = base + Vector3.new(side * 0.2, 0.36, 0.12) * s
		stick(rig, s, base, tip, 0.09 * s, METAL)
		add(rig, newPart("Ball", Vector3.one * s * 0.1, accent, NEON), CFrame.new(tip))
	end
end

function traits.Crown(rig, s, c, accent, h)
	local center = (h + Vector3.new(0, 0.1, 0)) * s
	add(rig, newPart("Cylinder", Vector3.new(0.1 * s, 0.42 * s, 0.42 * s), GOLD, Enum.Material.Metal), CFrame.new(center) * VERTICAL)
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		local pos = center + Vector3.new(math.cos(a) * 0.17, 0.1, math.sin(a) * 0.17) * s
		add(rig, newPart("Block", Vector3.new(0.07, 0.18, 0.07) * s, GOLD, Enum.Material.Metal), CFrame.new(pos) * CFrame.Angles(0, a, math.pi / 4))
	end
	add(rig, newPart("Ball", Vector3.one * s * 0.1, accent, NEON), CFrame.new(center + Vector3.new(0, 0.02, -0.21) * s))
end

function traits.Antenna(rig, s, c, accent, h)
	local base = h * s
	local wobble = swing("Z", base, 3.5, 0.25)
	stick(rig, s, base, base + Vector3.new(0.02, 0.4, 0.05) * s, 0.04 * s, METAL, nil, wobble)
	add(rig, newPart("Ball", Vector3.one * s * 0.13, accent, NEON), CFrame.new(base + Vector3.new(0.02, 0.44, 0.05) * s), wobble)
end

function traits.Spikes(rig, s, c, accent, h)
	for k = 0, 2 do
		local pos = (h + Vector3.new(0, -0.08 - k * 0.1, 0.28 + k * 0.2)) * s
		add(rig, newPart("Block", Vector3.new(0.05, 0.22 - k * 0.04, 0.22 - k * 0.04) * s, accent, NEON), CFrame.new(pos) * CFrame.Angles(math.pi / 4, 0, 0))
	end
end

function traits.Crystals(rig, s, c, accent, h)
	local base = (h + Vector3.new(0, -0.12, 0.32)) * s
	for k = -1, 1 do
		add(rig, newPart("Block", Vector3.new(0.12, 0.34 - math.abs(k) * 0.1, 0.12) * s, accent, NEON, 0.15), CFrame.new(base + Vector3.new(k * 0.12, 0.12, math.abs(k) * 0.05) * s) * CFrame.Angles(0.25, 0, -k * 0.45) * CFrame.Angles(0, math.pi / 4, 0))
	end
end

function traits.Gears(rig, s, c, accent, h)
	local center = (h + Vector3.new(0, -0.35, 0.48)) * s
	local turn = { kind = "spin", axis = "Z", joint = center, speed = 2.5 }
	add(rig, newPart("Cylinder", Vector3.new(0.08 * s, 0.5 * s, 0.5 * s), GOLD, Enum.Material.Metal), CFrame.new(center) * FACING, turn)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		add(rig, newPart("Block", Vector3.new(0.1, 0.1, 0.09) * s, GOLD, Enum.Material.Metal), CFrame.new(center + Vector3.new(math.cos(a) * 0.27, math.sin(a) * 0.27, 0) * s) * CFrame.Angles(0, 0, a), turn)
	end
	add(rig, newPart("Ball", Vector3.one * s * 0.14, accent, NEON), CFrame.new(center + Vector3.new(0, 0, 0.03) * s))
end

function traits.Flame(rig, s, c, accent, h)
	local base = (h + Vector3.new(0, 0.12, 0)) * s
	local colors = { Color3.fromRGB(255, 120, 40), Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 90, 40) }
	for k = -1, 1 do
		local flick = swing("Z", base, 9 + k, 0.12, k * 1.3)
		add(rig, newPart("Ellipsoid", Vector3.new(0.14, 0.34 - math.abs(k) * 0.1, 0.14) * s, colors[k + 2], NEON, 0.1), CFrame.new(base + Vector3.new(k * 0.1, 0.12 - math.abs(k) * 0.04, 0) * s), flick)
	end
end

function traits.Shards(rig, s, c, accent, h)
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2
		add(rig, newPart("Block", Vector3.one * s * 0.14, if k % 2 == 0 then accent else c, NEON), CFrame.new(math.cos(a) * 0.9 * s, 0.15 * s, math.sin(a) * 0.9 * s) * CFrame.Angles(math.pi / 4, a, math.pi / 4), { kind = "spin", axis = "Y", joint = Vector3.zero, speed = 1.6 })
	end
end

function traits.Wings(rig, s, c, accent, h)
	for side = -1, 1, 2 do
		local joint = (h + Vector3.new(side * 0.15, -0.3, 0.3)) * s
		local flap = swing("Z", joint, 8, side * 0.45)
		add(rig, newPart("Ellipsoid", Vector3.new(0.75, 0.04, 0.4) * s, accent, NEON, 0.4), CFrame.new(joint + Vector3.new(side * 0.38, 0.12, 0.08) * s) * CFrame.Angles(0, -side * 0.3, side * 0.35), flap)
	end
end

-- ================= API =================

-- vòng/hào quang theo độ hiếm: Legendary 1 vòng vàng; Mythic vòng hồng + 3 viên ngọc bay quanh;
-- Secret 2 vòng chéo đổi màu cầu vồng + 4 quả cầu sáng bay quanh
local function rarityAura(rig, bot, s, h)
	local top = Vector3.new(0, (h.Y + 0.38) * s, h.Z * s)
	if bot.rarity == "Legendary" then
		add(rig, newPart("Cylinder", Vector3.new(0.05 * s, 0.55 * s, 0.55 * s), GOLD, NEON, 0.1), CFrame.new(top) * VERTICAL, { kind = "spin", axis = "Y", joint = top, speed = 3 })
	elseif bot.rarity == "Mythic" then
		add(rig, newPart("Cylinder", Vector3.new(0.06 * s, 0.6 * s, 0.6 * s), Color3.fromRGB(255, 90, 220), NEON, 0.05), CFrame.new(top) * VERTICAL, { kind = "spin", axis = "Y", joint = top, speed = 3 })
		for k = 0, 2 do
			local a = k / 3 * math.pi * 2
			add(rig, newPart("Block", Vector3.one * s * 0.16, Color3.fromRGB(255, 120, 230), NEON), CFrame.new(math.cos(a) * 0.95 * s, 0.25 * s, math.sin(a) * 0.95 * s) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), { kind = "spin", axis = "Y", joint = Vector3.zero, speed = 2.2 })
		end
	elseif bot.rarity == "Secret" then
		rig.rainbowParts = rig.rainbowParts or {}
		for k, tilt in { 0.6, -0.6 } do
			local ring = add(rig, newPart("Cylinder", Vector3.new(0.05 * s, 1.9 * s, 1.9 * s), WHITE, NEON, 0.3), CFrame.Angles(tilt, 0, tilt * 0.5) * VERTICAL, { kind = "spin", axis = "Y", joint = Vector3.zero, speed = if k == 1 then 1.8 else -1.4 })
			table.insert(rig.rainbowParts, ring)
		end
		local crown = add(rig, newPart("Cylinder", Vector3.new(0.07 * s, 0.62 * s, 0.62 * s), WHITE, NEON, 0), CFrame.new(top) * VERTICAL, { kind = "spin", axis = "Y", joint = top, speed = 4 })
		table.insert(rig.rainbowParts, crown)
		for k = 0, 3 do
			local a = k / 4 * math.pi * 2
			local orb = add(rig, newPart("Ball", Vector3.one * s * 0.16, WHITE, NEON), CFrame.new(math.cos(a) * 1.05 * s, (k % 2) * 0.3 * s, math.sin(a) * 1.05 * s), { kind = "spin", axis = "Y", joint = Vector3.zero, speed = 2.6 })
			table.insert(rig.rainbowParts, orb)
		end
	end
end

-- bot: dòng trong Config.Bots. level: cấp nâng (to dần 4%/cấp).
-- variant: nil | "Shiny" | "Holo" | "Void" | "Clone"
function BotModels.Build(bot, level, variant)
	local s = bot.size * (1 + ((level or 1) - 1) * 0.04)
	local accent = bot.accent or bot.color:Lerp(WHITE, 0.45)
	local build = forms[bot.form] or forms.Orb
	local rig = build(s, bot.color, accent)
	local head = HEADS[bot.form] or HEADS.Orb
	for _, name in bot.traits or {} do
		local trait = traits[name]
		if trait then
			trait(rig, s, bot.color, accent, head)
		end
	end
	rarityAura(rig, bot, s, head)
	if variant == "Shiny" then
		-- vỏ kim loại hoá vàng bóng
		for _, part in rig.model:GetDescendants() do
			if part:IsA("BasePart") and part:GetAttribute("Metal") then
				part.Color = SHINY_METAL
				part.Material = Enum.Material.Metal
				part.Reflectance = 0.25
			end
		end
	elseif variant == "Clone" then
		-- bản sao hologram (Clone Squad): vật liệu ForceField lấp lánh màu xanh
		for _, part in rig.model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Material = Enum.Material.ForceField
				part.Color = Color3.fromRGB(90, 220, 255)
				part.Transparency = 0
			end
		end
	elseif variant == "Holo" then
		-- mọi part (trừ phần tối) đổi màu cầu vồng liên tục trong Pose
		rig.holoParts = {}
		for _, part in rig.model:GetDescendants() do
			if part:IsA("BasePart") and not part:GetAttribute("Dark") then
				table.insert(rig.holoParts, part)
			end
		end
	elseif variant == "Void" then
		-- vật chất tối: vỏ tím than, mọi đèn neon thành tím hồng, thêm vòng vật chất tối xoay quanh
		for _, part in rig.model:GetDescendants() do
			if part:IsA("BasePart") then
				if part.Material == NEON then
					part.Color = VOID_GLOW
				elseif part:GetAttribute("Metal") or part:GetAttribute("Dark") then
					part.Color = VOID_SHELL
					part.Material = Enum.Material.Glass
					part.Reflectance = 0.15
				else
					part.Color = part.Color:Lerp(VOID_SHELL, 0.7)
				end
			end
		end
		for k, tilt in { 0.45, -0.45 } do
			add(rig, newPart("Cylinder", Vector3.new(0.06 * s, 1.75 * s, 1.75 * s), VOID_GLOW, NEON, 0.35), CFrame.Angles(tilt, 0, -tilt) * VERTICAL, { kind = "spin", axis = "Y", joint = Vector3.zero, speed = if k == 1 then -2 else 2.6 })
		end
	end
	rig.model.Name = bot.name
	rig.variant = variant
	rig.size = s
	BotModels.Pose(rig, CFrame.new(), 0)
	return rig
end

function BotModels.Pose(rig, cframe, t)
	rig.body.CFrame = cframe
	for _, piece in rig.pieces do
		local cf = piece.cf
		local a = piece.anim
		if a then
			local angle = if a.kind == "spin" then t * a.speed else math.sin(t * a.speed + a.phase) * a.amp
			local rot = if a.axis == "X" then CFrame.Angles(angle, 0, 0) elseif a.axis == "Y" then CFrame.Angles(0, angle, 0) else CFrame.Angles(0, 0, angle)
			-- xoay quanh khớp: dời tới khớp, xoay, dời về
			cf = CFrame.new(a.joint) * rot * CFrame.new(-a.joint) * cf
		end
		piece.part.CFrame = cframe * cf
	end
	if rig.holoParts then
		for i, part in rig.holoParts do
			part.Color = Color3.fromHSV((t * 0.25 + i * 0.045) % 1, 0.5, 1)
		end
	end
	if rig.rainbowParts then
		for i, part in rig.rainbowParts do
			part.Color = Color3.fromHSV((t * 0.35 + i * 0.13) % 1, 0.55, 1)
		end
	end
end

-- bot chưa khám phá: hiện dạng hologram xanh mờ "???" (không phải cục đen)
function BotModels.Silhouette(rig)
	rig.holoParts = nil
	rig.rainbowParts = nil
	for _, part in rig.model:GetDescendants() do
		if part:IsA("BasePart") then
			local glow = part.Material == NEON
			part.Color = if glow then Color3.fromRGB(120, 200, 255) else Color3.fromRGB(60, 105, 185)
			part.Material = if glow then NEON else PLASTIC
			part.Reflectance = 0
			part.Transparency = if glow then 0.35 else 0.4
		end
	end
end

-- khung bao (gần đúng, bỏ qua góc xoay) để camera tự căn: trả về tâm, kích thước
function BotModels.Bounds(model)
	local minV, maxV = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			minV = minV:Min(part.Position - half)
			maxV = maxV:Max(part.Position + half)
		end
	end
	return (minV + maxV) / 2, maxV - minV
end

-- Capsule đồ chơi: nửa trên màu trong suốt, nửa dưới kim loại, đai neon ở giữa. scale = đường kính
function BotModels.Capsule(color, scale)
	scale = scale or 2
	local model = Instance.new("Model")
	model.Name = "Capsule"
	local bottom = newPart("Ellipsoid", Vector3.new(1, 0.8, 1) * scale, METAL)
	bottom.Name = "Bottom"
	local top = newPart("Ellipsoid", Vector3.new(1, 0.8, 1) * scale, color, Enum.Material.Glass, 0.15)
	top.Name = "Top"
	local band = newPart("Cylinder", Vector3.new(0.12, 1.03, 1.03) * scale, color, NEON)
	band.Name = "Band"
	local knob = newPart("Ball", Vector3.one * 0.2 * scale, color:Lerp(WHITE, 0.5), NEON)
	knob.Name = "Knob"
	local glow = newPart("Ball", Vector3.one * 0.45 * scale, color, NEON, 0.3)
	glow.Name = "Glow"
	for _, p in { bottom, top, band, knob, glow } do
		p.Parent = model
	end
	model.PrimaryPart = bottom
	local capsule = { model = model, top = top, bottom = bottom, band = band, knob = knob, glow = glow, scale = scale }
	BotModels.PoseCapsule(capsule, CFrame.new(), 0)
	return capsule
end

-- open: 0 = đóng, 1 = bung hẳn (nắp bay lên, đáy tụt xuống)
function BotModels.PoseCapsule(capsule, cframe, open)
	local s = capsule.scale
	capsule.bottom.CFrame = cframe * CFrame.new(0, -0.14 * s - open * 0.6 * s, 0)
	capsule.top.CFrame = cframe * CFrame.new(0, 0.14 * s + open * 0.9 * s, 0) * CFrame.Angles(open * 0.6, 0, 0)
	capsule.band.CFrame = cframe * CFrame.new(0, -open * 0.6 * s, 0) * VERTICAL
	capsule.knob.CFrame = cframe * CFrame.new(0, 0.55 * s + open * 0.9 * s, 0)
	capsule.glow.CFrame = cframe
end

-- bộ dụng cụ dựng model cho module khác (EnemyModels dùng chung cách dựng + Pose)
BotModels.Kit = {
	newPart = newPart,
	add = add,
	swing = swing,
	stick = stick,
	makeRig = makeRig,
	along = along,
	VERTICAL = VERTICAL,
	FACING = FACING,
	METAL = METAL,
	DARK = DARK,
	GOLD = GOLD,
	WHITE = WHITE,
	NEON = NEON,
}

return BotModels
