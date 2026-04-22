# ⚠️ Signoff — `tb_int` MuSiP SWB/OPQ integration

**DUT:** `swb_block` &nbsp; **Date:** `2026-04-22` &nbsp;
**Release under check:** `local working tree` &nbsp; **Git base:** `local working tree`

This page is the master integrated signoff dashboard for the musip-owned SWB datapath around the authentic Qsys-generated OPQ wrapper. Detailed DV evidence lives in [`../DV_REPORT.md`](../DV_REPORT.md), the live bug ledger lives in [`../BUG_HISTORY.md`](../BUG_HISTORY.md), and the machine-readable dashboard lives in [`../DV_REPORT.json`](../DV_REPORT.json).

## Legend

✅ pass / closed &middot; ⚠️ partial / caveat &middot; ❌ failed / blocked &middot; ❓ pending &middot; ℹ️ informational

## Health

| status | field | value |
|:---:|---|---|
| ⚠️ | overall_signoff | `partial` |
| ✅ | promoted_opq_owner | `OPQ_SOURCE_MODE=upstream_qsys_generated` via the authentic Qsys wrapper regenerated from `external/mu3e-ip-cores` |
| ✅ | integrated_replay_closure | smoke and full replay pass end to end on the promoted integrated path |
| ✅ | per_hit_tracking | ingress, OPQ, and DMA hit identity closure is green on the promoted traced run |
| ✅ | lane_mask_contract | masked FEB lanes are now gated before OPQ ingress; `B046` passes on the integrated path |
| ✅ | directed_bucket_spot_checks | `B046`, `E025`, `E026`, `E027`, and `P040` each have in-repo evidence logs |
| ✅ | promoted_random_screen | `ip-uvm-longrun` is the promoted randomized screen for the default `0.0..0.5` per-lane rate matrix |
| ✅ | rtl_hygiene | `make ip-lint-rtl` passes on the current musip-owned integration code |
| ⚠️ | coverage_dashboard | UCDB save/merge is still pending, so merged coverage totals are not yet available |
| ⚠️ | deferred_cleanup | `BUG-004-R` (`musip_event_builder` completion-contract cleanup) remains open but is not blocking current end-to-end closure |

## Verification

| status | area | result | source |
|:---:|---|---|---|
| ✅ | replay closure | `make ip-tlm-basic-smoke`, `make ip-tlm-basic`, `make ip-plain-basic-smoke`, and `make ip-plain-basic` pass on the promoted owner | [`../DV_REPORT.md`](../DV_REPORT.md) |
| ✅ | integrated UVM closure | default `make ip-uvm-basic` passes with merge enabled and zero ghost/missing hits | [`../DV_REPORT.md`](../DV_REPORT.md) |
| ✅ | lane masking | `B046_lane0_only` now passes after the musip-local ingress-mask repair in `swb_block.vhd` | [`../BUG_HISTORY.md`](../BUG_HISTORY.md), [`../REPORT/cases/B046.md`](../REPORT/cases/B046.md) |
| ✅ | edge spot checks | `E025`, `E026`, and legal bounded `E027` each pass on the integrated UVM path | [`../REPORT/cases/E025.md`](../REPORT/cases/E025.md), [`../REPORT/cases/E026.md`](../REPORT/cases/E026.md), [`../REPORT/cases/E027.md`](../REPORT/cases/E027.md) |
| ✅ | backpressure spot check | `P040_dma_half_full_50` passes with zero ghost/missing hits and correct DMA payload accounting | [`../REPORT/cases/P040.md`](../REPORT/cases/P040.md) |
| ✅ | boundary audit | `make ip-plain-basic-2env-smoke`, `make ip-plain-basic-2env`, and `make ip-formal-boundary` pass | [`../DV_REPORT.md`](../DV_REPORT.md) |
| ⚠️ | merged coverage closure | bucket and merged UCDB totals remain pending until the UCDB flow is wired into the promoted build | [`../DV_COV.md`](../DV_COV.md) |

## Fixes In Scope

| status | class | summary |
|:---:|---|---|
| ✅ | Owner selection | the deprecated local OPQ copy is waived for signoff; the authentic Qsys-generated wrapper is the only promoted owner |
| ✅ | Packaging | musip Qsys packaging propagates the intended FIFO-depth parameters into the regenerated wrapper |
| ✅ | Harness | per-hit ledgers, deterministic case seeding, zero-payload handling, and split-harness DMA scoreboarding all close on the current workspace |
| ✅ | Integration RTL | `swb_block` now masks FEB lanes before OPQ ingress, closing the lane-mask contract gap |
| ⚠️ | Event-builder contract | `musip_event_builder` still carries the legacy zero-word completion behavior tracked in `BUG-004-R` |

## Evidence Index

- [`../DV_REPORT.md`](../DV_REPORT.md) — integrated DV dashboard
- [`../DV_REPORT.json`](../DV_REPORT.json) — machine-readable integrated dashboard
- [`../BUG_HISTORY.md`](../BUG_HISTORY.md) — integrated bug ledger
- [`../REPORT/cases/B046.md`](../REPORT/cases/B046.md) — lane-mask evidence
- [`../REPORT/cases/E025.md`](../REPORT/cases/E025.md) — zero-hit subheader evidence
- [`../REPORT/cases/E026.md`](../REPORT/cases/E026.md) — single-hit subheader evidence
- [`../REPORT/cases/E027.md`](../REPORT/cases/E027.md) — bounded legal `MAX_HITS` evidence
- [`../REPORT/cases/P040.md`](../REPORT/cases/P040.md) — heavy backpressure evidence

## Notes

- This integrated signoff page does not replace standalone upstream packet-scheduler signoff. It covers only musip-owned integration behavior around the promoted Qsys-generated OPQ wrapper.
- Any future candidate OPQ-internal defect must be reproduced in the upstream `packet_scheduler` workspace before it is attributed outside musip.
- The current partial signoff state is driven by missing UCDB merge totals and the deferred `musip_event_builder` cleanup, not by an open end-to-end datapath mismatch on the promoted owner.
