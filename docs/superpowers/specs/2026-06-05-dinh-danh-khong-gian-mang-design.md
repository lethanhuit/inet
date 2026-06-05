# Thiết kế: Nền tảng Định danh trên Không gian mạng (MVP)

**Ngày:** 2026-06-05
**Trạng thái:** Đã duyệt thiết kế, chờ review spec

## 1. Mục tiêu & phạm vi

Xây dựng nền tảng định danh số gồm hai trụ cột bổ sung cho nhau:

- **eKYC** — xác minh "đúng người thật" (đọc giấy tờ, so khớp khuôn mặt, kiểm tra liveness).
- **IdP/SSO** — quản lý danh tính và đăng nhập một lần theo chuẩn OAuth 2.0 / OpenID Connect.

Tầm nhìn dài hạn: phục vụ nhiều đối tượng (doanh nghiệp, người chơi game, người dùng đại chúng, dịch vụ công). Kiến trúc thiết kế tổng quát, nhưng **MVP tập trung một lát cắt**: SSO/IdP nội bộ + eKYC dạng API xác minh.

### Quyết định cốt lõi

| Yếu tố | Quyết định |
|---|---|
| Backend | Go |
| Chuẩn IdP | OAuth 2.0 / OpenID Connect |
| Lõi IdP | Tự viết app, dùng thư viện đã kiểm chứng (`ory/fosite`) cho lớp token/crypto |
| eKYC engine | Tích hợp nhà cung cấp qua lớp adapter (không tự huấn luyện model) |
| Kiến trúc | Modular Monolith (một service Go, 4 module nội bộ) |
| Mô hình định danh | Tập trung (kiểu UAE PASS), KHÔNG theo SSI/phi tập trung |
| Xác thực | Passkey/FIDO (WebAuthn) + mật khẩu, MFA (TOTP) tùy chọn |
| Chiến lược token | JWT access token ký bất đối xứng (validate qua JWKS) + refresh token có xoay vòng |
| Khả năng mở rộng | Service stateless, scale ngang; MVP tải vừa nhưng kiến trúc sẵn sàng cho quy mô lớn |
| Triển khai | Docker container; Postgres + Redis là dependency |

### Sản phẩm tham khảo (benchmark)

- **UAE PASS** (uaepass.ae) — IdP quốc gia **tập trung**: SSO 15.000+ dịch vụ, sinh trắc, chữ ký số có giá trị pháp lý, Digital Vault, cấp độ định danh. **Đây là mô hình ta theo.**
- **NDA Key** (ndakey.vn) — mô hình **SSI/phi tập trung**: ví credential trên thiết bị, DID, blockchain (NDAChain), ZKP, Passkey/FIDO, eIDAS 2.0. Tham khảo về Passkey và quyền riêng tư; **không** theo kiến trúc phi tập trung này cho MVP.

### Lý do "tự viết app + thư viện cho lớp token"

Một IdP gồm 4 lớp: (1) crypto/token, (2) giao thức OAuth/OIDC, (3) nghiệp vụ, (4) UI/tích hợp. Lớp 1–2 là nơi 90% lỗ hổng nằm, đã chuẩn hóa toàn cầu, không tạo lợi thế cạnh tranh → dùng thư viện đã kiểm chứng. Lớp 3–4 là giá trị riêng → tự viết, làm chủ hoàn toàn. Tự hand-roll crypto token là anti-pattern bảo mật kinh điển.

## 2. Kiến trúc tổng thể

Modular Monolith: một binary Go, 4 module nội bộ với ranh giới rõ, giao tiếp qua interface (không gọi chéo struct nội bộ). Mỗi module có thể tách thành service riêng sau này mà không viết lại.

