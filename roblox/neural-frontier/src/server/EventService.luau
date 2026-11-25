-- Sự kiện Glitch Floor (minigame nhiều người chơi):
--   Chờ (Idle) -> Mời tham gia (Lobby, bấm JOIN ở đâu cũng được hoặc bước lên cổng ở Hub)
--   -> dịch chuyển người tham gia lên sàn đấu bay -> đếm 3-2-1
--   -> từng đợt ô sàn nhấp nháy đỏ rồi rơi, nhịp nhanh dần, có đợt rơi cả hàng/cột/vòng
--   -> rơi khỏi sàn là bị loại (đưa về Hub) -> còn 1 người (hoặc hết giờ) thì kết thúc
--   -> người thắng: credits + 1 capsule miễn phí, người chơi khác: credits tham gia.
-- Trạng thái gửi cho client qua attribute của workspace:
--   EventPhase ("Idle" | "Lobby" | "Live"), EventEndsAt (giờ server), EventPlayers (số người)
-- và attribute "EventJoined" trên từng người chơi.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local WorldService = require(script.Parent.WorldService)

local EventService = {}

local TILE_COLOR = Color3.fromRGB(30, 34, 56)
local INLAY_COLOR = Color3.fromRGB(0, 220, 255)
local WARN_TILE = Color3.fromRGB(110, 20, 40)
local WARN_INLAY = Color3.fromRGB(255, 40, 70)

local arena
local phase = "Idle"
local joined = {} -- [player] = true: đăng ký lượt tới
local participants = {} -- [player] = true: đang trên sàn
local eliminated = {} -- người bị loại trong lượt hiện tại (theo thứ tự)
local rng = Random.new()

local function now()
	return workspace:GetServerTimeNow()
end

local function count(map)
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

local function setPhase(name, endsAt)
	phase = name
	workspace:SetAttribute("EventPhase", name)
	workspace:SetAttribute("EventEndsAt", endsAt or 0)
	workspace:SetAttribute("EventPlayers", if name == "Live" then count(participants) else count(joined))
end

local function rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

-- ================= Sàn đấu =================

local function resetTiles()
	for _, tile in arena.tiles do
		tile.alive = true
		tile.base.Transparency = 0
		tile.base.CanCollide = true
		tile.base.Color = TILE_COLOR
		tile.inlay.Transparency = 0.25
		tile.inlay.Color = INLAY_COLOR
	end
end

local function markTile(tile)
	tile.base.Color = WARN_TILE
	tile.inlay.Color = WARN_INLAY
	tile.inlay.Transparency = 0
end

local function dropTile(tile)
	tile.alive = false
	tile.base.Transparency = 1
	tile.base.CanCollide = false
	tile.inlay.Transparency = 1
end

