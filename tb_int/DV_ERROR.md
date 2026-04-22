# DV_ERROR.md — tb_int (MuSiP SWB/OPQ integration)

**Companion:** [`DV_INT_PLAN.md`](DV_INT_PLAN.md) · [`DV_INT_HARNESS.md`](DV_INT_HARNESS.md) · [`DV_BASIC.md`](DV_BASIC.md) · [`DV_COV.md`](DV_COV.md) · [`DV_REPORT.md`](DV_REPORT.md) · [`BUG_HISTORY.md`](BUG_HISTORY.md)
**Canonical ID range:** `X001`–`X129`
**Intent:** fault-injection, illegal-stimulus, reset-lifecycle, and bug-regression traps for the SWB+OPQ integration. Every case drives stimulus that violates one specific contract (K-char, framing, OPQ page, DMA padding, event boundary, reset sequencing) and asserts the expected containment — no propagation of corruption beyond the stage responsible for the check.
**Stimulus source:** same FEB AvST grammar as [`DV_BASIC.md`](DV_BASIC.md); error cases mutate exactly the bits or beats named in the scenario and hold everything else at the BASIC shape, so the failure is attributable.

## Method / implementation legend

- **method** — `D` = directed fault · `R` = randomized fault injection
- **implementation** — `live UVM`, `live plain`, `live 2env`, `planned`, `planned (variant-only)`

## Bug anchors

X111 through X125 each reproduce one ledger entry in [`BUG_HISTORY.md`](BUG_HISTORY.md). If a regression reintroduces the same class of defect, the anchor case fails deterministically.

| anchor | bug_id | reproduced failure mode |
|---|---|---|
| X111 | BUG-001-H | reverse padding loop underflow in `swb_case_builder::build_basic_case` |
| X112 | BUG-002-R | native-SV OPQ merge path stalls upstream of `dma_done` |
| X113 | BUG-003-R | local full replay diverges from expected DMA ledger |
| X114 | BUG-004-R | `musip_event_builder` legacy completion contract inconsistency |
| X115 | BUG-005-R | external `signoff_4lane` alignment gap (audit-only; kept out of pass gate) |
| X116 | BUG-006-H | random UVM case seed not captured |
| X117 | BUG-007-H | per-hit trace export fails if report directory missing |
| X118 | BUG-008-H | zero-payload random case spuriously requires `dma_done` and EoE |
| X119 | BUG-009-H | plain_2env DMA scoreboard blind to ingress |
| X120-X125 | combined | pair-wise regressions across the above |

## Catalog

<!-- columns:
  case_id / method / implementation / scenario / primary checks / stage
-->

