# DV Coverage Summary — `tb_int` MuSiP SWB/OPQ integration

Chief-architect-facing dashboard only. Per-case incremental coverage rows live under [`REPORT/cases/`](REPORT/cases/); per-bucket ordered merge traces under [`REPORT/buckets/`](REPORT/buckets/); continuous-frame signoff runs under [`REPORT/cross/`](REPORT/cross/); random-case checkpoint curves under [`REPORT/txn_growth/`](REPORT/txn_growth/).

Plan references: [`DV_INT_PLAN.md`](DV_INT_PLAN.md) · [`DV_INT_HARNESS.md`](DV_INT_HARNESS.md) · [`DV_BASIC.md`](DV_BASIC.md) · [`DV_EDGE.md`](DV_EDGE.md) · [`DV_PROF.md`](DV_PROF.md) · [`DV_ERROR.md`](DV_ERROR.md) · [`DV_CROSS.md`](DV_CROSS.md) · [`BUG_HISTORY.md`](BUG_HISTORY.md).

## Legend

✅ pass / closed &middot; ⚠️ partial / <gloss> &middot; ❌ <gloss> &middot; ❓ pending &middot; ℹ️ informational

## Targets vs merged totals (all buckets union)

<!-- columns:
  status      = dashboard emoji per legend
  metric      = code coverage category per dv-workflow skill
  merged_pct  = union of every evidenced UCDB across every bucket for the promoted build
  target      = bucket-union target from skill §Coverage; unset means not a gating metric
-->

| status | metric | merged_pct | target |
|:---:|---|---:|---:|
| ⚠️ | stmt | 68.02 | 95.0 |
| ⚠️ | branch | 60.13 | 90.0 |
| ⚠️ | cond | 21.27 | 85.0 |
| ⚠️ | expr | 45.42 | 85.0 |
| ⚠️ | fsm_state | 54.44 | 95.0 |
| ⚠️ | fsm_trans | 25.42 | 90.0 |
| ⚠️ | toggle | 18.17 | 80.0 |
| ⚠️ | functional | 47.81 | 100.0 bins saturated (see [`DV_CROSS.md`](DV_CROSS.md) §4) |

Current state: `make ip-cov-closure` now emits and merges UCDBs for the promoted replay-bearing harnesses under [`tb_int/sim_runs/coverage/`](sim_runs/coverage/). The flow itself is closed, but the measured merged totals remain below the signoff targets and the continuous-frame baselines are still placeholder-only.

## Per-bucket dashboard

<!-- columns:
  status               = bucket-level health emoji
  bucket               = DV bucket (planning file pointer)
  cases_planned        = count in the canonical catalog
  cases_evidenced      = count with an isolated evidence page under REPORT/cases/
  merged_after_bucket  = running merged code-coverage total after the bucket's ordered merge
  trace                = pointer to REPORT/buckets/<bucket>.md for the ordered-merge row-by-row audit
-->

| status | bucket | cases_planned | cases_implemented | cases_evidenced | merged_after_bucket | trace |
|:---:|---|---:|---:|---:|---|---|
| ⚠️ | [BASIC](DV_BASIC.md) | 129 | 129 | 1 | pending | [`REPORT/buckets/BASIC.md`](REPORT/buckets/BASIC.md) |
| ⚠️ | [EDGE](DV_EDGE.md) | 129 | 129 | 3 | pending | [`REPORT/buckets/EDGE.md`](REPORT/buckets/EDGE.md) |
| ⚠️ | [PROF](DV_PROF.md) | 129 | 129 | 1 | pending | [`REPORT/buckets/PROF.md`](REPORT/buckets/PROF.md) |
| ⚠️ | [ERROR](DV_ERROR.md) | 129 | 129 | 0 | pending | [`REPORT/buckets/ERROR.md`](REPORT/buckets/ERROR.md) |
| ⚠️ | [CROSS](DV_CROSS.md) | 129 | 129 | 0 | pending | [`REPORT/buckets/CROSS.md`](REPORT/buckets/CROSS.md) · [`REPORT/cross/README.md`](REPORT/cross/README.md) |

## Per-bucket row contract

<!-- every bucket's REPORT/buckets/<bucket>.md carries one row per case in the canonical order,
     with the strict column set below: -->

```
| case_id | type (d/r) | coverage_by_this_case | executed random txn | coverage_incr_per_txn |
```

