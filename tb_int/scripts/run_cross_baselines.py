#!/usr/bin/env python3
"""Run promoted tb_int continuous-frame CROSS baselines.

The UVM harness owns the continuous-frame primitive through
+SWB_SEGMENT_MANIFEST.  This script builds deterministic replay bundles,
composes them into the promoted CROSS-001..005 anchor manifests, runs each
manifest with coverage, and writes machine-readable evidence for the report
generator.
"""

from __future__ import annotations

import argparse
import copy
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path
from typing import Iterable

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from build_dv_report_json import coverage_payload, locate_vcover  # noqa: E402


@dataclass
class Segment:
    case_id: str
    bucket: str
    replay_args: list[str]
    feb_enable_mask: str = "f"
    use_merge: int = 1
    dma_half_full_pct: int = 0
    dma_half_full_seed: int = 0x5A17C0DE
    case_seed: int = 0
    reset_before: bool = False
    note: str = ""
    replay_dir: Path | None = None


@dataclass
class CrossRun:
    run_id: str
    mode: str
    bucket: str
    scope: str
    notes: str
    segments: list[Segment] = field(default_factory=list)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tb", default="tb_int", help="path to tb_int root")
    parser.add_argument(
        "--only",
        action="append",
        default=[],
        help="run only this CROSS id; may be repeated",
    )
    parser.add_argument(
        "--skip-existing",
        action="store_true",
        help="reuse passing entries from sim_runs/cross/summary.json when log and UCDB still exist",
    )
    return parser.parse_args()


def run_cmd(cmd: list[str], log_path: Path, cwd: Path) -> subprocess.CompletedProcess[bytes]:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("wb") as out:
        out.write(("command: " + " ".join(cmd) + "\n").encode("utf-8"))
        out.flush()
        return subprocess.run(cmd, cwd=cwd, stdout=out, stderr=subprocess.STDOUT)


def relpath(path: Path, base: Path) -> str:
    return path.resolve().relative_to(base.resolve()).as_posix()


def ref_segments() -> dict[str, Segment]:
    sat_02040608 = ["--sat", "0.20", "0.40", "0.60", "0.80"]
    sat_02020202 = ["--sat", "0.20", "0.20", "0.20", "0.20"]
    sat_025 = ["--sat", "0.25", "0.25", "0.25", "0.25"]
    sat_01020304 = ["--sat", "0.10", "0.20", "0.30", "0.40"]
    zero_sat = ["--sat", "0.00", "0.00", "0.00", "0.00"]

    return {
        "B001": Segment("B001", "BASIC", ["--profile", "smoke"], case_seed=0, note="smoke replay"),
        "B002": Segment("B002", "BASIC", ["--seed", "1"], case_seed=1, note="full replay"),
        "B046": Segment("B046", "BASIC", ["--seed", "4242", "--feb-enable-mask", "1", *sat_02040608], "1", case_seed=4242),
        "B047": Segment("B047", "BASIC", ["--seed", "4242", "--feb-enable-mask", "2", *sat_02040608], "2", case_seed=4242),
        "B048": Segment("B048", "BASIC", ["--seed", "4242", "--feb-enable-mask", "4", *sat_02040608], "4", case_seed=4242),
        "B049": Segment("B049", "BASIC", ["--seed", "4242", "--feb-enable-mask", "8", *sat_02040608], "8", case_seed=4242),
        "E025": Segment("E025", "EDGE", ["--seed", "111", "--hit-mode", "zero", *sat_02020202], case_seed=111),
        "E026": Segment("E026", "EDGE", ["--frames", "1", "--seed", "112", "--hit-mode", "single", *sat_02020202], case_seed=112),
        "E027": Segment("E027", "EDGE", ["--frames", "1", "--seed", "113", "--hit-mode", "max", "--feb-enable-mask", "1", *sat_02020202], "1", case_seed=113),
        "P040": Segment("P040", "PROF", ["--seed", "5151", *sat_02020202], dma_half_full_pct=50, case_seed=5151),
        "P041": Segment("P041", "PROF", ["--seed", "5151", *sat_02020202], dma_half_full_pct=75, case_seed=5151),
        "P123": Segment("P123", "PROF", ["--frames", "16", "--seed", "123", *sat_025, "--lane-skew-fixed", "0,512,1024,2048"], case_seed=123),
        "P124": Segment("P124", "PROF", ["--frames", "16", "--seed", "124", *sat_025, "--lane-skew-varying", "--lane-skew-max-cyc", "2048"], case_seed=124),
        "X111": Segment("X111", "ERROR", ["--seed", "1066426748", *sat_02040608], case_seed=1066426748),
        "X112": Segment("X112", "ERROR", ["--profile", "smoke"], case_seed=0, note="merge-enabled replay smoke"),
        "X116": Segment("X116", "ERROR", ["--frames", "2", "--seed", "12345", *sat_01020304], case_seed=12345),
        "X117": Segment("X117", "ERROR", ["--frames", "2", "--seed", "12345", *sat_01020304], case_seed=12345),
        "X118": Segment("X118", "ERROR", ["--frames", "2", "--seed", "1327604986", "--hit-mode", "zero", *zero_sat], case_seed=1327604986),
        "X120": Segment("X120", "ERROR", ["--frames", "1", "--seed", "1", *sat_01020304], case_seed=1),
        "X122": Segment("X122", "ERROR", ["--frames", "2", "--seed", "1327604986", "--hit-mode", "zero", *zero_sat], case_seed=1327604986),
        "X123": Segment("X123", "ERROR", ["--frames", "2", "--seed", "1327604986", "--hit-mode", "zero", *zero_sat], case_seed=1327604986),
        "X124": Segment("X124", "ERROR", ["--frames", "2", "--seed", "1327604986", "--hit-mode", "zero", *zero_sat], case_seed=1327604986),
    }


