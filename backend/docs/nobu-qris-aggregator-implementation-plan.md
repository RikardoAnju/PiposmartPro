# Rencana Implementasi QRIS Nobu untuk Ayocuci

## 1. Ringkasan

Dokumen ini menjadi rencana teknis implementasi QRIS Dynamic Nobu pada backend Ayocuci.

Model bisnis:

```text
Customer laundry
    -> membayar QRIS Dynamic Nobu
Nobu
    -> menerima dan menyalurkan dana ke rekening Ayocuci
Ayocuci
    -> mengonfirmasi order
    -> mencatat kewajiban kepada owner laundry
    -> melakukan settlement kepada owner
```

Ayocuci bertindak sebagai aggregator/platform sesuai pembahasan dengan tim Nobu. Persetujuan tertulis, kontrak, dan kewajiban compliance dari Nobu tetap menjadi prasyarat aktivasi production.

## 2. Tujuan

### Tujuan bisnis

- Customer dapat membayar order laundry melalui QRIS.
- Pembayaran dapat dikonfirmasi otomatis tanpa upload bukti transfer.
- Pembayaran customer masuk ke rekening Ayocuci di Nobu.
- Sistem mencatat nominal bersih yang menjadi hak owner laundry.
- Ayocuci dapat melakukan settlement kepada owner berdasarkan ledger yang dapat diaudit.
- Semua transaksi dapat direkonsiliasi dengan data Nobu.

### Tujuan teknis

- Mengintegrasikan B2B token Nobu.
- Mengimplementasikan RSA signature untuk token request.
- Mengimplementasikan HMAC-SHA512 untuk transaction request.
- Mengimplementasikan Generate QR, Query Payment, dan Payment Notification.
- Menjamin idempotency untuk request dan callback.
- Memisahkan status order, status pembayaran, payable owner, dan settlement.
- Menyediakan UAT tanpa menyentuh production.

## 3. Scope

### Scope MVP

- QRIS Dynamic untuk order laundry.
- Generate QR berdasarkan nominal order.
- QR expiry dan regenerate.
- Callback pembayaran Nobu.
- Query status sebagai fallback.
- Validasi nominal, currency, merchant, dan reference.
- Penyimpanan seluruh reference Nobu.
- Idempotent processing untuk callback ganda.
- Update order menjadi lunas setelah pembayaran tervalidasi.
- Pencatatan payable owner.
- Pencatatan MDR/fee.
- Settlement owner secara manual atau batch approval terlebih dahulu.
- Rekonsiliasi harian.
- Audit log dan monitoring.

### Di luar scope MVP

- QRIS Static.
- Payment Redirect.
- Payment Host-to-Host.
- Apply OTT.
- Refund otomatis.
- Settlement otomatis tanpa approval.
- Pembayaran langsung ke rekening masing-masing owner melalui API Nobu.
- Top up koin customer.

## 4. Kondisi Backend Saat Ini

Backend sudah memiliki:

- Model order pada `ac_transaksi`.
- Detail order pada `ac_detail_transaksi`.
- Histori pembayaran pada `ac_dp_transaksi`.
- Master metode pembayaran pada `ac_metode_pembayaran`.
- Endpoint pembayaran manual pada `/api/v1/transactions/payment`.
- Integrasi callback Midtrans untuk modul lain.
- Multi-outlet melalui `ac_outlet`.

Backend belum memiliki:

- Client Nobu.
- B2B token Nobu.
- RSA/HMAC signature Nobu.
- Generate QRIS Dynamic.
- Callback Nobu.
- Query status Nobu.
- External payment reference.
- Raw callback/audit payload.
- Owner payable ledger.
- Settlement account owner.
- Settlement batch dan settlement item.
- Rekonsiliasi terhadap laporan Nobu.

## 5. Keputusan Arsitektur

### Pembayaran pusat atau per owner

Credential Nobu yang tersedia menunjukkan Ayocuci sebagai partner/merchant. Karena dana masuk ke rekening Ayocuci, credential Nobu disimpan sebagai konfigurasi partner pusat, bukan konfigurasi per outlet.

