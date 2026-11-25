#!/usr/bin/env bash
# Run app di environment DEV (server api-dev.ayocuci.id).
# Semua dart-define diambil dari dart_defines/dev.json — anti lupa/ketinggalan.
# Contoh: ./scripts/run_dev.sh -d CPH2239
#         ./scripts/run_dev.sh -d CPH2239 --release
set -e
cd "$(dirname "$0")/.."
exec flutter run --flavor dev --dart-define-from-file=dart_defines/dev.json "$@"
