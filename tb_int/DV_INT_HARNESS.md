# DV_INT Harness: MuSiP SWB/OPQ integration

**Companion to:** [`DV_INT_PLAN.md`](DV_INT_PLAN.md)
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)
**Date:** 2026-04-21
**Status:** Four harnesses share one replay model. The local integrated path is green in both `plain/` and `uvm/`, the split OPQ-boundary harness is green, the formal seam scaffold is green, and the promoted UVM long-run campaign passes.

---

## 1. Clock / reset

| Clock | Freq | Period | Used by |
|---|---|---|---|
| `clk` | 250 MHz | 4 ns | single simulation clock shared by the replay drivers, `swb_block`, `musip_mux_4_1`, and `musip_event_builder` |
| `reset_n` | active-low | held low for `G_SETTLE_CYCLES` at time zero | synchronous to `clk` |

This harness family is single-clock in simulation. The real FEB -> SWB path has a GXB crossing, but the benches bypass the PHY and drive the AvST-facing inputs directly. Adding an explicit CDC model is future work, not part of the promoted musip-local tree.

`i_dmamemhalffull` is held low throughout. The DMA sink is always a scoreboard, not a simulated DMA engine.

---

## 2. Shared replay bundle

`cases/basic/ref/run_basic_ref.py` generates deterministic replay bundles under `out/` or `out_smoke/`. Replay-capable harnesses consume those artifacts directly.

Bundle layout:

```
out/
|- plan.json
|- summary.json
|- lane0_ingress.mem
|- lane1_ingress.mem
|- lane2_ingress.mem
|- lane3_ingress.mem
|- lane0_ingress.jsonl
|- lane1_ingress.jsonl
|- lane2_ingress.jsonl
|- lane3_ingress.jsonl
|- opq_egress.mem
|- opq_egress.jsonl
|- expected_dma_words.mem
|- expected_dma_words.txt
`- uvm_replay_manifest.json
```

Promoted file semantics:

- `lane*_ingress.mem` - packed 37-bit per-lane replay beats `{valid[36], datak[35:32], data[31:0]}`.
- `opq_egress.mem` - synthesized merged OPQ-seam replay in the same packed format.
- `expected_dma_words.mem` - normalized 256-bit payload words.
- `summary.json` - profile, rates, seed, word counts, and self-check results.

The reference generator reparses its own ingress and OPQ-seam outputs, so `reparsed_dma_match` and `reparsed_opq_dma_match` remain the first sanity gate before mixed-language simulation starts.

---

## 3. RTL skeleton per harness

### 3.1 `cases/basic/uvm/`

```
tb_top (SystemVerilog)
|- clk / reset_n generation
|- interfaces.sv
|- swb_block_uvm_wrapper (VHDL)
|   |- ingress_egress_adaptor
|   |- native-SV OPQ merge path
|   |- musip_mux_4_1
|   `- musip_event_builder
`- uvm
    |- swb_uvm_pkg.sv
    |- swb_agents.sv
    |- swb_scoreboard.sv
    |- swb_sequences.sv
    |- swb_env.sv
    `- swb_basic_test.sv
```

Key promoted features in the UVM harness:

- replay mode via `+SWB_REPLAY_DIR=<path>`,
- exact randomized rerun via `+SWB_CASE_SEED=<n>`,
- synchronized frame-start slots for waveform evidence via `+SWB_FRAME_SLOT_CYCLES=<n>`,
- per-hit trace export via `+SWB_HIT_TRACE_PREFIX=<abs-prefix>`,
- campaign wrapper via `run_longrun.py` and the `make longrun` target,
- `SWB_CHECK_PASS` emitted only when payload, parser, end-of-event, and per-hit checks all close.

### 3.2 `cases/basic/plain/`

