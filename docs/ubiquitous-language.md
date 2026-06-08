# Ubiquitous Language — Nền tảng Định danh trên Không gian mạng

**Tác giả:** Thành Lê Phước

**Ngày:** 2026-06-08 · **Loại:** Hợp đồng từ vựng (DDD Ubiquitous Language)

> **Mục đích:** đây KHÔNG phải từ điển bách khoa, mà là **hợp đồng từ vựng**: chốt **một thuật ngữ chuẩn** cho mỗi khái niệm, nêu **đồng nghĩa cần tránh**, và ánh xạ tới **định danh trong code**. Mọi tài liệu, commit, tên hàm/bảng/biến phải dùng đúng từ chuẩn ở đây.

## 0. Quy ước & nguồn chân lý

- **Tài liệu này là nguồn chân lý cho *từ vựng*.** Khi spec/code và tài liệu này lệch tên gọi → sửa cho khớp tài liệu này (hoặc cập nhật tài liệu này nếu domain đổi).
- **Quyết định kiến trúc/công nghệ** thì nguồn chân lý là `docs/adr/` (xem thêm `docs/quyet-dinh-cong-nghe-tradeoff.md`).
- Mỗi mục: **Thuật ngữ chuẩn · Nghĩa trong dự án · Lưu ý / đồng nghĩa cần tránh · Định danh trong code**.
- Tài liệu liên quan: bản đồ kiến trúc `docs/superpowers/specs/2026-06-05-…-design.md`, Spec identity-core `…/2026-06-06-identity-core-design.md`.

---

## 1. Quyết định từ vựng (đọc trước tiên)

Những khái niệm dễ gây hiểu nhầm nhất — đã chốt cách gọi. Đây là phần giá trị nhất của hợp đồng.

| Thuật ngữ chuẩn | Quyết định & vì sao | Cấm dùng / tránh |
|---|---|---|
| **Relying Party (RP) / client** | Đơn vị tích hợp SSO = mỗi game/app/dịch vụ. Là đối tượng đăng ký `client_id` để dùng IdP. | ❌ **"tenant"** — đã **bỏ multi-tenant** (ADR-0001). "tenant" chỉ xuất hiện khi nói về *house O2O* hoặc roadmap bán IdP cho tổ chức ngoài. |
| **Pool người dùng (một pool)** | Toàn hệ chỉ có **một tập người dùng duy nhất**, `email` unique toàn cục, **một issuer**. | ❌ "realm", "tenant user store", "org" theo nghĩa cô lập user. |
| **Chữ ký số** ⚠️ *hai nghĩa* | Phải nói rõ nghĩa nào: **(a) ký token** = ký JWT bằng ES256 (kỹ thuật, MVP); **(b) chữ ký số pháp lý** = ký tài liệu bằng PKI/CA có giá trị pháp lý (roadmap). | ❌ Dùng trống "chữ ký số" mà không nói (a)/(b). Trong code: `TokenSigner` vs `DocumentSignature`. |
| **kyc_id** | **Handle duy nhất** để identity-core tham chiếu PII trong SDS. identity-core **không bao giờ** giữ PII plaintext, chỉ giữ `kyc_id` + `ial`. | ❌ Truyền PII (CCCD, ảnh) qua identity-core; ❌ list/search PII tương đối. |
| **DATA_KEY (có version)** | Khóa dữ liệu của SDS **đánh version**, KHÔNG khóa-theo-tenant (khác house O2O). | ❌ "tenant key" / "khóa theo tenant" trong dự án này (ADR-0004). |
| **IAL "gắn năng lực"** | Mức định danh (IAL1/2/3) là **điều kiện mở khóa tính năng** (kiểu SOP của UAE PASS), không chỉ là nhãn. | ❌ Hiểu IAL như "trạng thái hồ sơ" thụ động. |
| **Issuer (`iss`)** | **Một** issuer cố định cho toàn hệ; mọi token mang `iss` này. | ❌ issuer-per-tenant / issuer-per-client. |
| **Tiết lộ tối thiểu (centralized)** | "Chứng minh tính đúng mà không lộ dữ liệu gốc" trong mô hình ta = **IdP ký claim dẫn xuất**, KHÔNG phải ZKP. Ranh giới riêng tư là **IdP↔RP** (RP không thấy PII; IdP vẫn thấy). | ❌ Hiểu nhầm là ZKP/SSI; ❌ kỳ vọng "giấu khỏi cả IdP" (đó là roadmap). |

