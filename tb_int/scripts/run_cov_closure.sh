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
REF_COV_DIR="${REF_DIR}/cov_closure"

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
CLOSURE_KEEP_LOGS="${CLOSURE_KEEP_LOGS:-0}"
CLOSURE_RESUME="${CLOSURE_RESUME:-0}"

case_run_log() {
  local name="$1"
  if [[ "${CLOSURE_KEEP_LOGS}" == "1" ]]; then
    echo "${LOG_DIR}/${name}.log"
  else
    echo "/dev/null"
  fi
}

run_make_case() {
  if [[ "${CLOSURE_KEEP_LOGS}" == "1" ]]; then
    "$@"
  else
    "$@" >/dev/null
  fi
}

reuse_ucdb() {
  local ucdb="$1"
  [[ "${CLOSURE_RESUME}" == "1" && -s "${ucdb}" ]]
}

run_uvm_cov() {
  local name="$1"
  local swb_use_merge="$2"
  local sim_args="$3"
  local run_log
  local ucdb="${COV_DIR}/${name}.ucdb"
  if reuse_ucdb "${ucdb}"; then
    echo "[reuse] ${name}" >&2
    return
  fi
  run_log="$(case_run_log "${name}")"
  run_make_case make -C "${UVM_DIR}" \
    COV=1 \
    SWB_USE_MERGE="${swb_use_merge}" \
    RUN_LOG="${run_log}" \
    COV_UCDB="${ucdb}" \
    SIM_ARGS="${sim_args}" \
    run_cov
}

run_plain_cov() {
  local name="$1"
  local target="$2"
  local run_log
  local ucdb="${COV_DIR}/${name}.ucdb"
  if reuse_ucdb "${ucdb}"; then
    echo "[reuse] ${name}" >&2
    return
  fi
  run_log="$(case_run_log "${name}")"
  run_make_case make -C "${PLAIN_DIR}" \
    COV=1 \
    RUN_LOG="${run_log}" \
    RUN_LOG_SMOKE="${run_log}" \
    COV_UCDB="${ucdb}" \
    COV_UCDB_SMOKE="${ucdb}" \
    "${target}"
}

run_plain_2env_cov() {
  local name="$1"
  local target="$2"
  local run_log
  local ucdb="${COV_DIR}/${name}.ucdb"
  if reuse_ucdb "${ucdb}"; then
    echo "[reuse] ${name}" >&2
    return
  fi
  run_log="$(case_run_log "${name}")"
  run_make_case make -C "${PLAIN_2ENV_DIR}" \
    COV=1 \
    RUN_LOG="${run_log}" \
    RUN_LOG_SMOKE="${run_log}" \
    COV_UCDB="${ucdb}" \
    COV_UCDB_SMOKE="${ucdb}" \
    "${target}"
}

merge_ucdb() {
  local output="$1"
  shift
  rm -f "${output}"
  "${VCOVER}" merge "${output}" "$@"
}

run_uvm_case() {
  local name="$1"
  local swb_use_merge="$2"
  local sim_args="$3"
  echo "[uvm] ${name}" >&2
  uvm_ucdbs+=("${COV_DIR}/${name}.ucdb")
  run_uvm_cov "${name}" "${swb_use_merge}" "${sim_args}"
}

run_ref_case() {
  local name="$1"
  shift
  local out_dir="${REF_COV_DIR}/${name}"
  echo "[ref] ${name}" >&2
  rm -rf "${out_dir}"
  python3 "${REF_DIR}/run_basic_ref.py" --out-dir "${out_dir}" "$@"
}

run_control_ref_case() {
  local name="$1"
  local out_dir="${REF_COV_DIR}/${name}"
  echo "[ref] ${name}" >&2
  rm -rf "${out_dir}"
  python3 "${REF_DIR}/gen_control_replay.py" --out-dir "${out_dir}"
}

run_error_ref_case() {
  local name="$1"
  local profile="$2"
  local out_dir="${REF_COV_DIR}/${name}"
  echo "[ref] ${name}" >&2
  rm -rf "${out_dir}"
  python3 "${REF_DIR}/gen_error_replay.py" --profile "${profile}" --out-dir "${out_dir}"
}

