# `REPORT/cases/<CASE_ID>.md` — per-case evidence template

> Replace `<CASE_ID>` with the planned canonical id (e.g. `B017`, `E044`, `P022`, `X112`). This file is the schema for every case page emitted by `dv_report_gen.py`. Hand edits are overwritten on the next run — fix the JSON or the generator.
>
> **Audience:** chief architect reviewing musip DV sign-off. Every column and row definition must be interpretable without opening the RTL, UVM source, or the generator.

## Header

- **case_id:** `<CASE_ID>` — id from the matching `DV_<BUCKET>.md` catalog
- **bucket:** `<BUCKET>` — one of `BASIC`, `EDGE`, `PROF`, `ERROR`, `CROSS`
- **scenario:** one-line paraphrase of the scenario column from the bucket catalog
- **contract anchor:** exact FEB AvST beat, subheader slot, hit field, or integrator-facing invariant that this case probes. Cite [`feb_frame_assembly.vhd`](../../../external/mu3e-ip-cores/feb_frame_assembly/feb_frame_assembly.vhd) beat name or the Mu3eSpecBook §5.2.6 hit field.
- **stage taps:** stages exercised (`A` plan · `I` ingress · `M` merge · `O` OPQ egress · `D` DMA packed · `E` event-builder retirement)
- **status:** one emoji from the legend (`✅ ⚠️ ❌ ❓ ℹ️`)

## Execution method

<!-- columns:
  method          = D = directed (single deterministic transaction) or R = randomised (N transactions)
  harness         = which harness ran this case (plain, plain_2env, uvm, formal)
  make_target     = promoted `make` target or documented invocation
  plusargs        = UVM plusargs or env vars set for this run (+SWB_REPLAY_DIR, +SWB_FRAMES, +SWB_CASE_SEED, +SWB_SATn, SWB_USE_MERGE, USE_MERGE, USE_BIT_MERGER, USE_BIT_STREAM, USE_BIT_GENERIC, ...)
  seed            = UVM run seed (for R); `n/a` for D
-->

| method | harness | make_target | plusargs | seed |
|:---:|---|---|---|---|
| D / R | plain · plain_2env · uvm · formal | `make ip-…` | `+…` | `<seed>` or `n/a` |

## Execution evidence

<!-- columns:
  outcome            = case-level health emoji
  sim_time           = simulated time observed at scoreboard finish
  txn_count          = number of scoreboard-accepted transactions (1 for D)
  ingress_hits       = hits observed at the ingress stage tap
  opq_hits           = hits observed at the OPQ-egress stage tap
  dma_hits           = hits observed at the DMA-packed stage tap
  payload_words      = payload word count observed before the 128-word padding tail
  padding_words      = padding word count observed on the DMA stream (fixed 128 in this IP)
  ghost_missing      = counted as `ghost=<N>, missing=<N>` at the ingress→opq→dma checker
  log_path           = relative pointer to the run log under `tb_int/cases/.../report/` or `uvm/cov_after/`
  ucdb_path          = relative pointer to the UCDB snapshot for this case
-->

| outcome | sim_time | txn_count | ingress_hits | opq_hits | dma_hits | payload_words | padding_words | ghost_missing | log_path | ucdb_path |
|:---:|---|---:|---:|---:|---:|---:|---:|---|---|---|
| ❓ | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending |

## Isolated coverage

<!-- From this case's own UCDB run in `isolated` mode. Vector layout matches the skill's strict coverage-encoding. -->

<!-- columns:
  metric   = coverage category from the skill §Coverage table
  value    = percent from this case's own UCDB
  target   = per-skill category target (not always gating for a single case)
  note     = any RTL/harness caveat (e.g. "fsm_trans covers only MERGE state fan-in")
-->

| metric | value | target | note |
|---|---:|---:|---|
| stmt | pending | 95.0 | |
| branch | pending | 90.0 | |
| cond | pending | 85.0 | |
| expr | pending | 85.0 | |
| fsm_state | pending | 95.0 | |
| fsm_trans | pending | 90.0 | |
| toggle | pending | 80.0 | |
| functional | pending | bucket-dependent | linkage to [`../../DV_CROSS.md`](../../DV_CROSS.md) cross cluster |

## Bucket gain (vs. ordered-merge baseline)

The incremental gain this case contributed to its bucket's ordered merge, versus the merged baseline of all previously-added cases in the bucket. See [`../buckets/<BUCKET>.md`](../buckets/BASIC.md) for the full ordered trace.

<!-- columns:
  metric          = coverage category
  prev_baseline   = bucket merged total before this case was added
  after           = bucket merged total after this case was added
  gain            = after − prev_baseline; must match the row in the bucket's ordered-merge trace
-->

| metric | prev_baseline | after | gain |
|---|---:|---:|---:|
| stmt | pending | pending | pending |
| branch | pending | pending | pending |
| cond | pending | pending | pending |
| expr | pending | pending | pending |
| fsm_state | pending | pending | pending |
| fsm_trans | pending | pending | pending |
| toggle | pending | pending | pending |

## Per-txn gain

Required for randomised (R) cases. Mirrors `coverage_by_this_case` for directed (D) cases because a directed case is treated as one deterministic transaction.

<!-- columns:
  metric          = coverage category
  incr_per_txn    = average incremental gain per accepted transaction, same vector layout
  saturation_knee = transaction count at which the curve visibly flattens (from txn_growth/<CASE_ID>.md)
-->

| metric | incr_per_txn | saturation_knee |
|---|---:|---:|
| stmt | pending | pending |
| branch | pending | pending |
| cond | pending | pending |
| expr | pending | pending |
| fsm_state | pending | pending |
| fsm_trans | pending | pending |
| toggle | pending | pending |

For R cases, the full checkpoint curve is under [`../txn_growth/<CASE_ID>.md`](../txn_growth/README.md).

## Waveform and debug artifacts

<!-- columns:
  artifact   = what the file is
  path       = pointer relative to this page
  note       = handoff caveat, signal grouping, or reviewer aid
-->

| artifact | path | note |
|---|---|---|
| Questa wlf | `../../cases/.../*.wlf` | pending |
| `.gtkw` save | `../../cases/.../*.gtkw` | pending |
| per-hit ingress ledger | `../../cases/basic/uvm/report/*_ingress_hits.tsv` | pending |
| per-hit OPQ ledger     | `../../cases/basic/uvm/report/*_opq_hits.tsv` | pending |
| per-hit DMA ledger     | `../../cases/basic/uvm/report/*_dma_hits.tsv` | pending |
| scoreboard summary     | `../../cases/basic/uvm/report/*_summary.txt` | pending |

## Linked evidence

- Planning row for this case: [`../../DV_<BUCKET>.md`](../../DV_BASIC.md)
- Bucket ordered-merge row for this case: [`../buckets/<BUCKET>.md`](../buckets/BASIC.md)
- Bug ledger (if this case anchors a BUG entry): [`../../BUG_HISTORY.md`](../../BUG_HISTORY.md)
- Related continuous-frame signoff (if participating in a `bucket_frame` or `all_buckets_frame` baseline): [`../cross/README.md`](../cross/README.md)
- Stimulus field map anchor: [`../../DV_BASIC.md#stimulus-field-map-per-frame-per-lane`](../../DV_BASIC.md#stimulus-field-map-per-frame-per-lane)
