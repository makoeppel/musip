# DV_CROSS.md — tb_int (MuSiP SWB/OPQ integration)

**Companion:** [`DV_INT_PLAN.md`](DV_INT_PLAN.md) · [`DV_INT_HARNESS.md`](DV_INT_HARNESS.md) · [`DV_BASIC.md`](DV_BASIC.md) · [`DV_EDGE.md`](DV_EDGE.md) · [`DV_PROF.md`](DV_PROF.md) · [`DV_ERROR.md`](DV_ERROR.md) · [`DV_COV.md`](DV_COV.md) · [`DV_REPORT.md`](DV_REPORT.md) · [`BUG_HISTORY.md`](BUG_HISTORY.md)
**Canonical run range:** `CROSS-001`–`CROSS-129`
**Intent:** long-run cross-signoff regression that composes the direct catalog (`B`, `E`, `P`, `X`) into continuous-frame runs, promotes anchored direct patterns to seed-swept randomized soaks, and drives merged functional + code coverage to closure.

## 1) Purpose and long-run philosophy

The direct catalog (`B001-B129`, `E001-E129`, `P001-P129`, `X001-X129`) proves each SWB+OPQ contract on a clean harness. Cross runs prove the contracts survive time, interleaving, and noise. They exist to:

- exercise every direct case in a continuous frame without harness reset between cases, so any case-boundary cleanup gap in scoreboard / OPQ page / DMA padding is visible
- promote curated direct patterns (zero-payload, K-char ghost, GOOD-ERROR-GOOD, overwrite pressure, counter approach to rollover) to randomized seed-swept soaks so the same invariants re-hit millions of cycles apart with different phases
- hit FSM / counter / arbitration corners that the direct cases only graze, until merged code coverage clears the closure targets in [`DV_COV.md`](DV_COV.md)
- seed explicit traps for every bug in [`BUG_HISTORY.md`](BUG_HISTORY.md) so a regression cannot reintroduce the same class of defect silently

## 2) Direct → random promotion ladder

Every cross run is one of five ladders. The ladder name is the first token in the scenario column of the catalog in §6.

| ladder | how stimulus is produced | what it proves beyond direct cases | typical frames per run |
|---|---|---|---|
| `bucket_frame` | direct cases in their declared order, no harness restart | case boundaries leave no carry-over in scoreboard, OPQ pages, event builder, or harness state | 256-2048 |
| `all_buckets_frame` | `BASIC → EDGE → PROF → ERROR` in order, no restart | full-stack composition; reset lifecycle handled once per bucket transition only | 1024-8192 |
| `anchored_hybrid` | one or more direct cases pinned as "anchor" with randomized inter-case gap, randomized `λ`, randomized lane skew, randomized sink backpressure | anchor's invariants hold under random surrounding traffic | 512-4096 |
| `seed_sweep` | one randomized case (typically `P0xx`) replayed with N orthogonal LCG seeds | per-case coverage bins union across seeds; seed axis explicit in closure | 128-16384 per seed |
| `checkpoint_soak` | pure randomized traffic over long horizon (≥10000 frames) with log-spaced UCDB checkpoints | coverage growth curve; catches bins that only saturate deep in a run; exposes long-horizon counter bugs | 10000-100000+ |

Every `anchored_hybrid` and above saves one isolated UCDB plus checkpoint UCDBs per log-spaced milestone under [`REPORT/txn_growth/`](REPORT/txn_growth/). `bucket_frame` and `all_buckets_frame` save one merged UCDB under [`REPORT/cross/`](REPORT/cross/).

## 3) Randomization axes

The composer draws from these axes. A cross run's metadata line must name every axis it varies — this is the contract with the seed file and the checkpoint UCDB index.

