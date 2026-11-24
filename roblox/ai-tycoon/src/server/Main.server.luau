-- Điểm khởi động phía server: tạo remote, bật các service, nối sự kiện người chơi.
-- Server 1 người: người chơi thứ 2 vào sẽ được mời sang server khác.
-- Chữ người chơi thấy là tiếng Anh; chú thích code là tiếng Việt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CalendarService = require(script.Parent.CalendarService)
local CompanyService = require(script.Parent.CompanyService)
local DataService = require(script.Parent.DataService)
local EventService = require(script.Parent.EventService)
local FactoryService = require(script.Parent.FactoryService)
local GoalService = require(script.Parent.GoalService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local ModelService = require(script.Parent.ModelService)
local MonetizationService = require(script.Parent.MonetizationService)
local ProgressService = require(script.Parent.ProgressService)
local ResearchService = require(script.Parent.ResearchService)
local StaffService = require(script.Parent.StaffService)
local StockService = require(script.Parent.StockService)
local WorldService = require(script.Parent.WorldService)

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in { "State", "Action", "Notify", "Market", "Popup" } do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
end
remotes.Parent = ReplicatedStorage

DataService.Start()
WorldService.Start() -- dựng thành phố trước
CompanyService.Start(remotes)
CalendarService.Start()
-- thứ tự đăng ký day hook = thứ tự chạy mỗi ngày: lương → R&D → xưởng → model & doanh số → sự kiện → mục tiêu
StaffService.Start()
ResearchService.Start()
FactoryService.Start()
ModelService.Start()
EventService.Start()
GoalService.Start()
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
	StaffService.Prepare(profile)
	CompanyService.OnPlayerLoaded(player, profile)
	if CompanyService.IsActive(player) then
		FactoryService.Render(player)
		ModelService.OnPlayerLoaded(player)
		EventService.OnPlayerLoaded(player, profile)
		MonetizationService.AfterLoaded(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	if CompanyService.IsActive(player) then
		FactoryService.Clear()
	end
	CompanyService.OnPlayerRemoving(player)
	DataService.Release(player)
end)
