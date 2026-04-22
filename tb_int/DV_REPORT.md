# DV Report — `tb_int` MuSiP SWB/OPQ integration

**DUT:** `swb_block` (`ingress_egress_adaptor` → Qsys-generated native-SV OPQ merge → `musip_mux_4_1` → `musip_event_builder`)
**Date:** `2026-04-22`
**Branch:** `yifeng-ip_sim-2604`
**Toolchain:** `/data1/questaone_sim/questasim` (full Siemens Questa, ETH floating license `8161@lic-mentor.ethz.ch`)

Chief-architect-facing dashboard only. Machine-readable source: [`DV_REPORT.json`](DV_REPORT.json). Per-case detail lives under [`REPORT/`](REPORT/). Plan: [`DV_INT_PLAN.md`](DV_INT_PLAN.md). Harness: [`DV_INT_HARNESS.md`](DV_INT_HARNESS.md). Coverage: [`DV_COV.md`](DV_COV.md). Bug ledger: [`BUG_HISTORY.md`](BUG_HISTORY.md).

Planning files: [`DV_BASIC.md`](DV_BASIC.md) · [`DV_EDGE.md`](DV_EDGE.md) · [`DV_PROF.md`](DV_PROF.md) · [`DV_ERROR.md`](DV_ERROR.md) · [`DV_CROSS.md`](DV_CROSS.md).

## Legend

✅ pass / closed &middot; ⚠️ partial / <gloss> &middot; ❌ <gloss> &middot; ❓ pending &middot; ℹ️ informational

## Health

<!-- columns:
  status = health emoji
  field  = integration gate (matches DV_REPORT.json.summary keys)
  value  = one-sentence evidence summary
-->

| status | field | value |
|:---:|---|---|
| ✅ | `supported_toolchain_installed` | full Siemens Questa runtime active on teferi |
| ✅ | `license_check` | ETH floating features reachable |
| ✅ | `replay_generator` | smoke and full replay bundles generated and reparsed cleanly |
| ✅ | `local_integrated_smoke` | merge-enabled authentic-wrapper SWB smoke passes on the promoted integrated path |
| ✅ | `local_integrated_full_replay` | merge-enabled authentic-wrapper full replay passes end to end on the promoted integrated path |
| ✅ | `local_default_uvm_run` | default randomized mixed-language UVM run passes |
| ✅ | `local_plain_semantic_hit_check` | plain replay bench closes on normalized per-hit payload content |
| ✅ | `local_uvm_hit_trace` | seeded UVM run exports per-hit ingress/OPQ/DMA ledgers with zero ghost/missing hits |
| ✅ | `local_uvm_longrun_cross_0_50_128` | 128-run per-lane `0.0..0.5` cross-random campaign passes cleanly |
| ✅ | `opq_boundary_audit` | `ip-plain-basic-2env` smoke and full replay pass |
| ✅ | `seam_formal` | `ip-formal-boundary` packet-contract scaffold passes |
| ✅ | `implemented_catalog_cases` | all 516 case pages, 129 cross-run pages, and 129 txn-growth pages are rendered in the report tree |
| ✅ | `event_builder_contract_cleanup` | `BUG-004-R` is fixed in the musip-local event-builder RTL |
| ⚠️ | `coverage_merged_totals` | merged UCDB totals are now measured; current percentages remain below signoff targets, see [`DV_COV.md`](DV_COV.md) |

## Bucket summary

<!-- columns:
  status          = bucket-level emoji
  bucket          = DV bucket pointer
  planned         = count in canonical catalog
  evidenced       = count with isolated evidence in REPORT/cases/
  merged_totals   = running merged code-coverage total after bucket's ordered merge (pending UCDB wiring)
  functional_pct  = functional coverage percent for the bucket (pending)
  trace           = pointer to REPORT/buckets/<bucket>.md for the ordered-merge audit trail
-->

