#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR"

APP_ENV="production"
API_BASE_URL="https://api.ayocuci.id/api/v1"
API_PLAIN_URL="https://api.ayocuci.id"
WS_BASE_URL="wss://api.ayocuci.id/api/v1/ws"

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

echo "Production IPA ready:"
echo "$IPA_FILE"
echo
echo "Upload this IPA manually using Transporter."