- `case_id` — planned canonical id (`B001`, `E017`, `P022`, `X053`, `CROSS-038`)
- `type (d/r)` — `d` for directed, `r` for randomized
- `coverage_by_this_case` — incremental code-coverage gain added by this case vs. the previously merged baseline for the active execution mode, as an explicit vector `stmt=x, branch=y, cond=z, expr=a, fsm_state=b, fsm_trans=c, toggle=d`
- `executed random txn` — for `r` cases, the observed transaction count; `0` for directed
- `coverage_incr_per_txn` — per-transaction incremental gain (same vector layout); for `d` cases, mirrors `coverage_by_this_case`

## Execution-mode baselines

<!-- columns:
  mode                   = canonical execution mode name
  build                  = promoted make target that produced the UCDB
  case_ordering          = deterministic ordering used for this baseline run
  merged_total           = union of UCDBs across the mode (pending coverage wiring)
  trace                  = pointer to the full evidence page for the run
-->

| mode | build | case_ordering | merged_total | trace |
|---|---|---|---|---|
| isolated | `make ip-uvm-basic`, `make ip-plain-basic`, `make ip-plain-basic-2env` per case | each case under its own harness restart | pending | [`REPORT/cases/`](REPORT/cases/) |
| bucket_frame BASIC | `make ip-uvm-basic` continuous | `B001, B002, …, B129` | pending | [`REPORT/cross/CROSS-001.md`](REPORT/cross/CROSS-001.md) |
| bucket_frame EDGE | same | `E001, E002, …, E129` | pending | [`REPORT/cross/CROSS-002.md`](REPORT/cross/CROSS-002.md) |
| bucket_frame PROF | same | `P001, P002, …, P129` | pending | [`REPORT/cross/CROSS-003.md`](REPORT/cross/CROSS-003.md) |
| bucket_frame ERROR | same | `X001, X002, …, X129` | pending | [`REPORT/cross/CROSS-004.md`](REPORT/cross/CROSS-004.md) |
| all_buckets_frame | same | `BASIC → EDGE → PROF → ERROR`, case-id order within | pending | [`REPORT/cross/CROSS-005.md`](REPORT/cross/CROSS-005.md) |

## Per-harness merged totals

<!-- columns:
  status    = harness-level emoji
  harness   = evidence owner (per DV_INT_HARNESS.md)
  stmt .. toggle = promoted-build merged percentages (pending UCDB)
-->

| status | harness | stmt | branch | cond | expr | fsm_state | fsm_trans | toggle |
|:---:|---|---:|---:|---:|---:|---:|---:|---:|
| ⚠️ | [`cases/basic/uvm/`](cases/basic/uvm/) | 68.51 | 60.91 | 23.27 | 46.38 | 54.78 | 25.57 | 19.53 |
| ⚠️ | [`cases/basic/plain/`](cases/basic/plain/) | 66.81 | 58.76 | 19.83 | 43.78 | 54.78 | 25.57 | 18.72 |
| ⚠️ | [`cases/basic/plain_2env/`](cases/basic/plain_2env/) | 70.55 | 62.28 | 18.80 | 58.33 | 50.00 | 23.08 | 10.09 |
| ℹ️ | [`cases/basic/plain_2env/formal/`](cases/basic/plain_2env/formal/) | n/a | n/a | n/a | n/a | n/a | n/a | n/a (formal-scope only, not part of code coverage) |

## Functional coverage families (planned)

Map onto the stage contract in [`DV_INT_PLAN.md`](DV_INT_PLAN.md) §5. These are planned coverage families; the UVM harness does not yet emit them.

| status | family | scope | expected collector |
|:---:|---|---|---|
| ❓ | `cov_ingress_packet` | per-lane FEB AvST grammar: SOP, header0/1, debug0/1, subheader marker, hit beat, trailer; `feb_type`, `feb_id`, `pkg_cnt`, `gts_8n` bands | per-lane covergroup in `cases/basic/uvm/sv/swb_agents.sv` |
| ❓ | `cov_hit_field` | hit word `{Row, Col, TS1, TS2}` toggle + bucket-value coverage (Mu3eSpecBook 5.2.6 item 80) | covergroup sampled at ingress monitor |
| ❓ | `cov_subheader_field` | subheader `{shd_ts, TBD, sub_hit_cnt}` × frame `subheader_cnt` position | covergroup at subheader monitor |
| ❓ | `cov_merge_mode` | bypass vs integrated `ingress_egress_adaptor` path × `USE_MERGE` × `USE_BIT_*` × `N_SHD` residency | wrapper-level covergroup in `cases/basic/uvm/sv/swb_scoreboard.sv` |
| ❓ | `cov_mux_pack` | `musip_mux_4_1` packing: 4 hits per 256-bit beat × lane priority × `i_use_direct_mux` | covergroup on stage-D observations |
| ❓ | `cov_event_builder` | `musip_event_builder` retirement: `i_get_n_words` bands × payload/padding ratio × `o_endofevent` / `o_done` latency | covergroup on stage-E observations |
| ❓ | `cov_dma_backpressure` | `dma_ready_p` × payload size × padding position | covergroup on stage-D/E |
| ❓ | `cov_replay_shape` | replay bundle profile × per-lane saturation band × frame count × seed | replay-side sampling cross |
| ❓ | `cov_lane_mask_cross` | active lane subset × per-lane saturation | cross covergroup at wrapper level |

