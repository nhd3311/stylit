-- GameAnalytics: lớp bọc mỏng và AN TOÀN quanh AnalyticsService của Roblox (chỉ dùng ở server).
-- File tên AnalyticsService.luau nhưng bên trong gọi là GameAnalytics để khỏi nhầm với
-- game:GetService("AnalyticsService") của Roblox.
--   • Mọi lệnh chạy trong pcall: thiếu API, sai kiểu, lỗi mạng... đều bỏ qua, không bao giờ làm hỏng game.
--   • Số được làm tròn xuống; số âm, NaN, vô cực hoặc sai kiểu -> bỏ qua sự kiện đó.
--   • Hàm trả về true nếu đã gửi được, false nếu bị bỏ qua.
--
-- ===== API =====
--   GameAnalytics.Funnel(player, step, stepName?)    phễu người mới (LogOnboardingFunnelStepEvent), step >= 1
--   GameAnalytics.Source(player, amount, endingBalance, transactionType, itemSku?)   Credits VÀO
--   GameAnalytics.Sink(player, amount, endingBalance, transactionType, itemSku?)     Credits RA
--       transactionType = TÊN giá trị của Enum.AnalyticsEconomyTransactionType, dạng chuỗi:
--       "IAP" (mua bằng Robux), "Shop", "Gameplay", "ContextualPurchase", "TimedReward", "Onboarding".
--       Tên sai -> dùng "Gameplay" (cảnh báo 1 lần trong output).
--       endingBalance = số Credits SAU giao dịch (profile.credits ngay sau khi cộng/trừ).
--   GameAnalytics.Progress(player, level)            lên level -> LogCustomEvent("LevelUp", level)
--   GameAnalytics.Custom(player, eventName, value?)  sự kiện tuỳ ý (LogCustomEvent)
--   GameAnalytics.Start(PlayerService)               (tuỳ chọn) tự nghe event bus PlayerService.On(...)
--
-- ===== Cách 1 (khuyên dùng): Main.server gọi GameAnalytics.Start(PlayerService) =====
-- Tự ghi qua event bus: Loaded + Tutorial (phễu), Uploaded (Source), Spent (Sink: Capsule/Upgrade/Backpack),
-- LevelUp (Progress), EventWin (Custom), Hatched (Custom theo độ hiếm + biến thể).
-- Vẫn phải gọi TAY phần mua bằng Robux (mục 5 bên dưới) vì MonetizationService chưa phát sự kiện.
-- ĐỪNG vừa gọi Start vừa gọi tay các mục 1-4, 6-8 (sẽ bị ghi 2 lần).
--
-- ===== Cách 2: gọi tay ở các chỗ sau =====
--  1. Hướng dẫn (phễu người mới):
--     PlayerService.OnPlayerLoaded: nếu profile.tutorial == 0 -> Analytics.Funnel(player, 1, "Joined game")
--     PlayerService actions.Tutorial: nhớ bước cũ trước khi gán; nếu 1 <= step <= 9 và step > bước cũ
--       -> Analytics.Funnel(player, step + 1, "Tutorial " .. step)
--       (step 99 khi chưa xong 9 bước = bỏ qua -> Analytics.Custom(player, "TutorialSkipped", bướcCũ))
--  2. Upload ra Credits: PlayerService upload(), sau PlayerService.AddCredits
--     -> Analytics.Source(player, credits, profile.credits, "Gameplay", "Upload")
--  3. Mua capsule bằng Credits: PlayerService actions.OpenCapsule, sau profile.credits -= cost
--     -> Analytics.Sink(player, cost, profile.credits, "Shop", capsule.id)
--  4. Nâng cấp: PlayerService actions.UpgradeBot, sau profile.credits -= price
--     -> Analytics.Sink(player, price, profile.credits, "Shop", "Upgrade_" .. bot.id)
--     PlayerService actions.BuyBackpack, sau profile.credits -= nextTier.price
--     -> Analytics.Sink(player, nextTier.price, profile.credits, "Shop", "Backpack_" .. (profile.backpack + 1))
--  5. Mua bằng Robux: MonetizationService grantProduct
--     nhánh "Credits", sau AddCredits -> Analytics.Source(player, amount, profile.credits, "IAP", product.name)
--     nhánh "Bundle" có product.credits -> Analytics.Source(player, product.credits, profile.credits, "IAP", product.name)
--     (tuỳ chọn) processReceipt sau khi granted -> Analytics.Custom(player, "Robux_" .. key)
--  6. Lên level: PlayerService.AddXp, trong khối `if leveled then` -> Analytics.Progress(player, profile.level)
--  7. Thắng Glitch Floor: EventService reward(), trong `if won then` -> Analytics.Custom(player, "GlitchFloorWin")
--  8. Mở capsule: PlayerService.Hatch, trong vòng lặp sau khi có bot/variant
--     -> Analytics.Custom(player, "Hatch_" .. bot.rarity)
--     và nếu có variant -> Analytics.Custom(player, "Hatch_" .. variant)

