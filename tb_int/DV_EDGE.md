# DV_EDGE.md — tb_int (MuSiP SWB/OPQ integration)

**Companion:** [`DV_INT_PLAN.md`](DV_INT_PLAN.md) · [`DV_INT_HARNESS.md`](DV_INT_HARNESS.md) · [`DV_BASIC.md`](DV_BASIC.md) · [`DV_COV.md`](DV_COV.md) · [`DV_REPORT.md`](DV_REPORT.md) · [`BUG_HISTORY.md`](BUG_HISTORY.md)
**Canonical ID range:** `E001`–`E129`
**Intent:** boundary, timing, arbitration, and K-char-hazard corners of the SWB+OPQ integration contract. Every case targets a specific field bit or framing edge in the per-lane FEB AvST grammar (see [`DV_BASIC.md`](DV_BASIC.md) §Stimulus field map) or a specific boundary in the OPQ / `musip_mux_4_1` / `musip_event_builder` pipeline.
**Stimulus source:** same FEB `aso_hit_type3` AvST grammar emitted by `feb_frame_assembly.vhd`; edge cases alter specific bits or injector timings rather than the grammar shape itself.

## Method / implementation legend

- **method** — `D` = directed · `R` = randomized
- **implementation** — `live UVM`, `live plain`, `live 2env`, `planned`, `planned (variant-only)` (variant-only = requires non-default build flags — `SWB_N_LANES={2,8}`, `SWB_N_SUBHEADERS={64,256}`, `SWB_MAX_HITS_PER_SUBHEADER={2,8}`, `USE_BIT_STREAM`, `USE_BIT_GENERIC`, `SWB_USE_MERGE=0`)

## Field-map anchors

