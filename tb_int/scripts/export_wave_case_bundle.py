#!/usr/bin/env python3
"""Export a reproducible per-case waveform/analyzer bundle under tb_int/wave_reports."""

from __future__ import annotations

import argparse
import json
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case-id", required=True, help="Wave bundle directory name under tb_int/wave_reports.")
    parser.add_argument("--profile-name", required=True, help="SWB_PROFILE_NAME plusarg value.")
    parser.add_argument("--frames", type=int, default=2, help="Number of frames per lane.")
    parser.add_argument("--seed", type=int, required=True, help="Deterministic SWB_CASE_SEED value.")
    parser.add_argument(
        "--sat",
        type=float,
        nargs=4,
        required=True,
        metavar=("SAT0", "SAT1", "SAT2", "SAT3"),
        help="Per-lane saturation values.",
    )
    parser.add_argument(
        "--feb-enable-mask",
        default="0xf",
        help="FEB enable mask passed to SWB_FEB_ENABLE_MASK. Accepts values like 0xf or f.",
    )
    parser.add_argument("--dma-half-full-pct", type=int, default=0, help="Optional SWB_DMA_HALF_FULL_PCT value.")
    parser.add_argument(
        "--frame-start",
        type=int,
        default=0,
        help="First ingress frame to expose through the packet analyzer.",
    )
    parser.add_argument(
        "--frame-count",
        type=int,
        default=2,
        help="Number of ingress frames to expose through the packet analyzer.",
    )
    parser.add_argument(
        "--out-root",
        type=Path,
        default=Path("tb_int/wave_reports"),
        help="Output root that will receive <case-id>/...",
    )
    return parser


def run_cmd(cmd: list[str], cwd: Path) -> None:
    subprocess.run(cmd, cwd=cwd, check=True)


def parse_mask(raw: str) -> tuple[int, str]:
    text = raw.strip().lower()
    if text.startswith("0x"):
        value = int(text, 16)
    else:
        value = int(text, 16)
    if value < 0 or value > 0xF:
        raise ValueError(f"FEB enable mask must fit in 4 bits, got {raw!r}")
    return value, f"{value:x}"


def make_sim_args(args: argparse.Namespace, mask_hex: str) -> list[str]:
    sim_args = [
        f"+SWB_PROFILE_NAME={args.profile_name}",
        f"+SWB_FRAMES={args.frames}",
        f"+SWB_CASE_SEED={args.seed}",
        f"+SWB_SAT0={args.sat[0]:0.2f}",
        f"+SWB_SAT1={args.sat[1]:0.2f}",
        f"+SWB_SAT2={args.sat[2]:0.2f}",
        f"+SWB_SAT3={args.sat[3]:0.2f}",
    ]
    if mask_hex != "f":
        sim_args.append(f"+SWB_FEB_ENABLE_MASK={mask_hex}")
    if args.dma_half_full_pct:
        sim_args.append(f"+SWB_DMA_HALF_FULL_PCT={args.dma_half_full_pct}")
    return sim_args


def write_bundle_readme(
    path: Path,
    case_id: str,
    profile_name: str,
    sim_args: list[str],
    summary_lines: dict[str, str],
    vcd_rel: str,
) -> None:
    serve_cmd = (
        "python3 external/mu3e-ip-cores/tools/packet_transaction_traffic_analyzer/scripts/"
        f"serve_packet_analyzer.py --dir tb_int/wave_reports/{case_id}/packet_analyzer --port 8765"
    )
    path.write_text(
        "\n".join(
            [
                f"# `{case_id}` wave bundle",
                "",
                f"- **profile:** `{profile_name}`",
                f"- **same-axis VCD:** `{vcd_rel}`",
                f"- **sim args:** `{shlex.join(sim_args)}`",
                "",
                "## Captured summary",
                "",
                f"- **start:** `{summary_lines.get('start_time', 'n/a')}`",
                f"- **case:** `{summary_lines.get('case', 'n/a')}`",
                f"- **opq:** `{summary_lines.get('opq', 'n/a')}`",
                f"- **dma:** `{summary_lines.get('dma', 'n/a')}`",
                f"- **dma_summary:** `{summary_lines.get('dma_summary', 'n/a')}`",
                f"- **pass:** `{summary_lines.get('pass', 'n/a')}`",
                f"- **end:** `{summary_lines.get('end_time', 'n/a')}`",
                "",
                "## Notes",
                "",
                "- The recorded VCD keeps `feb_if0..3`, `opq_if`, `dma_if`, and `ctrl_if` on the same clock/time axis.",
                "- The packet analyzer bundle decodes ingress packets from the same VCD; use GTKWave or Questa on the VCD when you want to correlate those ingress packets against `opq_if` and `dma_if` cycle-by-cycle.",
                "",
                "## Serve",
                "",
                f"`{serve_cmd}`",
                "",
            ]
        )
        + "\n",
        encoding="utf-8",
    )


