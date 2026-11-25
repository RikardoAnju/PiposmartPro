#!/usr/bin/env bash
set -euo pipefail

ANDROID_STUDIO_JBR="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
if [[ -z "${JAVA_HOME:-}" && -x "$ANDROID_STUDIO_JBR/bin/java" ]]; then
  export JAVA_HOME="$ANDROID_STUDIO_JBR"
fi

flutter build apk \
  --flavor prod \
  --dart-define=APP_ENV=production \
  --dart-define=API_BASE_URL=https://api.ayocuci.id/api/v1 \
  --dart-define=API_PLAIN_URL=https://api.ayocuci.id \
  --dart-define=WS_BASE_URL=wss://api.ayocuci.id/api/v1/ws \
  "$@"