run_plain_replay_case() {
  local name="$1"
  local replay_dir="$2"
  local use_merge="$3"
  local feb_enable_mask_hex="$4"
  local lookup_ctrl_hex="$5"
  local dma_half_full_period_cycles="$6"
  local dma_half_full_assert_cycles="$7"
  local run_log
  local ucdb="${COV_DIR}/${name}.ucdb"
  run_log="$(case_run_log "${name}")"
  echo "[plain] ${name}" >&2
  plain_ucdbs+=("${COV_DIR}/${name}.ucdb")
  if reuse_ucdb "${ucdb}"; then
    echo "[reuse] ${name}" >&2
    return
  fi
  run_make_case make -C "${PLAIN_DIR}" \
    COV=1 \
    RUN_LOG="${run_log}" \
    REPLAY_DIR="${replay_dir}" \
    USE_MERGE="${use_merge}" \
    FEB_ENABLE_MASK_HEX="${feb_enable_mask_hex}" \
    LOOKUP_CTRL_HEX="${lookup_ctrl_hex}" \
    DMA_HALF_FULL_PERIOD_CYCLES="${dma_half_full_period_cycles}" \
    DMA_HALF_FULL_ASSERT_CYCLES="${dma_half_full_assert_cycles}" \
    COV_UCDB="${ucdb}" \
    run_cov
}

run_plain_2env_replay_case() {
  local name="$1"
  local replay_dir="$2"
  local sim_args="$3"
  local run_log
  local ucdb="${COV_DIR}/${name}.ucdb"
  run_log="$(case_run_log "${name}")"
  echo "[plain_2env] ${name}" >&2
  plain_2env_ucdbs+=("${COV_DIR}/${name}.ucdb")
  if reuse_ucdb "${ucdb}"; then
    echo "[reuse] ${name}" >&2
    return
  fi
  run_make_case make -C "${PLAIN_2ENV_DIR}" \
    COV=1 \
    RUN_LOG="${run_log}" \
    REPLAY_DIR="${replay_dir}" \
    COV_UCDB="${ucdb}" \
    SIM_ARGS="${sim_args}" \
    run_cov
}

if [[ "${CLOSURE_RESUME}" != "1" ]]; then
  rm -rf "${LOG_DIR}" "${COV_DIR}"
  rm -rf "${REF_COV_DIR}"
fi
mkdir -p "${LOG_DIR}" "${COV_DIR}"

if [[ "${CLOSURE_RESUME}" == "1" && -d "${SMOKE_REPLAY_DIR}" && -d "${FULL_REPLAY_DIR}" ]]; then
  echo "[reuse] promoted replay bundles" >&2
else
  make -C "${REPO_ROOT}" ip-tlm-basic-smoke
  make -C "${REPO_ROOT}" ip-tlm-basic
fi

uvm_ucdbs=()
LOOKUP_WORD_L0="007ffe80"
LOOKUP_WORD_L1="007ffe91"
LOOKUP_WORD_L2="007ffea2"
LOOKUP_WORD_L3="007ffeb3"
LOOKUP_WORD_INVALID="00000180"
POISSON_SAT="+SWB_SAT0=0.75 +SWB_SAT1=0.75 +SWB_SAT2=0.75 +SWB_SAT3=0.75"

run_uvm_case "uvm_smoke" 1 "+SWB_REPLAY_DIR=${SMOKE_REPLAY_DIR}"
run_uvm_case "uvm_full" 1 "+SWB_REPLAY_DIR=${FULL_REPLAY_DIR}"

