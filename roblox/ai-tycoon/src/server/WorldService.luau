-- Map thành phố "Thung Lũng AI": đại lộ, đường ngang, đèn đường, cây xanh, dãy nhà chọc trời
-- phía xa, đồi núi bao quanh (Terrain), xe chạy (client tự chạy, xem Fx), ngày/đêm,
-- và Quảng trường Công Nghệ có Sàn Chứng Khoán.
--
-- 8 lô đất cho người chơi: 2 hàng x 4, hàng trên quay mặt xuống đại lộ, hàng dưới quay lên.

local Lighting = game:GetService("Lighting")

local Visuals = require(script.Parent.Visuals)

local WorldService = {}

local DAY_LENGTH = 20 * 60 -- 1 ngày trong game = 20 phút ngoài đời
local AVENUE_HALF = 7.5 -- đại lộ rộng 15 stud dọc trục X ở z = 0
local CITY_HALF_X = 262

local ASPHALT = Color3.fromRGB(38, 38, 44)
local CONCRETE = Color3.fromRGB(150, 150, 155)

local city -- Folder chứa mọi thứ của thành phố
local streetLights = {}

-- Server 1 người: lô 2 là trụ sở của người chơi, lô 3 là xưởng, các lô còn lại là công ty đối thủ
WorldService.HQLot = 2
WorldService.FactoryLot = 3
WorldService.RivalLots = { 1, 4, 5, 6, 7, 8 }

-- Vị trí dành cho các service khác
WorldService.Plaza = CFrame.new(-228, 0, 0) -- giữa Quảng trường Công Nghệ
WorldService.LeaderboardCFrame = CFrame.new(-210, 13, -30) * CFrame.Angles(0, math.pi / 2, 0)
-- bảng điện tử đặt trên nóc Sàn Chứng Khoán, mặt chữ nhìn ra quảng trường (+X)
WorldService.TickerCFrame = CFrame.new(-250, 32, 0) * CFrame.Angles(0, math.pi / 2, 0)

-- CFrame gốc của lô đất thứ `index` (tâm lô, mặt tiền nhìn về phía +Z cục bộ = phía đại lộ)
function WorldService.LotOrigin(index)
	local col = (index - 1) % 4
	local row = math.floor((index - 1) / 4)
	local origin = CFrame.new((col - 1.5) * 95, 0, (row - 0.5) * 120)
	if row == 0 then
		return origin -- hàng z âm: +Z cục bộ hướng về đại lộ (z = 0)
	end
	return origin * CFrame.Angles(0, math.pi, 0)
end

local function part(props)
	local p = Visuals.Part(props)
	p.Parent = city
	return p
end

-- ================= Đường sá =================

local function road(center, size)
	part({
		Name = "Road",
		Size = size,
		CFrame = CFrame.new(center),
		Color = ASPHALT,
		Material = Enum.Material.Asphalt,
	})
end

