# 🌐 AI Empire: Garage to AGI (Roblox) — v5

Game **quản lý công ty AI**, mỗi server 1 người chơi, **giao diện tiếng Anh**. Hướng dẫn này viết bằng tiếng Việt cho người làm game.

Người chơi bắt đầu từ một **garage** năm 2015. Trên đường lớn lên thành **Global HQ 8 tầng, 240 nhân viên**, họ sẽ: thuê nhân sự chia theo **phòng ban**, sắm bàn ghế máy tính, nghiên cứu R&D theo từng năm, xây xưởng compute, **thiết kế và ra mắt model AI**, chờ báo chí chấm điểm, **leo hạng AI Arena** đấu với 6 công ty đối thủ, xử lý **sự kiện bất ngờ**, mua cổ phần và mở rộng ra toàn cầu.

## ✨ Chất riêng của game

| Tính năng | Mô tả |
|---|---|
| 🏆 **AI Arena** | Model tốt nhất của bạn đấu với model của 6 công ty đối thủ. Đối thủ **tự ra model mới** theo thời gian, và mỗi lần ra thì **cổ phiếu của họ nhảy**. Đứng **#1 được +25% người dùng**, top 3 được +10%. |
| 📱 **Hype Feed** | Mỗi lần ra mắt, mạng xã hội ảo tràn bình luận khen chê theo điểm báo chí. Bình luận hiện cả trên màn hình **Hype Wall** ở sảnh. |
| ⚡ **Sự kiện ngẫu nhiên** | Thiếu GPU, meme viral, lỗ hổng bảo mật, nhà nghiên cứu ngôi sao, quỹ đầu tư rót vốn, hackathon, bị kiện bản quyền, crunch time... Mỗi sự kiện **có 2 lựa chọn**, và thời gian tạm dừng cho tới khi người chơi quyết định. |
| 🎯 **25 mục tiêu** | Dẫn người chơi đi từ nghiên cứu đầu tiên tới Global HQ, mỗi mục tiêu có thưởng $. |
| 😊 **Tinh thần nhân viên** | Tinh thần cao thì làm nhanh hơn, quá thấp thì nghỉ việc. Có **Team Party** để kéo tinh thần lên. |
| 🧩 **Phòng ban** | Engineering, Research Lab, Marketing, Hardware. Nhân viên ngồi theo khu, có thảm màu và biển tên phòng ban. Mỗi phòng ban có 5 cấp, mỗi cấp +15% năng suất. |

## 🏢 Tòa nhà 8 cấp

| Cấp | Cần doanh thu | Sức chứa |
|---|---|---|
| 🏚️ Garage (tường gạch, cửa cuốn) | – | 4 |
| 🏠 Small Office | $25K | 8 |
| 🏢 Big Office | $250K | 16 |
| 🏬 2-Floor Building | $2.5M | 40 |
| 🏙️ 3-Floor HQ | $25M | 60 |
| 🌆 4-Floor Campus | $250M | 96 |
| 🗼 Tech Tower (6 tầng) | $2.5B | 180 |
| 🌐 Global HQ (8 tầng) | $25B | 240 |

Từ Small Office trở lên có sảnh đón khách (mái che đèn neon, bồn cây, cột cờ), quầy cà phê, sofa, bảng trắng, cây xanh ở góc, sàn gỗ, thang máy, và màn hình **Hype Wall** ở sảnh.

## 🎨 Đồ họa

- **Nhân viên là avatar Roblox thật** (R15), áo màu theo vai trò, ngồi đúng tư thế, tay đặt lên bàn phím, tên hiện trên đầu. Nếu không tạo được avatar thì tự dùng nhân vật khối thay thế.
- Thành phố có đường, xe chạy, đèn đường tự bật ban đêm, đồi núi, chu kỳ ngày/đêm.
- Trụ sở 6 công ty đối thủ trên các lô đất xung quanh. Xưởng compute có băng chuyền chạy thật.

