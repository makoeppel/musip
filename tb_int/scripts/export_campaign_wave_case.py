#!/usr/bin/env python3
"""Export a representative-run waveform bundle for a promoted longrun campaign case."""

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


def run_cmd(cmd: list[str], cwd: Path) -> None:
    subprocess.run(cmd, cwd=cwd, check=True)


def append_campaign_section(readme_path: Path, campaign: dict[str, object], bundle_rel_summary: str, bundle_rel_run_log: str | None) -> None:
    base = readme_path.read_text(encoding="utf-8")
    extra_lines = [
        "## Campaign context",
        "",
        f"- **campaign seed:** `{campaign['campaign_seed']}`",
        f"- **campaign runs:** `{campaign['runs_executed']} / {campaign['runs_requested']}`",
        f"- **representative run id:** `{campaign['representative_run']['run_id']}`",
        f"- **representative case seed:** `{campaign['representative_run']['case_seed']}`",
        f"- **representative rates:** `{', '.join(f'{value:0.2f}' for value in campaign['representative_run']['rates'])}`",
        f"- **campaign summary copy:** `{bundle_rel_summary}`",
        f"- **campaign run log copy:** `{bundle_rel_run_log if bundle_rel_run_log is not None else 'not bundled'}`",
        "",
    ]
    readme_path.write_text(base + "\n".join(extra_lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Export a representative-run bundle for a longrun campaign case")
    parser.add_argument("--case-id", required=True)
    parser.add_argument("--campaign-summary", type=Path, required=True)
    parser.add_argument("--run-id", type=int, required=True)
    parser.add_argument("--profile-name", default="", help="Optional profile name override passed to export_wave_case_bundle.py")
    parser.add_argument("--frame-count", type=int, default=3, help="Number of frames to expose in the analyzer window")
    parser.add_argument(
        "--frame-start",
        type=int,
        default=-1,
        help="First displayed frame. Use -1 to select the middle window when the capture is deeper than frame-count.",
    )
    parser.add_argument("--out-root", type=Path, default=Path("tb_int/wave_reports"))
    args = parser.parse_args()

    root = repo_root()
    summary_path = args.campaign_summary if args.campaign_summary.is_absolute() else (root / args.campaign_summary)
    if not summary_path.is_file():
        raise FileNotFoundError(f"Campaign summary not found: {summary_path}")

    campaign_summary = json.loads(summary_path.read_text(encoding="utf-8"))
    results = campaign_summary["results"]
    if args.run_id < 0 or args.run_id >= len(results):
        raise ValueError(f"run-id {args.run_id} is out of range for summary with {len(results)} runs")
    representative = results[args.run_id]

    frames = max(int(campaign_summary["frames"]), args.frame_count)
    frame_start = args.frame_start
    if frame_start < 0:
        frame_start = max(0, (frames - args.frame_count) // 2)

    export_cmd = [
        "python3",
        str(root / "tb_int/scripts/export_wave_case_bundle.py"),
        "--case-id",
        args.case_id,
        "--profile-name",
        args.profile_name or args.case_id,
        "--frames",
        str(frames),
        "--seed",
        str(representative["case_seed"]),
        "--sat",
        *(f"{float(value):0.2f}" for value in representative["rates"]),
        "--frame-start",
        str(frame_start),
        "--frame-count",
        str(args.frame_count),
        "--out-root",
        str(args.out_root),
    ]
    run_cmd(export_cmd, cwd=root)

    bucket = bucket_name_for_case_id(args.case_id)
    bundle_dir = (root / args.out_root / bucket / args.case_id).resolve()
    ref_dir = bundle_dir / "ref"
    bundle_json = bundle_dir / "bundle.json"
    bundle_readme = bundle_dir / "README.md"

    campaign_summary_copy = ref_dir / "campaign_summary.json"
    shutil.copy2(summary_path, campaign_summary_copy)

    uvm_dir = summary_path.parents[2]
    campaign_run_log_copy: Path | None = None
    log_rel = representative.get("log_path")
    if isinstance(log_rel, str):
        campaign_run_log = (uvm_dir / log_rel).resolve()
        if campaign_run_log.is_file():
            campaign_run_log_copy = ref_dir / "campaign_run.log"
            shutil.copy2(campaign_run_log, campaign_run_log_copy)

    payload = json.loads(bundle_json.read_text(encoding="utf-8"))
    payload["campaign"] = {
        "summary_json": str(campaign_summary_copy.relative_to(bundle_dir)),
        "runs_requested": campaign_summary["runs_requested"],
        "runs_executed": campaign_summary["runs_executed"],
        "pass_count": campaign_summary["pass_count"],
        "fail_count": campaign_summary["fail_count"],
        "campaign_seed": campaign_summary["campaign_seed"],
        "rate_grid": campaign_summary["rate_grid"],
        "representative_run": representative,
    }
    bundle_json.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    append_campaign_section(
        bundle_readme,
        payload["campaign"],
        str(campaign_summary_copy.relative_to(bundle_dir)),
        str(campaign_run_log_copy.relative_to(bundle_dir)) if campaign_run_log_copy is not None else None,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
