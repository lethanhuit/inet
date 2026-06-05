# Bản đồ kiến trúc — Nền tảng Định danh trên Không gian mạng (arc42)

**Ngày:** 2026-06-06
**Loại tài liệu:** Architecture Overview / Map (template arc42). Đây là **bản đồ**, không phải bản build chi tiết.
**Mô hình:** **Một pool người dùng, nhiều relying party (RP/client)** — kiểu VNeID/UAE PASS/SSO nội bộ. KHÔNG multi-tenant.
**Tài liệu con:** Spec #1 `identity-core` (`2026-06-06-identity-core-design.md`) · Spec #2 `sensitive-data-service` (chuyển thể từ PDF).

> Phạm vi: kiến trúc tổng thể + cách phân rã. Chi tiết build ở từng spec con; mỗi spec con đi qua vòng riêng spec → plan → implement.

---

## 1. Introduction and Goals

Nền tảng định danh số gồm hai trụ cột: **eKYC** (xác minh người thật) và **IdP/SSO** (OAuth 2.0 / OpenID Connect), theo mô hình **một pool người dùng** và **tự chủ** (tự viết IdP, không Keycloak). Các ứng dụng tích hợp dưới dạng **relying party (client)**. Tái sử dụng house architecture O2O ở mức convention.

**Quality goals (ưu tiên cao → thấp):**
1. **Bảo mật & quyền riêng tư PII** — PII/KYC luôn mã hóa, không lộ plaintext kể cả khi DB bị tấn công.
2. **OIDC an toàn, đúng chuẩn** — nơi lỗ hổng IdP hay nằm.
3. **Khả năng mở rộng** — stateless, scale ngang; sẵn sàng quy mô lớn dù MVP tải vừa.
4. **Sẵn sàng & chịu lỗi** — provider eKYC/SDS chậm không sập hot path auth.
5. **Tuân thủ** — Nghị định 13/2023/NĐ-CP; sẵn sàng GDPR/ISO 27001 theo house.

**Stakeholders:** end user, operator/admin nền tảng, relying party (app dùng SSO), internal services, đội vận hành/bảo mật, cơ quan tuân thủ.

## 2. Architecture Constraints

- Backend **Go**; chuẩn **OAuth 2.0 / OpenID Connect**.
- **Tự viết IdP** (thư viện cho lớp token/crypto, vd `ory/fosite`) — **không Keycloak**.
- Bám **house style**: DDD/Clean Architecture, Kafka, gRPC + Envoy, K8s, PostgreSQL, Redis (Sentinel), object storage + CDN, OTel/SigNoz, CI/CD staged.
- eKYC qua **adapter nhà cung cấp** (FPT.AI tham chiếu đầu tiên).
- Tuân thủ Nghị định 13/2023/NĐ-CP.

## 3. Context and Scope

**Business context:**
- *End user* → đăng nhập, eKYC. *Operator/admin* → quản lý client/RP, user, decrypt PII (có quyền). *Relying party* → tích hợp SSO. *Internal service* → fetch dữ liệu nhạy cảm qua `kyc_id`.
- *Hệ ngoài:* nhà cung cấp eKYC (FPT.AI…), object storage/CDN, KMS/Vault (master key).

**Technical context (giao diện chính) — một issuer:**
- **OIDC endpoints** (REST): `/authorize`, `/token`, `/userinfo`, `/.well-known/openid-configuration`, `/.well-known/jwks.json`, login/consent UI.
- **gRPC nội bộ:** `identity-core ↔ sensitive-data-service` (partner-key + IP whitelist).
- **Kafka:** audit, encrypted event payload, eKYC async, retry/DLQ.
- **eKYC provider API** (qua adapter).

## 4. Solution Strategy

