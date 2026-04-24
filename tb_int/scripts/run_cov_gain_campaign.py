#!/usr/bin/env python3
"""Run measured post-closure coverage candidates one by one.

The campaign starts from an already-built current-source merged UCDB
(`tb_int/sim_runs/coverage/tb_int_merged.ucdb` by default), runs extra plain/UVM
cases sequentially, and accepts only the candidates that increase owned-scope
code coverage hits. It stops after a sustained no-gain streak.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import shutil
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any


def load_cov_module(repo_root: Path):
    module_path = repo_root / "tb_int" / "scripts" / "build_dv_report_json.py"
    spec = importlib.util.spec_from_file_location("tb_cov_builder", module_path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


@dataclass(frozen=True)
class Candidate:
    name: str
    harness: str
    description: str
    use_merge: int
    replay_profile: str | None = None
    replay_generator: str | None = None
    replay_script: str | None = None
    replay_args: tuple[str, ...] = ()
    feb_enable_mask: str = "F"
    lookup_ctrl_hex: str = "00000000"
    dma_half_full_period_cycles: int = 0
    dma_half_full_assert_cycles: int = 0
    sim_args: str = ""


@dataclass
class CandidateResult:
    name: str
    harness: str
    description: str
    accepted: bool
    gain_hits: dict[str, int]
    totals_before: dict[str, int]
    totals_after: dict[str, int]
    ucdb: str
    log: str
    replay_dir: str | None


METRIC_ORDER = ("stmt", "branch", "cond", "expr", "fsm_state", "fsm_trans", "toggle")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run measured tb_int coverage gain campaigns.")
    parser.add_argument("--tb", default="tb_int", help="Path to the tb_int root.")
    parser.add_argument(
        "--baseline-ucdb",
        default=None,
        help="Baseline merged UCDB. Defaults to <tb>/sim_runs/coverage/tb_int_merged.ucdb.",
    )
    parser.add_argument(
        "--campaign-dir",
        default=None,
        help="Directory for campaign logs, replay bundles, and accepted merges.",
    )
    parser.add_argument(
        "--no-gain-limit",
        type=int,
        default=20,
        help="Stop after this many consecutive no-gain candidates.",
    )
    parser.add_argument(
        "--max-cases",
        type=int,
        default=64,
        help="Maximum number of candidates to attempt from the ordered list.",
    )
    return parser.parse_args()


def build_candidates() -> list[Candidate]:
    candidates: list[Candidate] = [
        Candidate(
            name="plain_gain_idle_guard_mix",
            harness="plain",
            description="Idle-state K-code guards plus RC routing on all four demerge lanes",
            replay_script="gen_control_replay.py",
            replay_args=("--profile", "idle_guard_mix"),
            use_merge=0,
        ),
        Candidate(
            name="plain_gain_data_ctrl_mix",
            harness="plain",
            description="STATE_DATA control-word passthrough and RC discrimination on all demerge lanes",
            replay_script="gen_control_replay.py",
            replay_args=("--profile", "data_ctrl_mix"),
            use_merge=0,
        ),
        Candidate(
            name="plain_gain_sc_ctrl_mix",
            harness="plain",
            description="STATE_SC control-word passthrough and RC discrimination on all demerge lanes",
            replay_script="gen_control_replay.py",
            replay_args=("--profile", "sc_ctrl_mix"),
            use_merge=0,
        ),
        Candidate(
            name="plain_2env_gain_mask1_single_lookup",
            harness="plain_2env",
            description="Single enabled lane with lookup hit on lane0 for mux-side per-lane decode coverage",
            replay_script="run_basic_ref.py",
            replay_args=(
                "--frames", "8",
                "--subheaders", "32",
                "--hit-mode", "single",
                "--feb-enable-mask", "1",
                "--seed", "7201",
                "--header-kind", "mupix",
            ),
            use_merge=1,
            sim_args="+SWB_FEB_ENABLE_MASK=1 +SWB_LOOKUP_CTRL_WORD=007ffe80",
        ),
        Candidate(
            name="plain_2env_gain_mask2_single_lookup",
            harness="plain_2env",
            description="Single enabled lane with lookup hit on lane1 for mux-side per-lane decode coverage",
            replay_script="run_basic_ref.py",
            replay_args=(
                "--frames", "8",
                "--subheaders", "32",
                "--hit-mode", "single",
                "--feb-enable-mask", "2",
                "--seed", "7202",
                "--header-kind", "mupix",
            ),
            use_merge=1,
            sim_args="+SWB_FEB_ENABLE_MASK=2 +SWB_LOOKUP_CTRL_WORD=007ffe91",
        ),
        Candidate(
            name="plain_2env_gain_mask4_tile_max_bp25",
            harness="plain_2env",
            description="Single enabled tile lane with max hits and light backpressure",
            replay_script="run_basic_ref.py",
            replay_args=(
                "--frames", "8",
                "--subheaders", "16",
                "--hit-mode", "max",
                "--feb-enable-mask", "4",
                "--seed", "7203",
                "--header-kind", "tile",
            ),
            use_merge=1,
            sim_args="+SWB_FEB_ENABLE_MASK=4 +SWB_LOOKUP_CTRL_WORD=007ffea2 +SWB_DMA_HALF_FULL_PCT=25 +SWB_DMA_HALF_FULL_SEED=7203",
        ),
        Candidate(
            name="plain_2env_gain_mask8_scifi_max_bp50",
            harness="plain_2env",
            description="Single enabled SciFi lane with max hits and medium backpressure",
            replay_script="run_basic_ref.py",
            replay_args=(
                "--frames", "8",
                "--subheaders", "16",
                "--hit-mode", "max",
                "--feb-enable-mask", "8",
                "--seed", "7204",
                "--header-kind", "scifi",
            ),
            use_merge=1,
            sim_args="+SWB_FEB_ENABLE_MASK=8 +SWB_LOOKUP_CTRL_WORD=007ffeb3 +SWB_DMA_HALF_FULL_PCT=50 +SWB_DMA_HALF_FULL_SEED=7204",
        ),
        Candidate(
            name="plain_2env_gain_mask5_tile_single_bp25",
            harness="plain_2env",
            description="Two enabled tile lanes with partial-mask mux arbitration",
            replay_script="run_basic_ref.py",
            replay_args=(
                "--frames", "12",
                "--subheaders", "32",
                "--hit-mode", "single",
                "--feb-enable-mask", "5",
                "--seed", "7205",
                "--header-kind", "tile",
            ),
            use_merge=1,
            sim_args="+SWB_FEB_ENABLE_MASK=5 +SWB_LOOKUP_CTRL_WORD=007ffea2 +SWB_DMA_HALF_FULL_PCT=25 +SWB_DMA_HALF_FULL_SEED=7205",
        ),
        Candidate(
            name="plain_2env_gain_maska_scifi_single_bp25",
            harness="plain_2env",
            description="Two enabled SciFi lanes with partial-mask mux arbitration",
            replay_script="run_basic_ref.py",
            replay_args=(
                "--frames", "12",
                "--subheaders", "32",
                "--hit-mode", "single",
                "--feb-enable-mask", "A",
                "--seed", "7206",
                "--header-kind", "scifi",
            ),
            use_merge=1,
            sim_args="+SWB_FEB_ENABLE_MASK=A +SWB_LOOKUP_CTRL_WORD=007ffeb3 +SWB_DMA_HALF_FULL_PCT=25 +SWB_DMA_HALF_FULL_SEED=7206",
        ),
    ]

    seed = 6100
    uvm_specs = [
        (
            "uvm_gain_slot_single_f32_fixed",
            "Long single-hit frame slots with fixed quarter-frame skew",
            "+SWB_FRAMES=32 +SWB_SUBHEADERS=128 +SWB_HIT_MODE=single "
            "+SWB_FRAME_SLOT_CYCLES=2048 +SWB_LANE0_SKEW_CYC=0 +SWB_LANE1_SKEW_CYC=512 "
            "+SWB_LANE2_SKEW_CYC=1024 +SWB_LANE3_SKEW_CYC=1536",
        ),
        (
            "uvm_gain_slot_single_f64_fixed",
            "Deeper single-hit fixed-skew slots to keep current-frame SOP ownership alive",
            "+SWB_FRAMES=64 +SWB_SUBHEADERS=128 +SWB_HIT_MODE=single "
            "+SWB_FRAME_SLOT_CYCLES=2048 +SWB_LANE0_SKEW_CYC=0 +SWB_LANE1_SKEW_CYC=512 "
            "+SWB_LANE2_SKEW_CYC=1024 +SWB_LANE3_SKEW_CYC=1536",
        ),
        (
            "uvm_gain_slot_single_f64_varying_bp25",
            "Single-hit varying-skew slots with light downstream backpressure",
            "+SWB_FRAMES=64 +SWB_SUBHEADERS=128 +SWB_HIT_MODE=single +SWB_DMA_HALF_FULL_PCT=25 "
            "+SWB_FRAME_SLOT_CYCLES=2048 +SWB_LANE_SKEW_VARYING=1 +SWB_LANE_SKEW_MAX_CYC=1536",
        ),
        (
            "uvm_gain_slot_max_f32_fixed",
            "Max-hit medium-depth slots with fixed skew to stress busy-lane retirement",
            "+SWB_FRAMES=32 +SWB_SUBHEADERS=64 +SWB_HIT_MODE=max "
            "+SWB_FRAME_SLOT_CYCLES=2048 +SWB_LANE0_SKEW_CYC=0 +SWB_LANE1_SKEW_CYC=512 "
            "+SWB_LANE2_SKEW_CYC=1024 +SWB_LANE3_SKEW_CYC=1536",
        ),
        (
            "uvm_gain_slot_max_f64_fixed_bp25",
            "Deep max-hit fixed-skew slots with light backpressure",
            "+SWB_FRAMES=64 +SWB_SUBHEADERS=64 +SWB_HIT_MODE=max +SWB_DMA_HALF_FULL_PCT=25 "
            "+SWB_FRAME_SLOT_CYCLES=4096 +SWB_LANE0_SKEW_CYC=0 +SWB_LANE1_SKEW_CYC=1024 "
            "+SWB_LANE2_SKEW_CYC=2048 +SWB_LANE3_SKEW_CYC=3072",
        ),
        (
            "uvm_gain_slot_max_f64_varying_bp75",
            "Deep max-hit varying-skew slots with heavy backpressure",
            "+SWB_FRAMES=64 +SWB_SUBHEADERS=64 +SWB_HIT_MODE=max +SWB_DMA_HALF_FULL_PCT=75 "
            "+SWB_FRAME_SLOT_CYCLES=4096 +SWB_LANE_SKEW_VARYING=1 +SWB_LANE_SKEW_MAX_CYC=3072",
        ),
        (
            "uvm_gain_slot_poisson_asym_a_fixed",
            "Asymmetric dense/sparse poisson slots under fixed skew",
            "+SWB_FRAMES=64 +SWB_SUBHEADERS=128 +SWB_HIT_MODE=poisson "
            "+SWB_SAT0=0.95 +SWB_SAT1=0.10 +SWB_SAT2=0.95 +SWB_SAT3=0.10 "
            "+SWB_FRAME_SLOT_CYCLES=4096 +SWB_LANE0_SKEW_CYC=0 +SWB_LANE1_SKEW_CYC=1024 "
            "+SWB_LANE2_SKEW_CYC=2048 +SWB_LANE3_SKEW_CYC=3072",
        ),
        (
            "uvm_gain_slot_poisson_asym_a_varying_bp50",
            "Asymmetric dense/sparse poisson slots with varying skew and medium backpressure",
            "+SWB_FRAMES=64 +SWB_SUBHEADERS=128 +SWB_HIT_MODE=poisson +SWB_DMA_HALF_FULL_PCT=50 "
            "+SWB_SAT0=0.95 +SWB_SAT1=0.10 +SWB_SAT2=0.95 +SWB_SAT3=0.10 "
            "+SWB_FRAME_SLOT_CYCLES=4096 +SWB_LANE_SKEW_VARYING=1 +SWB_LANE_SKEW_MAX_CYC=3072",
        ),
        (
            "uvm_gain_slot_poisson_asym_b_fixed",
            "Lane-interleaved poisson asymmetry with fixed skew",
            "+SWB_FRAMES=64 +SWB_SUBHEADERS=128 +SWB_HIT_MODE=poisson "
            "+SWB_SAT0=0.05 +SWB_SAT1=0.95 +SWB_SAT2=0.15 +SWB_SAT3=0.85 "
            "+SWB_FRAME_SLOT_CYCLES=4096 +SWB_LANE0_SKEW_CYC=0 +SWB_LANE1_SKEW_CYC=1024 "
            "+SWB_LANE2_SKEW_CYC=2048 +SWB_LANE3_SKEW_CYC=3072",
        ),
        (
            "uvm_gain_slot_poisson_asym_b_varying_bp75",
            "Lane-interleaved poisson asymmetry with varying skew and heavy backpressure",
            "+SWB_FRAMES=64 +SWB_SUBHEADERS=128 +SWB_HIT_MODE=poisson +SWB_DMA_HALF_FULL_PCT=75 "
            "+SWB_SAT0=0.05 +SWB_SAT1=0.95 +SWB_SAT2=0.15 +SWB_SAT3=0.85 "
            "+SWB_FRAME_SLOT_CYCLES=4096 +SWB_LANE_SKEW_VARYING=1 +SWB_LANE_SKEW_MAX_CYC=3072",
        ),
        (
            "uvm_gain_slot_poisson_sparse_fixed",
            "Alternating active/idle poisson lanes under fixed skew",
            "+SWB_FRAMES=64 +SWB_SUBHEADERS=128 +SWB_HIT_MODE=poisson "
            "+SWB_SAT0=0.95 +SWB_SAT1=0.00 +SWB_SAT2=0.95 +SWB_SAT3=0.00 "
            "+SWB_FRAME_SLOT_CYCLES=4096 +SWB_LANE0_SKEW_CYC=0 +SWB_LANE1_SKEW_CYC=1024 "
            "+SWB_LANE2_SKEW_CYC=2048 +SWB_LANE3_SKEW_CYC=3072",
        ),
        (
            "uvm_gain_slot_poisson_sparse_varying",
            "Alternating active/idle poisson lanes with varying skew",
            "+SWB_FRAMES=64 +SWB_SUBHEADERS=128 +SWB_HIT_MODE=poisson "
            "+SWB_SAT0=0.95 +SWB_SAT1=0.00 +SWB_SAT2=0.95 +SWB_SAT3=0.00 "
            "+SWB_FRAME_SLOT_CYCLES=4096 +SWB_LANE_SKEW_VARYING=1 +SWB_LANE_SKEW_MAX_CYC=3072",
        ),
        (
            "uvm_gain_slot_poisson_dense_fixed",
            "Dense poisson traffic with fixed deep skew and frame slots",
            "+SWB_FRAMES=64 +SWB_SUBHEADERS=128 +SWB_HIT_MODE=poisson "
            "+SWB_SAT0=0.95 +SWB_SAT1=0.95 +SWB_SAT2=0.95 +SWB_SAT3=0.95 "
            "+SWB_FRAME_SLOT_CYCLES=4096 +SWB_LANE0_SKEW_CYC=0 +SWB_LANE1_SKEW_CYC=1024 "
            "+SWB_LANE2_SKEW_CYC=2048 +SWB_LANE3_SKEW_CYC=3072",
        ),
        (
            "uvm_gain_slot_poisson_dense_varying_bp75",
            "Dense poisson traffic with varying skew and heavy backpressure",
            "+SWB_FRAMES=64 +SWB_SUBHEADERS=128 +SWB_HIT_MODE=poisson +SWB_DMA_HALF_FULL_PCT=75 "
            "+SWB_SAT0=0.95 +SWB_SAT1=0.95 +SWB_SAT2=0.95 +SWB_SAT3=0.95 "
            "+SWB_FRAME_SLOT_CYCLES=4096 +SWB_LANE_SKEW_VARYING=1 +SWB_LANE_SKEW_MAX_CYC=3072",
        ),
        (
            "uvm_gain_slot_single_mask7_fixed",
            "Three-lane single-hit slots with fixed skew to test partial-frame joins",
            "+SWB_FRAMES=64 +SWB_SUBHEADERS=128 +SWB_HIT_MODE=single +SWB_FEB_ENABLE_MASK=7 "
            "+SWB_FRAME_SLOT_CYCLES=2048 +SWB_LANE0_SKEW_CYC=0 +SWB_LANE1_SKEW_CYC=512 "
            "+SWB_LANE2_SKEW_CYC=1024 +SWB_LANE3_SKEW_CYC=1536",
        ),
        (
            "uvm_gain_slot_single_maskb_fixed",
            "Alternate three-lane single-hit slots with fixed skew",
            "+SWB_FRAMES=64 +SWB_SUBHEADERS=128 +SWB_HIT_MODE=single +SWB_FEB_ENABLE_MASK=B "
            "+SWB_FRAME_SLOT_CYCLES=2048 +SWB_LANE0_SKEW_CYC=0 +SWB_LANE1_SKEW_CYC=512 "
            "+SWB_LANE2_SKEW_CYC=1024 +SWB_LANE3_SKEW_CYC=1536",
        ),
        (
            "uvm_gain_slot_max_maskd_fixed",
            "Three-lane max-hit slots with fixed skew and partial active sets",
            "+SWB_FRAMES=64 +SWB_SUBHEADERS=64 +SWB_HIT_MODE=max +SWB_FEB_ENABLE_MASK=D "
            "+SWB_FRAME_SLOT_CYCLES=4096 +SWB_LANE0_SKEW_CYC=0 +SWB_LANE1_SKEW_CYC=1024 "
            "+SWB_LANE2_SKEW_CYC=2048 +SWB_LANE3_SKEW_CYC=3072",
        ),
        (
            "uvm_gain_slot_poisson_maske_varying",
            "Three-lane poisson slots with varying skew and sparse lane rotation",
            "+SWB_FRAMES=64 +SWB_SUBHEADERS=128 +SWB_HIT_MODE=poisson +SWB_FEB_ENABLE_MASK=E "
            "+SWB_SAT0=0.00 +SWB_SAT1=0.90 +SWB_SAT2=0.30 +SWB_SAT3=0.90 "
            "+SWB_FRAME_SLOT_CYCLES=4096 +SWB_LANE_SKEW_VARYING=1 +SWB_LANE_SKEW_MAX_CYC=3072",
        ),
        (
            "uvm_gain_slot_max_f96_fixed",
            "Extra-deep max-hit fixed-skew slots to push future/past body classification",
            "+SWB_FRAMES=96 +SWB_SUBHEADERS=64 +SWB_HIT_MODE=max "
            "+SWB_FRAME_SLOT_CYCLES=4096 +SWB_LANE0_SKEW_CYC=0 +SWB_LANE1_SKEW_CYC=1024 "
            "+SWB_LANE2_SKEW_CYC=2048 +SWB_LANE3_SKEW_CYC=3072",
        ),
        (
            "uvm_gain_slot_poisson_f96_asym_a_fixed",
            "Extra-deep asymmetric poisson slots with fixed skew",
            "+SWB_FRAMES=96 +SWB_SUBHEADERS=128 +SWB_HIT_MODE=poisson "
            "+SWB_SAT0=0.95 +SWB_SAT1=0.10 +SWB_SAT2=0.95 +SWB_SAT3=0.10 "
            "+SWB_FRAME_SLOT_CYCLES=4096 +SWB_LANE0_SKEW_CYC=0 +SWB_LANE1_SKEW_CYC=1024 "
            "+SWB_LANE2_SKEW_CYC=2048 +SWB_LANE3_SKEW_CYC=3072",
        ),
        (
            "uvm_gain_slot_max_f128_fixed_sh32",
            "Long frame-serial wrap pressure with 128 fixed-skew max-hit frames",
            "+SWB_FRAMES=128 +SWB_SUBHEADERS=32 +SWB_HIT_MODE=max "
            "+SWB_FRAME_SLOT_CYCLES=2048 +SWB_LANE0_SKEW_CYC=0 +SWB_LANE1_SKEW_CYC=512 "
            "+SWB_LANE2_SKEW_CYC=1024 +SWB_LANE3_SKEW_CYC=1536",
        ),
        (
            "uvm_gain_slot_poisson_f128_dense_varying",
            "Long dense poisson slots with varying skew to stress sustained presenter turnover",
            "+SWB_FRAMES=128 +SWB_SUBHEADERS=64 +SWB_HIT_MODE=poisson "
            "+SWB_SAT0=0.95 +SWB_SAT1=0.95 +SWB_SAT2=0.95 +SWB_SAT3=0.95 "
            "+SWB_FRAME_SLOT_CYCLES=3072 +SWB_LANE_SKEW_VARYING=1 +SWB_LANE_SKEW_MAX_CYC=2048",
        ),
        (
            "uvm_gain_slot_single_f128_varying_bp50",
            "Long single-hit slots with varying skew and medium backpressure",
            "+SWB_FRAMES=128 +SWB_SUBHEADERS=128 +SWB_HIT_MODE=single +SWB_DMA_HALF_FULL_PCT=50 "
            "+SWB_FRAME_SLOT_CYCLES=2048 +SWB_LANE_SKEW_VARYING=1 +SWB_LANE_SKEW_MAX_CYC=1536",
        ),
    ]

    for name, description, sim_args in uvm_specs:
        seed += 1
        candidates.append(
            Candidate(
                name=name,
                harness="uvm",
                description=description,
                use_merge=1,
                sim_args=f"+SWB_PROFILE_NAME={name} +SWB_CASE_SEED={seed} {sim_args}",
            )
        )

    return candidates


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def run_cmd(cmd: list[str], cwd: Path, log_path: Path | None = None) -> None:
    env = os.environ.copy()
    stdout = subprocess.PIPE if log_path is None else log_path.open("w", encoding="utf-8")
    try:
        proc = subprocess.run(
            cmd,
            cwd=cwd,
            env=env,
            stdout=stdout,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
        )
    finally:
        if log_path is not None and stdout is not None:
            stdout.close()
    if proc.returncode != 0:
        raise RuntimeError(f"Command failed ({proc.returncode}): {' '.join(cmd)}")


def coverage_totals(cov_module, vcover: Path, ucdb: Path) -> dict[str, dict[str, float]]:
    cov = cov_module.code_cov_for_ucdb(vcover, ucdb)
    if cov is None:
        raise FileNotFoundError(f"Coverage UCDB missing: {ucdb}")
    return cov


def totals_hits(cov: dict[str, dict[str, float]]) -> dict[str, int]:
    return {metric: int(cov[metric]["hits"]) for metric in METRIC_ORDER}


def totals_pct(cov: dict[str, dict[str, float]]) -> dict[str, float]:
    return {metric: float(cov[metric]["pct"]) for metric in METRIC_ORDER}


def gains(before: dict[str, int], after: dict[str, int]) -> dict[str, int]:
    return {metric: after[metric] - before[metric] for metric in METRIC_ORDER}


def candidate_improves(before: dict[str, int], after: dict[str, int]) -> bool:
    return any(after[metric] > before[metric] for metric in METRIC_ORDER)


def make_plain_case(
    repo_root: Path,
    coverage_dir: Path,
    logs_dir: Path,
    replay_dir: Path,
    candidate: Candidate,
) -> tuple[Path, Path]:
    ucdb_path = coverage_dir / f"{candidate.name}.ucdb"
    log_path = logs_dir / f"{candidate.name}.log"
    cmd = [
        "make",
        "-C",
        str(repo_root / "tb_int" / "cases" / "basic" / "plain"),
        "COV=1",
        f"RUN_LOG={log_path}",
        f"REPLAY_DIR={replay_dir}",
        f"USE_MERGE={candidate.use_merge}",
        f"FEB_ENABLE_MASK_HEX={candidate.feb_enable_mask}",
        f"LOOKUP_CTRL_HEX={candidate.lookup_ctrl_hex}",
        f"DMA_HALF_FULL_PERIOD_CYCLES={candidate.dma_half_full_period_cycles}",
        f"DMA_HALF_FULL_ASSERT_CYCLES={candidate.dma_half_full_assert_cycles}",
        f"COV_UCDB={ucdb_path}",
        "run_cov",
    ]
    run_cmd(cmd, repo_root)
    return ucdb_path, log_path


def make_uvm_case(repo_root: Path, coverage_dir: Path, logs_dir: Path, candidate: Candidate) -> tuple[Path, Path]:
    ucdb_path = coverage_dir / f"{candidate.name}.ucdb"
    log_path = logs_dir / f"{candidate.name}.log"
    cmd = [
        "make",
        "-C",
        str(repo_root / "tb_int" / "cases" / "basic" / "uvm"),
        "COV=1",
        f"SWB_USE_MERGE={candidate.use_merge}",
        f"RUN_LOG={log_path}",
        f"COV_UCDB={ucdb_path}",
        f"SIM_ARGS={candidate.sim_args}",
        "run_cov",
    ]
    run_cmd(cmd, repo_root)
    return ucdb_path, log_path


def make_plain_2env_case(
    repo_root: Path,
    coverage_dir: Path,
    logs_dir: Path,
    replay_dir: Path,
    candidate: Candidate,
) -> tuple[Path, Path]:
    ucdb_path = coverage_dir / f"{candidate.name}.ucdb"
    log_path = logs_dir / f"{candidate.name}.log"
    cmd = [
        "make",
        "-C",
        str(repo_root / "tb_int" / "cases" / "basic" / "plain_2env"),
        "COV=1",
        f"RUN_LOG={log_path}",
        f"REPLAY_DIR={replay_dir}",
        f"COV_UCDB={ucdb_path}",
        f"SIM_ARGS={candidate.sim_args}",
        "run_cov",
    ]
    run_cmd(cmd, repo_root)
    return ucdb_path, log_path


def generate_replay_bundle(repo_root: Path, replay_root: Path, candidate: Candidate) -> Path:
    replay_script = candidate.replay_script
    replay_args = candidate.replay_args
    if replay_script is None:
        assert candidate.replay_profile is not None
        assert candidate.replay_generator is not None
        replay_script = candidate.replay_generator
        replay_args = ("--profile", candidate.replay_profile)
    out_dir = replay_root / candidate.name
    ensure_dir(out_dir)
    cmd = [
        sys.executable,
        str(repo_root / "tb_int" / "cases" / "basic" / "ref" / replay_script),
        *replay_args,
        "--out-dir",
        str(out_dir),
    ]
    run_cmd(cmd, repo_root)
    return out_dir


def merge_ucdb(vcover: Path, output_ucdb: Path, inputs: list[Path], cwd: Path) -> None:
    cmd = [str(vcover), "merge", str(output_ucdb), *[str(path) for path in inputs]]
    run_cmd(cmd, cwd)


def replace_file(src: Path, dst: Path) -> None:
    shutil.copyfile(src, dst)


def main() -> int:
    args = parse_args()
    tb_root = Path(args.tb).resolve()
    repo_root = tb_root.parent
    cov_module = load_cov_module(repo_root)
    vcover = cov_module.locate_vcover()
    if vcover is None:
        print("campaign: unable to locate vcover", file=sys.stderr)
        return 2

    baseline_ucdb = Path(args.baseline_ucdb).resolve() if args.baseline_ucdb else (tb_root / "sim_runs" / "coverage" / "tb_int_merged.ucdb")
    if not baseline_ucdb.is_file():
        print(f"campaign: baseline UCDB not found: {baseline_ucdb}", file=sys.stderr)
        return 2

    campaign_dir = Path(args.campaign_dir).resolve() if args.campaign_dir else (tb_root / "sim_runs" / "campaign")
    coverage_dir = campaign_dir / "coverage"
    logs_dir = campaign_dir / "logs"
    replay_dir_root = campaign_dir / "replay"
    ensure_dir(coverage_dir)
    ensure_dir(logs_dir)
    ensure_dir(replay_dir_root)

    accepted_merge_ucdb = coverage_dir / "accepted_merged.ucdb"
    replace_file(baseline_ucdb, accepted_merge_ucdb)

    current_cov = coverage_totals(cov_module, vcover, accepted_merge_ucdb)
    current_hits = totals_hits(current_cov)
    current_pct = totals_pct(current_cov)

    results: list[CandidateResult] = []
    accepted_cases: list[str] = []
    no_gain_streak = 0

    candidates = build_candidates()[: args.max_cases]
    print(
        "campaign: "
        f"baseline={baseline_ucdb} cases={len(candidates)} no_gain_limit={args.no_gain_limit}"
    )
    print(f"campaign: baseline_pct={json.dumps(current_pct, sort_keys=True)}")

    for index, candidate in enumerate(candidates):
        if no_gain_streak >= args.no_gain_limit:
            print(
                "campaign: "
                f"stopping after no_gain_streak={no_gain_streak} at candidate_index={index}"
            )
            break

        replay_dir: Path | None = None
        if candidate.harness == "plain":
            replay_dir = generate_replay_bundle(repo_root, replay_dir_root, candidate)
            ucdb_path, log_path = make_plain_case(repo_root, coverage_dir, logs_dir, replay_dir, candidate)
        elif candidate.harness == "plain_2env":
            replay_dir = generate_replay_bundle(repo_root, replay_dir_root, candidate)
            ucdb_path, log_path = make_plain_2env_case(repo_root, coverage_dir, logs_dir, replay_dir, candidate)
        elif candidate.harness == "uvm":
            ucdb_path, log_path = make_uvm_case(repo_root, coverage_dir, logs_dir, candidate)
        else:
            raise ValueError(f"Unsupported harness {candidate.harness}")

        before_hits = dict(current_hits)
        trial_merge_ucdb = coverage_dir / f"{candidate.name}.merged.ucdb"
        merge_ucdb(vcover, trial_merge_ucdb, [accepted_merge_ucdb, ucdb_path], repo_root)
        trial_cov = coverage_totals(cov_module, vcover, trial_merge_ucdb)
        trial_hits = totals_hits(trial_cov)
        gain_hits = gains(before_hits, trial_hits)
        accepted = candidate_improves(before_hits, trial_hits)

        if accepted:
            replace_file(trial_merge_ucdb, accepted_merge_ucdb)
            current_cov = trial_cov
            current_hits = trial_hits
            current_pct = totals_pct(current_cov)
            accepted_cases.append(candidate.name)
            no_gain_streak = 0
        else:
            no_gain_streak += 1

        result = CandidateResult(
            name=candidate.name,
            harness=candidate.harness,
            description=candidate.description,
            accepted=accepted,
            gain_hits=gain_hits,
            totals_before=before_hits,
            totals_after=trial_hits,
            ucdb=str(ucdb_path),
            log=str(log_path),
            replay_dir=(str(replay_dir) if replay_dir is not None else None),
        )
        results.append(result)

        print(
            "campaign: "
            f"case={candidate.name} accepted={int(accepted)} no_gain_streak={no_gain_streak} "
            f"gain_hits={json.dumps(gain_hits, sort_keys=True)} "
            f"pct={json.dumps(current_pct, sort_keys=True)}"
        )

    summary = {
        "baseline_ucdb": str(baseline_ucdb),
        "accepted_merge_ucdb": str(accepted_merge_ucdb),
        "accepted_cases": accepted_cases,
        "final_hits": current_hits,
        "final_pct": current_pct,
        "no_gain_limit": args.no_gain_limit,
        "results": [asdict(result) for result in results],
    }
    summary_path = campaign_dir / "summary.json"
    summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(f"campaign: summary={summary_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
