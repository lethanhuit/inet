# Bản đồ kiến trúc — Nền tảng Định danh trên Không gian mạng (arc42)

**Ngày:** 2026-06-06
**Loại tài liệu:** Architecture Overview / Map (theo template arc42). Đây là **bản đồ**, không phải bản build chi tiết.
**Tài liệu con:** Spec #1 `identity-core` (`2026-06-06-identity-core-design.md`) · Spec #2 `sensitive-data-service` (sẽ chuyển thể từ PDF của team).

> Phạm vi: mô tả kiến trúc tổng thể của nền tảng và cách phân rã. Chi tiết build nằm ở từng spec con; mỗi spec con đi qua vòng riêng spec → plan → implement.

---

## 1. Introduction and Goals

Nền tảng định danh số gồm hai trụ cột: **eKYC** (xác minh người thật) và **IdP/SSO** (OAuth 2.0 / OpenID Connect), theo mô hình **multi-tenant** và **tự chủ** (tự viết IdP, không phụ thuộc Keycloak). Là lát cắt auth + tenant + user + kyc + sensitive-data, tái sử dụng house architecture của nền tảng O2O.

**Quality goals (ưu tiên cao nhất → thấp):**
1. **Bảo mật & quyền riêng tư PII** — PII/KYC luôn mã hóa, cô lập theo tenant, không lộ plaintext kể cả khi DB bị tấn công.
2. **Cô lập multi-tenant** — dữ liệu & khóa giữa các tenant cách ly tuyệt đối, kể cả khi lộ một tenant key.
3. **Khả năng mở rộng** — stateless, scale ngang; sẵn sàng cho quy mô lớn dù MVP tải vừa.
4. **Tính sẵn sàng & chịu lỗi** — provider eKYC chậm/lỗi không sập hot path auth.
5. **Tuân thủ** — Nghị định 13/2023/NĐ-CP; sẵn sàng GDPR/ISO 27001/PCI DSS theo house.

**Stakeholders:** end user, tenant admin, relying party (app dùng SSO), internal services (O2O), đội vận hành/bảo mật, cơ quan tuân thủ.

## 2. Architecture Constraints

- Backend **Go**; chuẩn **OAuth 2.0 / OpenID Connect**.
- **Tự viết IdP** (dùng thư viện đã kiểm chứng cho lớp token/crypto, vd `ory/fosite`) — **không Keycloak**.
- Bám **house style**: DDD/Clean Architecture, Kafka, gRPC + Envoy, K8s, PostgreSQL, Redis (Sentinel), object storage + CDN (Cloudflare/R2), observability OpenTelemetry/SigNoz, CI/CD staged.
- eKYC qua **adapter nhà cung cấp** (FPT.AI tham chiếu đầu tiên), không tự train model.
- Tuân thủ Nghị định 13/2023/NĐ-CP.

## 3. Context and Scope

**Business context (actor & hệ ngoài):**
- *End user* → đăng nhập, eKYC. *Tenant admin* → quản lý tenant, decrypt PII (có quyền). *Relying party* → tích hợp SSO. *Internal service* → fetch dữ liệu nhạy cảm qua `kyc_id`.
- *Hệ ngoài:* nhà cung cấp eKYC (FPT.AI…), object storage/CDN, KMS/Vault (master key).

**Technical context (giao diện chính):**
- **OIDC endpoints** (HTTP/REST, per-tenant): `/t/{tenant}/authorize`, `/t/{tenant}/token`, `/t/{tenant}/.well-known/openid-configuration`, JWKS, login/consent UI.
- **gRPC nội bộ:** `identity-core ↔ sensitive-data-service`; partner-key + IP whitelist.
- **Kafka:** audit events, encrypted event payload, eKYC async, retry/DLQ.
- **eKYC provider API** (qua adapter).

## 4. Solution Strategy

- **Nền gọn + trụ cột nhà:** không bung full microservices; topology nhỏ gọn nhưng dùng DDD, Kafka, sharding (nơi cần), DR/CI-CD, CDN, Redis.
- **Tự viết multi-tenant OIDC** — đây là rủi ro mới lớn nhất (xem §11), chi tiết ở Spec identity-core.
- **SDS là lõi bảo mật** — service cô lập, mô hình khóa phân cấp (xem §8).
- **Postgres-first** cho toàn bộ MVP (kể cả audit); Mongo để roadmap.
- **Scale-ready, defer cái đắt:** stateless + JWT/JWKS + connection pool + rate limit + object storage làm ngay; sharding thật/đa-DC/K8s autoscale/Mongo hoãn tới khi tải cần.

