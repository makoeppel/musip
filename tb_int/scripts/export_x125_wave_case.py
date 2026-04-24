#!/usr/bin/env python3
"""Export the combined plain + 2env waveform bundle for X125."""

from __future__ import annotations

import argparse
import collections
import csv
import html
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path


DMA_WORD_BITS = 256
DMA_PADDING_WORD = (1 << DMA_WORD_BITS) - 1
HIT_WORD_BITS = 64
HIT_MASK = (1 << HIT_WORD_BITS) - 1
HIT_RSVD_MASK = ~(((1 << 5) - 1) << 58) & HIT_MASK


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


def read_plain_dma_hits(path: Path) -> tuple[list[int], int, int]:
    plain_words = 0
    padding_words = 0
    hits: list[int] = []
    for raw_line in path.read_text(encoding="ascii").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        plain_words += 1
        word = int(line, 16)
        if word == DMA_PADDING_WORD:
            padding_words += 1
            continue
        for slot in range(4):
            hits.append(((word >> (slot * HIT_WORD_BITS)) & HIT_MASK) & HIT_RSVD_MASK)
    return hits, plain_words, padding_words


def read_twoenv_dma_hits(path: Path) -> list[int]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        return [int(row["normalized_hit_word"], 16) for row in reader if row.get("stage_name") == "dma"]


def write_compare_summary(path: Path, plain_hits: list[int], plain_words: int, plain_padding: int, twoenv_hits: list[int]) -> dict[str, str]:
    counter_match = collections.Counter(plain_hits) == collections.Counter(twoenv_hits)
    order_exact = plain_hits == twoenv_hits
    summary_lines = {
        "plain_words": str(plain_words),
        "plain_hits": str(len(plain_hits)),
        "plain_padding_words": str(plain_padding),
        "twoenv_hits": str(len(twoenv_hits)),
        "counter_match": "1" if counter_match else "0",
        "order_exact": "1" if order_exact else "0",
    }
    if not order_exact:
        mismatch_index = next(
            (
                idx
                for idx, (plain_hit, twoenv_hit) in enumerate(zip(plain_hits, twoenv_hits))
                if plain_hit != twoenv_hit
            ),
            min(len(plain_hits), len(twoenv_hits)),
        )
        summary_lines["first_mismatch_index"] = str(mismatch_index)
        summary_lines["plain_hit"] = (
            f"0x{plain_hits[mismatch_index]:016X}" if mismatch_index < len(plain_hits) else "n/a"
        )
        summary_lines["twoenv_hit"] = (
            f"0x{twoenv_hits[mismatch_index]:016X}" if mismatch_index < len(twoenv_hits) else "n/a"
        )
    path.write_text(
        "\n".join(f"{key}={value}" for key, value in summary_lines.items()) + "\n",
        encoding="utf-8",
    )
    return summary_lines


