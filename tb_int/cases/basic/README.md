# `tb_int/cases/basic`

Basic SWB/OPQ bring-up case.

If you just want to know what to run:

1. Run `make ip-tlm-basic-smoke` first. This creates the smallest deterministic replay bundle.
2. Read `tb_int/cases/basic/ref/out_smoke/summary.json`. It tells you the exact smoke packet and DMA footprint.
3. Run `make ip-check-license`. This verifies the ETH floating features for the installed full Questa runtime.
4. Run `make ip-compile-basic` to make sure the UVM harness compiles cleanly.
5. Run `make ip-uvm-basic SIM_ARGS="+SWB_REPLAY_DIR=$(pwd)/tb_int/cases/basic/ref/out_smoke"` to replay the exact same smoke traffic in UVM/RTL.
   The local default is the real integrated merge path (`SWB_USE_MERGE=1`).
6. Run `make ip-tlm-basic` to create the larger Poisson replay bundle.
7. Run `make ip-plain-basic REPLAY_DIR=$(pwd)/tb_int/cases/basic/ref/out` if you want the plain mixed-language replay bench instead of UVM.
8. Run `make ip-plain-basic-2env REPLAY_DIR=$(pwd)/tb_int/cases/basic/ref/out` if you want the split OPQ boundary harness with the full default replay bundle.
9. Run `make ip-formal-boundary` for the packet-contract scaffold at the OPQ boundary.
10. Run `make ip-uvm-longrun` when you want the promoted default randomized screen.

Current bring-up paths:

- `uvm/` is the default mixed-language RTL/UVM harness. It is green with the real integrated OPQ merge path enabled.
- `plain/` is the plain mixed-language replay bench for focused deterministic runs. It is green and uses a semantic per-hit DMA checker.
- `plain_2env/` is the split seam path: VHDL-only post-OPQ datapath plus a DPI-backed OPQ boundary harness with explicit seam scoreboarding. It remains the promoted OPQ boundary audit owner on the current toolchain.
- `ref/` exports replay vectors and expected DMA words without running RTL.

Case content:

- 4 FEB lanes with MuPix-style frames,
- subheader hit-count field populated for the current OPQ ingress parser,
- Poisson-distributed per-subheader occupancy with lane rates in the `0.0` to `0.8` saturation range,
- DMA payload checking after MuSiP repacking,
- promoted long-run screening over unique 4-lane `0.0` to `0.5` saturation combinations.

What it does not claim yet:

- exact replay of `feb_integration_datapath`,
- coverage closure across detector variants,
- formal signoff of the full SWB wrapper.

Use `ref/` for replay generation, `uvm/` for the default RTL/UVM flow, `plain/` for focused replay-only runs, and `plain_2env/` for boundary-focused seam checking.

Promoted current evidence:

- smoke replay closes in both `plain/` and `uvm/`,
- full replay closes in both `plain/` and `uvm/`,
- a seeded trace run with `+SWB_HIT_TRACE_PREFIX` closes with zero ghost or missing hits at ingress, OPQ, and DMA,
- the promoted default `make ip-uvm-longrun` campaign closes `128/128` runs on the authentic-wrapper owner, and a historical stronger `256/256` rerun archive remains available in `uvm/report/longrun_ext_260422_fixed/summary.json`.
