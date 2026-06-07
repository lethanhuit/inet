# ADR-0011: Triển khai Docker→K8s + Envoy + OpenTelemetry/SigNoz

- **Trạng thái:** Accepted
- **Ngày:** 2026-06-07

## Bối cảnh
Cần chiến lược triển khai, gateway, quan sát — bám house O2O nhưng giữ MVP gọn.

## Quyết định
- **Đóng gói Docker → chạy K8s**; **Envoy** làm gateway (gRPC nội bộ + REST ngoài).
- **Service stateless** → N replica sau load balancer; state ra Redis (Sentinel).
- **Observability: OpenTelemetry → SigNoz** (trace/log/APM) + metrics Prometheus.
- **CI/CD staged:** dev → qc → staging → prelive → live group → live all + rollback (theo house).
- **DR:** backup + PITR; master-key backup + job re-encrypt; đa DC/GEO để **roadmap**.

## Hệ quả
- **Tích cực:** scale ngang, nhất quán house, vận hành/quan sát chuẩn.
- **Tiêu cực:** K8s + Envoy là chi phí vận hành; với MVP nhỏ có thể chạy Docker đơn giản trước rồi lên K8s (autoscale/đa-DC để hoãn).

## Phương án đã cân nhắc
- **Chỉ Docker/VM, không K8s:** đơn giản hơn nhưng lệch house + khó scale/triển khai chuẩn.
- **Autoscale + đa DC ngay:** thừa cho MVP — hoãn.
