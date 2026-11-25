-- Vẽ Habitat của mọi người chơi ở máy mình (không tốn băng thông server):
--   • bot trong vườn đi dạo ngẫu nhiên trong ô, nhún nhảy, quay mặt theo hướng đi
--   • 3 bot hiếm nhất đứng trên bệ trưng bày, xoay nhẹ
--   • biển tên: "🏠 Tên · 📚 23/40"
-- Đọc attribute người chơi: Plot (số ô), Habitat, Showcase ("id:level:variant,..."), Collection.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BotModels = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BotModels"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Habitat = {}

local H = Config.Habitat
local folder = Instance.new("Folder")
folder.Name = "HabitatFx"
folder.Parent = workspace

local owners = {} -- [player] = { plot, habitatKey, showcaseKey, walkers = {}, statues = {}, sign }
local random = Random.new()

local function parse(key)
	local list = {}
	for entry in (key or ""):gmatch("[^,]+") do
		local id, level, variant = entry:match("^(%w+):(%d+):?(%a*)$")
		local bot = id and Config.BotById[id]
		if bot then
			table.insert(list, { bot = bot, level = tonumber(level), variant = if variant ~= "" then variant else nil })
		end
	end
	return list
end

local function clearRigs(list)
	for _, item in list do
		item.rig.model:Destroy()
	end
	table.clear(list)
end

local function randomSpot(plot)
	local half = H.PlotSize / 2 - 4
	return plot + Vector3.new(random:NextNumber(-half, half), 0, random:NextNumber(-half, half))
end

local function makeSign(player, plotIndex)
	local world = workspace:FindFirstChild("World")
	local part = world and world:FindFirstChild("PlotSign_" .. plotIndex)
	if not part then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Adornee = part
	gui.Size = UDim2.fromScale(14, 4.5)
	gui.StudsOffset = Vector3.new(0, 1, 0)
	gui.MaxDistance = 160
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Michroma
	label.TextScaled = true
	label.RichText = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = folder
	return label
end

local function refresh(player)
	local plotIndex = player:GetAttribute("Plot")
	local plot = plotIndex and H.Plots[plotIndex]
	local owner = owners[player]
	if not owner or owner.plot ~= plotIndex then
		if owner then
			clearRigs(owner.walkers)
			clearRigs(owner.statues)
			if owner.sign then
				owner.sign.Parent:Destroy()
			end
		end
		owner = { plot = plotIndex, walkers = {}, statues = {} }
		owners[player] = owner
		if plot then
			owner.sign = makeSign(player, plotIndex)
		end
	end
	if not plot then
		return
	end
	-- biển có thể chưa tải về kịp lúc đầu: thử lại ở các lần sau
	if not owner.sign then
		owner.sign = makeSign(player, plotIndex)
	end
	-- bot dạo trong vườn
	local habitatKey = player:GetAttribute("Habitat") or ""
	if habitatKey ~= owner.habitatKey then
		owner.habitatKey = habitatKey
		clearRigs(owner.walkers)
		for _, item in parse(habitatKey) do
			local rig = BotModels.Build(item.bot, item.level, item.variant)
			rig.model.Parent = folder
			local start = randomSpot(plot)
			table.insert(owner.walkers, { rig = rig, pos = start, target = randomSpot(plot), wait = random:NextNumber(0, 2), phase = random:NextNumber(0, 6), facing = Vector3.new(0, 0, -1) })
		end
	end
	-- bệ trưng bày
	local showcaseKey = player:GetAttribute("Showcase") or ""
	if showcaseKey ~= owner.showcaseKey then
		owner.showcaseKey = showcaseKey
		clearRigs(owner.statues)
		local front = Config.PlotFront(plot)
		for k, item in parse(showcaseKey) do
			local spec = H.Pedestals[k]
			if spec then
				local rig = BotModels.Build(item.bot, item.level, item.variant)
				rig.model.Parent = folder
				local base = plot - front * (H.PlotSize / 2 - H.PedestalInset) + Vector3.new(spec.dx, spec.h + 0.3 + rig.size * 1.05, 0)
				table.insert(owner.statues, { rig = rig, pos = base, front = front, phase = k })
			end
		end
	end
	if owner.sign then
		local total = #Config.Bots
		owner.sign.Text = string.format("🏠 %s\n<font size='60' color='#9BFFD2'>📚 %d / %d bots</font>", player.DisplayName, player:GetAttribute("Collection") or 0, total)
	end
end

local function watch(player)
	for _, name in { "Plot", "Habitat", "Showcase", "Collection" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			refresh(player)
		end)
	end
	refresh(player)
end

local function update(dt)
	local t = os.clock()
	for player, owner in owners do
		if not player.Parent then
			clearRigs(owner.walkers)
			clearRigs(owner.statues)
			if owner.sign then
				owner.sign.Parent:Destroy()
			end
			owners[player] = nil
			continue
		end
		local plot = owner.plot and H.Plots[owner.plot]
		if not plot then
			continue
		end
		for _, w in owner.walkers do
			-- đi tới điểm đích, tới nơi thì đứng nghỉ một lúc rồi chọn điểm mới
			local offset = w.target - w.pos
			if offset.Magnitude < 0.5 then
				w.wait -= dt
				if w.wait <= 0 then
					w.target = randomSpot(plot)
					w.wait = random:NextNumber(1, 3.5)
				end
			else
				local step = math.min(offset.Magnitude, dt * 4)
				w.pos += offset.Unit * step
				w.facing = Vector3.new(offset.X, 0, offset.Z).Unit
			end
			local height = 1.2 + w.rig.size * 0.9 + math.abs(math.sin(t * 4 + w.phase)) * 0.5
			local at = w.pos + Vector3.new(0, height, 0)
			BotModels.Pose(w.rig, CFrame.lookAt(at, at + w.facing), t + w.phase)
		end
		for _, s in owner.statues do
			local angle = math.sin(t * 0.8 + s.phase) * 0.6
			local cf = CFrame.lookAt(s.pos, s.pos + s.front) * CFrame.Angles(0, angle, 0) + Vector3.new(0, math.sin(t * 1.6 + s.phase) * 0.15, 0)
			BotModels.Pose(s.rig, cf, t + s.phase)
		end
	end
end

function Habitat.Start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	RunService.RenderStepped:Connect(update)
	-- làm mới định kỳ (biển tên tải chậm, người chơi đổi tên hiển thị...)
	task.spawn(function()
		while true do
			task.wait(3)
			for _, player in Players:GetPlayers() do
				refresh(player)
			end
		end
	end)
end

return Habitat
