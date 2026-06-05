# Spec #1 — identity-core (arc42)

**Ngày:** 2026-06-06
**Trạng thái:** Draft, chờ review
**Tài liệu cha:** Bản đồ kiến trúc (`2026-06-05-dinh-danh-khong-gian-mang-design.md`)
**Service anh em:** `sensitive-data-service` (SDS) — Spec #2 (chuyển thể từ PDF của team)

> **Tâm điểm của spec này: OIDC đa tenant tự viết** — phần Keycloak realms vốn cho không, nay tự gánh. Đây là nơi rủi ro tập trung, nên §8 được viết sâu nhất.

---

## 1. Introduction and Goals

`identity-core` là service (modular monolith, layering DDD) cung cấp **IdP/SSO đa tenant** theo OAuth 2.0 / OpenID Connect, quản lý hồ sơ user và **mức định danh (IAL)**. Nó gọi SDS để lưu/đọc PII; nó **không** tự lưu PII plaintext.

**Phạm vi (in-scope):** module `auth` (OIDC), `tenant`, `user`, `IAL`, `admin`.
**Ngoài phạm vi:** mã hóa/lưu PII (→ SDS, Spec #2); chữ ký số, SDK, ví credential (→ roadmap).

**Quality goals:** (1) cô lập tenant ở tầng token; (2) bảo mật token/khóa ký; (3) stateless scale ngang; (4) không sập khi eKYC/SDS chậm.

## 2. Architecture Constraints

Go; OAuth2/OIDC; tự viết (thư viện token: `ory/fosite` hoặc tương đương); DDD/Clean Architecture; PostgreSQL + sqlc + pgxpool; Redis (Sentinel) cho state; gRPC tới SDS; Kafka cho event/audit; observability OTel/SigNoz.

## 3. Context and Scope

**Giao diện ngoài (REST/HTTP):**
- Per-tenant discovery: `GET /t/{tenant}/.well-known/openid-configuration`
- Per-tenant JWKS: `GET /t/{tenant}/.well-known/jwks.json`
- Authorization: `GET /t/{tenant}/authorize` (code + PKCE)
- Token: `POST /t/{tenant}/token`
- UserInfo: `GET /t/{tenant}/userinfo`
- Login/consent UI (server-rendered, theo subdomain tenant)
- Admin API (quản lý tenant, client, user, xem audit)

**Giao diện trong:**
- gRPC → SDS: `StoreSensitive`, `FetchByKycId`, `Verify` (partner-key + IP whitelist).
- Kafka producer: `identity.audit.*`, `identity.ekyc.*`.

## 4. Solution Strategy

- **Layering DDD** (domain → application/CQRS → infrastructure → interfaces), wiring DI trong `cmd`.
- **OIDC engine** dùng thư viện cho luồng/token; ta sở hữu lớp nghiệp vụ, UI, multi-tenant.
- **Multi-tenant = issuer-per-tenant** (xem §8) — cô lập mạnh nhất, thư viện OIDC chuẩn tự enforce qua `iss`.
- **Stateless:** mọi state (auth code, PKCE, session, refresh token) ra Redis.

## 5. Building Block View

**Module (level 2):**
- `auth` — OIDC/OAuth flows, login/consent, passkey/MFA, token & khóa ký theo tenant.
- `tenant` — vòng đời tenant, resolution, bootstrap khóa ký + (gọi SDS/Tenant để tạo tenant key).
- `user` — hồ sơ user (scope theo tenant), credential, passkey.
- `IAL` — mức định danh, liên kết kết quả eKYC.
- `admin` — quản lý client/RP, user, xem audit.

**Bố cục thư mục (theo house, mỗi module theo Clean Architecture):**
```
/cmd/server/main.go              # wiring DI, bootstrap
/internal/
  /auth/  /tenant/  /user/  /ial/  /admin/
     domain/        # entities, value objects, aggregates, domain events, repo interfaces
     application/   # use cases (commands/queries CQRS), DTO, ports
     infrastructure/# repo impl (sqlc), redis, kafka, grpc client→SDS
     interfaces/    # HTTP handlers (chi), OIDC endpoints, middlewares
  /platform/        # config, db(pgxpool), redis, observability, ratelimit, crypto/keys, tenantctx
/migrations/        # sqlc + goose
/web/               # template login/consent
```

## 6. Runtime View

**6.1 Đăng nhập + cấp token (đa tenant):**
1. RP redirect `→ /t/{tenant}/authorize?client_id&redirect_uri&PKCE&state&nonce`.
2. `tenant` resolve & validate tenant đang active; `auth` validate client thuộc tenant + redirect_uri.
3. Hiện login (subdomain tenant) → xác thực (passkey/mật khẩu + MFA) → consent.
4. Phát authorization code (lưu Redis, gắn tenant + PKCE).
5. RP `POST /t/{tenant}/token` (code + code_verifier) → cấp **ID/access token JWT ký bằng khóa ký của tenant** (`iss=/t/{tenant}`, `aud=client_id`, claim `ial`, `tid`).

**6.2 Refresh:** refresh token **rotation** — mỗi lần refresh cấp token mới + xoay refresh; phát hiện tái sử dụng (reuse-detection) → thu hồi cả family. Denylist khẩn cấp ở Redis (chỉ kiểm khi refresh).

**6.3 eKYC → nâng IAL:** user upload → `IAL`/`auth` gọi SDS (lưu mã hóa) + adapter provider → kết quả khớp → IAL1→IAL2; token sau phản ánh `ial=2`.

**6.4 Bootstrap tenant:** tạo tenant → sinh **khóa ký OIDC của tenant** (ES256, private key bọc mã hóa) + (gọi tạo `PLAIN_TENANT_KEY` ở SDS) → tenant sẵn sàng phát token.

## 7. Deployment View

Stateless → N replica sau Envoy; Postgres (primary + replica, RLS theo tenant); Redis Sentinel; Kafka. Khóa ký private bọc mã hóa (Vault/MASTER_KEY). CI/CD staged. OTel/SigNoz.

## 8. Crosscutting Concepts — **MULTI-TENANT OIDC (trọng tâm)**

### 8.1 Tenant resolution
- Chuẩn: **subdomain** `tenant-code.idp.example` hoặc path prefix `/t/{tenant}`. Middleware `tenantctx` resolve `tenant_code → tenant_id`, nạp vào context cho mọi tầng dưới. Tenant không active → 404/403 sớm.

### 8.2 Chiến lược issuer — **issuer-per-tenant** (quyết định)

| Phương án | Cô lập | Quản lý khóa | Rủi ro |
|---|---|---|---|
| **Issuer-per-tenant** (`iss=/t/{tenant}`) ✅ | **Mạnh** — thư viện OIDC validate `iss` ⇒ token tenant A tự động bị RP tenant B từ chối | Nhiều khóa hơn (theo tenant) | Provisioning phải tạo khóa/discovery per tenant |
| Shared issuer + claim `tid` | Yếu hơn — phụ thuộc RP nhớ kiểm `tid` | Đơn giản (1 key set) | **Dễ nhầm token chéo tenant** nếu RP quên kiểm |

**Chọn issuer-per-tenant** — mô phỏng đúng "realm" mà team đã quen, và biến cô lập tenant thành thuộc tính được *chuẩn OIDC enforce* thay vì dựa vào kỷ luật RP. Đánh đổi (nhiều khóa) xử lý bằng tự động hóa ở §8.3.

### 8.3 Khóa ký + JWKS + xoay khóa **theo tenant**
- Mỗi tenant có **key set riêng** (ES256). `kid = {tenant}-{version}`.
- **Private key bọc mã hóa** (envelope qua MASTER_KEY/Vault); public key lộ qua JWKS của tenant.
- **Discovery/JWKS per tenant**, cacheable (header cache + Redis).
- **Xoay khóa:** sinh key mới (thành signing key), **giữ public key cũ trong JWKS** đến khi mọi token ký bằng nó hết hạn (≥ TTL access tối đa) rồi mới retire. Lịch xoay theo tenant.

### 8.4 Scope client/RP theo tenant
- `oauth_clients.tenant_id` — mỗi client thuộc đúng một tenant; `client_id` unique trong tenant.
- `redirect_uri` validate tuyệt đối theo client của đúng tenant. Request ở `/t/{tenant}/authorize` chỉ chấp nhận client của tenant đó.

### 8.5 Chống nhầm lẫn token chéo tenant
- Bộ ba `iss` (per tenant) + `aud` (client của tenant) + `kid` (trỏ về khóa tenant) ⇒ token không thể replay sang tenant khác. `tid` claim là lớp kiểm tra phụ.

### 8.6 User & session
- **User scope theo tenant:** `users(tenant_id, email)` unique theo tenant. Một email có thể tồn tại độc lập ở nhiều tenant. (Cross-tenant SSO ngoài phạm vi.)
- **Session per tenant:** cookie scope theo subdomain tenant; SSO giữa các RP **trong cùng tenant**. Auth code/PKCE/session lưu Redis, khóa gắn tenant.

### 8.7 Token strategy (kế thừa từ phần scalability)
- Access token **JWT** ES256/RS256; TTL cân bằng 15–30′. Refresh **rotation + reuse-detection** (thu hồi family). Denylist khẩn cấp ở Redis (kiểm khi refresh).

### 8.8 RBAC
- Vai trò: end user, tenant admin (quản lý tenant, quyền cao), operator, viewer. Quyền decrypt PII chỉ tenant admin (thực thi ở SDS qua RBAC + `kyc_id`).

### 8.9 Mô hình dữ liệu (Postgres, RLS theo `tenant_id`)
- `tenants(id, code, status, created_at)`
- `users(id, tenant_id, email, phone, password_hash, status, ial, created_at)` — unique `(tenant_id, email)`
- `passkeys(id, user_id, credential_id, public_key, sign_count)`
- `oauth_clients(id, tenant_id, client_id, secret_hash, redirect_uris[], scopes[], status)`
- `tenant_signing_keys(id, tenant_id, kid, alg, public_jwk, private_key_cipher, version, status, rotate_at)` — status CURRENT/ACTIVE/RETIRED
- `refresh_tokens(id, tenant_id, user_id, client_id, family_id, hash, status, expires_at)` (hoặc store của fosite trong Redis)
- `identity_assurance(user_id, tenant_id, ial, kyc_id, verified_at)`
- `audit_log(id, tenant_id, actor_id, action, target_id, ts, metadata jsonb)` — append-only, partition theo thời gian, GIN + full-text + pgvector

### 8.10 Persistence & error handling
- sqlc + pgxpool; **RLS** ép `tenant_id` ở tầng DB. Lỗi nghiệp vụ (4xx) tách lỗi hệ thống (5xx + cảnh báo). Gọi SDS bọc timeout + circuit breaker → SDS chậm chỉ ảnh hưởng eKYC, không sập login.

## 9. Architecture Decisions (ADR riêng của identity-core)

- **ADR-IC-001 — Issuer-per-tenant** (xem §8.2). Cô lập do chuẩn OIDC enforce.
- **ADR-IC-002 — Khóa ký + JWKS theo tenant, xoay có overlap** (§8.3).
- **ADR-IC-003 — User scope theo tenant** (§8.6); cross-tenant SSO ngoài phạm vi.
- **ADR-IC-004 — sqlc + RLS** cho cô lập tenant tầng DB.

## 10. Quality Requirements (scenario)

- *Cô lập:* token `iss=/t/A` đưa cho RP của tenant B → bị từ chối tự động (sai `iss`).
- *Bảo mật khóa:* DB lộ → private signing key vẫn ở dạng cipher (cần MASTER_KEY/Vault).
- *Mở rộng:* tăng replica → tăng login/validate, không sửa kiến trúc (stateless).
- *Sẵn sàng:* SDS timeout → eKYC suy giảm, đăng nhập/cấp token vẫn chạy.

## 11. Risks and Technical Debt

- 🔴 **Đúng-đắn multi-tenant OIDC** — validate `iss/aud/kid` đa tenant, xoay khóa per tenant không gãy phiên: cần integration test bao phủ kịch bản chéo tenant.
- Quản lý vòng đời khóa ký per tenant (sinh/bọc/xoay/retire) — tự động hóa + test.
- Phụ thuộc SDS cho IAL/PII (đã cô lập qua gRPC + circuit breaker).

## 12. Glossary

Xem Glossary của bản đồ kiến trúc cha. Bổ sung: `kid` = key id; `tid` = tenant id claim; reuse-detection = phát hiện tái dùng refresh token.

---

**Phạm vi MVP của identity-core (build mỏng):** OIDC code+PKCE đa tenant (issuer-per-tenant), login + passkey/MFA, cấp/refresh token (rotation+reuse-detection), IAL1/IAL2 (gọi SDS), quản trị client/user cơ bản, audit. **Hoãn:** sharding thật, đa-DC, autoscale, social login, chữ ký số.
