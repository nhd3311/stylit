-- Phần kiếm Robux: Game Pass (mua 1 lần, dùng mãi) và Developer Product (mua nhiều lần).
-- Quy tắc vàng: CHỈ báo PurchaseGranted sau khi đã lưu data thành công,
-- nếu không người chơi có thể mất Robux mà không nhận được đồ.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local CompanyService = require(script.Parent.CompanyService)
local ProductService = require(script.Parent.ProductService)
local ResearchService = require(script.Parent.ResearchService)

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
	if not player:GetAttribute("StarterPack") or not profile or profile.starterClaimed or not CompanyService.GetLot(player) then
		return
	end
	local pack = Config.StarterPack
	local targetTier = Config.GpuTier[pack.gpu]
	local installed = 0
	for i, slot in Config.RackSlots do
		if not CompanyService.HasFloor(player, profile, slot.floor) then
			continue
		end
		if installed >= pack.gpuCount then
			break
		end
		local key = tostring(i)
		local rack = profile.racks[key]
		if not rack or Config.GpuTier[rack.gpu] < targetTier then
			profile.racks[key] = { gpu = pack.gpu, buffer = if rack then rack.buffer else 0 }
			installed += 1
		end
	end
	CompanyService.AddCash(player, pack.cash)
	addBoosts(profile, pack.boosts)
	profile.starterClaimed = true
	task.spawn(DataService.Save, player)

	remotes.Notify:FireClient(player, "🎁 Đã mở Gói Khởi Nghiệp! GPU mới, tiền và Mega Boost đã vào công ty 🚀", "Evolve")
	CompanyService.RenderBuilding(player)
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
	end
	CompanyService.Refresh(player)
end

-- Gọi SAU khi CompanyService đã dựng tòa nhà (Gói Khởi Nghiệp cần kệ để lắp GPU)
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
				warn("[Monetization] Không kiểm tra được pass", passKey, owns)
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
	elseif product.kind == "TimeWarp" then
		local cash, tokens = CompanyService.TimeWarp(player, product.hours)
		return true, string.format("%s (+%s, +%s 🪙)", product.name, Config.Money(cash), Config.Short(tokens))
	elseif product.kind == "Instant" then
		local finish = if product.target == "Research" then ResearchService.FinishNow else ProductService.FinishNow
		if finish(player) then
			return true, product.name
		end
		-- không có gì đang chạy: tặng lại bằng boost R&D để người chơi không mất Robux
		addBoosts(profile, { Research = 30 * 60 })
		return true, product.name .. " (chưa có gì đang chạy nên đổi thành x2 R&D 30 phút)"
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
		warn("[Monetization] ProductId lạ, chưa có trong Config:", receipt.ProductId)
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

	remotes.Notify:FireClient(player, "Cảm ơn đã ủng hộ! Đã nhận: " .. grantedText .. " 💖")
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
				remotes.Notify:FireClient(player, "Đã kích hoạt " .. pass.name .. " 🎉")
			end
		end
	end)
end

return MonetizationService
