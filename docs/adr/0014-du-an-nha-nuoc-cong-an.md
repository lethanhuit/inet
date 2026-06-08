# ADR-0014: Dự án nhà nước & công an — ràng buộc chủ quyền và tuân thủ công nghệ

**Tác giả:** Thành Lê Phước

- **Trạng thái:** Accepted
- **Ngày:** 2026-06-08
- **Loại:** ADR bối cảnh/ràng buộc (chi phối & yêu cầu xem xét lại các ADR khác)

> ⚠️ Một số tham chiếu pháp lý/cấp độ nêu dưới đây cần **xác nhận với cơ quan chủ quản** theo phân loại cụ thể của hệ thống. ADR này đặt *định hướng ràng buộc*, không thay cho thẩm định pháp lý/an ninh chính thức.

## Bối cảnh
Đây là nền tảng định danh phục vụ **nhà nước và Bộ Công an** — định danh công dân quy mô quốc gia, gắn **VNeID / Cơ sở dữ liệu quốc gia về dân cư**, theo định hướng **Đề án 06**. Khác hẳn một SaaS thương mại, hệ chịu **khung pháp lý + an ninh quốc gia + chủ quyền dữ liệu** của Việt Nam. Nhiều lựa chọn ở các ADR trước được đặt trên giả định SaaS/house O2O (có dùng dịch vụ cloud nước ngoài: Cloudflare/R2/S3) nên **phải được cân nhắc lại**.

## Quyết định
Áp dụng **tư thế "cấp nhà nước" (government-grade posture)** làm ràng buộc xuyên suốt; mọi ADR khác phải được đánh giá lại theo 8 nguyên tắc:

1. **Chủ quyền & lưu trú dữ liệu trong nước.** Toàn bộ dữ liệu (PII, audit, khóa, log) lưu & xử lý **trong lãnh thổ VN**; tuân **Luật An ninh mạng 2018 + NĐ53/2022** (nội địa hóa dữ liệu), **NĐ13/2023** (bảo vệ DLCN), **Luật Căn cước 2023**. → **Không** dùng cloud/dịch vụ quản lý đặt ở nước ngoài cho dữ liệu nhà nước.
2. **Hạ tầng trong nước / on-prem.** Triển khai trên **cloud chính phủ / trung tâm dữ liệu nhà nước / cloud nội địa** (Viettel/VNPT/FPT/CMC…) thay cho Cloudflare/AWS/R2. → **điều chỉnh ADR-0011** (đổi object storage R2/S3 + CDN nước ngoài sang lưu trữ & CDN trong nước/on-prem; K8s/Envoy/SigNoz giữ nguyên vì tự-host được).
3. **Tích hợp nguồn quốc gia là bắt buộc.** **VNeID + CSDL quốc gia về dân cư (C06)** là nguồn định danh chính thống; tích hợp phải qua **phê duyệt/cấp phép cơ quan chủ quản** → nâng **ADR-0012** từ "khuyến nghị" thành **bắt buộc, có ràng buộc cấp phép**.
4. **Mật mã & quản lý khóa cấp nhà nước.** Giữ chuẩn quốc tế đã chọn (AES-256-GCM, ES256 — ADR-0004/0005) cho lớp ứng dụng, **nhưng** MASTER_KEY/HSM phải **đặt trong nước, dưới quyền kiểm soát của cơ quan**; tùy độ mật do cơ quan phân loại, có thể **yêu cầu mật mã/chữ ký số chuyên dùng của Ban Cơ yếu Chính phủ** (Luật Cơ yếu 2011).
5. **PKI & chữ ký số theo CA quốc gia.** Chữ ký số (roadmap) phải chuỗi tin cậy tới **RootCA quốc gia (NEAC, Bộ TT&TT)** hoặc **PKI chuyên dùng Chính phủ (Ban Cơ yếu)**; **không** tự làm CA, **không** dựa CA nước ngoài. → ràng buộc cho ADR-0005/0013 + ADR chữ ký số roadmap.
6. **An toàn HTTT theo cấp độ.** Phân loại & bảo vệ theo **NĐ85/2016 + TT03/2017 + TCVN 11930**; hệ định danh dân cư nhiều khả năng **cấp độ 4–5** (cao) → kiểm thử/kiểm định, giám sát **SOC**, kiểm toán độc lập, ứng cứu sự cố. *(Cấp độ cụ thể cần xác nhận với cơ quan chủ quản.)*
7. **Chủ quyền chuỗi cung ứng & khả năng kiểm toán.** Ưu tiên **OSS tự-host, kiểm toán được** (Postgres/Redis/Kafka/SigNoz/OTel — vốn đã chọn, **phù hợp sẵn**); tránh SaaS/telemetry nước ngoài; rà soát & ghim phụ thuộc (supply chain); mã nguồn sẵn sàng để cơ quan an ninh thẩm định.
8. **Lưu vết & truy nguyên cấp pháp lý.** Audit bất biến, thời hạn lưu trữ theo quy định, sẵn sàng phục vụ điều tra/giám sát hợp pháp; non-repudiation.

## Hệ quả
- **Tích cực:** phù hợp pháp lý & an ninh quốc gia; bảo đảm chủ quyền dữ liệu; **phần lớn stack OSS đã chọn (Postgres/Redis/Kafka/SigNoz/OTel) vốn tự-host nên đã đúng hướng**; tăng độ tin cậy thể chế.
- **Tiêu cực:** phải **thay dịch vụ cloud nước ngoài** (Cloudflare/R2/S3) → chi phí & đổi nhà cung cấp; ràng buộc cấp phép VNeID/CSDL dân cư có thể **chậm, nhiều thủ tục**; cấp độ ATTT cao → tăng chi phí kiểm định/SOC/vận hành; có thể phát sinh **mật mã chuyên dùng (Ban Cơ yếu)** làm phức tạp lớp khóa; lệ thuộc tiến độ/chính sách cơ quan nhà nước.
- **Cần xem xét lại các ADR:** **0011** (hạ tầng/cloud → trong nước/on-prem), **0004** (custody khóa/HSM, khả năng Ban Cơ yếu), **0005·0013 + chữ ký số roadmap** (PKI/CA quốc gia), **0012** (VNeID bắt buộc + cấp phép). Cập nhật **bản đồ §7** + `quyet-dinh-cong-nghe-tradeoff.md` (dòng object storage R2/S3 → nội địa).

## Phương án đã cân nhắc
- **Giữ nguyên stack SaaS (cloud nước ngoài, không phân cấp độ):** nhanh/rẻ nhưng **vi phạm chủ quyền dữ liệu & quy định** — loại với dự án nhà nước.
- **Coi như dự án thương mại, "tuân thủ sau":** rủi ro phải làm lại kiến trúc khi thẩm định an ninh — loại; đặt ràng buộc ngay từ đầu rẻ hơn nhiều.
