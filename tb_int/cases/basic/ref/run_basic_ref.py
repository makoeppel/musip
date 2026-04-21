#!/usr/bin/env python3
"""Simulatorless basic-case fallback for MuSiP SWB/OPQ bring-up.

This script mirrors the current UVM basic case closely enough to keep
sequence generation, packet formatting assumptions, and expected DMA packing
moving while the full Mentor/Questa runtime is unavailable on the host.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable


SWB_N_LANES = 4
SWB_N_SUBHEADERS = 128
SWB_MAX_HITS_PER_SUBHEADER = 4
SWB_MUPIX_HEADER_ID = 0b111010
SWB_K285 = 0xBC
SWB_K284 = 0x9C
SWB_K237 = 0xF7


@dataclass
class HitDesc:
    payload_word: int


@dataclass
class SubheaderDesc:
    shd_ts: int
    hits: list[HitDesc] = field(default_factory=list)

    @property
    def hit_count(self) -> int:
        return len(self.hits)


@dataclass
class FrameItem:
    lane_id: int
    frame_id: int
    ts_high_word: int
    ts_low_word: int
    pkg_cnt: int
    feb_id: int
    subheaders: list[SubheaderDesc] = field(default_factory=list)

    @property
    def subheader_count(self) -> int:
        return len(self.subheaders)

    @property
    def hit_count(self) -> int:
        return sum(shd.hit_count for shd in self.subheaders)


@dataclass
class CasePlan:
    frames_by_lane: list[list[FrameItem]] = field(default_factory=lambda: [[] for _ in range(SWB_N_LANES)])
    expected_dma_words: list[int] = field(default_factory=list)
    expected_word_count: int = 0
    total_hits: int = 0
    lane_saturation: list[float] = field(default_factory=lambda: [0.0] * SWB_N_LANES)


def poisson_trunc(rng: random.Random, lam: float, max_hits: int) -> int:
    """Match the UVM truncated-Poisson behavior closely enough for stimulus."""
    if lam <= 0.0:
        return 0

    threshold = math.exp(-lam)
    product = 1.0
    k = 0

    while product > threshold and k <= max_hits:
        sample_u = rng.random()
        if sample_u <= 0.0:
            sample_u = sys.float_info.min
        product *= sample_u
        k += 1

    if k == 0:
        return 0
    if (k - 1) > max_hits:
        return max_hits
    return k - 1


def make_hit_payload(lane_id: int, frame_id: int, subheader_idx: int, hit_idx: int) -> int:
    payload_word = 0
    low_nibble = (lane_id & 0xF) + ((hit_idx & 0xF) * 4)
    payload_word |= (low_nibble & 0xF) << 28
    payload_word |= (lane_id & 0xF) << 22
    payload_word |= ((frame_id * 13 + subheader_idx * 3 + hit_idx) & 0xFF) << 14
    payload_word |= ((lane_id * 17 + subheader_idx + hit_idx * 7) & 0xFF) << 6
    payload_word |= ((hit_idx + frame_id) & 0x1F) << 1
    return payload_word & 0xFFFF_FFFF


def make_debug_header0(frame: FrameItem) -> int:
    data_word = 0
    data_word |= (frame.subheader_count & 0x7FFF) << 16
    data_word |= frame.hit_count & 0xFFFF
    return data_word & 0xFFFF_FFFF


def make_subheader_word(shd: SubheaderDesc) -> int:
    data_word = 0
    data_word |= (shd.shd_ts & 0xFF) << 24
    data_word |= (shd.hit_count & 0xFF) << 8
    data_word |= SWB_K237
    return data_word & 0xFFFF_FFFF


def make_expected_mupix_hit(ts_high_word: int, ts_low_word: int, shd_ts: int, hit_word: int) -> int:
    data_word = 0
    data_word |= ((hit_word >> 14) & 0xFF) << 50
    data_word |= ((hit_word >> 6) & 0xFF) << 42
    data_word |= ((hit_word >> 1) & 0x1F) << 37
    tail = (
        ((ts_high_word & ((1 << 21) - 1)) << (5 + 7 + 4))
        | (((ts_low_word >> 11) & 0x1F) << (7 + 4))
        | ((shd_ts & 0x7F) << 4)
        | ((hit_word >> 28) & 0xF)
    )
    data_word |= tail & ((1 << 37) - 1)
    return data_word & 0xFFFF_FFFF_FFFF_FFFF


def make_abs_ts(ts_high_word: int, ts_low_word: int, shd_ts: int, hit_word: int) -> int:
    return (
        ((ts_high_word & ((1 << 21) - 1)) << (5 + 7 + 4))
        | (((ts_low_word >> 11) & 0x1F) << (7 + 4))
        | ((shd_ts & 0x7F) << 4)
        | ((hit_word >> 28) & 0xF)
    )


def pack_dma_word(hit_words: list[int]) -> int:
    assert len(hit_words) == 4
    packed_word = 0
    packed_word |= hit_words[0] & 0xFFFF_FFFF_FFFF_FFFF
    packed_word |= (hit_words[1] & 0xFFFF_FFFF_FFFF_FFFF) << 64
    packed_word |= (hit_words[2] & 0xFFFF_FFFF_FFFF_FFFF) << 128
    packed_word |= (hit_words[3] & 0xFFFF_FFFF_FFFF_FFFF) << 192
    return packed_word & ((1 << 256) - 1)


def normalize_dma_word(data_word: int) -> int:
    normalized = data_word
    for upper_bit in (62, 126, 190, 254):
        normalized &= ~(((1 << 5) - 1) << (upper_bit - 4))
    return normalized


def add_hit_to_subheader(frame: FrameItem, shd: SubheaderDesc, lane_id: int, frame_id: int, subheader_idx: int) -> None:
    hit_idx = shd.hit_count
    shd.hits.append(HitDesc(payload_word=make_hit_payload(lane_id, frame_id, subheader_idx, hit_idx)))


def pack_expected_words_from_frames(frames_by_lane: list[list[FrameItem]]) -> tuple[list[int], int]:
    records: list[tuple[int, int]] = []
    total_hits = 0

    for lane_frames in frames_by_lane:
        for frame in lane_frames:
            for shd in frame.subheaders:
                for hit in shd.hits:
                    abs_ts = make_abs_ts(frame.ts_high_word, frame.ts_low_word, shd.shd_ts, hit.payload_word)
                    hit_word = make_expected_mupix_hit(frame.ts_high_word, frame.ts_low_word, shd.shd_ts, hit.payload_word)
                    records.append((abs_ts, hit_word))
                    total_hits += 1

    if total_hits % 4 != 0:
        raise RuntimeError(f"Total hit count {total_hits} is not divisible by 4")

    records.sort(key=lambda item: item[0])
    packed_words: list[int] = []
    for idx in range(0, len(records), 4):
        packed_words.append(pack_dma_word([records[idx + off][1] for off in range(4)]))
    return packed_words, total_hits


def count_total_hits(frames_by_lane: list[list[FrameItem]]) -> int:
    return sum(frame.hit_count for lane_frames in frames_by_lane for frame in lane_frames)


def build_basic_case(frame_count: int, lane_saturation: list[float], seed: int) -> CasePlan:
    rng = random.Random(seed)
    plan = CasePlan()
    plan.lane_saturation = lane_saturation[:]

    for frame_idx in range(frame_count):
        ts_high_word = (0x1200_0000 + frame_idx) & 0xFFFF_FFFF
        ts_low_word = (0xA000 + frame_idx * 16) & 0xFFFF

        for lane_id in range(SWB_N_LANES):
            frame = FrameItem(
                lane_id=lane_id,
                frame_id=frame_idx,
                ts_high_word=ts_high_word,
                ts_low_word=ts_low_word,
                pkg_cnt=frame_idx & 0xFFFF,
                feb_id=lane_id & 0xFFFF,
            )

            for shd_idx in range(SWB_N_SUBHEADERS):
                shd = SubheaderDesc(shd_ts=shd_idx & 0xFF)
                hit_target = poisson_trunc(rng, lane_saturation[lane_id] * SWB_MAX_HITS_PER_SUBHEADER, SWB_MAX_HITS_PER_SUBHEADER)
                for _ in range(hit_target):
                    add_hit_to_subheader(frame, shd, lane_id, frame_idx, shd_idx)
                frame.subheaders.append(shd)

            plan.frames_by_lane[lane_id].append(frame)

    plan.total_hits = count_total_hits(plan.frames_by_lane)

    extra_hits = (4 - (plan.total_hits % 4)) % 4
    if extra_hits != 0:
        for lane_id in range(SWB_N_LANES - 1, -1, -1):
            for frame in reversed(plan.frames_by_lane[lane_id]):
                for shd_idx in range(len(frame.subheaders) - 1, -1, -1):
                    shd = frame.subheaders[shd_idx]
                    while extra_hits != 0 and shd.hit_count < SWB_MAX_HITS_PER_SUBHEADER:
                        add_hit_to_subheader(frame, shd, lane_id, frame.frame_id, shd_idx)
                        extra_hits -= 1
                    if extra_hits == 0:
                        break
                if extra_hits == 0:
                    break
            if extra_hits == 0:
                break
        if extra_hits != 0:
            raise RuntimeError("Unable to pad final hit count to a multiple of four")

        plan.total_hits = count_total_hits(plan.frames_by_lane)

    expected_words, total_hits = pack_expected_words_from_frames(plan.frames_by_lane)
    plan.expected_dma_words = expected_words
    plan.expected_word_count = len(expected_words)
    plan.total_hits = total_hits

    return plan


def serialize_frame(frame: FrameItem) -> list[dict[str, int | str]]:
    transfers: list[dict[str, int | str]] = []

    transfers.append(
        {
            "valid": 1,
            "data": ((SWB_MUPIX_HEADER_ID & 0x3F) << 26) | ((frame.feb_id & 0xFFFF) << 8) | SWB_K285,
            "datak": 0x1,
            "kind": "sop",
        }
    )
    transfers.append({"valid": 1, "data": frame.ts_high_word, "datak": 0x0, "kind": "ts_high"})
    transfers.append(
        {
            "valid": 1,
            "data": ((frame.ts_low_word & 0xFFFF) << 16) | (frame.pkg_cnt & 0xFFFF),
            "datak": 0x0,
            "kind": "ts_low_pkg",
        }
    )
    transfers.append({"valid": 1, "data": make_debug_header0(frame), "datak": 0x0, "kind": "debug0"})
    transfers.append({"valid": 1, "data": 0x0000_0000, "datak": 0x0, "kind": "debug1"})

    for shd in frame.subheaders:
        transfers.append({"valid": 1, "data": make_subheader_word(shd), "datak": 0x1, "kind": "subheader"})
        for hit in shd.hits:
            transfers.append({"valid": 1, "data": hit.payload_word, "datak": 0x0, "kind": "hit"})

    transfers.append({"valid": 1, "data": SWB_K284, "datak": 0x1, "kind": "eop"})
    transfers.append({"valid": 0, "data": 0x0000_0000, "datak": 0x0, "kind": "idle"})
    return transfers


def serialize_plan(plan: CasePlan) -> list[list[dict[str, int | str]]]:
    lane_streams: list[list[dict[str, int | str]]] = []
    for lane_id in range(SWB_N_LANES):
        lane_stream: list[dict[str, int | str]] = []
        for frame in plan.frames_by_lane[lane_id]:
            lane_stream.extend(serialize_frame(frame))
        lane_streams.append(lane_stream)
    return lane_streams


def parse_lane_stream(lane_id: int, stream: Iterable[dict[str, int | str]]) -> list[FrameItem]:
    words = [item for item in stream if int(item["valid"]) == 1]
    frames: list[FrameItem] = []
    idx = 0

    while idx < len(words):
        sop = words[idx]
        data = int(sop["data"])
        datak = int(sop["datak"])
        if datak != 0x1 or (data & 0xFF) != SWB_K285 or ((data >> 26) & 0x3F) != SWB_MUPIX_HEADER_ID:
            raise RuntimeError(f"Lane {lane_id}: expected SOP at word {idx}, got data=0x{data:08X} datak=0x{datak:X}")

        feb_id = (data >> 8) & 0xFFFF
        ts_high_word = int(words[idx + 1]["data"]) & 0xFFFF_FFFF
        ts_low_pkg = int(words[idx + 2]["data"]) & 0xFFFF_FFFF
        ts_low_word = (ts_low_pkg >> 16) & 0xFFFF
        pkg_cnt = ts_low_pkg & 0xFFFF
        idx += 5

        frame = FrameItem(
            lane_id=lane_id,
            frame_id=len(frames),
            ts_high_word=ts_high_word,
            ts_low_word=ts_low_word,
            pkg_cnt=pkg_cnt,
            feb_id=feb_id,
        )

        while idx < len(words):
            word = words[idx]
            data = int(word["data"]) & 0xFFFF_FFFF
            datak = int(word["datak"])

            if datak == 0x1 and (data & 0xFF) == SWB_K284:
                idx += 1
                break

            if datak != 0x1 or (data & 0xFF) != SWB_K237:
                raise RuntimeError(f"Lane {lane_id}: expected subheader/EOP at word {idx}, got data=0x{data:08X} datak=0x{datak:X}")

            shd_ts = (data >> 24) & 0xFF
            hit_count = (data >> 8) & 0xFF
            idx += 1

            shd = SubheaderDesc(shd_ts=shd_ts)
            for _ in range(hit_count):
                if idx >= len(words):
                    raise RuntimeError(f"Lane {lane_id}: truncated hit list after subheader 0x{data:08X}")
                hit_word = int(words[idx]["data"]) & 0xFFFF_FFFF
                hit_datak = int(words[idx]["datak"])
                if hit_datak != 0x0:
                    raise RuntimeError(f"Lane {lane_id}: expected hit payload at word {idx}, got data=0x{hit_word:08X} datak=0x{hit_datak:X}")
                shd.hits.append(HitDesc(payload_word=hit_word))
                idx += 1
            frame.subheaders.append(shd)

        frames.append(frame)

    return frames


def plan_to_jsonable(plan: CasePlan) -> dict[str, object]:
    return {
        "lane_saturation": plan.lane_saturation,
        "expected_word_count": plan.expected_word_count,
        "total_hits": plan.total_hits,
        "frames_by_lane": [
            [
                {
                    "lane_id": frame.lane_id,
                    "frame_id": frame.frame_id,
                    "ts_high_word": f"0x{frame.ts_high_word:08X}",
                    "ts_low_word": f"0x{frame.ts_low_word:04X}",
                    "pkg_cnt": frame.pkg_cnt,
                    "feb_id": frame.feb_id,
                    "subheaders": [
                        {
                            "shd_ts": shd.shd_ts,
                            "hit_count": shd.hit_count,
                            "hits": [f"0x{hit.payload_word:08X}" for hit in shd.hits],
                        }
                        for shd in frame.subheaders
                    ],
                }
                for frame in lane_frames
            ]
            for lane_frames in plan.frames_by_lane
        ],
    }


def parse_plusargs(argv: list[str]) -> tuple[list[str], dict[str, str]]:
    plain_args: list[str] = []
    plusargs: dict[str, str] = {}
    for arg in argv:
        if not arg.startswith("+"):
            plain_args.append(arg)
            continue
        keyval = arg[1:]
        if "=" not in keyval:
            raise SystemExit(f"Unsupported plusarg format: {arg}")
        key, value = keyval.split("=", 1)
        plusargs[key] = value
    return plain_args, plusargs


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run the simulatorless MuSiP SWB basic reference case.")
    parser.add_argument("--frames", type=int, default=2, help="Number of frames per lane.")
    parser.add_argument("--seed", type=int, default=1, help="Deterministic RNG seed for Poisson traffic.")
    parser.add_argument(
        "--sat",
        type=float,
        nargs=SWB_N_LANES,
        default=[0.20, 0.40, 0.60, 0.80],
        metavar=("SAT0", "SAT1", "SAT2", "SAT3"),
        help="Per-lane saturation factors in the 0.0 to 0.8 bring-up range.",
    )
    parser.add_argument("--out-dir", type=Path, default=Path("out"), help="Artifact output directory.")
    return parser


def main(argv: list[str]) -> int:
    plain_args, plusargs = parse_plusargs(argv)
    parser = build_arg_parser()
    args = parser.parse_args(plain_args)

    if "SWB_FRAMES" in plusargs:
        args.frames = int(plusargs["SWB_FRAMES"])
    if "SWB_SEED" in plusargs:
        args.seed = int(plusargs["SWB_SEED"])
    if "SWB_OUT_DIR" in plusargs:
        args.out_dir = Path(plusargs["SWB_OUT_DIR"])
    for lane_id in range(SWB_N_LANES):
        key = f"SWB_SAT{lane_id}"
        if key in plusargs:
            args.sat[lane_id] = float(plusargs[key])

    out_dir = args.out_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    plan = build_basic_case(frame_count=args.frames, lane_saturation=list(args.sat), seed=args.seed)
    lane_streams = serialize_plan(plan)
    parsed_frames_by_lane = [parse_lane_stream(lane_id, lane_streams[lane_id]) for lane_id in range(SWB_N_LANES)]
    reparsed_dma_words, reparsed_total_hits = pack_expected_words_from_frames(parsed_frames_by_lane)

    normalized_source = [normalize_dma_word(word) for word in plan.expected_dma_words]
    normalized_reparsed = [normalize_dma_word(word) for word in reparsed_dma_words]

    if normalized_source != normalized_reparsed:
        raise RuntimeError("Reparsed lane streams do not reproduce the expected DMA payload words")
    if plan.total_hits != reparsed_total_hits:
        raise RuntimeError(
            f"Total hit count mismatch after reparsing: source={plan.total_hits} reparsed={reparsed_total_hits}"
        )

    digest = hashlib.sha256(
        "\n".join(f"{word:064X}" for word in normalized_source).encode("ascii")
    ).hexdigest()

    with (out_dir / "plan.json").open("w", encoding="utf-8") as handle:
        json.dump(plan_to_jsonable(plan), handle, indent=2)
        handle.write("\n")

    with (out_dir / "expected_dma_words.txt").open("w", encoding="ascii") as handle:
        for idx, word in enumerate(normalized_source):
            handle.write(f"word[{idx:04d}] = 0x{word:064X}\n")

    with (out_dir / "expected_dma_words.mem").open("w", encoding="ascii") as handle:
        for word in normalized_source:
            handle.write(f"{word:064X}\n")

    for lane_id, lane_stream in enumerate(lane_streams):
        path = out_dir / f"lane{lane_id}_ingress.jsonl"
        with path.open("w", encoding="utf-8") as handle:
            for index, item in enumerate(lane_stream):
                record = {
                    "index": index,
                    "valid": int(item["valid"]),
                    "data": f"0x{int(item['data']) & 0xFFFF_FFFF:08X}",
                    "datak": f"0x{int(item['datak']) & 0xF:X}",
                    "kind": item["kind"],
                }
                handle.write(json.dumps(record, sort_keys=True))
                handle.write("\n")

        with (out_dir / f"lane{lane_id}_ingress.mem").open("w", encoding="ascii") as handle:
            for item in lane_stream:
                packed_beat = (
                    ((int(item["valid"]) & 0x1) << 36)
                    | ((int(item["datak"]) & 0xF) << 32)
                    | (int(item["data"]) & 0xFFFF_FFFF)
                )
                handle.write(f"{packed_beat:010X}\n")

    replay_manifest = {
        "format": {
            "lane_mem_word": "{valid[36], datak[35:32], data[31:0]}",
            "expected_dma_word": "normalized 256-bit payload word, one per line",
        },
        "replay_dir_plusarg": str(out_dir),
        "lane_mem_files": [f"lane{lane_id}_ingress.mem" for lane_id in range(SWB_N_LANES)],
        "expected_dma_words_mem": "expected_dma_words.mem",
    }

    with (out_dir / "uvm_replay_manifest.json").open("w", encoding="utf-8") as handle:
        json.dump(replay_manifest, handle, indent=2)
        handle.write("\n")

    summary = {
        "frames_per_lane": args.frames,
        "seed": args.seed,
        "lane_saturation": list(args.sat),
        "total_hits": plan.total_hits,
        "expected_word_count": plan.expected_word_count,
        "expected_dma_sha256": digest,
        "artifacts": {
            "plan": str((out_dir / "plan.json").relative_to(out_dir)),
            "expected_dma_words": str((out_dir / "expected_dma_words.txt").relative_to(out_dir)),
            "expected_dma_words_mem": "expected_dma_words.mem",
            "lane_streams": [f"lane{lane_id}_ingress.jsonl" for lane_id in range(SWB_N_LANES)],
            "lane_streams_mem": [f"lane{lane_id}_ingress.mem" for lane_id in range(SWB_N_LANES)],
            "uvm_replay_manifest": "uvm_replay_manifest.json",
        },
        "checks": {
            "reparsed_dma_match": True,
            "reparsed_total_hits": reparsed_total_hits,
        },
    }

    with (out_dir / "summary.json").open("w", encoding="utf-8") as handle:
        json.dump(summary, handle, indent=2)
        handle.write("\n")

    print(
        "basic/ref: "
        f"frames={args.frames} seed={args.seed} "
        f"sat={','.join(f'{value:0.2f}' for value in args.sat)} "
        f"total_hits={plan.total_hits} expected_words={plan.expected_word_count} "
        f"sha256={digest[:16]}"
    )
    print(f"basic/ref: wrote artifacts to {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
