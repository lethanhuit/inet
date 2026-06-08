# Bộ tìm hiểu tính năng: UAE PASS & NDA Key

**Tác giả:** Thành Lê Phước

**Ngày:** 2026-06-07
**Mục đích:** catalog tính năng chi tiết của hai sản phẩm mẫu để rút bài học & quyết định đưa vào MVP/roadmap. (Bổ trợ cho `docs/superpowers/specs/2026-06-06-so-sanh-benchmark.md`.)

---

## Phần 1 — UAE PASS (định danh quốc gia UAE, tập trung)

Nền tảng định danh số + chữ ký số quốc gia, dùng OAuth 2.0 / OIDC. App di động đóng vai "digital idSP" (authenticator). 7.2M+ user, 15.000+ dịch vụ.

### 1.1 Ba nhóm tính năng chính
| Tính năng | Cho ai | Mô tả |
|---|---|---|
| **Authentication** | Gov + tư nhân | Đăng ký & đăng nhập (SSO) qua OIDC; xác thực bằng app di động + 2FA |
| **Digital Signature & eSeal** | Gov + tư nhân | Ký tài liệu / đóng dấu điện tử có giá trị pháp lý |
| **Data & Document Sharing** | Tư nhân (gov qua GSB) | Chia sẻ tài liệu/hồ sơ giữa các bên |

### 1.2 Levels of Assurance (SOP) — mô hình cấp độ định danh
| Mức | Trạng thái | Chữ ký số | Ghi chú |
|---|---|---|---|
| **SOP1** | Chưa xác minh (chỉ email + SĐT) | ❌ không | Không truy cập chữ ký / chia sẻ dữ liệu |
| **SOP2** | Đã xác minh (Smart Pass/Dubai ID, **Emirates ID**) | ✅ Advanced | Ký nâng cao nếu app cho phép |
| **SOP3** | Đã xác minh | ✅ Qualified | Ký đủ điều kiện (cao nhất) |

→ Cấp độ gắn với **năng lực** (signature/sharing) — không chỉ là nhãn. `userType`/attribute phản ánh LoA. Có kịch bản cho **visitor** (khách, không Emirates ID).

### 1.3 Mô hình tích hợp
- OAuth 2.0 / OIDC, Authorization Code; RP đổi code lấy token rồi gọi userinfo.
- **Session phía IdP** + endpoint **/logout** bắt buộc để kết thúc phiên (SLO).
- App di động làm authenticator (push/2FA); ký tài liệu trong app.
- Bộ **attributes** chuẩn (Emirates ID, tên, LoA…) trả qua userinfo.

### 1.4 Bài học cho ta
- ✅ **Mô hình LoA gắn năng lực** rất hợp với IAL của ta — nên thiết kế IAL không chỉ là nhãn mà **mở khóa tính năng** (vd IAL cao mới được ký số / chia sẻ).
- ✅ **/logout (SLO) phía IdP** — nhớ thiết kế single-logout, không chỉ xóa session phía RP.
- ✅ Chữ ký số 2 mức (Advanced/Qualified) — tham chiếu khi làm chữ ký số (roadmap).

---

## Phần 2 — NDA Key / NDAChain (định danh phi tập trung, VN)

Ứng dụng định danh tự chủ (SSI) trên **NDAChain** — blockchain quốc gia VN (permissioned L1, PoA + ZKP, ~3.600 TPS, 49 validator; do National Data Association phát triển, Bộ Công an vận hành; ra mắt 07/2025). Mô hình **lai** (tập trung + phi tập trung).

### 2.1 Tính năng NDA Key
| Tính năng | Mô tả |
|---|---|
| **Quản lý danh tính SSI** | Lưu/mã hóa giấy tờ dưới dạng **Verifiable Credentials (VC)** trên điện thoại; người dùng tự kiểm soát |
| **Verifiable Presentation (VP)** | Tạo "bằng chứng số" để **chia sẻ chọn lọc** dữ liệu |
| **eKYC / xác minh** | Xác minh danh tính nhanh, chống giả mạo (fraud-proof) qua app |
| **Passkey / FIDO** | Xác thực sinh trắc chuẩn FIDO |
| **Zero-Knowledge Proof (ZKP)** | Chứng minh tính đúng **mà không lộ dữ liệu gốc** |
| **DIDComm** | Giao thức trao đổi dữ liệu mã hóa đầu-cuối dựa trên DID |
| **DID + VC/VP + JSON-LD** | Chuẩn W3C, liên thông toàn cầu |
| **Tích hợp VNeID** | NDA DID gắn với **VNeID** — xác minh danh tính trong vài giây |
| **SDK** | Tích hợp cho doanh nghiệp |

