-- Bảng Social (client): Friend Boost, mời bạn, phần thưởng nhóm, nhắc Favorite + Like.
-- Module trả về 1 hàm vẽ bảng: function(ctx). Main.client gọi lại hàm này mỗi lần vẽ lại bảng (khá thường xuyên),
-- nên hàm KHÔNG giữ trạng thái giao diện nào: mọi thứ đọc lại từ ctx.state.social mỗi lần vẽ.
-- Hợp đồng ctx (Main.client truyền vào): state, fire, section, row, button, text, new, content, nextOrder,
-- C (bảng màu), toast, short, player.
-- Server quyết định mọi phần thưởng; bảng này chỉ hiển thị và gửi yêu cầu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local SocialConfig = require(Shared:WaitForChild("SocialConfig"))

-- đang chờ Roblox trả lời lời mời. Không phải trạng thái vẽ: chỉ chặn bấm liên tục khi đang chờ mạng.
local inviteBusy = false

local function percent(fraction)
	return math.floor((fraction or 0) * 100 + 0.5)
end

-- mở bảng mời bạn của Roblox. CanSendGameInviteAsync phải chờ mạng nên chạy luồng riêng.
local function invite(ctx)
	if inviteBusy then
		return
	end
	inviteBusy = true
	task.spawn(function()
		local ok, canSend = pcall(SocialService.CanSendGameInviteAsync, SocialService, ctx.player)
		if not ok then
			ctx.toast("📨 Couldn't open invites right now. Please try again in a moment!", 3, ctx.C.gold)
		elseif not canSend then
			-- tài khoản bị giới hạn (độ tuổi / cài đặt riêng tư), thiết bị không hỗ trợ, hoặc đang thử trong Studio
			ctx.toast("📨 Invites aren't available for your account or device right now", 4, ctx.C.gold)
		else
			local shown = pcall(SocialService.PromptGameInvite, SocialService, ctx.player)
			if not shown then
				ctx.toast("📨 Couldn't open the invite window. Please try again!", 3, ctx.C.gold)
			end
		end
		inviteBusy = false
	end)
end

-- chữ mô tả phần thưởng nhóm, vd. "+1.2K credits + a free capsule (best you've unlocked)"
local function groupRewardText(ctx, level)
	local reward = SocialConfig.GroupReward or {}
	local parts = {}
	local credits = Config.ScaledCredits(reward.credits or 0, level)
	if credits > 0 then
		table.insert(parts, "+" .. ctx.short(credits) .. " credits")
	end
	if reward.capsule == "Best" then
		table.insert(parts, "a free capsule (best you've unlocked)")
	elseif type(reward.capsule) == "string" and Config.CapsuleById[reward.capsule] then
		table.insert(parts, "a free " .. Config.CapsuleById[reward.capsule].name)
	end
	return table.concat(parts, " + ")
end

return function(ctx)
	local C = ctx.C
	local state = ctx.state
	local social = state and state.social
	if not social then
		ctx.row({ icon = "⏳", iconColor = C.off, title = "Loading social info...", sub = "One moment!", dim = true, height = 58 })
		return
	end
	local level = state.level or 1
	local perFriend = percent(SocialConfig.FriendBoostPerFriend)
	local maxBoost = percent(SocialConfig.FriendBoostMax)

	-- ---------- Friend Boost ----------
	local friends = social.friendsHere or 0
	local boost = percent(social.friendBoost)
	ctx.section(
		"👥 FRIEND BOOST",
		if boost > 0
			then string.format("<font color='#%s'>+%d%% active</font>", C.lime:ToHex(), boost)
			else string.format("+%d%% per friend · max +%d%%", perFriend, maxBoost)
	)
	local friendSub
	if friends <= 0 then
		friendSub = string.format("Play with your Roblox friends in the same server: +%d%% gather & credits per friend (max +%d%%).", perFriend, maxBoost)
	elseif boost >= maxBoost then
		friendSub = string.format("%d friends are playing here with you. Max boost reached!", friends)
	else
		friendSub = string.format("%d %s here with you. Each friend adds +%d%% (max +%d%%).", friends, if friends == 1 then "friend is playing" else "friends are playing", perFriend, maxBoost)
	end
	ctx.row({
		icon = "👥",
		iconColor = if friends > 0 then C.lime else C.cyan,
		title = if friends > 0 then string.format("+%d%% gather & credits", boost) else "No friends in this server yet",
		sub = friendSub,
		accent = if friends > 0 then C.lime else nil,
		height = 64,
	})

	-- ---------- Mời bạn ----------
	local inviteCredits = Config.ScaledCredits((SocialConfig.InviteReward or {}).credits or 0, level)
	ctx.section("📨 INVITE FRIENDS")
	ctx.row({
		icon = "📨",
		iconColor = C.violet,
		title = "Invite your friends",
		sub = string.format("When a friend joins you from your invite, you BOTH get +%s credits (once per friend).", ctx.short(inviteCredits)),
		accent = C.violet,
		buttons = { {
			text = "📨 INVITE",
			color = C.violet,
			onClick = function()
				invite(ctx)
			end,
		} },
		height = 64,
	})

	-- ---------- Nhóm ----------
	local status = social.groupReward
	local rewardText = groupRewardText(ctx, level)
	ctx.section("🏛️ GROUP REWARD")
	if status == "claimable" then
		ctx.row({
			icon = "🎁",
			iconColor = C.gold,
			title = "Thanks for joining our group!",
			sub = "Your one-time reward: " .. rewardText,
			accent = C.gold,
			buttons = { {
				text = "🎁 CLAIM",
				color = C.lime:Lerp(C.void, 0.3),
				onClick = function()
					ctx.fire("ClaimGroupReward")
				end,
			} },
			height = 64,
		})
	elseif status == "claimed" then
		ctx.row({
			icon = "✅",
			iconColor = C.lime,
			title = "Group reward claimed",
			sub = "Thanks for supporting " .. Config.GameName .. "! 💙",
			dim = true,
			buttons = { { text = "✓ CLAIMED", color = C.off } },
			height = 58,
		})
	elseif status == "notMember" then
		ctx.row({
			icon = "🏛️",
			iconColor = C.blue,
			title = "Join our group for a reward",
			sub = "Join the " .. Config.GameName .. " group (find it on the game page), then tap CHECK. Reward: " .. rewardText,
			buttons = { {
				text = "🔄 CHECK",
				color = C.blue,
				onClick = function()
					ctx.fire("ClaimGroupReward")
				end,
			} },
			height = 64,
		})
	else
		-- "none": chưa điền SocialConfig.GroupId
		ctx.row({
			icon = "🏛️",
			iconColor = C.off,
			title = "Group reward coming soon",
			sub = "No group is set up yet. Check back later!",
			dim = true,
			height = 58,
		})
	end

	-- ---------- Favorite & Like ----------
	-- chỉ là chữ nhắc: không dùng API mở hộp thoại Favorite (Roblox không có API chắc chắn cho việc này)
	ctx.section("⭐ FAVORITE & LIKE")
	ctx.row({
		icon = "⭐",
		iconColor = C.gold,
		title = "Enjoying " .. Config.GameName .. "?",
		sub = "Tap ⭐ Favorite and 👍 Like on the game page. It really helps us add new zones, bots and events!",
		height = 64,
	})
end
