# 🧠 Trùm Công Nghệ: AI Tycoon (Roblox) — v2

Từ dev quèn gõ code trong phòng trọ thành **đế chế công nghệ**: farm token, lắp GPU, nuôi AI, **lẻn sang lab người khác trộm dữ liệu**, rồi **IPO** để thành Big Tech.

Map (phòng lab neon, kệ máy chủ, lõi AI, két dữ liệu, bảng xếp hạng) và UI đều **dựng bằng code**. Mở Baseplate trống, nạp script vào, bấm Play là chơi.

## Vòng lặp chính

```
💻 Gõ code ──▶ 🪙 Token ──▶ 🖥️ GPU tự đào ──▶ 🧠 Train AI ──▶ GPU xịn hơn ──┐
     ▲                                                                       │
     │      🕵️ Trộm ổ dữ liệu ở lab người khác / 🛡️ giữ két nhà mình         │
     │                                                                       ▼
     └──────────── 📈 IPO: reset, nhận cổ phiếu = +10% token vĩnh viễn ◀─────┘
```

| Tính năng | Chi tiết |
|---|---|
| 💻 Gõ code | Nút tròn bên phải màn hình, đặt cao hơn nút nhảy để không đụng trên điện thoại. |
| 🖥️ GPU | 6 tier: CPU cũ → GPU Gaming → GPU Pro → Tensor Core → Siêu máy tính → Chip Lượng Tử. |
| 🧠 Train AI | Đổ token vào AI. Lên level thì +15% token, mở GPU mới. AI tiến hoá qua 6 giai đoạn. |
| 🕵️ **Phi vụ dữ liệu** | Két ở mỗi lab tự sinh **ổ dữ liệu** (mỗi ổ = 90 giây đào). Chủ lab thu về thành token. Người khác **giữ E để trộm**, rồi ôm ổ chạy về Máy thu token của lab mình. Đang ôm thì chạy chậm, **chủ lab chạm vào là lấy lại**, trộm chết thì ổ cũng rơi lại. |
| 🛡️ Bảo vệ | Lab có **khiên** thì không bị trộm. Lab người mới (AI dưới Lv.3) cũng không bị trộm, và két vừa bị trộm có 20 giây hồi. |
| 📈 **IPO (Rebirth)** | Từ AI Lv.15 trở lên. Reset lab để nhận cổ phiếu: `sqrt(token kiếm được / 100K)`. Danh hiệu đi từ Startup Phòng Trọ lên tới Đế Chế Công Nghệ 👑 |
| 🎁 **Quà 7 ngày** | Quà to dần theo tốc độ đào, ngày 7 tặng thêm x2 Token 30 phút. Bỏ lỡ 1 ngày là chuỗi về ngày 1. Bảng quà tự mở khi vào game. |
| 🏆 **Top tỷ phú** | Bảng xếp hạng toàn game giữa map (OrderedDataStore), cập nhật mỗi 5 phút. |
| 🌃 **Đồ họa neon** | Cảnh đêm, sương tím, bloom, sàn lưới neon, cổng phát sáng, kệ có LED nhấp nháy, lõi AI có hạt sáng và đĩa quay. |
| 😴 Offline | GPU vẫn đào khi thoát game (tối đa 2 giờ, VIP 8 giờ). |

## 💎 Shop (15 món)

| Nhóm | Món | Hiệu ứng | Giá gợi ý |
|---|---|---|---|
| 🔥 Hot | 🎁 **Gói Khởi Nghiệp** (pass) | Nhận 1 lần: 3 GPU Gaming + 5.000 token + Mega Boost 30 phút | 49 R$ |
| 🔥 Hot | 🚀 **Mega Boost** | x2 Token + x2 Train trong 30 phút | 59 R$ |
| 🔥 Hot | ⭐ **VIP** (pass) | x2 token, +4 kệ VIP, offline 8 giờ, tag VIP | 249 R$ |
| Pass | 🤖 Auto Thu Token | Token từ GPU tự vào ví | 149 R$ |
| Pass | 🕵️ Siêu Đạo Chích | Trộm nhanh gấp 3, ôm 2 ổ, không bị chậm | 199 R$ |
| Pass | 📈 IPO+ | +50% cổ phiếu mỗi lần IPO | 299 R$ |
| Boost | 🪙 x2 Token / 🧠 x2 Train | 15 phút, mua thêm thì cộng dồn | 29 R$ |
| Time Warp | ⏩ 1h / 6h / 24h | Nhận ngay token bằng số giờ đào đó | 25 / 99 / 299 R$ |
| Khiên | 🛡️ 1 giờ / 8 giờ | Chống trộm | 15 / 79 R$ |

Có món rẻ để mua lần đầu (Gói Khởi Nghiệp, Khiên 1h), món tầm trung (boost) và món cao cấp (VIP, IPO+). Time Warp và Gói Khởi Nghiệp **tự tăng giá trị theo tiến độ**, nên lúc nào mua cũng thấy hời.

