#!/usr/bin/env python3
from __future__ import annotations

import argparse
from dataclasses import dataclass, field
from pathlib import Path
from textwrap import dedent
from xml.sax.saxutils import escape


OPQ_VERSION = "26.4.14.0428"
OPQ_UID = 0x4F50514D
OPQ_VERSION_WORD = 0x1A04D1AC
OPQ_VERSION_DATE = 20260428
OPQ_VERSION_GIT = 0x4F667FB1
OPQ_INSTANCE_ID = 0
LANE_BASE_WORD = 0x040
LANE_STRIDE_WORDS = 0x010


@dataclass(frozen=True)
class FieldDef:
    name: str
    bit_offset: int
    bit_width: int
    description: str
    access: str | None = None


@dataclass(frozen=True)
class RegisterDef:
    offset: int
    name: str
    description: str
    access: str = "read-only"
    reset: int = 0
    fields: tuple[FieldDef, ...] = field(default_factory=tuple)


def xml(text: str) -> str:
    return escape(text, {'"': "&quot;"})


def field_xml(field_def: FieldDef, inherited_access: str) -> str:
    access = field_def.access or inherited_access
    return dedent(
        f"""\
        <field>
          <name>{xml(field_def.name)}</name>
          <description>{xml(field_def.description)}</description>
          <bitOffset>{field_def.bit_offset}</bitOffset>
          <bitWidth>{field_def.bit_width}</bitWidth>
          <access>{access}</access>
        </field>
        """
    )


def register_xml(reg: RegisterDef) -> str:
    fields = ""
    if reg.fields:
        field_rows = "\n".join(field_xml(field_def, reg.access) for field_def in reg.fields)
        fields = f"\n      <fields>\n{field_rows}      </fields>"

    return dedent(
        f"""\
        <register>
          <name>{xml(reg.name)}</name>
          <description>{xml(reg.description)}</description>
          <addressOffset>0x{reg.offset:03X}</addressOffset>
          <size>32</size>
          <access>{reg.access}</access>
          <resetValue>0x{reg.reset:08X}</resetValue>{fields}
        </register>
        """
    )


def lane_mask_fields(lanes: int) -> tuple[FieldDef, ...]:
    return tuple(
        FieldDef(
            name=f"MASK_LANE{lane}",
            bit_offset=lane,
            bit_width=1,
            description=f"Mask ingress lane {lane} at packet boundaries when set.",
        )
        for lane in range(lanes)
    )


def status_fields(lanes: int) -> tuple[FieldDef, ...]:
    return (
        FieldDef("LANE_MASK_SHADOW", 0, lanes, "Current software-programmed lane mask."),
        FieldDef("ALLOC_BUSY", 16, 1, "Page allocator is active."),
        FieldDef("ARBITER_BUSY", 17, 1, "Page-RAM write-port arbiter is active."),
        FieldDef("PRESENTER_BUSY", 18, 1, "Egress presenter is currently valid."),
        FieldDef("MASK_EFFECTIVE", 19, 1, "At least one lane is currently blocked by the packet-boundary mask."),
        FieldDef("N_LANE", 20, 4, "Instantiated lane count."),
    )


def cap_fields() -> tuple[FieldDef, ...]:
    return (
        FieldDef("UID_META_HEADER", 0, 1, "Common Mu3e UID + META identity header is implemented."),
        FieldDef("LANE_MASK_CTRL", 1, 1, "Packet-boundary lane mask control is implemented."),
        FieldDef("PER_LANE_CNTRS", 2, 1, "Per-lane write/read/drop and credit counters are implemented."),
        FieldDef("FT_CNTRS", 3, 1, "Frame-table write/read/drop counters are implemented."),
        FieldDef("DRR_CTRL", 4, 1, "Per-lane DRR allowance programming and live observability are implemented."),
        FieldDef("LANE_REGION_STRIDE", 8, 8, "Per-lane CSR region stride in 32-bit words."),
        FieldDef("LANE_REGION_BASE", 16, 8, "Base word address of the per-lane CSR region."),
        FieldDef("N_LANE", 24, 8, "Instantiated lane count."),
    )


COMMON_COUNTERS = (
    (0x020, "FT_WR_HDR", "Headers committed into frame-table ownership."),
    (0x024, "FT_WR_SHD", "Subheaders committed into frame-table ownership."),
    (0x028, "FT_WR_HIT", "Hits committed into frame-table ownership."),
    (0x02C, "FT_RD_HDR", "Headers retired through the egress presenter."),
    (0x030, "FT_RD_SHD", "Subheaders retired through the egress presenter."),
    (0x034, "FT_RD_HIT", "Hits retired through the egress presenter."),
    (0x038, "FT_DROP_HDR", "Headers dropped by frame-table overwrite or overwrite recovery."),
    (0x03C, "FT_DROP_SHD", "Subheaders dropped by frame-table overwrite or overwrite recovery."),
    (0x040, "FT_DROP_HIT", "Hits dropped by frame-table overwrite or overwrite recovery."),
)

