-- Hiệu ứng chạy riêng ở máy người chơi (không tốn băng thông server):
--   Blink = true          -> nhấp nháy lệch nhịp nhau
--   Spin = số             -> xoay quanh trục Y của thế giới (radian/giây)
--   Drive = số            -> chạy dọc trục X (stud/giây), quay vòng trong [DriveMin, DriveMax].
--                            Tính theo giờ server nên mọi người chơi thấy xe ở cùng chỗ.
--   Bob = số              -> nhún lên xuống nhẹ (biên độ stud), như nhân viên đang gõ phím

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Fx = {}

local spinning = {} -- [part] = tốc độ
local driving = {} -- [part] = { speed, x0, min, max, offset }
local bobbing = {} -- [part] = { amplitude, base, phase }
local started = false

local function track(inst)
	if not inst:IsA("BasePart") then
		return
	end
	if inst:GetAttribute("Blink") then
		-- nhịp ngẫu nhiên để cả dàn LED không chớp cùng lúc
		local info = TweenInfo.new(0.4 + math.random() * 0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, math.random() * 0.6)
		TweenService:Create(inst, info, { Transparency = 0.75 }):Play()
	end
	local speed = inst:GetAttribute("Spin")
	if type(speed) == "number" then
		spinning[inst] = speed
	end
	local bob = inst:GetAttribute("Bob")
	if type(bob) == "number" then
		bobbing[inst] = { amplitude = bob, base = inst.CFrame, phase = math.random() * math.pi * 2 }
	end
	local driveSpeed = inst:GetAttribute("Drive")
	if type(driveSpeed) == "number" then
		local min = inst:GetAttribute("DriveMin") or -250
		local max = inst:GetAttribute("DriveMax") or 250
		driving[inst] = {
			speed = driveSpeed,
			x0 = inst.Position.X,
			min = min,
			span = max - min,
			offset = inst.CFrame - inst.Position, -- giữ nguyên hướng xoay
		}
	end
end

local function untrack(inst)
	spinning[inst] = nil
	driving[inst] = nil
	bobbing[inst] = nil
end

function Fx.Start(root)
	for _, inst in root:GetDescendants() do
		track(inst)
	end
	root.DescendantAdded:Connect(track)
	root.DescendantRemoving:Connect(untrack)

	if started then
		return
	end
	started = true
	RunService.RenderStepped:Connect(function(dt)
		for part, speed in spinning do
			local pos = part.Position
			part.CFrame = CFrame.new(pos) * CFrame.Angles(0, speed * dt, 0) * (CFrame.new(-pos) * part.CFrame)
		end
		local t = workspace:GetServerTimeNow()
		local clock = os.clock()
		for part, b in bobbing do
			part.CFrame = b.base * CFrame.new(0, math.abs(math.sin(clock * 9 + b.phase)) * b.amplitude, 0)
		end
		for part, d in driving do
			local x = d.min + (d.x0 - d.min + d.speed * t) % d.span
			local pos = part.Position
			part.CFrame = CFrame.new(x, pos.Y, pos.Z) * d.offset
		end
	end)
end

return Fx
