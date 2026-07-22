#!/usr/bin/env bash
set -euo pipefail

install=false
accept_license=false
for arg in "$@"; do
  case "$arg" in
    --install) install=true ;;
    --accept-docker-license) accept_license=true ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

if [[ "$install" != true ]]; then
  echo "Use --install --accept-docker-license for the explicit administrator deployment." >&2
  exit 2
fi
if [[ "$accept_license" != true ]]; then
  echo "Docker Desktop license acceptance is required." >&2
  exit 2
fi
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This installer currently supports managed macOS deployment only." >&2
  exit 2
fi
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required by the managed macOS deployment package." >&2
  exit 127
fi

brew install --cask docker
brew install --cask powershell
open -gj -a Docker

daemon_ready=false
for _ in $(seq 1 24); do
  if docker info --format '{{.OSType}}' >/dev/null 2>&1; then
    daemon_ready=true
    break
  fi
  sleep 5
done
if [[ "$daemon_ready" != true ]]; then
  echo "Docker Desktop requires first-run enterprise approval. Complete it, then rerun this command." >&2
  exit 1
fi

docker pull alpine:3.20
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pwsh -NoProfile -File "$script_dir/test-enterprise-environment.ps1" -PassThru
echo "Qianlima Enterprise managed environment is ready. Agent execution remains Attestation- and Grant-gated."