Data outlet tetap disimpan pada order sebagai `outlet_id` dan pada mapping external store jika Nobu mensyaratkannya.

### Satu pembayaran untuk satu order

Setiap order menghasilkan satu payment order Nobu aktif. Jika QR expired, sistem membuat reference baru yang tetap terhubung ke order yang sama.

Satu order tidak boleh memiliki lebih dari satu pembayaran sukses tanpa proses exception/reversal yang jelas.

### Sumber kebenaran pembayaran

Sumber kebenaran adalah callback/query Nobu yang telah divalidasi, bukan status dari aplikasi customer dan bukan request manual kasir.

Endpoint pembayaran manual tetap digunakan untuk cash/transfer yang sudah ada, tetapi tidak digunakan untuk mengonfirmasi QRIS Nobu.

### Status pembayaran dan settlement dipisahkan

Pembayaran berhasil tidak berarti owner sudah menerima dana.

```text
Payment:  PENDING -> PAID -> REFUNDED/FAILED
Payable:  NOT_CREATED -> OPEN -> RESERVED -> SETTLED
```

## 6. Flow End-to-End

### Membuat order

1. Outlet membuat order laundry seperti biasa.
2. Backend menghitung total final order.
3. Order disimpan dengan status pembayaran belum lunas.
4. Customer memilih QRIS Nobu.
5. Backend membuat payment record internal.

### Generate QR

1. Backend membuat `partnerReferenceNo` maksimal 25 karakter.
2. Backend mengambil token B2B yang masih valid atau meminta token baru.
3. Backend membuat signature HMAC-SHA512.
4. Backend memanggil `POST /v1.2/qr/qr-mpm-generate/`.
5. Backend menyimpan response Nobu.
6. Backend mengembalikan `qrContent`, `qrUrl`, atau `qrImage` ke aplikasi.
7. Aplikasi menampilkan QR dan countdown expiry.

### Customer membayar

Customer scan QR menggunakan aplikasi bank/e-wallet. Ayocuci tidak mengubah order menjadi lunas hanya karena QR berhasil dibuat.

### Callback Nobu

1. Nobu memanggil callback Ayocuci.
2. Backend memvalidasi token callback.
3. Backend memvalidasi signature callback.
4. Backend menyimpan raw request dan header penting.
5. Backend mencari payment berdasarkan `originalPartnerReferenceNo`.
6. Backend memvalidasi merchant, store, nominal, dan currency.
7. Jika `latestTransactionStatus = 00`, payment ditandai paid.
8. Dalam transaksi database yang sama, order ditandai lunas dan owner payable dibuat.
9. Callback dibalas dengan `2005200` sesuai ketentuan Nobu.

### Fallback query

Jika callback belum diterima:

1. Worker atau endpoint internal memproses payment yang masih pending.
2. Query dilakukan dengan backoff, misalnya 5 detik, 15 detik, 30 detik.
3. Query dihentikan setelah status final.
4. Jika transaksi tidak ditemukan, payment masuk status exception untuk pemeriksaan.
5. Polling tidak boleh terus menerus atau membebani API Nobu.

### Membuat payable owner

Contoh:

```text
Nilai order       Rp100.000
MDR Nobu          Rp  1.500
Fee platform      Rp  2.500
Hak owner         Rp 96.000
```

Aturan pembagian fee harus dikonfigurasi dan disetujui bisnis sebelum production. Nilai payable tidak boleh dihitung ulang secara bebas setelah order masuk settlement batch.

### Settlement owner

Tahap awal menggunakan proses batch:

1. Finance memilih periode settlement.
2. Sistem mengambil payable berstatus `OPEN`.
3. Sistem membuat settlement batch.
4. Sistem mengunci item menjadi `RESERVED`.
5. Finance melakukan transfer ke rekening owner.
6. Finance mencatat reference transfer dan bukti.
7. Item menjadi `SETTLED`.
8. Sistem menampilkan laporan settlement kepada owner.

## 7. State Machine

### Payment status

