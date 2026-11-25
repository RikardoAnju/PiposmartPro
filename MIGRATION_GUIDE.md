# 📋 Piposmart Pro - Migration Guide dari Ayocuci

Dokumen ini menjelaskan proses cloning Ayocuci menjadi Piposmart Pro dan perubahan yang dilakukan.

## 🎯 Tujuan Migrasi

1. Reuse codebase Ayocuci untuk mempercepat development Piposmart Pro
2. Rebrand dengan identitas Piposmart Pro
3. Update semua package names dan references
4. Siapkan repository baru untuk deployment

## 📦 Apa yang Dikerjakan

### ✅ 1. Project Structure Cloning
```
AYOCUCI/                  → PiposmartPro/
├── Backend/              →  ├── backend/
├── frontend/             →  ├── frontend/
└── ...                   →  └── ...
```

### ✅ 2. Package Name Updates

#### Android/Flutter Frontend
| Komponen | Lama | Baru |
|----------|------|------|
| Package Name | `id.ayocuci.app` | `id.piposmart.pro.app` |
| Application ID | `id.co.ayocuci.apps` | `id.piposmart.pro.apps` |
| App Name (Dev) | `AyoCuci Dev` | `Piposmart Pro Dev` |
| App Name (Prod) | `Ayo Cuci` | `Piposmart Pro` |
| Pubspec Name | `ayocucinew` | `piposmart_pro` |

#### Go Backend
| Komponen | Lama | Baru |
|----------|------|------|
| Go Module | `ayocuci` | `github.com/RikardoAnju/PiposmartPro` |
| OSS Bucket | `ayocuci-data` | `piposmart-pro-data` |
| JWT Issuer | `ayocuci-api` | `piposmart-pro-api` |
| FCM Channel ID | `ayocuci_brand_alerts_v2` | `piposmart_pro_alerts_v2` |

### ✅ 3. Code Changes

#### Frontend Changes (1,241 files)
- Updated `pubspec.yaml` dengan nama dan deskripsi baru
- Updated Android package names di `build.gradle.kts`
- Updated app names di flavor configurations
- All imports dan references sudah konsisten

#### Backend Changes (~470+ references)
- Updated `go.mod` dengan module path baru
- Updated semua `import` statements di Go files
- Updated configuration values (bucket, issuer, channel IDs)
- Database credentials tetap menggunakan Ayocuci config (akan diganti saat setup)

### ✅ 4. Git Setup
- Initialized local git repository
- Added remote: `https://github.com/RikardoAnju/PiposmartPro.git`
- Created `.gitignore` untuk macOS, Flutter, Android, iOS, Go, IDE files
- Initial commit dengan 1,242 tracked files

## 📝 Commits Created

```
301b7ac docs: add comprehensive README for Piposmart Pro
6902df0 Initial commit: Clone from Ayocuci with Piposmart Pro branding
```

## 🔧 Hal-hal yang Perlu Dikonfigurasi Nanti

### Database
```bash
# Sesuaikan credentials di backend
# Frontend: android/app/build.gradle.kts (dev & prod flavors)
# Backend: cmd/seeder/main.go, cmd/reset/main.go
```

Saat ini masih menggunakan:
```
Database User: ayocuci_user
Database Name: ayocuci_db
```

Ganti dengan Piposmart Pro database saat production setup.

### Environment Variables
1. Update `.env` file dengan credentials baru
2. Update Firebase configuration (google-services.json untuk Android)
3. Update Midtrans payment gateway keys
4. Update OSS (Alibaba Object Storage Service) credentials
5. Update FCM (Firebase Cloud Messaging) keys

### Assets & Branding
- Logo files tetap Ayocuci, perlu diganti dengan Piposmart Pro logo
- Assets berada di:
  - Frontend: `frontend/assets/`
  - App icons: `frontend/android/app/src/main/res/`

## 🚀 Next Steps

### 1. Push ke GitHub
```bash
cd /Volumes/Penyimpanan Ekstra/PiposmartPro

# Pastikan remote sudah benar
git remote -v

# Push ke GitHub (perlu GitHub credentials)
git push -u origin main
```

### 2. Update Firebase Configuration
- Download `google-services.json` dari Firebase Console
- Letakkan di `frontend/android/app/`
- Update iOS configuration jika perlu

### 3. Update Environment Variables
```bash
# Backend
cd backend
cp .env.example .env
# Edit .env dengan credentials baru

# Update database credentials
# Update payment gateway keys
# Update cloud storage credentials
```

### 4. Database Setup
```bash
# Update database credentials di cmd/seeder/main.go
# Run migrations dari docs/migrations/ folder
# Seed data jika diperlukan
```

### 5. Test Build
```bash
# Frontend
cd frontend
flutter pub get
flutter build apk

# Backend
cd backend
go build -o ./bin/piposmart-pro
```

## 📊 Statistik Migrasi

| Item | Jumlah |
|------|--------|
| Total Files | 1,242 |
| Package References Updated | 470+ |
| Configuration Items Updated | 7 |
| Git Commits | 2 |
| Lines of Code (approximate) | 100,000+ |

## ❓ FAQ

### Q: Apakah database Ayocuci perlu dimigrate?
A: Tidak, Piposmart Pro akan menggunakan database baru. Database Ayocuci bisa tetap independent.

### Q: Bisakah saya update package name nanti?
A: Tergantung seberapa dalam sudah integration. Lebih mudah dilakukan sekarang, tapi bisa juga nanti.

### Q: Bagaimana dengan Firebase configuration?
A: Perlu setup Firebase project baru untuk Piposmart Pro, download google-services.json dari Firebase Console.

### Q: Apakah logo Ayocuci perlu diganti?
A: Disarankan diganti untuk branding yang konsisten, tapi tidak critical.

## 📞 Support

Jika ada pertanyaan atau masalah, check:
1. Git history: `git log`
2. Docs folder di backend: `backend/docs/`
3. README.md untuk overview
4. This file untuk details

---

**Created**: November 25, 2026
**Migrated from**: Ayocuci Project
**Migration Status**: ✅ Complete - Ready for GitHub Push

