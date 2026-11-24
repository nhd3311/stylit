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

-- Ánh sáng chiều nắng hơi bão hoà, hợp phong cách cartoon/neon
function Visuals.SetupLighting()
	Lighting.ClockTime = 15.5
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(90, 90, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 160)
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.8
	local function ensure(className, name)
		local inst = Lighting:FindFirstChild(name) or Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
		return inst
	end
	local atmosphere = ensure("Atmosphere", "FrontierAir")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(190, 210, 255)
	atmosphere.Decay = Color3.fromRGB(120, 110, 200)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.4
	local bloom = ensure("BloomEffect", "Bloom")
	bloom.Intensity = 0.6
	bloom.Size = 26
	bloom.Threshold = 0.9
	local grade = ensure("ColorCorrectionEffect", "Grade")
	grade.Saturation = 0.22
	grade.Contrast = 0.1
	ensure("SunRaysEffect", "SunRays").Intensity = 0.08
end

return Visuals
