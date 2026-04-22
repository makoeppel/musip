# DV_BASIC.md — tb_int (MuSiP SWB/OPQ integration)

**Companion:** [`DV_INT_PLAN.md`](DV_INT_PLAN.md) · [`DV_INT_HARNESS.md`](DV_INT_HARNESS.md) · [`DV_COV.md`](DV_COV.md) · [`DV_REPORT.md`](DV_REPORT.md) · [`BUG_HISTORY.md`](BUG_HISTORY.md)
**Canonical ID range:** `B001`–`B129`
**Intent:** standard functional scenarios that every SWB+OPQ integration build has to close before edge, profile, or error buckets are meaningful.
**Stimulus source:** FEB `aso_hit_type3` per-lane AvST grammar emitted by `feb_frame_assembly.vhd` (see §1 of [`DV_INT_HARNESS.md`](DV_INT_HARNESS.md) and the on-wire layout below).

## Method / implementation legend

- **method** — `D` = directed (one deterministic stimulus sequence per case) · `R` = random (multi-txn)
- **implementation** — `live UVM` = currently runnable in `cases/basic/uvm/` · `live plain` = runnable in `cases/basic/plain/` · `live 2env` = runnable in `cases/basic/plain_2env/` · `planned` = stimulus exists in replay bundle but no UVM test class yet · `planned (variant-only)` = requires a non-default build (`USE_BIT_MERGER=0`, reduced `N_SHD`, extra lanes, …)

## Stimulus field map (per-frame, per-lane)

Every case in this bucket drives lanes through this exact 36-bit AvST grammar. The bit layout is the contract — a case that says "hit word X with `Col=0x41`" drives `data[15:9]=0x41` in the hit beat, not any other field.

| beat | datak | data[31:0] | source |
|---|---|---|---|
| preamble/SOP | `0x1` | `{feb_type[5:0], 2'b0, feb_id[15:0], K28.5=0xBC}` | `feb_frame_assembly.vhd:1464..1468` |
| header0 | `0x0` | `gts_8n[47:16]` | `feb_frame_assembly.vhd:1470..1473` |
| header1 | `0x0` | `{gts_8n[15:0], pkg_cnt[15:0]}` | `feb_frame_assembly.vhd:1474..1483` |
| debug0 | `0x0` | `{1'b0, subheader_cnt[14:0], hit_cnt[15:0]}` | `feb_frame_assembly.vhd:1484..1487`, filled at EOF via `header_fifo` |
| debug1 | `0x0` | `{1'b0, gts_8n[30:0]}` | `feb_frame_assembly.vhd:1488..1496` |
| subheader | `0x1` | `{shd_ts[11:4], TBD[7:0], hit_cnt[7:0], K23.7=0xF7}` | `feb_frame_assembly.vhd:54..56`, `K237 = 0xF7` |
| hit | `0x0` | `{TS2[4:0], TS1[10:0], Col[6:0], Row[8:0]}` | Mu3eSpecBook 5.2.6 item 80 |
| trailer/EOP | `0x1` | `{24'b0, K28.4=0x9C}` | `feb_frame_assembly.vhd:1534..1541`, `K284 = 0x9C` |

K-char table (8b/10b): `K28.5 = 0xBC` (preamble), `K28.4 = 0x9C` (trailer), `K23.7 = 0xF7` (subheader marker).

## Catalog

<!-- columns:
  case_id          = B### canonical id
  method           = D (directed, 1 txn) / R (random, N txns)
  implementation   = live <harness> / planned / planned (variant-only)
  scenario         = one-line stimulus description anchored on the field map above
  primary checks   = pass contract this case exercises; language-matched to DV_INT_PLAN §5 stage taps
  stage            = I = stage-I ingress · M = stage-M post-merge · O = stage-O mux input · D = stage-D packed · E = stage-E event-builder retirement
-->

