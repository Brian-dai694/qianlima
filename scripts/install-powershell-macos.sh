#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bash scripts/install-powershell-macos.sh [--install]

Without --install, this script only shows the required installation steps.
With --install, it installs Homebrew when needed, then installs PowerShell 7.
EOF
}

install=false
case "${1:-}" in
  "") ;;
  --install) install=true ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 64 ;;
esac

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This installer only supports macOS." >&2
  exit 1
fi

if command -v pwsh >/dev/null 2>&1; then
  echo "PowerShell is already available: $(pwsh --version)"
  exit 0
fi

if [[ "$install" != true ]]; then
  cat <<'EOF'
PowerShell 7 is required to run Qianlima on macOS.

This installer will:
  1. Install Homebrew if it is not available.
  2. Run: brew install --cask powershell
  3. Verify: pwsh --version

Run the following explicit command to continue:
  bash scripts/install-powershell-macos.sh --install
EOF
  exit 0
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is not installed. Installing it using the official installer..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew was installed but is not available in this shell. Open a new Terminal window, then rerun this command." >&2
  exit 1
fi

echo "Installing PowerShell 7 with Homebrew..."
brew install --cask powershell

if ! command -v pwsh >/dev/null 2>&1; then
  echo "PowerShell installation completed, but pwsh is not yet on PATH. Open a new Terminal window and run: pwsh --version" >&2
  exit 1
fi

echo "PowerShell installation verified: $(pwsh --version)"
echo "Start Qianlima with: bash start-qianlima.sh"