-- chọn ô sẽ rơi: đa số ngẫu nhiên, thỉnh thoảng cả 1 hàng / 1 cột / vòng ngoài cùng còn lại
local function pickTiles(amount)
	local alive = {}
	for _, tile in arena.tiles do
		if tile.alive then
			table.insert(alive, tile)
		end
	end
	if #alive <= 2 then
		return {}
	end
	local picks = {}
	local r = rng:NextNumber()
	if r < 0.22 then
		local byRow = rng:NextNumber() < 0.5
		local line = rng:NextInteger(1, Config.Event.Grid)
		for _, tile in alive do
			if (if byRow then tile.ix else tile.iz) == line then
				table.insert(picks, tile)
			end
		end
	elseif r < 0.32 then
		-- vòng ngoài cùng còn lại
		local outer = 0
		for _, tile in alive do
			local n = Config.Event.Grid
			outer = math.max(outer, math.max(math.abs(tile.ix - (n + 1) / 2), math.abs(tile.iz - (n + 1) / 2)))
		end
		for _, tile in alive do
			local n = Config.Event.Grid
			if math.max(math.abs(tile.ix - (n + 1) / 2), math.abs(tile.iz - (n + 1) / 2)) == outer then
				table.insert(picks, tile)
			end
		end
	end
	if #picks == 0 or #picks >= #alive - 1 then
		picks = {}
		for _ = 1, math.min(amount, #alive - 2) do
			table.insert(picks, table.remove(alive, rng:NextInteger(1, #alive)))
		end
	end
	return picks
end

-- ================= Người chơi =================

local function join(player)
	if phase == "Live" then
		PlayerService.Notify(player, "🟥 A round is running. You'll be in the next one!")
	end
	if joined[player] then
		return
	end
	joined[player] = true
	player:SetAttribute("EventJoined", true)
	if phase ~= "Live" then
		workspace:SetAttribute("EventPlayers", count(joined))
	end
	PlayerService.Notify(player, if phase == "Lobby" then "✅ You're in! The round starts soon." else "✅ Queued for the next Glitch Floor round!", "EventJoined")
end

local function eliminate(player)
	participants[player] = nil
	table.insert(eliminated, player)
	workspace:SetAttribute("EventPlayers", count(participants))
	if player.Parent then
		if rootOf(player) then
			player.Character:PivotTo(WorldService.HubSpawn())
		end
		PlayerService.Notify(player, "💥 You fell! Better luck next round.", "EventOut")
	end
end

local function checkEliminations()
	for player in participants do
		local root = rootOf(player)
		if not player.Parent or not root or root.Position.Y < arena.top - 8 then
			eliminate(player)
		end
	end
end

-- chờ `seconds` giây nhưng vẫn kiểm tra người rơi liên tục
local function watch(seconds)
	local t0 = os.clock()
	while os.clock() - t0 < seconds do
		task.wait(0.1)
		checkEliminations()
	end
end

local function reward(player, won)
	local profile = DataService.Profiles[player]
	if not profile or not player.Parent then
		return
	end
	local e = Config.Event
	local credits = Config.ScaledCredits(if won then e.WinCredits else e.PlayCredits, profile.level)
	PlayerService.AddCredits(player, credits)
	if won then
		profile.stats.eventWins = (profile.stats.eventWins or 0) + 1
		local capsule = PlayerService.BestCapsule(profile)
		PlayerService.Notify(player, string.format("🏆 YOU WIN! +%s credits and a free %s", Config.Short(credits), capsule.name), "EventWin")
		PlayerService.Hatch(player, profile, capsule, 1)
	else
		PlayerService.Notify(player, string.format("🎮 +%s credits for playing Glitch Floor", Config.Short(credits)), "Reward")
		PlayerService.PushState(player)
	end
end

-- ================= Một lượt =================

local function runRound()
	local e = Config.Event
	setPhase("Lobby", now() + e.LobbyTime)
	for _, player in Players:GetPlayers() do
		PlayerService.Notify(player, string.format("🟥 GLITCH FLOOR opens! Tap JOIN within %ds", e.LobbyTime), "EventOpen")
	end
	task.wait(e.LobbyTime)

	local list = {}
	for player in joined do
		player:SetAttribute("EventJoined", nil)
		if player.Parent and rootOf(player) then
			table.insert(list, player)
		end
	end
	joined = {}
	if #list == 0 then
		setPhase("Idle", now() + e.Interval)
		return
	end

	resetTiles()
	participants, eliminated = {}, {}
	for _, player in list do
		participants[player] = true
		local tile = arena.tiles[rng:NextInteger(1, #arena.tiles)]
		player.Character:PivotTo(CFrame.new(tile.base.Position + Vector3.new(rng:NextNumber(-1, 1), 5, rng:NextNumber(-1, 1))))
		PlayerService.Notify(player, "", "EventCountdown")
	end
	local startCount = #list
	setPhase("Live", now() + 3 + e.MaxTime)
	watch(3) -- client hiện 3-2-1

	local start = os.clock()
	local interval, wave = 2.2, 3
	while true do
		checkEliminations()
		local remaining = count(participants)
		if remaining == 0 or (startCount > 1 and remaining <= 1) or os.clock() - start >= e.MaxTime then
			break
		end
		local picks = pickTiles(math.floor(wave))
		for _, tile in picks do
			markTile(tile)
		end
		local warnTime = math.max(0.45, 1 - (os.clock() - start) / 120)
		watch(warnTime)
		for _, tile in picks do
			dropTile(tile)
		end
		watch(math.max(0.3, interval - warnTime))
		interval = math.max(0.9, interval * 0.95)
		wave = math.min(12, wave + 0.45)
	end

	-- kết thúc: ai còn trên sàn là người thắng
	local winners = {}
	for player in participants do
		table.insert(winners, player)
	end
	for _, player in winners do
		reward(player, true)
	end
	for _, player in eliminated do
		reward(player, false)
	end
	local names = {}
	for _, player in winners do
		table.insert(names, player.DisplayName)
	end
	local summary = if #names > 0 then "🏆 Glitch Floor winner: " .. table.concat(names, ", ") .. "!" else "💥 Glitch Floor: nobody survived!"
	for _, player in Players:GetPlayers() do
		if not table.find(winners, player) then
			PlayerService.Notify(player, summary, "Announce")
		end
	end
	setPhase("Idle", now() + e.Interval)
	-- cho người thắng ăn mừng vài giây rồi đưa về Hub, dựng lại sàn
	task.wait(4)
	for _, player in winners do
		if player.Parent and rootOf(player) then
			player.Character:PivotTo(WorldService.HubSpawn())
		end
	end
	participants, eliminated = {}, {}
	resetTiles()
end

function EventService.Start()
	arena = WorldService.Arena
	resetTiles()
	WorldService.OnEventJoin = join
	PlayerService.AddAction("JoinEvent", function(player)
		join(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		joined[player] = nil
		participants[player] = nil
	end)
	local firstDelay = 60
	setPhase("Idle", now() + firstDelay)
	task.spawn(function()
		task.wait(firstDelay)
		while true do
			local ok, err = pcall(runRound)
			if not ok then
				warn("[EventService] Lỗi trong lượt Glitch Floor:", err)
				participants, eliminated, joined = {}, {}, {}
				resetTiles()
				setPhase("Idle", now() + Config.Event.Interval)
			end
			task.wait(Config.Event.Interval)
		end
	end)
end

return EventService
