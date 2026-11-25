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

-- ================= API =================

-- bot: dòng trong Config.Bots. level: cấp nâng (to dần 4%/cấp). variant: nil | "Shiny" | "Holo" | "Clone"
function BotModels.Build(bot, level, variant)
	local s = bot.size * (1 + ((level or 1) - 1) * 0.04)
	local accent = bot.accent or bot.color:Lerp(WHITE, 0.45)
	local build = forms[bot.form] or forms.Orb
	local rig = build(s, bot.color, accent)
	if bot.rarity == "Legendary" or bot.rarity == "Mythic" then
		-- vòng hào quang trên đầu cho bot hiếm
		local halo = if bot.rarity == "Mythic" then Color3.fromRGB(255, 90, 220) else GOLD
		add(rig, newPart("Cylinder", Vector3.new(0.05 * s, 0.55 * s, 0.55 * s), halo, NEON, 0.1), CFrame.new(0, 0.85 * s, 0) * VERTICAL, { kind = "spin", axis = "Y", joint = Vector3.new(0, 0.85 * s, 0), speed = 3 })
	end
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
end

-- biến thành bóng đen "???" cho bot chưa khám phá
function BotModels.Silhouette(rig)
	rig.holoParts = nil
	for _, part in rig.model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Color = Color3.fromRGB(14, 16, 26)
			part.Material = PLASTIC
			part.Transparency = 0
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

return BotModels
