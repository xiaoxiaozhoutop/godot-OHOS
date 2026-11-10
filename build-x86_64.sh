#!/usr/bin/env bash
# Build a Godot export template for OpenHarmony.
#
# Usage:
#   bash build-x86_64.sh            # x86_64, Release
#   bash build-arm64.sh              # ARM64, Release
#   ARCH=arm64 bash build-x86_64.sh  # same as above
#
# Parallelism is chosen by build_jobs.py from the CPU count and free memory.
# Override with JOBS=<n> (or GODOT_BUILD_JOBS=<n>).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_PATH="${OPENHARMONY_SDK_PATH:-${DEVECO_CLI_CLT_PATH:-/home/zhou/command-line-tools}/sdk/default/openharmony}"
TARGET="${TARGET:-template_release}"
ARCH="${ARCH:-x86_64}"

SCONS="${SCONS:-${ROOT_DIR}/.venv/bin/scons}"
if [[ ! -x "${SCONS}" ]]; then
    echo "Missing SCons: python3 -m venv .venv && .venv/bin/pip install scons==4.11.1" >&2
    exit 1
fi

JOBS="${JOBS:-$(python3 "${ROOT_DIR}/build_jobs.py")}"
if ! [[ "${JOBS}" =~ ^[0-9]+$ ]] || [[ "${JOBS}" -lt 1 ]]; then
    echo "Invalid JOBS value: ${JOBS}" >&2
    exit 1
fi

export TMPDIR="${TMPDIR:-/tmp/opencode}"
echo "Building ${ARCH} ${TARGET} with ${JOBS} parallel jobs."

cd "${ROOT_DIR}"
exec "${SCONS}" \
    platform=openharmony arch="${ARCH}" target="${TARGET}" \
    OPENHARMONY_SDK_PATH="${SDK_PATH}" \
    debug_symbols=no lto=none generate_bundle=yes -j"${JOBS}" "$@"