run_uvm_case "uvm_cov_p0_bp0_m1" 1 "+SWB_PROFILE_NAME=cov_p0_bp0_m1 +SWB_CASE_SEED=1001 +SWB_FRAMES=1 +SWB_SUBHEADERS=4 +SWB_FEB_ENABLE_MASK=1 +SWB_HIT_MODE=zero +SWB_DMA_HALF_FULL_PCT=0"
run_uvm_case "uvm_cov_p0_bp10_m0" 0 "+SWB_PROFILE_NAME=cov_p0_bp10_m0 +SWB_CASE_SEED=1002 +SWB_FRAMES=1 +SWB_SUBHEADERS=4 +SWB_FEB_ENABLE_MASK=3 +SWB_HIT_MODE=zero +SWB_DMA_HALF_FULL_PCT=10 +SWB_LANE1_SKEW_CYC=1"
run_uvm_case "uvm_cov_p0_bp40_m1" 1 "+SWB_PROFILE_NAME=cov_p0_bp40_m1 +SWB_CASE_SEED=1003 +SWB_FRAMES=1 +SWB_SUBHEADERS=4 +SWB_FEB_ENABLE_MASK=7 +SWB_HIT_MODE=zero +SWB_DMA_HALF_FULL_PCT=40 +SWB_LANE1_SKEW_CYC=128"
run_uvm_case "uvm_cov_p0_bp75_m0" 0 "+SWB_PROFILE_NAME=cov_p0_bp75_m0 +SWB_CASE_SEED=1004 +SWB_FRAMES=1 +SWB_SUBHEADERS=4 +SWB_FEB_ENABLE_MASK=f +SWB_HIT_MODE=zero +SWB_DMA_HALF_FULL_PCT=75 +SWB_LANE3_SKEW_CYC=768"

run_uvm_case "uvm_cov_p1_bp0_m1" 1 "+SWB_PROFILE_NAME=cov_p1_bp0_m1 +SWB_CASE_SEED=1011 +SWB_FRAMES=1 +SWB_SUBHEADERS=4 +SWB_FEB_ENABLE_MASK=2 +SWB_HIT_MODE=single +SWB_DMA_HALF_FULL_PCT=0 +SWB_LOOKUP_CTRL_WORD=${LOOKUP_WORD_L1} +SWB_LANE1_SKEW_CYC=1536"
run_uvm_case "uvm_cov_p1_bp10_m0" 0 "+SWB_PROFILE_NAME=cov_p1_bp10_m0 +SWB_CASE_SEED=1012 +SWB_FRAMES=1 +SWB_SUBHEADERS=1 +SWB_FEB_ENABLE_MASK=4 +SWB_HIT_MODE=max +SWB_DMA_HALF_FULL_PCT=10 +SWB_LOOKUP_CTRL_WORD=${LOOKUP_WORD_L2} +SWB_LANE_SKEW_VARYING=1 +SWB_LANE_SKEW_MAX_CYC=64"
run_uvm_case "uvm_cov_p1_bp40_m0" 0 "+SWB_PROFILE_NAME=cov_p1_bp40_m0 +SWB_CASE_SEED=1013 +SWB_FRAMES=1 +SWB_SUBHEADERS=4 +SWB_FEB_ENABLE_MASK=8 +SWB_HIT_MODE=single +SWB_DMA_HALF_FULL_PCT=40 +SWB_LOOKUP_CTRL_WORD=${LOOKUP_WORD_L3} +SWB_LANE_SKEW_VARYING=1 +SWB_LANE_SKEW_MAX_CYC=1024"
run_uvm_case "uvm_cov_p1_bp75_m1" 1 "+SWB_PROFILE_NAME=cov_p1_bp75_m1 +SWB_CASE_SEED=1014 +SWB_FRAMES=1 +SWB_SUBHEADERS=4 +SWB_FEB_ENABLE_MASK=1 +SWB_HIT_MODE=single +SWB_DMA_HALF_FULL_PCT=75 +SWB_LOOKUP_CTRL_WORD=${LOOKUP_WORD_L0}"

