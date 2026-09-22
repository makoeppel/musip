#!/usr/bin/env python3
"""Generate deterministic MuTRiG3 beamtime26 QC configuration headers.

The input XML files contain the four local ASIC configurations measured for
SMB3.  Global ASICs 4..7 intentionally reuse local configurations 0..3.
Packing follows the field order and bit-order flags in
mutrig_controller_bsp.tcl.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Iterable


SCRIPT_DIR = Path(__file__).resolve().parent
FIELD_ORDER = ("Header", "Channel", "TDC", "Footer")
EXPECTED_FIELD_BITS = {
    "Header": 34,
    "Channel": 71,
    "TDC": 84,
    "Footer": 272,
}
CONFIG_BITS = 2662
CONFIG_BYTES = 333
LOCAL_ASICS = 4
GLOBAL_ASICS = 8

SOURCE_SUBDIR = Path("board_test_system/trash_bin/good_ribbon_0")
TDC_SOURCE_NAME = "config_smb3_tdc.txt"
ANALOG_SOURCE_NAME = "config_smb3_ana_asic-0123.txt"
BSP_RELATIVE_PATH = Path(
    "toolkits/fe_scifi/system_console/lib/mutrig_controller_bsp.tcl"
)
HOST_SCHEMA_RELATIVE_PATH = Path(
    "switching_pc/slowcontrol/mutrig/Mutrig3Config.cpp"
)

# MUTRIG.md documents these SMB3 defaults in (vncnt, vnvcodelay,
# vnhitlogic) order.  Keeping this assertion here prevents silently
# regenerating a beamtime preset from an unrelated XML file.
SMB3_TDC_PLL_DEFAULTS = (
    (48, 20, 30),
    (43, 30, 30),
    (45, 35, 20),
    (41, 10, 20),
)

ParamInfo = dict[str, list[tuple[str, int, int]]]
FieldKey = tuple[str, int | None, str]
FieldOffsets = dict[FieldKey, tuple[int, int, int]]


def discover_mu3e_ip_root() -> Path:
    """Find the sibling mu3e-ip-cores checkout used by this workspace."""

    configured = os.environ.get("MU3E_IP_ROOT")
    if configured:
        return Path(configured).expanduser().resolve()

    for ancestor in SCRIPT_DIR.parents:
        candidate = ancestor / "mu3e_ip_dev" / "mu3e-ip-cores"
        if candidate.is_dir():
            return candidate.resolve()

    raise RuntimeError(
        "cannot find mu3e-ip-cores; pass --mu3e-ip-root or set MU3E_IP_ROOT"
    )


def discover_online_root() -> Path:
    """Find the online checkout containing the MIDAS MuTRiG3 packer."""

    for ancestor in SCRIPT_DIR.parents:
        if (ancestor / HOST_SCHEMA_RELATIVE_PATH).is_file():
            return ancestor
    raise RuntimeError("cannot find the online checkout containing Mutrig3Config.cpp")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bytes_sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def extract_param_info(bsp_path: Path) -> ParamInfo:
    """Extract the four canonical parameter lists from the Tcl BSP."""

    text = bsp_path.read_text(encoding="utf-8")
    spans = {
        "Header": ("set mutrig_header_param", "set mutrig_ch_param"),
        "Channel": ("set mutrig_ch_param", "set mutrig_tdc_param"),
        "TDC": ("set mutrig_tdc_param", "set mutrig_footer_param"),
        "Footer": ("set mutrig_footer_param", "switch $fieldName"),
    }
    result: ParamInfo = {}
    for field, (start_marker, stop_marker) in spans.items():
        try:
            start = text.index(start_marker)
            stop = text.index(stop_marker, start + len(start_marker))
        except ValueError as exc:
            raise RuntimeError(
                f"cannot find {field} schema markers in {bsp_path}"
            ) from exc
        block = text[start:stop]
        entries = [
            (name, int(width), int(reverse))
            for name, width, reverse in re.findall(
                r'\{"([^"]+)"\s+(\d+)\s+(\d+)\}', block
            )
        ]
        if not entries:
            raise RuntimeError(f"empty {field} schema extracted from {bsp_path}")
        if any(reverse not in (0, 1) for _, _, reverse in entries):
            raise RuntimeError(f"invalid bit-order flag in {field} schema")
        result[field] = entries

    actual_bits = {
        field: sum(width for _, width, _ in entries)
        for field, entries in result.items()
    }
    if actual_bits != EXPECTED_FIELD_BITS:
        raise RuntimeError(
            f"unexpected MuTRiG3 schema widths {actual_bits}, "
            f"expected {EXPECTED_FIELD_BITS}"
        )
    total = (
        actual_bits["Header"]
        + 32 * actual_bits["Channel"]
        + actual_bits["TDC"]
        + actual_bits["Footer"]
    )
    if total != CONFIG_BITS:
        raise RuntimeError(
            f"unexpected MuTRiG3 configuration length {total}, expected {CONFIG_BITS}"
        )
    return result


def validate_host_schema(host_schema_path: Path, param_info: ParamInfo) -> None:
    """Require the NIOS/Tcl and MIDAS/C++ packers to describe identical bits."""

    text = host_schema_path.read_text(encoding="utf-8")
    cpp_names = {
        "Header": "parameters_header",
        "Channel": "parameters_ch",
        "TDC": "parameters_tdc",
        "Footer": "parameters_footer",
    }
    for field, cpp_name in cpp_names.items():
        match = re.search(
            rf"Mutrig3Config::paras_t\s+Mutrig3Config::{cpp_name}\s*="
            rf"\s*\{{(.*?)\n\s*\}};",
            text,
            re.DOTALL,
        )
        if match is None:
            raise RuntimeError(
                f"cannot find MIDAS {cpp_name} schema in {host_schema_path}"
            )

        # Ignore commented-out legacy fields before extracting make_param calls.
        block = "\n".join(
            line.split("//", 1)[0] for line in match.group(1).splitlines()
        )
        host_entries = [
            (name, int(width), 1 - int(msb_first))
            for name, width, msb_first in re.findall(
                r'make_param\("([^"]+)"\s*,\s*(\d+)\s*,\s*([01])\)',
                block,
            )
        ]
        if host_entries != param_info[field]:
            raise RuntimeError(
                f"NIOS/Tcl and MIDAS/C++ {field} schemas differ: "
                f"{host_entries!r} != {param_info[field]!r}"
            )


def load_mutrigs(xml_path: Path) -> dict[int, ET.Element]:
    root = ET.parse(xml_path).getroot()
    result: dict[int, ET.Element] = {}
    for mutrig in root.findall(".//mutrig"):
        index_text = mutrig.findtext("index")
        if index_text is None:
            raise RuntimeError(f"mutrig without index in {xml_path}")
        index = int(index_text.strip(), 0)
        if index in result:
            raise RuntimeError(f"duplicate local ASIC {index} in {xml_path}")
        result[index] = mutrig
    expected = set(range(LOCAL_ASICS))
    if set(result) != expected:
        raise RuntimeError(
            f"{xml_path} contains local ASICs {sorted(result)}, "
            f"expected {sorted(expected)}"
        )
    return result


def parameter_parent(
    mutrig: ET.Element, field: str, channel: int | None = None
) -> ET.Element:
    params = mutrig.find("parameters")
    if params is None:
        raise RuntimeError("mutrig entry has no parameters node")
    path = f"Channel/ch{channel}" if field == "Channel" else field
    parent = params.find(path)
    if parent is None:
        raise RuntimeError(f"mutrig entry has no {path} node")
    return parent


def parameter_value(
    mutrig: ET.Element, field: str, name: str, channel: int | None = None
) -> int:
    parent = parameter_parent(mutrig, field, channel)
    text = parent.findtext(name)
    if text is None or not text.strip():
        location = f"{field}.ch{channel}" if channel is not None else field
        raise RuntimeError(f"missing {location}.{name}")
    return int(text.strip(), 0)


def set_channel_parameter(mutrig: ET.Element, channel: int, name: str, value: int) -> None:
    parent = parameter_parent(mutrig, "Channel", channel)
    node = parent.find(name)
    if node is None:
        raise RuntimeError(f"missing Channel.ch{channel}.{name}")
    node.text = str(value)


def patched_channels(mutrig: ET.Element, values: dict[str, int]) -> ET.Element:
    patched = copy.deepcopy(mutrig)
    for channel in range(32):
        for name, value in values.items():
            set_channel_parameter(patched, channel, name, value)
    return patched


def append_parameter_bits(
    chunks: list[str], value: int, width: int, reverse: int, label: str
) -> None:
    if value < 0 or value >= (1 << width):
        raise ValueError(f"{label}={value} does not fit in {width} bits")
    bits = f"{value:0{width}b}"
    chunks.append(bits[::-1] if reverse else bits)


def pack_config(mutrig: ET.Element, param_info: ParamInfo) -> bytes:
    chunks: list[str] = []
    for field in FIELD_ORDER:
        entries = param_info[field]
        if field == "Channel":
            for channel in range(32):
                for name, width, reverse in entries:
                    append_parameter_bits(
                        chunks,
                        parameter_value(mutrig, field, name, channel),
                        width,
                        reverse,
                        f"{field}.ch{channel}.{name}",
                    )
        else:
            for name, width, reverse in entries:
                append_parameter_bits(
                    chunks,
                    parameter_value(mutrig, field, name),
                    width,
                    reverse,
                    f"{field}.{name}",
                )

    bit_stream = "".join(chunks)
    if len(bit_stream) != CONFIG_BITS:
        raise RuntimeError(
            f"packed {len(bit_stream)} MuTRiG3 bits, expected {CONFIG_BITS}"
        )

    packed = bytearray()
    for start in range(0, CONFIG_BITS, 8):
        byte_bits = bit_stream[start : start + 8].ljust(8, "0")
        packed.append(
            sum((bit == "1") << bit_index for bit_index, bit in enumerate(byte_bits))
        )
    if len(packed) != CONFIG_BYTES:
        raise RuntimeError(f"packed {len(packed)} bytes, expected {CONFIG_BYTES}")
    return bytes(packed)


def build_field_offsets(param_info: ParamInfo) -> FieldOffsets:
    result: FieldOffsets = {}
    offset = 0
    for field in FIELD_ORDER:
        entries = param_info[field]
        if field == "Channel":
            for channel in range(32):
                for name, width, reverse in entries:
                    result[(field, channel, name)] = (offset, width, reverse)
                    offset += width
        else:
            for name, width, reverse in entries:
                result[(field, None, name)] = (offset, width, reverse)
                offset += width
    if offset != CONFIG_BITS:
        raise RuntimeError(f"field map covers {offset} bits, expected {CONFIG_BITS}")
    return result


def unpack_parameter(data: bytes, spec: tuple[int, int, int]) -> int:
    offset, width, reverse = spec
    bits = "".join(
        "1" if data[bit // 8] & (1 << (bit % 8)) else "0"
        for bit in range(offset, offset + width)
    )
    if reverse:
        bits = bits[::-1]
    return int(bits, 2)


def validate_channel_fields(
    name: str,
    configs: list[bytes],
    offsets: FieldOffsets,
    expected: dict[str, int | None],
) -> None:
    for local_asic, config in enumerate(configs):
        for channel in range(32):
            for field_name, expected_value in expected.items():
                value = unpack_parameter(
                    config, offsets[("Channel", channel, field_name)]
                )
                if expected_value is None:
                    if value == 0:
                        raise RuntimeError(
                            f"{name}[{local_asic}] ch{channel} "
                            f"{field_name} is not enabled"
                        )
                elif value != expected_value:
                    raise RuntimeError(
                        f"{name}[{local_asic}] ch{channel} {field_name}={value}, "
                        f"expected {expected_value}"
                    )


def validate_presets(
    tdc: list[bytes],
    analog: list[bytes],
    all_off: list[bytes],
    offsets: FieldOffsets,
) -> None:
    for preset_name, configs in (
        ("TDC", tdc),
        ("ANALOG", analog),
        ("ALL_OFF", all_off),
    ):
        if len(configs) != LOCAL_ASICS:
            raise RuntimeError(
                f"{preset_name} has {len(configs)} configs, expected {LOCAL_ASICS}"
            )
        for local_asic, config in enumerate(configs):
            if len(config) != CONFIG_BYTES:
                raise RuntimeError(
                    f"{preset_name}[{local_asic}] has {len(config)} bytes, "
                    f"expected {CONFIG_BYTES}"
                )
            # Only six bits of byte 332 are part of the 2662-bit stream.
            if config[-1] & 0xC0:
                raise RuntimeError(
                    f"{preset_name}[{local_asic}] has nonzero padding bits"
                )

    validate_channel_fields(
        "TDC",
        tdc,
        offsets,
        {"tdctest_n": 0, "cml": 0, "mask": 0, "recv_all": 1},
    )
    validate_channel_fields(
        "ANALOG",
        analog,
        offsets,
        {"tdctest_n": 1, "cml": None, "mask": 0, "recv_all": 1},
    )
    validate_channel_fields(
        "ALL_OFF",
        all_off,
        offsets,
        {"tdctest_n": 1, "cml": 0, "mask": 1, "recv_all": 0},
    )

    for local_asic, expected in enumerate(SMB3_TDC_PLL_DEFAULTS):
        actual = tuple(
            unpack_parameter(tdc[local_asic], offsets[("TDC", None, name)])
            for name in ("vncnt", "vnvcodelay", "vnhitlogic")
        )
        if actual != expected:
            raise RuntimeError(
                f"TDC[{local_asic}] PLL defaults {actual}, expected {expected}"
            )


def format_byte_rows(data: bytes, indent: str) -> list[str]:
    lines: list[str] = []
    for start in range(0, len(data), 12):
        values = ", ".join(f"0x{value:02X}" for value in data[start : start + 12])
        lines.append(f"{indent}{values},")
    return lines


def format_config_array(name: str, configs: Iterable[bytes]) -> list[str]:
    rows = list(configs)
    lines = [
        f"static const uint8_t {name}[MUTRIG3_BEAMTIME26_QC_LOCAL_ASICS]",
        "                                 [MUTRIG3_BEAMTIME26_QC_BYTES] = {",
    ]
    for local_asic, data in enumerate(rows):
        lines.append(f"    {{ /* SMB3 local ASIC {local_asic} */")
        lines.extend(format_byte_rows(data, "        "))
        lines.append("    },")
    lines.append("};")
    return lines


def provenance_lines(
    tdc_path: Path,
    analog_path: Path,
    bsp_path: Path,
    tdc: list[bytes],
    analog: list[bytes],
    all_off: list[bytes],
) -> list[str]:
    lines = [
        " * Sources:",
        f" *   {SOURCE_SUBDIR / TDC_SOURCE_NAME}",
        f" *     SHA-256 {sha256(tdc_path)}",
        f" *   {SOURCE_SUBDIR / ANALOG_SOURCE_NAME}",
        f" *     SHA-256 {sha256(analog_path)}",
        f" *   {BSP_RELATIVE_PATH}",
        f" *     SHA-256 {sha256(bsp_path)}",
        " * Packed payload SHA-256 values by SMB3 local ASIC 0..3:",
    ]
    for name, configs in (("ALL_OFF", all_off), ("TDC", tdc), ("ANALOG", analog)):
        hashes = ", ".join(bytes_sha256(config) for config in configs)
        lines.append(f" *   {name}: {hashes}")
    return lines


def render_beamtime_header(
    tdc_path: Path,
    analog_path: Path,
    bsp_path: Path,
    tdc: list[bytes],
    analog: list[bytes],
    all_off: list[bytes],
) -> str:
    lines = [
        "/* AUTO-GENERATED by generate_beamtime26_qc.py. DO NOT EDIT. */",
        "/*",
        " * MuTRiG3 beamtime26 QC presets.",
        " *",
        " * ALL_OFF is based on each SMB3 TDC config with every channel masked,",
        " * tdctest_n=1, CML disabled, and recv_all=0.",
        " * ANALOG is based on the SMB3 analog config with tdctest_n patched to 1.",
        " * Global ASICs 4..7 intentionally repeat SMB3 local ASICs 0..3.",
    ]
    lines.extend(provenance_lines(tdc_path, analog_path, bsp_path, tdc, analog, all_off))
    lines.extend(
        [
            " */",
            "",
            "#ifndef MUTRIG3_BEAMTIME26_QC_H_",
            "#define MUTRIG3_BEAMTIME26_QC_H_",
            "",
            "#include <stdint.h>",
            "",
            "enum {",
            f"    MUTRIG3_BEAMTIME26_QC_BITS = {CONFIG_BITS},",
            f"    MUTRIG3_BEAMTIME26_QC_BYTES = {CONFIG_BYTES},",
            f"    MUTRIG3_BEAMTIME26_QC_LOCAL_ASICS = {LOCAL_ASICS},",
            f"    MUTRIG3_BEAMTIME26_QC_GLOBAL_ASICS = {GLOBAL_ASICS}",
            "};",
            "",
            "static const uint8_t config_BEAMTIME26_QC_LOCAL_ASIC",
            "    [MUTRIG3_BEAMTIME26_QC_GLOBAL_ASICS] = {0, 1, 2, 3, 0, 1, 2, 3};",
            "",
        ]
    )
    lines.extend(format_config_array("config_BEAMTIME26_QC_ALL_OFF", all_off))
    lines.append("")
    lines.extend(format_config_array("config_BEAMTIME26_QC_TDC", tdc))
    lines.append("")
    lines.extend(format_config_array("config_BEAMTIME26_QC_ANALOG", analog))
    lines.extend(["", "#endif /* MUTRIG3_BEAMTIME26_QC_H_ */", ""])
    return "\n".join(lines)


def render_all_off_header(
    tdc_path: Path,
    analog_path: Path,
    bsp_path: Path,
    tdc: list[bytes],
    analog: list[bytes],
    all_off: list[bytes],
) -> str:
    lines = [
        "/* AUTO-GENERATED by generate_beamtime26_qc.py. DO NOT EDIT. */",
        "/*",
        " * Safe common MuTRiG3 all-off pattern (SMB3 local ASIC 0 base).",
        " * Every channel is masked with tdctest_n=1, CML disabled, recv_all=0.",
    ]
    lines.extend(provenance_lines(tdc_path, analog_path, bsp_path, tdc, analog, all_off))
    lines.extend(
        [
            " */",
            "",
            "#ifndef MUTRIG3_ALL_OFF_H_",
            "#define MUTRIG3_ALL_OFF_H_",
            "",
            "#include <stdint.h>",
            "",
            f"static const uint8_t config_ALL_OFF[{CONFIG_BYTES}] = {{",
        ]
    )
    lines.extend(format_byte_rows(all_off[0], "    "))
    lines.extend(["};", "", "#endif /* MUTRIG3_ALL_OFF_H_ */", ""])
    return "\n".join(lines)


def render_schema_header(
    param_info: ParamInfo,
    bsp_path: Path,
    host_schema_path: Path,
) -> str:
    """Render the field descriptors used by the NIOS live-config browser."""

    section_bases = {
        "Header": 0,
        "Channel": 0,
        "TDC": EXPECTED_FIELD_BITS["Header"]
        + 32 * EXPECTED_FIELD_BITS["Channel"],
        "Footer": EXPECTED_FIELD_BITS["Header"]
        + 32 * EXPECTED_FIELD_BITS["Channel"]
        + EXPECTED_FIELD_BITS["TDC"],
    }
    array_names = {
        "Header": "HEADER_FIELDS",
        "Channel": "CHANNEL_FIELDS",
        "TDC": "TDC_FIELDS",
        "Footer": "FOOTER_FIELDS",
    }

    lines = [
        "/* AUTO-GENERATED by generate_beamtime26_qc.py. DO NOT EDIT. */",
        "/*",
        " * MuTRiG3 configuration field descriptors shared by the NIOS",
        " * live-configuration browser and host-side consistency tests.",
        " *",
        f" * Tcl schema SHA-256: {sha256(bsp_path)}",
        f" * MIDAS schema SHA-256: {sha256(host_schema_path)}",
        " */",
        "",
        "#ifndef MUTRIG3_CONFIG_SCHEMA_H_",
        "#define MUTRIG3_CONFIG_SCHEMA_H_",
        "",
        "#include <stdint.h>",
        "",
        "namespace mutrig3_config {",
        "",
        "enum field_order_t : uint8_t {",
        "    FIELD_BIG_ENDIAN = 0,",
        "    FIELD_LITTLE_ENDIAN = 1",
        "};",
        "",
        "struct field_descriptor_t {",
        "    const char* name;",
        "    uint16_t offset;",
        "    uint8_t width;",
        "    field_order_t order;",
        "};",
        "",
    ]

    for section in FIELD_ORDER:
        entries = param_info[section]
        array_name = array_names[section]
        offset = section_bases[section]
        lines.append(
            f"static const field_descriptor_t {array_name}[{len(entries)}] = {{"
        )
        for name, width, reverse in entries:
            order = "FIELD_LITTLE_ENDIAN" if reverse else "FIELD_BIG_ENDIAN"
            lines.append(
                f'    {{"{name}", {offset}, {width}, {order}}},'
            )
            offset += width
        lines.extend(["};", ""])

    lines.extend(
        [
            "enum : uint8_t {",
            f"    HEADER_FIELD_COUNT = {len(param_info['Header'])},",
            f"    CHANNEL_FIELD_COUNT = {len(param_info['Channel'])},",
            f"    TDC_FIELD_COUNT = {len(param_info['TDC'])},",
            f"    FOOTER_FIELD_COUNT = {len(param_info['Footer'])}",
            "};",
            "",
            "} // namespace mutrig3_config",
            "",
            "#endif /* MUTRIG3_CONFIG_SCHEMA_H_ */",
            "",
        ]
    )
    return "\n".join(lines)


def write_or_check(path: Path, content: str, check: bool) -> bool:
    if check:
        try:
            current = path.read_text(encoding="utf-8")
        except FileNotFoundError:
            print(f"missing generated header: {path}", file=sys.stderr)
            return False
        if current != content:
            print(f"stale generated header: {path}", file=sys.stderr)
            return False
        print(f"checked {path}")
        return True

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")
    print(f"wrote {path}")
    return True


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--mu3e-ip-root",
        type=Path,
        help="path to mu3e-ip-cores (auto-detected from the sibling checkout)",
    )
    parser.add_argument(
        "--beamtime-header",
        type=Path,
        default=SCRIPT_DIR / "beamtime26_qc.h",
        help="generated beamtime preset header",
    )
    parser.add_argument(
        "--all-off-header",
        type=Path,
        default=SCRIPT_DIR / "ALL_OFF.h",
        help="generated compatibility all-off header",
    )
    parser.add_argument(
        "--schema-header",
        type=Path,
        default=SCRIPT_DIR / "mutrig3_config_schema.h",
        help="generated MuTRiG3 field-descriptor header",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify generated headers without rewriting them",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        ip_root = (
            args.mu3e_ip_root.expanduser().resolve()
            if args.mu3e_ip_root
            else discover_mu3e_ip_root()
        )
        tdc_path = ip_root / SOURCE_SUBDIR / TDC_SOURCE_NAME
        analog_path = ip_root / SOURCE_SUBDIR / ANALOG_SOURCE_NAME
        bsp_path = ip_root / BSP_RELATIVE_PATH
        for path in (tdc_path, analog_path, bsp_path):
            if not path.is_file():
                raise RuntimeError(f"required input does not exist: {path}")

        param_info = extract_param_info(bsp_path)
        host_schema_path = discover_online_root() / HOST_SCHEMA_RELATIVE_PATH
        validate_host_schema(host_schema_path, param_info)
        offsets = build_field_offsets(param_info)
        tdc_xml = load_mutrigs(tdc_path)
        analog_xml = load_mutrigs(analog_path)

        tdc = [pack_config(tdc_xml[index], param_info) for index in range(LOCAL_ASICS)]
        analog = [
            pack_config(
                patched_channels(analog_xml[index], {"tdctest_n": 1}),
                param_info,
            )
            for index in range(LOCAL_ASICS)
        ]
        all_off = [
            pack_config(
                patched_channels(
                    tdc_xml[index],
                    {"mask": 1, "tdctest_n": 1, "cml": 0, "recv_all": 0},
                ),
                param_info,
            )
            for index in range(LOCAL_ASICS)
        ]
        validate_presets(tdc, analog, all_off, offsets)

        beamtime_content = render_beamtime_header(
            tdc_path, analog_path, bsp_path, tdc, analog, all_off
        )
        all_off_content = render_all_off_header(
            tdc_path, analog_path, bsp_path, tdc, analog, all_off
        )
        schema_content = render_schema_header(
            param_info, bsp_path, host_schema_path
        )
        ok = write_or_check(args.beamtime_header, beamtime_content, args.check)
        ok &= write_or_check(args.all_off_header, all_off_content, args.check)
        ok &= write_or_check(args.schema_header, schema_content, args.check)
        return 0 if ok else 1
    except (ET.ParseError, OSError, RuntimeError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
