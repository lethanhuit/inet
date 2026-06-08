# ADR-0015: Định vị & mandate — Kịch bản B (sản phẩm chủ quyền, tích hợp VNeID)

**Tác giả:** Thành Lê Phước

- **Trạng thái:** Accepted
- **Ngày:** 2026-06-09

## Bối cảnh
`risk-register.md` xác định **R1 (mandate + quyền tích hợp VNeID/CSDL dân cư)** là rủi ro *gating* lớn nhất. Hai kịch bản định vị: **(A)** xây CHO/CÙNG cơ quan nhà nước — phụ thuộc sponsor + MOU + cam kết cấp quyền VNeID *trước* khi đầu tư lớn; **(B)** xây **sản phẩm IdP+eKYC chủ quyền**, tích hợp VNeID như nguồn xác minh, **MVP chạy độc lập**. ADR-0014 đặt chuẩn *government-grade* (chủ quyền, trong nước, PKI quốc gia, cấp độ ATTT) — **giữ nguyên**.

## Quyết định
**Chọn Kịch bản B.** Xây **nền tảng IdP+eKYC chủ quyền (government-grade)**, **tích hợp VNeID như nguồn xác minh cấp cao**, phục vụ **khu vực công & doanh nghiệp**. **Không** đặt điều kiện tiên quyết là "được chỉ định làm hệ định danh quốc gia". Cụ thể:
- **MVP chạy độc lập** bằng provider eKYC thương mại (FPT.AI…) qua adapter `Verifier`; **VNeID cắm vào khi được cấp phép** → không bị chặn cổng. (Refine **ADR-0012**: VNeID là *mục tiêu tích hợp ưu tiên*, **không** *điều kiện chặn MVP*.)
- **Giữ trọn chuẩn ADR-0014** (chủ quyền dữ liệu, hạ tầng trong nước/on-prem, PKI quốc gia, cấp độ ATTT) — vừa là yêu cầu, vừa là **lợi thế bán hàng**.
- **Đường nâng cấp lên A để mở:** nếu sau này có sponsor/đề án nhà nước → nâng lên vai trò chính thức (đường tiến hóa, không phải điều kiện).

## Hệ quả
- **Tích cực:** **gỡ thế chặn cổng của R1**; bắt đầu & tạo giá trị được ngay; giữ định vị chủ quyền + đường tới khu vực công; thị trường rộng hơn (công + tư).
- **Tiêu cực:** định vị **khiêm tốn hơn** "hệ định danh quốc gia chính thức"; tính năng đỉnh (IAL3 qua VNeID, chữ ký số pháp lý) vẫn cần cấp phép/CA quốc gia → thuộc lộ trình; phải cạnh tranh như một sản phẩm.
- **Refine:** ADR-0012 (VNeID "bắt buộc" → "mục tiêu ưu tiên, không chặn MVP"); risk register **R1 hạ mức** (🔴→🟠) nhờ MVP độc lập.

## Phương án đã cân nhắc
- **Kịch bản A (cho/cùng nhà nước):** định vị mạnh nhất nhưng **phụ thuộc sponsor + cấp quyền VNeID trước** → rủi ro gating cao, có thể kẹt vô thời hạn. Giữ làm **đường nâng cấp**, không phải điểm khởi đầu.
