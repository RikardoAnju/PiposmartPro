# AyoCuci iOS IAP + Addon Lock Migration Plan

Dokumen ini adalah acuan kerja tunggal untuk migrasi monetisasi AyoCuci ke model:

- iOS top up koin memakai Apple In-App Purchase
- Android top up koin tetap memakai flow existing
- Addon hanya bisa dibeli memakai koin
- Pembayaran addon via transfer manual dan Midtrans dihentikan total
- Aktivasi outlet PRO di iOS memakai Apple In-App Purchase
- Fitur premium dikunci dari backend dan UI berdasarkan addon aktif / status PRO outlet

Dokumen ini sengaja dibuat langsung eksekusi-oriented. Setelah ini tidak perlu bikin dokumen turunan lagi.

## 1. Keputusan Produk

### 1.1 Top up koin

- iOS:
  - user membeli paket koin via Apple IAP
  - app mengirim bukti pembelian ke backend
  - backend verifikasi ke Apple
  - backend menambahkan saldo koin ke outlet yang dipilih
- Android:
  - flow top up koin existing tetap dipakai

### 1.2 Addon

- semua addon eceran hanya bisa dibeli memakai koin
- flow `TRANSFER`, `MIDTRANS`, upload bukti, dan pending order untuk addon dihentikan total
- aktivasi addon terjadi instan setelah saldo koin berhasil dipotong

### 1.3 Aktivasi outlet PRO

- iOS:
  - aktivasi PRO memakai Apple IAP
  - karena 1 owner bisa punya lebih dari 1 outlet, pembelian PRO harus dimapping ke `outlet_id` yang dipilih saat checkout
- Android:
  - sementara tetap boleh memakai flow existing sampai nanti diseragamkan

### 1.4 Penguncian fitur premium

- backend menjadi source of truth
- Flutter hanya menampilkan status dan guard UX
- semua screen premium tetap harus aman walau diakses lewat deep link, state lama, atau request manual

## 2. Kondisi Sistem Saat Ini

### 2.1 Backend addon

Sudah ada:

- katalog addon di `ac_addons`
- histori addon aktif di `ac_history_addons`
- transaksi addon di `ac_transaksi_addons`
- detail transaksi addon di `ac_detail_transaksi_addons`
- middleware pengunci addon `RequireAddon(...)`
- `CheckFeatureAccess(...)` di `AddonService`

Masalah saat ini:

- route premium belum semua memakai `RequireAddon(...)`
- addon masih mendukung flow `TRANSFER` / `MIDTRANS`
- top up koin belum punya jalur iOS IAP
- aktivasi PRO belum punya jalur iOS IAP dengan mapping outlet yang aman

### 2.2 Flutter app

Sudah ada:

- halaman top up koin existing
- halaman aktivasi akun / addon / PRO existing
- provider addon, provider koin, provider outlet

Belum ada:

- dependency dan service `in_app_purchase`
- flow verifikasi purchase iOS ke backend
- state restore purchase iOS
- UX khusus iOS untuk top up koin dan PRO

## 3. Arsitektur Target

## 3.1 Monetisasi

- `Koin`:
  - iOS: dibeli via Apple IAP
  - Android: existing
- `Addon`:
  - dibeli via koin internal saja
- `PRO outlet`:
  - iOS: dibeli via Apple IAP
  - Android: existing dulu

## 3.2 Sumber kebenaran

- Apple Store hanya sumber bukti pembelian
- backend AyoCuci adalah sumber kebenaran final untuk:
  - kredit koin
  - aktivasi PRO
  - histori transaksi internal
  - anti double processing
  - mapping pembelian ke outlet

## 4. Perubahan Data / Tabel

Tambahkan tabel baru untuk menyimpan transaksi store iOS.

## 4.1 Tabel baru `ac_store_transactions`

Tujuan:

- simpan semua transaksi Apple IAP yang masuk
- cegah double grant
- simpan mapping pembelian ke owner dan outlet
- bantu restore / audit / investigasi refund

Kolom yang disarankan:

- `st_id` string primary key
- `st_platform` enum/string
  - `IOS`
- `st_store` enum/string
  - `APP_STORE`
- `st_product_id` string
- `st_product_type` string
  - `COIN`
  - `OUTLET_PRO`
- `st_transaction_id` string unique
- `st_original_transaction_id` string nullable
- `st_owner_user_id` string
- `st_outlet_id` string nullable
- `st_purchase_token` text nullable
- `st_receipt_payload` longtext/text nullable
- `st_status` string
  - `RECEIVED`
  - `VERIFIED`
  - `GRANTED`
  - `REJECTED`
  - `REFUNDED`
- `st_grant_status` string
  - `PENDING`
  - `DONE`
  - `FAILED`
