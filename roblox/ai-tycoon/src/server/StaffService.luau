-- Nhân sự: ứng viên (đổi đầu mỗi tháng), tuyển, sa thải, đào tạo, trả lương ngày 1 hằng tháng,
-- tinh thần (morale) + team party, nâng cấp phòng ban, và điểm làm việc mỗi ngày theo vai trò.
-- Founder (chính người chơi) luôn làm cả Engineer lẫn Researcher, không lương, tinh thần luôn tốt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CalendarService = require(script.Parent.CalendarService)
local CompanyService = require(script.Parent.CompanyService)
local Config = require(ReplicatedStorage.Shared.Config)

local StaffService = {}

local S = Config.Staff
local M = Config.Morale
local notify = CompanyService.Notify
local random = Random.new()

local function randomName()
	return Config.FirstNames[random:NextInteger(1, #Config.FirstNames)] .. " " .. Config.LastNames[random:NextInteger(1, #Config.LastNames)]
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

local function freeSeats(profile)
	return profile.workstations - 1 - #profile.staff
end

-- Thêm 1 nhân viên (gói Hire Legend, Starter Pack, sự kiện). Trả về false nếu hết bàn.
function StaffService.AddStaff(player, profile, role, skill, name)
	if freeSeats(profile) <= 0 then
		return false
	end
	table.insert(profile.staff, {
		id = profile.nextStaffId,
		name = name or randomName(),
		role = role,
		skill = skill,
		salary = Config.Salary(skill, profile.day),
		morale = M.Start,
	})
	profile.nextStaffId += 1
	return true
end

-- Điểm/ngày của 1 vai trò = tổng (kỹ năng/10 x tinh thần) x trang bị x phòng ban x sự kiện
function StaffService.Points(player, profile, role)
	local total = 0
	if role == "Dev" or role == "Research" then
		total += Config.Founder.skill / 10 * Config.MoraleMult(90)
	end
	for _, staff in profile.staff do
		if staff.role == role then
			total += staff.skill / 10 * Config.MoraleMult(staff.morale)
		end
	end
	local mult = CompanyService.WorkMultiplier(player) * Config.DepartmentMult(profile.departments[role])
	if role == "Dev" or role == "Research" then
		mult *= CompanyService.Modifier(profile, role)
	end
	return total * mult
end

-- Tổng kỹ năng (đã tính tinh thần + phòng ban) của 1 vai trò, dùng làm bonus % cho Marketing/Hardware
function StaffService.SkillSum(profile, role)
	local total = 0
	for _, staff in profile.staff do
		if staff.role == role then
			total += staff.skill * Config.MoraleMult(staff.morale)
		end
	end
	return total * Config.DepartmentMult(profile.departments[role])
end

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

local function averageMorale(profile)
	if #profile.staff == 0 then
		return 100
	end
	local total = 0
	for _, staff in profile.staff do
		total += staff.morale
	end
	return total / #profile.staff
end

local function partyPrice(profile)
	return M.PartyBase + M.PartyPerStaff * #profile.staff
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
		if freeSeats(profile) <= 0 then
			notify(player, "No free desk! Buy another workstation first 🪑", "Open:Company")
			return
		end
		table.remove(profile.candidates, index)
		StaffService.AddStaff(player, profile, candidate.role, candidate.skill, candidate.name)
		profile.staff[#profile.staff].salary = candidate.salary
		local role = Config.Roles[candidate.role]
		notify(player, string.format("🤝 Hired %s %s (%s, skill %d)", role.emoji, candidate.name, role.name, candidate.skill), "Collect")
		CompanyService.RenderSeats(player)
		CompanyService.PushState(player)
	end)

	CompanyService.RegisterAction("Fire", function(player, profile, session, id)
		local index, staff = findStaff(profile, id)
		if not index then
			return
		end
		table.remove(profile.staff, index)
		-- đồng nghiệp hơi buồn khi có người bị cho nghỉ
		for _, other in profile.staff do
			other.morale = math.max(0, other.morale - 3)
		end
		notify(player, "👋 " .. staff.name .. " has left the company")
		CompanyService.RenderSeats(player)
		CompanyService.PushState(player)
	end)

	CompanyService.RegisterAction("Train", function(player, profile, session, id)
		local _, staff = findStaff(profile, id)
		if not staff then
			return
		end
		if staff.skill >= S.MaxSkill then
			notify(player, staff.name .. " is already maxed out 🔥")
			return
		end
		if not CompanyService.Spend(player, staff.skill * S.TrainCostPerSkill, "train " .. staff.name) then
			return
		end
		staff.skill = math.min(S.MaxSkill, staff.skill + S.TrainAmount)
		staff.salary = Config.Salary(staff.skill, profile.day)
		staff.morale = math.min(100, staff.morale + M.TrainGain)
		notify(player, string.format("📚 %s reached skill %d (new salary %s/mo)", staff.name, staff.skill, Config.Money(staff.salary)), "Collect")
		CompanyService.RenderSeats(player)
		CompanyService.PushState(player)
	end)

	CompanyService.RegisterAction("RefreshCandidates", function(player, profile)
		if not CompanyService.Spend(player, S.RefreshPrice, "find new candidates") then
			return
		end
		refreshCandidates(player, profile)
		notify(player, "📋 Fresh candidates are in!")
		CompanyService.PushState(player)
	end)

	CompanyService.RegisterAction("Party", function(player, profile)
		if #profile.staff == 0 then
			notify(player, "Hire someone first, a party for one is a little sad 🥲")
			return
		end
		local wait = profile.lastParty + M.PartyCooldownDays - profile.day
		if wait > 0 then
			notify(player, string.format("The team is still recovering from the last party (%d days) 🎉", wait))
			return
		end
		if not CompanyService.Spend(player, partyPrice(profile), "throw a team party") then
			return
		end
		for _, staff in profile.staff do
			staff.morale = math.min(100, staff.morale + M.PartyGain)
		end
		profile.lastParty = profile.day
		notify(player, "🎉 Team party! Everyone's morale went up", "Evolve")
		CompanyService.PushState(player)
	end)

	CompanyService.RegisterAction("UpgradeDepartment", function(player, profile, session, role)
		local dept = type(role) == "string" and Config.Departments[role]
		if not dept then
			return
		end
		local nextLevel = (profile.departments[role] or 1) + 1
		local spec = Config.DepartmentLevels[nextLevel]
		if not spec then
			notify(player, dept.name .. " is already max level 🔥")
			return
		end
		if profile.building < spec.requireBuilding then
			notify(player, "Move into a " .. Config.Buildings[spec.requireBuilding].name .. " to expand " .. dept.name .. " 🏢")
			return
		end
		if not CompanyService.Spend(player, spec.price, "expand " .. dept.name) then
			return
		end
		profile.departments[role] = nextLevel
		notify(player, string.format("%s %s is now Lv.%d (+%d%% output)", dept.emoji, dept.name, nextLevel, math.floor((Config.DepartmentMult(nextLevel) - 1) * 100 + 0.5)), "Evolve")
		CompanyService.RenderSeats(player)
		CompanyService.PushState(player)
	end)

	-- Đầu mỗi tháng: trả lương, tinh thần tụt dần, ai quá chán thì nghỉ, đổi ứng viên
	CalendarService.RegisterDayHook(function(player, profile, day)
		if day % 30 ~= 0 then
			return
		end
		local total = payroll(profile)
		local unpaid = false
		if total > 0 then
			profile.cash -= total
			unpaid = profile.cash < 0
			local warn = if unpaid then " ⚠️ You're in debt! Launch a model or cut staff." else ""
			notify(player, string.format("💸 Payday %s: -%s%s", Config.MonthText(day), Config.Money(total), warn))
		end
		local quitters = {}
		for i = #profile.staff, 1, -1 do
			local staff = profile.staff[i]
			staff.morale = math.max(0, staff.morale - M.MonthlyDrop - (if unpaid then M.UnpaidDrop else 0))
			if staff.morale < M.QuitBelow then
				table.insert(quitters, staff.name)
				table.remove(profile.staff, i)
			end
		end
		if #quitters > 0 then
			notify(player, "😤 " .. table.concat(quitters, ", ") .. " quit because morale was too low! Throw a team party next time.")
			CompanyService.RenderSeats(player)
		end
		refreshCandidates(player, profile)
	end)

	CompanyService.RegisterStateProvider(function(player, profile, state)
		if #profile.candidates == 0 and profile.day == 0 then
			refreshCandidates(player, profile)
		end
		state.staff = profile.staff
		state.candidates = profile.candidates
		state.payroll = payroll(profile)
		state.morale = averageMorale(profile)
		state.partyPrice = partyPrice(profile)
		state.partyIn = math.max(0, profile.lastParty + M.PartyCooldownDays - profile.day)
		state.departments = profile.departments
		state.points = {}
		for _, role in Config.RoleOrder do
			state.points[role] = StaffService.Points(player, profile, role)
		end
	end)
end

-- dọn data cũ: nhân viên từ bản trước chưa có tinh thần
function StaffService.Prepare(profile)
	for _, staff in profile.staff do
		staff.morale = staff.morale or M.Start
	end
	for role in Config.Departments do
		profile.departments[role] = profile.departments[role] or 1
	end
end

return StaffService