def refresh_moved_analyzer_paths(bundle_dir: Path, case_id: str) -> None:
    summary_path = bundle_dir / "packet_analyzer/index.summary.json"
    html_path = bundle_dir / "packet_analyzer/index.html"
    if not summary_path.is_file():
        return

    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    replacements = {
        str(summary.get("vcd_path", "")): str(bundle_dir / "sim" / f"{case_id}.vcd"),
        str(summary.get("ref_dir", "")): str(bundle_dir / "ref"),
    }
    summary["vcd_path"] = replacements.get(str(summary.get("vcd_path", "")), summary.get("vcd_path", ""))
    summary["ref_dir"] = replacements.get(str(summary.get("ref_dir", "")), summary.get("ref_dir", ""))
    summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    if html_path.is_file():
        html_text = html_path.read_text(encoding="utf-8")
        for old_path, new_path in replacements.items():
            if not old_path:
                continue
            html_text = html_text.replace(html.escape(old_path), html.escape(new_path))
            html_text = html_text.replace(old_path, new_path)
        html_path.write_text(html_text, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Export the combined X125 plain + 2env waveform bundle")
    parser.add_argument("--case-id", default="X125")
    parser.add_argument("--replay-source-dir", type=Path, default=Path("tb_int/cases/basic/ref/out"))
    parser.add_argument("--frame-count", type=int, default=3)
    parser.add_argument("--out-root", type=Path, default=Path("tb_int/wave_reports"))
    args = parser.parse_args()

    root = repo_root()
    bucket = bucket_name_for_case_id(args.case_id)
    out_dir = (root / args.out_root / bucket / args.case_id).resolve()
    compare_summary = out_dir / "compare_summary.txt"
    bundle_json = out_dir / "bundle.json"
    bundle_readme = out_dir / "README.md"

    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="musip_x125_plain_") as plain_tmp, tempfile.TemporaryDirectory(
        prefix="musip_x125_2env_"
    ) as twoenv_tmp:
        plain_root = Path(plain_tmp)
        twoenv_root = Path(twoenv_tmp)
        plain_bundle = plain_root / bucket / args.case_id
        twoenv_bundle = twoenv_root / bucket / args.case_id
        twoenv_trace_prefix = twoenv_bundle / "sim" / "x125_trace"

        run_cmd(
            [
                "python3",
                str(root / "tb_int/scripts/export_plain_wave_case.py"),
                "--case-id",
                args.case_id,
                "--replay-source-dir",
                str(args.replay_source_dir),
                "--make-target",
                "run",
                "--frame-count",
                str(args.frame_count),
                "--out-root",
                str(plain_root),
            ],
            cwd=root,
        )
        run_cmd(
            [
                "python3",
                str(root / "tb_int/scripts/export_plain_2env_wave_case.py"),
                "--case-id",
                args.case_id,
                "--replay-source-dir",
                str(args.replay_source_dir),
                "--make-target",
                "run",
                "--frame-count",
                str(args.frame_count),
                "--sim-args",
                f"+SWB_HIT_TRACE_PREFIX={twoenv_trace_prefix}",
                "--out-root",
                str(twoenv_root),
            ],
            cwd=root,
        )

        plain_hits, plain_words, plain_padding = read_plain_dma_hits(plain_bundle / "sim/actual_dma_words.mem")
        twoenv_hits = read_twoenv_dma_hits(twoenv_bundle / "sim/x125_trace_dma_hits.tsv")
        summary_lines = write_compare_summary(compare_summary, plain_hits, plain_words, plain_padding, twoenv_hits)

        plain_dst = out_dir / "plain"
        twoenv_dst = out_dir / "twoenv"
        shutil.move(str(plain_bundle), str(plain_dst))
        shutil.move(str(twoenv_bundle), str(twoenv_dst))
        refresh_moved_analyzer_paths(plain_dst, args.case_id)
        refresh_moved_analyzer_paths(twoenv_dst, args.case_id)

    payload = {
        "bucket": bucket,
        "case_id": args.case_id,
        "frames": args.frame_count,
        "frame_window": {
            "frame_start": 0,
            "frame_count": args.frame_count,
        },
        "artifacts": {
            "compare_summary": str(compare_summary.relative_to(out_dir)),
            "plain_bundle": "plain",
            "twoenv_bundle": "twoenv",
            "plain_packet_analyzer": "plain/packet_analyzer/index.html",
            "twoenv_packet_analyzer": "twoenv/packet_analyzer/index.html",
        },
        "summary_lines": summary_lines,
    }
    bundle_json.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    bundle_readme.write_text(
        "\n".join(
            [
                f"# `{args.case_id}` dual-harness wave bundle",
                "",
                f"- **bucket:** `{bucket}`",
                "- **scope:** combined plain-harness and split-2env replay evidence on the same replay bundle",
                "- **compare summary:** `compare_summary.txt`",
                "- **plain analyzer:** `plain/packet_analyzer/index.html`",
                "- **2env analyzer:** `twoenv/packet_analyzer/index.html`",
                "",
                "## Captured summary",
                "",
                f"- **plain_words:** `{summary_lines.get('plain_words', 'n/a')}`",
                f"- **plain_hits:** `{summary_lines.get('plain_hits', 'n/a')}`",
                f"- **twoenv_hits:** `{summary_lines.get('twoenv_hits', 'n/a')}`",
                f"- **counter_match:** `{summary_lines.get('counter_match', 'n/a')}`",
                f"- **order_exact:** `{summary_lines.get('order_exact', 'n/a')}`",
                "",
                "## Notes",
                "",
                "- `plain/` keeps the raw-bus plain-harness VCD, analyzer bundle, replay copy, and DMA semantic check artifacts.",
                "- `twoenv/` keeps the split-harness VCD, analyzer bundle, replay copy, and DMA hit-trace TSV used for the cross-harness compare.",
                "- The top-level compare summary reproduces the promoted X125 claim directly: multiset equality is required, exact normalized-hit order is informative only.",
                "",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
