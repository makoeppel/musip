# `tb_int/cases/basic`

Basic SWB/OPQ bring-up case.

If you just want to know what to run:

1. Run `make ip-tlm-basic-smoke` first. This creates the smallest deterministic replay bundle.
2. Read `tb_int/cases/basic/ref/out_smoke/summary.json`. It tells you the exact smoke packet and DMA footprint.
3. Run `make ip-plain-basic-2env-smoke`. This runs the split seam harness with ingress and egress packet monitoring.
4. Run `make ip-lint-rtl` before larger mixed-language bring-up. This catches formatting or hygiene regressions in the integration files.
5. Run `make ip-tlm-basic` to create the larger Poisson replay bundle.
6. Run `make ip-plain-basic REPLAY_DIR=$(pwd)/tb_int/cases/basic/ref/out` if you want the plain quartus-system-style replay bench.
7. Run `make ip-plain-basic-2env REPLAY_DIR=$(pwd)/tb_int/cases/basic/ref/out` if you want the split OPQ seam with the full default replay bundle.
8. Run `make ip-formal-boundary` for the packet-contract scaffold at the OPQ boundary.
9. When the full Mentor verification runtime is installed, run `make ip-uvm-basic SIM_ARGS="+SWB_REPLAY_DIR=$(pwd)/tb_int/cases/basic/ref/out"` to replay the exact same traffic in UVM/RTL.

Current bring-up paths:

- `uvm/` is the real mixed-language RTL/UVM harness.
- `plain/` is the quartus-system-style plain mixed-language replay bench.
- `plain_2env/` is the split workaround path: VHDL-only post-OPQ datapath plus a DPI-backed OPQ seam harness with explicit seam scoreboarding.
- `ref/` is the simulatorless fallback that exports replay vectors and expected DMA words while the proper Mentor/Questa runtime is unavailable.

Case content:

- 4 FEB lanes with MuPix-style frames,
- subheader hit-count field populated for the current OPQ ingress parser,
- Poisson-distributed per-subheader occupancy with lane rates in the `0.0` to `0.8` saturation range,
- DMA payload checking after OPQ merge and MuSiP repacking.

What it does not claim yet:

- exact replay of `feb_integration_datapath`,
- coverage closure across detector variants,
- formal signoff of the full SWB wrapper.

Use `ref/` for replay generation, `plain/` for the low-license mixed-language path, `plain_2env/` for the split OPQ-seam workaround plus boundary checking, and `uvm/` for the full harness.
