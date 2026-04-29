#!/usr/bin/env python3
"""Compare critical OPQ timing points between native-SV UVM and GHDL VCDs."""

from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path


K285 = 0xBC
K284 = 0x9C
K237 = 0xF7


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--uvm-vcd", required=True, type=Path)
    parser.add_argument("--ghdl-vcd", required=True, type=Path)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--frame-slot-cycles", type=int, default=4096)
    parser.add_argument("--frame-ts-step", type=lambda text: int(text, 0), default=0x800)
    parser.add_argument("--ghdl-case-cycles", type=int, default=24576)
    parser.add_argument("--frames", type=int, default=3)
    return parser.parse_args()


def parse_header(vcd: Path) -> dict[str, str]:
    ids: dict[str, str] = {}
    stack: list[str] = []
    with vcd.open("r", encoding="ascii", errors="replace") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if line.startswith("$scope "):
                stack.append(line.split()[2])
            elif line.startswith("$upscope"):
                stack.pop()
            elif line.startswith("$var "):
                parts = line.split()
                ids[parts[3]] = ".".join(stack + [parts[4]])
            elif line == "$enddefinitions $end":
                break
    return ids


def pick(name_to_id: dict[str, str], *names: str) -> str:
    for name in names:
        if name in name_to_id:
            return name_to_id[name]
    raise KeyError(", ".join(names))


def bits_to_int(bits: str | None) -> int | None:
    if bits is None:
        return 0
    lowered = bits.lower()
    if "x" in lowered or "z" in lowered:
        return None
    if set(bits) <= {"0", "1"}:
        return int(bits, 2)
    return int(bits)


def extract_streams(vcd: Path, layout: str) -> dict[str, list[tuple[int, int, int]]]:
    ids = parse_header(vcd)
    name_to_id = {name: ident for ident, name in ids.items()}
    if layout == "uvm":
        clk_id = name_to_id["tb_top.clk"]
        specs = {
            f"lane{lane}": (
                name_to_id[f"tb_top.feb_if{lane}.valid"],
                pick(name_to_id, f"tb_top.feb_if{lane}.data", f"tb_top.feb_if{lane}.data[31:0]"),
                pick(name_to_id, f"tb_top.feb_if{lane}.datak", f"tb_top.feb_if{lane}.datak[3:0]"),
            )
            for lane in range(4)
        }
        specs["opq"] = (
            name_to_id["tb_top.opq_if.valid"],
            pick(name_to_id, "tb_top.opq_if.data", "tb_top.opq_if.data[31:0]"),
            pick(name_to_id, "tb_top.opq_if.datak", "tb_top.opq_if.datak[3:0]"),
        )
    elif layout == "ghdl":
        clk_id = name_to_id["tb_swb_cross_ghdl.clk"]
        specs = {
            f"lane{lane}": (
                pick(name_to_id, "tb_swb_cross_ghdl.lane_valid", "tb_swb_cross_ghdl.lane_valid[3:0]"),
                pick(name_to_id, f"tb_swb_cross_ghdl.lane{lane}_data", f"tb_swb_cross_ghdl.lane{lane}_data[31:0]"),
                pick(name_to_id, f"tb_swb_cross_ghdl.lane{lane}_datak", f"tb_swb_cross_ghdl.lane{lane}_datak[3:0]"),
            )
            for lane in range(4)
        }
        specs["opq"] = (
            name_to_id["tb_swb_cross_ghdl.opq_presenter_valid"],
            pick(name_to_id, "tb_swb_cross_ghdl.opq_data", "tb_swb_cross_ghdl.opq_data[31:0]"),
            pick(name_to_id, "tb_swb_cross_ghdl.opq_datak", "tb_swb_cross_ghdl.opq_datak[3:0]"),
        )
    else:
        raise ValueError(layout)

    values: dict[str, str] = {}
    streams: dict[str, list[tuple[int, int, int]]] = {name: [] for name in specs}
    changes: list[tuple[str, str]] = []
    cycle = -1
    last_clk = "0"

    def apply_group() -> None:
        nonlocal cycle, last_clk
        if not changes:
            return
        for ident, value in changes:
            values[ident] = value
        clk = values.get(clk_id, "0")
        if last_clk == "0" and clk == "1":
            cycle += 1
            for name, (valid_id, data_id, datak_id) in specs.items():
                valid_raw = bits_to_int(values.get(valid_id))
                if layout == "ghdl" and name.startswith("lane"):
                    lane = int(name[-1])
                    valid = ((valid_raw or 0) >> lane) & 1
                else:
                    valid = valid_raw
                if valid == 1:
                    data = bits_to_int(values.get(data_id))
                    datak = bits_to_int(values.get(datak_id))
                    if data is None or datak is None:
                        raise ValueError(f"{layout}:{name} has X/Z at cycle {cycle}")
                    streams[name].append((cycle, data, datak))
        last_clk = clk

    with vcd.open("r", encoding="ascii", errors="replace") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue
            if line.startswith("$"):
                continue
            if line.startswith("#"):
                apply_group()
                changes = []
            elif line.startswith("b"):
                bits, ident = line[1:].split(maxsplit=1)
                changes.append((ident, bits))
            else:
                changes.append((line[1:], line[0]))
        apply_group()
    return streams