| axis | values | notes |
|---|---|---|
| `seed` | 32-bit LCG seed | drives all other axes for the run; recorded in every case evidence page |
| `sat_per_lane` | `{0.00, 0.05, 0.10, 0.20, 0.30, 0.40, 0.50}` per lane (4 independent draws) | per-lane Poisson saturation of subheader occupancy |
| `frames_per_run` | `{1, 2, 4, 8, 16, 32, 128, 1024, 10000}` | length of the run in frames |
| `lane_skew_cyc` | `{0, 1, 16, 64, 256, 1024, 4096}` | inter-lane SOP skew |
| `feb_type` | `{0x3A (MuPix), 0x3B, 0x30}` per lane | lane-type routing coverage; `feb_type=0x3A` is the default MuPix header |
| `feb_id` | any 16-bit value; pool of 256 distinct ids sampled | `feb_id` tag coverage |
| `dma_ready_p` | `{1.0, 0.95, 0.90, 0.80, 0.70, 0.50, 0.25}` | sink Bernoulli backpressure rate |
| `i_get_n_words` | `{1, 4, 16, 64, 128, 256, 512}` | event-builder grouping |
| `injection` | `none`, `k_char_ghost`, `midframe_sop`, `early_eop`, `shd_overdeclare`, `reset_mid_frame`, `dma_halffull_stuck` | fault injection type (error bucket promotion) |
| `lane_mask` | any non-zero subset of `{0,1,2,3}` | active lane selection |
| `opq_variant` | `USE_MERGE={0,1}`, `USE_BIT_MERGER={0,1}`, `USE_BIT_STREAM={0,1}`, `USE_BIT_GENERIC={0,1}` | build-axis: one run per non-default variant |
| `shape_variant` | `SWB_N_SUBHEADERS={64,128,256}`, `SWB_MAX_HITS_PER_SUBHEADER={2,4,8}`, `SWB_N_LANES={2,4,8}` | build-axis |

## 4) Closure targets

Merged across the promoted isolated evidence plus CROSS-001..005, the April 24 DV signoff bar is:

| metric | target | merge scope |
|---|---|---|
| `stmt` | ≥ 80.0% | promoted isolated B/E/P/X anchors plus CROSS-001..005 |
| `branch` | ≥ 75.0% | same |
| `cond` | ≥ 45.0% | same |
| `expr` | ≥ 55.0% | same |
| `fsm_state` | ≥ 89.0% | per-FSM: parser, OPQ page allocator, mux arbiter, event builder |
| `fsm_trans` | ≥ 50.0% | same |
| `toggle` | ≥ 35.0% | all RTL nets; key toggles are `gts_8n[47:0]`, `pkg_cnt`, `feb_id`, `abs_ts`, hit word, OPQ page pointers |
| `functional` | ≥ 100.0% bins saturated for: per-lane saturation × frame count, OPQ page fill levels, DMA payload sizes, padding start/end, event boundary, `feb_type` × `feb_id` × lane_id, `dma_ready` regimes, reset lifecycle × stage | promoted functional model |

The broader 129-row cross catalog remains available for future expansion and stress screening, but CROSS-001..005 are the required promoted continuous-frame baselines for this DV signoff. Bins known to saturate slow in deeper campaigns: per-lane skew × saturation > 128k frames; `gts_8n` MSB toggle > 10M frames; OPQ tag table reuse > 256k frames; event-builder `i_get_n_words` × payload-count cross > 512k frames.

## 5) Bug-spotting plays

Each cross family has at least one run whose purpose is to re-trip a previously-found bug if it regresses. The anchored direct case for each bug is listed so the composer can re-seed the trap even if the underlying bug moves location.

| bug | pattern the play reproduces | cross runs that anchor it |
|---|---|---|
| BUG-001-H reverse padding loop underflow | default non-replay UVM with zero-payload corner embedded | CROSS-051, CROSS-063, CROSS-091 |
| BUG-002-R merge path stall upstream of `dma_done` | merge-enabled replay through full OPQ, check `o_done` asserts | CROSS-052, CROSS-086, CROSS-112 |
| BUG-003-R local full replay DMA divergence | plain+2env replay on same bundle; compare DMA per-hit ledgers | CROSS-053, CROSS-087, CROSS-113 |
| BUG-004-R event-builder legacy completion contract | variant `i_get_n_words` sweep with documented `o_done` timing check | CROSS-054, CROSS-100 |
| BUG-005-R external signoff_4lane alignment | audit-only cross (not a blocker) | CROSS-055 (informational) |
| BUG-006-H UVM case seed not captured | seeded randomized runs rerun twice and compared | CROSS-056, CROSS-088, CROSS-114 |
| BUG-007-H trace export directory missing | trace export to never-existed directory | CROSS-057, CROSS-089 |
| BUG-008-H zero-payload false failure | per-lane `λ=0.0` anywhere in a long run | CROSS-058, CROSS-090, CROSS-115 |
| BUG-009-H 2env DMA scoreboard blind to ingress | 2env runs with ingress+DMA scoreboards both on | CROSS-059, CROSS-091, CROSS-121 |

## 6) Canonical cross catalog

