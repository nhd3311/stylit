-- FriendsService: tính năng xã hội phía server. Đặt tên khác SocialService (service của Roblox) cho khỏi nhầm.
--   • Friend Boost: đếm số bạn Roblox đang ở cùng server. Hệ số = 1 + min(số bạn × FriendBoostPerFriend, FriendBoostMax).
--     Kết quả IsFriendsWith được nhớ theo từng cặp người chơi; số bạn được đếm lại khi có người vào / ra.
--     Đặt attribute "FriendBoost" (phần cộng thêm, vd. 0.2) và cung cấp FriendsService.Multiplier(player).
--   • Phần thưởng nhóm: hành động "ClaimGroupReward", mỗi tài khoản nhận 1 lần
--     (credits nhân theo level + 1 capsule miễn phí).
--   • Mời bạn: người vào game từ lời mời (GetJoinData().ReferredByPlayerId) khi người mời đang ở server này
--     → cả hai nhận thưởng, mỗi cặp 1 lần.
--   • Gửi state.social cho client vẽ bảng Social.
-- Mọi lệnh gọi web / mạng xã hội của Roblox đều bọc pcall: lỗi mạng chỉ làm tính năng tạm tắt, không làm hỏng game.
-- Server là "trọng tài": client chỉ gửi yêu cầu, server tự kiểm tra rồi mới phát thưởng.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SocialConfig = require(ReplicatedStorage.Shared.SocialConfig)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)

local FriendsService = {}

local GROUP_REFRESH = 120 -- giây giữa 2 lần tự hỏi lại tư cách thành viên nhóm
local CLAIM_COOLDOWN = 5 -- giây giữa 2 lần bấm nhận thưởng nhóm (mỗi lần là 1 lệnh gọi web)
local PROFILE_TIMEOUT = 60 -- chờ data người chơi tải xong tối đa bấy nhiêu giây
local GREET_DELAY = 3 -- chờ giao diện client dựng xong rồi mới báo cho người vừa vào
local PENDING = "pending" -- cặp đang chờ Roblox trả lời IsFriendsWith

local friendPairs = {} -- ["idNhỏ:idLớn"] = true / false / PENDING
local friendCount = {} -- [player] = số bạn đang ở cùng server
local ready = {} -- [player] = true khi đã kiểm tra bạn bè lúc vào server xong
local groupMember = {} -- [player] = true / false (nil = chưa hỏi được)
local groupCheckedAt = {} -- [player] = os.clock() lần hỏi nhóm gần nhất
local lastClaim = {} -- [player] = os.clock() lần bấm nhận thưởng nhóm gần nhất

local notify = PlayerService.Notify

-- ================= Dữ liệu =================

-- data cũ chưa có field mới thì bù mặc định (DataService cũng nên thêm 2 field này vào defaultData)
local function ensureDefaults(profile)
	if profile.groupRewardClaimed == nil then
		profile.groupRewardClaimed = false
	end
	if type(profile.invitesRewarded) ~= "table" then
		profile.invitesRewarded = {}
	end
end

-- chờ DataService tải xong data (Main.server gọi DataService.Load song song với service này)
local function waitForProfile(player)
	local deadline = os.clock() + PROFILE_TIMEOUT
	while player.Parent and os.clock() < deadline do
		local profile = DataService.Profiles[player]
		if profile then
			ensureDefaults(profile)
			return profile
		end
		task.wait(0.5)
	end
	return nil
end

-- sau mỗi lần chờ mạng: người chơi còn ở server và vẫn đúng data này không
local function stillLoaded(player, profile)
	return player.Parent ~= nil and DataService.Profiles[player] == profile
end

local function percent(fraction)
	return math.floor(fraction * 100 + 0.5)
end

-- ================= Friend Boost =================

local function pairKey(a, b)
	local low, high = math.min(a.UserId, b.UserId), math.max(a.UserId, b.UserId)
	return low .. ":" .. high
end

-- phần cộng thêm (0 .. FriendBoostMax) theo số bạn
local function bonusFor(count)
	return math.min(count * SocialConfig.FriendBoostPerFriend, SocialConfig.FriendBoostMax)
end

-- "Playing with a friend: +10% gather & credits!"
local function boostText(count)
	local who = if count == 1 then "a friend" else count .. " friends"
	return string.format("Playing with %s: +%d%% gather & credits!", who, percent(bonusFor(count)))
end

-- đếm lại số bạn đang ở server chỉ từ kết quả đã nhớ (không gọi web, không chờ)
local function recount(player)
	if not player.Parent then
		return
	end
	local count = 0
	for _, other in Players:GetPlayers() do
		if other ~= player and friendPairs[pairKey(player, other)] == true then
			count += 1
		end
	end
	friendCount[player] = count
	player:SetAttribute("FriendBoost", bonusFor(count))
end

