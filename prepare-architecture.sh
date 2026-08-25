#!/usr/bin/env bash
set -euo pipefail

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

texo="$(find_texo || true)"
if [[ -z "${texo}" || ! -x "${texo}" ]]; then
    echo "error: Texo CLI is missing; install v0.1.2 with fabricaup" >&2
    exit 1
fi
if [[ "$("${texo}" --version)" != "texo 0.1.2" ]]; then
    echo "error: this template requires Texo CLI v0.1.2" >&2
    exit 1
fi

"${texo}" target fetch LFE5UM5G-85F
