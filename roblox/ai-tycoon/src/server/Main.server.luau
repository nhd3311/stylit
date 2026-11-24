-- Điểm khởi động phía server: tạo remote, bật các service, nối sự kiện người chơi.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local HeistService = require(script.Parent.HeistService)
local LabService = require(script.Parent.LabService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local MonetizationService = require(script.Parent.MonetizationService)
local ProgressService = require(script.Parent.ProgressService)

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in { "State", "Action", "Notify" } do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
end
remotes.Parent = ReplicatedStorage

DataService.Start()
LabService.Start(remotes) -- dựng lab trước, các service sau gắn thêm vào lab
HeistService.Start()
ProgressService.Start()
LeaderboardService.Start()
MonetizationService.Start(remotes)

local function onPlayerAdded(player)
	local profile = DataService.Load(player)
	if not profile then
		return
	end
	MonetizationService.LoadPasses(player)
	-- LoadPasses có gọi web nên người chơi có thể đã thoát trong lúc chờ
	if not player.Parent or DataService.Profiles[player] ~= profile then
		return
	end
	LabService.OnPlayerLoaded(player, profile)
	MonetizationService.AfterLoaded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	LabService.OnPlayerRemoving(player)
	DataService.Release(player)
end)
