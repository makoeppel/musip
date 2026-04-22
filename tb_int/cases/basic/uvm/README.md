# `tb_int/cases/basic/uvm`

Mixed-language UVM harness for the MuSiP SWB integration.

Layout:

- `dut/` holds the VHDL wrapper that exposes a narrow UVM seam around `swb_block`.
- `sv/` holds interfaces, UVM package code, agents, scoreboard, env, and the basic test.
- `work/` is created by the local Makefile for Questa scratch data.

Primary targets:

- `make compile` compiles the VHDL DUT slice and the SystemVerilog/UVM harness.
- `make run` runs `swb_basic_test`.
- `make longrun` runs the default randomized campaign wrapper and writes `report/longrun/summary.json`.
- `make clean` removes local Questa build products.

Fast path:

1. Use the full Questa runtime at `/data1/questaone_sim/questasim`.
2. Run `make compile`.
3. To replay the exact reference case in RTL, run `make run SIM_ARGS="+SWB_REPLAY_DIR=/absolute/path/to/tb_int/cases/basic/ref/out"`.
4. To generate a fresh constrained-random case inside UVM instead, run `make run` without `SWB_REPLAY_DIR`.
5. `make run` defaults to `SWB_USE_MERGE=1`, so the real integrated OPQ path is in the loop.
6. Use `make longrun` or the root wrapper `make ip-uvm-longrun` for the promoted default 128-run screen.
7. Use `../plain/` or `../plain_2env/` only when you intentionally want a narrower deterministic harness than the full UVM flow.

Helpful overrides:

- `make run SIM_ARGS='+SWB_FRAMES=1 +SWB_SAT0=0.10 +SWB_SAT1=0.20 +SWB_SAT2=0.30 +SWB_SAT3=0.40'`
- `make run SIM_ARGS='+SWB_REPLAY_DIR=/absolute/path/to/tb_int/cases/basic/ref/out'` loads `lane*_ingress.mem` and `expected_dma_words.mem` exported by the reference flow.
- `make run SIM_ARGS='+SWB_FRAMES=2 +SWB_CASE_SEED=12345 +SWB_SAT0=0.10 +SWB_SAT1=0.20 +SWB_SAT2=0.30 +SWB_SAT3=0.40'` reruns a specific random case exactly.
- `make run SIM_ARGS='+SWB_FRAMES=2 +SWB_CASE_SEED=12345 +SWB_SAT0=0.10 +SWB_SAT1=0.20 +SWB_SAT2=0.30 +SWB_SAT3=0.40 +SWB_HIT_TRACE_PREFIX=/absolute/path/prefix'` exports ingress, OPQ, and DMA hit ledgers plus a summary file.
- `make longrun LONGRUN_ARGS='--runs 128 --frames 2 --campaign-seed 260421'` runs the promoted default cross-random screen.
- `make longrun LONGRUN_ARGS='--runs 256 --frames 2 --campaign-seed 260422 --out-dir report/longrun_ext_260422_fixed'` recreates the historical stronger 256-run archive. The promoted nightly-style signoff screen remains the default 128-run campaign.
- `make run QUESTA_HOME=/data1/questaone_sim/questasim` points the harness at the installed full Questa runtime.
- `make run SALT_LICENSE_SERVER=8161@lic-mentor.ethz.ch` forces the ETH floating server explicitly.

Runtime note:

- The Intel FPGA Edition `vsim` binary boots as `intelqsim` and cannot consume the ETH `mtiverification` and `msimhdlmix` floating features. The local `run_questa.sh` wrapper fails fast with that explanation instead of letting Questa die with a generic SALT error.
- This workspace now defaults to the full runtime under `/data1/questaone_sim/questasim`. Do not use FE/FSE for simulation in this flow.
- The UVM-based targets also load the shipped `uvm_dpi.so` from the same Questa install so `uvm_cmdline_processor` and regex helpers work without falling back to `UVM_NO_DPI`.
- `dma_done` here is the `musip_event_builder.o_done` bit. It goes high only after the requested payload words have been drained and the 128-word padding tail has been emitted.
- The scoreboard assigns a hidden hit ID from the ingress-derived merged stream and checks that the same normalized hit plus the same non-overflowing 8 ns debug timestamp appears at the OPQ and DMA stages. `SWB_CHECK_PASS` is emitted only after those per-hit checks close with zero ghost or missing hits.
