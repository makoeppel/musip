#!/usr/bin/env python3
from __future__ import annotations

import argparse
import itertools
import json
import os
import random
import re
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass
class RunResult:
    run_id: int
    case_seed: int
    rates: list[float]
    fixed_lane_skew_cycles: list[int] | None
    lane_skew_varying: bool
    lane_skew_max_cyc: int
    passed: bool
    returncode: int
    pass_sentinel: bool
    uvm_errors: int | None
    uvm_fatals: int | None
    log_path: str
    trace_prefix: str | None
    trace_log_path: str | None


def build_rate_grid(rate_min: float, rate_max: float, rate_step: float) -> list[float]:
    values: list[float] = []
    current = rate_min
    while current <= (rate_max + 1e-9):
        values.append(round(current, 4))
        current += rate_step
    return values


def build_cases(runs: int, rate_grid: list[float], campaign_seed: int) -> list[tuple[list[float], int]]:
    if not rate_grid:
        raise ValueError("rate grid is empty")

    combinations = list(itertools.product(rate_grid, repeat=4))
    if runs > len(combinations):
        raise ValueError(
            f"Requested {runs} runs but only {len(combinations)} unique rate combinations are available"
        )

    rng = random.Random(campaign_seed)
    rng.shuffle(combinations)

    cases: list[tuple[list[float], int]] = []
    for idx in range(runs):
        case_seed = rng.randrange(1, 2**31 - 1)
        cases.append((list(combinations[idx]), case_seed))
    return cases


def parse_fixed_lane_skew(raw_value: str | None) -> list[int] | None:
    if raw_value is None:
        return None

    parts = [part.strip() for part in raw_value.split(",")]
    if len(parts) != 4:
        raise ValueError("--lane-skew-fixed must provide exactly 4 comma-separated cycle values")

    skew_cycles: list[int] = []
    for lane, part in enumerate(parts):
        if part == "":
            raise ValueError(f"--lane-skew-fixed lane {lane} is empty")
        value = int(part, 0)
        if value < 0:
            raise ValueError(f"--lane-skew-fixed lane {lane} must be non-negative")
        skew_cycles.append(value)
    return skew_cycles


def format_lane_skew(
    fixed_lane_skew_cycles: list[int] | None,
    lane_skew_varying: bool,
    lane_skew_max_cyc: int,
) -> str:
    if fixed_lane_skew_cycles is not None:
        return "[" + ",".join(str(value) for value in fixed_lane_skew_cycles) + "]"
    if lane_skew_varying:
        return f"varying<={lane_skew_max_cyc}"
    return "none"


def build_sim_args(
    frames: int,
    case_seed: int,
    rates: list[float],
    trace_prefix: Path | None,
    fixed_lane_skew_cycles: list[int] | None,
    lane_skew_varying: bool,
    lane_skew_max_cyc: int,
) -> str:
    sim_args = [
        f"+SWB_FRAMES={frames}",
        f"+SWB_CASE_SEED={case_seed}",
        f"+SWB_SAT0={rates[0]:0.2f}",
        f"+SWB_SAT1={rates[1]:0.2f}",
        f"+SWB_SAT2={rates[2]:0.2f}",
        f"+SWB_SAT3={rates[3]:0.2f}",
    ]
    if fixed_lane_skew_cycles is not None:
        for lane, skew_cycles in enumerate(fixed_lane_skew_cycles):
            sim_args.append(f"+SWB_LANE{lane}_SKEW_CYC={skew_cycles}")
    elif lane_skew_varying:
        sim_args.append("+SWB_LANE_SKEW_VARYING=1")
        sim_args.append(f"+SWB_LANE_SKEW_MAX_CYC={lane_skew_max_cyc}")
    if trace_prefix is not None:
        sim_args.append(f"+SWB_HIT_TRACE_PREFIX={trace_prefix}")
    return " ".join(sim_args)


def run_make(uvm_dir: Path, args: list[str], log_path: Path) -> int:
    cmd = ["make", "-C", str(uvm_dir), *args]
    with log_path.open("w", encoding="utf-8") as handle:
        proc = subprocess.run(
            cmd,
            stdout=handle,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
        )
    return proc.returncode


def parse_pass_sentinel(log_path: Path) -> bool:
    text = log_path.read_text(encoding="utf-8", errors="replace")
    return "SWB_CHECK_PASS" in text


