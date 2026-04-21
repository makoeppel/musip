#!/usr/bin/env python3
"""Policy-aware RTL lint for maintained MuSiP files, benches, and snapshots.

Clean-room maintained files are checked against the local rtl-writing house
rules. Legacy touched files, benches, and imported OPQ snapshot files are
checked with a lighter hygiene policy instead of forcing broad formatting
rewrites in an integration branch.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RTL_STYLE_CHECK = Path.home() / ".codex/skills/rtl-writing/scripts/rtl_style_check.py"

STRICT_FILES = [
    ROOT / "firmware/a10_board/a10/merger/ingress_egress_adaptor.vhd",
    ROOT / "tb_int/cases/basic/uvm/dut/swb_block_uvm_wrapper.vhd",
]

HYGIENE_FILES = [
    ROOT / "firmware/a10_board/a10/swb/musip_mux_4_1.vhd",
    ROOT / "firmware/a10_board/a10/swb/swb_block.vhd",
    ROOT / "tb_int/cases/basic/plain/tb_swb_block_plain_replay.vhd",
    ROOT / "tb_int/cases/basic/plain_2env/dut/swb_datapath_2env_wrapper.vhd",
    ROOT / "tb_int/cases/basic/plain_2env/sv/swb_2env_boundary_scoreboard.sv",
    ROOT / "tb_int/cases/basic/plain_2env/sv/swb_opq_boundary_contract_sva.sv",
    ROOT / "tb_int/cases/basic/plain_2env/formal/swb_opq_boundary_formal_top.sv",
    ROOT / "firmware/a10_board/a10/merger/opq_monolithic_4lane_merge_opq_0.vhd",
    ROOT / "firmware/a10_board/a10/merger/ticket_fifo.v",
    ROOT / "firmware/a10_board/a10/merger/lane_fifo.v",
    ROOT / "firmware/a10_board/a10/merger/handle_fifo.v",
    ROOT / "firmware/a10_board/a10/merger/page_ram.v",
    ROOT / "firmware/a10_board/a10/merger/tile_fifo.v",
]


def run_house_style(path: Path) -> bool:
    result = subprocess.run(
        ["python3", str(RTL_STYLE_CHECK), str(path)],
        cwd=ROOT,
        check=False,
    )
    return result.returncode == 0


def check_snapshot_hygiene(path: Path) -> list[str]:
    data = path.read_bytes()
    issues: list[str] = []

    if b"\r" in data:
        issues.append("contains CR characters; keep snapshot sources LF-only")
    if not data.endswith(b"\n"):
        issues.append("missing trailing newline")
    if b"\x00" in data:
        issues.append("contains NUL bytes")

    decoded = data.decode("utf-8", errors="replace")
    for line_no, line in enumerate(decoded.splitlines(), start=1):
        if (
            line.startswith("<<<<<<<")
            or line.startswith("=======")
            or line.startswith(">>>>>>>")
        ):
            issues.append(f"line {line_no}: contains merge-conflict marker")
            break
        if line.rstrip(" \t") != line:
            issues.append(f"line {line_no}: trailing whitespace")
            break

    return issues


def main() -> int:
    ok = True

    print("Maintained RTL house-style checks:")
    for path in STRICT_FILES:
        if not run_house_style(path):
            ok = False

    print("\nLegacy, bench, and snapshot hygiene checks:")
    for path in HYGIENE_FILES:
        issues = check_snapshot_hygiene(path)
        if issues:
            ok = False
            for issue in issues:
                print(f"{path}: hygiene: {issue}")
        else:
            print(f"{path}: hygiene: PASS")

    if not ok:
        print("\nlint_rtl.py: FAIL")
        return 1

    print("\nlint_rtl.py: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