local Players = game:GetService("Players")

local okService, service = pcall(function()
	return game:GetService("AnalyticsService")
end)
if not okService then
	service = nil
end

local GameAnalytics = {}
GameAnalytics.Currency = "Credits"
GameAnalytics.Enabled = service ~= nil -- đặt false để tắt toàn bộ (vd. khi test)

local MAX_NAME = 50 -- độ dài tối đa tên sự kiện / tên bước / SKU (ký tự)
local DEFAULT_TRANSACTION = "Gameplay"
-- tên từng bước, khớp thứ tự TUTORIAL trong Main.client.luau (chỉ để đọc trên dashboard)
local TUTORIAL_NAMES = {
	"Welcome",
	"Reach Byte Meadow",
	"Harvest data",
	"Upload at Hub",
	"Open a capsule",
	"Open Bots menu",
	"Use Habitat",
	"Fight a drone",
	"Tutorial complete",
}
-- loại chi tiêu (sự kiện "Spent") -> loại giao dịch Roblox
local SPENT_TRANSACTION = { Capsule = "Shop", Upgrade = "Shop", Backpack = "Shop" }

local warned = {}
-- cảnh báo mỗi loại lỗi đúng 1 lần cho đỡ rác output
local function warnOnce(key, ...)
	if not warned[key] then
		warned[key] = true
		warn("[Analytics]", key, ...)
	end
end

local function isPlayer(player)
	return typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players
end

-- số nguyên >= 0 (làm tròn xuống); NaN / vô cực / âm / sai kiểu -> nil
local function wholeNumber(x)
	if type(x) ~= "number" or x ~= x or x == math.huge or x == -math.huge then
		return nil
	end
	x = math.floor(x)
	if x < 0 then
		return nil
	end
	return x
end

-- chuỗi gọn: bỏ ký tự điều khiển, cắt khoảng trắng 2 đầu, tối đa MAX_NAME ký tự; rỗng / sai kiểu -> nil
local function cleanName(s)
	if type(s) == "number" then
		s = tostring(s)
	end
	if type(s) ~= "string" then
		return nil
	end
	s = (s:gsub("%c", ""))
	s = s:match("^%s*(.-)%s*$") or ""
	if s == "" then
		return nil
	end
	if #s > MAX_NAME then
		-- cắt theo ký tự UTF-8 để không làm vỡ chữ có dấu / emoji
		local ok, cut = pcall(utf8.offset, s, MAX_NAME + 1)
		if ok and cut then
			s = s:sub(1, cut - 1)
		end
	end
	return s
end

-- "IAP" / Enum.AnalyticsEconomyTransactionType.IAP -> "IAP"; sai -> "Gameplay"
local function transactionName(kind)
	local ok, name = pcall(function()
		if typeof(kind) == "EnumItem" then
			return if kind.EnumType == Enum.AnalyticsEconomyTransactionType then kind.Name else nil
		end
		if type(kind) == "string" then
			-- tên không có trong Enum -> lỗi -> pcall bắt, dùng mặc định
			return Enum.AnalyticsEconomyTransactionType[kind].Name
		end
		return nil
	end)
	if ok and type(name) == "string" then
		return name
	end
	warnOnce("transactionType " .. tostring(kind), "không hợp lệ, dùng " .. DEFAULT_TRANSACTION)
	return DEFAULT_TRANSACTION
end

local function flowType(name)
	local ok, item = pcall(function()
		return Enum.AnalyticsEconomyFlowType[name]
	end)
	return if ok then item else nil
end

-- gọi 1 hàm của AnalyticsService trong pcall; trả true nếu không lỗi
local function call(method, ...)
	if not service or not GameAnalytics.Enabled then
		return false
	end
	local args = table.pack(...)
	local ok, err = pcall(function()
		local fn = service[method]
		fn(service, table.unpack(args, 1, args.n))
	end)
	if not ok then
		warnOnce(method, err)
	end
	return ok
end

-- ================= API =================

function GameAnalytics.Funnel(player, step, stepName)
	if not isPlayer(player) then
		return false
	end
	step = wholeNumber(step)
	if not step or step < 1 then
		return false
	end
	local name = cleanName(stepName)
	if name then
		return call("LogOnboardingFunnelStepEvent", player, step, name)
	end
	return call("LogOnboardingFunnelStepEvent", player, step)
end

