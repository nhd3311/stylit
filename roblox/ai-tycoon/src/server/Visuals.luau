-- Đồ họa dựng bằng code: ánh sáng, tầng nhà kính, nóc tòa nhà, kệ máy chủ có LED,
-- lõi AI có vòng quay. Hiệu ứng chuyển động (LED nhấp nháy, vòng quay) chạy ở client
-- (xem client/Fx.luau) để server khỏi phải gửi thay đổi mỗi khung hình.
--
-- Attribute mà client đọc để tạo hiệu ứng:
--   Blink = true      -> nhấp nháy
--   Spin = số         -> xoay quanh trục Y của thế giới, tâm là chính part (radian/giây)

local Lighting = game:GetService("Lighting")

local Visuals = {}

Visuals.Colors = {
	floor = Color3.fromRGB(16, 18, 30),
	grid = Color3.fromRGB(0, 190, 255),
	gridAlt = Color3.fromRGB(190, 60, 255),
	rack = Color3.fromRGB(30, 33, 46),
	glass = Color3.fromRGB(120, 200, 255),
	off = Color3.fromRGB(60, 60, 75),
	locked = Color3.fromRGB(70, 70, 80),
	vip = Color3.fromRGB(255, 200, 40),
	metal = Color3.fromRGB(55, 58, 75),
}

