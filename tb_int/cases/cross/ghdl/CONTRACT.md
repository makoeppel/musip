# GHDL OPQ Packet Display Contract

This file is the local contract for `tb_swb_cross_ghdl.vhd`, the replay
generators, the GTKWave save file, and the timing/content comparison scripts.
It is intentionally stricter than a visual smoke test: rows in the waveform must
either represent a real Mu3e/OPQ contract signal or be labelled as a diagnostic
model annotation.

## Mu3e Data Packet Structure

Each displayed stream word is 36 bits:

| Bits | Name | Meaning |
|---:|---|---|
| `[35:32]` | `datak` | K-code byte qualifier. `0x1` means byte 0 is a control byte. |
| `[31:0]` | `data` | Mu3e front-end packet payload word. |

Packet framing follows the Mu3e front-end data packet format:

| Word | Required decode |
|---|---|
| Preamble/header | `datak=0x1`, `data[7:0]=K28.5=0xBC`; `data[31:26]` is packet type, `data[25:24]` is slow-control subtype when applicable, `data[23:8]` is FPGA ID. |
| Timestamp high | `frame_ts[47:16]` |
| Timestamp low/package count | `data[31:16]=frame_ts[15:0]`, `data[15:0]=package counter` |
| Debug/count word | subheader count and hit count for the frame |
| Dispatch/debug timestamp | diagnostic send timestamp |
| Subheader | `datak=0x1`, `data[7:0]=K23.7=0xF7`, `data[31:24]=ts[11:4]`, overflow/count fields in the body |
| Hit | `datak=0x0`, layout depends on packet type |
| Trailer | `datak=0x1`, `data[7:0]=K28.4=0x9C` |

Hit decode shown in GTKWave must not invent a source-lane field. Common bits are
decoded as `ts_low[3:0]=data[31:28]` and `chip_id[5:0]=data[27:22]`.
MuPix rows use `col[7:0]=data[21:14]`, `row[8:0]=data[13:5]`,
`tot[3:0]=data[4:1]`. SciFi/Tile rows use `channel_id[5:0]=data[21:16]`,
`ts_50ps[7:0]=data[15:8]`, and `energy[7:0]=data[7:0]`.

## Timing Guard

The BASIC B001 evidence case is the reference timing guard:

| Requirement | Contract |
|---|---|
| Frame count | At least three complete ingress frames and three complete OPQ egress frames. |
| Lane skew | B001 ingress lane SOPs are aligned across lanes for every checked frame. |
| Frame distance | Lane header timestamps advance by `0x800` ticks in the 8 ns timestamp domain. At a 4 ns GHDL clock this is `4096` cycles between frame headers. |
| Egress after page commit | First OPQ egress SOP must occur after all four lanes have completed the corresponding ingress frame and after page-RAM writes for that frame have become inactive. |
| Packet integrity | OPQ egress must preserve legal packet grammar and match the expected merged frame contents: header timestamp, header count fields, subheader count fields, and hit payload multiset. |

SOP/EOP cycle spacing alone is not enough evidence. The compare script must also
parse packet contents and timestamps.

## OPQ Dataflow Display Assumptions

The GHDL fixture is a scheduled replay/debug harness, not the signoff DUT.
Internal OPQ rows are therefore diagnostic annotations that must qualitatively
match the native-SV OPQ contract:

| Display family | Expected qualitative behavior |
|---|---|
| Ingress accept | Per-lane accepted beats follow lane valid and runtime lane mask. |
| Ticket/allocator | Ticket requests come from header/subheader ownership events; grants are one-lane transactions, not a level tied to every ingress beat. |
| DRR/mover | Raw requests can remain high while lane data is pending; grants/lock events identify selected lanes and should visibly rotate under multi-lane traffic. |
| Credits | Lane credit decreases on accepted lane-FIFO writes and returns on mover service. Ticket credit decreases on ticket push and returns on allocator consumption. |
| FIFO fill levels | `*_fifo_usedw` rows are derived from displayed write and read pointers as `(wr_ptr - rd_ptr) mod depth`; they are not independent counters. This is required so a drained FIFO visibly returns to zero after its read pointer catches its write pointer, including wrap cases. |
| Page RAM | `page_ram_we/waddr/wdata` model mover commits into page RAM, not raw ingress acceptance. The write-enable must close after all active lanes finish the current frame and remain low while the presenter emits the corresponding OPQ packet. |
| Egress provenance | The OPQ egress stream is a merged packet stream with no contractual per-packet source-lane sideband. The GTKWave row is labelled `MERGED`/`UNKNOWN`; per-hit fields come only from the Mu3e hit payload layout. |
| DMA sample | DMA rows show hit payload only and must not show header/subheader fields as if they were a packet stream. |

## Statistics / Loss Ledger

Appendix A1 mirrors the `model/` loss-evidence ladder:

| Tier | GTKWave rows | Meaning |
|---|---|---|
| Controlled loss | `stat_drop_controlled_*` | Intended/configured loss, such as runtime lane masking. |
| Asserted loss | `stat_drop_asserted_*` | Local debug-observed loss, such as malformed/error-kind packet rejection and frame-table drop accounting. |
| Inferred loss | `stat_drop_inferred_*`, `missing_count` | End-to-end scoreboard missing objects after the run has drained. These rows should stay zero for the B001 packet-integrity evidence case. |

The live counters deliberately separate input and output cardinality:
`stat_ingress_frame_count` counts lane-local accepted headers, while
`stat_egress_frame_count` counts merged output packet headers. These are not
expected to be one-to-one. Hits are expected to be one-to-one after drain, so
`stat_hit_inflight_count = stat_ingress_hit_count - stat_egress_hit_count`
is the live backlog handle for correlating accepted hits to egress hits.

## CSR Display Assumptions

CSR addresses in Appendix A2 use byte offsets from the SVD/JTAG view:

- common registers: `UID=0x000`, `META=0x004`, `LANE_MASK=0x008`,
  `CTRL=0x00C`, `STATUS=0x010`, `CAP=0x014`.
- frame-table counters: `FT_WR_HDR=0x020` through `FT_DROP_HIT=0x040`.
- per-lane windows: lane base `0x100 + lane * 0x40`, with word offsets
  `WR_HDR`, `WR_SHD`, `WR_HIT`, `RD_HDR`, `RD_SHD`, `RD_HIT`,
  `DROP_HDR`, `DROP_SHD`, `DROP_HIT`, `LANE_CREDIT`, `TICKET_CREDIT`,
  `DRR_ALLOWANCE`, `DRR_QUANTUM`, `DRR_GRANT_CNT`, `DRR_BEAT_CNT`,
  and `DRR_DEFER_CNT`.

Counters in Appendix A1 should move during traffic rather than acting as static
labels. `STATUS` mirrors the native-SV status fields: lane-mask shadow,
allocator busy, arbiter busy, presenter busy, effective mask, and lane count.
