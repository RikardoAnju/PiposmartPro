# Deployment Stages

Backend API memakai dua stage:

- `development`: branch `development`, deploy ke server lama untuk testing (`76.13.19.62`).
- `production`: branch `main`, deploy ke server prod baru (`187.127.109.86`).

Pull request ke `development` atau `main` hanya menjalankan validasi build. Deploy hanya jalan saat ada push ke branch stage tersebut.

## GitHub Environments

Buat dua GitHub Environments di repository settings:

- `development`
- `production`

Isi secret dengan nama yang sama di masing-masing environment. Nilainya berbeda sesuai server/stage.

### Required secrets

```text
DB_DSN
JWT_SECRET
SSH_HOST
SSH_PORT
SSH_USER
SSH_KEY
DEPLOY_PATH
```

### Optional secrets

```text
GOOGLE_CLIENT_ID
FONNTE_TOKEN
FIREBASE_SERVICE_ACCOUNT_JSON_BASE64
REDIS_ADDR
REDIS_USERNAME
REDIS_PASSWORD
REDIS_DB
OSS_ACCESS_KEY_ID
OSS_ACCESS_KEY_SECRET
```

Untuk production baru, isi secret Redis dengan host/user/password Redis production. Untuk development lama, `REDIS_ADDR` bisa dibiarkan kosong jika masih memakai container `Redis-Server:6379` di server yang sama.

## GitHub Environment Variables

Tambahkan variables ini bila dibutuhkan:

```text
AYOCUCI_API_HOST
STORAGE_DRIVER
OSS_ENDPOINT
OSS_BUCKET
OSS_PREFIX
OSS_OBJECT_ACL
OSS_PUBLIC_BASE_URL
MYSQL_NETWORK_NAME
```

Contoh:

- `development`: `AYOCUCI_API_HOST=api-dev.ayocuci.id`, `STORAGE_DRIVER=local`
- `development`: `MYSQL_NETWORK_NAME=msyql-database_default`
- `production`: `AYOCUCI_API_HOST=api.ayocuci.id`, `STORAGE_DRIVER=oss`
- `production`: `MYSQL_NETWORK_NAME=mysql-database_default`

## SSH Deploy Key

GitHub Actions butuh SSH private key di secret `SSH_KEY`. Public key pasangan dari secret itu harus ada di server `development` dan `production` pada user yang dipakai deploy.

Public key yang sedang disiapkan untuk CI:

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKAg31djU4GSejOXJs+o0vO+dlp0/u48ombey2his8Zu github-actions-ayocuci-api
```

Pasang public key itu di setiap server:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKAg31djU4GSejOXJs+o0vO+dlp0/u48ombey2his8Zu github-actions-ayocuci-api' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

## Branch Flow

1. Fitur masuk ke branch feature.
2. Merge/push ke `development` untuk deploy ke server dev.
3. Setelah lolos testing, merge `development` ke `main`.
4. Push ke `main` otomatis deploy ke production.

Jika branch `development` belum ada di remote:

```bash
git switch -c development
git push -u origin development
```

## Server Prod Baru

Di server production baru, siapkan minimal:

- Git checkout repository di `DEPLOY_PATH`.
- Docker dan Docker Compose plugin.
- SSH user yang bisa menjalankan Docker.
- Traefik/reverse proxy jika domain publik memakai label Traefik.
- DNS `AYOCUCI_API_HOST` mengarah ke server production.

Workflow akan membuat `.env` di server dari GitHub Environment secrets, menjalankan `git reset --hard origin/<branch>`, `docker compose up --build -d`, lalu mengecek `/health`.