run_uvm_case "uvm_cov_ps_bp0_m1" 1 "+SWB_PROFILE_NAME=cov_ps_bp0_m1 +SWB_CASE_SEED=1021 +SWB_FRAMES=1 +SWB_SUBHEADERS=4 +SWB_FEB_ENABLE_MASK=3 +SWB_HIT_MODE=single +SWB_DMA_HALF_FULL_PCT=0 +SWB_LANE1_SKEW_CYC=3072"
run_uvm_case "uvm_cov_ps_bp10_m0" 0 "+SWB_PROFILE_NAME=cov_ps_bp10_m0 +SWB_CASE_SEED=1022 +SWB_FRAMES=1 +SWB_SUBHEADERS=4 +SWB_FEB_ENABLE_MASK=5 +SWB_HIT_MODE=single +SWB_DMA_HALF_FULL_PCT=10 +SWB_LANE_SKEW_VARYING=1 +SWB_LANE_SKEW_MAX_CYC=2048"
run_uvm_case "uvm_cov_ps_bp40_m1" 1 "+SWB_PROFILE_NAME=cov_ps_bp40_m1 +SWB_CASE_SEED=1023 +SWB_FRAMES=1 +SWB_SUBHEADERS=4 +SWB_FEB_ENABLE_MASK=9 +SWB_HIT_MODE=single +SWB_DMA_HALF_FULL_PCT=40 +SWB_LANE_SKEW_VARYING=1 +SWB_LANE_SKEW_MAX_CYC=3072"
run_uvm_case "uvm_cov_ps_bp75_m0" 0 "+SWB_PROFILE_NAME=cov_ps_bp75_m0 +SWB_CASE_SEED=1024 +SWB_FRAMES=1 +SWB_SUBHEADERS=4 +SWB_FEB_ENABLE_MASK=c +SWB_HIT_MODE=single +SWB_DMA_HALF_FULL_PCT=75"

run_uvm_case "uvm_cov_pm_bp0_m1" 1 "+SWB_PROFILE_NAME=cov_pm_bp0_m1 +SWB_CASE_SEED=1031 +SWB_FRAMES=1 +SWB_SUBHEADERS=8 +SWB_FEB_ENABLE_MASK=7 +SWB_HIT_MODE=single +SWB_DMA_HALF_FULL_PCT=0"
run_uvm_case "uvm_cov_pm_bp10_m0" 0 "+SWB_PROFILE_NAME=cov_pm_bp10_m0 +SWB_CASE_SEED=1032 +SWB_FRAMES=1 +SWB_SUBHEADERS=8 +SWB_FEB_ENABLE_MASK=b +SWB_HIT_MODE=single +SWB_DMA_HALF_FULL_PCT=10 +SWB_LANE1_SKEW_CYC=1"
run_uvm_case "uvm_cov_pm_bp40_m1" 1 "+SWB_PROFILE_NAME=cov_pm_bp40_m1 +SWB_CASE_SEED=1033 +SWB_FRAMES=1 +SWB_SUBHEADERS=8 +SWB_FEB_ENABLE_MASK=d +SWB_HIT_MODE=single +SWB_DMA_HALF_FULL_PCT=40 +SWB_LANE2_SKEW_CYC=128"
run_uvm_case "uvm_cov_pm_bp75_m0" 0 "+SWB_PROFILE_NAME=cov_pm_bp75_m0 +SWB_CASE_SEED=1034 +SWB_FRAMES=1 +SWB_SUBHEADERS=8 +SWB_FEB_ENABLE_MASK=e +SWB_HIT_MODE=single +SWB_DMA_HALF_FULL_PCT=75 +SWB_LANE3_SKEW_CYC=768"

