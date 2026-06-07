# ADR-0003: Topology gọn — core modular + SDS cô lập + workers

- **Trạng thái:** Accepted
- **Ngày:** 2026-06-07

## Bối cảnh
House O2O theo microservices đầy đủ. Nền tảng định danh cần cân bằng tốc độ ra MVP và đường tiến hóa, không nên bung cả rừng service nhưng cũng không nên monolith thuần (vì SDS cần cô lập).

## Quyết định
Topology **gọn, một bộ deployable nhỏ**:
- `identity-core` — **modular monolith** (layering DDD), module `auth`/`user`/`IAL`/`admin`.
- `sensitive-data-service (SDS)` — **service cô lập riêng** (own DB, private network, partner-key).
- **workers** — `sensitive-data-worker`, `audit-worker` (qua Kafka).

## Hệ quả
- **Tích cực:** nhanh ra MVP, ít chi phí vận hành; ranh giới module sạch để tách thành microservice khi cần; SDS cô lập đúng nơi cần cô lập.
- **Tiêu cực:** phải kỷ luật giữ ranh giới module trong core; có liên lạc liên-service (core↔SDS).

## Phương án đã cân nhắc
- **Microservices đầy đủ (như O2O):** mạnh nhưng nặng vận hành, chậm MVP.
- **Monolith thuần (cả SDS bên trong):** mất giá trị cô lập PII của SDS.
