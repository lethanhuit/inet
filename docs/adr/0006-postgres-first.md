# ADR-0006: Postgres-first kể cả audit; MongoDB hoãn

- **Trạng thái:** Accepted
- **Ngày:** 2026-06-07

## Bối cảnh
Dữ liệu lõi (credential, token, khóa, sensitive_data) cần ACID + ràng buộc. House dùng PostgreSQL cho giao dịch và **MongoDB cho audit log** (Kafka→Mongo, full-text/vector search).

## Quyết định
Dùng **PostgreSQL cho TOÀN BỘ MVP**, kể cả **audit log** (append-only, partition theo thời gian, JSONB+GIN, full-text, **pgvector**). **MongoDB đưa vào roadmap** — chỉ rút ra khi audit cần scale ngang.

## Hệ quả
- **Tích cực:** một datastore = ít bề mặt bảo mật/vận hành (quan trọng với nền tảng bảo mật); Postgres phủ đủ nhu cầu audit (full-text + vector); ACID/RLS cho dữ liệu định danh.
- **Tiêu cực:** *deviation có chủ đích* so với house; Postgres sharding cho log tốn công hơn auto-sharding của Mongo (chỉ là vấn đề khi volume rất lớn).

## Phương án đã cân nhắc
- **MongoDB cho audit (như house):** tốt khi volume cực lớn, nhưng thêm một cụm phải bảo mật/sao lưu — chưa cần cho MVP.