### 6.1 Bucket and all-bucket baselines (CROSS-001-006)

Reset-per-case-free direct regressions. Any case-boundary cleanup gap is caught here first.

| case_id | ladder | scenario | bug / coverage target |
|---|---|---|---|
| CROSS-001 | `bucket_frame` | `B001-B129` in declared order, one harness start | case-boundary cleanup for BASIC CSR and control cases; smoke gate for bucket composition |
| CROSS-002 | `bucket_frame` | `E001-E129` in declared order | E013-E017 gts/pkg rollover chain; E069-E084 OPQ page boundary chain; E085-E100 DMA/event boundary chain |
| CROSS-003 | `bucket_frame` | `P001-P129` in declared order | all promoted random cases composed without restart; checkpoint UCDB cadence merged across bucket |
| CROSS-004 | `bucket_frame` | `X001-X129` in declared order | fault containment composed; no latent corruption between error cases |
| CROSS-005 | `all_buckets_frame` | `BASIC → EDGE → PROF → ERROR` in order | full stack; bucket transitions via exactly one reset per transition |
| CROSS-006 | `all_buckets_frame` | `BASIC → EDGE → PROF → ERROR` with `B005/B006`, `E008`, `P011`, `X018`, `X094` repeated mid-frame | repeated high-load cases stress OPQ page allocator across bucket boundaries |

### 6.2 Anchored GOOD-ERROR-GOOD hybrids (CROSS-007-012)

Each run pins a direct X-case (the "error window") between two randomized GOOD windows. Proves an ERROR epoch does not leak state forward or backward.

| case_id | ladder | scenario | bug / coverage target |
|---|---|---|---|
| CROSS-007 | `anchored_hybrid` | GOOD(random, 512 frames) → `X001` (K-char ghost) anchor → GOOD(random, 512 frames); explicit reset between windows | X001 regression; post-fault scoreboard and OPQ page invariants |
| CROSS-008 | `anchored_hybrid` | GOOD(512) → `X017` (mid-frame EOP) → reset → GOOD(512) | X017 regression; partial-frame drop containment |
| CROSS-009 | `anchored_hybrid` | GOOD(512) → `X045` (DMA backpressure stuck) → reset → GOOD(512) | X045 regression; DMA backpressure clearance |
| CROSS-010 | `anchored_hybrid` | GOOD(512) → `X053` (`o_done` missing) → reset → GOOD(512) | X053 regression; event-builder recovery |
| CROSS-011 | `anchored_hybrid` | overwrite-pressure GOOD (`λ=0.50`, 512 frames) → `X022` (MAX_HITS+1) → recovery GOOD(512) | X022 regression; hit-cap containment under saturation |
| CROSS-012 | `anchored_hybrid` | dense GOOD(128) → `X094` (ghost hit injected) → reset → dense GOOD(128) | X094 regression; scoreboard correctly flags ghost |

### 6.3 Arbitration and skew anchors (CROSS-013-018)

| case_id | ladder | scenario | bug / coverage target |
|---|---|---|---|
| CROSS-013 | `anchored_hybrid` | 4-lane symmetric `λ=0.5` with lane skew `{0, 1, 16, 64}` rotated every 256 frames, 2048 frames | lane-skew × saturation arbitration coverage; `musip_mux_4_1` priority under load |
| CROSS-014 | `anchored_hybrid` | same as CROSS-013 but with lane skew drawn uniform from `[0, 1024]` per frame, 2048 frames | high-entropy skew × arbitration; BUG-002-R regression watch |
| CROSS-015 | `anchored_hybrid` | dense same-lane burst on lane 0 while lanes 1-3 hold `λ=0.05` (background), 2048 frames | hot-lane soak with light background; lane starvation watch |
| CROSS-016 | `anchored_hybrid` | alternating hot lane across frames (lane 0 hot frames 0-7, lane 1 hot 8-15, …), 2048 frames | round-robin hot-lane rotation; mux fairness under load change |
| CROSS-017 | `anchored_hybrid` | frontdoor CSR reads during active 4-lane `λ=0.25` soak; read every 1024 cyc | CSR × datapath coexistence; scoreboard verifies read data independent of ingress |
| CROSS-018 | `anchored_hybrid` | CSR writes to `i_get_n_words` swept every 1024 cyc during active soak | dynamic event-builder config under load; BUG-004-R regression anchor |

### 6.4 Interleaving and random-time composition (CROSS-019-024)

