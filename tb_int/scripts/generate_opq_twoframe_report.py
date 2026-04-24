#!/usr/bin/env python3
"""Generate a WaveDrom HTML report for a selected OPQ frame window.

This script consumes:
- a seam-only replay VCD from the UVM wrapper (`tb_top.*_if`)
- the replay reference bundle emitted by `tb_int/cases/basic/ref/run_basic_ref.py`

It publishes a static HTML page with three WaveDrom panels:
-- 4-lane ingress window for the selected frame window
-- merged OPQ egress window for the same frame window
- 256-bit PCIe app payload words covering those frames

The page is intended to be served from the existing local web server.
"""

from __future__ import annotations

import argparse
import html
import importlib.util
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


SWB_K285 = 0xBC
SWB_K284 = 0x9C
SWB_K237 = 0xF7
SWB_MUPIX_HEADER_ID = 0b111010
CHUNK_NAV_STEP_PX = 72
PANEL_CHUNK_SLOTS = {
    "ingress": 48,
    "egress": 48,
    "dma": 32,
}
MIN_PANEL_HSCALE = 2
MAX_PANEL_HSCALE = 6


@dataclass
class Beat:
    cycle: int
    time_ps: int
    data: int
    datak: int
    kind: str
    frame_id: int
    shd_ts: int | None = None
    hit_count: int | None = None
    hit_idx: int | None = None


@dataclass
class DmaWord:
    cycle: int
    time_ps: int
    data: int
    eoe: int
    word_idx: int
    slots: list[dict[str, Any]]


@dataclass
class PanelBundle:
    panel_id: str
    render_index: int
    base_hscale: int
    title: str
    subtitle: str
    extra_class: str
    chunks: list[dict[str, Any]]
    ledger_html: str
    full_detail: str


def load_vcd_module() -> Any:
    candidates = [
        Path.home() / ".codex/skills/wavedrom-viewer/vcd2wavedrom.py",
        Path.home() / ".claude/skills/wavedrom-viewer/vcd2wavedrom.py",
    ]
    for candidate in candidates:
        if candidate.exists():
            spec = importlib.util.spec_from_file_location("wavedrom_vcd", candidate)
            if spec and spec.loader:
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
                return module
    raise FileNotFoundError("Unable to locate wavedrom-viewer/vcd2wavedrom.py in ~/.codex or ~/.claude")


def bits_to_int(bits: str) -> int | None:
    lowered = bits.lower()
    if "x" in lowered or "z" in lowered:
        return None
    return int(lowered, 2)


def exact_signal_id(vcd: Any, full_path: str) -> str:
    for sid, sig in vcd.signals.items():
        if sig.full_path == full_path:
            return sid
    raise KeyError(f"Signal not found in VCD: {full_path}")


def matching_signal_ids(vcd: Any, full_path: str) -> list[str]:
    matches = [sid for sid, sig in vcd.signals.items() if sig.full_path == full_path]
    if not matches:
        raise KeyError(f"Signal not found in VCD: {full_path}")
    return matches


def signal_bits_at(vcd: Any, signal_ids: list[str], time_vcd: int) -> str:
    return "".join(vcd.get_value_at(signal_id, time_vcd) for signal_id in signal_ids)


def _extract_interface_stream(vcd: Any, edges: list[int], top_scope: str, prefix: str) -> list[dict[str, int]]:
    valid_id = exact_signal_id(vcd, f"{top_scope}.{prefix}.valid")
    data_id = exact_signal_id(vcd, f"{top_scope}.{prefix}.data")
    datak_id = exact_signal_id(vcd, f"{top_scope}.{prefix}.datak")

    rows: list[dict[str, int]] = []
    for cycle, time_vcd in enumerate(edges):
        valid = bits_to_int(vcd.get_value_at(valid_id, time_vcd))
        if valid == 1:
            data = bits_to_int(vcd.get_value_at(data_id, time_vcd))
            datak = bits_to_int(vcd.get_value_at(datak_id, time_vcd))
            if data is None or datak is None:
                raise ValueError(f"{prefix} produced X/Z during valid beat at cycle {cycle}")
            rows.append(
                {
                    "cycle": cycle,
                    "time_ps": int(round(time_vcd * vcd.timescale_ps)),
                    "data": data,
                    "datak": datak,
                }
            )
    return rows


def _extract_plain_ingress_stream(vcd: Any, edges: list[int], top_scope: str, lane: int) -> list[dict[str, int]]:
    valid_ids = matching_signal_ids(vcd, f"{top_scope}.feb_valid")
    data_ids = matching_signal_ids(vcd, f"{top_scope}.feb_data")
    datak_ids = matching_signal_ids(vcd, f"{top_scope}.feb_datak")

    rows: list[dict[str, int]] = []
    for cycle, time_vcd in enumerate(edges):
        valid_word = bits_to_int(signal_bits_at(vcd, valid_ids, time_vcd))
        data_word = bits_to_int(signal_bits_at(vcd, data_ids, time_vcd))
        datak_word = bits_to_int(signal_bits_at(vcd, datak_ids, time_vcd))
        if valid_word is None or data_word is None or datak_word is None:
            raise ValueError(f"Plain ingress produced X/Z at cycle {cycle}")
        if ((valid_word >> lane) & 0x1) == 1:
            rows.append(
                {
                    "cycle": cycle,
                    "time_ps": int(round(time_vcd * vcd.timescale_ps)),
                    "data": (data_word >> (lane * 32)) & 0xFFFF_FFFF,
                    "datak": (datak_word >> (lane * 4)) & 0xF,
                }
            )
    return rows


def _extract_plain_opq_stream(vcd: Any, edges: list[int], top_scope: str) -> list[dict[str, int]]:
    valid_ids = matching_signal_ids(vcd, f"{top_scope}.opq_valid")
    data_ids = matching_signal_ids(vcd, f"{top_scope}.opq_data")
    datak_ids = matching_signal_ids(vcd, f"{top_scope}.opq_datak")

    rows: list[dict[str, int]] = []
    for cycle, time_vcd in enumerate(edges):
        valid = bits_to_int(signal_bits_at(vcd, valid_ids, time_vcd))
        if valid == 1:
            data = bits_to_int(signal_bits_at(vcd, data_ids, time_vcd))
            datak = bits_to_int(signal_bits_at(vcd, datak_ids, time_vcd))
            if data is None or datak is None:
                raise ValueError(f"Plain OPQ stream produced X/Z at cycle {cycle}")
            rows.append(
                {
                    "cycle": cycle,
                    "time_ps": int(round(time_vcd * vcd.timescale_ps)),
                    "data": data,
                    "datak": datak,
                }
            )
    return rows


def extract_stream(
    vcd: Any,
    edges: list[int],
    top_scope: str,
    prefix: str,
    signal_layout: str = "interface",
    lane: int | None = None,
) -> list[dict[str, int]]:
    if signal_layout == "interface":
        return _extract_interface_stream(vcd, edges, top_scope, prefix)
    if signal_layout == "plain":
        if prefix.startswith("feb_if"):
            if lane is None:
                raise ValueError("plain signal layout requires an explicit ingress lane index")
            return _extract_plain_ingress_stream(vcd, edges, top_scope, lane)
        if prefix == "opq_if":
            return _extract_plain_opq_stream(vcd, edges, top_scope)
    raise ValueError(f"Unsupported signal layout {signal_layout!r} for prefix {prefix!r}")


