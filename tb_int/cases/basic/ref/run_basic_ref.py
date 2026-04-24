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
SWB_TILE_HEADER_ID = 0b110100
SWB_SCIFI_HEADER_ID = 0b111000
SWB_K285 = 0xBC
SWB_K284 = 0x9C
SWB_K237 = 0xF7
SWB_FINE_TS_BITS = 4


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
    pre_sop_cycles: int
    ts_high_word: int
    ts_low_word: int
    debug1_word: int
    pkg_cnt: int
    feb_id: int
    header_id: int = SWB_MUPIX_HEADER_ID
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
    raw_total_hits_before_padding: int = 0
    padding_hits_added: int = 0
    lane_saturation: list[float] = field(default_factory=lambda: [0.0] * SWB_N_LANES)
    feb_enable_mask: int = 0xF
    profile: str = "poisson"
    hit_mode: str = "poisson"
    subheader_count: int = SWB_N_SUBHEADERS
    header_kind: str = "mupix"


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


def frame_ts_stride_8ns(subheader_count: int) -> int:
    return subheader_count << SWB_FINE_TS_BITS


def frame_base_ts_8ns(frame_idx: int, subheader_count: int) -> int:
    return frame_idx * frame_ts_stride_8ns(subheader_count)


def frame_dispatch_ts_word(frame_idx: int, subheader_count: int) -> int:
    dispatch_ts = frame_base_ts_8ns(frame_idx, subheader_count) + frame_ts_stride_8ns(subheader_count)
    return dispatch_ts & 0x7FFF_FFFF


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


def make_expected_mutrig_hit(header_id: int, ts_high_word: int, ts_low_word: int, shd_ts: int, hit_word: int) -> int:
    data_word = 0
    data_word |= 1 << 63
    data_word |= (0 & 0x3) << 61
    data_word |= ((hit_word >> 17) & 0x1F) << 56
    data_word |= (hit_word & 0x1FF) << 47
    data_word |= ((hit_word >> 14) & 0x7) << 44
    data_word |= ((hit_word >> 9) & 0x1F) << 39
    if header_id == SWB_SCIFI_HEADER_ID:
        time_tail = (
            ((ts_high_word & ((1 << 23) - 1)) << (4 + 8 + 4))
            | (((ts_low_word >> 12) & 0xF) << (8 + 4))
            | ((shd_ts & 0xFF) << 4)
            | ((hit_word >> 28) & 0xF)
        )
        data_word |= time_tail & ((1 << 39) - 1)
    else:
        time_tail = (
            ((ts_high_word & ((1 << 23) - 1)) << (4 + 8 + 4))
            | (((ts_low_word >> 12) & 0xF) << (8 + 4))
            | ((shd_ts & 0xFF) << 4)
            | ((hit_word >> 28) & 0xF)
        )
        data_word |= time_tail & ((1 << 39) - 1)
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


def pack_expected_words_from_frames(frames_by_lane: list[list[FrameItem]], feb_enable_mask: int = 0xF) -> tuple[list[int], int]:
    records: list[tuple[int, int]] = []
    total_hits = 0

    for lane_id, lane_frames in enumerate(frames_by_lane):
        if ((feb_enable_mask >> lane_id) & 0x1) == 0:
            continue
        for frame in lane_frames:
            for shd in frame.subheaders:
                for hit in shd.hits:
                    abs_ts = make_abs_ts(frame.ts_high_word, frame.ts_low_word, shd.shd_ts, hit.payload_word)
                    if frame.header_id == SWB_MUPIX_HEADER_ID:
                        hit_word = make_expected_mupix_hit(frame.ts_high_word, frame.ts_low_word, shd.shd_ts, hit.payload_word)
                    else:
                        hit_word = make_expected_mutrig_hit(
                            frame.header_id,
                            frame.ts_high_word,
                            frame.ts_low_word,
                            shd.shd_ts,
                            hit.payload_word,
                        )
                    records.append((abs_ts, hit_word))
                    total_hits += 1

    if total_hits % 4 != 0:
        raise RuntimeError(f"Total hit count {total_hits} is not divisible by 4")

    records.sort(key=lambda item: item[0])
    packed_words: list[int] = []
    for idx in range(0, len(records), 4):
        packed_words.append(pack_dma_word([records[idx + off][1] for off in range(4)]))
    return packed_words, total_hits