def sop_cycles(stream: list[tuple[int, int, int]]) -> list[int]:
    return [cycle for cycle, data, datak in stream if datak == 1 and (data & 0xFF) == K285]


def eop_cycles(stream: list[tuple[int, int, int]]) -> list[int]:
    return [cycle for cycle, data, datak in stream if datak == 1 and (data & 0xFF) == K284]


def packet_frames(stream: list[tuple[int, int, int]]) -> list[list[tuple[int, int, int]]]:
    frames: list[list[tuple[int, int, int]]] = []
    current: list[tuple[int, int, int]] = []
    in_frame = False
    for beat in stream:
        _cycle, data, datak = beat
        if datak == 1 and (data & 0xFF) == K285:
            current = [beat]
            in_frame = True
        elif in_frame:
            current.append(beat)
            if datak == 1 and (data & 0xFF) == K284:
                frames.append(current)
                current = []
                in_frame = False
    return frames


def digest_counter(counter: Counter[object]) -> str:
    payload = "\n".join(f"{item}:{count}" for item, count in sorted(counter.items()))
    return hashlib.sha1(payload.encode("ascii")).hexdigest()[:16]


def parse_packet(frame: list[tuple[int, int, int]]) -> dict[str, object]:
    if len(frame) < 7:
        return {
            "valid_grammar": False,
            "reason": "short_frame",
            "hit_counter": Counter(),
            "subframe_hit_counter": Counter(),
        }
    valid_grammar = (
        frame[0][2] == 1
        and (frame[0][1] & 0xFF) == K285
        and frame[-1][2] == 1
        and (frame[-1][1] & 0xFF) == K284
    )
    header = frame[0][1]
    ts_high = frame[1][1]
    ts_low_pkg = frame[2][1]
    debug0 = frame[3][1]
    frame_ts = ((ts_high & 0xFFFF_FFFF) << 16) | ((ts_low_pkg >> 16) & 0xFFFF)
    declared_subheaders = (debug0 >> 16) & 0x7FFF
    declared_hits = debug0 & 0xFFFF

    hit_counter: Counter[int] = Counter()
    subframe_hit_counter: Counter[tuple[int, int]] = Counter()
    subheaders: list[int] = []
    current_sub_ts = -1
    for _cycle, data, datak in frame[5:-1]:
        if datak == 1 and (data & 0xFF) == K237:
            current_sub_ts = (data >> 24) & 0xFF
            subheaders.append(current_sub_ts)
        elif datak == 0:
            hit_counter[data] += 1
            subframe_hit_counter[(current_sub_ts, data)] += 1
        else:
            valid_grammar = False

    return {
        "valid_grammar": valid_grammar,
        "sop_cycle": frame[0][0],
        "eop_cycle": frame[-1][0],
        "packet_type": (header >> 26) & 0x3F,
        "fpga_id": (header >> 8) & 0xFFFF,
        "frame_ts": frame_ts,
        "pkg_cnt": ts_low_pkg & 0xFFFF,
        "declared_subheaders": declared_subheaders,
        "declared_hits": declared_hits,
        "subheader_count": len(subheaders),
        "hit_count": sum(hit_counter.values()),
        "hit_digest": digest_counter(hit_counter),
        "subframe_hit_digest": digest_counter(subframe_hit_counter),
        "declared_counts_ok": (
            declared_subheaders == len(subheaders)
            and declared_hits == sum(hit_counter.values())
        ),
        "hit_counter": hit_counter,
        "subframe_hit_counter": subframe_hit_counter,
    }


def public_packet_summary(packet: dict[str, object]) -> dict[str, object]:
    return {
        key: (f"0x{value:x}" if key == "frame_ts" and isinstance(value, int) else value)
        for key, value in packet.items()
        if key not in {"hit_counter", "subframe_hit_counter"}
    }


