# Quyết định công nghệ & Tradeoff — Nền tảng Định danh trên Không gian mạng

**Tác giả:** Thành Lê Phước

**Ngày:** 2026-06-08 · **Loại:** So sánh công nghệ toàn stack (cross-stack overview)

> **Nguồn chân lý:** quyết định kiến trúc đầy đủ nằm ở `docs/adr/` (mỗi quyết định một ADR, bất biến). Tài liệu này **chỉ tổng hợp & so sánh** để xem cả stack trong một khung nhìn — khi mâu thuẫn, **ADR thắng**. Từ vựng: xem `docs/ubiquitous-language.md`.

## 0. Cách đọc

Mỗi quyết định trả lời 5 câu: **chọn gì · phương án khác · vì sao chọn · tradeoff chấp nhận · ADR**. Nguyên tắc xuyên suốt: **bám house O2O ở mức convention + dùng chuẩn/thư viện đã kiểm chứng, không hand-roll, không bung quá mức cho MVP.**

> ⚠️ **Ràng buộc chi phối — [ADR-0014](adr/0014-du-an-nha-nuoc-cong-an.md) (dự án nhà nước & công an):** chủ quyền & lưu trú dữ liệu trong nước, **hạ tầng trong nước/on-prem (KHÔNG cloud nước ngoài)**, VNeID/CSDL dân cư bắt buộc, PKI quốc gia (NEAC/Ban Cơ yếu), cấp độ ATTT cao. Mọi lựa chọn dưới đây được đọc **dưới ràng buộc này**.

---

## 1. Bảng tổng hợp toàn stack

