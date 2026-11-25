#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR"
APP_ENV="production"
API_BASE_URL="https://api.ayocuci.id/api/v1"
API_PLAIN_URL="https://api.ayocuci.id"
WS_BASE_URL="wss://api.ayocuci.id/api/v1/ws"

ASC_API_KEY_ID="77278VVPW3"
ASC_API_ISSUER_ID="4d731144-e951-4637-83dc-a1cb093671c7"
PRIVATE_KEYS_DIR="$APP_DIR/private_keys"
PRIVATE_KEY_DEST="$PRIVATE_KEYS_DIR/AuthKey_${ASC_API_KEY_ID}.p8"

# Cari key di private_keys/ (lokasi utama) atau root project (fallback).
if [[ -f "$PRIVATE_KEY_DEST" ]]; then
  ASC_API_KEY_PATH="$PRIVATE_KEY_DEST"
elif [[ -f "$APP_DIR/AuthKey_${ASC_API_KEY_ID}.p8" ]]; then
  ASC_API_KEY_PATH="$APP_DIR/AuthKey_${ASC_API_KEY_ID}.p8"
else
  echo "API key file not found di:"
  echo "  - $PRIVATE_KEY_DEST"
  echo "  - $APP_DIR/AuthKey_${ASC_API_KEY_ID}.p8"
  exit 1
fi

# altool membaca --apiKey dari folder private_keys, jadi pastikan ada di sana.
mkdir -p "$PRIVATE_KEYS_DIR"
if [[ "$ASC_API_KEY_PATH" != "$PRIVATE_KEY_DEST" ]]; then
  cp "$ASC_API_KEY_PATH" "$PRIVATE_KEY_DEST"
fi

VERSION_LINE="$(grep -E '^version:' "$APP_DIR/pubspec.yaml" | head -n 1 | sed 's/^version:[[:space:]]*//')"
if [[ -z "${VERSION_LINE:-}" ]]; then
  echo "Could not read version from pubspec.yaml"
  exit 1
fi

BUILD_NAME="${VERSION_LINE%%+*}"
BUILD_NUMBER="${VERSION_LINE##*+}"

if [[ "$BUILD_NAME" == "$BUILD_NUMBER" ]]; then
  echo "pubspec.yaml version must be in the form x.y.z+build, got: $VERSION_LINE"
  exit 1
fi

cd "$APP_DIR"

echo "Cleaning Flutter build artifacts..."
flutter clean

echo "Fetching dependencies..."
flutter pub get

echo "Building iOS IPA for production..."
flutter build ipa \
  --release \
  --build-name="$BUILD_NAME" \
  --build-number="$BUILD_NUMBER" \
  --dart-define=APP_ENV="$APP_ENV" \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=API_PLAIN_URL="$API_PLAIN_URL" \
  --dart-define=WS_BASE_URL="$WS_BASE_URL"

IPA_FILE="$(find "$APP_DIR/build/ios/ipa" -maxdepth 1 -name '*.ipa' -print0 | xargs -0 ls -t 2>/dev/null | head -n 1 || true)"
if [[ -z "${IPA_FILE:-}" ]]; then
  echo "No IPA file found after build."
  exit 1
fi

echo "Uploading IPA: $IPA_FILE"
xcrun altool --upload-app \
  --type ios \
  --file "$IPA_FILE" \
  --apiKey "$ASC_API_KEY_ID" \
  --apiIssuer "$ASC_API_ISSUER_ID"
