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
-- style = "garage": tường gạch kín, cửa cuốn rộng phía trước, sàn bê tông.
-- Mặc định: văn phòng kính, sàn gỗ.
function Visuals.BuildFloorShell(parent, base, width, depth, height, door, accent, style)
	local garage = style == "garage"
	local floor = Visuals.Part({
		Name = "Slab",
		Size = Vector3.new(width, 1, depth),
		CFrame = base * CFrame.new(0, -0.5, 0),
		Color = Color3.fromRGB(70, 72, 82),
		Material = Enum.Material.Concrete,
	})
	floor.Parent = parent
	Visuals.Part({
		Name = "FloorFinish",
		Size = Vector3.new(width - 1, 0.1, depth - 1),
		CFrame = base * CFrame.new(0, 0.05, 0),
		Color = if garage then Color3.fromRGB(120, 120, 125) else Color3.fromRGB(150, 105, 70),
		Material = if garage then Enum.Material.Concrete else Enum.Material.WoodPlanks,
		CanCollide = false,
	}).Parent = parent

	local glassColor = Color3.fromRGB(140, 190, 230)
	local function glass(size, cf)
		Visuals.Part({
			Name = if garage then "Wall" else "Glass",
			Size = size,
			CFrame = cf,
			Color = if garage then Color3.fromRGB(160, 85, 65) else glassColor,
			Material = if garage then Enum.Material.Brick else Enum.Material.Glass,
			Transparency = if garage then 0 else 0.55,
			Reflectance = if garage then 0 else 0.15,
		}).Parent = parent
	end
	local h = height - 1
	-- vách sau, trái, phải
	glass(Vector3.new(width, h, 0.4), base * CFrame.new(0, h / 2, -depth / 2))
	glass(Vector3.new(0.4, h, depth), base * CFrame.new(-width / 2, h / 2, 0))
	glass(Vector3.new(0.4, h, depth), base * CFrame.new(width / 2, h / 2, 0))
	-- vách trước: garage chừa cửa cuốn rộng, văn phòng chừa cửa 12 stud ở giữa
	if garage then
		local opening = width - 8
		glass(Vector3.new(4, h, 0.4), base * CFrame.new(-width / 2 + 2, h / 2, depth / 2))
		glass(Vector3.new(4, h, 0.4), base * CFrame.new(width / 2 - 2, h / 2, depth / 2))
		glass(Vector3.new(opening, h - 9, 0.4), base * CFrame.new(0, 9 + (h - 9) / 2, depth / 2))
		-- cửa cuốn đang kéo lên
		Visuals.Part({
			Name = "RollerDoor",
			Size = Vector3.new(opening, 1.6, 1.6),
			CFrame = base * CFrame.new(0, 8.4, depth / 2 - 0.6),
			Color = Color3.fromRGB(170, 175, 180),
			Material = Enum.Material.CorrodedMetal,
		}).Parent = parent
	elseif door then
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

-- ================= Nội thất & trang trí =================

function Visuals.Plant(parent, cframe, scale)
	scale = scale or 1
	Visuals.Part({
		Name = "Pot",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, 1.8, 1.8) * scale,
		CFrame = cframe * CFrame.new(0, 0.8 * scale, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(230, 230, 230),
		Material = Enum.Material.Ceramic,
		Parent = parent,
	})
	for i, offset in { Vector3.new(0, 2.6, 0), Vector3.new(0.5, 2.1, 0.3), Vector3.new(-0.5, 2.2, -0.3) } do
		Visuals.Part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (if i == 1 then 1.8 else 1.4) * scale,
			CFrame = cframe * CFrame.new(offset * scale),
			Color = Color3.fromRGB(70, 150, 70),
			Material = Enum.Material.Grass,
			CanCollide = false,
			Parent = parent,
		})
	end
end

