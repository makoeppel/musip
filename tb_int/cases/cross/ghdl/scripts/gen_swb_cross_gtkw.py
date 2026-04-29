#!/usr/bin/env python3
"""Generate a packet-evidence GTKWave save file for the GHDL cross fixture."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


CASES = [
    ("B001", 1, "BASIC"),
    ("B046", 46, "BASIC"),
    ("P123", 2123, "PROF"),
    ("X111", 3111, "ERROR"),
    ("C001", 4001, "CSR"),
]

CASE_INDEXES = {idx: case_id for idx, (case_id, _code, _bucket) in enumerate(CASES)}

BUCKETS = {
    0: "BASIC",
    1: "EDGE",
    2: "PROF",
    3: "ERROR",
    4: "CSR",
}

FLOW_STATES = {
    0: "RESET",
    1: "CASE_SOP",
    2: "INGRESS",
    3: "OPQ_JOIN_WAIT",
    4: "DMA_BACKPRESSURE",
    5: "CASE_EOP",
    6: "DONE",
}

WORD_KINDS = {
    0: "IDLE",
    1: "SOP_HEADER",
    2: "TS_HIGH",
    3: "TS_LOW_PKG",
    4: "DEBUG0_COUNTS",
    5: "DEBUG1_TS",
    6: "SUBHEADER",
    7: "HIT",
    8: "EOP_TRAILER",
    9: "HEADER_ERROR",
    10: "SUBHEADER_ERROR",
    11: "HIT_ERROR",
    12: "DMA_HIT_PAYLOAD",
}

DATAK_CODES = {
    0: "DATA",
    1: "K_BYTE0",
}

HEADER_IDS = {
    0: "NONE",
    7: "SC_CTRL",
    11: "BAD_UNSUPPORTED",
    52: "TILE",
    56: "SCIFI",
    58: "MUPIX",
}

LANES = {
    0: "LANE0",
    1: "LANE1",
    2: "LANE2",
    3: "LANE3",
}

PROVENANCE = {
    0: "LANE0",
    1: "LANE1",
    2: "LANE2",
    3: "LANE3",
    4: "MERGED",
    5: "UNKNOWN",
}

CSR_REGS = {
    0: "NONE",
    1: "UID",
    2: "META",
    3: "LANE_MASK",
    4: "CTRL",
    5: "STATUS",
    6: "CAP",
    7: "FT_WR_HDR",
    8: "FT_WR_SHD",
    9: "FT_WR_HIT",
    10: "FT_RD_HDR",
    11: "FT_RD_SHD",
    12: "FT_RD_HIT",
    13: "FT_DROP_HDR",
    14: "FT_DROP_SHD",
    15: "FT_DROP_HIT",
    16: "LANE_WR_HDR",
    17: "LANE_WR_SHD",
    18: "LANE_WR_HIT",
    19: "LANE_RD_HDR",
    20: "LANE_RD_SHD",
    21: "LANE_RD_HIT",
    22: "LANE_DROP_HDR",
    23: "LANE_DROP_SHD",
    24: "LANE_DROP_HIT",
    25: "LANE_CREDIT",
    26: "TICKET_CREDIT",
    27: "DRR_ALLOWANCE",
    28: "DRR_QUANTUM",
    29: "DRR_GRANT_CNT",
    30: "DRR_BEAT_CNT",
    31: "DRR_DEFER_CNT",
}

GROUP_DESCRIPTION_PATTERNS = [
    (r"00 Clock \+ Reset", "Simulation timebase, reset, and run-active envelope."),
    (r"01 Scenario \+ Runtime Controls", "Case identity, bucket, flow state, frame cadence, and runtime lane-mask commands."),
    (r"02 Ingress Packets: Four Lanes Into OPQ", "Four 36-bit FEB packet streams entering OPQ; bit N of vector handshakes corresponds to lane N."),
    (r"RX lane\d+", "One ingress lane packet stream with raw 36-bit word, packet-kind enum, timestamp, and decoded header/subheader/hit fields."),
    (r".* header fields", "Header-only bit slices; meaningful when packet kind is SOP_HEADER or HEADER_ERROR."),
    (r".* frame/debug fields", "Timestamp, package counter, declared subheader count, declared hit count, and dispatch/debug timestamp words."),
    (r".* subheader fields", "Collapsed subheader bit slices; expand when packet kind is SUBHEADER or SUBHEADER_ERROR."),
    (r".* hit fields", "Hit payload interpretations for MuPix plus SciFi/Tile layouts; no source-lane field is inferred from payload bits."),
    (r"03 OPQ egress packet", "Single merged OPQ packet stream after page-table ordering; provenance is MERGED unless an explicit sideband exists."),
    (r"04 OPQ Internal Dataflow", "Diagnostic annotations for ingress accept, ticket allocation, mover page writes, page RAM, and presenter handoff."),
    (r"04a OPQ DRR / Credit Scheduler", "DRR scheduler request, eligible, grant, lock/defer, selected lane, allowance, and quantum rows."),
    (r"04b OPQ FIFO Fill Levels", "Pointer-derived FIFO fill, credits, page occupancy, and aggregate fill-level statistics."),
    (r"05 DMA payload sample", "Downstream DMA sample of OPQ hit payloads only; not a full packet stream."),
    (r"05 DMA payload sample hit payload fields", "DMA hit payload decode rows using the same payload bit layout as OPQ hit fields."),
    (r"A0 Diagnostics", "Harness diagnostics and scoreboard status that explain case boundaries, stalls, inferred loss, and pass state."),
    (r"A1 Derived Statistics / Loss Ledger", "Model-aligned offered/accepted/transmitted counters plus controlled/asserted/inferred drop tiers."),
    (r"A1b CSR Counter Values", "Live CSR-style counter mirrors for frame-table and per-lane write/read/drop accounting."),
    (r"A2 CSR Map / JTAG Read Bus", "Synthetic JTAG CSR transaction bus and decoded register identity for CSR readback cases."),
]

SIGNAL_DESCRIPTION_PATTERNS = [
    (r"clk$", "Fixture clock."),
    (r"reset_n$", "Active-low reset, deasserted after the initial reset window."),
    (r"run_active$", "High while the cross-run sequence is active."),
    (r"cycle_tick", "Global fixture cycle counter."),
    (r"case_tick", "Cycle counter local to the current case."),
    (r"case_index", "Decoded case ordinal: B001, B046, P123, X111, or C001."),
    (r"bucket_id", "Decoded verification bucket for the current case."),
    (r"case_sop|case_eop|segment_reset|bucket_transition", "One-cycle case boundary marker."),
    (r"frame_slot", "Pulse at the configured 0x800 timestamp-domain frame interval."),
    (r"flow_state", "Decoded high-level harness state."),
    (r"lane_mask_cmd_", "CSR-style lane-mask command pulse/value."),
    (r"lane_mask", "Live runtime lane enable mask; bit N controls lane N."),
    (r"lane_valid|lane_ready|lane_fire", "Per-lane ingress handshake vector; bit N is lane N."),
    (r"ingress_words", "Accepted ingress beat count across all enabled lanes."),
    (r"lane\d+_datak", "Decoded 4-bit K-code qualifier for the ingress word."),
    (r"lane\d+_word_kind", "Decoded packet word kind from the replay event stream."),
    (r"lane\d+_word", "Raw 36-bit ingress word: datak[35:32] concatenated with data[31:0]."),
    (r"lane\d+_data", "Raw 32-bit ingress payload word."),
    (r"lane\d+_source_lane", "Ingress lane tag carried by the replay event metadata."),
    (r"lane\d+_frame_ts", "Decoded 48-bit frame timestamp assembled from timestamp-high and timestamp-low words."),
    (r"lane\d+_header_id", "Decoded packet type field data[31:26]."),
    (r"lane\d+_hit_low", "Low 16 bits of the current ingress hit payload."),
    (r"opq_datak", "Decoded 4-bit K-code qualifier for the OPQ egress word."),
    (r"opq_word_kind", "Decoded OPQ packet word kind."),
    (r"opq_word", "Raw 36-bit OPQ egress word: datak[35:32] concatenated with data[31:0]."),
    (r"opq_data", "Raw 32-bit OPQ egress payload word."),
    (r"opq_lane_provenance", "Merged-stream provenance annotation; MERGED means no source-lane sideband is contractual."),
    (r"opq_frame_ts", "Decoded 48-bit OPQ frame timestamp."),
    (r"opq_header_id", "Decoded OPQ packet type field data[31:26]."),
    (r"opq_hit_low", "Low 16 bits of the current OPQ hit payload."),
    (r"opq_ingress_accept", "Per-lane accepted ingress beat vector after runtime mask."),
    (r"opq_ticket_push", "Per-lane diagnostic ticket ownership event for headers/subheaders."),
    (r"opq_allocator_req|opq_allocator_grant", "Allocator request/grant diagnostic handshake."),
    (r"opq_allocator_ticket_", "Allocator ticket metadata for the granted lane and synthetic ticket id."),
    (r"opq_mover_cmd_", "Mover command diagnostic handshake, selected lane, and page id."),
    (r"opq_mover_data_valid", "Mover data phase diagnostic valid pulse."),
    (r"opq_page_ram_", "Diagnostic page-RAM write-enable/address/data or occupancy row."),
    (r"opq_presenter_", "Presenter egress valid/ready diagnostic handshake."),
    (r"opq_drr_req_raw", "Per-lane raw DRR request before eligibility gating."),
    (r"opq_drr_req_eligible", "Per-lane DRR request after credit/backpressure eligibility."),
    (r"opq_drr_grant", "One-hot DRR grant; identifies the lane drained this cycle."),
    (r"opq_drr_lock_event", "DRR lock/grant event annotation."),
    (r"opq_drr_defer_event", "DRR defer event annotation when a raw request cannot be granted."),
    (r"opq_drr_selected_lane", "Decoded lane selected by the DRR grant."),
    (r"opq_drr_allowance\d", "Configured DRR allowance for the lane."),
    (r"opq_drr_quantum\d", "Live DRR quantum/credit for the lane."),
    (r"opq_lane\d+_fifo_usedw", "Lane FIFO fill derived from displayed write/read pointers with wrap."),
    (r"opq_lane\d+_fifo_wr_ptr", "Lane FIFO write pointer used to derive usedw."),
    (r"opq_lane\d+_fifo_rd_ptr", "Lane FIFO read pointer used to derive usedw."),
    (r"opq_ticket\d+_fifo_usedw", "Ticket FIFO fill derived from displayed write/read pointers with wrap."),
    (r"opq_ticket\d+_fifo_wr_ptr", "Ticket FIFO write pointer used to derive usedw."),
    (r"opq_ticket\d+_fifo_rd_ptr", "Ticket FIFO read pointer used to derive usedw."),
    (r"opq_lane\d+_credit", "Lane FIFO credit mirror; decreases on accepted lane writes and returns on mover service."),
    (r"opq_ticket\d+_credit", "Ticket FIFO credit mirror; decreases on ticket push and returns on allocator consumption."),
    (r"opq_handle_fifo_usedw", "Diagnostic allocator-handle FIFO occupancy."),
    (r"opq_page_free_count", "Synthetic free-page count derived from page occupancy."),
    (r"dma_datak", "DMA sample K-code qualifier; normally DATA for hit payload rows."),
    (r"dma_word_kind", "Decoded DMA sample kind; hits are tagged DMA_HIT_PAYLOAD."),
    (r"dma_word", "Raw 36-bit DMA sample word."),
    (r"dma_data", "Raw 32-bit DMA hit payload sample."),
    (r"dma_half_full", "Synthetic downstream backpressure marker."),
    (r"dma_wren", "DMA hit-sample write-enable pulse."),
    (r"dma_done", "One-cycle marker after a case drains."),
    (r"expected_words|payload_words|dma_words", "Harness count of expected, payload, or DMA-sampled words."),
    (r"join_pending|inactive_wait|opq_body_hold", "Diagnostic hold/wait marker for skew or join-delay cases."),
    (r"opq_wait_cycles", "Remaining synthetic OPQ wait/hold cycles."),
    (r"reorder_depth", "Diagnostic backlog depth: handle occupancy plus page occupancy."),
    (r"error_expected", "Current case intentionally exercises malformed/error traffic."),
    (r"ghost_count", "End-to-end unexpected-output count; should stay zero in healthy cases."),
    (r"missing_count", "End-to-end inferred missing-hit count after drain; should stay zero for B001."),
    (r"scoreboard_pass", "Per-case scoreboard pass marker after case drain."),
    (r"cases_done", "Number of completed cases."),
    (r"stat_offered_", "Object count offered at lane inputs before masks or error rejection."),
    (r"stat_ingress_", "Object count accepted into the OPQ-side ingress model."),
    (r"stat_egress_", "Object count transmitted on the merged OPQ egress stream."),
    (r"stat_hit_inflight_count", "Live accepted-minus-egress hit backlog."),
    (r"stat_drop_controlled_", "Controlled loss tier: intended/configured drops such as lane masking."),
    (r"stat_drop_asserted_", "Asserted loss tier: local debug-observed drops such as malformed/error-kind rejection."),
    (r"stat_drop_inferred_", "Inferred loss tier: end-to-end missing objects after drain."),
    (r"stat_.*fifo_.*usedw|stat_page_ram_max_usedw", "Aggregate or high-water fill-level statistic."),
    (r"csr_cmd_|csr_read_valid|csr_readdatavalid", "Synthetic JTAG CSR command/read handshake."),
    (r"csr_addr", "CSR byte address for the synthetic JTAG transaction."),
    (r"csr_reg_id", "Decoded CSR register identity for the synthetic read/write."),
    (r"csr_wdata|csr_rdata", "CSR write or read data bus."),
    (r"csr_uid|csr_status|csr_lane_mask_shadow", "CSR mirror register value."),
    (r"csr_ft_", "Frame-table CSR mirror counter."),
    (r"csr_lane\d+_", "Per-lane CSR mirror counter or credit value."),
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--wave-file", required=True, type=Path)
    parser.add_argument("--case-cycles", required=True, type=int)
    parser.add_argument("--clock-period-ns", required=True, type=int)
    parser.add_argument("--scope", default="tb_swb_cross_ghdl")
    return parser.parse_args()


def write_filter(path: Path, mapping: dict[int, str], width: int) -> None:
    path.write_text(
        "\n".join(
            f"{key:0{width}b} {value}" for key, value in sorted(mapping.items())
        )
        + "\n",
        encoding="ascii",
    )


def describe_group(name: str) -> str:
    for pattern, description in GROUP_DESCRIPTION_PATTERNS:
        if re.fullmatch(pattern, name):
            return description
    return "Generated waveform group; see the local display contract for assumptions."


def describe_signal(display_name: str, signal_path: str, group_name: str) -> str:
    target = f"{display_name} {signal_path}".lower()
    for pattern, description in SIGNAL_DESCRIPTION_PATTERNS:
        if re.search(pattern.lower(), target):
            return description
    group_description = describe_group(group_name)
    return f"Signal belongs to this group: {group_description}"


def parse_signal_row(line: str, scope: str) -> tuple[str, str] | None:
    if line.startswith("+{"):
        end_label = line.find("}")
        if end_label < 0:
            return None
        display_name = line[2:end_label]
        signal_path = line[end_label + 2 :]
    elif line.startswith(f"{scope}."):
        signal_path = line
        display_name = signal_path.removeprefix(f"{scope}.")
    else:
        return None

    if not signal_path.startswith(f"{scope}."):
        return None
    return display_name, signal_path.removeprefix(f"{scope}.")


def render_signal_guide(gtkw_text: str, scope: str, guide_path: Path) -> str:
    groups: list[tuple[str, list[tuple[str, str]]]] = []
    current_group = "Ungrouped"
    current_rows: list[tuple[str, str]] = []

    for raw_line in gtkw_text.splitlines():
        line = raw_line.strip()
        if line.startswith("-") and len(line) > 1:
            if current_rows or current_group != "Ungrouped":
                groups.append((current_group, current_rows))
            current_group = line[1:]
            current_rows = []
            continue
        parsed = parse_signal_row(line, scope)
        if parsed is not None:
            current_rows.append(parsed)

    if current_rows or current_group != "Ungrouped":
        groups.append((current_group, current_rows))

    guide_lines = [
        "# OPQ GHDL GTKWave Signal Guide",
        "",
        "Generated with `gen_swb_cross_gtkw.py` next to the GTKWave save file.",
        f"Guide path: `{guide_path}`",
        "",
        "The GHDL fixture is a deterministic waveform/debug harness. Internal",
        "OPQ rows are diagnostic annotations and are interpreted by group below.",
        "",
    ]

    for group_name, rows in groups:
        guide_lines.extend(
            [
                f"## {group_name}",
                "",
                describe_group(group_name),
                "",
            ]
        )
        if not rows:
            continue
        guide_lines.extend(["| Display row | Signal | Description |", "|---|---|---|"])
        seen: set[tuple[str, str]] = set()
        for display_name, signal_path in rows:
            key = (display_name, signal_path)
            if key in seen:
                continue
            seen.add(key)
            guide_lines.append(
                f"| `{display_name}` | `{signal_path}` | {describe_signal(display_name, signal_path, group_name)} |"
            )
        guide_lines.append("")

    return "\n".join(guide_lines).rstrip() + "\n"


def case_markers(case_cycles: int, clock_period_ns: int) -> tuple[list[int], list[str]]:
    reset_cycles = 8
    case_stride = case_cycles + 1
    period_fs = clock_period_ns * 1_000_000
    times = [reset_cycles * period_fs]
    names = ["T00_RESET_DEASSERT"]

    for idx, (case_id, _code, _bucket) in enumerate(CASES, start=1):
        start_cycle = reset_cycles + (idx - 1) * case_stride
        times.append(start_cycle * period_fs)
        names.append(f"T{idx:02d}_{case_id}")

    end_cycle = reset_cycles + len(CASES) * case_stride + 1
    times.append(end_cycle * period_fs)
    names.append(f"T{len(CASES) + 1:02d}_CROSS_DONE")
    return times, names


def group(lines: list[str], name: str, collapsed: bool = False) -> None:
    lines.extend(["@1200" if collapsed else "@200", f"-{name}"])


def signal(
    lines: list[str],
    scope: str,
    name: str,
    attr: str,
    color: int | None = None,
    label: str | None = None,
    filter_file: Path | None = None,
) -> None:
    lines.append(f"@{attr}")
    if color is not None:
        lines.append(f"[color] {color}")
    if filter_file is not None:
        lines.append(f"^1 {filter_file.resolve()}")
    if label is not None:
        lines.append(f"+{{{label}}} {scope}.{name}")
    else:
        lines.append(f"{scope}.{name}")


def enum_signal(
    lines: list[str],
    scope: str,
    name: str,
    label: str,
    filter_file: Path,
    color: int = 5,
) -> None:
    signal(lines, scope, name, "2029", color, f"{label} decoded", filter_file)


def packet_stream(
    lines: list[str],
    scope: str,
    prefix: str,
    title: str,
    word_kind_filter: Path,
    datak_filter: Path,
    header_filter: Path,
    lane_filter: Path,
    *,
    show_source_lane: bool = True,
    provenance_filter: Path | None = None,
    provenance_signal: str | None = None,
) -> None:
    group(lines, title)
    signal(lines, scope, f"{prefix}_word[35:0]", "22", 5, f"{title} word[35:0] raw")
    signal(lines, scope, f"{prefix}_data[31:0]", "22", 5, f"{title} data[31:0] raw")
    enum_signal(lines, scope, f"{prefix}_datak[3:0]", f"{title} datak[35:32]", datak_filter, 5)
    enum_signal(lines, scope, f"{prefix}_word_kind[4:0]", f"{title} packet kind", word_kind_filter, 5)
    if show_source_lane:
        enum_signal(lines, scope, f"{prefix}_source_lane[1:0]", f"{title} ingress lane tag", lane_filter, 0)
    if provenance_filter is not None and provenance_signal is not None:
        enum_signal(lines, scope, provenance_signal, f"{title} packet provenance", provenance_filter, 0)
    signal(lines, scope, f"{prefix}_frame_ts[47:0]", "22", 0, f"{title} frame_ts[47:0] hex")

    group(lines, f"{title} header fields")
    enum_signal(lines, scope, f"{prefix}_header_id[5:0]", f"{title} packet_type[31:26]", header_filter, 0)
    signal(lines, scope, f"{prefix}_data[25:24]", "24", 0, f"{title} header.sc_subtype[1:0]")
    signal(lines, scope, f"{prefix}_data[23:8]", "22", 0, f"{title} header.fpga_id[15:0]")
    signal(lines, scope, f"{prefix}_data[7:0]", "22", 0, f"{title} header.K28.5")

    group(lines, f"{title} frame/debug fields")
    signal(lines, scope, f"{prefix}_data[31:0]", "22", 0, f"{title} ts_high[47:16]")
    signal(lines, scope, f"{prefix}_data[31:16]", "22", 0, f"{title} ts_low[15:0]")
    signal(lines, scope, f"{prefix}_data[15:0]", "24", 4, f"{title} pkg_cnt")
    signal(lines, scope, f"{prefix}_data[30:16]", "24", 4, f"{title} debug0.subheader_count")
    signal(lines, scope, f"{prefix}_data[15:0]", "24", 4, f"{title} debug0.hit_count")
    signal(lines, scope, f"{prefix}_data[30:0]", "22", 0, f"{title} debug1.dispatch_ts")

    group(lines, f"{title} subheader fields", collapsed=True)
    signal(lines, scope, f"{prefix}_data[31:24]", "22", 0, f"{title} subheader.shd_ts")
    signal(lines, scope, f"{prefix}_data[15:8]", "24", 4, f"{title} subheader.hit_count")
    signal(lines, scope, f"{prefix}_data[7:0]", "22", 0, f"{title} subheader.K23.7")

    group(lines, f"{title} hit fields")
    signal(lines, scope, f"{prefix}_data[31:28]", "22", 5, f"{title} hit.ts_low[3:0]")
    signal(lines, scope, f"{prefix}_data[27:22]", "24", 0, f"{title} hit.chip_id[5:0]")
    signal(lines, scope, f"{prefix}_data[21:14]", "24", 5, f"{title} mupix.col[7:0]")
    signal(lines, scope, f"{prefix}_data[13:5]", "24", 5, f"{title} mupix.row[8:0]")
    signal(lines, scope, f"{prefix}_data[4:1]", "24", 5, f"{title} mupix.tot[3:0]")
    signal(lines, scope, f"{prefix}_data[0]", "28", 5, f"{title} mupix.reserved")
    signal(lines, scope, f"{prefix}_data[21:16]", "24", 5, f"{title} scifi_tile.channel_id[5:0]")
    signal(lines, scope, f"{prefix}_data[15:8]", "24", 5, f"{title} scifi_tile.ts_50ps[7:0]")
    signal(lines, scope, f"{prefix}_data[7:0]", "24", 5, f"{title} scifi_tile.energy[7:0]")
    signal(lines, scope, f"{prefix}_hit_low[15:0]", "22", 5, f"{title} hit.low16")


def dma_payload_stream(
    lines: list[str],
    scope: str,
    prefix: str,
    title: str,
    word_kind_filter: Path,
    datak_filter: Path,
) -> None:
    group(lines, title)
    signal(lines, scope, f"{prefix}_word[35:0]", "22", 5, f"{title} word[35:0] raw")
    signal(lines, scope, f"{prefix}_data[31:0]", "22", 5, f"{title} data[31:0] raw")
    enum_signal(lines, scope, f"{prefix}_datak[3:0]", f"{title} datak[35:32]", datak_filter, 5)
    enum_signal(lines, scope, f"{prefix}_word_kind[4:0]", f"{title} payload kind", word_kind_filter, 5)
    group(lines, f"{title} hit payload fields")
    signal(lines, scope, f"{prefix}_data[31:28]", "22", 5, f"{title} hit.ts_low[3:0]")
    signal(lines, scope, f"{prefix}_data[27:22]", "24", 0, f"{title} hit.chip_id[5:0]")
    signal(lines, scope, f"{prefix}_data[21:14]", "24", 5, f"{title} mupix.col[7:0]")
    signal(lines, scope, f"{prefix}_data[13:5]", "24", 5, f"{title} mupix.row[8:0]")
    signal(lines, scope, f"{prefix}_data[4:1]", "24", 5, f"{title} mupix.tot[3:0]")
    signal(lines, scope, f"{prefix}_data[21:16]", "24", 5, f"{title} scifi_tile.channel_id[5:0]")
    signal(lines, scope, f"{prefix}_data[15:8]", "24", 5, f"{title} scifi_tile.ts_50ps[7:0]")
    signal(lines, scope, f"{prefix}_data[7:0]", "24", 5, f"{title} scifi_tile.energy[7:0]")


def render_gtkw(args: argparse.Namespace) -> str:
    out_dir = args.out.parent
    case_index_filter = out_dir / "case_index_filter.txt"
    bucket_filter = out_dir / "bucket_filter.txt"
    flow_filter = out_dir / "flow_state_filter.txt"
    word_kind_filter = out_dir / "word_kind_filter.txt"
    datak_filter = out_dir / "datak_filter.txt"
    header_filter = out_dir / "header_id_filter.txt"
    lane_filter = out_dir / "lane_filter.txt"
    provenance_filter = out_dir / "provenance_filter.txt"
    csr_filter = out_dir / "csr_reg_filter.txt"

    write_filter(case_index_filter, CASE_INDEXES, 8)
    write_filter(bucket_filter, BUCKETS, 4)
    write_filter(flow_filter, FLOW_STATES, 4)
    write_filter(word_kind_filter, WORD_KINDS, 5)
    write_filter(datak_filter, DATAK_CODES, 4)
    write_filter(header_filter, HEADER_IDS, 6)
    write_filter(lane_filter, LANES, 2)
    write_filter(provenance_filter, PROVENANCE, 3)
    write_filter(csr_filter, CSR_REGS, 8)

    marker_times, marker_names = case_markers(args.case_cycles, args.clock_period_ns)
    marker_line = "*0.000000 " + " ".join(str(time) for time in marker_times)
    marker_line += " " + " ".join("-1" for _ in range(max(0, 27 - len(marker_times))))

    scope = args.scope
    lines = [
        "[*]",
        "[*] GTKWave Analyzer v3.3.121",
        "[*] MuSiP GHDL packet-level OPQ evidence view",
        "[*] See the generated *_signal_guide.md beside this save file for row descriptions.",
        "[*]",
        f"[dumpfile] \"{args.wave_file.resolve()}\"",
        f"[savefile] \"{args.out.resolve()}\"",
        "[timestart] 0",
        "[size] 1800 1100",
        "[pos] -1 -1",
        marker_line,
    ]
    lines.extend(f"[markername_long] {name}" for name in marker_names)
    lines.extend(
        [
            f"[treeopen] {scope}.",
            "[sst_width] 280",
            "[signals_width] 390",
            "[sst_expanded] 1",
            "[sst_vpaned_height] 300",
        ]
    )

    group(lines, "00 Clock + Reset")
    signal(lines, scope, "clk", "28", 0)
    signal(lines, scope, "reset_n", "28", 1)
    signal(lines, scope, "cycle_tick[31:0]", "24", 0)
    signal(lines, scope, "run_active", "28", 0)

    group(lines, "01 Scenario + Runtime Controls")
    signal(lines, scope, "case_index[7:0]", "2029", 0, "case_index decoded", case_index_filter)
    enum_signal(lines, scope, "bucket_id[3:0]", "bucket_id", bucket_filter, 0)
    enum_signal(lines, scope, "flow_state[3:0]", "flow_state", flow_filter, 5)
    signal(lines, scope, "case_tick[31:0]", "24", 4)
    signal(lines, scope, "case_sop", "28", 3)
    signal(lines, scope, "case_eop", "28", 3)
    signal(lines, scope, "frame_slot", "28", 3)
    signal(lines, scope, "lane_mask[3:0]", "08", 0, "lane_mask live")
    signal(lines, scope, "lane_mask_cmd_valid", "28", 3)
    signal(lines, scope, "lane_mask_cmd_value[3:0]", "08", 0)

    group(lines, "02 Ingress Packets: Four Lanes Into OPQ")
    signal(lines, scope, "lane_valid[3:0]", "08", 3)
    signal(lines, scope, "lane_ready[3:0]", "08", 3)
    signal(lines, scope, "lane_fire[3:0]", "08", 3)
    signal(lines, scope, "ingress_words[31:0]", "24", 4)
    signal(lines, scope, "ingress_words[31:0]", "8024", 4, "ingress_words analog")
    for lane in range(4):
        packet_stream(
            lines,
            scope,
            f"lane{lane}",
            f"RX lane{lane}",
            word_kind_filter,
            datak_filter,
            header_filter,
            lane_filter,
        )

    packet_stream(
        lines,
        scope,
        "opq",
        "03 OPQ egress packet",
        word_kind_filter,
        datak_filter,
        header_filter,
        lane_filter,
        show_source_lane=False,
        provenance_filter=provenance_filter,
        provenance_signal="opq_lane_provenance[2:0]",
    )

    group(lines, "04 OPQ Internal Dataflow")
    signal(lines, scope, "opq_ingress_accept[3:0]", "08", 3)
    signal(lines, scope, "opq_ticket_push[3:0]", "08", 3)
    signal(lines, scope, "opq_allocator_req[3:0]", "08", 3)
    signal(lines, scope, "opq_allocator_grant", "28", 3)
    signal(lines, scope, "opq_allocator_grant_lane[3:0]", "08", 3)
    signal(lines, scope, "opq_allocator_ticket_valid", "28", 3)
    enum_signal(lines, scope, "opq_allocator_ticket_lane[1:0]", "allocator.ticket_lane", lane_filter, 0)
    signal(lines, scope, "opq_allocator_ticket_id[15:0]", "24", 0)
    signal(lines, scope, "opq_mover_cmd_valid", "28", 3)
    signal(lines, scope, "opq_mover_cmd_ready", "28", 3)
    enum_signal(lines, scope, "opq_mover_cmd_lane[1:0]", "mover.cmd_lane", lane_filter, 0)
    signal(lines, scope, "opq_mover_cmd_page[15:0]", "24", 0)
    signal(lines, scope, "opq_mover_data_valid", "28", 3)
    signal(lines, scope, "opq_page_ram_we", "28", 3)
    signal(lines, scope, "opq_page_ram_waddr[15:0]", "24", 0)
    signal(lines, scope, "opq_page_ram_wdata[35:0]", "22", 5)
    signal(lines, scope, "opq_presenter_valid", "28", 3)
    signal(lines, scope, "opq_presenter_ready", "28", 3)

    group(lines, "04a OPQ DRR / Credit Scheduler")
    signal(lines, scope, "opq_drr_req_raw[3:0]", "08", 3)
    signal(lines, scope, "opq_drr_req_eligible[3:0]", "08", 3)
    signal(lines, scope, "opq_drr_grant[3:0]", "08", 3)
    signal(lines, scope, "opq_drr_lock_event[3:0]", "08", 3)
    signal(lines, scope, "opq_drr_defer_event[3:0]", "08", 1)
    enum_signal(lines, scope, "opq_drr_selected_lane[1:0]", "drr.selected_lane", lane_filter, 0)
    for name in (
        "opq_drr_allowance0[9:0]",
        "opq_drr_allowance1[9:0]",
        "opq_drr_allowance2[9:0]",
        "opq_drr_allowance3[9:0]",
        "opq_drr_quantum0[9:0]",
        "opq_drr_quantum1[9:0]",
        "opq_drr_quantum2[9:0]",
        "opq_drr_quantum3[9:0]",
    ):
        signal(lines, scope, name, "24", 4)

    group(lines, "04b OPQ FIFO Fill Levels")
    for lane in range(4):
        usedw = f"opq_lane{lane}_fifo_usedw[10:0]"
        signal(lines, scope, usedw, "24", 4)
        signal(lines, scope, usedw, "8024", 4, f"{usedw} analog")
        signal(lines, scope, f"opq_lane{lane}_fifo_wr_ptr[10:0]", "24", 4)
        signal(lines, scope, f"opq_lane{lane}_fifo_rd_ptr[10:0]", "24", 4)
    for lane in range(4):
        usedw = f"opq_ticket{lane}_fifo_usedw[10:0]"
        signal(lines, scope, usedw, "24", 4)
        signal(lines, scope, usedw, "8024", 4, f"{usedw} analog")
        signal(lines, scope, f"opq_ticket{lane}_fifo_wr_ptr[10:0]", "24", 4)
        signal(lines, scope, f"opq_ticket{lane}_fifo_rd_ptr[10:0]", "24", 4)
    for name in (
        "opq_lane0_credit[10:0]",
        "opq_lane1_credit[10:0]",
        "opq_lane2_credit[10:0]",
        "opq_lane3_credit[10:0]",
        "opq_ticket0_credit[10:0]",
        "opq_ticket1_credit[10:0]",
        "opq_ticket2_credit[10:0]",
        "opq_ticket3_credit[10:0]",
        "opq_handle_fifo_usedw[10:0]",
        "opq_page_ram_usedw[15:0]",
        "opq_page_free_count[15:0]",
        "stat_lane_fifo_total_usedw[15:0]",
        "stat_lane_fifo_max_usedw[10:0]",
        "stat_ticket_fifo_total_usedw[15:0]",
        "stat_ticket_fifo_max_usedw[10:0]",
        "stat_page_ram_max_usedw[15:0]",
    ):
        signal(lines, scope, name, "24", 4)
        signal(lines, scope, name, "8024", 4, f"{name} analog")

    dma_payload_stream(
        lines,
        scope,
        "dma",
        "05 DMA payload sample",
        word_kind_filter,
        datak_filter,
    )
    signal(lines, scope, "dma_half_full", "28", 1)
    signal(lines, scope, "dma_wren", "28", 3)
    signal(lines, scope, "dma_done", "28", 3)
    signal(lines, scope, "expected_words[31:0]", "24", 4)
    signal(lines, scope, "payload_words[31:0]", "24", 4)
    signal(lines, scope, "dma_words[31:0]", "24", 4)
    signal(lines, scope, "dma_words[31:0]", "10024", 4, "dma_words analog")

    group(lines, "A0 Diagnostics")
    signal(lines, scope, "segment_reset", "28", 1)
    signal(lines, scope, "bucket_transition", "28", 5)
    signal(lines, scope, "join_pending", "28", 5)
    signal(lines, scope, "inactive_wait", "28", 5)
    signal(lines, scope, "opq_body_hold", "28", 3)
    signal(lines, scope, "opq_wait_cycles[15:0]", "24", 4)
    signal(lines, scope, "opq_wait_cycles[15:0]", "8024", 4, "opq_wait_cycles analog")
    signal(lines, scope, "reorder_depth[15:0]", "24", 4)
    signal(lines, scope, "reorder_depth[15:0]", "8024", 4, "reorder_depth analog")
    signal(lines, scope, "error_expected", "28", 1)
    signal(lines, scope, "ghost_count[15:0]", "24", 1)
    signal(lines, scope, "missing_count[15:0]", "24", 1)
    signal(lines, scope, "scoreboard_pass", "28", 3)
    signal(lines, scope, "cases_done[7:0]", "24", 4)

    group(lines, "A1 Derived Statistics / Loss Ledger")
    for name in (
        "stat_offered_frame_count[31:0]",
        "stat_offered_subframe_count[31:0]",
        "stat_offered_hit_count[31:0]",
        "stat_ingress_frame_count[31:0]",
        "stat_ingress_subframe_count[31:0]",
        "stat_ingress_hit_count[31:0]",
        "stat_egress_frame_count[31:0]",
        "stat_egress_subframe_count[31:0]",
        "stat_egress_hit_count[31:0]",
        "stat_hit_inflight_count[31:0]",
        "stat_drop_controlled_frame[31:0]",
        "stat_drop_controlled_subframe[31:0]",
        "stat_drop_controlled_hit[31:0]",
        "stat_drop_asserted_frame[31:0]",
        "stat_drop_asserted_subframe[31:0]",
        "stat_drop_asserted_hit[31:0]",
        "stat_drop_inferred_frame[31:0]",
        "stat_drop_inferred_subframe[31:0]",
        "stat_drop_inferred_hit[31:0]",
    ):
        signal(lines, scope, name, "24", 4)
        signal(lines, scope, name, "10024", 4, f"{name} analog")

    group(lines, "A1b CSR Counter Values")
    for name in (
        "csr_ft_wr_header[31:0]",
        "csr_ft_wr_subheader[31:0]",
        "csr_ft_wr_hit[31:0]",
        "csr_ft_rd_header[31:0]",
        "csr_ft_rd_subheader[31:0]",
        "csr_ft_rd_hit[31:0]",
        "csr_ft_drop_header[31:0]",
        "csr_ft_drop_subheader[31:0]",
        "csr_ft_drop_hit[31:0]",
        "csr_lane0_accept_cnt[31:0]",
        "csr_lane1_accept_cnt[31:0]",
        "csr_lane2_accept_cnt[31:0]",
        "csr_lane3_accept_cnt[31:0]",
        "csr_lane0_drop_cnt[31:0]",
        "csr_lane1_drop_cnt[31:0]",
        "csr_lane2_drop_cnt[31:0]",
        "csr_lane3_drop_cnt[31:0]",
    ):
        signal(lines, scope, name, "24", 4)
    for lane in range(4):
        for suffix in (
            "wr_hdr",
            "wr_shd",
            "wr_hit",
            "rd_hdr",
            "rd_shd",
            "rd_hit",
            "drop_hdr",
            "drop_shd",
            "drop_hit",
        ):
            signal(lines, scope, f"csr_lane{lane}_{suffix}_cnt[31:0]", "24", 4)

    group(lines, "A2 CSR Map / JTAG Read Bus")
    signal(lines, scope, "csr_cmd_valid", "28", 3)
    signal(lines, scope, "csr_cmd_write", "28", 3)
    signal(lines, scope, "csr_read_valid", "28", 3)
    signal(lines, scope, "csr_readdatavalid", "28", 3)
    signal(lines, scope, "csr_addr[15:0]", "22", 0)
    enum_signal(lines, scope, "csr_reg_id[7:0]", "csr_reg", csr_filter, 0)
    signal(lines, scope, "csr_wdata[31:0]", "22", 5)
    signal(lines, scope, "csr_rdata[31:0]", "22", 5)
    signal(lines, scope, "csr_uid[31:0]", "22", 0)
    signal(lines, scope, "csr_status[31:0]", "22", 0)
    signal(lines, scope, "csr_lane_mask_shadow[3:0]", "08", 0)

    lines.extend(["[pattern_trace] 1", "[pattern_trace] 0"])
    return "\n".join(lines) + "\n"


def main() -> int:
    args = parse_args()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    gtkw_text = render_gtkw(args)
    args.out.write_text(gtkw_text, encoding="ascii")
    guide_path = args.out.with_name(f"{args.out.stem}_signal_guide.md")
    guide_path.write_text(render_signal_guide(gtkw_text, args.scope, guide_path), encoding="ascii")
    print(f"wrote {args.out}")
    print(f"wrote {guide_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