def count_total_hits(frames_by_lane: list[list[FrameItem]], feb_enable_mask: int = 0xF) -> int:
    total_hits = 0
    for lane_id, lane_frames in enumerate(frames_by_lane):
        if ((feb_enable_mask >> lane_id) & 0x1) == 0:
            continue
        total_hits += sum(frame.hit_count for frame in lane_frames)
    return total_hits


def build_basic_case(
    frame_count: int,
    lane_saturation: list[float],
    seed: int,
    subheader_count: int,
    feb_enable_mask: int,
    hit_mode: str,
    header_id: int,
    header_kind: str,
) -> CasePlan:
    rng = random.Random(seed)
    plan = CasePlan()
    plan.lane_saturation = lane_saturation[:]
    plan.feb_enable_mask = feb_enable_mask & 0xF
    plan.profile = "poisson"
    plan.hit_mode = hit_mode
    plan.subheader_count = subheader_count
    plan.header_kind = header_kind

    for frame_idx in range(frame_count):
        frame_base_ts = frame_base_ts_8ns(frame_idx, subheader_count)
        ts_high_word = (frame_base_ts >> 16) & 0xFFFF_FFFF
        ts_low_word = frame_base_ts & 0xFFFF
        debug1_word = frame_dispatch_ts_word(frame_idx, subheader_count)

        for lane_id in range(SWB_N_LANES):
            frame = FrameItem(
                lane_id=lane_id,
                frame_id=frame_idx,
                pre_sop_cycles=0,
                ts_high_word=ts_high_word,
                ts_low_word=ts_low_word,
                debug1_word=debug1_word,
                pkg_cnt=frame_idx & 0xFFFF,
                feb_id=lane_id & 0xFFFF,
                header_id=header_id,
            )

            for shd_idx in range(subheader_count):
                shd = SubheaderDesc(shd_ts=shd_idx & 0xFF)
                if hit_mode == "zero":
                    hit_target = 0
                elif hit_mode == "single":
                    hit_target = 1
                elif hit_mode == "max":
                    hit_target = SWB_MAX_HITS_PER_SUBHEADER
                else:
                    hit_target = poisson_trunc(
                        rng,
                        lane_saturation[lane_id] * SWB_MAX_HITS_PER_SUBHEADER,
                        SWB_MAX_HITS_PER_SUBHEADER,
                    )
                for _ in range(hit_target):
                    add_hit_to_subheader(frame, shd, lane_id, frame_idx, shd_idx)
                frame.subheaders.append(shd)

            plan.frames_by_lane[lane_id].append(frame)

    plan.raw_total_hits_before_padding = count_total_hits(plan.frames_by_lane, plan.feb_enable_mask)
    plan.total_hits = plan.raw_total_hits_before_padding

    extra_hits = (4 - (plan.total_hits % 4)) % 4
    plan.padding_hits_added = extra_hits
    if extra_hits != 0:
        for lane_id in range(SWB_N_LANES - 1, -1, -1):
            if ((plan.feb_enable_mask >> lane_id) & 0x1) == 0:
                continue
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

        plan.total_hits = count_total_hits(plan.frames_by_lane, plan.feb_enable_mask)

    expected_words, total_hits = pack_expected_words_from_frames(plan.frames_by_lane, plan.feb_enable_mask)
    plan.expected_dma_words = expected_words
    plan.expected_word_count = len(expected_words)
    plan.total_hits = total_hits

    return plan


