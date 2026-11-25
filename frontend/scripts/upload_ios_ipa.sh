#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR"
IPA_PATH="$APP_DIR/build/ios/ipa"

if [[ ! -d "$IPA_PATH" ]]; then
  echo "IPA directory not found: $IPA_PATH"
  exit 1
fi

IPA_FILE="$(find "$IPA_PATH" -maxdepth 1 -name '*.ipa' | head -n 1 || true)"
if [[ -z "${IPA_FILE:-}" ]]; then
  echo "No IPA file found in: $IPA_PATH"
  exit 1
fi

: "${ASC_API_KEY_ID:?Set ASC_API_KEY_ID to your App Store Connect API Key ID}"
: "${ASC_API_ISSUER_ID:?Set ASC_API_ISSUER_ID to your App Store Connect Issuer ID}"
: "${ASC_API_KEY_PATH:?Set ASC_API_KEY_PATH to the .p8 file path}"

if [[ ! -f "$ASC_API_KEY_PATH" ]]; then
  echo "API key file not found: $ASC_API_KEY_PATH"
  exit 1
fi

echo "Uploading: $IPA_FILE"
echo "Using key id: $ASC_API_KEY_ID"
echo "Using issuer:  $ASC_API_ISSUER_ID"

xcrun altool --upload-app \
  --type ios \
  --file "$IPA_FILE" \
  --apiKey "$ASC_API_KEY_ID" \
  --apiIssuer "$ASC_API_ISSUER_ID" \
  --apiKeyPath "$ASC_API_KEY_PATH"