function Visuals.Part(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

-- Chữ nổi trên đầu một part. Trả về TextLabel (BillboardGui là label.Parent).
function Visuals.Label(parent, text, size, offset, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = size or UDim2.fromScale(6, 1.5)
	gui.StudsOffset = offset or Vector3.new(0, 3, 0)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.BuilderSansExtraBold
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.RichText = true
	label.Text = text
	label.Parent = gui
	gui.Parent = parent
	return label
end

function Visuals.Light(parent, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 10
	light.Brightness = brightness or 1.5
	light.Shadows = false
	light.Parent = parent
	return light
end

-- Ánh sáng chung. Giờ trong ngày do WorldService chạy (ngày/đêm).
function Visuals.SetupWorld()
	Lighting.Brightness = 2
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.GlobalShadows = true

	local function ensure(className, name)
		local inst = Lighting:FindFirstChild(name)
		if not inst then
			inst = Instance.new(className)
			inst.Name = name
			inst.Parent = Lighting
		end
		return inst
	end

	local atmosphere = ensure("Atmosphere", "CityHaze")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(200, 180, 220)
	atmosphere.Decay = Color3.fromRGB(110, 90, 150)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.2

	local bloom = ensure("BloomEffect", "NeonBloom")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 0.92

	local color = ensure("ColorCorrectionEffect", "CityGrade")
	color.Saturation = 0.12
	color.Contrast = 0.08

	ensure("SunRaysEffect", "SunRays").Intensity = 0.06

	-- Baseplate mặc định đổi thành nền cỏ của thung lũng
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Color = Color3.fromRGB(86, 140, 70)
		baseplate.Material = Enum.Material.Grass
		for _, child in baseplate:GetChildren() do
			if child:IsA("Texture") then
				child:Destroy()
			end
		end
	end
end

-- Một tầng nhà kính: sàn, 4 vách kính (mặt trước chừa cửa nếu `door`), cột khung, đèn trần.
-- `base` là CFrame ở tâm mặt sàn. Trả về sàn.
function Visuals.BuildFloorShell(parent, base, width, depth, height, door, accent)
	local floor = Visuals.Part({
		Name = "Slab",
		Size = Vector3.new(width, 1, depth),
		CFrame = base * CFrame.new(0, -0.5, 0),
		Color = Color3.fromRGB(70, 72, 82),
		Material = Enum.Material.Concrete,
	})
	floor.Parent = parent
	Visuals.Part({
		Name = "Carpet",
		Size = Vector3.new(width - 4, 0.1, depth - 4),
		CFrame = base * CFrame.new(0, 0.05, 0),
		Color = Color3.fromRGB(45, 48, 62),
		Material = Enum.Material.Fabric,
		CanCollide = false,
	}).Parent = parent

	local glassColor = Color3.fromRGB(140, 190, 230)
	local function glass(size, cf)
		Visuals.Part({
			Name = "Glass",
			Size = size,
			CFrame = cf,
			Color = glassColor,
			Material = Enum.Material.Glass,
			Transparency = 0.55,
			Reflectance = 0.15,
		}).Parent = parent
	end
	local h = height - 1
	-- vách sau, trái, phải
	glass(Vector3.new(width, h, 0.4), base * CFrame.new(0, h / 2, -depth / 2))
	glass(Vector3.new(0.4, h, depth), base * CFrame.new(-width / 2, h / 2, 0))
	glass(Vector3.new(0.4, h, depth), base * CFrame.new(width / 2, h / 2, 0))
	-- vách trước, chừa cửa 12 stud ở giữa nếu có
	if door then
		local side = (width - 12) / 2
		glass(Vector3.new(side, h, 0.4), base * CFrame.new(-(6 + side / 2), h / 2, depth / 2))
		glass(Vector3.new(side, h, 0.4), base * CFrame.new(6 + side / 2, h / 2, depth / 2))
		glass(Vector3.new(12, h - 9, 0.4), base * CFrame.new(0, 9 + (h - 9) / 2, depth / 2))
	else
		glass(Vector3.new(width, h, 0.4), base * CFrame.new(0, h / 2, depth / 2))
	end

	-- cột khung ở 4 góc + giữa các mặt
	for _, x in { -width / 2, 0, width / 2 } do
		for _, z in { -depth / 2, depth / 2 } do
			if not (door and x == 0 and z == depth / 2) then
				Visuals.Part({
					Name = "Mullion",
					Size = Vector3.new(1, h, 1),
					CFrame = base * CFrame.new(x, h / 2, z),
					Color = Color3.fromRGB(40, 42, 50),
					Material = Enum.Material.Metal,
				}).Parent = parent
			end
		end
	end

	-- dải đèn viền ngoài tầng (màu nhấn của công ty) + đèn trần bên trong
	Visuals.Part({
		Name = "Trim",
		Size = Vector3.new(width + 0.6, 0.4, depth + 0.6),
		CFrame = base * CFrame.new(0, h + 0.2, 0),
		Color = accent,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.2,
	}).Parent = parent
	for _, x in { -width / 4, width / 4 } do
		local lamp = Visuals.Part({
			Name = "CeilingLight",
			Size = Vector3.new(width / 3, 0.2, 2),
			CFrame = base * CFrame.new(x, h - 0.2, 0),
			Color = Color3.fromRGB(255, 245, 225),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		Visuals.Light(lamp, Color3.fromRGB(255, 240, 220), 22, 1.2)
		lamp.Parent = parent
	end
	return floor
end

-- Nóc tòa nhà: mái, sân đỗ trực thăng, biển tên công ty phát sáng. Trả về TextLabel của biển.
function Visuals.BuildRoof(parent, base, width, depth, accent)
	Visuals.Part({
		Name = "Roof",
		Size = Vector3.new(width, 1, depth),
		CFrame = base * CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(60, 62, 70),
		Material = Enum.Material.Concrete,
	}).Parent = parent
	local pad = Visuals.Part({
		Name = "Helipad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 18, 18),
		CFrame = base * CFrame.new(0, 1.15, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(45, 45, 52),
		Material = Enum.Material.Asphalt,
	})
	pad.Parent = parent
	Visuals.Label(pad, "<b>H</b>", UDim2.fromScale(6, 6), Vector3.new(0, 0.6, 0), Color3.fromRGB(255, 220, 60)).Parent.MaxDistance = 200
	local signPost = Visuals.Part({
		Name = "SignPost",
		Size = Vector3.new(width * 0.7, 6, 1),
		CFrame = base * CFrame.new(0, 4, depth / 2 - 2),
		Color = Color3.fromRGB(25, 25, 32),
		Material = Enum.Material.Metal,
	})
	Visuals.Light(signPost, accent, 30, 2)
	signPost.Parent = parent
	local label = Visuals.Label(signPost, "", UDim2.fromScale(width * 0.9, 10), Vector3.new(0, 9, 0), accent)
	label.Parent.MaxDistance = 600
	return label
end

-- Kệ máy chủ: thân + kính + dải đèn trên + 3 LED nhấp nháy.
-- Trả về thân kệ; các con: Light (dải đèn), Led1..3, Glow (PointLight trong Light)
function Visuals.BuildRack(cframe)
	local body = Visuals.Part({
		Size = Vector3.new(5, 8, 3),
		CFrame = cframe,
		Color = Visuals.Colors.rack,
		Material = Enum.Material.Metal,
	})
	Visuals.Part({
		Name = "Glass",
		Size = Vector3.new(4.4, 6.6, 0.15),
		CFrame = body.CFrame * CFrame.new(0, -0.3, 1.55),
		Color = Visuals.Colors.glass,
		Material = Enum.Material.Glass,
		Transparency = 0.7,
		CanCollide = false,
	}).Parent = body
	local light = Visuals.Part({
		Name = "Light",
		Size = Vector3.new(4.6, 0.35, 0.2),
		CFrame = body.CFrame * CFrame.new(0, 3.6, 1.6),
		Color = Visuals.Colors.off,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	Visuals.Light(light, Visuals.Colors.off, 8, 1.2).Name = "Glow"
	light.Parent = body
	for i = 1, 3 do
		local led = Visuals.Part({
			Name = "Led" .. i,
			Size = Vector3.new(0.35, 0.35, 0.1),
			CFrame = body.CFrame * CFrame.new(-1.6 + (i - 1) * 0.6, -3.3, 1.62),
			Color = Visuals.Colors.off,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		led:SetAttribute("Blink", true)
		led.Parent = body
	end
	return body
end

-- Đổi màu kệ theo tier GPU (nil = tắt)
function Visuals.PaintRack(body, color)
	local c = color or Visuals.Colors.off
	body.Light.Color = c
	body.Light.Glow.Color = c
	body.Light.Glow.Enabled = color ~= nil
	for i = 1, 3 do
		body["Led" .. i].Color = c
	end
end

-- Lõi AI: quả cầu ngoài (ForceField) + lõi trong (Neon) + 2 vòng quay + hạt sáng
function Visuals.BuildCore(parent, cframe, color)
	local core = Visuals.Part({
		Name = "AICore",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(4, 4, 4),
		CFrame = cframe,
		Color = color,
		Material = Enum.Material.ForceField,
		CanCollide = false,
	})
	local inner = Visuals.Part({
		Name = "Inner",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.4, 2.4, 2.4),
		CFrame = cframe,
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	inner.Parent = core
	for i, tilt in { 0.35, -0.6 } do
		local ring = Visuals.Part({
			Name = "Ring" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 6, 6),
			-- nghiêng đĩa trước rồi mới dựng trục X của Cylinder thành pháp tuyến
			CFrame = cframe * CFrame.Angles(tilt, 0, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.7,
			CanCollide = false,
			CanQuery = false,
		})
		ring:SetAttribute("Spin", if i == 1 then 1.2 else -0.8)
		ring.Parent = core
	end
	Visuals.Light(inner, color, 24, 3).Name = "Glow"
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "Sparks"
	particles.Color = ColorSequence.new(color)
	particles.LightEmission = 1
	particles.Rate = 10
	particles.Lifetime = NumberRange.new(1.5, 2.5)
	particles.Speed = NumberRange.new(1, 3)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Parent = inner
	core.Parent = parent
	return core
end

function Visuals.PaintCore(core, color, size)
	core.Color = color
	core.Size = Vector3.new(size, size, size)
	core.Inner.Color = color
	core.Inner.Size = Vector3.new(size * 0.6, size * 0.6, size * 0.6)
	core.Inner.Glow.Color = color
	core.Inner.Sparks.Color = ColorSequence.new(color)
	for i = 1, 2 do
		local ring = core["Ring" .. i]
		ring.Color = color
		ring.Size = Vector3.new(0.2, size * 1.5, size * 1.5)
	end
end

return Visuals
