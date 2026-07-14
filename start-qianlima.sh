#!/usr/bin/env bash
# Qianlima macOS/Linux entry.
# Principle: PowerShell 7 (pwsh) is the sole runtime; this script only checks and hands off.
# If pwsh is missing it errors out explicitly and never claims a successful startup.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PS1_ENTRY="${SCRIPT_DIR}/start-qianlima.ps1"

if ! command -v pwsh >/dev/null 2>&1; then
  echo "Error: PowerShell 7 (pwsh) not found." >&2
  echo "Qianlima's runtime is PowerShell 7; bash only forwards to it." >&2
  echo "Install first:" >&2
  echo "  macOS : brew install --cask powershell" >&2
  echo "  Linux : https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux" >&2
  echo "Then re-run: ./start-qianlima.sh [-SkipValidation] [-Force] [-Quiet]" >&2
  exit 127
fi

if [ ! -f "${PS1_ENTRY}" ]; then
  echo "Error: missing entry script ${PS1_ENTRY}" >&2
  exit 1
fi

# Pass through the same switches the .ps1 accepts: -SkipValidation / -Force / -Quiet.
exec pwsh -NoProfile -File "${PS1_ENTRY}" "$@"