```
┌─────────────────────────────────────────────┐
│         identity-platform (Go, 1 binary)     │
│                                              │
│  ┌────────┐ ┌────────┐ ┌─────────┐ ┌───────┐ │
│  │  auth  │ │ ekyc   │ │identity │ │ admin │ │
│  │(fosite)│ │(adapter│ │(profile,│ │(client│ │
│  │OIDC/   │ │→ FPT/  │ │assurance│ │ mgmt, │ │
│  │OAuth2  │ │ VNPT)  │ │ level)  │ │ audit)│ │
│  └────────┘ └────────┘ └─────────┘ └───────┘ │
│        │         │          │         │      │
│     ┌──────────────────────────────────────┐ │
│     │   storage layer (interface)          │ │
│     └──────────────────────────────────────┘ │
└──────────────┬──────────────┬────────────────┘
               │              │
          PostgreSQL       Redis
       (users, clients,  (sessions, token
        verifications,    store, rate limit)
        audit log)
```

## 3. Các module

### 3.1 `auth` — Lõi OAuth2/OIDC
- Dùng `ory/fosite` làm động cơ OAuth/OIDC.
- Cung cấp: discovery endpoint (`/.well-known/openid-configuration`), authorization code flow + PKCE, refresh token, JWKS endpoint.
- Trang login & consent (tự viết UI).
- **Passkey/FIDO (WebAuthn)** — đăng nhập không mật khẩu/sinh trắc, dùng thư viện WebAuthn cho Go (vd `go-webauthn/webauthn`). Mật khẩu vẫn hỗ trợ làm phương án dự phòng.
- MFA tùy chọn (TOTP).
- **Token:** access token là JWT ký bất đối xứng (RS256/ES256) để relying party tự validate qua JWKS, không gọi ngược về IdP. TTL cân bằng (cỡ 15–30 phút) — đủ ngắn để hạn chế rủi ro thu hồi, đủ dài để không dồn tải refresh. **Refresh token có xoay vòng + phát hiện tái sử dụng** (reuse-detection → thu hồi cả "family"). Denylist khẩn cấp trong Redis chỉ kiểm ở bước refresh.
- **Xoay khóa ký:** mọi replica ký bằng khóa private dùng chung (từ secret store); JWKS công bố nhiều khóa theo `kid` để xoay khóa không gãy phiên.
- Nhúng claim `ial` (Identity Assurance Level) vào ID token.

### 3.2 `ekyc` — Xác minh danh tính
- Định nghĩa interface `Verifier` với các thao tác: đọc giấy tờ (OCR), so khớp khuôn mặt, kiểm tra liveness.
- Một adapter cụ thể gọi nhà cung cấp bên ngoài. FPT.AI là tích hợp tham chiếu đầu tiên; provider cụ thể là cấu hình, không ràng buộc kiến trúc.
- Lưu kết quả xác minh (verification record) + mức tin cậy. Ảnh gốc lưu ở object storage (xem §5), không lưu trong DB.
- **MVP xử lý đồng bộ** (gọi provider trong request). Vì provider chậm/bursty, phải **cô lập đường chậm** để một sự cố provider không làm sập hot path đăng nhập:
  - Giới hạn đồng thời (semaphore / pool xử lý riêng cho eKYC, tách khỏi pool của auth).
  - Timeout chặt + circuit breaker khi provider lỗi/chậm kéo dài.
  - Khi tải thực tăng → chuyển eKYC sang xử lý bất đồng bộ (queue + worker), tách scale độc lập (Phase 2, ranh giới đã sẵn).

### 3.3 `identity` — Hồ sơ & mức định danh
- Hồ sơ người dùng.
- **Identity Assurance Level (IAL)**:
  - IAL1 = tài khoản mới, chỉ email/SĐT.
  - IAL2 = đã eKYC thành công, xác minh người thật.
- Liên kết kết quả eKYC vào hồ sơ và nâng mức IAL.

### 3.4 `admin` — Quản trị
- Quản lý relying party (oauth_clients: client_id/secret, redirect_uri, scope).
- Xem audit log.

## 4. Luồng dữ liệu chính

### 4.1 Đăng nhập SSO
App → redirect tới `/authorize` → user login (+MFA nếu bật) → consent → cấp authorization code → app đổi code lấy ID token + access token (chứa claim `ial`).

### 4.2 eKYC
User đã đăng nhập → upload ảnh giấy tờ + selfie → `ekyc` gọi adapter nhà cung cấp → nhận kết quả → lưu verification record → `identity` nâng lên IAL2 → lần đăng nhập sau, token phản ánh mức mới.

