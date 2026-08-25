#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bitstream="${1:-${project_dir}/build/Top.bit}"

if ! command -v openFPGALoader >/dev/null 2>&1; then
    echo "openFPGALoader is required: sudo apt install openfpgaloader" >&2
    exit 1
fi

if [[ ! -f "${bitstream}" ]]; then
    echo "bitstream not found: ${bitstream}" >&2
    echo "run ./build.sh first" >&2
    exit 1
fi

exec openFPGALoader -b ecp5_evn "${bitstream}"
