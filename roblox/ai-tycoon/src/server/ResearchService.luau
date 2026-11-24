-- Cây nghiên cứu (R&D). Mỗi lúc chỉ nghiên cứu 1 công nghệ: trả token, chờ hết thời gian
-- (nhanh hơn nhờ boost / nghiên cứu Tự động hoá), xong thì được hiệu ứng vĩnh viễn trong lượt chơi.
-- Cần tầng Lab R&D.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CompanyService = require(script.Parent.CompanyService)
local DataService = require(script.Parent.DataService)

local ResearchService = {}

local notify = CompanyService.Notify

local function labIndex()
	return CompanyService.FloorIndexOf("Lab")
end

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
	local unlock = node.effect.unlock and Config.ProductById[node.effect.unlock]
	local extra = if unlock then string.format(" Mở khoá sản phẩm %s %s!", unlock.emoji, unlock.name) else ""
	notify(player, string.format("🔬 Nghiên cứu xong %s %s!%s", node.emoji, node.name, extra), "Evolve")
	CompanyService.Refresh(player)
end

local function start(player, profile, nodeId)
	local node = type(nodeId) == "string" and Config.ResearchById[nodeId]
	if not node then
		return
	end
	if not CompanyService.HasFloor(player, profile, labIndex()) then
		notify(player, "Cần xây tầng 🔬 Lab R&D trước đã!", "Open:Build")
		return
	end
	if profile.research.done[node.id] then
		notify(player, "Cái này nghiên cứu xong rồi nha ✅")
		return
	end
	if profile.research.current then
		notify(player, "Lab đang bận nghiên cứu cái khác, chờ xíu! ⏳")
		return
	end
	if not requirementsMet(profile, node) then
		notify(player, "Phải nghiên cứu các công nghệ trước đó đã 🔒")
		return
	end
	if profile.tokens < node.cost then
		notify(player, string.format("Cần %s 🪙 token để nghiên cứu %s", Config.Short(node.cost), node.name))
		return
	end
	profile.tokens -= node.cost
	profile.research.current = { id = node.id, progress = 0 }
	notify(player, string.format("🔬 Bắt đầu nghiên cứu %s %s", node.emoji, node.name))
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

	CompanyService.RegisterStateProvider(function(player, profile, state)
		local current = profile.research.current
		local node = current and Config.ResearchById[current.id]
		state.research = {
			done = profile.research.done,
			current = if node then current.id else nil,
			progress = if node then math.clamp(current.progress / node.time, 0, 1) else 0,
			remaining = if node then math.max(0, (node.time - current.progress) / CompanyService.ResearchSpeed(player, "research")) else 0,
			hasLab = CompanyService.HasFloor(player, profile, labIndex()),
		}
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			for player, profile in DataService.Profiles do
				local current = profile.research.current
				local node = current and Config.ResearchById[current.id]
				if current and not node then
					profile.research.current = nil -- nghiên cứu đã bị xoá khỏi Config
				elseif node and CompanyService.GetLot(player) then
					current.progress += CompanyService.ResearchSpeed(player, "research")
					if current.progress >= node.time then
						complete(player, profile)
					end
				end
			end
		end
	end)
end

return ResearchService