local function buildRoads()
	-- đại lộ chính + vạch kẻ đứt quãng
	road(Vector3.new(0, 0, 0), Vector3.new(CITY_HALF_X * 2, 0.2, AVENUE_HALF * 2))
	for x = -CITY_HALF_X + 6, CITY_HALF_X - 6, 12 do
		part({
			Name = "LaneMark",
			Size = Vector3.new(5, 0.05, 0.4),
			CFrame = CFrame.new(x, 0.12, 0),
			Color = Color3.fromRGB(240, 240, 240),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
	end
	-- đường ngang giữa các lô
	for _, x in { -95, 0, 95 } do
		road(Vector3.new(x, 0, 0), Vector3.new(10, 0.2, 240))
	end
	-- đường vành đai
	for _, z in { -120, 120 } do
		road(Vector3.new(0, 0, z), Vector3.new(CITY_HALF_X * 2, 0.2, 15))
	end
	for _, x in { -192.5, 192.5 } do
		road(Vector3.new(x, 0, 0), Vector3.new(15, 0.2, 255))
	end
end

-- ================= Đèn đường, cây, xe =================

local function streetLight(position, facing)
	local pole = part({
		Name = "LightPole",
		Size = Vector3.new(0.6, 14, 0.6),
		CFrame = CFrame.new(position + Vector3.new(0, 7, 0)),
		Color = Color3.fromRGB(50, 52, 60),
		Material = Enum.Material.Metal,
	})
	local arm = part({
		Name = "LightArm",
		Size = Vector3.new(0.4, 0.4, 3),
		CFrame = CFrame.new(position + Vector3.new(0, 13.8, 0) + facing * 1.5, position + Vector3.new(0, 13.8, 0) + facing * 3),
		Color = pole.Color,
		Material = Enum.Material.Metal,
	})
	local lamp = part({
		Name = "Lamp",
		Size = Vector3.new(1.4, 0.4, 1.4),
		CFrame = arm.CFrame * CFrame.new(0, -0.3, -1.4),
		Color = Color3.fromRGB(255, 225, 160),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 110
	light.Range = 26
	light.Brightness = 3
	light.Color = Color3.fromRGB(255, 220, 160)
	light.Parent = lamp
	table.insert(streetLights, light)
end

local function tree(position, scale)
	scale = scale or 1
	part({
		Name = "Trunk",
		Size = Vector3.new(1.2, 6, 1.2) * scale,
		CFrame = CFrame.new(position + Vector3.new(0, 3 * scale, 0)),
		Color = Color3.fromRGB(100, 70, 45),
		Material = Enum.Material.Wood,
	})
	local green = Color3.fromRGB(60 + math.random(0, 30), 130 + math.random(0, 40), 60)
	for i, offset in { Vector3.new(0, 7.5, 0), Vector3.new(1.4, 6.5, 0.8), Vector3.new(-1.2, 6.8, -0.9) } do
		part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (if i == 1 then 6 else 4.5) * scale,
			CFrame = CFrame.new(position + offset * scale),
			Color = green,
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end
end

-- Xe chỉ là part tĩnh có attribute Drive (tốc độ). Client tự chạy dọc trục X cho mượt (xem Fx).
local function car(lane, startX, speed, color)
	local body = part({
		Name = "Car",
		Size = Vector3.new(7, 2, 3.4),
		CFrame = CFrame.new(startX, 1.2, lane),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	local cabin = part({
		Name = "CarCabin",
		Size = Vector3.new(3.6, 1.6, 3),
		CFrame = CFrame.new(startX - 0.4, 2.9, lane),
		Color = Color3.fromRGB(30, 40, 55),
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		CanCollide = false,
	})
	for _, p in { body, cabin } do
		p:SetAttribute("Drive", speed)
		p:SetAttribute("DriveMin", -CITY_HALF_X)
		p:SetAttribute("DriveMax", CITY_HALF_X)
	end
	local headlight = part({
		Name = "Headlight",
		Size = Vector3.new(0.2, 0.5, 2.6),
		CFrame = CFrame.new(startX + math.sign(speed) * 3.55, 1.4, lane),
		Color = Color3.fromRGB(255, 250, 220),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	headlight:SetAttribute("Drive", speed)
	headlight:SetAttribute("DriveMin", -CITY_HALF_X)
	headlight:SetAttribute("DriveMax", CITY_HALF_X)
end

local function buildStreetLife()
	for x = -240, 240, 32 do
		if math.abs(x) % 95 > 8 then -- không đặt ngay giao lộ
			streetLight(Vector3.new(x, 0, -9.5), Vector3.new(0, 0, 1))
			streetLight(Vector3.new(x + 16, 0, 9.5), Vector3.new(0, 0, -1))
		end
	end
	local colors = {
		Color3.fromRGB(200, 40, 40),
		Color3.fromRGB(240, 240, 240),
		Color3.fromRGB(30, 30, 35),
		Color3.fromRGB(40, 90, 200),
		Color3.fromRGB(240, 190, 40),
		Color3.fromRGB(120, 120, 130),
	}
	for i = 1, 6 do
		local forward = i % 2 == 0
		car(if forward then -3.5 else 3.5, -CITY_HALF_X + i * 80, (if forward then 1 else -1) * math.random(18, 28), colors[i])
	end
	-- hàng cây dọc đường vành đai
	for x = -250, 250, 25 do
		tree(Vector3.new(x, 0, -132), 1.2)
		tree(Vector3.new(x + 12, 0, 132), 1.2)
	end
end

-- ================= Nhà chọc trời phía xa =================

local function skyscraper(position, width, depth, height)
	local tint = math.random(0, 2)
	local color = ({ Color3.fromRGB(70, 100, 140), Color3.fromRGB(90, 95, 110), Color3.fromRGB(60, 120, 130) })[tint + 1]
	local tower = part({
		Name = "Tower",
		Size = Vector3.new(width, height, depth),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)),
		Color = color,
		Material = Enum.Material.Glass,
		Reflectance = 0.25,
	})
	-- vài dải cửa sổ sáng đèn
	for y = 8, height - 6, 14 do
		if math.random() < 0.55 then
			part({
				Name = "Windows",
				Size = Vector3.new(width + 0.2, 1.2, depth + 0.2),
				CFrame = tower.CFrame * CFrame.new(0, y - height / 2, 0),
				Color = Color3.fromRGB(255, 225, 150),
				Material = Enum.Material.Neon,
				Transparency = 0.55,
				CanCollide = false,
			})
		end
	end
	-- đèn đỏ chống va chạm máy bay trên nóc
	part({
		Name = "Beacon",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.2,
		CFrame = CFrame.new(position + Vector3.new(0, height + 0.6, 0)),
		Color = Color3.fromRGB(255, 40, 40),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}):SetAttribute("Blink", true)
end

local function buildSkyline()
	local random = Random.new(2026) -- cố định để server nào cũng ra cùng một skyline
	for x = -300, 300, 40 do
		for _, z in { -175, 175 } do
			local w = random:NextInteger(22, 34)
			skyscraper(Vector3.new(x + random:NextInteger(-6, 6), 0, z + random:NextInteger(-10, 10)), w, random:NextInteger(22, 34), random:NextInteger(50, 170))
		end
	end
	for z = -130, 130, 45 do
		local w = random:NextInteger(22, 32)
		skyscraper(Vector3.new(310, 0, z), w, w, random:NextInteger(60, 150))
	end
end

-- ================= Đồi núi bao quanh thung lũng =================

local function buildHills()
	local terrain = workspace.Terrain
	local random = Random.new(7)
	for i = 0, 23 do
		local angle = i / 24 * math.pi * 2
		local dist = random:NextNumber(470, 560)
		local radius = random:NextNumber(110, 170)
		local center = Vector3.new(math.cos(angle) * dist, -radius * 0.45, math.sin(angle) * dist)
		terrain:FillBall(center, radius, if i % 3 == 0 then Enum.Material.Rock else Enum.Material.Grass)
	end
	-- Biển chữ khổng lồ trên đồi phía bắc
	local sign = part({
		Name = "ValleySign",
		Size = Vector3.new(160, 26, 1),
		CFrame = CFrame.new(0, 70, -500),
		Transparency = 1,
		CanCollide = false,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 8
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.BuilderSansExtraBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(250, 250, 250)
	text.Text = "THUNG LŨNG AI"
	text.Parent = gui
	gui.Parent = sign
end

-- ================= Quảng trường Công Nghệ + Sàn Chứng Khoán =================

local function buildPlaza()
	part({
		Name = "Plaza",
		Size = Vector3.new(55, 0.4, 110),
		CFrame = WorldService.Plaza * CFrame.new(0, 0.2, 0),
		Color = Color3.fromRGB(190, 185, 175),
		Material = Enum.Material.Pavement,
	})
	-- tòa Sàn Chứng Khoán: bậc thềm, cột, mái
	local exchange = CFrame.new(-252, 0, 0)
	part({
		Name = "ExchangeBase",
		Size = Vector3.new(22, 3, 50),
		CFrame = exchange * CFrame.new(0, 1.5, 0),
		Color = Color3.fromRGB(225, 222, 215),
		Material = Enum.Material.Marble,
	})
	for z = -21, 21, 7 do
		part({
			Name = "Column",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(16, 2.4, 2.4),
			CFrame = exchange * CFrame.new(10, 11, z) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(235, 232, 225),
			Material = Enum.Material.Marble,
		})
	end
	part({
		Name = "ExchangeRoof",
		Size = Vector3.new(24, 4, 52),
		CFrame = exchange * CFrame.new(0, 21, 0),
		Color = Color3.fromRGB(225, 222, 215),
		Material = Enum.Material.Marble,
	})
	part({
		Name = "ExchangeHall",
		Size = Vector3.new(14, 16, 46),
		CFrame = exchange * CFrame.new(-3, 11, 0),
		Color = Color3.fromRGB(205, 200, 190),
		Material = Enum.Material.Marble,
	})
	Visuals.Label(part({
		Name = "ExchangeTitle",
		Size = Vector3.new(1, 1, 1),
		CFrame = exchange * CFrame.new(12, 21, 0),
		Transparency = 1,
		CanCollide = false,
	}), "🏛️ SÀN CHỨNG KHOÁN", UDim2.fromScale(40, 6), Vector3.new(0, 4, 0), Color3.fromRGB(255, 215, 90))

	-- vài cây và ghế đá quanh quảng trường
	for _, z in { -45, -15, 15, 45 } do
		tree(Vector3.new(-205, 0, z), 1)
	end
end

-- Trụ sở công ty đối thủ trên 1 lô đất: tháp kính màu thương hiệu + biển tên phát sáng
function WorldService.BuildRival(lotIndex, name, emoji, color, height)
	local origin = WorldService.LotOrigin(lotIndex)
	local folder = Instance.new("Folder")
	folder.Name = "Rival_" .. name
	Visuals.Part({
		Name = "Ground",
		Size = Vector3.new(85, 0.6, 105),
		CFrame = origin * CFrame.new(0, -0.15, 0),
		Color = Color3.fromRGB(165, 165, 170),
		Material = Enum.Material.Concrete,
	}).Parent = folder
	local tower = Visuals.Part({
		Name = "Tower",
		Size = Vector3.new(40, height, 34),
		CFrame = origin * CFrame.new(0, height / 2, -22),
		Color = color,
		Material = Enum.Material.Glass,
		Reflectance = 0.2,
		Transparency = 0.1,
	})
	tower.Parent = folder
	for y = 10, height - 6, 14 do
		Visuals.Part({
			Name = "Floor",
			Size = Vector3.new(40.4, 0.8, 34.4),
			CFrame = tower.CFrame * CFrame.new(0, y - height / 2, 0),
			Color = Color3.fromRGB(40, 42, 50),
			Material = Enum.Material.Metal,
		}).Parent = folder
	end
	local sign = Visuals.Part({
		Name = "Sign",
		Size = Vector3.new(30, 1, 1),
		CFrame = origin * CFrame.new(0, height + 1, -6),
		Transparency = 1,
		CanCollide = false,
	})
	Visuals.Label(sign, emoji .. " " .. string.upper(name), UDim2.fromScale(40, 8), Vector3.new(0, 4, 0), color).Parent.MaxDistance = 700
	sign.Parent = folder
	folder.Parent = city
end

-- ================= Ngày / đêm =================

local function isNight(clock)
	return clock >= 18 or clock < 6.3
end

local function startDayNight()
	local startClock = 16.5 -- vào game lúc chiều muộn cho đẹp
	local wasNight = nil
	task.spawn(function()
		while true do
			local clock = (startClock + (workspace.DistributedGameTime / DAY_LENGTH) * 24) % 24
			Lighting.ClockTime = clock
			local night = isNight(clock)
			if night ~= wasNight then
				wasNight = night
				for _, light in streetLights do
					light.Enabled = night
				end
				Lighting.OutdoorAmbient = if night then Color3.fromRGB(70, 70, 100) else Color3.fromRGB(128, 128, 128)
				Lighting.Ambient = if night then Color3.fromRGB(40, 40, 60) else Color3.fromRGB(70, 70, 70)
			end
			task.wait(1)
		end
	end)
end

function WorldService.Start()
	Visuals.SetupWorld()
	city = Instance.new("Folder")
	city.Name = "City"
	city.Parent = workspace
	buildRoads()
	buildStreetLife()
	buildSkyline()
	buildPlaza()
	buildHills()
	startDayNight()
end

return WorldService
