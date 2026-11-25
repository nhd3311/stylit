-- Người chơi: level/XP, máu, ba lô data, thu thập (bot tự hút + bấm tay), upload đổi Credits,
-- mở Capsule ra bot (có tỉ lệ + luck + biến thể Shiny/Holo), Fuse, khoá bot, Bot Database,
-- nâng/recycle bot, nâng ba lô, kỹ năng AI Core, nhiệm vụ của Unit-0, quà đăng nhập mỗi ngày.
-- Server là "trọng tài": client chỉ gửi yêu cầu, server kiểm tra rồi mới làm.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)

local PlayerService = {}

local remotes
local sessions = {} -- [player] = { lastAction, lastHarvest, lastUpload, lastHatch, cooldowns, overclockUntil, shieldUntil }
local rng = Random.new()
local actions = {}
local dailyInfo -- định nghĩa ở mục Quà đăng nhập

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
	return Config.BotStat(bot, entry.level, "gather", entry.variant) + Config.BotStat(bot, entry.level, "attack", entry.variant)
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

-- % gather cộng thêm vĩnh viễn từ các bộ Database đã hoàn thành
local function gatherBonus(profile)
	local bonus = 0
	for id in profile.claimedSets do
		local capsule = Config.CapsuleById[id]
		if capsule then
			bonus += capsule.reward.gather
		end
	end
	return bonus
end

function PlayerService.Luck(player, profile)
	local luck = 1
	if player:GetAttribute("LuckyScanner") then
		luck *= Config.Multipliers.LuckyPass
	end
	if boostOn(profile, "Luck") then
		luck *= Config.Multipliers.LuckBoost
	end
	return luck
end

function PlayerService.GatherPerSecond(player, profile)
	local total = 0
	for _, i in equipped(player, profile) do
		local entry = profile.bots[i]
		total += Config.BotStat(Config.BotById[entry.type], entry.level, "gather", entry.variant)
	end
	if overclocked(player) then
		total *= 2
	end
	if boostOn(profile, "Gather") then
		total *= Config.Multipliers.GatherBoost
	end
	return total * (1 + gatherBonus(profile))
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
		total += Config.BotStat(Config.BotById[entry.type], entry.level, "attack", entry.variant)
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

-- Thông tin bot cho mọi client vẽ (mỗi người chơi thấy bot của nhau): "Scout:1:,Miner:2:Shiny"
local function publishBots(player, profile)
	local parts = {}
	for _, i in equipped(player, profile) do
		local entry = profile.bots[i]
		table.insert(parts, entry.type .. ":" .. entry.level .. ":" .. (entry.variant or ""))
	end
	player:SetAttribute("Bots", table.concat(parts, ","))
end

