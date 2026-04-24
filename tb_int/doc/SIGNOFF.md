# ✅ Signoff — `tb_int` MuSiP SWB/OPQ integration

**DUT:** `swb_block` &nbsp; **Date:** `2026-04-24` &nbsp;
**Release under check:** `tb-int-dv-signoff-v2026.04.24` &nbsp; **Git base:** `yifeng-ip_sim-2604`

This page is the master integrated signoff dashboard for the musip-owned SWB datapath around the authentic Qsys-generated OPQ wrapper. Detailed DV evidence lives in [`../DV_REPORT.md`](../DV_REPORT.md), the live bug ledger lives in [`../BUG_HISTORY.md`](../BUG_HISTORY.md), and the machine-readable dashboard lives in [`../DV_REPORT.json`](../DV_REPORT.json).

## Legend

✅ pass / closed &middot; ⚠️ partial / caveat &middot; ❌ failed / blocked &middot; ❓ pending &middot; ℹ️ informational

## Health

| status | field | value |
|:---:|---|---|
| ✅ | overall_signoff | `dv_closed` |
| ✅ | promoted_opq_owner | `OPQ_SOURCE_MODE=upstream_qsys_generated` via the authentic Qsys wrapper regenerated from `external/mu3e-ip-cores` |
| ✅ | integrated_replay_closure | smoke and full replay pass end to end on the promoted integrated path |
| ✅ | per_hit_tracking | ingress, OPQ, and DMA hit identity closure is green on the promoted traced run |
| ✅ | lane_mask_contract | masked FEB lanes are now gated before OPQ ingress; `B046` passes on the integrated path |
| ✅ | directed_bucket_spot_checks | `B046-B049`, `E025-E027`, `P040-P041`, `P123-P124`, and promoted `X` regression anchors have in-repo evidence |
| ✅ | promoted_random_screen | `ip-uvm-longrun` is the promoted randomized screen for the default `0.0..0.5` per-lane rate matrix |
| ✅ | rtl_hygiene | `make ip-lint-rtl` passes on the current musip-owned integration code |
| ✅ | coverage_dashboard | merged UCDB totals are published and pass the targets in [`../DV_COV.md`](../DV_COV.md) |
| ✅ | continuous_frame_baselines | CROSS-001..005 pass as promoted bucket-frame and all-buckets-frame evidence |
| ✅ | event_builder_cleanup | `BUG-004-R` is closed in the musip-local RTL; non-zero launch, last-payload retirement, and fixed padding behavior are now explicit |

## Verification

| status | area | result | source |
|:---:|---|---|---|
| ✅ | replay closure | `make ip-tlm-basic-smoke`, `make ip-tlm-basic`, `make ip-plain-basic-smoke`, and `make ip-plain-basic` pass on the promoted owner | [`../DV_REPORT.md`](../DV_REPORT.md) |
| ✅ | integrated UVM closure | default `make ip-uvm-basic` passes with merge enabled and zero ghost/missing hits | [`../DV_REPORT.md`](../DV_REPORT.md) |
| ✅ | lane masking | `B046_lane0_only` now passes after the musip-local ingress-mask repair in `swb_block.vhd` | [`../BUG_HISTORY.md`](../BUG_HISTORY.md), [`../REPORT/cases/B046.md`](../REPORT/cases/B046.md) |
| ✅ | edge spot checks | `E025`, `E026`, and legal bounded `E027` each pass on the integrated UVM path | [`../REPORT/cases/E025.md`](../REPORT/cases/E025.md), [`../REPORT/cases/E026.md`](../REPORT/cases/E026.md), [`../REPORT/cases/E027.md`](../REPORT/cases/E027.md) |
| ✅ | backpressure spot check | `P040_dma_half_full_50` passes with zero ghost/missing hits and correct DMA payload accounting | [`../REPORT/cases/P040.md`](../REPORT/cases/P040.md) |
| ✅ | boundary audit | `make ip-plain-basic-2env-smoke`, `make ip-plain-basic-2env`, and `make ip-formal-boundary` pass | [`../DV_REPORT.md`](../DV_REPORT.md) |
| ✅ | merged coverage closure | `make ip-cov-closure` emits and merges UCDBs; current totals are `stmt=80.56`, `branch=75.95`, `cond=47.58`, `expr=57.81`, `fsm_state=90.09`, `fsm_trans=53.29`, `toggle=35.11`, `functional=100.00` | [`../DV_COV.md`](../DV_COV.md) |
| ✅ | continuous-frame closure | `make ip-cross-baselines` promotes CROSS-001..005; CROSS-005 carries the 22-segment all-buckets frame | [`../DV_REPORT.md`](../DV_REPORT.md), [`../REPORT/cross/CROSS-005.md`](../REPORT/cross/CROSS-005.md) |

