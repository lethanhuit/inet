# ADR-0001: Mô hình một pool (không multi-tenant)

**Tác giả:** Thành Lê Phước

- **Trạng thái:** Accepted
- **Ngày:** 2026-06-07

## Bối cảnh
Nền tảng định danh có thể theo hai mô hình: (A) đa tenant — host định danh cho nhiều tổ chức tách biệt (kiểu Auth0/Keycloak realm); (B) một pool người dùng, nhiều ứng dụng tích hợp (kiểu VNeID/UAE PASS/SSO nội bộ). Khái niệm "tenant" ban đầu bê từ tài liệu O2O (mỗi merchant một tenant) nhưng chưa chắc hợp với nền tảng định danh.

## Quyết định
Chọn **Mô hình B — một pool người dùng duy nhất, nhiều relying party (RP/client)**. Đơn vị tích hợp là **RP/client** (mỗi game/app/dịch vụ), không phải tenant. Một issuer, một JWKS, một pool user (`email` unique).

## Hệ quả
- **Tích cực:** đơn giản hơn nhiều; **xóa rủi ro lớn nhất** (multi-tenant OIDC tự viết); chuẩn OIDC một issuer dễ tích hợp.
- **Tiêu cực:** nếu sau này cần bán IdP cho tổ chức ngoài → nâng cấp issuer/khóa/pool (không nhỏ). Hiện ngoài phạm vi.

## Phương án đã cân nhắc
- **A — đa tenant (issuer-per-tenant):** cô lập mạnh nhưng phải tự xây multi-tenant OIDC (phần Keycloak realms vốn cho không) — quá phức tạp/rủi ro cho MVP.
- **Lai (vài tenant nội bộ):** vẫn là A, chưa cần.