| case_id | method | implementation | scenario | primary checks | stage |
|---|---|---|---|---|---|
| X001 | D | live UVM | hit beat with `data[7:0] = 0xBC` and `datak = 0x1` (ghost preamble K-char flagged inside a hit) | parser raises `UNEXPECTED_K285_MID_FRAME`; OPQ does not accept the hit; frame continues to normal trailer | I |
| X002 | D | live UVM | hit beat with `data[7:0] = 0x9C` and `datak = 0x1` (ghost trailer K-char flagged inside a hit) | parser raises `EARLY_TRAILER`; frame closed prematurely; scoreboard flags truncation | I/E |
| X003 | D | live UVM | hit beat with `data[7:0] = 0xF7` and `datak = 0x1` (ghost subheader K-char flagged inside a hit) | parser misinterprets as subheader; scoreboard flags `MIS_SUBHEADER`; frame count becomes inconsistent | I/O |
| X004 | D | planned | preamble `datak = 0x1` but `data[7:0] = 0x00` (reserved K-pattern, not one of `0xBC/0x9C/0xF7`) | parser raises `UNKNOWN_K_CHAR`; frame dropped | I |
| X005 | D | planned | preamble `datak = 0x3` (illegal multi-bit K mask) | parser rejects; frame dropped; OPQ sees no SOP | I |
| X006 | D | planned | subheader `datak = 0x0` with data `0xF7` in `data[7:0]` (K-flag dropped, real K byte) | parser does not classify as subheader; subsequent hit beats are counted under the previous subheader | I/O |
| X007 | D | planned | trailer `datak = 0x1` with data `data[7:0] = 0xBC` (accidentally emits preamble K-char at EOP beat) | parser raises `PREAMBLE_AT_EOP`; frame drop; next frame expected to restart cleanly | I |
| X008 | D | planned | trailer beat missing altogether (frame ends at last hit, no K28.4) | parser times out after `SWB_FRAME_TIMEOUT`; OPQ frame not retired; scoreboard flags `MISSING_EOP` | I/E |
| X009 | D | planned | preamble beat missing (first beat is a header0, no SOP) | parser raises `MISSING_SOP`; frame dropped; no partial state leaks | I |
| X010 | D | planned | preamble beat with `feb_type[5:0] = 0b000000` under `SWB_USE_MERGE=1` | OPQ classifies frame as non-MuPix; scoreboard flags `NON_MUPIX_FRAME` (informational, not a fault) | I/M |
| X011 | D | planned | subheader `sub_hit_cnt = 0x00` but followed by 4 hit beats (lying subheader) | OPQ accepts the 4 hits per stream order; scoreboard flags `SHD_LIES`; downstream count matches real hits | I/O |
| X012 | D | planned | subheader `sub_hit_cnt = 0xFF` but followed by 1 hit beat (grossly overdeclared) | OPQ drains 1 hit; scoreboard flags `SHD_OVERDECLARE_255` | I/O |
| X013 | D | planned | two SOP K28.5 beats in a row (a frame starts while the previous is still mid-stream, no EOP in between) | parser raises `DOUBLE_SOP`; previous frame abandoned; new frame takes over | I |
| X014 | D | planned | two EOP K28.4 beats in a row (back-to-back trailers, no headers between) | parser raises `DOUBLE_EOP`; only first EOP retires a frame; second is discarded | I |
| X015 | D | planned | SOP at the cycle the previous EOP is still in its wait-state (zero idle gap) | parser allows back-to-back (E008 baseline); only reject if protocol requires ≥1 gap | I |
| X016 | D | planned | SOP injected during the middle of a frame's data beats (before EOP) | parser raises `MIDFRAME_SOP`; old frame abandoned; new frame accepted | I |
| X017 | D | planned | EOP injected during the middle of a frame's hit payload (before all declared hits are seen) | parser raises `EARLY_TRAILER`; OPQ retires frame with partial hits; scoreboard flags `HIT_TRUNCATION` | I/O |
| X018 | D | planned | EOP injected immediately after SOP (no headers, no hits) | OPQ sees zero-payload frame; padding still runs; `o_done` asserts; scoreboard flags `DEGENERATE_FRAME` | I/E |
| X019 | D | planned | SOP-headers-EOP (no subheader, no hits) | OPQ retires frame with 0 subheaders, 0 hits; padding still runs | I/O/E |
| X020 | D | planned | SOP-headers-subheader-EOP (subheader with `sub_hit_cnt > 0`, no hit beats before EOP) | parser raises `MISSING_HIT`; OPQ retires frame with 0 real hits; scoreboard flags truncation | I/O |
| X021 | D | planned | `N_SHD+1`-th subheader injected on N_SHD=128 variant build | OPQ drops the overflow subheader; scoreboard flags `OPQ_SHD_OVERFLOW`; frame still closes | I/O (variant) |
| X022 | D | planned | `MAX_HITS+1` hits injected under one subheader on default build | OPQ drops the `MAX_HITS+1`-th hit; scoreboard flags `HIT_CAPPED_BY_MAX_HITS`; subheader retires with MAX_HITS | I/O |
| X023 | D | planned | subheader beat interleaved between two hit beats of the same prior subheader | parser raises `UNEXPECTED_SUBHEADER`; OPQ treats as new subheader; original subheader under-counted | I/O |
| X024 | D | planned | hit beat before any subheader (first data beat after debug1 is a hit, not a subheader) | parser raises `HIT_BEFORE_SUBHEADER`; hit discarded; OPQ frame carries zero hits | I/O |
| X025 | D | planned | ingress FIFO backpressure during SOP beat (upstream asserts ready=0 exactly on SOP) | FEB repeats SOP until ready=1; parser sees only one SOP; OPQ unaffected | I |
| X026 | D | planned | ingress FIFO backpressure during EOP beat | FEB repeats EOP; parser dedupes; OPQ frame retires once | I |
| X027 | D | planned | ingress FIFO backpressure during subheader beat | FEB repeats subheader; parser dedupes; OPQ accepts only one subheader | I/O |
| X028 | D | planned | ingress FIFO backpressure during hit beat | FEB repeats hit; parser dedupes; OPQ accepts only one hit | I/O |
| X029 | D | planned | ingress FIFO backpressure for 4096 cycles during frame | FEB stalls; no timeout; frame completes after backpressure releases | I |
| X030 | D | planned | SOP beat flagged with `datak=0x0` (not K) — see E001 | parser raises `SOP_NO_K_FLAG`; frame dropped at parser | I |
| X031 | D | planned | OPQ page fills to N_SHD subheaders then another subheader is injected | OPQ either rejects or cycles the page; scoreboard verifies no lost subheaders from prior pages | I/O |
| X032 | D | planned | OPQ page fills while drain is in progress from same page (read/write collision) | OPQ internal forwarding ensures no dropped beat; `abs_ts` sort at egress remains monotone | M/O |
| X033 | D | planned | OPQ page fills while DMA backpressure holds egress (`dma_ready=0`) for 128 cycles | OPQ page drains only when DMA ready returns; no fill/drain pointer corruption | O |
| X034 | D | planned | OPQ tag table overflow attempted (more distinct `feb_id` values than implementation supports) | OPQ either rejects new tags with `TAG_OVERFLOW` or reuses oldest; scoreboard verifies documented policy | I/M/O |
| X035 | D | planned | OPQ merge tie-break on identical `abs_ts` across 4 lanes, two different `feb_id` per `abs_ts` | tie-break rule (lane ascending then feb_id ascending) deterministic; scoreboard compares to reference | M/O |
| X036 | D | planned | OPQ drain stall: `dma_ready=0` for >2× frame duration | no internal timeout; OPQ page retained; scoreboard flags `OPQ_STALL` as informational | O |
| X037 | D | planned | OPQ reset injected mid-fill | page discarded; next SOP triggers new page allocation; no ghost data in new page | I/O |
| X038 | D | planned | OPQ reset injected mid-drain | drain cancelled; DMA sees truncated beat; scoreboard flags `OPQ_DRAIN_ABORT` | O/D |
| X039 | D | planned | `musip_mux_4_1` arbitration fault simulation: force one lane to always win | mux produces only lane 0 output; lanes 1-3 starved; scoreboard flags `STARVATION` | M |
| X040 | D | planned | `musip_mux_4_1` with conflicting valid/ready timing: lane 0 valid held, lane 1 valid pulses | mux handles pulses correctly; no lost beats | M |
| X041 | D | planned | `musip_event_builder` `i_get_n_words=0` (invalid) | event builder holds indefinitely; scoreboard flags `EVENT_BUILDER_FROZEN` | E |
| X042 | D | planned | `musip_event_builder` `i_get_n_words` changes during active event | new value takes effect at next event boundary; current event completes with old value | E |
| X043 | D | planned | `musip_event_builder` internal counter force-corrupted via backdoor | if backdoor write is detected by self-check, `o_done` suppressed and scoreboard flags `EB_COUNTER_CORRUPT` | E |
| X044 | D | planned | DMA payload larger than internal buffer (if implementation has a cap) | DMA splits or holds; scoreboard verifies per-hit ledger matches regardless of splitting | D/E |
| X045 | D | planned | DMA `memhalffull` stuck high (never deasserts) | event builder stalls; `o_done` never asserts; scoreboard flags `DMA_PERMANENT_BACKPRESSURE` | D/E |
| X046 | D | planned | DMA `memhalffull` toggles every cycle | pipeline absorbs; no beat loss; scoreboard counts match | D/E |
| X047 | D | planned | DMA `ready` stuck low for 32768 cycles | event builder holds; no internal overflow; no beat loss on `ready` return | D/E |
| X048 | D | planned | DMA beat retransmit (simulated glitch: same `valid` beat observed twice) | scoreboard dedupes; per-hit ledger counts once | D |
| X049 | D | planned | payload count mismatches `i_get_n_words` with `o_endofevent` asserted prematurely | scoreboard flags `EOE_PAYLOAD_MISMATCH`; reported to bug ledger if seen | D/E |
| X050 | D | planned | `o_endofevent` held high for 2 cycles (duplicate) | scoreboard flags `EOE_DUPLICATE`; counts once | E |
| X051 | D | planned | `o_endofevent` pulses without any prior payload | scoreboard flags `EOE_WITHOUT_PAYLOAD`; event count not incremented | E |
| X052 | D | planned | `o_done` asserted mid-padding (before 128 beats) | scoreboard flags `DONE_EARLY`; padding count verified < 128 | E |
| X053 | D | planned | `o_done` never asserts after payload + 128 padding beats | scoreboard flags `DONE_MISSING`; test fails after `SWB_DONE_TIMEOUT` | E |
| X054 | D | planned | `o_done` asserts twice for one event | scoreboard flags `DONE_DUPLICATE`; counts once | E |
| X055 | D | planned | padding beat `data[31:0]` contains non-zero garbage instead of expected padding pattern | scoreboard either tolerates (if padding data is unspecified) or flags `PADDING_DATA_GARBAGE` | E |
| X056 | D | planned | padding beat count = 127 (one short) | scoreboard flags `PADDING_SHORT`; `o_done` timing shifted | E |
| X057 | D | planned | padding beat count = 129 (one over) | scoreboard flags `PADDING_LONG`; extra beat between events | E |
| X058 | D | planned | two `o_done` pulses with no intervening payload (back-to-back events, second is empty) | second `o_done` is padding-only event; scoreboard records two events, one empty | E |
| X059 | D | planned | ingress-only fault: one lane emits malformed preamble while others are clean | affected lane's frame dropped; other lanes unaffected; DMA contract still closes for clean lanes | I/M |
| X060 | D | planned | ingress-only fault: one lane emits a single bit-flipped hit | scoreboard flags `HIT_MISMATCH` for that hit only; rest of frame clean | I/D |
| X061 | D | planned | DMA packed word bit-flip simulation (backdoor edit to one payload word) | scoreboard flags `DMA_DATA_CORRUPT`; per-hit ledger shows one mismatch | D |
| X062 | D | planned | OPQ page metadata bit-flip (backdoor) | OPQ tag lookup miss; scoreboard flags `OPQ_META_CORRUPT` | O |
| X063 | D | planned | reset asserted for 1 cycle only (glitch pulse) | DUT recovers cleanly; next frame processes normally | A |
| X064 | D | planned | reset asserted for exactly a frame duration | active frame dropped; next frame processes normally; no stuck state | A |
| X065 | D | planned | reset deasserted exactly on a hit beat | parser starts on hit beat; no frame context; frame dropped with `NO_SOP_ON_START` | I |
| X066 | D | planned | reset re-asserted between `o_endofevent` and `o_done` beats | padding cancelled; scoreboard flags `PADDING_ABORT_BY_RESET` | E |
| X067 | D | planned | reset re-asserted during DMA backpressure (stalled event builder) | event builder cleared; stalled event discarded; scoreboard flags `EVENT_LOST_BY_RESET` | E |
| X068 | D | planned | reset pulse `1, 0, 1` (double-toggle glitch) | DUT treats as two resets; scoreboard verifies no stuck state | A |
| X069 | D | planned | multiple resets within 1 frame (stress glitch) | frame fully dropped; DUT recovers on next SOP | A |
| X070 | D | planned | reset with `lane_mask` changing across the reset boundary | post-reset lane mask honored immediately; pre-reset mask discarded | I/M |
| X071 | D | planned | reset with `i_get_n_words` changing across the boundary | post-reset value honored; event builder starts fresh | E |
| X072 | D | planned | reset with `feb_type` changing across the boundary | post-reset routing honored | I/M |
| X073 | D | planned | reset lifecycle full: assert → hold 100 cyc → deassert → run 1 frame → assert → hold → deassert → run 1 frame | both frames process cleanly; no carry-over state | A |
| X074 | D | planned | CSR illegal command injection via register write during active frame | DUT ignores or flags `ILLEGAL_CSR_MID_FRAME`; frame unaffected | A |
| X075 | D | planned | CSR write to read-only register | DUT ignores; readback unchanged; scoreboard verifies no side effects | A |
| X076 | D | planned | CSR readback during reset | returns default / reset value; no stale data | A |
| X077 | D | planned | CSR concurrent write/read race | serializer inside DUT resolves deterministically; read returns pre- or post-write value, not garbage | A |
| X078 | D | planned | clock stretch simulation (clock gated for 16 cyc mid-run) | no internal counter glitch; DUT resumes cleanly | A |
| X079 | D | planned | clock gate toggle at EOE boundary | event boundary preserved; padding resumes after clock return | E |
| X080 | D | planned | clock gate toggle at SOP boundary | SOP beat not dropped; parser starts correctly on clock return | I |
| X081 | D | planned | replay bundle corrupted: one beat's `valid` bit cleared mid-frame | replay generator or harness flags `BUNDLE_CORRUPT`; test skips rather than faulting | A |
| X082 | D | planned | replay bundle corrupted: one beat's `datak` bit flipped | parser sees a K-char where none was expected; handled per X001-X007 | I |
| X083 | D | planned | replay bundle truncated mid-frame | harness flags `BUNDLE_TRUNCATED`; test skips or fails loudly, not silently | A |
| X084 | D | planned | replay bundle with wrong magic number in summary.json | replay generator rejects; harness does not launch with a bad bundle | A |
| X085 | D | planned | replay bundle where one lane's beat count disagrees with summary.json | harness flags mismatch before simulation starts | A |
| X086 | D | planned | replay bundle with `gts_8n` going backwards between beats on one lane | parser rejects or flags `GTS_REGRESSION`; OPQ does not accept out-of-order frames | I/M |
| X087 | D | planned | replay bundle with two frames identical (same `gts_8n`, same `pkg_cnt`, same payload) | OPQ dedup policy verified; scoreboard flags either `FRAME_DUP_TOLERATED` or `FRAME_DUP_REJECTED` | I/M |
| X088 | D | planned | replay bundle where hit's `abs_ts` predates the subheader's `shd_ts` bucket | OPQ either rejects hit or tags `TS_OUT_OF_BUCKET`; scoreboard verifies documented policy | I/O |
| X089 | D | planned | replay bundle with `subheader_cnt` in debug0 that contradicts real count (mismatch fault) | scoreboard flags `DEBUG0_MISMATCH`; OPQ uses real count | I/O |
| X090 | D | planned | replay bundle with `hit_cnt` in debug0 exceeding real count by 100 | scoreboard flags `DEBUG0_HIT_OVERCOUNT`; OPQ uses real count | I/O |
| X091 | D | planned | plain harness timeout: no DMA activity for `DMA_TIMEOUT_CYC` | harness fails with `DMA_TIMEOUT`; not silently hung | D/E |
| X092 | D | planned | plain harness timeout: no `o_done` for `DONE_TIMEOUT_CYC` | harness fails with `DONE_TIMEOUT` | E |
| X093 | D | planned | UVM harness timeout: `SWB_CHECK_PASS` not emitted by `UVM_TIMEOUT` | harness fails with `CHECK_PASS_MISSING` | A |
| X094 | D | planned | UVM harness scoreboard detects ghost hit (hit at DMA not present in ingress trace) | scoreboard flags `DMA_GHOST` and fails the run | D |
| X095 | D | planned | UVM harness scoreboard detects missing hit (hit at ingress but not at DMA) | scoreboard flags `DMA_MISSING` and fails the run | D |
| X096 | D | planned | 2env harness scoreboard detects ghost at OPQ boundary only (not at DMA) | scoreboard isolates to OPQ stage; flags `OPQ_GHOST` | O |
| X097 | D | planned | 2env harness scoreboard detects missing hit at OPQ boundary | scoreboard flags `OPQ_MISSING` | O |
| X098 | D | planned | formal boundary scaffold fails on a simulated bug in the OPQ seam | `make ip-formal-boundary` returns non-zero; property name in the failing cex | O |
| X099 | D | planned | UVM run with `+UVM_MAX_QUIT_COUNT=0` force-quits on first UVM_ERROR | failure is surfaced immediately; no log-hunting | A |
| X100 | D | planned | harness build fails cleanly if `SWB_REPLAY_DIR` is missing | `ip-uvm-basic` errors with `REPLAY_DIR_NOT_FOUND`; not a VCS crash | A |
| X101 | D | planned | harness build fails cleanly if OPQ snapshot is missing | `ip-compile-basic` errors with `OPQ_SNAPSHOT_MISSING`; suggests `ip-init` | A |
| X102 | D | planned | harness license check fails cleanly if ETH server unreachable | `ip-check-license` fails loudly, not silently passes | A |
| X103 | D | planned | harness handles a failed replay generator (Python error) | bundle absent; `ip-uvm-basic` errors before vsim launch | A |
| X104 | D | planned | UVM run with corrupted UCDB file in scratch: harness deletes and regenerates | no stale coverage merged into new run | A |
| X105 | D | planned | UVM run with disk full at UCDB save: graceful error, not corruption | `ucdb save` error surfaced; run counted as failed | A |
| X106 | D | planned | UVM run with clock divided by 2 (125MHz): ensure DUT is not clock-dependent | contract closes; timing scaled; no framing error | A |
| X107 | D | planned | UVM run with clock multiplied by 2 (500MHz): ensure DUT contract holds | contract closes; DMA backpressure more frequent | A |
| X108 | D | planned | UVM run with jittered clock (±5% period) | contract closes; no spurious setup/hold glitch in scoreboard | A |
| X109 | D | planned | UVM run with truncated lane replay file (one lane has 0 bytes) | harness fails with `LANE_REPLAY_EMPTY` | A |
| X110 | D | planned | UVM run with swapped lane replay files (lane 0 content on lane 3, etc.) | scoreboard flags `FEB_ID_MISMATCH` at ingress; test fails | I |
| X111 | D | live UVM | BUG-001-H regression: default randomized UVM run, zero-payload corner | `swb_case_builder::build_basic_case` does not underflow; reverse padding loop uses signed iterator | A |
| X112 | D | live UVM | BUG-002-R regression: merge-enabled replay through OPQ, validate `dma_done` is reached | OPQ merge path does not stall; `o_done` observed | O/D/E |
| X113 | D | live plain | BUG-003-R regression: `ip-plain-basic` full replay, compare DMA output to reference | per-hit ledger at DMA matches reference; `order_exact=0` tolerated | D |
| X114 | D | planned | BUG-004-R trap: `musip_event_builder` contract audit; drive known boundaries and check documented `o_done` timing | `o_done` timing matches documented contract; contract version captured in log | E |
| X115 | D | planned | BUG-005-R reference trap: external `signoff_4lane` alignment audit — informational only, not gating | audit report generated; not counted toward signoff pass/fail | A |
| X116 | D | live UVM | BUG-006-H regression: seeded UVM run with `+SWB_CASE_SEED=<val>` produces byte-identical trace to saved reference | per-hit trace deterministic across runs with same seed | A |
| X117 | D | live UVM | BUG-007-H regression: `+SWB_HIT_TRACE_PREFIX=<non-existent-path>` creates directory and writes trace | report directory auto-created; trace file present | A |
| X118 | D | live UVM | BUG-008-H regression: zero-payload case (`SWB_SAT0..3=0.0`, 2 frames) passes without requiring `dma_done` or EoE | harness detects empty-event case; scoreboard passes; no spurious failure | D/E |
| X119 | D | live 2env | BUG-009-H regression: `ip-plain-basic-2env` smoke wires ingress into DMA scoreboard | `DMA_SUMMARY` fields `ingress_hits` and `dma_hits` both populated and equal | I/D |
| X120 | D | planned | BUG-001-H + BUG-006-H combined: random run with seed capture + reverse-padding boundary | both checks pass; seeded regression reproducible | A |
| X121 | D | planned | BUG-002-R + BUG-009-H combined: merge-enabled 2env split run | OPQ boundary scoreboard closes AND DMA scoreboard closes; both on same replay | I/O/D |
| X122 | D | planned | BUG-007-H + BUG-008-H combined: zero-payload run with trace export enabled to a non-existent directory | directory auto-created; zero-payload run passes; trace files present (possibly empty) | A |
| X123 | D | planned | BUG-006-H + BUG-008-H combined: seeded zero-payload reproducibility | seed produces the same zero-payload trace; passes on rerun | A |
| X124 | D | planned | BUG-002-R + BUG-008-H combined: merge-enabled zero-payload frame | OPQ merge bypass path of BUG-008 still closes when `SWB_USE_MERGE=1` | O/E |
| X125 | D | planned | BUG-003-R + BUG-009-H combined: plain and 2env replay run on same bundle, compare DMA outputs | plain and 2env produce the same per-hit DMA trace | D |
| X126 | D | planned | all-BUG regression: sequential replay of X111-X119 in `bucket_frame` mode | all 9 anchors close; any regression in a bug family fails this run | A |
| X127 | D | planned | smoke-fault regression: X001, X017, X022, X045, X053, X065, X094 chained in `bucket_frame` mode | anchor faults each trigger the expected containment flag; no unexpected carry-over between cases | I/O/D/E |
| X128 | D | planned | reset-lifecycle stress: X063, X064, X066, X067, X068, X069 chained | all reset variants recover cleanly; no stuck state | A |
| X129 | D | planned | error-bucket signoff smoke: X001, X016, X031, X049, X063, X074, X111, X119 chained | one case from each sub-category closes; bucket-level smoke | all |

## Execution modes

- **isolated** — per-case `make ip-uvm-basic SIM_ARGS='+UVM_TESTNAME=swb_error_test +SWB_CASE_ID=X0xx'` (or equivalent plain/2env) with explicit plusargs.
- **bucket_frame** — sweep `X001..X129` in order (see [`DV_CROSS.md`](DV_CROSS.md) §6.1).

## Regenerate

```
python3 tb_int/scripts/build_dv_report_json.py --tb tb_int
python3 tb_int/scripts/dv_report_gen.py --tb tb_int
```