## Cross-harness signoff baselines

<!-- Tracked in DV_REPORT.json.cross_baselines[]; any baseline line whose status flips to ✅ must appear here. -->

| status | run_id | kind | build | case_count | stmt | branch | toggle | functional_cross_pct | evidence |
|:---:|---|---|---|---:|---|---|---|---:|---|
| ✅ | `longrun_260421_default` | longrun_default | `ip-compile-basic` | 128 | pending | pending | pending | pending | [`cases/basic/uvm/report/longrun/summary.json`](cases/basic/uvm/report/longrun/summary.json) |
| ✅ | `plain_basic_smoke` | smoke replay | `ip-compile-plain` | 1 | measured in harness merge | measured in harness merge | measured in harness merge | n/a | `cases/basic/plain/out_smoke/` |
| ✅ | `plain_basic_full` | full replay | `ip-compile-plain` | 1 | measured in harness merge | measured in harness merge | measured in harness merge | n/a | `cases/basic/plain/out/` |
| ✅ | `plain_2env_full` | boundary | `ip-compile-plain-2env` | 1 | measured in harness merge | measured in harness merge | measured in harness merge | 32.60 | `cases/basic/plain_2env/out/` |
| ✅ | `formal_boundary` | formal seam | `ip-formal-boundary` | — | n/a | n/a | n/a | — | `cases/basic/plain_2env/formal/out/` |

## Final sign-off summary

<!-- closed when every bucket table union and every continuous-frame baseline meet their targets -->

| status | item | current | target |
|:---:|---|---|---|
| ⚠️ | total merged code coverage | `stmt=68.02, branch=60.13, cond=21.27, expr=45.42, fsm_state=54.44, fsm_trans=25.42, toggle=18.17` | per-metric targets above |
| ⚠️ | total final functional coverage | `47.81` | 100.0 bins saturated |
| ✅ | bug ledger linkage | see [`BUG_HISTORY.md`](BUG_HISTORY.md) | every fix has a commit hash after verification |
| ⚠️ | per-case evidence rows | `645 / 645` implemented, `5 / 645` evidenced | 645 pages under [`REPORT/cases/`](REPORT/cases/) |
| ✅ | bucket_frame baseline pointers | 4 (CROSS-001..004) | 4 |
| ✅ | all_buckets_frame baseline pointer | 1 (CROSS-005) | 1 |

## Gap analysis

- The case-contract `covergroup` is now wired into `swb_scoreboard.sv`, but the current functional merged total (`47.81%`) covers only the implemented contract family, not the full planned family list in this document.
- The UCDB save/merge flow now runs through `make ip-cov-closure`, and the merged databases live under [`sim_runs/coverage/`](sim_runs/coverage/).
- The plain replay bench now emits UCDB and contributes code coverage, but it still has no functional covergroups, so its functional entry remains `n/a`.
- The formal scaffold under `plain_2env/formal/` contributes to property-level closure, not to code coverage. It is intentionally out of the `DV_COV.md` code-coverage union.
- The promoted randomized screen (`ip-uvm-longrun`, default 128-run) still produces pass/fail summaries only. It is not yet folded into the merged UCDB baseline.
- A stronger 256-run rerun remains on disk as historical archive evidence, but it is not part of the promoted nightly baseline union.
- The measured merged totals are well below the target thresholds because the current UCDB baseline only exercises the promoted replay-bearing anchors, not the full 645-case catalog or the continuous-frame baselines.

## Regenerate

```
python3 tb_int/scripts/build_dv_report_json.py --tb tb_int
python3 tb_int/scripts/dv_report_gen.py --tb tb_int
```

The generator now consumes measured UCDB data from `tb_int/sim_runs/coverage/`. Placeholder cells remain only where continuous-frame baselines or isolated per-case evidence have not yet been promoted.