run_uvm_case "uvm_cov_pl_bp0_m1" 1 "+SWB_PROFILE_NAME=cov_pl_bp0_m1 +SWB_CASE_SEED=1041 +SWB_FRAMES=2 +SWB_SUBHEADERS=128 +SWB_FEB_ENABLE_MASK=f +SWB_HIT_MODE=single +SWB_DMA_HALF_FULL_PCT=0"
run_uvm_case "uvm_cov_pl_bp10_m0" 0 "+SWB_PROFILE_NAME=cov_pl_bp10_m0 +SWB_CASE_SEED=1042 +SWB_FRAMES=2 +SWB_SUBHEADERS=128 +SWB_FEB_ENABLE_MASK=f +SWB_HIT_MODE=single +SWB_DMA_HALF_FULL_PCT=10 +SWB_LANE_SKEW_VARYING=1 +SWB_LANE_SKEW_MAX_CYC=512"
run_uvm_case "uvm_cov_pl_bp40_m1" 1 "+SWB_PROFILE_NAME=cov_pl_bp40_m1 +SWB_CASE_SEED=1043 +SWB_FRAMES=2 +SWB_SUBHEADERS=128 +SWB_FEB_ENABLE_MASK=f +SWB_HIT_MODE=single +SWB_DMA_HALF_FULL_PCT=40 +SWB_LANE_SKEW_VARYING=1 +SWB_LANE_SKEW_MAX_CYC=1024"
run_uvm_case "uvm_cov_pl_bp75_m0" 0 "+SWB_PROFILE_NAME=cov_pl_bp75_m0 +SWB_CASE_SEED=1044 +SWB_FRAMES=2 +SWB_SUBHEADERS=128 +SWB_FEB_ENABLE_MASK=f +SWB_HIT_MODE=single +SWB_DMA_HALF_FULL_PCT=75 +SWB_LANE_SKEW_VARYING=1 +SWB_LANE_SKEW_MAX_CYC=3072"

