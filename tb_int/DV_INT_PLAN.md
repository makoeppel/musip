# DV_INT: MuSiP SWB/OPQ integration testbench

**DUT chain:** `lane*_ingress` -> `ingress_egress_adaptor` (OPQ merge) -> `musip_mux_4_1` -> `musip_event_builder` -> DMA
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)
**Date:** 2026-04-22
**Status:** The musip-local integrated path is green on the promoted full Questa toolchain. Replay generation, plain replay, full UVM, split OPQ-boundary replay, the formal seam scaffold, seeded per-hit tracing, the event-builder cleanup, and the promoted UCDB save/merge flow all pass in this workspace. A stronger 256-run rerun is retained as historical archive evidence only. Coverage is now measured under `tb_int/sim_runs/coverage/`, but the merged totals remain below the signoff targets in [`DV_COV.md`](DV_COV.md).

**Companion docs:**

- [`DV_INT_HARNESS.md`](DV_INT_HARNESS.md) - clock/reset, RTL skeleton, stage taps, compile order, plusargs.
- [`DV_REPORT.md`](DV_REPORT.md) - current dashboard and promoted evidence.
- [`DV_COV.md`](DV_COV.md) - coverage status and planned collectors.
- [`BUG_HISTORY.md`](BUG_HISTORY.md) - live bug ledger.

---

## 1. Purpose

`tb_int/` is the integration verification workspace for the MuSiP SWB/OPQ path in this repository. Unlike the standalone IP benches under `external/mu3e-ip-cores/<ip>/tb/`, this tree wires the actual local `swb_block` submodules into one harness family and asks whether the end-to-end FEB-AvST -> DMA contract closes with the RTL that ships in this repo.

The tree has four jobs:

- replay generation - produce deterministic ingress, OPQ-seam, and DMA reference bundles from the same traffic model used by the UVM flow.
- integrated SWB validation - run the full `swb_block` wrapper under the promoted mixed-language Questa toolchain.
- OPQ-boundary isolation - keep the OPQ seam explicitly checkable in `plain_2env/` even when the fully integrated path is not the debug target.
- randomized screen - run the UVM harness across a larger grid of seeds and lane saturation combinations and retain per-case evidence.

This tree does **not** claim standalone OPQ signoff. OPQ-internal closure belongs to the dedicated packet-scheduler verification tree. `tb_int/` owns the integration-side contract: ingress grammar, merge visibility, DMA payload ordering, event-builder completion, and per-hit equivalence across the active local datapath.

---

## 2. Topology

```
 +--------------------------------- SWB BLOCK ---------------------------------+
 |                                                                             |
 |   lane0  --+                                                                |
 |   lane1  --+                              USE_BIT_MERGER = 1                |
 |   lane2  --+ --> feb_rx --> e_ingress_egress_adaptor (N_SHD=128)            |
 |   lane3  --+                      -> native-SV OPQ merge path               |
 |                                                                             |
 |                          USE_BIT_MERGER = 0                                 |
 |   (debug bypass) --> rx_data_sim_merged <- direct copy of rx_data_sim       |
 |                                                                             |
 |                                    |                                        |
 |                                    v                                        |
 |                            e_musip_mux_4_1 (g_LINK_N=4)                     |
 |                                    |                                        |
 |                                    v   256-bit packed hit beats             |
 |                            e_event_builder (musip_event_builder)            |
 |                                    |                                        |
 |                                    v   o_dma_data[255:0] + o_dma_wren       |
 |                                        o_endofevent / o_done                |
 +-----------------------------------------------------------------------------+
                                     |
                                     v
                              DMA payload ledger
```

Key integration facts:

- 4 FEB lanes per SWB, using the MuPix packet grammar packed into 37-bit replay beats `{valid[36], datak[35:32], data[31:0]}`.
- The promoted local mode is `USE_BIT_MERGER=1`, which keeps the real integrated OPQ merge path in the loop.
- The bypass mode still exists for debug and targeted A/B checks, but it is no longer the promoted default.
- `musip_event_builder` adds a fixed 128-word padding tail after the payload and only then asserts `o_done`.