| case_id | ladder | scenario | bug / coverage target |
|---|---|---|---|
| CROSS-019 | `anchored_hybrid` | curated all-bucket mix: `B005/B006`, `E020`, `P011`, `X018`, random idle gaps drawn from `[0, 256]` cyc | case-boundary ownership under repeated invocation; direct+random patterns from all buckets coexist |
| CROSS-020 | `anchored_hybrid` | same as CROSS-019 but idle gaps drawn from `[0, 4096]` cyc | idle-gap insensitivity across wide range |
| CROSS-021 | `anchored_hybrid` | same-frame repeated with different `feb_id` (pool of 256 ids) every frame | `feb_id` tag table coverage under continuous frame composition |
| CROSS-022 | `anchored_hybrid` | same-frame repeated with `feb_type` cycling `{0x3A, 0x3B, 0x30}` per frame | `feb_type` routing coverage |
| CROSS-023 | `anchored_hybrid` | per-lane independent `(feb_id, feb_type)` draws per frame, 2048 frames | combined routing-axis coverage |
| CROSS-024 | `anchored_hybrid` | per-lane `gts_8n` decorrelated (independent random offsets) across 2048 frames | cross-lane `gts_8n` coverage without artificial synchronization |

### 6.5 Seed-swept random promotions (CROSS-025-050)

Each row replays one promoted random case with an orthogonal LCG seed. Seeds `0x01…0x1A` are reserved by DV_PROF `P051-P059`. Runs share the seed line so merged UCDBs align.

| case_id | ladder | anchor case | seed | scenario | bug / coverage target |
|---|---|---|---|---|---|
| CROSS-025 | `seed_sweep` | P001 | `0x01` | `make ip-uvm-longrun` with seed 0x01 | baseline longrun repro with alt seed |
| CROSS-026 | `seed_sweep` | P001 | `0x02` | same with seed 0x02 | seed-axis toggle contribution |
| CROSS-027 | `seed_sweep` | P002 | `0x03` | 256-run longrun with seed 0x03 | extended longrun alt seed |
| CROSS-028 | `seed_sweep` | P002 | `0x04` | 256-run longrun with seed 0x04 | extended longrun alt seed |
| CROSS-029 | `seed_sweep` | P011 | `0x05` | symmetric 4-lane λ=0.5, 32 frames, seed 0x05 | peak saturation alt seed |
| CROSS-030 | `seed_sweep` | P011 | `0x06` | same with seed 0x06 | peak saturation alt seed |
| CROSS-031 | `seed_sweep` | P022 | `0x07` | 8-frame sat=0.25, seed 0x07, checkpoint ckp cadence `1,2,4,8` | cross-merge baseline |
| CROSS-032 | `seed_sweep` | P026 | `0x08` | 1024-frame sat=0.25, seed 0x08 | long-horizon alt seed, ckp `1,…,1024` |
| CROSS-033 | `seed_sweep` | P027 | `0x09` | 1024-frame sat=0.50, seed 0x09 | peak-saturation long-horizon alt seed |
| CROSS-034 | `seed_sweep` | P028 | `0x0A` | 1024-frame sat=0.05, seed 0x0A | sparse long-horizon alt seed |
| CROSS-035 | `seed_sweep` | P029 | `0x0B` | 10000-frame sat=0.25, seed 0x0B, ckp `1,…,8192` | 10k alt seed |
| CROSS-036 | `seed_sweep` | P030 | `0x0C` | 10000-frame sat=0.50, seed 0x0C, ckp `1,…,8192` | 10k peak alt seed |
| CROSS-037 | `seed_sweep` | P044 | `0x0D` | `i_get_n_words=1` sat=0.25 32-frame, seed 0x0D | event-builder grouping=1 alt seed |
| CROSS-038 | `seed_sweep` | P047 | `0x0E` | `i_get_n_words=64` sat=0.25, seed 0x0E | event-builder grouping=64 alt seed |
| CROSS-039 | `seed_sweep` | P068 | `0x0F` | random-per-frame λ, 128 frames, seed 0x0F | broadest λ coverage alt seed |
| CROSS-040 | `seed_sweep` | P069 | `0x10` | hot-lane-0, 1024 frames, seed 0x10 | hot-thread long-horizon alt seed |
| CROSS-041 | `seed_sweep` | P077 | `0x11` | full uniform hit-field random, seed 0x11 | hit-word toggle saturation alt seed |
| CROSS-042 | `seed_sweep` | P091 | `0x12` | 4096-frame λ=0.30, seed 0x12, ckp `1,…,4096` | coverage-growth curve alt seed |
| CROSS-043 | `seed_sweep` | P094 | `0x13` | 128-frame coverage closure, seed 0x13 | coverage-closure drive alt seed |
| CROSS-044 | `seed_sweep` | P097 | `0x14` | 512-frame dense λ=0.50, seed 0x14 | dense long-horizon alt seed |
| CROSS-045 | `seed_sweep` | P104 | `0x15` | 128-run mixed-random campaign, seed 0x15 | campaign axis drift re-seeded |
| CROSS-046 | `seed_sweep` | P105 | `0x16` | 256-run mixed-random campaign, seed 0x16 | campaign axis drift re-seeded |
| CROSS-047 | `seed_sweep` | P106 | `0x17` | 512-run mixed-random campaign, seed 0x17 | campaign axis drift re-seeded |
| CROSS-048 | `seed_sweep` | P107 | `0x18` | 10000-frame longhaul, seed 0x18 | 10k longhaul alt seed; counter-toggle watch |
| CROSS-049 | `seed_sweep` | P108 | `0x19` | 50000-frame longhaul, seed 0x19 | 50k longhaul alt seed |
| CROSS-050 | `seed_sweep` | P109 | `0x1A` | 100000-frame longhaul, seed 0x1A | max-depth longhaul alt seed |

