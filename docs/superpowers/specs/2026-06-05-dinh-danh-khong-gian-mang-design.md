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
- Nhúng claim `ial` (Identity Assurance Level) vào ID token.

### 3.2 `ekyc` — Xác minh danh tính
- Định nghĩa interface `Verifier` với các thao tác: đọc giấy tờ (OCR), so khớp khuôn mặt, kiểm tra liveness.
- Một adapter cụ thể gọi nhà cung cấp bên ngoài. FPT.AI là tích hợp tham chiếu đầu tiên; provider cụ thể là cấu hình, không ràng buộc kiến trúc.
- Lưu kết quả xác minh (verification record) + mức tin cậy.
- Bọc trong timeout + retry có kiểm soát.

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

- **PostgreSQL**: `users`, `oauth_clients`, `verifications`, `audit_log`.
- **Redis**: session, token store của fosite, rate limiting.
- **PII** (ảnh giấy tờ, số CCCD, khuôn mặt):
  - Mã hóa khi lưu (envelope encryption).
  - Ảnh gốc xóa sau khi xác minh xong; chỉ giữ kết quả + hash.
  - Tuân thủ **Nghị định 13/2023/NĐ-CP** về bảo vệ dữ liệu cá nhân: đồng ý rõ ràng, quyền xóa, nhật ký truy cập.
- **Audit log**: mọi sự kiện định danh (login, cấp token, eKYC) ghi log bất biến.

## 6. Xử lý lỗi

- Lỗi từ nhà cung cấp eKYC (timeout, ảnh mờ, không khớp) → trả mã lỗi rõ ràng cho client, không nâng IAL, cho phép thử lại có giới hạn (rate limit).
- Tách lỗi nghiệp vụ (4xx, hiển thị cho user) khỏi lỗi hệ thống (5xx, ghi log + cảnh báo).
- Adapter eKYC bọc timeout + retry để lỗi nhà cung cấp không làm sập luồng auth.

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

## 9. Ngoài phạm vi MVP — Roadmap Phase 2+

Cố tình loại khỏi MVP để giữ trọng tâm vào vòng lặp giá trị chính (SSO an toàn + eKYC + nâng IAL). Ranh giới module được thiết kế sẵn để bổ sung mà không phải viết lại:

- **Chữ ký số** (ký tài liệu có giá trị pháp lý) — cần CA/chứng thư số, tích hợp nhà cung cấp ký số, tuân thủ Luật Giao dịch điện tử 2023. Là một module con đáng kể → Phase 2. Có thể gắn quyền ký với mức IAL cao (như UAE PASS).
- **SDK cho bên tích hợp** — đường tắt cho relying party; MVP đã dùng được qua thư viện OIDC chuẩn nên chưa cấp thiết.
- **Kho tài liệu / ví credential** (kiểu Digital Vault) — lưu & chia sẻ chọn lọc giấy tờ đã xác minh.
- **Định danh người chơi game** (lát cắt B2C/game).
- **Đa nhà cung cấp eKYC** (định tuyến/đối chiếu nhiều provider).
- **Tách microservices (Hướng B) / hàng đợi bất đồng bộ (Hướng C)**.
- **Social login** và **mô hình SSI/DID** (nếu sau này muốn lai với hướng NDA Key).
