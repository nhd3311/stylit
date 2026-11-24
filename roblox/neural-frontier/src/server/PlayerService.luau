-- Người chơi: level/XP, máu, ba lô data, thu thập (bot tự hút + bấm tay), upload đổi Credits,
-- mua/nâng bot, nâng ba lô, kỹ năng AI Core, nhiệm vụ của Unit-0.
-- Server là "trọng tài": client chỉ gửi yêu cầu, server kiểm tra rồi mới làm.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)

local PlayerService = {}

local remotes
local sessions = {} -- [player] = { lastAction, lastHarvest, lastUpload, cooldowns, overclockUntil, shieldUntil }
local actions = {}

-- EnemyService gắn vào đây để tránh require vòng
PlayerService.DamageArea = nil -- (player, position, radius, amount)

function PlayerService.Notify(player, message, action)
	remotes.Notify:FireClient(player, message, action)
end
local notify = PlayerService.Notify

function PlayerService.Fx(...)
	remotes.Fx:FireAllClients(...)
end

local function boostOn(profile, name)
	return (profile.boosts[name] or 0) > os.time()
end

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function humanoidOf(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- ================= Chỉ số =================

local function slots(player)
	return Config.BotSlots + (if player:GetAttribute("BotSlots") then Config.ExtraSlotsPass else 0)
end

local function botPower(entry)
	local bot = Config.BotById[entry.type]
	return Config.BotStat(bot, entry.level, "gather") + Config.BotStat(bot, entry.level, "attack")
end

-- Danh sách chỉ số bot đang mang ra trận (mạnh nhất trước), tối đa = số slot
local function equipped(player, profile)
	local order = {}
	for i, entry in profile.bots do
		if Config.BotById[entry.type] then
			table.insert(order, i)
		end
	end
	table.sort(order, function(a, b)
		return botPower(profile.bots[a]) > botPower(profile.bots[b])
	end)
	local result = {}
	for i = 1, math.min(#order, slots(player)) do
		result[i] = order[i]
	end
	return result
end

function PlayerService.Capacity(player, profile)
	local cap = Config.Backpacks[profile.backpack].capacity
	return if player:GetAttribute("BigBackpack") then cap * 2 else cap
end

local function overclocked(player)
	local session = sessions[player]
	return session and session.overclockUntil > os.clock()
end

function PlayerService.GatherPerSecond(player, profile)
	local total = 0
	for _, i in equipped(player, profile) do
		local entry = profile.bots[i]
		total += Config.BotStat(Config.BotById[entry.type], entry.level, "gather")
	end
	if overclocked(player) then
		total *= 2
	end
	if boostOn(profile, "Gather") then
		total *= Config.Multipliers.GatherBoost
	end
	return total
end

-- Sát thương/giây đội bot gây lên 1 quái gần nhất
function PlayerService.BotAttack(player)
	local profile = DataService.Profiles[player]
	if not profile then
		return 0
	end
	local total = 0
	for _, i in equipped(player, profile) do
		local entry = profile.bots[i]
		total += Config.BotStat(Config.BotById[entry.type], entry.level, "attack")
	end
	return total * (if overclocked(player) then 2 else 1) * (1 + 0.05 * (profile.level - 1))
end

local function creditMult(player, profile)
	local mult = 1
	if player:GetAttribute("VIP") then
		mult *= Config.Multipliers.Vip
	end
	if boostOn(profile, "Credits") then
		mult *= Config.Multipliers.CreditBoost
	end
	return mult
end

-- ================= Đồng bộ =================

-- Thông tin bot cho mọi client vẽ (mỗi người chơi thấy bot của nhau): "Scout:1,Miner:2"
local function publishBots(player, profile)
	local parts = {}
	for _, i in equipped(player, profile) do
		local entry = profile.bots[i]
		table.insert(parts, entry.type .. ":" .. entry.level)
	end
	player:SetAttribute("Bots", table.concat(parts, ","))
end

local function questInfo(player, profile)
	local quest = Config.Quests[profile.quest]
	if not quest then
		return nil
	end
	local s = profile.stats
	local value = ({
		uploaded = s.uploaded,
		kills = s.kills,
		bots = #profile.bots,
		level = profile.level,
		backpack = profile.backpack,
		boss = if s.bosses[quest.target] then 1 else 0,
	})[quest.check]
	local target = if quest.check == "boss" then 1 else quest.target
	return { index = profile.quest, total = #Config.Quests, text = quest.text, reward = quest.reward, value = value, target = target }
end

function PlayerService.PushState(player)
	local profile = DataService.Profiles[player]
	if not profile or not sessions[player] then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Level.Value = profile.level
		stats.Credits.Value = math.floor(profile.credits)
	end
	local root = rootOf(player)
	local zone = root and Config.ZoneAt(root.Position)
	remotes.State:FireClient(player, {
		credits = profile.credits,
		level = profile.level,
		xp = profile.xp,
		xpNext = Config.XpToNext(profile.level),
		data = profile.data,
		capacity = PlayerService.Capacity(player, profile),
		backpack = profile.backpack,
		bots = profile.bots,
		equipped = equipped(player, profile),
		slots = slots(player),
		gather = PlayerService.GatherPerSecond(player, profile),
		attack = PlayerService.BotAttack(player),
		power = Config.Power(profile.level),
		zone = zone and zone.id,
		quest = questInfo(player, profile),
		boosts = profile.boosts,
		stats = profile.stats,
		vip = player:GetAttribute("VIP") == true,
	})
end

-- ================= Tiến trình =================

local function checkQuest(player, profile)
	local info = questInfo(player, profile)
	while info and info.value >= info.target do
		profile.credits += info.reward
		profile.totalEarned += info.reward
		notify(player, string.format("✅ Quest complete: %s! +%s credits", info.text, Config.Short(info.reward)), "Reward")
		profile.quest += 1
		info = questInfo(player, profile)
	end
end

local function applyCharacterStats(player, profile)
	local humanoid = humanoidOf(player)
	if humanoid then
		local ratio = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
		humanoid.MaxHealth = Config.MaxHealth(profile.level)
		humanoid.Health = humanoid.MaxHealth * math.clamp(ratio, 0, 1)
		humanoid.WalkSpeed = if player:GetAttribute("TurboBoots") then Config.Player.TurboSpeed else Config.Player.WalkSpeed
	end
end

function PlayerService.AddXp(player, amount)
	local profile = DataService.Profiles[player]
	if not profile then
		return
	end
	profile.xp += amount
	local leveled = false
	while profile.level < Config.Player.MaxLevel and profile.xp >= Config.XpToNext(profile.level) do
		profile.xp -= Config.XpToNext(profile.level)
		profile.level += 1
		leveled = true
	end
	if leveled then
		applyCharacterStats(player, profile)
		local humanoid = humanoidOf(player)
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
		local unlocked = {}
		for _, core in Config.Cores do
			if core.level == profile.level then
				table.insert(unlocked, core.emoji .. " " .. core.name)
			end
		end
		for _, zone in Config.Zones do
			if zone.level == profile.level then
				table.insert(unlocked, zone.emoji .. " " .. zone.name)
			end
		end
		local extra = if #unlocked > 0 then " Unlocked: " .. table.concat(unlocked, ", ") else ""
		notify(player, string.format("⬆️ Level %d!%s", profile.level, extra), "LevelUp")
		local root = rootOf(player)
		if root then
			PlayerService.Fx("LevelUp", root.Position)
		end
	end
	checkQuest(player, profile)
end

function PlayerService.AddCredits(player, amount)
	local profile = DataService.Profiles[player]
	if profile and amount > 0 then
		profile.credits += amount
		profile.totalEarned += amount
	end
end

-- Thưởng khi hạ quái (EnemyService gọi)
function PlayerService.OnKill(player, def, zone, isBoss)
	local profile = DataService.Profiles[player]
	if not profile then
		return
	end
	PlayerService.AddCredits(player, def.credits * creditMult(player, profile))
	profile.stats.kills += 1
	if isBoss then
		profile.stats.bosses[zone.id] = true
		notify(player, string.format("🏆 %s defeated! +%s credits", def.name, Config.Short(def.credits * creditMult(player, profile))), "Reward")
	end
	PlayerService.AddXp(player, def.xp)
end

-- Quái đánh người chơi (EnemyService gọi). Shield giảm sát thương.
function PlayerService.Damage(player, amount)
	local session = sessions[player]
	local humanoid = humanoidOf(player)
	if not session or not humanoid or humanoid.Health <= 0 then
		return
	end
	if session.shieldUntil > os.clock() then
		amount *= 1 - Config.CoreById.Shield.reduction
	end
	humanoid:TakeDamage(amount)
end

local function addData(player, profile, amount)
	local cap = PlayerService.Capacity(player, profile)
	local before = profile.data
	profile.data = math.min(cap, profile.data + amount)
	return profile.data - before
end

local function upload(player, profile, quiet)
	if profile.data < 1 then
		if not quiet then
			notify(player, "Your backpack is empty. Go gather data in a zone! 💾")
		end
		return
	end
	local amount = math.floor(profile.data)
	profile.data = 0
	local credits = amount * creditMult(player, profile)
	PlayerService.AddCredits(player, credits)
	profile.stats.uploaded += amount
	notify(player, string.format("📡 Uploaded %s data → +%s credits", Config.Short(amount), Config.Short(credits)), "Reward")
	PlayerService.AddXp(player, math.ceil(amount * 0.4))
	PlayerService.PushState(player)
end

-- ================= Hành động =================

function actions.Harvest(player, profile, session)
	local t = os.clock()
	if t - session.lastHarvest < Config.Player.HarvestCooldown then
		return
	end
	session.lastHarvest = t
	local root = rootOf(player)
	if not root then
		return
	end
	local node, zone = WorldService.NearestNode(root.Position, Config.Player.HarvestRange)
	if not node or profile.level < zone.level then
		return
	end
	if profile.data >= PlayerService.Capacity(player, profile) then
		notify(player, "🎒 Backpack full! Upload at the Hub")
		return
	end
	WorldService.HarvestNode(node)
	local gained = addData(player, profile, zone.nodeValue * (1 + 0.05 * (profile.level - 1)))
	PlayerService.Fx("Harvest", node.Position, zone.crystal, math.floor(gained))
end

function actions.BuyBot(player, profile, session, botId)
	local bot = type(botId) == "string" and Config.BotById[botId]
	if not bot then
		return
	end
	if #profile.bots >= Config.MaxBots then
		notify(player, "Your bot garage is full 🤖")
		return
	end
	if profile.credits < bot.price then
		notify(player, string.format("You need %s credits for a %s", Config.Short(bot.price), bot.name))
		return
	end
	profile.credits -= bot.price
	table.insert(profile.bots, { type = bot.id, level = 1 })
	notify(player, string.format("🤖 %s joined your squad!", bot.name), "Reward")
	publishBots(player, profile)
	checkQuest(player, profile)
	PlayerService.PushState(player)
end

function actions.UpgradeBot(player, profile, session, index)
	local entry = type(index) == "number" and profile.bots[index]
	local bot = entry and Config.BotById[entry.type]
	if not bot then
		return
	end
	if entry.level >= Config.BotUpgrade.MaxLevel then
		notify(player, bot.name .. " is max level 🔥")
		return
	end
	local price = Config.BotUpgradePrice(bot, entry.level)
	if profile.credits < price then
		notify(player, string.format("You need %s credits", Config.Short(price)))
		return
	end
	profile.credits -= price
	entry.level += 1
	notify(player, string.format("⬆️ %s is now level %d", bot.name, entry.level), "Reward")
	publishBots(player, profile)
	PlayerService.PushState(player)
end

function actions.RecycleBot(player, profile, session, index)
	local entry = type(index) == "number" and profile.bots[index]
	local bot = entry and Config.BotById[entry.type]
	if not bot or #profile.bots <= 1 then
		return
	end
	table.remove(profile.bots, index)
	local refund = math.floor(bot.price * 0.3)
	profile.credits += refund
	notify(player, string.format("♻️ Recycled %s for %s credits", bot.name, Config.Short(refund)))
	publishBots(player, profile)
	PlayerService.PushState(player)
end

function actions.BuyBackpack(player, profile)
	local nextTier = Config.Backpacks[profile.backpack + 1]
	if not nextTier then
		notify(player, "You already have the best backpack 🎒")
		return
	end
	if profile.credits < nextTier.price then
		notify(player, string.format("You need %s credits for the %s", Config.Short(nextTier.price), nextTier.name))
		return
	end
	profile.credits -= nextTier.price
	profile.backpack += 1
	notify(player, string.format("🎒 Upgraded to %s (%s capacity)", nextTier.name, Config.Short(PlayerService.Capacity(player, profile))), "Reward")
	checkQuest(player, profile)
	PlayerService.PushState(player)
end

function actions.UseCore(player, profile, session, coreId)
	local core = type(coreId) == "string" and Config.CoreById[coreId]
	if not core or profile.level < core.level then
		return
	end
	local t = os.clock()
	if (session.cooldowns[core.id] or 0) > t then
		return
	end
	session.cooldowns[core.id] = t + core.cooldown - 0.1 -- trừ chút độ trễ mạng
	local root = rootOf(player)
	local humanoid = humanoidOf(player)
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	if core.id == "Pulse" then
		PlayerService.Fx("Pulse", root.Position, core.radius)
		if PlayerService.DamageArea then
			PlayerService.DamageArea(player, root.Position, core.radius, Config.Power(profile.level))
		end
	elseif core.id == "Overclock" then
		session.overclockUntil = t + core.duration
		PlayerService.Fx("Aura", player, Color3.fromRGB(255, 220, 60), core.duration)
	elseif core.id == "Shield" then
		session.shieldUntil = t + core.duration
		PlayerService.Fx("Aura", player, Color3.fromRGB(80, 200, 255), core.duration)
	end
	-- Dash do client tự đẩy nhân vật (client sở hữu vật lý nhân vật); server chỉ giữ cooldown
end

local function onAction(player, name, ...)
	local session = sessions[player]
	local profile = DataService.Profiles[player]
	local handler = type(name) == "string" and actions[name]
	if not session or not profile or not handler then
		return
	end
	if name ~= "Harvest" and name ~= "UseCore" then
		local t = os.clock()
		if t - session.lastAction < 0.15 then
			return
		end
		session.lastAction = t
	end
	handler(player, profile, session, ...)
end

-- ================= Vòng lặp =================

local function tick()
	for player, session in sessions do
		local profile = DataService.Profiles[player]
		local root = rootOf(player)
		local humanoid = humanoidOf(player)
		if not profile or not root or not humanoid or humanoid.Health <= 0 then
			continue
		end
		local zone = Config.ZoneAt(root.Position)
		if zone and profile.level < zone.level then
			-- chưa đủ level mà lọt vào vùng: đưa về Hub
			player.Character:PivotTo(WorldService.HubSpawn())
			notify(player, string.format("🔒 %s needs level %d", zone.name, zone.level))
		elseif zone then
			local gained = addData(player, profile, PlayerService.GatherPerSecond(player, profile) * zone.dataMult)
			if gained > 0 then
				PlayerService.Fx("Gather", player, zone.crystal)
			end
			if profile.data >= PlayerService.Capacity(player, profile) and player:GetAttribute("AutoUpload") then
				upload(player, profile, true)
			end
		end
		PlayerService.PushState(player)
	end
end

-- ================= Vòng đời =================

function PlayerService.OnPlayerLoaded(player, profile)
	sessions[player] = { lastAction = 0, lastHarvest = 0, lastUpload = 0, cooldowns = {}, overclockUntil = 0, shieldUntil = 0 }
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = leaderstats
	local credits = Instance.new("NumberValue")
	credits.Name = "Credits"
	credits.Parent = leaderstats
	leaderstats.Parent = player

	local function onCharacter(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then
			return
		end
		task.wait()
		character:PivotTo(WorldService.HubSpawn())
		humanoid.Health = humanoid.MaxHealth
		applyCharacterStats(player, profile)
		humanoid.Health = humanoid.MaxHealth
		humanoid.Died:Connect(function()
			if profile.data > 0 then
				notify(player, string.format("💀 You were knocked out and lost %s data!", Config.Short(profile.data)))
				profile.data = 0
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	publishBots(player, profile)
	PlayerService.PushState(player)
end

function PlayerService.OnPlayerRemoving(player)
	sessions[player] = nil
end

-- gọi khi pass thay đổi (VIP, BotSlots, BigBackpack, TurboBoots...)
function PlayerService.Refresh(player)
	local profile = DataService.Profiles[player]
	if profile then
		applyCharacterStats(player, profile)
		publishBots(player, profile)
		PlayerService.PushState(player)
	end
end

function PlayerService.Start(remoteFolder)
	remotes = remoteFolder
	remotes.Action.OnServerEvent:Connect(onAction)
	WorldService.OnUpload = function(player, fromPad)
		local session = sessions[player]
		local profile = DataService.Profiles[player]
		if not session or not profile then
			return
		end
		-- dẫm lên tấm upload bắn Touched liên tục, giãn ra cho đỡ spam
		if os.clock() - session.lastUpload < 1 then
			return
		end
		session.lastUpload = os.clock()
		upload(player, profile, fromPad)
	end
	WorldService.OnOpen = function(player, panel)
		notify(player, "", "Open:" .. panel)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			tick()
		end
	end)
	Players.PlayerRemoving:Connect(PlayerService.OnPlayerRemoving)
end

return PlayerService
