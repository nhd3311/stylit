-- Thế giới "Neon Grid": mọi thứ là KHỐI nổi trên khoảng không (không dùng Terrain).
--   • Hub: đảo lát gạch trắng, lan can kính, trụ đèn, cổng ra vùng, cổng sự kiện Glitch Floor
--   • 3 vùng: đảo lát gạch caro theo chủ đề, tường khối cao thấp so le, viền neon
--       Byte Meadow: cây voxel, khối data bay, bồn cây
--       Circuit Canyon: vách hẻm núi bậc thang, mạch điện neon dưới sàn, tủ server nhấp nháy
--       Neon Spires: tháp kính nhiều tầng có cửa sổ neon, vòng hologram bay
--       Frost Server: cụm pha lê băng, tủ server đóng băng, tuyết rơi
--       Magma Forge: hồ dung nham, trụ lò rèn có lửa, tàn lửa bay lên
--       Glitch Rift: khối glitch lơ lửng xoay, cột sáng neon, bia đá đen viền hồng
--       Cloud Citadel: cột đá trắng mũ vàng, cổng vòm vàng, mây khối trôi
--   • cầu nối giữa các đảo, trụ đỡ cắm xuống vực, lưới neon dưới đáy vực, mảnh đảo trôi xa xa
--   • sàn đấu Glitch Floor bay bên phải Hub (EventService điều khiển)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotModels = require(ReplicatedStorage.Shared.BotModels)
local Config = require(ReplicatedStorage.Shared.Config)
local Visuals = require(script.Parent.Visuals)

local WorldService = {}

local world -- Folder chứa mọi thứ
local nodes = {} -- [part] = { zone, active }
local random = Random.new(42)

-- callback cho PlayerService / EventService
WorldService.OnUpload = nil
WorldService.OnOpen = nil -- (player, panelName)
WorldService.OnEventJoin = nil -- (player)
WorldService.Arena = nil -- { center, top, half, tiles = { { base, inlay } } }

local TILE = 10
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local PLASTIC = Enum.Material.SmoothPlastic

-- bảng màu theo chủ đề
local THEMES = {
	Hub = { a = Color3.fromRGB(226, 232, 244), b = Color3.fromRGB(198, 206, 224), glow = Color3.fromRGB(0, 220, 255), wall = Color3.fromRGB(40, 46, 70), trim = Color3.fromRGB(0, 220, 255) },
	Meadow = { a = Color3.fromRGB(170, 235, 205), b = Color3.fromRGB(138, 212, 184), glow = Color3.fromRGB(80, 255, 170), wall = Color3.fromRGB(34, 68, 72), trim = Color3.fromRGB(90, 255, 180) },
	Canyon = { a = Color3.fromRGB(232, 160, 100), b = Color3.fromRGB(206, 134, 80), glow = Color3.fromRGB(255, 170, 60), wall = Color3.fromRGB(104, 58, 38), trim = Color3.fromRGB(255, 190, 80) },
	Spires = { a = Color3.fromRGB(54, 42, 94), b = Color3.fromRGB(40, 30, 74), glow = Color3.fromRGB(190, 90, 255), wall = Color3.fromRGB(22, 16, 42), trim = Color3.fromRGB(200, 110, 255) },
	Frost = { a = Color3.fromRGB(218, 238, 255), b = Color3.fromRGB(186, 218, 245), glow = Color3.fromRGB(120, 220, 255), wall = Color3.fromRGB(30, 52, 86), trim = Color3.fromRGB(150, 225, 255) },
	Magma = { a = Color3.fromRGB(70, 46, 44), b = Color3.fromRGB(52, 34, 32), glow = Color3.fromRGB(255, 110, 30), wall = Color3.fromRGB(34, 20, 18), trim = Color3.fromRGB(255, 120, 40), glowChance = 0.12 },
	Rift = { a = Color3.fromRGB(36, 14, 48), b = Color3.fromRGB(20, 6, 30), glow = Color3.fromRGB(255, 60, 220), wall = Color3.fromRGB(12, 4, 20), trim = Color3.fromRGB(255, 70, 230), glowChance = 0.08 },
	Citadel = { a = Color3.fromRGB(246, 246, 252), b = Color3.fromRGB(232, 224, 196), glow = Color3.fromRGB(255, 210, 110), wall = Color3.fromRGB(220, 226, 238), trim = Color3.fromRGB(255, 205, 90) },
}

local function prompt(parent, objectText, actionText, distance)
	local p = Instance.new("ProximityPrompt")
	p.ObjectText = objectText
	p.ActionText = actionText
	p.HoldDuration = 0
	p.MaxActivationDistance = distance or 12
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

local function block(name, size, cframe, color, material, extra)
	local props = { Name = name, Size = size, CFrame = cframe, Color = color, Material = material or PLASTIC, Parent = world }
	for key, value in extra or {} do
		props[key] = value
	end
	return Visuals.Part(props)
end

-- lệch màu nhẹ cho từng khối đỡ đơn điệu
local function jitter(color, amount)
	local k = 1 + random:NextNumber(-amount, amount)
	return Color3.new(math.clamp(color.R * k, 0, 1), math.clamp(color.G * k, 0, 1), math.clamp(color.B * k, 0, 1))
end

-- ================= Khối nền =================

-- Đảo nổi lát gạch (mặt trên ở y = center.Y): đế kim loại dày có viền neon dưới đáy,
-- lớp phát sáng lộ qua khe gạch, gạch caro lệch màu nhẹ, thỉnh thoảng 1 viên gạch phát sáng.
local function tiledIsland(center, sizeX, sizeZ, theme)
	block("IslandBase", Vector3.new(sizeX + 6, 8, sizeZ + 6), CFrame.new(center + Vector3.new(0, -5, 0)), theme.wall, METAL)
	block("IslandTrim", Vector3.new(sizeX + 6.4, 0.5, sizeZ + 6.4), CFrame.new(center + Vector3.new(0, -8.7, 0)), theme.trim, NEON, { CanCollide = false })
	block("IslandGlow", Vector3.new(sizeX, 0.2, sizeZ), CFrame.new(center + Vector3.new(0, -0.75, 0)), theme.glow, NEON, { CanCollide = false, Transparency = 0.3 })
	local nx, nz = math.floor(sizeX / TILE), math.floor(sizeZ / TILE)
	local tx, tz = sizeX / nx, sizeZ / nz
	for ix = 0, nx - 1 do
		for iz = 0, nz - 1 do
			local x = center.X - sizeX / 2 + (ix + 0.5) * tx
			local z = center.Z - sizeZ / 2 + (iz + 0.5) * tz
			local glowTile = random:NextNumber() < (theme.glowChance or 0.04)
			local color = if glowTile then theme.glow else jitter(if (ix + iz) % 2 == 0 then theme.a else theme.b, 0.035)
			block("Tile", Vector3.new(tx - 0.35, 1.2, tz - 0.35), CFrame.new(x, center.Y - 0.6, z), color, if glowTile then NEON else PLASTIC, if glowTile then { Transparency = 0.4 } else nil)
		end
	end
