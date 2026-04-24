#!/usr/bin/env python3
"""Generate deterministic raw control/data replay bundles for closure holes."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


SWB_N_LANES = 4
SWB_MUPIX_HEADER_ID = 0b111010
SWB_TILE_HEADER_ID = 0b110100
SWB_SC_HEADER_ID = 0b000111
SWB_BAD_HEADER_ID = 0b001011
SWB_K285 = 0xBC
SWB_K284 = 0x9C
SWB_K237 = 0xF7
SWB_N_SHD = 128
SWB_FINE_TS_BITS = 4
RUN_PREP_ACK = 0x000000FE
RUN_END = 0x000000FD
MERGER_TIMEOUT = 0x000000FB


def pack_beat(valid: int, datak: int, data: int) -> int:
    return ((valid & 0x1) << 36) | ((datak & 0xF) << 32) | (data & 0xFFFF_FFFF)


def make_sop(header_id: int, feb_id: int) -> int:
    return ((header_id & 0x3F) << 26) | ((feb_id & 0xFFFF) << 8) | SWB_K285


def make_debug0(subheaders: int, hits: int) -> int:
    return ((subheaders & 0x7FFF) << 16) | (hits & 0xFFFF)


def make_subheader(shd_ts: int, hits: int) -> int:
    return ((shd_ts & 0xFF) << 24) | ((hits & 0xFF) << 8) | SWB_K237


def make_bad_k285(feb_id: int) -> int:
    return make_sop(SWB_BAD_HEADER_ID, feb_id)


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


def lane_control_combo_stream(lane_id: int) -> list[int]:
    feb_id = lane_id & 0xFFFF
    stream: list[int] = []

    stream.append(pack_beat(1, 0x1, MERGER_TIMEOUT))

    stream.extend(
        [
            pack_beat(1, 0x1, make_sop(SWB_MUPIX_HEADER_ID, feb_id)),
            pack_beat(1, 0x1, RUN_PREP_ACK),
            pack_beat(1, 0x0, frame_ts_high_word(0)),
            pack_beat(1, 0x0, (frame_ts_low_word(0) << 16) | lane_id),
            pack_beat(1, 0x0, make_debug0(1, 0)),
            pack_beat(1, 0x0, frame_dispatch_ts_word(0)),
            pack_beat(1, 0x1, make_subheader(lane_id, 0)),
            pack_beat(1, 0x1, SWB_K284),
        ]
    )

    stream.extend(
        [
            pack_beat(1, 0x1, make_sop(SWB_TILE_HEADER_ID, feb_id)),
            pack_beat(1, 0x1, RUN_END),
            pack_beat(1, 0x0, frame_ts_high_word(1)),
            pack_beat(1, 0x0, (frame_ts_low_word(1) << 16) | (0x100 | lane_id)),
            pack_beat(1, 0x0, make_debug0(1, 0)),
            pack_beat(1, 0x0, frame_dispatch_ts_word(1)),
            pack_beat(1, 0x1, make_subheader(0x10 | lane_id, 0)),
            pack_beat(1, 0x1, SWB_K284),
        ]
    )

    stream.extend(
        [
            pack_beat(1, 0x1, make_sop(SWB_SC_HEADER_ID, feb_id)),
            pack_beat(1, 0x0, frame_ts_high_word(2)),
            pack_beat(1, 0x1, MERGER_TIMEOUT),
            pack_beat(1, 0x1, SWB_K284),
            pack_beat(0, 0x0, 0x0000_0000),
        ]
    )
    return stream


def lane_idle_guard_mix_stream(lane_id: int) -> list[int]:
    feb_id = lane_id & 0xFFFF
    return [
        pack_beat(1, 0x1, SWB_K284),
        pack_beat(1, 0x1, make_bad_k285(feb_id)),
        pack_beat(1, 0x2, MERGER_TIMEOUT),
        pack_beat(1, 0x1, MERGER_TIMEOUT),
        pack_beat(0, 0x0, 0x0000_0000),
    ]


def lane_data_ctrl_mix_stream(lane_id: int) -> list[int]:
    feb_id = lane_id & 0xFFFF
    return [
        pack_beat(1, 0x1, make_sop(SWB_MUPIX_HEADER_ID, feb_id)),
        pack_beat(1, 0x0, frame_ts_high_word(0)),
        pack_beat(1, 0x0, (frame_ts_low_word(0) << 16) | (0x0100 | lane_id)),
        pack_beat(1, 0x0, make_debug0(1, 0)),
        pack_beat(1, 0x0, frame_dispatch_ts_word(0)),
        pack_beat(1, 0x1, make_bad_k285(feb_id)),
        pack_beat(1, 0x2, 0xDEAD_0000 | lane_id),
        pack_beat(1, 0x1, RUN_PREP_ACK),
        pack_beat(1, 0x1, make_subheader(0x20 | lane_id, 0)),
        pack_beat(1, 0x1, SWB_K284),
        pack_beat(0, 0x0, 0x0000_0000),
    ]


def lane_sc_ctrl_mix_stream(lane_id: int) -> list[int]:
    feb_id = lane_id & 0xFFFF
    return [
        pack_beat(1, 0x1, make_sop(SWB_SC_HEADER_ID, feb_id)),
        pack_beat(1, 0x0, frame_ts_high_word(0)),
        pack_beat(1, 0x1, make_bad_k285(feb_id)),
        pack_beat(1, 0x2, 0xCAFE_0000 | lane_id),
        pack_beat(1, 0x1, MERGER_TIMEOUT),
        pack_beat(1, 0x1, SWB_K284),
        pack_beat(0, 0x0, 0x0000_0000),
    ]


def lane_combo_stream(profile: str, lane_id: int) -> list[int]:
    if profile == "control_combo":
        return lane_control_combo_stream(lane_id)
    if profile == "idle_guard_mix":
        return lane_idle_guard_mix_stream(lane_id)
    if profile == "data_ctrl_mix":
        return lane_data_ctrl_mix_stream(lane_id)
    if profile == "sc_ctrl_mix":
        return lane_sc_ctrl_mix_stream(lane_id)
    raise ValueError(f"Unsupported profile {profile}")


def write_lines(path: Path, lines: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(lines), encoding="ascii")


def profile_summary(profile: str) -> dict[str, object]:
    if profile == "control_combo":
        return {
            "header_kinds": ["mupix", "tile", "sc"],
            "checks": {
                "idle_rc": True,
                "rc_in_data": True,
                "tile_preamble": True,
                "sc_packet": True,
                "rc_in_sc": True,
            },
        }
    if profile == "idle_guard_mix":
        return {
            "header_kinds": [],
            "checks": {
                "idle_k284_guard": True,
                "idle_bad_k285_guard": True,
                "idle_bad_datak_guard": True,
                "idle_rc": True,
            },
        }
    if profile == "data_ctrl_mix":
        return {
            "header_kinds": ["mupix"],
            "checks": {
                "data_bad_k285_passthrough": True,
                "data_bad_datak_passthrough": True,
                "data_rc": True,
                "data_zero_hit_subheader": True,
            },
        }
    if profile == "sc_ctrl_mix":
        return {
            "header_kinds": ["sc"],
            "checks": {
                "sc_bad_k285_passthrough": True,
                "sc_bad_datak_passthrough": True,
                "sc_rc": True,
                "sc_trailer": True,
            },
        }
    raise ValueError(f"Unsupported profile {profile}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate a deterministic control replay bundle.")
    parser.add_argument("--out-dir", type=Path, required=True, help="Artifact output directory.")
    parser.add_argument(
        "--profile",
        default="control_combo",
        choices=("control_combo", "idle_guard_mix", "data_ctrl_mix", "sc_ctrl_mix"),
        help="Replay profile to emit.",
    )
    args = parser.parse_args()

    out_dir = args.out_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    for lane_id in range(SWB_N_LANES):
        lane_lines = [f"{beat:010X}\n" for beat in lane_combo_stream(args.profile, lane_id)]
        write_lines(out_dir / f"lane{lane_id}_ingress.mem", lane_lines)

    write_lines(out_dir / "expected_dma_words.mem", [])
    write_lines(out_dir / "opq_egress.mem", [])
    write_lines(out_dir / "expected_dma_words.txt", [])

    summary = {
        "profile": args.profile,
        "frames_per_lane": 0,
        "expected_word_count": 0,
        "total_hits": 0,
        **profile_summary(args.profile),
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

    print(f"control/ref: wrote profile {args.profile} to {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