---

## 2. Domain — Định danh & Xác thực (Identity & Authentication)

| Thuật ngữ chuẩn | Nghĩa trong dự án | Lưu ý / đồng nghĩa tránh | Code |
|---|---|---|---|
| **IdP** (Identity Provider) | Hệ ta đang xây — phát hành & xác minh định danh, cấp token. | = "nhà cung cấp định danh". | `identity-core` |
| **SSO** (Single Sign-On) | Một lần đăng nhập dùng cho mọi RP trong pool. | | — |
| **OAuth 2.0 / OIDC** | Khung uỷ quyền (OAuth2) + lớp định danh (OpenID Connect) ta tuân theo. | OIDC = OAuth2 + ID token. | — |
| **Relying Party (RP)** | Xem §1. | ❌ tenant. | `oauth_clients` |
| **Authorization Code + PKCE** | Luồng cấp token chuẩn duy nhất; PKCE **bắt buộc** (đặc biệt public client). | ❌ implicit flow, password grant. | `/authorize`, `code_verifier` |
| **Access token** | JWT ES256, tự chứa, validate offline qua JWKS; TTL 15–30′. | ❌ opaque token (đã loại — ADR-0005). | — |
| **ID token** | JWT chứng minh danh tính cho RP (`sub`, `aud`, `nonce`, claim `ial`). | Khác access token (uỷ quyền). | — |
| **Refresh token** | Token đổi lấy access mới; **rotation + reuse-detection** (thu hồi cả family). | ❌ refresh token "vĩnh viễn không xoay". | `refresh_tokens.family_id` |
| **Reuse-detection** | Phát hiện refresh token cũ bị tái dùng → thu hồi toàn family. | | — |
| **JWKS** | Bộ khóa **công khai** để RP tự xác minh chữ ký token. | `/.well-known/jwks.json`. | `signing_keys.public_jwk` |
| **`kid`** | Định danh phiên bản khóa ký trong JWT header & JWKS. | | `signing_keys.kid` |
| **Xoay khóa có overlap** | Sinh khóa mới nhưng giữ public key cũ trong JWKS đến khi token ký bằng nó hết hạn. | ❌ retire khóa ngay khi xoay. | `status: CURRENT/ACTIVE/RETIRED` |
| **`state` / `nonce`** | `state` chống CSRF; `nonce` chống replay ID token. | | — |
| **Scope / Claim** | Scope = phạm vi quyền RP xin; Claim = thuộc tính trong token (`sub`, `ial`…). | | `oauth_clients.scopes[]` |
| **Consent** | Bước user đồng ý cho RP truy cập scope. | | — |
| **Claim dẫn xuất / Predicate** | Vị từ IdP tính sẵn từ PII rồi ký, thay cho dữ liệu gốc: `age_over_18`, `verified`, `resident_province`. | ❌ Đưa dữ liệu gốc (ngày sinh/CCCD) vào token. | claim `age_over_18` |
| **Minimal disclosure** | Nguyên tắc chỉ phát claim **tối thiểu** RP cần; mặc định ít nhất. | NĐ13/2023. | — |
| **Pairwise sub (PPID)** | `subject_type: pairwise` — mỗi RP nhận một `sub` khác cho cùng người → chống RP liên kết. | ❌ public sub dùng chung mọi RP (cho phép tương quan). | `subject_type` |
| **Selective disclosure / SD-JWT** | Credential ký sẵn, bên trình diện **chọn lộ** từng claim (claim khác là salted-hash). | Near-term; khớp stack JWT/OIDC. | — |
| **Discovery** | Endpoint công bố cấu hình OIDC. | `/.well-known/openid-configuration`. | — |
| **UserInfo** | Endpoint trả thuộc tính user theo access token. | `/userinfo`. | — |
| **Single-Logout (SLO)** | Đăng xuất **kết thúc session phía IdP** (RP-Initiated / back-channel), không chỉ xoá session RP. | Bài học từ UAE PASS. | `/logout` |
| **Session** | Phiên login trên domain IdP (cookie); state lưu Redis. | | — |
| **Denylist** | Danh sách thu hồi khẩn cấp (kiểm khi refresh), ở Redis. | Bù cho việc JWT không thu hồi tức thì. | — |
| **MFA / TOTP** | Xác thực đa yếu tố; TOTP = mã 6 số theo thời gian (RFC 6238). | | — |
| **Passkey / FIDO2 / WebAuthn** | Đăng nhập không mật khẩu bằng khóa thiết bị (chuẩn WebAuthn). | "passkey" = tên thân thiện của FIDO2 credential. | `passkeys` |
| **Credential** | Bất kỳ phương tiện xác thực của user: mật khẩu (hash), passkey, TOTP. | | — |
| **argon2id** | Thuật toán băm mật khẩu được chọn. | ❌ MD5/SHA thuần/bcrypt cho mật khẩu mới. | — |

