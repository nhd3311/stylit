# 🤖 Neural Frontier (Roblox)

Game **nhiều người chơi** thể loại *collector simulator + phiêu lưu hành động*, **giao diện tiếng Anh**, chủ đề AI. Hướng dẫn này viết bằng tiếng Việt cho người làm game.

Người chơi là một **Bot Tamer**. Bạn dẫn một đội **thú máy AI** (mèo, cáo, bọ, cú, sứa, rồng máy...) đi vào các vùng đất, thu thập **Data Shard** từ tinh thể, rồi mang về **Hub** để upload lấy **Credits** và XP. Credits dùng để **mở Capsule ra bot mới**, nâng cấp bot, mua ba lô to hơn. Trên đường đi sẽ gặp drone nổi loạn và boss, bạn hạ chúng bằng kỹ năng **AI Core** và đội bot tự bắn.

> Đây là game nguyên bản: thế giới, nhân vật, quái, tên gọi và hệ thống đều tự thiết kế. Game chỉ dùng chung *thể loại* (thu thập → bán → nâng cấp → mở vùng mới) với nhiều game simulator khác.

## 🔁 Vòng lặp chính

1. Đi vào vùng → đứng gần tinh thể và bấm **chuột trái / G** để thu thập. Đội bot cũng tự hút data mỗi giây.
2. Ba lô đầy → quay về Hub, bước lên **Upload Pad** 📡 → nhận Credits + XP.
3. Mở capsule ở **Capsule Lab** để có bot mới, sưu tầm đủ bộ trong **Bot Database**, mua ba lô ở **Gear Shop**, làm nhiệm vụ của **Unit-0**.
4. Lên level → mở kỹ năng mới và mở cổng vùng tiếp theo.
5. Chết thì **mất data đang mang** (Credits vẫn giữ), nên phải tính lúc nào về upload.

## 🗺️ Thế giới "Neon Grid" (toàn khối, không còn cỏ/núi)

Mọi thứ là **khối nổi lơ lửng** trên khoảng không, dưới đáy là lưới neon tím xanh chìm trong sương. Ánh sáng tông **hoàng hôn neon** để khối phát sáng nổi bật.

- **Hub**: đảo lát gạch trắng, khe gạch phát sáng xanh, lan can kính, 4 trụ đèn, cổng "TO THE FRONTIER", cổng sự kiện 🟥 Glitch Floor.
- Các đảo nối nhau bằng **cầu khối** có lan can kính và trụ đỡ cắm xuống vực. **Rơi xuống vực là bị hạ gục** (mất data đang mang).
- Mảnh đảo khối trôi xa xa hai bên cho khung cảnh có chiều sâu.

| Vùng | Level | Data x | Phong cách khối | Quái | Boss |
|---|---|---|---|---|---|
| 🌿 Byte Meadow | 1 | x1 | Gạch caro bạc hà, cây voxel có "quả pixel" phát sáng, khối data bay | Rogue Drone | 👑 Glitch King |
| 🏜️ Circuit Canyon | 6 | x4 | Gạch đồng, vách hẻm núi bậc thang, mạch điện neon dưới sàn, tủ server nhấp nháy | Scrap Hunter | 👑 Rust Titan |
| 🌃 Neon Spires | 15 | x16 | Gạch tím đậm, tháp kính nhiều tầng có cửa sổ neon, vòng hologram bay | Neon Wraith | 👑 Overmind |
| ❄️ Frost Server | 22 | x64 | Gạch trắng băng, cụm pha lê kính, tủ server đóng băng, **tuyết rơi** | Frost Sentinel | 👑 Cryo Colossus |
| 🌋 Magma Forge | 30 | x256 | Gạch bazan có nhiều ô dung nham, hồ lava nhấp nháy, trụ lò rèn **có lửa thật**, tàn lửa bay lên | Magma Crawler | 👑 Forge Tyrant |
| 🌀 Glitch Rift | 40 | x1024 | Gạch đen/hồng, khối glitch lơ lửng xoay, bia đá đen, cột sáng neon cao vút | Rift Phantom | 👑 The Glitch Queen |
| ☁️ Cloud Citadel | 50 | x4096 | Gạch trắng/vàng, cột đá cẩm thạch mũ vàng, cổng vòm vàng, mây khối trôi, vòng hào quang khổng lồ | Aegis Drone | 👑 Celestial Core |

