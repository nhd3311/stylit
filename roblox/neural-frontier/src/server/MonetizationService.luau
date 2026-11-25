-- Kiếm Robux: Game Pass (mua 1 lần) và Developer Product (mua nhiều lần, gồm Neon Capsule).
-- Quy tắc vàng: CHỈ báo PurchaseGranted sau khi đã lưu data thành công, và nhớ PurchaseId
-- để không cộng đồ 2 lần.
-- Luật Roblox về vật phẩm ngẫu nhiên trả tiền (capsule): luôn hiện tỉ lệ rơi, và người chơi ở
-- nơi bị cấm (PolicyService) thì ẩn mọi món có paidRandom = true.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local GameAnalytics = require(script.Parent.AnalyticsService)
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
	-- Không đọc được chính sách thì coi như bị cấm cho an toàn (trừ khi đang thử trong Studio)
	local policyOk, policy = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	local restricted
	if policyOk and policy then
		restricted = policy.ArePaidRandomItemsRestricted == true
	else
		restricted = not RunService:IsStudio()
		warn("[Monetization] Không đọc được PolicyService", policy)
	end
	player:SetAttribute("PaidRandomRestricted", restricted)
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
		GameAnalytics.Source(player, amount, profile.credits, "IAP", product.name)
		return true, string.format("%s (+%s credits)", product.name, Config.Short(amount))
	elseif product.kind == "Capsule" then
		local capsule = Config.CapsuleById[product.capsule]
		if not capsule then
			return false, nil
		end
		-- đồ đã trả tiền: cho vượt giới hạn kho bot để không mất lượt mua
		PlayerService.Hatch(player, profile, capsule, product.count)
		return true, product.name
	elseif product.kind == "ServerBoost" then
		-- bật cho cả server; mua chồng thì cộng dồn thời gian
		local key = "Server" .. product.boost .. "Until"
		workspace:SetAttribute(key, math.max(os.time(), workspace:GetAttribute(key) or 0) + product.seconds)
		for _, other in Players:GetPlayers() do
			remotes.Notify:FireClient(other, string.format("🌍 %s activated %s for EVERYONE! Thank you! 💖", player.DisplayName, product.name), "Announce")
			PlayerService.PushState(other)
		end
		return true, product.name
	elseif product.kind == "Bundle" then
		-- gói cố định (không ngẫu nhiên): bot chắc chắn + credits + boost
		local bot = product.bot and Config.BotById[product.bot]
		if bot then
			local isNew = not profile.discovered[bot.id]
			profile.discovered[bot.id] = true
			table.insert(profile.bots, { type = bot.id, level = 1 })
			remotes.Hatch:FireClient(player, "Gift", { { id = bot.id, new = isNew } })
		end
		if product.credits then
			PlayerService.AddCredits(player, product.credits)
			GameAnalytics.Source(player, product.credits, profile.credits, "IAP", product.name)
		end
		for boost, seconds in product.boosts or {} do
			profile.boosts[boost] = math.max(os.time(), profile.boosts[boost] or 0) + seconds
		end
		if product.once then
			profile.starterPack = true
		end
		PlayerService.Refresh(player)
		return true, product.name
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