---

## 3. Domain — Định danh điện tử & eKYC (Verification & Assurance)

| Thuật ngữ chuẩn | Nghĩa trong dự án | Lưu ý / đồng nghĩa tránh | Code |
|---|---|---|---|
| **eKYC** | Xác minh "người thật, đúng người" qua giấy tờ + khuôn mặt. | = "định danh điện tử". | module `ekyc` |
| **OCR / Face-match / Liveness** | Đọc giấy tờ / so khớp khuôn mặt / chống ảnh giả. Do **provider** thực hiện. | Ta **không tự train model** (ADR-0009). | — |
| **Verifier (adapter)** | Interface chung cho mọi nguồn xác minh; mỗi provider là một adapter. | Provider là **cấu hình**, không ràng buộc kiến trúc. | `Verifier` interface |
| **VNeID** | Nguồn xác minh **chính thống** (MVP), assurance cao nhất; là một adapter. | Cần fallback khi không khả dụng (ADR-0012). | adapter trong `ekyc` |
| **FPT.AI** | Provider thương mại tham chiếu / **fallback**. | | adapter trong `ekyc` |
| **IAL** (Identity Assurance Level) | Mức tin cậy định danh; **gắn năng lực** (xem §1). | NIST 800-63 dùng IAL; "SOP" là cách UAE PASS gọi. | `identity_assurance.ial`, claim `ial` |
| **IAL1 / IAL2 / IAL3** | IAL1 = email/SĐT; IAL2 = eKYC provider; IAL3 = VNeID (cân nhắc). | Mức cao **mở khóa** tính năng. | — |
| **Capability gating** | Cơ chế: tính năng X yêu cầu IAL ≥ N. | "gắn năng lực". | — |

---

## 4. Domain — Bảo mật dữ liệu nhạy cảm (Sensitive Data / SDS)