-- hỏi Roblox 2 người có là bạn không (có chờ mạng).
-- Trả về true / false, hoặc nil khi lỗi mạng hay 1 trong 2 đã rời server (lần sau hỏi lại).
local function lookupPair(player, other)
	local key = pairKey(player, other)
	local known = friendPairs[key]
	if known == true or known == false then
		return known
	elseif known == PENDING then
		return nil -- luồng khác đang hỏi cặp này rồi
	end
	friendPairs[key] = PENDING
	local ok, result = pcall(player.IsFriendsWith, player, other.UserId)
	if friendPairs[key] ~= PENDING then
		return nil -- trong lúc chờ, 1 trong 2 đã rời server và cặp đã bị xoá
	end
	if not ok then
		friendPairs[key] = nil
		warn("[FriendsService] IsFriendsWith lỗi:", result)
		return nil
	end
	friendPairs[key] = result == true
	return friendPairs[key]
end

-- hỏi mọi cặp (player, người khác) chưa biết, rồi đếm lại cho những ai liên quan.
-- readyOnly = true (vòng hỏi lại định kỳ): bỏ qua người vừa vào chưa kiểm tra xong,
-- để chính luồng vào server của họ phát hiện cặp và báo "bạn vừa vào".
-- Trả về danh sách bạn MỚI phát hiện.
local function checkFriends(player, readyOnly)
	local found = {}
	for _, other in Players:GetPlayers() do
		local eligible = other ~= player and (not readyOnly or ready[other])
		if eligible and friendPairs[pairKey(player, other)] == nil and lookupPair(player, other) == true then
			table.insert(found, other)
		end
	end
	recount(player)
	for _, other in found do
		recount(other)
	end
	return found
end

function FriendsService.Multiplier(player)
	return 1 + bonusFor(friendCount[player] or 0)
end

-- ================= Phần thưởng nhóm =================

local function groupEnabled()
	return type(SocialConfig.GroupId) == "number" and SocialConfig.GroupId > 0
end

-- hỏi Roblox người chơi có trong nhóm không (có chờ mạng). Trả về true / false, hoặc nil nếu không hỏi được.
-- fresh = true (lúc bấm nhận): IsInGroup báo "không" thì hỏi thêm GroupService:GetGroupsAsync,
-- vì IsInGroup trên server có thể giữ kết quả cũ cả phiên chơi (người vừa vào nhóm giữa chừng vẫn bị báo "không").
local function checkGroup(player, fresh)
	if not groupEnabled() then
		return false
	end
	local ok, result = pcall(player.IsInGroup, player, SocialConfig.GroupId)
	local member = if ok then result == true else nil
	if not ok then
		warn("[FriendsService] IsInGroup lỗi:", result)
	end
	if member ~= true and fresh then
		local listOk, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
		if listOk and type(groups) == "table" then
			member = false
			for _, group in groups do
				if type(group) == "table" and group.Id == SocialConfig.GroupId then
					member = true
					break
				end
			end
		end
	end
	if player.Parent then
		groupCheckedAt[player] = os.clock()
		if member ~= nil then
			groupMember[player] = member
		end
	end
	return member
end

-- "none" | "claimable" | "claimed" | "notMember" (chỉ đọc kết quả đã nhớ, không chờ mạng)
local function groupStatus(player, profile)
	if not groupEnabled() then
		return "none"
	elseif profile.groupRewardClaimed then
		return "claimed"
	elseif groupMember[player] == true then
		return "claimable"
	end
	return "notMember"
end

local function claimGroupReward(player, profile)
	ensureDefaults(profile)
	if not groupEnabled() then
		notify(player, "🏛️ There's no group reward yet. Stay tuned!")
		return
	end
	if profile.groupRewardClaimed then
		notify(player, "🏛️ You already claimed the group reward. Thanks for joining! 💙")
		return
	end
	local now = os.clock()
	if now - (lastClaim[player] or -math.huge) < CLAIM_COOLDOWN then
		notify(player, "🏛️ Still checking... try again in a few seconds")
		return
	end
	lastClaim[player] = now
	local member = checkGroup(player, true)
	if member == nil then
		member = groupMember[player] -- lỗi mạng: dùng kết quả hỏi được lần trước (nếu có)
	end
	-- trong lúc chờ mạng: người chơi có thể đã thoát, hoặc đã nhận ở 1 lần bấm khác
	if not stillLoaded(player, profile) or profile.groupRewardClaimed then
		return
	end
	if member == nil then
		notify(player, "🏛️ Couldn't check your group membership right now. Try again in a minute!")
		return
	end
	if not member then
		notify(player, "🏛️ Join our Roblox group first (find it on the game page), then tap CHECK again!")
		PlayerService.PushState(player)
		return
	end
	-- đánh dấu đã nhận TRƯỚC khi phát thưởng
	profile.groupRewardClaimed = true
	local reward = SocialConfig.GroupReward or {}
	local credits = Config.ScaledCredits(reward.credits or 0, profile.level)
	if credits > 0 then
		PlayerService.AddCredits(player, credits)
	end
	local capsule = nil
	if reward.capsule == "Best" then
		capsule = PlayerService.BestCapsule(profile)
	elseif type(reward.capsule) == "string" then
		capsule = Config.CapsuleById[reward.capsule]
	end
	if capsule then
		notify(player, string.format("🏛️ Group reward: +%s credits and a free %s!", Config.Short(credits), capsule.name), "Reward")
		PlayerService.Hatch(player, profile, capsule, 1)
	else
		notify(player, string.format("🏛️ Group reward: +%s credits!", Config.Short(credits)), "Reward")
	end
	PlayerService.PushState(player)