def extract_dma(vcd: Any, edges: list[int], top_scope: str, signal_layout: str = "interface") -> list[dict[str, int]]:
    if signal_layout == "interface":
        wren_id = exact_signal_id(vcd, f"{top_scope}.dma_if.wren")
        data_id = exact_signal_id(vcd, f"{top_scope}.dma_if.data")
        eoe_id = exact_signal_id(vcd, f"{top_scope}.dma_if.end_of_event")
    elif signal_layout == "plain":
        wren_ids = matching_signal_ids(vcd, f"{top_scope}.dma_wren")
        data_ids = matching_signal_ids(vcd, f"{top_scope}.dma_data")
        eoe_ids = matching_signal_ids(vcd, f"{top_scope}.end_of_event")
    else:
        raise ValueError(f"Unsupported signal layout {signal_layout!r} for DMA extraction")

    rows: list[dict[str, int]] = []
    for cycle, time_vcd in enumerate(edges):
        if signal_layout == "interface":
            wren = bits_to_int(vcd.get_value_at(wren_id, time_vcd))
        else:
            wren = bits_to_int(signal_bits_at(vcd, wren_ids, time_vcd))
        if wren == 1:
            if signal_layout == "interface":
                data = bits_to_int(vcd.get_value_at(data_id, time_vcd))
                eoe = bits_to_int(vcd.get_value_at(eoe_id, time_vcd))
            else:
                data = bits_to_int(signal_bits_at(vcd, data_ids, time_vcd))
                eoe = bits_to_int(signal_bits_at(vcd, eoe_ids, time_vcd))
            if data is None or eoe is None:
                raise ValueError(f"dma_if produced X/Z during wren at cycle {cycle}")
            rows.append(
                {
                    "cycle": cycle,
                    "time_ps": int(round(time_vcd * vcd.timescale_ps)),
                    "data": data,
                    "eoe": eoe,
                }
            )
    return rows


def parse_framed_stream(rows: list[dict[str, int]]) -> list[list[Beat]]:
    frames: list[list[Beat]] = []
    idx = 0

    while idx < len(rows):
        frame_id = len(frames)
        sop = rows[idx]
        data = sop["data"]
        datak = sop["datak"]
        if not (datak == 0x1 and (data & 0xFF) == SWB_K285 and ((data >> 26) & 0x3F) == SWB_MUPIX_HEADER_ID):
            raise ValueError(
                f"Expected SOP at row {idx}, got data=0x{data:08X} datak=0x{datak:X}"
            )

        frame: list[Beat] = [
            Beat(**sop, kind="sop", frame_id=frame_id),
            Beat(**rows[idx + 1], kind="ts_high", frame_id=frame_id),
            Beat(**rows[idx + 2], kind="ts_low_pkg", frame_id=frame_id),
            Beat(**rows[idx + 3], kind="debug0", frame_id=frame_id),
            Beat(**rows[idx + 4], kind="debug1", frame_id=frame_id),
        ]
        idx += 5

        while idx < len(rows):
            beat = rows[idx]
            data = beat["data"]
            datak = beat["datak"]
            if datak == 0x1 and (data & 0xFF) == SWB_K284:
                frame.append(Beat(**beat, kind="eop", frame_id=frame_id))
                idx += 1
                break

            if not (datak == 0x1 and (data & 0xFF) == SWB_K237):
                raise ValueError(
                    f"Expected subheader/EOP at row {idx}, got data=0x{data:08X} datak=0x{datak:X}"
                )

            shd_ts = (data >> 24) & 0xFF
            hit_count = (data >> 8) & 0xFF
            frame.append(
                Beat(
                    **beat,
                    kind="subheader",
                    frame_id=frame_id,
                    shd_ts=shd_ts,
                    hit_count=hit_count,
                )
            )
            idx += 1

            for hit_idx in range(hit_count):
                hit = rows[idx]
                if hit["datak"] != 0:
                    raise ValueError(
                        f"Expected hit payload at row {idx}, got data=0x{hit['data']:08X} datak=0x{hit['datak']:X}"
                    )
                frame.append(
                    Beat(
                        **hit,
                        kind="hit",
                        frame_id=frame_id,
                        shd_ts=shd_ts,
                        hit_idx=hit_idx,
                    )
                )
                idx += 1

        frames.append(frame)

    return frames


def hex32(value: int) -> str:
    return f"{value:08X}"


def hex64(value: int) -> str:
    return f"{value:016X}"


def hex256(value: int) -> str:
    return f"{value:064X}"


def time_ns(time_ps: int) -> float:
    return time_ps / 1000.0


def fmt_time(time_ps_value: int) -> str:
    return f"{time_ns(time_ps_value):.3f} ns"


def decode_debug0(data: int) -> str:
    return f"subheaders={((data >> 16) & 0x7FFF)} hits={(data & 0xFFFF)}"


def decode_hit32(data: int) -> str:
    lane_field = (data >> 22) & 0xF
    col = (data >> 14) & 0xFF
    row = (data >> 6) & 0xFF
    pri = (data >> 1) & 0x1F
    tail = (data >> 28) & 0xF
    return f"lane={lane_field} col={col} row={row} pri={pri} tail=0x{tail:X}"


def decode_dma_hit64(data: int) -> str:
    col = (data >> 50) & 0xFF
    row = (data >> 42) & 0xFF
    pri = (data >> 37) & 0x1F
    ts = data & ((1 << 37) - 1)
    return f"col={col} row={row} pri={pri} ts=0x{ts:010X}"


def short_label(beat: Beat) -> str:
    if beat.kind == "sop":
        feb_id = (beat.data >> 8) & 0xFFFF
        return f"HDR {feb_id:04X}"
    if beat.kind == "ts_high":
        return f"TH {hex32(beat.data)}"
    if beat.kind == "ts_low_pkg":
        ts_low = (beat.data >> 16) & 0xFFFF
        pkg = beat.data & 0xFFFF
        return f"TL {ts_low:04X}/{pkg:04X}"
    if beat.kind == "debug0":
        return f"D0 {((beat.data >> 16) & 0x7FFF)}/{(beat.data & 0xFFFF)}"
    if beat.kind == "debug1":
        return f"D1 {hex32(beat.data)}"
    if beat.kind == "subheader":
        return f"S{beat.shd_ts:02X}/{beat.hit_count}"
    if beat.kind == "hit":
        return hex32(beat.data)
    if beat.kind == "eop":
        return "TRL"
    return hex32(beat.data)


def wave_char_for_kind(kind: str) -> str:
    if kind in {"sop", "ts_high", "ts_low_pkg", "debug0", "debug1", "eop"}:
        return "5"
    if kind == "subheader":
        return "6"
    if kind == "hit":
        return "7"
    return "="


def build_axis(segments: list[tuple[int, int]]) -> list[Any]:
    axis: list[Any] = []
    for seg_idx, (start, end) in enumerate(segments):
        if seg_idx != 0:
            prev_end = segments[seg_idx - 1][1]
            gap = start - prev_end - 1
            axis.append(
                {
                    "gap": True,
                    "label": f"// {gap} cyc / {(gap * 4.0) / 1000.0:.3f} us",
                }
            )
        axis.extend(range(start, end + 1))
    return axis


def build_clock_wave(axis: list[Any]) -> dict[str, Any]:
    cycles = sum(1 for item in axis if not isinstance(item, dict))
    rendered = len(axis)
    return {
        "name": "clk250",
        "wave": "P" + "." * max(0, rendered - 1),
        "periods": cycles,
    }


def build_bit_row(name: str, axis: list[Any], active_cycles: set[int]) -> dict[str, Any]:
    wave = []
    prev = None
    for item in axis:
        val = "0"
        if not isinstance(item, dict) and item in active_cycles:
            val = "1"
        if val == prev:
            wave.append(".")
        else:
            wave.append(val)
        prev = val
    return {"name": name, "wave": "".join(wave)}


def build_data_row(name: str, axis: list[Any], beat_by_cycle: dict[int, Beat]) -> dict[str, Any]:
    wave = []
    data = []
    prev = None
    for item in axis:
        if isinstance(item, dict):
            token = "3"
            label = item["label"]
        else:
            beat = beat_by_cycle.get(item)
            if beat is None:
                token = "x"
                label = None
            else:
                token = wave_char_for_kind(beat.kind)
                label = short_label(beat)
        if token == prev and token in {"0", "1", "x", "z"}:
            wave.append(".")
        else:
            wave.append(token)
            if label is not None and token not in {"0", "1", "x", "z", "."}:
                data.append(label)
        prev = token
    row: dict[str, Any] = {"name": name, "wave": "".join(wave)}
    if data:
        row["data"] = data
    return row


def html_table(headers: list[str], rows: list[list[str]]) -> str:
    head_html = "".join(f"<th>{html.escape(h)}</th>" for h in headers)
    body_parts = []
    for row in rows:
        body_parts.append(
            "<tr>" + "".join(f"<td>{html.escape(cell)}</td>" for cell in row) + "</tr>"
        )
    body_html = "\n".join(body_parts)
    return (
        "<div class=\"ledger-wrap\"><table class=\"ledger\">"
        f"<thead><tr>{head_html}</tr></thead><tbody>{body_html}</tbody></table></div>"
    )


