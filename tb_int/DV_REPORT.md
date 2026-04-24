# ✅ DV Report — `tb_int` MuSiP SWB/OPQ integration

**DUT:** `swb_block` (`ingress_egress_adaptor` → Qsys-generated native-SV OPQ merge → `musip_mux_4_1` → `musip_event_builder`)
**Date:** `2026-04-24`
**Branch:** `yifeng-ip_sim-2604`

This page is the chief-architect dashboard. All per-case evidence lives under [`REPORT/`](REPORT/README.md).

## Legend

✅ pass / closed &middot; ⚠️ partial / below target / evidence pending &middot; ❌ failed / missing evidence &middot; ❓ pending &middot; ℹ️ informational

## Health

| status | field | value |
|:---:|---|---|
| ✅ | `supported_toolchain_installed` | full Siemens Questa runtime active at `/data1/questaone_sim/questasim` |
| ✅ | `license_check` | ETH floating Siemens/Mentor features reachable |
| ✅ | `replay_generator` | smoke and full replay bundles generate and reparse cleanly |
| ✅ | `local_integrated_smoke` | merge-enabled authentic-wrapper SWB smoke passes on the promoted integrated path |
| ✅ | `local_integrated_full_replay` | merge-enabled authentic-wrapper full replay passes end to end on the promoted integrated path |
| ✅ | `local_default_uvm_run` | default randomized mixed-language UVM run passes |
| ✅ | `local_plain_semantic_hit_check` | plain replay bench closes on normalized per-hit payload content |
| ✅ | `local_uvm_hit_trace` | seeded UVM run exports per-hit ingress/OPQ/DMA ledgers with zero ghost/missing hits |
| ✅ | `local_uvm_longrun_cross_0_50_128` | default 128-run per-lane `0.0..0.5` randomized screen passes cleanly |
| ✅ | `opq_boundary_audit` | `ip-plain-basic-2env` smoke and full replay pass |
| ✅ | `seam_formal` | `ip-formal-boundary` seam scaffold passes |
| ✅ | `implemented_catalog_cases` | all `516` case pages and `129` cross pages are present under `REPORT/` |
| ✅ | `implemented_cross_runs` | `5` / `129` cross pages have promoted evidence; required CROSS-001..005 baselines are tracked in Signoff Runs |
| ✅ | `event_builder_contract_cleanup` | `BUG-004-R` is fixed in the musip-local `musip_event_builder` RTL |
| ✅ | `coverage_merged_totals` | merged UCDB totals are measured: stmt=80.56, branch=75.95, cond=47.58, expr=57.81, fsm_state=90.09, fsm_trans=53.29, toggle=35.11, functional=100.00 |

## Signoff Scope

| field | claimed value |
|---|---|
| workspace | `tb_int` |
| dut | `swb_block integrated SWB/OPQ path` |
| opq_source_mode | `upstream_qsys_generated` |
| simulator | `/data1/questaone_sim/questasim` |
| license_server | `8161@lic-mentor.ethz.ch` |
| stimulus_source | `firmware/a10_board/a10/merger/../feb_frame_assembly/feb_frame_assembly.vhd` |
| coverage_ucdb | `/home/yifeng/packages/musip_2604/tb_int/sim_runs/coverage/tb_int_merged.ucdb` |

## Non-Claims

- External upstream `packet_scheduler` `signoff_4lane` alignment remains informational and is not part of the musip-local signoff gate in this repo.
- The catalog is structurally complete, but only the promoted anchor cases currently carry isolated rerun evidence; the remaining pages are explicit implemented placeholders.
- CROSS-001..005 are promoted anchor-segment continuous-frame baselines, not an exhaustive execution of every planned or variant-only catalog row.

## Bucket Summary

| status | bucket | catalog_planned | promoted | evidenced | backlog | merged | promoted functional |
|:---:|---|---:|---:|---:|---:|---|---|
| ⚠️ | [`BASIC`](REPORT/buckets/BASIC.md) | 129 | 129 | 7 | 122 | pending | pending (7/129) |
| ⚠️ | [`EDGE`](REPORT/buckets/EDGE.md) | 129 | 129 | 3 | 126 | pending | pending (3/129) |
| ⚠️ | [`PROF`](REPORT/buckets/PROF.md) | 129 | 129 | 6 | 123 | pending | pending (6/129) |
| ⚠️ | [`ERROR`](REPORT/buckets/ERROR.md) | 129 | 129 | 13 | 116 | pending | pending (13/129) |

## Totals

| status | metric | pct | target |
|:---:|---|---|---|
| ✅ | stmt | 80.56 | 80.0 |
| ✅ | branch | 75.95 | 75.0 |
| ✅ | cond | 47.58 | 45.0 |
| ✅ | expr | 57.81 | 55.0 |
| ✅ | fsm_state | 90.09 | 89.0 |
| ✅ | fsm_trans | 53.29 | 50.0 |
| ✅ | toggle | 35.11 | 35.0 |
| ✅ | functional | 100.00 | 100.0 |

- catalog_planned_cases: `516`
- promoted_signoff_cases: `516`
- evidenced_promoted_cases: `29`
- promoted functional coverage: `100.00% (merged UCDB total)`

## Signoff Runs

| status | run_id | kind | build | seq | txns | cross_pct |
|:---:|---|---|---|---|---:|---:|
| ✅ | [`CROSS-001`](REPORT/cross/CROSS-001.md) | bucket_frame | make ip-cross-baselines | promoted BASIC anchors B001,B002,B046-B049 in one no-restart frame | 6 | 36.88 |
| ✅ | [`CROSS-002`](REPORT/cross/CROSS-002.md) | bucket_frame | make ip-cross-baselines | promoted EDGE anchors E025-E027 in one no-restart frame | 3 | 39.88 |
| ✅ | [`CROSS-003`](REPORT/cross/CROSS-003.md) | bucket_frame | make ip-cross-baselines | promoted PROF anchors P040,P041,P123,P124 in one no-restart frame | 4 | 31.46 |
| ✅ | [`CROSS-004`](REPORT/cross/CROSS-004.md) | bucket_frame | make ip-cross-baselines | promoted ERROR anchors X111,X112,X116-X118,X120,X122-X124 in one no-restart frame | 9 | 41.46 |
| ✅ | [`CROSS-005`](REPORT/cross/CROSS-005.md) | all_buckets_frame | make ip-cross-baselines | promoted BASIC to EDGE to PROF to ERROR anchors with exactly one reset per bucket transition | 22 | 52.88 |
| ✅ | [`ip-uvm-longrun`](cases/basic/uvm/report/longrun/summary.json) | random_screen | make ip-uvm-longrun | default 128-run rate grid | 128 | pending |

## Index

- [`REPORT/README.md`](REPORT/README.md) — reviewer entry point
- [`REPORT/buckets/`](REPORT/buckets/) — ordered-merge trace per bucket
- [`REPORT/cases/`](REPORT/cases/) — one page per case
- [`REPORT/cross/`](REPORT/cross/) — one page per signoff run
- [`DV_COV.md`](DV_COV.md) — coverage totals, per-harness merges, and baseline scope
- [`DV_REPORT.json`](DV_REPORT.json) — machine-readable source of truth
- [`BUG_HISTORY.md`](BUG_HISTORY.md) — live bug ledger
- [`doc/SIGNOFF.md`](doc/SIGNOFF.md) — integrated signoff dashboard

_This dashboard is generated by `python3 tb_int/scripts/dv_report_gen.py --tb tb_int`. Edits are overwritten; fix the JSON or the generator instead._
