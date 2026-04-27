#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-8789}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WAVE_ROOT="${ROOT}/tb_int/report/wave"

if [[ ! -d "${WAVE_ROOT}" ]]; then
  echo "error: wave root not found: ${WAVE_ROOT}" >&2
  exit 2
fi

exec python3 -m http.server "${PORT}" --bind 127.0.0.1 --directory "${WAVE_ROOT}"
