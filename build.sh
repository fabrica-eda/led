#!/usr/bin/env bash
set -euo pipefail

workspace_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
build_dir="${workspace_dir}/blinky/build"

for tool in cargo nextpnr-ecp5 ecppack; do
    if ! command -v "${tool}" >/dev/null; then
        echo "error: required command is missing: ${tool}" >&2
        exit 1
    fi
done

"${workspace_dir}/prepare-architecture.sh"
cargo run --locked --release --manifest-path "${workspace_dir}/Cargo.toml" -p verify-blinky

nextpnr-ecp5 \
    --um5g-85k \
    --package CABGA381 \
    --speed 8 \
    --json "${build_dir}/Top.struo.json" \
    --lpf "${workspace_dir}/blinky/lfe5um5g-85f-evn.lpf" \
    --textcfg "${build_dir}/Top.config" \
    --report "${build_dir}/Top.nextpnr-report.json" \
    --freq 12

ecppack \
    --db /usr/share/trellis/database \
    --svf "${build_dir}/Top.svf" \
    "${build_dir}/Top.config" \
    "${build_dir}/Top.bit"

sha256sum "${build_dir}/Top.bit"
