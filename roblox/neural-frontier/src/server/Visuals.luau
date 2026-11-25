-- Hàm tiện ích dựng đồ họa: part, chữ nổi, đèn, và ánh sáng toàn map.

local Lighting = game:GetService("Lighting")

local Visuals = {}

function Visuals.Part(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			part[key] = value
		end
	end
	part.Parent = props.Parent
	return part
end

function Visuals.Label(parent, text, size, offset, color, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Size = size or UDim2.fromScale(8, 2)
	gui.StudsOffset = offset or Vector3.new(0, 4, 0)
	gui.MaxDistance = maxDistance or 150
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.RichText = true
	label.Font = Enum.Font.Michroma -- chữ kiểu tương lai, khớp với giao diện
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	gui.Parent = parent
	return label
end

function Visuals.Light(parent, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 12
	light.Brightness = brightness or 1.5
	light.Parent = parent
	return light
end

function Visuals.Particles(parent, color, rate)
	local p = Instance.new("ParticleEmitter")
	p.Color = ColorSequence.new(color)
	p.LightEmission = 1
	p.Rate = rate or 6
	p.Lifetime = NumberRange.new(1, 2)
	p.Speed = NumberRange.new(1, 3)
	p.SpreadAngle = Vector2.new(180, 180)
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	p.Parent = parent
	return p
end

-- Ánh sáng hoàng hôn tím/xanh: khối neon nổi bật, đáy vực chìm trong sương
function Visuals.SetupLighting()
	Lighting.ClockTime = 17.6
	Lighting.GeographicLatitude = 20
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(80, 70, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 120, 175)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 1
	local function ensure(className, name)
		local inst = Lighting:FindFirstChild(name) or Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
		return inst
	end
	local atmosphere = ensure("Atmosphere", "FrontierAir")
	atmosphere.Density = 0.36
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(210, 180, 255)
	atmosphere.Decay = Color3.fromRGB(70, 50, 140)
	atmosphere.Glare = 0.12
	atmosphere.Haze = 1.8
	local bloom = ensure("BloomEffect", "Bloom")
	-- bloom vừa phải: neon vẫn sáng nhưng không loá mắt
	bloom.Intensity = 0.45
	bloom.Size = 20
	bloom.Threshold = 0.95
	local grade = ensure("ColorCorrectionEffect", "Grade")
	grade.Saturation = 0.25
	grade.Contrast = 0.1
	grade.Brightness = -0.03
	grade.TintColor = Color3.fromRGB(245, 240, 255)
	ensure("SunRaysEffect", "SunRays").Intensity = 0.06
end

return Visuals
