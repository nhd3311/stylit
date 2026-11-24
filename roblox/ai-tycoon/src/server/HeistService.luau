-- Phi vụ đánh cắp dữ liệu.
-- Két ở sảnh mỗi tòa nhà tự sinh "ổ dữ liệu" (giá trị = vài chục giây thu nhập $ của chủ nhà).
--   * Chủ tòa nhà bấm E ở két (trong sảnh) để thu ổ thành $.
--   * Người khác giữ E ở két để trộm 1 ổ, rồi ôm chạy về Máy thu token ở sảnh tòa nhà mình.
--   * Đang ôm ổ thì chạy chậm. Chủ nhà đứng sát trộm là lấy lại được, trộm chết cũng rơi lại.
--   * Nhà đang bật khiên, nhà của người mới (AI dưới NewbieLevel) và két vừa bị trộm thì không trộm được.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local CompanyService = require(script.Parent.CompanyService)
local Visuals = require(script.Parent.Visuals)

local H = Config.Heist
local DRIVE_COLOR = Color3.fromRGB(0, 230, 255)

local HeistService = {}

local vaults = {} -- [slot] = { part, label, shield, driveParts, drives = {giá trị...}, timer, lastStolen }
local carrying = {} -- [thief] = { items = { { owner = Player, value = number } }, visuals = {}, conns = {} }

local notify = CompanyService.Notify

local function isMasterThief(player)
	return player:GetAttribute("MasterThief") == true
end

local function shieldLeft(profile)
	return math.max(0, (profile.boosts.Shield or 0) - os.time())
end

