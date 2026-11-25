#!/usr/bin/env bash
set -euo pipefail

# Build Android App Bundle (.aab) untuk produksi dengan penyesuaian typography
# Android AKTIF. Mirror dari scripts/build_ios_prod.sh.

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

echo "Building Android App Bundle for production..."
set +e
flutter build appbundle \
  --release \
  --flavor prod \
  --build-name="$BUILD_NAME" \
  --build-number="$BUILD_NUMBER" \
  --dart-define=APP_ENV="$APP_ENV" \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=API_PLAIN_URL="$API_PLAIN_URL" \
  --dart-define=WS_BASE_URL="$WS_BASE_URL" \
  --dart-define=APP_IS_ANDROID=true
FLUTTER_BUILD_STATUS=$?
set -e

AAB_FILE="$APP_DIR/build/app/outputs/bundle/prodRelease/app-prod-release.aab"
if [[ ! -f "$AAB_FILE" ]]; then
  echo "No .aab file found after build."
  exit 1
fi

# Flutter's post-build apkanalyzer check currently breaks when the project path
# contains spaces, even though Gradle produced the symbol metadata correctly.
# Validate the release bundle directly before accepting that false-negative.
if [[ "$FLUTTER_BUILD_STATUS" -ne 0 ]]; then
  if ! unzip -l "$AAB_FILE" | grep 'libflutter.so.sym' >/dev/null; then
    echo "Flutter build failed and libflutter native symbols are missing."
    exit "$FLUTTER_BUILD_STATUS"
  fi
  if ! unzip -l "$AAB_FILE" | grep 'libapp.so.sym' >/dev/null; then
    echo "Flutter build failed and libapp native symbols are missing."
    exit "$FLUTTER_BUILD_STATUS"
  fi
  echo "Flutter apkanalyzer returned a false-negative; embedded native symbols verified directly."
fi

unzip -tqq "$AAB_FILE"

echo "Production App Bundle ready:"
echo "$AAB_FILE"
echo
echo "Upload this .aab to Play Console."