local function countKeys(map)
	local n = 0
	for _ in map do
		n += 1
	end
	return n
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
		discovered = countKeys(profile.discovered),
		eventWins = s.eventWins or 0,
	})[quest.check]
	local target = if quest.check == "boss" then 1 else quest.target
	return { index = profile.quest, total = #Config.Quests, text = quest.text, reward = quest.reward, value = value, target = target }
end

-- ================= Quà đăng nhập =================

local function today()
	return os.time() // 86400
end

-- ngày nhận tiếp theo (1..7) và có nhận được chưa
function dailyInfo(profile)
	local daily = profile.daily
	local ready = daily.last < today()
	local streak = if daily.last == today() - 1 or daily.last == today() then daily.streak else 0
	local nextStreak = if ready then streak + 1 else streak
	return { ready = ready, streak = streak, day = ((math.max(1, nextStreak) - 1) % #Config.DailyRewards) + 1 }
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
		stats.Wins.Value = profile.stats.eventWins or 0
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
		luck = PlayerService.Luck(player, profile),
		discovered = profile.discovered,
		claimedSets = profile.claimedSets,
		gatherBonus = gatherBonus(profile),
		restricted = player:GetAttribute("PaidRandomRestricted") == true,
		variants = profile.variants,
		daily = dailyInfo(profile),
		starterPack = profile.starterPack == true,
		eventWins = profile.stats.eventWins or 0,
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

-- Quay 1 bot theo tỉ lệ (đã tính luck)
local function roll(capsule, luck)
	local odds = Config.CapsuleOdds(capsule, luck)
	local r = rng:NextNumber()
	for _, item in odds do
		r -= item.chance
		if r <= 0 then
			return item.bot
		end
	end
	return odds[#odds].bot
end

-- Mở `count` capsule cho người chơi (Credits đã trừ / Robux đã trả trước khi gọi).
-- Bot hiếm (Legendary+) được báo cho cả server.
-- ghi nhận đã gặp biến thể (Bot Database hiện huy hiệu ✨/🌈)
local function markVariant(profile, botId, variant)
	if variant then
		profile.variants[botId] = profile.variants[botId] or {}
		profile.variants[botId][variant] = true
	end
end

local function rollVariant(player)
	local hunter = player:GetAttribute("ShinyHunter") == true
	local r = rng:NextNumber()
	local holo = Config.VariantChance("Holo", hunter)
	if r < holo then
		return "Holo"
	elseif r < holo + Config.VariantChance("Shiny", hunter) then
		return "Shiny"
	end
	return nil
end

local function announce(player, text)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			notify(other, text, "Announce")
		end
	end
end

-- Mở `count` capsule cho người chơi (Credits đã trừ / Robux đã trả / quà miễn phí trước khi gọi).
-- Mỗi bot có thể ra biến thể Shiny/Holo. Bot hiếm được báo cho cả server.
function PlayerService.Hatch(player, profile, capsule, count)
	local luck = PlayerService.Luck(player, profile)
	local results = {}
	for _ = 1, count do
		local bot = roll(capsule, luck)
		local variant = rollVariant(player)
		local isNew = not profile.discovered[bot.id]
		profile.discovered[bot.id] = true
		markVariant(profile, bot.id, variant)
		table.insert(profile.bots, { type = bot.id, level = 1, variant = variant })
		table.insert(results, { id = bot.id, new = isNew, variant = variant })
		if Config.RarityOrder[bot.rarity] >= Config.RarityOrder.Legendary or variant == "Holo" or (variant == "Shiny" and Config.RarityOrder[bot.rarity] >= Config.RarityOrder.Epic) then
			announce(player, string.format("🌟 %s hatched a %s (%s)!", player.DisplayName, Config.BotLabel(bot, variant), bot.rarity))
		end
	end
	remotes.Hatch:FireClient(player, capsule.id, results)
	publishBots(player, profile)
	checkQuest(player, profile)
	PlayerService.PushState(player)
	return results
end

-- capsule Credits xịn nhất người chơi đã mở khoá (quà ngày, thưởng sự kiện)
function PlayerService.BestCapsule(profile)
	local best = Config.Capsules[1]
	for _, capsule in Config.Capsules do
		if capsule.price and profile.level >= capsule.level then
			best = capsule
		end
	end
	return best
end

function actions.OpenCapsule(player, profile, session, capsuleId, count)
	local capsule = type(capsuleId) == "string" and Config.CapsuleById[capsuleId]
	if not capsule or not capsule.price then
		return
	end
	count = if count == 3 and player:GetAttribute("TripleHatch") then 3 else 1
	if profile.level < capsule.level then
		notify(player, string.format("🔒 %s unlocks at level %d", capsule.name, capsule.level))
		return
	end
	if #profile.bots + count > Config.MaxBots then
		notify(player, "🤖 Bot storage is full. Recycle some bots first!")
		return
	end
	local cost = capsule.price * count
	if profile.credits < cost then
		notify(player, string.format("You need %s credits", Config.Short(cost)))
		return
	end
	-- chờ animation mở capsule chạy xong
	if os.clock() - session.lastHatch < 1.5 then
		return
	end
	session.lastHatch = os.clock()
	profile.credits -= cost
	PlayerService.Hatch(player, profile, capsule, count)
end

-- Bot Database: đủ bộ của 1 capsule thì nhận thưởng 1 lần
function actions.ClaimSet(player, profile, session, capsuleId)
	local capsule = type(capsuleId) == "string" and Config.CapsuleById[capsuleId]
	if not capsule or profile.claimedSets[capsule.id] then
		return
	end
	for _, drop in capsule.drops do
		if not profile.discovered[drop.bot] then
			return
		end
	end
	profile.claimedSets[capsule.id] = true
	PlayerService.AddCredits(player, capsule.reward.credits)
	notify(player, string.format("📚 %s set complete! +%s credits, +%d%% gather forever", capsule.name, Config.Short(capsule.reward.credits), math.floor(capsule.reward.gather * 100 + 0.5)), "Reward")
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
	if entry.locked then
		notify(player, "🔒 This bot is locked. Unlock it first.")
		return
	end
	table.remove(profile.bots, index)
	local refund = Config.RecycleValue(bot, entry.level, entry.variant)
	profile.credits += refund
	notify(player, string.format("♻️ Recycled %s for %s credits", bot.name, Config.Short(refund)))
	publishBots(player, profile)
	PlayerService.PushState(player)
end

-- Recycle mọi bot dự bị (không ra trận) thuộc 1 độ hiếm, để dọn kho sau khi mở nhiều capsule
function actions.RecycleReserve(player, profile, session, rarity)
	if type(rarity) ~= "string" or not Config.RarityOrder[rarity] then
		return
	end
	local keep = {}
	for _, i in equipped(player, profile) do
		keep[i] = true
	end
	local refund, count = 0, 0
	-- đi từ cuối lên để xoá không làm lệch chỉ số các bot chưa duyệt
	for i = #profile.bots, 1, -1 do
		local entry = profile.bots[i]
		local bot = Config.BotById[entry.type]
		-- không đụng tới bot đang ra trận, bot đã khoá và bot biến thể
		if not keep[i] and bot and bot.rarity == rarity and not entry.locked and not entry.variant and #profile.bots > 1 then
			refund += Config.RecycleValue(bot, entry.level, entry.variant)
			table.remove(profile.bots, i)
			count += 1
		end
	end
	if count == 0 then
		notify(player, "No reserve " .. rarity .. " bots to recycle")
		return
	end
	profile.credits += refund
	notify(player, string.format("♻️ Recycled %d %s bots for %s credits", count, rarity, Config.Short(refund)), "Reward")
	publishBots(player, profile)
	PlayerService.PushState(player)
end

-- khoá / mở khoá bot (bot khoá không bị Recycle, không bị Fuse)
function actions.ToggleLock(player, profile, session, index)
	local entry = type(index) == "number" and profile.bots[index]
	if not entry then
		return
	end
	entry.locked = if entry.locked then nil else true
	PlayerService.PushState(player)
end

-- Fuse: gộp FuseCount bot giống hệt (cùng loại, cùng biến thể, chưa khoá) thành 1 bot biến thể kế tiếp.
-- Ưu tiên tiêu bot cấp thấp; bot mới giữ cấp cao nhất trong số bị gộp.
function actions.FuseBots(player, profile, session, botType, variant)
	local bot = type(botType) == "string" and Config.BotById[botType]
	if not bot then
		return
	end
	variant = if variant == "Shiny" then "Shiny" else nil
	local target = Config.NextVariant[variant or ""]
	if not target then
		return
	end
	local picks = {}
	for i, entry in profile.bots do
		if entry.type == bot.id and entry.variant == variant and not entry.locked then
			table.insert(picks, i)
		end
	end
	if #picks < Config.FuseCount then
		notify(player, string.format("You need %d unlocked %s to fuse", Config.FuseCount, Config.BotLabel(bot, variant)))
		return
	end
	table.sort(picks, function(a, b)
		return profile.bots[a].level < profile.bots[b].level
	end)
	local chosen, level = {}, 1
	for k = 1, Config.FuseCount do
		chosen[picks[k]] = true
		level = math.max(level, profile.bots[picks[k]].level)
	end
	for i = #profile.bots, 1, -1 do
		if chosen[i] then
			table.remove(profile.bots, i)
		end
	end
	local isNew = not (profile.variants[bot.id] and profile.variants[bot.id][target])
	table.insert(profile.bots, { type = bot.id, level = level, variant = target })
	markVariant(profile, bot.id, target)
	if target == "Holo" then
		announce(player, string.format("🧬 %s fused a %s!", player.DisplayName, Config.BotLabel(bot, target)))
	end
	remotes.Hatch:FireClient(player, "Fuse", { { id = bot.id, new = isNew, variant = target } })
	publishBots(player, profile)
	PlayerService.PushState(player)
end

-- Quà đăng nhập: mỗi ngày (giờ UTC) nhận 1 lần; nhận liên tục thì lên ngày tiếp theo của chuỗi 7 ngày
function actions.ClaimDaily(player, profile)
	local info = dailyInfo(profile)
	if not info.ready then
		notify(player, "🎁 Come back tomorrow for your next reward!")
		return
	end
	profile.daily.streak = info.streak + 1
	profile.daily.last = today()
	local reward = Config.DailyRewards[info.day]
	if reward.credits then
		local amount = Config.ScaledCredits(reward.credits, profile.level)
		PlayerService.AddCredits(player, amount)
		notify(player, string.format("🎁 Day %d reward: +%s credits!", info.day, Config.Short(amount)), "Reward")
	elseif reward.boost then
		profile.boosts[reward.boost] = math.max(os.time(), profile.boosts[reward.boost] or 0) + reward.minutes * 60
		notify(player, string.format("🎁 Day %d reward: x2 %s for %d min!", info.day, reward.boost, reward.minutes), "Reward")
	elseif reward.capsule then
		local capsule = if reward.capsule == "Best" then PlayerService.BestCapsule(profile) else Config.CapsuleById[reward.capsule]
		notify(player, string.format("🎁 Day %d reward: free %s!", info.day, capsule.name), "Reward")
		PlayerService.Hatch(player, profile, capsule, 1)
	end
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
	if name ~= "Harvest" and name ~= "UseCore" and name ~= "ToggleLock" then
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
		-- rơi xuống vực: hạ gục (mất data đang mang như chết bình thường)
		if root.Position.Y < -30 then
			humanoid.Health = 0
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
	sessions[player] = { lastAction = 0, lastHarvest = 0, lastUpload = 0, lastHatch = 0, cooldowns = {}, overclockUntil = 0, shieldUntil = 0 }
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = leaderstats
	local credits = Instance.new("NumberValue")
	credits.Name = "Credits"
	credits.Parent = leaderstats
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = leaderstats
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

-- cho service khác (EventService) đăng ký thêm hành động từ client
function PlayerService.AddAction(name, handler)
	actions[name] = handler
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
