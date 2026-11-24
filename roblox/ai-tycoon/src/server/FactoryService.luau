-- Xưởng sản xuất ⚡ compute (dùng để train model). Xây xưởng → mua dây chuyền → nâng cấp
-- dây chuyền theo linh kiện đã nghiên cứu (CPU → GPU → TPU → 3nm → Lượng tử).
-- Kỹ sư làm tăng sản lượng toàn xưởng.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CalendarService = require(script.Parent.CalendarService)
local CompanyService = require(script.Parent.CompanyService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local StaffService = require(script.Parent.StaffService)
local Visuals = require(script.Parent.Visuals)
local WorldService = require(script.Parent.WorldService)

local FactoryService = {}

local F = Config.Factory
local notify = CompanyService.Notify

local origin -- tâm lô đất xưởng
local hall -- Folder đồ họa xưởng

function FactoryService.ComputePerDay(player, profile)
	if not profile.factory.built then
		return 0
	end
	local rate = 0
	for _, tier in profile.factory.lines do
		rate += Config.FactoryTiers[tier].rate
	end
	return rate * (1 + StaffService.SkillSum(profile, "Engineer") * F.EngineerBonus)
end

-- Lấy `amount` compute ra khỏi kho (thiếu thì lấy hết). Trả về số lấy được.
function FactoryService.Take(profile, amount)
	local taken = math.min(profile.factory.compute, amount)
	profile.factory.compute -= taken
	return taken
end

local function render(profile)
	if hall then
		hall:Destroy()
		hall = nil
	end
	if not profile or not profile.factory.built then
		return
	end
	hall = Instance.new("Folder")
	hall.Name = "Factory"
	local base = origin * CFrame.new(0, 0.6, -18)
	Visuals.BuildFloorShell(hall, base, 64, 52, 16, true, Color3.fromRGB(255, 170, 40))
	Visuals.BuildRoof(hall, origin * CFrame.new(0, 15.6, -18), 64, 52, Color3.fromRGB(255, 170, 40)).Text = "🏭 XƯỞNG COMPUTE"
	for i, tier in profile.factory.lines do
		local t = Config.FactoryTiers[tier]
		local machine = Visuals.BuildFactoryLine(hall, base * CFrame.new(4, 0, -18 + (i - 1) * 11), t.color, 36)
		Visuals.Label(machine, string.format("%s %s • %s⚡/ngày", t.emoji, t.name, Config.Short(t.rate)), UDim2.fromScale(12, 2), Vector3.new(0, 5, 0))
	end
	hall.Parent = workspace:WaitForChild("Lots")
end

function FactoryService.Render(player)
	render(DataService.Profiles[player])
end

function FactoryService.Clear()
	render(nil)
end

function FactoryService.Start()
	origin = WorldService.LotOrigin(WorldService.FactoryLot)
	-- sân xưởng luôn có, kể cả lúc chưa xây
	local yard = Visuals.Part({
		Name = "FactoryYard",
		Size = Vector3.new(85, 0.6, 105),
		CFrame = origin * CFrame.new(0, -0.15, 0),
		Color = Color3.fromRGB(150, 150, 155),
		Material = Enum.Material.Concrete,
	})
	local sign = Visuals.Part({
		Name = "FactorySign",
		Size = Vector3.new(1, 7, 1),
		CFrame = origin * CFrame.new(-30, 3.5, 40),
		Color = Visuals.Colors.metal,
		Material = Enum.Material.Metal,
		Parent = yard,
	})
	Visuals.Label(sign, "🏭 Đất xây xưởng", UDim2.fromScale(14, 3), Vector3.new(0, 6, 0))
	yard.Parent = workspace:WaitForChild("Lots")

	CompanyService.RegisterAction("BuildFactory", function(player, profile)
		if profile.factory.built then
			return
		end
		if profile.building < F.RequireBuilding then
			notify(player, "Cần lên " .. Config.Buildings[F.RequireBuilding].name .. " mới xây được xưởng 🏭")
			return
		end
		if not CompanyService.Spend(player, F.BuildPrice, "xây xưởng") then
			return
		end
		profile.factory.built = true
		profile.factory.lines = { 1 }
		notify(player, "🏭 Xưởng đã xây xong với 1 dây chuyền CPU!", "Evolve")
		render(profile)
		CompanyService.PushState(player)
	end)

	CompanyService.RegisterAction("BuyLine", function(player, profile)
		local count = #profile.factory.lines
		local price = F.LinePrices[count + 1]
		if not profile.factory.built or not price then
			notify(player, "Xưởng đã đủ dây chuyền rồi 🔥")
			return
		end
		if not CompanyService.Spend(player, price, "mua dây chuyền mới") then
			return
		end
		table.insert(profile.factory.lines, 1)
		notify(player, "⚙️ Đã lắp thêm dây chuyền mới!", "Collect")
		render(profile)
		CompanyService.PushState(player)
	end)

	CompanyService.RegisterAction("UpgradeLine", function(player, profile, session, index)
		local tier = type(index) == "number" and profile.factory.lines[index]
		if not tier then
			return
		end
		local nextTier = Config.FactoryTiers[tier + 1]
		if not nextTier then
			notify(player, "Dây chuyền này đã max cấp ⚛️")
			return
		end
		if nextTier.research and not profile.research.done[nextTier.research] then
			notify(player, "Cần nghiên cứu " .. Config.ResearchById[nextTier.research].name .. " trước 🔬", "Open:Research")
			return
		end
		if not CompanyService.Spend(player, nextTier.price, "nâng cấp lên " .. nextTier.name) then
			return
		end
		profile.factory.lines[index] = tier + 1
		notify(player, string.format("%s Dây chuyền %d lên %s!", nextTier.emoji, index, nextTier.name), "Evolve")
		render(profile)
		CompanyService.PushState(player)
	end)

	CalendarService.RegisterDayHook(function(player, profile)
		profile.factory.compute += FactoryService.ComputePerDay(player, profile)
	end)

	CompanyService.RegisterStateProvider(function(player, profile, state)
		state.factory = {
			built = profile.factory.built,
			lines = profile.factory.lines,
			compute = profile.factory.compute,
			perDay = FactoryService.ComputePerDay(player, profile),
		}
	end)
end

return FactoryService
