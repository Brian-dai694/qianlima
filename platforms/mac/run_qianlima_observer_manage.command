#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

PYTHON_BIN=""
for candidate in python3 /opt/homebrew/bin/python3 /usr/local/bin/python3; do
  if command -v "$candidate" >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v "$candidate")"
    break
  fi
done

if [[ -z "$PYTHON_BIN" ]]; then
  echo "python3 not found" >&2
  exit 1
fi

exec "$PYTHON_BIN" -m qianlima_observer.cli "${1:-.}" --manage --interactive "${@:2}"