```
tb_swb_block_plain_replay (VHDL)
|- G_REPLAY_DIR
|- G_USE_MERGE
|- G_TIMEOUT_PADDING_CYCLES
|- G_SETTLE_CYCLES
|- 4x lane replay readers
|- swb_block_uvm_wrapper
`- DMA payload checker + semantic hit checker
```

The plain harness replays the deterministic bundle into the same DUT wrapper as UVM, but the final compare is hit-semantic rather than raw packed-word equality. This keeps the local check aligned with the user-visible contract: same hits, same timestamps, same completion.

### 3.3 `cases/basic/plain_2env/`

```
tb_top_2env (SystemVerilog)
|- clk / reset_n generation
|- interfaces.sv
|- swb_datapath_2env_wrapper (VHDL-only post-OPQ chain)
|- swb_opq_2env_dpi.c
|- swb_2env_agents.sv
|- swb_2env_boundary_scoreboard.sv
|- swb_opq_boundary_contract_sva.sv
|- swb_2env_env.sv
`- swb_2env_test.sv
```

This remains the explicit OPQ boundary audit harness. It is still useful even though the fully integrated path is now green, because it keeps seam debug localized when needed.

### 3.4 `cases/basic/ref/`

Python-only replay generation. No RTL. Produces the deterministic artifacts consumed by `plain/`, `plain_2env/`, and replay-mode `uvm/`.

### 3.5 `cases/basic/plain_2env/formal/`

SystemVerilog grammar model plus `swb_opq_boundary_contract_sva.sv`, driven by SymbiYosys. The scope is the seam packet grammar, not the real OPQ implementation.

---

## 4. Stage taps

All promoted monitors are passive observers.

| Stage | Tap point | `ref/` | `plain/` | `plain_2env/` | `uvm/` |
|---|---|:-:|:-:|:-:|:-:|
| A | plan creation | yes | replay-loaded | replay-loaded | yes |
| I | FEB ingress beats | yes | yes | yes | yes |
| M | post-merge AvST from `ingress_egress_adaptor` | synthesized | merge mode only | n/a | merge mode only |
| O | AvST into `musip_mux_4_1` | synthesized | wrapper-visible | DPI replay + seam scoreboard | explicit OPQ monitor |
| D | packed 256-bit words into the event builder | synthesized | yes | yes | yes |
| E | `o_dma_data`, `o_dma_wren`, `o_endofevent`, `o_done` | expected ledger | yes | yes | yes |

The UVM harness now owns the richest active observability:

- ingress monitors on all four lanes,
- explicit OPQ egress monitor,
- DMA monitor,
- hit parsing at ingress, OPQ, and DMA,
- hidden-ID and `debug_ts_8ns` matching across stages,
- optional hit-ledger dumps for debug replay.

---

## 5. Parser, scoreboard, and SVA

Promoted passive contract stack:

- ingress packet grammar - MuPix SOP/header/subheader/hit/EOP sequencing per lane.
- OPQ-seam grammar - same packet grammar after merge/interleave.
- DMA payload contract - normalized 64-bit hits packed into normalized 256-bit words.
- event-builder completion contract - payload length, `o_endofevent`, fixed padding tail, then `o_done`.

Per-harness ownership:

- `ref/` reparses generated traffic and rebuilds the expected DMA payload.
- `plain/` checks observed payload hits against the reference hit multiset and reports semantic deltas.
- `plain_2env/` checks ingress, seam, and DMA behavior with a dedicated seam scoreboard plus packet SVA.
- `uvm/` parses hits from ingress, OPQ, and DMA, assigns hidden IDs from the ingress-derived expected merged stream, reports ghost/missing hits, and can dump TSV ledgers for all stages.

The promoted UVM pass contract is:

1. no parser error,
2. ingress parsing completes cleanly,
3. OPQ parsing completes cleanly when merge is enabled,
4. observed payload word count matches the plan,
5. `o_endofevent` and `o_done` are observed,
6. zero OPQ ghost or missing hits,
7. zero DMA ghost or missing hits,
8. `SWB_CHECK_PASS` appears in the log.

