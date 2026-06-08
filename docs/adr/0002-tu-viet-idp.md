# ADR-0002: Tự viết IdP, không dùng Keycloak

**Tác giả:** Thành Lê Phước

- **Trạng thái:** Accepted
- **Ngày:** 2026-06-07

## Bối cảnh
Cần một IdP OAuth2/OIDC. Lựa chọn: tự viết, dùng nền sẵn (Keycloak/Ory/Zitadel), hay tự viết app + thư viện cho lớp token. Tài liệu house O2O có nhắc Keycloak, nhưng mục tiêu của nền tảng là **tự chủ lớp định danh**.

## Quyết định
**Tự viết IdP bằng Go**, nhưng **dùng thư viện đã kiểm chứng cho lớp token/crypto** (ví dụ `ory/fosite`) — không tự hand-roll JWT/JWKS/crypto, và không dùng Keycloak trọn gói. Sở hữu hoàn toàn lớp nghiệp vụ, UI, luồng định danh.

## Hệ quả
- **Tích cực:** làm chủ codebase, kiến trúc, nghiệp vụ; không lệ thuộc sản phẩm ngoài; an toàn ở lớp token nhờ thư viện.
- **Tiêu cực:** phải tự đảm bảo đúng-đắn luồng OIDC (PKCE, redirect_uri, xoay khóa, refresh) — gánh trách nhiệm bảo mật cao hơn dùng nền sẵn.

## Phương án đã cân nhắc
- **Keycloak/Ory trọn gói:** nhanh, đã chứng nhận OIDC, nhưng lệ thuộc, khó tùy biến sâu, không "sở hữu".
- **Hand-roll cả crypto/token:** rủi ro bảo mật không được trả công — anti-pattern.
