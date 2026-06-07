# ADR-0004: SDS là service cô lập + mô hình khóa có version

- **Trạng thái:** Accepted
- **Ngày:** 2026-06-07

## Bối cảnh
PII/KYC cần được bảo vệ tuyệt đối (NĐ13/2023, GDPR/ISO-ready). Mô hình SDS trong tài liệu house dùng khóa theo tenant. Nền tảng định danh theo Mô hình B (một pool, không tenant — xem ADR-0001) nên cần điều chỉnh mô hình khóa.

## Quyết định
Tách toàn bộ PII/KYC sang **Sensitive Data Service** cô lập (own DB, private network, partner-key + IP whitelist; chỉ fetch theo `kyc_id`, không có list/search tương đối). Mô hình khóa **không theo tenant** mà **có version**:
`MASTER_KEY` (KMS/Vault) → `DATA_KEY` (random AES-256, có version, mã hóa bởi MASTER_KEY) → khóa dẫn xuất (`encrypt`/`hash`/`event`) qua **HKDF-SHA256**; mã hóa **AES-256-GCM**; searchable bằng hash suffix; xoay khóa theo version + background re-encrypt.

## Hệ quả
- **Tích cực:** DB lộ không đọc được nếu thiếu MASTER_KEY+DATA_KEY; **blast-radius nhỏ** (lộ một version chỉ ảnh hưởng dữ liệu mã bằng version đó); sẵn sàng nâng lên đa tenant sau (chỉ cần đổi data key theo tenant).
- **Tiêu cực:** thêm một service + DB để vận hành/bảo mật; quản lý vòng đời khóa phức tạp, cần test kỹ.

## Phương án đã cân nhắc
- **Khóa theo tenant (như house):** thừa cho Mô hình B; versioning đạt mục tiêu blast-radius mà đơn giản hơn.
- **Mã hóa ngay trong identity-core:** mất cô lập, tăng bề mặt lộ PII.
