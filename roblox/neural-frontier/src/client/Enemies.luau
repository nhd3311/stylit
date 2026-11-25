-- Vẽ quái và boss ở máy người chơi: mỗi "thân" vô hình trong workspace.Enemies (server điều khiển)
-- được gắn 1 model riêng theo thuộc tính Model/Color/Size/Elite, bám theo thân từng khung hình
-- và cử động (cánh quạt, chân, cánh, vòng quay). Quái ở xa không vẽ để nhẹ máy.
-- Kèm thanh máu boss lớn ở trên màn hình khi đứng gần boss.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BotModels = require(Shared:WaitForChild("BotModels"))
local EnemyModels = require(Shared:WaitForChild("EnemyModels"))

local Enemies = {}

local DRAW_DISTANCE = 320 -- xa hơn thì cất model đi
local BOSS_BAR_DISTANCE = 130

local fxFolder = Instance.new("Folder")
fxFolder.Name = "EnemyFx"
fxFolder.Parent = workspace

local rigs = {} -- [body] = { rig, phase }
local started = false

local function attach(body)
	if not body:IsA("BasePart") or rigs[body] then
		return
	end
	local modelId = body:GetAttribute("Model")
	if type(modelId) ~= "string" then
		return
	end
	local ok, rig = pcall(EnemyModels.Build, modelId, body:GetAttribute("Size") or body.Size.X, body:GetAttribute("Color") or Color3.fromRGB(255, 80, 80), body:GetAttribute("Elite") == true)
	if not ok then
		warn("[Enemies] Không dựng được model", modelId, rig)
		return
	end
	rig.model.Parent = fxFolder
	rigs[body] = { rig = rig, phase = math.random() * 6 }
end

local function detach(body)
	local entry = rigs[body]
	if entry then
		entry.rig.model:Destroy()
		rigs[body] = nil
	end
end

-- boss gần nhất trong tầm (cho thanh máu lớn)
function Enemies.NearestBoss(maxDistance)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local best, bestDist
	for body in rigs do
		if body.Parent and body:GetAttribute("Boss") then
			local dist = (body.Position - root.Position).Magnitude
			if dist <= (maxDistance or BOSS_BAR_DISTANCE) and (not bestDist or dist < bestDist) then
				best, bestDist = body, dist
			end
		end
	end
	return best
end

function Enemies.Start()
	if started then
		return
	end
	started = true
	local folder = workspace:WaitForChild("Enemies")
	for _, body in folder:GetChildren() do
		attach(body)
	end
	folder.ChildAdded:Connect(attach)
	folder.ChildRemoved:Connect(detach)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local camera = workspace.CurrentCamera
		local eye = camera and camera.CFrame.Position
		for body, entry in rigs do
			if not body.Parent then
				detach(body)
				continue
			end
			local rig = entry.rig
			if eye and (body.Position - eye).Magnitude > DRAW_DISTANCE then
				if rig.model.Parent then
					rig.model.Parent = nil
				end
				continue
			elseif not rig.model.Parent then
				rig.model.Parent = fxFolder
			end
			-- boss giận dữ (phase cao) thì cử động nhanh hơn
			local speed = 1 + ((body:GetAttribute("Phase") or 1) - 1) * 0.35
			local bob = math.sin(t * 2 + entry.phase) * 0.06 * rig.size
			BotModels.Pose(rig, body.CFrame * CFrame.new(0, bob, 0), t * speed + entry.phase)
		end
	end)
end

return Enemies
