-- Nhân sự: ứng viên (đổi đầu mỗi tháng), tuyển, sa thải, đào tạo, trả lương ngày 1 hằng tháng,
-- và tính điểm làm việc mỗi ngày theo vai trò.
-- Founder (chính người chơi) luôn làm cả lập trình lẫn nghiên cứu, không lương.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CalendarService = require(script.Parent.CalendarService)
local CompanyService = require(script.Parent.CompanyService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local StaffService = {}

local S = Config.Staff
local notify = CompanyService.Notify
local random = Random.new()

local function randomName()
	return Config.LastNames[random:NextInteger(1, #Config.LastNames)] .. " " .. Config.FirstNames[random:NextInteger(1, #Config.FirstNames)]
end

local function makeCandidate(player, profile, role)
	local years = Config.YearOf(profile.day) - Config.Calendar.StartYear
	local low = 10 + profile.building * 6 + years
	local high = 35 + profile.building * 9 + years * 2
	if player:GetAttribute("Headhunter") then
		low += S.HeadhunterBonus
		high += S.HeadhunterBonus
	end
	local skill = math.clamp(random:NextInteger(low, math.max(low, high)), 5, 95)
	return { name = randomName(), role = role, skill = skill, salary = Config.Salary(skill, profile.day) }
end

local function refreshCandidates(player, profile)
	local list = {}
	local perRole = S.CandidatesPerRole + (if player:GetAttribute("Headhunter") then 1 else 0)
	for _, role in Config.RoleOrder do
		for _ = 1, perRole do
			table.insert(list, makeCandidate(player, profile, role))
		end
	end
	profile.candidates = list
end

-- Thêm 1 nhân viên (dùng cho Gói Khởi Nghiệp). Trả về false nếu hết chỗ.
function StaffService.AddStaff(player, profile, role, skill)
	if #profile.staff + 1 >= profile.workstations then
		return false
	end
	table.insert(profile.staff, {
		id = profile.nextStaffId,
		name = randomName(),
		role = role,
		skill = skill,
		salary = Config.Salary(skill, profile.day),
	})
	profile.nextStaffId += 1
	return true
end

-- Điểm/ngày của 1 vai trò (Dev, Research, Marketing, Engineer)
function StaffService.Points(player, profile, role)
	local total = 0
	if role == "Dev" or role == "Research" then
		total += Config.Founder.skill / 10
	end
	for _, staff in profile.staff do
		if staff.role == role then
			total += staff.skill / 10
		end
	end
	return total * CompanyService.WorkMultiplier(player)
end

-- Tổng kỹ năng của 1 vai trò (marketing, kỹ sư dùng làm bonus %)
function StaffService.SkillSum(profile, role)
	local total = 0
	for _, staff in profile.staff do
		if staff.role == role then
			total += staff.skill
		end
	end
	return total
end

-- Kỹ năng trung bình của đội lập trình (tính cả Founder) — ảnh hưởng chất lượng model
function StaffService.DevSkillAverage(profile)
	local total, count = Config.Founder.skill, 1
	for _, staff in profile.staff do
		if staff.role == "Dev" then
			total += staff.skill
			count += 1
		end
	end
	return total / count
end

local function payroll(profile)
	local total = 0
	for _, staff in profile.staff do
		total += staff.salary
	end
	return total
end

local function findStaff(profile, id)
	for index, staff in profile.staff do
		if staff.id == id then
			return index, staff
		end
	end
	return nil
end

function StaffService.Start()
	CompanyService.RegisterAction("Hire", function(player, profile, session, index)
		local candidate = type(index) == "number" and profile.candidates[index]
		if not candidate then
			return
		end
		if #profile.staff + 1 >= profile.workstations then
			notify(player, "Hết bàn trống rồi! Mua thêm chỗ làm việc trước 🪑", "Open:Company")
			return
		end
		table.remove(profile.candidates, index)
		table.insert(profile.staff, {
			id = profile.nextStaffId,
			name = candidate.name,
			role = candidate.role,
			skill = candidate.skill,
			salary = candidate.salary,
		})
		profile.nextStaffId += 1
		local role = Config.Roles[candidate.role]
		notify(player, string.format("🤝 Đã tuyển %s %s (%s, kỹ năng %d)", role.emoji, candidate.name, role.name, candidate.skill), "Collect")
		CompanyService.RenderSeats(player)
		CompanyService.PushState(player)
	end)

	CompanyService.RegisterAction("Fire", function(player, profile, session, id)
		local index, staff = findStaff(profile, id)
		if not index then
			return
		end
		table.remove(profile.staff, index)
		notify(player, "👋 Đã cho " .. staff.name .. " nghỉ việc")
		CompanyService.RenderSeats(player)
		CompanyService.PushState(player)
	end)

	CompanyService.RegisterAction("Train", function(player, profile, session, id)
		local _, staff = findStaff(profile, id)
		if not staff then
			return
		end
		if staff.skill >= S.MaxSkill then
			notify(player, staff.name .. " đã max kỹ năng rồi 🔥")
			return
		end
		local cost = staff.skill * S.TrainCostPerSkill
		if not CompanyService.Spend(player, cost, "đào tạo " .. staff.name) then
			return
		end
		staff.skill = math.min(S.MaxSkill, staff.skill + S.TrainAmount)
		staff.salary = Config.Salary(staff.skill, profile.day)
		notify(player, string.format("📚 %s lên kỹ năng %d (lương mới %s/tháng)", staff.name, staff.skill, Config.Money(staff.salary)), "Collect")
		CompanyService.RenderSeats(player)
		CompanyService.PushState(player)
	end)

	CompanyService.RegisterAction("RefreshCandidates", function(player, profile)
		if not CompanyService.Spend(player, S.RefreshPrice, "tìm ứng viên mới") then
			return
		end
		refreshCandidates(player, profile)
		notify(player, "📋 Đã có danh sách ứng viên mới")
		CompanyService.PushState(player)
	end)

	-- Đầu mỗi tháng: trả lương + đổi ứng viên
	CalendarService.RegisterDayHook(function(player, profile, day)
		if day % 30 ~= 0 then
			return
		end
		local total = payroll(profile)
		if total > 0 then
			profile.cash -= total
			local warn = if profile.cash < 0 then " ⚠️ Công ty đang âm tiền, mau ra mắt model hoặc cắt giảm nhân sự!" else ""
			notify(player, string.format("💸 Trả lương tháng %s: -%s%s", Config.DateText(day):sub(4), Config.Money(total), warn))
		end
		refreshCandidates(player, profile)
	end)

	CompanyService.RegisterStateProvider(function(player, profile, state)
		-- lượt chơi mới (ngày 0) thì có sẵn ứng viên; sau đó chỉ đổi đầu tháng hoặc trả tiền tìm mới
		if #profile.candidates == 0 and profile.day == 0 then
			refreshCandidates(player, profile)
		end
		state.staff = profile.staff
		state.candidates = profile.candidates
		state.payroll = payroll(profile)
		state.points = {}
		for _, role in Config.RoleOrder do
			state.points[role] = StaffService.Points(player, profile, role)
		end
	end)
end

return StaffService
