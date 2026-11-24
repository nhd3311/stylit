-- Lịch trong game: ngày/tháng/năm trôi theo tốc độ người chơi chọn (⏸ ▶ ⏩ ⏭).
-- Mỗi ngày trôi qua gọi lần lượt các "day hook" (nhân sự, R&D, xưởng, model...).
-- Thời gian chỉ trôi khi người chơi đang online.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CompanyService = require(script.Parent.CompanyService)
local DataService = require(script.Parent.DataService)

local CalendarService = {}

local C = Config.Calendar
local STEP = 0.2 -- giây giữa 2 lần kiểm tra
local hooks = {}
local progress = {} -- [player] = phần ngày đã trôi (0..1)

-- hook(player, profile, day) chạy mỗi khi sang ngày mới
function CalendarService.RegisterDayHook(hook)
	table.insert(hooks, hook)
end

local function advanceDay(player, profile)
	profile.day += 1
	for _, hook in hooks do
		hook(player, profile, profile.day)
	end
end

-- Tua ngay `days` ngày (gói Robux "Tua nhanh")
function CalendarService.Skip(player, days)
	local profile = DataService.Profiles[player]
	if not profile then
		return
	end
	for _ = 1, days do
		advanceDay(player, profile)
	end
	CompanyService.PushState(player)
end

function CalendarService.Start()
	CompanyService.RegisterAction("SetSpeed", function(player, profile, session, index)
		if type(index) ~= "number" or not C.Speeds[index] then
			return
		end
		if profile.event then
			CompanyService.Notify(player, "Make a decision on the current event first ⚡")
			return
		end
		local fastUnlocked = player:GetAttribute("VIP") == true or player:GetAttribute("TimeMachine") == true
		if index >= C.FastSpeedIndex and not fastUnlocked then
			CompanyService.Notify(player, "x5 speed needs the ⏭️ Time Machine pass or VIP", "Open:Shop")
			return
		end
		profile.speed = index
		CompanyService.PushState(player)
	end)

	task.spawn(function()
		while true do
			task.wait(STEP)
			for player, profile in DataService.Profiles do
				if not CompanyService.IsActive(player) then
					continue
				end
				local speed = C.Speeds[profile.speed] or 1
				if speed <= 0 then
					continue
				end
				progress[player] = (progress[player] or 0) + STEP * speed / C.SecondsPerDay
				local advanced = false
				while progress[player] >= 1 do
					progress[player] -= 1
					advanceDay(player, profile)
					advanced = true
					-- sự kiện vừa tạm dừng thời gian thì dừng luôn
					if (C.Speeds[profile.speed] or 0) <= 0 then
						progress[player] = 0
						break
					end
				end
				if advanced then
					CompanyService.PushState(player)
				end
			end
			for player in progress do
				if not DataService.Profiles[player] then
					progress[player] = nil
				end
			end
		end
	end)
end

return CalendarService