- **OIDC chuẩn một issuer**, làm đúng & chắc; đơn vị tích hợp là **RP/client**.
- **Nền gọn + trụ cột nhà:** topology nhỏ gọn nhưng dùng DDD, Kafka, DR/CI-CD, CDN, Redis; sharding để dành.
- **SDS là lõi bảo mật** — service cô lập, mô hình khóa có version (xem §8).
- **Postgres-first** cho toàn bộ MVP (kể cả audit); Mongo để roadmap.
- **Scale-ready, defer cái đắt:** stateless + JWT/JWKS + connection pool + rate limit + object storage làm ngay; sharding thật/đa-DC/K8s autoscale/Mongo hoãn.

## 5. Building Block View

**Level 1 — topology:**
```
                      ┌────────── Envoy / API Gateway ──────────┐
   OIDC/REST  ┌───────▼────────┐   gRPC (partner-key)  ┌────────▼─────────┐
  ───────────▶│  identity-core │──────────────────────▶│ sensitive-data-  │
   (login,    │ (modular,DDD)  │                        │  service (SDS)   │
    token)    │ auth·user·IAL· │                        │ key model (ver), │
              │ admin(client)  │                        │ cô lập, own DB   │
              └───┬────────┬───┘                        └────────┬─────────┘
                  │        │ Kafka (audit, events, eKYC async)   │
        ┌─────────▼──┐  ┌──▼───────────────┐            ┌────────▼────────┐
        │ PostgreSQL │  │ Redis (Sentinel) │            │ PostgreSQL (SDS │
        │ + audit    │  │ session/token/   │            │ riêng) + object │
        │ (partition)│  │ rate-limit/cache │            │ storage (ảnh)   │
        └────────────┘  └──────────────────┘            └─────────────────┘
   Workers: sensitive-data-worker (encrypt/retry/DLQ) · audit-worker (Kafka→audit)
```

**Level 2 — `identity-core`:** module `auth` (OIDC tự viết), `user`, `IAL`, `admin` (quản lý client/RP). Layering DDD. Chi tiết: Spec #1.

**`sensitive-data-service` (SDS):** building block cô lập; mô hình khóa `MASTER_KEY → DATA_KEY (có version)` + derived qua HKDF. Chi tiết: Spec #2.

## 6. Runtime View (kịch bản chính — tóm tắt)

1. **Đăng nhập + cấp token:** `/authorize` (code+PKCE) → login (+MFA/passkey) → consent → đổi token (ID/access JWT, `iss` chung, `aud`=client, claim `ial`).
2. **eKYC → nâng IAL:** upload giấy tờ/selfie → identity-core gọi SDS (lưu mã hóa) + adapter provider → kết quả → IAL1→IAL2.
3. **Đăng ký RP/client:** admin tạo client (`client_id`/secret, redirect_uris, scopes).
4. **Xoay khóa:** OIDC signing key xoay có overlap; SDS data key xoay theo version + background re-encrypt.

## 7. Deployment View

- Đóng gói **Docker → K8s**; **Envoy** gateway (gRPC nội bộ + REST ngoài).
- **PostgreSQL** primary + read replica; shard theo thời gian/khối khi cần. **Redis Sentinel**. **Kafka**. **Object storage** (R2/S3) + **CDN**.
- **DR:** backup + PITR; master-key backup + job re-encrypt; sẵn sàng đa DC/GEO (roadmap).
- **CI/CD staged:** dev → qc → staging → prelive → live group → live all + rollback.
- **Observability:** OpenTelemetry → SigNoz; metrics Prometheus.

## 8. Crosscutting Concepts

