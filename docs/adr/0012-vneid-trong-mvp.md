# ADR-0012: VNeID là nguồn eKYC chính thống trong MVP

**Tác giả:** Thành Lê Phước

- **Trạng thái:** Accepted
- **Ngày:** 2026-06-07
- **Bổ sung bởi:** [ADR-0014](0014-du-an-nha-nuoc-cong-an.md) — VNeID/CSDL dân cư (C06) là **bắt buộc + cần cấp phép** (Đề án 06), không chỉ khuyến nghị.

## Bối cảnh
ADR-0009 để ngỏ việc dùng VNeID. Cả hai sản phẩm mẫu đều gắn ID quốc gia (UAE PASS ↔ Emirates ID; NDA Key ↔ VNeID). Với định hướng định danh công dân ở VN, VNeID là nguồn xác minh chính thống, độ tin cậy cao.

## Quyết định
**Đưa VNeID vào MVP** như một **adapter trong module `ekyc`** (cùng `Verifier` interface với provider thương mại như FPT.AI). VNeID là nguồn xác minh cấp assurance cao; thiết kế IAL để VNeID có thể cấp mức cao hơn eKYC provider thường (cân nhắc IAL3).

## Hệ quả
- **Tích cực:** xác minh chính thống, chống giả mạo mạnh; phù hợp định hướng công dân; tham chiếu trực tiếp mô hình NDA Key (`did:nda`↔VNeID).
- **Tiêu cực:** phụ thuộc API/quy trình cấp phép của cơ quan VNeID (có thể chậm/thủ tục); cần **fallback** sang provider thương mại khi VNeID không khả dụng; ràng buộc tuân thủ chặt hơn.

## Phương án đã cân nhắc
- **Chỉ provider thương mại, VNeID để roadmap:** đơn giản hơn nhưng bỏ lỡ nguồn chính thống — không hợp định hướng công dân; cả hai mẫu đều có ID quốc gia.
