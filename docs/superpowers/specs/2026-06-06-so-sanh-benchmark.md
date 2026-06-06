# So sánh benchmark: UAE PASS · NDA Key · Plan của ta (Mô hình B)

**Ngày:** 2026-06-06
**Mục đích:** đối chiếu hai dự án mẫu với plan định danh của ta trên 3 trục — **tính năng, công nghệ, giải pháp tổng thể** — để rút bài học & xác định khoảng trống.

## 0. Ba nguồn & mô hình nền tảng

| Nguồn | Bản chất | Mô hình |
|---|---|---|
| **UAE PASS** | Định danh số **quốc gia** của UAE (gov + tư nhân) | **Tập trung** — IdP OIDC + chữ ký số + vault |
| **NDA Key** (thuộc NDAChain, VN) | Định danh **phi tập trung** trên blockchain quốc gia | **SSI/decentralized** — DID + VC + ZKP |
| **Plan của ta** | eKYC + IdP/SSO, một pool | **Tập trung** — IdP OIDC tự viết + eKYC + SDS |

→ **Plan của ta gần UAE PASS nhất về mô hình** (đều tập trung, OIDC). NDA Key là "con đường không chọn" (phi tập trung).

## 1. So sánh TÍNH NĂNG

| Tính năng | UAE PASS | NDA Key | Plan của ta |
|---|---|---|---|
| SSO / OIDC | ✅ 15.000+ dịch vụ, 7.2M user | qua SDK/DID | ✅ (một issuer, nhiều RP) |
| eKYC / xác minh người thật | ✅ | ✅ (mobile, fraud-proof) | ✅ (adapter provider, IAL1/2) |
| Cấp độ định danh | ✅ unverified→verified→qualified | (theo VC) | ✅ IAL1/IAL2 |
| Sinh trắc / Passkey | ✅ (app 2FA) | ✅ Passkey/FIDO | ✅ Passkey/FIDO + MFA |
| **Chữ ký số pháp lý** | ✅ | ✅ | ⏸️ roadmap |
| **Kho tài liệu/ví** | ✅ Digital Vault | ✅ ví credential | ⏸️ roadmap |
| **Verifiable Credentials + ZKP** (chia sẻ chọn lọc) | ❌ | ✅ (điểm mạnh) | ❌ (mô hình tập trung) |
| **Tích hợp VNeID / ID quốc gia** | ✅ (Emirates ID) | ✅ (`did:nda` ↔ VNeID) | ❌ **chưa có — đáng cân nhắc** |
| Bảo vệ PII mã hóa | (vault) | ZKP/on-chain proof | ✅ **SDS (điểm mạnh của ta)** |

## 2. So sánh CÔNG NGHỆ

| Khía cạnh | UAE PASS | NDA Key | Plan của ta |
|---|---|---|---|
| Giao thức định danh | OAuth 2.0 / OIDC (auth code) | **DID + Verifiable Credentials**, DIDComm | OAuth 2.0 / OIDC (code+PKCE) |
| Hạ tầng tin cậy | IdP tập trung (server-side session, /logout) | **Blockchain NDAChain** (PoA + ZKP, ~1.200–3.600 TPS) | DB tập trung (Postgres) |
| Quyền riêng tư | mức tài khoản | **ZKP** — chứng minh không lộ dữ liệu | mã hóa AES-256-GCM + RBAC theo `kyc_id` |
| Chuẩn | OIDC | **W3C DID, VC, eIDAS 2.0, GDPR** | OIDC, NĐ13/2023 (ISO/GDPR-ready) |
| Token | OIDC token (qua app) | VC / on-chain proof | **JWT ES256 + JWKS + xoay khóa**, refresh rotation+reuse-detection |
| Khóa/Crypto | (không công bố) | blockchain key, ZKP | **MASTER_KEY→DATA_KEY(version)→HKDF** (mô hình SDS) |
| Stack | (gov, không công bố; RP hay broker qua Keycloak/WSO2) | blockchain + mobile SDK | **Go + DDD/Clean Arch + Postgres + Redis + Kafka + K8s + Envoy + OTel** |
| Tự viết hay nền sẵn | nền quốc gia | nền blockchain quốc gia | **tự viết IdP** (thư viện cho token) |

## 3. So sánh GIẢI PHÁP TỔNG THỂ (triết lý kiến trúc)