| case_id | method | implementation | scenario | primary checks | stage |
|---|---|---|---|---|---|
| B001 | D | live plain / live UVM | smoke replay bundle `out_smoke/` (1 frame, 1 hit per lane across 4 lanes, `shd_ts` picked from lane id) | preamble K28.5 seen on each lane, 8 ingress hits observed, 8 OPQ hits, 8 DMA hits, payload `2` words + padding `128`, `o_endofevent` after payload, `o_done` after padding | I/M/O/D/E |
| B002 | D | live plain / live UVM | full replay bundle `out/` (2 frames, Poisson saturation `0.2/0.4/0.6/0.8`) | ingress/OPQ/DMA hit counts all equal `3800`, payload `950` words + padding `128`, zero ghost/missing hits | I/M/O/D/E |
| B003 | D | live UVM | default randomized case with merge enabled (no replay, `SWB_USE_MERGE=1`, campaign seed 260421) | SWB_CHECK_PASS emitted, parser clean, EoE and done observed | I/M/O/D/E |
| B004 | D | live UVM | seeded rerun `+SWB_CASE_SEED=12345 +SWB_SAT*=0.10/0.20/0.30/0.40` with per-hit trace | ingress/OPQ/DMA hits `1008/1008/1008`, zero ghost, zero missing | I/M/O/D/E |
| B005 | D | live 2env | split OPQ-boundary smoke replay (same `out_smoke/`) | OPQ_BOUNDARY_SUMMARY closes; DMA scoreboard `payload_words=2`, `ghosts=0` | I/O/D/E |
| B006 | D | live 2env | split OPQ-boundary full replay (same `out/`) | `DMA_SUMMARY payload_words=950 ingress_hits=3800 dma_hits=3800 ghosts=0` | I/O/D/E |
| B007 | D | live UVM | single-lane only (`lane_mask=0b0001`), single frame, single subheader with one hit | OPQ egress reproduces the one hit, DMA produces 1 beat (padded to 4-hit alignment via padding helper) | I/O/D |
| B008 | D | live UVM | single-lane only, single frame, `N_SHD` subheaders all empty (no hits) | OPQ egress emits zero hits, payload `0`, case falls back to zero-payload path (BUG-008-H guard) | I/O |
| B009 | D | live UVM | single-lane, two subheaders each carrying 4 hits (`hit_cnt=4`) | 8 normalized hits pass through OPQ; `shd_ts` mapping preserved end-to-end | I/O/D |
| B010 | D | live UVM | 4-lane, 1 frame, 1 subheader per lane with `hit_cnt=4` | 16 normalized hits sorted by `abs_ts` at DMA, 4 DMA beats of 4 hits each | I/O/D/E |
| B011 | D | live UVM | 4-lane, 2 frames, smoke shape repeated | frame `package_cnt` increments `{0,1}`, `gts_8n[47:16]` rolls by 1 per frame; DMA ordered by `abs_ts` across both frames | I/O/D/E |
| B012 | D | live UVM | K28.5 preamble at SOP validated (parser contract) | `datak=0x1` on SOP, `data[7:0]==0xBC`; any deviation raises parser error | I |
| B013 | D | live UVM | K28.4 trailer at EOP validated | `datak=0x1` on trailer, `data[7:0]==0x9C` on EOP; assert no extra beats after EOP | I |
| B014 | D | live UVM | K23.7 subheader marker validated | every subheader beat has `data[7:0]==0xF7` and `datak=0x1`; parser emits subheader event | I |
| B015 | D | live UVM | preamble `feb_id` is preserved through OPQ | `data[23:8]` at SOP matches OPQ frame's FEB tag and the DMA per-hit feb_id field | I/O |
| B016 | D | live UVM | preamble `feb_type[5:0]` covers the default `0b111010` (`SWB_MUPIX_HEADER_ID`) | `data[31:26]` at SOP equals `0x3A`; OPQ tag routes as MuPix payload | I/O |
| B017 | D | live UVM | header0 carries `gts_8n[47:16]` and OPQ preserves frame identity | two OPQ frames emitted if and only if two distinct `(gts_8n[47:16], gts_8n[15:12])` tuples observed at ingress | I/M/O |
| B018 | D | live UVM | header1 `pkg_cnt[15:0]` monotonicity in single-frame bundle | `pkg_cnt` equals per-lane frame index; OPQ does not reorder within-frame | I/O |
| B019 | D | live UVM | debug0 hit_cnt matches sum of subheader hit counts | ingress parser reports `debug0.hit_cnt == sum(subheader.hit_cnt)`; SWB scoreboard only counts subheader-declared hits | I |
| B020 | D | live UVM | debug1 `gts_8n[30:0]` is close to live gts at EOF (TTL invariant) | `debug1` is observed, ingress monitor does not emit error flag for TTL skew | I |
| B021 | D | live UVM | subheader `shd_ts[11:4]` sampling covers 0x00 | one subheader per lane with `shd_ts=0x00`; DMA hit carries `abs_ts[11:4]==0x00` | I/D |
| B022 | D | live UVM | subheader `shd_ts[11:4]` sampling covers 0xFF | one subheader per lane with `shd_ts=0xFF`; DMA hit carries `abs_ts[11:4]==0xFF` | I/D |
| B023 | D | live UVM | subheader `hit_cnt=0` (empty subheader) | no hits appear between subheader and next subheader; ingress parser closes the empty window cleanly | I |
| B024 | D | live UVM | subheader `hit_cnt=1` (single hit) | one hit beat immediately after subheader; OPQ surface 1 hit in this frame | I/O |
| B025 | D | live UVM | subheader `hit_cnt=4` (max per-subheader hits) | four hit beats follow; OPQ surface 4 hits in this subheader window | I/O |
| B026 | D | live UVM | hit word `Row[8:0]` min `0x000` | DMA hit normalized form preserves `Row` in the lower 9 bits of the hit-word field | I/D |
| B027 | D | live UVM | hit word `Row[8:0]` max `0x1FF` | DMA hit carries `Row==0x1FF` | I/D |
| B028 | D | live UVM | hit word `Col[6:0]` min `0x00` | DMA hit carries `Col==0x00` | I/D |
| B029 | D | live UVM | hit word `Col[6:0]` max `0x7F` | DMA hit carries `Col==0x7F` | I/D |
| B030 | D | live UVM | hit word `TS1[10:0]` min `0x000` | DMA hit carries `TS1==0x000`, `abs_ts` lower bits match | I/D |
| B031 | D | live UVM | hit word `TS1[10:0]` max `0x7FF` | DMA hit carries `TS1==0x7FF` | I/D |
| B032 | D | live UVM | hit word `TS2[4:0]` min `0x00` | DMA hit carries `TS2==0x00` | I/D |
| B033 | D | live UVM | hit word `TS2[4:0]` max `0x1F` | DMA hit carries `TS2==0x1F` | I/D |
| B034 | D | live UVM | all 32 `TS2` codepoints swept per lane (one hit each) | DMA produces 32 hits, sorted by `abs_ts`; each codepoint round-trips | I/D |
| B035 | D | live UVM | all 128 `Col` codepoints swept per lane | every Col value appears exactly once in the DMA ledger | I/D |
| B036 | D | live UVM | all 512 `Row` codepoints swept per lane (batched across 4 subheaders) | every Row value appears exactly once in the DMA ledger | I/D |
| B037 | D | live UVM | mixed hit and zero-hit subheaders in same frame | parser transitions from subheader to subheader without needing a hit beat in between | I |
| B038 | D | live UVM | lane0 has 4 hits, lane1-3 have 0 hits in one frame | OPQ emits 4 hits all tagged from lane0; debug0 on lane0 reports hit_cnt=4 and 0 on others | I/O |
| B039 | D | live UVM | each lane carries a disjoint `shd_ts` band | OPQ orders across lanes by absolute timestamp | O/D |
| B040 | D | live UVM | four lanes all fire the same `shd_ts` simultaneously | OPQ chooses a deterministic lane order per DRR; hit set is identical to ingress multiset | O/D |
| B041 | D | live UVM | payload `i_get_n_words = actual payload` (exact match) | `o_endofevent` asserts on last payload word; `o_done` after 128 padding words | E |
| B042 | D | live UVM | payload `i_get_n_words > actual payload` | event builder stalls; harness times out with documented message (BUG-008-H path exercised differently) | E |
| B043 | D | live UVM | payload `i_get_n_words = 0` | no payload beat; `o_done` behavior per BUG-008-H; harness treats `expected_word_count=0` as legal | E |
| B044 | D | live UVM | `i_dmamemhalffull=0` held throughout | DMA never backpressures; payload writes at max 1 word/cycle | E |
| B045 | D | live UVM | `feb_enable_mask=4'b1111` (all lanes enabled) | all four lane streams arrive at OPQ; lane count at ingress monitor is 4 | I/O |
| B046 | D | live UVM | `feb_enable_mask=4'b0001` (lane0 only) | only lane0 stream reaches OPQ; lanes 1..3 are masked to `LINK32_IDLE` in `swb_block` before `ingress_egress_adaptor` | I/O |
| B047 | D | live UVM | `feb_enable_mask=4'b0010` (lane1 only) | only lane1 stream at OPQ | I |
| B048 | D | live UVM | `feb_enable_mask=4'b0100` (lane2 only) | only lane2 stream at OPQ | I |
| B049 | D | live UVM | `feb_enable_mask=4'b1000` (lane3 only) | only lane3 stream at OPQ | I |
| B050 | D | live UVM | `feb_enable_mask=4'b0011` (two-lane pair) | OPQ surfaces hits from lanes 0 and 1 only | I/O |
| B051 | D | live UVM | `feb_enable_mask=4'b0101` (odd pair) | OPQ surfaces lanes 0 and 2 only | I/O |
| B052 | D | live UVM | `feb_enable_mask=4'b1010` (even pair) | OPQ surfaces lanes 1 and 3 only | I/O |
| B053 | D | live UVM | `feb_enable_mask=4'b0110` | OPQ surfaces lanes 1 and 2 only | I/O |
| B054 | D | live UVM | `feb_enable_mask=4'b1100` | OPQ surfaces lanes 2 and 3 only | I/O |
| B055 | D | live UVM | `USE_BIT_MERGER=1` (promoted merge path) | integrated OPQ merge active; DMA payload matches `expected_dma_words.mem` | M/O |
| B056 | D | live UVM | `USE_BIT_MERGER=0` (bypass) | merged stream is `rx_data_sim` direct copy; scoreboard tolerates bypass in A/B mode | M |
| B057 | D | live UVM | replay bundle `plan.json` metadata round-trip | test RNG seed, lane saturation, frame count appear verbatim in `cases/basic/uvm/report/.../summary.json` | A |
| B058 | D | live UVM | `uvm_replay_manifest.json` lane-file mapping is honored | harness picks `lane0_ingress.mem` for lane 0 etc.; no cross-lane replay leakage | I |
| B059 | D | live UVM | `expected_dma_words.mem` normalization is round-trip stable | payload words observed at DMA equal the normalized-64-bit hit view in the bundle | D |
| B060 | D | live UVM | `reparsed_dma_match=true` self-consistency gate | harness asserts bundle's own self-check passed before running simulation | A |
| B061 | D | live UVM | smoke bundle `summary.json` field `total_hits=8` | scoreboard final total matches 8 | I |
| B062 | D | live UVM | smoke bundle `summary.json` field `expected_word_count=2` | event builder retires exactly 2 payload words | E |
| B063 | D | live UVM | full bundle `summary.json` field `total_hits=3800` | scoreboard final total matches 3800 | I |
| B064 | D | live UVM | full bundle `summary.json` field `expected_word_count=950` | event builder retires exactly 950 payload words | E |
| B065 | D | live UVM | 128-word padding tail | `o_dma_wren` stays high for 128 padding beats after `o_endofevent`; padding words match legacy padder | E |
| B066 | D | live UVM | `o_endofevent` pulse width = 1 cycle | scoreboard observes exactly one EOE strobe per frame | E |
| B067 | D | live UVM | `o_done` pulse width = 1 cycle | scoreboard observes one `dma_done` strobe after padding tail | E |
| B068 | D | live UVM | back-to-back frames (no idle between EOP and next SOP) | OPQ absorbs the second frame's header while draining first frame's hits | I/O |
| B069 | D | live UVM | idle beats between EOP and next SOP (valid=0) | parser tolerates `valid=0` gap and re-synchronises on next `K28.5` | I |
| B070 | D | live UVM | 8 frames at 10% saturation on all lanes | cumulative hit count at DMA equals ingress; per-hit ledger matches | I/D |
| B071 | D | live UVM | 16 frames at 10% saturation on all lanes | same, larger sample | I/D |
| B072 | D | live UVM | 32 frames at 10% saturation on all lanes | same, longer run | I/D |
| B073 | D | live UVM | lane-skew `lane0=0%, lane3=20%` | OPQ merges despite lane-rate asymmetry; DMA order preserved | I/M/O/D |
| B074 | D | live UVM | lane-skew `lane0=40%, lane1-3=0%` | OPQ page allocator surfaces lane0 exclusively; other lanes emit empty frames | I/M |
| B075 | D | live UVM | lane-skew `lane0=0%, lane1=0%, lane2=30%, lane3=0%` | OPQ page allocator surfaces lane2 exclusively | I/M |
| B076 | D | live UVM | reset duration `G_SETTLE_CYCLES=16` (default) | DUT reaches first SOP within settle + 2 cycles; BUG-002-R no longer reproduces | A |
| B077 | D | live UVM | reset duration `G_SETTLE_CYCLES=64` (long settle) | DUT reaches first SOP, behaviour unchanged from default | A |
| B078 | D | live UVM | post-reset first-frame SOP observed on all enabled lanes | parser sees exactly one SOP per enabled lane before any EOP | I |
| B079 | D | live UVM | `use_merge` stamped `1` at `t=0` | integrated OPQ active for the first frame, no bypass transient | M |
| B080 | D | live UVM | `USE_BIT_STREAM=1`, `USE_BIT_GENERIC=1` (default) | harness brings up with both knobs; no parser error | A |
| B081 | D | live plain | deterministic `out_smoke/` replay under `plain/` harness | hit-semantic compare passes (`check_dma_hits.py` reports zero mismatch) | I/D/E |
| B082 | D | live plain | deterministic `out/` replay under `plain/` harness | hit-semantic compare passes; 3800 hits end-to-end | I/D/E |
| B083 | D | live plain | `G_USE_MERGE=0` bypass replay `out_smoke/` | packed-word identity compare passes | D/E |
| B084 | D | live plain | `G_USE_MERGE=0` bypass replay `out/` | packed-word identity compare passes | D/E |
| B085 | D | live 2env | `plain_2env/` boundary SVA watchdog on seam grammar | `swb_opq_boundary_contract_sva.sv` emits no violation across smoke run | O |
| B086 | D | live 2env | `plain_2env/` boundary SVA watchdog across full run | no violation across full `out/` replay | O |
| B087 | D | live 2env | DPI seam scoreboard consumes same `opq_egress.mem` | seam scoreboard closes on same 3800 hits | O |
| B088 | D | live 2env | `plain_2env/` DMA scoreboard fed by ingress-adapter feed (BUG-009-H path) | downstream DMA scoreboard reports `ghosts=0` | O/D/E |
| B089 | D | live UVM | per-hit trace export: `single_seed_ingress_hits.tsv` present | file exists and row count matches `ingress_hits` | I |
| B090 | D | live UVM | per-hit trace export: `single_seed_opq_hits.tsv` present | file exists and row count matches `opq_hits` | O |
| B091 | D | live UVM | per-hit trace export: `single_seed_dma_hits.tsv` present | file exists and row count matches `dma_hits` | D |
| B092 | D | live UVM | per-hit trace export: `single_seed_expected_hits.tsv` present | file exists and row count matches ingress-derived expected hits | I |
| B093 | D | live UVM | per-hit trace summary: `single_seed_summary.txt` fields present | `scoreboard_pass`, `parse_errors`, `opq_ghost_count`, `opq_missing_count`, `dma_ghost_count`, `dma_missing_count` all present | all |
| B094 | D | live UVM | per-hit trace summary: counts agree with hit exports | `ingress_hits == opq_hits == dma_hits` | I/O/D |
| B095 | D | live UVM | `+SWB_HIT_TRACE_PREFIX=<abs-prefix>` relative prefix rejected | harness raises `UVM_ERROR` for relative path; confirms BUG-007-H mitigation | A |
| B096 | D | live UVM | Makefile auto-creates `report/` directory before `vsim` | report dir exists when simulation starts; BUG-007-H closure | A |
| B097 | D | live plain | `check_dma_hits.py` runs after replay | script exits zero on smoke | D |
| B098 | D | live plain | `check_dma_hits.py` tolerates `order_exact=0` | full replay accepted on multiset equality despite timestamp tie-order | D |
| B099 | D | live UVM | `+SWB_CASE_SEED=<n>` seed captured in summary | `summary.json.case_seed` equals the plusarg value | A |
| B100 | D | live UVM | rerun with same `SWB_CASE_SEED` is bit-identical | two runs produce same hit TSV hashes | all |
| B101 | D | live UVM | `run_longrun.py` campaign seed `260421` default, 128 runs | `pass_count=128` with rate grid `0.0..0.5` step `0.1` | all |
| B102 | D | live UVM | `run_longrun.py` summary contains `case_seed` per row | every row in `summary.json.runs[*]` carries a non-null case seed | A |
| B103 | D | live UVM | `run_longrun.py --runs 256 --campaign-seed 260422` extended rerun | `pass_count=256` across same rate grid | all |
| B104 | D | live UVM | default-rate (SAT0..3 all 0.0) single run (BUG-008-H corner) | run reaches SWB_CHECK_PASS with `payload_words=0` | E |
| B105 | D | live plain | `order_exact=1` smoke bundle | ordered compare matches | D |
| B106 | D | live plain | `order_exact=0` full bundle | multiset compare matches (expected) | D |
| B107 | D | live UVM | first payload beat valid timing | `o_dma_wren` rises at least 2 cycles after last hit beat | E |
| B108 | D | live UVM | last payload beat before EOE | `o_endofevent` coincides with `expected_word_count`-th `o_dma_wren` | E |
| B109 | D | live UVM | padding block length | exactly 128 padding beats of `o_dma_wren` after `o_endofevent` | E |
| B110 | D | live UVM | `o_done` follows padding | `o_done` asserts on the cycle after the 128th padding beat | E |
| B111 | D | live UVM | `EVENT_BUILD_STATUS_REGISTER_R` observable (BUG-004-R link) | status register read post-`o_done` returns the documented legacy field set | E |
| B112 | D | live UVM | wrapper exposes `dma_done` to harness seam | `dma_done` at wrapper equals `o_done` driven inside `swb_block` | E |
| B113 | D | live UVM | `swb_block_uvm_wrapper.vhd` ports tied to DUT top | each port drives the DUT input/output intended in `DV_INT_HARNESS.md §3.1` | A |
| B114 | D | live UVM | `tb_top.sv` instantiates `clk`/`reset_n` at 250 MHz / 4 ns | period 4000 ps; reset held low for `G_SETTLE_CYCLES` | A |
| B115 | D | live UVM | `interfaces.sv` hooks for stages I/M/O/D/E present | all five passive monitors compile, no spurious UVM_INFO | A |
| B116 | D | live UVM | scoreboard `SWB_CHECK_PASS` marker present in log | grep passes on log | A |
| B117 | D | live UVM | scoreboard `UVM_ERROR: 0` | log ends with `UVM_ERROR : 0` | A |
| B118 | D | live UVM | scoreboard `UVM_FATAL: 0` | no fatal fired | A |
| B119 | D | live plain | VHDL hit-checker `order_exact` field reported | `plain/` log prints `order_exact=0` or `order_exact=1` | D |
| B120 | D | live 2env | DPI `swb_opq_2env_dpi.c` seam driver runs | seam DPI emits the expected `opq_egress.mem` stream | O |
| B121 | D | live 2env | split-env scoreboard reports `DMA_SUMMARY` | `payload_words`, `ingress_hits`, `dma_hits`, `ghosts` fields populated | I/D |
| B122 | D | live UVM | `SWB_N_LANES=4` (default) build | build compiles, 4 lane streams honored | A |
| B123 | D | planned (variant-only) | `SWB_N_LANES=2` build | build compiles, 2 lane streams honored, remaining lanes tied off | A |
| B124 | D | planned (variant-only) | `SWB_N_LANES=8` build | build compiles, 8 lane streams honored, OPQ page allocator scales | A |
| B125 | D | planned (variant-only) | `SWB_N_SUBHEADERS=64` build | `N_SHD=64` accepted by `feb_frame_assembly` and OPQ; shorter frames | I |
| B126 | D | planned (variant-only) | `SWB_N_SUBHEADERS=256` build (current default) | `N_SHD=256` as emitted by `run_basic_ref.py` | I |
| B127 | D | planned | `SWB_MAX_HITS_PER_SUBHEADER=2` (reduced) | each subheader carries at most 2 hits; DMA hit multiset still matches | I/D |
| B128 | D | planned | `SWB_MAX_HITS_PER_SUBHEADER=8` (extended) | each subheader carries at most 8 hits | I/D |
| B129 | D | live UVM | signoff smoke regression: `B001..B006` chained in `bucket_frame` mode | all six cases close without harness reset between them | all |

## Execution modes

- **isolated** — `make ip-uvm-basic SIM_ARGS='+UVM_TESTNAME=swb_basic_test +SWB_CASE_ID=B0xx'` (per-case, fresh DUT).
- **bucket_frame** — sweep `B001..B129` in order inside one continuous timeframe, no reset between cases (see [`DV_CROSS.md`](DV_CROSS.md) §6.1).
- **all_buckets_frame** — bucket order `BASIC → EDGE → PROF → ERROR`, then case-id order (see [`DV_CROSS.md`](DV_CROSS.md) §6.1).

## Regenerate

```
python3 ~/.codex/skills/dv-workflow/scripts/dv_report_gen.py --tb tb_int
```