Mỗi vùng có **tường khối cao thấp so le** với viền neon trên đỉnh. Máu người chơi và sức mạnh Pulse tăng theo cấp số nhân để đánh được quái ở stage cao. Có thêm 5 tier ba lô (tới **Infinity Core**) và 8 nhiệm vụ mới cho các stage sau.

**Dịch chuyển**: bấm nút 🌀 trên thanh vùng. Về Hub luôn miễn phí. Tới vùng đã mở thì **miễn phí mỗi 60 giây**; có pass 🌀 Zone Warp thì không phải chờ. Boss hồi sinh sau 2–3 phút và cả server được báo. Ai góp sát thương đều được thưởng.

## 🥚 Capsule Lab + 🤖 20 thú máy

Bot không mua thẳng nữa mà **mở từ Capsule**. Mỗi capsule cho đúng 1 bot, **tỉ lệ rơi luôn hiện rõ** (đã tính luck).

| Capsule | Mở bằng | Level | Bot bên trong (tỉ lệ gốc) |
|---|---|---|---|
| 🌿 Meadow | 120 Credits | 1 | Scout Orb 45% · Byte Kitty 30% · Miner Beetle 17% · Glitch Fox 7% · **Pixel Owl 1%** |
| 🏜️ Canyon | 4K Credits | 6 | Guard Beetle 45% · Laser Orb 30% · Dune Kitty 17% · Harvester Jelly 7% · **Sun Drake 1%** |
| 🌃 Spires | 90K Credits | 15 | Titan Beetle 45% · Neon Jelly 30% · Volt Fox 17% · Void Owl 7% · **Quantum Dragon 1%** |
| ❄️ Frost | 2.5M Credits | 22 | Snow Orb 45% · Frost Kitty 30% · Glacier Beetle 17% · Borealis Jelly 7% · **Ice Wyrm 1%** |
| 🌋 Magma | 70M Credits | 30 | Ember Orb 45% · Cinder Fox 30% · Magma Beetle 17% · Blaze Owl 7% · **Inferno Drake 1%** |
| 🌀 Rift | 2B Credits | 40 | Static Orb 45% · Rift Kitty 30% · Null Beetle 17% · Phase Fox 7% · **Rift Leviathan 1%** |
| ☁️ Citadel | 60B Credits | 50 | Halo Orb 45% · Seraph Kitty 30% · Aegis Beetle 17% · Oracle Owl 7% · **Celestial Dragon 1%** |
| 💎 **Neon** | **Robux** | 1 | Holo Kitty 50% · Prism Fox 30% · Aurora Owl 15% · **Nova Dragon 4.5%** · **Singularity 0.5%** |

- Độ hiếm: Common → Rare → Epic → Legendary → **Mythic** (chỉ có trong Neon Capsule).
- **Luck** chỉ nhân tỉ lệ của Epic, Legendary, Mythic. Nguồn luck: Game Pass 🍀 Lucky Scanner (x1.5, vĩnh viễn) và gói 🍀 x2 Luck (15 phút).
- **Hoạt cảnh mở capsule**: capsule rung (bot càng hiếm rung càng lâu), bung nắp, bot hiện ra giữa vầng sáng màu độ hiếm, hiện chữ "NEW!" nếu là bot mới. Mở x3/x10 thì hiện cả hàng kết quả.
- Ai mở được bot **Legendary/Mythic** thì **cả server được báo**.
- Mỗi bot là một **thú máy dựng bằng Part**, có cử động: đập cánh, vẫy đuôi, xúc tu đung đưa, vòng hào quang quay. Bot Legendary/Mythic có vòng hào quang trên đầu.
- Chỉ **4 bot mạnh nhất** ra trận (Game Pass Bot Slots +3). Kho tối đa 60 bot. Bot dư có thể Recycle từng con hoặc **Recycle cả loạt** bot dự bị Common/Rare.

## ✨ Biến thể, 🧬 Fuse, 🔒 Khoá bot

- Mỗi bot mở ra có cơ hội là **✨ Shiny** (1/40, chỉ số x1.5, vỏ vàng bóng, lấp lánh vàng) hoặc **🌈 Holo** (1/400, chỉ số x3, đổi màu cầu vồng liên tục). Game Pass ✨ Shiny Hunter nhân đôi cơ hội. Cơ hội biến thể hiện trên từng capsule.
- **Fusion Lab** (trong bảng Bots): gộp **5 bot giống hệt nhau** thành 1 bản ✨ Shiny, 5 Shiny thành 1 🌈 Holo. Bot mới giữ cấp cao nhất. Có hoạt cảnh riêng.
- **Khoá bot** 🔒: bot khoá không bị Recycle, không bị Fuse. Recycle cả loạt không bao giờ đụng tới bot đang ra trận, bot khoá và bot Shiny/Holo.