run_uvm_case "uvm_cov_lane1_poisson" 0 "+SWB_PROFILE_NAME=cov_lane1_poisson +SWB_CASE_SEED=1051 +SWB_FRAMES=1 +SWB_SUBHEADERS=8 +SWB_FEB_ENABLE_MASK=2 +SWB_HIT_MODE=poisson +SWB_LOOKUP_CTRL_WORD=${LOOKUP_WORD_L1} ${POISSON_SAT}"
run_uvm_case "uvm_cov_lane2_max" 0 "+SWB_PROFILE_NAME=cov_lane2_max +SWB_CASE_SEED=1052 +SWB_FRAMES=1 +SWB_SUBHEADERS=2 +SWB_FEB_ENABLE_MASK=3 +SWB_HIT_MODE=max"
run_uvm_case "uvm_cov_lane2_poisson" 1 "+SWB_PROFILE_NAME=cov_lane2_poisson +SWB_CASE_SEED=1053 +SWB_FRAMES=1 +SWB_SUBHEADERS=8 +SWB_FEB_ENABLE_MASK=5 +SWB_HIT_MODE=poisson ${POISSON_SAT}"
run_uvm_case "uvm_cov_lane3_max" 1 "+SWB_PROFILE_NAME=cov_lane3_max +SWB_CASE_SEED=1054 +SWB_FRAMES=1 +SWB_SUBHEADERS=1 +SWB_FEB_ENABLE_MASK=7 +SWB_HIT_MODE=max"
run_uvm_case "uvm_cov_lane3_poisson" 0 "+SWB_PROFILE_NAME=cov_lane3_poisson +SWB_CASE_SEED=1055 +SWB_FRAMES=1 +SWB_SUBHEADERS=8 +SWB_FEB_ENABLE_MASK=b +SWB_HIT_MODE=poisson ${POISSON_SAT}"
run_uvm_case "uvm_cov_lane4_max" 1 "+SWB_PROFILE_NAME=cov_lane4_max +SWB_CASE_SEED=1056 +SWB_FRAMES=1 +SWB_SUBHEADERS=1 +SWB_FEB_ENABLE_MASK=f +SWB_HIT_MODE=max"
run_uvm_case "uvm_cov_lane4_poisson" 0 "+SWB_PROFILE_NAME=cov_lane4_poisson +SWB_CASE_SEED=1057 +SWB_FRAMES=1 +SWB_SUBHEADERS=8 +SWB_FEB_ENABLE_MASK=f +SWB_HIT_MODE=poisson ${POISSON_SAT}"
run_uvm_case "uvm_cov_short_varying_f4" 1 "+SWB_PROFILE_NAME=cov_short_varying_f4 +SWB_CASE_SEED=1061 +SWB_FRAMES=4 +SWB_SUBHEADERS=8 +SWB_FEB_ENABLE_MASK=f +SWB_HIT_MODE=single +SWB_DMA_HALF_FULL_PCT=25 +SWB_LANE_SKEW_VARYING=1 +SWB_LANE_SKEW_MAX_CYC=64"
run_uvm_case "uvm_cov_half_varying_f10" 0 "+SWB_PROFILE_NAME=cov_half_varying_f10 +SWB_CASE_SEED=1062 +SWB_FRAMES=10 +SWB_SUBHEADERS=8 +SWB_FEB_ENABLE_MASK=f +SWB_HIT_MODE=single +SWB_DMA_HALF_FULL_PCT=50 +SWB_LANE_SKEW_VARYING=1 +SWB_LANE_SKEW_MAX_CYC=2048"
run_uvm_case "uvm_cov_heavy_fixed_skew" 1 "+SWB_PROFILE_NAME=cov_heavy_fixed_skew +SWB_CASE_SEED=5001 +SWB_FRAMES=16 +SWB_SUBHEADERS=128 +SWB_FEB_ENABLE_MASK=f +SWB_HIT_MODE=single +SWB_SAT0=0.25 +SWB_SAT1=0.25 +SWB_SAT2=0.25 +SWB_SAT3=0.25 +SWB_LANE0_SKEW_CYC=0 +SWB_LANE1_SKEW_CYC=512 +SWB_LANE2_SKEW_CYC=1024 +SWB_LANE3_SKEW_CYC=2048"
run_uvm_case "uvm_cov_heavy_varying_bp" 0 "+SWB_PROFILE_NAME=cov_heavy_varying_bp +SWB_CASE_SEED=5002 +SWB_FRAMES=16 +SWB_SUBHEADERS=128 +SWB_FEB_ENABLE_MASK=f +SWB_HIT_MODE=single +SWB_SAT0=0.25 +SWB_SAT1=0.25 +SWB_SAT2=0.25 +SWB_SAT3=0.25 +SWB_DMA_HALF_FULL_PCT=75 +SWB_LANE_SKEW_VARYING=1 +SWB_LANE_SKEW_MAX_CYC=2048"
run_uvm_case "uvm_cov_heavy_max_fixed" 1 "+SWB_PROFILE_NAME=cov_heavy_max_fixed +SWB_CASE_SEED=5003 +SWB_FRAMES=16 +SWB_SUBHEADERS=32 +SWB_FEB_ENABLE_MASK=f +SWB_HIT_MODE=max +SWB_SAT0=0.25 +SWB_SAT1=0.25 +SWB_SAT2=0.25 +SWB_SAT3=0.25 +SWB_LANE0_SKEW_CYC=0 +SWB_LANE1_SKEW_CYC=512 +SWB_LANE2_SKEW_CYC=1024 +SWB_LANE3_SKEW_CYC=2048"
run_uvm_case "uvm_cov_heavy_max_varying_bp" 0 "+SWB_PROFILE_NAME=cov_heavy_max_varying_bp +SWB_CASE_SEED=5004 +SWB_FRAMES=16 +SWB_SUBHEADERS=32 +SWB_FEB_ENABLE_MASK=f +SWB_HIT_MODE=max +SWB_SAT0=0.25 +SWB_SAT1=0.25 +SWB_SAT2=0.25 +SWB_SAT3=0.25 +SWB_DMA_HALF_FULL_PCT=75 +SWB_LANE_SKEW_VARYING=1 +SWB_LANE_SKEW_MAX_CYC=2048"
run_uvm_case "uvm_cov_heavy_poisson_fixed" 1 "+SWB_PROFILE_NAME=cov_heavy_poisson_fixed +SWB_CASE_SEED=5005 +SWB_FRAMES=16 +SWB_SUBHEADERS=64 +SWB_FEB_ENABLE_MASK=f +SWB_HIT_MODE=poisson +SWB_SAT0=0.75 +SWB_SAT1=0.75 +SWB_SAT2=0.75 +SWB_SAT3=0.75 +SWB_LANE0_SKEW_CYC=0 +SWB_LANE1_SKEW_CYC=256 +SWB_LANE2_SKEW_CYC=1024 +SWB_LANE3_SKEW_CYC=3072"
run_uvm_case "uvm_cov_heavy_poisson_varying_bp" 0 "+SWB_PROFILE_NAME=cov_heavy_poisson_varying_bp +SWB_CASE_SEED=5006 +SWB_FRAMES=16 +SWB_SUBHEADERS=64 +SWB_FEB_ENABLE_MASK=f +SWB_HIT_MODE=poisson +SWB_SAT0=0.75 +SWB_SAT1=0.75 +SWB_SAT2=0.75 +SWB_SAT3=0.75 +SWB_DMA_HALF_FULL_PCT=75 +SWB_LANE_SKEW_VARYING=1 +SWB_LANE_SKEW_MAX_CYC=3072"
run_uvm_case "uvm_gain_slot_max_f32_fixed" 1 "+SWB_PROFILE_NAME=uvm_gain_slot_max_f32_fixed +SWB_CASE_SEED=6104 +SWB_FRAMES=32 +SWB_SUBHEADERS=64 +SWB_HIT_MODE=max +SWB_FRAME_SLOT_CYCLES=2048 +SWB_LANE0_SKEW_CYC=0 +SWB_LANE1_SKEW_CYC=512 +SWB_LANE2_SKEW_CYC=1024 +SWB_LANE3_SKEW_CYC=1536"
run_uvm_case "uvm_gain_slot_single_f64_fixed" 1 "+SWB_PROFILE_NAME=uvm_gain_slot_single_f64_fixed +SWB_CASE_SEED=6102 +SWB_FRAMES=64 +SWB_SUBHEADERS=128 +SWB_HIT_MODE=single +SWB_FRAME_SLOT_CYCLES=2048 +SWB_LANE0_SKEW_CYC=0 +SWB_LANE1_SKEW_CYC=512 +SWB_LANE2_SKEW_CYC=1024 +SWB_LANE3_SKEW_CYC=1536"
plain_ucdbs=()
run_plain_cov "plain_smoke" "run_cov_smoke"
run_plain_cov "plain_full" "run_cov"