## 5. Building Block View

**Level 1 — topology:**
```
                      ┌────────── Envoy / API Gateway ──────────┐
                      │                                         │
   OIDC/REST  ┌───────▼────────┐   gRPC (partner-key)  ┌────────▼─────────┐
  ───────────▶│  identity-core │──────────────────────▶│ sensitive-data-  │
   (login,    │ (modular,DDD)  │                        │  service (SDS)   │
    token)    │ auth·tenant·   │                        │ tenant key model │
              │ user·IAL·admin │                        │ (cô lập, own DB) │
              └───┬────────┬───┘                        └────────┬─────────┘
                  │        │ Kafka (audit, events, eKYC async)   │
        ┌─────────▼──┐  ┌──▼───────────────┐            ┌────────▼────────┐
        │ PostgreSQL │  │ Redis (Sentinel) │            │ PostgreSQL (SDS │
        │ + audit    │  │ session/token/   │            │ riêng) + object │
        │ (partition)│  │ rate-limit/cache │            │ storage (ảnh)   │
        └────────────┘  └──────────────────┘            └─────────────────┘
   Workers: sensitive-data-worker (encrypt/retry/DLQ) · audit-worker (Kafka→audit)
```

**Level 2 — `identity-core` (modular monolith, layering DDD):** module `auth` (OIDC tự viết), `tenant`, `user`, `IAL`, `admin`. Layering domain → application (CQRS) → infrastructure → interfaces. Chi tiết: Spec #1.

**`sensitive-data-service` (SDS):** building block cô lập, mô hình khóa `MASTER_KEY → PLAIN_TENANT_KEY → HKDF derived keys`. Chi tiết: Spec #2 (chuyển thể từ PDF).

## 6. Runtime View (kịch bản chính — tóm tắt)

1. **Đăng nhập multi-tenant + cấp token:** resolve tenant (subdomain) → login (+MFA/passkey) → consent → authorization code → đổi token (ID/access JWT ký bằng khóa của tenant, claim `ial`).
2. **eKYC → nâng IAL:** user upload giấy tờ/selfie → identity-core gọi SDS (lưu mã hóa) + adapter provider → kết quả → nâng IAL1→IAL2.
3. **Onboard tenant:** tạo tenant → Tenant Service sinh `PLAIN_TENANT_KEY` (mã hóa bằng MASTER_KEY, lưu `tenant_crypto_keys`) → khởi tạo khóa ký OIDC của tenant.
4. **Xoay khóa tenant:** policy/force → sinh key version mới (CURRENT), key cũ → ACTIVE (giải mã dữ liệu cũ), background re-encrypt theo batch.

## 7. Deployment View

- Đóng gói **Docker → K8s**; **Envoy** gateway (gRPC nội bộ + REST ngoài).
- **PostgreSQL** primary + read replica; shard theo `tenant_id` khi cần. **Redis Sentinel**. **Kafka**. **Object storage** (R2/S3) + **CDN**.
- **DR:** backup + PITR; master-key backup + job re-encrypt; sẵn sàng đa DC/GEO (roadmap).
- **CI/CD staged:** dev → qc → staging → prelive → live group → live all, kèm rollback (theo house).
- **Observability:** OpenTelemetry → SigNoz (trace/log/APM), metrics Prometheus.

## 8. Crosscutting Concepts

