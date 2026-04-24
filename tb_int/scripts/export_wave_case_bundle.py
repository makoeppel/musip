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


def resolve_packet_analyzer_script(root: Path, script_name: str) -> Path:
    candidates = [
        root.parent / "mu3e_ip_dev/mu3e-ip-cores/tools/packet_transaction_traffic_analyzer/scripts" / script_name,
        root / "external/mu3e-ip-cores/tools/packet_transaction_traffic_analyzer/scripts" / script_name,
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    raise FileNotFoundError(f"Unable to locate packet analyzer helper script {script_name!r}")


def resolve_wave_asset(root: Path, rel_path: str) -> Path:
    candidates = [
        root.parent / "mu3e_ip_dev/mu3e-ip-cores/tools/packet_transaction_traffic_analyzer/assets" / rel_path,
        root / "external/mu3e-ip-cores/tools/packet_transaction_traffic_analyzer/assets" / rel_path,
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    raise FileNotFoundError(f"Unable to locate wave asset {rel_path!r}")


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--case-id",
        required=True,
        help="Canonical DV case id, for example B047, E129, P041, X116, or CROSS-004.",
    )
    parser.add_argument("--profile-name", required=True, help="SWB_PROFILE_NAME plusarg value.")
    parser.add_argument("--frames", type=int, default=3, help="Number of frames per lane.")
    parser.add_argument("--seed", type=int, required=True, help="Deterministic SWB_CASE_SEED value.")
    parser.add_argument(
        "--frame-slot-cycles",
        type=int,
        default=4096,
        help="SOP-to-SOP spacing in cycles for waveform evidence. Use 4096 for the physical N_SHD=128 cadence at 250 MHz.",
    )
    parser.add_argument(
        "--sat",
        type=float,
        nargs=4,
        required=True,
        metavar=("SAT0", "SAT1", "SAT2", "SAT3"),
        help="Per-lane saturation values.",
    )
    parser.add_argument(
        "--hit-mode",
        choices=("poisson", "zero", "single", "max"),
        default="poisson",
        help="Per-subheader hit generation mode used by the reference bundle and UVM case builder.",
    )
    parser.add_argument(
        "--feb-enable-mask",
        default="0xf",
        help="FEB enable mask passed to SWB_FEB_ENABLE_MASK. Accepts values like 0xf or f.",
    )
    parser.add_argument("--dma-half-full-pct", type=int, default=0, help="Optional SWB_DMA_HALF_FULL_PCT value.")
    parser.add_argument(
        "--lane-skew-fixed",
        default="0,0,0,0",
        help="Comma-separated per-lane SOP skew in cycles. Use 0,512,1024,2048 for the fixed half-frame profile.",
    )
    parser.add_argument(
        "--lane-skew-varying",
        action="store_true",
        help="Randomize lane 1..3 pre-SOP skew independently per frame.",
    )
    parser.add_argument(
        "--lane-skew-max-cyc",
        type=int,
        default=0,
        help="Maximum varying per-frame skew in cycles.",
    )
    parser.add_argument(
        "--frame-start",
        type=int,
        default=0,
        help="First ingress frame to expose through the packet analyzer.",
    )
    parser.add_argument(
        "--frame-count",
        type=int,
        default=3,
        help="Number of ingress frames to expose through the packet analyzer.",
    )
    parser.add_argument(
        "--out-root",
        type=Path,
        default=Path("tb_int/wave_reports"),
        help="Output root that will receive <bucket>/<case-id>/...",
    )
    parser.add_argument(
        "--svd",
        type=Path,
        default=Path("build/ip/opq_monolithic_4lane_merge.svd"),
        help="Optional SVD file to copy into the bundle. Relative paths resolve from the repo root.",
    )
    parser.add_argument(
        "--ref-source-dir",
        type=Path,
        help="Optional existing replay/reference directory to copy into the bundle instead of regenerating it.",
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


def bucket_name_for_case_id(case_id: str) -> str:
    upper = case_id.upper()
    if re.fullmatch(r"CROSS-\d{3}", upper):
        return "CROSS"
    if re.fullmatch(r"[BEPX]\d{3}", upper):
        return {
            "B": "BASIC",
            "E": "EDGE",
            "P": "PROF",
            "X": "ERROR",
        }[upper[0]]
    raise ValueError(f"Unsupported canonical case id for wave bundle layout: {case_id!r}")


def make_sim_args(args: argparse.Namespace, mask_hex: str, replay_dir: Path | None) -> list[str]:
    sim_args = [
        f"+SWB_PROFILE_NAME={args.profile_name}",
        f"+SWB_FRAMES={args.frames}",
        f"+SWB_FRAME_SLOT_CYCLES={args.frame_slot_cycles}",
        f"+SWB_CASE_SEED={args.seed}",
        f"+SWB_SAT0={args.sat[0]:0.2f}",
        f"+SWB_SAT1={args.sat[1]:0.2f}",
        f"+SWB_SAT2={args.sat[2]:0.2f}",
        f"+SWB_SAT3={args.sat[3]:0.2f}",
    ]
    if args.hit_mode != "poisson":
        sim_args.append(f"+SWB_HIT_MODE={args.hit_mode}")
    if mask_hex != "f":
        sim_args.append(f"+SWB_FEB_ENABLE_MASK={mask_hex}")
    if args.dma_half_full_pct:
        sim_args.append(f"+SWB_DMA_HALF_FULL_PCT={args.dma_half_full_pct}")
    if args.lane_skew_varying:
        sim_args.append("+SWB_LANE_SKEW_VARYING=1")
        sim_args.append(f"+SWB_LANE_SKEW_MAX_CYC={args.lane_skew_max_cyc}")
    else:
        skew_values = [part.strip() for part in args.lane_skew_fixed.split(",")]
        if len(skew_values) != 4:
            raise ValueError("--lane-skew-fixed must provide exactly 4 comma-separated values")
        for lane, skew in enumerate(skew_values):
            sim_args.append(f"+SWB_LANE{lane}_SKEW_CYC={int(skew, 0)}")
    if replay_dir is not None:
        sim_args.append(f"+SWB_REPLAY_DIR={replay_dir}")
    return sim_args


def populate_ref_dir(args: argparse.Namespace, root: Path, ref_script: Path, ref_dir: Path) -> None:
    if args.ref_source_dir is not None:
        source_dir = args.ref_source_dir if args.ref_source_dir.is_absolute() else (root / args.ref_source_dir)
        if not source_dir.is_dir():
            raise FileNotFoundError(f"Replay/reference source directory does not exist: {source_dir}")
        shutil.copytree(source_dir, ref_dir, dirs_exist_ok=True)
        return

    run_cmd(
        [
            "python3",
            str(ref_script),
            "--frames",
            str(args.frames),
            "--seed",
            str(args.seed),
            "--hit-mode",
            args.hit_mode,
            "--sat",
            f"{args.sat[0]:0.2f}",
            f"{args.sat[1]:0.2f}",
            f"{args.sat[2]:0.2f}",
            f"{args.sat[3]:0.2f}",
            "--feb-enable-mask",
            args.feb_enable_mask,
            "--out-dir",
            str(ref_dir),
        ]
        + (
            [
                "--lane-skew-varying",
                "--lane-skew-max-cyc",
                str(args.lane_skew_max_cyc),
            ]
            if args.lane_skew_varying
            else [
                "--lane-skew-fixed",
                args.lane_skew_fixed,
            ]
        ),
        cwd=root,
    )


def write_bundle_readme(
    path: Path,
    bucket: str,
    case_id: str,
    profile_name: str,
    sim_args: list[str],
    summary_lines: dict[str, str],
    vcd_rel: str,
    shared_axis_rel: str | None,
    svd_rel: str | None,
    serve_script: Path,
) -> None:
    serve_cmd = f"python3 {serve_script} --dir tb_int/wave_reports/{bucket}/{case_id}/packet_analyzer --port 8765"
    path.write_text(
        "\n".join(
            [
                f"# `{case_id}` wave bundle",
                "",
                f"- **bucket:** `{bucket}`",
                f"- **profile:** `{profile_name}`",
                f"- **same-axis VCD:** `{vcd_rel}`",
                f"- **shared-axis HTML:** `{shared_axis_rel if shared_axis_rel is not None else 'not generated'}`",
                f"- **bundled SVD:** `{svd_rel if svd_rel is not None else 'not bundled'}`",
                f"- **sim args:** `{shlex.join(sim_args)}`",
                "- **frame cadence:** `SWB_FRAME_SLOT_CYCLES=4096` is the physical `N_SHD=128` SOP spacing at `250 MHz`; smaller values are visualization-only compression.",
                "- **timestamp contract:** frame-header `ts[47:0]` is the time-slice origin in `8 ns` units, starts at `0`, advances by `0x0800` per frame at `N_SHD=128` (`0x1000` at `N_SHD=256`), keeps the lower slice bits zero, and `debug1` is the later live dispatch timestamp rather than a copy of the frame origin.",
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
                "- `bundle.json` names those interface roles explicitly so downstream tools can identify ingress, merged OPQ egress, DMA, and control signals without guessing from the raw VCD.",
                "- When present, `opq.svd` is the register-map snapshot that belongs to the same evidence bundle.",
                "- `packet_analyzer/` is the local shared-axis WaveDrom report generated from `tb_int/`. It is the human-readable ingress/egress/DMA correlation view for the exact same capture.",
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
    min_frames = args.frame_start + args.frame_count
    if args.frames < min_frames:
        args.frames = min_frames
    root = repo_root()
    tb_root = root / "tb_int"
    uvm_dir = tb_root / "cases/basic/uvm"
    ref_script = tb_root / "cases/basic/ref/run_basic_ref.py"
    serve_script = resolve_packet_analyzer_script(root, "serve_packet_analyzer.py")
    shared_axis_script = tb_root / "scripts/generate_opq_twoframe_report.py"
    wavedrom_default = resolve_wave_asset(root, "wavedrom/default.js")
    wavedrom_js = resolve_wave_asset(root, "wavedrom/wavedrom.min.js")

    mask_value, mask_hex = parse_mask(args.feb_enable_mask)

    bucket = bucket_name_for_case_id(args.case_id)
    out_dir = (root / args.out_root / bucket / args.case_id).resolve()
    ref_dir = out_dir / "ref"
    sim_dir = out_dir / "sim"
    analyzer_dir = out_dir / "packet_analyzer"
    bundle_json = out_dir / "bundle.json"
    bundle_readme = out_dir / "README.md"
    vcd_path = sim_dir / f"{args.case_id}.vcd"
    run_log = sim_dir / "run_vcd.log"
    svd_src = args.svd if args.svd.is_absolute() else (root / args.svd)
    svd_dst = out_dir / "opq.svd"

    if out_dir.exists():
        shutil.rmtree(out_dir)
    ref_dir.mkdir(parents=True, exist_ok=True)
    sim_dir.mkdir(parents=True, exist_ok=True)

    populate_ref_dir(args, root, ref_script, ref_dir)

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
    sim_args = make_sim_args(args, mask_hex, ref_dir if args.ref_source_dir is not None else None)

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

    analyzer_dir.mkdir(parents=True, exist_ok=True)
    shared_axis_html = analyzer_dir / "index.html"
    run_cmd(
        [
            "python3",
            str(shared_axis_script),
            "--vcd",
            str(vcd_path),
            "--ref-dir",
            str(ref_dir),
            "--out-html",
            str(shared_axis_html),
            "--frame-start",
            str(args.frame_start),
            "--frame-count",
            str(args.frame_count),
            "--frame-slot-cycles",
            str(args.frame_slot_cycles),
        ],
        cwd=root,
    )
    shutil.copy2(wavedrom_default, analyzer_dir / "default.js")
    shutil.copy2(wavedrom_js, analyzer_dir / "wavedrom.min.js")

    svd_rel: str | None = None
    if svd_src.is_file():
        shutil.copy2(svd_src, svd_dst)
        svd_rel = str(svd_dst.relative_to(out_dir))

    summary_lines = collect_summary_lines(run_log)
    shared_axis_rel = str(shared_axis_html.relative_to(out_dir))
    bundle_payload = {
        "bucket": bucket,
        "case_id": args.case_id,
        "profile_name": args.profile_name,
        "frames": args.frames,
        "seed": args.seed,
        "hit_mode": args.hit_mode,
        "frame_slot_cycles": args.frame_slot_cycles,
        "lane_saturation": list(args.sat),
        "feb_enable_mask": f"0x{mask_value:x}",
        "dma_half_full_pct": args.dma_half_full_pct,
        "lane_skew": {
            "fixed_cycles": [int(part.strip(), 0) for part in args.lane_skew_fixed.split(",")],
            "varying": args.lane_skew_varying,
            "max_cyc": args.lane_skew_max_cyc,
        },
        "frame_window": {
            "frame_start": args.frame_start,
            "frame_count": args.frame_count,
        },
        "timestamp_contract": {
            "unit": "8ns",
            "frame_origin_role": "time-slice origin carried by the frame header",
            "frame_origin_start": 0,
            "frame_stride_units_nshd128": 2048,
            "frame_stride_hex_nshd128": "0x0800",
            "frame_stride_hex_nshd256": "0x1000",
            "frame_low_bits_rule": "lower slice bits are zero in the frame header timestamp",
            "debug1_role": "dispatch timestamp sampled from the live global counter",
            "debug1_relation": "ingress debug1 is later than or equal to the frame origin and OPQ may delay it further",
        },
        "signal_roles": {
            "clock": {"role": "clock", "path": "tb_top.clk"},
            "interfaces": [
                {"role": "ingress", "lane": 0, "path": "tb_top.feb_if0", "kind": "feb_ingress_if"},
                {"role": "ingress", "lane": 1, "path": "tb_top.feb_if1", "kind": "feb_ingress_if"},
                {"role": "ingress", "lane": 2, "path": "tb_top.feb_if2", "kind": "feb_ingress_if"},
                {"role": "ingress", "lane": 3, "path": "tb_top.feb_if3", "kind": "feb_ingress_if"},
                {"role": "egress", "path": "tb_top.opq_if", "kind": "opq_egress_if"},
                {"role": "dma", "path": "tb_top.dma_if", "kind": "dma_sink_if"},
                {"role": "control", "path": "tb_top.ctrl_if", "kind": "swb_ctrl_if"},
            ],
        },
        "artifacts": {
            "vcd": str(vcd_path.relative_to(out_dir)),
            "run_log": str(run_log.relative_to(out_dir)),
            "ref_dir": str(ref_dir.relative_to(out_dir)),
            "packet_analyzer": str(analyzer_dir.relative_to(out_dir)),
            "shared_axis": shared_axis_rel,
            "svd": svd_rel,
        },
        "summary_lines": summary_lines,
    }
    bundle_json.write_text(json.dumps(bundle_payload, indent=2) + "\n", encoding="utf-8")
    write_bundle_readme(
        bundle_readme,
        bucket,
        args.case_id,
        args.profile_name,
        sim_args,
        summary_lines,
        str(vcd_path.relative_to(out_dir)),
        shared_axis_rel,
        svd_rel,
        serve_script,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
