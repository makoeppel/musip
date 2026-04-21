# `tb_int/cases/basic/uvm`

Mixed-language UVM harness for the MuSiP SWB OPQ integration.

Layout:

- `dut/` holds the VHDL wrapper that exposes a narrow UVM seam around `swb_block`.
- `sv/` holds interfaces, UVM package code, agents, scoreboard, env, and the basic test.
- `work/` is created by the local Makefile for Questa scratch data.

Primary targets:

- `make compile` compiles the VHDL DUT slice and the SystemVerilog/UVM harness.
- `make run` runs `swb_basic_test`.
- `make clean` removes local Questa build products.

Fast path:

1. If you do not have a full Mentor/Questa runtime, stop here and use `../ref/`.
2. If you only have standard mixed-language simulation, use `../plain/` first, or `../plain_2env/` if you want to split the OPQ seam.
3. If you do have the full runtime, point `QUESTA_HOME` at it.
4. To replay the exact fallback case in RTL, run `make run SIM_ARGS="+SWB_REPLAY_DIR=/absolute/path/to/tb_int/cases/basic/ref/out"`.
5. To generate a fresh constrained-random case inside UVM instead, run `make run` without `SWB_REPLAY_DIR`.

Helpful overrides:

- `make run SIM_ARGS='+SWB_FRAMES=1 +SWB_SAT0=0.10 +SWB_SAT1=0.20 +SWB_SAT2=0.30 +SWB_SAT3=0.40'`
- `make run SIM_ARGS='+SWB_REPLAY_DIR=/absolute/path/to/tb_int/cases/basic/ref/out'` loads `lane*_ingress.mem` and `expected_dma_words.mem` exported by the fallback flow.
- `make run QUESTA_HOME=/path/to/full/questa` points the harness at a non-Intel Mentor/Questa install for runtime.
- `make run MGLS_LICENSE_FILE=8161@129.132.148.195` forces the ETH floating server explicitly.

Runtime note:

- The Intel FPGA Edition `vsim` binary boots as `intelqsim` and cannot consume the ETH `mtiverification` and `msimhdlmix` floating features. The local `run_questa.sh` wrapper fails fast with that explanation instead of letting Questa die with a generic SALT error.
- While that runtime is unavailable, use `../ref/` to generate the same basic Poisson traffic case, export replay vectors, and validate the expected DMA packing rules without pretending to run the RTL.