| Thuật ngữ chuẩn | Nghĩa trong dự án | Lưu ý / đồng nghĩa tránh | Code |
|---|---|---|---|
| **PII** | Dữ liệu cá nhân nhạy cảm (CCCD, ảnh, sinh trắc…). | NĐ13/2023 gọi "dữ liệu cá nhân". | — |
| **SDS** (Sensitive Data Service) | Service **cô lập** giữ & mã hóa toàn bộ PII; own DB, private network, partner-key. | identity-core **không** lưu PII. | `sensitive-data-service` |
| **kyc_id** | Xem §1 — handle duy nhất vào SDS. | | — |
| **MASTER_KEY** | Khóa gốc trong KMS/Vault, **không bao giờ rời ra**, chỉ bọc DATA_KEY. | | — |
| **DATA_KEY (có version)** | Khóa AES-256 ngẫu nhiên mã hóa dữ liệu, **đánh version**, được MASTER_KEY mã hóa. | ❌ "tenant key" (xem §1). | `version` |
| **Envelope encryption** | Mô hình "khóa bọc khóa": MASTER_KEY bọc DATA_KEY, DATA_KEY mã hóa dữ liệu. | | — |
| **Khóa dẫn xuất (derived key)** | Khóa con cho từng mục đích (`encrypt`/`hash`/`event`) sinh từ DATA_KEY qua HKDF. | Domain separation. | — |
| **Blast-radius** | Phạm vi thiệt hại khi lộ một khóa; versioning giữ nó **nhỏ**. | | — |
| **Searchable hash (blind index)** | Hash-có-khóa của suffix để **so khớp chính xác** mà không lưu plaintext. | Chỉ exact-match, không range/fuzzy. | — |
| **Re-encrypt (background)** | Job nền mã hóa lại dữ liệu sang DATA_KEY version mới khi xoay khóa. | | — |
| **RBAC** | Phân quyền theo vai trò; decrypt PII chỉ role hợp lệ, thực thi ở SDS. | Vai trò: user/operator/viewer/admin. | — |
| **partner-key + IP whitelist** | Cơ chế tin cậy giữa identity-core ↔ SDS (gRPC). | | — |

---

## 5. Domain — Tổ chức code & kiến trúc (DDD / Clean Architecture)

| Thuật ngữ chuẩn | Nghĩa trong dự án | Lưu ý | Code |
|---|---|---|---|
| **identity-core** | Modular monolith chứa lõi IdP/SSO + eKYC + IAL + admin. | Một deployable. | `cmd/server` |
| **Module / Bounded context** | `auth`, `user`, `ekyc`, `ial`, `admin` — mỗi module tự chứa. | Ranh giới phải sạch. | `internal/<module>` |
| **Layer: domain** | Entity, value object, aggregate, domain event, **repo interface**. | Không phụ thuộc hạ tầng. | `domain/` |
| **Layer: application** | Use case dạng **CQRS** (command/query), DTO, port. | | `application/` |
| **Layer: infrastructure** | Hiện thực repo (sqlc), Redis, Kafka, gRPC client→SDS. | | `infrastructure/` |
| **Layer: interfaces** | HTTP handler (chi), OIDC endpoint, middleware. | | `interfaces/` |
| **CQRS** | Tách lệnh (ghi) khỏi truy vấn (đọc). | | — |
| **Repository** | Cổng truy cập dữ liệu định nghĩa ở domain, hiện thực ở infrastructure. | | — |
| **Adapter / Port** | Cổng (interface) + bộ chuyển đổi tới hệ ngoài (eKYC provider, SDS…). | Ports & Adapters. | — |
| **platform (shared)** | Code dùng chung: config, db pool, redis, observability, ratelimit, crypto/keys. | | `internal/platform` |
| **Worker** | Tiến trình nền tiêu thụ Kafka: `sensitive-data-worker`, `audit-worker`. | | — |
| **Transactional outbox** | Ghi event vào bảng outbox cùng transaction nghiệp vụ; relay/CDC đẩy sang Kafka. | Chống mất/trùng event. | — |
| **Audit log** | Nhật ký bất biến mọi sự kiện định danh; chỉ chứa hash/mark, không PII. | append-only, partition. | `audit_log` |
| **Non-repudiation** | Tính chống chối bỏ — audit đảm bảo hành động truy vết được. | | — |

---

## 6. Mã hóa & Chữ ký số (Cryptography)

