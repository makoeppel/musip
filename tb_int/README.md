# `tb_int` — MuSiP SWB/OPQ integration workspace

Integrated testbench workspace for the MuSiP SWB/OPQ bring-up. Four harnesses share a single replay bundle and validate the same `swb_block` integration contract from four different angles.

## Structure

- [`cases/`](cases/) — case inventory bucketed as `basic/`, `edge/`, `prof/`, `error/`, and `cross/`.
- [`cases/basic/ref/`](cases/basic/ref/) — simulatorless replay generator (Python). Owns the shared replay bundle.
- [`cases/basic/plain/`](cases/basic/plain/) — plain mixed-language VHDL replay bench around `swb_block_uvm_wrapper`.
- [`cases/basic/plain_2env/`](cases/basic/plain_2env/) — split 2-env DPI seam harness. Promoted OPQ boundary audit owner.
- [`cases/basic/plain_2env/formal/`](cases/basic/plain_2env/formal/) — OPQ-seam packet-contract formal scaffold.
- [`cases/basic/uvm/`](cases/basic/uvm/) — mixed-language UVM harness around the full `swb_block`.
- [`cases/cross/ghdl/`](cases/cross/ghdl/) — lightweight all-bucket GHDL waveform fixture with GTKWave markers and named checkpoint validation.
- [`doc/DV_INT_PLAN.md`](doc/DV_INT_PLAN.md) — promoted integration plan: purpose, topology, locked decisions, stage contract, test list, phasing, non-goals.
- [`doc/DV_INT_HARNESS.md`](doc/DV_INT_HARNESS.md) — harness-side companion: clock/reset, RTL skeleton, replay bundle format, stage taps, compile / elaboration order.
- [`doc/DV_REPORT.md`](doc/DV_REPORT.md) — current integration dashboard (health + validation matrix + promoted evidence).
- [`doc/DV_REPORT.json`](doc/DV_REPORT.json) — machine-readable source of truth.
- [`doc/DV_COV.md`](doc/DV_COV.md) — coverage summary, merged totals, and continuous-frame baseline evidence.
- [`doc/BUG_HISTORY.md`](doc/BUG_HISTORY.md) — live bug ledger for this branch.
- [`report/`](report/) — checked-in signoff evidence, waveform bundles, and server helper scripts.
- [`report/signoff/DV_SIGNOFF.md`](report/signoff/DV_SIGNOFF.md) — functional coverage / missing-case dashboard for this base signoff.
- [`report/wave/`](report/wave/) — static packet analyzer and waveform evidence bundles.

## Reading order

1. [`doc/DV_INT_PLAN.md`](doc/DV_INT_PLAN.md) — what the workspace is for and which decisions are locked.
2. [`doc/DV_INT_HARNESS.md`](doc/DV_INT_HARNESS.md) — how each harness is wired and what to compile in what order.
3. [`doc/DV_REPORT.md`](doc/DV_REPORT.md) — current musip-local status, promoted evidence, and randomized-screen results.
4. [`report/signoff/DV_SIGNOFF.md`](report/signoff/DV_SIGNOFF.md) — implemented and missing functional coverage by bucket.
5. [`doc/BUG_HISTORY.md`](doc/BUG_HISTORY.md) — how the failing issues were closed and which follow-on items still remain.

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
11. `make ip-cross-baselines` — promoted CROSS-001..005 continuous-frame baselines.
12. `make ip-ghdl-cross-run` — fast deterministic all-bucket GHDL waveform run.
13. `make ip-ghdl-cross-checkpoints` — validate the named VCD checkpoint table used for visual inspection.
14. `make ip-ghdl-cross-view` — open the generated GTKWave save file when `DISPLAY` is available.
15. `CLOSURE_RESUME=1 make ip-cov-closure` — promoted UCDB closure bundle and dashboard refresh.
16. `tb_int/report/script/start_wave_server.sh 8789` — serve checked-in waveform/analyzer evidence from `tb_int/report/wave`.

## Make targets

