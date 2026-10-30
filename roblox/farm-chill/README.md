# 🌾 Farm Chill (Roblox)

Game nông trại trên Roblox: trồng cây, nuôi thú, bán nông sản lấy coin, mở rộng đất.
Kiếm Robux bằng **Game Pass VIP** và **Developer Product** (boost, coin, chín ngay).

Toàn bộ map (ruộng, chuồng, biển tên) và UI đều được **dựng bằng code**. Mở Baseplate trống, nạp script vào, bấm Play là chơi được luôn.

## Gameplay

| Tính năng | Chi tiết |
|---|---|
| 🌱 Trồng cây | 6 loại: Lúa mì, Cà rốt, Cà chua, Dưa hấu, Bí ngô, Thanh long. Chọn hạt ở thanh dưới màn hình, đi tới ô đất bấm **E**. |
| ⏳ Lớn cả khi offline | Thoát game vẫn tính giờ, quay lại là cây chín. |
| 🐔 Nuôi thú | Gà → Trứng, Bò → Sữa, Heo → Nấm truffle. Thú tự cho sản phẩm vào kho. |
| 💰 Bán | Menu **🎒 Kho** → **Bán hết**. |
| 🔓 Mở rộng | 4 ô miễn phí, ô 5–8 mua bằng coin (giá tăng dần), ô 9–12 chỉ dành cho VIP. |
| 💾 Lưu data | DataStore, tự lưu mỗi 2 phút + khi thoát + khi server tắt + ngay sau khi mua bằng Robux. |

## Kiếm Robux

| Loại | Tên | Hiệu ứng |
|---|---|---|
| Game Pass | ⭐ VIP | x2 coin khi bán, +4 ô đất VIP, +2 chỗ mỗi chuồng, tag VIP trên đầu và trong chat |
| Game Pass | 🌱 Cây Lớn Nhanh | Cây lớn nhanh x1.5 vĩnh viễn |
| Dev Product | 💰 x2 Coin 15 phút | Cộng dồn nếu mua nhiều lần |
| Dev Product | ⚡ x2 Tốc độ lớn 15 phút | Cộng dồn nếu mua nhiều lần |
| Dev Product | 🌟 Chín ngay | Tất cả cây đang trồng chín ngay |
| Dev Product | 🪙 1.000 / 12.000 Coin | Cộng coin ngay |

Các hệ số nhân với nhau: VIP + boost coin = **x4 coin**, Pass lớn nhanh + boost lớn = **x3 tốc độ**.

Giá gợi ý cho người mới: VIP 199 R$, Cây Lớn Nhanh 99 R$, boost 25–35 R$, Chín ngay 15 R$, 1.000 coin 20 R$, 12.000 coin 149 R$.

## Cài đặt

### Cách 1: Rojo (khuyên dùng)

1. Cài [Rojo](https://rojo.space) (plugin Studio + CLI, hoặc extension Rojo trong VS Code).
2. Trong thư mục này chạy:
   ```bash
   rojo serve
   ```
3. Mở Roblox Studio → tạo **Baseplate** → plugin Rojo → **Connect**.

### Cách 2: Copy tay

Tạo đúng cấu trúc sau trong Studio, rồi dán code của từng file vào:

```
ReplicatedStorage
└── Shared (Folder)
    └── Config (ModuleScript)          ← src/shared/Config.luau
ServerScriptService
└── Server (Folder)
    ├── Main (Script)                  ← src/server/Main.server.luau
    ├── DataService (ModuleScript)     ← src/server/DataService.luau
    ├── FarmService (ModuleScript)     ← src/server/FarmService.luau
    └── MonetizationService (ModuleScript) ← src/server/MonetizationService.luau
StarterPlayer
└── StarterPlayerScripts
    └── Client (Folder)
        └── Main (LocalScript)         ← src/client/Main.client.luau
```

> Tên phải khớp chính xác vì code tìm nhau bằng tên.

### Cấu hình bắt buộc trong Studio

1. **File → Publish to Roblox** (DataStore chỉ chạy khi game đã publish).
2. **Game Settings → Security → Enable Studio Access to API Services** = ON (để test lưu data trong Studio).
3. **Game Settings → Places → Max Players = 8** (mỗi server có 8 farm, khớp `Config.MaxFarms`).

### Tạo Game Pass và Dev Product

1. Vào [Creator Dashboard](https://create.roblox.com/dashboard/creations) → chọn game → **Monetization**.
2. **Passes**: tạo `VIP` và `Cây Lớn Nhanh` → bật **Item for Sale** → đặt giá.
3. **Developer Products**: tạo 5 cái tương ứng `CoinBoost`, `GrowBoost`, `InstantGrow`, `Coins1K`, `Coins10K`.
4. Copy **ID** của từng cái và dán vào `src/shared/Config.luau` (các chỗ `id = 0`).

Mua thử trong Studio là **miễn phí** (test purchase). Giá hiển thị trong shop được lấy trực tiếp từ Roblox nên không cần sửa code khi đổi giá.

## Cân bằng game

Mọi con số nằm trong `src/shared/Config.luau`: giá hạt, giá bán, thời gian lớn, giá thú, giá mở ô, hệ số VIP/boost. Thêm cây hoặc thú mới chỉ cần thêm một dòng vào bảng, UI sẽ tự cập nhật.

## Kiến trúc

```
Client (UI) ──Action──▶ Server (FarmService kiểm tra tiền/quyền)
            ◀──State───  (snapshot coin, kho, thú, boost)
            ◀──Notify──  (thông báo nhỏ)
```

- Client **không bao giờ** tự cộng tiền. Mọi thứ đều qua server, nên exploiter không hack coin được.
- `ProcessReceipt` chỉ trả `PurchaseGranted` sau khi **lưu data thành công**, và nhớ `PurchaseId` để không cộng 2 lần.
- Remote có giới hạn spam (0.15 giây/lần).

## Lưu ý luật Roblox

- Không bán vật phẩm **ngẫu nhiên** (kiểu trứng ra pet random) bằng Robux nếu không công khai tỉ lệ. Hiện game chưa có cái này. Nếu sau này thêm thì phải hiện tỉ lệ rõ ràng.
- Khi lên Experience Guidelines / Maturity questionnaire nhớ khai có bán vật phẩm bằng Robux.

## Ý tưởng nâng cấp

- [ ] Dùng [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) để có session lock (chống mất data khi đổi server liên tục).
- [ ] Hệ thống level + nhiệm vụ hằng ngày (giữ chân người chơi).
- [ ] Bảng xếp hạng toàn server (OrderedDataStore theo `totalEarned`).
- [ ] Rebirth: reset farm đổi lấy hệ số coin vĩnh viễn.
- [ ] Model 3D thật cho cây và thú thay cho khối màu.
- [ ] Pass **Auto Thu Hoạch** và **Auto Bán**.