local function humanoidOf(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- ================= Két =================

local function renderVault(slot)
	local vault = vaults[slot]
	local owner = slot.owner
	local profile = owner and DataService.Profiles[owner]

	for i, drivePart in vault.driveParts do
		drivePart.Transparency = if i <= #vault.drives then 0 else 1
	end

	local shielded = profile and shieldLeft(profile) > 0
	vault.shield.Transparency = if shielded then 0.55 else 1

	if not profile then
		vault.label.Text = "💾 Két dữ liệu"
		return
	end
	local total = 0
	for _, value in vault.drives do
		total += value
	end
	local status = ""
	if shielded then
		local left = shieldLeft(profile)
		status = string.format("\n<font color='#7FDBFF'>🛡️ Khiên %d:%02d</font>", left // 60, left % 60)
	elseif profile.ai.level < H.NewbieLevel then
		status = "\n<font color='#AAAAAA'>🐣 Công ty người mới</font>"
	end
	vault.label.Text = string.format("💾 %d/%d • %s%s", #vault.drives, H.MaxDrives, Config.Money(total), status)
end

local function onCollect(player, slot)
	local vault = vaults[slot]
	if slot.owner ~= player or #vault.drives == 0 then
		return
	end
	local total = 0
	for _, value in vault.drives do
		total += value
	end
	table.clear(vault.drives)
	CompanyService.AddCash(player, total)
	notify(player, "Thu dữ liệu +" .. Config.Money(total) .. " 💾", "Collect")
	renderVault(slot)
	CompanyService.PushState(player)
end

-- ================= Ôm ổ dữ liệu =================

local function refreshCarrier(thief)
	local data = carrying[thief]
	local humanoid = humanoidOf(thief)
	for _, part in data.visuals do
		part:Destroy()
	end
	table.clear(data.visuals)

	local root = rootOf(thief)
	if root then
		for i = 1, #data.items do
			local drive = Visuals.Part({
				Name = "StolenDrive",
				Anchored = false,
				CanCollide = false,
				Massless = true,
				Size = Vector3.new(1.6, 1.6, 0.6),
				Color = DRIVE_COLOR,
				Material = Enum.Material.Neon,
			})
			drive.CFrame = root.CFrame * CFrame.new(0, 0.6 + (i - 1) * 1.8, 1.1)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = drive
			weld.Parent = drive
			Visuals.Light(drive, DRIVE_COLOR, 10, 2)
			drive.Parent = thief.Character
			table.insert(data.visuals, drive)
		end
	end

	if humanoid then
		local slow = #data.items > 0 and not isMasterThief(thief)
		humanoid.WalkSpeed = if slow then H.CarrySpeed else H.NormalSpeed
	end
	if #data.items == 0 then
		for _, conn in data.conns do
			conn:Disconnect()
		end
		carrying[thief] = nil
	end
	CompanyService.PushState(thief)
end

-- Trả các ổ của `owner` (nil = tất cả) từ tay trộm về két chủ cũ
local function returnDrives(thief, owner)
	local data = carrying[thief]
	if not data then
		return 0
	end
	local returned = 0
	for i = #data.items, 1, -1 do
		local item = data.items[i]
		if owner == nil or item.owner == owner then
			table.remove(data.items, i)
			returned += 1
			local slot = CompanyService.GetLot(item.owner)
			local vault = slot and vaults[slot]
			if vault and #vault.drives < H.MaxDrives then
				table.insert(vault.drives, item.value)
				renderVault(slot)
			end
		end
	end
	refreshCarrier(thief)
	return returned
end

local function onSteal(thief, slot)
	local vault = vaults[slot]
	local owner = slot.owner
	local ownerProfile = owner and DataService.Profiles[owner]
	if not ownerProfile or owner == thief or not CompanyService.GetLot(thief) then
		return
	end
	if shieldLeft(ownerProfile) > 0 then
		notify(thief, "Công ty này đang bật khiên 🛡️ Thử nhà khác đi!")
		return
	end
	if ownerProfile.ai.level < H.NewbieLevel then
		notify(thief, "Tha cho người mới đi bạn ơi 🐣")
		return
	end
	if #vault.drives == 0 then
		notify(thief, "Két trống trơn rồi 😢")
		return
	end
	local cooldown = H.StealCooldown - (os.clock() - vault.lastStolen)
	if cooldown > 0 then
		notify(thief, string.format("Két vừa bị trộm, chờ %ds nữa", math.ceil(cooldown)))
		return
	end
	local data = carrying[thief]
	local maxCarry = if isMasterThief(thief) then H.MasterMaxCarry else H.MaxCarry
	if data and #data.items >= maxCarry then
		notify(thief, "Tay đầy rồi! Mang về Máy thu token trước đã 🏃")
		return
	end

	local value = table.remove(vault.drives)
	vault.lastStolen = os.clock()
	if not data then
		data = { items = {}, visuals = {}, conns = {} }
		carrying[thief] = data
		-- chết hoặc respawn thì ổ rơi về két chủ cũ
		local function drop()
			returnDrives(thief, nil)
		end
		local humanoid = humanoidOf(thief)
		if humanoid then
			table.insert(data.conns, humanoid.Died:Connect(drop))
		end
		table.insert(data.conns, thief.CharacterRemoving:Connect(drop))
	end
	table.insert(data.items, { owner = owner, value = value })
	refreshCarrier(thief)
	renderVault(slot)

	notify(thief, "🕵️ Trộm được ổ dữ liệu " .. Config.Money(value) .. "! Chạy về Máy thu token ở sảnh nhà mình!", "Heist")
	notify(owner, "🚨 " .. thief.DisplayName .. " vừa trộm dữ liệu của bạn! Đuổi theo chạm vào để lấy lại!", "Alarm")
end

-- Hook ở Máy thu token: trộm về tới sảnh nhà mình thì đổi ổ thành $
local function onTerminal(player)
	local data = carrying[player]
	if not data or #data.items == 0 then
		return false
	end
	local total = 0
	for _, item in data.items do
		total += item.value
	end
	table.clear(data.items)
	CompanyService.AddCash(player, total)
	refreshCarrier(player)
	notify(player, "😎 Phi vụ thành công! +" .. Config.Money(total), "Collect")
	return true
end

-- Chủ nhà đứng sát trộm là lấy lại
local function checkTags()
	for thief, data in carrying do
		local thiefRoot = rootOf(thief)
		if not thiefRoot then
			continue
		end
		local owners = {}
		for _, item in data.items do
			owners[item.owner] = true
		end
		for owner in owners do
			local ownerRoot = rootOf(owner)
			if ownerRoot and (ownerRoot.Position - thiefRoot.Position).Magnitude <= H.TagDistance then
				if returnDrives(thief, owner) > 0 then
					notify(owner, "💪 Bắt được trộm! Dữ liệu đã về két.", "Collect")
					notify(thief, "😱 Bị bắt rồi! Ổ dữ liệu bị lấy lại.")
				end
			end
		end
	end
end

local function buildVault(slot)
	local part = Visuals.Part({
		Name = "Vault",
		Size = Vector3.new(6, 5, 4),
		CFrame = slot.base * CFrame.new(18, 2.5, 12), -- trong sảnh, gần cửa
		Color = Color3.fromRGB(35, 40, 60),
		Material = Enum.Material.DiamondPlate,
	})
	Visuals.Part({
		Name = "VaultNeon",
		Size = Vector3.new(6.2, 0.3, 4.2),
		CFrame = part.CFrame * CFrame.new(0, 2.4, 0),
		Color = DRIVE_COLOR,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}).Parent = part
	Visuals.Light(part, DRIVE_COLOR, 14, 1.5)

	local driveParts = {}
	for i = 1, H.MaxDrives do
		local drive = Visuals.Part({
			Name = "Drive" .. i,
			Size = Vector3.new(0.9, 1.2, 0.4),
			CFrame = part.CFrame * CFrame.new(-2 + (i - 1), 3.2, 0),
			Color = DRIVE_COLOR,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Transparency = 1,
		})
		drive.Parent = part
		driveParts[i] = drive
	end

	local shield = Visuals.Part({
		Name = "Shield",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(14, 14, 14),
		CFrame = part.CFrame,
		Color = Color3.fromRGB(80, 200, 255),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	shield.Parent = part

	local label = Visuals.Label(part, "💾 Két dữ liệu", UDim2.fromScale(10, 3), Vector3.new(0, 6, 0))

	local collect = Instance.new("ProximityPrompt")
	collect.Name = "CollectPrompt"
	collect.ObjectText = "Két dữ liệu"
	collect.ActionText = "Thu dữ liệu"
	collect.HoldDuration = 0
	collect.MaxActivationDistance = 9
	collect.RequiresLineOfSight = false
	collect.Parent = part

	local steal = Instance.new("ProximityPrompt")
	steal.Name = "StealPrompt"
	steal.ObjectText = "Két dữ liệu"
	steal.ActionText = "🕵️ Trộm ổ dữ liệu"
	steal.HoldDuration = H.StealHold
	steal.MaxActivationDistance = 9
	steal.RequiresLineOfSight = false
	steal:SetAttribute("ForOthers", true) -- client chỉ hiện nút này ở nhà người khác
	steal.Parent = part

	part.Parent = slot.model

	vaults[slot] = { part = part, label = label, shield = shield, driveParts = driveParts, drives = {}, timer = 0, lastStolen = -math.huge }
	collect.Triggered:Connect(function(player)
		onCollect(player, slot)
	end)
	steal.Triggered:Connect(function(player)
		onSteal(player, slot)
	end)
end

function HeistService.Start()
	for _, slot in CompanyService.GetLots() do
		buildVault(slot)
	end

	CompanyService.RegisterTerminalHook(onTerminal)
	CompanyService.RegisterStateProvider(function(player, profile, state)
		local data = carrying[player]
		local value = 0
		if data then
			for _, item in data.items do
				value += item.value
			end
		end
		state.carrying = if data then #data.items else 0
		state.carryValue = value
		state.shieldLeft = shieldLeft(profile)
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- trộm thoát game thì ổ về lại két chủ
		if carrying[player] then
			returnDrives(player, nil)
		end
		-- chủ nhà thoát game: trộm vẫn giữ ổ đã lấy, két được dọn sạch
		for _, slot in CompanyService.GetLots() do
			if slot.owner == player then
				table.clear(vaults[slot].drives)
			end
		end
	end)

	-- Sinh ổ dữ liệu + cập nhật két mỗi giây
	task.spawn(function()
		while true do
			task.wait(1)
			for slot, vault in vaults do
				local owner = slot.owner
				if owner and DataService.Profiles[owner] then
					vault.timer += 1
					if vault.timer >= H.DriveInterval then
						vault.timer = 0
						if #vault.drives < H.MaxDrives then
							local value = math.max(H.MinDriveValue, CompanyService.CashRate(owner) * H.DriveValueSeconds)
							table.insert(vault.drives, math.floor(value))
						end
					end
				else
					vault.timer = 0
					table.clear(vault.drives)
				end
				renderVault(slot)
			end
		end
	end)

	-- Kiểm tra bắt trộm thường xuyên hơn cho mượt
	task.spawn(function()
		while true do
			task.wait(0.25)
			checkTags()
		end
	end)
end

return HeistService
