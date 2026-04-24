#!/usr/bin/env python3
"""Export a replay-backed plain-harness waveform bundle under tb_int/wave_reports."""

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


def run_cmd(cmd: list[str], cwd: Path, capture_path: Path | None = None) -> str:
    if capture_path is None:
        subprocess.run(cmd, cwd=cwd, check=True)
        return ""
    proc = subprocess.run(
        cmd,
        cwd=cwd,
        check=True,
        text=True,
        capture_output=True,
    )
    capture_path.write_text(proc.stdout + proc.stderr, encoding="utf-8")
    return proc.stdout


def collect_summary_lines(run_log: Path, dma_check_summary: Path) -> dict[str, str]:
    patterns = {
        "start_time": re.compile(r"^# Start time:"),
        "end_time": re.compile(r"^# End time:"),
    }
    found: dict[str, str] = {}
    for raw_line in run_log.read_text(encoding="utf-8", errors="ignore").splitlines():
        for key, pattern in patterns.items():
            if key in found:
                continue
            if pattern.search(raw_line):
                found[key] = raw_line.strip()
    summary_text = dma_check_summary.read_text(encoding="utf-8", errors="ignore").strip()
    if summary_text:
        found["pass"] = summary_text.splitlines()[0]
    return found


def write_bundle_readme(
    path: Path,
    bucket: str,
    case_id: str,
    sim_args: str,
    summary_lines: dict[str, str],
    vcd_rel: str,
    actual_dma_rel: str,
    check_summary_rel: str,
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
                f"- **actual DMA capture:** `{actual_dma_rel}`",
                f"- **DMA semantic summary:** `{check_summary_rel}`",
                f"- **bundled SVD:** `{svd_rel if svd_rel is not None else 'not bundled'}`",
                f"- **sim args:** `{sim_args if sim_args else '(none)'}`",
                "- **timestamp contract:** frame-header `ts[47:0]` is the time-slice origin in `8 ns` units, starts at `0`, advances by `0x0800` per frame at `N_SHD=128`, and `debug1` is the later live dispatch timestamp rather than the frame origin.",
                "",
                "## Captured summary",
                "",
                f"- **start:** `{summary_lines.get('start_time', 'n/a')}`",
                f"- **pass:** `{summary_lines.get('pass', 'n/a')}`",
                f"- **end:** `{summary_lines.get('end_time', 'n/a')}`",
                "",
                "## Notes",
                "",
                "- This plain harness records raw ingress buses plus raw OPQ and DMA signals under `tb_swb_block_plain_replay`; the analyzer decodes them with the `plain` signal-layout mode and still renders ingress, merged OPQ egress, and DMA on the same time axis.",
                "- `bundle.json` names the raw signal groups explicitly so downstream tools can identify ingress lane slices, merged OPQ egress, DMA, and control-state signals from the VCD without guessing.",
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
    parser = argparse.ArgumentParser(description="Export a replay-backed plain-harness waveform bundle")
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
    plain_dir = tb_root / "cases/basic/plain"
    check_script = plain_dir / "check_dma_hits.py"
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
    actual_dma_words = sim_dir / "actual_dma_words.mem"
    dma_check_summary = sim_dir / "dma_check_summary.txt"
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
        "vcd add /tb_swb_block_plain_replay/clk; "
        "vcd add /tb_swb_block_plain_replay/reset_n; "
        "vcd add /tb_swb_block_plain_replay/feb_valid; "
        "vcd add /tb_swb_block_plain_replay/feb_data; "
        "vcd add /tb_swb_block_plain_replay/feb_datak; "
        "vcd add /tb_swb_block_plain_replay/feb_err_desc; "
        "vcd add /tb_swb_block_plain_replay/feb_enable_mask; "
        "vcd add /tb_swb_block_plain_replay/use_merge; "
        "vcd add /tb_swb_block_plain_replay/enable_dma; "
        "vcd add /tb_swb_block_plain_replay/get_n_words; "
        "vcd add /tb_swb_block_plain_replay/lookup_ctrl; "
        "vcd add /tb_swb_block_plain_replay/dma_half_full; "
        "vcd add /tb_swb_block_plain_replay/opq_valid; "
        "vcd add /tb_swb_block_plain_replay/opq_data; "
        "vcd add /tb_swb_block_plain_replay/opq_datak; "
        "vcd add /tb_swb_block_plain_replay/dma_wren; "
        "vcd add /tb_swb_block_plain_replay/dma_data; "
        "vcd add /tb_swb_block_plain_replay/end_of_event; "
        "vcd add /tb_swb_block_plain_replay/dma_done; "
        "vcd add /tb_swb_block_plain_replay/lane_done; "
        "run -all; quit -f"
    )

    make_args = [
        "make",
        "-C",
        str(plain_dir),
        args.make_target,
        f"RUN_DO={do_script}",
    ]
    if args.make_target == "run-smoke":
        make_args.append(f"RUN_LOG_SMOKE={run_log}")
        make_args.append(f"SMOKE_REPLAY_DIR={ref_dir}")
        make_args.append(f"ACTUAL_DMA_WORDS_SMOKE={actual_dma_words}")
    else:
        make_args.append(f"RUN_LOG={run_log}")
        make_args.append(f"REPLAY_DIR={ref_dir}")
        make_args.append(f"ACTUAL_DMA_WORDS={actual_dma_words}")
    if args.sim_args:
        make_args.append(f"SIM_ARGS={args.sim_args}")
    run_cmd(make_args, cwd=root)

    check_output = run_cmd(
        [
            "python3",
            str(check_script),
            "--expected",
            str(ref_dir / "expected_dma_words.mem"),
            "--actual",
            str(actual_dma_words),
        ],
        cwd=root,
        capture_path=dma_check_summary,
    )
    if check_output and not check_output.endswith("\n"):
        dma_check_summary.write_text(check_output + "\n", encoding="utf-8")

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
            "tb_swb_block_plain_replay",
            "--signal-layout",
            "plain",
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

    summary_lines = collect_summary_lines(run_log, dma_check_summary)
    bundle_payload = {
        "bucket": bucket,
        "case_id": args.case_id,
        "frames": args.frame_start + args.frame_count,
        "frame_window": {
            "frame_start": args.frame_start,
            "frame_count": args.frame_count,
        },
        "signal_roles": {
            "clock": {"role": "clock", "path": "tb_swb_block_plain_replay.clk"},
            "interfaces": [
                {
                    "role": "ingress",
                    "lane": 0,
                    "kind": "feb_lane_raw",
                    "valid_path": "tb_swb_block_plain_replay.feb_valid[0]",
                    "data_path": "tb_swb_block_plain_replay.feb_data[31:0]",
                    "datak_path": "tb_swb_block_plain_replay.feb_datak[3:0]",
                },
                {
                    "role": "ingress",
                    "lane": 1,
                    "kind": "feb_lane_raw",
                    "valid_path": "tb_swb_block_plain_replay.feb_valid[1]",
                    "data_path": "tb_swb_block_plain_replay.feb_data[63:32]",
                    "datak_path": "tb_swb_block_plain_replay.feb_datak[7:4]",
                },
                {
                    "role": "ingress",
                    "lane": 2,
                    "kind": "feb_lane_raw",
                    "valid_path": "tb_swb_block_plain_replay.feb_valid[2]",
                    "data_path": "tb_swb_block_plain_replay.feb_data[95:64]",
                    "datak_path": "tb_swb_block_plain_replay.feb_datak[11:8]",
                },
                {
                    "role": "ingress",
                    "lane": 3,
                    "kind": "feb_lane_raw",
                    "valid_path": "tb_swb_block_plain_replay.feb_valid[3]",
                    "data_path": "tb_swb_block_plain_replay.feb_data[127:96]",
                    "datak_path": "tb_swb_block_plain_replay.feb_datak[15:12]",
                },
                {
                    "role": "egress",
                    "kind": "opq_raw",
                    "valid_path": "tb_swb_block_plain_replay.opq_valid",
                    "data_path": "tb_swb_block_plain_replay.opq_data",
                    "datak_path": "tb_swb_block_plain_replay.opq_datak",
                },
                {
                    "role": "dma",
                    "kind": "dma_raw",
                    "wren_path": "tb_swb_block_plain_replay.dma_wren",
                    "data_path": "tb_swb_block_plain_replay.dma_data",
                    "end_of_event_path": "tb_swb_block_plain_replay.end_of_event",
                    "done_path": "tb_swb_block_plain_replay.dma_done",
                },
            ],
            "control_signals": [
                "tb_swb_block_plain_replay.reset_n",
                "tb_swb_block_plain_replay.enable_dma",
                "tb_swb_block_plain_replay.feb_enable_mask",
                "tb_swb_block_plain_replay.lookup_ctrl",
                "tb_swb_block_plain_replay.dma_half_full",
                "tb_swb_block_plain_replay.use_merge",
                "tb_swb_block_plain_replay.lane_done",
            ],
        },
        "artifacts": {
            "vcd": str(vcd_path.relative_to(out_dir)),
            "run_log": str(run_log.relative_to(out_dir)),
            "actual_dma_words": str(actual_dma_words.relative_to(out_dir)),
            "dma_check_summary": str(dma_check_summary.relative_to(out_dir)),
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
        str(actual_dma_words.relative_to(out_dir)),
        str(dma_check_summary.relative_to(out_dir)),
        svd_rel,
        serve_script,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