All cases below address specific fields or beats defined in the stimulus field map in [`DV_BASIC.md`](DV_BASIC.md#stimulus-field-map-per-frame-per-lane). Shorthand used in the scenario column:

- `K28.5=0xBC`, `K28.4=0x9C`, `K23.7=0xF7` — the three K-chars emitted by `feb_frame_assembly.vhd`
- `gts_8n[47:0]` — 48-bit global timestamp; split into `gts[47:16]` (header0), `gts[15:0]` (header1 high), and `gts[30:0]` (debug1). Also split at SWB into `frame_ts = gts[47:12]`, `shd_ts = gts[11:4]`, `hit_ts = gts[3:0]`.
- `pkg_cnt[15:0]` — frame counter at header1 low
- `subheader_cnt[14:0]` — debug0 high, `hit_cnt[15:0]` — debug0 low (frame totals)
- `shd_ts[11:4]` — subheader beat high byte · `sub_hit_cnt[7:0]` — subheader beat mid byte
- hit word `{TS2[4:0], TS1[10:0], Col[6:0], Row[8:0]}`
- `N_SHD` — per-lane subheader budget (`SWB_N_SUBHEADERS`, default 256 in replay, 128 in OPQ)
- `MAX_HITS` — `SWB_MAX_HITS_PER_SUBHEADER` (default 4)

## Catalog

<!-- columns:
  case_id / method / implementation / scenario / primary checks / stage
  stage = I ingress · M merger · O OPQ egress · D DMA packed · E event-builder retirement
-->

| case_id | method | implementation | scenario | primary checks | stage |
|---|---|---|---|---|---|
| E001 | D | live UVM | SOP beat with `datak=0x0` (preamble K28.5 seen but no K-flag) | parser rejects frame; ingress hit count on this lane stays at 0; harness raises `UNRECOGNIZED_START` | I |
| E002 | D | live UVM | EOP beat with `datak=0x0` (trailer byte `0x9C` but K-flag clear) | parser treats as data beat; downstream sees no `o_endofevent` until next real trailer; scoreboard flags missing EOP | I/E |
| E003 | D | live UVM | subheader beat with `datak=0x0` (K23.7 byte `0xF7` with K-flag clear) | parser does not classify beat as subheader; `sub_hit_cnt` does not advance; subsequent hits are counted under the previous subheader | I/O |
| E004 | D | live UVM | frame starts with two SOP beats back-to-back on one lane (second SOP lands while first is still being parsed) | parser raises `DOUBLE_SOP`; scoreboard discards the duplicate preamble; ingress hit count for the frame is 0 | I |
| E005 | D | planned | frame ends with two EOP beats back-to-back (filler + real trailer both flagged K28.4) | parser records exactly one `EOF_FRAME`; `o_endofevent` pulses once; extra trailer beat is dropped | I/E |
| E006 | D | planned | EOP arrives directly after SOP with no data/headers in between | zero-header frame is rejected at parser; ingress hit count stays 0; OPQ does not allocate a frame slot | I/O |
| E007 | D | planned | EOP missing at end of frame (SOP+headers+hits but no trailer beat emitted) | harness timeout after `SWB_FRAME_TIMEOUT` cycles; `o_endofevent` never asserts; test fails with `MISSING_EOP` | I/E |
| E008 | D | planned | two full frames on one lane with zero-cycle idle gap (EOP of frame N on cycle `c`, SOP of frame N+1 on cycle `c+1`) | both frames parse cleanly; OPQ allocates two distinct frame slots; DMA payloads concatenate without dropped hits | I/O/D |
| E009 | D | planned | idle gap between frames is exactly one cycle | parser allows one-cycle gap; no regression vs E008 | I |
| E010 | D | planned | idle gap between frames is 4096 cycles (long stall) | OPQ frame slot retains headers through the stall; subsequent frame does not reuse the slot | I/O |
| E011 | D | planned | SOP on lane 0 and EOP on lane 1 in the exact same cycle | per-lane SOP/EOP parsers are independent; neither event is dropped; `musip_mux_4_1` observes both events | I/M |
| E012 | D | planned | trailer of lane 0 arrives the cycle after OPQ starts draining lane 0's frame | OPQ merge does not pick up a mid-frame word; frame drains cleanly; no `shd_ts` discontinuity at the merge output | M/O |
| E013 | D | planned | `gts_8n[47:16]` rolls from `0xFFFFFFFF` to `0x00000000` between frame N and frame N+1 | header0 holds new zero; frame identity in OPQ differs; `frame_ts` at OPQ egress reflects roll | I/M/O |
| E014 | D | planned | `gts_8n[15:0]` in header1 rolls `0xFFFF→0x0000` while `gts_8n[47:16]` advances by 1 | header0 ticks by 1; header1 high word wraps; `frame_ts = gts[47:12]` carries the increment | I/M |
| E015 | D | planned | `gts_8n[30:0]` in debug1 crosses bit 31 boundary (value `0x7FFFFFFF→0x00000000`) | debug1 reflects wrap; OPQ does not interpret debug1 as error; downstream consumers treat it as opaque metadata | I/O |
| E016 | D | planned | `pkg_cnt[15:0]` rolls from `0xFFFF` to `0x0000` across frames N and N+1 on the same lane | header1 low word wraps; OPQ does not reject the second frame; per-frame pkg_cnt ledger records both values | I/O |
| E017 | D | planned | `pkg_cnt` duplicated between two consecutive frames (`pkg_cnt=0x0000` for both) | OPQ still disambiguates frames via `gts_8n[47:12]`; scoreboard flags `DUP_PKG_CNT` as informational | I/M |
| E018 | D | planned | `subheader_cnt` in debug0 equals zero for a frame that actually contains subheaders | debug0 reports 0 but OPQ observes real subheaders; scoreboard flags `DEBUG0_UNDERCOUNT` | I/M |
| E019 | D | planned | `subheader_cnt` equals `N_SHD` with N_SHD-1 subheaders actually present (off-by-one overcount) | debug0 reports one extra; scoreboard flags `DEBUG0_OVERCOUNT`; OPQ drains only the real count | I/O |
| E020 | D | planned | `hit_cnt[15:0]` in debug0 equals 0 with at least one hit present | debug0 undercount; actual DMA hits observed but frame's debug0 ledger is wrong; scoreboard flags `DEBUG0_HIT_UNDERCOUNT` | I/D |
| E021 | D | planned | `hit_cnt[15:0]` in debug0 equals `0xFFFF` with one hit present | debug0 saturated; scoreboard records real hit count and flags `DEBUG0_HIT_SATURATED` | I/D |
| E022 | D | planned | `subheader_cnt` at exactly N_SHD boundary on N_SHD=128 OPQ build (127 subheaders emitted) | highest legal value; OPQ page allocator does not overflow | I/O |
| E023 | D | planned | frame with `subheader_cnt = N_SHD+1` attempted (overflow injector, variant build only) | OPQ rejects the N_SHD+1-th subheader; scoreboard flags `SHD_OVERFLOW`; DMA output truncated at N_SHD | I/O (variant) |
| E024 | D | planned | debug0 `subheader_cnt[14:0]` MSB flips mid-frame (value crosses `0x3FFF→0x4000`) | field is preserved end-to-end; OPQ does not misinterpret MSB | I/M |
| E025 | D | live UVM | subheader with `sub_hit_cnt=0` (zero-hit subheader) | OPQ does not emit an OPQ hit for this subheader; `shd_ts` is recorded in the frame ledger; DMA count unchanged | I/O/D |
| E026 | D | live UVM | subheader with `sub_hit_cnt=1` (single-hit subheader) | OPQ emits exactly 1 normalized hit for the subheader; `shd_ts` propagates correctly | I/O |
| E027 | D | live UVM | subheader with `sub_hit_cnt=MAX_HITS` (=4 on default build) under a bounded legal active-lane mask so total event hits stay `<= OPQ_N_HIT` | OPQ emits exactly `MAX_HITS` hits per active subheader with no truncation in the promoted legal configuration | I/O |
| E028 | D | planned | subheader claims `sub_hit_cnt=MAX_HITS+1` but only MAX_HITS hits are present (overdeclared) | OPQ records MAX_HITS hits; scoreboard flags `SHD_HITCNT_OVERDECLARE` | I/O |
| E029 | D | planned | subheader claims `sub_hit_cnt=MAX_HITS-1` but MAX_HITS hits follow (underdeclared) | extra hit is still forwarded; scoreboard flags `SHD_HITCNT_UNDERDECLARE`; DMA count matches real hits | I/O |
| E030 | D | planned | subheader with `sub_hit_cnt=0xFF` and only 1 hit present | 8-bit saturation corner; same handling as E028 | I/O |
| E031 | D | planned | two subheaders in one frame with identical `shd_ts[11:4]` | OPQ tolerates duplicate `shd_ts`; `abs_ts = (frame_ts << 12) | (shd_ts << 4) | hit_ts` disambiguates via `hit_ts` | I/O |
| E032 | D | planned | `shd_ts[11:4]` monotonically increasing across subheaders (0, 1, 2, …) | sort-stable path; DMA order matches strict-ts sort | I/O/D |
| E033 | D | planned | `shd_ts[11:4]` monotonically decreasing across subheaders (0xFF, 0xFE, …) | OPQ's timestamp merger reorders; DMA output sorted in the expected order (ascending `abs_ts`) | M/O/D |
| E034 | D | planned | `shd_ts` wraps from `0xFF` to `0x00` within one frame | OPQ interprets wrap as a new `frame_ts` window; scoreboard checks merged `abs_ts` is monotone | M/O |
| E035 | D | planned | two lanes emit identical `(frame_ts, shd_ts, hit_ts)` across 4-hit bursts | OPQ tie-break rule (lane id ascending) applied; DMA order is lane 0 before lane 1 | M/O/D |
| E036 | D | planned | all four lanes emit one hit each at identical `abs_ts` | DMA outputs 4 hits in lane-id order; `musip_mux_4_1` arbitration observed in the correct priority | M/O/D |
| E037 | D | planned | subheader beat `data[23:16] = 0xFF` (TBD byte at maximum) | TBD byte is opaque; OPQ does not interpret it; DMA hit contract unchanged | I/O |
| E038 | D | planned | subheader beat `data[23:16] = 0x00` (TBD byte at minimum) | same contract | I/O |
| E039 | D | planned | subheader immediately after SOP (no headers/data in between) | parser enforces SOP → hdr0 → hdr1 → dbg0 → dbg1 → subheader; out-of-order is rejected with `BAD_BEAT_ORDER` | I |
| E040 | D | planned | subheader before any preceding subheader's hits have been emitted | parser may see `sub_hit_cnt=N` then 0 hit beats then next subheader; OPQ records zero for the first subheader | I/O |
| E041 | D | live UVM | hit word `Row[8:0]` at `0x000` (minimum) | OPQ passes through; DMA carries `Row=0` | I/D |
| E042 | D | live UVM | hit word `Row[8:0]` at `0x1FF` (maximum 9-bit) | OPQ passes through; DMA carries `Row=0x1FF` | I/D |
| E043 | D | live UVM | hit word `Col[6:0]` at `0x00` (minimum) | OPQ passes through | I/D |
| E044 | D | live UVM | hit word `Col[6:0]` at `0x7F` (maximum 7-bit) | OPQ passes through | I/D |
| E045 | D | live UVM | hit word `TS1[10:0]` at `0x000` (minimum) | `abs_ts` reflects `hit_ts=0`; merge places hit at `shd_ts` boundary | I/O |
| E046 | D | live UVM | hit word `TS1[10:0]` at `0x7FF` (maximum 11-bit) | `hit_ts = TS1[3:0] = 0xF`; merge accounts for the 4-bit carry into `shd_ts` (implementation-defined) | I/O |
| E047 | D | live UVM | hit word `TS2[4:0]` at `0x00` (minimum) | OPQ passes through | I/D |
| E048 | D | live UVM | hit word `TS2[4:0]` at `0x1F` (maximum 5-bit) | OPQ passes through | I/D |
| E049 | D | planned | hit word all zeros `0x00000000` | OPQ records as valid hit; DMA carries all zeros; no filter applies | I/D |
| E050 | D | planned | hit word all ones `0xFFFFFFFF` | OPQ records as valid hit; no protocol collision (datak=0 so `0xFFFFFFFF` is pure data) | I/D |
| E051 | D | planned | hit word value `0x000000BC` with `datak=0x0` (K28.5 byte pattern under data flag) | parser must not mistake this for a preamble; OPQ records as normal hit | I |
| E052 | D | planned | hit word value `0x0000009C` with `datak=0x0` (K28.4 byte pattern under data flag) | parser must not mistake this for a trailer; OPQ records as normal hit | I |
| E053 | D | planned | hit word value `0x000000F7` with `datak=0x0` (K23.7 byte pattern under data flag) | parser must not mistake this for a subheader; OPQ records as normal hit | I |
| E054 | D | planned | hit word `data[31:24] = 0xBC` with `datak=0x0` (ghost K-char in high byte) | parser must not truncate frame; OPQ records full 32-bit hit | I |
| E055 | D | planned | repeated identical hit word 4 times in one subheader | OPQ records 4 distinct hits with identical payload; DMA order by ingress order | I/O/D |
| E056 | D | planned | repeated identical hit word across 4 subheaders (1 hit each, same payload) | OPQ records 4 hits, one per subheader; `shd_ts` disambiguates; DMA ordered by `abs_ts` | I/O/D |
| E057 | D | planned | hit word where `{TS2, TS1}` sorts before previous hit's timestamp within the same subheader | sort stability inside a subheader (OPQ may or may not reorder within the 4-hit burst — document in trace) | I/O |
| E058 | D | planned | hit word followed immediately by subheader (no other hits in between) | parser sees hit beat then K23.7 beat; `sub_hit_cnt=1` for the previous subheader is honored | I |
| E059 | D | planned | data header 0 `data[31:0] = 0xBCBCBCBC` (ghost K28.5 in all four bytes, `datak=0x0`) | parser does not re-trigger SOP; frame continues to hdr1 | I |
| E060 | D | planned | data header 1 `data[31:0] = 0x9C9C9C9C` (ghost K28.4 everywhere) | parser does not re-trigger EOP; frame continues to dbg0 | I |
| E061 | D | planned | debug header 0 `data[31:0] = 0xF7F7F7F7` (ghost K23.7 everywhere) | parser does not re-trigger subheader; frame continues to dbg1 | I |
| E062 | D | planned | debug header 1 `data[31:0] = 0xBC9CF7BC` (mixed ghost K-char pattern) | parser treats as opaque data; no spurious framing events | I |
| E063 | D | planned | preamble `feb_id` = `0x0000` (minimum value) | OPQ tag routes with id=0; per-hit feb_id on DMA equals 0 | I/O |
| E064 | D | planned | preamble `feb_id` = `0xFFFF` (maximum 16-bit value) | OPQ tag routes with id=0xFFFF; no overflow | I/O |
| E065 | D | planned | preamble `feb_type[5:0]` = `0b000000` (invalid / non-MuPix) | OPQ classifies frame as non-MuPix; scoreboard flags `NON_MUPIX_FRAME`; DMA does not receive hits from this frame | I/M |
| E066 | D | planned | preamble `feb_type[5:0]` = `0b111111` (reserved / invalid) | same as E065 | I/M |
| E067 | D | planned | preamble byte 2 bits `[25:24]` non-zero (reserved bits set) | parser ignores reserved bits; OPQ does not fault | I |
| E068 | D | planned | SOP beat where `data[7:0] = 0xFF` instead of `K28.5=0xBC` but `datak=0x1` | parser rejects as `BAD_PREAMBLE_K`; no frame allocated | I |
| E069 | D | planned | OPQ `N_SHD` page fills exactly (subheader_cnt = N_SHD, hit budget exhausted) | OPQ signals full; no frame drop; page drains on merge to next stage | I/O |
| E070 | D | planned | OPQ `N_SHD+1` page overflow attempted (variant build with smaller N_SHD) | OPQ drops the surplus subheader; scoreboard flags `OPQ_SHD_OVERFLOW`; frame still closes | I/O (variant) |
| E071 | D | planned | OPQ drain begins while write is still in progress on the same page | OPQ internal forwarding holds; no read/write collision; `shd_ts` order at OPQ egress remains sorted | M/O |
| E072 | D | planned | OPQ merge produces identical `abs_ts` values across two lanes; tie-break resolves deterministically | documented tie-break (lane-id ascending) holds; DMA order is reproducible | M/O/D |
| E073 | D | planned | OPQ read pointer arrives at write pointer (page empty) mid-drain | drain stalls waiting for next subheader write; no spurious valid on DMA | O |
| E074 | D | planned | OPQ page reused for a second frame before first frame is fully drained (if implementation allows) | OPQ rejects reuse or preserves frame ID metadata; DMA does not interleave frames' payloads | O (variant) |
| E075 | D | planned | `musip_mux_4_1` with only lane 0 producing, lanes 1-3 in hold | mux forwards lane 0 beats; no arbitration starvation events logged | M |
| E076 | D | planned | `musip_mux_4_1` with all four lanes producing simultaneously at the same ts | round-robin or priority is deterministic; scoreboard compares to reference trace | M |
| E077 | D | planned | `musip_mux_4_1` with lane 0 in long burst, lanes 1-3 idle | no deadlock; arbitration does not starve lanes 1-3 if they wake up | M |
| E078 | D | planned | `musip_event_builder` `i_get_n_words=1` (minimum) | event builder retires every hit as a 1-beat event; padding still appended | D/E |
| E079 | D | planned | `musip_event_builder` `i_get_n_words=4` (1 subheader group) | event builder retires 4-hit groups; padding appended once per event | D/E |
| E080 | D | planned | `musip_event_builder` `i_get_n_words=128` (full OPQ page worth) | event builder aggregates 128 beats; `o_endofevent` at the 128th beat | D/E |
| E081 | D | planned | `musip_event_builder` `i_get_n_words` matches exactly the payload count | exactly one event; `o_endofevent` asserts at the boundary; no trailing residual | D/E |
| E082 | D | planned | payload = `i_get_n_words - 1` (one short) | event builder waits for more input; `o_endofevent` is delayed | D/E |
| E083 | D | planned | payload = `i_get_n_words + 1` (one beyond) | event builder retires at `i_get_n_words` and holds the surplus for the next event | D/E |
| E084 | D | planned | padding tail at exactly 128 words (default) | DMA beats after `o_endofevent` number exactly 128; `o_done` asserts on beat 128+payload | D/E |
| E085 | D | planned | DMA `memhalffull` asserts at the exact payload/padding boundary | padding continues through backpressure; no hits lost | D/E |
| E086 | D | planned | DMA `memhalffull` asserts during padding (mid-tail) | padding pauses and resumes; `o_done` asserts after 128 total padding beats elapse | D/E |
| E087 | D | planned | DMA `memhalffull` asserts at the first payload beat | payload paused; event builder holds; `o_endofevent` and `o_done` delayed correspondingly | D/E |
| E088 | D | planned | DMA `memhalffull` asserts for 1 cycle only | transient; no pipeline glitch; no missing beats | D/E |
| E089 | D | planned | DMA `memhalffull` asserts for 1024 consecutive cycles | long backpressure; event builder state preserved; `o_done` asserts on resumption | D/E |
| E090 | D | planned | DMA ready deasserts during `o_endofevent` beat | event builder holds the `o_endofevent` marker until ready returns | E |
| E091 | D | planned | DMA ready deasserts during `o_done` beat | event builder holds `o_done` | E |
| E092 | D | planned | `o_endofevent` asserts exactly 1 beat before the last payload beat (early EoE corner) | scoreboard flags `EOE_EARLY`; payload count does not match event-builder count | D/E |
| E093 | D | planned | `o_endofevent` asserts 1 beat after the last payload beat (late EoE corner) | scoreboard flags `EOE_LATE`; extra beat seen | D/E |
| E094 | D | planned | `o_done` asserts before full 128 padding beats complete (short tail) | scoreboard flags `DONE_EARLY`; padding counter mismatch | E |
| E095 | D | planned | `o_done` asserts after 129 padding beats (overshoot) | scoreboard flags `DONE_LATE` | E |
| E096 | D | planned | event builder sees 0 payload beats then 128 padding beats then `o_done` (zero-payload event) | BUG-008-H guard path; `o_endofevent` asserts at beat 0 or is elided; `o_done` still asserts | D/E |
| E097 | D | planned | event builder sees payload + padding + payload back-to-back (second event without explicit reset) | event boundary identified by `o_endofevent`; no leakage between events | D/E |
| E098 | D | planned | two frames produce zero-payload events concurrently (all lanes empty) | event builder emits two distinct `o_done` pulses; padding between them respected | D/E |
| E099 | D | planned | DMA beat contains hit words matching `0xBC`, `0x9C`, `0xF7` byte patterns (ghost K-char in packed DMA data) | DMA packer does not misinterpret as K-char; `datak` lanes in DMA are unused | D |
| E100 | D | planned | DMA packer boundary where last payload word happens to be an alignment filler | no extra padding beats; event builder counts only real payload | D/E |
| E101 | D | planned | lane mask transitions mid-run from `0b0001` to `0b0011` between frames | second frame includes lane 1; OPQ allocator adapts; no hits from a previously-disabled lane | I/M |
| E102 | D | planned | lane mask all zero (no lanes enabled) | no frames expected; event builder sees 0 events; `o_done` not asserted | A |
| E103 | D | planned | lane mask toggles rapidly (every frame) | each frame sees a different active lane set; scoreboard verifies no stale hits | I |
| E104 | D | planned | single lane active but that lane emits `N_SHD` subheaders with 0 hits each | OPQ consumes the subheaders; DMA payload is 0; padding still runs | I/O/D/E |
| E105 | D | planned | single lane active, all `N_SHD` subheaders with MAX_HITS each | OPQ drains `N_SHD * MAX_HITS` hits; DMA payload equals `ceil(hits/4)` beats | I/O/D |
| E106 | D | planned | lane 3 active only, lanes 0/1/2 tied to zero (no ingress) | mux arbitration emits lane 3's beats; no starvation warning | M |
| E107 | D | planned | lanes 0 and 2 active, lanes 1 and 3 silent (checkerboard mask) | mux handles gaps; DMA order correct | M/O |
| E108 | D | planned | lanes 0 and 1 start frames in same cycle but lane 0 has 2× the subheaders | both frames close at their own pace; no lane-0 starvation of lane-1 drain | I/O/M |
| E109 | D | planned | lane skew: lane 0 frame starts 64 cycles before lane 1 | OPQ frame allocator tracks both; DMA still retires in ingress order per lane | I/M |
| E110 | D | planned | lane skew: lane 0 frame starts 4096 cycles before lane 3 (long skew) | OPQ does not time out; cross-lane `abs_ts` sort still holds at DMA | I/M/D |
| E111 | D | planned | reset deasserts exactly on the first SOP beat | parser accepts the SOP if datak sampling is stable; scoreboard allows a 1-cycle grace if not | I |
| E112 | D | planned | reset re-asserts mid-frame (after headers, before subheaders) | OPQ drains nothing for this frame; scoreboard flags `PARTIAL_FRAME_DROP` | I/M/O |
| E113 | D | planned | reset re-asserts during padding tail | event builder aborts; `o_done` does not assert; scoreboard flags `PADDING_ABORT` | E |
| E114 | D | planned | reset re-asserts during `o_endofevent` beat | event boundary lost; scoreboard flags `EOE_DURING_RESET` | D/E |
| E115 | D | planned | frame straddles a reset boundary: SOP before, EOP after the same reset | trailing fragment is dropped; `o_endofevent` never asserts for that event | I/E |
| E116 | D | planned | `SWB_USE_MERGE=0` variant build on smoke replay | merge path bypassed; DMA still closes on per-hit contract (E-stage only) | D/E (variant) |
| E117 | D | planned | `USE_MERGE=0` variant in plain harness on smoke replay | plain bench runs with bypass; scoreboard still reports `order_exact=1` if monotonic | D (variant) |
| E118 | D | planned | `USE_BIT_MERGER=1` and `USE_BIT_STREAM=0` mixed variant | internal OPQ uses bit-merger path; contract unchanged | M/O (variant) |
| E119 | D | planned | `USE_BIT_STREAM=1` and `USE_BIT_GENERIC=0` | internal OPQ uses bit-stream path; contract unchanged | M/O (variant) |
| E120 | D | planned | `USE_BIT_GENERIC=1` build variant | internal OPQ uses generic path; contract unchanged | M/O (variant) |
| E121 | D | planned | `SWB_N_SUBHEADERS=64` build variant with replay containing exactly 64 subheaders per lane | page allocator drains at boundary; no overflow | I/O (variant) |
| E122 | D | planned | `SWB_N_SUBHEADERS=64` build variant with replay containing 65 subheaders per lane | page overflow triggers; scoreboard flags `OPQ_SHD_OVERFLOW` | I/O (variant) |
| E123 | D | planned | `SWB_MAX_HITS_PER_SUBHEADER=2` build with 4 hits declared in a subheader | OPQ accepts 2 and drops 2; scoreboard flags `HIT_CAPPED_BY_MAX_HITS` | I/O (variant) |
| E124 | D | planned | `SWB_MAX_HITS_PER_SUBHEADER=8` build with 8 hits declared | OPQ passes all 8; DMA payload scales | I/O (variant) |
| E125 | D | planned | `SWB_N_LANES=2` build (reduced) with 2-lane replay | compile passes; other two lane parsers compiled out or tied off | A (variant) |
| E126 | D | planned | `SWB_N_LANES=8` build (extended) with 8-lane replay | compile passes; OPQ page allocator scales; mux arbitrates 8 streams | A (variant) |
| E127 | D | planned | plain_2env split: OPQ boundary audit with DPI seam only (no DMA scoreboard) | OPQ egress trace matches reference; DMA scoreboard is not required to run | I/O |
| E128 | D | planned | plain_2env split: DMA scoreboard only (OPQ seam replayed from reference file, not DUT) | DMA per-hit contract closes; scoreboard isolates any failure to the egress stage | D/E |
| E129 | D | planned | edge-bucket regression: E001, E013, E025, E041, E069, E084, E101, E111 chained in `bucket_frame` mode | all eight anchor cases close without harness reset between them | all |

## Execution modes

- **isolated** — `make ip-uvm-basic SIM_ARGS='+UVM_TESTNAME=swb_edge_test +SWB_CASE_ID=E0xx'` per case.
- **bucket_frame** — sweep `E001..E129` in order inside one continuous timeframe (see [`DV_CROSS.md`](DV_CROSS.md) §6.1).
- **all_buckets_frame** — follows BASIC, see [`DV_CROSS.md`](DV_CROSS.md) §6.1.

## Regenerate

```
python3 tb_int/scripts/build_dv_report_json.py --tb tb_int
python3 tb_int/scripts/dv_report_gen.py --tb tb_int
```
