# 🤖 Neural Frontier (Roblox)

Game **nhiều người chơi** thể loại *collector simulator + phiêu lưu hành động*, **giao diện tiếng Anh**, chủ đề AI. Hướng dẫn này viết bằng tiếng Việt cho người làm game.

Người chơi là một **Bot Tamer**. Bạn dẫn một đội bot AI đi vào các vùng đất, thu thập **Data Shard** từ tinh thể, rồi mang về **Hub** để upload lấy **Credits** và XP. Credits dùng để mua thêm bot, nâng cấp bot, mua ba lô to hơn. Trên đường đi sẽ gặp drone nổi loạn và boss, bạn hạ chúng bằng kỹ năng **AI Core** và đội bot tự bắn.

> Đây là game nguyên bản: thế giới, nhân vật, quái, tên gọi và hệ thống đều tự thiết kế. Game chỉ dùng chung *thể loại* (thu thập → bán → nâng cấp → mở vùng mới) với nhiều game simulator khác.

## 🔁 Vòng lặp chính

1. Đi vào vùng → đứng gần tinh thể và bấm **chuột trái / G** để thu thập. Đội bot cũng tự hút data mỗi giây.
2. Ba lô đầy → quay về Hub, bước lên **Upload Pad** 📡 → nhận Credits + XP.
3. Mua bot ở **Bot Forge**, mua ba lô ở **Gear Shop**, làm nhiệm vụ của **Unit-0**.
4. Lên level → mở kỹ năng mới và mở cổng vùng tiếp theo.
5. Chết thì **mất data đang mang** (Credits vẫn giữ), nên phải tính lúc nào về upload.

## 🗺️ Ba vùng

| Vùng | Level | Data x | Quái | Boss |
|---|---|---|---|---|
| 🌿 Byte Meadow | 1 | x1 | Rogue Drone | 👑 Glitch King |
| 🏜️ Circuit Canyon | 6 | x4 | Scrap Hunter | 👑 Rust Titan |
| 🌃 Neon Spires | 15 | x16 | Neon Wraith | 👑 Overmind |

Boss hồi sinh sau 2 đến 3 phút và cả server được báo. **Ai góp sát thương đều được thưởng**, nên người chơi có lý do đánh boss cùng nhau.

## 🤖 Bot (7 loại)

| Bot | Độ hiếm | Giá |
|---|---|---|
| Scout Bot | Common | 100 |
| Miner Bot | Common | 750 |
| Guard Bot | Rare | 1.5K |
| Laser Bot | Rare | 6K |
| Harvester X | Epic | 18K |
| Titan Drone | Epic | 70K |
| Quantum Bot | Legendary | 300K |

- Mỗi bot có chỉ số **gather** (data/giây) và **attack** (sát thương/giây). Có thể nâng cấp tới Lv.10, mỗi cấp +25%.
- Chỉ **4 bot mạnh nhất** được ra trận (Game Pass Bot Slots +3). Bot dư có thể Recycle để lấy lại 30% giá.
- Bot ra trận **bay theo sau lưng** người chơi, có vệt sáng. Người chơi khác cũng nhìn thấy đội bot của bạn, đây là thứ để khoe.

## ⚡ Kỹ năng AI Core

| Phím | Kỹ năng | Mở ở level | Tác dụng |
|---|---|---|---|
| Q | 💥 Pulse | 1 | Sóng xung kích gây sát thương quanh người |
| E | 💨 Dash | 3 | Lao về phía trước |
| R | ⚡ Overclock | 8 | Bot thu thập và bắn x2 trong 10 giây |
| F | 🛡️ Shield | 12 | Giảm 70% sát thương trong 6 giây |

Trên điện thoại có sẵn nút bấm cho từng kỹ năng và nút 💾 thu thập.

## 💎 Shop

Shop **không có trứng hay hộp quay ngẫu nhiên trả bằng Robux**. Người mua luôn biết chính xác mình nhận được gì.

| Loại | Tên | Tác dụng |
|---|---|---|
| Game Pass | ⭐ VIP | x2 Credits khi upload, tag VIP trên đầu |
| Game Pass | 🤖 +3 Bot Slots | Mang thêm 3 bot ra trận |
| Game Pass | 🎒 Big Backpack | Ba lô x2 vĩnh viễn |
| Game Pass | 📡 Auto Upload | Đầy ba lô thì tự upload, khỏi chạy về |
| Game Pass | 👟 Turbo Boots | Chạy nhanh hơn |
| Dev Product | 🚀 Mega Boost | x2 Credits + x2 Gather trong 30 phút |
| Dev Product | 💰 / 💾 Boost | x2 Credits hoặc x2 Gather trong 15 phút |
| Dev Product | 💳 Credit Pack S / L | Số Credits tự tăng theo tiến độ người chơi |

## ▶️ Chạy thử trong Studio

1. Mở `NeuralFrontier.rbxlx` bằng Studio (**File → Open from File**), rồi bấm **Play**. Chưa publish vẫn chơi được ở chế độ thử, nhưng data không được lưu.
2. Muốn lưu data thì **Publish** game, rồi bật **Game Settings → Security → Enable Studio Access to API Services**.
3. Muốn thử nhiều người chơi: tab **Test → Clients and Servers → 2 Players → Start**.
4. Vào Creator Dashboard, tạo 5 Game Pass `VIP`, `BotSlots`, `BigBackpack`, `AutoUpload`, `TurboBoots` và 5 Developer Product `CreditBoost`, `GatherBoost`, `MegaBoost`, `CreditsSmall`, `CreditsLarge`.
5. Dán ID vào `src/shared/Config.luau`. Khi ID còn là `0`, nút trong shop sẽ hiện "Set ID".

Dùng Rojo thì chạy `rojo serve` trong thư mục này.

## 📁 Cấu trúc code

| File | Việc |
|---|---|
| `shared/Config.luau` | Toàn bộ số liệu: bot, vùng, quái, kỹ năng, nhiệm vụ, shop |
| `server/DataService.luau` | Lưu và tải data, retry, chế độ thử khi chưa publish |
| `server/WorldService.luau` | Dựng map bằng code: Terrain, Hub, cổng vùng, tinh thể data |
| `server/PlayerService.luau` | Thu thập, upload, mua và nâng cấp bot, kỹ năng, level, nhiệm vụ |
| `server/EnemyService.luau` | AI của quái và boss, đội bot tự bắn, chia thưởng boss |
| `server/MonetizationService.luau` | Game Pass, Dev Product (chỉ báo đã nhận sau khi lưu xong) |
| `client/Main.client.luau` | HUD, nút kỹ năng, các bảng Bots / Gear / Quests / Shop |
| `client/Effects.luau` | Vẽ đội bot bay theo, laser, số sát thương, nổ, hào quang |
| `client/Fx.luau` | Làm tinh thể xoay, đèn nhấp nháy |

Server quyết định mọi thứ (tiền, data, sát thương). Client chỉ gửi yêu cầu và hiển thị, nên khó hack tiền.

## 🎨 Nâng cấp đồ họa

Map hiện tại dựng hoàn toàn bằng code (Part + Terrain). Muốn đẹp hơn nhiều:
- Thay thân bot trong `client/Effects.luau` (hàm `makeBot`) bằng model tự làm trong Blender.
- Lấy model cây, đá, nhà từ Creator Store. **Nhớ kiểm tra model không chứa Script lạ** trước khi dùng.