---

## 3. Locked design decisions

| # | Decision | Resolution |
|---|----------|------------|
| 1 | Supported simulator | Only the full Siemens install at `/data1/questaone_sim/questasim` is promoted. ETH floating license source: `8161@lic-mentor.ethz.ch`. Intel FE/FSE is not accepted for this flow. |
| 2 | Intel VHDL libraries | Use `/data1/questaone_sim/questasim/intel_2026/vhdl` via the patched `modelsim.ini`. Refresh with `tools/ip/refresh_questa_intel_libs.sh` whenever the install is replaced. |
| 3 | Integrated merge default | `ip-uvm-basic` and `ip-plain-basic` run with the real integrated merge path enabled by default (`SWB_USE_MERGE=1`, `USE_MERGE=1`). The former bypass-only workaround is retired. |
| 4 | Boundary audit owner | `ip-plain-basic-2env` remains the promoted OPQ boundary audit path because it makes the seam explicit, but it is not the only passing owner anymore. |
| 5 | Replay format | Every replay-capable harness consumes the same 37-bit packed beat format and the same `expected_dma_words.mem` oracle produced by `ref/`. |
| 6 | `dma_done` interpretation | `dma_done` is `musip_event_builder.o_done`. It goes high only after the requested payload words retire and the fixed 128-word padding tail completes. |
| 7 | Per-hit tracking contract | The UVM scoreboard assigns a hidden hit ID from the ingress-derived merged stream and requires the same normalized hit plus the same non-overflowing 8 ns debug timestamp to appear at OPQ and DMA. `SWB_CHECK_PASS` is emitted only when these checks close with zero ghost or missing hits. |
| 8 | Randomized screen owner | `make ip-uvm-longrun` is the promoted musip-local randomized screen. Default campaign: 128 unique 4-lane rate combinations over the `0.0..0.5` grid, 2 frames, campaign seed `260421`. A historical stronger 256-run archive with campaign seed `260422` remains in `cases/basic/uvm/report/longrun_ext_260422_fixed/summary.json`, but it is not the promoted nightly gate. |
| 9 | Formal scope | `ip-formal-boundary` is a contract-grammar scaffold at the OPQ seam, not a formal proof of the real OPQ implementation. |
| 10 | Lint rigor | `ip-lint-rtl` stays strict on owned bridge/wrapper RTL and hygiene-only on imported or legacy RTL. |
| 11 | Critical frame-timestamp prior | At the integrated seam `e_ingress_egress_adaptor` runs with `N_SHD=128`. One subheader consumes `16 * 8 ns = 128 ns`, so the physical frame-to-frame launch cadence is `128 * 128 ns = 16384 ns = 2048` timestamp units = `4096` cycles at the promoted `250 MHz` harness clock. The frame header timestamp is the start-of-slice timestamp in `8 ns` units: it starts from `0`, advances by exactly one frame slice per frame (`0x0800` at `N_SHD=128`, `0x1000` at `N_SHD=256`), and its masked low bits remain zero because the subheader and hit fields own those lower timestamp bits. This is a critical prior for all replay generators, wave bundles, and promoted evidence. |
| 12 | Debug-dispatch timestamp prior | `debug1` is not the frame-slice origin. It is the dispatch timestamp sampled from the live global counter after the frame header timestamp and therefore must be slightly larger at ingress; downstream blocks such as OPQ may delay it further. OPQ reset release must align with the start of the global timestamp counter so the first promoted frame can legally start at timestamp `0`. |
| 13 | Waveform-evidence prior | Human-facing ingress waveform evidence must use synchronized frame-start slots so the same frame ID launches on all enabled lanes in the same cycle. When that evidence claims physical timing for the integrated `N_SHD=128` path, the meaningful SOP-to-SOP slot is the real `4096`-cycle cadence above; any shorter `+SWB_FRAME_SLOT_CYCLES=<n>` value is a visualization-only compression and must be labeled as such. Within a physically aligned slot the trailer timing is still expected to vary with packet size, while the frame header timestamp words (`ts_high` / `ts_low_pkg`) must still advance by the exact fixed `0x0800` slice interval and `debug1` must remain a delayed live-dispatch timestamp rather than a copy of the frame origin. |

