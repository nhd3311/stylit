-- Hai bảng phụ cho giao diện: nhập mã quà (Codes) và danh sách thành tựu (Achievements).
-- Main.client gọi renderer bên trong khung bảng chung và truyền ctx:
--   ctx.state, ctx.fire, ctx.section, ctx.row, ctx.button, ctx.text, ctx.new, ctx.content,
--   ctx.nextOrder, ctx.C, ctx.DISPLAY, ctx.BODY, ctx.toast, ctx.short, ctx.player
-- Renderer không giữ tham chiếu UI giữa các lần vẽ (bảng bị xoá và vẽ lại thường xuyên).
-- Thứ duy nhất được nhớ là chữ đang gõ dở trong ô mã (draft), để vẽ lại không xoá mất.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local RewardsConfig = require(Shared:WaitForChild("RewardsConfig"))

local WHITE = Color3.new(1, 1, 1)
local MAX_CODE_LENGTH = 32
local MAX_SHOWN_CODES = 8
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

local draft = "" -- chữ đang gõ dở trong ô nhập mã (giữ qua các lần vẽ lại)

local function trim(s)
	return string.match(s, "^%s*(.-)%s*$") or ""
end

-- ngày mở khoá dạng "Nov 25, 2026" (giờ máy người chơi)
local function dateText(timestamp)
	if type(timestamp) ~= "number" then
		return ""
	end
	local d = os.date("*t", timestamp)
	return string.format("%s %d, %d", MONTHS[d.month], d.day, d.year)
end

