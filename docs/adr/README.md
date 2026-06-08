# Architecture Decision Records (ADR)

**Tác giả:** Thành Lê Phước

Nhật ký các **quyết định kiến trúc** của nền tảng Định danh trên Không gian mạng.

**Quy ước:**
- Mỗi ADR = **một quyết định**, được đánh số tăng dần, **bất biến**. Nếu sau này đổi → tạo ADR mới, đánh dấu ADR cũ là `Superseded by ADR-XXXX`.
- Trạng thái: `Proposed` → `Accepted` → `Superseded` / `Deprecated`.
- Định dạng: Nygard/MADR rút gọn (xem `0000-template.md`).
- Liên kết: ADR là chi tiết cho mục **§9 Architecture Decisions** trong bản đồ arc42.

## Mục lục

| # | Quyết định | Trạng thái |
|---|---|---|
| [0001](0001-mo-hinh-mot-pool.md) | Mô hình một pool (không multi-tenant) | Accepted |
| [0002](0002-tu-viet-idp.md) | Tự viết IdP, không Keycloak | Accepted |
| [0003](0003-topology-gon.md) | Topology gọn: core modular + SDS cô lập + workers | Accepted |
| [0004](0004-sds-va-mo-hinh-khoa.md) | SDS là service cô lập + mô hình khóa có version | Accepted |
| [0005](0005-oidc-token-strategy.md) | Chiến lược OIDC & token (JWT ES256 + JWKS) | Accepted |
| [0006](0006-postgres-first.md) | Postgres-first kể cả audit; Mongo hoãn | Accepted |
| [0007](0007-sqlc.md) | sqlc + pgxpool cho truy cập DB | Accepted |
| [0008](0008-kafka-messaging.md) | Kafka cho messaging/event bus | Accepted |
| [0009](0009-ekyc-adapter.md) | eKYC qua adapter nhà cung cấp | Accepted |
| [0010](0010-go-ddd-clean-arch.md) | Go + DDD/Clean Architecture + chi | Accepted |
| [0011](0011-trien-khai-k8s-observability.md) | Triển khai Docker→K8s + Envoy + OTel/SigNoz | Accepted |
| [0012](0012-vneid-trong-mvp.md) | VNeID là nguồn eKYC chính thống trong MVP | Accepted |
| [0013](0013-privacy-selective-disclosure.md) | Privacy & Selective Disclosure (mô hình tập trung) | Accepted |
| [0014](0014-du-an-nha-nuoc-cong-an.md) | Dự án nhà nước & công an — ràng buộc chủ quyền/tuân thủ (chi phối các ADR khác) | Accepted |
| [0015](0015-dinh-vi-mandate.md) | Định vị & mandate — Kịch bản B (sản phẩm chủ quyền, tích hợp VNeID) | Accepted |