### 6.6 Bug-seeded long soaks (CROSS-051-070)

Each row traps one BUG ledger entry. Surrounding traffic is randomized so the trap is hit many times per run.

| case_id | ladder | bug anchor | scenario | bug / coverage target |
|---|---|---|---|---|
| CROSS-051 | `anchored_hybrid` | BUG-001-H | default randomized UVM soak with per-lane `λ=0.0` embedded every 64 frames, 2048 frames | reverse-padding underflow trap re-hit many times |
| CROSS-052 | `anchored_hybrid` | BUG-002-R | merge-enabled replay through full OPQ, `SWB_USE_MERGE=1`, `λ=0.25` 2048 frames | every frame observes `o_done`; no merge-path stall |
| CROSS-053 | `anchored_hybrid` | BUG-003-R | plain and 2env replay on same bundle, parallel comparison, 1024 frames | per-hit DMA ledger equal between plain and 2env |
| CROSS-054 | `anchored_hybrid` | BUG-004-R | event-builder `i_get_n_words` swept through `{1,4,16,64,128,256,512}` every 256 frames, 2048 total | `o_done` timing matches documented contract at every grouping |
| CROSS-055 | informational | BUG-005-R | external signoff_4lane audit cross; result appended to report but does not gate signoff | `signoff_4lane_audit_status` field in DV_REPORT.json |
| CROSS-056 | `anchored_hybrid` | BUG-006-H | seeded randomized run re-executed twice; compare per-hit traces byte-exact | seeded reproducibility holds under repeated execution |
| CROSS-057 | `anchored_hybrid` | BUG-007-H | trace export to a randomized non-existent path every run | directory auto-creation succeeds on every run |
| CROSS-058 | `anchored_hybrid` | BUG-008-H | per-lane `λ=0.0` on all four lanes for 2 frames embedded in 2048-frame soak | zero-payload corner passes without spurious failure |
| CROSS-059 | `anchored_hybrid` | BUG-009-H | 2env run with ingress+DMA scoreboards both on, 2048 frames | `DMA_SUMMARY.ingress_hits` and `dma_hits` agree every run |
| CROSS-060 | `anchored_hybrid` | BUG-001-H + BUG-008-H | zero-payload case with reverse-padding exercise, seeded, 128 frames | combined harness regression |
| CROSS-061 | `anchored_hybrid` | BUG-002-R + BUG-003-R | merge-enabled + plain/2env compare, 1024 frames | merge path closes AND DMA ledgers agree |
| CROSS-062 | `anchored_hybrid` | BUG-002-R + BUG-009-H | merge-enabled 2env with both scoreboards, 1024 frames | both stages close on same merge-enabled traffic |
| CROSS-063 | `anchored_hybrid` | BUG-001-H + BUG-006-H | seeded random with zero-payload corners embedded every 128 frames | seed reproducibility under zero-payload corners |
| CROSS-064 | `anchored_hybrid` | BUG-007-H + BUG-008-H | trace export to non-existent path, zero-payload frames, 128 frames | directory + empty-trace resilience |
| CROSS-065 | `anchored_hybrid` | BUG-003-R + BUG-009-H | plain and 2env replay on same bundle, DMA scoreboards compared | cross-harness DMA ledger agreement |
| CROSS-066 | `anchored_hybrid` | BUG-004-R + BUG-008-H | `i_get_n_words` sweep with zero-payload frames embedded | grouping-change robustness on empty events |
| CROSS-067 | `anchored_hybrid` | BUG-002-R + BUG-004-R | merge-enabled with `i_get_n_words` sweep, 2048 frames | both RTL corners cross cleanly |
| CROSS-068 | `anchored_hybrid` | BUG-006-H + BUG-008-H | seeded zero-payload reproducibility, 256 frames | seed determinism on empty events |
| CROSS-069 | `anchored_hybrid` | BUG-003-R + BUG-004-R | full-replay plain with `i_get_n_words` sweep, 1024 frames | RTL + contract regression combined |
| CROSS-070 | `anchored_hybrid` | all-bug | randomized composer pinning any BUG-00x anchor every 64 frames, 2048 frames | integration of every bug family into one run |

