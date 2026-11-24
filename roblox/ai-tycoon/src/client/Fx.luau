-- Hiệu ứng chạy riêng ở máy người chơi (không tốn băng thông server):
--   Blink = true   -> LED nhấp nháy lệch nhịp nhau
--   Spin = số      -> xoay quanh trục Y của thế giới (radian/giây)

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Fx = {}

local spinning = {} -- [part] = tốc độ

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
end

function Fx.Start(root)
	for _, inst in root:GetDescendants() do
		track(inst)
	end
	root.DescendantAdded:Connect(track)
	root.DescendantRemoving:Connect(function(inst)
		spinning[inst] = nil
	end)

	RunService.RenderStepped:Connect(function(dt)
		for part, speed in spinning do
			local pos = part.Position
			part.CFrame = CFrame.new(pos) * CFrame.Angles(0, speed * dt, 0) * (CFrame.new(-pos) * part.CFrame)
		end
	end)
end

return Fx
