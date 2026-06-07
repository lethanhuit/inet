# ADR-0010: Go + DDD/Clean Architecture + chi

- **Trạng thái:** Accepted
- **Ngày:** 2026-06-07

## Bối cảnh
Cần ngôn ngữ + cách tổ chức code. House dùng Go + Clean Architecture. Dịch vụ định danh cần hiệu năng, đúng-đắn, dễ test.

## Quyết định
- **Ngôn ngữ: Go** (hiệu năng, biên dịch tĩnh, hợp dịch vụ xác thực chịu tải).
- **Layering: DDD + Clean Architecture** — domain → application (CQRS commands/queries) → infrastructure → interfaces; mỗi module (`auth`/`user`/`IAL`/`admin`) tự chứa.
- **HTTP router: chi** (idiomatic, tương thích net/http) cho OIDC endpoints; **gRPC** cho liên lạc nội bộ (core↔SDS).
- Wiring DI thủ công trong `cmd` (không framework DI cho MVP).

## Hệ quả
- **Tích cực:** ranh giới sạch, dễ test (mock qua interface), khớp house; domain tách khỏi hạ tầng.
- **Tiêu cực:** boilerplate của Clean Architecture; cần kỷ luật giữ tầng.

## Phương án đã cân nhắc
- **Node.js/Java:** lệch house Go.
- **Layering phẳng (handler→service→repo):** đơn giản hơn nhưng lệch chuẩn DDD house đã chọn.
