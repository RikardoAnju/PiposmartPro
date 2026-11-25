#!/usr/bin/env bash
set -euo pipefail

ANDROID_STUDIO_JBR="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
if [[ -z "${JAVA_HOME:-}" && -x "$ANDROID_STUDIO_JBR/bin/java" ]]; then
  export JAVA_HOME="$ANDROID_STUDIO_JBR"
fi

flutter build appbundle \
  --flavor dev \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=https://api-dev.ayocuci.id/api/v1 \
  --dart-define=API_PLAIN_URL=https://api-dev.ayocuci.id \
  --dart-define=WS_BASE_URL=wss://api-dev.ayocuci.id/api/v1/ws \
  "$@"

echo
echo "Use this development AAB only for the dev/internal app:"
echo "build/app/outputs/bundle/devRelease/app-dev-release.aab"
