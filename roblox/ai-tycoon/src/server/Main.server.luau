-- Điểm khởi động phía server: tạo remote, bật các service, nối sự kiện người chơi.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CompanyService = require(script.Parent.CompanyService)
local DataService = require(script.Parent.DataService)
local HeistService = require(script.Parent.HeistService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local MonetizationService = require(script.Parent.MonetizationService)
local ProductService = require(script.Parent.ProductService)
local ProgressService = require(script.Parent.ProgressService)
local ResearchService = require(script.Parent.ResearchService)
local StockService = require(script.Parent.StockService)
local WorldService = require(script.Parent.WorldService)

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in { "State", "Action", "Notify", "Market" } do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
end
remotes.Parent = ReplicatedStorage

DataService.Start()
WorldService.Start() -- dựng thành phố trước
CompanyService.Start(remotes) -- rồi tới các lô đất, các service sau gắn thêm vào lô
HeistService.Start()
ResearchService.Start()
ProductService.Start()
StockService.Start(remotes)
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
	CompanyService.OnPlayerLoaded(player, profile)
	MonetizationService.AfterLoaded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	CompanyService.OnPlayerRemoving(player)
	DataService.Release(player)
end)