---

## 6. Run control

Run control remains intentionally minimal:

1. assert reset for `G_SETTLE_CYCLES`,
2. release reset,
3. stamp the required CSR defaults,
4. enable DMA,
5. drive replay or randomized ingress traffic,
6. wait for payload completion, padding completion, and `dma_done`.

Minimal stamped controls:

- `feb_enable_mask = 4'b1111`,
- `get_n_words = expected_word_count`,
- `use_merge = 1` by default in the promoted integrated benches,
- `USE_BIT_STREAM = 1`,
- `USE_BIT_GENERIC = 1`.

There is still no full run-control agent with explicit `RUN_PREPARE / RUN_START / RUN_END` phases. That remains future work, but it is not required for the current signoff evidence.

---

## 7. Compile / elaboration order

Promoted compile sequence:

1. verify the full Questa license (`make ip-check-license`),
2. compile UVM 1.2 from the promoted Questa install,
3. compile shared support packages,
4. compile the active `swb_block` source set, including the native-SV OPQ tree selected by `tb_int/cases/basic/opq_sources.mk`,
5. compile the harness wrapper,
6. compile the harness-specific SV or VHDL files,
7. elaborate with the shipped `uvm_dpi.so` from the same Questa install for UVM runs.

When the OPQ snapshot under `firmware/a10_board/a10/merger/` changes, rerun at least:

- `make ip-compile-basic`
- `make ip-plain-basic`
- `make ip-plain-basic-2env`
- `make ip-uvm-longrun`

---

## 8. Plusargs / environment overrides

| Harness | Lever | Effect |
|---|---|---|
| `uvm/` | `+SWB_REPLAY_DIR=<path>` | load deterministic replay instead of generating a fresh random case |
| `uvm/` | `+SWB_FRAMES`, `+SWB_SAT0..3` | override random-case shape |
| `uvm/` | `+SWB_CASE_SEED=<n>` | exact rerun of a randomized case |
| `uvm/` | `+SWB_FRAME_SLOT_CYCLES=<n>` | force a fixed SOP-to-SOP slot on every enabled lane; use for human-facing wave captures where headers must align across lanes while trailers still reflect packet size |
| `uvm/` | `+SWB_HIT_TRACE_PREFIX=<abs-prefix>` | write ingress, OPQ, and DMA hit ledgers plus a summary file |
| `uvm/` | `SWB_USE_MERGE=0` or `1` | select debug bypass or real merge path |
| `uvm/` | `LONGRUN_ARGS='...'` | forward CLI options to `run_longrun.py` |
| `plain_2env/` | `+SWB_FRAME_SLOT_CYCLES=<n>` | same aligned-frame evidence mode at the explicit OPQ seam |
| `plain/` | `REPLAY_DIR=<path>` | choose the deterministic replay bundle |
| `plain/` | `SMOKE_REPLAY_DIR=<path>` | choose the smoke replay bundle |
| `plain/` | `USE_MERGE=0` or `1` | select debug bypass or real merge path |
| `plain_2env/` | `REPLAY_DIR`, `SMOKE_REPLAY_DIR` | choose the replay bundle for the DPI bridge |
| all | `QUESTA_HOME=<path>` | point to a different full Questa install |
| all | `SALT_LICENSE_SERVER=<server>` | override the default ETH floating server |
| all | `LM_LICENSE_FILE`, `MGLS_LICENSE_FILE` | chain additional license sources |

`tools/ip/run_questa.sh` fails fast when the selected install is FE/FSE rather than the promoted full Questa runtime.

---

## 9. Known harness gaps

- no real FEB/SWB CDC model,
- no full run-control agent,
- no UCDB collection or merged coverage report,
- no bind-only stage-M monitor inside shipping RTL,
- no standalone OPQ proof claim,
- no real PCIe/DMA-engine simulation.

These are real gaps, but they do not invalidate the current musip-local end-to-end closure evidence.