---

## 4. `dma_done` contract

`dma_done` is easy to misread in this workspace, so its meaning is pinned here.

- Exposed at the harness seam by `tb_int/cases/basic/uvm/dut/swb_block_uvm_wrapper.vhd`.
- Driven inside `swb_block` by `musip_event_builder.o_done`.

`musip_event_builder` retires a run in this order:

1. Accept payload beats from `musip_mux_4_1`.
2. Wait for DMA enable and non-zero `i_get_n_words`.
3. Drain exactly `i_get_n_words` payload beats and assert `o_endofevent` on the last payload beat.
4. Emit the fixed 128-word padding tail.
5. Assert `o_done`.

Current evidence says `dma_done` is **not** the active datapath blocker in the local workspace:

- integrated plain replay passes,
- integrated UVM replay passes,
- integrated seeded random UVM replay with per-hit tracing passes,
- the split boundary harness passes through the same event builder,
- the promoted default 128-run randomized UVM screen passes cleanly.
- a retained historical 256-run rerun archive also passes cleanly, including the former zero-payload corner seed `1327604986`.

The event-builder completion contract has now been cleaned up locally: non-zero launch is explicit, one-word payloads retire through the same last-payload path as longer events, and the fixed `128`-word padding phase is tracked directly in the RTL. Zero-word requests remain an explicit no-launch case under the current contract.

---

## 5. Stage contract

The stage vocabulary used by the report and bug ledger is:

| Stage | Tap point | Observed in | Contract family |
|---|---|---|---|
| A | test-plan creation | `ref/`, `uvm/` | deterministic plan metadata: frames, saturations, seed, expected DMA word count |
| I | FEB ingress into `feb_rx[3:0]` | all harnesses | MuPix packet grammar per lane |
| M | post-merge AvST out of `ingress_egress_adaptor` | `plain/`, `uvm/` when merge is enabled | same MuPix grammar after real merge arbitration |
| O | OPQ egress AvST into `musip_mux_4_1` | all harnesses | same packet grammar at the mux input |
| D | 256-bit packed DMA word out of `musip_mux_4_1` | all harnesses | 4 normalized hits per beat, sorted by absolute time |
| E | `o_dma_data` + `o_dma_wren` + `o_endofevent` + `o_done` | all harnesses | payload equality plus event-builder end-of-event and done behavior |

Promoted comparison rules:

- `ref/` reparses its own generated ingress and OPQ-seam streams to ensure the reference bundle is self-consistent.
- `plain/` compares the observed DMA payload against the reference at the normalized 64-bit hit level, not just the packed 256-bit word level.
- `uvm/` compares the same traffic at three stages: ingress hits, OPQ hits, and DMA hits.
- `plain_2env/` checks both the OPQ seam and the downstream DMA behavior with separate monitors and scoreboards.

---

## 6. Test list