def collect_summary_lines(run_log: Path) -> dict[str, str]:
    patterns = {
        "start_time": re.compile(r"^# Start time:"),
        "case": re.compile(r"\[CASE\]"),
        "opq": re.compile(r"\[HIT_STAGE_SUMMARY\] opq"),
        "dma": re.compile(r"\[HIT_STAGE_SUMMARY\] dma"),
        "dma_summary": re.compile(r"\[DMA_SUMMARY\]"),
        "pass": re.compile(r"\[SWB_CHECK_PASS\]"),
        "end_time": re.compile(r"^# End time:"),
    }
    found: dict[str, str] = {}
    for raw_line in run_log.read_text(encoding="utf-8", errors="ignore").splitlines():
        for key, pattern in patterns.items():
            if key in found:
                continue
            if pattern.search(raw_line):
                found[key] = raw_line.strip()
    return found


def main(argv: list[str]) -> int:
    args = build_arg_parser().parse_args(argv)
    root = repo_root()
    tb_root = root / "tb_int"
    uvm_dir = tb_root / "cases/basic/uvm"
    ref_script = tb_root / "cases/basic/ref/run_basic_ref.py"
    analyzer_script = (
        root
        / "external/mu3e-ip-cores/tools/packet_transaction_traffic_analyzer/scripts/generate_musip_packet_analyzer.py"
    )

    mask_value, mask_hex = parse_mask(args.feb_enable_mask)

    out_dir = (root / args.out_root / args.case_id).resolve()
    ref_dir = out_dir / "ref"
    sim_dir = out_dir / "sim"
    analyzer_dir = out_dir / "packet_analyzer"
    bundle_json = out_dir / "bundle.json"
    bundle_readme = out_dir / "README.md"
    vcd_path = sim_dir / f"{args.case_id}.vcd"
    run_log = sim_dir / "run_vcd.log"

    if out_dir.exists():
        shutil.rmtree(out_dir)
    ref_dir.mkdir(parents=True, exist_ok=True)
    sim_dir.mkdir(parents=True, exist_ok=True)

    run_cmd(
        [
            "python3",
            str(ref_script),
            "--frames",
            str(args.frames),
            "--seed",
            str(args.seed),
            "--sat",
            f"{args.sat[0]:0.2f}",
            f"{args.sat[1]:0.2f}",
            f"{args.sat[2]:0.2f}",
            f"{args.sat[3]:0.2f}",
            "--out-dir",
            str(ref_dir),
        ],
        cwd=root,
    )

    do_script = (
        f"vcd file {vcd_path}; "
        "vcd add /tb_top/clk; "
        "vcd add -r /tb_top/feb_if0/*; "
        "vcd add -r /tb_top/feb_if1/*; "
        "vcd add -r /tb_top/feb_if2/*; "
        "vcd add -r /tb_top/feb_if3/*; "
        "vcd add -r /tb_top/opq_if/*; "
        "vcd add -r /tb_top/dma_if/*; "
        "vcd add -r /tb_top/ctrl_if/*; "
        "run -all; quit -f"
    )
    sim_args = make_sim_args(args, mask_hex)

    run_cmd(
        [
            "make",
            "-C",
            str(uvm_dir),
            "run",
            f"RUN_LOG={run_log}",
            f"RUN_DO={do_script}",
            f"SIM_ARGS={' '.join(sim_args)}",
        ],
        cwd=root,
    )

    run_cmd(
        [
            "python3",
            str(analyzer_script),
            "--vcd",
            str(vcd_path),
            "--out-dir",
            str(analyzer_dir),
            "--frame-start",
            str(args.frame_start),
            "--frame-count",
            str(args.frame_count),
        ],
        cwd=root,
    )

    summary_lines = collect_summary_lines(run_log)
    bundle_payload = {
        "case_id": args.case_id,
        "profile_name": args.profile_name,
        "frames": args.frames,
        "seed": args.seed,
        "lane_saturation": list(args.sat),
        "feb_enable_mask": f"0x{mask_value:x}",
        "dma_half_full_pct": args.dma_half_full_pct,
        "frame_window": {
            "frame_start": args.frame_start,
            "frame_count": args.frame_count,
        },
        "artifacts": {
            "vcd": str(vcd_path.relative_to(out_dir)),
            "run_log": str(run_log.relative_to(out_dir)),
            "ref_dir": str(ref_dir.relative_to(out_dir)),
            "packet_analyzer": str(analyzer_dir.relative_to(out_dir)),
        },
        "summary_lines": summary_lines,
    }
    bundle_json.write_text(json.dumps(bundle_payload, indent=2) + "\n", encoding="utf-8")
    write_bundle_readme(
        bundle_readme,
        args.case_id,
        args.profile_name,
        sim_args,
        summary_lines,
        str(vcd_path.relative_to(out_dir)),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
