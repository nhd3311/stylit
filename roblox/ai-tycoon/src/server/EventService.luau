-- Sự kiện ngẫu nhiên có 2 lựa chọn (thiếu GPU, rò rỉ dữ liệu, bị kiện, quỹ đầu tư...).
-- Khi có sự kiện, lịch tạm dừng cho tới khi người chơi chọn. Chi phí / phần thưởng tính theo
-- doanh thu mỗi ngày (có mức tối thiểu) để công ty to hay nhỏ đều thấy "đau" hoặc "đã".
-- Crisis Shield (mua bằng Robux) tự xử lý sự kiện xấu tiếp theo miễn phí.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CalendarService = require(script.Parent.CalendarService)
local CompanyService = require(script.Parent.CompanyService)
local Config = require(ReplicatedStorage.Shared.Config)
local ModelService = require(script.Parent.ModelService)
local StaffService = require(script.Parent.StaffService)

local EventService = {}

local E = Config.Events
local notify = CompanyService.Notify
local random = Random.new()

local function scaled(player, days, minimum)
	return math.max(minimum or 0, math.floor(ModelService.RevenuePerDay(player) * (days or 0)))
end

local function addModifier(profile, kind, mult, days)
	table.insert(profile.modifiers, { kind = kind, mult = mult, untilDay = profile.day + days })
end

-- Thực hiện lựa chọn `choice` của sự kiện. Trả về câu tóm tắt kết quả.
local function apply(player, profile, choice)
	local parts = {}
	local effect = choice.effect or {}
	if choice.costDays then
		local cost = scaled(player, choice.costDays, choice.minCost)
		profile.cash -= cost
		table.insert(parts, "-" .. Config.Money(cost))
	end
	if effect.gamble then
		-- ra toà: 50% thắng (không mất gì), 50% thua nặng
		if random:NextNumber() < 0.5 then
			table.insert(parts, "You won the case! ⚖️")
		else
			local cost = scaled(player, effect.costDays, effect.minCost)
			profile.cash -= cost
			table.insert(parts, "You lost the case: -" .. Config.Money(cost))
		end
	end
	if effect.cashDays then
		local cash = scaled(player, effect.cashDays, effect.minCash)
		CompanyService.AddCash(player, cash)
		table.insert(parts, "+" .. Config.Money(cash))
	end
	if effect.modifier then
		addModifier(profile, effect.modifier, effect.mult, effect.days)
		table.insert(parts, string.format("%s x%.1f for %d days", effect.modifier, effect.mult, effect.days))
	end
	if effect.hire then
		if StaffService.AddStaff(player, profile, effect.hire, effect.skill) then
			table.insert(parts, "A new star joined your team 🌟")
			CompanyService.RenderSeats(player)
		else
			table.insert(parts, "No free desk, so they went to a rival 😢")
		end
	end
	return if #parts > 0 then table.concat(parts, " • ") else "Nothing changed."
end

local function trigger(player, profile)
	local event = E.List[random:NextInteger(1, #E.List)]
	if event.bad and profile.shields > 0 then
		profile.shields -= 1
		notify(player, string.format("🛡️ Crisis Shield handled \"%s\" for you", event.title), "Collect")
		return
	end
	profile.event = { id = event.id, speed = profile.speed }
	profile.speed = 1 -- tạm dừng thời gian
	local choices = {}
	for i, choice in event.choices do
		local cost = if choice.costDays then scaled(player, choice.costDays, choice.minCost) else nil
		table.insert(choices, { index = i, label = choice.label, cost = cost })
	end
	CompanyService.Popup(player, { kind = "Event", emoji = event.emoji, title = event.title, text = event.text, choices = choices })
end

function EventService.Start()
	CompanyService.RegisterAction("ChooseEvent", function(player, profile, session, index)
		local pending = profile.event
		local event = pending and Config.EventById[pending.id]
		local choice = event and type(index) == "number" and event.choices[index]
		if not choice then
			return
		end
		profile.event = nil
		profile.speed = pending.speed or 2
		notify(player, string.format("%s %s → %s", event.emoji, choice.label, apply(player, profile, choice)), "Evolve")
		CompanyService.PushState(player)
	end)

	CalendarService.RegisterDayHook(function(player, profile, day)
		-- dọn hiệu ứng đã hết hạn
		for i = #profile.modifiers, 1, -1 do
			if profile.modifiers[i].untilDay < day then
				table.remove(profile.modifiers, i)
			end
		end
		if day > 30 and not profile.event and random:NextNumber() < E.Chance then
			trigger(player, profile)
		end
	end)

	CompanyService.RegisterStateProvider(function(player, profile, state)
		state.modifiers = profile.modifiers
		state.eventPending = profile.event ~= nil
	end)
end

-- Người chơi vào lại game giữa lúc đang có sự kiện: mở lại popup
function EventService.OnPlayerLoaded(player, profile)
	local pending = profile.event
	local event = pending and Config.EventById[pending.id]
	if not event then
		profile.event = nil
		return
	end
	local choices = {}
	for i, choice in event.choices do
		local cost = if choice.costDays then scaled(player, choice.costDays, choice.minCost) else nil
		table.insert(choices, { index = i, label = choice.label, cost = cost })
	end
	task.delay(2, function()
		CompanyService.Popup(player, { kind = "Event", emoji = event.emoji, title = event.title, text = event.text, choices = choices })
	end)
end

return EventService
