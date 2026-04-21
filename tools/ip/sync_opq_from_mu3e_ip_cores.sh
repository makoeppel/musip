#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
dest_dir="${repo_root}/firmware/a10_board/a10/merger"

resolve_src_root() {
  if [[ -n "${MU3E_IP_CORES_ROOT:-}" && -d "${MU3E_IP_CORES_ROOT}" ]]; then
    printf '%s\n' "${MU3E_IP_CORES_ROOT}"
    return 0
  fi

  if [[ -d "${repo_root}/external/mu3e-ip-cores" ]]; then
    printf '%s\n' "${repo_root}/external/mu3e-ip-cores"
    return 0
  fi

  if [[ -d "/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores" ]]; then
    printf '%s\n' "/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores"
    return 0
  fi

  return 1
}

if ! src_root="$(resolve_src_root)"; then
  printf 'Unable to find mu3e-ip-cores. Set MU3E_IP_CORES_ROOT or add external/mu3e-ip-cores.\n' >&2
  exit 1
fi

src_dir="${src_root}/packet_scheduler/syn/quartus/opq_monolithic_4lane_merge/generated/synthesis/submodules"
rtl_files=(
  ticket_fifo.v
  lane_fifo.v
  handle_fifo.v
  page_ram.v
  tile_fifo.v
  opq_monolithic_4lane_merge_opq_0.vhd
)

mkdir -p "${dest_dir}"
for rtl_file in "${rtl_files[@]}"; do
  src="${src_dir}/${rtl_file}"
  dest="${dest_dir}/${rtl_file}"
  if [[ ! -f "${src}" ]]; then
    printf 'OPQ source not found at %s\n' "${src}" >&2
    exit 1
  fi
  install "${src}" "${dest}"
  printf 'Synced %s\n' "${dest}"
done