```text
CREATED -> QR_GENERATED -> WAITING_PAYMENT -> PAID
                                      \-> FAILED
                                      \-> EXPIRED
PAID -> REFUNDED
```

Status `PAID` hanya boleh diproses jika:

- Status Nobu adalah `00`.
- Reference cocok.
- Nominal cocok.
- Currency adalah `IDR`.
- Merchant dan store cocok.
- Payment belum pernah diproses sukses.

### Owner payable status

```text
OPEN -> RESERVED -> SETTLED
  \-> HOLD
  \-> REVERSED
```

`HOLD` digunakan untuk dispute, refund, data rekening tidak valid, atau mismatch rekonsiliasi.

## 8. Rancangan Data

### `ac_payment_transactions`

Tabel baru untuk payment provider, bukan menggantikan histori order lama.

Field minimum:

- `id`, `order_id`, `outlet_id`, `provider`, `payment_method`.
- `partner_reference_no`, `nobu_reference_no`, `payment_reference_no`.
- `retrieval_reference_no`, `external_id`.
- `merchant_id`, `sub_merchant_id`, `store_id`, `terminal_id`.
- `amount_value`, `amount_currency`, `nett_amount`, `total_refund`.
- `payer_name`, `payer_phone_number`.
- `qr_content`, `qr_url`, `qr_image`, `qr_expired_at`.
- `provider_status`, `provider_status_desc`, `internal_status`.
- `paid_at`, `last_queried_at`, `failure_code`, `failure_message`.
- `created_at`, `updated_at`.

Constraint penting:

- Unique `(provider, partner_reference_no)`.
- Unique `(provider, payment_reference_no)` jika tersedia.
- Index `order_id`, `internal_status`, `provider_status`, `created_at`.

### `ac_payment_provider_events`

Menyimpan callback dan response untuk audit/idempotency.

Field minimum:

- `id`, `provider`, `event_type`, `external_id`.
- `request_headers`, `request_body`, `signature_valid`.
- `processing_status`, `processing_error`.
- `payment_transaction_id`, `received_at`, `processed_at`.

### `ac_owner_payables`

Menyimpan kewajiban Ayocuci kepada owner.

Field minimum:

- `id`, `outlet_id`, `order_id`, `payment_transaction_id`.
- `gross_amount`, `provider_fee`, `platform_fee`, `adjustment_amount`, `payable_amount`.
- `status`, `settlement_id`.
- `opened_at`, `reserved_at`, `settled_at`, `reversed_at`.
- `created_at`, `updated_at`.

Constraint penting:

- Satu payable aktif untuk satu payment sukses.
- Unique `payment_transaction_id` untuk mencegah payable ganda.

### `ac_owner_settlement_accounts`

Data rekening owner/outlet untuk settlement.

Field minimum:

- `id`, `outlet_id`, `bank_code`, `bank_name`.
- `account_name`, `account_number_encrypted`.
- `verification_status`, `is_default`, `verified_at`.
- `created_at`, `updated_at`.

### `ac_settlements`

Header batch settlement.

Field minimum:

- `id`, `period_start`, `period_end`.
- `total_gross`, `total_fee`, `total_payable`, `item_count`.
- `status`, `created_by`, `approved_by`, `executed_by`, `executed_at`.
- `created_at`, `updated_at`.

### `ac_settlement_items`

Detail payout per owner/payable.

Field minimum:

- `id`, `settlement_id`, `outlet_id`, `payable_id`, `account_id`.
- `amount`, `bank_reference`, `proof_url`, `status`, `failure_reason`, `settled_at`.

## 9. Mapping Data Nobu ke Ayocuci