### 2.2 Hệ sinh thái NDAChain (liên quan)
- **NDA DID** — định danh phi tập trung gắn VNeID (ký hợp đồng số, truy cập dịch vụ).
- **NDATrace** — xác thực sản phẩm (GS1, W3C DID, EU EBSI).
- Chuẩn: **W3C DID, VC, GS1, GDPR, eIDAS 2.0**.

### 2.3 Bài học cho ta
- 🔵 **Tích hợp VNeID** — NDA Key gắn `did:nda`↔VNeID. **Ta đã quyết đưa VNeID vào MVP** → đây là tham chiếu trực tiếp về cách dùng VNeID làm nguồn xác minh chính thống.
- 🔵 **VC/VP + selective disclosure (ZKP)** — hướng nâng cấp quyền riêng tư cho roadmap (nếu cần chia sẻ chọn lọc).
- 🔵 **Passkey/FIDO** — đã có trong MVP của ta.
- ⚪ SSI/blockchain/DID — ta cố tình KHÔNG theo (Mô hình B tập trung); chỉ tham khảo nếu sau này lai SSI.

---

## Phần 3 — Đối chiếu nhanh & ánh xạ vào plan của ta

| Tính năng (từ 2 mẫu) | UAE PASS | NDA Key | Plan của ta |
|---|---|---|---|
| OIDC SSO | ✅ | qua SDK | ✅ MVP |
| eKYC + cấp độ định danh | ✅ SOP | ✅ | ✅ MVP (IAL1/2) |
| **VNeID / ID quốc gia** | ✅ Emirates ID | ✅ VNeID | ✅ **MVP (vừa quyết)** |
| Passkey/FIDO | ✅ | ✅ | ✅ MVP |
| **IAL mở khóa năng lực** | ✅ (SOP→signature) | – | 🔵 **nên áp dụng** (thiết kế IAL gắn quyền) |
| **Single-logout (SLO)** | ✅ /logout | – | 🔵 **nên thêm** vào auth |
| Chữ ký số (Advanced/Qualified) | ✅ | ✅ | ⏸ roadmap |
| Kho tài liệu / ví VC | ✅ Vault | ✅ ví VC | ⏸ roadmap |
| VC/VP + ZKP (chia sẻ chọn lọc) | ❌ | ✅ | ⏸ roadmap (nếu lai SSI) |
| Bảo vệ PII mã hóa | vault | ZKP/on-chain | ✅ **SDS (điểm mạnh ta)** |

**Hai điều chỉnh đề xuất cho identity-core (rút từ tìm hiểu này):**
1. **IAL gắn năng lực** (như SOP của UAE PASS) — IAL không chỉ là nhãn mà điều kiện mở khóa tính năng (ký số, chia sẻ…).
2. **Single-Logout (SLO)** — thêm endpoint/luồng logout phía IdP, không chỉ xóa session RP.

## Nguồn
- UAE PASS: [docs.uaepass.ae overview](https://docs.uaepass.ae/overview), [User Account Types (SOP)](https://docs.uaepass.ae/guidelines/use-case-guidelines/user-account-types), [Signing Guide](https://docs.uaepass.ae/feature-guides/signature-integration-guide/digital-signature-single-document/signing-guide), [Attributes List](https://docs.uaepass.ae/resources/attributes-list), [u.ae](https://u.ae/en/about-the-uae/digital-uae/digital-transformation/platforms-and-apps/the-uae-pass-app)
- NDA Key / NDAChain: [ndakey.vn](https://www.ndakey.vn/vi), [NDA Key trên Google Play](https://play.google.com/store/apps/details?id=io.kyc.onboarding), [CCN — NDAChain explained](https://www.ccn.com/education/crypto/ndachain-vietnam-national-blockchain-explained/), [CryptoNinjas — 3,600 TPS & Digital ID](https://www.cryptoninjas.net/news/vietnams-ndachain-goes-live-a-national-blockchain-powering-3600-tps-digital-id/), [The Paypers](https://thepaypers.com/fraud-and-fincrime/news/vietnam-rolls-out-ndachain-blockchain-for-public-data-use)