- **UAE PASS** = "một danh tính quốc gia, đăng nhập mọi nơi" — tập trung, tiện, kiểm soát bởi nhà nước; RP tích hợp dễ qua OIDC chuẩn (nhiều RP dùng Keycloak/WSO2 làm broker). Điểm mạnh: phủ rộng, chữ ký số pháp lý, vault. Điểm yếu: quyền riêng tư ở mức tập trung, người dùng không "sở hữu" dữ liệu.
- **NDA Key** = "người dùng sở hữu danh tính" — phi tập trung, ZKP cho quyền riêng tư, tương thích chuẩn toàn cầu (W3C DID), gắn VNeID. Điểm mạnh: privacy, chủ quyền dữ liệu, chia sẻ chọn lọc. Điểm yếu: phức tạp, cần hạ tầng blockchain, độ chín ứng dụng còn mới.
- **Plan của ta** = "IdP tập trung tự chủ + bảo vệ PII bằng SDS" — đi giữa: mô hình tập trung kiểu UAE PASS (đơn giản, OIDC chuẩn) nhưng **đầu tư mạnh vào mã hóa PII (SDS)** thay vì ZKP. Điểm mạnh: tự chủ codebase, bảo mật PII bài bản, stack vận hành quen thuộc, ra MVP nhanh. Điểm yếu: chưa có chữ ký số/vault/VC, **chưa tích hợp VNeID**, quyền riêng tư không bằng ZKP.

## 4. Bài học & khuyến nghị cho plan

**Nên học / cân nhắc đưa vào roadmap:**
- 🔵 **Tích hợp VNeID** (như NDA Key gắn `did:nda`↔VNeID; UAE PASS gắn Emirates ID). Với một nền tảng định danh ở VN, đây là **khoảng trống đáng chú ý nhất** — có thể là nguồn IAL cao/eKYC chính thống. → đề nghị thêm vào roadmap (hoặc cân nhắc cho MVP nếu định hướng "định danh công dân").
- 🔵 **Chữ ký số pháp lý** + **vault/ví credential** — cả hai mẫu đều có; đã nằm roadmap của ta.
- 🔵 **Verifiable Credentials + selective disclosure (ZKP)** — nếu sau này cần quyền riêng tư cao / chia sẻ chọn lọc, đây là hướng lai với mô hình NDA Key (đã ghi "SSI/DID" trong roadmap).
- 🔵 **App authenticator + /logout phía IdP** (UAE PASS) — quản lý session tập trung, có endpoint logout chuẩn OIDC. Lưu ý cho thiết kế session.

**Ta cố tình khác (giữ nguyên):**
- Tập trung thay vì SSI/blockchain (đơn giản, hợp MVP) — như UAE PASS, khác NDA Key.
- Tự viết IdP thay vì dùng nền sẵn — đánh đổi đã phân tích.
- Bảo vệ PII bằng **SDS mã hóa** (điểm khác biệt & mạnh của ta) thay vì ZKP/on-chain.

**Khoảng trống cần quyết:**
- Có đưa **VNeID** vào không, và ở MVP hay roadmap?
- Mức quyền riêng tư: chấp nhận mô hình tập trung (mã hóa + RBAC) hay sau này tiến tới VC/ZKP?

## Nguồn
- UAE PASS: [u.ae official](https://u.ae/en/about-the-uae/digital-uae/digital-transformation/platforms-and-apps/the-uae-pass-app), [docs.uaepass.ae](https://docs.uaepass.ae/), [tích hợp OIDC/Keycloak](https://medium.com/@shrivastavamohit628/implementing-uae-pass-authentication-with-keycloak-a-complete-guide-beaae5c4d555), [tích hợp WSO2](https://medium.com/identity-beyond-borders/integrating-uae-pass-as-the-federated-authentication-in-wso2-identity-server-5-11-0-c61b87042578)
- NDA Key / NDAChain: [ndakey.vn](https://www.ndakey.vn/vi), [ndachain.vn](https://ndachain.vn/en), [CCN giải thích NDAChain](https://www.ccn.com/education/crypto/ndachain-vietnam-national-blockchain-explained/), [Vietnam Briefing](https://www.vietnam-briefing.com/news/vietnam-introduces-national-blockchain-platform-new-tool-for-secure-data-identity-and-compliance.html/)
