# ADR-0008: Kafka cho messaging / event bus

**Tác giả:** Thành Lê Phước

- **Trạng thái:** Accepted
- **Ngày:** 2026-06-07

## Bối cảnh
Cần messaging cho: audit fan-out, encrypted event payload, eKYC async, retry/DLQ. Đã cân nhắc NATS JetStream (nhẹ, Go-native), Postgres-queue (River), Redpanda/WarpStream (Kafka-API). Yếu tố quyết định: **Kafka đã được chứng minh bền vững** và **house O2O đã vận hành Kafka + team có expertise**.

## Quyết định
Dùng **Kafka** làm event bus/messaging — nhất quán house, proven, đội đã quen. Đảm bảo đúng-đắn (không mất/trùng sự kiện audit/eKYC) bằng **transactional outbox** (ghi event vào bảng outbox cùng transaction nghiệp vụ; relay/CDC đẩy sang Kafka — house dùng Debezium).

## Hệ quả
- **Tích cực:** proven & bền vững; tái dùng hạ tầng + expertise sẵn có; hệ sinh thái sâu (Connect, CDC, schema registry) cho tương lai.
- **Tiêu cực:** ops nặng (partition, rebalancing, KRaft/JVM); cần outbox để tránh mất sự kiện; hơi thừa so với tải MVP.

## Phương án đã cân nhắc
- **NATS JetStream:** nhẹ, Go-native, ops thấp — nhưng **không đáng thêm công nghệ mới khi đã có Kafka proven + house**.
- **Postgres-queue (River):** transactional, zero hạ tầng mới — có thể bổ trợ cho job đơn giản, nhưng quyết định chính giữ Kafka.
- **Redpanda/WarpStream (Kafka-API):** để dành nếu sau này muốn ops nhẹ mà giữ Kafka API.