### 6.7 Variant-build crosses (CROSS-071-085)

Variant builds run against the same seed line as the default so merged UCDBs compare cleanly.

| case_id | ladder | variant | scenario | bug / coverage target |
|---|---|---|---|---|
| CROSS-071 | `seed_sweep` | `SWB_USE_MERGE=0` | 2048-frame λ=0.25 seed 0x01 | bypass merge path long-horizon |
| CROSS-072 | `seed_sweep` | `SWB_USE_MERGE=0` | 2048-frame λ=0.50 seed 0x02 | bypass merge path peak sat |
| CROSS-073 | `seed_sweep` | `SWB_N_LANES=2` | 2048-frame λ=0.25 seed 0x03 | 2-lane build long-horizon |
| CROSS-074 | `seed_sweep` | `SWB_N_LANES=8` | 2048-frame λ=0.25 seed 0x04 | 8-lane build long-horizon |
| CROSS-075 | `seed_sweep` | `SWB_N_SUBHEADERS=64` | 2048-frame λ=0.25 seed 0x05 | smaller-page long-horizon |
| CROSS-076 | `seed_sweep` | `SWB_N_SUBHEADERS=256` | 2048-frame λ=0.25 seed 0x06 | larger-page long-horizon |
| CROSS-077 | `seed_sweep` | `SWB_MAX_HITS_PER_SUBHEADER=2` | 2048-frame λ=0.25 seed 0x07 | narrower subheader long-horizon |
| CROSS-078 | `seed_sweep` | `SWB_MAX_HITS_PER_SUBHEADER=8` | 2048-frame λ=0.25 seed 0x08 | wider subheader long-horizon |
| CROSS-079 | `seed_sweep` | `USE_BIT_MERGER=1, USE_BIT_STREAM=0` | 2048-frame λ=0.25 seed 0x09 | bit-merger internal |
| CROSS-080 | `seed_sweep` | `USE_BIT_STREAM=1, USE_BIT_GENERIC=0` | 2048-frame λ=0.25 seed 0x0A | bit-stream internal |
| CROSS-081 | `seed_sweep` | `USE_BIT_GENERIC=1` | 2048-frame λ=0.25 seed 0x0B | generic internal |
| CROSS-082 | `seed_sweep` | combined `N_SHD=256, MAX_HITS=8` | 2048-frame λ=0.25 seed 0x0C | high-density variant |
| CROSS-083 | `seed_sweep` | combined `N_LANES=8, N_SHD=64` | 2048-frame λ=0.25 seed 0x0D | wide-narrow variant |
| CROSS-084 | `seed_sweep` | combined `N_LANES=2, MAX_HITS=8` | 2048-frame λ=0.25 seed 0x0E | narrow-deep variant |
| CROSS-085 | `seed_sweep` | default (control) | 2048-frame λ=0.25 seed 0x0C (same as CROSS-082) | default baseline for variant deltas |

### 6.8 Coverage-closure-driven soaks (CROSS-086-115)

Runs are picked to close specific coverage bins identified in [`DV_COV.md`](DV_COV.md).