## Fixes In Scope

| status | class | summary |
|:---:|---|---|
| ✅ | Owner selection | the deprecated local OPQ copy is waived for signoff; the authentic Qsys-generated wrapper is the only promoted owner |
| ✅ | Packaging | musip Qsys packaging propagates the intended FIFO-depth parameters into the regenerated wrapper |
| ✅ | Harness | per-hit ledgers, deterministic case seeding, zero-payload handling, and split-harness DMA scoreboarding all close on the current workspace |
| ✅ | Integration RTL | `swb_block` now masks FEB lanes before OPQ ingress, closing the lane-mask contract gap |
| ✅ | Event-builder contract | `musip_event_builder` now carries the cleaned-up completion contract tracked in `BUG-004-R`; zero-word requests remain an explicit no-launch case |

## Evidence Index

- [`../DV_REPORT.md`](../DV_REPORT.md) — integrated DV dashboard
- [`../DV_REPORT.json`](../DV_REPORT.json) — machine-readable integrated dashboard
- [`../DV_COV.md`](../DV_COV.md) — merged coverage totals and target closure
- [`../BUG_HISTORY.md`](../BUG_HISTORY.md) — integrated bug ledger
- [`../REPORT/cases/B046.md`](../REPORT/cases/B046.md) — lane-mask evidence
- [`../REPORT/cases/B047.md`](../REPORT/cases/B047.md), [`../REPORT/cases/B048.md`](../REPORT/cases/B048.md), [`../REPORT/cases/B049.md`](../REPORT/cases/B049.md) — active-lane promoted evidence
- [`../REPORT/cases/E025.md`](../REPORT/cases/E025.md) — zero-hit subheader evidence
- [`../REPORT/cases/E026.md`](../REPORT/cases/E026.md) — single-hit subheader evidence
- [`../REPORT/cases/E027.md`](../REPORT/cases/E027.md) — bounded legal `MAX_HITS` evidence
- [`../REPORT/cases/P040.md`](../REPORT/cases/P040.md), [`../REPORT/cases/P041.md`](../REPORT/cases/P041.md) — heavy backpressure evidence
- [`../REPORT/cross/CROSS-001.md`](../REPORT/cross/CROSS-001.md), [`../REPORT/cross/CROSS-002.md`](../REPORT/cross/CROSS-002.md), [`../REPORT/cross/CROSS-003.md`](../REPORT/cross/CROSS-003.md), [`../REPORT/cross/CROSS-004.md`](../REPORT/cross/CROSS-004.md), [`../REPORT/cross/CROSS-005.md`](../REPORT/cross/CROSS-005.md) — promoted continuous-frame baselines
- [`../wave_reports/BASIC/B047/packet_analyzer/index.html`](../wave_reports/BASIC/B047/packet_analyzer/index.html), [`../wave_reports/BASIC/B048/packet_analyzer/index.html`](../wave_reports/BASIC/B048/packet_analyzer/index.html), [`../wave_reports/BASIC/B049/packet_analyzer/index.html`](../wave_reports/BASIC/B049/packet_analyzer/index.html), [`../wave_reports/PROF/P041/packet_analyzer/index.html`](../wave_reports/PROF/P041/packet_analyzer/index.html) — checked-in traffic-analyzer wave evidence

## Notes

- This integrated signoff page does not replace standalone upstream packet-scheduler signoff. It covers only musip-owned integration behavior around the promoted Qsys-generated OPQ wrapper.
- Any future candidate OPQ-internal defect must be reproduced in the upstream `packet_scheduler` workspace before it is attributed outside musip.
- External upstream `signoff_4lane` alignment remains an audit note only. It is not a musip-local DV blocker for this release.