| # | Lớp | ✅ Chọn | Phương án khác | Vì sao chọn (tóm tắt) | Tradeoff chấp nhận | ADR |
|---|---|---|---|---|---|---|
| 1 | Ngôn ngữ | **Go** | Node.js, Java | Hiệu năng, biên dịch tĩnh, hợp dịch vụ xác thực chịu tải; khớp house | Verbose hơn; ít "magic" | [0010](adr/0010-go-ddd-clean-arch.md) |
| 2 | Kiểu kiến trúc | **Modular monolith + SDS cô lập + workers** | Microservices đầy đủ; monolith thuần | Nhanh ra MVP, ranh giới sạch để tách sau; SDS cô lập đúng nơi cần | Phải kỷ luật giữ ranh giới module | [0003](adr/0003-topology-gon.md) |
| 3 | Mô hình định danh | **Một pool, RP/client** | Multi-tenant (issuer-per-tenant) | Bỏ rủi ro lớn nhất (multi-tenant OIDC tự viết); chuẩn OIDC một issuer | Bán IdP cho tổ chức ngoài sau này phải nâng cấp lớn | [0001](adr/0001-mo-hinh-mot-pool.md) |
| 4 | IdP | **Tự viết + `ory/fosite`** | Keycloak/Ory trọn gói; hand-roll crypto | Sở hữu nghiệp vụ/UI; an toàn lớp token nhờ thư viện | Tự gánh đúng-đắn luồng OIDC | [0002](adr/0002-tu-viet-idp.md) |
| 5 | Layering | **DDD/Clean Arch + CQRS + chi**, DI thủ công | Layering phẳng; framework DI | Ranh giới sạch, dễ test/mock; khớp house | Boilerplate; cần kỷ luật tầng | [0010](adr/0010-go-ddd-clean-arch.md) |
| 6 | Token OIDC | **JWT ES256 + JWKS** (validate offline) | Opaque + introspection; RS256 | Scale tốt (IdP rời hot-path validate); ES256 nhỏ/nhanh | JWT không thu hồi tức thì → TTL ngắn + denylist | [0005](adr/0005-oidc-token-strategy.md) |
| 7 | **Database** | **PostgreSQL-first (kể cả audit)** | MongoDB cho audit (house); MySQL | Một datastore = ít bề mặt bảo mật; Postgres phủ ACID+JSONB+full-text+pgvector+RLS+partition | Sharding log thủ công hơn Mongo (chỉ khi volume rất lớn) | [0006](adr/0006-postgres-first.md) |
| 8 | Truy cập DB | **sqlc + pgxpool + goose** | Bun (ORM house); GORM; pgx thuần | SQL tường minh, type-safe — quan trọng cho truy vấn nhạy cảm/RLS | Lệch cơ-tay team (quen Bun); bước codegen | [0007](adr/0007-sqlc.md) |
| 9 | State/cache | **Redis (Sentinel)** | In-memory; Postgres làm session | Stateless scale ngang; TTL/atomic ops cho code/refresh/rate-limit/denylist | Thêm một hạ tầng phải HA | [0011](adr/0011-trien-khai-k8s-observability.md) |
| 10 | Messaging | **Kafka + transactional outbox** | NATS JetStream; Postgres-queue/River; Redpanda/WarpStream | Proven & bền vững; tái dùng hạ tầng + expertise house | Ops nặng; hơi thừa cho tải MVP | [0008](adr/0008-kafka-messaging.md) |
| 11 | eKYC | **Adapter nhà cung cấp** (`Verifier`) | Tự train model in-house | Ra MVP nhanh, độ chính xác cao; provider là cấu hình | Phụ thuộc bên thứ ba (đã bao vây) | [0009](adr/0009-ekyc-adapter.md) |
| 12 | Nguồn eKYC chính | **VNeID (MVP) + FPT.AI fallback** | Chỉ provider thương mại | Nguồn chính thống, chống giả mạo mạnh; hợp định hướng công dân | Phụ thuộc quy trình cấp phép cơ quan; cần fallback | [0012](adr/0012-vneid-trong-mvp.md) |
| 13 | Mã hóa PII | **AES-256-GCM + HKDF + envelope** | AES-CBC+HMAC; ChaCha20-Poly1305; GCM-SIV | AEAD một bước; AES-NI nhanh; envelope giới hạn blast-radius | Phải đảm bảo nonce không tái dùng | [0004](adr/0004-sds-va-mo-hinh-khoa.md) |
| 14 | Băm mật khẩu | **argon2id** | bcrypt; scrypt; PBKDF2 | Thắng Password Hashing Competition; kháng GPU/ASIC + side-channel | Tốn RAM/CPU (cố ý) → cần tinh chỉnh tham số | — |
| 15 | Passkey | **WebAuthn (`go-webauthn`)** | Chỉ mật khẩu+TOTP | Chống phishing, không mật khẩu; chuẩn FIDO2 | UX onboarding thiết bị; cần fallback | — |
| 16 | Lưu file | **Object storage + CDN trong nước/on-prem** (cloud nội địa) | ❌ Cloudflare R2/S3 (nước ngoài); blob trong Postgres | **Chủ quyền dữ liệu** (ADR-0014); DB gọn, scale ảnh/giấy tờ | Ít managed service; tự vận hành nhiều hơn | [0011](adr/0011-trien-khai-k8s-observability.md) · [0014](adr/0014-du-an-nha-nuoc-cong-an.md) |
| 17 | Triển khai | **Docker → K8s + Envoy** | VM/Docker đơn thuần | Scale ngang, nhất quán house, gateway chuẩn | K8s+Envoy là chi phí vận hành (có thể Docker trước) | [0011](adr/0011-trien-khai-k8s-observability.md) |
| 18 | Observability | **OpenTelemetry → SigNoz + Prometheus** | Datadog; ELK | Chuẩn mở, không khóa nhà cung cấp; **tự-host (chủ quyền)**; khớp house | Tự vận hành stack quan sát | [0011](adr/0011-trien-khai-k8s-observability.md) |
| ⚑ | **Bối cảnh/ràng buộc** | **Dự án nhà nước & công an** | (SaaS thương mại) | Chủ quyền dữ liệu + an ninh quốc gia; **chi phối mọi lớp trên** | Bỏ cloud nước ngoài; cấp phép VNeID; cấp độ ATTT cao | [0014](adr/0014-du-an-nha-nuoc-cong-an.md) |

---

## 2. Đào sâu các quyết định trọng yếu

### 2.1 Database — vì sao PostgreSQL-first cho TẤT CẢ (kể cả audit)

User hỏi "từ database" → đây là phần được nhấn. House O2O dùng Postgres cho giao dịch + **MongoDB cho audit**. Ta **lệch có chủ đích**: dùng Postgres cho cả audit, hoãn Mongo.

