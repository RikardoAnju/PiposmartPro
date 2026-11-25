# AyoCuci API 🧺

Backend API untuk sistem manajemen laundry berbasis SaaS (Software as a Service) menggunakan Go (Golang) dan Gin Framework.

## Fitur Utama Kita

- **Multi-Tenant SaaS**: Mendukung banyak outlet dengan manajemen paket langganan (Hemat, Reguler, Sultan).
- **Audit Trail**: Tracking perubahan data menggunakan `actor_id` dan `actor_type` secara konsisten.
- **Sistem Nota Dinamis**: Konfigurasi nota per-outlet dengan QR Code generator untuk sinkronisasi app karyawan.
- **Role-Based Access Control (RBAC)**: Pengaturan hak akses pegawai berdasarkan role yang fleksibel, termasuk manajemen karyawan dan role pada modul `pegawai`.

## Tech Stack

- **Framework**: [Gin Gonic](https://github.com/gin-gonic/gin)
- **ORM**: [GORM](https://gorm.io/)
- **Database**: MySQL
- **Auth**: JWT (JSON Web Token)

## Storage Upload

Upload gambar default tetap disimpan lokal di folder `uploads` supaya development tidak berubah. Untuk production OSS Alibaba Cloud, set environment berikut:

```env
STORAGE_DRIVER=oss
OSS_ENDPOINT=https://oss-ap-southeast-3.aliyuncs.com
OSS_BUCKET=ayocuci-data
OSS_ACCESS_KEY_ID=...
OSS_ACCESS_KEY_SECRET=...
OSS_PREFIX=uploads
OSS_OBJECT_ACL=public-read
OSS_PUBLIC_BASE_URL=https://ayocuci-data.oss-ap-southeast-3.aliyuncs.com
```

Route `/uploads` tetap dipertahankan untuk membaca file legacy yang belum dimigrasikan ke OSS.

## GitHub Actions Secrets

Deploy membuat `.env` server dari GitHub Environment secrets. Stage yang dipakai:

- `development`: push ke branch `development`, deploy ke server development.
- `production`: push ke branch `main`, deploy ke server production.

Untuk panduan lengkap setup branch, environment, secrets, Redis, dan host domain, lihat [docs/deployment-stages.md](docs/deployment-stages.md).

Untuk OSS upload, pastikan secrets berikut ada di environment yang memakai OSS:

```text
OSS_ACCESS_KEY_ID
OSS_ACCESS_KEY_SECRET
```

Secret seperti `DB_DSN`, `JWT_SECRET`, `GOOGLE_CLIENT_ID`, `FONNTE_TOKEN`, `RESEND_API_KEY`, `RESEND_FROM_EMAIL`, `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64`, `REDIS_ADDR`, `REDIS_USERNAME`, `REDIS_PASSWORD`, `REDIS_DB`, `SSH_HOST`, `SSH_PORT`, `SSH_USER`, `SSH_KEY`, dan `DEPLOY_PATH` dipakai oleh workflow deploy.

# Notes

**Udah Running**: Gass