## 📚 Bot Database

- Bot chưa có hiện **bóng đen "???"**, có rồi thì hiện thú máy 3D đầy màu sắc.
- Sưu tầm đủ 5 bot của một capsule thì nhận thưởng một lần: Credits và **+% gather vĩnh viễn** (Meadow +5%, Canyon +10%, Spires +15%, Frost +20%, Magma +25%, Rift +30%, Citadel +40%, Neon +25%). Tổng cộng **40 bot** để sưu tầm.
- Mỗi bot có 2 huy hiệu ✨/🌈 sáng lên khi anh từng sở hữu bản biến thể đó.

## 🏠 Habitat: nuôi bot và trưng bày bộ sưu tập

- Đảo **Bot Habitat** nằm phía sau Hub (đi qua cầu ở cổng nam). Có **8 ô vườn**, mỗi người chơi vào server được chia 1 ô.
- **Đặt bot vào vườn** (bảng 🏠 HABITAT): bot sẽ **đi dạo quanh ô, nhún nhảy**. Bot nghỉ trong vườn thì không ra trận.
- Bot trong vườn **làm ra Credits cả khi offline**. Sản lượng = tổng gather của bot trong vườn × hệ số data của vùng xịn nhất đã mở.
- **Độ vui** giảm dần trong 6 giờ. Bấm **🍖 Feed** để bot vui lại 100%; vui càng nhiều thì làm càng nhiều (đói hẳn vẫn làm được 30%).
- Kho chứa tối đa **4 giờ** sản lượng, nên phải quay lại bấm **💰 Collect**. Đây là lý do để người chơi quay lại game mỗi ngày.
- **Trưng bày**: 3 bot hiếm nhất của anh đứng xoay trên **bệ đá**. Biển tên hiện *"🏠 Tên · 📚 23/40 bots"* cho cả server xem.
- Game Pass **🏡 Habitat Expansion**: +6 ô nghỉ và kho chứa x2.
- Nút 🌀 Warp có thêm **"My Habitat"** (miễn phí).
- ⚠️ Có 8 ô vườn, nên anh đặt **Max Players = 8** trong Game Settings (hoặc thêm ô trong `Config.Habitat.Plots`).

## 📖 Hướng dẫn người mới + nút ❓ Guide

- Người chơi mới vào game sẽ có **tutorial 9 bước**: đi vào Byte Meadow → thu thập → upload → mở capsule → xem đội bot → đặt bot vào Habitat → đánh drone → xong.
- Bước nào cần đi tới đâu thì có **tia sáng chỉ đường** từ nhân vật tới đích và **mũi tên ⬇️** trên đích. Bước cần bấm menu thì có **ngón tay 👈** chỉ vào nút.
- Làm đúng thì **tự qua bước sau**, có bong bóng ăn mừng. Có nút **SKIP**. Tiến độ được lưu, thoát ra vào lại vẫn làm tiếp.
- Nút **❓ GUIDE** luôn hiện cạnh thẻ phi công. Mở ra là **hướng dẫn đầy đủ** mọi tính năng, có nút **▶ chơi lại tutorial**.
- Người chơi cũ (level > 3) không bị bắt làm tutorial.

## 🎁 Quà đăng nhập 7 ngày

Mỗi ngày (theo giờ UTC) nhận 1 lần. Chuỗi liên tục thì lên ngày tiếp theo, lỡ 1 ngày là quay về Ngày 1. Credits tự tăng theo level.

| Ngày | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| Quà | Credits | Capsule xịn nhất đã mở | Credits | x2 Luck 15' | Credits | x2 Gather 30' | **💎 Neon Capsule miễn phí** |

Vào game mà có quà chưa nhận thì bảng Daily tự mở.

## 🟥 Sự kiện Glitch Floor (minigame)

