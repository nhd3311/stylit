-- Phần kiếm Robux: Game Pass (mua 1 lần, dùng mãi) và Developer Product (mua nhiều lần).
-- Quy tắc vàng: CHỈ báo PurchaseGranted sau khi đã lưu data thành công,
-- nếu không người chơi có thể mất Robux mà không nhận được đồ.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local FarmService = require(script.Parent.FarmService)

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

local function grantPass(player, passKey)
	if player:GetAttribute(passKey) then
		return
	end
	player:SetAttribute(passKey, true)
	if passKey == "VIP" and player.Character then
		task.spawn(addVipTag, player.Character)
	end
	FarmService.Refresh(player)
end

-- Gọi khi người chơi vào game, TRƯỚC khi FarmService dựng farm
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
		local current = math.max(os.time(), profile.boosts[product.boost] or 0)
		profile.boosts[product.boost] = current + product.duration
	elseif product.kind == "Coins" then
		profile.coins += product.amount
	elseif product.kind == "InstantGrow" then
		FarmService.InstantGrow(player)
	else
		return false
	end
	return true
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

	if not grantProduct(player, profile, product) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService.MarkPurchase(profile, receipt.PurchaseId)

	if not DataService.Save(player) then
		-- Đồ đã cộng trong RAM + đã đánh dấu, lần gọi lại sẽ trả Granted ở trên
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	remotes.Notify:FireClient(player, "Cảm ơn đã ủng hộ! Đã nhận: " .. product.name .. " 💖")
	FarmService.PushState(player)
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