## 5. Lưu trữ & bảo mật dữ liệu

- **PostgreSQL**: `users`, `oauth_clients`, `verifications`, `audit_log`. Truy cập qua connection pool.
- **Redis**: trạng thái dùng chung giữa các replica — session, authorization code/PKCE, token store của fosite, rate limiting, denylist token, cache cấu hình nóng (oauth_clients/JWKS).
- **Object storage** (ví dụ S3-compatible): lưu ảnh giấy tờ/selfie thay vì nhồi vào DB; stream upload, xử lý xong xóa ảnh gốc.
- **PII** (ảnh giấy tờ, số CCCD, khuôn mặt):
  - Mã hóa khi lưu (envelope encryption).
  - Ảnh gốc xóa sau khi xác minh xong; chỉ giữ kết quả + hash.
  - Tuân thủ **Nghị định 13/2023/NĐ-CP** về bảo vệ dữ liệu cá nhân: đồng ý rõ ràng, quyền xóa, nhật ký truy cập.
- **Audit log**: mọi sự kiện định danh (login, cấp token, eKYC) ghi log bất biến; ghi nhiều và tăng vô hạn nên thiết kế để tách sang kho riêng khi quy mô lớn (xem §9).

## 6. Xử lý lỗi

- Lỗi từ nhà cung cấp eKYC (timeout, ảnh mờ, không khớp) → trả mã lỗi rõ ràng cho client, không nâng IAL, cho phép thử lại có giới hạn (rate limit).
- Tách lỗi nghiệp vụ (4xx, hiển thị cho user) khỏi lỗi hệ thống (5xx, ghi log + cảnh báo).
- Adapter eKYC bọc timeout + retry + circuit breaker + giới hạn đồng thời (xem §3.2) để provider chậm/lỗi chỉ làm suy giảm eKYC, không làm sập hot path đăng nhập.

## 7. Chiến lược kiểm thử

- **Unit test** từng module qua interface (mock storage, mock eKYC verifier).
- **Integration test** luồng OIDC đầy đủ với fosite + Postgres/Redis thật (testcontainers).
- **eKYC test** dùng mock adapter trả các kịch bản (thành công, không khớp, lỗi provider) — không gọi API thật khi test.
- Theo TDD: viết test trước cho từng luồng.

## 8. Triển khai

- Đóng gói Docker, chạy container.
- Postgres + Redis là dependency.
- Cấu hình qua biến môi trường.
- Chưa cần Kubernetes cho MVP.

## 9. Khả năng mở rộng & yêu cầu phi chức năng

**Bối cảnh quy mô:** MVP phục vụ SSO nội bộ (tải vừa). Mục này KHÔNG đặt ra con số dung lượng cụ thể; mục tiêu là đảm bảo kiến trúc *không chặn đường* lên quy mô lớn (tầm nhìn B2C/quốc gia) — chọn sẵn những lựa chọn rẻ-mà-mở-đường ngay từ MVP, hoãn hạ tầng đắt cho tới khi tải thực đòi hỏi.

**Nguyên tắc:** hot path (auth/token) phải mỏng + stateless + scale ngang; đường chậm (eKYC) phải bị cô lập.

**Làm ngay trong MVP (rẻ, mở đường scale):**
- Service hoàn toàn stateless — mọi trạng thái ra Redis; không cần sticky session; chạy N replica sau load balancer L7.
- JWT access token + JWKS → relying party tự validate, IdP rời khỏi hot path validate.
- Connection pool tới Postgres.
- Rate limiting đa tầng (IP/user/client) + metrics/observability cơ bản (p99 theo endpoint, độ bão hòa pool).
- Object storage cho ảnh eKYC; cô lập đồng thời eKYC (semaphore + circuit breaker).
- Ranh giới module sạch để tách thành phần khi cần.

**Hoãn tới khi tải đòi hỏi (đắt):**
- Redis Cluster (MVP: primary + replica là đủ).
- Read replica Postgres + connection pooler ngoài.
- Tách worker eKYC bất đồng bộ, scale độc lập (Hướng C).
- Kho audit log riêng + autoscaling/K8s.