- Cứ **5 phút** mở một lượt (lượt đầu sau 1 phút). Bấm **JOIN** trên HUD ở đâu cũng được, hoặc bước lên cổng đỏ ở Hub.
- Người tham gia được đưa lên **sàn đấu bay**, đếm 3-2-1-GO. Ô sàn **nhấp nháy đỏ rồi rơi**, nhịp nhanh dần. Có đợt rơi nguyên một hàng, một cột hoặc cả vòng ngoài.
- Rơi khỏi sàn là bị loại. Người cuối cùng còn đứng (hoặc trụ đủ 90 giây) **thắng**: nhận credits và 1 capsule miễn phí. Người chơi khác nhận credits tham gia.
- Bảng xếp hạng có cột **Wins**, và có thêm nhiệm vụ "Win a Glitch Floor event".


## ⚡ Kỹ năng AI Core

| Phím | Kỹ năng | Mở ở level | Tác dụng |
|---|---|---|---|
| Q | 💥 Pulse | 1 | Sóng xung kích gây sát thương quanh người |
| E | 💨 Dash | 3 | Lao về phía trước |
| R | ⚡ Overclock | 8 | Bot thu thập và bắn x2 trong 10 giây |
| F | 🛡️ Shield | 12 | Giảm 70% sát thương trong 6 giây |

Trên điện thoại có sẵn nút bấm cho từng kỹ năng và nút 💾 thu thập.

## 🫧 Giao diện 3D bong bóng

- **Mọi nút đều nổi khối 3D**: mặt nút nằm trên đế tối màu. Rê chuột thì nút nổi lên, bấm thì lún xuống, thả ra thì bật lại. Có lớp bóng kính và đốm sáng như bong bóng.
- **Menu dạng viên thuốc bóng**: icon nằm trong bong bóng tròn và nhún nhảy lệch nhịp. **Bong bóng bay lên** khi rê chuột, bấm, và lác đác cả lúc rảnh.
- **Ô kỹ năng** cũng nổi 3D và có bong bóng khi bấm.
- Mở bảng thì bảng **nghiêng nhẹ rồi về thẳng**, từng thẻ **bật lên lần lượt**. Nền bảng có **bong bóng lớn trôi chậm**.

## 💎 Shop (Robux là nguồn thu chính)