| Target | Purpose |
|--------|---------|
| `make ip-init` | initialize submodules and regenerate the musip-local authentic Qsys OPQ wrapper |
| `make ip-sync-opq` | materialize the musip-local authentic Qsys OPQ wrapper from local Qsys packaging |
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
| `make ip-cross-baselines` | run promoted CROSS-001..005 continuous-frame baseline evidence |
| `make ip-ghdl-cross-objects` | compile the lightweight all-bucket GHDL waveform fixture |
| `make ip-ghdl-cross-run` | run the GHDL fixture and write the VCD/log/GTKWave save file under `cases/cross/ghdl/report/` |
| `make ip-ghdl-cross-gtkw` | regenerate the SignalTap-aligned GTKWave save file and translate filters |
| `make ip-ghdl-cross-checkpoints` | validate named GHDL VCD checkpoints for the representative cross-run |
| `make ip-ghdl-cross-view` | run the fixture and open GTKWave when an X display is available |
| `make ip-cov-closure` | run the promoted UCDB closure bundle and regenerate the DV report |
| `make ip-e2e` / `ip-e2e-ref` / `ip-e2e-plain` / `ip-e2e-plain-2env` | aliases for `ip-uvm-basic`, `ip-tlm-basic`, `ip-plain-basic`, `ip-plain-basic-2env` |
| `make ip-clean` | remove both UVM scratch data and generated replay output |

## Current posture

- `ref/`, `plain/`, `uvm/`, `plain_2env/`, and `ip-formal-boundary` are all green on the promoted full-Questa toolchain when the replay owner is `OPQ_SOURCE_MODE=upstream_qsys_generated`.
- `plain_2env/` remains useful as the explicit OPQ boundary audit owner, but it is no longer the only passing path.
- `plain_2env/` smoke and full replay now feed both the OPQ boundary scoreboard and the downstream DMA hit checker from the same ingress replay, so the split harness closes on the same per-hit DMA contract as the integrated path.
- The UVM harness now supports per-hit ingress, OPQ, and DMA ledgers via `+SWB_HIT_TRACE_PREFIX=<abs-prefix>`.
- The promoted randomized screen remains `make ip-uvm-longrun`; the current signoff owner is the regenerated authentic Qsys wrapper under `firmware/a10_board/a10/merger/qsys/opq_upstream_4lane_native_sv/`.
- The regenerated OPQ Qsys wrapper is pinned to packet_scheduler `26.4.13.0428` and the board flow is timing-clean: `make -C firmware/a10_board flow` reports worst setup slack `+0.141 ns`, worst hold slack `+0.013 ns`, and zero setup/hold TNS.
- Coverage closure is green in `doc/DV_COV.md` with merged totals `stmt=80.56`, `branch=75.95`, `cond=47.58`, `expr=57.81`, `fsm_state=90.09`, `fsm_trans=53.29`, `toggle=35.11`, and `functional=100.00`.
- CROSS-001..005 are the promoted continuous-frame baselines; CROSS-005 carries the 22-segment all-buckets frame.
- The GHDL cross fixture is green for the same representative all-bucket shape: 22 anchor segments, 13 named checkpoints, and 41 VCD signal expectations. Its GTKWave view is grouped clock/reset -> case delimiters -> RX ingress -> OPQ join/reorder -> DMA egress -> scoreboard diagnostics for SignalTap-style inspection.
- The upstream OPQ owner is now checked in as the `external/mu3e-ip-cores` submodule; musip-local packaging and replay flows should resolve through that submodule by default.
- External upstream `signoff_4lane` alignment is tracked as an audit note only. It is not a blocker for musip-local signoff in this repo.
- See [`doc/DV_REPORT.md`](doc/DV_REPORT.md) for the current validation matrix, [`report/signoff/DV_SIGNOFF.md`](report/signoff/DV_SIGNOFF.md) for implemented/missing functional coverage, and [`doc/BUG_HISTORY.md`](doc/BUG_HISTORY.md) for the open bug ledger.
