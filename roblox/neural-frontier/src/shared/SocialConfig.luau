-- Cấu hình tính năng xã hội: chơi cùng bạn bè (Friend Boost), phần thưởng nhóm Roblox,
-- thưởng mời bạn, nhắc Favorite + Like. Server (FriendsService) và client (SocialPanel,
-- SocialReminder) cùng đọc file này.
-- Chữ người chơi thấy là tiếng Anh; chú thích code là tiếng Việt.
-- KHÔNG tự bịa ID: để 0 nghĩa là chưa có, tính năng liên quan tự tắt gọn gàng.

local SocialConfig = {}

-- ID nhóm (group) Roblox của game: con số trong link roblox.com/groups/<ID>/...
-- 0 = chưa có nhóm: phần thưởng nhóm tắt hẳn, server không gọi IsInGroup,
-- bảng Social ghi "chưa có nhóm". Chủ game điền ID thật khi đã tạo nhóm.
SocialConfig.GroupId = 0

-- Friend Boost: mỗi người bạn Roblox đang ở CÙNG server cộng thêm 10% gather (data/giây)
-- và 10% credits khi upload.
SocialConfig.FriendBoostPerFriend = 0.1
-- Trần phần cộng thêm: tối đa +30% (đủ 3 người bạn). Có trần để rủ cả nhóm vào 1 server
-- không làm lệch kinh tế game.
SocialConfig.FriendBoostMax = 0.3

-- Thưởng nhóm, nhận 1 lần duy nhất cho mỗi tài khoản đã vào nhóm.
--   credits: mức gốc, nhân theo level bằng Config.ScaledCredits (người chơi level cao vẫn thấy đáng nhận).
--   capsule: "Best" = mở miễn phí 1 capsule Credits xịn nhất đã mở khoá; hoặc ghi ID capsule cụ thể
--            trong Config.Capsules; nil = không tặng capsule.
SocialConfig.GroupReward = { credits = 1000, capsule = "Best" }

-- Thưởng mời bạn: bạn vào game từ lời mời trong game (SocialService:PromptGameInvite) và người mời
-- đang ở chính server đó thì CẢ HAI nhận credits (mức gốc, nhân theo level của từng người).
-- Mỗi cặp người chơi chỉ nhận 1 lần, mời lại bao nhiêu lần cũng không nhận thêm.
SocialConfig.InviteReward = { credits = 500 }

-- Chơi được bấy nhiêu phút thì hiện 1 lời nhắc thân thiện mời Favorite + Like game
-- (mỗi lần vào game tối đa 1 lần). 0 = tắt lời nhắc.
SocialConfig.FavoriteReminderMinutes = 20

return SocialConfig
