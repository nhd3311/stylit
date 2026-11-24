-- Chuỗi mục tiêu (Config.Goals): dẫn người chơi từ Garage tới Global HQ, xong mỗi mục tiêu có thưởng $.
-- Kiểm tra mỗi ngày game và mỗi lần gửi State (để mục tiêu mua sắm xong là thấy liền).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CalendarService = require(script.Parent.CalendarService)
local CompanyService = require(script.Parent.CompanyService)
local Config = require(ReplicatedStorage.Shared.Config)
local ModelService = require(script.Parent.ModelService)

local GoalService = {}

-- Mỗi điều kiện trả về (đã xong?, tiến độ 0..1)
local checks = {
	research = function(_, profile, goal)
		return profile.research.done[goal.target] == true, 0
	end,
	devStarted = function(_, profile)
		return profile.dev ~= nil or profile.pending ~= nil or (profile.launchCount or 0) > 0, 0
	end,
	launches = function(_, profile, goal)
		local n = profile.launchCount or 0
		return n >= goal.target, n / goal.target
	end,
	workstations = function(_, profile, goal)
		return profile.workstations >= goal.target, profile.workstations / goal.target
	end,
	staff = function(_, profile, goal)
		return #profile.staff >= goal.target, #profile.staff / goal.target
	end,
	party = function(_, profile)
		return profile.lastParty >= 0, 0
	end,
	earned = function(_, profile, goal)
		return profile.runEarned >= goal.target, profile.runEarned / goal.target
	end,
	building = function(_, profile, goal)
		return profile.building >= goal.target, 0
	end,
	factory = function(_, profile)
		return profile.factory.built, 0
	end,
	sizeLaunched = function(_, profile, goal)
		return (profile.maxSize or 0) >= goal.target, 0
	end,
	bestScore = function(_, profile, goal)
		return (profile.bestScore or 0) >= goal.target, (profile.bestScore or 0) / goal.target
	end,
	market = function(_, profile, goal)
		return profile.markets[goal.target] == true, 0
	end,
	arenaRank = function(player, profile, goal)
		if (profile.launchCount or 0) == 0 then
			return false, 0
		end
		return ModelService.ArenaRank(player) <= goal.target, 0
	end,
	typeLaunched = function(_, profile, goal)
		return (profile.typesLaunched or {})[goal.target] == true, 0
	end,
}

local function check(player, profile)
	local goal = Config.Goals[profile.goal]
	-- có thể xong nhiều mục tiêu liền một lúc
	while goal do
		local done = checks[goal.check](player, profile, goal)
		if not done then
			return
		end
		CompanyService.AddCash(player, goal.reward)
		CompanyService.Notify(player, string.format("🎯 Goal complete: %s! +%s", goal.text, Config.Money(goal.reward)), "Evolve")
		profile.goal += 1
		goal = Config.Goals[profile.goal]
	end
end

function GoalService.Start()
	CalendarService.RegisterDayHook(function(player, profile)
		check(player, profile)
	end)
	CompanyService.RegisterStateProvider(function(player, profile, state)
		check(player, profile)
		local goal = Config.Goals[profile.goal]
		if goal then
			local _, progress = checks[goal.check](player, profile, goal)
			state.goal = { index = profile.goal, total = #Config.Goals, text = goal.text, reward = goal.reward, progress = math.clamp(progress or 0, 0, 1) }
		else
			state.goal = nil
		end
	end)
end

return GoalService
