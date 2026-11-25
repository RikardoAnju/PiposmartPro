#!/usr/bin/env bash
set -euo pipefail

# Menjalankan app di Android dengan penyesuaian typography Android AKTIF
# (--dart-define=APP_IS_ANDROID=true) plus dart-define environment.
#
# Default API = dev. Untuk API produksi: ENV=prod ./scripts/run_android.sh ...
# Argumen tambahan (device, --flavor, --release, dll) diteruskan ke flutter run.
#
# Contoh:
#   ./scripts/run_android.sh -d CPH2239 --flavor dev --release
#   ./scripts/run_android.sh -d Ssstt
#   ENV=prod ./scripts/run_android.sh -d CPH2239 --flavor dev --release

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ENV="${ENV:-dev}" # dev | prod

if [[ "$ENV" == "prod" ]]; then
  APP_ENV="production"
  API_BASE_URL="https://api.ayocuci.id/api/v1"
  API_PLAIN_URL="https://api.ayocuci.id"
  WS_BASE_URL="wss://api.ayocuci.id/api/v1/ws"
else
  APP_ENV="development"
  API_BASE_URL="https://api-dev.ayocuci.id/api/v1"
  API_PLAIN_URL="https://api-dev.ayocuci.id"
  WS_BASE_URL="wss://api-dev.ayocuci.id/api/v1/ws"
fi

echo "Android run — ENV=$ENV, APP_IS_ANDROID=true"
flutter run \
  --dart-define=APP_IS_ANDROID=true \
  --dart-define=APP_ENV="$APP_ENV" \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=API_PLAIN_URL="$API_PLAIN_URL" \
  --dart-define=WS_BASE_URL="$WS_BASE_URL" \
  "$@"
