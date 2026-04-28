#!/usr/bin/env python3
"""Generate a SignalTap-aligned GTKWave save file for the GHDL cross fixture."""

from __future__ import annotations

import argparse
from pathlib import Path


CASES = [
    ("B001", 1, "BASIC"),
    ("B002", 2, "BASIC"),
    ("B046", 46, "BASIC"),
    ("B047", 47, "BASIC"),
    ("B048", 48, "BASIC"),
    ("B049", 49, "BASIC"),
    ("E025", 1025, "EDGE"),
    ("E026", 1026, "EDGE"),
    ("E027", 1027, "EDGE"),
    ("P040", 2040, "PROF"),
    ("P041", 2041, "PROF"),
    ("P123", 2123, "PROF"),
    ("P124", 2124, "PROF"),
    ("X111", 3111, "ERROR"),
    ("X112", 3112, "ERROR"),
    ("X116", 3116, "ERROR"),
    ("X117", 3117, "ERROR"),
    ("X118", 3118, "ERROR"),
    ("X120", 3120, "ERROR"),
    ("X122", 3122, "ERROR"),
    ("X123", 3123, "ERROR"),
    ("X124", 3124, "ERROR"),
]

BUCKETS = {
    0: "BASIC",
    1: "EDGE",
    2: "PROF",
    3: "ERROR",
}

