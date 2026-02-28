#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_FILE="$ROOT_DIR/.secrets/openai.dev.json"

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "Missing secrets file: $SECRETS_FILE" >&2
  exit 1
fi

cd "$ROOT_DIR"
flutter pub get
flutter run \
  --dart-define-from-file="$SECRETS_FILE" \
  --dart-define=OPENAI_DEBUG_LOGS=true \
  "$@"