| Test | Owner harness | Purpose | Current status |
|---|---|---|---|
| `ip-tlm-basic-smoke` | `ref/` | smallest deterministic replay bundle | PASS |
| `ip-tlm-basic` | `ref/` | full Poisson replay bundle | PASS |
| `ip-plain-basic-smoke` | `plain/` | integrated replay against the smoke bundle | PASS |
| `ip-plain-basic` | `plain/` | integrated replay against the full bundle | PASS |
| `ip-uvm-basic SIM_ARGS=+SWB_REPLAY_DIR=$(pwd)/tb_int/cases/basic/ref/out_smoke` | `uvm/` | integrated UVM replay of the smoke bundle | PASS |
| `ip-uvm-basic SIM_ARGS=+SWB_REPLAY_DIR=$(pwd)/tb_int/cases/basic/ref/out` | `uvm/` | integrated UVM replay of the full bundle | PASS |
| `ip-uvm-basic` | `uvm/` | default randomized UVM case on the promoted toolchain | PASS |
| `ip-uvm-basic SIM_ARGS='+SWB_FRAMES=2 +SWB_CASE_SEED=12345 +SWB_SAT0=0.10 +SWB_SAT1=0.20 +SWB_SAT2=0.30 +SWB_SAT3=0.40 +SWB_HIT_TRACE_PREFIX=...'` | `uvm/` | seeded random replay with exported per-hit ledgers | PASS |
| `ip-uvm-longrun` | `uvm/` | default randomized 128-run campaign across the per-lane `0.0..0.5` rate grid | PASS |
| `python3 tb_int/cases/basic/uvm/run_longrun.py --runs 256 --campaign-seed 260422 --out-dir report/longrun_ext_260422_fixed` | `uvm/` | historical stronger 256-run rerun archive across the same per-lane `0.0..0.5` rate grid | PASS |
| `ip-plain-basic-2env-smoke` | `plain_2env/` | split OPQ-boundary smoke replay | PASS |
| `ip-plain-basic-2env` | `plain_2env/` | split OPQ-boundary full replay | PASS |
| `ip-formal-boundary` | `plain_2env/formal/` | OPQ-seam packet-contract grammar scaffold | PASS |

---

## 7. Phasing

| Phase | Deliverable | Status |
|---|---|---|
| 0 | plan, harness notes, report, bug ledger | done |
| 1 | replay generator and deterministic bundles | done |
| 2 | plain mixed-language replay bench | done |
| 3 | mixed-language UVM harness | done |
| 4 | split 2-env OPQ-boundary harness | done |
| 5 | OPQ-seam formal scaffold | done |
| 6 | integrated local replay closure in `plain/` and `uvm/` | done |
| 7 | integrated merge-enabled closure in the local workspace | done |
| 8 | per-hit tracking from ingress through OPQ and DMA | done |
| 9 | promoted randomized long-run screen | done |
| 10 | event-builder completion-contract cleanup | done |
| 11 | UCDB-based coverage collection and merge flow | done |

---

## 8. Hard constraints and open items

- Full Questa only. The musip-local signoff evidence in this workspace is not portable to FE/FSE.
- UVM 1.2 from the promoted Questa install, with the shipped `uvm_dpi.so`.
- No standalone OPQ signoff claim from this tree.
- No real PCIe or DMA-engine simulation; `i_dmamemhalffull` stays low and the scoreboard is the sink.
- UCDB save/merge is now wired for the promoted replay-bearing harnesses. Coverage is measured under `tb_int/sim_runs/coverage/`, but the merged totals are still below the target thresholds in `DV_COV.md`.
- External upstream `signoff_4lane` alignment may still be audited separately, but it is out of scope for musip-local closure in this repo.

---

## 9. Current signoff boundary (2026-04-22)

Signed off locally on the promoted toolchain:

- replay generation for smoke and full bundles,
- integrated plain replay for smoke and full bundles,
- integrated UVM replay for smoke and full bundles,
- default randomized UVM run,
- seeded per-hit trace run with zero OPQ and DMA ghost/missing hits,
- default 128-run randomized UVM campaign over the per-lane `0.0..0.5` saturation grid,
- retained historical 256-run randomized UVM rerun archive over the same per-lane `0.0..0.5` saturation grid,
- split OPQ-boundary replay in `plain_2env/`,
- OPQ-seam packet-contract formal scaffold,
- event-builder completion-contract cleanup,
- UCDB-based save/merge flow for the promoted replay-bearing harnesses.

Not yet signed off:

- merged code and functional coverage closure against the target thresholds in `DV_COV.md`,
- optional external upstream `signoff_4lane` alignment work.

The musip-local end-to-end datapath and the phase-11 coverage plumbing are therefore closed in this workspace. Remaining work is coverage-target closure and optional external alignment work, not a local replay or infrastructure blocker.