def build_smoke_case(frame_count: int = 1) -> CasePlan:
    """Build the smallest deterministic case that still preserves SWB framing."""
    plan = CasePlan()
    plan.profile = "smoke"
    plan.hit_mode = "smoke"
    plan.lane_saturation = [0.0] * SWB_N_LANES
    plan.feb_enable_mask = 0xF
    plan.subheader_count = SWB_N_SUBHEADERS
    plan.header_kind = "mupix"

    for frame_idx in range(frame_count):
        frame_base_ts = frame_base_ts_8ns(frame_idx, SWB_N_SUBHEADERS)
        ts_high_word = (frame_base_ts >> 16) & 0xFFFF_FFFF
        ts_low_word = frame_base_ts & 0xFFFF
        debug1_word = frame_dispatch_ts_word(frame_idx, SWB_N_SUBHEADERS)

        for lane_id in range(SWB_N_LANES):
            frame = FrameItem(
                lane_id=lane_id,
                frame_id=frame_idx,
                pre_sop_cycles=0,
                ts_high_word=ts_high_word,
                ts_low_word=ts_low_word,
                debug1_word=debug1_word,
                pkg_cnt=((frame_idx * SWB_N_LANES) + lane_id) & 0xFFFF,
                feb_id=lane_id & 0xFFFF,
                header_id=SWB_MUPIX_HEADER_ID,
            )
            hit_subheader_idx = lane_id
            for shd_idx in range(SWB_N_SUBHEADERS):
                shd = SubheaderDesc(shd_ts=shd_idx & 0xFF)
                if shd_idx == hit_subheader_idx:
                    add_hit_to_subheader(frame, shd, lane_id, frame.frame_id, shd_idx)
                    add_hit_to_subheader(frame, shd, lane_id, frame.frame_id, shd_idx)
                frame.subheaders.append(shd)
            plan.frames_by_lane[lane_id].append(frame)

    plan.raw_total_hits_before_padding = count_total_hits(plan.frames_by_lane, plan.feb_enable_mask)
    plan.padding_hits_added = 0
    expected_words, total_hits = pack_expected_words_from_frames(plan.frames_by_lane, plan.feb_enable_mask)
    plan.expected_dma_words = expected_words
    plan.expected_word_count = len(expected_words)
    plan.total_hits = total_hits
    return plan


