#!/usr/bin/env python3
"""Export a replay-backed plain_2env waveform bundle under tb_int/wave_reports."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def bucket_name_for_case_id(case_id: str) -> str:
    upper = case_id.upper()
    if re.fullmatch(r"[BEPX]\d{3}", upper):
        return {
            "B": "BASIC",
            "E": "EDGE",
            "P": "PROF",
            "X": "ERROR",
        }[upper[0]]
    raise ValueError(f"Unsupported canonical case id for wave bundle layout: {case_id!r}")


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


def run_cmd(cmd: list[str], cwd: Path) -> None:
    subprocess.run(cmd, cwd=cwd, check=True)


def collect_summary_lines(run_log: Path) -> dict[str, str]:
    patterns = {
        "start_time": re.compile(r"^# Start time:"),
        "opq_boundary": re.compile(r"\[OPQ_BOUNDARY_SUMMARY\]"),
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


def write_bundle_readme(
    path: Path,
    bucket: str,
    case_id: str,
    sim_args: str,
    summary_lines: dict[str, str],
    vcd_rel: str,
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
                f"- **same-axis VCD:** `{vcd_rel}`",
                f"- **bundled SVD:** `{svd_rel if svd_rel is not None else 'not bundled'}`",
                f"- **sim args:** `{sim_args if sim_args else '(none)'}`",
                "- **timestamp contract:** frame-header `ts[47:0]` is the time-slice origin in `8 ns` units, starts at `0`, advances by `0x0800` per frame at `N_SHD=128`, and `debug1` is the later live dispatch timestamp.",
                "",
                "## Captured summary",
                "",
                f"- **start:** `{summary_lines.get('start_time', 'n/a')}`",
                f"- **opq_boundary:** `{summary_lines.get('opq_boundary', 'n/a')}`",
                f"- **dma_summary:** `{summary_lines.get('dma_summary', 'n/a')}`",
                f"- **pass:** `{summary_lines.get('pass', 'n/a')}`",
                f"- **end:** `{summary_lines.get('end_time', 'n/a')}`",
                "",
                "## Notes",
                "",
                "- The recorded VCD keeps `feb_if0..3`, `opq_if`, `dma_if`, and `ctrl_if` on the same clock/time axis under `tb_top_2env`.",
                "- `bundle.json` names those interface roles explicitly so downstream tools can identify ingress, OPQ seam egress, DMA, and control signals without guessing from the raw VCD.",
                "- `packet_analyzer/` is the local shared-axis WaveDrom report generated from `tb_int/`; it is the human-readable ingress/egress/DMA correlation view for this split-harness capture.",
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


def main() -> int:
    parser = argparse.ArgumentParser(description="Export a replay-backed plain_2env waveform bundle")
    parser.add_argument("--case-id", required=True)
    parser.add_argument("--replay-source-dir", type=Path, required=True)
    parser.add_argument("--make-target", choices=("run", "run-smoke"), required=True)
    parser.add_argument("--sim-args", default="", help="Optional raw SIM_ARGS string passed through to make")
    parser.add_argument("--frame-start", type=int, default=0)
    parser.add_argument("--frame-count", type=int, default=3)
    parser.add_argument("--out-root", type=Path, default=Path("tb_int/wave_reports"))
    parser.add_argument("--svd", type=Path, default=Path("build/ip/opq_monolithic_4lane_merge.svd"))
    args = parser.parse_args()

    root = repo_root()
    tb_root = root / "tb_int"
    plain_2env_dir = tb_root / "cases/basic/plain_2env"
    shared_axis_script = tb_root / "scripts/generate_opq_twoframe_report.py"
    serve_script = resolve_packet_analyzer_script(root, "serve_packet_analyzer.py")
    wavedrom_default = resolve_wave_asset(root, "wavedrom/default.js")
    wavedrom_js = resolve_wave_asset(root, "wavedrom/wavedrom.min.js")
    svd_src = args.svd if args.svd.is_absolute() else (root / args.svd)

    bucket = bucket_name_for_case_id(args.case_id)
    out_dir = (root / args.out_root / bucket / args.case_id).resolve()
    ref_dir = out_dir / "ref"
    sim_dir = out_dir / "sim"
    analyzer_dir = out_dir / "packet_analyzer"
    bundle_json = out_dir / "bundle.json"
    bundle_readme = out_dir / "README.md"
    vcd_path = sim_dir / f"{args.case_id}.vcd"
    run_log = sim_dir / "run_vcd.log"
    svd_dst = out_dir / "opq.svd"

    if out_dir.exists():
        shutil.rmtree(out_dir)
    ref_dir.mkdir(parents=True, exist_ok=True)
    sim_dir.mkdir(parents=True, exist_ok=True)
    analyzer_dir.mkdir(parents=True, exist_ok=True)

    replay_source_dir = args.replay_source_dir if args.replay_source_dir.is_absolute() else (root / args.replay_source_dir)
    if not replay_source_dir.is_dir():
        raise FileNotFoundError(f"Replay source directory does not exist: {replay_source_dir}")
    shutil.copytree(replay_source_dir, ref_dir, dirs_exist_ok=True)

    do_script = (
        f"vcd file {vcd_path}; "
        "vcd add /tb_top_2env/clk; "
        "vcd add -r /tb_top_2env/feb_if0/*; "
        "vcd add -r /tb_top_2env/feb_if1/*; "
        "vcd add -r /tb_top_2env/feb_if2/*; "
        "vcd add -r /tb_top_2env/feb_if3/*; "
        "vcd add -r /tb_top_2env/opq_if/*; "
        "vcd add -r /tb_top_2env/dma_if/*; "
        "vcd add -r /tb_top_2env/ctrl_if/*; "
        "run -all; quit -f"
    )

    make_args = [
        "make",
        "-C",
        str(plain_2env_dir),
        args.make_target,
        f"RUN_DO={do_script}",
    ]
    if args.make_target == "run-smoke":
        make_args.append(f"RUN_LOG_SMOKE={run_log}")
        make_args.append(f"SMOKE_REPLAY_DIR={ref_dir}")
    else:
        make_args.append(f"RUN_LOG={run_log}")
        make_args.append(f"REPLAY_DIR={ref_dir}")
    if args.sim_args:
        make_args.append(f"SIM_ARGS={args.sim_args}")
    run_cmd(make_args, cwd=root)

    run_cmd(
        [
            "python3",
            str(shared_axis_script),
            "--vcd",
            str(vcd_path),
            "--ref-dir",
            str(ref_dir),
            "--out-html",
            str(analyzer_dir / "index.html"),
            "--top-scope",
            "tb_top_2env",
            "--frame-start",
            str(args.frame_start),
            "--frame-count",
            str(args.frame_count),
            "--frame-slot-cycles",
            "4096",
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
    bundle_payload = {
        "bucket": bucket,
        "case_id": args.case_id,
        "frames": args.frame_start + args.frame_count,
        "frame_window": {
            "frame_start": args.frame_start,
            "frame_count": args.frame_count,
        },
        "signal_roles": {
            "clock": {"role": "clock", "path": "tb_top_2env.clk"},
            "interfaces": [
                {"role": "ingress", "lane": 0, "path": "tb_top_2env.feb_if0", "kind": "feb_ingress_if"},
                {"role": "ingress", "lane": 1, "path": "tb_top_2env.feb_if1", "kind": "feb_ingress_if"},
                {"role": "ingress", "lane": 2, "path": "tb_top_2env.feb_if2", "kind": "feb_ingress_if"},
                {"role": "ingress", "lane": 3, "path": "tb_top_2env.feb_if3", "kind": "feb_ingress_if"},
                {"role": "egress", "path": "tb_top_2env.opq_if", "kind": "opq_egress_if"},
                {"role": "dma", "path": "tb_top_2env.dma_if", "kind": "dma_sink_if"},
                {"role": "control", "path": "tb_top_2env.ctrl_if", "kind": "swb_ctrl_if"},
            ],
        },
        "artifacts": {
            "vcd": str(vcd_path.relative_to(out_dir)),
            "run_log": str(run_log.relative_to(out_dir)),
            "ref_dir": str(ref_dir.relative_to(out_dir)),
            "packet_analyzer": str(analyzer_dir.relative_to(out_dir)),
            "shared_axis": str((analyzer_dir / "index.html").relative_to(out_dir)),
            "svd": svd_rel,
        },
        "summary_lines": summary_lines,
    }
    bundle_json.write_text(json.dumps(bundle_payload, indent=2) + "\n", encoding="utf-8")
    write_bundle_readme(
        bundle_readme,
        bucket,
        args.case_id,
        args.sim_args,
        summary_lines,
        str(vcd_path.relative_to(out_dir)),
        svd_rel,
        serve_script,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
