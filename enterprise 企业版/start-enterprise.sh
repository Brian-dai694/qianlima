#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v pwsh >/dev/null 2>&1; then
  echo "Qianlima Enterprise Edition requires PowerShell 7 (pwsh)." >&2
  echo "Run: bash scripts/install-powershell-macos.sh --install" >&2
  exit 127
fi

exec pwsh -NoProfile -File "$project_root/enterprise 企业版/start-enterprise.ps1" "$@"