def write_text(path: Path, text: str) -> str:
    path.write_text(text)
    return path.name


def write_json(path: Path, payload: Any) -> str:
    path.write_text(json.dumps(payload, separators=(",", ":")))
    return path.name


def chunk_bounds(axis_len: int, chunk_slots: int) -> list[tuple[int, int]]:
    return [
        (start, min(axis_len, start + chunk_slots))
        for start in range(0, axis_len, chunk_slots)
    ]


def axis_cycle_span(axis: list[Any]) -> tuple[int | None, int | None]:
    cycles = [item for item in axis if not isinstance(item, dict)]
    if not cycles:
        return (None, None)
    return (cycles[0], cycles[-1])


def axis_gap_labels(axis: list[Any]) -> list[str]:
    return [item["label"] for item in axis if isinstance(item, dict)]


def chunk_nav_label(cycle_start: int | None, slot_start: int) -> str:
    if cycle_start is not None:
        return f"C{cycle_start}"
    return f"S{slot_start}"


def chunk_detail_text(
    slot_start: int,
    slot_stop: int,
    cycle_start: int | None,
    cycle_end: int | None,
    gap_labels: list[str],
) -> str:
    parts = [f"slots {slot_start}..{slot_stop - 1}"]
    if cycle_start is not None and cycle_end is not None:
        parts.append(f"cycles {cycle_start}..{cycle_end}")
        parts.append(f"{2 + 4 * cycle_start:.3f}..{2 + 4 * cycle_end:.3f} ns")
    if gap_labels:
        parts.append("; ".join(gap_labels))
    return " | ".join(parts)