def clone_segments(cases: Iterable[str], catalog: dict[str, Segment]) -> list[Segment]:
    return [copy.deepcopy(catalog[case_id]) for case_id in cases]


def cross_runs() -> dict[str, CrossRun]:
    catalog = ref_segments()
    basic = clone_segments(["B001", "B002", "B046", "B047", "B048", "B049"], catalog)
    edge = clone_segments(["E025", "E026", "E027"], catalog)
    prof = clone_segments(["P040", "P041", "P123", "P124"], catalog)
    error = clone_segments(["X111", "X112", "X116", "X117", "X118", "X120", "X122", "X123", "X124"], catalog)

    all_buckets: list[Segment] = []
    for bucket_segments in (basic, edge, prof, error):
        copied = [copy.deepcopy(segment) for segment in bucket_segments]
        if all_buckets and copied:
            copied[0].reset_before = True
        all_buckets.extend(copied)

    return {
        "CROSS-001": CrossRun(
            "CROSS-001",
            "bucket_frame",
            "BASIC",
            "promoted BASIC anchors B001,B002,B046-B049 in one no-restart frame",
            "BASIC smoke/full replay plus active-lane mask anchors.",
            basic,
        ),
        "CROSS-002": CrossRun(
            "CROSS-002",
            "bucket_frame",
            "EDGE",
            "promoted EDGE anchors E025-E027 in one no-restart frame",
            "zero/single/MAX_HITS subheader anchors.",
            edge,
        ),
        "CROSS-003": CrossRun(
            "CROSS-003",
            "bucket_frame",
            "PROF",
            "promoted PROF anchors P040,P041,P123,P124 in one no-restart frame",
            "DMA backpressure plus fixed/varying skew anchors.",
            prof,
        ),
        "CROSS-004": CrossRun(
            "CROSS-004",
            "bucket_frame",
            "ERROR",
            "promoted ERROR anchors X111,X112,X116-X118,X120,X122-X124 in one no-restart frame",
            "bug-regression anchor shapes that are legal pass cases.",
            error,
        ),
        "CROSS-005": CrossRun(
            "CROSS-005",
            "all_buckets_frame",
            "ALL",
            "promoted BASIC to EDGE to PROF to ERROR anchors with exactly one reset per bucket transition",
            "Full promoted-anchor stack composition; reset before first EDGE, PROF, and ERROR segment only.",
            all_buckets,
        ),
    }


def generate_replay(tb: Path, segment: Segment, replay_root: Path, ref_log: Path) -> None:
    out_dir = replay_root / segment.case_id
    segment.replay_dir = out_dir.resolve()
    expected = out_dir / "expected_dma_words.mem"
    lanes_ok = all((out_dir / f"lane{lane}_ingress.mem").is_file() for lane in range(4))
    if expected.is_file() and lanes_ok:
        return
    cmd = [
        "python3",
        str(tb / "cases/basic/ref/run_basic_ref.py"),
        "--out-dir",
        str(out_dir),
        *segment.replay_args,
    ]
    proc = run_cmd(cmd, ref_log, tb.parent)
    if proc.returncode != 0:
        raise RuntimeError(f"failed to generate replay for {segment.case_id}; see {ref_log}")


def write_manifest(run: CrossRun, path: Path) -> None:
    lines = [
        "# case_id mode replay_dir feb_enable_mask use_merge dma_half_full_pct dma_half_full_seed case_seed reset_before\n"
    ]
    for segment in run.segments:
        if segment.replay_dir is None:
            raise RuntimeError(f"missing replay_dir for {segment.case_id}")
        lines.append(
            " ".join(
                [
                    segment.case_id,
                    "replay",
                    str(segment.replay_dir),
                    segment.feb_enable_mask,
                    str(segment.use_merge),
                    str(segment.dma_half_full_pct),
                    str(segment.dma_half_full_seed),
                    str(segment.case_seed),
                    "1" if segment.reset_before else "0",
                ]
            )
            + "\n"
        )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(lines), encoding="ascii")


