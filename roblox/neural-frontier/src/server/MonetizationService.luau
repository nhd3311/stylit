-- Kiếm Robux: Game Pass (mua 1 lần) và Developer Product (mua nhiều lần).
-- Quy tắc vàng: CHỈ báo PurchaseGranted sau khi đã lưu data thành công, và nhớ PurchaseId
-- để không cộng đồ 2 lần.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)

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
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
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

local function grantPass(player, passKey)
	if player:GetAttribute(passKey) then
		return
	end
	player:SetAttribute(passKey, true)
	if passKey == "VIP" and player.Character then
		task.spawn(addVipTag, player.Character)
	end
	PlayerService.Refresh(player)
end

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
		for boost, seconds in product.boosts do
			profile.boosts[boost] = math.max(os.time(), profile.boosts[boost] or 0) + seconds
		end
		return true, product.name
	elseif product.kind == "Credits" then
		-- gói Credits tự tăng theo tiến độ: bằng số phút thu thập ở vùng xịn nhất đã mở
		local bestMult = 1
		for _, zone in Config.Zones do
			if profile.level >= zone.level then
				bestMult = zone.dataMult
			end
		end
		local perSecond = PlayerService.GatherPerSecond(player, profile) * bestMult
		local amount = math.max(product.min, math.floor(perSecond * 60 * product.minutes))
		PlayerService.AddCredits(player, amount)
		return true, string.format("%s (+%s credits)", product.name, Config.Short(amount))
	end
	return false, nil
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = player and DataService.Profiles[player]
	if not profile then
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
	local granted, text = grantProduct(player, profile, product)
	if not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService.MarkPurchase(profile, receipt.PurchaseId)
	if not DataService.Save(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	remotes.Notify:FireClient(player, "Thanks for your support! You got: " .. text .. " 💖", "Reward")
	PlayerService.PushState(player)
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
				remotes.Notify:FireClient(player, pass.name .. " activated 🎉", "Reward")
			end
		end
	end)
end

return MonetizationService