| status | bucket | planned | implemented | evidenced | merged_totals | functional_pct | trace |
|:---:|---|---:|---:|---:|---|---:|---|
| ⚠️ | [BASIC](DV_BASIC.md) | 129 | 129 | 1 | pending | pending | [`REPORT/buckets/BASIC.md`](REPORT/buckets/BASIC.md) |
| ⚠️ | [EDGE](DV_EDGE.md) | 129 | 129 | 3 | pending | pending | [`REPORT/buckets/EDGE.md`](REPORT/buckets/EDGE.md) |
| ⚠️ | [PROF](DV_PROF.md) | 129 | 129 | 1 | pending | pending | [`REPORT/buckets/PROF.md`](REPORT/buckets/PROF.md) |
| ⚠️ | [ERROR](DV_ERROR.md) | 129 | 129 | 0 | pending | pending | [`REPORT/buckets/ERROR.md`](REPORT/buckets/ERROR.md) |
| ⚠️ | [CROSS](DV_CROSS.md) | 129 | 129 | 0 | pending | pending | [`REPORT/buckets/CROSS.md`](REPORT/buckets/CROSS.md) · [`REPORT/cross/README.md`](REPORT/cross/README.md) |

## Validation matrix (promoted targets)

<!-- mirror of DV_REPORT.json.targets; every row must match a make target or a documented invocation. -->

| status | target | result |
|:---:|---|---|
| ✅ | `make ip-check-license` | ETH Siemens/Mentor features reachable |
| ✅ | `make ip-tlm-basic-smoke` | smoke replay bundle generated and reparsed cleanly |
| ✅ | `make ip-tlm-basic` | full Poisson replay bundle generated and reparsed cleanly |
| ✅ | `make ip-plain-basic-smoke` | `expected_words=2 actual_words=130 expected_hits=8 actual_hits=8 actual_padding_words=128 order_exact=1` |
| ✅ | `make ip-plain-basic` | `expected_words=950 actual_words=1078 expected_hits=3800 actual_hits=3800 actual_padding_words=128 order_exact=0` |
| ✅ | `make ip-uvm-basic SIM_ARGS=+SWB_REPLAY_DIR=$(pwd)/tb_int/cases/basic/ref/out_smoke` | `opq expected=8 actual=8`, `dma expected=8 actual=8`, payload `2` + padding `128` |
| ✅ | `make ip-uvm-basic SIM_ARGS=+SWB_REPLAY_DIR=$(pwd)/tb_int/cases/basic/ref/out` | `opq expected=3800 actual=3800`, `dma expected=3800 actual=3800`, payload `950` + padding `128` |
| ✅ | `make ip-uvm-basic` | default randomized case passes with merge enabled: `payload_words=951`, `padding_words=128`, `ingress/opq/dma=3804/3804/3804` |
| ✅ | `make ip-uvm-basic SIM_ARGS='+SWB_PROFILE_NAME=B046_lane0_only +SWB_CASE_SEED=4242 +SWB_FEB_ENABLE_MASK=1 +SWB_SAT0=0.20 +SWB_SAT1=0.40 +SWB_SAT2=0.60 +SWB_SAT3=0.80'` | lane-mask directed case passes after the musip-local ingress mask fix: `opq expected=368 actual=368`, `dma expected=368 actual=368` |
| ✅ | `make ip-uvm-basic SIM_ARGS='+SWB_PROFILE_NAME=E025_zero_hit +SWB_CASE_SEED=111 +SWB_HIT_MODE=zero +SWB_SAT0..3=0.20'` | zero-hit subheader closes legally with `payload_words=0`, `ingress/opq/dma=0/0/0` |
| ✅ | `make ip-uvm-basic SIM_ARGS='+SWB_PROFILE_NAME=E026_single_hit +SWB_CASE_SEED=112 +SWB_FRAMES=1 +SWB_HIT_MODE=single +SWB_SAT0..3=0.20'` | single-hit subheader passes: `payload_words=256`, `ingress/opq/dma=1024/1024/1024` |
| ✅ | `make ip-uvm-basic SIM_ARGS='+SWB_PROFILE_NAME=E027_max_hit_lane0_only +SWB_CASE_SEED=113 +SWB_FRAMES=1 +SWB_HIT_MODE=max +SWB_FEB_ENABLE_MASK=1 +SWB_SAT0..3=0.20'` | bounded legal `MAX_HITS` case passes within the default `OPQ_N_HIT` budget: `opq expected=1024 actual=1024`, `dma expected=1024 actual=1024` |
| ✅ | `make ip-uvm-basic SIM_ARGS='+SWB_PROFILE_NAME=P040_dma_half_full_50 +SWB_CASE_SEED=5151 +SWB_DMA_HALF_FULL_PCT=50 +SWB_SAT0..3=0.20'` | heavy DMA half-full backpressure passes: `payload_words=410`, `ingress/opq/dma=1640/1640/1640` |
| ✅ | `make ip-uvm-basic SIM_ARGS='+SWB_FRAMES=2 +SWB_CASE_SEED=12345 +SWB_SAT0..3=0.10..0.40 +SWB_HIT_TRACE_PREFIX=…/single_seed'` | `scoreboard_pass=1`, payload `509`, padding `128`, ingress/opq/dma `2036/2036/2036`, zero ghost/missing |
| ✅ | `make ip-uvm-longrun` | default wrapper `pass_count=128 fail_count=0`; summary in `cases/basic/uvm/report/longrun/summary.json` |
| ✅ | `make ip-plain-basic-2env-smoke` | `OPQ_BOUNDARY_SUMMARY` and `DMA_SUMMARY` pass |
| ✅ | `make ip-plain-basic-2env` | full OPQ-boundary replay passes |
| ✅ | `make ip-formal-boundary` | SymbiYosys seam scaffold passes |
| ✅ | `make ip-cov-closure` | promoted replay-bearing harnesses now emit and merge UCDBs under `tb_int/sim_runs/coverage/`; merged totals are published in [`DV_COV.md`](DV_COV.md) |
| ✅ | `make ip-lint-rtl` | strict bridge/wrapper house-style and imported-RTL hygiene checks pass |

