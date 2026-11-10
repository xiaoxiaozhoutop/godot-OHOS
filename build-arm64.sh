#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ARCH=arm64
exec bash "${ROOT_DIR}/build-x86_64.sh" "$@"
