#!/usr/bin/env python3
"""Generate the MuTRiG timestamp decode ROM MIF."""

from __future__ import annotations

import argparse
from pathlib import Path


ADDR_WIDTH = 15
DATA_WIDTH = 15
TABLE_ENTRIES = (1 << ADDR_WIDTH) - 1
DEPTH = 1 << ADDR_WIDTH
MASK = (1 << ADDR_WIDTH) - 1
START_STATE = 1


def next_state(state: int) -> int:
    bit_hi = (state >> (ADDR_WIDTH - 1)) & 1
    bit_lo = (state >> (ADDR_WIDTH - 2)) & 1
    feedback = 1 ^ bit_hi ^ bit_lo
    return ((state << 1) & MASK) | feedback


def generate_table() -> dict[int, int]:
    state = START_STATE
    seen: set[int] = set()
    table: dict[int, int] = {}

    for count in range(TABLE_ENTRIES):
        if state in seen:
            raise RuntimeError(f"LFSR state repeated early at count {count}: 0x{state:04X}")
        seen.add(state)
        table[state] = count
        state = next_state(state)

    if state != START_STATE:
        raise RuntimeError(f"LFSR did not return to start state: 0x{state:04X}")
    return table


def render_mif(table: dict[int, int]) -> bytes:
    lines = [
        f"WIDTH={DATA_WIDTH};\n",
        f"DEPTH={DEPTH};\n",
        "\n",
        "ADDRESS_RADIX=HEX;\n",
        "DATA_RADIX=BIN;\n",
        "\n",
        "CONTENT BEGIN\n",
    ]
    for address in range(DEPTH):
        value = table.get(address, 0)
        lines.append(f"    {address:04X} : {value:0{DATA_WIDTH}b};\n")
    lines.append("END;\n")
    return "".join(lines).encode("ascii")


def write_if_changed(path: Path, data: bytes) -> None:
    if path.exists() and path.read_bytes() == data:
        return
    path.write_bytes(data)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="write the generated Quartus MIF file")
    args = parser.parse_args()

    table = generate_table()
    write_if_changed(args.output, render_mif(table))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