- **Một pool & RP model:** một issuer, một pool user (`email` unique), nhiều client/RP (đơn vị tích hợp). SSO xuyên mọi RP.
- **Security & key model (SDS):** `MASTER_KEY` (Vault) → `DATA_KEY` (random AES-256, **có version**, mã hóa bằng MASTER_KEY) → derived `HASH_KEY`/`EVENT_MESSAGE_KEY` qua **HKDF-SHA256**; mã hóa **AES-256-GCM** (AEAD); searchable bằng hash suffix; RBAC chỉ fetch theo `kyc_id`. (Versioning giới hạn blast-radius + sẵn sàng multi-tenant về sau. Chi tiết: Spec #2.)
- **OIDC & token:** JWT access token ký bất đối xứng, **một JWKS**, xoay khóa có overlap; refresh rotation + reuse-detection; TTL 15–30′. (Chi tiết: Spec #1.)
- **Persistence:** **Postgres-first** — identity + key tables + `sensitive_data` + **audit_log** (append-only, partition theo thời gian, JSONB+GIN, full-text, pgvector). Mongo → roadmap. Truy cập **sqlc** + pgxpool.
- **Resilience:** eKYC đồng bộ nhưng **bao vây** (semaphore + timeout + circuit breaker); Kafka retry/DLQ cho xử lý nền.
- **Audit & non-repudiation:** mọi sự kiện định danh ghi log bất biến; audit chỉ chứa hash/mark.

## 9. Architecture Decisions (ADR — tóm tắt)

- **ADR-001 — Tự viết IdP, không Keycloak.** Sở hữu lớp định danh; dùng thư viện cho token/crypto.
- **ADR-002 — SDS là service cô lập lõi.** Giá trị bảo mật đến từ cô lập (own DB, private network, partner-key).
- **ADR-003 — Nền gọn (core modular + SDS cô lập + workers), không full microservices.**
- **ADR-004 — Mô hình B: một pool, RP/client là đơn vị tích hợp.** Bỏ multi-tenant khỏi lõi; nâng cấp sau nếu cần (nợ có kiểm soát).
- **ADR-005 — Postgres-first kể cả audit; Mongo hoãn.** *Deviation có chủ đích* so với house: một datastore = ít bề mặt bảo mật/vận hành cho MVP; Postgres phủ full-text + pgvector.
- **ADR-006 — sqlc cho truy cập DB.** SQL tường minh, type-safe.
- **ADR-007 — SDS key model có version (không theo tenant).** Blast-radius nhỏ + xoay khóa, sẵn sàng multi-tenant về sau.

## 10. Quality Requirements (scenario tiêu biểu)

- **Bảo mật:** DB sensitive bị sao chép → không đọc được nếu thiếu master_key + data_key. Lộ một data_key version → chỉ ảnh hưởng dữ liệu mã bằng version đó.
- **OIDC an toàn:** redirect_uri lạ / thiếu PKCE / thiếu nonce → từ chối.
- **Mở rộng:** thêm replica → tăng login/validate, không sửa kiến trúc.
- **Sẵn sàng:** provider eKYC timeout → chỉ eKYC suy giảm, đăng nhập vẫn chạy.

## 11. Risks and Technical Debt

- 🔴 **Đúng-đắn bảo mật OIDC** (PKCE, redirect_uri, validate token, xoay khóa, refresh reuse-detection) — tâm điểm Spec identity-core; dựa thư viện đã kiểm chứng + integration test.
- Đúng-đắn quản lý khóa (rotation, re-encrypt) — nhạy cảm, test kỹ.
- Hoãn sharding/đa-DC — nợ kỹ thuật có kiểm soát.
- Phụ thuộc provider eKYC (đã cô lập qua adapter + circuit breaker).
- Nếu sau này cần multi-tenant → nâng cấp issuer/khóa/pool (không nhỏ); hiện ngoài phạm vi.

## 12. Glossary

| Thuật ngữ | Nghĩa |
|---|---|
| IdP / OIDC | Nhà cung cấp định danh / OpenID Connect |
| IAL | Identity Assurance Level (IAL1 email/SĐT, IAL2 đã eKYC) |
| SDS | Sensitive Data Service — service mã hóa PII/KYC |
| RP / client | Ứng dụng tích hợp SSO (đơn vị tích hợp; thay cho "tenant") |
| JWKS | JSON Web Key Set (khóa công khai để validate token) |
| HKDF | HMAC-based Key Derivation Function (RFC 5869) |
| MASTER_KEY / data key | Phân cấp khóa SDS (data key có version) |