| Nobu | Ayocuci | Catatan |
|---|---|---|
| `partnerReferenceNo` | `ac_payment_transactions.partner_reference_no` | ID internal maksimal 25 karakter |
| `amount.value` | `amount_value` dan outstanding order | Simpan decimal string sebelum parsing |
| `currency` | `amount_currency` | Harus `IDR` |
| `merchantId` | Konfigurasi partner Nobu | Jangan dari input customer |
| `subMerchantId` | Konfigurasi/mapping Nobu | Tunggu keputusan model merchant |
| `storeId` | Mapping outlet eksternal | Jangan langsung memakai ID internal jika format berbeda |
| `terminalId` | Konfigurasi terminal | Perhatikan versi dokumen terbaru |
| `qrContent` | Payment transaction | Dipakai untuk render QR |
| `qrUrl`/`qrImage` | Payment transaction | Opsional sesuai response |
| `originalReferenceNo` | `nobu_reference_no` | Reference provider |
| `paymentReferenceNo` | `payment_reference_no` | Reference pembayaran |
| `retrievalReferenceNo` | `retrieval_reference_no` | Reference issuer |
| `latestTransactionStatus` | `provider_status` | `00` sukses |
| `nettAmount` | `nett_amount` | Rekonsiliasi dengan settlement Nobu |
| `totalRefund` | `total_refund` | Untuk future refund/reversal |
| `paidTime` | `paid_at` | Simpan timezone |
| callback payload | `ac_payment_provider_events.request_body` | Audit dan debugging |
| payable owner | `ac_owner_payables` | Dibuat saat payment sukses |
| settlement owner | `ac_settlement_items` | Dibuat saat batch settlement |

## 10. Modul Backend yang Diperlukan

### Configuration

Tambahkan environment UAT/production berikut:

```text
NOBU_BASE_URL
NOBU_CLIENT_ID
NOBU_CLIENT_SECRET
NOBU_PARTNER_ID
NOBU_MERCHANT_ID
NOBU_SUB_MERCHANT_ID
NOBU_STORE_ID
NOBU_TERMINAL_ID
NOBU_PRIVATE_KEY_PATH atau NOBU_PRIVATE_KEY
NOBU_CALLBACK_TOKEN
NOBU_TIMEOUT_SECONDS
NOBU_ENVIRONMENT
```

Credential UAT dan production harus terpisah. Jangan commit credential, private key, client secret, atau public key ke repository.

### `NobuClient`

Tanggung jawab:

- HTTP request ke Nobu.
- Timeout dan retry yang aman.
- Generate token request.
- Generate QR.
- Query payment.
- Parsing response.
- Redaction credential dan sensitive data pada log.

### `NobuSignatureService`

Tanggung jawab:

- RSA SHA256 signature untuk request token.
- HMAC-SHA512 signature untuk transaction request.
- Format timestamp WIB/ISO-8601.
- Hash body yang sudah diminify secara konsisten.
- Base64 encoding.
- Unit test menggunakan sample resmi Nobu.

Formula transaksi:

```text
stringToSign = HTTP_METHOD
             + ":" + RELATIVE_PATH
             + ":" + ACCESS_TOKEN
             + ":" + lowercase(hex(sha256(minify(body))))
             + ":" + X_TIMESTAMP

signature = Base64(HMAC-SHA512(clientSecret, stringToSign))
```

### `NobuPaymentService`

Tanggung jawab:

- Membuat payment order.
- Menentukan nominal dari order server-side.
- Memanggil generate QR.
- Menyimpan response.
- Memproses callback.
- Memproses query.
- Menjalankan transition status.
- Membuat payable secara atomik.

### `NobuCallbackController`

Endpoint:

```text
POST /v1.0/qr/qr-mpm-notify/

Legacy alias:

POST /api/v1/callback/nobu/qris
```

Endpoint callback tidak memakai JWT aplikasi customer. Keamanan berasal dari token, signature, allowlist IP bila disepakati, validasi reference, dan validasi payload.

Callback wajib mengembalikan response Nobu:

```json
{
  "responseCode": "2005200",
  "responseMessage": "Request has been processed successfully",
  "additionalInfo": {}
}
```

### `OwnerLedgerService`

Tanggung jawab:

- Membuka payable setelah payment sukses.
- Menghitung gross, MDR, platform fee, dan net payable.
- Menahan payable jika ada exception.
- Mengunci payable saat masuk settlement batch.
- Menandai settled setelah transfer berhasil.
- Mencegah double credit dan double settlement.

