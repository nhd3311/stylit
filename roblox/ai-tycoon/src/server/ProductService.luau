-- Phát triển và ra mắt sản phẩm AI. Mỗi lúc làm 1 sản phẩm (hoặc 1 phiên bản mới):
-- trả token, chờ hết thời gian phát triển, ra mắt thì nhận $ ngay + thu nhập $/giây mãi mãi.
-- Cần tầng Studio Sản Phẩm và nghiên cứu mở khoá tương ứng.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CompanyService = require(script.Parent.CompanyService)
local DataService = require(script.Parent.DataService)

local ProductService = {}

local notify = CompanyService.Notify

local function studioIndex()
	return CompanyService.FloorIndexOf("Studio")
end

local function isUnlocked(profile, productId)
	local researchId = Config.ProductUnlockedBy[productId]
	return researchId == nil or profile.research.done[researchId] == true
end

local function launch(player, profile)
	local dev = profile.dev
	local product = dev and Config.ProductById[dev.id]
	profile.dev = nil
	if not product then
		return
	end
	profile.products[product.id] = dev.version
	local spec = Config.ProductVersion(product, dev.version)
	local bonus = math.floor(spec.launchCash * CompanyService.LaunchMultiplier(player))
	CompanyService.AddCash(player, bonus)
	notify(player, string.format("🚀 Ra mắt %s %s v%d! +%s, thu nhập mới %s/giây", product.emoji, product.name, dev.version, Config.Money(bonus), Config.Money(spec.income * CompanyService.CashMultiplier(player))), "Evolve")
	if dev.version == 1 then
		CompanyService.NotifyAll(string.format("📰 %s Corp vừa ra mắt %s %s!", player.DisplayName, product.emoji, product.name))
	end
	CompanyService.PushState(player)
end

local function start(player, profile, productId)
	local product = type(productId) == "string" and Config.ProductById[productId]
	if not product then
		return
	end
	if not CompanyService.HasFloor(player, profile, studioIndex()) then
		notify(player, "Cần xây tầng 🚀 Studio Sản Phẩm trước đã!", "Open:Build")
		return
	end
	if not isUnlocked(profile, product.id) then
		notify(player, "Phải nghiên cứu công nghệ mở khoá trước 🔬", "Open:Research")
		return
	end
	if profile.dev then
		notify(player, "Studio đang bận làm sản phẩm khác, chờ xíu! ⏳")
		return
	end
	local version = (profile.products[product.id] or 0) + 1
	if version > Config.ProductVersions.Max then
		notify(player, "Sản phẩm này đã lên bản cuối rồi 🔥")
		return
	end
	local spec = Config.ProductVersion(product, version)
	if profile.tokens < spec.devTokens then
		notify(player, string.format("Cần %s 🪙 token để làm %s v%d", Config.Short(spec.devTokens), product.name, version))
		return
	end
	profile.tokens -= spec.devTokens
	profile.dev = { id = product.id, version = version, progress = 0 }
	notify(player, string.format("💻 Bắt đầu phát triển %s %s v%d", product.emoji, product.name, version))
	CompanyService.PushState(player)
end

-- Gọi từ MonetizationService (gói "Ra mắt ngay"). Trả về false nếu không có gì đang làm.
function ProductService.FinishNow(player)
	local profile = DataService.Profiles[player]
	if not profile or not profile.dev then
		return false
	end
	launch(player, profile)
	return true
end

function ProductService.Start()
	CompanyService.RegisterAction("StartProduct", function(player, profile, session, productId)
		start(player, profile, productId)
	end)

	CompanyService.RegisterStateProvider(function(player, profile, state)
		local dev = profile.dev
		local product = dev and Config.ProductById[dev.id]
		local time = if product then Config.ProductVersion(product, dev.version).devTime else 1
		local unlocked = {}
		for _, p in Config.Products do
			unlocked[p.id] = isUnlocked(profile, p.id)
		end
		state.products = {
			versions = profile.products,
			unlocked = unlocked,
			dev = if product then { id = dev.id, version = dev.version } else nil,
			progress = if product then math.clamp(dev.progress / time, 0, 1) else 0,
			remaining = if product then math.max(0, (time - dev.progress) / CompanyService.ResearchSpeed(player, "dev")) else 0,
			hasStudio = CompanyService.HasFloor(player, profile, studioIndex()),
			cashMult = CompanyService.CashMultiplier(player),
			launchMult = CompanyService.LaunchMultiplier(player),
		}
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			for player, profile in DataService.Profiles do
				local dev = profile.dev
				local product = dev and Config.ProductById[dev.id]
				if dev and not product then
					profile.dev = nil
				elseif product and CompanyService.GetLot(player) then
					dev.progress += CompanyService.ResearchSpeed(player, "dev")
					local time = Config.ProductVersion(product, dev.version).devTime
					CompanyService.SetStudioScreen(player, string.format("%s %s v%d\n%d%%", product.emoji, product.name, dev.version, math.floor(math.min(1, dev.progress / time) * 100)))
					if dev.progress >= time then
						launch(player, profile)
						CompanyService.SetStudioScreen(player, "🚀 SẴN SÀNG RA MẮT")
					end
				end
			end
		end
	end)
end

return ProductService