| case_id | ladder | closure target | scenario | evidence |
|---|---|---|---|---|
| CROSS-086 | `checkpoint_soak` | parser FSM state | sparse `λ=0.05` 10000-frame soak, DMA ready=100% | parser state `F_IDLE`, `F_HDR0…3`, `F_SHD`, `F_HIT`, `F_EOF` all saturated |
| CROSS-087 | `checkpoint_soak` | OPQ page allocator FSM | dense `λ=0.50` 10000-frame soak | page allocator states visited at least 95% |
| CROSS-088 | `checkpoint_soak` | mux arbiter FSM | 4-lane symmetric hot soak 10000 frames | arbiter states and transitions ≥ 95% |
| CROSS-089 | `checkpoint_soak` | event builder FSM | `i_get_n_words` sweep over 10000 frames | event builder states × `i_get_n_words` cross ≥ 95% |
| CROSS-090 | `checkpoint_soak` | `gts_8n` MSB toggle | run starting near `gts_8n=2^47 - 2^24`, 50000 frames | `gts_8n[47:40]` all toggled |
| CROSS-091 | `checkpoint_soak` | `pkg_cnt` roll | run forcing `pkg_cnt` to cross `0xFFFF→0x0000` 10 times, 50000 frames | `pkg_cnt` wrap observed 10 times |
| CROSS-092 | `checkpoint_soak` | `feb_id` toggle | 256-id pool random draw, 10000 frames | `feb_id[15:0]` toggle ≥ 80% |
| CROSS-093 | `checkpoint_soak` | DMA payload-size bin cover | payload size drawn uniform from `{1, 4, 16, 64, 256, 1024, 2048}` | payload-size histogram saturated |
| CROSS-094 | `checkpoint_soak` | padding length bin | padding count drawn deterministic 128 per event; event count varied 1-8192 | padding runs observed at every event count |
| CROSS-095 | `checkpoint_soak` | OPQ tag reuse | 256-id pool with 5 active at any time, 100000 frames | tag table reuse coverage |
| CROSS-096 | `checkpoint_soak` | hit-field toggle | uniform hit-field draw, 100000 frames | `{Row, Col, TS1, TS2}` toggle ≥ 95% |
| CROSS-097 | `checkpoint_soak` | backpressure regime × saturation | `dma_ready_p ∈ {0.25,0.50,0.70,0.90}` × `λ ∈ {0.1,0.25,0.5}`, 4096 frames per cell | cross coverage matrix |
| CROSS-098 | `checkpoint_soak` | lane-mask × saturation | active lane set cycled through all 15 non-zero subsets | subset × saturation cross saturated |
| CROSS-099 | `checkpoint_soak` | `i_get_n_words` × payload-size | 7 grouping values × 5 payload sizes × 1024 frames each | grouping/payload cross saturated |
| CROSS-100 | `checkpoint_soak` | event-builder contract | BUG-004-R anchor: `o_done` timing documented at every grouping | documented timing table generated from run |
| CROSS-101 | `checkpoint_soak` | reset × stage cross | reset injected at every stage boundary, 10000 frames | reset × stage matrix saturated |
| CROSS-102 | `checkpoint_soak` | ghost K-char cover | K-char byte pattern injected in hit fields across 10000 frames | ghost K-char toggle ≥ 95% |
| CROSS-103 | `checkpoint_soak` | `shd_ts` full sweep | `shd_ts[11:4]` drawn uniform 0x00..0xFF over 10000 frames | `shd_ts` toggle ≥ 95% |
| CROSS-104 | `checkpoint_soak` | `abs_ts` monotonicity | cross-lane `abs_ts` drawn to produce identical values frequently | tie-break path exercised |
| CROSS-105 | `checkpoint_soak` | OPQ page boundary | `subheader_cnt` forced to `N_SHD-1, N_SHD` alternating | boundary bin saturated |
| CROSS-106 | `checkpoint_soak` | `MAX_HITS` boundary | `sub_hit_cnt ∈ {0, MAX_HITS-1, MAX_HITS}` weighted draw | boundary bin saturated |
| CROSS-107 | `checkpoint_soak` | hit TS2 edge | hit `TS2 ∈ {0x00, 0x1F}` weighted draw | TS2 extremes saturated |
| CROSS-108 | `checkpoint_soak` | `feb_type` × lane | `feb_type ∈ {0x3A,0x3B,0x30}` × lane 4 values | 12-bin cross saturated |
| CROSS-109 | `checkpoint_soak` | padding under backpressure | `dma_ready_p=0.5` × full padding 128 beats | backpressured-padding fully covered |
| CROSS-110 | `checkpoint_soak` | frame length bin | frame subheader count drawn from `{1, 8, 32, 64, 127, 128}` | frame-length histogram saturated |
| CROSS-111 | `checkpoint_soak` | lane skew bin | lane skew drawn from full `{0,1,16,64,256,1024,4096}` grid | lane-skew histogram saturated |
| CROSS-112 | `checkpoint_soak` | BUG-002-R watchdog | merge-enabled long soak with `o_done` latency measured | no stall observed in 50000 frames |
| CROSS-113 | `checkpoint_soak` | BUG-003-R watchdog | plain+2env replay compare for 10000 frames | per-hit ledger match every run |
| CROSS-114 | `checkpoint_soak` | BUG-006-H watchdog | seeded randomized run repeated 16 times | all 16 traces identical |
| CROSS-115 | `checkpoint_soak` | BUG-008-H watchdog | zero-payload corners injected every 128 frames over 50000 frames | no spurious failure |

