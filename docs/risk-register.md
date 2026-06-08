# Risk Register — Nền tảng Định danh trên Không gian mạng

**Tác giả:** Thành Lê Phước

**Ngày:** 2026-06-09 · **Loại:** Sổ đăng ký rủi ro (sống — cập nhật định kỳ)

> Kết tinh phần phân tích "thách thức lớn nhất & cách giải quyết". Nguồn chân lý cho **rủi ro & giảm thiểu**; quyết định kiến trúc xem `docs/adr/`.

**Thang đánh giá:** Khả năng / Tác động ∈ {Cao, TB, Thấp}. Mức: 🔴 nghiêm trọng (xử lý trước) · 🟠 cao · 🟡 trung bình.

## Bảng rủi ro

| # | Rủi ro | Khả năng | Tác động | Mức | Giảm thiểu & khuyến nghị | Chủ sở hữu |
|---|---|---|---|---|---|---|
| **R1** | **Không được cấp quyền tích hợp VNeID/CSDL dân cư & thiếu mandate** (rủi ro *gating*) | Cao | Nghiêm trọng | 🟠 | **✅ Đã chốt Kịch bản B (ADR-0015)** → MVP chạy độc lập qua provider thương mại, **gỡ thế chặn cổng**; tiếp cận **C06** để cắm VNeID khi được cấp phép | Lãnh đạo / BD |
| **R2** | **Lỗ hổng trong IdP tự viết** (PKCE, redirect_uri, refresh, xoay khóa) | TB | Nghiêm trọng | 🔴 | Dùng **fosite** (không hand-roll); **threat model**; chạy **OIDC conformance test**; **pentest + audit bảo mật độc lập** trước go-live; integration test các đường hiểm | Security / Eng lead |
| **R3** | **Rò rỉ PII / sai vòng đời khóa** (rotation, re-encrypt) | TB | Nghiêm trọng | 🔴 | SDS cô lập + envelope encryption + khóa có version (ADR-0004); **HSM**; test kỹ rotation/re-encrypt; RBAC + audit; chỉ truy cập theo `kyc_id` | Security |
| **R4** | **Không đạt kiểm định ATTT cấp độ 4–5 đúng hạn** | TB–Cao | Cao | 🟠 | **Khởi động kiểm định từ sớm**; thiết kế theo NĐ85/2016 + TCVN 11930; SOC + giám sát; dự trù thời gian/chi phí | Compliance |
| **R5** | **Tập trung = SPOF** — sự cố gây ngừng dịch vụ diện rộng | TB | Cao | 🟠 | DR + PITR; **nâng đa-DC sớm hơn** nếu quy mô quốc gia; degrade graceful (login chạy khi eKYC chậm — đã thiết kế); SLA + giám sát | SRE |
| **R6** | **Niềm tin & quyền riêng tư** (trung tâm thấy hết dữ liệu) | TB | Cao | 🟠 | Tiết lộ tối thiểu + pairwise sub (ADR-0013); audit độc lập; minh bạch chính sách dữ liệu | Architect / Legal |
| **R7** | **Phạm vi vượt năng lực đội / trượt tiến độ** | Cao | Cao | 🟠 | MVP **mỏng**, phân mảnh nhỏ theo TDD; **hoãn** chữ ký số/ví/ZKP; bổ sung chuyên gia bảo mật/định danh | PM / Eng lead |
| **R8** | **Phụ thuộc provider eKYC** (chậm/lỗi/chi phí) | TB | TB | 🟡 | Adapter đa provider + timeout + circuit breaker (ADR-0009); fallback giữa VNeID ↔ thương mại | Eng |

## Quyết định gating (go/no-go) — cần chốt sớm

> ✅ **ĐÃ CHỐT (2026-06-09): Kịch bản B** — xem [ADR-0015](adr/0015-dinh-vi-mandate.md). MVP chạy độc lập, VNeID cắm khi được cấp phép → R1 hạ mức.

**Định vị dự án (ảnh hưởng mọi thứ phía sau):**
- **(A) Xây CHO/CÙNG cơ quan nhà nước** → điều kiện đi tiếp: có **sponsor nhà nước + MOU/đề án được phê duyệt + cam kết cấp quyền VNeID**. Không có → **không** đổ lực vào phần "cấp nhà nước".
- **(B) Sản phẩm IdP+eKYC chủ quyền cho doanh nghiệp, *tích hợp* VNeID** → khả thi hơn, ít bị chặn cổng. **Khuyến nghị mặc định nếu chưa có sponsor nhà nước.**

**Mốc M0 (trước khi build lõi định danh phụ thuộc VNeID):** đạt cam kết/được cấp quyền truy cập VNeID, hoặc xác nhận MVP chạy độc lập bằng provider thương mại (kịch bản B). → Nếu trượt M0: **pivot sang B**, không dừng dự án.

## Nguyên tắc xuyên suốt
Rủi ro **kỹ thuật** (R2–R8) đều **giải được bằng kỷ luật kỹ thuật** và đã có hướng trong các ADR. Rủi ro **thể chế (R1)** đã được **gỡ thế chặn cổng nhờ chốt Kịch bản B** (ADR-0015 — MVP độc lập); vẫn tiếp tục theo đuổi quyền tích hợp VNeID cho các tính năng cấp cao (IAL3, chữ ký số pháp lý).
