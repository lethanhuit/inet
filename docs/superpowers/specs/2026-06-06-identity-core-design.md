# Spec #1 — identity-core (arc42)

**Ngày:** 2026-06-06
**Trạng thái:** Draft (đã chỉnh theo Mô hình B — một pool), chờ review
**Tài liệu cha:** Bản đồ kiến trúc (`2026-06-05-dinh-danh-khong-gian-mang-design.md`)
**Service anh em:** `sensitive-data-service` (SDS) — Spec #2 (chuyển thể từ PDF)

> **Mô hình: một pool người dùng, nhiều relying party (RP/client).** Một issuer duy nhất (kiểu VNeID/UAE PASS/SSO nội bộ). KHÔNG multi-tenant. Trọng tâm spec: **OIDC chuẩn làm thật chắc** + eKYC/IAL.

---

## 1. Introduction and Goals

`identity-core` là IdP/SSO theo OAuth 2.0 / OpenID Connect cho **một tập người dùng duy nhất**; các ứng dụng (game/web/dịch vụ) tích hợp dưới dạng **relying party (client)**. Quản lý hồ sơ user và **mức định danh (IAL)**; gọi SDS để lưu/đọc PII (không tự lưu PII plaintext).

**Phạm vi:** `auth` (OIDC), `user`, `IAL`, `admin` (quản lý client/RP + user + audit).
**Ngoài phạm vi:** mã hóa/lưu PII (→ SDS); multi-tenant (→ roadmap nếu sau này bán IdP cho tổ chức ngoài); chữ ký số, SDK, ví.

**Quality goals (ưu tiên):** (1) **OIDC an toàn, đúng chuẩn**; (2) bảo mật token/khóa ký; (3) stateless scale ngang; (4) không sập khi eKYC/SDS chậm.

## 2. Architecture Constraints

Go; OAuth2/OIDC; **tự viết** (thư viện token: `ory/fosite` hoặc tương đương); DDD/Clean Architecture; PostgreSQL + sqlc + pgxpool; Redis (Sentinel) cho state; gRPC tới SDS; Kafka cho event/audit; OTel/SigNoz.

## 3. Context and Scope

**Giao diện ngoài (REST/HTTP) — một issuer:**
- Discovery: `GET /.well-known/openid-configuration`
- JWKS: `GET /.well-known/jwks.json`
- Authorization: `GET /authorize` (code + PKCE)
- Token: `POST /token`
- UserInfo: `GET /userinfo`
- Login/consent UI; Admin API (quản lý client/RP, user, audit)

**Giao diện trong:**
- gRPC → SDS: `StoreSensitive`, `FetchByKycId`, `Verify` (partner-key + IP whitelist).
- Kafka producer: `identity.audit.*`, `identity.ekyc.*`.

## 4. Solution Strategy

- **OIDC chuẩn một issuer**, làm đúng và chắc (đây là nơi 90% lỗ hổng IdP nằm).
- **Layering DDD** (domain → application/CQRS → infrastructure → interfaces), wiring DI trong `cmd`.
- Dùng thư viện cho luồng/token; sở hữu lớp nghiệp vụ + UI.
- **Stateless:** mọi state (auth code, PKCE, session, refresh token) ra Redis.
- **eKYC cô lập** (gọi SDS/provider qua gRPC + circuit breaker) để không sập hot path.

## 5. Building Block View

**Module (level 2):**
- `auth` — OIDC/OAuth flows, login/consent, passkey/MFA, token & khóa ký.
- `user` — hồ sơ user (một pool), credential, passkey.
- `IAL` — mức định danh, liên kết kết quả eKYC (gọi SDS).
- `admin` — đăng ký & quản lý **client/RP**, user, xem audit.

**Bố cục thư mục (Clean Architecture mỗi module):**
```
/cmd/server/main.go
/internal/
  /auth/  /user/  /ial/  /admin/
     domain/        # entities, value objects, aggregates, domain events, repo interfaces
     application/   # use cases (commands/queries CQRS), DTO, ports
     infrastructure/# repo impl (sqlc), redis, kafka, grpc client→SDS
     interfaces/    # HTTP handlers (chi), OIDC endpoints, middlewares
  /platform/        # config, db(pgxpool), redis, observability, ratelimit, crypto/keys
/migrations/
/web/               # template login/consent
```

## 6. Runtime View

**6.1 Đăng nhập + cấp token:**
1. RP redirect `→ /authorize?client_id&redirect_uri&PKCE&state&nonce`.
2. `auth` validate client + redirect_uri (tuyệt đối).
3. Login (passkey/mật khẩu + MFA) → consent.
4. Phát authorization code (lưu Redis + PKCE).
5. RP `POST /token` (code + code_verifier) → cấp **ID/access token JWT** (`iss` = issuer chung, `aud` = client_id, claim `ial`, `sub`).

**6.2 Refresh:** rotation — cấp token mới + xoay refresh; **reuse-detection** → thu hồi family. Denylist khẩn cấp ở Redis (kiểm khi refresh).

**6.3 eKYC → nâng IAL:** user upload → `IAL`/`auth` gọi SDS (lưu mã hóa) + adapter provider → khớp → IAL1→IAL2; token sau phản ánh `ial=2`.

**6.4 Đăng ký RP/client:** admin tạo client → `client_id`/`secret`, `redirect_uris`, `scopes`. (Không có khái niệm tenant.)

## 7. Deployment View

Stateless → N replica sau Envoy; Postgres (primary + replica); Redis Sentinel; Kafka. Khóa ký private **bọc mã hóa** (Vault/MASTER_KEY). CI/CD staged. OTel/SigNoz.

## 8. Crosscutting Concepts — **OIDC AN TOÀN (trọng tâm)**