## 11. Endpoint Internal Ayocuci

Endpoint yang disarankan:

```text
POST /api/v1/transactions/:id/qris/nobu
GET  /api/v1/transactions/:id/qris/nobu
POST /api/v1/payments/nobu/query
POST /v1.0/qr/qr-mpm-notify/
GET  /api/v1/outlets/:id/payables
GET  /api/v1/outlets/:id/settlements
POST /api/v1/admin/settlements
POST /api/v1/admin/settlements/:id/approve
POST /api/v1/admin/settlements/:id/execute
```

Endpoint generate QR harus:

- Memastikan order milik actor/outlet yang benar.
- Menggunakan nominal order dari database.
- Menolak order yang sudah paid.
- Mengembalikan payment yang masih aktif jika masih valid.
- Membuat payment baru jika QR expired.

## 12. Aturan Idempotency dan Konsistensi

- `X-EXTERNAL-ID` harus unik untuk setiap request ke Nobu dalam hari yang sama.
- `partnerReferenceNo` harus unik per payment order.
- Callback yang sama tidak boleh membuat pembayaran kedua.
- Callback sukses setelah status sudah paid harus dibalas sukses tanpa side effect kedua.
- Callback gagal tidak boleh membuat payable.
- Nominal callback harus sama dengan nominal payment yang dibuat.
- Update order, payment, dan payable harus berada dalam satu database transaction.
- Jika response Nobu timeout setelah request dikirim, jangan langsung generate ulang tanpa query atau pemeriksaan reference.
- Retry hanya untuk timeout/network/5xx, bukan invalid merchant, invalid signature, suspected fraud, atau invalid amount.
- Simpan correlation ID pada semua request dan callback.

## 13. Error Handling

| Nobu | Penanganan Ayocuci |
|---|---|
| `2004700` | QR berhasil dibuat |
| `2005100` + status `00` | Payment sukses |
| `2005100` + status `01` | Tetap pending, query kembali sesuai backoff |
| `2005100` + status `04` | Refunded, tahan/reverse payable |
| `2005100` + status `06` | Failed, jangan buat payable |
| `4045101` | Masuk exception, jangan menandai paid |
| `401xx01` | Refresh token lalu retry terbatas |
| `401xx00` | Stop retry, periksa signature/config |
| `409xx00` / duplicate | Gunakan reference existing, jangan buat transaksi baru sembarangan |
| `4034702` | Tolak nominal dan tampilkan error yang sesuai |
| `4034715` | QR expired, generate QR baru |
| `500xx` / `504xx` | Retry dengan exponential backoff |

## 14. Keamanan

- Simpan client secret dan private key hanya di secret manager/environment server.
- Private key tidak boleh dikirim ke Nobu atau dimasukkan ke repository.
- Public key hanya dikirim melalui mekanisme yang disepakati Nobu.
- Jangan log `Authorization`, `X-SIGNATURE`, client secret, private key, atau full payer data.
- Redact nomor rekening dan nomor telepon pada log.
- Callback harus menggunakan HTTPS.
- Terapkan IP allowlist Nobu jika tersedia di firewall/reverse proxy.
- Validasi timestamp dan toleransi clock skew sesuai kesepakatan Nobu.
- Terapkan rate limit untuk endpoint generate QR dan query.
- Pisahkan secret UAT dan production.
- Pastikan CORS tidak membuka endpoint callback secara tidak perlu.

## 15. Environment dan Deployment

### Development lokal

- Tidak memanggil production Nobu.
- Gunakan mock Nobu client atau recorded response.
- Gunakan test database.
- Uji signature dengan fixture resmi.

### Server development/UAT

- Gunakan Base URL sandbox Nobu.
- Gunakan credential UAT.
- Gunakan IP publik server development yang dikirim ke Nobu untuk whitelist.
- Gunakan callback URL UAT.
- Gunakan database dan rekening yang terpisah dari production.
- Aktifkan fitur dengan feature flag.

### Production

