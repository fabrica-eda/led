#!/usr/bin/env bash
set -euo pipefail

workspace_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
build_dir="${workspace_dir}/blinky/build"

find_texo() {
    if [[ -n "${TEXO:-}" ]]; then
        printf '%s\n' "${TEXO}"
    elif command -v texo >/dev/null 2>&1; then
        command -v texo
    elif [[ -x "${HOME}/.fabrica/bin/texo" ]]; then
        printf '%s\n' "${HOME}/.fabrica/bin/texo"
    else
        return 1
    fi
}

if ! command -v cargo >/dev/null 2>&1; then
    echo "error: required command is missing: cargo" >&2
    exit 1
fi

texo="$(find_texo || true)"
if [[ -z "${texo}" || ! -x "${texo}" ]]; then
    echo "error: Texo CLI is missing; install v0.1.2 with fabricaup" >&2
    exit 1
fi
if [[ "$("${texo}" --version)" != "texo 0.1.2" ]]; then
    echo "error: this template requires Texo CLI v0.1.2" >&2
    exit 1
fi

mkdir -p "${build_dir}"
export TEXO="${texo}"
"${workspace_dir}/prepare-architecture.sh"
cargo run --locked --release --manifest-path "${workspace_dir}/Cargo.toml" -p verify-blinky

"${texo}" pnr "${workspace_dir}/blinky" \
    --top Top \
    --device LFE5UM5G-85F \
    --package CABGA381 \
    --speed 8 \
    --lpf "${workspace_dir}/blinky/lfe5um5g-85f-evn.lpf" \
    --output "${build_dir}/Top.texo.checkpoint.json" \
    --synthesis-goal-mhz 12

"${texo}" bitgen "${build_dir}/Top.texo.checkpoint.json" \
    --config "${build_dir}/Top.config" \
    --bit "${build_dir}/Top.bit"