### 6.9 Checkpoint-UCDB deep soaks (CROSS-116-129)

Very long runs whose main purpose is growth-curve evidence for coverage and wall-clock stability.

| case_id | ladder | scenario | checkpoint cadence | bug / coverage target |
|---|---|---|---|---|
| CROSS-116 | `checkpoint_soak` | `λ=0.25` seed 0x100, 10000 frames | `1,2,4,…,8192` | baseline growth curve |
| CROSS-117 | `checkpoint_soak` | `λ=0.50` seed 0x101, 10000 frames | `1,2,4,…,8192` | peak-sat growth curve |
| CROSS-118 | `checkpoint_soak` | `λ=0.05` seed 0x102, 10000 frames | `1,2,4,…,8192` | sparse growth curve |
| CROSS-119 | `checkpoint_soak` | mixed-λ per frame seed 0x103, 10000 frames | `1,2,4,…,8192` | random-shape growth curve |
| CROSS-120 | `checkpoint_soak` | `λ=0.25` seed 0x104, 50000 frames | `1,2,4,…,32768` | 5× horizon growth |
| CROSS-121 | `checkpoint_soak` | `λ=0.25` 2env seed 0x105, 50000 frames | `1,2,4,…,32768` | 2env long-horizon; BUG-009-H regression |
| CROSS-122 | `checkpoint_soak` | dense `λ=0.50` seed 0x106, 50000 frames | `1,2,4,…,32768` | peak-sat long-horizon |
| CROSS-123 | `checkpoint_soak` | `λ=0.25` seed 0x107, 100000 frames | `1,2,4,…,65536` | 10× baseline horizon |
| CROSS-124 | `checkpoint_soak` | `λ=0.50` seed 0x108, 100000 frames | `1,2,4,…,65536` | 10× peak horizon |
| CROSS-125 | `checkpoint_soak` | `λ=0.30`, `dma_ready_p=0.80` seed 0x109, 100000 frames | `1,2,4,…,65536` | 10× with backpressure |
| CROSS-126 | `checkpoint_soak` | `λ=0.30`, `dma_ready_p=0.50` seed 0x10A, 100000 frames | `1,2,4,…,65536` | 10× heavy backpressure |
| CROSS-127 | `checkpoint_soak` | `λ=0.25` lane skew drawn uniform `[0, 4096]` seed 0x10B, 100000 frames | `1,2,4,…,65536` | 10× with lane skew |
| CROSS-128 | `checkpoint_soak` | all-axes uniform random seed 0x10C, 100000 frames | `1,2,4,…,65536` | universal coverage soak |
| CROSS-129 | `checkpoint_soak` | all-axes uniform random seed 0x10D, 1000000 frames | `1,2,4,…,524288` | signoff-depth soak; nightly-only run |

## Execution modes

- **isolated** — per-run `python3 tb_int/cases/basic/uvm/run_longrun.py --runs <N> --campaign-seed <seed> --out-dir report/cross/<case_id>`.
- **`bucket_frame` and `all_buckets_frame`** — harness does not reset between composed cases; see harness support in [`DV_INT_HARNESS.md`](DV_INT_HARNESS.md) §6.
- **`checkpoint_soak`** — cadence `1, 2, 4, 8, …` frames; each checkpoint saves a UCDB under [`REPORT/txn_growth/<case_id>/`](REPORT/txn_growth/).

## Regenerate

```
python3 tb_int/scripts/build_dv_report_json.py --tb tb_int
python3 tb_int/scripts/dv_report_gen.py --tb tb_int
```
