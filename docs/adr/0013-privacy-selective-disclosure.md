# ADR-0013: Privacy & Selective Disclosure (mô hình tập trung)

**Tác giả:** Thành Lê Phước

- **Trạng thái:** Accepted
- **Ngày:** 2026-06-08
- **Bổ sung bởi:** [ADR-0014](0014-du-an-nha-nuoc-cong-an.md) — chữ ký/PKI cho SD-JWT/chữ ký số theo **CA quốc gia (NEAC)/Ban Cơ yếu**; dữ liệu & hạ tầng trong nước.

## Bối cảnh
Bài toán "**chứng minh tính đúng mà không lộ dữ liệu gốc**" (vd chứng minh ≥18 tuổi mà không lộ ngày sinh). Sản phẩm tham chiếu **NDA Key** giải bằng **ZKP/VC/SSI** (phi tập trung — người dùng tự giữ & tự chứng minh). Dự án ta đã chốt **mô hình tập trung kiểu UAE PASS** (ADR-0001), nơi IdP là bên được tin. Cần định vị rõ **cách giải quyết riêng tư/tiết lộ tối thiểu trong mô hình tập trung**, và lộ trình tới ZKP/VC.

## Quyết định
Trong mô hình tập trung, giải bằng **"IdP là bên chứng thực (attester) + tiết lộ tối thiểu"**, KHÔNG dùng ZKP cho MVP. "Bằng chứng" gửi cho RP là **token JWT chứa claim dẫn vị, ký bằng ES256** (verify qua JWKS — ADR-0005); dữ liệu gốc không bao giờ rời SDS.

Bốn cơ chế xếp lớp:
1. **Claim dẫn xuất / predicate** — IdP tính sẵn vị từ từ PII (trong SDS) rồi ký phát ra **kết luận tối thiểu** thay vì dữ liệu gốc: `age_over_18`, `verified`, `ial`, `resident_province`… (thay cho ngày sinh / CCCD / địa chỉ).
2. **Scope + Consent** — mỗi RP/client đăng ký sẵn `scopes[]`; RP chỉ nhận claim trong scope được cấp; **mặc định tối thiểu**; consent hiển thị đúng thứ chia sẻ.
3. **Pairwise subject (PPID)** — `subject_type: pairwise`: mỗi RP nhận một `sub` khác cho cùng người → **chống RP đối chiếu/liên kết** người dùng (câu trả lời tập trung cho tính unlinkable).
4. **PII cô lập ở SDS + RBAC + Audit** — identity-core chỉ giữ **vị từ dẫn xuất (non-PII)** + `kyc_id`; truy cập PII gốc phải qua SDS (partner-key + RBAC theo `kyc_id`) và **ghi audit mọi lần**.

**Thiết kế dữ liệu:** lưu vị từ dẫn xuất (`age_over_18`, `is_resident_vn`, `ial`…) ở identity-core **tại thời điểm eKYC** (core luôn sạch PII); dữ liệu gốc chỉ ở SDS mã hóa.

**Lộ trình:** MVP = (1)+(2)+(3)+(4); **near-term = SD-JWT** (selective disclosure khớp stack JWT/OIDC) + thêm vị từ; **roadmap = ZKP/VC/SSI** (khi đi hướng ví số/phi tập trung, để giấu cả khỏi trung tâm).

## Hệ quả
- **Tích cực:** RP **không bao giờ thấy PII gốc**, chỉ nhận kết luận tối thiểu đã ký; tối thiểu hóa dữ liệu (NĐ13/2023); pairwise `sub` chống tương quan; dùng **chuẩn OIDC sẵn có**, không cần crypto phức tạp; identity-core giữ được "sạch PII".
- **Tiêu cực:** **không giấu khỏi chính IdP** — ranh giới riêng tư là **IdP↔RP**, không phải user↔IdP (muốn giấu khỏi trung tâm phải lên ZKP/VC = roadmap, không nhỏ); cần kỷ luật scope/consent + audit; vị từ precompute có thể **lỗi thời** (vd vừa tròn 18 sau ngày tính) → cần chiến lược refresh/tính realtime cho vị từ nhạy thời gian.

## Phương án đã cân nhắc
- **ZKP/VC/SSI ngay (như NDA Key):** riêng tư mạnh nhất (giấu cả khỏi trung tâm) nhưng phức tạp, chi phí proving, tooling chưa chín đều, và **mâu thuẫn mô hình tập trung đã chọn** (ADR-0001) — đưa vào roadmap.
- **Gửi PII gốc cho RP rồi RP tự lọc:** vi phạm tối thiểu hóa, lộ PII không cần thiết — loại.
- **Opaque token + introspection từng claim:** đã loại ở ADR-0005 (IdP thành nút thắt).
