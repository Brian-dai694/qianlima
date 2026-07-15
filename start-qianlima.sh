#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v pwsh >/dev/null 2>&1; then
  echo "Qianlima requires PowerShell 7 (pwsh) on macOS/Linux." >&2
  echo "macOS setup: bash scripts/install-powershell-macos.sh --install" >&2
  echo "Then run: bash start-qianlima.sh" >&2
  exit 127
fi

exec pwsh -NoProfile -File "$project_root/start-qianlima.ps1" "$@"
