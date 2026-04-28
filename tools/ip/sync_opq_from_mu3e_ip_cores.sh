#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
board_dir="${repo_root}/firmware/a10_board"
opq_source_root="${repo_root}/external/mu3e-ip-cores/packet_scheduler"
opq_source_version_file="${opq_source_root}/VERSION"
opq_source_hw_tcl="${opq_source_root}/script/ordered_priority_queue_hw.tcl"
opq_qsys_dir="${board_dir}/a10/merger/qsys/opq_upstream_4lane_native_sv"
opq_hw_tcl="${opq_qsys_dir}/ordered_priority_queue_native_sv_fixed4_hw.tcl"
opq_qsys_tcl="${opq_qsys_dir}/opq_upstream_4lane.tcl"
opq_qip="${opq_qsys_dir}/generated/opq_upstream_4lane.qip"
make_bin="${MAKE:-make}"
quartus_root="${QUARTUS_ROOTDIR:-/data1/intelFPGA/18.1/quartus}"
target="opq_qsys_unpack"

if [[ "${OPQ_QSYS_FORCE:-0}" == "1" ]]; then
  target="opq_qsys_regen"
fi

if [[ ! -f "${opq_hw_tcl}" ]]; then
  printf 'Missing local OPQ component descriptor: %s\n' "${opq_hw_tcl}" >&2
  exit 1
fi

if [[ ! -f "${opq_qsys_tcl}" ]]; then
  printf 'Missing local OPQ Qsys script: %s\n' "${opq_qsys_tcl}" >&2
  exit 1
fi

if [[ ! -f "${opq_source_version_file}" ]]; then
  printf 'Missing upstream OPQ VERSION file: %s\n' "${opq_source_version_file}" >&2
  exit 1
fi

if [[ ! -f "${opq_source_hw_tcl}" ]]; then
  printf 'Missing upstream OPQ component descriptor: %s\n' "${opq_source_hw_tcl}" >&2
  exit 1
fi

opq_version="$(tr -d '[:space:]' < "${opq_source_version_file}")"
if [[ ! "${opq_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'Invalid upstream OPQ VERSION: %s\n' "${opq_version}" >&2
  exit 1
fi

if ! grep -Eq "set_module_property[[:space:]]+VERSION[[:space:]]+${opq_version//./\\.}" "${opq_source_hw_tcl}"; then
  printf 'Upstream OPQ _hw.tcl version does not match VERSION (%s): %s\n' \
    "${opq_version}" "${opq_source_hw_tcl}" >&2
  exit 1
fi

get_tcl_const() {
  local name="$1"
  awk -v name="${name}" '$1 == "set" && $2 == name { print $3; exit }' "${opq_source_hw_tcl}"
}

opq_version_major="$(get_tcl_const VERSION_MAJOR_DEFAULT_CONST)"
opq_version_minor="$(get_tcl_const VERSION_MINOR_DEFAULT_CONST)"
opq_version_patch="$(get_tcl_const VERSION_PATCH_DEFAULT_CONST)"
opq_build="$(get_tcl_const BUILD_DEFAULT_CONST)"
opq_version_date="$(get_tcl_const VERSION_DATE_DEFAULT_CONST)"
opq_version_git="$(get_tcl_const VERSION_GIT_DEFAULT_CONST)"

for value in \
  "${opq_version_major}" \
  "${opq_version_minor}" \
  "${opq_version_patch}" \
  "${opq_build}" \
  "${opq_version_date}" \
  "${opq_version_git}"; do
  if [[ ! "${value}" =~ ^[0-9]+$ ]]; then
    printf 'Invalid upstream OPQ identity constant from %s\n' "${opq_source_hw_tcl}" >&2
    exit 1
  fi
done

sed -i -E \
  "s/^(set_module_property[[:space:]]+VERSION[[:space:]]+).*/\\1${opq_version}/" \
  "${opq_hw_tcl}"
sed -i -E \
  "s/^(set[[:space:]]+VERSION_MAJOR_DEFAULT_CONST[[:space:]]+).*/\\1${opq_version_major}/" \
  "${opq_hw_tcl}"
sed -i -E \
  "s/^(set[[:space:]]+VERSION_MINOR_DEFAULT_CONST[[:space:]]+).*/\\1${opq_version_minor}/" \
  "${opq_hw_tcl}"
sed -i -E \
  "s/^(set[[:space:]]+VERSION_PATCH_DEFAULT_CONST[[:space:]]+).*/\\1${opq_version_patch}/" \
  "${opq_hw_tcl}"
sed -i -E \
  "s/^(set[[:space:]]+BUILD_DEFAULT_CONST[[:space:]]+).*/\\1${opq_build}/" \
  "${opq_hw_tcl}"
sed -i -E \
  "s/^(set[[:space:]]+VERSION_DATE_DEFAULT_CONST[[:space:]]+).*/\\1${opq_version_date}/" \
  "${opq_hw_tcl}"
sed -i -E \
  "s/^(set[[:space:]]+VERSION_GIT_DEFAULT_CONST[[:space:]]+).*/\\1${opq_version_git}/" \
  "${opq_hw_tcl}"
sed -i -E \
  "s/^(add_instance[[:space:]]+opq_0[[:space:]]+ordered_priority_queue_native_sv_fixed4[[:space:]]+).*/\\1${opq_version}/" \
  "${opq_qsys_tcl}"

printf 'Local OPQ Qsys package refreshed from %s (version %s git %s)\n' \
  "${opq_source_hw_tcl}" "${opq_version}" "${opq_version_git}"

"${make_bin}" -C "${board_dir}" QUARTUS_ROOTDIR="${quartus_root}" "${target}"

if [[ ! -f "${opq_qip}" ]]; then
  printf 'OPQ Qsys generation did not create %s\n' "${opq_qip}" >&2
  exit 1
fi

printf 'OPQ Qsys QIP ready: %s\n' "${opq_qip}"
printf 'Generated synthesis iteration root: %s\n' "${opq_qsys_dir}/generated"