| Thuật ngữ chuẩn | Nghĩa trong dự án | Lưu ý |
|---|---|---|
| **Đối xứng (symmetric)** | Một khóa chung để mã hóa & giải mã. Dùng cho **dữ liệu khối lượng lớn** (PII). | AES. |
| **Bất đối xứng (asymmetric)** | Cặp khóa public/private. Dùng cho **chữ ký & trao đổi khóa**. | RSA, ECC. |
| **AES-256-GCM** | Mã hóa PII; GCM là **AEAD** (mã hóa + xác thực toàn vẹn một bước). | ⚠️ **nonce không được tái dùng**. |
| **AEAD** | Authenticated Encryption with Associated Data — chống cả nghe lén + giả mạo. | | 
| **Nonce / IV** | Số dùng một lần cho mỗi lần mã hóa GCM. | Tái dùng = thảm họa bảo mật. |
| **HKDF (HKDF-SHA256)** | Hàm dẫn xuất khóa có khóa bí mật (RFC 5869) → nhiều khóa con + domain separation. | ❌ SHA-256 thuần để "hash dữ liệu nhạy cảm". |
| **HMAC** | Mã xác thực thông điệp có khóa; nền của HKDF & searchable hash. | |
| **ES256** | ECDSA đường cong **P-256** + SHA-256 — thuật toán **ký token** đã chọn. | "256" = SHA-256, KHÔNG phải độ dài khóa. |
| **RS256** | RSA (khóa ≥2048) + SHA-256. | Chỉ dùng nếu cần tương thích client cũ. |
| **EdDSA / Ed25519** | Chữ ký hiện đại, nhanh, deterministic. | Hỗ trợ OIDC chưa phổ biến bằng ES256. |
| **PKI / CA / X.509** | Hạ tầng khóa công khai / tổ chức chứng thực / định dạng chứng thư — cho **chữ ký số pháp lý** (roadmap). | Tích hợp CA được công nhận, **không tự làm CA**. |
| **PAdES / XAdES / CAdES** | Chuẩn ETSI cho chữ ký số tài liệu PDF/XML/CMS (roadmap). | |
| **TokenSigner vs DocumentSignature** | Hai khái niệm code tách biệt cho hai nghĩa "chữ ký số" (xem §1). | |
| **ZKP** (Zero-Knowledge Proof) 🔭 | Chứng minh mệnh đề đúng mà **không lộ dữ liệu gốc, không cần tin trung tâm**. completeness/soundness/zero-knowledge. | Roadmap; mô hình ta dùng claim dẫn xuất + chữ ký thay cho ZKP (xem ADR-0013). |
| **Predicate proof / Range proof** 🔭 | ZKP cho vị từ (vd tuổi≥18, số trong khoảng) — Bulletproofs/zk-SNARK/zk-STARK. | Roadmap. |
| **VC / VP** 🔭 | Verifiable Credential / Presentation (W3C) — credential người dùng tự giữ & xuất trình. | Roadmap (ví số/SSI). |
| **BBS+ / Nullifier** 🔭 | Chữ ký cho selective disclosure + unlinkable / "một người một lần" ẩn danh. | Roadmap. |

---

## 7. Tham chiếu kỹ thuật / hạ tầng (infra reference)

> Phần này là **tra cứu**, không phải ngôn ngữ domain — không dùng các từ này để đặt tên khái niệm nghiệp vụ.