end

-- Tường khối bao quanh đảo, cao thấp so le, viền neon trên đỉnh.
-- openings = { north = nửa bề rộng lối đi, south = ..., east = ..., west = ... } (north là phía -Z)
-- low = true: lan can kính thấp (cho Hub thoáng)
local function walls(center, sizeX, sizeZ, theme, openings, low)
	local function segment(pos, alongX, side)
		local gap = openings[side]
		if gap and math.abs(if alongX then pos.X - center.X else pos.Z - center.Z) < gap then
			return
		end
		local h = if low then 2.6 else 6 + random:NextInteger(0, 4) * 2
		local size = if alongX then Vector3.new(TILE, h, 3) else Vector3.new(3, h, TILE)
		block("Wall", size, CFrame.new(pos + Vector3.new(0, h / 2, 0)), if low then Color3.fromRGB(200, 230, 255) else jitter(theme.wall, 0.06), if low then Enum.Material.Glass else METAL, if low then { Transparency = 0.55 } else nil)
		block("WallTrim", Vector3.new(size.X + 0.2, 0.4, size.Z + 0.2), CFrame.new(pos + Vector3.new(0, h + 0.2, 0)), theme.trim, NEON, { CanCollide = false, Transparency = 0.2 })
	end
	for i = 0, sizeX / TILE - 1 do
		local x = center.X - sizeX / 2 + (i + 0.5) * TILE
		segment(Vector3.new(x, center.Y, center.Z - sizeZ / 2 - 1.5), true, "north")
		segment(Vector3.new(x, center.Y, center.Z + sizeZ / 2 + 1.5), true, "south")
	end
	for i = 0, sizeZ / TILE - 1 do
		local z = center.Z - sizeZ / 2 + (i + 0.5) * TILE
		segment(Vector3.new(center.X - sizeX / 2 - 1.5, center.Y, z), false, "west")
		segment(Vector3.new(center.X + sizeX / 2 + 1.5, center.Y, z), false, "east")
	end
end

-- Cầu nối 2 đảo theo trục Z (từ zFrom xuống zTo, zFrom > zTo), có lan can kính và trụ đỡ cắm xuống vực
local function bridge(zFrom, zTo, theme)
	local length = zFrom - zTo
	local mid = (zFrom + zTo) / 2
	local width = 18
	block("BridgeBase", Vector3.new(width, 3, length), CFrame.new(0, -2.5, mid), theme.wall, METAL)
	block("BridgeGlow", Vector3.new(width - 1, 0.2, length), CFrame.new(0, -0.75, mid), theme.glow, NEON, { CanCollide = false, Transparency = 0.3 })
	local n = math.max(1, math.floor(length / TILE))
	for i = 0, n - 1 do
		for col, x in { -4.4, 4.4 } do
			block("BridgeTile", Vector3.new(8.4, 1.2, length / n - 0.35), CFrame.new(x, -0.6, zTo + (i + 0.5) * length / n), jitter(if (i + col) % 2 == 0 then theme.a else theme.b, 0.03))
		end
	end
	for _, x in { -width / 2, width / 2 } do
		block("Rail", Vector3.new(1, 2.4, length), CFrame.new(x, 1.2, mid), Color3.fromRGB(200, 230, 255), Enum.Material.Glass, { Transparency = 0.5 })
		block("RailTrim", Vector3.new(1.2, 0.3, length), CFrame.new(x, 2.5, mid), theme.trim, NEON, { CanCollide = false })
	end
	for z = zTo + 10, zFrom - 10, 20 do
		block("Pylon", Vector3.new(4, 60, 4), CFrame.new(0, -34, z), theme.wall, METAL)
		block("PylonLight", Vector3.new(4.3, 0.6, 4.3), CFrame.new(0, -12, z), theme.trim, NEON, { CanCollide = false })
	end
end

-- Đáy vực: mặt phẳng tối + lưới neon tím, nhìn xuyên sương mù như "không gian số"
local function voidGrid()
	local center = Vector3.new(0, -90, -800)
	block("Void", Vector3.new(2048, 2, 2048), CFrame.new(center), Color3.fromRGB(10, 8, 26))
	for i = -16, 16 do
		local line = { CanCollide = false, Transparency = 0.25 }
		block("GridX", Vector3.new(2048, 0.2, 0.8), CFrame.new(center + Vector3.new(0, 1.1, i * 64)), Color3.fromRGB(120, 70, 255), NEON, line)
		block("GridZ", Vector3.new(0.8, 0.2, 2048), CFrame.new(center + Vector3.new(i * 64, 1.1, 0)), Color3.fromRGB(0, 180, 255), NEON, line)
	end
end