end

-- ================= Mời bạn =================

-- thưởng 1 người trong cặp mời/được mời; khoá theo userId của người kia.
-- Khoá là chuỗi vì DataStore không lưu được bảng có khoá số thưa (userId).
local function rewardInvite(player, profile, other, message)
	local key = tostring(other.UserId)
	if profile.invitesRewarded[key] then
		return
	end
	profile.invitesRewarded[key] = true
	local credits = Config.ScaledCredits((SocialConfig.InviteReward or {}).credits or 0, profile.level)
	if credits > 0 then
		PlayerService.AddCredits(player, credits)
	end
	notify(player, string.format(message, other.DisplayName, Config.Short(credits)), "Reward")
	PlayerService.PushState(player)
end

local function handleReferral(player, profile)
	local ok, joinData = pcall(player.GetJoinData, player)
	if not ok or type(joinData) ~= "table" then
		return
	end
	local raw = joinData.ReferredByPlayerId
	local referrerId = if type(raw) == "number" then raw elseif type(raw) == "string" then tonumber(raw) else nil
	if not referrerId or referrerId <= 0 or referrerId == player.UserId then
		return
	end
	-- chỉ thưởng khi người mời đang ở chính server này
	local referrer = Players:GetPlayerByUserId(referrerId)
	if not referrer then
		return
	end
	local referrerProfile = waitForProfile(referrer)
	if not referrerProfile or not stillLoaded(player, profile) or not stillLoaded(referrer, referrerProfile) then
		return
	end
	rewardInvite(player, profile, referrer, "📨 You joined from %s's invite: +%s credits!")
	rewardInvite(referrer, referrerProfile, player, "📨 %s joined from your invite: +%s credits!")
end

-- ================= Vào / ra server =================

local function onPlayerAdded(player)
	player:SetAttribute("FriendBoost", 0)
	task.spawn(checkGroup, player, false)
	-- báo những người bạn đang ở server: bạn mình vừa vào
	for _, other in checkFriends(player) do
		if other.Parent then
			notify(other, string.format("👥 %s joined! %s", player.DisplayName, boostText(friendCount[other] or 0)), "Reward")
		end
	end
	if not player.Parent then
		return
	end
	ready[player] = true
	local profile = waitForProfile(player)
	if not profile then
		return
	end
	task.wait(GREET_DELAY)
	if not stillLoaded(player, profile) then
		return
	end
	local count = friendCount[player] or 0
	if count > 0 then
		notify(player, "👥 " .. boostText(count), "Reward")
	end
	handleReferral(player, profile)
end

local function onPlayerRemoving(player)
	-- quên mọi cặp có người này (vào lại thì hỏi lại), rồi đếm lại cho người ở lại
	local prefix, suffix = player.UserId .. ":", ":" .. player.UserId
	for key in friendPairs do
		if key:sub(1, #prefix) == prefix or key:sub(-#suffix) == suffix then
			friendPairs[key] = nil
		end
	end
	friendCount[player] = nil
	ready[player] = nil
	groupMember[player] = nil
	groupCheckedAt[player] = nil
	lastClaim[player] = nil
	for _, other in Players:GetPlayers() do
		if other ~= player then
			recount(other)
		end
	end
end

-- định kỳ: hỏi lại nhóm cho người chưa nhận thưởng, và hỏi lại các cặp bạn bè lần trước lỗi mạng
local function refreshLoop()
	while true do
		task.wait(15)
		for _, player in Players:GetPlayers() do
			local profile = DataService.Profiles[player]
			local due = os.clock() - (groupCheckedAt[player] or -math.huge) >= GROUP_REFRESH
			if due and groupEnabled() and profile and not profile.groupRewardClaimed then
				groupCheckedAt[player] = os.clock() -- đánh dấu trước để vòng sau không hỏi trùng
				task.spawn(checkGroup, player, false)
			end
			if ready[player] then
				task.spawn(checkFriends, player, true) -- cặp đã biết thì bỏ qua, không gọi web
			end
		end
	end
end

function FriendsService.Start()
	PlayerService.AddAction("ClaimGroupReward", claimGroupReward)
	-- PlayerService không require được service này (require vòng) nên gắn hàm vào PlayerService,
	-- giống cách EnemyService gắn PlayerService.DamageArea
	PlayerService.FriendMultiplier = FriendsService.Multiplier
	PlayerService.StateExtras.social = function(player, profile)
		ensureDefaults(profile)
		local count = friendCount[player] or 0
		return {
			friendBoost = bonusFor(count),
			friendsHere = count,
			groupId = SocialConfig.GroupId,
			groupReward = groupStatus(player, profile),
		}
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	task.spawn(refreshLoop)
end

return FriendsService
