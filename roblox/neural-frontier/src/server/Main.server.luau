-- Điểm khởi động phía server: tạo remote, bật các service, nối sự kiện người chơi.
-- Chữ người chơi thấy là tiếng Anh; chú thích code là tiếng Việt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchievementService = require(script.Parent.AchievementService)
local CodesService = require(script.Parent.CodesService)
local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)
local EventService = require(script.Parent.EventService)
local FriendsService = require(script.Parent.FriendsService)
local GameAnalytics = require(script.Parent.AnalyticsService)
local HabitatService = require(script.Parent.HabitatService)
local HeistService = require(script.Parent.HeistService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local MonetizationService = require(script.Parent.MonetizationService)
local PlayerService = require(script.Parent.PlayerService)
local SettingsService = require(script.Parent.SettingsService)
local WorldService = require(script.Parent.WorldService)

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in { "State", "Action", "Notify", "Fx", "Hatch" } do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
end
remotes.Parent = ReplicatedStorage

DataService.Start()
WorldService.Start()
LeaderboardService.Start()
PlayerService.Start(remotes)
EnemyService.Start()
HeistService.Start()
EventService.Start()
HabitatService.Start()
FriendsService.Start()
CodesService.Start()
AchievementService.Start()
SettingsService.Start()
GameAnalytics.Start(PlayerService) -- nghe event bus: hướng dẫn, kiếm/tiêu credits, lên level, mở capsule
MonetizationService.Start(remotes)

local function onPlayerAdded(player)
	local profile = DataService.Load(player)
	if not profile then
		return
	end
	MonetizationService.LoadPasses(player)
	if not player.Parent or DataService.Profiles[player] ~= profile then
		return
	end
	PlayerService.OnPlayerLoaded(player, profile)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	DataService.Release(player)
end)
