#!/usr/bin/env python3
"""Check named VCD checkpoints for the GHDL all-bucket cross fixture."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path


CASES = [
    ("B001", 1, 0),
    ("B002", 2, 0),
    ("B046", 46, 0),
    ("B047", 47, 0),
    ("B048", 48, 0),
    ("B049", 49, 0),
    ("E025", 1025, 1),
    ("E026", 1026, 1),
    ("E027", 1027, 1),
    ("P040", 2040, 2),
    ("P041", 2041, 2),
    ("P123", 2123, 2),
    ("P124", 2124, 2),
    ("X111", 3111, 3),
    ("X112", 3112, 3),
    ("X116", 3116, 3),
    ("X117", 3117, 3),
    ("X118", 3118, 3),
    ("X120", 3120, 3),
    ("X122", 3122, 3),
    ("X123", 3123, 3),
    ("X124", 3124, 3),
]


@dataclass(frozen=True)
class Check:
    name: str
    time_fs: int
    expected: dict[str, int | str]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vcd", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--case-cycles", required=True, type=int)
    parser.add_argument("--clock-period-ns", required=True, type=int)
    return parser.parse_args()


def signal_ids(vcd: Path) -> dict[str, str]:
    ids: dict[str, str] = {}
    with vcd.open("r", encoding="ascii", errors="replace") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if line == "$enddefinitions $end":
                break
            if not line.startswith("$var "):
                continue
            parts = line.split()
            if len(parts) >= 5:
                ids[parts[4]] = parts[3]
    return ids


def checkpoint_plan(case_cycles: int, clock_period_ns: int) -> list[Check]:
    period_fs = clock_period_ns * 1_000_000
    base_fs = ((2 * 8 - 1) * clock_period_ns * 500_000)
    stride_fs = (case_cycles + 1) * period_fs

    def start(case_idx: int) -> int:
        return base_fs + case_idx * stride_fs

    def mid(case_idx: int, cycles: int) -> int:
        return start(case_idx) + cycles * period_fs

    checks: list[Check] = [
        Check("T01_BASIC_B001 start", start(0), {"case_code[15:0]": 1, "bucket_id[3:0]": 0, "run_active": "1", "ghost_count[15:0]": 0, "missing_count[15:0]": 0}),
        Check("T03_BASIC_B046 single lane", start(2), {"case_code[15:0]": 46, "bucket_id[3:0]": 0, "lane_mask[3:0]": 1}),
        Check("T07_EDGE_E025 start", start(6), {"case_code[15:0]": 1025, "bucket_id[3:0]": 1, "error_expected": "0"}),
        Check("T10_PROF_P040 start", start(9), {"case_code[15:0]": 2040, "bucket_id[3:0]": 2}),
        Check("P040 DMA backpressure active", mid(9, 20), {"case_code[15:0]": 2040, "dma_half_full": "1", "flow_state[3:0]": 4}),
        Check("P041 DMA backpressure released", mid(10, 80), {"case_code[15:0]": 2041, "dma_half_full": "0"}),
        Check("T12_PROF_P123 start", start(11), {"case_code[15:0]": 2123, "bucket_id[3:0]": 2}),
        Check("P123 partial-join body hold", mid(11, 1000), {"case_code[15:0]": 2123, "opq_body_hold": "1", "join_pending": "1", "flow_state[3:0]": 3}),
        Check("P123 body hold released", mid(11, 3000), {"case_code[15:0]": 2123, "opq_body_hold": "0", "join_pending": "0"}),
        Check("P124 partial-join body hold", mid(12, 1000), {"case_code[15:0]": 2124, "opq_body_hold": "1", "join_pending": "1"}),
        Check("T14_ERROR_X111 start", start(13), {"case_code[15:0]": 3111, "bucket_id[3:0]": 3, "error_expected": "1"}),
        Check("T18_ERROR_X118 start", start(17), {"case_code[15:0]": 3118, "bucket_id[3:0]": 3, "error_expected": "1"}),
        Check("T23_CROSS_DONE", start(len(CASES)) + period_fs, {"run_active": "0", "cases_done[7:0]": 22, "ghost_count[15:0]": 0, "missing_count[15:0]": 0, "scoreboard_pass": "1"}),
    ]
    return checks


def parse_value(raw: str | None) -> int | str | None:
    if raw is None:
        return None
    if raw in {"0", "1", "x", "z"}:
        return raw
    if set(raw.lower()) <= {"0", "1", "x", "z"}:
        if "x" in raw.lower() or "z" in raw.lower():
            return raw
        return int(raw, 2)
    return raw


def sample_vcd(vcd: Path, ids: dict[str, str], checks: list[Check]) -> dict[str, dict[str, int | str | None]]:
    id_to_name = {ident: name for name, ident in ids.items()}
    watched = set(id_to_name)
    values: dict[str, str] = {}
    results: dict[str, dict[str, int | str | None]] = {}
    sorted_checks = sorted(checks, key=lambda check: check.time_fs)
    check_idx = 0
    now = 0

    def capture_before(target_time: int) -> None:
        nonlocal check_idx
        while check_idx < len(sorted_checks) and sorted_checks[check_idx].time_fs < target_time:
            check = sorted_checks[check_idx]
            results[check.name] = {
                name: parse_value(values.get(ids[name]))
                for name in check.expected
            }
            check_idx += 1

    with vcd.open("r", encoding="ascii", errors="replace") as handle:
        in_dumpvars = False
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue
            if line.startswith("$"):
                in_dumpvars = line == "$dumpvars"
                continue
            if line.startswith("#"):
                capture_before(int(line[1:]))
                now = int(line[1:])
                if check_idx >= len(sorted_checks):
                    break
                continue
            if line.startswith("b"):
                bits, ident = line[1:].split(maxsplit=1)
                if ident in watched:
                    values[ident] = bits
            else:
                ident = line[1:]
                if ident in watched:
                    values[ident] = line[0]
            if in_dumpvars:
                capture_before(now)

    while check_idx < len(sorted_checks):
        check = sorted_checks[check_idx]
        results[check.name] = {
            name: parse_value(values.get(ids[name]))
            for name in check.expected
        }
        check_idx += 1
    return results


def main() -> int:
    args = parse_args()
    ids = signal_ids(args.vcd)
    checks = checkpoint_plan(args.case_cycles, args.clock_period_ns)
    missing = sorted({name for check in checks for name in check.expected} - set(ids))
    if missing:
        raise SystemExit(f"missing VCD signals: {', '.join(missing)}")

    samples = sample_vcd(args.vcd, ids, checks)
    rows = []
    failures = []
    for check in checks:
        sample = samples.get(check.name, {})
        for signal, expected in check.expected.items():
            observed = sample.get(signal)
            passed = observed == expected
            rows.append((check.name, check.time_fs, signal, expected, observed, passed))
            if not passed:
                failures.append((check.name, signal, expected, observed))

    args.out.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# GHDL Cross VCD Checkpoints",
        "",
        "| checkpoint | time_fs | signal | expected | observed | result |",
        "|---|---:|---|---:|---:|:---:|",
    ]
    for name, time_fs, signal, expected, observed, passed in rows:
        lines.append(
            f"| {name} | {time_fs} | `{signal}` | `{expected}` | `{observed}` | {'PASS' if passed else 'FAIL'} |"
        )
    args.out.write_text("\n".join(lines) + "\n", encoding="ascii")
    print(f"wrote {args.out}")
    print(f"checked {len(checks)} checkpoints / {len(rows)} signal expectations")
    if failures:
        for name, signal, expected, observed in failures:
            print(f"FAIL {name}: {signal} expected {expected} observed {observed}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
