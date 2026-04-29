#!/usr/bin/env python3
"""Extract a native-SV UVM VCD into GHDL scheduled replay files for one case."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path


K285 = 0xBC
K284 = 0x9C
K237 = 0xF7
CASE_CYCLES = 24576

KIND_IDLE = 0
KIND_SOP = 1
KIND_TS_HIGH = 2
KIND_TS_LOW = 3
KIND_DEBUG0 = 4
KIND_DEBUG1 = 5
KIND_SUBHEADER = 6
KIND_HIT = 7
KIND_EOP = 8


@dataclass(frozen=True)
class Beat:
    cycle: int
    data: int
    datak: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vcd", required=True, type=Path)
    parser.add_argument("--case-dir", required=True, type=Path)
    parser.add_argument("--case-cycles", type=int, default=CASE_CYCLES)
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


def extract_streams(vcd: Path) -> dict[str, list[Beat]]:
    ids = parse_header(vcd)
    name_to_id = {name: ident for ident, name in ids.items()}
    clk_id = name_to_id["tb_top.clk"]
    specs: dict[str, tuple[str, str, str]] = {
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

    values: dict[str, str] = {}
    streams: dict[str, list[Beat]] = {name: [] for name in specs}
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
                valid = bits_to_int(values.get(valid_id))
                if valid == 1:
                    data = bits_to_int(values.get(data_id))
                    datak = bits_to_int(values.get(datak_id))
                    if data is None or datak is None:
                        raise ValueError(f"{name} contains X/Z at cycle {cycle}")
                    streams[name].append(Beat(cycle, data, datak))
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


def classify_stream(beats: list[Beat], source_lane: int) -> list[tuple[int, int, int, int, int]]:
    state = 0
    rows: list[tuple[int, int, int, int, int]] = []
    for beat in beats:
        if beat.datak == 1 and (beat.data & 0xFF) == K285:
            kind = KIND_SOP
            state = 1
        elif state == 1:
            kind = KIND_TS_HIGH
            state = 2
        elif state == 2:
            kind = KIND_TS_LOW
            state = 3
        elif state == 3:
            kind = KIND_DEBUG0
            state = 4
        elif state == 4:
            kind = KIND_DEBUG1
            state = 5
        elif beat.datak == 1 and (beat.data & 0xFF) == K237:
            kind = KIND_SUBHEADER
        elif beat.datak == 1 and (beat.data & 0xFF) == K284:
            kind = KIND_EOP
            state = 0
        else:
            kind = KIND_HIT
        rows.append((beat.cycle, source_lane, kind, beat.datak, beat.data))
    return rows


def pack_event(source_lane: int, kind: int, valid: int, datak: int, data: int) -> int:
    return (
        ((source_lane & 0x3) << 45)
        | ((kind & 0x1F) << 40)
        | ((valid & 0x1) << 36)
        | ((datak & 0xF) << 32)
        | (data & 0xFFFF_FFFF)
    )


def write_schedule(path: Path, rows: list[tuple[int, int, int, int, int]], cycle_offset: int, case_cycles: int) -> None:
    schedule = [pack_event(0, KIND_IDLE, 0, 0, 0) for _ in range(case_cycles)]
    for cycle, source_lane, kind, datak, data in rows:
        out_cycle = cycle - cycle_offset
        if 0 <= out_cycle < case_cycles:
            schedule[out_cycle] = pack_event(source_lane, kind, 1, datak, data)
    path.write_text("".join(f"{word:012X}\n" for word in schedule), encoding="ascii")


def first_sop(beats: list[Beat]) -> int:
    for beat in beats:
        if beat.datak == 1 and (beat.data & 0xFF) == K285:
            return beat.cycle
    raise ValueError("stream has no SOP")


def main() -> int:
    args = parse_args()
    streams = extract_streams(args.vcd)
    cycle_offset = first_sop(streams["lane0"])
    args.case_dir.mkdir(parents=True, exist_ok=True)
    for lane in range(4):
        rows = classify_stream(streams[f"lane{lane}"], lane)
        write_schedule(args.case_dir / f"lane{lane}.mem", rows, cycle_offset, args.case_cycles)
    write_schedule(args.case_dir / "opq.mem", classify_stream(streams["opq"], 0), cycle_offset, args.case_cycles)
    print(
        f"extracted UVM replay to {args.case_dir} "
        f"(cycle_offset={cycle_offset}, opq_sop_delta={first_sop(streams['opq']) - cycle_offset})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