- `st_coin_amount` int default 0
- `st_pro_activated` tinyint default 0
- `st_environment` string
  - `Sandbox`
  - `Production`
- `st_verified_at` datetime nullable
- `st_granted_at` datetime nullable
- `st_created` datetime
- `st_lastupdate` datetime nullable

Index penting:

- unique `st_transaction_id`
- index `st_owner_user_id`
- index `st_outlet_id`
- index `st_product_id`
- index `st_status`

## 4.2 Opsional: tabel mapping produk store

Kalau ingin fleksibel, tambahkan tabel master:

- `ac_store_products`

Kolom:

- `sp_product_id`
- `sp_platform`
- `sp_type`
- `sp_coin_amount`
- `sp_target_code`
- `sp_status`

Kalau tidak mau tambah tabel baru, mapping bisa di-hardcode dulu di backend config.

Rekomendasi:

- fase 1: mapping hardcode di backend config/service
- fase 2: jika produk makin banyak, pindah ke tabel

## 4.3 Tabel existing yang dipakai

- `ac_transaksi_addons`
  - tetap dipakai untuk histori addon dan aktivasi PRO internal
- `ac_detail_transaksi_addons`
  - tetap dipakai untuk detail item addon / PRO existing
- `ac_history_addons`
  - tetap dipakai untuk fitur aktif
- `ac_outlet`
  - tetap menyimpan status PRO outlet

## 5. Perubahan Endpoint Backend

## 5.1 Endpoint baru iOS IAP

Tambahkan group baru, misalnya:

- `POST /v1/iap/ios/verify-coin-topup`
- `POST /v1/iap/ios/verify-outlet-pro`
- `GET /v1/iap/ios/products`
- `POST /v1/iap/ios/restore`

Payload minimal verify:

```json
{
  "product_id": "coin_100",
  "transaction_id": "1000001234567890",
  "original_transaction_id": "1000001234567890",
  "receipt_data": "base64-or-jws-payload",
  "outlet_id": "OT-XXXX",
  "environment_hint": "Sandbox"
}
```

Catatan:

- `outlet_id` wajib untuk top up koin dan PRO
- untuk owner multi-outlet, grant hanya boleh terjadi ke outlet yang dikirim saat checkout

## 5.2 Endpoint addon existing yang diubah

Endpoint existing:

- `POST /v1/addons/buy-koin`
- `POST /v1/addons/request`
- `POST /v1/addons/upload-bukti`
- `POST /v1/addons/cancel-order`

Target akhir:

- `buy-koin` tetap dipakai untuk pembelian addon
- `request` dinonaktifkan untuk addon eceran
- `upload-bukti` tidak dipakai lagi untuk addon
- `cancel-order` tidak dipakai lagi untuk addon eceran non-koin

Strategi implementasi:

### opsi aman fase transisi

- `POST /v1/addons/request`
  - return `400` dengan pesan bahwa pembayaran addon hanya bisa memakai koin
- `POST /v1/addons/upload-bukti`
  - return `410` / `400` untuk transaksi addon baru

### opsi bersih fase final

- hapus akses UI ke flow ini
- backend tetap sisakan handler sementara untuk histori lama

## 5.3 Endpoint PRO existing

Endpoint existing:

- `POST /v1/addons/activate-outlet`

Target:

- Android tetap boleh pakai endpoint existing
- iOS tidak lagi membuat invoice transfer / Midtrans untuk PRO
- iOS memakai endpoint baru `verify-outlet-pro`

## 5.4 Endpoint premium reports

Pastikan route berikut memakai `RequireAddon(...)`:

- `REPORT_DEBT`
- `REPORT_PROFIT_LOSS`
- `REPORT_SERVICE_SUMMARY`
- `REPORT_CUSTOMER_DETAIL`

Audit juga screen / endpoint lain yang sebenarnya premium.

## 6. Validasi Backend yang Wajib

## 6.1 Validasi transaksi store

Saat backend menerima purchase iOS:

1. cek auth user
2. cek `outlet_id` benar milik owner / actor yang sedang login
3. cek `transaction_id` belum pernah diproses
4. verifikasi receipt / JWS ke Apple
5. cek `product_id` valid dan sesuai jenis produk
6. cek environment sandbox / production
7. simpan ke `ac_store_transactions`
8. grant benefit di dalam DB transaction

## 6.2 Validasi top up koin

- `product_id` harus mapping ke nominal koin yang valid
- kredit koin hanya sekali per `transaction_id`
- histori mutasi koin harus tercatat

## 6.3 Validasi outlet PRO

- `outlet_id` wajib
- owner login harus punya akses ke outlet tersebut
- outlet belum PRO
- `transaction_id` belum pernah dipakai
- setelah valid:
  - aktifkan PRO outlet itu saja
  - catat transaksi internal