plain_ucdbs+=("${COV_DIR}/plain_smoke.ucdb" "${COV_DIR}/plain_full.ucdb")

run_ref_case "zero_hit" --frames 1 --subheaders 4 --hit-mode zero --feb-enable-mask F
run_ref_case "oneword_lookup" --frames 1 --subheaders 1 --hit-mode single --feb-enable-mask F --seed 3001
run_ref_case "mask3_short" --frames 4 --subheaders 8 --hit-mode single --feb-enable-mask 3 --seed 3002 --sat 0.20 0.20 0.20 0.20
run_ref_case "mask5_max" --frames 3 --subheaders 8 --hit-mode max --feb-enable-mask 5 --seed 3003 --sat 0.20 0.20 0.20 0.20
run_ref_case "maskf_bpheavy" --frames 4 --subheaders 32 --hit-mode max --feb-enable-mask F --seed 3004 --sat 0.20 0.20 0.20 0.20
run_control_ref_case "control_combo"
run_error_ref_case "hdr_err_recover" "hdr_err_recover"
run_error_ref_case "subhdr_err_recover" "subhdr_err_recover"
run_error_ref_case "hit_err_recover" "hit_err_recover"
run_error_ref_case "midhit_shderr_recover" "midhit_shderr_recover"

run_plain_replay_case "plain_cov_zero_hit" "${REF_COV_DIR}/zero_hit" 1 "F" "00000000" 0 0
run_plain_replay_case "plain_cov_oneword_lookup" "${REF_COV_DIR}/oneword_lookup" 1 "F" "${LOOKUP_WORD_L0}" 0 0
run_plain_replay_case "plain_cov_oneword_invalid_lookup" "${REF_COV_DIR}/oneword_lookup" 1 "F" "${LOOKUP_WORD_INVALID}" 0 0
run_plain_replay_case "plain_cov_mask3_short" "${REF_COV_DIR}/mask3_short" 1 "3" "${LOOKUP_WORD_L1}" 0 0
run_plain_replay_case "plain_cov_mask5_max" "${REF_COV_DIR}/mask5_max" 1 "5" "${LOOKUP_WORD_L2}" 0 0
run_plain_replay_case "plain_cov_maskf_bpheavy" "${REF_COV_DIR}/maskf_bpheavy" 1 "F" "${LOOKUP_WORD_L3}" 2 1
run_plain_replay_case "plain_cov_control_combo" "${REF_COV_DIR}/control_combo" 0 "F" "00000000" 0 0
run_plain_replay_case "plain_cov_control_combo_invalid_lookup" "${REF_COV_DIR}/control_combo" 0 "F" "${LOOKUP_WORD_INVALID}" 0 0
run_plain_replay_case "plain_cov_hdr_err_recover" "${REF_COV_DIR}/hdr_err_recover" 1 "F" "00000000" 0 0
run_plain_replay_case "plain_cov_subhdr_err_recover" "${REF_COV_DIR}/subhdr_err_recover" 1 "F" "00000000" 0 0
run_plain_replay_case "plain_cov_hit_err_recover" "${REF_COV_DIR}/hit_err_recover" 1 "F" "00000000" 0 0
run_plain_replay_case "plain_cov_midhit_shderr_recover" "${REF_COV_DIR}/midhit_shderr_recover" 1 "F" "00000000" 0 0