**Lưu ý quan trọng về tải của chính IdP:** JWT chỉ giảm tải *validate token* (RP tự làm), KHÔNG giảm tải *cấp/refresh token* — IdP vẫn nằm trọn trên đường login + refresh. TTL access token càng ngắn thì tần suất refresh càng cao → tải refresh tỉ lệ nghịch với TTL. Vì vậy chọn TTL cân bằng (15–30 phút); reuse-detection của refresh token vừa là thuộc tính bảo mật vừa là yếu tố chi phối lượng ghi store.

*Lựa chọn công cụ cụ thể (pooler, kho audit, hàng đợi…) để dành cho implementation plan.*

## 10. Tech stack & kiến trúc nội bộ

### Kiến trúc nội bộ
Mỗi module chia 3 lớp, giao tiếp qua interface (ports & adapters "lite"):
- **handler** (HTTP) → **service** (nghiệp vụ) → **repository** (interface lưu trữ + implementation).
- Storage và eKYC provider nằm sau interface → dễ mock, dễ thay, dễ test độc lập.
- Wiring phụ thuộc thủ công trong `main` (idiomatic Go, không dùng framework DI cho MVP).

### Bố cục thư mục
```
/cmd/server/main.go        # điểm vào, wiring
/internal/
  /auth/                   # OIDC, login, passkey, token, quản lý khóa
  /ekyc/                   # Verifier interface + adapter provider
  /identity/               # profile, IAL
  /admin/                  # client mgmt, audit
  /platform/               # config, db, redis, objectstore, middleware,
                           # observability, ratelimit, crypto/keys
/migrations/               # SQL migrations
/web/                      # template + static cho trang login/consent
```

### Thư viện đã chốt

| Mối quan tâm | Lựa chọn |
|---|---|
| HTTP router | **chi** |
| OAuth/OIDC | **ory/fosite** |
| Passkey/WebAuthn | **go-webauthn/webauthn** |
| Postgres driver | **jackc/pgx** + pgxpool |
| Truy vấn DB | **sqlc** (sinh code type-safe từ SQL thuần) |
| Migration | **goose** |
| Redis client | **redis/go-redis v9** |
| Rate limit | **go-redis/redis_rate** (token-bucket trên Redis) |
| Object storage | **minio-go** / aws-sdk-go-v2 (S3-compatible) |
| Logging | **log/slog** (stdlib) |
| Metrics | **prometheus/client_golang** |
| Tracing | **OpenTelemetry** (bật dần) |
| Config | **caarlos0/env** (12-factor, biến môi trường) |
| Validation | **go-playground/validator** |
| Test | **testing + testify + testcontainers-go**; mock viết tay theo interface |

**Phase 2:** hàng đợi cho eKYC async → **asynq** (Redis) hoặc **river** (Postgres).

## 11. Ngoài phạm vi MVP — Roadmap Phase 2+

Cố tình loại khỏi MVP để giữ trọng tâm vào vòng lặp giá trị chính (SSO an toàn + eKYC + nâng IAL). Ranh giới module được thiết kế sẵn để bổ sung mà không phải viết lại:

- **Chữ ký số** (ký tài liệu có giá trị pháp lý) — cần CA/chứng thư số, tích hợp nhà cung cấp ký số, tuân thủ Luật Giao dịch điện tử 2023. Là một module con đáng kể → Phase 2. Có thể gắn quyền ký với mức IAL cao (như UAE PASS).
- **SDK cho bên tích hợp** — đường tắt cho relying party; MVP đã dùng được qua thư viện OIDC chuẩn nên chưa cấp thiết.
- **Kho tài liệu / ví credential** (kiểu Digital Vault) — lưu & chia sẻ chọn lọc giấy tờ đã xác minh.
- **Định danh người chơi game** (lát cắt B2C/game).
- **Đa nhà cung cấp eKYC** (định tuyến/đối chiếu nhiều provider).
- **Tách microservices (Hướng B) / hàng đợi bất đồng bộ (Hướng C)**.
- **Social login** và **mô hình SSI/DID** (nếu sau này muốn lai với hướng NDA Key).
