# ADR-0009: eKYC qua adapter nhà cung cấp

**Tác giả:** Thành Lê Phước

- **Trạng thái:** Accepted
- **Ngày:** 2026-06-07

## Bối cảnh
eKYC cần OCR giấy tờ + so khớp khuôn mặt + liveness. Tự huấn luyện model AI tốn dữ liệu/GPU/thời gian; thị trường có nhà cung cấp chín (FPT.AI, VNPT, AWS).

## Quyết định
**Tích hợp nhà cung cấp qua một lớp adapter** (`Verifier` interface), bắt đầu với một provider tham chiếu (FPT.AI). Chọn provider là **cấu hình**, không ràng buộc kiến trúc. eKYC **xử lý có bao vây** (semaphore + timeout + circuit breaker) để provider chậm/lỗi không sập hot path auth.

## Hệ quả
- **Tích cực:** ra MVP nhanh, độ chính xác cao, dồn công sức vào nền tảng; dễ thay/đa provider sau.
- **Tiêu cực:** phụ thuộc bên thứ ba (đã cô lập qua adapter + circuit breaker); chi phí theo lượt gọi.

## Phương án đã cân nhắc
- **Tự xây model in-house:** kiểm soát toàn bộ nhưng tốn nhiều nguồn lực — để roadmap nếu cần.
- **VNeID làm nguồn eKYC chính thống:** đang để ngỏ (MVP vs roadmap) — sẽ ghi ADR riêng khi quyết.
