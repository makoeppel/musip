#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
from textwrap import dedent


COMMON_REGS = [
    (0x000, "UID", "IP identity word"),
    (0x004, "META", "Version/date/git/instance selector window"),
    (0x008, "LANE_MASK", "Runtime lane mask"),
    (0x00C, "CTRL", "Control/status selector"),
    (0x010, "STATUS", "Aggregated status"),
    (0x014, "CAP", "Capability word"),
    (0x020, "FT_WR_HDR", "Frame-table written headers"),
    (0x024, "FT_WR_SHD", "Frame-table written subheaders"),
    (0x028, "FT_WR_HIT", "Frame-table written hits"),
    (0x02C, "FT_RD_HDR", "Frame-table read headers"),
    (0x030, "FT_RD_SHD", "Frame-table read subheaders"),
    (0x034, "FT_RD_HIT", "Frame-table read hits"),
    (0x038, "FT_DROP_HDR", "Frame-table dropped headers"),
    (0x03C, "FT_DROP_SHD", "Frame-table dropped subheaders"),
    (0x040, "FT_DROP_HIT", "Frame-table dropped hits"),
]

LANE_WORDS = [
    (0x0, "WR_HDR_CNT", "Per-lane written headers"),
    (0x1, "WR_SHD_CNT", "Per-lane written subheaders"),
    (0x2, "WR_HIT_CNT", "Per-lane written hits"),
    (0x3, "RD_HDR_CNT", "Per-lane read headers"),
    (0x4, "RD_SHD_CNT", "Per-lane read subheaders"),
    (0x5, "RD_HIT_CNT", "Per-lane read hits"),
    (0x6, "DROP_HDR_CNT", "Per-lane dropped headers"),
    (0x7, "DROP_SHD_CNT", "Per-lane dropped subheaders"),
    (0x8, "DROP_HIT_CNT", "Per-lane dropped hits"),
    (0x9, "LANE_CREDIT", "Per-lane lane-FIFO credit"),
    (0xA, "TICKET_CREDIT", "Per-lane ticket credit"),
    (0xB, "DRR_ALLOWANCE", "Configured DRR allowance"),
    (0xC, "DRR_QUANTUM", "Current DRR quantum"),
    (0xD, "DRR_GRANT_CNT", "Grant counter"),
    (0xE, "DRR_BEAT_CNT", "Granted beat counter"),
    (0xF, "DRR_DEFER_CNT", "Deferred grant counter"),
]


def render_register(offset: int, name: str, description: str) -> str:
    return dedent(
        f"""\
        <register>
          <name>{name}</name>
          <description>{description}</description>
          <addressOffset>0x{offset:03X}</addressOffset>
          <size>32</size>
          <access>read-write</access>
        </register>
        """
    )


def build_svd(lanes: int) -> str:
    registers = []
    registers.extend(render_register(offset, name, desc) for offset, name, desc in COMMON_REGS)

    lane_base = 0x100
    lane_stride = 0x40
    for lane in range(lanes):
      for word_idx, name, desc in LANE_WORDS:
        offset = lane_base + (lane * lane_stride) + (word_idx * 4)
        registers.append(render_register(offset, f"LANE{lane}_{name}", desc))

    registers_xml = "\n".join(registers)
    return dedent(
        f"""\
        <?xml version="1.0" encoding="utf-8"?>
        <device schemaVersion="1.3" xmlns:xs="http://www.w3.org/2001/XMLSchema-instance" xs:noNamespaceSchemaLocation="CMSIS-SVD.xsd">
          <name>OPQ_MONOLITHIC_4LANE_MERGE</name>
          <version>26.3.6</version>
          <description>Ordered priority queue runtime CSR aperture for the MuSiP SWB integration.</description>
          <addressUnitBits>8</addressUnitBits>
          <width>32</width>
          <peripherals>
            <peripheral>
              <name>OPQ</name>
              <description>Ordered priority queue CSR window</description>
              <baseAddress>0x00000000</baseAddress>
              <addressBlock>
                <offset>0x0</offset>
                <size>0x400</size>
                <usage>registers</usage>
              </addressBlock>
              <registers>
        {registers_xml}
              </registers>
            </peripheral>
          </peripherals>
        </device>
        """
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate a minimal CMSIS-SVD view of the OPQ CSR map.")
    parser.add_argument("--lanes", type=int, default=4, help="Number of ingress lanes to describe")
    parser.add_argument("--output", type=Path, required=True, help="Output SVD path")
    args = parser.parse_args()

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(build_svd(args.lanes), encoding="utf-8")
    print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