| Tiêu chí | ✅ **PostgreSQL** | MySQL | MongoDB |
|---|---|---|---|
| ACID / giao dịch đa bảng | Mạnh, MVCC tốt | Có (InnoDB) | Yếu hơn (multi-doc txn mới có, đắt) |
| Ràng buộc quan hệ / FK | Đầy đủ | Đầy đủ | Không (document) |
| JSON | **JSONB + GIN** (index, query sâu) | JSON (yếu hơn) | Bản địa (mạnh) |
| Full-text search | **Tích hợp** (tsvector) | Cơ bản | Có |
| Vector search | **pgvector** | Không | Atlas Vector (managed) |
| Row-Level Security | **Có (RLS)** — quan trọng cho PII/đa quyền | Không | Không |
| Partition (audit theo thời gian) | **Declarative partitioning** | Có | Sharding tự động |
| Audit append-only + truy vấn linh hoạt | Postgres phủ đủ (JSONB+GIN+full-text+vector) | Hạn chế | Mạnh khi schema lỏng |
| Sharding ngang khi volume CỰC lớn | Thủ công hơn | Thủ công hơn | **Auto-sharding** (điểm mạnh) |
| Bề mặt bảo mật/vận hành | **1 datastore** | 2 datastore | 2 datastore |

**Kết luận:** với nền tảng **bảo mật**, ít datastore = ít bề mặt phải bảo mật/sao lưu/giám sát. Postgres một mình phủ **đủ** nhu cầu MVP kể cả audit (full-text + vector trên cùng engine). **Mongo chỉ rút ra** khi audit cần auto-sharding ở volume rất lớn → để **roadmap**. (ADR-0006)

### 2.2 Token — vì sao JWT ES256, không opaque, không RS256

| Trục | ✅ JWT ES256 + JWKS | Opaque + introspection | RS256 |
|---|---|---|---|
| Validate | **Offline** tại RP (qua JWKS) | Mỗi lần gọi về IdP | Offline |
| Tải lên IdP | Chỉ issuance/refresh | **Mọi request** → nút thắt | Như ES256 |
| Kích thước token / chữ ký | **Nhỏ** (~64B) | Nhỏ (chuỗi tham chiếu) | Lớn (~256B) |
| Thu hồi tức thì | Không (bù: TTL 15–30′ + denylist) | **Có** | Không |
| Mức an toàn / khóa | P-256 ≈ RSA-3072, khóa nhỏ | — | RSA-2048, khóa lớn |

→ Chọn **ES256** vì scale (validate offline) + token gọn/nhanh. Bù điểm yếu "không thu hồi tức thì" bằng **TTL ngắn + refresh rotation/reuse-detection + denylist Redis**. RS256 chỉ để dành nếu cần tương thích client cũ. (ADR-0005). Chi tiết AES vs RSA, ý nghĩa "256": xem `docs/ubiquitous-language.md` §6.

### 2.3 Messaging — vì sao giữ Kafka

| Trục | ✅ Kafka | NATS JetStream | Postgres-queue (River) | Redpanda/WarpStream |
|---|---|---|---|---|
| Độ chín / proven | **Rất cao** | Cao | Trung bình | Cao (Kafka-API) |
| Đã có trong house + expertise | **Có** | Không | Không | Một phần |
| Ops | Nặng (KRaft/JVM, partition) | **Nhẹ, Go-native** | **Zero hạ tầng mới** | Nhẹ hơn Kafka |
| Hệ sinh thái (Connect/CDC/registry) | **Sâu** | Hẹp hơn | — | Tương thích Kafka |
| Hợp tải MVP | Hơi thừa | Vừa | Vừa cho job đơn giản | Vừa |

→ Yếu tố quyết định: **"Kafka đã được chứng minh bền vững" + house đã vận hành + team quen**. Không thêm công nghệ mới khi cái proven đã có. Đúng-đắn (không mất/trùng event audit/eKYC) đảm bảo bằng **transactional outbox + Debezium/CDC**. River có thể bổ trợ job đơn giản; Redpanda/WarpStream để dành nếu muốn ops nhẹ mà giữ Kafka API. (ADR-0008)

### 2.4 IdP — vì sao tự viết (mà vẫn dùng thư viện)

| Phương án | Sở hữu | Tốc độ MVP | Rủi ro bảo mật | Tùy biến |
|---|---|---|---|---|
| **✅ Tự viết app + `ory/fosite`** | **Cao** | Trung bình | Trung bình (token lib đã kiểm chứng) | **Cao** |
| Keycloak/Ory trọn gói | Thấp | Nhanh | Thấp (đã chứng nhận) | Thấp/khó sâu |
| Hand-roll cả crypto/token | Cao | Chậm | **Cao** (anti-pattern) | Cao |