local function uiCorner(ctx, radius)
	return ctx.new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function uiStroke(ctx, color, thickness, transparency)
	return ctx.new("UIStroke", { Color = color, Thickness = thickness, Transparency = transparency, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

-- ================= Codes =================

local function renderCodes(ctx)
	local C = ctx.C
	ctx.section("REDEEM A CODE", "Get <b>credits</b>, <b>boosts</b> and <b>free capsules</b>")

	-- thẻ kính tối: ô nhập mã bên trái, nút REDEEM bên phải
	local card = ctx.new("Frame", {
		LayoutOrder = ctx.nextOrder(),
		Size = UDim2.new(1, 0, 0, 76),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Parent = ctx.content,
	}, {
		uiCorner(ctx, 12),
		ctx.new("UIGradient", { Color = ColorSequence.new(C.glassHi, C.glass), Rotation = 90 }),
		uiStroke(ctx, C.magenta, 1.4, 0.25),
	})

	-- ô nhập: nền tối + viền neon, sáng lên khi đang gõ
	local field = ctx.new("Frame", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -196, 0, 48),
		BackgroundColor3 = C.void,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Parent = card,
	}, {
		uiCorner(ctx, 10),
	})
	local fieldStroke = uiStroke(ctx, C.cyan, 1.5, 0.35)
	fieldStroke.Parent = field
	ctx.text({ Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(36, 48), TextSize = 22, Text = "🎟️", Parent = field })

	local box = ctx.new("TextBox", {
		Position = UDim2.fromOffset(46, 0),
		Size = UDim2.new(1, -56, 1, 0),
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		ClipsDescendants = true,
		FontFace = ctx.DISPLAY,
		TextSize = 16,
		TextColor3 = C.text,
		PlaceholderText = "ENTER CODE",
		PlaceholderColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = draft,
		Parent = field,
	})

	box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > MAX_CODE_LENGTH then
			box.Text = string.sub(box.Text, 1, MAX_CODE_LENGTH)
			return
		end
		draft = box.Text
	end)
	box.Focused:Connect(function()
		fieldStroke.Color = C.magenta
		fieldStroke.Transparency = 0
		fieldStroke.Thickness = 2
	end)

	local function submit()
		if trim(box.Text) == "" then
			ctx.toast("🎟️ Type a code first!", 2, C.gold)
			return
		end
		ctx.fire("RedeemCode", box.Text)
	end

	box.FocusLost:Connect(function(enterPressed)
		fieldStroke.Color = C.cyan
		fieldStroke.Transparency = 0.35
		fieldStroke.Thickness = 1.5
		if enterPressed then
			submit()
		end
	end)

	ctx.button({
		Parent = card,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 2),
		Size = UDim2.fromOffset(168, 52),
		Text = "🎁 REDEEM",
		Color = C.lime:Lerp(C.void, 0.3),
		Font = ctx.DISPLAY,
		TextSize = 13,
		Radius = 12,
		onClick = submit,
	})

	ctx.row({
		icon = "📣",
		iconColor = C.magenta,
		title = "Follow us for new codes!",
		sub = "New codes drop with updates, events and milestones. Each code works once per player.",
		height = 62,
	})

	-- mã đã dùng (server gửi state.redeemedCodes)
	local used = {}
	for code in (ctx.state and ctx.state.redeemedCodes) or {} do
		table.insert(used, code)
	end
	table.sort(used)
	if #used > 0 then
		ctx.section("REDEEMED", string.format("%d code%s", #used, if #used == 1 then "" else "s"))
		local shown = {}
		for i = 1, math.min(#used, MAX_SHOWN_CODES) do
			table.insert(shown, used[i])
		end
		local more = if #used > MAX_SHOWN_CODES then string.format("  +%d more", #used - MAX_SHOWN_CODES) else ""
		ctx.row({
			icon = "✅",
			iconColor = C.lime,
			title = table.concat(shown, "  ·  ") .. more,
			sub = "Already claimed on this account",
			dim = true,
			height = 58,
		})
	end
end

-- ================= Achievements =================

local function renderAchievements(ctx)
	local C = ctx.C
	local state = ctx.state or {}
	local unlocked = state.achievements or {}
	local list = RewardsConfig.Achievements

	-- đếm tổng + theo nhóm
	local done = 0
	local groups = {} -- [group] = { done, total }
	for _, achievement in list do
		local group = achievement.group or "Achievements"
		groups[group] = groups[group] or { done = 0, total = 0 }
		groups[group].total += 1
		if unlocked[achievement.key] then
			done += 1
			groups[group].done += 1
		end
	end

	ctx.section("ACHIEVEMENTS", string.format("<font color='#%s'><b>%d</b></font> / %d unlocked", C.gold:ToHex(), done, #list))

	-- thanh tiến độ tổng
	local ratio = done / math.max(1, #list)
	local back = ctx.new("Frame", {
		LayoutOrder = ctx.nextOrder(),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = C.void,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Parent = ctx.content,
	}, {
		uiCorner(ctx, 6),
		uiStroke(ctx, C.gold, 1, 0.45),
	})
	ctx.new("Frame", {
		Size = UDim2.fromScale(ratio, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Parent = back,
	}, {
		uiCorner(ctx, 6),
		ctx.new("UIGradient", { Color = ColorSequence.new(C.gold, C.orange) }),
	})
	ctx.text({
		Size = UDim2.fromScale(1, 1),
		FontFace = ctx.DISPLAY,
		TextSize = 10,
		TextStrokeTransparency = 0.45,
		ZIndex = 2,
		Text = string.format("%d%% COMPLETE", math.floor(ratio * 100 + 0.5)),
		Parent = back,
	})

	-- từng thành tựu theo thứ tự config, có tiêu đề nhóm; đã mở thì sáng, chưa mở thì mờ
	local level = state.level or 1
	local lastGroup = nil
	for _, achievement in list do
		local group = achievement.group or "Achievements"
		if group ~= lastGroup then
			lastGroup = group
			ctx.section(string.upper(group), string.format("%d / %d", groups[group].done, groups[group].total))
		end
		local at = unlocked[achievement.key]
		local base = achievement.reward and achievement.reward.credits or 0
		local reward = if base > 0 then "  ·  Reward: " .. ctx.short(Config.ScaledCredits(base, level)) .. " credits" else ""
		if at then
			local when = dateText(at)
			ctx.row({
				icon = achievement.icon,
				iconColor = C.gold,
				title = achievement.name,
				sub = achievement.description .. (if when ~= "" then "  ·  Unlocked " .. when else ""),
				accent = C.gold,
				buttons = { { text = "✓ UNLOCKED", color = C.lime:Lerp(C.void, 0.35) } },
				height = 60,
			})
		else
			ctx.row({
				icon = achievement.icon,
				iconColor = C.off,
				title = achievement.name,
				sub = achievement.description .. reward,
				dim = true,
				height = 60,
			})
		end
	end
end

return {
	Codes = renderCodes,
	Achievements = renderAchievements,
}