def parse_uvm_summary(log_path: Path) -> tuple[int | None, int | None]:
    text = log_path.read_text(encoding="utf-8", errors="replace")
    error_match = re.search(r"UVM_ERROR\s*:\s*(\d+)", text)
    fatal_match = re.search(r"UVM_FATAL\s*:\s*(\d+)", text)
    uvm_errors = int(error_match.group(1)) if error_match else None
    uvm_fatals = int(fatal_match.group(1)) if fatal_match else None
    return uvm_errors, uvm_fatals


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the musip SWB UVM long-run campaign")
    parser.add_argument("--runs", type=int, default=128)
    parser.add_argument("--frames", type=int, default=2)
    parser.add_argument("--rate-min", type=float, default=0.0)
    parser.add_argument("--rate-max", type=float, default=0.5)
    parser.add_argument("--rate-step", type=float, default=0.1)
    parser.add_argument("--campaign-seed", type=int, default=260421)
    parser.add_argument("--fail-fast", action="store_true")
    parser.add_argument("--trace-failures", action="store_true", default=True)
    parser.add_argument("--no-trace-failures", dest="trace_failures", action="store_false")
    parser.add_argument(
        "--lane-skew-fixed",
        help="Four comma-separated fixed per-lane SOP skew values in cycles, e.g. 0,512,1024,2048",
    )
    parser.add_argument(
        "--lane-skew-varying",
        action="store_true",
        help="Draw lane 1..3 SOP skew uniformly per frame from [0, --lane-skew-max-cyc]",
    )
    parser.add_argument(
        "--lane-skew-max-cyc",
        type=int,
        default=0,
        help="Maximum SOP skew in cycles when --lane-skew-varying is enabled",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path("report/longrun"),
        help="Directory relative to the UVM case directory unless absolute",
    )
    args = parser.parse_args()

    uvm_dir = Path(__file__).resolve().parent
    out_dir = args.out_dir if args.out_dir.is_absolute() else (uvm_dir / args.out_dir)
    runs_dir = out_dir / "runs"
    failures_dir = out_dir / "failures"
    out_dir.mkdir(parents=True, exist_ok=True)
    runs_dir.mkdir(parents=True, exist_ok=True)
    failures_dir.mkdir(parents=True, exist_ok=True)

    try:
        fixed_lane_skew_cycles = parse_fixed_lane_skew(args.lane_skew_fixed)
    except ValueError as exc:
        print(f"longrun: {exc}", file=sys.stderr)
        return 2

    if fixed_lane_skew_cycles is not None and args.lane_skew_varying:
        print("longrun: --lane-skew-fixed and --lane-skew-varying are mutually exclusive", file=sys.stderr)
        return 2
    if args.lane_skew_varying and args.lane_skew_max_cyc <= 0:
        print("longrun: --lane-skew-varying requires --lane-skew-max-cyc > 0", file=sys.stderr)
        return 2
    if (not args.lane_skew_varying) and (args.lane_skew_max_cyc != 0):
        print("longrun: --lane-skew-max-cyc requires --lane-skew-varying", file=sys.stderr)
        return 2

    rate_grid = build_rate_grid(args.rate_min, args.rate_max, args.rate_step)
    cases = build_cases(args.runs, rate_grid, args.campaign_seed)

    compile_log = out_dir / "compile.log"
    compile_rc = run_make(uvm_dir, ["compile"], compile_log)
    if compile_rc != 0:
      print(f"longrun: compile failed, see {compile_log}", file=sys.stderr)
      return compile_rc

    results: list[RunResult] = []
    print(
        "longrun: "
        f"runs={args.runs} frames={args.frames} "
        f"rate_grid={','.join(f'{value:0.2f}' for value in rate_grid)} "
        f"campaign_seed={args.campaign_seed} "
        f"lane_skew={format_lane_skew(fixed_lane_skew_cycles, args.lane_skew_varying, args.lane_skew_max_cyc)}"
    )

    for run_id, (rates, case_seed) in enumerate(cases):
        log_path = runs_dir / f"run_{run_id:03d}.log"
        sim_args = build_sim_args(
            args.frames,
            case_seed,
            rates,
            None,
            fixed_lane_skew_cycles,
            args.lane_skew_varying,
            args.lane_skew_max_cyc,
        )
        rc = run_make(
            uvm_dir,
            [
                "run",
                "SWB_USE_MERGE=1",
                f"SIM_ARGS={sim_args}",
            ],
            log_path,
        )
        pass_sentinel = (rc == 0) and parse_pass_sentinel(log_path)
        uvm_errors, uvm_fatals = parse_uvm_summary(log_path)
        run_passed = (
            pass_sentinel
            and (uvm_errors == 0)
            and (uvm_fatals == 0)
        )
        trace_prefix: Path | None = None
        trace_log_path: Path | None = None

        if not run_passed and args.trace_failures:
            trace_prefix = failures_dir / f"run_{run_id:03d}"
            trace_log_path = failures_dir / f"run_{run_id:03d}.trace.log"
            trace_args = build_sim_args(
                args.frames,
                case_seed,
                rates,
                trace_prefix,
                fixed_lane_skew_cycles,
                args.lane_skew_varying,
                args.lane_skew_max_cyc,
            )
            run_make(
                uvm_dir,
                [
                    "run",
                    "SWB_USE_MERGE=1",
                    f"SIM_ARGS={trace_args}",
                ],
                trace_log_path,
            )

        results.append(
            RunResult(
                run_id=run_id,
                case_seed=case_seed,
                rates=rates,
                fixed_lane_skew_cycles=fixed_lane_skew_cycles,
                lane_skew_varying=args.lane_skew_varying,
                lane_skew_max_cyc=args.lane_skew_max_cyc,
                passed=run_passed,
                returncode=rc,
                pass_sentinel=pass_sentinel,
                uvm_errors=uvm_errors,
                uvm_fatals=uvm_fatals,
                log_path=str(log_path.relative_to(uvm_dir)),
                trace_prefix=(str(trace_prefix.relative_to(uvm_dir)) if trace_prefix is not None else None),
                trace_log_path=(str(trace_log_path.relative_to(uvm_dir)) if trace_log_path is not None else None),
            )
        )

        status = "PASS" if run_passed else "FAIL"
        print(
            "longrun: "
            f"run={run_id:03d} status={status} seed={case_seed} "
            f"rates=[{rates[0]:0.2f},{rates[1]:0.2f},{rates[2]:0.2f},{rates[3]:0.2f}] "
            f"lane_skew={format_lane_skew(fixed_lane_skew_cycles, args.lane_skew_varying, args.lane_skew_max_cyc)} "
            f"uvm_errors={uvm_errors} uvm_fatals={uvm_fatals} "
            f"log={results[-1].log_path}"
        )
        if not run_passed and args.fail_fast:
            break

    pass_count = sum(1 for result in results if result.passed)
    fail_count = len(results) - pass_count
    summary = {
        "runs_requested": args.runs,
        "runs_executed": len(results),
        "frames": args.frames,
        "rate_min": args.rate_min,
        "rate_max": args.rate_max,
        "rate_step": args.rate_step,
        "rate_grid": rate_grid,
        "campaign_seed": args.campaign_seed,
        "fixed_lane_skew_cycles": fixed_lane_skew_cycles,
        "lane_skew_varying": args.lane_skew_varying,
        "lane_skew_max_cyc": args.lane_skew_max_cyc,
        "opq_source_mode": os.environ.get("OPQ_SOURCE_MODE"),
        "opq_n_shd": os.environ.get("OPQ_N_SHD"),
        "opq_lane_fifo_depth": os.environ.get("OPQ_LANE_FIFO_DEPTH"),
        "opq_ticket_fifo_depth": os.environ.get("OPQ_TICKET_FIFO_DEPTH"),
        "opq_handle_fifo_depth": os.environ.get("OPQ_HANDLE_FIFO_DEPTH"),
        "opq_page_ram_depth": os.environ.get("OPQ_PAGE_RAM_DEPTH"),
        "pass_count": pass_count,
        "fail_count": fail_count,
        "results": [asdict(result) for result in results],
    }

    summary_path = out_dir / "summary.json"
    summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    print(
        "longrun: "
        f"completed pass_count={pass_count} fail_count={fail_count} summary={summary_path.relative_to(uvm_dir)}"
    )
    return 0 if fail_count == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
