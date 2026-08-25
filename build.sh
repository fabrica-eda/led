#!/usr/bin/env bash
set -euo pipefail

workspace_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
build_dir="${workspace_dir}/blinky/build"
pytrellis_dir="${workspace_dir}/blinky/.build/python3-pytrellis/usr/lib/x86_64-linux-gnu/trellis"
texo_revision="e153f96"

for tool in cargo find python3 ecppack ecpunpack; do
    if ! command -v "${tool}" >/dev/null; then
        echo "error: required command is missing: ${tool}" >&2
        exit 1
    fi
done

"${workspace_dir}/prepare-architecture.sh"
cargo run --locked --release --manifest-path "${workspace_dir}/Cargo.toml" -p verify-blinky

cargo_home="${CARGO_HOME:-${HOME}/.cargo}"
bitgen="$(find "${cargo_home}/git/checkouts" -path "*/${texo_revision}/tools/ecp5_bitstream.py" -print -quit)"
if [[ -z "${bitgen}" ]]; then
    echo "error: Texo ECP5 bitstream generator was not found in the Cargo Git cache" >&2
    exit 1
fi

python3 "${bitgen}" \
    --checkpoint "${build_dir}/Top.texo.checkpoint.json" \
    --config "${build_dir}/Top.config" \
    --bit "${build_dir}/Top.bit" \
    --database /usr/share/trellis/database \
    --pytrellis-libdir "${pytrellis_dir}"