- Aktif setelah UAT ditandatangani/lulus.
- Gunakan credential production.
- Whitelist IP production Nobu.
- Daftarkan callback production.
- Pastikan monitoring, alert, backup, dan rekonsiliasi aktif.
- Deploy dengan migration yang backward-compatible.

## 16. UAT Nobu

Fokus awal adalah sheet Dynamic pada workbook UAT.

### Skenario wajib

- Generate QR sukses.
- Access token invalid.
- Signature invalid.
- Missing mandatory field.
- Invalid field format.
- Duplicate `X-EXTERNAL-ID`.
- Invalid merchant.
- Query transaksi sukses.
- Query transaksi pending.
- Query transaksi tidak ditemukan.
- Callback transaksi sukses.
- Callback transaksi gagal.
- Callback ganda/idempotency.
- QR expired dan regenerate.
- Nominal callback tidak sesuai.
- Callback untuk reference yang tidak dikenal.
- Nobu timeout dan retry.
- Token expired dan refresh.

### Skenario yang dapat ditunda

- Decode QR.
- Payment Redirect.
- Payment Host-to-Host.
- Apply OTT.
- Cancel Payment.
- Refund Payment.
- Static QRIS.

### Bukti UAT

Setiap skenario harus memiliki:

- Request URL.
- Request header yang sudah disensor.
- Request body.
- Response Nobu.
- Response callback Ayocuci.
- Reference internal.
- Reference Nobu.
- Hasil aktual.
- Screenshot QR/payment jika relevan.
- Catatan dan tindak lanjut.

## 17. Rekonsiliasi

Rekonsiliasi membandingkan tiga sumber:

1. Order Ayocuci.
2. Payment transaction Nobu.
3. Mutasi/settlement rekening Ayocuci dari Nobu.

Minimal laporan:

- Payment Ayocuci tanpa callback.
- Callback Nobu tanpa order.
- Nominal berbeda.
- Payment sukses tanpa payable.
- Payable tanpa payment sukses.
- Payable sudah settled tetapi transfer gagal.
- MDR berbeda.
- Payment sukses tetapi tidak muncul pada mutasi rekening.

Status rekonsiliasi: `MATCHED`, `MISMATCH`, atau `MANUAL_REVIEW`.

## 18. Observability

Metric minimum:

- Jumlah generate QR sukses/gagal.
- Persentase callback sukses.
- Callback signature invalid.
- Payment pending lebih dari batas waktu.
- Query fallback count.
- Payment sukses.
- Payment gagal/expired.
- Payable open.
- Settlement failed.
- Nilai mismatch rekonsiliasi.

Alert minimum:

- Callback error meningkat.
- Signature invalid berulang.
- Token gagal dibuat.
- Payment pending terlalu lama.
- Settlement batch gagal.
- Selisih rekonsiliasi non-zero.

## 19. Testing Teknis

### Unit test

- RSA signature token.
- HMAC signature transaction.
- Body minification dan SHA-256.
- Timestamp formatting.
- Amount formatting dua desimal.
- Status mapping Nobu.
- Fee calculation.
- Idempotency callback.
- Payable calculation.

### Integration test

- Mock generate QR.
- Mock query success/pending/failed/not found.
- Mock callback success/failed/duplicate.
- Token refresh.
- Timeout and retry.
- Invalid signature.
- Database transaction rollback.

### End-to-end test

- Create order.
- Generate QR.
- Simulate/payment UAT.
- Receive callback.
- Verify order paid.
- Verify payment record.
- Verify payable owner.
- Create settlement batch.
- Verify item settled.

## 20. Rollout Plan

### Phase 0 - Klarifikasi dan readiness

- Konfirmasi tertulis model aggregator dengan Nobu.
- Konfirmasi merchant/sub-merchant/store mapping.
- Konfirmasi MDR, fee, settlement, refund, dan dispute.
- Konfirmasi callback URL dan IP whitelist.
- Konfirmasi dokumen KYC/compliance owner.

### Phase 1 - Fondasi backend

- Tambah config.
- Tambah model dan migration.
- Tambah signature service.
- Tambah Nobu HTTP client.
- Tambah unit test cryptographic.