-- Mảnh đảo khối trôi xa xa hai bên cho khung cảnh có chiều sâu
local function skyShards()
	local colors = { THEMES.Hub.trim, THEMES.Meadow.trim, THEMES.Canyon.trim, THEMES.Spires.trim }
	for i = 1, 40 do
		local side = if i % 2 == 0 then 1 else -1
		local pos = Vector3.new(side * random:NextNumber(190, 340), random:NextNumber(-20, 90), random:NextNumber(-1800, 120))
		local size = Vector3.new(random:NextNumber(10, 34), random:NextNumber(4, 12), random:NextNumber(10, 34))
		local cf = CFrame.new(pos) * CFrame.Angles(random:NextNumber(-0.2, 0.2), random:NextNumber(0, 6), random:NextNumber(-0.2, 0.2))
		block("Shard", size, cf, Color3.fromRGB(30, 30, 52), METAL)
		block("ShardTrim", Vector3.new(size.X + 0.3, 0.4, size.Z + 0.3), cf * CFrame.new(0, -size.Y / 2, 0), colors[i % #colors + 1], NEON, { CanCollide = false })
		-- vài khối nhỏ trên mặt đảo
		for _ = 1, 3 do
			local h = random:NextNumber(2, 8)
			block("ShardBlock", Vector3.new(h, h, h), cf * CFrame.new(random:NextNumber(-size.X / 3, size.X / 3), size.Y / 2 + h / 2, random:NextNumber(-size.Z / 3, size.Z / 3)), Color3.fromRGB(44, 44, 70), METAL)
		end
	end
end

-- ================= Trang trí theo chủ đề =================

-- điểm ngẫu nhiên ở vành ngoài của vùng (tránh tinh thể data ở giữa và đường đi |x| < 14)
local function ringPoint(zone, minR, maxR)
	local h = zone.size / 2
	for _ = 1, 30 do
		local x = random:NextNumber(-h * maxR, h * maxR)
		local z = random:NextNumber(-h * maxR, h * maxR)
		local m = math.max(math.abs(x), math.abs(z)) / h
		if m >= minR and math.abs(x) > 16 then
			return zone.center + Vector3.new(x, 0, z)
		end
	end
	return zone.center + Vector3.new(h * minR, 0, 0)
end

local function voxelTree(pos, s)
	block("Trunk", Vector3.new(1.6, 6, 1.6) * s, CFrame.new(pos + Vector3.new(0, 3 * s, 0)), Color3.fromRGB(70, 96, 112))
	for i, spec in { { 6.2, 6.5 }, { 4.6, 9.7 }, { 3, 12.2 } } do
		block("Leaves", Vector3.one * spec[1] * s, CFrame.new(pos + Vector3.new(0, spec[2] * s, 0)) * CFrame.Angles(0, math.rad(i * 18), 0), jitter(Color3.fromRGB(110, 225, 160), 0.08), PLASTIC, { CanCollide = i == 1 })
	end
	-- "quả pixel" phát sáng gắn trên mặt tán lá
	for _ = 1, 3 do
		local onX = random:NextNumber() < 0.5
		local side = if random:NextNumber() < 0.5 then -1 else 1
		local offset = if onX then Vector3.new(side * 3.2, random:NextNumber(5, 8), random:NextNumber(-2.4, 2.4)) else Vector3.new(random:NextNumber(-2.4, 2.4), random:NextNumber(5, 8), side * 3.2)
		block("Fruit", Vector3.one * 0.8 * s, CFrame.new(pos + offset * s), Color3.fromRGB(255, 120, 200), NEON, { CanCollide = false })
	end
end

local function planter(pos, theme)
	block("Planter", Vector3.new(7, 1.4, 7), CFrame.new(pos + Vector3.new(0, 0.7, 0)), theme.wall, METAL)
	block("PlanterSoil", Vector3.new(6.2, 0.3, 6.2), CFrame.new(pos + Vector3.new(0, 1.5, 0)), Color3.fromRGB(90, 200, 130))
	for _ = 1, 4 do
		local h = random:NextNumber(0.8, 2.2)
		block("Sprout", Vector3.new(0.7, h, 0.7), CFrame.new(pos + Vector3.new(random:NextNumber(-2.4, 2.4), 1.6 + h / 2, random:NextNumber(-2.4, 2.4))), theme.glow, NEON, { CanCollide = false })
	end
end

local function dataCube(pos, color)
	local cube = block("DataCube", Vector3.one * 1.8, CFrame.new(pos) * CFrame.Angles(0.6, 0, 0.6), color, NEON, { CanCollide = false, Transparency = 0.1 })
	cube:SetAttribute("Spin", random:NextNumber(0.6, 1.4))
	Visuals.Light(cube, color, 10, 1)
end

-- bậc vách hẻm núi dọc tường đông/tây (khối cao dần về phía tường)
local function terraces(zone, theme, side)
	local h = zone.size / 2
	for i = 0, zone.size / TILE - 1 do
		local z = zone.center.Z - h + (i + 0.5) * TILE
		local steps = random:NextInteger(1, 2)
		for step = 1, steps do
			local height = step * 5 + random:NextInteger(0, 2) * 2
			local x = zone.center.X + side * (h - (steps - step) * 6 - 3)
			block("Cliff", Vector3.new(6, height, TILE), CFrame.new(x, height / 2, z), jitter(theme.a:Lerp(theme.wall, 0.3 + step * 0.1), 0.07))
			block("CliffEdge", Vector3.new(6.1, 0.25, TILE + 0.05), CFrame.new(x, height + 0.12, z), theme.trim, NEON, { CanCollide = false, Transparency = 0.35 })
		end
	end
end

-- mạch điện neon chạy trên sàn (hình chữ L)
local function circuitTrace(zone, theme)
	local start = zone.center + Vector3.new(random:NextNumber(-0.4, 0.4) * zone.size, 0.06, random:NextNumber(-0.4, 0.4) * zone.size)
	local lx = random:NextNumber(14, 36) * (if random:NextNumber() < 0.5 then -1 else 1)
	local lz = random:NextNumber(14, 36) * (if random:NextNumber() < 0.5 then -1 else 1)
	local trace = { CanCollide = false }
	block("Trace", Vector3.new(math.abs(lx), 0.1, 0.5), CFrame.new(start + Vector3.new(lx / 2, 0, 0)), theme.trim, NEON, trace)
	block("Trace", Vector3.new(0.5, 0.1, math.abs(lz)), CFrame.new(start + Vector3.new(lx, 0, lz / 2)), theme.trim, NEON, trace)
	block("TraceNode", Vector3.new(1.4, 0.12, 1.4), CFrame.new(start + Vector3.new(lx, 0, lz)), theme.glow, NEON, trace)
end

local function serverRack(pos, theme)
	local rack = block("ServerRack", Vector3.new(4, 10, 3), CFrame.new(pos + Vector3.new(0, 5, 0)), Color3.fromRGB(30, 30, 42), METAL)
	for i = 1, 5 do
		local led = block("Led", Vector3.new(3.4, 0.3, 0.1), rack.CFrame * CFrame.new(0, -4 + i * 1.6, -1.55), if i % 2 == 0 then theme.trim else Color3.fromRGB(80, 255, 140), NEON, { CanCollide = false })
		led:SetAttribute("Blink", true)
	end
	Visuals.Light(rack, theme.trim, 12, 1)
end

-- tháp kính nhiều tầng thu nhỏ dần, dải cửa sổ neon, đèn chớp trên đỉnh
local function neonTower(pos, height, theme)
	local w = random:NextInteger(6, 9)
	local y = 0
	while y < height do
		local h = math.min(random:NextInteger(8, 14), height - y)
		block("Tower", Vector3.new(w, h, w), CFrame.new(pos + Vector3.new(0, y + h / 2, 0)), jitter(theme.wall, 0.12), Enum.Material.Glass, { Reflectance = 0.15 })
		for _, face in { Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0) } do
			local size = if face.X ~= 0 then Vector3.new(0.2, 0.5, w * 0.7) else Vector3.new(w * 0.7, 0.5, 0.2)
			block("Window", size, CFrame.new(pos + Vector3.new(face.X * (w / 2 + 0.05), y + h * 0.6, face.Z * (w / 2 + 0.05))), theme.trim, NEON, { CanCollide = false })
		end
		y += h
		w = math.max(2, w - 1)
	end
	local tip = block("TowerTip", Vector3.one * 1.4, CFrame.new(pos + Vector3.new(0, y + 1.2, 0)), theme.glow, NEON, { CanCollide = false })
	tip:SetAttribute("Blink", true)
	Visuals.Light(tip, theme.glow, 22, 2)
end

local function holoRing(pos, color)
	local ring = block("HoloRing", Vector3.new(0.4, 12, 12), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(0.4, 0, 0), color, NEON, { Shape = Enum.PartType.Cylinder, CanCollide = false, Transparency = 0.55 })
	ring:SetAttribute("Spin", 0.5)
end

-- ❄️ cụm pha lê băng: vài khối kính xanh nghiêng, lõi neon
local function iceCluster(pos, theme)
	for _ = 1, random:NextInteger(3, 5) do
		local h = random:NextNumber(5, 15)
		local w = random:NextNumber(1.6, 3)
		local cf = CFrame.new(pos + Vector3.new(random:NextNumber(-2.5, 2.5), h / 2 - 0.5, random:NextNumber(-2.5, 2.5))) * CFrame.Angles(random:NextNumber(-0.35, 0.35), random:NextNumber(0, 6), random:NextNumber(-0.35, 0.35))
		block("Ice", Vector3.new(w, h, w), cf, Color3.fromRGB(170, 225, 255), Enum.Material.Glass, { Transparency = 0.3, Reflectance = 0.25 })
	end
	local core = block("IceCore", Vector3.one * 1.6, CFrame.new(pos + Vector3.new(0, 2, 0)), theme.glow, NEON, { CanCollide = false })
	Visuals.Light(core, theme.glow, 14, 1.5)
end

-- hạt rơi/bay trên cả vùng (tuyết, tàn lửa) bằng ParticleEmitter dạng hộp
local function weather(zone, color, fromTop)
	local emitter = block("Weather", Vector3.new(zone.size, 1, zone.size), CFrame.new(zone.center + Vector3.new(0, if fromTop then 60 else 1, 0)), color, PLASTIC, { Transparency = 1, CanCollide = false, CanQuery = false })
	local p = Instance.new("ParticleEmitter")
	p.Shape = Enum.ParticleEmitterShape.Box
	p.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	p.EmissionDirection = if fromTop then Enum.NormalId.Bottom else Enum.NormalId.Top
	p.Color = ColorSequence.new(color)
	p.LightEmission = if fromTop then 0.3 else 1
	p.Rate = 70
	p.Lifetime = NumberRange.new(6, 10)
	p.Speed = NumberRange.new(4, 9)
	p.SpreadAngle = Vector2.new(15, 15)
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, if fromTop then 0.35 else 0.25), NumberSequenceKeypoint.new(1, 0.1) })
	p.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	p.Parent = emitter