## Per-hit tracking (promoted contract)

The UVM scoreboard reconstructs normalized 64-bit hits and a non-overflowing 8 ns debug timestamp at three stages: ingress of SWB, merged stream out of OPQ, DMA payload stream. The checker assigns a hidden ID from the ingress-derived expected merged stream and then requires the same hit identity at OPQ and DMA.

A passing traced run writes:

- [`single_seed_expected_hits.tsv`](cases/basic/uvm/report/single_seed_expected_hits.tsv)
- [`single_seed_ingress_hits.tsv`](cases/basic/uvm/report/single_seed_ingress_hits.tsv)
- [`single_seed_opq_hits.tsv`](cases/basic/uvm/report/single_seed_opq_hits.tsv)
- [`single_seed_dma_hits.tsv`](cases/basic/uvm/report/single_seed_dma_hits.tsv)
- [`single_seed_summary.txt`](cases/basic/uvm/report/single_seed_summary.txt)

Promoted pass conditions: zero parser errors, correct payload length, observed `o_endofevent`, observed `dma_done`, zero OPQ ghost/missing, zero DMA ghost/missing, `SWB_CHECK_PASS` present.

## Stimulus contract (authoritative source)

The per-lane FEB AvST grammar driving every case is anchored on the `feb_frame_assembly` source folder in [`../external/mu3e-ip-cores/feb_frame_assembly/`](../external/mu3e-ip-cores/feb_frame_assembly/) and reflects Mu3eSpecBook §5.2.6 (MuPix hit word). The field map is reproduced in [`DV_BASIC.md`](DV_BASIC.md#stimulus-field-map-per-frame-per-lane) and referenced by every case in [`DV_EDGE.md`](DV_EDGE.md), [`DV_PROF.md`](DV_PROF.md), [`DV_ERROR.md`](DV_ERROR.md), and [`DV_CROSS.md`](DV_CROSS.md). Deviations from this grammar are intentional fault injection and are named explicitly in the scenario column of the case catalog.

## Findings

- The active integrated simulation source in this workspace is the musip-regenerated authentic Qsys wrapper under `firmware/a10_board/a10/merger/qsys/opq_upstream_4lane_native_sv/generated/`. The former direct-path workaround and the deprecated local OPQ owner are retired in the promoted flow.
- The plain replay bench no longer depends on packed-word identity alone. `tb_int/cases/basic/plain/check_dma_hits.py` compares normalized 64-bit hits, so repacking differences that preserve the real hit contract do not cause false failures.
- The UVM harness supports exact rerun of randomized cases through `+SWB_CASE_SEED=<n>`. The promoted long-run driver records that seed for every run.
- The split `plain_2env/` harness feeds the downstream DMA scoreboard from the same ingress replay used by the OPQ boundary scoreboard, so smoke and full replay close on the same per-hit DMA contract as the integrated path.
- The musip-owned SWB integration now honors `feb_enable_mask` before `ingress_egress_adaptor`, so masked FEB lanes no longer leak into the promoted OPQ/DMA hit ledger (`B046` / `BUG-010-R`).
- `dma_done` is `musip_event_builder.o_done` and now retires through an explicit non-zero launch, last-payload, and fixed-padding contract in the musip-owned RTL.
- External upstream `signoff_4lane` alignment is not part of the local musip signoff gate; it may be audited separately (see `CROSS-055` in [`DV_CROSS.md`](DV_CROSS.md) §6.6).

## Current posture

| item | state |
|---|---|
| promoted simulator | `/data1/questaone_sim/questasim` |
| local integrated default | merge enabled (`SWB_USE_MERGE=1`, `USE_MERGE=1`) |
| promoted replay owner | `OPQ_SOURCE_MODE=upstream_qsys_generated` |
| promoted Qsys package | `ordered_priority_queue_native_sv_fixed4_26422504` |
| boundary audit owner | `ip-plain-basic-2env` |
| randomized screen owner | `ip-uvm-longrun` |
| stimulus authoritative source | `feb_frame_assembly.vhd` + Mu3eSpecBook §5.2.6 |
| DV catalog shape | `B001-B129` · `E001-E129` · `P001-P129` · `X001-X129` · `CROSS-001-CROSS-129` |
| per-case evidence pages | `REPORT/cases/` (516 / 516 implemented pages, 5 promoted evidence anchors, 511 explicit pending stubs) · `REPORT/cross/` (129 / 129 implemented run-shape pages) · `REPORT/txn_growth/` (129 / 129 implemented checkpoint pages) |

## Evidence index

- [`DV_INT_PLAN.md`](DV_INT_PLAN.md) — plan, locked decisions, signoff boundary
- [`DV_INT_HARNESS.md`](DV_INT_HARNESS.md) — harness topology, monitors, plusargs
- [`BUG_HISTORY.md`](BUG_HISTORY.md) — live bug ledger (BUG-001-H..BUG-010-R)
- [`DV_REPORT.json`](DV_REPORT.json) — machine-readable dashboard
- [`DV_COV.md`](DV_COV.md) — coverage dashboard
- [`doc/SIGNOFF.md`](doc/SIGNOFF.md) — integrated signoff dashboard
- [`REPORT/README.md`](REPORT/README.md) — per-case / per-bucket / per-cross reviewer entry
- [`cases/basic/ref/out/summary.json`](cases/basic/ref/out/summary.json) — full replay bundle summary
- [`cases/basic/ref/out_smoke/summary.json`](cases/basic/ref/out_smoke/summary.json) — smoke replay bundle summary
- [`cases/basic/uvm/report/longrun/summary.json`](cases/basic/uvm/report/longrun/summary.json) — promoted default 128-run randomized screen

## Remaining work

1. Close the measured merged-coverage gaps against the signoff targets in [`DV_COV.md`](DV_COV.md); current merged totals are `stmt=68.02`, `branch=60.13`, `cond=21.27`, `expr=45.42`, `fsm_state=54.44`, `fsm_trans=25.42`, `toggle=18.17`, `functional=47.81`.
2. Promote additional isolated evidence pages beyond the five executed anchor cases if case-by-case rerun collateral is required for signoff review.
3. Keep any upstream packet-scheduler alignment work separate from the musip-local signoff gate in this repo (`CROSS-055` is informational).

## Regenerate

```bash
python3 tb_int/scripts/dv_report_gen.py --tb tb_int
```
