#!/usr/bin/env python3
"""Generate scheduled replay files for the GHDL cross waveform fixture.

The files produced here are intentionally plain: one packed word per simulated
cycle. The GHDL testbench reads them directly, so the packet cadence and packet
contents come from the same reference builder used by the UVM sequence.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any


N_LANES = 4
FRAME_SLOT_CYCLES = 4096
FRAME_COUNT = 3
CASE_CYCLES = 24576

K285 = 0xBC
K284 = 0x9C
K237 = 0xF7
MUPIX_HEADER_ID = 0b111010
BAD_HEADER_ID = 0b001011

KIND = {
    "idle": 0,
    "sop": 1,
    "ts_high": 2,
    "ts_low_pkg": 3,
    "debug0": 4,
    "debug1": 5,
    "subheader": 6,
    "hit": 7,
    "eop": 8,
    "header_error": 9,
    "subheader_error": 10,
    "hit_error": 11,
    "dma_hit_payload": 12,
}


def repo_root() -> Path:
    return Path(__file__).resolve().parents[5]


def load_ref_module(root: Path) -> Any:
    ref_path = root / "tb_int/cases/basic/ref/run_basic_ref.py"
    spec = importlib.util.spec_from_file_location("swb_basic_ref", ref_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {ref_path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def pack_event(source_lane: int, kind: int, valid: int, datak: int, data: int, err: int = 0) -> int:
    return (
        ((source_lane & 0x3) << 45)
        | ((kind & 0x1F) << 40)
        | ((err & 0x7) << 37)
        | ((valid & 0x1) << 36)
        | ((datak & 0xF) << 32)
        | (data & 0xFFFF_FFFF)
    )


def idle_event(source_lane: int = 0) -> int:
    return pack_event(source_lane, KIND["idle"], 0, 0, 0)


def kind_code(item: dict[str, int | str]) -> int:
    return KIND.get(str(item["kind"]), KIND["idle"])


def place_stream(
    schedule: list[int],
    base_cycle: int,
    source_lane: int,
    stream: list[dict[str, int | str]],
    *,
    error_kind: int | None = None,
) -> int:
    last_valid = base_cycle - 1
    for offset, item in enumerate(stream):
        cycle = base_cycle + offset
        if cycle >= len(schedule):
            break
        valid = int(item["valid"])
        datak = int(item["datak"]) & 0xF
        data = int(item["data"]) & 0xFFFF_FFFF
        code = kind_code(item)
        err = 0
        if error_kind is not None and valid:
            if code == KIND["sop"]:
                code = KIND["header_error"]
                err = 4
            elif code == KIND["subheader"]:
                code = KIND["subheader_error"]
                err = 2
            elif code == KIND["hit"]:
                code = KIND["hit_error"]
                err = 1
        schedule[cycle] = pack_event(source_lane, code, valid, datak, data, err)
        if valid:
            last_valid = cycle
    return last_valid


def lane_frame_stream(ref: Any, frame: Any) -> list[dict[str, int | str]]:
    return ref.serialize_frame(frame)


def build_basic_case(
    ref: Any,
    *,
    seed: int,
    sat: list[float],
    lane_skew: list[int],
    mask_by_frame: list[int],
    hit_mode: str = "poisson",
) -> tuple[list[list[int]], list[int], dict[str, Any]]:
    plan = ref.build_basic_case(
        FRAME_COUNT,
        sat,
        seed,
        ref.SWB_N_SUBHEADERS,
        0xF,
        hit_mode,
        MUPIX_HEADER_ID,
        "mupix",
    )
    ref.apply_fixed_lane_skew(plan, lane_skew)

    lane_schedules = [[idle_event(lane) for _ in range(CASE_CYCLES)] for lane in range(N_LANES)]
    opq_schedule = [idle_event(0) for _ in range(CASE_CYCLES)]
    eop_cycles_by_frame: list[int] = []
    opq_cursor = 0

    for frame_idx in range(FRAME_COUNT):
        frame_base = frame_idx * FRAME_SLOT_CYCLES
        mask = mask_by_frame[min(frame_idx, len(mask_by_frame) - 1)] & 0xF
        last_eop = frame_base
        active_frames_by_lane: list[list[Any]] = [[] for _ in range(N_LANES)]
        for lane in range(N_LANES):
            if ((mask >> lane) & 0x1) == 0:
                continue
            frame = plan.frames_by_lane[lane][frame_idx]
            stream = lane_frame_stream(ref, frame)
            last_eop = max(last_eop, place_stream(lane_schedules[lane], frame_base, lane, stream))
            active_frames_by_lane[lane].append(frame)

        eop_cycles_by_frame.append(last_eop)
        merged_frames = ref.build_opq_egress_frames(active_frames_by_lane, mask)
        if merged_frames:
            # The native-SV OPQ presents near the end of the 4096-cycle slot for
            # this long-run profile. Keep that display timing, while also
            # enforcing the page-commit rule when packets are shorter.
            release_cycle = max(frame_base + FRAME_SLOT_CYCLES - 225, last_eop + 2, opq_cursor)
            merged_stream = ref.serialize_frame(merged_frames[0])
            opq_cursor = place_stream(opq_schedule, release_cycle, 0, merged_stream) + 1

    summary = {
        "seed": seed,
        "sat": sat,
        "lane_skew": lane_skew,
        "mask_by_frame": [f"0x{mask:x}" for mask in mask_by_frame],
        "total_hits": plan.total_hits,
        "expected_words": plan.expected_word_count,
        "eop_cycles_by_frame": eop_cycles_by_frame,
    }
    return lane_schedules, opq_schedule, summary


def make_control_word(kind: int, datak: int, data: int, lane: int = 0) -> int:
    return pack_event(lane, kind, 1, datak, data, 0)


def make_sop(header_id: int, feb_id: int) -> int:
    return ((header_id & 0x3F) << 26) | ((feb_id & 0xFFFF) << 8) | K285


def make_subheader(shd_ts: int, hits: int) -> int:
    return ((shd_ts & 0xFF) << 24) | ((hits & 0xFF) << 8) | K237


def make_short_case(*, error: bool = False, control: bool = False) -> tuple[list[list[int]], list[int], dict[str, Any]]:
    lane_schedules = [[idle_event(lane) for _ in range(CASE_CYCLES)] for lane in range(N_LANES)]
    opq_schedule = [idle_event(0) for _ in range(CASE_CYCLES)]
    eop_cycles_by_frame: list[int] = []

    for frame_idx in range(FRAME_COUNT):
        frame_base = frame_idx * FRAME_SLOT_CYCLES
        for lane in range(N_LANES):
            header_id = BAD_HEADER_ID if error and lane == 0 else MUPIX_HEADER_ID
            feb_id = (0x100 + lane) & 0xFFFF
            ts = frame_idx * 0x800
            words = [
                make_control_word(KIND["header_error"] if error and lane == 0 else KIND["sop"], 1, make_sop(header_id, feb_id), lane),
                make_control_word(KIND["ts_high"], 0, (ts >> 16) & 0xFFFF_FFFF, lane),
                make_control_word(KIND["ts_low_pkg"], 0, ((ts & 0xFFFF) << 16) | ((frame_idx * 4 + lane) & 0xFFFF), lane),
                make_control_word(KIND["debug0"], 0, (1 << 16) | (0 if control else 1), lane),
                make_control_word(KIND["debug1"], 0, (ts + 0x800) & 0x7FFF_FFFF, lane),
                make_control_word(KIND["subheader_error"] if error and lane == 0 else KIND["subheader"], 1, make_subheader(lane, 0 if control else 1), lane),
            ]
            if not control:
                words.append(make_control_word(KIND["hit_error"] if error and lane == 0 else KIND["hit"], 0, 0x4000_0000 | (frame_idx << 20) | (lane << 16), lane))
            words.append(make_control_word(KIND["eop"], 1, K284, lane))
            for offset, packed in enumerate(words):
                cycle = frame_base + offset
                lane_schedules[lane][cycle] = packed
            eop_cycles_by_frame.append(frame_base + len(words) - 1)

        if not error and not control:
            release = frame_base + 64
            for lane in range(N_LANES):
                words = [lane_schedules[lane][frame_base + offset] for offset in range(8)]
                for offset, packed in enumerate(words):
                    opq_schedule[release + lane * 8 + offset] = packed

    return lane_schedules, opq_schedule, {"eop_cycles_by_frame": eop_cycles_by_frame}


def write_case(out_dir: Path, case_id: str, lanes: list[list[int]], opq: list[int], summary: dict[str, Any]) -> None:
    case_dir = out_dir / case_id
    case_dir.mkdir(parents=True, exist_ok=True)
    for lane, schedule in enumerate(lanes):
        (case_dir / f"lane{lane}.mem").write_text(
            "".join(f"{word:012X}\n" for word in schedule),
            encoding="ascii",
        )
    (case_dir / "opq.mem").write_text(
        "".join(f"{word:012X}\n" for word in opq),
        encoding="ascii",
    )
    (case_dir / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", required=True, type=Path)
    parser.add_argument("--case-cycles", type=int, default=CASE_CYCLES)
    args = parser.parse_args()
    if args.case_cycles != CASE_CYCLES:
        raise SystemExit(f"this replay generator currently emits CASE_CYCLES={CASE_CYCLES}")

    root = repo_root()
    ref = load_ref_module(root)
    out_dir = args.out_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    cases = {
        "B001": build_basic_case(ref, seed=1, sat=[0.20, 0.40, 0.60, 0.80], lane_skew=[0, 0, 0, 0], mask_by_frame=[0xF, 0xF, 0xF]),
        "B046": build_basic_case(ref, seed=46, sat=[0.20, 0.40, 0.60, 0.80], lane_skew=[0, 0, 0, 0], mask_by_frame=[0xF, 0x3, 0x1]),
        "P123": build_basic_case(ref, seed=123, sat=[0.20, 0.40, 0.60, 0.80], lane_skew=[0, 512, 1024, 2048], mask_by_frame=[0xF, 0xF, 0xF]),
        "X111": make_short_case(error=True),
        "C001": make_short_case(control=True),
    }

    manifest: dict[str, Any] = {
        "format": "packed_event[47:0] = {1'b0, source_lane[1:0], word_kind[4:0], err[2:0], valid, datak[3:0], data[31:0]}",
        "case_cycles": CASE_CYCLES,
        "frame_slot_cycles": FRAME_SLOT_CYCLES,
        "frames": FRAME_COUNT,
        "cases": {},
    }
    for case_id, (lanes, opq, summary) in cases.items():
        write_case(out_dir, case_id, lanes, opq, summary)
        manifest["cases"][case_id] = summary
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"wrote replay schedules to {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