## 💎 Shop (8 Game Pass + 14 Developer Product)

| Tab | Món |
|---|---|
| 🔥 Hot | Starter Pack • Mega Boost • VIP • Series A |
| ⭐ Passes | Time Machine (tua x5) • **Golden Office** (+20% năng suất, nội thất vàng) • **Mega Factory** (x2 compute) • **PR Agency** (+30% độ hot) • Headhunter • Founder+ |
| ⚡ Boosts | x2 Revenue • x2 Staff Output • x2 Compute • Go Viral |
| 💰 Funding | **Seed Round / Series A / Series B**: tiền mặt tính theo doanh thu, nên mua lúc nào cũng hời |
| ⏩ Time | Finish research • Finish model • Skip 1 month / 1 quarter |
| 🦸 Team | **Hire a Legend** (nhân viên kỹ năng 90) • **Crisis Shield** (tự xử lý sự kiện xấu kế tiếp) |

Mấy món "xong ngay" mà lúc mua không có gì đang chạy thì tự đổi thành boost, người chơi không mất Robux oan.

## Cài đặt

1. Mở `AITycoon.rbxlx` bằng Studio (**File → Open from File**), rồi bấm **Play**. Chưa publish cũng chơi được ở chế độ thử (không lưu data).
2. Muốn lưu data: **Publish**, rồi bật **Game Settings → Security → Enable Studio Access to API Services**.
3. Đặt **Max Players = 1**.
4. Tạo Game Pass `VIP`, `TimeMachine`, `Headhunter`, `GoldenOffice`, `MegaFactory`, `PRAgency`, `FounderPlus`, `StarterPack`.
5. Tạo Developer Product `CashBoost`, `WorkBoost`, `ComputeBoost`, `MegaBoost`, `Viral`, `InstantResearch`, `InstantDev`, `SkipMonth`, `SkipQuarter`, `SeedRound`, `SeriesA`, `SeriesB`, `HireLegend`, `CrisisShield`.
6. Dán ID vào `src/shared/Config.luau`.

Dùng Rojo thì chạy `rojo serve` trong thư mục này.

## Kiến trúc

| Module | Việc |
|---|---|
| `CalendarService` | Ngày/tháng/năm, tốc độ, tạm dừng khi có sự kiện |
| `CompanyService` | Tòa nhà 8 cấp, chỗ ngồi theo phòng ban, avatar nhân viên, nội thất, Hype Wall, tiền, các hệ số |
| `StaffService` | Tuyển dụng, đào tạo, lương, tinh thần, team party, phòng ban |
| `ResearchService` / `FactoryService` | R&D theo năm / xưởng compute |
| `ModelService` | Thiết kế, ra mắt, chấm điểm, Hype Feed, AI Arena, đối thủ ra model mới, thị trường |
| `EventService` / `GoalService` | Sự kiện có lựa chọn / chuỗi mục tiêu |
| `StockService` | Cổ phần 6 đối thủ (giá nhảy khi họ ra model mới) |
| `WorldService` / `Visuals` | Thành phố, nội thất, avatar |
| `ProgressService` / `LeaderboardService` / `MonetizationService` | Quà + bán công ty / top tỷ phú / Robux |

Mọi con số và mọi chữ người chơi thấy nằm trong `src/shared/Config.luau`. Muốn dịch sang ngôn ngữ khác thì sửa ở đó và ở client.

## Lưu ý

- Thiết kế, tên, nội dung đều là của game mình. Game lấy cảm hứng từ thể loại tycoon / management sim nhưng không sao chép giao diện hay nội dung của game nào.
- Không bán vật phẩm ngẫu nhiên bằng Robux. Riêng lựa chọn "Fight in court" trong sự kiện là 50/50 nhưng chỉ dùng $ trong game.
- Tên model đặt tự động, không cho người chơi gõ chữ, nên không cần lọc chữ.
