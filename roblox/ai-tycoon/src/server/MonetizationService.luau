-- Phần kiếm Robux: Game Pass (mua 1 lần, dùng mãi) và Developer Product (mua nhiều lần).
-- Quy tắc vàng: CHỈ báo PurchaseGranted sau khi đã lưu data thành công,
-- nếu không người chơi có thể mất Robux mà không nhận được đồ.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local CalendarService = require(script.Parent.CalendarService)
local CompanyService = require(script.Parent.CompanyService)
local ModelService = require(script.Parent.ModelService)
local ResearchService = require(script.Parent.ResearchService)
local StaffService = require(script.Parent.StaffService)

local MonetizationService = {}

local remotes

local function addVipTag(character)
	local head = character:WaitForChild("Head", 10)
	if not head or head:FindFirstChild("VipTag") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "VipTag"
	gui.Size = UDim2.fromScale(4, 1)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.BuilderSansExtraBold
	label.TextColor3 = Color3.fromRGB(255, 215, 0)
	label.TextStrokeTransparency = 0
	label.Text = "⭐ VIP"
	label.Parent = gui
	gui.Parent = head
end

local function addBoosts(profile, boosts)
	for boost, seconds in boosts do
		local current = math.max(os.time(), profile.boosts[boost] or 0)
		profile.boosts[boost] = current + seconds
	end
end

-- Gói Khởi Nghiệp là Game Pass nhưng quà chỉ phát 1 lần (đánh dấu trong data)
local function grantStarterPack(player)
	local profile = DataService.Profiles[player]
	if not player:GetAttribute("StarterPack") or not profile or profile.starterClaimed or not CompanyService.IsActive(player) then
		return
	end
	local pack = Config.StarterPack
	local capacity = Config.Capacity(profile.building)
	local seats = math.min(pack.workstations, capacity - profile.workstations)
	profile.workstations += seats
	-- hết chỗ kê bàn thì đổi phần bàn thiếu ra tiền
	local cash = pack.cash + (pack.workstations - seats) * Config.WorkstationPrice
	CompanyService.AddCash(player, cash)
	local hired = StaffService.AddStaff(player, profile, "Dev", pack.devSkill)
	if not hired then
		CompanyService.AddCash(player, Config.Salary(pack.devSkill, profile.day) * 6)
	end
	profile.starterClaimed = true
	task.spawn(DataService.Save, player)

	remotes.Notify:FireClient(player, "🎁 Starter Pack opened! Cash, desks and a skilled engineer just joined your company 🚀", "Evolve")
	CompanyService.RenderSeats(player)
	CompanyService.PushState(player)
end

local function grantPass(player, passKey)
	if player:GetAttribute(passKey) then
		return
	end
	player:SetAttribute(passKey, true)
	if passKey == "VIP" and player.Character then
		task.spawn(addVipTag, player.Character)
	elseif passKey == "StarterPack" then
		grantStarterPack(player)
	elseif passKey == "GoldenOffice" then
		CompanyService.RenderBuilding(player) -- đổi sang nội thất vàng
	end
	CompanyService.PushState(player)
end

-- Gọi SAU khi CompanyService đã dựng tòa nhà (Gói Khởi Nghiệp cần chỗ để kê bàn)
function MonetizationService.AfterLoaded(player)
	grantStarterPack(player)
end

-- Gọi khi người chơi vào game, TRƯỚC khi CompanyService dựng tòa nhà
function MonetizationService.LoadPasses(player)
	for passKey, pass in Config.GamePasses do
		if pass.id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and owns then
				player:SetAttribute(passKey, true)
			elseif not ok then
				warn("[Monetization] Could not check pass", passKey, owns)
			end
		end
	end
	player.CharacterAdded:Connect(function(character)
		if player:GetAttribute("VIP") then
			addVipTag(character)
		end
	end)
	if player.Character and player:GetAttribute("VIP") then
		task.spawn(addVipTag, player.Character)
	end
end

local function grantProduct(player, profile, product)
	if product.kind == "Boost" then
		addBoosts(profile, product.boosts)
		return true, product.name
	elseif product.kind == "Hype" then
		profile.viral += 1
		return true, product.name
	elseif product.kind == "Skip" then
		local before = profile.cash
		CalendarService.Skip(player, product.days)
		return true, string.format("%s (%s%s)", product.name, if profile.cash >= before then "+" else "", Config.Money(profile.cash - before))
	elseif product.kind == "Instant" then
		local finish = if product.target == "Research" then ResearchService.FinishNow else ModelService.FinishNow
		if finish(player) then
			return true, product.name
		end
		-- không có gì đang chạy: đổi thành boost năng suất để người chơi không mất Robux
		addBoosts(profile, { Work = 30 * 60 })
		return true, product.name .. " (nothing was running, so you got x2 staff output for 30 min instead)"
	elseif product.kind == "Funding" then
		local cash = math.max(product.minCash, math.floor(ModelService.RevenuePerDay(player) * product.cashDays))
		CompanyService.AddCash(player, cash)
		return true, string.format("%s (+%s)", product.name, Config.Money(cash))
	elseif product.kind == "Legend" then
		-- vai trò đang ít người nhất; hết bàn thì kê thêm 1 bàn nếu còn chỗ trong tòa nhà
		local counts = {}
		for _, role in Config.RoleOrder do
			counts[role] = 0
		end
		for _, staff in profile.staff do
			counts[staff.role] += 1
		end
		local role = Config.RoleOrder[1]
		for _, r in Config.RoleOrder do
			if counts[r] < counts[role] then
				role = r
			end
		end
		if profile.workstations - 1 - #profile.staff <= 0 and profile.workstations < Config.Capacity(profile.building) then
			profile.workstations += 1
		end
		if StaffService.AddStaff(player, profile, role, Config.Staff.LegendSkill) then
			CompanyService.RenderSeats(player)
			return true, string.format("%s (%s %s)", product.name, Config.Roles[role].emoji, Config.Roles[role].name)
		end
		-- tòa nhà hết chỗ: đổi ra tiền bằng 1 năm lương của huyền thoại
		local cash = Config.Salary(Config.Staff.LegendSkill, profile.day) * 12
		CompanyService.AddCash(player, cash)
		return true, string.format("%s (office full, so you got %s instead)", product.name, Config.Money(cash))
	elseif product.kind == "Shield" then
		profile.shields += 1
		return true, product.name
	end
	return false, nil
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = player and DataService.Profiles[player]
	if not profile then
		-- Người chơi đã thoát hoặc chưa tải xong data: Roblox sẽ gọi lại lần sau
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if DataService.HasProcessedPurchase(profile, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local key = Config.DevProductById[receipt.ProductId]
	local product = key and Config.DevProducts[key]
	if not product then
		warn("[Monetization] Unknown ProductId, not in Config:", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local granted, grantedText = grantProduct(player, profile, product)
	if not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService.MarkPurchase(profile, receipt.PurchaseId)

	if not DataService.Save(player) then
		-- Đồ đã cộng trong RAM + đã đánh dấu, lần gọi lại sẽ trả Granted ở trên
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	remotes.Notify:FireClient(player, "Thanks for your support! You got: " .. grantedText .. " 💖")
	CompanyService.PushState(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Start(remoteFolder)
	remotes = remoteFolder
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for passKey, pass in Config.GamePasses do
			if pass.id == passId then
				grantPass(player, passKey)
				remotes.Notify:FireClient(player, pass.name .. " activated 🎉")
			end
		end
	end)
end

return MonetizationService