| Loại | Tên | Tác dụng | Giá gợi ý |
|---|---|---|---|
| Dev Product | 🎁 **Starter Pack** (chỉ bán 1 lần) | Holo Kitty (Epic) chắc chắn + 5K credits + 30' x2 Credits & Gather | 49–99 R$ |
| Dev Product | 💎 Neon Capsule x1 / x3 / x10 | Mở ngay Neon Capsule (có Mythic) | 49 / 139 / 399 R$ |
| Dev Product | 🍀 x2 Luck | x2 tỉ lệ Epic+ trong 15 phút | 49 R$ |
| Game Pass | 🍀 Lucky Scanner | x1.5 luck vĩnh viễn | 249 R$ |
| Game Pass | ✨ Shiny Hunter | x2 cơ hội Shiny/Holo | 299 R$ |
| Game Pass | ⚡ Rapid Fire | Bot bắn nhanh x2 | 249 R$ |
| Game Pass | 🤖 Auto Harvest | Đội bot tự hút tinh thể gần nhất mỗi giây, khỏi bấm | 199 R$ |
| Game Pass | 🛡️ Data Shield | Bị hạ gục không mất data đang mang | 149 R$ |
| Game Pass | 🔋 Core Overdrive | Kỹ năng hồi chiêu nhanh x2 | 149 R$ |
| Game Pass | 🌀 Zone Warp | Dịch chuyển tức thì tới vùng đã mở (nút 🌀 trên thanh vùng). Về Hub thì miễn phí cho mọi người | 99 R$ |
| Game Pass | 📦 Mega Storage | Kho bot +60 | 99 R$ |
| Game Pass | 🏡 Habitat Expansion | +6 ô nghỉ trong Habitat, kho chứa x2 | 199 R$ |
| Dev Product | 👥 x4 Clone Squad (15') | 4 bản sao hologram của bot mạnh nhất cùng đánh và thu thập (mỗi bản 50% sức mạnh) | 49 R$ |
| Dev Product | 🌍 Server x2 Luck (15') | x2 luck cho **cả server**, cả server được báo tên người mua | 99 R$ |
| Game Pass | 🥚 Triple Hatch | Mở 3 capsule Credits một lần | 199 R$ |
| Game Pass | ⭐ VIP | x2 Credits khi upload, tag VIP | 199 R$ |
| Game Pass | 🤖 +3 Bot Slots | Mang thêm 3 bot ra trận | 299 R$ |
| Game Pass | 🎒 Big Backpack · 📡 Auto Upload · 👟 Turbo Boots | Ba lô x2 · tự upload · chạy nhanh | 99–149 R$ |
| Dev Product | 🚀 Mega Boost · 💰 x2 Credits (30') · 💾 x2 Gather (15') | x2 Credits và/hoặc Gather | 29–79 R$ |
| Dev Product | 💳 Credit Pack S / L | Credits tự tăng theo tiến độ | 49 / 199 R$ |

Giá là gợi ý, anh tự đặt trên Creator Dashboard. **x3 và x10 rẻ hơn thật** so với mua lẻ, không dùng giá gạch giả. Starter Pack là gói **cố định, không ngẫu nhiên** nên ai cũng mua được.

### ⚖️ Làm đúng luật Roblox về vật phẩm ngẫu nhiên trả tiền
- **Luôn hiện tỉ lệ rơi** ở Capsule Lab, trên bệ trưng bày trong map và trong hoạt cảnh mở.
- Game kiểm tra `PolicyService:GetPolicyInfoForPlayerAsync()`. Người chơi ở nơi luật cấm (`ArePaidRandomItemsRestricted`) sẽ **không thấy** Neon Capsule, Luck, Server Luck, Shiny Hunter, Triple Hatch và Credit Pack (các món có `paidRandom = true` trong Config). Họ vẫn mở capsule bằng Credits kiếm được khi chơi.
- Cơ hội ✨ Shiny / 🌈 Holo cũng được hiện rõ trên từng capsule.
- Khi publish, trong **Maturity & Compliance Questionnaire** nhớ khai là game **có paid random items**.

## 🚀 Hệ thống chuẩn bị launch

| Hệ thống | Chỗ chỉnh | Cần điền trước khi launch |
|---|---|---|
| 🎵 Âm thanh (nhạc theo khu vực, nhạc boss, 36 hiệu ứng) | `shared/AudioConfig.luau` | Toàn bộ id đang là `0` (game im lặng, không lỗi). Chỉ dùng audio public trên Creator Store hoặc do chính tài khoản/nhóm của game upload. Điền mỗi `Music.Hub` là có nhạc khắp nơi. |
| 🎟️ Mã quà | `server/CodesConfig.luau` (chỉ server đọc được, người chơi không xem trộm được) | Mã mẫu: `RELEASE`, `NEONBOTS`, `FREECAPSULE`, `LAUNCHWEEK` (hết hạn 01/01/2027). Mỗi người thử tối đa 5 lần / 60 giây. |
| 🏅 Thành tựu + Badge | `shared/RewardsConfig.luau` | `badgeId = 0` thì vẫn có thành tựu + thưởng Credits, chỉ không trao badge. Tạo badge ở Creator Dashboard rồi dán ID. |
| 🏆 Bảng xếp hạng | `server/LeaderboardService.luau` | 4 bảng trong Hub (Top Level, Uploaded, Glitch Champions, Collection). Chưa publish thì bảng ghi "Available after publishing". |
| 👥 Chơi cùng bạn | `shared/SocialConfig.luau` | Có bạn bè cùng server thì được cộng % Credits. `GroupId = 0` thì ẩn quà tham gia nhóm. Sau 20 phút chơi game nhắc Favorite + Like. |
| ⚙️ Cài đặt | `client/Settings.luau` + `server/SettingsService.luau` | Âm lượng nhạc/hiệu ứng, đồ hoạ thấp, ẩn đội bot người khác, cỡ giao diện, số sát thương. Được lưu theo tài khoản. |
| 📊 Analytics | `server/AnalyticsService.luau` | Tự ghi phễu hướng dẫn, Credits vào/ra, lên level, mua Robux. Xem ở Creator Dashboard → Analytics. |

Nút ⚙️ 🎟️ 🏅 👥 nằm thành cột ở mép phải màn hình.

## ▶️ Chạy thử trong Studio

1. Mở `NeuralFrontier.rbxlx` bằng Studio (**File → Open from File**), rồi bấm **Play**. Chưa publish vẫn chơi được ở chế độ thử, nhưng data không được lưu.
2. Muốn lưu data thì **Publish** game, rồi bật **Game Settings → Security → Enable Studio Access to API Services**.
3. Muốn thử nhiều người chơi: tab **Test → Clients and Servers → 2 Players → Start**.
4. Vào Creator Dashboard, tạo 15 Game Pass `VIP`, `LuckyScanner`, `TripleHatch`, `ShinyHunter`, `RapidFire`, `AutoHarvest`, `DataShield`, `CoreOverdrive`, `ZoneWarp`, `MegaStorage`, `BigHabitat`, `BotSlots`, `BigBackpack`, `AutoUpload`, `TurboBoots` và 12 Developer Product `StarterPack`, `NeonCapsule1`, `NeonCapsule3`, `NeonCapsule10`, `LuckBoost`, `CloneSquad`, `ServerLuck`, `CreditBoost`, `GatherBoost`, `MegaBoost`, `CreditsSmall`, `CreditsLarge`.
5. Dán ID vào `src/shared/Config.luau`. Khi ID còn là `0`, nút trong shop sẽ hiện "Set ID".

Dùng Rojo thì chạy `rojo serve` trong thư mục này.

## 📁 Cấu trúc code

| File | Việc |
|---|---|
| `shared/Config.luau` | Toàn bộ số liệu: bot, capsule + tỉ lệ, vùng, quái, kỹ năng, nhiệm vụ, shop |
| `shared/BotModels.luau` | Dựng 7 dáng thú máy (Orb, Cat, Fox, Beetle, Owl, Jelly, Dragon) + cử động + biến thể Shiny/Holo, capsule 3D |
| `server/DataService.luau` | Lưu và tải data, retry, chế độ thử khi chưa publish |
| `server/WorldService.luau` | Dựng thế giới khối: đảo lát gạch, tường, cầu, trang trí theo vùng, Hub, Capsule Lab, sàn Glitch Floor |
| `server/HabitatService.luau` | Chia ô vườn, bot nghỉ làm Credits khi offline, độ vui/cho ăn/thu hoạch, bệ trưng bày |
| `client/Habitat.luau` | Vẽ bot đi dạo trong vườn, bot trên bệ trưng bày, biển tên chủ ô |
| `server/EventService.luau` | Điều khiển sự kiện Glitch Floor: mời, đếm ngược, làm rơi ô sàn, loại người rơi, phát thưởng |
| `server/PlayerService.luau` | Thu thập, upload, mở capsule + biến thể, Fuse, khoá bot, Database, quà ngày, kỹ năng, level, nhiệm vụ |
| `server/EnemyService.luau` | AI của quái và boss, đội bot tự bắn, chia thưởng boss |
| `server/MonetizationService.luau` | Game Pass, Dev Product, Neon Capsule, kiểm tra PolicyService |
| `client/Main.client.luau` | HUD hologram, nút 3D bong bóng, menu có bong bóng bay, các bảng (Bots, Capsules, Database, Daily, Gear, Missions, Shop, Warp), hoạt cảnh mở capsule |
| `client/Effects.luau` | Vẽ đội thú máy bay theo, laser, số sát thương, nổ, hào quang |
| `client/Fx.luau` | Làm tinh thể xoay, đèn nhấp nháy |
| `client/Audio.luau` | Nhạc nền theo khu vực (chuyển mượt), nhạc boss, hiệu ứng 2D/3D có pool |
| `server/CodesService.luau` + `server/CodesConfig.luau` | Nhập mã quà, chống spam, mã hết hạn |
| `server/AchievementService.luau` + `client/RewardsPanels.luau` | Thành tựu, badge, bảng Codes và Achievements |
| `server/LeaderboardService.luau` | 4 bảng xếp hạng toàn server trong Hub |
| `server/FriendsService.luau` + `client/SocialPanel.luau` | Thưởng chơi cùng bạn, mời bạn, quà nhóm Roblox |
| `server/SettingsService.luau` + `client/Settings.luau` | Lưu và áp dụng cài đặt người chơi |
| `server/AnalyticsService.luau` | Ghi số liệu cho Creator Dashboard (bọc an toàn, lỗi không làm hỏng game) |

Server quyết định mọi thứ (tiền, data, sát thương). Client chỉ gửi yêu cầu và hiển thị, nên khó hack tiền.

## 🎨 Nâng cấp đồ họa

Map hiện tại dựng hoàn toàn bằng code (Part + Terrain). Muốn đẹp hơn nhiều:
- Thú máy đang dựng từ Part trong `shared/BotModels.luau`. Có model Blender thì thay vào hàm `BotModels.Build` (giữ hướng mặt trước là -Z).
- Lấy model cây, đá, nhà từ Creator Store. **Nhớ kiểm tra model không chứa Script lạ** trước khi dùng.