plain_2env_ucdbs=()
run_plain_2env_cov "plain_2env_smoke" "run_cov_smoke"
run_plain_2env_cov "plain_2env_full" "run_cov"
plain_2env_ucdbs+=("${COV_DIR}/plain_2env_smoke.ucdb" "${COV_DIR}/plain_2env_full.ucdb")

run_plain_2env_replay_case "plain_2env_cov_zero_hit" "${REF_COV_DIR}/zero_hit" ""
run_plain_2env_replay_case "plain_2env_cov_oneword_lookup" "${REF_COV_DIR}/oneword_lookup" "+SWB_LOOKUP_CTRL_WORD=${LOOKUP_WORD_L0}"
run_plain_2env_replay_case "plain_2env_cov_mask3_short" "${REF_COV_DIR}/mask3_short" "+SWB_LOOKUP_CTRL_WORD=${LOOKUP_WORD_L1}"
run_plain_2env_replay_case "plain_2env_cov_mask5_max_bp" "${REF_COV_DIR}/mask5_max" "+SWB_LOOKUP_CTRL_WORD=${LOOKUP_WORD_L2} +SWB_DMA_HALF_FULL_PCT=25 +SWB_DMA_HALF_FULL_SEED=3005"
run_plain_2env_replay_case "plain_2env_cov_maskf_bpheavy" "${REF_COV_DIR}/maskf_bpheavy" "+SWB_LOOKUP_CTRL_WORD=${LOOKUP_WORD_L3} +SWB_DMA_HALF_FULL_PCT=50 +SWB_DMA_HALF_FULL_SEED=3006"
run_plain_2env_replay_case "plain_2env_cov_invalid_lookup" "${REF_COV_DIR}/oneword_lookup" "+SWB_LOOKUP_CTRL_WORD=${LOOKUP_WORD_INVALID}"

merge_ucdb \
  "${COV_DIR}/uvm_merged.ucdb" \
  "${uvm_ucdbs[@]}"

merge_ucdb \
  "${COV_DIR}/plain_merged.ucdb" \
  "${plain_ucdbs[@]}"

merge_ucdb \
  "${COV_DIR}/plain_2env_merged.ucdb" \
  "${plain_2env_ucdbs[@]}"

merge_ucdb \
  "${COV_DIR}/tb_int_merged.ucdb" \
  "${COV_DIR}/uvm_merged.ucdb" \
  "${COV_DIR}/plain_merged.ucdb" \
  "${COV_DIR}/plain_2env_merged.ucdb"

python3 "${TB_DIR}/scripts/build_dv_report_json.py" --tb "${TB_DIR}"
python3 "${TB_DIR}/scripts/dv_report_gen.py" --tb "${TB_DIR}"
python3 "${HOME}/.codex/skills/rtl-doc-style/scripts/rtl_doc_style_check.py" "${TB_DIR}" "${TB_DIR}/doc"

echo "coverage closure artifacts written under ${COV_DIR}"