## 6.4 Validasi addon koin-only

Untuk `POST /addons/buy-koin`:

- addon ID valid
- jika `EXTRA_STAFF`, `target_id` wajib
- saldo koin cukup
- target pegawai milik outlet yang sama
- jika addon report global, cukup outlet-level
- jika addon target-based, validasi `target_id`

## 7. Flow iOS Purchase End-to-End

## 7.1 Flow top up koin iOS

1. user membuka screen top up koin
2. Flutter iOS memuat daftar produk IAP dari App Store
3. user memilih paket koin
4. user memilih outlet tujuan top up
5. app memulai purchase Apple
6. Apple mengembalikan purchase result
7. app mengirim proof purchase + `outlet_id` ke backend
8. backend verifikasi ke Apple
9. backend menyimpan transaksi store
10. backend menambah saldo koin outlet
11. backend mengembalikan status sukses
12. app refresh saldo koin dan histori

## 7.2 Flow aktivasi PRO iOS

1. user membuka screen aktivasi PRO
2. app menampilkan outlet yang akan diaktifkan
3. user konfirmasi outlet target
4. app memulai purchase Apple untuk produk PRO
5. app mengirim proof purchase + `outlet_id` ke backend
6. backend verifikasi ke Apple
7. backend memastikan outlet target belum PRO
8. backend mengaktifkan PRO pada outlet itu
9. backend menyimpan histori store + histori internal
10. app refresh profile outlet

## 7.3 Flow pembelian addon dengan koin

1. user membuka screen addon
2. app load katalog addon + status aktif + saldo koin
3. user memilih addon
4. app hanya menawarkan metode bayar koin
5. app memanggil `POST /addons/buy-koin`
6. backend memotong koin
7. backend mengaktifkan addon
8. app refresh active addons + saldo koin

## 8. Penguncian Fitur Premium

## 8.1 Backend lock

Semua endpoint premium harus memakai:

- permission role
- addon lock bila feature eceran

Pattern:

```go
finance.GET(
  "/report-profit-loss",
  middleware.AuthPermission("laporan", "read_profit_loss"),
  middleware.RequireAddon("REPORT_PROFIT_LOSS", addonSvc),
  ctrl.GetProfitLossReport,
)
```

## 8.2 Flutter lock

Flutter hanya untuk UX:

- sembunyikan menu premium jika belum aktif
- tampilkan badge premium / terkunci
- saat API balas `ADDON_REQUIRED`, arahkan user ke halaman pembelian addon

Screen yang minimal harus diaudit:

- laba rugi
- piutang
- ringkasan per layanan
- detail laporan pelanggan

## 9. Perubahan Flutter App

## 9.1 Dependency baru

Tambahkan package:

- `in_app_purchase`

Opsional:

- helper untuk receipt parsing / restore management jika dibutuhkan

## 9.2 Service / provider baru

Tambahkan:

- `IapProvider` atau `IosIapProvider`
- `IapService`

Tanggung jawab:

- load products
- start purchase
- observe purchase stream
- kirim purchase proof ke backend
- handle success / pending / error / restore

## 9.3 Perilaku per platform

### iOS

- screen top up koin:
  - tampilkan produk IAP Apple
  - wajib pilih outlet tujuan top up
- screen addon:
  - hanya bayar pakai koin
- screen aktivasi PRO:
  - tampilkan produk IAP PRO
  - wajib pilih outlet target

### Android

- top up koin tetap existing
- addon hanya koin-only
- PRO sementara tetap existing

## 9.4 UX penting

- tampilkan outlet target dengan jelas sebelum purchase PRO
- tampilkan outlet target dengan jelas sebelum top up koin
- jika purchase sukses tapi verifikasi backend gagal, tampilkan status pending help
- support restore purchase iOS untuk kasus client retry

## 10. Perubahan Backend Service

Tambahkan service baru:

- `IapService`

Tanggung jawab:

- verifikasi transaksi Apple
- mapping product ke action internal
- idempotent grant
- simpan `ac_store_transactions`

Method yang dibutuhkan:

- `VerifyIosCoinTopup(...)`
- `VerifyIosOutletPro(...)`
- `RestoreIosPurchases(...)`
- `MapAppleProduct(...)`
- `RecordStoreTransaction(...)`

Tambahkan repository / helper:

- Apple verifier client
- config product map

## 11. File yang Perlu Disentuh Dulu

## 11.1 Backend Go

File existing yang hampir pasti disentuh:

- `AyoCuci_API/internal/route/v1/addon_route.go`
- `AyoCuci_API/internal/route/v1/finance_route.go`
- `AyoCuci_API/internal/route/v1/routes.go`
- `AyoCuci_API/internal/controller/addon_controller.go`
- `AyoCuci_API/internal/service/addon_service.go`
- `AyoCuci_API/internal/database/mysql.go`
- `AyoCuci_API/internal/model/addon_transaksi.go`

File baru yang kemungkinan dibuat:

- `AyoCuci_API/internal/model/store_transaction.go`
- `AyoCuci_API/internal/controller/iap_controller.go`
- `AyoCuci_API/internal/service/iap_service.go`
- `AyoCuci_API/internal/route/v1/iap_route.go`
- `AyoCuci_API/internal/thirdparty/apple/verify_client.go`

Migration / docs:

- update `AyoCuci_API/docs/schema.sql`
- tambah migration SQL untuk `ac_store_transactions`

## 11.2 Flutter

File existing yang hampir pasti disentuh:

- `AyoCuci_Apps/pubspec.yaml`
- `AyoCuci_Apps/lib/app_providers.dart`
- `AyoCuci_Apps/lib/screens/settings/koin/topup_koin_screen.dart`
- `AyoCuci_Apps/lib/screens/settings/aktivasi/aktivasi_akun_screen.dart`
- `AyoCuci_Apps/lib/screens/settings/aktivasi/checkout_aktivasi_screen.dart`
- `AyoCuci_Apps/lib/screens/settings/aktivasi/ringkasan_pesanan_screen.dart`
- `AyoCuci_Apps/lib/providers/addon_provider.dart`
- `AyoCuci_Apps/lib/providers/koin_provider.dart`
- `AyoCuci_Apps/lib/providers/app_provider.dart`
- `AyoCuci_Apps/lib/shared/widgets/report_access_placeholder.dart`

File baru yang kemungkinan dibuat:

- `AyoCuci_Apps/lib/providers/iap_provider.dart`
- `AyoCuci_Apps/lib/core/service/iap_service.dart`
- `AyoCuci_Apps/lib/data/models/iap_product_model.dart`

## 12. Urutan Eksekusi

Implementasi dikerjakan berurutan seperti ini:

### fase 1

- tambah tabel `ac_store_transactions`
- tambah backend `IapService`
- tambah endpoint verify iOS coin topup
- tambah endpoint verify iOS outlet PRO
- siapkan mapping product Apple

### fase 2

- integrasi Flutter iOS IAP untuk top up koin
- integrasi Flutter iOS IAP untuk PRO
- refresh saldo koin / outlet profile setelah sukses

### fase 3

- ubah addon menjadi koin-only
- stop flow addon transfer / Midtrans di backend dan UI
- sederhanakan screen checkout addon

### fase 4

- aktifkan `RequireAddon(...)` di semua route premium backend
- kunci screen Flutter premium
- audit semua jalur akses premium

### fase 5

- smoke test iOS sandbox
- test owner multi-outlet
- test duplicate transaction id
- test retry / restore purchase

## 13. Acceptance Criteria

Pekerjaan dianggap selesai kalau:

- iOS bisa top up koin via Apple IAP
- kredit koin hanya terjadi sekali per transaksi store
- iOS bisa aktivasi PRO per outlet via Apple IAP
- owner multi-outlet tidak salah mapping outlet
- addon tidak lagi bisa dibayar via transfer / Midtrans
- addon hanya bisa dibeli dengan koin
- endpoint premium tidak bisa diakses tanpa addon aktif
- Flutter menampilkan state terkunci dengan benar

## 14. Risiko yang Harus Dijaga

- salah mapping purchase PRO ke outlet yang bukan target user
- transaksi Apple ter-grant dua kali
- restore purchase mengkreditkan ulang koin
- flow Android lama rusak saat iOS path ditambahkan
- route premium belum terkunci semua walau UI sudah disembunyikan

## 15. Keputusan Implementasi yang Dipakai

Agar eksekusi cepat dan tidak melebar, keputusan yang dipakai sekarang:

- iOS IAP hanya untuk:
  - top up koin
  - aktivasi outlet PRO
- addon eceran menjadi koin-only
- Android top up koin tetap existing
- Android PRO tetap existing dulu
- backend lock premium dikerjakan setelah monetisasi iOS dan addon koin-only siap

## 16. Langkah Eksekusi Pertama Setelah Dokumen Ini

Langkah pertama yang harus langsung dikerjakan:

1. buat model + migration `ac_store_transactions`
2. buat `IapService` backend dan route verify iOS
3. tambah package `in_app_purchase` di Flutter
4. sambungkan top up koin iOS ke endpoint verify backend

Setelah itu baru lanjut ke PRO iOS, lalu addon koin-only, lalu lock premium routes.
