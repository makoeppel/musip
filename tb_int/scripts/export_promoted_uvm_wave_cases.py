#!/usr/bin/env python3
"""Regenerate wave bundles for promoted single-run UVM evidence cases."""

from __future__ import annotations

import argparse
import re
import shlex
import subprocess
from pathlib import Path


DEFAULT_SAT = [0.20, 0.40, 0.60, 0.80]
EXEC_ROW_RE = re.compile(r"^\| ([DR]) \| `([^`]+)` \| `([^`]*)` \| `(.*)` \| `([^`]*)` \|$")
SEED_RE = re.compile(r"(\d+)")


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def parse_case_row(case_md: Path) -> tuple[str, str, str] | None:
    for raw_line in case_md.read_text(encoding="utf-8").splitlines():
        match = EXEC_ROW_RE.match(raw_line.strip())
        if match is None:
            continue
        _method, harness, make_target, plusargs, seed_text = match.groups()
        if harness != "uvm" or make_target != "make ip-uvm-basic":
            return None
        return plusargs, seed_text, case_md.stem
    return None


def parse_plusargs(text: str) -> dict[str, str]:
    plusargs: dict[str, str] = {}
    for token in shlex.split(text):
        if not token.startswith("+"):
            continue
        body = token[1:]
        if "=" not in body:
            continue
        key, value = body.split("=", 1)
        plusargs[key] = value
    return plusargs


def parsed_seed(plusargs: dict[str, str], seed_text: str) -> int:
    if "SWB_CASE_SEED" in plusargs:
        return int(plusargs["SWB_CASE_SEED"], 0)
    match = SEED_RE.search(seed_text)
    if match is not None:
        return int(match.group(1), 10)
    return 1


def parsed_frames(plusargs: dict[str, str]) -> int:
    return int(plusargs.get("SWB_FRAMES", "2"), 0)


def parsed_sats(plusargs: dict[str, str]) -> list[float]:
    sats = DEFAULT_SAT[:]
    for lane in range(4):
        key = f"SWB_SAT{lane}"
        if key in plusargs:
            sats[lane] = float(plusargs[key])
    return sats


def frame_start_for_window(frames: int, frame_count: int) -> int:
    if frames <= frame_count:
        return 0
    return max(0, (frames - frame_count) // 2)


def build_export_command(
    case_id: str,
    plusargs: dict[str, str],
    seed_text: str,
    frame_count: int,
) -> list[str]:
    root = repo_root()
    frames = max(parsed_frames(plusargs), frame_count)
    frame_start = frame_start_for_window(frames, frame_count)
    cmd = [
        "python3",
        str(root / "tb_int/scripts/export_wave_case_bundle.py"),
        "--case-id",
        case_id,
        "--profile-name",
        plusargs.get("SWB_PROFILE_NAME", case_id),
        "--frames",
        str(frames),
        "--seed",
        str(parsed_seed(plusargs, seed_text)),
        "--sat",
        *(f"{value:0.2f}" for value in parsed_sats(plusargs)),
        "--feb-enable-mask",
        plusargs.get("SWB_FEB_ENABLE_MASK", "0xf"),
        "--frame-slot-cycles",
        plusargs.get("SWB_FRAME_SLOT_CYCLES", "4096"),
        "--hit-mode",
        plusargs.get("SWB_HIT_MODE", "poisson"),
        "--frame-start",
        str(frame_start),
        "--frame-count",
        str(frame_count),
    ]
    if "SWB_DMA_HALF_FULL_PCT" in plusargs:
        cmd.extend(["--dma-half-full-pct", plusargs["SWB_DMA_HALF_FULL_PCT"]])
    if "SWB_REPLAY_DIR" in plusargs:
        cmd.extend(["--ref-source-dir", plusargs["SWB_REPLAY_DIR"]])
    if "SWB_LANE_SKEW_VARYING" in plusargs:
        cmd.append("--lane-skew-varying")
        cmd.extend(["--lane-skew-max-cyc", plusargs.get("SWB_LANE_SKEW_MAX_CYC", "0")])
    else:
        cmd.extend(
            [
                "--lane-skew-fixed",
                ",".join(plusargs.get(f"SWB_LANE{lane}_SKEW_CYC", "0") for lane in range(4)),
            ]
        )
    return cmd


def discover_cases(case_dir: Path) -> list[tuple[str, dict[str, str], str]]:
    discovered: list[tuple[str, dict[str, str], str]] = []
    for case_md in sorted(case_dir.glob("*.md")):
        if case_md.stem == "TEMPLATE":
            continue
        parsed = parse_case_row(case_md)
        if parsed is None:
            continue
        plusargs_text, seed_text, case_id = parsed
        plusargs = parse_plusargs(plusargs_text)
        discovered.append((case_id, plusargs, seed_text))
    return discovered


def main() -> int:
    parser = argparse.ArgumentParser(description="Regenerate promoted UVM wave bundles from REPORT/cases/*.md")
    parser.add_argument(
        "--cases",
        nargs="*",
        help="Optional explicit case-id subset. Default: every promoted single-run UVM evidence page.",
    )
    parser.add_argument(
        "--frame-count",
        type=int,
        default=3,
        help="Number of frames to expose in each generated analyzer window.",
    )
    args = parser.parse_args()

    root = repo_root()
    case_dir = root / "tb_int/REPORT/cases"
    discovered = discover_cases(case_dir)
    selected = set(case.upper() for case in args.cases) if args.cases else None

    for case_id, plusargs, seed_text in discovered:
        if selected is not None and case_id.upper() not in selected:
            continue
        cmd = build_export_command(case_id, plusargs, seed_text, args.frame_count)
        print(f"[wave] {case_id}")
        subprocess.run(cmd, cwd=root, check=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