def chunk_marker_stride(chunk_count: int) -> int:
    return max(1, (chunk_count + 11) // 12)


def chunk_record(
    src_name: str,
    slot_start: int,
    slot_stop: int,
    axis_slice: list[Any],
) -> dict[str, Any]:
    cycle_start, cycle_end = axis_cycle_span(axis_slice)
    return {
        "src": src_name,
        "label": chunk_nav_label(cycle_start, slot_start),
        "detail": chunk_detail_text(
            slot_start,
            slot_stop,
            cycle_start,
            cycle_end,
            axis_gap_labels(axis_slice),
        ),
    }


def ledger_placeholder(summary_text: str, src_name: str) -> str:
    return (
        f'<details class="ledger-box lazy-ledger" data-ledger-src="./{html.escape(src_name)}">'
        f"<summary>{html.escape(summary_text)}</summary>"
        '<div class="ledger-slot" data-ledger-slot>'
        f'<div class="ledger-status">Ledger is loaded on demand from <code>{html.escape(src_name)}</code>.</div>'
        "</div></details>"
    )


def ingress_table_rows(frames: list[list[Beat]]) -> list[list[str]]:
    rows: list[list[str]] = []
    for beat in [b for frame in frames for b in frame]:
        decode = ""
        if beat.kind == "sop":
            decode = f"feb_id=0x{((beat.data >> 8) & 0xFFFF):04X}"
        elif beat.kind == "ts_high":
            decode = f"ts_high=0x{beat.data:08X}"
        elif beat.kind == "ts_low_pkg":
            decode = f"ts_low=0x{((beat.data >> 16) & 0xFFFF):04X} pkg=0x{(beat.data & 0xFFFF):04X}"
        elif beat.kind == "debug0":
            decode = decode_debug0(beat.data)
        elif beat.kind == "debug1":
            decode = f"debug1=0x{beat.data:08X}"
        elif beat.kind == "subheader":
            decode = f"shd_ts=0x{beat.shd_ts:02X} hit_count={beat.hit_count}"
        elif beat.kind == "hit":
            decode = decode_hit32(beat.data)
        elif beat.kind == "eop":
            decode = "K28.4 trailer"
        rows.append(
            [
                f"F{beat.frame_id}",
                str(beat.cycle),
                fmt_time(beat.time_ps),
                beat.kind,
                f"0x{beat.datak:X}",
                f"0x{beat.data:08X}",
                decode,
            ]
        )
    return rows


def build_ingress_panel(
    lane_frames: dict[int, list[list[Beat]]],
    out_dir: Path,
    stem: str,
) -> tuple[PanelBundle, tuple[int, int]]:
    start_cycle = min(frame[0].cycle for frames in lane_frames.values() for frame in frames)
    end_cycle = max(frame[-1].cycle for frames in lane_frames.values() for frame in frames)
    axis = build_axis([(start_cycle, end_cycle)])
    table_blocks: list[str] = []
    total_rows = 0
    lane_beat_maps: dict[int, dict[int, Beat]] = {}
    lane_active_cycles: dict[int, set[int]] = {}
    lane_datak_cycles: dict[int, set[int]] = {}
    for lane in range(4):
        frames = lane_frames[lane]
        lane_rows = ingress_table_rows(frames)
        total_rows += len(lane_rows)
        beats = [beat for frame in frames for beat in frame]
        beat_map = {beat.cycle: beat for beat in beats}
        lane_beat_maps[lane] = beat_map
        lane_active_cycles[lane] = set(beat_map)
        lane_datak_cycles[lane] = {beat.cycle for beat in beats if beat.datak != 0}
        lane_src = write_text(
            out_dir / f"{stem}.ledger.ingress.lane{lane}.html",
            html_table(
                ["frame", "cycle", "time", "kind", "datak", "data", "decode"],
                lane_rows,
            ),
        )
        table_blocks.append(
            ledger_placeholder(
                f"Lane {lane} decoded ledger ({len(lane_rows)} rows)",
                lane_src,
            )
        )
    ingress_src = write_text(
        out_dir / f"{stem}.ledger.ingress.html",
        "\n".join(table_blocks),
    )
    chunk_records: list[dict[str, Any]] = []
    chunk_count = len(chunk_bounds(len(axis), PANEL_CHUNK_SLOTS["ingress"]))
    for chunk_idx, (slot_start, slot_stop) in enumerate(chunk_bounds(len(axis), PANEL_CHUNK_SLOTS["ingress"])):
        axis_slice = axis[slot_start:slot_stop]
        signal: list[Any] = [build_clock_wave(axis_slice), {}]
        for lane in range(4):
            signal.append(
                [
                    f"Lane {lane}",
                    build_bit_row("valid", axis_slice, lane_active_cycles[lane]),
                    build_bit_row("datak!=0", axis_slice, lane_datak_cycles[lane]),
                    build_data_row("data[31:0]", axis_slice, lane_beat_maps[lane]),
                ]
            )
            signal.append({})

        chunk_cycle_start, chunk_cycle_end = axis_cycle_span(axis_slice)
        chunk_panel = {
            "signal": signal,
            "config": {"hscale": 3},
            "head": {
                "text": (
                    f"Ingress to OPQ chunk {chunk_idx + 1}/{chunk_count}: "
                    f"lanes 0..3, cycles {chunk_cycle_start}..{chunk_cycle_end}"
                ),
                "tick": 0,
            },
            "foot": {
                "text": (
                    "Absolute axis: C0 = first rising edge at 2.000 ns, "
                    f"chunk window = {chunk_cycle_start}..{chunk_cycle_end} cycles, "
                    f"{2 + 4 * chunk_cycle_start:.3f}..{2 + 4 * chunk_cycle_end:.3f} ns"
                )
            },
        }
        chunk_src = write_json(
            out_dir / f"{stem}.panel.ingress.chunk{chunk_idx:03d}.json",
            chunk_panel,
        )
        chunk_records.append(chunk_record(chunk_src, slot_start, slot_stop, axis_slice))

    bundle = PanelBundle(
        panel_id="ingress",
        render_index=0,
        base_hscale=3,
        title="Ingress Window",
        subtitle=(
            "4 FEB lanes into the OPQ; selected frame window. "
            "Only the current chunk is rendered. Scroll the timeline strip to move through the full window."
        ),
        extra_class="ingress",
        chunks=chunk_records,
        ledger_html=ledger_placeholder(f"Decoded ledger ({total_rows} rows)", ingress_src),
        full_detail=(
            "Absolute axis: C0 = first rising edge at 2.000 ns, "
            f"full window = {start_cycle}..{end_cycle} cycles, "
            f"{2 + 4 * start_cycle:.3f}..{2 + 4 * end_cycle:.3f} ns"
        ),
    )
    return (bundle, (start_cycle, end_cycle))


def build_egress_panel(
    frames: list[list[Beat]],
    out_dir: Path,
    stem: str,
) -> tuple[PanelBundle, list[tuple[int, int]]]:
    segments = [(frame[0].cycle, frame[-1].cycle) for frame in frames]
    axis = build_axis(segments)
    beats = [beat for frame in frames for beat in frame]
    beat_map = {beat.cycle: beat for beat in beats}
    active_cycles = set(beat_map)
    datak_cycles = {beat.cycle for beat in beats if beat.datak != 0}

    table_rows = ingress_table_rows(frames)
    table_html = html_table(
        ["frame", "cycle", "time", "kind", "datak", "data", "decode"],
        table_rows,
    )
    egress_src = write_text(out_dir / f"{stem}.ledger.egress.html", table_html)
    chunk_records: list[dict[str, Any]] = []
    chunk_count = len(chunk_bounds(len(axis), PANEL_CHUNK_SLOTS["egress"]))
    for chunk_idx, (slot_start, slot_stop) in enumerate(chunk_bounds(len(axis), PANEL_CHUNK_SLOTS["egress"])):
        axis_slice = axis[slot_start:slot_stop]
        data_row = build_data_row("data[31:0]", axis_slice, beat_map)
        note_row = {
            "name": "gap-note",
            "wave": "".join("3" if isinstance(item, dict) else "x" for item in axis_slice),
            "data": [item["label"] for item in axis_slice if isinstance(item, dict)],
        }
        chunk_cycle_start, chunk_cycle_end = axis_cycle_span(axis_slice)
        chunk_panel = {
            "signal": [
                build_clock_wave(axis_slice),
                {},
                [
                    "Merged OPQ Egress",
                    build_bit_row("valid", axis_slice, active_cycles),
                    build_bit_row("datak!=0", axis_slice, datak_cycles),
                    data_row,
                    note_row,
                ],
            ],
            "config": {"hscale": 3},
            "head": {
                "text": (
                    f"Merged OPQ egress chunk {chunk_idx + 1}/{chunk_count}: "
                    f"cycles {chunk_cycle_start}..{chunk_cycle_end}"
                ),
                "tick": 0,
            },
            "foot": {
                "text": (
                    f"Absolute axis: chunk {chunk_cycle_start}..{chunk_cycle_end} cycles, "
                    f"{2 + 4 * chunk_cycle_start:.3f}..{2 + 4 * chunk_cycle_end:.3f} ns"
                )
            },
        }
        chunk_src = write_json(
            out_dir / f"{stem}.panel.egress.chunk{chunk_idx:03d}.json",
            chunk_panel,
        )
        chunk_records.append(chunk_record(chunk_src, slot_start, slot_stop, axis_slice))

    segment_labels = [
        f"seg{idx} {2 + 4 * start:.3f}..{2 + 4 * stop:.3f} ns"
        for idx, (start, stop) in enumerate(segments)
    ]

    bundle = PanelBundle(
        panel_id="egress",
        render_index=1,
        base_hscale=3,
        title="Merged OPQ Egress",
        subtitle=(
            "Merged OPQ output for the selected frame window. "
            "The long idle region remains represented by // markers, but only the visible chunk is rendered."
        ),
        extra_class="egress",
        chunks=chunk_records,
        ledger_html=ledger_placeholder(f"Decoded ledger ({len(table_rows)} rows)", egress_src),
        full_detail=f"Absolute axis: {', '.join(segment_labels)}",
    )
    return (bundle, segments)


def build_frame_prefix_map(plan_json: dict[str, Any]) -> dict[int, int]:
    prefix_map: dict[int, int] = {}
    for lane_frames in plan_json["frames_by_lane"]:
        for frame in lane_frames:
            frame_id = int(frame["frame_id"])
            ts_high_word = int(frame["ts_high_word"], 16)
            ts_low_word = int(frame["ts_low_word"], 16)
            prefix = ((ts_high_word & ((1 << 21) - 1)) << 5) | ((ts_low_word >> 11) & 0x1F)
            prefix_map[prefix] = frame_id
    return prefix_map


def annotate_dma_payload(
    actual_dma: list[dict[str, int]],
    payload_word_count: int,
    frame_prefix_map: dict[int, int],
) -> list[dict[str, Any]]:
    packs: list[dict[str, Any]] = []
    for word_idx, actual in enumerate(actual_dma[:payload_word_count]):
        packed = actual["data"]
        slots: list[dict[str, Any]] = []
        for slot in range(4):
            data64 = (packed >> (64 * slot)) & ((1 << 64) - 1)
            prefix = (data64 >> 11) & ((1 << 26) - 1)
            frame_id = frame_prefix_map.get(prefix, -1)
            slots.append(
                {
                    "frame_id": frame_id,
                    "data64": data64,
                    "prefix": prefix,
                }
            )
        packs.append({"word_idx": word_idx, "data": packed, "slots": slots})
    return packs


def build_dma_panel(
    actual_dma: list[dict[str, int]],
    payload_word_count: int,
    frame_prefix_map: dict[int, int],
    frame_start: int,
    frame_count: int,
    out_dir: Path,
    stem: str,
) -> tuple[PanelBundle, tuple[int, int]]:
    if len(actual_dma) < payload_word_count:
        raise ValueError("Actual DMA stream is shorter than expected payload")

    actual_payload = actual_dma[:payload_word_count]
    expected_packs = annotate_dma_payload(actual_dma, payload_word_count, frame_prefix_map)

    selected_frames = set(range(frame_start, frame_start + frame_count))
    selected_words = [
        pack for pack in expected_packs if any(slot["frame_id"] in selected_frames for slot in pack["slots"])
    ]
    if not selected_words:
        table_html = html_table(
            ["word", "cycle", "time", "eoe", "raw256", "decoded slots"],
            [],
        )
        dma_src = write_text(out_dir / f"{stem}.ledger.dma.html", table_html)
        empty_chunk = {
            "signal": [
                {"name": "clk250", "wave": "P"},
                {},
                [
                    "PCIe App 256-bit Payload",
                    {"name": "wren", "wave": "0"},
                    {"name": "end_of_event", "wave": "0"},
                    {"name": "data[255:0]", "wave": "x", "data": ["no payload words in selected frames"]},
                ],
            ],
            "config": {"hscale": 4},
            "head": {
                "text": "PCIe app payload chunk 1/1: selected frames carry zero payload words",
                "tick": 0,
            },
            "foot": {
                "text": "No DMA payload words are expected; only the fixed padding tail exists and is intentionally excluded.",
            },
        }
        chunk_src = write_json(
            out_dir / f"{stem}.panel.dma.chunk000.json",
            empty_chunk,
        )
        bundle = PanelBundle(
            panel_id="dma",
            render_index=2,
            base_hscale=4,
            title="PCIe App Payload",
            subtitle="Selected frames carry zero DMA payload words on the shared axis.",
            extra_class="dma",
            chunks=[
                {
                    "src": chunk_src,
                    "label": "S0",
                    "detail": "selected frames carry zero payload words",
                }
            ],
            ledger_html=ledger_placeholder("Decoded ledger (0 rows)", dma_src),
            full_detail=(
                "Selected frames carry zero payload words. The fixed 128-word DMA padding tail is present "
                "in the simulation but is intentionally excluded from the payload correlation panel."
            ),
        )
        return (bundle, (0, 0))

    first_idx = selected_words[0]["word_idx"]
    last_idx = selected_words[-1]["word_idx"]

    words: list[DmaWord] = []
    for pack in expected_packs[first_idx : last_idx + 1]:
        actual = actual_payload[pack["word_idx"]]
        words.append(
            DmaWord(
                cycle=actual["cycle"],
                time_ps=actual["time_ps"],
                data=actual["data"],
                eoe=actual["eoe"],
                word_idx=pack["word_idx"],
                slots=pack["slots"],
            )
        )

    start_cycle = words[0].cycle
    end_cycle = words[-1].cycle
    axis = build_axis([(start_cycle, end_cycle)])
    word_map = {word.cycle: word for word in words}
    active_cycles = set(word_map)
    eoe_cycles = {word.cycle for word in words if word.eoe}

    table_rows: list[list[str]] = []
    for word in words:
        slot_texts = []
        for slot_idx, hit in enumerate(word.slots):
            slot_texts.append(
                f"s{slot_idx}: F{hit['frame_id']} raw64=0x{hit['data64']:016X} {decode_dma_hit64(hit['data64'])}"
            )
        table_rows.append(
            [
                f"W{word.word_idx:04d}",
                str(word.cycle),
                fmt_time(word.time_ps),
                f"{word.eoe}",
                f"0x{word.data:064X}",
                " | ".join(slot_texts),
            ]
        )
    table_html = html_table(
        ["word", "cycle", "time", "eoe", "raw256", "decoded slots"],
        table_rows,
    )
    dma_src = write_text(out_dir / f"{stem}.ledger.dma.html", table_html)
    chunk_records: list[dict[str, Any]] = []
    chunk_count = len(chunk_bounds(len(axis), PANEL_CHUNK_SLOTS["dma"]))
    for chunk_idx, (slot_start, slot_stop) in enumerate(chunk_bounds(len(axis), PANEL_CHUNK_SLOTS["dma"])):
        axis_slice = axis[slot_start:slot_stop]
        raw_row = {"name": "data[255:0]", "wave": "", "data": []}
        slot_rows = [{"name": f"slot{slot}", "wave": "", "data": []} for slot in range(4)]
        prev_raw = None
        prev_slots = [None, None, None, None]
        for item in axis_slice:
            if isinstance(item, dict):
                raw_row["wave"] += "3"
                raw_row["data"].append(item["label"])
                for slot_row in slot_rows:
                    slot_row["wave"] += "3"
                    slot_row["data"].append(item["label"])
                prev_raw = "3"
                prev_slots = ["3", "3", "3", "3"]
                continue

            word = word_map.get(item)
            if word is None:
                token = "x"
                raw_row["wave"] += "." if token == prev_raw and token in {"0", "1", "x"} else token
                prev_raw = token
                for slot, slot_row in enumerate(slot_rows):
                    slot_row["wave"] += "." if token == prev_slots[slot] and token in {"0", "1", "x"} else token
                    prev_slots[slot] = token
                continue

            raw_row["wave"] += "7"
            raw_row["data"].append(f"W{word.word_idx:04d}")
            prev_raw = "7"
            for slot, hit in enumerate(word.slots):
                frame_id = hit["frame_id"]
                slot_rows[slot]["wave"] += "7"
                slot_rows[slot]["data"].append(
                    f"F{frame_id} c{(hit['data64'] >> 50) & 0xFF} r{(hit['data64'] >> 42) & 0xFF} p{(hit['data64'] >> 37) & 0x1F}"
                )
                prev_slots[slot] = "7"

        chunk_cycle_start, chunk_cycle_end = axis_cycle_span(axis_slice)
        chunk_panel = {
            "signal": [
                build_clock_wave(axis_slice),
                {},
                [
                    "PCIe App 256-bit Payload",
                    build_bit_row("wren", axis_slice, active_cycles),
                    build_bit_row("end_of_event", axis_slice, eoe_cycles),
                    raw_row,
                    *slot_rows,
                ],
            ],
            "config": {"hscale": 4},
            "head": {
                "text": (
                    f"PCIe app payload chunk {chunk_idx + 1}/{chunk_count}: "
                    f"cycles {chunk_cycle_start}..{chunk_cycle_end}"
                ),
                "tick": 0,
            },
            "foot": {
                "text": (
                    f"Absolute axis: chunk {chunk_cycle_start}..{chunk_cycle_end} cycles, "
                    f"{2 + 4 * chunk_cycle_start:.3f}..{2 + 4 * chunk_cycle_end:.3f} ns"
                )
            },
        }
        chunk_src = write_json(
            out_dir / f"{stem}.panel.dma.chunk{chunk_idx:03d}.json",
            chunk_panel,
        )
        chunk_records.append(chunk_record(chunk_src, slot_start, slot_stop, axis_slice))

    bundle = PanelBundle(
        panel_id="dma",
        render_index=2,
        base_hscale=4,
        title="PCIe App Payload",
        subtitle=(
            "256-bit PCIe app payload words covering the same frame window. "
            "Only the visible chunk is rendered so the browser does not build the full million-pixel-wide SVG."
        ),
        extra_class="dma",
        chunks=chunk_records,
        ledger_html=ledger_placeholder(f"Decoded ledger ({len(table_rows)} rows)", dma_src),
        full_detail=(
            f"Absolute axis: cycles {start_cycle}..{end_cycle}, "
            f"{2 + 4 * start_cycle:.3f}..{2 + 4 * end_cycle:.3f} ns; "
            f"payload window contains {len(words)} consecutive 256-bit writes"
        ),
    )
    return (bundle, (start_cycle, end_cycle))


def panel_block(panel: PanelBundle) -> str:
    marker_stride = chunk_marker_stride(len(panel.chunks))
    markers = []
    for chunk_idx, chunk in enumerate(panel.chunks):
        marker_text = ""
        if chunk_idx == 0 or chunk_idx == len(panel.chunks) - 1 or chunk_idx % marker_stride == 0:
            marker_text = chunk["label"]
        markers.append(
            f'<button class="chunk-stop{" major" if marker_text else ""}" '
            f'type="button" '
            f'data-panel-id="{html.escape(panel.panel_id)}" '
            f'data-chunk-index="{chunk_idx}" '
            f'style="left:{chunk_idx * CHUNK_NAV_STEP_PX}px" '
            f'title="{html.escape(chunk["detail"])}">'
            f"<span>{html.escape(marker_text)}</span>"
            "</button>"
        )
    track_width = max(len(panel.chunks) * CHUNK_NAV_STEP_PX, CHUNK_NAV_STEP_PX)
    return f"""
<section class="panel {panel.extra_class}" data-panel-id="{html.escape(panel.panel_id)}">
  <div class="panel-head">
    <h2>{html.escape(panel.title)}</h2>
    <p>{html.escape(panel.subtitle)}</p>
    <p class="panel-note">{html.escape(panel.full_detail)}</p>
  </div>
  <div class="chunk-toolbar">
    <button class="chunk-btn" type="button" data-panel-prev="{html.escape(panel.panel_id)}">Prev</button>
    <div class="chunk-status" data-panel-status="{html.escape(panel.panel_id)}">Loading first chunk...</div>
    <div class="zoom-tools">
      <button class="chunk-btn" type="button" data-panel-zoom-out="{html.escape(panel.panel_id)}">Zoom Out</button>
      <button class="chunk-btn" type="button" data-panel-zoom-reset="{html.escape(panel.panel_id)}">Reset</button>
      <button class="chunk-btn" type="button" data-panel-zoom-in="{html.escape(panel.panel_id)}">Zoom In</button>
      <div class="zoom-status" data-panel-zoom-status="{html.escape(panel.panel_id)}">Scale {panel.base_hscale}</div>
    </div>
    <button class="chunk-btn" type="button" data-panel-next="{html.escape(panel.panel_id)}">Next</button>
  </div>
  <div class="wave-scroll" data-wave-scroll="{html.escape(panel.panel_id)}">
    <div id="WaveDrom_Display_{panel.render_index}" class="wave-display">
      <div class="wave-render-status">Loading first chunk...</div>
    </div>
  </div>
  <div class="chunk-hint">
    Scroll the timeline strip below to move through the full window. Only the selected chunk is rendered.
  </div>
  <div class="chunk-strip-shell">
    <div class="chunk-strip" data-panel-strip="{html.escape(panel.panel_id)}">
      <div class="chunk-track" style="width:{track_width}px">
        {''.join(markers)}
      </div>
    </div>
  </div>
  {panel.ledger_html}
</section>
"""


def render_page(
    out_html: Path,
    summary: dict[str, Any],
    panels: list[PanelBundle],
) -> None:
    frame_slot_note = ""
    if summary.get("frame_slot_cycles", 0):
        frame_slot_note = (
            f" Waveform evidence uses aligned frame slots: SOP-to-SOP = "
            f"{summary['frame_slot_cycles']} cycles ({summary['frame_slot_cycles'] * 4} ns)."
        )
    panel_meta = {
        panel.panel_id: {
            "panel_id": panel.panel_id,
            "render_index": panel.render_index,
            "base_hscale": panel.base_hscale,
            "chunk_count": len(panel.chunks),
            "nav_step_px": CHUNK_NAV_STEP_PX,
            "chunks": panel.chunks,
        }
        for panel in panels
    }

    html_text = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>MuSiP OPQ Frame-Window Wave Report</title>
  <script src="./default.js"></script>
  <script src="./wavedrom.min.js"></script>
  <style>
    :root {{
      --bg: #06070a;
      --panel: #12161f;
      --border: #242a37;
      --text: #d8deea;
      --muted: #9aa5bb;
      --accent: #65a7ff;
      --mono: "IBM Plex Mono", "Consolas", monospace;
      --sans: system-ui, sans-serif;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      background: radial-gradient(circle at top left, #13233d 0%, var(--bg) 45%);
      color: var(--text);
      font-family: var(--sans);
      line-height: 1.45;
    }}
    main {{
      max-width: 1800px;
      margin: 0 auto;
      padding: 24px 24px 56px;
    }}
    .hero {{
      background: rgba(18, 22, 31, 0.9);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 20px 22px;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.25);
      margin-bottom: 22px;
    }}
    .hero h1 {{
      margin: 0 0 8px;
      font-size: 28px;
    }}
    .hero p {{
      margin: 6px 0;
      color: var(--muted);
    }}
    .meta {{
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 10px 20px;
      margin-top: 14px;
      font-family: var(--mono);
      font-size: 13px;
    }}
    .meta div {{
      background: rgba(255, 255, 255, 0.02);
      border: 1px solid rgba(255, 255, 255, 0.04);
      border-radius: 10px;
      padding: 8px 10px;
    }}
    .meta strong {{
      color: var(--accent);
      display: inline-block;
      min-width: 110px;
    }}
    .grid {{
      display: grid;
      grid-template-columns: 1fr;
      gap: 22px;
    }}
    .panel {{
      background: rgba(18, 22, 31, 0.95);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 16px 18px 18px;
      box-shadow: 0 20px 50px rgba(0, 0, 0, 0.2);
    }}
    .panel.egress {{
      margin-left: 6vw;
      max-width: calc(100% - 6vw);
    }}
    .panel.dma {{
      margin-left: 12vw;
      max-width: calc(100% - 12vw);
    }}
    .panel-head h2 {{
      margin: 0;
      font-size: 22px;
    }}
    .panel-head p {{
      margin: 6px 0 14px;
      color: var(--muted);
      font-family: var(--mono);
      font-size: 13px;
    }}
    .wave-scroll {{
      overflow-x: auto;
      padding: 14px;
      border-radius: 12px;
      background: #ffffff;
      box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.06);
    }}
    .wave-display {{
      display: inline-block;
      min-width: 100%;
    }}
    .wave-scroll svg {{
      display: block;
    }}
    .wave-render-status {{
      min-height: 160px;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #4a5870;
      font-family: var(--mono);
      font-size: 12px;
    }}
    .chunk-toolbar {{
      display: flex;
      align-items: center;
      gap: 10px;
      margin: 14px 0 10px;
    }}
    .chunk-btn {{
      font-family: var(--mono);
      font-size: 12px;
      padding: 6px 10px;
      border-radius: 8px;
      border: 1px solid var(--border);
      background: #171d29;
      color: var(--text);
      cursor: pointer;
    }}
    .chunk-btn:disabled {{
      opacity: 0.45;
      cursor: default;
    }}
    .chunk-status {{
      min-height: 20px;
      font-family: var(--mono);
      font-size: 12px;
      color: var(--muted);
      flex: 1;
    }}
    .zoom-tools {{
      display: flex;
      align-items: center;
      gap: 8px;
      flex-wrap: wrap;
    }}
    .zoom-status {{
      min-width: 82px;
      text-align: right;
      font-family: var(--mono);
      font-size: 12px;
      color: var(--muted);
    }}
    .chunk-hint {{
      margin-top: 12px;
      font-family: var(--mono);
      font-size: 12px;
      color: var(--muted);
    }}
    .chunk-strip-shell {{
      margin-top: 10px;
      border: 1px solid var(--border);
      border-radius: 10px;
      background: rgba(0, 0, 0, 0.16);
      padding: 8px 0;
    }}
    .chunk-strip {{
      overflow-x: auto;
      overflow-y: hidden;
      padding: 0 10px 2px;
    }}
    .chunk-track {{
      position: relative;
      height: 42px;
    }}
    .chunk-stop {{
      position: absolute;
      top: 0;
      width: 64px;
      height: 30px;
      border: none;
      border-left: 1px solid rgba(255, 255, 255, 0.08);
      background: transparent;
      color: var(--muted);
      cursor: pointer;
      padding: 0 4px;
      text-align: left;
      font-family: var(--mono);
      font-size: 10px;
    }}
    .chunk-stop span {{
      display: block;
      margin-top: 14px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }}
    .chunk-stop::before {{
      content: "";
      position: absolute;
      left: 0;
      top: 0;
      width: 2px;
      height: 12px;
      background: rgba(138, 163, 196, 0.45);
    }}
    .chunk-stop.major::before {{
      height: 18px;
      background: rgba(138, 197, 255, 0.9);
    }}
    .chunk-stop.active {{
      color: #dff0ff;
      background: linear-gradient(180deg, rgba(61, 108, 255, 0.24), rgba(61, 108, 255, 0));
    }}
    .chunk-stop.active::before {{
      background: #7fd0ff;
      height: 24px;
    }}
    .ledger-box {{
      margin-top: 16px;
      border-top: 1px solid var(--border);
      padding-top: 12px;
    }}
    .ledger-box summary {{
      cursor: pointer;
      font-family: var(--mono);
      color: var(--accent);
      margin-bottom: 10px;
    }}
    .ledger-wrap {{
      overflow: auto;
      max-height: 420px;
      border: 1px solid var(--border);
      border-radius: 10px;
    }}
    table.ledger {{
      border-collapse: collapse;
      width: 100%;
      min-width: 1100px;
      font-family: var(--mono);
      font-size: 11px;
      background: #0d1118;
    }}
    .ledger th,
    .ledger td {{
      border-bottom: 1px solid #1d2330;
      padding: 6px 8px;
      vertical-align: top;
      text-align: left;
      white-space: nowrap;
    }}
    .ledger th {{
      position: sticky;
      top: 0;
      background: #111826;
      color: #8ec5ff;
      z-index: 1;
    }}
    .ledger-status {{
      font-family: var(--mono);
      font-size: 12px;
      color: var(--muted);
      padding: 8px 2px 0;
    }}
    .lazy-ledger[data-ledger-loading="1"] summary::after {{
      content: " loading...";
      color: var(--muted);
      font-size: 12px;
    }}
    .legend {{
      margin-top: 14px;
      display: flex;
      gap: 12px;
      flex-wrap: wrap;
      font-family: var(--mono);
      font-size: 12px;
      color: var(--muted);
    }}
    .legend span::before {{
      content: "";
      display: inline-block;
      width: 12px;
      height: 12px;
      border-radius: 3px;
      margin-right: 6px;
      vertical-align: -1px;
    }}
    .legend .hdr::before {{ background: #3d6cff; }}
    .legend .sub::before {{ background: #7fd0ff; }}
    .legend .hit::before {{ background: #51d16b; }}
    .legend .gap::before {{ background: #ffc94d; }}
    @media (max-width: 1200px) {{
      .meta {{ grid-template-columns: 1fr; }}
      .panel.egress,
      .panel.dma {{
        margin-left: 0;
        max-width: 100%;
      }}
    }}
  </style>
</head>
<body>
<main>
  <section class="hero">
    <h1>MuSiP OPQ Frame-Window Wave Report</h1>
    <p>Selected window: frames F{summary["frame_start"]}..F{summary["frame_start"] + summary["frame_count"] - 1} from the captured 4-lane replay.</p>
    <p>Clock basis: 250 MHz, one cycle = 4 ns, with C0 defined as the first rising edge of <code>tb_top.clk</code> at 2.000 ns.{frame_slot_note}</p>
    <div class="meta">
      <div><strong>Replay Seed</strong>{summary["seed"]}</div>
      <div><strong>Lane Sat</strong>{summary["lane_saturation"]}</div>
      <div><strong>Frames/Lane</strong>{summary["frames_per_lane"]}</div>
      <div><strong>Displayed Window</strong>F{summary["frame_start"]}..F{summary["frame_start"] + summary["frame_count"] - 1}</div>
      <div><strong>Total Hits</strong>{summary["total_hits"]}</div>
      <div><strong>Frame Slot</strong>{summary.get("frame_slot_cycles", "free-run")}</div>
      <div><strong>VCD</strong>{html.escape(summary["vcd_path"])}</div>
      <div><strong>Ref Bundle</strong>{html.escape(summary["ref_dir"])}</div>
      <div><strong>Page URL</strong><a id="page-url" href="./index.html" style="color:#8ec5ff">{html.escape(summary["url"] or "./index.html")}</a></div>
      <div><strong>Note</strong>Idle gaps between panels or between egress subwindows are compressed with a yellow <code>//</code> marker; frame content itself is not truncated.</div>
    </div>
  <div class="legend">
      <span class="hdr">header / trailer / timestamp / debug</span>
      <span class="sub">subheader</span>
      <span class="hit">hit payload</span>
      <span class="gap">compressed idle gap</span>
    </div>
  </section>
  <div class="grid">
    {''.join(panel_block(panel) for panel in panels)}
  </div>
</main>
<script>
const PANEL_META = {json.dumps(panel_meta, separators=(",", ":"))};
const MIN_PANEL_HSCALE = {MIN_PANEL_HSCALE};
const MAX_PANEL_HSCALE = {MAX_PANEL_HSCALE};

async function loadLedger(details) {{
  if (!details || details.dataset.ledgerLoaded === '1' || details.dataset.ledgerLoading === '1') {{
    return;
  }}
  const src = details.dataset.ledgerSrc;
  const slot = details.querySelector('[data-ledger-slot]');
  if (!src || !slot) {{
    return;
  }}
  details.dataset.ledgerLoading = '1';
  slot.innerHTML = '<div class="ledger-status">Loading ledger...</div>';
  try {{
    const response = await fetch(src, {{ cache: 'no-store' }});
    if (!response.ok) {{
      throw new Error('HTTP ' + response.status);
    }}
    slot.innerHTML = await response.text();
    details.dataset.ledgerLoaded = '1';
    bindLazyLedgers(slot);
  }} catch (err) {{
    slot.innerHTML =
      '<div class="ledger-status">Failed to load ledger: ' +
      String(err && err.message ? err.message : err) +
      '</div>';
  }} finally {{
    details.dataset.ledgerLoading = '0';
  }}
}}

function bindLazyLedgers(root) {{
  const scope = root || document;
  scope.querySelectorAll('details[data-ledger-src]').forEach(function (details) {{
    if (details.dataset.ledgerBound === '1') {{
      return;
    }}
    details.dataset.ledgerBound = '1';
    details.addEventListener('toggle', function () {{
      if (details.open) {{
        loadLedger(details);
      }}
    }});
    if (details.open) {{
      loadLedger(details);
    }}
  }});
}}

async function loadPanelChunk(meta, chunkIndex) {{
  const chunk = meta.chunks[chunkIndex];
  if (!chunk) {{
    throw new Error('Invalid chunk index ' + chunkIndex);
  }}
  if (!meta.cache) {{
    meta.cache = {{}};
  }}
  if (meta.cache[chunkIndex]) {{
    return meta.cache[chunkIndex];
  }}
  const response = await fetch('./' + chunk.src, {{ cache: 'no-store' }});
  if (!response.ok) {{
    throw new Error('HTTP ' + response.status + ' while loading ' + chunk.src);
  }}
  const json = await response.json();
  meta.cache[chunkIndex] = json;
  return json;
}}

function updatePanelUi(meta, chunkIndex) {{
  const chunk = meta.chunks[chunkIndex];
  const status = document.querySelector('[data-panel-status="' + meta.panel_id + '"]');
  if (status && chunk) {{
    status.textContent = 'Chunk ' + (chunkIndex + 1) + '/' + meta.chunk_count + ' | ' + chunk.detail;
  }}
  document.querySelectorAll('.chunk-stop[data-panel-id="' + meta.panel_id + '"]').forEach(function (node) {{
    node.classList.toggle('active', Number(node.dataset.chunkIndex) === chunkIndex);
  }});
  const prevBtn = document.querySelector('[data-panel-prev="' + meta.panel_id + '"]');
  const nextBtn = document.querySelector('[data-panel-next="' + meta.panel_id + '"]');
  if (prevBtn) {{
    prevBtn.disabled = chunkIndex <= 0;
  }}
  if (nextBtn) {{
    nextBtn.disabled = chunkIndex >= meta.chunk_count - 1;
  }}
  const zoomStatus = document.querySelector('[data-panel-zoom-status="' + meta.panel_id + '"]');
  if (zoomStatus) {{
    const rel = Math.round((meta.currentHscale / meta.base_hscale) * 100);
    zoomStatus.textContent = 'Scale ' + meta.currentHscale + ' (' + rel + '%)';
  }}
  const zoomOutBtn = document.querySelector('[data-panel-zoom-out="' + meta.panel_id + '"]');
  const zoomResetBtn = document.querySelector('[data-panel-zoom-reset="' + meta.panel_id + '"]');
  const zoomInBtn = document.querySelector('[data-panel-zoom-in="' + meta.panel_id + '"]');
  if (zoomOutBtn) {{
    zoomOutBtn.disabled = meta.currentHscale <= MIN_PANEL_HSCALE;
  }}
  if (zoomResetBtn) {{
    zoomResetBtn.disabled = meta.currentHscale === meta.base_hscale;
  }}
  if (zoomInBtn) {{
    zoomInBtn.disabled = meta.currentHscale >= MAX_PANEL_HSCALE;
  }}
}}

function scrollStripToChunk(meta, chunkIndex, behavior) {{
  const strip = document.querySelector('[data-panel-strip="' + meta.panel_id + '"]');
  if (strip) {{
    strip.scrollTo({{ left: chunkIndex * meta.nav_step_px, behavior: behavior || 'auto' }});
  }}
}}

async function renderPanelChunk(panelId, chunkIndex, options) {{
  const meta = PANEL_META[panelId];
  if (!meta) {{
    return;
  }}
  const opts = options || {{}};
  const clamped = Math.max(0, Math.min(meta.chunk_count - 1, chunkIndex));
  if (meta.rendering === clamped) {{
    return;
  }}
  meta.requestToken = (meta.requestToken || 0) + 1;
  const requestToken = meta.requestToken;
  meta.rendering = clamped;
  const displayId = 'WaveDrom_Display_' + meta.render_index;
  const display = document.getElementById(displayId);
  const waveScroll = document.querySelector('[data-wave-scroll="' + panelId + '"]');
  if (display && !opts.keepStatus) {{
    display.innerHTML = '<div class="wave-render-status">Rendering chunk ' + (clamped + 1) + '/' + meta.chunk_count + '...</div>';
  }}
  try {{
    const json = await loadPanelChunk(meta, clamped);
    if (requestToken !== meta.requestToken) {{
      return;
    }}
    if (!display) {{
      return;
    }}
    const renderJson = JSON.parse(JSON.stringify(json));
    if (!renderJson.config) {{
      renderJson.config = {{}};
    }}
    renderJson.config.hscale = meta.currentHscale;
    display.innerHTML = '';
    WaveDrom.RenderWaveForm(meta.render_index, renderJson, 'WaveDrom_Display_', false);
    if (waveScroll && !opts.preserveScroll) {{
      waveScroll.scrollLeft = 0;
    }}
    meta.currentChunk = clamped;
    updatePanelUi(meta, clamped);
  }} catch (err) {{
    if (display) {{
      display.innerHTML = '<div class="wave-render-status">Failed to render chunk: ' +
        String(err && err.message ? err.message : err) +
        '</div>';
    }}
  }} finally {{
    meta.rendering = null;
  }}
}}

function bindPanel(meta) {{
  meta.currentChunk = 0;
  meta.rendering = null;
  meta.cache = {{}};
  meta.currentHscale = meta.base_hscale;
  const strip = document.querySelector('[data-panel-strip="' + meta.panel_id + '"]');
  if (strip) {{
    let scrollTimer = null;
    strip.addEventListener('scroll', function () {{
      if (scrollTimer) {{
        clearTimeout(scrollTimer);
      }}
      scrollTimer = window.setTimeout(function () {{
        const idx = Math.round(strip.scrollLeft / meta.nav_step_px);
        if (idx !== meta.currentChunk) {{
          renderPanelChunk(meta.panel_id, idx, {{ preserveScroll: false, keepStatus: true }});
        }}
      }}, 60);
    }});
  }}
  document.querySelectorAll('.chunk-stop[data-panel-id="' + meta.panel_id + '"]').forEach(function (node) {{
    node.addEventListener('click', function () {{
      const idx = Number(node.dataset.chunkIndex);
      renderPanelChunk(meta.panel_id, idx, {{ preserveScroll: false }});
      scrollStripToChunk(meta, idx, 'smooth');
    }});
  }});
  const prevBtn = document.querySelector('[data-panel-prev="' + meta.panel_id + '"]');
  if (prevBtn) {{
    prevBtn.addEventListener('click', function () {{
      renderPanelChunk(meta.panel_id, meta.currentChunk - 1, {{ preserveScroll: false }});
      scrollStripToChunk(meta, Math.max(0, meta.currentChunk - 1), 'smooth');
    }});
  }}
  const nextBtn = document.querySelector('[data-panel-next="' + meta.panel_id + '"]');
  if (nextBtn) {{
    nextBtn.addEventListener('click', function () {{
      renderPanelChunk(meta.panel_id, meta.currentChunk + 1, {{ preserveScroll: false }});
      scrollStripToChunk(meta, Math.min(meta.chunk_count - 1, meta.currentChunk + 1), 'smooth');
    }});
  }}
  const zoomOutBtn = document.querySelector('[data-panel-zoom-out="' + meta.panel_id + '"]');
  if (zoomOutBtn) {{
    zoomOutBtn.addEventListener('click', function () {{
      if (meta.currentHscale > MIN_PANEL_HSCALE) {{
        meta.currentHscale -= 1;
        renderPanelChunk(meta.panel_id, meta.currentChunk, {{ preserveScroll: true }});
      }}
    }});
  }}
  const zoomResetBtn = document.querySelector('[data-panel-zoom-reset="' + meta.panel_id + '"]');
  if (zoomResetBtn) {{
    zoomResetBtn.addEventListener('click', function () {{
      if (meta.currentHscale !== meta.base_hscale) {{
        meta.currentHscale = meta.base_hscale;
        renderPanelChunk(meta.panel_id, meta.currentChunk, {{ preserveScroll: true }});
      }}
    }});
  }}
  const zoomInBtn = document.querySelector('[data-panel-zoom-in="' + meta.panel_id + '"]');
  if (zoomInBtn) {{
    zoomInBtn.addEventListener('click', function () {{
      if (meta.currentHscale < MAX_PANEL_HSCALE) {{
        meta.currentHscale += 1;
        renderPanelChunk(meta.panel_id, meta.currentChunk, {{ preserveScroll: true }});
      }}
    }});
  }}
  renderPanelChunk(meta.panel_id, 0, {{ preserveScroll: false }});
}}

window.addEventListener('load', function () {{
  const pageUrl = document.getElementById('page-url');
  if (pageUrl) {{
    pageUrl.href = window.location.href;
    pageUrl.textContent = window.location.href;
  }}
  if (window.WaveDrom && typeof WaveDrom.RenderWaveForm === 'function') {{
    Object.keys(PANEL_META).forEach(function (panelId) {{
      bindPanel(PANEL_META[panelId]);
    }});
  }}
  bindLazyLedgers(document);
}});
</script>
</body>
</html>
"""
    out_html.write_text(html_text)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate the OPQ frame-window WaveDrom HTML report.")
    parser.add_argument("--vcd", required=True, help="Replay-mode VCD path")
    parser.add_argument("--ref-dir", required=True, help="Reference replay bundle directory")
    parser.add_argument("--out-html", required=True, help="Output HTML file")
    parser.add_argument("--top-scope", default="tb_top", help="Top scope that owns clk/feb_if*/opq_if/dma_if (default: tb_top)")
    parser.add_argument(
        "--signal-layout",
        choices=("interface", "plain"),
        default="interface",
        help="Signal naming/layout convention: interface-style tb_top.*_if or plain raw-signal harness",
    )
    parser.add_argument("--frame-start", type=int, default=1, help="First merged frame to report (default: 1)")
    parser.add_argument("--frame-count", type=int, default=3, help="Number of merged frames to report (default: 3)")
    parser.add_argument("--frame-slot-cycles", type=int, default=0, help="Optional fixed SOP-to-SOP slot used for aligned waveform captures")
    parser.add_argument("--url", default="", help="Served URL for the report")
    args = parser.parse_args()

    vcd_file = Path(args.vcd)
    ref_dir = Path(args.ref_dir)
    out_html = Path(args.out_html)
    out_html.parent.mkdir(parents=True, exist_ok=True)

    vcd_module = load_vcd_module()
    vcd = vcd_module.VCDParser().parse(str(vcd_file))
    clock_id = vcd.match_clock(f"{args.top_scope}.clk")
    if clock_id is None:
        raise ValueError(f"Clock {args.top_scope}.clk not found in VCD")
    edges = vcd.find_rising_edges(clock_id, 0, vcd.max_time)

    ingress_frames: dict[int, list[list[Beat]]] = {}
    for lane in range(4):
        parsed = parse_framed_stream(
            extract_stream(
                vcd,
                edges,
                args.top_scope,
                f"feb_if{lane}",
                signal_layout=args.signal_layout,
                lane=lane,
            )
        )
        ingress_frames[lane] = parsed[args.frame_start : args.frame_start + args.frame_count]

    opq_frames = parse_framed_stream(
        extract_stream(
            vcd,
            edges,
            args.top_scope,
            "opq_if",
            signal_layout=args.signal_layout,
        )
    )
    selected_opq = opq_frames[args.frame_start : args.frame_start + args.frame_count]

    plan_json = json.loads((ref_dir / "plan.json").read_text())
    summary_json = json.loads((ref_dir / "summary.json").read_text())
    frame_prefix_map = build_frame_prefix_map(plan_json)
    actual_dma = extract_dma(vcd, edges, args.top_scope, signal_layout=args.signal_layout)

    ingress_panel, ingress_span = build_ingress_panel(
        ingress_frames,
        out_html.parent,
        out_html.stem,
    )
    egress_panel, egress_spans = build_egress_panel(
        selected_opq,
        out_html.parent,
        out_html.stem,
    )
    dma_panel, dma_span = build_dma_panel(
        actual_dma,
        int(summary_json["expected_word_count"]),
        frame_prefix_map,
        args.frame_start,
        args.frame_count,
        out_html.parent,
        out_html.stem,
    )
    summary = {
        "seed": summary_json["seed"],
        "lane_saturation": ", ".join(f"{value:.2f}" for value in summary_json["lane_saturation"]),
        "frames_per_lane": summary_json["frames_per_lane"],
        "frame_start": args.frame_start,
        "frame_count": args.frame_count,
        "total_hits": summary_json["total_hits"],
        "frame_slot_cycles": args.frame_slot_cycles,
        "vcd_path": str(vcd_file),
        "ref_dir": str(ref_dir),
        "url": args.url,
        "ingress_span": ingress_span,
        "egress_spans": egress_spans,
        "dma_span": dma_span,
    }

    render_page(
        out_html,
        summary,
        [ingress_panel, egress_panel, dma_panel],
    )

    meta_out = out_html.with_suffix(".summary.json")
    meta_out.write_text(json.dumps(summary, indent=2) + "\n")
    print(f"wrote {out_html}")
    print(f"wrote {meta_out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