def timestamp_deltas(packets: list[dict[str, object]], frames: int) -> list[int]:
    values = [int(packet["frame_ts"]) for packet in packets[:frames]]
    return [values[idx + 1] - values[idx] for idx in range(len(values) - 1)]


def packet_integrity(
    streams: dict[str, list[tuple[int, int, int]]],
    frames: int,
    frame_ts_step: int,
) -> dict[str, object]:
    lane_packets = {
        f"lane{lane}": [parse_packet(frame) for frame in packet_frames(streams[f"lane{lane}"])[:frames]]
        for lane in range(4)
    }
    opq_packets = [parse_packet(frame) for frame in packet_frames(streams["opq"])[:frames]]
    enough_packet_frames = (
        len(opq_packets) >= frames
        and all(len(lane_packets[f"lane{lane}"]) >= frames for lane in range(4))
    )
    grammar_ok = enough_packet_frames and all(
        bool(packet["valid_grammar"])
        for packet in opq_packets[:frames]
    ) and all(
        bool(packet["valid_grammar"])
        for lane in range(4)
        for packet in lane_packets[f"lane{lane}"][:frames]
    )
    lane0_ts_deltas = timestamp_deltas(lane_packets["lane0"], frames) if enough_packet_frames else []
    opq_ts_deltas = timestamp_deltas(opq_packets, frames) if enough_packet_frames else []
    lane_ts_aligned = []
    opq_ts_matches_ingress = []
    hit_multiset_matches = []
    subframe_hit_multiset_matches = []
    opq_declared_counts_ok = []
    for frame_idx in range(frames if enough_packet_frames else 0):
        ingress_ts = [int(lane_packets[f"lane{lane}"][frame_idx]["frame_ts"]) for lane in range(4)]
        lane_ts_aligned.append(len(set(ingress_ts)) == 1)
        opq_ts_matches_ingress.append(int(opq_packets[frame_idx]["frame_ts"]) == ingress_ts[0])
        ingress_hits: Counter[int] = Counter()
        ingress_subframe_hits: Counter[tuple[int, int]] = Counter()
        for lane in range(4):
            ingress_hits.update(lane_packets[f"lane{lane}"][frame_idx]["hit_counter"])  # type: ignore[arg-type]
            ingress_subframe_hits.update(lane_packets[f"lane{lane}"][frame_idx]["subframe_hit_counter"])  # type: ignore[arg-type]
        hit_multiset_matches.append(opq_packets[frame_idx]["hit_counter"] == ingress_hits)
        subframe_hit_multiset_matches.append(opq_packets[frame_idx]["subframe_hit_counter"] == ingress_subframe_hits)
        opq_declared_counts_ok.append(bool(opq_packets[frame_idx]["declared_counts_ok"]))

    return {
        "enough_packet_frames": enough_packet_frames,
        "grammar_ok": grammar_ok,
        "lane_frame_ts_aligned": lane_ts_aligned,
        "lane0_frame_ts_deltas": [f"0x{delta:x}" for delta in lane0_ts_deltas],
        "lane0_frame_ts_step_ok": enough_packet_frames and all(delta == frame_ts_step for delta in lane0_ts_deltas),
        "opq_frame_ts_deltas": [f"0x{delta:x}" for delta in opq_ts_deltas],
        "opq_frame_ts_step_ok": enough_packet_frames and all(delta == frame_ts_step for delta in opq_ts_deltas),
        "opq_frame_ts_matches_ingress": opq_ts_matches_ingress,
        "opq_declared_counts_ok": opq_declared_counts_ok,
        "hit_multiset_matches": hit_multiset_matches,
        "subframe_hit_multiset_matches": subframe_hit_multiset_matches,
        "pass": bool(
            enough_packet_frames
            and grammar_ok
            and all(lane_ts_aligned)
            and all(opq_ts_matches_ingress)
            and all(hit_multiset_matches)
            and all(subframe_hit_multiset_matches)
            and all(opq_declared_counts_ok)
            and all(delta == frame_ts_step for delta in lane0_ts_deltas)
            and all(delta == frame_ts_step for delta in opq_ts_deltas)
        ),
        "opq_packets": [public_packet_summary(packet) for packet in opq_packets[:frames]],
    }


def limit_cycles(
    streams: dict[str, list[tuple[int, int, int]]],
    max_cycle: int | None,
) -> dict[str, list[tuple[int, int, int]]]:
    if max_cycle is None:
        return streams
    return {
        name: [beat for beat in beats if beat[0] < max_cycle]
        for name, beats in streams.items()
    }


