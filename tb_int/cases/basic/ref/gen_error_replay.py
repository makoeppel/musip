#!/usr/bin/env python3
"""Generate deterministic malformed replay bundles for parser-coverage closure."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


SWB_N_LANES = 4
SWB_MUPIX_HEADER_ID = 0b111010
SWB_K285 = 0xBC
SWB_K284 = 0x9C
SWB_K237 = 0xF7
SWB_N_SHD = 128
SWB_FINE_TS_BITS = 4

ERR_HIT = 0b001
ERR_SUBHEADER = 0b010
ERR_HEADER = 0b100


def pack_beat(valid: int, datak: int, data: int, err_desc: int = 0) -> int:
    return (
        ((err_desc & 0x7) << 37)
        | ((valid & 0x1) << 36)
        | ((datak & 0xF) << 32)
        | (data & 0xFFFF_FFFF)
    )


def make_sop(header_id: int, feb_id: int) -> int:
    return ((header_id & 0x3F) << 26) | ((feb_id & 0xFFFF) << 8) | SWB_K285


def make_debug0(subheaders: int, hits: int) -> int:
    return ((subheaders & 0x7FFF) << 16) | (hits & 0xFFFF)


def make_subheader(shd_ts: int, hits: int) -> int:
    return ((shd_ts & 0xFF) << 24) | ((hits & 0xFF) << 8) | SWB_K237


def frame_ts_stride_8ns() -> int:
    return SWB_N_SHD << SWB_FINE_TS_BITS


def frame_base_ts_8ns(frame_idx: int) -> int:
    return frame_idx * frame_ts_stride_8ns()


def frame_ts_high_word(frame_idx: int) -> int:
    return (frame_base_ts_8ns(frame_idx) >> 16) & 0xFFFF_FFFF


def frame_ts_low_word(frame_idx: int) -> int:
    return frame_base_ts_8ns(frame_idx) & 0xFFFF


def frame_dispatch_ts_word(frame_idx: int) -> int:
    return (frame_base_ts_8ns(frame_idx) + frame_ts_stride_8ns()) & 0x7FFF_FFFF


def emit_zero_hit_packet(
    stream: list[int],
    frame_idx: int,
    pkg_cnt: int,
    feb_id: int,
    *,
    sop_err: int = 0,
) -> None:
    stream.extend(
        [
            pack_beat(1, 0x1, make_sop(SWB_MUPIX_HEADER_ID, feb_id), sop_err),
            pack_beat(1, 0x0, frame_ts_high_word(frame_idx)),
            pack_beat(1, 0x0, (frame_ts_low_word(frame_idx) << 16) | (pkg_cnt & 0xFFFF)),
            pack_beat(1, 0x0, make_debug0(0, 0)),
            pack_beat(1, 0x0, frame_dispatch_ts_word(frame_idx)),
            pack_beat(1, 0x1, SWB_K284),
            pack_beat(0, 0x0, 0x0000_0000),
        ]
    )


def emit_subheader_packet(
    stream: list[int],
    frame_idx: int,
    pkg_cnt: int,
    feb_id: int,
    *,
    subheader_err: int = 0,
    hit_err_descs: list[int] | None = None,
) -> None:
    hit_err_descs = hit_err_descs or []
    hit_count = len(hit_err_descs)
    stream.extend(
        [
            pack_beat(1, 0x1, make_sop(SWB_MUPIX_HEADER_ID, feb_id)),
            pack_beat(1, 0x0, frame_ts_high_word(frame_idx)),
            pack_beat(1, 0x0, (frame_ts_low_word(frame_idx) << 16) | (pkg_cnt & 0xFFFF)),
            pack_beat(1, 0x0, make_debug0(1, hit_count)),
            pack_beat(1, 0x0, frame_dispatch_ts_word(frame_idx)),
            pack_beat(1, 0x1, make_subheader(0x10 | (pkg_cnt & 0xF), hit_count), subheader_err),
        ]
    )
    for hit_idx, err_desc in enumerate(hit_err_descs):
        stream.append(pack_beat(1, 0x0, 0x4400_0000 | (pkg_cnt << 4) | hit_idx, err_desc))
    stream.extend(
        [
            pack_beat(1, 0x1, SWB_K284),
            pack_beat(0, 0x0, 0x0000_0000),
        ]
    )


def profile_stream(profile: str) -> list[int]:
    stream: list[int] = []
    lane_id = 0

    if profile == "hdr_err_recover":
        emit_zero_hit_packet(stream, 0, 0x0010, lane_id, sop_err=ERR_HEADER)
        emit_zero_hit_packet(stream, 1, 0x0011, lane_id)
    elif profile == "subhdr_err_recover":
        emit_subheader_packet(stream, 0, 0x0020, lane_id, subheader_err=ERR_SUBHEADER)
        emit_zero_hit_packet(stream, 1, 0x0021, lane_id)
    elif profile == "hit_err_recover":
        emit_subheader_packet(stream, 0, 0x0030, lane_id, hit_err_descs=[ERR_HIT])
        emit_zero_hit_packet(stream, 1, 0x0031, lane_id)
    elif profile == "midhit_shderr_recover":
        emit_subheader_packet(stream, 0, 0x0040, lane_id, hit_err_descs=[ERR_SUBHEADER])
        emit_zero_hit_packet(stream, 1, 0x0041, lane_id)
    else:
        raise ValueError(f"Unsupported profile {profile}")

    return stream


def write_lines(path: Path, lines: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(lines), encoding="ascii")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate deterministic malformed replay bundles.")
    parser.add_argument("--out-dir", type=Path, required=True, help="Artifact output directory.")
    parser.add_argument(
        "--profile",
        required=True,
        choices=(
            "hdr_err_recover",
            "subhdr_err_recover",
            "hit_err_recover",
            "midhit_shderr_recover",
        ),
        help="Malformed replay profile to emit.",
    )
    args = parser.parse_args()

    out_dir = args.out_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    lane0_lines = [f"{beat:010X}\n" for beat in profile_stream(args.profile)]
    write_lines(out_dir / "lane0_ingress.mem", lane0_lines)
    for lane_id in range(1, SWB_N_LANES):
        write_lines(out_dir / f"lane{lane_id}_ingress.mem", [])

    write_lines(out_dir / "expected_dma_words.mem", [])
    write_lines(out_dir / "opq_egress.mem", [])
    write_lines(out_dir / "expected_dma_words.txt", [])

    summary = {
        "profile": args.profile,
        "expected_word_count": 0,
        "checks": {
            "parser_error": True,
            "recovery_packet": True,
        },
    }
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    (out_dir / "plan.json").write_text(
        json.dumps(
            {
                "profile": args.profile,
                "expected_word_count": 0,
                "frames_by_lane": [[] for _ in range(SWB_N_LANES)],
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    print(f"error/ref: wrote profile {args.profile} to {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