local function economy(flowName, player, amount, endingBalance, transactionType, itemSku)
	if not isPlayer(player) then
		return false
	end
	amount = wholeNumber(amount)
	endingBalance = wholeNumber(endingBalance)
	if not amount or amount <= 0 or not endingBalance then
		return false
	end
	local flow = flowType(flowName)
	if not flow then
		warnOnce("Enum.AnalyticsEconomyFlowType." .. flowName, "không có")
		return false
	end
	local kind = transactionName(transactionType)
	local sku = cleanName(itemSku)
	if sku then
		return call("LogEconomyEvent", player, flow, GameAnalytics.Currency, amount, endingBalance, kind, sku)
	end
	return call("LogEconomyEvent", player, flow, GameAnalytics.Currency, amount, endingBalance, kind)
end

function GameAnalytics.Source(player, amount, endingBalance, transactionType, itemSku)
	return economy("Source", player, amount, endingBalance, transactionType, itemSku)
end

function GameAnalytics.Sink(player, amount, endingBalance, transactionType, itemSku)
	return economy("Sink", player, amount, endingBalance, transactionType, itemSku)
end

function GameAnalytics.Custom(player, eventName, value)
	if not isPlayer(player) then
		return false
	end
	local name = cleanName(eventName)
	if not name then
		return false
	end
	if value == nil then
		return call("LogCustomEvent", player, name)
	end
	value = wholeNumber(value)
	if not value then
		return false
	end
	return call("LogCustomEvent", player, name, value)
end

-- Chưa chắc chữ ký của LogProgressionEvent nên dùng sự kiện tuỳ ý "LevelUp" (value = level mới)
function GameAnalytics.Progress(player, level)
	level = wholeNumber(level)
	if not level or level < 1 then
		return false
	end
	return GameAnalytics.Custom(player, "LevelUp", level)
end

-- ================= Tự nối vào event bus (tuỳ chọn) =================

local started = false
local tutorialSeen = {} -- [player] = bước hướng dẫn cao nhất đã ghi (chơi lại hướng dẫn thì không ghi lại)

function GameAnalytics.Start(PlayerService)
	if started then
		return
	end
	if type(PlayerService) ~= "table" or type(PlayerService.On) ~= "function" then
		warn("[Analytics] Start cần PlayerService có hàm On (event bus). Hãy gọi các hàm Analytics bằng tay.")
		return
	end
	started = true
	local on = PlayerService.On

	on("Loaded", function(player, profile)
		local step = if type(profile) == "table" and type(profile.tutorial) == "number" then profile.tutorial else 0
		tutorialSeen[player] = step
		if step == 0 then
			GameAnalytics.Funnel(player, 1, "Joined game")
		end
	end)

	on("Tutorial", function(player, _profile, data)
		local step = if type(data) == "table" then data.step else nil
		if type(step) ~= "number" then
			return
		end
		local seen = tutorialSeen[player] or 0
		if step >= 1 and step <= #TUTORIAL_NAMES and step > seen then
			tutorialSeen[player] = step
			GameAnalytics.Funnel(player, step + 1, TUTORIAL_NAMES[step])
		elseif step >= 99 and seen < #TUTORIAL_NAMES then
			-- 99 khi chưa xong hết các bước = người chơi bấm bỏ qua
			tutorialSeen[player] = 99
			GameAnalytics.Custom(player, "TutorialSkipped", seen)
		end
	end)

	on("Uploaded", function(player, profile, data)
		if type(profile) == "table" and type(data) == "table" then
			GameAnalytics.Source(player, data.credits, profile.credits, "Gameplay", "Upload")
		end
	end)

	on("Spent", function(player, profile, data)
		if type(profile) ~= "table" or type(data) ~= "table" then
			return
		end
		local kind = if type(data.kind) == "string" then data.kind else "Other"
		GameAnalytics.Sink(player, data.amount, profile.credits, SPENT_TRANSACTION[kind] or DEFAULT_TRANSACTION, data.sku or kind)
	end)

	on("LevelUp", function(player, profile, data)
		local level = if type(data) == "table" and data.level then data.level elseif type(profile) == "table" then profile.level else nil
		GameAnalytics.Progress(player, level)
	end)

	on("EventWin", function(player)
		GameAnalytics.Custom(player, "GlitchFloorWin")
	end)

	on("Hatched", function(player, _profile, data)
		if type(data) ~= "table" then
			return
		end
		local bot = data.bot
		if type(bot) == "table" and type(bot.rarity) == "string" then
			GameAnalytics.Custom(player, "Hatch_" .. bot.rarity)
		end
		if type(data.variant) == "string" then
			GameAnalytics.Custom(player, "Hatch_" .. data.variant)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		tutorialSeen[player] = nil
	end)
end

return GameAnalytics