def summarize(
    streams: dict[str, list[tuple[int, int, int]]],
    frame_slot_cycles: int,
    frames: int,
    *,
    max_cycle: int | None = None,
) -> dict[str, object]:
    streams = limit_cycles(streams, max_cycle)
    lane_sops = {f"lane{lane}": sop_cycles(streams[f"lane{lane}"])[:frames] for lane in range(4)}
    lane_eops = {f"lane{lane}": eop_cycles(streams[f"lane{lane}"])[:frames] for lane in range(4)}
    opq_sops = sop_cycles(streams["opq"])[:frames]
    enough_frames = (
        len(opq_sops) >= frames
        and all(len(lane_sops[f"lane{lane}"]) >= frames for lane in range(4))
        and all(len(lane_eops[f"lane{lane}"]) >= frames for lane in range(4))
    )
    first_sops = [lane_sops[f"lane{lane}"][0] for lane in range(4)] if enough_frames else []
    first_eops = [lane_eops[f"lane{lane}"][0] for lane in range(4)] if enough_frames else []
    aligned_frames = [
        len({lane_sops[f"lane{lane}"][idx] for lane in range(4)}) == 1
        for idx in range(frames)
    ] if enough_frames else []
    lane0_spacing = [
        lane_sops["lane0"][idx + 1] - lane_sops["lane0"][idx]
        for idx in range(frames - 1)
    ] if enough_frames else []
    opq_delays = [
        opq_sops[idx] - lane_sops["lane0"][idx]
        for idx in range(frames)
    ] if enough_frames else []
    return {
        "lane_sops": lane_sops,
        "lane_eops": lane_eops,
        "opq_sops": opq_sops,
        "enough_frames": enough_frames,
        "aligned_frames": aligned_frames,
        "first_sop_aligned": enough_frames and len(set(first_sops)) == 1,
        "all_sop_aligned": enough_frames and all(aligned_frames),
        "lane0_spacing": lane0_spacing,
        "lane0_spacing_ok": enough_frames and all(delta == frame_slot_cycles for delta in lane0_spacing),
        "opq_after_first_ingress_commit": enough_frames and opq_sops[0] > max(first_eops),
        "opq_delays_from_lane0_sop": opq_delays,
        "first_opq_delay_from_lane0_sop": opq_delays[0] if opq_delays else None,
        "first_ingress_commit_cycle": max(first_eops) if first_eops else None,
    }


def main() -> int:
    args = parse_args()
    uvm_streams = extract_streams(args.uvm_vcd, "uvm")
    ghdl_streams = extract_streams(args.ghdl_vcd, "ghdl")
    ghdl_limited_streams = limit_cycles(ghdl_streams, args.ghdl_case_cycles)
    uvm = summarize(uvm_streams, args.frame_slot_cycles, args.frames)
    ghdl = summarize(
        ghdl_limited_streams,
        args.frame_slot_cycles,
        args.frames,
    )
    uvm_packet_integrity = packet_integrity(uvm_streams, args.frames, args.frame_ts_step)
    ghdl_packet_integrity = packet_integrity(ghdl_limited_streams, args.frames, args.frame_ts_step)
    same_delays = uvm["opq_delays_from_lane0_sop"] == ghdl["opq_delays_from_lane0_sop"]
    result = {
        "uvm": uvm,
        "ghdl": ghdl,
        "uvm_packet_integrity": uvm_packet_integrity,
        "ghdl_packet_integrity": ghdl_packet_integrity,
        "same_first_opq_delay": uvm["first_opq_delay_from_lane0_sop"] == ghdl["first_opq_delay_from_lane0_sop"],
        "same_opq_delays": same_delays,
        "pass": bool(
            uvm["enough_frames"]
            and ghdl["enough_frames"]
            and uvm["all_sop_aligned"]
            and ghdl["all_sop_aligned"]
            and uvm["lane0_spacing_ok"]
            and ghdl["lane0_spacing_ok"]
            and uvm["opq_after_first_ingress_commit"]
            and ghdl["opq_after_first_ingress_commit"]
            and uvm_packet_integrity["pass"]
            and ghdl_packet_integrity["pass"]
            and same_delays
        ),
    }
    text = json.dumps(result, indent=2) + "\n"
    if args.out is not None:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text, encoding="utf-8")
        print(f"wrote {args.out}")
    print(text, end="")
    return 0 if result["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
