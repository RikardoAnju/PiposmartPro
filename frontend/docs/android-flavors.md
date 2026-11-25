# Android Flavors

App Android punya dua target install:

| Flavor | App name | Package ID | API |
| --- | --- | --- | --- |
| `dev` | `AyoCuci Dev` | `id.co.ayocuci.apps.dev` | `https://api-dev.ayocuci.id` |
| `prod` | `Ayo Cuci` | `id.co.ayocuci.apps` | `https://api.ayocuci.id` |

Karena package ID berbeda, app dev bisa di-install berdampingan dengan app Play Store.

## Build

Build APK dev:

```bash
./tool/build_android_dev.sh --release
```

Build APK prod:

```bash
./tool/build_android_prod.sh --release
```

Build AAB dev:

```bash
./tool/build_android_dev_aab.sh --release
```

Build AAB prod untuk Google Play:

```bash
./tool/build_android_prod_aab.sh --release
```

Debug APK bisa sangat besar karena membawa debug runtime/symbols. Release APK lebih kecil karena shrink/minify aktif. Untuk distribusi paling kecil lewat Play Store/internal testing, gunakan AAB karena Google Play akan membuat APK optimal per device.

Tambahkan argumen Flutter di belakang script bila perlu, misalnya untuk build debug lokal:

```bash
./tool/build_android_dev.sh --debug
```

## Run

Untuk menjalankan dev langsung ke device:

```bash
flutter run \
  --flavor dev \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=https://api-dev.ayocuci.id/api/v1 \
  --dart-define=API_PLAIN_URL=https://api-dev.ayocuci.id \
  --dart-define=WS_BASE_URL=wss://api-dev.ayocuci.id/api/v1/ws
```

Untuk prod:

```bash
flutter run \
  --flavor prod \
  --dart-define=APP_ENV=production \
  --dart-define=API_BASE_URL=https://api.ayocuci.id/api/v1 \
  --dart-define=API_PLAIN_URL=https://api.ayocuci.id \
  --dart-define=WS_BASE_URL=wss://api.ayocuci.id/api/v1/ws
```

## QA Flow

1. Backend feature masuk branch `development`.
2. GitHub Actions deploy ke `https://api-dev.ayocuci.id`.
3. Install `AyoCuci Dev` ke device.
4. Test login, transaksi, upload bukti/gambar, nota, websocket/status, dan admin/customer flow.
5. Kalau aman, merge backend ke `main` dan release app prod bila ada perubahan mobile.

Catatan Firebase: flavor dev memakai entry package `id.co.ayocuci.apps.dev` di `google-services.json`. Untuk production-grade push notification dan Google Sign-In dev, daftarkan package dev ini juga di Firebase Console.