| Thuật ngữ | Nghĩa ngắn |
|---|---|
| **Go** | Ngôn ngữ backend. |
| **chi** | HTTP router idiomatic (net/http) cho OIDC endpoints. |
| **gRPC / Envoy** | RPC nội bộ (core↔SDS) / gateway (REST ngoài + gRPC trong). |
| **ory/fosite** | Thư viện token/crypto OIDC (lớp token, không hand-roll). |
| **PostgreSQL** | CSDL chính cho **toàn bộ** MVP kể cả audit (ADR-0006). |
| **sqlc** | Sinh code Go type-safe từ SQL thuần. |
| **pgxpool** | Driver + connection pool Postgres. |
| **goose** | Công cụ migration schema. |
| **JSONB / GIN** | Kiểu JSON nhị phân Postgres / index cho JSONB & full-text. |
| **pgvector** | Extension vector search trên Postgres (cho audit/tương lai). |
| **RLS** (Row-Level Security) | Phân quyền theo hàng ở tầng Postgres. |
| **Partition** | Chia bảng (vd audit) theo thời gian. |
| **ACID** | Bảo đảm giao dịch (atomic/consistent/isolated/durable). |
| **Redis (Sentinel)** | Store state (session, code, refresh, rate-limit, denylist); Sentinel = HA. |
| **redis_rate** | Thư viện rate limit trên Redis. |
| **Kafka** | Event bus/messaging (audit, eKYC async, retry/DLQ) — ADR-0008. |
| **Topic / Partition / Consumer group** | Khái niệm Kafka: kênh / phân mảnh song song / nhóm tiêu thụ. |
| **DLQ** (Dead-Letter Queue) | Hàng đợi chứa message xử lý thất bại. |
| **Debezium / CDC** | Change Data Capture — relay outbox→Kafka. |
| **Object storage / CDN** | Lưu ảnh/giấy tờ (R2/S3) + phân phối nội dung. |
| **Docker → K8s** | Đóng gói container → điều phối Kubernetes (ADR-0011). |
| **Stateless / replica** | Service không giữ state cục bộ → nhân N bản sau load balancer. |
| **OpenTelemetry / SigNoz / Prometheus** | Chuẩn telemetry / nền APM-trace-log / metrics. |
| **Trace / Span** | Dấu vết một request / một đoạn công việc trong trace. |
| **PITR / DR** | Point-In-Time Recovery / Disaster Recovery. |
| **CI/CD staged** | dev → qc → staging → prelive → live group → live all + rollback. |
| **KRaft / JVM** | Cơ chế đồng thuận Kafka không-ZooKeeper / máy ảo Java (vận hành Kafka). |
| **caarlos0/env · validator · testify · testcontainers · slog** | Config qua env · validate input · test/assert · test với container thật · log chuẩn. |

---

## 8. Tuân thủ & Pháp lý (Compliance)

| Thuật ngữ chuẩn | Nghĩa trong dự án |
|---|---|
| **Nghị định 13/2023/NĐ-CP** | Quy định bảo vệ dữ liệu cá nhân (VN) — ràng buộc xử lý PII. |
| **Luật Giao dịch điện tử 2023** | Cơ sở pháp lý cho chữ ký số/giao dịch điện tử (roadmap chữ ký số). |
| **Luật An ninh mạng 2018 + NĐ53/2022** | Cơ sở **nội địa hóa & chủ quyền dữ liệu** (lưu trú trong nước). Xem ADR-0014. |
| **Luật Căn cước 2023** | Cơ sở pháp lý căn cước/định danh điện tử/VNeID/CSDL dân cư (hiệu lực 1/7/2024). |
| **Đề án 06** | Đề án quốc gia về dữ liệu dân cư + định danh & xác thực điện tử (Bộ Công an chủ trì) — định hướng dự án. |
| **CSDL quốc gia về dân cư / C06** | Cơ sở dữ liệu dân cư + đơn vị vận hành VNeID (Cục C06, Bộ Công an) — nguồn định danh chính thống. |
| **Cấp độ ATTT (NĐ85/2016 · TT03/2017 · TCVN 11930)** | Phân loại & bảo đảm an toàn HTTT theo cấp độ 1–5 (dân cư ~cấp 4–5). Xem ADR-0014. |
| **Ban Cơ yếu Chính phủ** | Cơ quan quản lý mật mã/chữ ký số **chuyên dùng** nhà nước (Luật Cơ yếu 2011) — có thể bắt buộc theo độ mật. |
| **NEAC / RootCA quốc gia** | Trung tâm Chứng thực điện tử quốc gia (Bộ TT&TT) — chuỗi tin cậy CA công cộng cho chữ ký số. |
| **Chủ quyền dữ liệu / data residency** | Dữ liệu lưu & xử lý trong lãnh thổ VN, hạ tầng trong nước/on-prem (không cloud nước ngoài). |
| **GDPR / ISO 27001** | Chuẩn quốc tế về quyền riêng tư / quản lý an toàn thông tin — "ready" theo house. |

---

**Ghi chú bảo trì:** khi thêm khái niệm domain mới trong spec/code → thêm vào đây **trước hoặc cùng lúc**. Khi đổi tên một khái niệm → sửa ở đây rồi lan ra spec/code (đây là nguồn chân lý từ vựng).
