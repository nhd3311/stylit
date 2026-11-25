-- Nhắc người chơi Favorite + Like game: chơi đủ SocialConfig.FavoriteReminderMinutes phút thì hiện
-- 1 thông báo thân thiện (mỗi lần vào game tối đa 1 lần). Chỉ là chữ, không gọi API nào của Roblox.
-- Dùng: SocialReminder.Start(toast) với toast(message, seconds?, color?) của Main.client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SocialConfig = require(Shared:WaitForChild("SocialConfig"))

local SocialReminder = {}

local GOLD = Color3.fromRGB(255, 210, 80) -- cùng màu C.gold của Main.client
local started = false -- LocalScript trong StarterPlayerScripts không chạy lại khi hồi sinh → 1 lần mỗi lần vào game

function SocialReminder.Start(toastFn)
	local minutes = SocialConfig.FavoriteReminderMinutes
	if started or type(toastFn) ~= "function" or type(minutes) ~= "number" or minutes <= 0 then
		return
	end
	started = true
	task.delay(minutes * 60, function()
		-- giữ câu ngắn cho vừa khung thông báo
		toastFn("⭐ Having fun? Favorite & 👍 Like the game to support us!", 6, GOLD)
	end)
end

return SocialReminder