- **Multi-tenancy:** tenant resolution (subdomain→tenant), cô lập bằng `tenant_id` + **Row-Level Security** (Postgres); sharding theo `tenant_id` cho `sensitive_data`/`audit_log` khi tải cần. (Chi tiết OIDC đa tenant ở Spec #1.)
- **Security & key model (SDS):** `MASTER_KEY` (Vault) → `PLAIN_TENANT_KEY` (random AES-256, không lưu plaintext) → derived `DATA_KEY`/`HASH_KEY`/`EVENT_MESSAGE_KEY` qua **HKDF-SHA256**; mã hóa **AES-256-GCM** (AEAD); searchable bằng hash suffix; RBAC chỉ fetch theo `kyc_id`. (Chi tiết: Spec #2.)
- **OIDC & token:** JWT access token ký bất đối xứng, **JWKS + khóa ký theo tenant**, xoay khóa; refresh rotation + reuse-detection; TTL cân bằng 15–30′. (Chi tiết: Spec #1.)
- **Persistence:** **Postgres-first** — identity + `tenant_crypto_keys` + `sensitive_data` + **audit_log** (append-only, partition theo thời gian, JSONB+GIN, full-text, pgvector). Mongo → roadmap. Truy cập qua **sqlc** + pgxpool.
- **Resilience:** eKYC đồng bộ nhưng **bao vây** (semaphore + timeout + circuit breaker) để không sập hot path; Kafka retry/DLQ cho xử lý nền.
- **Audit & non-repudiation:** mọi sự kiện định danh ghi log bất biến; audit chỉ chứa hash/mark, không ciphertext/plaintext.

## 9. Architecture Decisions (ADR — tóm tắt)

- **ADR-001 — Tự viết IdP, không Keycloak.** Sở hữu lớp định danh; dùng thư viện cho token/crypto. Đánh đổi: phải tự làm multi-tenant OIDC (xem §11).
- **ADR-002 — SDS là service cô lập lõi.** Giá trị bảo mật đến từ cô lập (own DB, private network, partner-key).
- **ADR-003 — Nền gọn (core modular + SDS cô lập + workers), không full microservices.** Cân bằng tốc độ MVP và đường tiến hóa.
- **ADR-004 — Postgres-first kể cả audit; Mongo hoãn.** *Deviation có chủ đích* so với house (house dùng Mongo cho audit): một datastore = ít bề mặt bảo mật/vận hành hơn cho MVP; Postgres phủ full-text + pgvector. Rút Mongo ra khi audit cần scale ngang.
- **ADR-005 — sqlc cho truy cập DB.** SQL tường minh, type-safe, hợp truy vấn nhạy cảm + RLS. (Bun là tùy chọn nhà.)
- **ADR-006 — JWT access token + JWKS theo tenant.** Giảm tải validate; cô lập tenant ở tầng khóa ký.

## 10. Quality Requirements (cây chất lượng — scenario tiêu biểu)

- **Bảo mật:** DB sensitive bị sao chép → không đọc được nếu thiếu master_key + data_key. Lộ một tenant key → chỉ ảnh hưởng tenant đó, version đó.
- **Cô lập tenant:** token cấp cho tenant A không bao giờ validate hợp lệ ở tenant B.
- **Mở rộng:** thêm replica xử lý tăng login/validate mà không sửa kiến trúc.
- **Sẵn sàng:** provider eKYC timeout → chỉ eKYC suy giảm, đăng nhập vẫn chạy.

## 11. Risks and Technical Debt

- **🔴 RỦI RO LỚN NHẤT — multi-tenant OIDC tự viết.** Trong house, multi-tenant định danh do **Keycloak realms** lo; bỏ Keycloak nhưng giữ multi-tenant nghĩa là tự xây phần này: tenant resolution, issuer/JWKS/khóa ký theo tenant, scope client theo tenant, chống nhầm lẫn token chéo tenant. → Là **tâm điểm Spec identity-core**.
- Đúng-đắn quản lý khóa (rotation, re-encrypt) — nhạy cảm, cần test kỹ.
- Hoãn sharding/đa-DC: nợ kỹ thuật có kiểm soát (đã thiết kế `tenant_id` shard key sẵn).
- Phụ thuộc provider eKYC (đã cô lập qua adapter + circuit breaker).

## 12. Glossary

| Thuật ngữ | Nghĩa |
|---|---|
| IdP / OIDC | Nhà cung cấp định danh / OpenID Connect |
| IAL | Identity Assurance Level (IAL1 email/SĐT, IAL2 đã eKYC) |
| SDS | Sensitive Data Service — service mã hóa PII/KYC |
| RP | Relying Party — app dùng SSO |
| JWKS | JSON Web Key Set (khóa công khai để validate token) |
| HKDF | HMAC-based Key Derivation Function (RFC 5869) |
| MASTER_KEY / tenant key / data key | Phân cấp khóa của SDS |
| RLS | Row-Level Security (Postgres) |
| tenant | Khách thuê (đơn vị cô lập dữ liệu) |