→ Lằn ranh: **sở hữu lớp nghiệp vụ/UI/luồng, nhưng KHÔNG hand-roll crypto/JWT** — đó là việc của `ory/fosite`. Cân bằng "tự chủ" với "không tự chế tạo bảo mật". (ADR-0002)

---

## 3. Lựa chọn thư viện/cơ chế (chưa có ADR riêng — ghi để nhất quán)

| Hạng mục | ✅ Chọn | Phương án khác | Vì sao |
|---|---|---|---|
| Băm mật khẩu | **argon2id** | bcrypt, scrypt, PBKDF2 | Thắng PHC 2015; tham số memory-hard kháng GPU/ASIC + kháng side-channel (biến thể `id`) |
| Mã hóa dữ liệu | **AES-256-GCM** | AES-CBC+HMAC; ChaCha20-Poly1305; **AES-GCM-SIV** | AEAD một bước + AES-NI; GCM-SIV là nâng cấp nếu lo nonce reuse; ChaCha tốt khi thiếu AES-NI |
| Dẫn xuất khóa | **HKDF-SHA256** | SHA-256 thuần; bcrypt-KDF | Có khóa bí mật + salt + `info` → domain separation; deterministic (không cần lưu khóa con) |
| Ký token | **ES256 (ECDSA P-256)** | RS256, EdDSA/Ed25519 | Khóa/chữ ký nhỏ, an toàn ≈ RSA-3072; EdDSA tốt nhưng hỗ trợ OIDC chưa rộng |
| Router HTTP | **chi** | gin, echo, net/http thuần | Idiomatic, tương thích `net/http`, middleware sạch |
| Config | **caarlos0/env** | viper, koanf | Gọn, struct-tag, hợp 12-factor |
| Rate limit | **redis_rate** | in-memory limiter | Chia sẻ giới hạn xuyên replica (stateless) |
| Test | **testify + testcontainers** | mock thuần, sqlite test | Test với Postgres/Redis **thật** trong container → sát production |
| Log | **slog** (chuẩn thư viện Go) | zap, zerolog | Chuẩn stdlib, structured, đủ nhanh; ghép OTel |

---

## 4. Tradeoff cấp hệ thống (đánh đổi đã chấp nhận, ghi rõ để không quên)

| Đánh đổi | Lợi | Hại đã chấp nhận | Cách bù / lối thoát |
|---|---|---|---|
| Bỏ multi-tenant | Đơn giản, xóa rủi ro lớn nhất | Bán IdP cho tổ chức ngoài sau này tốn công | DATA_KEY có version + ranh giới module sạch để nâng cấp |
| Postgres-first (hoãn Mongo) | 1 datastore, ít bề mặt bảo mật | Sharding audit thủ công khi volume cực lớn | Partition + pgvector; rút Mongo ra theo roadmap |
| JWT (không thu hồi tức thì) | Validate offline, scale | Token sống tới hết TTL | TTL 15–30′ + refresh rotation/reuse-detection + denylist |
| Kafka (ops nặng) | Proven, tái dùng house | Vận hành nặng cho tải MVP | Outbox đảm bảo đúng-đắn; Redpanda/WarpStream để dành |
| Tự viết IdP | Tự chủ, tùy biến | Gánh đúng-đắn OIDC | `ory/fosite` cho token + integration test luồng |
| Phụ thuộc provider eKYC/VNeID | Ra MVP nhanh, chính thống | Lệ thuộc bên thứ ba | Adapter `Verifier` + timeout + circuit breaker + fallback |
| Hoãn K8s autoscale/đa-DC | MVP gọn | Chưa sẵn quy mô cực lớn | Stateless sẵn sàng; bật khi cần (nợ có kiểm soát) |
| Bỏ cloud nước ngoài (ADR-0014) | Chủ quyền dữ liệu, hợp quy định nhà nước | Mất tiện ích managed (R2/CDN toàn cầu); tự vận hành nhiều hơn | Cloud nội địa + OSS tự-host (Postgres/Redis/Kafka/SigNoz vốn đã chọn) |

---

**Bảo trì:** quyết định mới → viết **ADR mới** trong `docs/adr/` (nguồn chân lý), rồi thêm một dòng vào bảng §1 ở đây. Tài liệu này **không** được trở thành nguồn chân lý cạnh tranh với ADR.