FLOW_STATES = {
    0: "RESET",
    1: "CASE_SOP",
    2: "INGRESS",
    3: "OPQ_JOIN_WAIT",
    4: "DMA_BACKPRESSURE",
    5: "CASE_EOP",
    6: "DONE",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--wave-file", required=True, type=Path)
    parser.add_argument("--case-cycles", required=True, type=int)
    parser.add_argument("--clock-period-ns", required=True, type=int)
    parser.add_argument("--scope", default="tb_swb_cross_ghdl")
    return parser.parse_args()


def write_filter(path: Path, mapping: dict[int, str]) -> None:
    path.write_text(
        "\n".join(f"{key} {value}" for key, value in sorted(mapping.items())) + "\n",
        encoding="ascii",
    )


def case_markers(case_cycles: int, clock_period_ns: int) -> tuple[list[int], list[str]]:
    reset_cycles = 8
    case_stride = case_cycles + 1
    period_fs = clock_period_ns * 1_000_000
    times = [reset_cycles * period_fs]
    names = ["T00_RESET_DEASSERT"]

    for idx, (case_id, _code, bucket) in enumerate(CASES, start=1):
        start_cycle = reset_cycles + (idx - 1) * case_stride
        times.append(start_cycle * period_fs)
        names.append(f"T{idx:02d}_{bucket}_{case_id}")

    end_cycle = reset_cycles + len(CASES) * case_stride + 1
    times.append(end_cycle * period_fs)
    names.append(f"T{len(CASES) + 1:02d}_CROSS_DONE")
    return times, names


def group(lines: list[str], name: str) -> None:
    lines.extend(["@200", f"-{name}"])


def signal(
    lines: list[str],
    scope: str,
    name: str,
    attr: str,
    color: int | None = None,
    label: str | None = None,
    filter_file: Path | None = None,
) -> None:
    lines.append(f"@{attr}")
    lines.append(f"{scope}.{name}")
    if filter_file is not None:
        lines.append(f"[translate_filter_file] {filter_file.resolve()}")
    if color is not None:
        lines.append(f"[color] {color}")
    if label is not None:
        lines.append(f"[label] {label}")


def render_gtkw(args: argparse.Namespace) -> str:
    out_dir = args.out.parent
    bucket_filter = out_dir / "bucket_filter.txt"
    case_filter = out_dir / "case_code_filter.txt"
    flow_filter = out_dir / "flow_state_filter.txt"

    write_filter(bucket_filter, BUCKETS)
    write_filter(case_filter, {code: case_id for case_id, code, _bucket in CASES})
    write_filter(flow_filter, FLOW_STATES)

    marker_times, marker_names = case_markers(args.case_cycles, args.clock_period_ns)
    marker_line = "*0.000000 " + " ".join(str(time) for time in marker_times)
    marker_line += " " + " ".join("-1" for _ in range(max(0, 27 - len(marker_times))))

    scope = args.scope
    lines = [
        "[*]",
        "[*] GTKWave Analyzer v3.3.121",
        "[*] MuSiP GHDL all-bucket cross-run view",
        "[*]",
        f"[dumpfile] \"{args.wave_file.resolve()}\"",
        f"[savefile] \"{args.out.resolve()}\"",
        "[timestart] 0",
        "[size] 1600 1000",
        "[pos] -1 -1",
        marker_line,
    ]
    lines.extend(f"[markername_long] {name}" for name in marker_names)
    lines.extend(
        [
            f"[treeopen] {scope}.",
            "[sst_width] 260",
            "[signals_width] 260",
            "[sst_expanded] 1",
            "[sst_vpaned_height] 300",
        ]
    )

    group(lines, "00 Clock + Reset")
    signal(lines, scope, "clk", "28", 0)
    signal(lines, scope, "reset_n", "28", 1)
    signal(lines, scope, "cycle_tick[31:0]", "24", 0)
    signal(lines, scope, "run_active", "28", 0)

    group(lines, "01 Cross Case Delimiters")
    signal(lines, scope, "bucket_id[3:0]", "2024", 0, filter_file=bucket_filter)
    signal(lines, scope, "case_index[7:0]", "24", 0)
    signal(lines, scope, "case_code[15:0]", "2024", 0, filter_file=case_filter)
    signal(lines, scope, "case_tick[31:0]", "24", 4)
    signal(lines, scope, "case_sop", "28", 3)
    signal(lines, scope, "case_eop", "28", 3)
    signal(lines, scope, "segment_reset", "28", 1)
    signal(lines, scope, "bucket_transition", "28", 5)

    group(lines, "02 RX AVST Ingress")
    signal(lines, scope, "lane_mask[3:0]", "22", 0)
    signal(lines, scope, "lane_valid[3:0]", "08", 3)
    signal(lines, scope, "lane_ready[3:0]", "08", 3)
    signal(lines, scope, "lane_fire[3:0]", "08", 3)
    signal(lines, scope, "frame_slot", "28", 3)
    signal(lines, scope, "ingress_words[31:0]", "24", 4)
    signal(lines, scope, "ingress_words[31:0]", "8024", 4, "ingress_words analog")

    group(lines, "03 OPQ Join + Reorder")
    signal(lines, scope, "flow_state[3:0]", "2024", 5, filter_file=flow_filter)
    signal(lines, scope, "join_pending", "28", 5)
    signal(lines, scope, "inactive_wait", "28", 5)
    signal(lines, scope, "opq_body_hold", "28", 3)
    signal(lines, scope, "opq_wait_cycles[15:0]", "24", 4)
    signal(lines, scope, "opq_wait_cycles[15:0]", "8024", 4, "opq_wait_cycles analog")
    signal(lines, scope, "reorder_depth[15:0]", "24", 4)
    signal(lines, scope, "reorder_depth[15:0]", "8024", 4, "reorder_depth analog")
    signal(lines, scope, "opq_words[31:0]", "24", 4)

    group(lines, "04 DMA Egress")
    signal(lines, scope, "dma_half_full", "28", 1)
    signal(lines, scope, "dma_wren", "28", 3)
    signal(lines, scope, "dma_done", "28", 3)
    signal(lines, scope, "expected_words[31:0]", "24", 4)
    signal(lines, scope, "payload_words[31:0]", "24", 4)
    signal(lines, scope, "dma_words[31:0]", "24", 4)
    signal(lines, scope, "dma_words[31:0]", "10024", 4, "dma_words analog")

    group(lines, "05 Scoreboard + Diagnostics")
    signal(lines, scope, "error_expected", "28", 1)
    signal(lines, scope, "ghost_count[15:0]", "24", 1)
    signal(lines, scope, "missing_count[15:0]", "24", 1)
    signal(lines, scope, "scoreboard_pass", "28", 3)
    signal(lines, scope, "cases_done[7:0]", "24", 4)
    lines.extend(["[pattern_trace] 1", "[pattern_trace] 0"])
    return "\n".join(lines) + "\n"


def main() -> int:
    args = parse_args()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(render_gtkw(args), encoding="ascii")
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
