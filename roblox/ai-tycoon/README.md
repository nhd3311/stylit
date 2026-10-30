# 🧠 Trùm Công Nghệ: AI Tycoon (Roblox)

Từ dev quèn gõ code trong phòng trọ thành trùm công nghệ: **farm token**, lắp GPU, **nuôi AI** mạnh lên, AI càng mạnh thì token về càng nhanh.
Kiếm Robux bằng **VIP**, **Auto Thu Token**, **boost** và **Time Warp**.

Map (phòng lab, kệ máy chủ, lõi AI) và UI đều **dựng bằng code**. Mở Baseplate trống, nạp script vào, bấm Play là chơi.

## Vòng lặp chính

```
💻 Gõ code (click) ──▶ 🪙 Token ──▶ 🖥️ Lắp/nâng GPU ──▶ token tự đào
                          │                                   │
                          ▼                                   ▼
                    🧠 Train AI  ◀────────────────  📦 Máy thu token
                          │
                          ▼
           Level AI ↑  ⇒  +15% token/level, click mạnh hơn, mở GPU xịn hơn
```

| Tính năng | Chi tiết |
|---|---|
| 💻 Gõ code | Nút to góc phải. Mỗi click được token, AI level càng cao click càng nhiều. |
| 🖥️ GPU | 6 tier: CPU cũ → GPU Gaming → GPU Pro → Tensor Core → Siêu máy tính → Chip Lượng Tử. Bấm **E** ở kệ để lắp/nâng cấp. |
| 📦 Thu token | GPU đổ token vào kệ (chứa tối đa 5 phút). Đi tới **Máy thu token** bấm E để gom. |
| 🧠 Train AI | Menu **🧠 AI** → đổ 10% / 50% / 100% token vào AI. 1 token = 1 XP. |
| 🌐 Tiến hoá | Bot Ngáo → Trợ Lý Ảo → Coder AI → Thiên Tài Số → AGI → Siêu Trí Tuệ. Lõi AI giữa phòng to lên và đổi màu. |
| 🔓 Mở rộng | 4 kệ miễn phí, kệ 5–8 mua bằng token, kệ 9–12 chỉ VIP. |
| 😴 Offline | GPU vẫn đào khi thoát game (tối đa 2 giờ, VIP 8 giờ). |
| 💾 Lưu data | DataStore, tự lưu mỗi 2 phút + khi thoát + khi server tắt + ngay sau khi mua bằng Robux. |

## Kiếm Robux

| Loại | Tên | Hiệu ứng |
|---|---|---|
| Game Pass | ⭐ VIP | x2 token (cả click lẫn GPU), +4 kệ VIP, offline 8 giờ, tag VIP trên đầu và trong chat |
| Game Pass | 🤖 Auto Thu Token | Token từ GPU tự vào ví, khỏi đi thu |
| Dev Product | 🪙 x2 Token 15 phút | Cộng dồn nếu mua nhiều lần |
| Dev Product | 🧠 x2 Train AI 15 phút | 1 token = 2 XP |
| Dev Product | ⏩ Time Warp 1 giờ / 6 giờ | Nhận ngay số token bằng 1 hoặc 6 giờ đào hiện tại |

Time Warp **tự scale theo tiến độ**: người chơi càng mạnh thì món này càng đáng tiền, nên bán được cả lúc đầu lẫn lúc cuối game.

Giá gợi ý: VIP 249 R$, Auto Thu Token 149 R$, boost 29–39 R$, Time Warp 1h 25 R$, Time Warp 6h 99 R$.

## Cài đặt

### Cách 1: Rojo (khuyên dùng)

1. Cài [Rojo](https://rojo.space) (plugin Studio + CLI, hoặc extension Rojo trong VS Code).
2. Trong thư mục này chạy `rojo serve`.
3. Mở Roblox Studio → tạo **Baseplate** → plugin Rojo → **Connect**.

### Cách 2: Copy tay

```
ReplicatedStorage
└── Shared (Folder)
    └── Config (ModuleScript)              ← src/shared/Config.luau
ServerScriptService
└── Server (Folder)
    ├── Main (Script)                      ← src/server/Main.server.luau
    ├── DataService (ModuleScript)         ← src/server/DataService.luau
    ├── LabService (ModuleScript)          ← src/server/LabService.luau
    └── MonetizationService (ModuleScript) ← src/server/MonetizationService.luau
StarterPlayer
└── StarterPlayerScripts
    └── Client (Folder)
        └── Main (LocalScript)             ← src/client/Main.client.luau
```

> Tên phải khớp chính xác vì code tìm nhau bằng tên.

### Cấu hình trong Studio

1. **File → Publish to Roblox** (DataStore chỉ chạy khi game đã publish).
2. **Game Settings → Security → Enable Studio Access to API Services** = ON.
3. Đặt **Max Players = 8** (mỗi server có 8 lab, khớp `Config.MaxLabs`).

### Tạo Game Pass và Dev Product

1. [Creator Dashboard](https://create.roblox.com/dashboard/creations) → chọn game → **Monetization**.
2. **Passes**: tạo `VIP` và `Auto Thu Token` → bật **Item for Sale** → đặt giá.
3. **Developer Products**: tạo `TokenBoost`, `TrainBoost`, `TimeWarp1H`, `TimeWarp6H`.
4. Dán **ID** vào `src/shared/Config.luau` (các chỗ `id = 0`).

Mua thử trong Studio là **miễn phí**. Giá trong shop được lấy trực tiếp từ Roblox.

## Cân bằng game

Mọi con số nằm trong `src/shared/Config.luau`:

- `Config.Gpus`: tốc độ, giá, level AI cần để mở từng GPU
- `Config.AI`: XP cần mỗi level (`XpBase * XpGrowth^(level-1)`), % token mỗi level
- `Config.AIStages`: tên, màu, kích thước lõi AI theo từng giai đoạn
- `Config.Racks`: số kệ, giá mở kệ, sức chứa
- `Config.Multipliers`: hệ số VIP và boost

## Kiến trúc

```
Client (UI) ──Action──▶ Server (LabService kiểm tra tiền/quyền)
            ◀──State───  (token, tốc độ, level, XP, boost; gửi mỗi giây)
            ◀──Notify──  (thông báo nhỏ, level up)
```

- Client **không bao giờ** tự cộng token. Click cũng do server đếm và có giới hạn ~14 click/giây chống auto-click.
- `ProcessReceipt` chỉ trả `PurchaseGranted` sau khi **lưu data thành công**, và nhớ `PurchaseId` để không cộng 2 lần.

## Ý tưởng nâng cấp

- [ ] **IPO (Rebirth)**: bán công ty, reset lab, nhận cổ phiếu cho hệ số token vĩnh viễn.
- [ ] Nhân viên: thuê intern/senior tự gõ code giúp.
- [ ] Nhiệm vụ hằng ngày + phần thưởng đăng nhập.
- [ ] Bảng xếp hạng "Top tỷ phú công nghệ" (OrderedDataStore theo `totalEarned`).
- [ ] Sự kiện: "Hacker tấn công", "Mất điện", "Cơn sốt AI x3 token".
- [ ] Dùng [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) để có session lock.
