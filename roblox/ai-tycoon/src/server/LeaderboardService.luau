-- Bảng "Top tỷ phú công nghệ" ở quảng trường, xếp theo tổng $ đã kiếm (OrderedDataStore).
-- Ghi điểm và tải top mỗi Config.Leaderboard.UpdateInterval giây cho đỡ tốn quota DataStore.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Visuals = require(script.Parent.Visuals)
local WorldService = require(script.Parent.WorldService)

local LeaderboardService = {}

-- Chưa publish thì không lấy được DataStore: bảng chỉ hiện lời nhắc
local storeOk, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, "TopEarned_v1")
if not storeOk then
	store = nil
end
local nameCache = {}
local rows = {}

local function nameFor(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = if ok then name else "Người chơi"
	return nameCache[userId]
end

local function buildBoard()
	local board = Visuals.Part({
		Name = "Leaderboard",
		Size = Vector3.new(22, 14, 1),
		CFrame = WorldService.LeaderboardCFrame, -- ở Quảng trường Công Nghệ
		Color = Color3.fromRGB(20, 20, 35),
		Material = Enum.Material.SmoothPlastic,
	})
	Visuals.Part({
		Name = "Frame",
		Size = Vector3.new(23, 15, 0.6),
		CFrame = board.CFrame,
		Color = Visuals.Colors.gridAlt,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}).Parent = board
	Visuals.Light(board, Visuals.Colors.gridAlt, 25, 2)

	-- Mặt trước và mặt sau đều có chữ, đứng phía nào cũng đọc được
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.PixelsPerStud = 40
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 4)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.Parent = gui
		local title = Instance.new("TextLabel")
		title.LayoutOrder = 0
		title.Size = UDim2.new(1, 0, 0, 80)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.BuilderSansExtraBold
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(255, 215, 80)
		title.Text = "🏆 TOP TỶ PHÚ CÔNG NGHỆ"
		title.Parent = gui
		for i = 1, Config.Leaderboard.Size do
			local row = Instance.new("TextLabel")
			row.LayoutOrder = i
			row.Size = UDim2.new(0.92, 0, 0, 40)
			row.BackgroundTransparency = 1
			row.Font = Enum.Font.BuilderSansBold
			row.TextScaled = true
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.TextColor3 = if i <= 3 then Color3.fromRGB(255, 240, 180) else Color3.fromRGB(220, 220, 240)
			row.Text = ""
			row.Parent = gui
			rows[face] = rows[face] or {}
			rows[face][i] = row
		end
		gui.Parent = board
	end
	board.Parent = workspace
end

local MEDALS = { "🥇", "🥈", "🥉" }

local function refresh()
	if not store or DataService.Offline then
		for _, faceRows in rows do
			faceRows[1].Text = "⚠️ Publish game + bật API Services để xem bảng xếp hạng"
		end
		return
	end
	for player, profile in DataService.Profiles do
		pcall(store.SetAsync, store, tostring(player.UserId), math.floor(math.min(profile.totalEarned, 2 ^ 53)))
	end

	local ok, pages = pcall(store.GetSortedAsync, store, false, Config.Leaderboard.Size)
	if not ok then
		warn("[Leaderboard] Không tải được top:", pages)
		return
	end
	local entries = pages:GetCurrentPage()
	for i = 1, Config.Leaderboard.Size do
		local entry = entries[i]
		local text = ""
		if entry then
			local rank = MEDALS[i] or ("#" .. i)
			text = string.format("%s  %s  —  %s", rank, nameFor(tonumber(entry.key)), Config.Money(entry.value))
		end
		for _, faceRows in rows do
			faceRows[i].Text = text
		end
	end
end

function LeaderboardService.Start()
	buildBoard()
	task.spawn(function()
		task.wait(15) -- đợi người chơi đầu tiên tải data xong
		while true do
			refresh()
			task.wait(Config.Leaderboard.UpdateInterval)
		end
	end)
end

return LeaderboardService