### 8.1 Bảo mật luồng OIDC
- **Authorization code + PKCE** bắt buộc; **validate `redirect_uri` tuyệt đối** theo client đã đăng ký (chống open redirect).
- `state` (chống CSRF) + `nonce` (chống replay ID token).
- Một **issuer** duy nhất; token `iss` cố định; `aud` = client_id; RP validate `iss`/`aud`/chữ ký.

### 8.2 Khóa ký + JWKS + xoay khóa
- **Một key set** (ES256 khuyến nghị). `kid = {version}`. Private key **bọc mã hóa** (envelope qua MASTER_KEY/Vault); public lộ qua JWKS.
- **Xoay khóa có overlap:** sinh key mới (signing key), giữ public key cũ trong JWKS đến khi mọi token ký bằng nó hết hạn (≥ TTL access tối đa) rồi mới retire.

### 8.3 Đăng ký & scope client/RP
- `oauth_clients(client_id, secret_hash, redirect_uris[], scopes[], grant_types[], status)`. Validate redirect_uri + scope theo client. Confidential vs public client (public bắt buộc PKCE).

### 8.4 Session & SSO
- **Một login session** (cookie trên domain IdP); **SSO xuyên mọi RP** trong pool. Auth code/PKCE/session lưu Redis.

### 8.5 Token strategy
- Access token **JWT** ES256; TTL cân bằng 15–30′. Refresh **rotation + reuse-detection** (thu hồi family). Denylist khẩn cấp ở Redis (kiểm khi refresh). Access token validate offline qua JWKS (IdP rời hot path validate).

### 8.6 eKYC / IAL & PII
- IAL1 (email/SĐT) → IAL2 (đã eKYC). eKYC gọi provider qua adapter (timeout + circuit breaker) và SDS để lưu mã hóa. PII **không bao giờ** ở identity-core dạng plaintext; chỉ giữ `kyc_id` + `ial`.

### 8.7 RBAC
- Vai trò: user, operator, viewer, admin. Quyền decrypt PII chỉ admin/role hợp lệ (thực thi ở SDS qua RBAC + `kyc_id`).

### 8.8 Mô hình dữ liệu (Postgres) — **không có `tenant_id`**
- `users(id, email, phone, password_hash, status, ial, created_at)` — unique `email`
- `passkeys(id, user_id, credential_id, public_key, sign_count)`
- `oauth_clients(id, client_id, secret_hash, redirect_uris[], scopes[], grant_types[], status)`
- `signing_keys(id, kid, alg, public_jwk, private_key_cipher, version, status, rotate_at)` — CURRENT/ACTIVE/RETIRED
- `refresh_tokens(id, user_id, client_id, family_id, hash, status, expires_at)` (hoặc store fosite trong Redis)
- `identity_assurance(user_id, ial, kyc_id, verified_at)`
- `audit_log(id, actor_id, action, target_id, ts, metadata jsonb)` — append-only, partition theo thời gian, GIN + full-text + pgvector

### 8.9 Persistence & error handling
- sqlc + pgxpool. Lỗi nghiệp vụ (4xx) tách lỗi hệ thống (5xx + cảnh báo). Gọi SDS bọc timeout + circuit breaker.

## 9. Architecture Decisions (ADR riêng)

- **ADR-IC-001 — OIDC một issuer, đơn vị tích hợp là RP/client** (Mô hình B). Bỏ multi-tenant khỏi lõi.
- **ADR-IC-002 — Khóa ký một bộ + JWKS, xoay có overlap** (§8.2).
- **ADR-IC-003 — User một pool** (`email` unique toàn cục).
- **ADR-IC-004 — sqlc + pgxpool.**
- **ADR-IC-005 — PII tách hẳn sang SDS**; identity-core chỉ giữ `kyc_id`+`ial`.

## 10. Quality Requirements (scenario)

- *Bảo mật OIDC:* redirect_uri lạ → từ chối; PKCE thiếu với public client → từ chối; ID token thiếu nonce hợp lệ → từ chối.
- *Bảo mật khóa:* DB lộ → private signing key vẫn cipher (cần Vault/MASTER_KEY).
- *Mở rộng:* tăng replica → tăng login/validate, không sửa kiến trúc (stateless).
- *Sẵn sàng:* SDS/provider timeout → eKYC suy giảm, đăng nhập/cấp token vẫn chạy.

## 11. Risks and Technical Debt

- 🔴 **Đúng-đắn bảo mật OIDC** (PKCE, redirect_uri, validate token, xoay khóa, refresh reuse-detection) — nơi lỗ hổng IdP hay nằm; cần integration test + dựa thư viện đã kiểm chứng cho lớp token.
- Quản lý vòng đời khóa ký (sinh/bọc/xoay/retire) — test kỹ.
- Phụ thuộc SDS/provider cho IAL (đã cô lập qua gRPC + circuit breaker).
- *Nợ tương lai có kiểm soát:* nếu sau này cần multi-tenant (bán IdP cho tổ chức ngoài / theo O2O) → phải nâng cấp issuer/khóa/pool (không nhỏ). Hiện ngoài phạm vi.

## 12. Glossary

Xem Glossary bản đồ cha. Bổ sung: RP/client = ứng dụng tích hợp SSO (đơn vị tích hợp, thay cho "tenant"); `kid` = key id; reuse-detection = phát hiện tái dùng refresh token.

---

**Phạm vi MVP (build mỏng):** OIDC code+PKCE một issuer, login + passkey/MFA, cấp/refresh token (rotation+reuse-detection), IAL1/IAL2 (gọi SDS), đăng ký & quản trị client/user cơ bản, audit. **Hoãn:** sharding thật, đa-DC, autoscale, social login, chữ ký số, **multi-tenant**.
