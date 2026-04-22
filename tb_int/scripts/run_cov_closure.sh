#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${TB_DIR}/.." && pwd)"
UVM_DIR="${TB_DIR}/cases/basic/uvm"
PLAIN_DIR="${TB_DIR}/cases/basic/plain"
PLAIN_2ENV_DIR="${TB_DIR}/cases/basic/plain_2env"
REF_DIR="${TB_DIR}/cases/basic/ref"
LOG_DIR="${TB_DIR}/sim_runs/logs"
COV_DIR="${TB_DIR}/sim_runs/coverage"

QUESTA_HOME="${QUESTA_HOME:-/data1/questaone_sim/questasim}"
VCOVER="${QUESTA_HOME}/bin/vcover"
if [[ ! -x "${VCOVER}" ]]; then
  VCOVER="${QUESTA_HOME}/linux_x86_64/vcover"
fi
if [[ ! -x "${VCOVER}" ]]; then
  echo "vcover not found under ${QUESTA_HOME}" >&2
  exit 1
fi

FULL_REPLAY_DIR="${REF_DIR}/out"
SMOKE_REPLAY_DIR="${REF_DIR}/out_smoke"

run_uvm_cov() {
  local name="$1"
  local sim_args="$2"
  make -C "${UVM_DIR}" \
    COV=1 \
    RUN_LOG="${LOG_DIR}/${name}.log" \
    COV_UCDB="${COV_DIR}/${name}.ucdb" \
    SIM_ARGS="${sim_args}" \
    run_cov
}

run_plain_cov() {
  local name="$1"
  local target="$2"
  make -C "${PLAIN_DIR}" \
    COV=1 \
    RUN_LOG="${LOG_DIR}/${name}.log" \
    RUN_LOG_SMOKE="${LOG_DIR}/${name}.log" \
    COV_UCDB="${COV_DIR}/${name}.ucdb" \
    COV_UCDB_SMOKE="${COV_DIR}/${name}.ucdb" \
    "${target}"
}

run_plain_2env_cov() {
  local name="$1"
  local target="$2"
  make -C "${PLAIN_2ENV_DIR}" \
    COV=1 \
    RUN_LOG="${LOG_DIR}/${name}.log" \
    RUN_LOG_SMOKE="${LOG_DIR}/${name}.log" \
    COV_UCDB="${COV_DIR}/${name}.ucdb" \
    COV_UCDB_SMOKE="${COV_DIR}/${name}.ucdb" \
    "${target}"
}

merge_ucdb() {
  local output="$1"
  shift
  rm -f "${output}"
  "${VCOVER}" merge "${output}" "$@"
}

rm -rf "${LOG_DIR}" "${COV_DIR}"
mkdir -p "${LOG_DIR}" "${COV_DIR}"

make -C "${REPO_ROOT}" ip-tlm-basic-smoke
make -C "${REPO_ROOT}" ip-tlm-basic

run_uvm_cov "uvm_smoke" "+SWB_REPLAY_DIR=${SMOKE_REPLAY_DIR}"
run_uvm_cov "uvm_full" "+SWB_REPLAY_DIR=${FULL_REPLAY_DIR}"
run_uvm_cov "uvm_random_default" ""
run_uvm_cov "uvm_lane_mask" "+SWB_PROFILE_NAME=B046_lane0_only +SWB_CASE_SEED=4242 +SWB_FEB_ENABLE_MASK=1 +SWB_SAT0=0.20 +SWB_SAT1=0.40 +SWB_SAT2=0.60 +SWB_SAT3=0.80"
run_uvm_cov "uvm_zero_payload" "+SWB_PROFILE_NAME=E025_zero_hit +SWB_CASE_SEED=111 +SWB_HIT_MODE=zero +SWB_SAT0=0.20 +SWB_SAT1=0.20 +SWB_SAT2=0.20 +SWB_SAT3=0.20"
run_uvm_cov "uvm_single_hit" "+SWB_PROFILE_NAME=E026_single_hit +SWB_CASE_SEED=112 +SWB_FRAMES=1 +SWB_HIT_MODE=single +SWB_SAT0=0.20 +SWB_SAT1=0.20 +SWB_SAT2=0.20 +SWB_SAT3=0.20"
run_uvm_cov "uvm_max_hit" "+SWB_PROFILE_NAME=E027_max_hit_lane0_only +SWB_CASE_SEED=113 +SWB_FRAMES=1 +SWB_HIT_MODE=max +SWB_FEB_ENABLE_MASK=1 +SWB_SAT0=0.20 +SWB_SAT1=0.20 +SWB_SAT2=0.20 +SWB_SAT3=0.20"
run_uvm_cov "uvm_dma_half_full_50" "+SWB_PROFILE_NAME=P040_dma_half_full_50 +SWB_CASE_SEED=5151 +SWB_DMA_HALF_FULL_PCT=50 +SWB_SAT0=0.20 +SWB_SAT1=0.20 +SWB_SAT2=0.20 +SWB_SAT3=0.20"

run_plain_cov "plain_smoke" "run_cov_smoke"
run_plain_cov "plain_full" "run_cov"

run_plain_2env_cov "plain_2env_smoke" "run_cov_smoke"
run_plain_2env_cov "plain_2env_full" "run_cov"

merge_ucdb \
  "${COV_DIR}/uvm_merged.ucdb" \
  "${COV_DIR}/uvm_smoke.ucdb" \
  "${COV_DIR}/uvm_full.ucdb" \
  "${COV_DIR}/uvm_random_default.ucdb" \
  "${COV_DIR}/uvm_lane_mask.ucdb" \
  "${COV_DIR}/uvm_zero_payload.ucdb" \
  "${COV_DIR}/uvm_single_hit.ucdb" \
  "${COV_DIR}/uvm_max_hit.ucdb" \
  "${COV_DIR}/uvm_dma_half_full_50.ucdb"

merge_ucdb \
  "${COV_DIR}/plain_merged.ucdb" \
  "${COV_DIR}/plain_smoke.ucdb" \
  "${COV_DIR}/plain_full.ucdb"

merge_ucdb \
  "${COV_DIR}/plain_2env_merged.ucdb" \
  "${COV_DIR}/plain_2env_smoke.ucdb" \
  "${COV_DIR}/plain_2env_full.ucdb"

merge_ucdb \
  "${COV_DIR}/tb_int_merged.ucdb" \
  "${COV_DIR}/uvm_merged.ucdb" \
  "${COV_DIR}/plain_merged.ucdb" \
  "${COV_DIR}/plain_2env_merged.ucdb"

python3 "${TB_DIR}/scripts/build_dv_report_json.py" --tb "${TB_DIR}"
python3 "${TB_DIR}/scripts/dv_report_gen.py" --tb "${TB_DIR}"

echo "coverage closure artifacts written under ${COV_DIR}"
