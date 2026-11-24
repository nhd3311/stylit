-- Sàn chứng khoán: cổ phần 6 công ty công nghệ đối thủ (có trụ sở trong thành phố).
-- Giá đi ngẫu nhiên (log-normal) và bị kéo nhẹ về quanh giá gốc nên không bay mãi lên hay rơi mãi xuống.
-- Thỉnh thoảng có tin tức làm 1 mã nhảy mạnh. Mua/bán bằng $ trong game, phí 1% mỗi lệnh.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CompanyService = require(script.Parent.CompanyService)
local Visuals = require(script.Parent.Visuals)
local WorldService = require(script.Parent.WorldService)

local StockService = {}

local M = Config.Market
local notify = CompanyService.Notify

local prices = {} -- [mã] = giá hiện tại
local history = {} -- [mã] = { giá cũ ... giá mới }
local tickerRows = {}
local remotes
local random = Random.new()

local function gaussian()
	-- Box-Muller
	local u1 = math.max(random:NextNumber(), 1e-9)
	local u2 = random:NextNumber()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

local function round(price)
	return math.floor(price * 100 + 0.5) / 100
end

local function change(id)
	local h = history[id]
	local prev = h[#h - 1] or h[#h]
	return (prices[id] - prev) / prev
end

local function snapshot()
	local changes = {}
	for id in prices do
		changes[id] = change(id)
	end
	return { prices = prices, changes = changes }
end

local function renderTicker()
	for i, stock in Config.Stocks do
		local c = change(stock.id)
		local arrow = if c >= 0 then "<font color='#4CFF7A'>▲" else "<font color='#FF5A5A'>▼"
		tickerRows[i].Text = string.format("%s %s  $%.2f  %s %.1f%%</font>", stock.emoji, stock.id, prices[stock.id], arrow, math.abs(c) * 100)
	end
end

local function step()
	local news
	for _, stock in Config.Stocks do
		local id = stock.id
		local logP = math.log(prices[id])
		local pull = M.Reversion * (math.log(stock.base) - logP)
		logP += pull + stock.vol * gaussian()
		prices[id] = math.max(0.5, round(math.exp(logP)))
	end
	if random:NextNumber() < M.NewsChance then
		local stock = Config.Stocks[random:NextInteger(1, #Config.Stocks)]
		local up = random:NextNumber() < 0.5
		local list = if up then Config.StockNews.up else Config.StockNews.down
		local move = random:NextNumber(0.1, 0.25)
		prices[stock.id] = math.max(0.5, round(prices[stock.id] * (if up then 1 + move else 1 - move)))
		news = string.format("📰 %s %s %s! Cổ phiếu %s %d%%", stock.emoji, stock.name, list[random:NextInteger(1, #list)], if up then "tăng" else "giảm", math.floor(move * 100))
	end
	for id, h in history do
		table.insert(h, prices[id])
		while #h > M.History do
			table.remove(h, 1)
		end
	end
	renderTicker()
	remotes.Market:FireAllClients(snapshot())
	if news then
		CompanyService.NotifyAll(news, "News")
	end
end

-- ================= Lệnh mua/bán =================

local function parseQty(qty)
	if qty == "max" or qty == "all" then
		return qty
	end
	if type(qty) ~= "number" or qty ~= qty or qty < 1 or qty > 1e9 then
		return nil
	end
	return math.floor(qty)
end

local function buy(player, profile, id, qty)
	local price = prices[id]
	qty = parseQty(qty)
	if not price or not qty then
		return
	end
	local unit = price * (1 + M.Fee)
	if qty == "max" or qty == "all" then
		qty = math.floor(profile.cash / unit)
	end
	if qty < 1 then
		notify(player, "Không đủ $ để mua cổ phiếu này 💸")
		return
	end
	local cost = unit * qty
	if profile.cash < cost then
		notify(player, string.format("Cần %s để mua %d cổ phiếu %s", Config.Money(cost), qty, id))
		return
	end
	profile.cash -= cost
	local holding = profile.stocks[id] or { qty = 0, cost = 0 }
	holding.qty += qty
	holding.cost += cost
	profile.stocks[id] = holding
	notify(player, string.format("📈 Đã mua %d %s giá $%.2f", qty, id, price), "Collect")
	CompanyService.PushState(player)
end

local function sell(player, profile, id, qty)
	local price = prices[id]
	local holding = profile.stocks[id]
	qty = parseQty(qty)
	if not price or not qty or not holding or holding.qty < 1 then
		return
	end
	if qty == "max" or qty == "all" then
		qty = holding.qty
	end
	qty = math.min(qty, holding.qty)
	local revenue = price * qty * (1 - M.Fee)
	local costPart = holding.cost * qty / holding.qty
	holding.qty -= qty
	holding.cost -= costPart
	if holding.qty <= 0 then
		profile.stocks[id] = nil
	end
	-- Bán cổ phiếu là đổi tài sản, không tính vào "$ kiếm được" (không làm phồng Điểm Founder)
	profile.cash += revenue
	local pnl = revenue - costPart
	notify(player, string.format("💰 Đã bán %d %s: %s (%s%s)", qty, id, Config.Money(revenue), if pnl >= 0 then "+" else "", Config.Money(pnl)), if pnl >= 0 then "Collect" else nil)
	CompanyService.PushState(player)
end

function StockService.Start(remoteFolder)
	remotes = remoteFolder
	for i, stock in Config.Stocks do
		prices[stock.id] = stock.base
		history[stock.id] = { stock.base }
		-- mỗi mã cổ phiếu có trụ sở thật trên 1 lô đất trong thành phố
		local lotIndex = WorldService.RivalLots[i]
		if lotIndex then
			WorldService.BuildRival(lotIndex, stock.name, stock.emoji, stock.color, 50 + (stock.base ^ 0.5) * 3)
		end
	end

	-- Bảng điện tử ở Sàn Chứng Khoán
	local board = Visuals.Part({
		Name = "StockTicker",
		Size = Vector3.new(36, 16, 1),
		CFrame = WorldService.TickerCFrame,
		Color = Color3.fromRGB(10, 10, 16),
		Material = Enum.Material.SmoothPlastic,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = gui
	local title = Instance.new("TextLabel")
	title.LayoutOrder = 0
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.BuilderSansExtraBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 210, 80)
	title.Text = "📈 BẢNG ĐIỆN TỬ"
	title.Parent = gui
	for i in Config.Stocks do
		local row = Instance.new("TextLabel")
		row.LayoutOrder = i
		row.Size = UDim2.new(1, -20, 0, 48)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.BuilderSansBold
		row.TextScaled = true
		row.RichText = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.fromRGB(230, 230, 240)
		row.Parent = gui
		tickerRows[i] = row
	end
	gui.Parent = board
	board.Parent = workspace
	renderTicker()

	CompanyService.RegisterAction("BuyStock", function(player, profile, session, id, qty)
		buy(player, profile, id, qty)
	end)
	CompanyService.RegisterAction("SellStock", function(player, profile, session, id, qty)
		sell(player, profile, id, qty)
	end)
	CompanyService.RegisterStateProvider(function(player, profile, state)
		state.stocks = profile.stocks
	end)

	-- người mới vào nhận lịch sử giá đầy đủ để vẽ biểu đồ
	Players.PlayerAdded:Connect(function(player)
		task.wait(2)
		remotes.Market:FireClient(player, { prices = prices, changes = snapshot().changes, history = history })
	end)

	task.spawn(function()
		while true do
			task.wait(M.Tick)
			step()
		end
	end)
end

return StockService
