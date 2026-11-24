-- Đồ họa dựng bằng code: ánh sáng đêm neon, sàn lưới phát sáng, kệ máy chủ có LED,
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

-- Ánh sáng toàn map: đêm, sương tím, bloom cho neon rực lên
function Visuals.SetupWorld()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.5
	Lighting.Ambient = Color3.fromRGB(45, 40, 70)
	Lighting.OutdoorAmbient = Color3.fromRGB(60, 50, 90)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.6
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

	local atmosphere = ensure("Atmosphere", "NeonHaze")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(120, 80, 200)
	atmosphere.Decay = Color3.fromRGB(40, 20, 80)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.5

	local bloom = ensure("BloomEffect", "NeonBloom")
	bloom.Intensity = 0.8
	bloom.Size = 28
	bloom.Threshold = 0.85

	local color = ensure("ColorCorrectionEffect", "NeonGrade")
	color.Saturation = 0.25
	color.Contrast = 0.12
	color.TintColor = Color3.fromRGB(235, 230, 255)

	-- Baseplate mặc định màu xám nhìn chán, đổi sang nền tối
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Color = Color3.fromRGB(12, 12, 20)
		baseplate.Material = Enum.Material.Slate
		for _, child in baseplate:GetChildren() do
			if child:IsA("Texture") then
				child:Destroy()
			end
		end
	end
end

-- Sàn lab: nền tối + lưới neon
function Visuals.BuildFloor(parent, origin, width, depth)
	Visuals.Part({
		Name = "Floor",
		Size = Vector3.new(width, 1, depth),
		CFrame = origin * CFrame.new(0, -0.4, 0),
		Color = Visuals.Colors.floor,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.15,
	}).Parent = parent

	local spacing = 12
	for x = -width / 2 + spacing / 2, width / 2, spacing do
		Visuals.Part({
			Name = "Grid",
			Size = Vector3.new(0.15, 0.05, depth),
			CFrame = origin * CFrame.new(x, 0.12, 0),
			Color = Visuals.Colors.grid,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = false,
			CanQuery = false,
		}).Parent = parent
	end
	for z = -depth / 2 + spacing / 2, depth / 2, spacing do
		Visuals.Part({
			Name = "Grid",
			Size = Vector3.new(width, 0.05, 0.15),
			CFrame = origin * CFrame.new(0, 0.12, z),
			Color = Visuals.Colors.gridAlt,
			Material = Enum.Material.Neon,
			Transparency = 0.6,
			CanCollide = false,
			CanQuery = false,
		}).Parent = parent
	end
end

-- Cổng vào lab có viền neon
function Visuals.BuildGate(parent, cframe, color)
	for _, x in { -9, 9 } do
		local pillar = Visuals.Part({
			Name = "GatePillar",
			Size = Vector3.new(1.5, 12, 1.5),
			CFrame = cframe * CFrame.new(x, 6, 0),
			Color = Visuals.Colors.metal,
			Material = Enum.Material.Metal,
		})
		Visuals.Part({
			Name = "GateNeon",
			Size = Vector3.new(0.3, 11, 1.6),
			CFrame = pillar.CFrame * CFrame.new(0.8 * math.sign(-x), 0, 0),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}).Parent = pillar
		pillar.Parent = parent
	end
	local beam = Visuals.Part({
		Name = "GateBeam",
		Size = Vector3.new(20, 1.2, 1.5),
		CFrame = cframe * CFrame.new(0, 12.6, 0),
		Color = color,
		Material = Enum.Material.Neon,
	})
	Visuals.Light(beam, color, 18, 2)
	beam.Parent = parent
	return beam
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