-- Màn hình treo tường có chữ. Trả về TextLabel. Mặt chữ quay về -Z của `cframe`.
function Visuals.Screen(parent, cframe, width, height, color)
	local screen = Visuals.Part({
		Name = "Screen",
		Size = Vector3.new(width, height, 0.3),
		CFrame = cframe,
		Color = Color3.fromRGB(12, 12, 20),
		Material = Enum.Material.SmoothPlastic,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 1, -20)
	label.Position = UDim2.fromOffset(10, 10)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.RichText = true
	label.TextWrapped = true
	label.TextColor3 = color or Color3.fromRGB(120, 220, 255)
	label.Parent = gui
	gui.Parent = screen
	screen.Parent = parent
	return label
end

function Visuals.Whiteboard(parent, cframe)
	local board = Visuals.Part({
		Name = "Whiteboard",
		Size = Vector3.new(8, 4, 0.2),
		CFrame = cframe,
		Color = Color3.fromRGB(245, 245, 245),
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
	-- vài nét "sơ đồ" vẽ trên bảng
	for i, c in { Color3.fromRGB(40, 90, 220), Color3.fromRGB(220, 60, 60), Color3.fromRGB(40, 160, 90) } do
		Visuals.Part({
			Name = "Scribble",
			Size = Vector3.new(2.2, 0.15, 0.05),
			CFrame = board.CFrame * CFrame.new(-2.5 + (i - 1) * 2.5, 0.8 - (i % 2) * 1.2, -0.13) * CFrame.Angles(0, 0, math.rad((i - 2) * 18)),
			Color = c,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Parent = board,
		})
	end
end

function Visuals.CoffeeBar(parent, cframe)
	Visuals.Part({
		Name = "Counter",
		Size = Vector3.new(8, 3.4, 2.4),
		CFrame = cframe * CFrame.new(0, 1.7, 0),
		Color = Color3.fromRGB(60, 45, 35),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	Visuals.Part({
		Name = "Top",
		Size = Vector3.new(8.4, 0.3, 2.8),
		CFrame = cframe * CFrame.new(0, 3.55, 0),
		Color = Color3.fromRGB(235, 235, 235),
		Material = Enum.Material.Marble,
		Parent = parent,
	})
	local machine = Visuals.Part({
		Name = "CoffeeMachine",
		Size = Vector3.new(1.4, 1.6, 1.2),
		CFrame = cframe * CFrame.new(-2.5, 4.5, 0),
		Color = Color3.fromRGB(40, 40, 45),
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	Visuals.Label(machine, "☕", UDim2.fromScale(2, 2), Vector3.new(0, 2, 0)).Parent.MaxDistance = 40
end

function Visuals.Sofa(parent, cframe, color)
	Visuals.Part({
		Name = "SofaSeat",
		Size = Vector3.new(7, 1.6, 3),
		CFrame = cframe * CFrame.new(0, 0.8, 0),
		Color = color,
		Material = Enum.Material.Fabric,
		Parent = parent,
	})
	Visuals.Part({
		Name = "SofaBack",
		Size = Vector3.new(7, 2.4, 0.8),
		CFrame = cframe * CFrame.new(0, 2, 1.1),
		Color = color,
		Material = Enum.Material.Fabric,
		Parent = parent,
	})
end

function Visuals.Workbench(parent, cframe)
	Visuals.Part({
		Name = "Workbench",
		Size = Vector3.new(7, 3, 2.6),
		CFrame = cframe * CFrame.new(0, 1.5, 0),
		Color = Color3.fromRGB(120, 85, 55),
		Material = Enum.Material.WoodPlanks,
		Parent = parent,
	})
	for i = 1, 3 do
		Visuals.Part({
			Name = "Box",
			Size = Vector3.new(1.4, 1.2, 1.4),
			CFrame = cframe * CFrame.new(-2.4 + i * 1.5, 3.6, 0) * CFrame.Angles(0, math.rad(i * 17), 0),
			Color = Color3.fromRGB(190, 150, 100),
			Material = Enum.Material.Cardboard,
			Parent = parent,
		})
	end
end

-- Sảnh đón ngoài cửa: mái che + 2 bồn cây + 2 cột cờ màu công ty
function Visuals.Entrance(parent, cframe, accent)
	Visuals.Part({
		Name = "Canopy",
		Size = Vector3.new(16, 0.6, 6),
		CFrame = cframe * CFrame.new(0, 10, 3),
		Color = Color3.fromRGB(40, 42, 50),
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	Visuals.Part({
		Name = "CanopyLight",
		Size = Vector3.new(16.2, 0.2, 6.2),
		CFrame = cframe * CFrame.new(0, 9.65, 3),
		Color = accent,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = parent,
	})
	for _, x in { -11, 11 } do
		Visuals.Part({
			Name = "Planter",
			Size = Vector3.new(4, 1.6, 4),
			CFrame = cframe * CFrame.new(x, 0.8, 4),
			Color = Color3.fromRGB(110, 110, 115),
			Material = Enum.Material.Concrete,
			Parent = parent,
		})
		Visuals.Plant(parent, cframe * CFrame.new(x, 1.6, 4), 1.4)
		local pole = Visuals.Part({
			Name = "FlagPole",
			Size = Vector3.new(0.4, 16, 0.4),
			CFrame = cframe * CFrame.new(x * 1.6, 8, 10),
			Color = Color3.fromRGB(200, 200, 205),
			Material = Enum.Material.Metal,
			Parent = parent,
		})
		Visuals.Part({
			Name = "Flag",
			Size = Vector3.new(0.1, 2.4, 4),
			CFrame = pole.CFrame * CFrame.new(0, 6.6, 2.1),
			Color = accent,
			Material = Enum.Material.Fabric,
			CanCollide = false,
			Parent = parent,
		})
	end
end

-- ================= Nhân viên =================

-- Avatar Roblox thật (R15) ngồi ở ghế, tên hiện trên đầu. Tạo mất chút thời gian nên gọi trong task.spawn.
-- Không tạo được (lỗi API) thì trả về nil để dùng BuildPerson thay thế.
function Visuals.BuildAvatar(name, shirt, pants, skin)
	local ok, model = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = skin
		desc.LeftArmColor = shirt
		desc.RightArmColor = shirt
		desc.TorsoColor = shirt
		desc.LeftLegColor = pants
		desc.RightLegColor = pants
		return game:GetService("Players"):CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		return nil
	end
	model.Name = name
	for _, inst in model:GetDescendants() do
		if inst:IsA("BaseScript") then
			inst:Destroy() -- bỏ script Animate: tư thế ngồi chỉnh tay bên dưới
		elseif inst:IsA("BasePart") then
			inst.CanCollide = false
			inst.CanQuery = false
		end
	end
	-- tư thế ngồi: gập hông ra trước, gập gối xuống
	for _, joint in { "LeftHip", "RightHip" } do
		local motor = model:FindFirstChild(joint, true)
		if motor then
			motor.C0 *= CFrame.Angles(math.rad(90), 0, 0)
		end
	end
	for _, joint in { "LeftKnee", "RightKnee" } do
		local motor = model:FindFirstChild(joint, true)
		if motor then
			motor.C0 *= CFrame.Angles(math.rad(-90), 0, 0)
		end
	end
	-- tay đưa ra trước như đang gõ phím
	for _, joint in { "LeftShoulder", "RightShoulder" } do
		local motor = model:FindFirstChild(joint, true)
		if motor then
			motor.C0 *= CFrame.Angles(math.rad(70), 0, 0)
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = name
		humanoid.NameDisplayDistance = 40
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	model.HumanoidRootPart.Anchored = true
	return model
end

-- Đặt avatar ngồi ở ghế của chỗ làm việc `seatCFrame` (cùng quy ước với BuildWorkstation)
function Visuals.SeatAvatar(model, seatCFrame)
	model:PivotTo(seatCFrame * CFrame.new(0, 3.15, 2))
end

-- Chỗ làm việc: bàn + màn hình/PC + ghế. `tiers` = { desk, chair, pc } là bảng tier trong Config.
-- `cframe` đặt ở sàn, giữa bàn; người ngồi quay mặt về -Z (nhìn vào màn hình).
function Visuals.BuildWorkstation(parent, cframe, tiers)
	local desk = Visuals.Part({
		Name = "Desk",
		Size = Vector3.new(5, 0.4, 2.6),
		CFrame = cframe * CFrame.new(0, 2.8, 0),
		Color = tiers.desk.color,
		Material = Enum.Material.WoodPlanks,
	})
	desk.Parent = parent
	for _, x in { -2.2, 2.2 } do
		Visuals.Part({
			Name = "Leg",
			Size = Vector3.new(0.3, 2.6, 2.2),
			CFrame = cframe * CFrame.new(x, 1.3, 0),
			Color = Color3.fromRGB(60, 60, 66),
			Material = Enum.Material.Metal,
		}).Parent = parent
	end
	-- màn hình: PC càng xịn thì màn càng to, càng sáng
	local pcTier = tiers.pcIndex or 1
	local screens = if pcTier >= 3 then 2 else 1
	for i = 1, screens do
		local x = if screens == 2 then (i - 1.5) * 2 else 0
		local monitor = Visuals.Part({
			Name = "Monitor",
			Size = Vector3.new(if pcTier >= 2 then 1.9 else 1.5, if pcTier >= 2 then 1.2 else 1.3, if pcTier >= 2 then 0.15 else 1),
			CFrame = cframe * CFrame.new(x, 3.75, -0.8),
			Color = tiers.pc.color or Color3.fromRGB(25, 25, 30),
			Material = Enum.Material.SmoothPlastic,
		})
		Visuals.Part({
			Name = "Screen",
			Size = Vector3.new(monitor.Size.X - 0.2, monitor.Size.Y - 0.2, 0.05),
			CFrame = monitor.CFrame * CFrame.new(0, 0, monitor.Size.Z / 2 + 0.03),
			Color = if pcTier >= 4 then Color3.fromRGB(190, 120, 255) elseif pcTier >= 3 then Color3.fromRGB(90, 200, 255) else Color3.fromRGB(150, 200, 255),
			Material = Enum.Material.Neon,
			CanCollide = false,
		}).Parent = monitor
		monitor.Parent = parent
	end
	-- ghế
	Visuals.Part({
		Name = "Seat",
		Size = Vector3.new(2, 0.4, 2),
		CFrame = cframe * CFrame.new(0, 1.8, 2),
		Color = tiers.chair.color,
		Material = Enum.Material.Fabric,
	}).Parent = parent
	Visuals.Part({
		Name = "Backrest",
		Size = Vector3.new(2, 2.2, 0.3),
		CFrame = cframe * CFrame.new(0, 3, 2.9),
		Color = tiers.chair.color,
		Material = Enum.Material.Fabric,
	}).Parent = parent
	return desk
end

-- Nhân viên dạng khối ngồi ở ghế: thân màu theo vai trò, đầu, tên nổi trên đầu.
-- Attribute Bob để client cho nhún nhẹ như đang gõ phím.
function Visuals.BuildPerson(parent, cframe, color, labelText)
	local torso = Visuals.Part({
		Name = "Torso",
		Size = Vector3.new(1.8, 2, 1),
		CFrame = cframe * CFrame.new(0, 3.1, 1.9),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	torso:SetAttribute("Bob", 0.08)
	torso.Parent = parent
	local head = Visuals.Part({
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.3,
		CFrame = cframe * CFrame.new(0, 4.75, 1.9),
		Color = Color3.fromRGB(234, 192, 150),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	head:SetAttribute("Bob", 0.08)
	head.Parent = parent
	local label = Visuals.Label(head, labelText, UDim2.fromScale(6, 1.2), Vector3.new(0, 1.6, 0))
	label.Parent.MaxDistance = 45
	return torso
end

-- Một dây chuyền xưởng: máy (màu theo tier) + băng chuyền + hộp chip chạy trên băng (client chạy).
-- `cframe` ở sàn, băng chuyền chạy dọc trục X của thế giới.
function Visuals.BuildFactoryLine(parent, cframe, color, length)
	local machine = Visuals.Part({
		Name = "Machine",
		Size = Vector3.new(6, 6, 5),
		CFrame = cframe * CFrame.new(-length / 2 - 3, 3, 0),
		Color = Color3.fromRGB(70, 74, 86),
		Material = Enum.Material.DiamondPlate,
	})
	Visuals.Part({
		Name = "MachineLight",
		Size = Vector3.new(6.2, 0.5, 5.2),
		CFrame = machine.CFrame * CFrame.new(0, 2.6, 0),
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}).Parent = machine
	Visuals.Light(machine, color, 14, 1.5)
	machine.Parent = parent
	local belt = Visuals.Part({
		Name = "Belt",
		Size = Vector3.new(length, 0.6, 3),
		CFrame = cframe * CFrame.new(0, 1.8, 0),
		Color = Color3.fromRGB(35, 35, 40),
		Material = Enum.Material.Rubber,
	})
	belt.Parent = parent
	local x0 = belt.Position.X - length / 2
	for i = 1, 4 do
		local chip = Visuals.Part({
			Name = "Chip",
			Size = Vector3.new(1.4, 0.6, 1.4),
			CFrame = cframe * CFrame.new(-length / 2 + i * length / 4 - length / 8, 2.4, 0),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		chip:SetAttribute("Drive", 4)
		chip:SetAttribute("DriveMin", x0)
		chip:SetAttribute("DriveMax", x0 + length)
		chip.Parent = parent
	end
	return machine
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