def serialize_frame(frame: FrameItem) -> list[dict[str, int | str]]:
    transfers: list[dict[str, int | str]] = []

    for _ in range(frame.pre_sop_cycles):
        transfers.append({"valid": 0, "data": 0x0000_0000, "datak": 0x0, "kind": "idle"})

    transfers.append(
        {
            "valid": 1,
            "data": ((frame.header_id & 0x3F) << 26) | ((frame.feb_id & 0xFFFF) << 8) | SWB_K285,
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
    transfers.append({"valid": 1, "data": frame.debug1_word & 0x7FFF_FFFF, "datak": 0x0, "kind": "debug1"})

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


def collect_sorted_hits(
    frames_by_lane: list[list[FrameItem]],
    feb_enable_mask: int = 0xF,
) -> list[tuple[int, int, int, int, int, int]]:
    records: list[tuple[int, int, int, int, int, int]] = []

    for lane_id, lane_frames in enumerate(frames_by_lane):
        if ((feb_enable_mask >> lane_id) & 0x1) == 0:
            continue
        for frame in lane_frames:
            for shd in frame.subheaders:
                for hit in shd.hits:
                    abs_ts = make_abs_ts(frame.ts_high_word, frame.ts_low_word, shd.shd_ts, hit.payload_word)
                    records.append(
                        (
                            abs_ts,
                            frame.header_id,
                            frame.ts_high_word,
                            frame.ts_low_word,
                            shd.shd_ts,
                            hit.payload_word,
                        )
                    )

    records.sort(key=lambda item: item[0])
    return records


def build_opq_egress_frames(frames_by_lane: list[list[FrameItem]], feb_enable_mask: int = 0xF) -> list[FrameItem]:
    merged_frames: list[FrameItem] = []
    current_frame: FrameItem | None = None
    current_frame_key: tuple[int, int, int] | None = None
    current_subheader: SubheaderDesc | None = None
    frame_debug1_by_key: dict[tuple[int, int, int], int] = {}

    for lane_frames in frames_by_lane:
        for frame in lane_frames:
            frame_key = (frame.header_id, frame.ts_high_word, frame.ts_low_word)
            frame_debug1_by_key[frame_key] = max(frame_debug1_by_key.get(frame_key, 0), frame.debug1_word)

    for _, header_id, ts_high_word, ts_low_word, shd_ts, payload_word in collect_sorted_hits(frames_by_lane, feb_enable_mask):
        frame_key = (header_id, ts_high_word, ts_low_word)

        if frame_key != current_frame_key:
            current_frame = FrameItem(
                lane_id=0,
                frame_id=len(merged_frames),
                pre_sop_cycles=0,
                ts_high_word=ts_high_word,
                ts_low_word=ts_low_word,
                debug1_word=frame_debug1_by_key.get(frame_key, 0),
                pkg_cnt=len(merged_frames) & 0xFFFF,
                feb_id=0,
                header_id=header_id,
            )
            merged_frames.append(current_frame)
            current_frame_key = frame_key
            current_subheader = None

        assert current_frame is not None

        if current_subheader is None or current_subheader.shd_ts != shd_ts:
            current_subheader = SubheaderDesc(shd_ts=shd_ts)
            current_frame.subheaders.append(current_subheader)

        current_subheader.hits.append(HitDesc(payload_word=payload_word))

    return merged_frames


def parse_lane_stream(lane_id: int, stream: Iterable[dict[str, int | str]]) -> list[FrameItem]:
    words = [item for item in stream if int(item["valid"]) == 1]
    frames: list[FrameItem] = []
    idx = 0

    while idx < len(words):
        frame_start_idx = idx
        if frame_start_idx + 4 >= len(words):
            raise RuntimeError(
                f"Lane {lane_id}: truncated frame header at word {frame_start_idx}; "
                f"need 5 words, have {len(words) - frame_start_idx}"
            )

        sop = words[frame_start_idx]
        data = int(sop["data"])
        datak = int(sop["datak"])
        if datak != 0x1 or (data & 0xFF) != SWB_K285:
            raise RuntimeError(f"Lane {lane_id}: expected SOP at word {idx}, got data=0x{data:08X} datak=0x{datak:X}")

        feb_id = (data >> 8) & 0xFFFF
        header_id = (data >> 26) & 0x3F
        ts_high_word = int(words[frame_start_idx + 1]["data"]) & 0xFFFF_FFFF
        ts_low_pkg = int(words[frame_start_idx + 2]["data"]) & 0xFFFF_FFFF
        ts_low_word = (ts_low_pkg >> 16) & 0xFFFF
        pkg_cnt = ts_low_pkg & 0xFFFF
        debug1_word = int(words[frame_start_idx + 4]["data"]) & 0x7FFF_FFFF
        idx = frame_start_idx + 5

        frame = FrameItem(
            lane_id=lane_id,
            frame_id=len(frames),
            pre_sop_cycles=0,
            ts_high_word=ts_high_word,
            ts_low_word=ts_low_word,
            debug1_word=debug1_word,
            pkg_cnt=pkg_cnt,
            feb_id=feb_id,
            header_id=header_id,
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
        "feb_enable_mask": f"0x{plan.feb_enable_mask:X}",
        "hit_mode": plan.hit_mode,
        "subheader_count": plan.subheader_count,
        "expected_word_count": plan.expected_word_count,
        "total_hits": plan.total_hits,
        "raw_total_hits_before_padding": plan.raw_total_hits_before_padding,
        "padding_hits_added": plan.padding_hits_added,
        "frames_by_lane": [
            [
                {
                    "lane_id": frame.lane_id,
                    "frame_id": frame.frame_id,
                    "pre_sop_cycles": frame.pre_sop_cycles,
                    "ts_high_word": f"0x{frame.ts_high_word:08X}",
                    "ts_low_word": f"0x{frame.ts_low_word:04X}",
                    "debug1_word": f"0x{frame.debug1_word:08X}",
                    "pkg_cnt": frame.pkg_cnt,
                    "feb_id": frame.feb_id,
                    "header_id": f"0x{frame.header_id:02X}",
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
    parser.add_argument(
        "--profile",
        choices=("poisson", "smoke"),
        default="poisson",
        help="Traffic profile: poisson is the default sweep, smoke is the minimal directed seam case.",
    )
    parser.add_argument("--frames", type=int, default=2, help="Number of frames per lane.")
    parser.add_argument(
        "--smoke-frames",
        type=int,
        default=1,
        help="Number of frames for the smoke profile; default keeps the historical one-frame smoke.",
    )
    parser.add_argument("--seed", type=int, default=1, help="Deterministic RNG seed for Poisson traffic.")
    parser.add_argument("--subheaders", type=int, default=SWB_N_SUBHEADERS, help="Number of subheaders per frame.")
    parser.add_argument(
        "--hit-mode",
        choices=("poisson", "zero", "single", "max"),
        default="poisson",
        help="Per-subheader hit generation mode.",
    )
    parser.add_argument(
        "--feb-enable-mask",
        default="F",
        help="4-bit hex FEB enable mask applied when synthesizing expected OPQ/DMA outputs.",
    )
    parser.add_argument(
        "--sat",
        type=float,
        nargs=SWB_N_LANES,
        default=[0.20, 0.40, 0.60, 0.80],
        metavar=("SAT0", "SAT1", "SAT2", "SAT3"),
        help="Per-lane saturation factors in the 0.0 to 0.8 bring-up range.",
    )
    parser.add_argument(
        "--lane-skew-fixed",
        type=str,
        default="0,0,0,0",
        help="Comma-separated per-lane idle cycles inserted before each frame SOP.",
    )
    parser.add_argument(
        "--lane-skew-varying",
        action="store_true",
        help="Randomize lane 1..3 pre-SOP skew independently for each frame.",
    )
    parser.add_argument("--lane-skew-max-cyc", type=int, default=0, help="Maximum random per-frame skew when varying.")
    parser.add_argument(
        "--header-kind",
        choices=("mupix", "tile", "scifi"),
        default="mupix",
        help="Detector header kind used for generated data frames.",
    )
    parser.add_argument("--out-dir", type=Path, default=Path("out"), help="Artifact output directory.")
    return parser


def parse_int_auto(text: str) -> int:
    if text.lower().startswith("0x"):
        return int(text, 16)
    try:
        return int(text, 10)
    except ValueError:
        return int(text, 16)


def parse_lane_skew_fixed(text: str) -> list[int]:
    fields = [field.strip() for field in text.split(",")]
    if len(fields) != SWB_N_LANES:
        raise SystemExit(f"--lane-skew-fixed requires {SWB_N_LANES} comma-separated entries")
    return [parse_int_auto(field) for field in fields]


def header_id_for_kind(kind: str) -> int:
    if kind == "tile":
        return SWB_TILE_HEADER_ID
    if kind == "scifi":
        return SWB_SCIFI_HEADER_ID
    return SWB_MUPIX_HEADER_ID


def apply_fixed_lane_skew(plan: CasePlan, lane_skew_cycles: list[int]) -> None:
    for lane_id, lane_frames in enumerate(plan.frames_by_lane):
        for frame in lane_frames:
            frame.pre_sop_cycles = lane_skew_cycles[lane_id]


def apply_varying_lane_skew(plan: CasePlan, lane_skew_max_cyc: int, seed: int) -> None:
    rng = random.Random(seed ^ 0x5A17C0DE)
    for lane_id, lane_frames in enumerate(plan.frames_by_lane):
        for frame in lane_frames:
            if lane_id == 0:
                frame.pre_sop_cycles = 0
            else:
                frame.pre_sop_cycles = rng.randint(0, lane_skew_max_cyc)


def main(argv: list[str]) -> int:
    plain_args, plusargs = parse_plusargs(argv)
    parser = build_arg_parser()
    args = parser.parse_args(plain_args)

    if "SWB_FRAMES" in plusargs:
        args.frames = int(plusargs["SWB_FRAMES"])
    if "SWB_SEED" in plusargs:
        args.seed = int(plusargs["SWB_SEED"])
    if "SWB_PROFILE" in plusargs:
        args.profile = plusargs["SWB_PROFILE"]
    if "SWB_SUBHEADERS" in plusargs:
        args.subheaders = int(plusargs["SWB_SUBHEADERS"])
    if "SWB_HIT_MODE" in plusargs:
        args.hit_mode = plusargs["SWB_HIT_MODE"]
    if "SWB_FEB_ENABLE_MASK" in plusargs:
        args.feb_enable_mask = plusargs["SWB_FEB_ENABLE_MASK"]
    if "SWB_OUT_DIR" in plusargs:
        args.out_dir = Path(plusargs["SWB_OUT_DIR"])
    for lane_id in range(SWB_N_LANES):
        key = f"SWB_SAT{lane_id}"
        if key in plusargs:
            args.sat[lane_id] = float(plusargs[key])
        key = f"SWB_LANE{lane_id}_SKEW_CYC"
        if key in plusargs:
            fixed_skew = parse_lane_skew_fixed(args.lane_skew_fixed)
            fixed_skew[lane_id] = int(plusargs[key])
            args.lane_skew_fixed = ",".join(str(value) for value in fixed_skew)
    if "SWB_LANE_SKEW_VARYING" in plusargs:
        args.lane_skew_varying = (int(plusargs["SWB_LANE_SKEW_VARYING"]) != 0)
    if "SWB_LANE_SKEW_MAX_CYC" in plusargs:
        args.lane_skew_max_cyc = int(plusargs["SWB_LANE_SKEW_MAX_CYC"])
    if "SWB_HEADER_KIND" in plusargs:
        args.header_kind = plusargs["SWB_HEADER_KIND"].lower()

    out_dir = args.out_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    if args.profile not in {"poisson", "smoke"}:
        raise SystemExit(f"Unsupported profile {args.profile!r}; use 'poisson' or 'smoke'")
    if args.hit_mode not in {"poisson", "zero", "single", "max"}:
        raise SystemExit(f"Unsupported hit mode {args.hit_mode!r}")
    if args.subheaders <= 0 or args.subheaders > SWB_N_SUBHEADERS:
        raise SystemExit(f"--subheaders must be in the range 1..{SWB_N_SUBHEADERS}")
    if args.lane_skew_varying and args.lane_skew_max_cyc <= 0:
        raise SystemExit("--lane-skew-varying requires --lane-skew-max-cyc > 0")
    fixed_lane_skew = parse_lane_skew_fixed(args.lane_skew_fixed)
    if args.lane_skew_varying and any(value != 0 for value in fixed_lane_skew):
        raise SystemExit("--lane-skew-fixed and --lane-skew-varying are mutually exclusive")
    feb_enable_mask = parse_int_auto(args.feb_enable_mask) & 0xF

    if args.profile == "smoke":
        if args.smoke_frames < 1:
            raise SystemExit("--smoke-frames must be at least 1")
        plan = build_smoke_case(args.smoke_frames)
        args.frames = args.smoke_frames
        args.seed = 0
        args.sat = [0.0] * SWB_N_LANES
    else:
        header_id = header_id_for_kind(args.header_kind)
        plan = build_basic_case(
            frame_count=args.frames,
            lane_saturation=list(args.sat),
            seed=args.seed,
            subheader_count=args.subheaders,
            feb_enable_mask=feb_enable_mask,
            hit_mode=args.hit_mode,
            header_id=header_id,
            header_kind=args.header_kind,
        )
    if args.profile == "smoke":
        plan.feb_enable_mask = feb_enable_mask
        plan.raw_total_hits_before_padding = count_total_hits(plan.frames_by_lane, plan.feb_enable_mask)
        plan.total_hits = plan.raw_total_hits_before_padding
        plan.padding_hits_added = 0
        plan.expected_dma_words, plan.total_hits = pack_expected_words_from_frames(plan.frames_by_lane, plan.feb_enable_mask)
        plan.expected_word_count = len(plan.expected_dma_words)
    if args.lane_skew_varying:
        apply_varying_lane_skew(plan, args.lane_skew_max_cyc, args.seed)
    else:
        apply_fixed_lane_skew(plan, fixed_lane_skew)
    lane_streams = serialize_plan(plan)
    opq_egress_stream: list[dict[str, int | str]] = []
    opq_egress_frames = build_opq_egress_frames(plan.frames_by_lane, plan.feb_enable_mask)
    for merged_frame in opq_egress_frames:
        opq_egress_stream.extend(serialize_frame(merged_frame))
    parsed_frames_by_lane = [parse_lane_stream(lane_id, lane_streams[lane_id]) for lane_id in range(SWB_N_LANES)]
    reparsed_dma_words, reparsed_total_hits = pack_expected_words_from_frames(parsed_frames_by_lane, plan.feb_enable_mask)
    reparsed_opq_frames = parse_lane_stream(0, opq_egress_stream)
    reparsed_opq_dma_words, reparsed_opq_total_hits = pack_expected_words_from_frames(
        [reparsed_opq_frames, [], [], []],
        0x1,
    )

    normalized_source = [normalize_dma_word(word) for word in plan.expected_dma_words]
    normalized_reparsed = [normalize_dma_word(word) for word in reparsed_dma_words]
    normalized_opq_reparsed = [normalize_dma_word(word) for word in reparsed_opq_dma_words]

    if normalized_source != normalized_reparsed:
        raise RuntimeError("Reparsed lane streams do not reproduce the expected DMA payload words")
    if plan.total_hits != reparsed_total_hits:
        raise RuntimeError(
            f"Total hit count mismatch after reparsing: source={plan.total_hits} reparsed={reparsed_total_hits}"
        )
    if normalized_source != normalized_opq_reparsed:
        raise RuntimeError("Synthesized OPQ egress replay does not reproduce the expected DMA payload words")
    if plan.total_hits != reparsed_opq_total_hits:
        raise RuntimeError(
            "Total hit count mismatch after reparsing the synthesized OPQ egress replay: "
            f"source={plan.total_hits} reparsed={reparsed_opq_total_hits}"
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

    with (out_dir / "opq_egress.jsonl").open("w", encoding="utf-8") as handle:
        for index, item in enumerate(opq_egress_stream):
            record = {
                "index": index,
                "valid": int(item["valid"]),
                "data": f"0x{int(item['data']) & 0xFFFF_FFFF:08X}",
                "datak": f"0x{int(item['datak']) & 0xF:X}",
                "kind": item["kind"],
            }
            handle.write(json.dumps(record, sort_keys=True))
            handle.write("\n")

    with (out_dir / "opq_egress.mem").open("w", encoding="ascii") as handle:
        for item in opq_egress_stream:
            packed_beat = (
                ((int(item["valid"]) & 0x1) << 36)
                | ((int(item["datak"]) & 0xF) << 32)
                | (int(item["data"]) & 0xFFFF_FFFF)
            )
            handle.write(f"{packed_beat:010X}\n")

    replay_manifest = {
        "format": {
            "lane_mem_word": "{valid[36], datak[35:32], data[31:0]}",
            "opq_egress_mem_word": "{valid[36], datak[35:32], data[31:0]} synthesized merged OPQ egress replay",
            "expected_dma_word": "normalized 256-bit payload word, one per line",
        },
        "replay_dir_plusarg": str(out_dir),
        "lane_mem_files": [f"lane{lane_id}_ingress.mem" for lane_id in range(SWB_N_LANES)],
        "opq_egress_mem": "opq_egress.mem",
        "expected_dma_words_mem": "expected_dma_words.mem",
    }

    with (out_dir / "uvm_replay_manifest.json").open("w", encoding="utf-8") as handle:
        json.dump(replay_manifest, handle, indent=2)
        handle.write("\n")

    summary = {
        "profile": plan.profile,
        "frames_per_lane": args.frames,
        "seed": args.seed,
        "lane_saturation": list(args.sat),
        "feb_enable_mask": f"0x{plan.feb_enable_mask:X}",
        "hit_mode": plan.hit_mode,
        "header_kind": plan.header_kind,
        "subheader_count": plan.subheader_count,
        "lane_skew_fixed": fixed_lane_skew,
        "lane_skew_varying": args.lane_skew_varying,
        "lane_skew_max_cyc": args.lane_skew_max_cyc,
        "total_hits": plan.total_hits,
        "raw_total_hits_before_padding": plan.raw_total_hits_before_padding,
        "padding_hits_added": plan.padding_hits_added,
        "expected_word_count": plan.expected_word_count,
        "expected_dma_sha256": digest,
        "artifacts": {
            "plan": str((out_dir / "plan.json").relative_to(out_dir)),
            "expected_dma_words": str((out_dir / "expected_dma_words.txt").relative_to(out_dir)),
            "expected_dma_words_mem": "expected_dma_words.mem",
            "lane_streams": [f"lane{lane_id}_ingress.jsonl" for lane_id in range(SWB_N_LANES)],
            "lane_streams_mem": [f"lane{lane_id}_ingress.mem" for lane_id in range(SWB_N_LANES)],
            "opq_egress": "opq_egress.jsonl",
            "opq_egress_mem": "opq_egress.mem",
            "uvm_replay_manifest": "uvm_replay_manifest.json",
        },
        "checks": {
            "reparsed_dma_match": True,
            "reparsed_total_hits": reparsed_total_hits,
            "reparsed_opq_dma_match": True,
            "reparsed_opq_total_hits": reparsed_opq_total_hits,
        },
    }

    with (out_dir / "summary.json").open("w", encoding="utf-8") as handle:
        json.dump(summary, handle, indent=2)
        handle.write("\n")

    print(
        "basic/ref: "
        f"profile={plan.profile} frames={args.frames} seed={args.seed} "
        f"sat={','.join(f'{value:0.2f}' for value in args.sat)} "
        f"mask=0x{plan.feb_enable_mask:X} hit_mode={plan.hit_mode} subheaders={plan.subheader_count} "
        f"header_kind={plan.header_kind} "
        f"total_hits={plan.total_hits} expected_words={plan.expected_word_count} "
        f"sha256={digest[:16]}"
    )
    print(f"basic/ref: wrote artifacts to {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