end

-- 🌋 hồ dung nham phát sáng có viền đá
local function lavaPool(pos, theme)
	local w, d = random:NextNumber(8, 14), random:NextNumber(8, 14)
	block("LavaRim", Vector3.new(w + 1.4, 0.5, d + 1.4), CFrame.new(pos + Vector3.new(0, 0.25, 0)), theme.wall, METAL)
	local lava = block("Lava", Vector3.new(w, 0.3, d), CFrame.new(pos + Vector3.new(0, 0.42, 0)), theme.glow, NEON, { CanCollide = false })
	lava:SetAttribute("Blink", true)
	Visuals.Light(lava, theme.glow, 18, 2)
end

-- 🌋 trụ lò rèn: khối bazan + lửa trên đỉnh
local function forgePillar(pos, theme)
	local h = random:NextNumber(10, 22)
	block("Forge", Vector3.new(4, h, 4), CFrame.new(pos + Vector3.new(0, h / 2, 0)), jitter(theme.a, 0.1), METAL)
	block("ForgeBand", Vector3.new(4.3, 0.6, 4.3), CFrame.new(pos + Vector3.new(0, h * 0.7, 0)), theme.trim, NEON, { CanCollide = false })
	local top = block("ForgeTop", Vector3.new(4.6, 1, 4.6), CFrame.new(pos + Vector3.new(0, h + 0.5, 0)), theme.wall, METAL)
	local fire = Instance.new("Fire")
	fire.Size = 7
	fire.Heat = 12
	fire.Color = Color3.fromRGB(255, 120, 30)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
	fire.Parent = top
	Visuals.Light(top, theme.glow, 24, 2.5)
end

-- 🌀 khối glitch lơ lửng xoay
local function glitchCube(pos, theme)
	local size = random:NextNumber(1.5, 4)
	local cube = block("GlitchCube", Vector3.one * size, CFrame.new(pos) * CFrame.Angles(random:NextNumber(0, 6), random:NextNumber(0, 6), random:NextNumber(0, 6)), if random:NextNumber() < 0.5 then theme.glow else Color3.fromRGB(60, 255, 230), NEON, { CanCollide = false, Transparency = 0.15 })
	cube:SetAttribute("Spin", random:NextNumber(-2, 2))
	if random:NextNumber() < 0.4 then
		cube:SetAttribute("Blink", true)
	end
end

