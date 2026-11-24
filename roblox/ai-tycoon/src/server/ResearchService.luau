-- Cây nghiên cứu (R&D). Mỗi lúc chỉ nghiên cứu 1 công nghệ, chạy bằng điểm R&D mỗi ngày
-- (từ Founder + nhà nghiên cứu). Có công nghệ phải tới đúng năm mới được nghiên cứu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CalendarService = require(script.Parent.CalendarService)
local CompanyService = require(script.Parent.CompanyService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local StaffService = require(script.Parent.StaffService)

local ResearchService = {}

local notify = CompanyService.Notify

local function requirementsMet(profile, node)
	for _, req in node.requires do
		if not profile.research.done[req] then
			return false
		end
	end
	return true
end

local function complete(player, profile)
	local current = profile.research.current
	local node = current and Config.ResearchById[current.id]
	profile.research.current = nil
	if not node then
		return
	end
	profile.research.done[node.id] = true
	notify(player, string.format("🔬 Research complete: %s %s!", node.emoji, node.name), "Evolve")
	CompanyService.PushState(player)
end

local function start(player, profile, nodeId)
	local node = type(nodeId) == "string" and Config.ResearchById[nodeId]
	if not node then
		return
	end
	if profile.research.done[node.id] then
		notify(player, "Already researched ✅")
		return
	end
	if profile.research.current then
		notify(player, "Your lab is busy with another project ⏳")
		return
	end
	if Config.YearOf(profile.day) < node.year then
		notify(player, string.format("This tech won't exist until %d 📅", node.year))
		return
	end
	if not requirementsMet(profile, node) then
		notify(player, "Research the earlier tech first 🔒")
		return
	end
	profile.research.current = { id = node.id, progress = 0 }
	notify(player, string.format("🔬 Started researching %s %s", node.emoji, node.name))
	CompanyService.PushState(player)
end

-- Gọi từ MonetizationService (gói "Xong ngay nghiên cứu"). Trả về false nếu không có gì đang chạy.
function ResearchService.FinishNow(player)
	local profile = DataService.Profiles[player]
	if not profile or not profile.research.current then
		return false
	end
	complete(player, profile)
	return true
end

function ResearchService.Start()
	CompanyService.RegisterAction("StartResearch", function(player, profile, session, nodeId)
		start(player, profile, nodeId)
	end)

	CalendarService.RegisterDayHook(function(player, profile, day)
		local current = profile.research.current
		if current then
			local node = Config.ResearchById[current.id]
			if not node then
				profile.research.current = nil
			else
				current.progress += StaffService.Points(player, profile, "Research")
				if current.progress >= node.cost then
					complete(player, profile)
				end
			end
		end
		-- sang năm mới: báo các công nghệ vừa mở
		if day % 360 == 0 then
			local year = Config.YearOf(day)
			local names = {}
			for _, node in Config.Research do
				if node.year == year then
					table.insert(names, node.emoji .. " " .. node.name)
				end
			end
			local extra = if #names > 0 then " New tech: " .. table.concat(names, ", ") else ""
			notify(player, string.format("🎆 Happy New Year %d!%s", year, extra), "Evolve")
		end
	end)

	CompanyService.RegisterStateProvider(function(player, profile, state)
		local current = profile.research.current
		local node = current and Config.ResearchById[current.id]
		local rp = StaffService.Points(player, profile, "Research")
		state.research = {
			current = if node then current.id else nil,
			progress = if node then math.clamp(current.progress / node.cost, 0, 1) else 0,
			eta = if node and rp > 0 then math.ceil((node.cost - current.progress) / rp) else 0,
			perDay = rp,
		}
	end)
end

return ResearchService
