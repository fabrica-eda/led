#!/usr/bin/env bash
set -euo pipefail

workspace_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
output="${workspace_dir}/blinky/build/LFE5UM5G-85F.json"
database="/usr/share/trellis/database"
texo_revision="9a04a21"

if [[ -f "${output}" && "${1:-}" != "--force" ]]; then
    echo "ECP5 architecture already exists: ${output}"
    exit 0
fi

for command in cargo apt dpkg-deb find python3; do
    if ! command -v "${command}" >/dev/null; then
        echo "error: required command is missing: ${command}" >&2
        exit 1
    fi
done
if [[ ! -d "${database}" ]]; then
    echo "error: Project Trellis database is missing: ${database}" >&2
    echo "install it with: sudo apt install fpga-trellis-database" >&2
    exit 1
fi

cargo fetch --locked --manifest-path "${workspace_dir}/Cargo.toml"
cargo_home="${CARGO_HOME:-${HOME}/.cargo}"
exporter="$(find "${cargo_home}/git/checkouts" -path "*/${texo_revision}/tools/export_ecp5.py" -print -quit)"
if [[ -z "${exporter}" ]]; then
    echo "error: Texo ECP5 exporter was not found in the Cargo Git cache" >&2
    exit 1
fi

temporary_dir="$(mktemp -d)"
trap 'rm -rf -- "${temporary_dir}"' EXIT
(
    cd "${temporary_dir}"
    apt download python3-pytrellis
    dpkg-deb -x python3-pytrellis_*.deb root
)

trellis_root="${temporary_dir}/root"
python3 "${exporter}" \
    --database "${database}" \
    --device LFE5UM5G-85F \
    --output "${output}" \
    --project-trellis-revision ubuntu-1.4-2build4 \
    --database-revision ubuntu-1.4-2build4 \
    -L "${trellis_root}/usr/lib/x86_64-linux-gnu/trellis" \
    -L "${trellis_root}/usr/share/trellis/timing/util" \
    -L "${trellis_root}/usr/share/trellis/util/common"

echo "Generated ${output}"