-- 🌀 bia đá đen viền neon + cột sáng
local function monolith(pos, theme)
	local h = random:NextNumber(12, 26)
	local slab = block("Monolith", Vector3.new(6, h, 2), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, random:NextNumber(0, 6), 0), Color3.fromRGB(10, 6, 16), Enum.Material.Glass, { Reflectance = 0.3 })
	block("MonolithEdge", Vector3.new(6.2, 0.4, 2.2), slab.CFrame * CFrame.new(0, h / 2, 0), theme.trim, NEON, { CanCollide = false })
	local beam = block("RiftBeam", Vector3.new(0.8, 70, 0.8), CFrame.new(pos + Vector3.new(random:NextNumber(-6, 6), 35, random:NextNumber(-6, 6))), theme.glow, NEON, { CanCollide = false, Transparency = 0.35 })
	beam:SetAttribute("Blink", true)
end

-- ☁️ cột đá trắng mũ vàng
local function column(pos, theme)
	local h = random:NextNumber(14, 26)
	block("Column", Vector3.new(h, 3.4, 3.4), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), theme.a, Enum.Material.Marble, { Shape = Enum.PartType.Cylinder })
	for _, y in { 0.6, h } do
		block("ColumnCap", Vector3.new(4.8, 1.2, 4.8), CFrame.new(pos + Vector3.new(0, y, 0)), theme.trim, METAL, { Reflectance = 0.3 })
	end
end

-- ☁️ cổng vòm vàng
local function goldenArch(pos, theme)
	for _, dx in { -5, 5 } do
		block("ArchPillar", Vector3.new(2, 14, 2), CFrame.new(pos + Vector3.new(dx, 7, 0)), theme.a, Enum.Material.Marble)
	end
	local top = block("ArchTop", Vector3.new(13, 1.6, 2.4), CFrame.new(pos + Vector3.new(0, 14.8, 0)), theme.trim, METAL, { Reflectance = 0.35 })
	Visuals.Light(top, theme.glow, 20, 1.5)
end

-- ☁️ mây khối (nhiều quả cầu trắng) trôi trên cao
local function cloud(pos)
	for _ = 1, random:NextInteger(4, 7) do
		local r = random:NextNumber(5, 10)
		block("Cloud", Vector3.one * r, CFrame.new(pos + Vector3.new(random:NextNumber(-8, 8), random:NextNumber(-1.5, 2), random:NextNumber(-5, 5))), Color3.fromRGB(255, 255, 255), PLASTIC, { Shape = Enum.PartType.Ball, CanCollide = false, Transparency = 0.15 })
	end
end

local function decorate(zone, theme)
	if zone.id == "Meadow" then
		for _ = 1, 18 do
			voxelTree(ringPoint(zone, 0.82, 0.94), random:NextNumber(0.9, 1.3))
		end
		for _ = 1, 6 do
			planter(ringPoint(zone, 0.8, 0.9), theme)
		end
		for _ = 1, 12 do
			dataCube(zone.center + Vector3.new(random:NextNumber(-0.45, 0.45) * zone.size, random:NextNumber(9, 16), random:NextNumber(-0.45, 0.45) * zone.size), theme.glow)
		end
	elseif zone.id == "Canyon" then
		terraces(zone, theme, -1)
		terraces(zone, theme, 1)
		for _ = 1, 14 do
			circuitTrace(zone, theme)
		end
		for _ = 1, 8 do
			local pos = ringPoint(zone, 0.8, 0.86)
			if math.abs(pos.X - zone.center.X) < zone.size * 0.35 then
				serverRack(pos, theme)
			end
		end
	elseif zone.id == "Frost" then
		for _ = 1, 16 do
			iceCluster(ringPoint(zone, 0.82, 0.94), theme)
		end
		for _ = 1, 6 do
			local pos = ringPoint(zone, 0.8, 0.88)
			serverRack(pos, theme)
		end
		for _ = 1, 8 do
			dataCube(zone.center + Vector3.new(random:NextNumber(-0.45, 0.45) * zone.size, random:NextNumber(9, 16), random:NextNumber(-0.45, 0.45) * zone.size), theme.glow)
		end
		weather(zone, Color3.fromRGB(240, 250, 255), true)
	elseif zone.id == "Magma" then
		for _ = 1, 10 do
			lavaPool(ringPoint(zone, 0.8, 0.92), theme)
		end
		for _ = 1, 12 do
			forgePillar(ringPoint(zone, 0.84, 0.94), theme)
		end
		for _ = 1, 12 do
			circuitTrace(zone, theme)
		end
		weather(zone, Color3.fromRGB(255, 150, 40), false)
	elseif zone.id == "Rift" then
		for _ = 1, 10 do
			monolith(ringPoint(zone, 0.84, 0.94), theme)
		end
		for _ = 1, 26 do
			glitchCube(zone.center + Vector3.new(random:NextNumber(-0.47, 0.47) * zone.size, random:NextNumber(6, 22), random:NextNumber(-0.47, 0.47) * zone.size), theme)
		end
		for _ = 1, 10 do
			circuitTrace(zone, theme)
		end
	elseif zone.id == "Citadel" then
		for _ = 1, 16 do
			column(ringPoint(zone, 0.84, 0.94), theme)
		end
		for _ = 1, 4 do
			goldenArch(ringPoint(zone, 0.8, 0.86), theme)
		end
		for _ = 1, 10 do
			cloud(zone.center + Vector3.new(random:NextNumber(-0.6, 0.6) * zone.size, random:NextNumber(24, 40), random:NextNumber(-0.6, 0.6) * zone.size))
		end
		holoRing(zone.center + Vector3.new(0, 34, 0), theme.glow)
	else
		for _ = 1, 14 do
			neonTower(ringPoint(zone, 0.84, 0.94), random:NextNumber(20, 60), theme)
		end
		for _ = 1, 7 do
			holoRing(zone.center + Vector3.new(random:NextNumber(-0.4, 0.4) * zone.size, random:NextNumber(14, 26), random:NextNumber(-0.4, 0.4) * zone.size), theme.glow)
		end
		for _ = 1, 10 do
			circuitTrace(zone, theme)
		end
	end
end