### Phase 2 - Pembayaran QRIS Dynamic

- Generate QR.
- Payment detail endpoint.
- Callback Nobu.
- Query fallback.
- Idempotency.
- Order payment transition.

### Phase 3 - Ledger dan settlement

- Owner payable.
- Rekening settlement owner.
- Settlement batch.
- Approval dan execute manual.
- Laporan payable/settlement.

### Phase 4 - UAT

- Deploy ke server UAT.
- Whitelist IP.
- Jalankan skenario workbook.
- Perbaiki temuan.
- Dokumentasikan hasil dan sign-off.

### Phase 5 - Production

- Migrate database production.
- Inject production secrets.
- Whitelist IP production.
- Smoke test nominal kecil sesuai arahan Nobu.
- Enable feature flag bertahap.
- Monitor intensif pada periode awal.

## 21. Acceptance Criteria

Implementasi siap UAT jika:

- Generate QR Dynamic berhasil menggunakan credential UAT.
- QR dapat ditampilkan dan memiliki expiry.
- Token RSA dan signature HMAC lulus fixture Nobu.
- Callback dapat diterima pada URL publik.
- Callback signature tervalidasi.
- Pembayaran sukses mengubah order menjadi lunas satu kali saja.
- Callback ganda tidak menambah pembayaran/payable.
- Pembayaran gagal tidak membuat payable.
- Query fallback berhenti saat status final.
- Nominal mismatch masuk manual review.
- Semua reference Nobu tersimpan.
- Owner payable terbentuk secara atomik.
- Settlement batch dapat dibuat tanpa mengubah data payment.
- Test UAT Dynamic terisi.
- Tidak ada secret di source code atau log.

Implementasi siap production jika:

- UAT Nobu disetujui.
- Model bisnis dan settlement disetujui tertulis.
- Rekonsiliasi sudah diuji.
- Runbook operasional tersedia.
- Monitoring dan alert aktif.
- Backup dan rollback migration tersedia.
- Credential production dan whitelist IP siap.

## 22. Runbook Operasional

### Payment pending

1. Cari payment berdasarkan `partner_reference_no`.
2. Periksa callback event.
3. Jalankan query sesuai batas retry.
4. Cocokkan nominal dan reference.
5. Jika tetap tidak jelas, tandai `MANUAL_REVIEW`.

### Callback gagal diproses

1. Simpan event dan error.
2. Periksa signature, reference, dan nominal.
3. Reprocess secara aman setelah penyebab diperbaiki.

### Settlement mismatch

1. Hentikan item mismatch dari batch berikutnya.
2. Cocokkan order, payment, payable, dan mutasi rekening.
3. Buat adjustment dengan audit trail.
4. Jangan mengedit nominal historis tanpa adjustment entry.

## 23. Open Decisions

Keputusan berikut perlu dikunci sebelum implementasi settlement selesai:

- Apakah setiap owner adalah sub-merchant Nobu atau hanya beneficiary settlement internal.
- Apakah `storeId` satu untuk Ayocuci atau berbeda per outlet.
- Apakah `subMerchantId` diisi pada generate/query/callback.
- Siapa yang menanggung MDR.
- Formula fee platform Ayocuci.
- Frekuensi settlement owner.
- Minimum settlement dan cut-off time.
- Prosedur refund/dispute.
- Dokumen KYC dan verifikasi rekening owner.
- Apakah settlement dilakukan manual, upload bank transfer, atau memakai API bank.
- Retensi raw callback dan data payer.

## 24. Referensi

- Nobu API QRIS MPM Documentation v1.4.5.
- Nobu Credential Documentation UAT Ayocuci.
- Nobu Signature and Key Guidance v2.4.
- Workbook Skenario dan Hasil Uji Fungsionalitas UAT QR MPM Acquirer.
- Backend Ayocuci pada `AyoCuci_API/internal`.

Dokumen ini tidak menyimpan credential, client secret, private key, atau nilai sensitif dari dokumen UAT.