## Cài đặt

### Rojo (khuyên dùng)

```bash
rojo serve
```

Mở Studio, tạo **Baseplate**, rồi bấm **Connect** trong plugin Rojo.

### Copy tay

```
ReplicatedStorage
└── Shared (Folder)
    └── Config (ModuleScript)              ← src/shared/Config.luau
ServerScriptService
└── Server (Folder)
    ├── Main (Script)                      ← src/server/Main.server.luau
    ├── DataService (ModuleScript)
    ├── LabService (ModuleScript)
    ├── HeistService (ModuleScript)
    ├── ProgressService (ModuleScript)
    ├── LeaderboardService (ModuleScript)
    ├── MonetizationService (ModuleScript)
    └── Visuals (ModuleScript)
StarterPlayer
└── StarterPlayerScripts
    └── Client (Folder)
        ├── Main (LocalScript)             ← src/client/Main.client.luau
        └── Fx (ModuleScript)              ← src/client/Fx.luau
```

### Cấu hình trong Studio

1. **File → Publish to Roblox** (DataStore chỉ chạy khi game đã publish).
2. **Game Settings → Security → Enable Studio Access to API Services** = ON.
3. Đặt **Max Players = 8** (mỗi server có 8 lab).
4. **Lighting → Technology = Future** để đèn neon đẹp nhất. Script không tự đổi được cái này.
5. Muốn test trộm dữ liệu thì cần 2 người chơi: **Test → Clients and Servers → 2 Players → Start**.

### Tạo Game Pass và Dev Product

Vào [Creator Dashboard](https://create.roblox.com/dashboard/creations) → **Monetization**:

- **Passes**: `VIP`, `AutoCollect`, `MasterThief`, `IPOPlus`, `StarterPack`
- **Developer Products**: `TokenBoost`, `TrainBoost`, `MegaBoost`, `TimeWarp1H`, `TimeWarp6H`, `TimeWarp24H`, `Shield1H`, `Shield8H`

Dán **ID** vào `src/shared/Config.luau` (các chỗ `id = 0`). Mua thử trong Studio là **miễn phí**.

## Cân bằng game

Mọi con số đều nằm trong `src/shared/Config.luau`: `Gpus`, `AI`, `AIStages`, `Racks`, `Rebirth`, `CompanyRanks`, `Daily`, `Heist`, `Multipliers`, `ShopSections`.

## Kiến trúc

| Module | Việc |
|---|---|
| `LabService` | Lab, GPU, click, train AI, Máy thu token, gửi State cho client. Có hook để module khác cắm vào. |
| `HeistService` | Két, ổ dữ liệu, trộm, ôm ổ, bắt trộm, khiên |
| `ProgressService` | Quà 7 ngày, IPO |
| `LeaderboardService` | Bảng xếp hạng OrderedDataStore |
| `MonetizationService` | Game Pass, ProcessReceipt, Gói Khởi Nghiệp |
| `DataService` | DataStore, `schemaVersion` + chuyển data cũ, retry, autosave |
| `Visuals` / `Fx` | Dựng đồ họa phía server / hiệu ứng chuyển động phía client |

- Server quyết định mọi thứ. Client chỉ gửi yêu cầu. Remote có chống spam và chống auto-click.
- `ProcessReceipt` chỉ trả `PurchaseGranted` sau khi **lưu data thành công**, và nhớ `PurchaseId` để không cộng đồ hai lần.
- Data có `schemaVersion = 2`. Data v1 (trước khi có IPO) tự được nâng cấp lúc vào game.

## Lưu ý fair-play & luật Roblox

- Không bán vật phẩm ngẫu nhiên, nên không phải công khai tỉ lệ. Nếu sau này thêm quay thưởng hoặc trứng mua bằng Robux thì **bắt buộc hiện tỉ lệ**.
- Trộm chỉ lấy **ổ dữ liệu**, không bao giờ trừ token trong ví nạn nhân. Người mới được bảo vệ, nên người không nạp vẫn chơi vui.
- Map, tên và ý tưởng đều tự làm, không dùng asset hay thương hiệu của game khác.

## Ý tưởng tiếp theo

- [ ] Nhiệm vụ hằng ngày (gõ 500 code, trộm 3 ổ, train 2 level...)
- [ ] Sự kiện "Cơn sốt AI": x3 token toàn server 15 phút mỗi giờ
- [ ] Bẫy laser, chó robot canh két (bán bằng token)
- [ ] Skin lõi AI và skin kệ máy chủ (cosmetic, bán Robux)
- [ ] Session lock bằng [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore)
- [ ] Analytics (AnalyticsService): funnel lượt chơi đầu, tỉ lệ mở shop/mua