-- cổng vào vùng: 2 trụ khối + thanh ngang neon + biển tên, khoá level hiện trên biển
local function zoneGate(zone)
	local z = zone.center.Z + zone.size / 2 + 1.5
	local color = zone.crystal
	for _, x in { -14, 14 } do
		local pillar = block("GatePillar", Vector3.new(4, 20, 4), CFrame.new(x, 10, z), Color3.fromRGB(40, 44, 60), METAL)
		block("GateGlow", Vector3.new(0.6, 19, 4.2), pillar.CFrame * CFrame.new(-math.sign(x) * 2.2, 0, 0), color, NEON, { CanCollide = false })
	end
	local beam = block("GateBeam", Vector3.new(32, 2.4, 4), CFrame.new(0, 21, z), color, NEON)
	Visuals.Light(beam, color, 30, 2.5)
	local lock = if zone.level > 1 then string.format("\n<font size='22' color='#FFD84D'>🔒 Level %d</font>", zone.level) else ""
	Visuals.Label(beam, string.format("%s %s%s", zone.emoji, string.upper(zone.name), lock), UDim2.fromScale(30, 7), Vector3.new(0, 5, 0), Color3.new(1, 1, 1), 400)
end

-- ================= Tinh thể data =================

local function setNode(part, active)
	nodes[part].active = active
	part.Transparency = if active then 0.15 else 1
	part.PointLight.Enabled = active
	part.Sparks.Enabled = active
end

-- Lấy tinh thể còn data gần `position` nhất trong bán kính `range`
function WorldService.NearestNode(position, range)
	local best, bestDist
	for part, info in nodes do
		if info.active then
			local dist = (part.Position - position).Magnitude
			if dist <= range and (not bestDist or dist < bestDist) then
				best, bestDist = part, dist
			end
		end
	end
	return best, best and nodes[best].zone
end

-- Thu thập 1 tinh thể: tắt đi rồi tự mọc lại sau NodeRespawn giây
function WorldService.HarvestNode(part)
	if not nodes[part] or not nodes[part].active then
		return false
	end
	setNode(part, false)
	task.delay(Config.NodeRespawn, function()
		if nodes[part] then
			setNode(part, true)
		end
	end)
	return true
end

local function buildNodes(zone)
	for _ = 1, zone.nodes do
		local offset = Vector3.new(random:NextNumber(-0.37, 0.37) * zone.size, 0, random:NextNumber(-0.37, 0.37) * zone.size)
		if math.abs(offset.X) < 9 then
			offset += Vector3.new(14, 0, 0) -- chừa đường đi ở giữa
		end
		local crystal = Visuals.Part({
			Name = "DataNode",
			Size = Vector3.new(2.2, 4.5, 2.2),
			CFrame = CFrame.new(zone.center + offset + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, random:NextNumber(0, 6), math.rad(random:NextNumber(-12, 12))),
			Color = zone.crystal,
			Material = Enum.Material.Neon,
			Transparency = 0.15,
			CanCollide = false,
			Parent = world,
		})
		Visuals.Light(crystal, zone.crystal, 10, 1.5)
		Visuals.Particles(crystal, zone.crystal, 3).Name = "Sparks"
		crystal:SetAttribute("Spin", 0.8)
		nodes[crystal] = { zone = zone, active = true }
	end
end

-- ================= Hub =================

