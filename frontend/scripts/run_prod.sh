#!/usr/bin/env bash
# Run app di environment PROD (server api.ayocuci.id).
# Semua dart-define diambil dari dart_defines/prod.json.
# Contoh: ./scripts/run_prod.sh -d CPH2239 --release
set -e
cd "$(dirname "$0")/.."
exec flutter run --flavor prod --dart-define-from-file=dart_defines/prod.json "$@"