LANE_WORDS = (
    (0x0, "WR_HDR_CNT", "Per-lane header tickets accepted from ingress parsing.", "read-only", 0),
    (0x1, "WR_SHD_CNT", "Per-lane subheader tickets accepted from ingress parsing.", "read-only", 0),
    (0x2, "WR_HIT_CNT", "Per-lane hit words written into the lane FIFO.", "read-only", 0),
    (0x3, "RD_HDR_CNT", "Per-lane header tickets consumed by the page allocator.", "read-only", 0),
    (0x4, "RD_SHD_CNT", "Per-lane subheaders accepted into the merged page stream.", "read-only", 0),
    (0x5, "RD_HIT_CNT", "Per-lane hits accepted into the merged page stream.", "read-only", 0),
    (0x6, "DROP_HDR_CNT", "Per-lane dropped headers before frame-table ownership.", "read-only", 0),
    (0x7, "DROP_SHD_CNT", "Per-lane dropped subheaders before frame-table ownership.", "read-only", 0),
    (0x8, "DROP_HIT_CNT", "Per-lane dropped hits before frame-table ownership.", "read-only", 0),
    (0x9, "LANE_CREDIT", "Current lane-FIFO free-credit counter.", "read-only", 0),
    (0xA, "TICKET_CREDIT", "Current ticket-FIFO free-credit counter.", "read-only", 0),
    (0xB, "DRR_ALLOWANCE", "Per-lane DRR refill allowance. Writes reseed the live quantum.", "read-write", 256),
    (0xC, "DRR_QUANTUM", "Current live DRR quantum or deficit budget.", "read-only", 0),
    (0xD, "DRR_GRANT_CNT", "Number of block-level arbiter lock windows granted to this lane.", "read-only", 0),
    (0xE, "DRR_BEAT_CNT", "Number of page-RAM data beats served from this lane.", "read-only", 0),
    (0xF, "DRR_DEFER_CNT", "Number of defer rounds where this lane requested service but could not cover the whole block.", "read-only", 0),
)


def build_registers(lanes: int) -> list[RegisterDef]:
    cap_reset = (lanes << 24) | (LANE_BASE_WORD << 16) | (LANE_STRIDE_WORDS << 8) | 0x1F
    registers = [
        RegisterDef(
            0x000,
            "UID",
            'Immutable Mu3e IP identifier. Default ASCII "OPQM".',
            reset=OPQ_UID,
            fields=(FieldDef("VALUE", 0, 32, 'ASCII "OPQM" packed as 0x4F50514D.'),),
        ),
        RegisterDef(
            0x004,
            "META",
            "Write PAGE_SEL[1:0], then read selected identity payload: 0=VERSION, 1=VERSION_DATE, 2=VERSION_GIT, 3=INSTANCE_ID.",
            access="read-write",
            reset=OPQ_VERSION_WORD,
            fields=(FieldDef("PAGE_SEL", 0, 2, "Selects the META payload page on write."),),
        ),
        RegisterDef(
            0x008,
            "LANE_MASK",
            "Runtime packet-boundary lane mask. A set bit disables new packets on that lane after the current packet drains.",
            access="read-write",
            fields=lane_mask_fields(lanes),
        ),
        RegisterDef(
            0x00C,
            "CTRL",
            "Control pulses. Write CLEAR_COUNTERS=1 to clear all software-visible counters.",
            access="write-only",
            fields=(FieldDef("CLEAR_COUNTERS", 0, 1, "Write-one pulse clears per-lane and frame-table counters."),),
        ),
        RegisterDef(
            0x010,
            "STATUS",
            "Aggregated lane-mask, busy, presenter, and effective-mask status.",
            reset=(lanes << 20),
            fields=status_fields(lanes),
        ),
        RegisterDef(
            0x014,
            "CAP",
            "Capability summary and per-lane CSR-region geometry.",
            reset=cap_reset,
            fields=cap_fields(),
        ),
    ]

    registers.extend(RegisterDef(offset, name, desc) for offset, name, desc in COMMON_COUNTERS)

    lane_base = LANE_BASE_WORD * 4
    lane_stride = LANE_STRIDE_WORDS * 4
    for lane in range(lanes):
        for word_idx, name, desc, access, reset in LANE_WORDS:
            offset = lane_base + (lane * lane_stride) + (word_idx * 4)
            fields: tuple[FieldDef, ...] = ()
            if name == "DRR_ALLOWANCE":
                fields = (FieldDef("ALLOWANCE", 0, 10, "DRR refill allowance in page words."),)
            registers.append(RegisterDef(offset, f"LANE{lane}_{name}", desc, access=access, reset=reset, fields=fields))

    return registers


def build_svd(lanes: int, device_name: str, peripheral_name: str, base_address: int) -> str:
    registers_xml = "\n".join(register_xml(reg) for reg in build_registers(lanes))
    return dedent(
        f"""\
        <?xml version="1.0" encoding="utf-8"?>
        <device schemaVersion="1.3" xmlns:xs="http://www.w3.org/2001/XMLSchema-instance" xs:noNamespaceSchemaLocation="CMSIS-SVD.xsd">
          <name>{xml(device_name)}</name>
          <version>{OPQ_VERSION}</version>
          <description>Ordered priority queue runtime CSR aperture for the MuSiP SWB integration.</description>
          <addressUnitBits>8</addressUnitBits>
          <width>32</width>
          <peripherals>
            <peripheral>
              <name>{xml(peripheral_name)}</name>
              <description>Ordered priority queue CSR window accessed through the Platform Designer JTAG Avalon master.</description>
              <baseAddress>0x{base_address:08X}</baseAddress>
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
    ).lstrip()


def parse_int(text: str) -> int:
    return int(text, 0)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate a CMSIS-SVD view of the OPQ CSR map.")
    parser.add_argument("--lanes", type=int, default=4, help="Number of ingress lanes to describe")
    parser.add_argument("--output", type=Path, required=True, help="Output SVD path")
    parser.add_argument("--device-name", default="OPQ_UPSTREAM_4LANE", help="SVD device name")
    parser.add_argument("--peripheral-name", default="OPQ", help="SVD peripheral name")
    parser.add_argument("--base-address", type=parse_int, default=0, help="OPQ CSR base address")
    args = parser.parse_args()

    if args.lanes < 1 or args.lanes > 16:
        raise SystemExit("--lanes must be in the range 1..16")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        build_svd(args.lanes, args.device_name, args.peripheral_name, args.base_address),
        encoding="utf-8",
    )
    print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
