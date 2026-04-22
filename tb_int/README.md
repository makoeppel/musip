# `tb_int` — MuSiP SWB/OPQ integration workspace

Integrated testbench workspace for the MuSiP SWB/OPQ bring-up. Four harnesses share a single replay bundle and validate the same `swb_block` integration contract from four different angles.

## Structure

- [`cases/`](cases/) — case inventory; current contents are the `basic/` bucket.
- [`cases/basic/ref/`](cases/basic/ref/) — simulatorless replay generator (Python). Owns the shared replay bundle.
- [`cases/basic/plain/`](cases/basic/plain/) — plain mixed-language VHDL replay bench around `swb_block_uvm_wrapper`.
- [`cases/basic/plain_2env/`](cases/basic/plain_2env/) — split 2-env DPI seam harness. Promoted OPQ boundary audit owner.
- [`cases/basic/plain_2env/formal/`](cases/basic/plain_2env/formal/) — OPQ-seam packet-contract formal scaffold.
- [`cases/basic/uvm/`](cases/basic/uvm/) — mixed-language UVM harness around the full `swb_block`.
- [`DV_INT_PLAN.md`](DV_INT_PLAN.md) — promoted integration plan: purpose, topology, locked decisions, stage contract, test list, phasing, non-goals.
- [`DV_INT_HARNESS.md`](DV_INT_HARNESS.md) — harness-side companion: clock/reset, RTL skeleton, replay bundle format, stage taps, compile / elaboration order.
- [`DV_REPORT.md`](DV_REPORT.md) — current integration dashboard (health + validation matrix + promoted evidence).
- [`DV_REPORT.json`](DV_REPORT.json) — machine-readable source of truth.
- [`DV_COV.md`](DV_COV.md) — coverage summary (pending tooling hookup).
- [`BUG_HISTORY.md`](BUG_HISTORY.md) — live bug ledger for this branch.

## Reading order

1. [`DV_INT_PLAN.md`](DV_INT_PLAN.md) — what the workspace is for and which decisions are locked.
2. [`DV_INT_HARNESS.md`](DV_INT_HARNESS.md) — how each harness is wired and what to compile in what order.
3. [`DV_REPORT.md`](DV_REPORT.md) — current musip-local status, promoted evidence, and randomized-screen results.
4. [`BUG_HISTORY.md`](BUG_HISTORY.md) — how the failing issues were closed and which follow-on items still remain.

## Quick start

Ordered so every step reuses artifacts from earlier steps:

1. `make ip-init` — init submodules and regenerate the musip-local authentic Qsys OPQ wrapper. One-off after clone.
2. `make ip-check-license` — verify ETH floating features for the promoted Questa runtime.
3. `make ip-tlm-basic-smoke` — generate the smallest deterministic replay bundle (`cases/basic/ref/out_smoke/`).
4. `make ip-compile-basic` — make sure the mixed-language UVM harness still compiles on the current host.
5. `make ip-uvm-basic` — default RTL/UVM run. Uses the real integrated merge path by default.
6. `make ip-tlm-basic` — generate the larger Poisson replay bundle (`cases/basic/ref/out/`).
7. `make ip-plain-basic` — plain replay bench with semantic per-hit DMA checking.
8. `make ip-plain-basic-2env` — split OPQ boundary harness with explicit seam scoreboarding.
9. `make ip-formal-boundary` — OPQ-seam packet-contract formal scaffold.
10. `make ip-uvm-longrun` — default 128-run randomized per-lane `0.0..0.5` saturation screen.

## Make targets

| Target | Purpose |
|--------|---------|
| `make ip-init` | initialize submodules and regenerate the musip-local authentic Qsys OPQ wrapper |
| `make ip-sync-opq` | regenerate the musip-local authentic Qsys OPQ wrapper only |
| `make ip-svd` | regenerate the OPQ memory-map SVD under `build/ip/` |
| `make ip-check-license` | check that the ETH Siemens/Mentor features are reachable |
| `make ip-lint-rtl` | strict-check maintained bridge/wrapper RTL; hygiene-check legacy or imported RTL |
| `make ip-compile-basic` | compile the mixed-language UVM harness only |
| `make ip-compile-plain` | compile the plain mixed-language replay bench |
| `make ip-compile-plain-2env` | compile the split 2-env DPI seam harness |
| `make ip-tlm-basic` | generate the full Poisson basic replay bundle |
| `make ip-tlm-basic-smoke` | generate the directed smoke replay bundle |
| `make ip-uvm-basic` | run the mixed-language UVM basic case (`SWB_USE_MERGE=1` by default) |
| `make ip-uvm-longrun` | run the randomized UVM campaign wrapper and write `cases/basic/uvm/report/longrun/summary.json` |
| `make ip-plain-basic` | run the plain mixed-language replay bench (`USE_MERGE=1` by default) |
| `make ip-plain-basic-smoke` | run the plain mixed-language directed smoke bench |
| `make ip-plain-basic-2env` | run the split 2-env DPI seam harness |
| `make ip-plain-basic-2env-smoke` | run the split 2-env directed smoke harness |
| `make ip-formal-boundary` | run the OPQ-seam packet-contract formal scaffold |
| `make ip-e2e` / `ip-e2e-ref` / `ip-e2e-plain` / `ip-e2e-plain-2env` | aliases for `ip-uvm-basic`, `ip-tlm-basic`, `ip-plain-basic`, `ip-plain-basic-2env` |
| `make ip-clean` | remove both UVM scratch data and generated replay output |

## Current posture

- `ref/`, `plain/`, `uvm/`, `plain_2env/`, and `ip-formal-boundary` are all green on the promoted full-Questa toolchain when the replay owner is `OPQ_SOURCE_MODE=upstream_qsys_generated`.
- `plain_2env/` remains useful as the explicit OPQ boundary audit owner, but it is no longer the only passing path.
- `plain_2env/` smoke and full replay now feed both the OPQ boundary scoreboard and the downstream DMA hit checker from the same ingress replay, so the split harness closes on the same per-hit DMA contract as the integrated path.
- The UVM harness now supports per-hit ingress, OPQ, and DMA ledgers via `+SWB_HIT_TRACE_PREFIX=<abs-prefix>`.
- The promoted randomized screen remains `make ip-uvm-longrun`; the current signoff owner is the regenerated authentic Qsys wrapper under `firmware/a10_board/a10/merger/qsys/opq_upstream_4lane_native_sv/`.
- The upstream OPQ owner is now checked in as the `external/mu3e-ip-cores` submodule; musip-local packaging and replay flows should resolve through that submodule by default.
- External upstream `signoff_4lane` alignment is tracked as an audit note only. It is not a blocker for musip-local signoff in this repo.
- See [`DV_REPORT.md`](DV_REPORT.md) for the current validation matrix and [`BUG_HISTORY.md`](BUG_HISTORY.md) for the open bug ledger.