def parse_uvm_count(text: str, severity: str) -> int | None:
    matches = re.findall(rf"\b{severity}\s*:\s*(\d+)", text)
    if not matches:
        return None
    return int(matches[-1])


def format_sim_time_from_ps(ps_value: int | None) -> str:
    if ps_value is None:
        return "pending"
    if ps_value >= 1_000_000:
        return f"{ps_value / 1_000_000.0:.3f} us"
    if ps_value >= 1_000:
        return f"{ps_value / 1_000.0:.3f} ns"
    return f"{ps_value} ps"


def parse_run_log(log_path: Path, segment_count: int, returncode: int) -> dict[str, object]:
    text = log_path.read_text(encoding="utf-8", errors="replace") if log_path.is_file() else ""
    segment_passes = re.findall(r"\[SWB_SEGMENT_PASS\]\s+profile=([^ ]+).*?expected_words=(\d+).*?mask=0x([0-9a-fA-F]+)", text)
    check_passes = re.findall(
        r"@\s*(\d+):.*?\[SWB_CHECK_PASS\]\s+profile=([^ ]+)\s+case_seed=(\d+)\s+"
        r"payload_words=(\d+)\s+padding_words=(\d+)\s+ingress_hits=(\d+)\s+"
        r"opq_hits=(\d+)\s+dma_hits=(\d+)",
        text,
    )
    uvm_errors = parse_uvm_count(text, "UVM_ERROR")
    uvm_fatals = parse_uvm_count(text, "UVM_FATAL")
    last_ps = int(check_passes[-1][0]) if check_passes else None
    totals = {
        "payload_words": sum(int(row[3]) for row in check_passes),
        "padding_words": sum(int(row[4]) for row in check_passes),
        "ingress_hits": sum(int(row[5]) for row in check_passes),
        "opq_hits": sum(int(row[6]) for row in check_passes),
        "dma_hits": sum(int(row[7]) for row in check_passes),
    }
    passed = (
        returncode == 0
        and len(segment_passes) == segment_count
        and len(check_passes) == segment_count
        and (uvm_errors in (0, None))
        and (uvm_fatals in (0, None))
    )
    return {
        "status": "pass" if passed else "fail",
        "returncode": returncode,
        "segment_pass_count": len(segment_passes),
        "check_pass_count": len(check_passes),
        "uvm_errors": uvm_errors,
        "uvm_fatals": uvm_fatals,
        "sim_time": format_sim_time_from_ps(last_ps),
        "segment_pass_profiles": [row[0] for row in segment_passes],
        **totals,
    }


def cov_payload(ucdb: Path) -> tuple[dict[str, float | None], float | None]:
    vcover = locate_vcover()
    if vcover is None:
        return ({metric: None for metric in ("branch", "cond", "expr", "fsm_state", "fsm_trans", "stmt", "toggle")}, None)
    return coverage_payload(vcover, ucdb)


def run_cross(tb: Path, run: CrossRun, paths: dict[str, Path]) -> dict[str, object]:
    manifest = paths["manifest_dir"] / f"{run.run_id}.manifest"
    run_log = paths["log_dir"] / f"{run.run_id}.log"
    driver_log = paths["driver_log_dir"] / f"{run.run_id}.driver.log"
    ucdb = paths["coverage_dir"] / f"{run.run_id}.ucdb"
    ref_log = paths["ref_log_dir"] / f"{run.run_id}.replay_gen.log"

    for segment in run.segments:
        generate_replay(tb, segment, paths["replay_dir"], ref_log)
    write_manifest(run, manifest)

    cmd = [
        "make",
        "-C",
        str(tb / "cases/basic/uvm"),
        "COV=1",
        "SWB_USE_MERGE=1",
        f"RUN_LOG={run_log}",
        f"COV_UCDB={ucdb}",
        f"SIM_ARGS=+SWB_SEGMENT_MANIFEST={manifest} +SWB_FRAME_SLOT_CYCLES=4096",
        "run_cov",
    ]
    proc = run_cmd(cmd, driver_log, tb.parent)
    parsed = parse_run_log(run_log, len(run.segments), proc.returncode)
    code_cov, func_cov = cov_payload(ucdb)

    evidence = {
        "run_id": run.run_id,
        "mode": run.mode,
        "bucket": run.bucket,
        "scope": run.scope,
        "notes": run.notes,
        "status": parsed["status"],
        "build": "make ip-cross-baselines",
        "invocation": " ".join(cmd),
        "manifest": relpath(manifest, tb),
        "log": relpath(run_log, tb),
        "driver_log": relpath(driver_log, tb),
        "ucdb": relpath(ucdb, tb),
        "segment_count": len(run.segments),
        "reset_count": sum(1 for segment in run.segments if segment.reset_before),
        "segments": [
            {
                "case_id": segment.case_id,
                "bucket": segment.bucket,
                "replay_dir": relpath(segment.replay_dir or Path("."), tb),
                "feb_enable_mask": f"0x{segment.feb_enable_mask.lower()}",
                "use_merge": segment.use_merge,
                "dma_half_full_pct": segment.dma_half_full_pct,
                "case_seed": segment.case_seed,
                "reset_before": segment.reset_before,
                "note": segment.note,
            }
            for segment in run.segments
        ],
        "coverage": code_cov,
        "functional_pct_bins_saturated": func_cov,
        **parsed,
    }
    return evidence