local function buildHub()
	local c = Config.Hub.center
	local theme = THEMES.Hub
	tiledIsland(c, 110, 110, theme)
	walls(c, 110, 110, theme, { north = 10 }, true)
	block("PlazaRing", Vector3.new(0.3, 30, 30), CFrame.new(c + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2), theme.glow, NEON, { Shape = Enum.PartType.Cylinder, CanCollide = false, Transparency = 0.45 })
	-- trụ đèn 4 góc
	for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
		local pos = c + corner * 50
		block("LightPylon", Vector3.new(3, 18, 3), CFrame.new(pos + Vector3.new(0, 9, 0)), theme.wall, METAL)
		local lamp = block("LightPylonLamp", Vector3.new(3.4, 2, 3.4), CFrame.new(pos + Vector3.new(0, 18.5, 0)), theme.trim, NEON, { CanCollide = false })
		Visuals.Light(lamp, theme.trim, 40, 2)
	end
	-- cổng ra vùng phía bắc
	for _, x in { -11, 11 } do
		block("ExitPillar", Vector3.new(3, 14, 3), CFrame.new(x, 7, -54), theme.wall, METAL)
	end
	local exitBeam = block("ExitBeam", Vector3.new(25, 1.6, 3), CFrame.new(0, 14.6, -54), theme.trim, NEON)
	Visuals.Label(exitBeam, "🚀 TO THE FRONTIER", UDim2.fromScale(22, 4), Vector3.new(0, 3.5, 0), Color3.fromRGB(180, 245, 255), 300)

	-- Cổng sự kiện Glitch Floor (dịch chuyển lên sàn đấu khi lượt mới bắt đầu)
	local portalPos = c + Vector3.new(44, 0, -24)
	for _, dz in { -6, 6 } do
		block("PortalPillar", Vector3.new(2.4, 13, 2.4), CFrame.new(portalPos + Vector3.new(0, 6.5, dz)), Color3.fromRGB(40, 30, 50), METAL)
	end
	local portalBeam = block("PortalBeam", Vector3.new(2.6, 1.4, 14.4), CFrame.new(portalPos + Vector3.new(0, 13.6, 0)), Color3.fromRGB(255, 60, 90), NEON)
	Visuals.Light(portalBeam, portalBeam.Color, 24, 2)
	local portalPad = block("PortalPad", Vector3.new(9, 0.5, 11), CFrame.new(portalPos + Vector3.new(0, 0.25, 0)), Color3.fromRGB(255, 60, 90), NEON, { Transparency = 0.25 })
	Visuals.Particles(portalPad, portalPad.Color, 8)
	Visuals.Label(portalBeam, "🟥 GLITCH FLOOR\n<font size='16'>Last one standing wins!</font>", UDim2.fromScale(14, 4), Vector3.new(0, 4, 0), Color3.fromRGB(255, 170, 190), 220)
	prompt(portalPad, "Glitch Floor", "Join next round", 14).Triggered:Connect(function(player)
		if WorldService.OnEventJoin then
			WorldService.OnEventJoin(player)
		end
	end)

	-- Trạm upload: tháp trung tâm có vòng hologram quay
	local tower = Visuals.Part({ Name = "UploadTower", Size = Vector3.new(8, 22, 8), CFrame = CFrame.new(c + Vector3.new(0, 11, -18)), Color = Color3.fromRGB(35, 40, 60), Material = Enum.Material.Metal, Parent = world })
	local core = Visuals.Part({ Name = "UploadCore", Shape = Enum.PartType.Ball, Size = Vector3.one * 7, CFrame = CFrame.new(c + Vector3.new(0, 27, -18)), Color = Color3.fromRGB(0, 220, 255), Material = Enum.Material.Neon, CanCollide = false, Parent = world })
	Visuals.Light(core, core.Color, 40, 3)
	Visuals.Particles(core, core.Color, 12)
	for i, tilt in { 0.4, -0.5 } do
		local ring = Visuals.Part({ Name = "Ring" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 13, 13), CFrame = core.CFrame * CFrame.Angles(tilt, 0, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(150, 240, 255), Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false, Parent = world })
		ring:SetAttribute("Spin", if i == 1 then 1.2 else -0.9)
	end
	Visuals.Label(tower, "📡 UPLOAD STATION", UDim2.fromScale(20, 4), Vector3.new(0, 20, 0), Color3.fromRGB(150, 240, 255), 250)
	local pad = Visuals.Part({ Name = "UploadPad", Size = Vector3.new(16, 0.6, 8), CFrame = CFrame.new(c + Vector3.new(0, 0.6, -10)), Color = Color3.fromRGB(0, 200, 255), Material = Enum.Material.Neon, Transparency = 0.3, Parent = world })
	prompt(pad, "Upload Station", "Upload Data", 14).Triggered:Connect(function(player)
		if WorldService.OnUpload then
			WorldService.OnUpload(player)
		end
	end)
	-- bước lên tấm sáng cũng tự upload
	pad.Touched:Connect(function(hit)
		local player = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
		if player and WorldService.OnUpload then
			WorldService.OnUpload(player, true)
		end
	end)

	-- Capsule Lab: 4 buồng kính, capsule xoay bên trong, bệ trưng bày bot hiếm nhất phía trước
	local lab = c + Vector3.new(-30, 0, 4)
	local toCenter = Vector3.new(c.X - lab.X, 0, c.Z - lab.Z).Unit
	local side = Vector3.new(-toCenter.Z, 0, toCenter.X)
	local wallPos = lab - toCenter * 7 + Vector3.new(0, 8, 0)
	local labWidth = #Config.Capsules * 9.5 + 4
	local wall = Visuals.Part({ Name = "LabWall", Size = Vector3.new(labWidth, 16, 1.5), CFrame = CFrame.lookAt(wallPos, wallPos + toCenter), Color = Color3.fromRGB(28, 32, 50), Material = Enum.Material.Metal, Parent = world })
	Visuals.Part({ Name = "LabStrip", Size = Vector3.new(labWidth + 0.2, 0.6, 1.7), CFrame = wall.CFrame * CFrame.new(0, 6.5, 0), Color = Color3.fromRGB(255, 70, 200), Material = Enum.Material.Neon, CanCollide = false, Parent = world })
	Visuals.Label(wall, "🥚 CAPSULE LAB", UDim2.fromScale(26, 4.5), Vector3.new(0, 11, 0), Color3.fromRGB(255, 160, 230), 260)
	for i, capsule in Config.Capsules do
		local pos = lab + side * ((i - (#Config.Capsules + 1) / 2) * 9.5)
		local premium = capsule.premium == true
		local width = if premium then 7.5 else 6.5
		local base = Visuals.Part({ Name = capsule.id .. "Pod", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, width + 1, width + 1), CFrame = CFrame.new(pos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(40, 44, 64), Material = Enum.Material.Metal, Parent = world })
		Visuals.Part({ Name = "PodRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, width + 1.4, width + 1.4), CFrame = CFrame.new(pos + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = capsule.color, Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false, Parent = world })
		Visuals.Part({ Name = "PodGlass", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, width, width), CFrame = CFrame.new(pos + Vector3.new(0, 5.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(200, 230, 255), Material = Enum.Material.Glass, Transparency = 0.7, Parent = world })
		local cap = Visuals.Part({ Name = "PodCap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, width + 0.6, width + 0.6), CFrame = CFrame.new(pos + Vector3.new(0, 9.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(40, 44, 64), Material = Enum.Material.Metal, Parent = world })
		Visuals.Light(cap, capsule.color, 14, 2)
		-- capsule bên trong: mọi part cùng trục nên Spin (xoay quanh trục Y của chính part) vẫn khớp
		local model = BotModels.Capsule(capsule.color, if premium then 4.2 else 3.6)
		model.model:PivotTo(CFrame.new(pos + Vector3.new(0, 5.2, 0)))
		for _, part in model.model:GetChildren() do
			part:SetAttribute("Spin", if premium then 1.2 else 0.8)
		end
		model.model.Parent = world
		local priceText = if capsule.price then "💳 " .. Config.Short(capsule.price) else "<font color='#7CFFB0'>ROBUX ONLY</font>"
		local lockText = if capsule.level > 1 then string.format("  🔒 Lv.%d", capsule.level) else ""
		Visuals.Label(cap, string.format("%s %s\n<font size='18'>%s%s</font>", capsule.emoji, string.upper(capsule.name), priceText, lockText), UDim2.fromScale(12, 3.6), Vector3.new(0, 3.2, 0), capsule.color:Lerp(Color3.new(1, 1, 1), 0.4), 160)
		prompt(base, capsule.name, "Open Capsule Lab", 14).Triggered:Connect(function(player)
			if WorldService.OnOpen then
				WorldService.OnOpen(player, "Capsules")
			end
		end)
		-- bệ trưng bày: bot hiếm nhất của capsule (để người chơi "săn")
		local chase = capsule.drops[#capsule.drops]
		local bot = Config.BotById[chase.bot]
		local plinthPos = pos + toCenter * 6
		local plinth = Visuals.Part({ Name = "Plinth", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 3.4, 3.4), CFrame = CFrame.new(plinthPos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(235, 240, 250), Material = Enum.Material.SmoothPlastic, Parent = world })
		Visuals.Part({ Name = "PlinthRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.05, 3.7, 3.7), CFrame = plinth.CFrame, Color = Config.RarityColors[bot.rarity], Material = Enum.Material.Neon, Transparency = 0.4, CanCollide = false, Parent = world })
		local rig = BotModels.Build(bot, 1)
		local standAt = plinthPos + Vector3.new(0, 1 + rig.size * 1.1, 0)
		BotModels.Pose(rig, CFrame.lookAt(standAt, standAt + toCenter), 0)
		rig.model.Parent = world
		Visuals.Label(plinth, string.format("%s\n<font size='16' color='#%s'>%s · %s</font>", bot.name, Config.RarityColors[bot.rarity]:ToHex(), bot.rarity, Config.FormatChance(chase.weight / 100)), UDim2.fromScale(8, 2.4), Vector3.new(0, 2.6 + rig.size * 2, 0), Color3.new(1, 1, 1), 90)
	end

	-- Tech Shop (nâng cấp ba lô)
	local tech = Visuals.Part({ Name = "TechShop", Size = Vector3.new(16, 10, 10), CFrame = CFrame.new(c + Vector3.new(26, 5, 6)) * CFrame.Angles(0, math.rad(-60), 0), Color = Color3.fromRGB(90, 140, 255), Material = Enum.Material.SmoothPlastic, Parent = world })
	Visuals.Label(tech, "🎒 GEAR SHOP", UDim2.fromScale(16, 3.5), Vector3.new(0, 9, 0), Color3.fromRGB(180, 210, 255), 250)
	prompt(tech, "Gear Shop", "Upgrade backpack", 16).Triggered:Connect(function(player)
		if WorldService.OnOpen then
			WorldService.OnOpen(player, "Gear")
		end
	end)

	-- Unit-0: robot giao nhiệm vụ
	local body = Visuals.Part({ Name = "Unit0", Size = Vector3.new(3, 4, 2.4), CFrame = CFrame.new(c + Vector3.new(12, 3, 16)), Color = Color3.fromRGB(235, 240, 250), Material = Enum.Material.SmoothPlastic, Parent = world })
	local head = Visuals.Part({ Name = "Unit0Head", Size = Vector3.new(2.6, 2, 2.2), CFrame = body.CFrame * CFrame.new(0, 3.1, 0), Color = Color3.fromRGB(235, 240, 250), Material = Enum.Material.SmoothPlastic, Parent = world })
	Visuals.Part({ Name = "Visor", Size = Vector3.new(2, 0.6, 0.2), CFrame = head.CFrame * CFrame.new(0, 0.1, -1.15), Color = Color3.fromRGB(0, 220, 255), Material = Enum.Material.Neon, CanCollide = false, Parent = world })
	Visuals.Label(head, "🤖 Unit-0\n<font size='16' color='#FFD84D'>❗ Quests</font>", UDim2.fromScale(7, 2.6), Vector3.new(0, 3, 0))
	prompt(body, "Unit-0", "Talk", 12).Triggered:Connect(function(player)
		if WorldService.OnOpen then
			WorldService.OnOpen(player, "Quests")
		end
	end)

end

-- ================= Sàn đấu Glitch Floor =================

local function buildArena()
	local e = Config.Event
	local center = e.ArenaCenter
	local n, size = e.Grid, e.TileSize
	local tiles = {}
	for ix = 1, n do
		for iz = 1, n do
			local x = center.X + (ix - (n + 1) / 2) * size
			local z = center.Z + (iz - (n + 1) / 2) * size
			local base = block("ArenaTile", Vector3.new(size - 0.6, 1.2, size - 0.6), CFrame.new(x, center.Y - 0.6, z), Color3.fromRGB(30, 34, 56))
			local inlay = block("ArenaInlay", Vector3.new(size - 2.2, 0.1, size - 2.2), CFrame.new(x, center.Y + 0.05, z), Color3.fromRGB(0, 220, 255), NEON, { CanCollide = false, Transparency = 0.25 })
			table.insert(tiles, { base = base, inlay = inlay, ix = ix, iz = iz })
		end
	end
	-- trụ 4 góc đặt ngoài mép sàn để người rơi không bám được
	local half = n * size / 2
	for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
		local pos = center + corner * (half + 5)
		block("ArenaPylon", Vector3.new(3, 30, 3), CFrame.new(pos + Vector3.new(0, 2, 0)), Color3.fromRGB(30, 30, 50), METAL)
		local cap = block("ArenaPylonCap", Vector3.new(3.4, 1.2, 3.4), CFrame.new(pos + Vector3.new(0, 17.6, 0)), Color3.fromRGB(255, 60, 90), NEON, { CanCollide = false })
		cap:SetAttribute("Blink", true)
		Visuals.Light(cap, cap.Color, 34, 2)
	end
	block("ArenaRim", Vector3.new(n * size + 4, 0.6, n * size + 4), CFrame.new(center + Vector3.new(0, -14, 0)), Color3.fromRGB(255, 60, 90), NEON, { CanCollide = false, Transparency = 0.6 })
	local sign = block("ArenaSign", Vector3.new(36, 2, 1), CFrame.new(center + Vector3.new(0, 24, -half - 6)), Color3.fromRGB(255, 60, 90), NEON, { CanCollide = false })
	Visuals.Label(sign, "🟥 GLITCH FLOOR", UDim2.fromScale(36, 7), Vector3.new(0, 4, 0), Color3.new(1, 1, 1), 400)
	WorldService.Arena = { center = center, top = center.Y, half = half, tiles = tiles }
end

function WorldService.Start()
	Visuals.SetupLighting()
	world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace
	-- bỏ Baseplate và mọi Terrain có sẵn: thế giới giờ toàn là khối
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	workspace.Terrain:Clear()
	voidGrid()
	skyShards()
	buildHub()
	local zones = Config.Zones
	-- cầu: Hub -> vùng 1 -> vùng 2 -> vùng 3
	bridge(Config.Hub.center.Z - 55, zones[1].center.Z + zones[1].size / 2, THEMES.Hub)
	for i = 1, #zones - 1 do
		bridge(zones[i].center.Z - zones[i].size / 2, zones[i + 1].center.Z + zones[i + 1].size / 2, THEMES[zones[i].id])
	end
	for i, zone in zones do
		local theme = THEMES[zone.id]
		tiledIsland(zone.center, zone.size, zone.size, theme)
		walls(zone.center, zone.size, zone.size, theme, { south = 14, north = if i < #zones then 14 else nil })
		zoneGate(zone)
		buildNodes(zone)
		decorate(zone, theme)
	end
	buildArena()
end

function WorldService.HubSpawn()
	return CFrame.new(Config.Hub.center + Vector3.new(0, 4, 20))
end

return WorldService
