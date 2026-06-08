# ADR-0005: Chiến lược OIDC & token (JWT ES256 + JWKS)

**Tác giả:** Thành Lê Phước

- **Trạng thái:** Accepted
- **Ngày:** 2026-06-07
- **Bổ sung bởi:** [ADR-0014](0014-du-an-nha-nuoc-cong-an.md) — khóa ký đặt trong nước; chữ ký số pháp lý (roadmap) theo **CA quốc gia (NEAC)/Ban Cơ yếu**, không CA nước ngoài.

## Bối cảnh
Cần chọn loại token và cách bảo mật luồng OIDC. Hai trục: (1) JWT tự chứa vs opaque + introspection; (2) bảo mật luồng (PKCE, redirect_uri, refresh).

## Quyết định
- **Access token = JWT ký bất đối xứng (ES256)**, validate offline qua **JWKS** → RP tự xác minh, IdP rời hot path validate.
- **TTL cân bằng 15–30′**; **refresh token rotation + reuse-detection** (thu hồi cả family); denylist khẩn cấp ở Redis (kiểm khi refresh).
- **Authorization code + PKCE bắt buộc**; **validate redirect_uri tuyệt đối**; `state` + `nonce`.
- **Một JWKS, xoay khóa có overlap** (giữ public key cũ đến khi mọi token ký bằng nó hết hạn). Private key bọc mã hóa (Vault/MASTER_KEY).

## Hệ quả
- **Tích cực:** scale tốt (validate offline); cô lập rủi ro thu hồi (TTL ngắn); chống open-redirect/CSRF/replay.
- **Tiêu cực:** JWT không thu hồi tức thì (bù bằng TTL ngắn + denylist); IdP vẫn ở trên đường login + refresh (TTL ngắn ⇒ tải refresh cao hơn — chọn 15–30′ để cân bằng).

## Phương án đã cân nhắc
- **Opaque token + introspection:** mỗi validate gọi về IdP → IdP thành nút thắt cổ chai.
- **RS256:** ổn, nhưng ES256 nhỏ/nhanh hơn.
