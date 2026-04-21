# `tb_int/cases/basic`

Basic SWB/OPQ bring-up case.

If you just want to know what to run:

1. Run `make ip-tlm-basic` first. This works on the current host and creates a replay bundle.
2. Read `tb_int/cases/basic/ref/out/summary.json`. It tells you how many hits and DMA words were generated.
3. Run `make ip-lint-rtl` before mixed-language bring-up. This catches formatting or hygiene regressions in the integration files.
4. When a standard Mentor mixed-language runtime is installed, run `make ip-plain-basic REPLAY_DIR=$(pwd)/tb_int/cases/basic/ref/out`.
5. When the full Mentor verification runtime is installed, run `make ip-uvm-basic SIM_ARGS="+SWB_REPLAY_DIR=$(pwd)/tb_int/cases/basic/ref/out"` to replay the exact same traffic in UVM/RTL.

Current bring-up paths:

- `uvm/` is the real mixed-language RTL/UVM harness.
- `plain/` is the quartus-system-style plain mixed-language replay bench.
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

Use `ref/` for the current no-runtime workaround, `plain/` for the low-license mixed-language path, and `uvm/` for the full harness.