def previous_pass(summary_path: Path, run_id: str, tb: Path) -> dict[str, object] | None:
    if not summary_path.is_file():
        return None
    try:
        data = json.loads(summary_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None
    runs = data.get("runs", {})
    if not isinstance(runs, dict):
        return None
    evidence = runs.get(run_id)
    if not isinstance(evidence, dict) or evidence.get("status") != "pass":
        return None
    log = tb / str(evidence.get("log", ""))
    ucdb = tb / str(evidence.get("ucdb", ""))
    if log.is_file() and ucdb.is_file():
        return evidence
    return None


def merge_cross_ucdbs(paths: dict[str, Path], evidences: dict[str, dict[str, object]], tb: Path) -> str | None:
    vcover = locate_vcover()
    if vcover is None:
        return None
    ucdbs = [tb / str(evidence["ucdb"]) for evidence in evidences.values() if evidence.get("status") == "pass"]
    if not ucdbs:
        return None
    merged = paths["coverage_dir"] / "cross_merged.ucdb"
    cmd = [str(vcover), "merge", str(merged), *[str(path) for path in ucdbs]]
    proc = run_cmd(cmd, paths["driver_log_dir"] / "cross_merged.driver.log", tb.parent)
    if proc.returncode != 0:
        return None
    return relpath(merged, tb)


def main() -> int:
    args = parse_args()
    tb = Path(args.tb).resolve()
    if not tb.is_dir():
        print(f"error: tb directory not found: {tb}", file=sys.stderr)
        return 2

    root = tb / "sim_runs/cross"
    paths = {
        "root": root,
        "replay_dir": root / "replay",
        "manifest_dir": root / "manifests",
        "log_dir": root / "logs",
        "driver_log_dir": root / "driver_logs",
        "ref_log_dir": root / "ref_logs",
        "coverage_dir": root / "coverage",
    }
    for path in paths.values():
        path.mkdir(parents=True, exist_ok=True)

    runs = cross_runs()
    requested = set(args.only) if args.only else set(runs)
    unknown = requested - set(runs)
    if unknown:
        print(f"error: unknown CROSS id(s): {', '.join(sorted(unknown))}", file=sys.stderr)
        return 2

    summary_path = root / "summary.json"
    evidences: dict[str, dict[str, object]] = {}
    for run_id in sorted(requested):
        if args.skip_existing:
            prior = previous_pass(summary_path, run_id, tb)
            if prior is not None:
                print(f"[cross] {run_id}: reusing existing pass")
                evidences[run_id] = prior
                continue
        print(f"[cross] {run_id}: running {runs[run_id].scope}")
        evidence = run_cross(tb, runs[run_id], paths)
        evidences[run_id] = evidence
        print(
            f"[cross] {run_id}: {evidence['status']} "
            f"segments={evidence['segment_pass_count']}/{evidence['segment_count']} "
            f"uvm_error={evidence['uvm_errors']} uvm_fatal={evidence['uvm_fatals']}"
        )

    if summary_path.is_file():
        try:
            previous = json.loads(summary_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            previous = {}
    else:
        previous = {}
    merged_runs = previous.get("runs", {}) if isinstance(previous.get("runs"), dict) else {}
    merged_runs.update(evidences)
    merged_ucdb = merge_cross_ucdbs(paths, merged_runs, tb)
    summary = {
        "date": str(date.today()),
        "workspace": "tb_int",
        "scope_kind": "promoted_anchor_segment_baselines",
        "note": (
            "CROSS-001..005 evidence uses the currently promoted legal anchor segments. "
            "The broader 129-row cross catalog remains the planning space for future exact case-id expansion."
        ),
        "merged_ucdb": merged_ucdb,
        "runs": dict(sorted(merged_runs.items())),
    }
    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=False) + "\n", encoding="utf-8")
    print(f"wrote {summary_path}")

    failed = [run_id for run_id, evidence in evidences.items() if evidence.get("status") != "pass"]
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
